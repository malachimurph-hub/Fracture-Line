#!/usr/bin/env python3
"""Source of truth for the voice manifest. Writes data/audio/voice_manifest.json,
builds/m2/VOICE_SCRIPT.md and builds/m2/VOICE_CHECKLIST.csv. All wording is original.
Run: python3 tools/voice_manifest_src.py"""
import json, os, csv
ROOT = os.path.join(os.path.dirname(__file__), "..")
BUILDS = os.path.join(ROOT, "..", "builds", "m2")

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

ANNOUNCER_EU = {
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


# ---------------------------------------------------------------- TPLA (working name)
# Sensitivity rule (GDD 4): multinational, secular, fictional. No real ethnicity, religion or
# militant group; no stereotyped real-world accents (AI voices use neutral US English).
TPLA_UNITS = {
    "tpla_laborer": {"folder": "laborer", "name": "Laborer (worker: builds and gathers)", "persona": "Hard-working scavenger with a wry, tired humour. Grounded, friendly.",
        "events": ["select", "move", "build", "harvest", "under_fire", "created"],
        "say": {"select": ["Yeah, boss?", "Got my shovel.", "Laborer here.", "Need a hand?"],
                "move": ["Walking.", "On my way.", "Khalas, fine, I'm going.", "Heading over."],
                "build": ["We'll knock it together.", "Scrap and sweat, coming up.", "I'll build it."],
                "harvest": ["Hauling crates.", "Back to the pile."],
                "under_fire": ["They're shooting at the workers!", "Cover! We're just diggers!"],
                "created": ["Another pair of hands.", "Laborer ready to work."]}},
    "tpla_militia": {"folder": "militia", "name": "Militia (rifle infantry)", "persona": "Scrappy volunteer fighter. Fierce, informal, quick.",
        "events": UNIT_EVENTS + ["garrison"],
        "say": {"select": ["Militia.", "We're here.", "Say the word.", "Ready to fight."],
                "move": ["Moving.", "Through the alleys!", "Yalla, follow me!", "Going now."],
                "attack": ["Hit them!", "Fire, fire!", "For the Basin!", "Take them down!"],
                "under_fire": ["They found us!", "Scatter! Take cover!"],
                "created": ["Militia, armed and angry.", "Fighters reporting."],
                "veteran": ["We've learned their tricks."],
                "garrison": ["Into the tunnel!", "Get inside!"]}},
    "tpla_rocket_cell": {"folder": "rocket_cell", "name": "Rocket Cell (anti-tank infantry)", "persona": "Tense, sharp rocket team. Short sentences, eyes on armour.",
        "events": UNIT_EVENTS + ["garrison"],
        "say": {"select": ["Rocket cell.", "Tubes ready.", "Point us at steel.", "Loaded."],
                "move": ["Shifting position.", "Keep low, move!", "Relocating.", "Going."],
                "attack": ["Rocket out!", "Hit the armour!", "Yalla, fire the tube!", "Burn that tank!"],
                "under_fire": ["We're spotted!", "Rocket cell pinned down!"],
                "created": ["Rocket cell ready to hunt.", "Anti-armour team here."],
                "veteran": ["Our aim just got better."],
                "garrison": ["Down the hole!", "Rocket nest in the tunnel."]}},
    "tpla_rattler": {"folder": "rattler", "name": "Rattler (technical truck)", "persona": "Reckless driver-and-gunner pair. Loud, grinning, a bit unhinged.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Rattler!", "Engine's coughing, but ready.", "Gun's on the back.", "Where are we driving?"],
                "move": ["Hang on!", "Full throttle!", "Yalla, yalla, driving!", "Kick up the dust!"],
                "attack": ["Spray them!", "Gunner, open up!", "Drive-by!", "Rattle them!"],
                "under_fire": ["Truck's taking hits!", "Get us out of here!"],
                "created": ["Rattler rolling, held together with wire.", "Fresh truck, fresh gun."],
                "veteran": ["Nobody drives like us now."]}},
    "tpla_hailstorm": {"folder": "hailstorm", "name": "Hailstorm (quad anti-air gun)", "persona": "Watchful sky gunner. Calm until the barrels spin.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Hailstorm.", "Watching the clouds.", "Four barrels, ready.", "Sky's clear."],
                "move": ["Moving the quad.", "Rolling.", "On it.", "Repositioning."],
                "attack": ["Hail on them!", "Four barrels firing!", "Shred it!", "Fill the air!"],
                "under_fire": ["Quad gun under fire!", "They're on us!"],
                "created": ["Hailstorm ready. Let them fly.", "Quad gun on the line."],
                "veteran": ["Tighter bursts now."]}},
    "tpla_scrapback": {"folder": "scrapback", "name": "Scrapback (scrap tank)", "persona": "Proud scrap-tank commander. Heavy, slow, stubborn.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Scrapback.", "Patched and ready.", "Armour, such as it is.", "Commander here."],
                "move": ["Grinding forward.", "Treads turning.", "Boro! Rolling out.", "Moving."],
                "attack": ["Fire the cannon!", "Break them!", "Target their armour!", "Pound it!"],
                "under_fire": ["The plates are buckling!", "Scrapback taking heavy hits!"],
                "created": ["Scrapback, built from the bones of their tanks.", "Tank ready."],
                "veteran": ["This old wreck is a veteran now."]}},
    "tpla_shrike": {"folder": "shrike", "name": "Shrike (rocket buggy)", "persona": "Fast, cocky buggy driver. Loves speed, hates sitting still.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Shrike.", "Racks loaded.", "Fast and light.", "Ready to sting."],
                "move": ["Wheels up!", "Fast as she goes!", "Going!", "Hold on to something!"],
                "attack": ["Salvo away!", "Rockets, rockets!", "Sting them!", "Hit and run!"],
                "under_fire": ["Shrike's hit!", "Too hot, pulling out!"],
                "created": ["Shrike ready. Blink and you'll miss us.", "Rocket buggy online."],
                "veteran": ["Faster than ever."]}},
    "tpla_mule": {"folder": "mule", "name": "Mule (bomb truck)", "persona": "Unnervingly calm demolition driver; dark humour about the cargo. No martyrdom talk.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Mule.", "Careful with the cargo.", "Don't bump me.", "The load is armed."],
                "move": ["Easy on the bumps.", "Rolling gently.", "Going.", "Slow and steady."],
                "attack": ["Special delivery!", "Clear out!", "Here's your package!", "Delivery coming!"],
                "under_fire": ["Don't shoot the cargo!", "They're shooting at the bomb!"],
                "created": ["Mule loaded. Handle with care.", "Demolition truck ready."],
                "veteran": ["Still in one piece. Somehow."]}},
    "tpla_blight": {"folder": "blight", "name": "Blight (rust artillery)", "persona": "Quiet, eerie chemist-gunner. Speaks softly about terrible things.",
        "events": UNIT_EVENTS,
        "say": {"select": ["Blight launcher.", "Canisters ready.", "Rust and ruin.", "Waiting."],
                "move": ["Moving the launcher.", "Relocating.", "Careful with the tanks.", "On my way."],
                "attack": ["Rust them.", "Canister away!", "Let it eat their steel.", "Firing blight!"],
                "under_fire": ["Launcher under fire!", "Protect the canisters!"],
                "created": ["Blight launcher ready.", "Rust artillery online."],
                "veteran": ["Thicker rust now."]}},
}

ANNOUNCER_TPLA = {
    "unit_ready":            {"say": ["Fighter ready.", "Unit ready.", "Another one joins us."]},
    "construction_complete": {"say": ["Construction done.", "It stands.", "Building ready."]},
    "building":              {"say": ["Raising it now.", "Building.", "Work started."]},
    "base_under_attack":     {"say": ["They're hitting our camp!", "Our base is under attack!", "The camp is under fire!"]},
    "units_under_attack":    {"say": ["Our fighters are under attack.", "Our people are taking fire.", "Fighters engaged."]},
    "low_power":             {"say": ["We need no power. Keep building.", "No power needed.", "Keep building."]},
    "insufficient_funds":    {"say": ["Not enough supplies.", "We need more cash.", "Funds are short."]},
    "cannot_build":          {"say": ["Can't build there.", "No room there.", "Find another spot."]},
    "building_captured":     {"say": ["Building taken.", "That building is ours now.", "Captured."]},
    "unit_promoted":         {"say": ["A fighter has risen.", "Unit promoted.", "Veteran fighter."]},
    "general_promoted":      {"say": ["Commander promoted.", "New tricks available.", "Your rank grows."]},
    "enemy_power_detected":  {"say": ["Enemy strike incoming!", "Warning: enemy weapon!", "They're launching something!"]},
    "player_eliminated":     {"say": ["A player is finished.", "One army has fallen.", "Another commander gone."]},
    "you_eliminated":        {"say": ["We are broken.", "Our network has fallen.", "It's over for us."]},
    "victory":               {"say": ["Victory. The Basin is free.", "We won.", "The field is ours."]},
    "defeat":                {"say": ["Defeat.", "We've lost.", "Scatter and survive."]},
    "battle_start":          {"say": ["The network is live.", "Commander, the streets are ours.", "Let's begin."]},
    "hole_rebuild":          {"priority": 1, "cooldown": 8.0, "variants": 1, "say": ["Rebuilding from the rubble.", "We dig back in.", "It rises again."]},
    "salvage_upgrade":       {"priority": 1, "cooldown": 6.0, "variants": 1, "say": ["Salvage upgrade.", "Bolted on more scrap.", "Vehicle upgraded."]},
    "trap_detonated":        {"priority": 2, "cooldown": 5.0, "variants": 1, "say": ["Trap sprung.", "Demo trap detonated.", "Boom. Trap triggered."]},
    "tunnel_lost":           {"priority": 3, "cooldown": 10.0, "variants": 1, "say": ["A tunnel has collapsed.", "We lost a tunnel.", "Tunnel destroyed."]},
}

# Faction defaults for the AI-generated voices (tools/gen_ai_voices.py). Kokoro-82M voices,
# Apache-2.0. Lists = several actors per unit (squad members take turns).
VOICE_CAST = {
    "eu": {"lang": "en-gb", "announcer": [{"v": "bf_emma", "speed": 1.0}],
           "units": {"eu_crawler": [{"v": "bm_george", "speed": 0.95}],
                     "eu_harvester": [{"v": "bm_lewis", "speed": 1.0}],
                     "eu_grenadier": [{"v": "bm_daniel", "speed": 1.05}, {"v": "bm_daniel:0.5,bm_lewis:0.5", "speed": 1.05}],
                     "eu_lancer": [{"v": "bm_fable", "speed": 1.02}, {"v": "bm_fable:0.6,bm_george:0.4", "speed": 1.0}],
                     "eu_wolfhound": [{"v": "bf_lily", "speed": 1.08}],
                     "eu_leopold": [{"v": "bm_george:0.7,bm_daniel:0.3", "speed": 0.92}],
                     "eu_aegis": [{"v": "bf_isabella", "speed": 1.0}],
                     "eu_flakwerk": [{"v": "bf_alice", "speed": 1.04}]}},
    # M2.5: Middle Eastern-accented English (Arabic / Persian accents). Engine: Chatterbox
    # Multilingual (MIT), language token "ar", voice-prompted by synthetic accented-English prompts
    # made by tools/accent_tts.py from CC0 Persian Piper voices (amir, ganji, reza_ibrahim), each
    # pitch+formant shifted ("shift", semitones) into a new speaker. "exag" = Chatterbox emotion.
    "tpla": {"engine": "chatterbox", "lang": "ar",
             "announcer": [{"v": "amir", "shift": -1.0, "exag": 0.45}],
             "units": {"tpla_laborer": [{"v": "ganji", "shift": -1.5, "exag": 0.45}, {"v": "ganji", "shift": -0.5, "exag": 0.5}],
                       "tpla_militia": [{"v": "amir", "shift": 0.5, "exag": 0.6}, {"v": "ganji", "shift": 1.5, "exag": 0.6}, {"v": "reza", "shift": 2.0, "exag": 0.6}],
                       "tpla_rocket_cell": [{"v": "ganji", "shift": 1.0, "exag": 0.55}, {"v": "amir", "shift": 4.5, "exag": 0.55}],
                       "tpla_rattler": [{"v": "reza", "shift": 2.5, "exag": 0.75}],
                       "tpla_hailstorm": [{"v": "amir", "shift": -2.5, "exag": 0.5}],
                       "tpla_scrapback": [{"v": "ganji", "shift": -3.0, "exag": 0.5}],
                       "tpla_shrike": [{"v": "ganji", "shift": 5.0, "exag": 0.7}],
                       "tpla_mule": [{"v": "reza", "shift": -1.0, "exag": 0.35}],
                       "tpla_blight": [{"v": "amir", "shift": 3.5, "exag": 0.35}]}},
}
EVENT_SPEED = {"select": 1.0, "move": 1.06, "attack": 1.1, "under_fire": 1.18, "created": 1.0, "veteran": 0.98, "build": 1.0, "harvest": 1.0, "garrison": 1.06}

FACTIONS = {"eu": {"label": "EU Alliance", "units": EU_UNITS, "announcer": ANNOUNCER_EU, "ann_folder": "announcer", "radio": "eu"},
            "tpla": {"label": "TPLA (The Peoples Liberation Army, working name)", "units": TPLA_UNITS, "announcer": ANNOUNCER_TPLA, "ann_folder": "announcer_tpla", "radio": "tpla"}}

def ann_rule(fac, ev):
    """Runtime rule for an announcer event: EU table first, then the faction's own extras."""
    base = ANNOUNCER_EU.get(ev, {})
    own = FACTIONS[fac]["announcer"].get(ev, {})
    return {"priority": own.get("priority", base.get("priority", 1)), "cooldown": own.get("cooldown", base.get("cooldown", 1.0)),
            "variants": own.get("variants", base.get("variants", 1))}

# M2.4 roster units without their own recordings yet: they reuse a sibling unit's voice folder
# (and events) in the runtime manifest only, so the recording script does not list them twice.
VOICE_ALIASES = {
    "eu": {"eu_salamander": "eu_wolfhound", "eu_hearth": "eu_wolfhound", "eu_spectre": "eu_aegis", "eu_sentinel": "eu_flakwerk",
           "eu_brennus": "eu_leopold", "eu_thunderhead": "eu_leopold", "eu_kestrel": "eu_wolfhound", "eu_corvid": "eu_flakwerk"},
    "tpla": {"tpla_junkhammer": "tpla_scrapback", "tpla_sprayer": "tpla_blight", "tpla_earwig": "tpla_rattler",
             "tpla_jackal": "tpla_shrike", "tpla_bus": "tpla_rattler"},
}

def build_manifest():
    fac = {}
    for f, fd in FACTIONS.items():
        fac[f] = {"label": fd["label"], "radio": True, "radio_style": fd["radio"], "units": {}}
        for uid, u in fd["units"].items():
            fac[f]["units"][uid] = {"folder": u["folder"], "events": u["events"]}
        for uid, sib in VOICE_ALIASES.get(f, {}).items():
            u = fd["units"][sib]
            fac[f]["units"][uid] = {"folder": u["folder"], "events": u["events"], "alias_of": sib}
    for later, label in [("us", "United States"), ("wa", "Western Alliance")]:
        fac[later] = {"label": label, "radio": True, "units": {}, "later": True}
    ann_events = {}
    for f in FACTIONS:
        for ev in FACTIONS[f]["announcer"]:
            r = ann_rule(f, ev)
            ann_events[ev] = {"priority": r["priority"], "cooldown": r["cooldown"]}
    return {
        "version": 2,
        "note": "Generated by tools/voice_manifest_src.py. Lookup order per line: recorded res://audio/voice/<faction>/<folder>/<event>_<n>.ogg (announcers: audio/voice/<announcer folder>/) -> AI-generated res://audio/voice_ai/... -> robotic placeholder res://audio/voice_placeholder/... Your own recordings always win.",
        "events": {k: {"priority": v["priority"], "cooldown": v["cooldown"]} for k, v in EVENTS.items()},
        "factions": fac,
        "announcer": {"folder": "announcer", "folders": {f: FACTIONS[f]["ann_folder"] for f in FACTIONS}, "radio": False, "events": ann_events,
                      "faction_events": {f: list(FACTIONS[f]["announcer"].keys()) for f in FACTIONS}},
        "max_variants": 9,
    }

def _vname(c):
    return c["v"] if "shift" not in c else f"chatterbox/{c['v']}{c['shift']:+g}st"

def lines():
    """Every line of the script: (faction, unit_id or 'announcer', folder, event, n, text, file_stem)."""
    out = []
    for f, fd in FACTIONS.items():
        for uid, u in fd["units"].items():
            for ev in u["events"]:
                says = u["say"].get(ev, [])
                for n in range(1, EVENTS[ev]["variants"] + 1):
                    out.append((f, uid, u["folder"], ev, n, says[(n - 1) % len(says)], f"{f}_{u['folder']}_{ev}_{n}", says))
        for ev, v in fd["announcer"].items():
            r = ann_rule(f, ev)
            for n in range(1, r["variants"] + 1):
                stem = f"{fd['ann_folder']}_{ev}_{n}"
                out.append((f, "announcer", fd["ann_folder"], ev, n, v["say"][(n - 1) % len(v["say"])], stem, v["say"]))
    return out

def write_docs():
    rows = []
    md = []
    md.append("# FRACTURE LINE — Voice recording script (M2: EU Alliance + TPLA)\n")
    md.append("You record these lines yourself; the game picks them up automatically. Until a line is recorded, the game plays an **AI-generated voice** (offline neural TTS: EU on Kokoro-82M, Apache-2.0; TPLA since M2.5 on Chatterbox Multilingual, MIT, with Middle Eastern-accented English) for it, so every line in this script already has a voice in the game. Your recording always replaces the AI line with the same file name.\n")
    md.append("Everything here is original wording. Feel free to improvise as long as the meaning and length fit.\n")
    md.append("**TPLA voice direction (M2.5, Malachi's call; replaces the old neutral-accent rule):** the TPLA speaks English with Middle Eastern (Arabic / Persian) accents. Play real people, not caricatures; orders must stay clearly understandable English. A few short in-language shouts are fine (\"Yalla!\" = come on / let's go, \"Khalas\" = enough / done, \"Boro!\" = go!). Still no religious phrases.\n")
    md.append("## How to record (phone is fine)\n")
    md.append("- **Room:** quiet, soft furnishings (a closet full of clothes or a car works great). No fans/AC, phone on flight mode.\n"
              "- **Distance:** about **15 cm** (a hand-span) from the phone's bottom mic, slightly off to the side so you don't pop on P/B sounds.\n"
              "- **App:** any recorder app (iPhone Voice Memos, Samsung Voice Recorder, …). WAV or M4A are both fine. Best quality setting, mono is fine.\n"
              "- **Takes:** record **every line 3 times** with slightly different delivery; leave ~1 s of silence before and after. One file per line is ideal, but one long file per unit is OK too (I'll cut it).\n"
              "- **Level:** speak at a firm, \"radio\" volume; avoid clipping (if the waveform hits the top, move back a little).\n"
              "- **Naming:** if you can, name each file exactly like the *File* column (e.g. `eu_leopold_attack_1.m4a`, `tpla_rattler_move_2.m4a`, `announcer_tpla_victory_1.m4a`). If not, just say the file name out loud before each take.\n"
              "- **Send:** drop the files in this chat or a Google Drive folder and share it. I run `tools/import_voice.py`, which trims silence, normalises to about **-16 LUFS**, adds the faction radio filter (EU: clean military radio; TPLA: rougher scavenged walkie-talkie; announcers stay nearly clean) and converts to Ogg.\n")
    md.append("## Delivery guide\n")
    md.append("| Event | Length | Delivery | Variants to record |\n|---|---|---|---|")
    for k, v in EVENTS.items():
        md.append(f"| `{k}` | {v['len']} | {v['note']} | {v['variants']} |")
    md.append("\nThe game picks variants at random without repeating the last one; higher-priority lines (under fire, promotions) interrupt chatter; each event has a cooldown so lines don't spam.\n")
    for f, fd in FACTIONS.items():
        cast = VOICE_CAST[f]
        md.append(f"## {fd['label']} — unit voices\n")
        for uid, u in fd["units"].items():
            md.append(f"### {u['name']} — `{uid}`\n")
            md.append(f"*Persona:* {u['persona']}  ")
            md.append(f"*Folder:* `res://audio/voice/{f}/{u['folder']}/`  ")
            md.append("*AI voice now:* " + ", ".join(_vname(c) for c in cast["units"][uid]) + "\n")
            md.append("| File | Event | Suggested wordings (pick one per take, or improvise) |\n|---|---|---|")
            for ev in u["events"]:
                for n in range(1, EVENTS[ev]["variants"] + 1):
                    fn = f"{f}_{u['folder']}_{ev}_{n}"
                    says = u["say"].get(ev, [])
                    md.append(f"| `{fn}` | {ev} | " + " / ".join(f"\"{x}\"" for x in says) + " |")
                    rows.append([f, uid, u["folder"], ev, n, fn + ".ogg", f"audio/voice/{f}/{u['folder']}/{ev}_{n}.ogg", " | ".join(says), EVENTS[ev]["len"], EVENTS[ev]["note"], "ai", "", ""])
            md.append("")
        af = fd["ann_folder"]
        persona = ("calm, authoritative command voice; clear diction, slightly clipped." if f == "eu" else
                   "the TPLA's underground radio voice: warm, confident, a little defiant; Middle Eastern (Arabic / Persian) accented English.")
        md.append(f"## {fd['label']} — announcer\n")
        md.append(f"*Persona:* {persona} The radio filter is NOT applied (only a light colour on the TPLA one).  \n*Folder:* `res://audio/voice/{af}/`  \n*AI voice now:* {_vname(cast['announcer'][0])}\n")
        md.append("| File | Event | Length | Suggested wordings |\n|---|---|---|---|")
        for ev, v in fd["announcer"].items():
            for n in range(1, ann_rule(f, ev)["variants"] + 1):
                fn = f"{af}_{ev}_{n}"
                md.append(f"| `{fn}` | {ev} | 0.6-2 s | " + " / ".join(f"\"{x}\"" for x in v["say"]) + " |")
                rows.append([f, "announcer", af, ev, n, fn + ".ogg", f"audio/voice/{af}/{ev}_{n}.ogg", " | ".join(v["say"]), "0.6-2 s", persona, "ai", "", ""])
        md.append("")
    md.append("## Other factions — later\n")
    md.append("United States and Western Alliance get their own unit lists, personas, announcers and radio filters when they are built. Nothing to record for them yet; the manifest has empty slots (`us`, `wa`).\n")
    md.append("## Totals\n")
    for f in FACTIONS:
        nu = sum(1 for r in rows if r[0] == f and r[1] != "announcer")
        na = sum(1 for r in rows if r[0] == f and r[1] == "announcer")
        md.append(f"- {FACTIONS[f]['label']}: **{nu}** unit lines + **{na}** announcer lines")
    md.append(f"- Total: **{len(rows)}** files (x3 takes each when recording). All of them currently play an AI-generated voice.\n")
    md.append("Checklist with every file: `VOICE_CHECKLIST.csv` (the *voice_now* column says `ai` until your recording replaces it; tick *recorded* as you go).\n")
    os.makedirs(BUILDS, exist_ok=True)
    with open(os.path.join(BUILDS, "VOICE_SCRIPT.md"), "w") as fh:
        fh.write("\n".join(md))
    with open(os.path.join(BUILDS, "VOICE_CHECKLIST.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["faction", "unit_id", "folder", "event", "variant", "file_name", "game_path", "suggested_wordings", "length", "delivery", "voice_now", "recorded", "notes"])
        w.writerows(rows)
    return len(rows)

if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "data", "audio"), exist_ok=True)
    with open(os.path.join(ROOT, "data", "audio", "voice_manifest.json"), "w") as fh:
        json.dump(build_manifest(), fh, indent=1)
    print("lines:", write_docs())
