#!/usr/bin/env python3
"""M2.5: TPLA voices in Middle Eastern-accented English (Arabic / Persian accents).

  /workspace/tools/tts/venv_cb/bin/python tools/gen_ai_voices_me.py [--force] [--only <folder>]

Engine: Chatterbox Multilingual (Resemble AI, MIT licence, weights ResembleAI/chatterbox) on CPU,
language token "ar", English text. Accent and voice come from a short *synthetic* voice prompt:
tools/accent_tts.py renders a neutral English paragraph with a CC0 Persian Piper voice (amir,
ganji, reza_ibrahim) through Persian accent phoneme rules, then the prompt is pitch+formant
shifted by the cast's "shift" (semitones) so every unit type gets its own new speaker. No real
person's voice is cloned or imitated. Output goes through tools/import_voice.py like recordings
(trim, TPLA radio filter or announcer colour, -16 LUFS, Ogg) into res://audio/voice_ai/.
Recordings in res://audio/voice/ still override every line."""
import os, sys, json, hashlib, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import resample_poly
sys.path.insert(0, os.path.dirname(__file__))
import voice_manifest_src as vm
import import_voice as iv
import accent_tts as at

ROOT = iv.ROOT
OUT = os.path.join(ROOT, "audio", "voice_ai")
PROMPTS = os.environ.get("FL_PROMPT_DIR", "/workspace/tools/tts/prompts_me")
PIPER = {"amir": "fa_IR-amir-medium", "ganji": "fa_IR-ganji-medium", "reza": "fa_IR-reza_ibrahim-medium"}
PROMPT_TEXT = ("The convoy reached the river crossing before dawn. We unloaded the crates, checked the engines, "
               "and waited for the signal from the hills. Then we moved.")

def prompt_for(c):
    os.makedirs(PROMPTS, exist_ok=True)
    p = os.path.join(PROMPTS, f"{c['v']}_{c['shift']:+.1f}.wav")
    if not os.path.exists(p):
        a, sr = at.synth(PROMPT_TEXT, PIPER[c["v"]], "fa2" if c["v"] == "reza" else "fa", speed=0.95, noise=0.5)
        r = 2 ** (c["shift"] / 12.0)      # play-speed shift: pitch and formants together -> new speaker
        a = resample_poly(a, int(round(1000 / r)), 1000).astype(np.float32)
        sf.write(p, a, sr)
    return p

def main(argv):
    force = "--force" in argv
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    import torch
    torch.set_num_threads(int(os.environ.get("FL_THREADS", "8")))
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    cast = vm.VOICE_CAST["tpla"]
    m = None
    log, n_new, cur = [], 0, None
    with tempfile.TemporaryDirectory() as td:
        for (fac, uid, folder, ev, n, text, stem, _says) in vm.lines():
            if fac != "tpla" or (only and folder != only):
                continue
            ann = uid == "announcer"
            actors = cast["announcer"] if ann else cast["units"][uid]
            c = actors[(n - 1) % len(actors)]
            rel = folder if ann else f"tpla/{folder}"
            dst = os.path.join(OUT, rel, f"{ev}_{n}.ogg")
            h = int(hashlib.md5(stem.encode()).hexdigest()[:4], 16)
            tempo = 1.0 if ann else round(vm.EVENT_SPEED.get(ev, 1.0) * (0.98 + (h % 5) * 0.01), 3)
            exag = min(0.9, c["exag"] + (0.2 if ev in ("under_fire", "attack") else 0.0))
            log.append({"file": os.path.relpath(dst, ROOT), "text": text, "voice": vm._vname(c), "exag": exag, "tempo": tempo,
                        "engine": "chatterbox-multilingual (MIT), lang=ar"})
            since = float(os.environ.get("FL_SINCE", "0"))   # resume a --force run: keep files made after this time
            if os.path.exists(dst) and (not force or os.path.getmtime(dst) > since > 0):
                continue
            if m is None:
                m = ChatterboxMultilingualTTS.from_pretrained("cpu")
            key = (c["v"], c["shift"], exag)
            if key != cur:
                m.prepare_conditionals(prompt_for(c), exaggeration=exag)
                cur = key
            torch.manual_seed(h)
            w = m.generate(text, language_id=cast["lang"], exaggeration=exag, cfg_weight=0.5).squeeze(0).numpy()
            raw = os.path.join(td, stem + "_raw.wav")
            pad = np.zeros(int(m.sr * 0.06), dtype=np.float32)
            sf.write(raw, np.concatenate([pad, w, pad]), m.sr)
            src = raw
            if abs(tempo - 1.0) > 0.005:
                src = os.path.join(td, stem + ".wav")
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", f"atempo={tempo}", src], check=True)
            iv.process(src, dst, not ann, iv.style_for(rel))
            n_new += 1
            print("gen", os.path.relpath(dst, ROOT), repr(text), flush=True)
    ip = os.path.join(OUT, "voice_ai_index.json")
    old = json.load(open(ip)) if os.path.exists(ip) else {"lines": []}
    keep = [l for l in old["lines"] if not (l["file"].startswith("audio/voice_ai/tpla/") or l["file"].startswith("audio/voice_ai/announcer_tpla/"))]
    with open(ip, "w") as fh:
        json.dump({"generator": "EU: Kokoro-82M v1.0 (Apache-2.0) via kokoro-onnx (MIT); TPLA: Chatterbox Multilingual (MIT), lang=ar, synthetic accented prompts from CC0 Piper fa_IR voices",
                   "lines": keep + log}, fh, indent=0)
    print(f"TPLA voices: {len(log)} lines ({n_new} generated now)")

if __name__ == "__main__":
    main(sys.argv[1:])
