#!/usr/bin/env python3
"""Minimal PLACEHOLDER voices (espeak-ng TTS) until the real recordings arrive.
Generic per-event EU unit lines + one line per announcer event, run through the same
import pipeline (radio filter for units). Output: audio/voice_placeholder/ (clearly
separate from recorded lines; the game reports them as placeholders)."""
import json, os, subprocess, tempfile, sys
sys.path.insert(0, os.path.dirname(__file__))
import import_voice as iv
ROOT = iv.ROOT
lines = json.load(open(os.path.join(ROOT, "tools", "placeholder_lines.json")))
out = os.path.join(ROOT, "audio", "voice_placeholder")
with tempfile.TemporaryDirectory() as td:
    for ev, says in lines["generic"].items():
        for k, s in enumerate(says[:2], 1):
            w = os.path.join(td, f"g_{ev}_{k}.wav")
            subprocess.run(["espeak-ng", "-v", "en-us+m3", "-s", "170", "-p", "38", "-w", w, s], check=True)
            iv.process(w, os.path.join(out, "eu", "_generic", f"{ev}_{k}.ogg"), True)
    for ev, s in lines["announcer"].items():
        w = os.path.join(td, f"a_{ev}.wav")
        subprocess.run(["espeak-ng", "-v", "en-gb+f2", "-s", "150", "-p", "45", "-w", w, s], check=True)
        iv.process(w, os.path.join(out, "announcer", f"{ev}_1.ogg"), False)
print("placeholders done")
