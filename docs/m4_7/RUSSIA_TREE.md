# Russia tech tree

Russia (faction id `ecc`) is the heavy side: armour, artillery, and a thick base. The United States stays the air-superiority faction. Russian aircraft are fewer and slower, and nothing here is stealthed in the air. Tech is gated on the Ministry of Defense, which itself needs the Vehicle Factory and now takes 22 seconds to build.

Germany, Iran and the US rosters are unchanged. Shared code that grew a Russia branch: stealth-until-engaged, deploy-before-fire, tower power draw, ballistic flight for two Russian missiles, and the command card.

## Chain

Kremlin → Combined-Cycle Gas Plant → Barracks and Supply Depot → Vehicle Factory → Airfield and Ministry of Defense.

The Ministry unlocks FSB GRU ($4200, −6 power) and the Black Market ($6500, −5 power).

| Step | Unlocks |
|---|---|
| Barracks | Conscript squad. Drone Operator once the Ministry exists. |
| Vehicle Factory | Tiger-M, BTR, Typhoon, BMP-3, T-90M, Shilka, 2S Msta, TOS-1A, BMPT, Iskander, Pantsir (needs Ministry), T-14 (needs Ministry), Grim Reaper (needs research), Engineer. Also Balanced Tower and Reactive Armour. |
| Airfield | Su-57, Ka-52, Mi-24, Mi-8, Tu-160 (needs Ministry). |
| Ministry | Anti-Armor Tower, Anti-Air Tower, Red Dawn, Grim Reaper research. |
| FSB GRU | FSB Alfa, Spetsnaz, VDV Spetsnaz. |
| Black Market | Four hacks. No wage. |

The old Infiltrator and Saboteur stay loadable for saves and replays. They are not in the build menu or the AI.

## Units

Costs are supply. Time is build time. Speed is milli-tiles per second.

| Unit | Cost | Time | Pop | HP | Speed | Role |
|---|---:|---:|---:|---:|---:|---|
| Conscripts | 1000 | 12 s | 3 | 500 | 1000 | 3× AK-47 (13 dmg), 2× RPG-7, 1× PKM |
| FSB Alfa | 750 | 10 s | 1 | 220 | 1280 | AS Val 26 dmg. Captures. Hidden until he fights. |
| Spetsnaz | 1200 | 14 s | 2 | 390 | 1380 | 3 men. VSS (38 dmg, 10-round clip, 4° aim) and two AK-74U. Hidden until they fight. |
| VDV Spetsnaz | 850 | 11 s | 2 | 300 | 1300 | 2 men, AK-74M plus GP-25. Tag `parachute` only. No drop mechanic. |
| BMP-3 | 1150 | 13 s | 2 | 960 | 1650 | 100 mm, 30 mm, ATGM. Carries 6. Slower and tougher than the Bradley (2000 / 820). |
| BMPT | 1600 | 16 s | 3 | 1180 | 1350 | Heavy. Twin 30 mm, grenades, ATGM. |
| T-90M | 1100 | 12 s | 3 | 970 | 1450 | Unchanged gun. Reactive Armour is research. |
| T-14 | 1900 | 18 s | 4 | 1400 | 1520 | 145 dmg cannon. Needs the Ministry. |
| Shilka | 800 | 9 s | 2 | 540 | 1900 | Same unit as `ecc_zeus`. Display name only. |
| 2S Msta | 1400 | 15 s | 3 | 480 | 1250 | Unchanged. |
| TOS-1A | 1750 | 16 s | 3 | 700 | 1100 | 12-rocket clip, 32 demolition, 4.8 tile range, 1.5 tile splash. |
| Iskander | 2400 | 20 s | 3 | 540 | 1250 | One 260 demolition missile, 15 tile range. 5 s setup. |
| Pantsir | 2100 | 20 s | 3 | 640 | 1400 | Needs the Ministry. 8 s deploy. 30 mm plus missiles out to 12 tiles. A planted Pantsir can engage aircraft that only base defences could hit. |
| Grim Reaper | 5200 | 42 s | 4 | 680 | 880 | Research. 8 s deploy. One missile, six 95-damage warheads, 1.7 tile splash. No build cap. |
| Mi-8 | 1250 | 14 s | 3 | 820 | 3400 | Carries 8. Door gun. Lands to load, same as the other helicopters. US Black Hawk is 4460. |

FSB soldiers use tag `stealth_combat`: hidden until they fire or take a hit, then for 3 seconds. Detectors and troops in contact still see them, the same way the other hidden infantry work.

## Research

Each is bought once.

| Research | Where | Cost | Time | Effect |
|---|---|---:|---:|---|
| Balanced Tower | Factory | 800 | 20 s | Fit any Russian structure for $450. Autocannon, ground and air. Draws 1 power. |
| Anti-Armor Tower | Ministry | 1400 | 28 s | Fit for $800. Anti-tank missile. Draws 2. |
| Anti-Air Tower | Ministry | 1400 | 28 s | Fit for $800. Anti-air missile. Draws 2. |
| Reactive Armour | Factory | 900 | 22 s | T-90M takes 40% less damage from cannon, anti-tank, autocannon, explosive, demolition, HMG, quad, flak and missiles. Small arms are unchanged. The hidden armour blocks on the model are shown. |
| Red Dawn | Ministry | 2500 | 40 s | Ministry ability. Three conscript squads. 7.5 min cooldown. Not a generals-points power. |
| Grim Reaper | Ministry | 3000 | 45 s | Unlocks the truck. |
| Grid Shutdown | Black Market | 700 | 16 s | Enemy power production drops to zero for 18 s. Cooldown 3 min. |
| Radar Blackout | Black Market | 800 | 16 s | Enemy minimap goes blank for 25 s. Cooldown 3.5 min. |
| Funds Siphon | Black Market | 1100 | 20 s | Steals $30 a second for 30 s, limited by what they hold. Cooldown 4 min. |
| Unit Hijack | Black Market | 1600 | 26 s | One enemy drone or ground vehicle. Not infantry, not aircraft with a crew. Cooldown 5 min. |

Hacks and Red Dawn need the building powered. One shared cooldown per player, not per building. The AI fits towers, calls Red Dawn on a known enemy, and uses the hacks.

## Models and voices

Buildings stay on `tools/m47/models_m47.gd`. The seven new vehicles are rebuilt in `tools/m47/vehicles_m47.gd` to published proportions (tracked family 0.30 model-units per metre, the same ballpark as the T-90's 1.9-unit hull). Russian green, road wheels or the real axle count, skirts or ERA, hatches, sights, antennas, exhausts, and baked AO.

| Vehicle | Published size used | Running gear | What the mesh is built around |
| --- | --- | --- | --- |
| BMP-3 | 7.14 x 3.23 x 2.30 m | 6 road wheels, rear sprocket | Blender mesh (`assets/models/ecc/bmp3.glb`). Boat bow, trim vane, three closed front hatches, 100 mm with the 30 mm beside it, three smoke pots a side, rear doors. The old scene is `bmp3_legacy.tscn` |
| BMPT | T-90 hull, about 7 m, same scale as the T-90 | 6 road wheels | Blender mesh (`assets/models/ecc/bmpt.glb`). Turret aft, twin 30 mm, a two-tube launcher each side, flush closed bow lids. The track run is tucked under the hull: idler low under the glacis, sprocket at the rear, top run behind the skirts. The old procedural scene is `bmpt_legacy.tscn` |
| T-14 | hull about 8.7 x 3.5 m, roughly a quarter longer than the T-90 in the top-down photo | 7 road wheels | Blender mesh (`assets/models/ecc/t14.glb`). Three closed crew hatches in a row, low unmanned turret set back, long gun, sensor block, rear slat basket. The old scene is `t14_legacy.tscn` |
| TOS-1A | T-72 hull | 6 road wheels | Cab hatches, 24 tubes as 3 rows of 8 on an elevating box |
| Iskander-M | MZKT-7930, about 13 x 3 m | 8x8, first two axles steer | Forward cab, twin canisters with nose cones, spare wheel |
| Pantsir | MZKT-7930 8x8 | 4 axles, front pair steers | Blender mesh (`assets/models/ecc/pantsir.glb`). Cab forward, mid module, search radar that rises on deploy, twin 30 mm, six-tube packs each side, outriggers. No badge or lettering |
| Mi-8 | fuselage about 18 m, rotor about 21 m | tricycle gear | Blender mesh (`assets/models/ecc/mi8.glb`). Bulbous glazed nose, clamshell rear doors, roof intakes, stub pylons with rocket pods, 5-blade main rotor, 3-blade tail rotor on the left. Drawn larger than the old helicopter, still short of the full 18 m so it can share a pad. The old scene is `mi8_legacy.tscn` |
| Grim Reaper | about 22.7 m at the T-90 scale, 16x16 | 8 axles, evenly spaced, first two steer | Split cabs beside a rounded canister nose, ribbed canister, side lockers and a ladder, outriggers that drop when it deploys |

The Grim Reaper is not a named launcher in the game. The mesh follows the 16-wheel TEL in `docs/m4_7/refs/` (eight axles, split cabs under the canister nose, ribbed tube). Parade stripes, stars and badges are not on any of these models. Reference photos in that folder are not imported. The BMPT, BMP-3, Mi-8, T-14 and Pantsir are Blender meshes. Their shared paint is `#8d9876`, the grey-green that still reads as the parade olive under the match sun. The T-90 and the Grim Reaper stay on `#96A468`. The older Russian vehicles stay the faction grey.

Conscripts are their own bakes (`ecc_con_flora`, `ecc_con_emr`, `ecc_con_olive`, `ecc_con_wood_rpg`, `ecc_con_flora_rpg`, `ecc_con_pkm`): wood AK-47, RPG-7 with a loaded round, wood-furniture PKM, helmets, a field cap, a side cap, vests and pouches. Flora and woodland use the blotch pattern on different cloth, EMR the fine digital pattern, olive a plain colour. The squad icon is the whole group. Spetsnaz and VDV still use the existing special-forces sculpts. The PKM gunner lies down to fire; standing, he carries the gun.

New voices are the existing male Russian banks: Alfa and Spetsnaz use the infiltrator, VDV the rifleman, BMP-3 the BTR, BMPT and T-14 the T-90M, the missile trucks the Msta, the Mi-8 the Ka-52. Shilka keeps the old Zeus lines.

## Tests

`test_runner.tscn -- m47`, plus the M3.3 income / pack-up checks and the M3.5 squad check, updated because the Black Market is no longer a mine and the conscript squad is no longer a grenadier section.
