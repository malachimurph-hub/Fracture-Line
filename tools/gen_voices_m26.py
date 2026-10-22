#!/usr/bin/env python3
"""M2.6 voice regeneration: distinct, grittier, all-male unit casts for EU, US and TPLA.

  /workspace/tools/tts/venv_cb/bin/python tools/gen_voices_m26.py [--only eu|us|tpla] [--unit <uid>] [--jobs 3] [--force]

Per line: text -> accented phonemes (tools/accent_eu.py for EU/US, tools/accent_tts.py Arabic /
Persian rules for TPLA) -> Kokoro-82M (Apache-2.0) male style blend -> vocal roughness (numpy) ->
rubberband pitch (formants shifted or kept) -> character FX + faction radio + loudness
(tools/import_voice.py) -> Whisper QA (faster-whisper small, MIT): a line under 0.8 word match is
re-taken with a lighter accent / other pace, best take kept. Cast: tools/voice_cast_m26.py.
Writes res://audio/voice_ai/... (recordings in res://audio/voice/ still override) and
voice_qa_m26.json. The TPLA Militia set is skipped (Malachi's reference voice) unless --unit
tpla_militia is given; a licence-clean candidate can be written elsewhere with --out."""
import os, sys, re, json, hashlib, subprocess, tempfile, difflib
from concurrent.futures import ProcessPoolExecutor
import numpy as np, soundfile as sf
sys.path.insert(0, os.path.dirname(__file__))
import voice_manifest_src as vm
import voice_cast_m26 as vc
import import_voice as iv
import accent_eu as ae

ROOT = iv.ROOT
OUT = os.path.join(ROOT, "audio", "voice_ai")
THR = 0.8
_k = _w = None
SHOUTS = ("yalla", "khalas", "boro")

def models():
    global _k, _w
    if _k is None:
        from kokoro_onnx import Kokoro
        _k = Kokoro("/workspace/tools/tts/kokoro-v1.0.onnx", "/workspace/tools/tts/voices-v1.0.bin")
        from faster_whisper import WhisperModel
        _w = WhisperModel("small", device="cpu", compute_type="int8", cpu_threads=2)
    return _k, _w

def style(k, mix):
    vec = None
    for part in mix.split(","):
        n, _, w = part.partition(":")
        v = k.get_voice_style(n) * float(w or 1.0)
        vec = v if vec is None else vec + v
    return vec

def phon(k, text, fac, acc, s, lang):
    if fac == "tpla" and acc in ("me", "fa2", "ar"):
        import accent_tts as at
        return at.kokoro_phonemes(text, acc)
    return ae.phonemes(k, text, lang, acc, s)

def roughen(a, sr, amt, seed):
    """Gravel: slow random amplitude jitter (shimmer, 25-90 Hz) + a little jitter-driven fry."""
    if amt <= 0:
        return a
    rng = np.random.default_rng(seed)
    n = rng.standard_normal(len(a) + 4096).astype(np.float32)
    f = np.fft.rfft(n); fr = np.fft.rfftfreq(len(n), 1 / sr)
    f[(fr < 25) | (fr > 90)] = 0
    m = np.fft.irfft(f, len(n))[:len(a)]
    m /= max(1e-6, np.std(m))
    env = np.abs(a); env = np.convolve(env, np.ones(240) / 240, "same")
    voiced = np.clip(env / (env.max() + 1e-6) * 4, 0, 1)
    return (a * (1 + amt * 0.5 * m * voiced)).astype(np.float32)

def words(s):
    return re.findall(r"[a-z']+", s.lower().replace("-", " "))

def _heard(wm, x, pad_s):
    pad = np.zeros(int(16000 * pad_s), np.float32)   # short one-word clips: Whisper needs some context
    segs, _ = wm.transcribe(np.concatenate([pad, x, pad]), language="en", beam_size=2, condition_on_previous_text=False)
    return " ".join(s.text for s in segs).strip()

def score(wm, path, text):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
    x = np.frombuffer(raw, np.float32)
    norm = lambda w: w.rstrip("'").replace("'em", "them")
    want = [norm(w) for w in words(text) if w not in SHOUTS]
    def sc_of(heard):
        got = set(words(heard))
        got |= {norm(w) for w in got}
        def hit(w):
            if w in got or w.replace("in'", "ing") in got:
                return True
            # invented unit names (Halberd, Leopold, Rattler...): accept a close phonetic spelling
            return len(w) >= 5 and any(difflib.SequenceMatcher(None, w, g).ratio() >= 0.7 for g in got)
        return sum(1 for w in want if hit(w)) / max(1, len(want))
    heard = _heard(wm, x, 0.4)
    sc = sc_of(heard)
    if sc < THR and len(x) < 16000 * 1.8:   # Whisper is erratic on ~1 s barks: second listen with more context
        h2 = _heard(wm, x, 1.2)
        s2 = sc_of(h2)
        if s2 > sc:
            sc, heard = s2, h2
    return sc, heard

def render(job):
    fac, uid, rel, ev, n, text, stem, dst, actor, lang, radio_on, rstyle = job
    k, wm = models()
    h = int(hashlib.md5(stem.encode()).hexdigest()[:6], 16)
    dst_ = dst
    est, espd, erough = vc.EVENT_MOD.get(ev, (0, 1, 0)) if uid != "announcer" else (0, 1, 0)
    ladder = [(actor["s"], 1.0), (actor["s"] * 0.55, 0.95), (0.0, 0.93), (0.0, 0.84)]
    if fac == "tpla":
        ladder = [(actor["acc"], 1.0), ("ar" if actor["acc"] == "me" else "me", 0.94), ("none", 0.95), ("none", 0.84)]
    if len(words(text)) <= 3:      # short barks: never rush them, Whisper (and players) lose them
        espd = min(espd, 1.0)
    best = (-1, None, "", None)
    with tempfile.TemporaryDirectory() as td:
        for i, (s_or_kind, sm) in enumerate(ladder):
            spd = actor["spd"] * espd * sm * (0.97 + (h % 7) * 0.01)
            if fac == "tpla":
                kind = s_or_kind
                ph = phon(k, text, fac, kind, 1, lang) if kind != "none" else k.tokenizer.phonemize(text, "en-us")
            else:
                ph = phon(k, text, fac, actor["acc"], s_or_kind, lang)
            a, sr = k.create(ph, voice=style(k, actor["v"]), speed=float(min(1.35, spd)), is_phonemes=True)
            a = np.asarray(a, np.float32)
            last = i == len(ladder) - 1      # last rung: slower, clean, light FX
            a = roughen(a, sr, 0 if last else actor.get("rough", 0) + erough, h + i)
            pad = np.zeros(int(sr * 0.08), np.float32)
            w0 = os.path.join(td, f"{i}_a.wav"); sf.write(w0, np.concatenate([pad, a, pad]), sr)
            st = actor["st"] + est + ((h >> 3) % 5 - 2) * 0.1
            src = w0
            if abs(st) > 0.05:
                src = os.path.join(td, f"{i}_b.wav")
                fm = "shifted" if actor.get("fmt") == "shift" else "preserved"
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w0, "-af",
                                f"rubberband=pitch={2 ** (st / 12):.5f}:formant={fm}:pitchq=quality", src], check=True)
            cand = os.path.join(td, f"{i}.ogg")
            iv.process(src, cand, radio_on, rstyle, pre=vc.FX["grit" if last and actor["fx"] in ("shout", "mask", "bullhorn") else actor["fx"]],
                       lufs=actor.get("lufs", -16.0))
            sc, heard = score(wm, cand, text)
            if sc > best[0]:
                best = (sc, cand, heard, i)
            if sc >= max(THR, 0.99) or (sc >= THR and i >= 1):
                break
        os.makedirs(os.path.dirname(dst_), exist_ok=True)
        subprocess.run(["cp", best[1], dst_], check=True)
    return {"file": os.path.relpath(dst_, ROOT), "text": text, "voice": actor["v"], "accent": actor["acc"], "pitch_st": actor["st"],
            "fx": actor["fx"], "who": actor.get("who", ""), "engine": "kokoro-82m (Apache-2.0) m26", "qa": round(best[0], 2),
            "take": best[3], "heard": best[2]}

def jobs(only=None, unit=None, out=OUT):
    js = []
    for (fac, uid, folder, ev, n, text, stem, _says) in vm.lines():
        if only and fac != only:
            continue
        if unit and uid != unit:
            continue
        cast = vc.CAST[fac]
        if uid == "announcer":
            if "announcer" not in cast:
                continue          # EU / US announcers (female allowed) unchanged
            actors, rel, radio_on = cast["announcer"], folder, False
        else:
            if uid == "tpla_militia" and unit != "tpla_militia":
                continue          # Malachi's reference voice stays
            actors, rel, radio_on = cast["units"][uid], f"{fac}/{folder}", True
        actor = actors[(n - 1) % len(actors)]
        dst = os.path.join(out, rel, f"{ev}_{n}.ogg")
        js.append((fac, uid, rel, ev, n, text, stem, dst, actor, cast["lang"], radio_on, iv.style_for(rel)))
    return js

def main(argv):
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    unit = argv[argv.index("--unit") + 1] if "--unit" in argv else None
    out = os.path.abspath(argv[argv.index("--out") + 1]) if "--out" in argv else OUT
    nj = int(argv[argv.index("--jobs") + 1]) if "--jobs" in argv else 3
    force = "--force" in argv
    rep_p = os.path.join(ROOT, "tools", "voice_qa_m26.json")
    rep = {r["file"]: r for r in (json.load(open(rep_p)) if os.path.exists(rep_p) else [])}
    event = argv[argv.index("--event") + 1] if "--event" in argv else None
    retake = "--retake" in argv     # re-render lines that stayed under the threshold
    js = [j for j in jobs(only, unit, out) if (event is None or j[3] in event.split(",")) and (force or os.path.relpath(j[7], ROOT) not in rep
          or (retake and rep[os.path.relpath(j[7], ROOT)]["qa"] < THR))]
    print("lines to render:", len(js), flush=True)
    import multiprocessing as mp
    with mp.get_context("spawn").Pool(nj, maxtasksperchild=25) as pool:   # recycle workers: onnx RSS creeps
        for r in pool.imap_unordered(render, js):
            rep[r["file"]] = r
            print("%-48s %.2f t%d %r" % (r["file"], r["qa"], r["take"], r["heard"]), flush=True)
            tmp = rep_p + ".tmp"     # save every line: an OOM kill must not lose finished work
            json.dump(sorted(rep.values(), key=lambda x: x["file"]), open(tmp, "w"), indent=0)
            os.replace(tmp, rep_p)
    json.dump(sorted(rep.values(), key=lambda x: x["file"]), open(rep_p, "w"), indent=0)
    sc = [r["qa"] for r in rep.values()]
    print("QA: %d lines, mean %.2f, under %.1f: %d" % (len(sc), sum(sc) / max(1, len(sc)), THR, sum(1 for x in sc if x < THR)))

if __name__ == "__main__":
    main(sys.argv[1:])
