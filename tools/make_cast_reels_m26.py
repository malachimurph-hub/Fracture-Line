#!/usr/bin/env python3
"""M2.6 cast reels: one mp3 per faction, the announcer then one line from every unit, back to back.
Picks each unit's best Whisper-QA 'select' line (falls back to attack/move) from tools/voice_qa_m26.json,
then (M2.7) the unit's best combat line from the intensity pass (tools/voice_qa_intensity_m27.json),
so each character is heard calm and under fire.
Output: builds/m2_6/voice_samples/cast_<faction>.mp3 (+ cast_reels.txt listing what is in each reel).
Run: python3 tools/make_cast_reels_m26.py"""
import json, os, subprocess, sys, tempfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import voice_manifest_src as vm, voice_cast_m26 as vc
OUT = os.path.abspath(os.path.join(ROOT, "..", "builds", "m2_6", "voice_samples"))
A = os.path.join(ROOT, "audio", "voice_ai")
rep = {r["file"]: r for r in json.load(open(os.path.join(ROOT, "tools", "voice_qa_m26.json")))}
_ip = os.path.join(ROOT, "tools", "voice_qa_intensity_m27.json")
irep = json.load(open(_ip)) if os.path.exists(_ip) else []
for r in irep:                 # intensity lines replace their m26 entries
    rep[r["file"]] = r
PREF = ["select", "move", "created", "attack", "under_fire"]

def combat(fac, uid):
    ev = "base_under_attack" if uid == "announcer" else "under_fire"
    rs = sorted([r for r in irep if r["faction"] == fac and r["unit"] == uid and r["qa"] >= 0.8],
                key=lambda r: (r["event"] != ev, -r["qa"], r["file"]))
    return (rs[0]["file"], rs[0]["text"], rs[0]["qa"]) if rs else None
lines = list(vm.lines())

def pick(fac, uid):
    if uid == "announcer":                 # EU/US announcers unchanged; TPLA announcer regenerated (male)
        for (f, u, folder, ev, n, text, stem, _s) in lines:
            p = f"audio/voice_ai/{folder}/{ev}_{n}.ogg"
            if f == fac and u == uid and ev == "battle_start" and n == 1 and os.path.exists(os.path.join(ROOT, p)):
                if fac == "tpla" and p not in rep:
                    return None
                return p, text, rep.get(p, {}).get("qa")
        return None
    cands = []
    for (f, u, folder, ev, n, text, stem, _s) in lines:
        if f != fac or u != uid or ev not in PREF:
            continue
        rel = folder if uid == "announcer" else f"{fac}/{folder}"
        p = f"audio/voice_ai/{rel}/{ev}_{n}.ogg"
        if uid == "tpla_militia":           # Malachi's reference voice: shipped files, not in the m26 report
            if ev == "select" and n == 1:
                return p, text, None
            continue
        if p in rep:
            cands.append((-rep[p]["qa"], PREF.index(ev), n, p, text, rep[p]["qa"]))
    if not cands:
        return None
    c = sorted(cands)[0]
    return c[3], c[4], c[5]

os.makedirs(OUT, exist_ok=True)
log = []
with tempfile.TemporaryDirectory() as td:
    gap = os.path.join(td, "gap.wav")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-t", "0.55", gap], check=True)
    for fac in ("eu", "us", "tpla"):
        order = ["announcer"] + [u for u in vc.CAST[fac]["units"]]
        if fac == "tpla" and "tpla_militia" not in order:
            order.insert(1, "tpla_militia")
        lst = os.path.join(td, fac + ".txt")
        with open(lst, "w") as fh:
            log.append(f"cast_{fac}.mp3")
            for i, uid in enumerate(order):
                got = pick(fac, uid)
                if got is None:
                    log.append(f"  - {uid}: (no m26 line yet)")
                    continue
                for j, got in enumerate([got, combat(fac, uid)]):
                    if got is None:
                        continue
                    p, text, qa = got
                    w = os.path.join(td, f"{fac}_{i}_{j}.wav")
                    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", os.path.join(ROOT, p), "-ac", "1", "-ar", "48000", w], check=True)
                    fh.write(f"file '{w}'\nfile '{gap}'\n")
                    log.append(f"  - {uid}{' (combat)' if j else ''}: \"{text}\" ({p}{'' if qa is None else ', QA %.2f' % qa})")
        dst = os.path.join(OUT, f"cast_{fac}.mp3")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c:a", "libmp3lame", "-q:a", "3", dst], check=True)
        print(dst)
open(os.path.join(OUT, "cast_reels.txt"), "w").write("\n".join(log) + "\n")
print("\n".join(log))
