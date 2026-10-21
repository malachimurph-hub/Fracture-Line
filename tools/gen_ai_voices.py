#!/usr/bin/env python3
"""AI-generated voices for every line of the voice script (EU + TPLA units and both
announcers) with Kokoro-82M (offline neural TTS; model + voices Apache-2.0, kokoro-onnx MIT).

  /workspace/tools/tts/venv/bin/python tools/gen_ai_voices.py [--only eu|tpla] [--force]

Writes res://audio/voice_ai/<faction>/<folder>/<event>_<n>.ogg and
res://audio/voice_ai/<announcer folder>/<event>_<n>.ogg through the same import pipeline as
real recordings (tools/import_voice.py: trim, faction radio filter, -16 LUFS, Ogg). The game
prefers recorded lines in res://audio/voice/, so your own recordings always override these.
Cast: VOICE_CAST in tools/voice_manifest_src.py (several actors per faction, distinct voices
per unit type, one announcer per faction)."""
import os, sys, tempfile, hashlib, json
import numpy as np
import soundfile as sf
sys.path.insert(0, os.path.dirname(__file__))
import voice_manifest_src as vm
import import_voice as iv
from kokoro_onnx import Kokoro

TTS = os.environ.get("FL_TTS_DIR", "/workspace/tools/tts")
ROOT = iv.ROOT
OUT = os.path.join(ROOT, "audio", "voice_ai")

def style(k, spec):
    if ":" not in spec:
        return spec
    acc = None
    for part in spec.split(","):
        name, w = part.split(":")
        v = k.get_voice_style(name) * float(w)
        acc = v if acc is None else acc + v
    return acc

def main(argv):
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    force = "--force" in argv
    k = Kokoro(os.path.join(TTS, "kokoro-v1.0.onnx"), os.path.join(TTS, "voices-v1.0.bin"))
    log = []
    n_new = 0
    with tempfile.TemporaryDirectory() as td:
        for (fac, uid, folder, ev, n, text, stem, _says) in vm.lines():
            if only and fac != only:
                continue
            cast = vm.VOICE_CAST[fac]
            if uid == "announcer":
                actors = cast["announcer"]
                rel = folder
                radio = False
                spd = 1.0
            else:
                actors = cast["units"][uid]
                rel = f"{fac}/{folder}"
                radio = True
                spd = vm.EVENT_SPEED.get(ev, 1.0)
            actor = actors[(n - 1) % len(actors)]
            # small deterministic tempo jitter per line so takes don't sound cloned
            h = int(hashlib.md5(stem.encode()).hexdigest()[:4], 16)
            speed = round(actor["speed"] * spd * (0.97 + (h % 7) * 0.01), 3)
            dst = os.path.join(OUT, rel, f"{ev}_{n}.ogg")
            log.append({"file": os.path.relpath(dst, ROOT), "text": text, "voice": actor["v"], "speed": speed})
            if os.path.exists(dst) and not force:
                continue
            samples, sr = k.create(text, voice=style(k, actor["v"]), speed=speed, lang=cast["lang"])
            # 60 ms of room tone so the trim filter has an edge to find
            pad = np.zeros(int(sr * 0.06), dtype=samples.dtype)
            w = os.path.join(td, stem + ".wav")
            sf.write(w, np.concatenate([pad, samples, pad]), sr)
            iv.process(w, dst, radio, iv.style_for(rel))
            n_new += 1
            if n_new % 25 == 0:
                print("...", n_new, flush=True)
    with open(os.path.join(OUT, "voice_ai_index.json"), "w") as fh:
        json.dump({"generator": "Kokoro-82M v1.0 (Apache-2.0) via kokoro-onnx 0.6.1 (MIT)", "lines": log}, fh, indent=0)
    print(f"AI voices: {len(log)} lines ({n_new} generated now) -> {os.path.relpath(OUT, ROOT)}")

if __name__ == "__main__":
    main(sys.argv[1:])
