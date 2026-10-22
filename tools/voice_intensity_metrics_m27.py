#!/usr/bin/env python3
"""Loudness / energy check for the M2.7 combat intensity pass: compares each unit's combat lines
(attack, under_fire; announcer alarms) with its calm lines (select, move, created; announcer
battle_start / unit_ready / construction_complete) in res://audio/voice_ai.
Per file: integrated loudness (EBU R128 LUFS), active-speech RMS (dBFS), approximate median f0 (YIN on loud frames, Hz),
spectral centroid (Hz, vocal effort / brightness), speech rate (words/s), and for TPLA the Whisper
language-ID probabilities (Arabic + Persian vs Russian: accent drift check).
  /workspace/tools/tts/venv_cb/bin/python tools/voice_intensity_metrics_m27.py [--root <voice dir>] [--json out.json]"""
import os, sys, json, subprocess, re
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import voice_manifest_src as vm
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
COMBAT = {"attack", "under_fire", "base_under_attack", "units_under_attack", "enemy_power_detected", "tunnel_lost"}
CALM = {"select", "move", "created", "battle_start", "unit_ready", "construction_complete"}

def decode(p, sr=16000):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32)

def lufs(p):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", p, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r)
    return float(m[-1]) if m else float("nan")

def feats(p, nwords):
    import librosa
    x = decode(p)
    fr = librosa.feature.rms(y=x, frame_length=512, hop_length=160)[0]
    act = fr > fr.max() * 0.1
    rms = 20 * np.log10(np.sqrt(np.mean(fr[act] ** 2)) + 1e-9)
    y = librosa.yin(x, fmin=65, fmax=330, sr=16000, frame_length=2048, hop_length=160)   # radio band: pYIN finds no voicing; YIN on loud frames
    r2 = librosa.feature.rms(y=x, frame_length=2048, hop_length=160)[0][:len(y)]
    f0 = float(np.median(y[r2 > r2.max() * 0.2]))
    cen = librosa.feature.spectral_centroid(y=x, sr=16000, n_fft=512, hop_length=160)[0]
    cen = float(np.median(cen[act])) if act.any() else float("nan")
    idx = np.where(act)[0]
    dur = (idx[-1] - idx[0]) * 0.01 if len(idx) > 1 else len(x) / 16000
    return {"lufs": lufs(p), "rms": float(rms), "f0": float(f0), "centroid": cen, "wps": nwords / max(0.2, dur), "dur": dur}

def main(argv):
    base = argv[argv.index("--root") + 1] if "--root" in argv else os.path.join(ROOT, "audio", "voice_ai")
    out = argv[argv.index("--json") + 1] if "--json" in argv else None
    wm = None
    rows = []
    for (fac, uid, folder, ev, n, text, stem, _s) in vm.lines():
        kind = "combat" if ev in COMBAT else "calm" if ev in CALM else None
        if kind is None:
            continue
        rel = folder if uid == "announcer" else f"{fac}/{folder}"
        p = os.path.join(base, rel, f"{ev}_{n}.ogg")
        if not os.path.exists(p):
            continue
        nw = len(re.findall(r"[a-z']+", text.lower().replace("-", " ")))
        r = {"file": os.path.relpath(p, ROOT), "fac": fac, "unit": uid, "event": ev, "kind": kind}
        r.update(feats(p, nw))
        if fac == "tpla":
            if wm is None:
                from faster_whisper import WhisperModel
                wm = WhisperModel("small", device="cpu", compute_type="int8", cpu_threads=4)
            x = decode(p); pad = np.zeros(8000, np.float32)
            _, _, probs = wm.detect_language(np.concatenate([pad, x, pad]))
            d = dict(probs)
            r["p_en"], r["p_arfa"], r["p_ru"] = d.get("en", 0), d.get("ar", 0) + d.get("fa", 0), d.get("ru", 0)
        rows.append(r)
    if out:
        json.dump(rows, open(out, "w"), indent=0)
    summary(rows)

def summary(rows):
    keys = ["lufs", "rms", "f0", "centroid", "wps"]
    print("%-22s %-7s %4s " % ("group", "kind", "n") + " ".join("%9s" % k for k in keys))
    groups = {}
    for r in rows:
        groups.setdefault((r["fac"] + ("/ann" if r["unit"] == "announcer" else "/units"), r["kind"]), []).append(r)
        groups.setdefault(("ALL", r["kind"]), []).append(r)
    for (g, k), rs in sorted(groups.items()):
        print("%-22s %-7s %4d " % (g, k, len(rs)) + " ".join("%9.2f" % np.nanmedian([r[x] for r in rs]) for x in keys))
    tp = [r for r in rows if "p_ru" in r]
    for k in ("calm", "combat"):
        rs = [r for r in tp if r["kind"] == k]
        if rs:
            print("TPLA %-6s lang-ID mean: en %.3f  ar+fa %.3f  ru %.3f  (n=%d, ru>ar+fa: %d)" % (
                k, np.mean([r["p_en"] for r in rs]), np.mean([r["p_arfa"] for r in rs]), np.mean([r["p_ru"] for r in rs]), len(rs),
                sum(1 for r in rs if r["p_ru"] > r["p_arfa"])))
    # per unit: combat minus calm medians
    units = sorted({(r["fac"], r["unit"]) for r in rows})
    worse = []
    for f, u in units:
        c = [r for r in rows if r["unit"] == u and r["fac"] == f and r["kind"] == "combat"]
        q = [r for r in rows if r["unit"] == u and r["fac"] == f and r["kind"] == "calm"]
        if c and q:
            d = {x: np.nanmedian([r[x] for r in c]) - np.nanmedian([r[x] for r in q]) for x in keys}
            print("  %-5s %-18s dLUFS %+5.1f dRMS %+5.1f df0 %+6.1f Hz dCentroid %+6.0f Hz dWPS %+5.2f" % (f, u, d["lufs"], d["rms"], d["f0"], d["centroid"], d["wps"]))
            if d["lufs"] <= 0:
                worse.append(u)
    print("units whose combat lines are not louder than calm:", worse or "none")

if __name__ == "__main__":
    main(sys.argv[1:])
