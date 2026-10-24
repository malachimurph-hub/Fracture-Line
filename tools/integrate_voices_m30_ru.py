#!/usr/bin/env python3
"""M3.0 F Russia voice set. Generation was capped (~20 min CPU budget), so most Russian units reuse
existing male Iran lines that say no unit, faction or nation name (same Chatterbox setup, accented
English); the T-90M and Machine Gunner also use the new Russian-accent lines from
tools/gen_voices_m30_ru.py whose speaker matches. Builds audio/voice_ai/ecc/<folder>/<event>_<n>.ogg
and adds them to audio/voice_ai/voice_ai_index.json. Re-runnable."""
import json, os, shutil
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = "tpla/"
R = "ru:"      # kept Russian render (moved aside first)
SETS = {
 "engineer": {"select": [T + "backhoe/select_3", T + "backhoe/select_2"], "move": [T + "backhoe/move_2"],
              "build": [T + "backhoe/build_1", T + "backhoe/build_2"], "under_fire": [T + "backhoe/under_fire_2"],
              "created": [T + "backhoe/select_3"]},
 "cargo_truck": {"select": [T + "pickup/select_3"], "move": [T + "pickup/move_2"], "harvest": [T + "pickup/harvest_1", T + "pickup/harvest_2"],
                 "under_fire": [T + "pickup/under_fire_2"], "created": [T + "pickup/select_3"]},
 "rifleman": {"select": [T + "militia/select_2"], "move": [T + "militia/move_2"], "attack": [T + "militia/attack_2"],
              "under_fire": [T + "militia/under_fire_2"], "created": [T + "militia/created_2"], "veteran": [T + "militia/attack_2"],
              "garrison": [T + "militia/garrison_2"]},
 "machine_gunner": {"select": [T + "marksman/select_2", T + "militia/select_4"], "move": [R + "machine_gunner/move_1"],
                    "attack": [T + "marksman/attack_3", T + "militia/attack_4"], "under_fire": [R + "machine_gunner/under_fire_1"],
                    "created": [T + "militia/select_4"], "veteran": [T + "militia/veteran_1"], "garrison": [T + "marksman/garrison_1"]},
 "rpg": {"select": [T + "rocket_man/select_2", T + "rocket_man/select_3"], "move": [T + "rocket_man/move_1", T + "rocket_man/move_2"],
         "attack": [T + "rocket_man/attack_1", T + "rocket_man/attack_2", T + "rocket_man/attack_3"],
         "under_fire": [T + "rocket_man/under_fire_1", T + "rocket_man/under_fire_2"], "created": [T + "rocket_man/select_2"],
         "veteran": [T + "rocket_man/veteran_1"], "garrison": [T + "rocket_man/garrison_1"]},
 "infiltrator": {"select": [T + "insurgent/select_1", T + "insurgent/select_2"], "move": [T + "insurgent/move_1"],
                 "attack": [T + "insurgent/attack_1", T + "insurgent/attack_2"], "under_fire": [T + "insurgent/under_fire_1", T + "insurgent/under_fire_2"],
                 "created": [T + "insurgent/select_2"], "veteran": [T + "insurgent/veteran_1"], "garrison": [T + "insurgent/select_2"]},
 "tigr": {"select": [T + "technical/select_3"], "move": [T + "technical/move_2"], "attack": [T + "technical/attack_2", T + "technical/attack_3"],
          "under_fire": [T + "technical/under_fire_2"], "created": [T + "technical/select_3"], "veteran": [T + "technical/attack_3"]},
 "btr": {"select": [T + "bmp2/select_1"], "move": [T + "bmp2/move_1"], "attack": [T + "bmp2/attack_1", T + "bmp2/attack_2", T + "bmp2/attack_3"],
         "under_fire": [T + "bmp2/under_fire_1", T + "bmp2/under_fire_2"], "created": [T + "bmp2/select_1"], "veteran": [T + "bmp2/attack_3"]},
 "typhoon": {"select": [T + "bmp2/select_1"], "move": [T + "bmp2/move_1"], "attack": [T + "bmp2/attack_3"],
             "under_fire": [T + "bmp2/under_fire_2"], "created": [T + "bmp2/select_1"], "veteran": [T + "bmp2/attack_3"]},
 "t90": {"select": [R + "t90/select_2"], "move": [R + "t90/move_1", R + "t90/move_2"], "attack": [T + "striker/attack_2", T + "striker/attack_3"],
         "under_fire": [T + "striker/under_fire_1", T + "striker/under_fire_2"], "created": [R + "t90/select_2"], "veteran": [T + "striker/attack_3"]},
 "msta": {"select": [T + "koksan/select_1"], "move": [T + "koksan/move_1"], "attack": [T + "koksan/attack_1", T + "koksan/attack_2"],
          "under_fire": [T + "koksan/under_fire_1"], "created": [T + "koksan/select_1"], "veteran": [T + "koksan/attack_1"]},
 "zeus": {"select": [T + "bhx35/select_1"], "move": [T + "bhx35/move_1"], "attack": [T + "bhx35/attack_1", T + "bhx35/attack_3"],
          "under_fire": [T + "bhx35/under_fire_1", T + "bhx35/under_fire_2"], "created": [T + "bhx35/select_1"], "veteran": [T + "bhx35/attack_3"]},
}

def main():
    va = os.path.join(ROOT, "audio", "voice_ai")
    ecc = os.path.join(va, "ecc")
    stash = os.path.join(ROOT, "tools", "voice_ru_renders")   # kept Russian renders live here (source copies)
    os.makedirs(stash, exist_ok=True)
    if os.path.isdir(ecc):
        for d in os.listdir(ecc):
            for f in os.listdir(os.path.join(ecc, d)):
                if f.endswith(".ogg") and not os.path.exists(os.path.join(stash, d + "__" + f)):
                    shutil.copy(os.path.join(ecc, d, f), os.path.join(stash, d + "__" + f))
        shutil.rmtree(ecc)
    idx_p = os.path.join(va, "voice_ai_index.json")
    idx = json.load(open(idx_p))
    by_file = {l["file"]: l for l in idx["lines"]}
    qa = {r["file"]: r for r in json.load(open(os.path.join(ROOT, "tools", "voice_qa_m30_ru.json")))}
    lines = [l for l in idx["lines"] if not l["file"].startswith("audio/voice_ai/ecc/")]
    used = set()
    for folder, evs in SETS.items():
        for ev, srcs in evs.items():
            for n, s in enumerate(srcs, 1):
                dst = f"audio/voice_ai/ecc/{folder}/{ev}_{n}.ogg"
                os.makedirs(os.path.dirname(os.path.join(ROOT, dst)), exist_ok=True)
                if s.startswith(R):
                    d, f = s[len(R):].split("/")
                    src = os.path.join(stash, f"{d}__{f}.ogg")
                    q = qa[f"audio/voice_ai/ecc/{d}/{f}.ogg"]
                    meta = {"text": q["text"], "voice": q.get("voice", "chatterbox/ru"), "note": "M3.0 F Russian-accent render"}
                    used.add(os.path.basename(src))
                else:
                    src = os.path.join(va, s + ".ogg")
                    m = by_file["audio/voice_ai/" + s + ".ogg"]
                    meta = {"text": m["text"], "voice": m.get("voice", ""), "note": "M3.0 F reused from " + s}
                shutil.copy(src, os.path.join(ROOT, dst))
                lines.append({"file": dst, **meta})
    for f in os.listdir(stash):   # drop renders that are not used (speaker did not match the reused lines)
        if f not in used:
            os.remove(os.path.join(stash, f))
    idx["lines"] = lines
    json.dump(idx, open(idx_p, "w"), indent=0)
    print("ecc lines:", sum(len(v) for e in SETS.values() for v in e.values()), "russian renders kept:", sorted(used))

if __name__ == "__main__":
    main()
