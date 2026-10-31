# M3.7 (0.3.9, versionCode 23)

Malachi's balance update (2026-10-31). Malachi's Russia/Iran music is not in this build; it
follows as 0.4.0 (branch m36-music).

## 1. Combat Squads spread out
- The six soldiers stand 1.6x wider apart (formation reach 0.34 -> 0.51-0.68 tile) and never
  closer than 0.26 to a mate. Each time a squad stops it scatters: every soldier steps up to 0.14
  off his slot (re-rolled per stop, eased in); while moving they keep the widened formation.
  View only (the sim and replays are unchanged).

## 2. Iran: one power plant
- The Gas Processing Plant (`tpla_cc_plant`) is Iran's only power plant: $800, +10 power, 10 s,
  1000 HP, now without the Defence Workshop prerequisite (was: needs tpla_workshop).
- The Gas Turbine Plant (`tpla_gas_plant`, $600, +8) left the build list; its def stays
  (RETIRED_BUILDINGS, not buildable) so old saves load. The Iran AI builds only the Gas
  Processing Plant when power runs short.

## 3. US vehicles light tan
- US vehicle base paint #a08a68 (flat dark earth) -> #c9b48c (light tan).

## 4. Foxholes removed
- The Dig foxhole button, the "dig" command, the dug-in damage cut (-40 %), hold-position logic,
  the foxhole berm in the view and the strings are gone. Squads keep their +50 % damage
  resistance. An old save's dug-in squad simply stands up.

## 5. Base defences hit harder (+60 %)
| Weapon | Building | Before | After |
|---|---|---|---|
| eu_bunker_cannon | Gun Bunker | 40 | 64 |
| eu_gatling (air) / eu_gatling_gnd | Flak Tower | 14 / 7 | 22 / 11 |
| tpla_tunnel_mg | Tunnel | 15 | 24 |
| tpla_wasp_missile (air) / tpla_wasp_gnd | Wasp Nest | 30 / 14 | 48 / 22 |
| us_sam (air) / us_patriot_gnd | Patriot | 15 / 9 | 24 / 14 |
| us_firebase_gun | Firebase | 90 | 144 |
| ecc_silo_missile | Missile Silo | 240 | 384 |
| ecc_zak30 (air) / ecc_zak30_gnd | AA Site | 14 / 7 | 22 / 11 |
- Anti-air sites' ground guns use a new damage type `aa_ground` (infantry 100 %, light 180 %,
  heavy 160 %, structures 25 %): before they were quad 70/20 %, hmg 65/20 %, anti_tank 120/125 %.
  Against a tank the Flak Tower / AA Site ground guns now do ~12x, the Patriot ~12x and the Wasp
  Nest ~2x their old damage per shot.

## 6. Artillery splash on infantry
- Blasts now reach a unit's edge, not only its centre (a squad beside the shell is caught), and
  artillery blasts fall off to 75 % at the rim on soldiers (was 50 %). Example: a Longreach shell
  on a rifleman at 90 % of the radius: 144 -> ~204 damage; a squad whose centre is just outside
  the radius: 0 -> 140.

## 7. Lighter squads (-33 %)
- US 660 -> 440, Germany 640 -> 430, Iran 560 -> 375, Russia 660 -> 440 HP.

Balance CSVs updated (data/balance/*.csv -> .tres via tools/import_balance.py). New test suite
`m37`; older tests updated (Gas Turbine Plant, silo damage, foxhole).
