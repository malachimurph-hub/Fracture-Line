# Fracture Line: Global Conflict — M3.3 (versionName 0.3.5, versionCode 19)

M3.3 is Malachi's 48-item list in five phases, plus the unreleased M3.2.2 changes (new title,
shield truck removed, aircraft spreading out). Package, signing, `user://` folder and save format
are unchanged, so it installs over M3.2.1 and old saves and replays still load.

## Build
(filled in by the release-info commit)

## M3.2.2 changes included
- **Retitled "Fracture Line: Global Conflict"**: menu badge, boot splash, credits, window title.
  The launcher label is **Fracture Line**.
- Germany's shield truck is removed from build lists, the roster, the Map Builder and the AI. It stays
  hidden so old saves and replays work.
- Aircraft spread out: formation slots on group moves, staggered attack spots, gentle separation.

## Phase 1: quick wins
- Balance and economy:
  - Self-propelled guns now have fixed turrets.
  - Tank rounds splash, and heavy blasts hurt infantry.
  - Light aircraft hit harder.
  - Start cash is at most $50k and funds cap at $9,999,999.
  - New income structures: Data Center, Oil Derrick, Automotive Plant, Minerals Mining.
  - US Nuclear Power gives 30% more.
  - Germany renames: Infanterie, Panzerfaust. The heavy tank is retired.
- Generals are hidden (no General button, tray or AI powers). Old replays that bought powers still play.
- Sell a finished structure for 70% back (not the HQ).
- Dozers find their way to build sites more reliably.
- Construction clears trees, rocks and grass under the footprint.
- 8 manual save slots with date and time, a Load screen, and Continue/Load on the main menu.
- HUD: money and a 40-segment power bar at the top centre, an 8-slot queue, text-only alerts, and a pause menu
  that fits the screen. The default zoom is 20% further out.
- Iran Technical repainted white. US drones rebuilt as quadcopters with lamps.
- Fix: a loaded game could fall out of step with the unsaved one (a weapon timer is now saved).

## Phase 2: art and models
- New models:
  - Data Center
  - Nuclear Power Plant with cooling towers
  - Iran Gas Turbine Plant and Combined-Cycle Gas Plant
  - Oil Derrick with pumpjack
  - Automotive Plant
  - bucket-wheel excavator (Minerals Mining)
  - Missile Silo with opening doors (replaces the Kornet Nest)
- Iran power economy. The Russian engineer vehicle gets a single anti-tank rocket.
- Bundeswehr cross on German structures and vehicles. Civilian buildings held by a team fly its flag.
- Builders animate at work: dozer blade, backhoe, crane boom.
- Barricade crews stand behind the wall and lean over it. Infantry are at true vehicle scale.
- Trees and rocks rebuilt. Iran structures look clean and modern. Helicopters and jets have dust trails again.

## Phase 3: environment
- Hills: vehicles slow on slopes, and structures sit on plinths.
- New ground types: earth, gravel, pavers, lush grass.
- 8-player lobby and new 2-, 4-, 6- and 8-player maps.
- Night maps: Riverside Metro by Night and Varno Crossing by Night, with street lamps, lit windows and
  headlights.
- Civilian buildings take blast damage and can be demolished, leaving rubble. Parked cars are wrecked by
  blasts or crushed by tanks.
- Minerals Mining can pack up, drive and set up elsewhere.

## Phase 4: icons, voices, music
- Icons for all 131 units and structures, rendered from our own models (see `docs/ICON_LICENSES.md`).
- German engineering "reporting" lines re-voiced naturally (male voice).
- New original Russian theme, "Steppe March" (choir, balalaika, bayan, brass, march drums).
- Fixes:
  - Headlights point forwards on every vehicle.
  - The power-plant exhaust stacks and other new parts no longer float.

## Phase 5: World Builder
- The map editor works on the real 3D map, with the game's terrain, lighting and models.
- Camera: orbit with two fingers (pan, pinch, twist), plus Tilt, Top, Fit and Grid buttons.
- Tabs:
  - **Ground** paints terrain live.
  - **Height** has Raise, Lower, Smooth, Flatten and Level brushes in three strengths.
  - **Objects** places starts, supplies, neutral buildings, props and units, with icons.
  - **Select** moves, rotates and deletes objects and sets their owner.
- Undo and redo cover everything. The 2D map stays as an overview.
- Sculpted heights are saved with the map and play in skirmish, saves and replays.
- Not included, compared with Zero Hour's editor:
  - scripts, waypoints, teams or trigger areas
  - the hand-placed scenery of built-in maps, when they are copied

## Tests
The suite has 19 groups, now including map_builder and wb (World Builder). The M3.2.1 board test
has 72 checks, and the M2.6 UI test also runs.
