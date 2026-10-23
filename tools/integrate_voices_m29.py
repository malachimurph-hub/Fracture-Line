#!/usr/bin/env python3
"""M2.9: point the TPLA manifest at the new voice folders (tools/gen_voices_m29.py), index the new
lines and drop the retired folders. Run after generation: python3 tools/integrate_voices_m29.py"""
import json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNITS = {"tpla_scrapback": "striker", "tpla_rattler": "technical", "tpla_hailstorm": "bhx35", "tpla_shrike": "fajr",
         "tpla_blight": "koksan", "tpla_bus": "bmp2", "tpla_rocket_cell": "rocket_man", "tpla_marksman": "marksman",
         "tpla_insurgent": "insurgent", "tpla_backhoe": "backhoe", "tpla_pickup": "pickup", "tpla_mirage": "mirage",
         "tpla_mig29": "mig29", "tpla_f16": "f16"}
RETIRED = ["rattler", "hailstorm", "scrapback", "shrike", "blight", "rocket_cell", "laborer"]
qa = json.load(open(os.path.join(ROOT, "tools", "voice_qa_m29.json")))
mp = os.path.join(ROOT, "data", "audio", "voice_manifest.json")
man = json.load(open(mp))
units = man["factions"]["tpla"]["units"]
for uid, folder in UNITS.items():
    evs = sorted({os.path.basename(r["file"]).rsplit("_", 1)[0] for r in qa if r["file"].split("/")[3] == folder})
    if not evs:
        print("no lines yet for", uid); continue
    units[uid]["folder"] = folder
    units[uid]["events"] = [e for e in ["select", "move", "attack", "build", "harvest", "under_fire", "created", "veteran", "garrison"] if e in evs]
used = {u["folder"] for u in units.values()}
json.dump(man, open(mp, "w"), indent=1, ensure_ascii=False)
ip = os.path.join(ROOT, "audio", "voice_ai", "voice_ai_index.json")
idx = json.load(open(ip))
drop = [f for f in RETIRED if f not in used]
idx["lines"] = [e for e in idx["lines"] if not any(f"/tpla/{f}/" in e["file"] for f in drop)]
have = {e["file"] for e in idx["lines"]}
for r in qa:
    if r["file"] not in have:
        idx["lines"].append({"file": r["file"], "text": r["text"], "voice": r["voice"], "engine": "chatterbox-multilingual (MIT), lang=ar, M2.9 (Militia-style prompt)", "qa": r["qa"]})
json.dump(idx, open(ip, "w"), indent=0, ensure_ascii=False)
for f in drop:
    d = os.path.join(ROOT, "audio", "voice_ai", "tpla", f)
    if os.path.isdir(d):
        shutil.rmtree(d); print("removed", d)
print("manifest + index updated; folders in use:", sorted(used))
