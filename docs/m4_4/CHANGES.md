# 0.4.4 — US tech tree

Not a version bump. `project.godot` and the export presets stay at 0.4.3 / versionCode 27 until a ship is requested. No APK or AAB.

Germany, Iran and Russia are unchanged.

## Chain

Headquarters → Sub Station → Barracks → Motor Pool → Pentagon → Data Center → DARPA ($5000) and SOCOM ($4500).

DARPA and SOCOM are buildings. Their command menus are the research (DARPA) and the special-forces units (SOCOM). They are not loose categories.

| Step | Unlocks |
|---|---|
| Headquarters | Dozer. Satellite is the minimap, live from the start, not a unit. |
| Sub Station | Early power (+12, $1000, 3×3). Replaces the old opening power plant. |
| Barracks | Combat Squad, MK 23 Grenade Launcher Team. Also the Supply Depot and the M777A2. |
| Supply Depot | M1083A1P2 Supply Truck |
| Motor Pool | JLTV, M3 Bradley, MAAS. M1A3 and M109A7 are built here once the Pentagon exists. |
| Pentagon | Was the Strategic Center. Unlocks the Airfield, LPWS, M1A3 and M109A7. |
| Airfield | AH-6 Little Bird, F-16 Fighting Falcon, UH-60 Black Hawk. Later aircraft stay here. |
| Data Center | Still pays $500 a minute. Unlocks DARPA and SOCOM. |
| DARPA | Advanced Aero, Robotics, Nuclear Research, ZEUS Defense Systems. |
| SOCOM | Scout Sniper, Green Beret, SEAL, JTAC Observer. |

### DARPA research

- **Advanced Aero** — F-35 (light attack bomber, 2 slots), B-1 Lancer (heavy bomber, 4 slots, replaces Thunderlance), AH-64 (attack helicopter, replaces Harrier), YF-22 (stealth fighter, stronger and costlier than the F-16, 2 slots).
- **Robotics** — Robotics Plant ($3800). The plant builds the Ripsaw and unlocks the Reaper (Airfield) and the Drone Operator (Barracks).
- **Nuclear Research** — Nuclear Power Plant: 4×4, $5200, +64 power. The moment the research finishes, every Sub Station stops producing power and no new one can be started.
- **ZEUS Defense Systems** — Zeus Launch Station ($8500, −11 power) and Zeus Pylon ($2000, −3 power, 14-tile ring).

New consumers draw power in step with cost: Robotics −5, SOCOM −6, DARPA −7, Zeus Pylon −3, Zeus Launch Station −11.

### Units

- **AH-6 Little Bird** — helicopter, faster and lower signature than the other US helicopters, much less health.
- **F-16** — cheaper, lighter fighter than the YF-22.
- **F-35** — light attack bomber.
- **YF-22** — stealth fighter. Ground troops see it only at very short range. Aircraft, detectors and base defences see it normally.
- **B-1 Lancer** — heavy bomber.
- **AH-64** — attack helicopter.
- **Reaper** — built at the Airfield. Flies like a helicopter on the way in, then holds a wide slow circle inside its weapon range. Same strike damage as the F-35. Only base defences can detect or shoot it.
- **Drone Operator** — same scout-drone launch as before. Trained at the Barracks after the Robotics Plant is up.
- **Ripsaw** — unmanned tank from the Robotics Plant. Smaller and quicker than the M1A3. Main gun is 85% of the M1A3's (94 vs 110 cannon damage, same rate). Coaxial .50 cal. No crew and no voice lines.
- **MK 23 team** — two soldiers, one grenade launcher (the assistant has a sidearm). Best against infantry, decent against light armour. Must set up (5 s) before firing.
- **Green Beret** — replaces the Breacher. Always stealthed until detected up close. Captures buildings. Strong against infantry.
- **SEAL** — stealthed, high health. An attack order on an enemy vehicle or building walks them in and plants a demolition charge (3 s, then 20 s before the next).
- **Scout Sniper** and **JTAC Observer** — same roles, trained at SOCOM.

### ZEUS

The pylon draws its ring for its owner. The launch station, while powered, fires six missiles 0.4 s apart at enemies whose centre is inside any friendly pylon. Missiles rotate through the targets in the ring, so a group is split up. Then it recharges for 30 s. Each missile is a demolition warhead (150 damage, splash).

### Retired (defs kept for old saves and replays)

Harrier Gunship, Wraith Fighter, Thunderlance Bomber, Breacher, and the old Drone Warfare research. Bomb Drone was never a US build item. The operator's scout drone is still the thing it launches; it is not a buildable aircraft.

## Tests

`test_runner.tscn -- m44`. The M3.3 nuclear-plant numbers and the Drone Operator research check were updated for this tree.

Models: `tools/m44/models_m44.gd`. Icons re-rendered from those models.

## Open points

- The First Battle on-screen step now says Sub Station. The recorded announcer line for that step still says the old power-plant name.
- New soldiers reuse existing US infantry meshes (breacher / rifleman / grenadier). They are not new sculpts.
- New units other than the Ripsaw have no recorded voice lines yet. The Ripsaw is silent on purpose.
- The Reaper's strike range is longer than the F-35's (9 tiles vs 3.5) so the wide circle stays inside the weapon. The damage and splash match the F-35.
- Sub Stations drop to zero power as soon as Nuclear Research completes, before the plant itself is built. The US AI switches its power building at that moment.
