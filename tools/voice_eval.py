#!/usr/bin/env python3
"""Objective check of accented TTS candidates with faster-whisper (MIT): forced-English
transcript word match (= is the order understandable?) and 1 - P(language=en) from whisper's
language ID (= how non-native / accented it sounds to the model).
  voice_eval.py <dir with c<cand>_<line>.wav> <names.txt>"""
import sys, re, difflib, glob, os, numpy as np, soundfile as sf
from scipy.signal import resample_poly
from faster_whisper import WhisperModel
LINES = ["Squad ready. Where do we go?", "Moving out, brothers!", "Stop that tank! We hold this street.", "Rocket team, fire on the armor!", "Our base is under attack!"]
def words(s): return re.findall(r"[a-z]+", s.lower())
def score(W, path, ref):
    a, sr = sf.read(path, dtype="float32")
    if a.ndim > 1: a = a.mean(1)
    a = resample_poly(a, 16000, sr).astype(np.float32)
    segs, info = W.transcribe(a, beam_size=1); list(segs)
    p_en = dict(info.all_language_probs or []).get("en", 0.0)
    segs, _ = W.transcribe(a, language="en", beam_size=1)
    hyp = " ".join(s.text for s in segs).strip()
    return difflib.SequenceMatcher(None, words(ref), words(hyp)).ratio(), 1 - p_en, hyp
if __name__ == "__main__":
    d, names = sys.argv[1], open(sys.argv[2]).read().splitlines()
    W = WhisperModel("small", device="cpu", compute_type="int8")
    for ci, name in enumerate(names):
        r = [score(W, os.path.join(d, f"c{ci}_{li}.wav"), t) for li, t in enumerate(LINES)]
        print(f"{name:44s} words_ok={np.mean([x[0] for x in r]):.2f} accent(non-en)={np.mean([x[1] for x in r]):.2f}  e.g. '{r[2][2]}'", flush=True)
