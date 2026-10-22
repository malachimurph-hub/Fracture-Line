#!/usr/bin/env python3
"""M2.6: pick licence-clean prompt speakers for the TPLA Chatterbox voices.

The v1/v2 prompts came from Persian Piper voices fine-tuned from the research-only "lessac" voice
(see docs/m2_6/LICENCE_REVIEW.md). This renders candidate prompts with Kokoro-82M male voices
(Apache-2.0) through the same Arabic-accent phoneme rules, voices two Militia lines through
Chatterbox with each, and scores each candidate against the shipped Militia takes (Malachi's
reference) with Chatterbox's own speaker encoder, plus Whisper word match and median pitch.

  FL_CANDS="em_alex:+0.0;hm_omega:-1.0" venv_cb/bin/python tools/voice_cast_search.py out.json"""
import os, sys, json, glob, subprocess, tempfile, re
import numpy as np, soundfile as sf, librosa
from scipy.signal import resample_poly
sys.path.insert(0, os.path.dirname(__file__))
import accent_tts as at
import import_voice as iv
import voice_manifest_src as vm

TEXT = "The convoy reached the river crossing before dawn. We unloaded the crates, checked the engines, and waited for the signal from the hills. Then we moved."
LINES = ["Ready. Point me where.", "Yalla, take them down!", "Moving up, stay low."]

def load16(p):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).copy()

def main(argv):
    import torch
    torch.set_num_threads(int(os.environ.get("FL_THREADS", "8")))
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    from faster_whisper import WhisperModel
    m = ChatterboxMultilingualTTS.from_pretrained("cpu")
    ve = m.ve
    wm = WhisperModel("small", device="cpu", compute_type="int8")
    ref = sorted(glob.glob(os.path.join(iv.ROOT, "audio/voice_ai/tpla/militia/*.ogg")))
    refs = {}
    for p in ref:
        n = int(re.search(r"_(\d+)\.ogg$", p).group(1))
        refs.setdefault((n - 1) % 3, []).append(load16(p))
    remb = {k: ve.embeds_from_wavs(v, sample_rate=16000).mean(0) for k, v in refs.items()}
    remb = {k: v / np.linalg.norm(v) for k, v in remb.items()}
    allemb = np.mean(list(remb.values()), 0); allemb /= np.linalg.norm(allemb)
    res = []
    with tempfile.TemporaryDirectory() as td:
        for cand in os.environ["FL_CANDS"].split(";"):
            mix, shift = cand.rsplit(":", 1) if cand.count(":") and cand.rsplit(":", 1)[1].startswith(("+", "-")) else (cand, "+0.0")
            shift = float(shift)
            a, sr = at.synth_kokoro(TEXT, mix)
            r = 2 ** (shift / 12.0)
            if abs(shift) > 0.01:
                a = resample_poly(a, int(round(1000 / r)), 1000).astype(np.float32)
            pp = os.path.join(td, "prompt.wav"); sf.write(pp, a, sr)
            m.prepare_conditionals(pp, exaggeration=0.6)
            embs, f0s, sc = [], [], []
            for i, t in enumerate(LINES):
                torch.manual_seed(100 + i)
                w = m.generate(t, language_id="ar", exaggeration=0.6, cfg_weight=0.5).squeeze(0).numpy()
                raw = os.path.join(td, f"r{i}.wav"); sf.write(raw, w, m.sr)
                o = os.path.join(td, f"c{i}.ogg"); iv.process(raw, o, True, iv.style_for("tpla/militia"))
                x = load16(o)
                e = ve.embeds_from_wavs([x], sample_rate=16000)[0]; embs.append(e / np.linalg.norm(e))
                f0, vf, _ = librosa.pyin(x, fmin=60, fmax=400, sr=16000)
                f0s.append(np.nanmedian(f0[vf]) if np.any(vf) else np.nan)
                segs, _ = wm.transcribe(x, language="en", beam_size=5)
                heard = " ".join(s.text for s in segs).lower()
                want = [w for w in re.findall(r"[a-z']+", t.lower()) if w != "yalla"]
                sc.append(sum(1 for w in want if w in re.findall(r"[a-z']+", heard)) / len(want))
            em = np.mean(embs, 0); em /= np.linalg.norm(em)
            row = {"cand": mix, "shift": shift, "sim_militia": round(float(em @ allemb), 3),
                   "sim_actor": {k: round(float(em @ v), 3) for k, v in remb.items()},
                   "f0": round(float(np.nanmean(f0s)), 1), "words": round(float(np.mean(sc)), 2)}
            print(json.dumps(row), flush=True); res.append(row)
    # reference: the shipped Militia takes against themselves (actor cross-similarity ceiling)
    print("REF actor cross-sim:", {f"{a}-{b}": round(float(remb[a] @ remb[b]), 3) for a in remb for b in remb if a < b})
    json.dump(res, open(argv[0], "w"), indent=1)

if __name__ == "__main__":
    main(sys.argv[1:])
