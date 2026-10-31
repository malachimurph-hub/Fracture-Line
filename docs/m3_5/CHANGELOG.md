# M3.5 (0.3.7, versionCode 21)

Malachi's M3.5 list. Malachi's new Russia and Iran music (branch m35-music) comes in a separate small follow-up update.

## Menu and startup (items 1–6)
- The live menu battle is gone (`ui/menu_battle.gd` and its wiring). The menu now uses Malachi's dusk photo as a cover-fit backdrop. Buttons sit in a left column of translucent dark plates, and the small emblem is top right.
- Startup: menu first frame went from 1.1–1.5 s to 0.43–0.49 s headless, and from 1.6–1.9 s to 0.75–0.78 s on xvfb/compat (wall ~2 s → ~1 s). Before, the live battle was ready at ~5 s. The cause was the MenuBattle script compile (~850 ms) plus the battle start.
- Touch scrolling (`TouchScroll`) is used in the lobby, settings, credits and Map Builder. It has a 10 dp deadzone, buttons pass drags through, and flicks keep scrolling. The lobby map picker is now a grid. The lobby fits every aspect ratio: the slot table scrolls sideways and the map preview keeps its aspect.
- Japan, Poland, China and the UK are on the roster, locked as "Coming soon" with darkened flags.
- Music plays in a fresh random order every match for all factions (view-only RNG, so the sim stays deterministic).

## Infantry (items 7–11)
- The US Drone Operator flies scout drones only. Russia gets a Drone Operator (barracks, needs the Ministry) that flies explosive drones only, in grey paint.
- Machine guns: US M240B, Germany MG3, Iran PKM, Russia PKM. Machine gunners drop prone to fire (prone_down / fire_prone / prone_up clips) and get up 2.5 s after the last burst or when ordered to move.
- AT and rocket soldiers kneel to fire.
- Each faction has a **Combat Squad** (`us_squad`, `eu_squad`, `tpla_squad`, `ecc_squad`): 3 riflemen, MG, AT and a grenadier as one unit.
  - HP is pooled, soldiers fall one by one as it drops, and each soldier's weapon stops firing when he dies. The last man standing is a rifleman.
  - Squads take 67 % damage (+50 % resistance).
  - **Dig foxhole** command: a ~4 s dig, then a further 40 % less damage. The squad holds position (no chasing) until given an order.
  - One squad per barricade or sandbags. A squad takes 3 transport seats.
  - Specials stay single (sniper, JTAC, breacher, engineers, Sturmtrupp, marksman, insurgent, infiltrator, saboteur, drone operators).
  - The old single rifle / MG / AT infantry are no longer trained. Their defs are kept so old saves load.
  - The AI trains squads. Squads use the riflemen's voice sets.
- Grenadier placeholders (each fires an underbarrel GL with 28 dmg and an 8 m splash):
  - US: M16 + M203 (`us_grenadier` model)
  - Germany: G36-style rifle + AG36 (`eu_rifleman` model)
  - Iran: AK + GP-25 (`tpla_grenadier`)
  - Russia: AK-74M + GP-25 (`ecc_grenadier`)

## Vehicles and world (items 12–17)
- All six artillery pieces (Longreach, Thunderhead, Hearth, Blight, Shrike, Msta) raise the gun or launcher while aiming and lower it afterwards. This is view only.
- Vehicle base paint is set per faction: US FDE tan, Germany dark pine green, Iran coyote brown, Russia grey. Team-colour accents are kept, and the paint covers vehicles, aircraft and drones.
- Supply stashes are now **Crude Oil Reserves**: a pad with two storage tanks, a catwalk and pallets of drums. Harvest trucks show oil drums in the bed (up to 6), growing with their load and gone after unloading "for export". The HUD, tooltips and Map Builder wording are updated, and the economy is unchanged.
- Russia and Iran power-station models and names are swapped. Russia's plant is now the 4x4 Combined-Cycle Gas Plant, and Iran's late plant is the 3x3 Gas Processing Plant. The stats followed the models: Russia's plant now costs $1,600 and gives +19 power (20 s build, 1,500 HP), and Iran's late plant costs $800 and gives +10 power (10 s build, 1,000 HP). Prerequisites stay per faction (Iran's still needs the Defence Workshop).
- Germany's Heavy Factory is removed. The Motor Pool now builds every German vehicle (the def is kept for saves).
- Non-lethal vehicles removed from production: the Fuchs EW jammer (`eu_spectre`) and the Fennek recon (`eu_sentinel`). Builders, harvesters and transports are kept.

## Tests
- `tests/m35_test.gd` covers:
  - menu layout, touch scroll, lobby layout, roster lock and music shuffle
  - squad composition, carriers, member loss vs HP, damage resistance, foxhole (dig, hold, cancel, save/load), one squad per barricade and transport seats
  - squad view: six soldiers, MG prone and up, AT kneel, soldier loss, foxhole mesh
  - drone operator kinds, artillery elevation for every artillery unit, factory merge, removal of non-lethal vehicles, power swap and AI weights
  - paint, the oil reserve model and truck drums
- Older tests were updated for the barricade capacity, US scout-only drones, the power swap, the TPLA voice manifest and the weapon FX classes. The board test now checks one squad per barricade.

## Results (Oct 30, 2026)
- The headless suite passes all 23 tests: content, placement, audio, corners, resume, zh, tpla, roster, m25, viewcost, airspread, replay, map_builder, wb, m33, m34, m35, turret, saveload, stash and m24.
- The board test passes (72 checks, 0 failed).
- The m26 UI test passes (2340x1080 at 450 dpi, mobile renderer).

## Questions for Malachi
- Should a squad take 3 seats in a transport?
- The Fennek was the only detector in the game. Should a detector go somewhere else?
- Power swap: answered, the stats swap too (done).
- Squad icons are copied from the old units' icons for now. Should they be re-rendered?
