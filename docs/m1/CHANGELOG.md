# FRACTURE LINE: Changelog

## 0.1.0-m1 (2026-10-21), Milestone 1: playable skirmish vertical slice

This is the first playable build. It is skirmish-only, as decided in GDD v0.5. There is no campaign and no tutorial.

### Game flow
- Main Menu > Skirmish setup (lobby) > Match > Results > back to Setup.
- **Continue** resumes a suspended match. The game autosaves every 2 minutes and when it is paused, backgrounded or closed.
- Settings screen (UI scale, render scale, FPS cap, gesture timings, ghost offset, camera inertia, edge pan, haptics, health bars, perf overlay) and a Credits/About screen.

### Lobby (Generals-style)
- Up to 4 players: 1 human plus up to 3 AI, or 0 humans for observer/AI-only play.
- Each slot can be Open, Closed or AI (Easy / Medium / Hard). Each slot also has a team (1-4), a color and a start position (or random).
- Every slot is EU Alliance. The other factions are greyed out as "coming later".
- Starting cash: $5k, $10k (default), $20k or $50k. Fog of war and shroud are on by default. The superweapons toggle is a [STUB].
- Setup is validated. Start is blocked with a clear message when there are fewer than 2 players, everyone is on one team, colors are duplicated, starts are duplicated, or no map is selected.
- Map: "Varno Crossing", 4 players, with 4 mirrored spawns, a river with crossings, supply fields, neutral pumps and civilian garrison blocks.

### Zero Hour-style mechanics
- **Construction:** the Crawler (builder) walks to the site and builds it. You can resume an unfinished site.
- **Economy:** supply fields worked by Hauler trucks that dock at a Supply Hub, plus capturable neutral Veridite pumps that pay a trickle of income (oil-derrick style).
- **Power:** reactors and the HQ supply power. Running low on power slows production and turns off powered defenses.
- **Production:** queues of up to 9 at each production building, with rally points and a repeat/loop toggle.
- **General's rank:** rank and points earned from combat. A General's Powers tray holds Recon Sweep, Emergency Logistics, Shield Overcharge and Grid Blackout [STUB].
- **Veterancy:** Veteran, Elite and Heroic chevrons, with damage and HP bonuses. Heroic units heal themselves.
- **Field repair:** units that have not been hit for 10 s heal 2% HP per second within 10 tiles of their own HQ or a production building. This was added during the self-playtest (see below).
- **Garrisons:** infantry can garrison civilian buildings and bunkers. Garrisoned buildings show a count.
- **Fog of war:** shroud plus fog with memory ghosts. Allies share vision.
- **Teams:** allies cannot damage each other. A team wins when every opposing player is eliminated.

### Roster (EU Alliance, original names)
- **Units:**
  - Crawler (builder)
  - Hauler (supply truck)
  - Grenadier squad (infantry)
  - Lancer squad (anti-tank infantry)
  - Wolfhound IFV (fast scout and combat car; carrying infantry is [STUB])
  - Leopold battle tank
  - Aegis shield carrier
  - Flakwerk AA (there are no aircraft in M1 yet)
- **Buildings:**
  - Command HQ
  - Fusion Reactor
  - Grid Pylon
  - Supply Hub
  - Barracks
  - Motor Pool
  - Heavy Factory
  - Gun Bunker

### Skirmish AI
- Three difficulties and data-driven personalities.
- The AI builds its base from an opening, harvests, expands to new supply fields and captures pumps.
- It scouts with a dedicated unit and attacks in growing waves. It reinforces waves and retreats damaged units (Medium and Hard). A whole wave withdraws when it is outmatched.
- It defends in proportion to the threat, and it grows a second barracks or factory and more bunkers in the mid game.
- It uses General's powers.
- Allied AIs share a target through a team board and converge on the same enemy.

### Controls and UI (S24 Ultra target)
- Touch controls:
  - tap to select or command, double-tap to select a type
  - hold then drag to box-select, hold then release to attack-move
  - two-finger tap to deselect, pinch to zoom (3 snap levels), drag to pan with inertia
  - placement ghost with Rotate / Cancel / Confirm (lifting your finger never places a building)
  - control groups 1-5, minimap jump and scrub, alerts with jump and Back
  - S Pen works as touch
- Zero Hour-style bottom bar with minimap, selection panel, a 2x5 command grid, and money, power and General's info.
- Tap targets are at least 48 dp, scaled by DPI. The UI respects safe areas and the camera cutout.
- Mouse and keyboard on web and desktop: LMB select or box, RMB command or cancel, MMB pan, wheel zoom, WASD and arrow keys, Ctrl+1-5 to set groups, A / S / G, R, B, P, Space, Esc.

### Tech
- Godot 4.7.2-stable with GDScript.
- Deterministic 20 Hz fixed-point simulation (PCG32 RNG) with a state hash. Replays and save/load are bit-exact.
- CSV balance data compiled into .tres resources.
- Android: Mobile renderer (Vulkan), render scale 0.75, arm64-v8a, ETC2/ASTC textures, and a size-optimized custom export template.
- Web: Compatibility renderer (WebGL 2), single-threaded.

### Self-playtest fixes (the worst issues found, fixed and re-verified)
1. **The exported game was inert or crashed.** The Godot export (a) left out the map tile files, so the release build crashed on map load, and (b) converted text resources to binary, which emptied every PackedStringArray in the data (unit tags, production lists, prerequisites and the AI opening). With those emptied, the AI did nothing and production failed. The editor build was unaffected; the bug was found by running the *exported* build headless. Fixed with an explicit include filter and by keeping text resources. Content validation now rejects this kind of data loss at startup.
2. **4-player AI games never ended (40-minute draws).** Four causes:
   - Periodic AI checks never fired for 3 of the 4 AIs because of staggered thinking.
   - Waves got stuck.
   - Every raid on an outlying building pulled the whole army home.
   - Retreated, damaged units waited forever with no way to heal.

   Fixed with:
   - period timers
   - a stuck-wave watchdog
   - weakest-enemy targeting shared with allies
   - attacking at the unit cap
   - defense in proportion to the threat
   - field repair, so retreated units heal and rejoin
   - a late-game wave ramp
3. **Web build glyphs.** ★, ≡, ▶, ✓ and ∞ showed as empty boxes on the web build (the default font has no fallback there). Replaced with ASCII labels.
4. **HUD alerts.** Repeated alerts stacked, and expired alert buttons stayed in the touch-blocker list. Alerts now dedupe, and the list is cleaned up.
