#!/usr/bin/env python3
"""M2.7 combat intensity reels: one mp3 per faction with combat lines only (announcer alarm, then
each unit's under_fire / attack lines from the intensity pass), about 30-40 s each.
Output: builds/m2_6/voice_samples/combat_intensity_<faction>.mp3 (+ combat_intensity_reels.txt).
Run: python3 tools/make_combat_reels_m27.py"""
import json, os, subprocess, sys, tempfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import voice_manifest_src as vm
OUT = os.path.abspath(os.path.join(ROOT, "..", "builds", "m2_6", "voice_samples"))
rep = json.load(open(os.path.join(ROOT, "tools", "voice_qa_intensity_m27.json")))
TARGET = 36.0
GAP = 0.45

def dur(p):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p], capture_output=True, text=True).stdout)

os.makedirs(OUT, exist_ok=True)
log = []
with tempfile.TemporaryDirectory() as td:
    gap = os.path.join(td, "gap.wav")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-t", str(GAP), gap], check=True)
    for fac in ("us", "eu", "tpla"):
        rs = [r for r in rep if r["faction"] == fac and r["qa"] >= 0.8]
        units = [u for u in vm.FACTIONS[fac]["units"]]
        by = lambda u, ev: sorted([r for r in rs if r["unit"] == u and r["event"] == ev], key=lambda r: (-r["qa"], r["file"]))
        # round 1: announcer alarm + every unit's best under_fire; round 2: attack lines; round 3: more
        rounds = [[("announcer", "base_under_attack")] + [(u, "under_fire") for u in units],
                  [(u, "attack") for u in units] + [("announcer", "units_under_attack")],
                  [(u, "under_fire") for u in units] + [(u, "attack") for u in units]]
        used, pl, t = set(), [], 0.0
        for rd in rounds:
            for u, ev in rd:
                for r in by(u, ev):
                    if r["file"] in used:
                        continue
                    d = dur(os.path.join(ROOT, r["file"]))
                    if t + d > TARGET + 3:
                        break
                    used.add(r["file"]); pl.append(r); t += d + GAP
                    break
                if t >= TARGET:
                    break
            if t >= TARGET:
                break
        if not pl:
            log.append(f"combat_intensity_{fac}.mp3: no intensity lines yet")
            print("skip", fac, "(no lines yet)")
            continue
        lst = os.path.join(td, fac + ".txt")
        with open(lst, "w") as fh:
            for i, r in enumerate(pl):
                w = os.path.join(td, f"{fac}_{i}.wav")
                subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", os.path.join(ROOT, r["file"]), "-ac", "1", "-ar", "48000", w], check=True)
                fh.write(f"file '{w}'\nfile '{gap}'\n")
        dst = os.path.join(OUT, f"combat_intensity_{fac}.mp3")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c:a", "libmp3lame", "-q:a", "3", dst], check=True)
        log.append(f"combat_intensity_{fac}.mp3 ({dur(dst):.1f} s)")
        log += [f"  - {r['unit']} {r['event']}: \"{r['text']}\" ({r['file']}, QA {r['qa']:.2f})" for r in pl]
        print(dst)
open(os.path.join(OUT, "combat_intensity_reels.txt"), "w").write("\n".join(log) + "\n")
print("\n".join(log))
