#!/usr/bin/env python3
"""Source of truth for the voice manifest. Writes data/audio/voice_manifest.json,
builds/m1/VOICE_SCRIPT.md and builds/m1/VOICE_CHECKLIST.csv. All wording is original.
Run: python3 tools/voice_manifest_src.py"""
import json, os, csv
ROOT = os.path.join(os.path.dirname(__file__), "..")
BUILDS = os.path.join(ROOT, "..", "builds", "m1")

# event -> runtime rules. priority: higher interrupts lower. cooldown: seconds per unit TYPE.
EVENTS = {
    "select":     {"priority": 1, "cooldown": 0.0,  "variants": 4, "len": "0.5-1.2 s", "note": "Acknowledging, alert, short. Different energy per take."},
    "move":       {"priority": 1, "cooldown": 0.0,  "variants": 4, "len": "0.5-1.2 s", "note": "Confirming an order while moving out. Brisk."},
    "attack":     {"priority": 2, "cooldown": 0.0,  "variants": 4, "len": "0.6-1.5 s", "note": "Aggressive, determined. A bit louder than move."},
    "under_fire": {"priority": 3, "cooldown": 14.0, "variants": 2, "len": "0.8-2 s",   "note": "Urgent, stressed, raised voice (not shouting into the mic)."},
    "created":    {"priority": 2, "cooldown": 2.0,  "variants": 2, "len": "0.8-2 s",   "note": "Unit just rolled out / reported in. Confident."},
    "veteran":    {"priority": 3, "cooldown": 4.0,  "variants": 1, "len": "0.8-2 s",   "note": "Promotion: proud, a smile in the voice."},
    "build":      {"priority": 2, "cooldown": 0.0,  "variants": 3, "len": "0.6-1.5 s", "note": "Builder acknowledging a construction order."},
    "harvest":    {"priority": 1, "cooldown": 0.0,  "variants": 2, "len": "0.6-1.5 s", "note": "Off to collect supplies. Workmanlike."},
    "garrison":   {"priority": 2, "cooldown": 0.0,  "variants": 2, "len": "0.6-1.5 s", "note": "Infantry moving into a building."},
}
UNIT_EVENTS = ["select", "move", "attack", "under_fire", "created", "veteran"]

EU_UNITS = {
    "eu_crawler": {"folder": "crawler", "name": "Crawler (builder dozer)", "persona": "Gruff, experienced combat engineer. Low, steady, a little dry humour.",
        "events": ["select", "move", "build", "under_fire", "created"],
        "say": {"select": ["Crawler here.", "Engineer ready.", "What are we building?", "Blade's down, standing by."],
                "move": ["Rolling.", "On my way.", "Moving the Crawler.", "Clearing a path."],
                "build": ["I'll get it built.", "Laying foundations.", "Construction underway.", "Give me a minute on this one."],
                "under_fire": ["Taking fire at the work site!", "They're shooting at the engineer!", "Need cover over here!"],
                "created": ["Crawler online, ready to build.", "Engineering unit reporting."]}},
    "eu_harvester": {"folder": "harvester", "name": "Supply hauler", "persona": "Cheerful logistics driver, tired but upbeat.",
        "events": ["select", "move", "harvest", "under_fire", "created"],
        "say": {"select": ["Hauler here.", "Supply run?", "Truck's ready.", "Logistics."],
                "move": ["Driving.", "Heading out.", "On the road.", "Moving the load."],
                "harvest": ["Going to fetch supplies.", "Loading up.", "Back to the pile."],
                "under_fire": ["The supply truck's under fire!", "They're hitting the convoy!"],
                "created": ["Hauler ready to roll.", "Supplies coming right up."]}},
    "eu_grenadier": {"folder": "grenadier", "name": "Grenadier squad (rifle infantry)", "persona": "Professional infantry squad leader. Clipped, confident.",
        "events": UNIT_EVENTS + ["garrison"],
        "say": {"select": ["Squad ready.", "Grenadiers.", "Go ahead.", "Standing by, sir."],
                "move": ["Moving.", "On the double!", "Squad, with me.", "Advancing."],
                "attack": ["Engaging!", "Open fire!", "Target in sight!", "Light them up!"],
                "under_fire": ["Contact! We're pinned!", "Taking heavy fire!", "Get down, get down!"],
                "created": ["Grenadier squad reporting.", "Boots on the ground."],
                "veteran": ["Squad's battle-hardened now.", "We've earned our stripes."],
                "garrison": ["Taking the building.", "Fortify inside!", "Holding this position."]}},
    "eu_lancer": {"folder": "lancer", "name": "Lancer squad (anti-tank infantry)", "persona": "Calm, focused anti-armour specialist. Slightly cocky.",
        "events": UNIT_EVENTS + ["garrison"],
        "say": {"select": ["Lancers.", "Tube's loaded.", "Show me armour.", "Ready."],
                "move": ["Relocating.", "Moving up.", "Changing position.", "Right away."],
                "attack": ["Rocket away!", "Target the armour!", "Fire the lance!", "Tank in the sights!"],
                "under_fire": ["We're exposed here!", "Lancers taking fire!"],
                "created": ["Lancer squad, ready to hunt tanks.", "Anti-tank team reporting."],
                "veteran": ["Lancers promoted. Bring more tanks.", "Veterans now."],
                "garrison": ["Into the building.", "Rocket nest set."]}},
    "eu_wolfhound": {"folder": "wolfhound", "name": "Wolfhound (armoured car)", "persona": "Fast recon crew. Energetic, quick delivery.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Wolfhound.", "Recon ready.", "Engine's hot.", "Where to?"],
                "move": ["Fast as we can!", "Moving out.", "On it.", "Wheels rolling."],
                "attack": ["Hitting them!", "Autocannon firing!", "Engaging target!", "Run them down!"],
                "under_fire": ["Wolfhound taking hits!", "We need to pull back!"],
                "created": ["Wolfhound ready for recon.", "Armoured car on the line."],
                "veteran": ["Wolfhound crew promoted.", "Sharper eyes now."]}},
    "eu_leopold": {"folder": "leopold", "name": "Leopold (main battle tank)", "persona": "Veteran tank commander. Heavy, confident, measured.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Leopold.", "Tank commander here.", "Armour ready.", "Give the order."],
                "move": ["Rolling out.", "Advancing.", "Tracks moving.", "Understood."],
                "attack": ["Main gun, fire!", "Target acquired!", "Engaging armour!", "Bring them down!"],
                "under_fire": ["Armour's taking hits!", "We're under fire, need support!"],
                "created": ["Leopold ready for combat.", "Main battle tank on the line."],
                "veteran": ["Leopold crew promoted.", "Battle-proven."]}},
    "eu_aegis": {"folder": "aegis", "name": "Aegis (Grid shield vehicle)", "persona": "Technical, calm systems operator. Precise.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Aegis online.", "Shield systems ready.", "Grid link stable.", "Projector standing by."],
                "move": ["Repositioning shield.", "Moving the dome.", "Relocating.", "Shield follows."],
                "attack": ["Covering the assault.", "Shields up, push forward!", "Projecting cover.", "Keep them inside the dome!"],
                "under_fire": ["Shield generator under fire!", "Projector taking damage!"],
                "created": ["Aegis online. Shields charged.", "Grid shield vehicle ready."],
                "veteran": ["Shield output improved.", "Aegis crew promoted."]}},
    "eu_flakwerk": {"folder": "flakwerk", "name": "Flakwerk (anti-air)", "persona": "Alert air-defence gunner. Sharp, watchful.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Flakwerk.", "Eyes on the sky.", "Air defence ready.", "Radar's clean."],
                "move": ["Moving the flak.", "Repositioning.", "On the move.", "Right away."],
                "attack": ["Flak up!", "Filling the sky!", "Engaging!", "Air target, firing!"],
                "under_fire": ["Flak battery under fire!", "We can't take much more!"],
                "created": ["Flakwerk ready. Nothing flies over us.", "Air defence on the line."],
                "veteran": ["Flak crew promoted.", "Better tracking now."]}},
}

ANNOUNCER = {
    "unit_ready":            {"priority": 2, "cooldown": 1.5,  "variants": 1, "say": ["Unit ready.", "Unit available.", "Reinforcements ready."]},
    "construction_complete": {"priority": 2, "cooldown": 1.5,  "variants": 1, "say": ["Construction complete.", "Structure complete.", "Building finished."]},
    "building":              {"priority": 1, "cooldown": 3.0,  "variants": 1, "say": ["Building.", "Construction started.", "Work begun."]},
    "base_under_attack":     {"priority": 4, "cooldown": 20.0, "variants": 2, "say": ["Our base is under attack.", "Warning: base under fire.", "The base is being attacked."]},
    "units_under_attack":    {"priority": 3, "cooldown": 25.0, "variants": 2, "say": ["Our forces are under attack.", "Units engaged.", "Our troops are taking fire."]},
    "low_power":             {"priority": 3, "cooldown": 30.0, "variants": 1, "say": ["Low power.", "Power is low. Build reactors.", "Warning: power shortage."]},
    "insufficient_funds":    {"priority": 2, "cooldown": 4.0,  "variants": 1, "say": ["Insufficient funds.", "Not enough money.", "Need more supplies."]},
    "cannot_build":          {"priority": 2, "cooldown": 2.0,  "variants": 1, "say": ["Cannot build there.", "Invalid location.", "Can't deploy there."]},
    "building_captured":     {"priority": 3, "cooldown": 3.0,  "variants": 1, "say": ["Building captured.", "Structure secured.", "Civilian building is ours."]},
    "unit_promoted":         {"priority": 2, "cooldown": 6.0,  "variants": 1, "say": ["Unit promoted.", "Veteran status gained.", "Unit has been promoted."]},
    "general_promoted":      {"priority": 3, "cooldown": 2.0,  "variants": 1, "say": ["General promoted.", "Command rank increased.", "Promotion: new options available."]},
    "enemy_power_detected":  {"priority": 4, "cooldown": 15.0, "variants": 1, "say": ["Enemy strike detected.", "Warning: enemy special weapon.", "Incoming enemy strike."]},
    "player_eliminated":     {"priority": 3, "cooldown": 2.0,  "variants": 1, "say": ["A player has been eliminated.", "Enemy commander defeated.", "One army is gone."]},
    "you_eliminated":        {"priority": 5, "cooldown": 2.0,  "variants": 1, "say": ["You have been defeated.", "Our forces are lost.", "Command has fallen."]},
    "victory":               {"priority": 5, "cooldown": 2.0,  "variants": 1, "say": ["Victory.", "The battlefield is ours.", "Mission accomplished."]},
    "defeat":                {"priority": 5, "cooldown": 2.0,  "variants": 1, "say": ["Defeat.", "We have lost the battle.", "Mission failed."]},
    "battle_start":          {"priority": 2, "cooldown": 2.0,  "variants": 1, "say": ["Battle control online.", "Commander, the field is yours.", "All systems ready."]},
}

def build_manifest():
    fac = {"eu": {"label": "EU Alliance", "radio": True, "units": {}}}
    for uid, u in EU_UNITS.items():
        fac["eu"]["units"][uid] = {"folder": u["folder"], "events": u["events"]}
    for later, label in [("us", "United States"), ("wa", "Western Alliance"), ("tpla", "TPLA (working name)")]:
        fac[later] = {"label": label, "radio": True, "units": {}, "later": True}
    return {
        "version": 1,
        "note": "Generated by tools/voice_manifest_src.py. Files: res://audio/voice/<faction>/<folder>/<event>_<n>.ogg; announcer: res://audio/voice/announcer/<event>_<n>.ogg. Missing lines fall back to res://audio/voice_placeholder/... (TTS placeholders).",
        "events": {k: {"priority": v["priority"], "cooldown": v["cooldown"]} for k, v in EVENTS.items()},
        "factions": fac,
        "announcer": {"folder": "announcer", "radio": False, "events": {k: {"priority": v["priority"], "cooldown": v["cooldown"]} for k, v in ANNOUNCER.items()}},
        "max_variants": 9,
    }

def write_docs():
    rows = []
    md = []
    md.append("# FRACTURE LINE — Voice recording script (M1.2)\n")
    md.append("You record these lines yourself; the game picks them up automatically. Until a line is recorded, the game plays a robotic **placeholder** (text-to-speech) so nothing is silent.\n")
    md.append("Everything here is original wording. Feel free to improvise as long as the meaning and length fit.\n")
    md.append("## How to record (phone is fine)\n")
    md.append("- **Room:** quiet, soft furnishings (a closet full of clothes or a car works great). No fans/AC, phone on flight mode.\n"
              "- **Distance:** about **15 cm** (a hand-span) from the phone's bottom mic, slightly off to the side so you don't pop on P/B sounds.\n"
              "- **App:** any recorder app (iPhone Voice Memos, Samsung Voice Recorder, …). WAV or M4A are both fine. Best quality setting, mono is fine.\n"
              "- **Takes:** record **every line 3 times** with slightly different delivery; leave ~1 s of silence before and after. One file per line is ideal, but one long file per unit is OK too (I'll cut it).\n"
              "- **Level:** speak at a firm, \"radio\" volume; avoid clipping (if the waveform hits the top, move back a little).\n"
              "- **Naming:** if you can, name each file exactly like the *File* column (e.g. `eu_leopold_attack_1.m4a`). If not, just say the file name out loud before each take.\n"
              "- **Send:** drop the files in this chat or a Google Drive folder and share it. I run `tools/import_voice.py`, which trims silence, normalises to about **-16 LUFS**, adds the faction radio filter (unit lines only; announcer stays clean) and converts to Ogg.\n")
    md.append("## Delivery guide\n")
    md.append("| Event | Length | Delivery | Variants to record |\n|---|---|---|---|")
    for k, v in EVENTS.items():
        md.append(f"| `{k}` | {v['len']} | {v['note']} | {v['variants']} |")
    md.append("\nThe game picks variants at random without repeating the last one; higher-priority lines (under fire, promotions) interrupt chatter; each event has a cooldown so lines don't spam.\n")
    md.append("## EU Alliance — unit voices\n")
    for uid, u in EU_UNITS.items():
        md.append(f"### {u['name']} — `{uid}`\n")
        md.append(f"*Persona:* {u['persona']}  ")
        md.append(f"*Folder:* `res://audio/voice/eu/{u['folder']}/`\n")
        md.append("| File | Event | Suggested wordings (pick one per take, or improvise) |\n|---|---|---|")
        for ev in u["events"]:
            for n in range(1, EVENTS[ev]["variants"] + 1):
                fn = f"eu_{u['folder']}_{ev}_{n}"
                says = u["say"].get(ev, [])
                md.append(f"| `{fn}` | {ev} | " + " / ".join(f"\"{s}\"" for s in says) + " |")
                rows.append(["eu", uid, u["folder"], ev, n, fn + ".ogg", f"audio/voice/eu/{u['folder']}/{ev}_{n}.ogg", " | ".join(says), EVENTS[ev]["len"], EVENTS[ev]["note"], "", ""])
        md.append("")
    md.append("## Announcer (battle control) — shared by all factions\n")
    md.append("*Persona:* calm, authoritative command voice; clear diction, neutral, slightly clipped. Not robotic (the radio filter is NOT applied).  \n*Folder:* `res://audio/voice/announcer/`\n")
    md.append("| File | Event | Length | Suggested wordings |\n|---|---|---|---|")
    for ev, v in ANNOUNCER.items():
        for n in range(1, v["variants"] + 1):
            fn = f"announcer_{ev}_{n}"
            md.append(f"| `{fn}` | {ev} | 0.6-2 s | " + " / ".join(f"\"{s}\"" for s in v["say"]) + " |")
            rows.append(["announcer", "announcer", "announcer", ev, n, fn + ".ogg", f"audio/voice/announcer/{ev}_{n}.ogg", " | ".join(v["say"]), "0.6-2 s", "calm command voice", "", ""])
    md.append("")
    md.append("## Other factions — later (M2)\n")
    md.append("United States, Western Alliance and TPLA (working name) get their own unit lists, personas and radio filters when they are built (M2+). Nothing to record for them yet; the manifest already has empty slots (`us`, `wa`, `tpla`).\n")
    n_unit = sum(1 for r in rows if r[0] == "eu")
    md.append(f"## Totals\n\n- EU unit lines: **{n_unit}** files\n- Announcer lines: **{len(rows) - n_unit}** files\n- Total: **{len(rows)}** files (x3 takes each when recording)\n")
    md.append("Checklist with every file: `VOICE_CHECKLIST.csv` (tick the *recorded* column as you go).\n")
    os.makedirs(BUILDS, exist_ok=True)
    with open(os.path.join(BUILDS, "VOICE_SCRIPT.md"), "w") as f:
        f.write("\n".join(md))
    with open(os.path.join(BUILDS, "VOICE_CHECKLIST.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["faction", "unit_id", "folder", "event", "variant", "file_name", "game_path", "suggested_wordings", "length", "delivery", "recorded", "notes"])
        w.writerows(rows)
    return len(rows)

if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "data", "audio"), exist_ok=True)
    with open(os.path.join(ROOT, "data", "audio", "voice_manifest.json"), "w") as f:
        json.dump(build_manifest(), f, indent=1)
    # placeholder TTS source list (minimal set: generic per event + announcer)
    ph = {"generic": {"select": ["Ready.", "Standing by."], "move": ["Moving.", "On my way."], "attack": ["Engaging!", "Open fire!"],
                      "under_fire": ["Taking fire!"], "created": ["Unit reporting."], "veteran": ["Promoted."], "build": ["Building."],
                      "harvest": ["Collecting supplies."], "garrison": ["Taking the building."]},
          "announcer": {ev: v["say"][0] for ev, v in ANNOUNCER.items()}}
    with open(os.path.join(ROOT, "tools", "placeholder_lines.json"), "w") as f:
        json.dump(ph, f, indent=1)
    print("lines:", write_docs())
