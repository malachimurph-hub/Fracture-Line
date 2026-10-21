# FRACTURE LINE — Voice recording script (M1.2)

You record these lines yourself; the game picks them up automatically. Until a line is recorded, the game plays a robotic **placeholder** (text-to-speech) so nothing is silent.

Everything here is original wording. Feel free to improvise as long as the meaning and length fit.

## How to record (phone is fine)

- **Room:** quiet, soft furnishings (a closet full of clothes or a car works great). No fans/AC, phone on flight mode.
- **Distance:** about **15 cm** (a hand-span) from the phone's bottom mic, slightly off to the side so you don't pop on P/B sounds.
- **App:** any recorder app (iPhone Voice Memos, Samsung Voice Recorder, …). WAV or M4A are both fine. Best quality setting, mono is fine.
- **Takes:** record **every line 3 times** with slightly different delivery; leave ~1 s of silence before and after. One file per line is ideal, but one long file per unit is OK too (I'll cut it).
- **Level:** speak at a firm, "radio" volume; avoid clipping (if the waveform hits the top, move back a little).
- **Naming:** if you can, name each file exactly like the *File* column (e.g. `eu_leopold_attack_1.m4a`). If not, just say the file name out loud before each take.
- **Send:** drop the files in this chat or a Google Drive folder and share it. I run `tools/import_voice.py`, which trims silence, normalises to about **-16 LUFS**, adds the faction radio filter (unit lines only; announcer stays clean) and converts to Ogg.

## Delivery guide

| Event | Length | Delivery | Variants to record |
|---|---|---|---|
| `select` | 0.5-1.2 s | Acknowledging, alert, short. Different energy per take. | 4 |
| `move` | 0.5-1.2 s | Confirming an order while moving out. Brisk. | 4 |
| `attack` | 0.6-1.5 s | Aggressive, determined. A bit louder than move. | 4 |
| `under_fire` | 0.8-2 s | Urgent, stressed, raised voice (not shouting into the mic). | 2 |
| `created` | 0.8-2 s | Unit just rolled out / reported in. Confident. | 2 |
| `veteran` | 0.8-2 s | Promotion: proud, a smile in the voice. | 1 |
| `build` | 0.6-1.5 s | Builder acknowledging a construction order. | 3 |
| `harvest` | 0.6-1.5 s | Off to collect supplies. Workmanlike. | 2 |
| `garrison` | 0.6-1.5 s | Infantry moving into a building. | 2 |

The game picks variants at random without repeating the last one; higher-priority lines (under fire, promotions) interrupt chatter; each event has a cooldown so lines don't spam.

## EU Alliance — unit voices

### Crawler (builder dozer) — `eu_crawler`

*Persona:* Gruff, experienced combat engineer. Low, steady, a little dry humour.  
*Folder:* `res://audio/voice/eu/crawler/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_crawler_select_1` | select | "Crawler here." / "Engineer ready." / "What are we building?" / "Blade's down, standing by." |
| `eu_crawler_select_2` | select | "Crawler here." / "Engineer ready." / "What are we building?" / "Blade's down, standing by." |
| `eu_crawler_select_3` | select | "Crawler here." / "Engineer ready." / "What are we building?" / "Blade's down, standing by." |
| `eu_crawler_select_4` | select | "Crawler here." / "Engineer ready." / "What are we building?" / "Blade's down, standing by." |
| `eu_crawler_move_1` | move | "Rolling." / "On my way." / "Moving the Crawler." / "Clearing a path." |
| `eu_crawler_move_2` | move | "Rolling." / "On my way." / "Moving the Crawler." / "Clearing a path." |
| `eu_crawler_move_3` | move | "Rolling." / "On my way." / "Moving the Crawler." / "Clearing a path." |
| `eu_crawler_move_4` | move | "Rolling." / "On my way." / "Moving the Crawler." / "Clearing a path." |
| `eu_crawler_build_1` | build | "I'll get it built." / "Laying foundations." / "Construction underway." / "Give me a minute on this one." |
| `eu_crawler_build_2` | build | "I'll get it built." / "Laying foundations." / "Construction underway." / "Give me a minute on this one." |
| `eu_crawler_build_3` | build | "I'll get it built." / "Laying foundations." / "Construction underway." / "Give me a minute on this one." |
| `eu_crawler_under_fire_1` | under_fire | "Taking fire at the work site!" / "They're shooting at the engineer!" / "Need cover over here!" |
| `eu_crawler_under_fire_2` | under_fire | "Taking fire at the work site!" / "They're shooting at the engineer!" / "Need cover over here!" |
| `eu_crawler_created_1` | created | "Crawler online, ready to build." / "Engineering unit reporting." |
| `eu_crawler_created_2` | created | "Crawler online, ready to build." / "Engineering unit reporting." |

### Supply hauler — `eu_harvester`

*Persona:* Cheerful logistics driver, tired but upbeat.  
*Folder:* `res://audio/voice/eu/harvester/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_harvester_select_1` | select | "Hauler here." / "Supply run?" / "Truck's ready." / "Logistics." |
| `eu_harvester_select_2` | select | "Hauler here." / "Supply run?" / "Truck's ready." / "Logistics." |
| `eu_harvester_select_3` | select | "Hauler here." / "Supply run?" / "Truck's ready." / "Logistics." |
| `eu_harvester_select_4` | select | "Hauler here." / "Supply run?" / "Truck's ready." / "Logistics." |
| `eu_harvester_move_1` | move | "Driving." / "Heading out." / "On the road." / "Moving the load." |
| `eu_harvester_move_2` | move | "Driving." / "Heading out." / "On the road." / "Moving the load." |
| `eu_harvester_move_3` | move | "Driving." / "Heading out." / "On the road." / "Moving the load." |
| `eu_harvester_move_4` | move | "Driving." / "Heading out." / "On the road." / "Moving the load." |
| `eu_harvester_harvest_1` | harvest | "Going to fetch supplies." / "Loading up." / "Back to the pile." |
| `eu_harvester_harvest_2` | harvest | "Going to fetch supplies." / "Loading up." / "Back to the pile." |
| `eu_harvester_under_fire_1` | under_fire | "The supply truck's under fire!" / "They're hitting the convoy!" |
| `eu_harvester_under_fire_2` | under_fire | "The supply truck's under fire!" / "They're hitting the convoy!" |
| `eu_harvester_created_1` | created | "Hauler ready to roll." / "Supplies coming right up." |
| `eu_harvester_created_2` | created | "Hauler ready to roll." / "Supplies coming right up." |

### Grenadier squad (rifle infantry) — `eu_grenadier`

*Persona:* Professional infantry squad leader. Clipped, confident.  
*Folder:* `res://audio/voice/eu/grenadier/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_grenadier_select_1` | select | "Squad ready." / "Grenadiers." / "Go ahead." / "Standing by, sir." |
| `eu_grenadier_select_2` | select | "Squad ready." / "Grenadiers." / "Go ahead." / "Standing by, sir." |
| `eu_grenadier_select_3` | select | "Squad ready." / "Grenadiers." / "Go ahead." / "Standing by, sir." |
| `eu_grenadier_select_4` | select | "Squad ready." / "Grenadiers." / "Go ahead." / "Standing by, sir." |
| `eu_grenadier_move_1` | move | "Moving." / "On the double!" / "Squad, with me." / "Advancing." |
| `eu_grenadier_move_2` | move | "Moving." / "On the double!" / "Squad, with me." / "Advancing." |
| `eu_grenadier_move_3` | move | "Moving." / "On the double!" / "Squad, with me." / "Advancing." |
| `eu_grenadier_move_4` | move | "Moving." / "On the double!" / "Squad, with me." / "Advancing." |
| `eu_grenadier_attack_1` | attack | "Engaging!" / "Open fire!" / "Target in sight!" / "Light them up!" |
| `eu_grenadier_attack_2` | attack | "Engaging!" / "Open fire!" / "Target in sight!" / "Light them up!" |
| `eu_grenadier_attack_3` | attack | "Engaging!" / "Open fire!" / "Target in sight!" / "Light them up!" |
| `eu_grenadier_attack_4` | attack | "Engaging!" / "Open fire!" / "Target in sight!" / "Light them up!" |
| `eu_grenadier_under_fire_1` | under_fire | "Contact! We're pinned!" / "Taking heavy fire!" / "Get down, get down!" |
| `eu_grenadier_under_fire_2` | under_fire | "Contact! We're pinned!" / "Taking heavy fire!" / "Get down, get down!" |
| `eu_grenadier_created_1` | created | "Grenadier squad reporting." / "Boots on the ground." |
| `eu_grenadier_created_2` | created | "Grenadier squad reporting." / "Boots on the ground." |
| `eu_grenadier_veteran_1` | veteran | "Squad's battle-hardened now." / "We've earned our stripes." |
| `eu_grenadier_garrison_1` | garrison | "Taking the building." / "Fortify inside!" / "Holding this position." |
| `eu_grenadier_garrison_2` | garrison | "Taking the building." / "Fortify inside!" / "Holding this position." |

### Lancer squad (anti-tank infantry) — `eu_lancer`

*Persona:* Calm, focused anti-armour specialist. Slightly cocky.  
*Folder:* `res://audio/voice/eu/lancer/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_lancer_select_1` | select | "Lancers." / "Tube's loaded." / "Show me armour." / "Ready." |
| `eu_lancer_select_2` | select | "Lancers." / "Tube's loaded." / "Show me armour." / "Ready." |
| `eu_lancer_select_3` | select | "Lancers." / "Tube's loaded." / "Show me armour." / "Ready." |
| `eu_lancer_select_4` | select | "Lancers." / "Tube's loaded." / "Show me armour." / "Ready." |
| `eu_lancer_move_1` | move | "Relocating." / "Moving up." / "Changing position." / "Right away." |
| `eu_lancer_move_2` | move | "Relocating." / "Moving up." / "Changing position." / "Right away." |
| `eu_lancer_move_3` | move | "Relocating." / "Moving up." / "Changing position." / "Right away." |
| `eu_lancer_move_4` | move | "Relocating." / "Moving up." / "Changing position." / "Right away." |
| `eu_lancer_attack_1` | attack | "Rocket away!" / "Target the armour!" / "Fire the lance!" / "Tank in the sights!" |
| `eu_lancer_attack_2` | attack | "Rocket away!" / "Target the armour!" / "Fire the lance!" / "Tank in the sights!" |
| `eu_lancer_attack_3` | attack | "Rocket away!" / "Target the armour!" / "Fire the lance!" / "Tank in the sights!" |
| `eu_lancer_attack_4` | attack | "Rocket away!" / "Target the armour!" / "Fire the lance!" / "Tank in the sights!" |
| `eu_lancer_under_fire_1` | under_fire | "We're exposed here!" / "Lancers taking fire!" |
| `eu_lancer_under_fire_2` | under_fire | "We're exposed here!" / "Lancers taking fire!" |
| `eu_lancer_created_1` | created | "Lancer squad, ready to hunt tanks." / "Anti-tank team reporting." |
| `eu_lancer_created_2` | created | "Lancer squad, ready to hunt tanks." / "Anti-tank team reporting." |
| `eu_lancer_veteran_1` | veteran | "Lancers promoted. Bring more tanks." / "Veterans now." |
| `eu_lancer_garrison_1` | garrison | "Into the building." / "Rocket nest set." |
| `eu_lancer_garrison_2` | garrison | "Into the building." / "Rocket nest set." |

### Wolfhound (armoured car) — `eu_wolfhound`

*Persona:* Fast recon crew. Energetic, quick delivery.  
*Folder:* `res://audio/voice/eu/wolfhound/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_wolfhound_select_1` | select | "Wolfhound." / "Recon ready." / "Engine's hot." / "Where to?" |
| `eu_wolfhound_select_2` | select | "Wolfhound." / "Recon ready." / "Engine's hot." / "Where to?" |
| `eu_wolfhound_select_3` | select | "Wolfhound." / "Recon ready." / "Engine's hot." / "Where to?" |
| `eu_wolfhound_select_4` | select | "Wolfhound." / "Recon ready." / "Engine's hot." / "Where to?" |
| `eu_wolfhound_move_1` | move | "Fast as we can!" / "Moving out." / "On it." / "Wheels rolling." |
| `eu_wolfhound_move_2` | move | "Fast as we can!" / "Moving out." / "On it." / "Wheels rolling." |
| `eu_wolfhound_move_3` | move | "Fast as we can!" / "Moving out." / "On it." / "Wheels rolling." |
| `eu_wolfhound_move_4` | move | "Fast as we can!" / "Moving out." / "On it." / "Wheels rolling." |
| `eu_wolfhound_attack_1` | attack | "Hitting them!" / "Autocannon firing!" / "Engaging target!" / "Run them down!" |
| `eu_wolfhound_attack_2` | attack | "Hitting them!" / "Autocannon firing!" / "Engaging target!" / "Run them down!" |
| `eu_wolfhound_attack_3` | attack | "Hitting them!" / "Autocannon firing!" / "Engaging target!" / "Run them down!" |
| `eu_wolfhound_attack_4` | attack | "Hitting them!" / "Autocannon firing!" / "Engaging target!" / "Run them down!" |
| `eu_wolfhound_under_fire_1` | under_fire | "Wolfhound taking hits!" / "We need to pull back!" |
| `eu_wolfhound_under_fire_2` | under_fire | "Wolfhound taking hits!" / "We need to pull back!" |
| `eu_wolfhound_created_1` | created | "Wolfhound ready for recon." / "Armoured car on the line." |
| `eu_wolfhound_created_2` | created | "Wolfhound ready for recon." / "Armoured car on the line." |
| `eu_wolfhound_veteran_1` | veteran | "Wolfhound crew promoted." / "Sharper eyes now." |

### Leopold (main battle tank) — `eu_leopold`

*Persona:* Veteran tank commander. Heavy, confident, measured.  
*Folder:* `res://audio/voice/eu/leopold/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_leopold_select_1` | select | "Leopold." / "Tank commander here." / "Armour ready." / "Give the order." |
| `eu_leopold_select_2` | select | "Leopold." / "Tank commander here." / "Armour ready." / "Give the order." |
| `eu_leopold_select_3` | select | "Leopold." / "Tank commander here." / "Armour ready." / "Give the order." |
| `eu_leopold_select_4` | select | "Leopold." / "Tank commander here." / "Armour ready." / "Give the order." |
| `eu_leopold_move_1` | move | "Rolling out." / "Advancing." / "Tracks moving." / "Understood." |
| `eu_leopold_move_2` | move | "Rolling out." / "Advancing." / "Tracks moving." / "Understood." |
| `eu_leopold_move_3` | move | "Rolling out." / "Advancing." / "Tracks moving." / "Understood." |
| `eu_leopold_move_4` | move | "Rolling out." / "Advancing." / "Tracks moving." / "Understood." |
| `eu_leopold_attack_1` | attack | "Main gun, fire!" / "Target acquired!" / "Engaging armour!" / "Bring them down!" |
| `eu_leopold_attack_2` | attack | "Main gun, fire!" / "Target acquired!" / "Engaging armour!" / "Bring them down!" |
| `eu_leopold_attack_3` | attack | "Main gun, fire!" / "Target acquired!" / "Engaging armour!" / "Bring them down!" |
| `eu_leopold_attack_4` | attack | "Main gun, fire!" / "Target acquired!" / "Engaging armour!" / "Bring them down!" |
| `eu_leopold_under_fire_1` | under_fire | "Armour's taking hits!" / "We're under fire, need support!" |
| `eu_leopold_under_fire_2` | under_fire | "Armour's taking hits!" / "We're under fire, need support!" |
| `eu_leopold_created_1` | created | "Leopold ready for combat." / "Main battle tank on the line." |
| `eu_leopold_created_2` | created | "Leopold ready for combat." / "Main battle tank on the line." |
| `eu_leopold_veteran_1` | veteran | "Leopold crew promoted." / "Battle-proven." |

### Aegis (Grid shield vehicle) — `eu_aegis`

*Persona:* Technical, calm systems operator. Precise.  
*Folder:* `res://audio/voice/eu/aegis/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_aegis_select_1` | select | "Aegis online." / "Shield systems ready." / "Grid link stable." / "Projector standing by." |
| `eu_aegis_select_2` | select | "Aegis online." / "Shield systems ready." / "Grid link stable." / "Projector standing by." |
| `eu_aegis_select_3` | select | "Aegis online." / "Shield systems ready." / "Grid link stable." / "Projector standing by." |
| `eu_aegis_select_4` | select | "Aegis online." / "Shield systems ready." / "Grid link stable." / "Projector standing by." |
| `eu_aegis_move_1` | move | "Repositioning shield." / "Moving the dome." / "Relocating." / "Shield follows." |
| `eu_aegis_move_2` | move | "Repositioning shield." / "Moving the dome." / "Relocating." / "Shield follows." |
| `eu_aegis_move_3` | move | "Repositioning shield." / "Moving the dome." / "Relocating." / "Shield follows." |
| `eu_aegis_move_4` | move | "Repositioning shield." / "Moving the dome." / "Relocating." / "Shield follows." |
| `eu_aegis_attack_1` | attack | "Covering the assault." / "Shields up, push forward!" / "Projecting cover." / "Keep them inside the dome!" |
| `eu_aegis_attack_2` | attack | "Covering the assault." / "Shields up, push forward!" / "Projecting cover." / "Keep them inside the dome!" |
| `eu_aegis_attack_3` | attack | "Covering the assault." / "Shields up, push forward!" / "Projecting cover." / "Keep them inside the dome!" |
| `eu_aegis_attack_4` | attack | "Covering the assault." / "Shields up, push forward!" / "Projecting cover." / "Keep them inside the dome!" |
| `eu_aegis_under_fire_1` | under_fire | "Shield generator under fire!" / "Projector taking damage!" |
| `eu_aegis_under_fire_2` | under_fire | "Shield generator under fire!" / "Projector taking damage!" |
| `eu_aegis_created_1` | created | "Aegis online. Shields charged." / "Grid shield vehicle ready." |
| `eu_aegis_created_2` | created | "Aegis online. Shields charged." / "Grid shield vehicle ready." |
| `eu_aegis_veteran_1` | veteran | "Shield output improved." / "Aegis crew promoted." |

### Flakwerk (anti-air) — `eu_flakwerk`

*Persona:* Alert air-defence gunner. Sharp, watchful.  
*Folder:* `res://audio/voice/eu/flakwerk/`

| File | Event | Suggested wordings (pick one per take, or improvise) |
|---|---|---|
| `eu_flakwerk_select_1` | select | "Flakwerk." / "Eyes on the sky." / "Air defence ready." / "Radar's clean." |
| `eu_flakwerk_select_2` | select | "Flakwerk." / "Eyes on the sky." / "Air defence ready." / "Radar's clean." |
| `eu_flakwerk_select_3` | select | "Flakwerk." / "Eyes on the sky." / "Air defence ready." / "Radar's clean." |
| `eu_flakwerk_select_4` | select | "Flakwerk." / "Eyes on the sky." / "Air defence ready." / "Radar's clean." |
| `eu_flakwerk_move_1` | move | "Moving the flak." / "Repositioning." / "On the move." / "Right away." |
| `eu_flakwerk_move_2` | move | "Moving the flak." / "Repositioning." / "On the move." / "Right away." |
| `eu_flakwerk_move_3` | move | "Moving the flak." / "Repositioning." / "On the move." / "Right away." |
| `eu_flakwerk_move_4` | move | "Moving the flak." / "Repositioning." / "On the move." / "Right away." |
| `eu_flakwerk_attack_1` | attack | "Flak up!" / "Filling the sky!" / "Engaging!" / "Air target, firing!" |
| `eu_flakwerk_attack_2` | attack | "Flak up!" / "Filling the sky!" / "Engaging!" / "Air target, firing!" |
| `eu_flakwerk_attack_3` | attack | "Flak up!" / "Filling the sky!" / "Engaging!" / "Air target, firing!" |
| `eu_flakwerk_attack_4` | attack | "Flak up!" / "Filling the sky!" / "Engaging!" / "Air target, firing!" |
| `eu_flakwerk_under_fire_1` | under_fire | "Flak battery under fire!" / "We can't take much more!" |
| `eu_flakwerk_under_fire_2` | under_fire | "Flak battery under fire!" / "We can't take much more!" |
| `eu_flakwerk_created_1` | created | "Flakwerk ready. Nothing flies over us." / "Air defence on the line." |
| `eu_flakwerk_created_2` | created | "Flakwerk ready. Nothing flies over us." / "Air defence on the line." |
| `eu_flakwerk_veteran_1` | veteran | "Flak crew promoted." / "Better tracking now." |

## Announcer (battle control) — shared by all factions

*Persona:* calm, authoritative command voice; clear diction, neutral, slightly clipped. Not robotic (the radio filter is NOT applied).  
*Folder:* `res://audio/voice/announcer/`

| File | Event | Length | Suggested wordings |
|---|---|---|---|
| `announcer_unit_ready_1` | unit_ready | 0.6-2 s | "Unit ready." / "Unit available." / "Reinforcements ready." |
| `announcer_construction_complete_1` | construction_complete | 0.6-2 s | "Construction complete." / "Structure complete." / "Building finished." |
| `announcer_building_1` | building | 0.6-2 s | "Building." / "Construction started." / "Work begun." |
| `announcer_base_under_attack_1` | base_under_attack | 0.6-2 s | "Our base is under attack." / "Warning: base under fire." / "The base is being attacked." |
| `announcer_base_under_attack_2` | base_under_attack | 0.6-2 s | "Our base is under attack." / "Warning: base under fire." / "The base is being attacked." |
| `announcer_units_under_attack_1` | units_under_attack | 0.6-2 s | "Our forces are under attack." / "Units engaged." / "Our troops are taking fire." |
| `announcer_units_under_attack_2` | units_under_attack | 0.6-2 s | "Our forces are under attack." / "Units engaged." / "Our troops are taking fire." |
| `announcer_low_power_1` | low_power | 0.6-2 s | "Low power." / "Power is low. Build reactors." / "Warning: power shortage." |
| `announcer_insufficient_funds_1` | insufficient_funds | 0.6-2 s | "Insufficient funds." / "Not enough money." / "Need more supplies." |
| `announcer_cannot_build_1` | cannot_build | 0.6-2 s | "Cannot build there." / "Invalid location." / "Can't deploy there." |
| `announcer_building_captured_1` | building_captured | 0.6-2 s | "Building captured." / "Structure secured." / "Civilian building is ours." |
| `announcer_unit_promoted_1` | unit_promoted | 0.6-2 s | "Unit promoted." / "Veteran status gained." / "Unit has been promoted." |
| `announcer_general_promoted_1` | general_promoted | 0.6-2 s | "General promoted." / "Command rank increased." / "Promotion: new options available." |
| `announcer_enemy_power_detected_1` | enemy_power_detected | 0.6-2 s | "Enemy strike detected." / "Warning: enemy special weapon." / "Incoming enemy strike." |
| `announcer_player_eliminated_1` | player_eliminated | 0.6-2 s | "A player has been eliminated." / "Enemy commander defeated." / "One army is gone." |
| `announcer_you_eliminated_1` | you_eliminated | 0.6-2 s | "You have been defeated." / "Our forces are lost." / "Command has fallen." |
| `announcer_victory_1` | victory | 0.6-2 s | "Victory." / "The battlefield is ours." / "Mission accomplished." |
| `announcer_defeat_1` | defeat | 0.6-2 s | "Defeat." / "We have lost the battle." / "Mission failed." |
| `announcer_battle_start_1` | battle_start | 0.6-2 s | "Battle control online." / "Commander, the field is yours." / "All systems ready." |

## Other factions — later (M2)

United States, Western Alliance and TPLA (working name) get their own unit lists, personas and radio filters when they are built (M2+). Nothing to record for them yet; the manifest already has empty slots (`us`, `wa`, `tpla`).

## Totals

- EU unit lines: **135** files
- Announcer lines: **19** files
- Total: **154** files (x3 takes each when recording)

Checklist with every file: `VOICE_CHECKLIST.csv` (tick the *recorded* column as you go).
