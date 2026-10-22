#!/usr/bin/env python3
"""M2.5 TPLA voice QA: transcribes every generated TPLA line with faster-whisper (small, forced
English) and scores it against the script (fraction of script words heard). Lines under the
threshold are re-rendered with other sampling seeds (same voice, same settings) and the best take
is kept. Writes builds/.../voice_qa.json-style report to stdout and tools-side log.

  /workspace/tools/tts/venv_cb/bin/python tools/voice_qa_me.py [threshold=0.7] [tries=4]"""
import os, sys, json, re, hashlib, subprocess, tempfile
import numpy as np, soundfile as sf
sys.path.insert(0, os.path.dirname(__file__))
import voice_manifest_src as vm
import import_voice as iv
import gen_ai_voices_me as g

def words(s):
    return re.findall(r"[a-z']+", s.lower().replace("-", " "))

def score(model, path, text):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
    a = np.frombuffer(raw, np.float32)
    segs, _ = model.transcribe(a, language="en", beam_size=5)
    heard = " ".join(s.text for s in segs)
    want = [w for w in words(text) if w not in ("yalla", "khalas", "boro")]   # in-language shouts
    got = set(words(heard))
    return (sum(1 for w in want if w in got) / max(1, len(want))), heard.strip()

def main(argv):
    thr = float(argv[0]) if argv else 0.7
    tries = int(argv[1]) if len(argv) > 1 else 4
    import torch
    torch.set_num_threads(int(os.environ.get("FL_THREADS", "8")))
    from faster_whisper import WhisperModel
    wm = WhisperModel("small", device="cpu", compute_type="int8")
    cast = vm.VOICE_CAST["tpla"]
    m = None
    report = []
    with tempfile.TemporaryDirectory() as td:
        for (fac, uid, folder, ev, n, text, stem, _says) in vm.lines():
            if fac != "tpla":
                continue
            if os.environ.get("FL_QA_ONLY") and stem not in os.environ["FL_QA_ONLY"].split(","):
                continue
            ann = uid == "announcer"
            c = (cast["announcer"] if ann else cast["units"][uid])[(n - 1) % len((cast["announcer"] if ann else cast["units"][uid]))]
            rel = folder if ann else f"tpla/{folder}"
            dst = os.path.join(g.OUT, rel, f"{ev}_{n}.ogg")
            s0, heard = score(wm, dst, text)
            best = (s0, None, heard)
            if s0 < thr:
                if m is None:
                    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
                    m = ChatterboxMultilingualTTS.from_pretrained("cpu")
                h = int(hashlib.md5(stem.encode()).hexdigest()[:4], 16)
                tempo = 1.0 if ann else round(vm.EVENT_SPEED.get(ev, 1.0) * (0.98 + (h % 5) * 0.01), 3)
                exag = min(0.9, c["exag"] + (0.2 if ev in ("under_fire", "attack") else 0.0))
                m.prepare_conditionals(g.prompt_for(c), exaggeration=exag)
                for k in range(1, tries + 1):
                    torch.manual_seed(h + 7919 * k)
                    w = m.generate(text, language_id=cast["lang"], exaggeration=exag, cfg_weight=0.5).squeeze(0).numpy()
                    raw = os.path.join(td, f"{stem}_{k}_raw.wav")
                    pad = np.zeros(int(m.sr * 0.06), dtype=np.float32)
                    sf.write(raw, np.concatenate([pad, w, pad]), m.sr)
                    src = raw
                    if abs(tempo - 1.0) > 0.005:
                        src = os.path.join(td, f"{stem}_{k}.wav")
                        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", f"atempo={tempo}", src], check=True)
                    cand = os.path.join(td, f"{stem}_{k}.ogg")
                    iv.process(src, cand, not ann, iv.style_for(rel))
                    sk, hk = score(wm, cand, text)
                    if sk > best[0]:
                        best = (sk, cand, hk)
                    if sk >= 0.99:
                        break
                if best[1] is not None:
                    subprocess.run(["cp", best[1], dst], check=True)
            report.append({"file": os.path.relpath(dst, g.ROOT), "text": text, "score_before": round(s0, 2), "score": round(best[0], 2), "heard": best[2]})
            print("%-55s %.2f -> %.2f  %r" % (os.path.relpath(dst, g.ROOT), s0, best[0], best[2]), flush=True)
    sc = [r["score"] for r in report]
    print("QA: %d lines, mean word match %.2f, under %.1f: %d" % (len(sc), sum(sc) / len(sc), thr, sum(1 for x in sc if x < thr)))
    json.dump(report, open(os.environ.get("FL_QA_OUT", "/tmp/voice_qa_me.json"), "w"), indent=1)

if __name__ == "__main__":
    main(sys.argv[1:])
