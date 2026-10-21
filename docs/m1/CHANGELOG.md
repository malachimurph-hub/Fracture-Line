# FRACTURE LINE: Changelog

## 0.1.2-m1.2 (2026-10-21): visual pass, Zero Hour build rules, audio v1, voice pipeline
APK: `FractureLine-M1.2.apk`. It is 19,841,810 bytes (about 18.9 MiB, under the 24 MB limit), versionCode 3, and installs over 0.1.1-m1. It is arm64-v8a only, debug-signed, and apksigner verifies it (v2 and v3 signatures). Textures ship as ETC2 for this phone.

### Gameplay
- **Build anywhere, Zero Hour style.** The build radius around the HQ and Grid is gone. A Crawler can build on any spot that is:
  - valid ground: not water, cliffs or rock
  - free: no overlap, and not too close to a supply seam
  - clear of enemy units
  - **explored:** black shroud shows "Unexplored ground — scout it first"
  - **reachable** by one of your Crawlers: otherwise "No Crawler can drive there"
- **AI uses build-anywhere.** It builds forward bunkers near its remote refineries and expands toward oil and supply.
- **Power is global, as in ZH.** Every finished structure counts toward power wherever it stands. Pylons and the Grid radius now only decide where EU Grid shields apply.

### Map: Varno Crossing v2 (ZH-style)
- A river crossing with 3 concrete bridges and 2 fords.
- A central riverside town with 20 garrisonable flat-roof buildings, a gas station and shacks.
- Asphalt streets with lane markings, 8 capturable oil derricks and central supply piles.
- Cliffs, rocks, palms, scrub, burned-out cars and power poles.
- The lobby map preview now shows the real terrain.

### Visuals
- **Terrain:** real ground textures (CC0, ambientCG) splat-blended: sand, dirt, dry scrub, green, asphalt, rock, riverbed and concrete. Terrain has height, with cliffs that keep pathing intact.
- **Water:** animated, with bank foam.
- **Lighting (Zero Hour look):** a warm, strong sun with crisp 2-split shadows, cool ambient light, light haze and a slightly saturated filmic grade.
- **New EU models:** every unit and building, in ZH proportions.
  - **Vehicles:** road wheels, sloped armour, turrets and team-colour stripes.
  - **Base:** concrete pads, sandbags, chain-link fences, corrugated-metal halls (CC0 texture), smokestacks, a helipad and flags.
- **New civilian and supply models:** the civilian building, the oil derrick with pumpjack, and the supply pile.
- **Fewer draw calls:** each model is now 1–5 draw calls instead of one per part.
- **Effects:**
  - Weapons: muzzle flashes, explosions with fire, smoke, dust and debris, flak bursts and missile trails.
  - Ground marks: scorch marks and craters.
  - Damaged and destroyed buildings: smoking or burning buildings, and building collapse with rubble and a smoke column.
  - Dust: from moving vehicles and from construction sites.

### Audio (new; M1 had none)
- **Settings:** volume sliders for Master, Music, Effects, Voices and Interface sounds.
- **Sound effects (original, synthesized):** weapons, explosions, building collapse, construction, UI sounds, and desert wind ambience.
- **Music (original):** "Dust Over Varno" (menu) and "Steel Rain" (battle).
- **Unit voices:** select, move, attack, under fire, created, veteran, plus build, harvest and garrison.
- **Announcer:** an EVA-style battle control voice. All wording is original.

### Voice pipeline (you record the voices)
- **Script and checklist:** `VOICE_SCRIPT.md` and `VOICE_CHECKLIST.csv` list 154 lines, with suggested wordings, delivery notes and phone recording tips.
- **Drop-in folders:** `audio/voice/<faction>/<unit>/<event>_<n>.ogg`; the game picks up new files automatically.
- **Import tool:** `tools/import_voice.py` trims silence, applies the radio filter (unit lines), normalizes to about −16 LUFS and converts to Ogg.
- **Placeholders:** until a line is recorded, a robotic TTS **placeholder** plays. Settings shows "Voice lines recorded: X of Y".

### Tests added
- **Placement test:** checks the build-anywhere rules (5 checks).
- **Audio test:** checks buses, that every sound loads, that every voice line resolves, and the no-repeat, priority and cooldown rules (24 checks).
- **Perf:** the perf run now reports draw calls.

## 0.1.1-m1 (2026-10-21), hotfix: blank screen after tapping Skirmish on Android
APK: `FractureLine-M1.1.apk` (versionCode 2, installs over 0.1.0-m1).

- **Fixed:** tapping **Skirmish** showed an empty screen on the phone. The lobby script called `Image.create()`. That is a deprecated alias of `Image.create_empty()`, and the size-optimized engine used for the APK is built without deprecated APIs (`deprecated=no`). The lobby script therefore failed to compile on the device and the screen came up empty. The HUD minimap and the terrain fog had the same problem, and would have broken the match next. All of them now use `Image.create_empty()`.
- **New:** scene changes are validated. If a screen fails to load or its scripts fail to compile, the game shows a **"Something went wrong"** panel with the error text instead of a blank screen. The panel has **Copy error log** (clipboard) and **Main menu** buttons, and the log is also saved to `user://last_error.txt`.
- **New:** engine and script errors are captured in-game for that panel. Godot file logging is enabled, writing to `user://logs/godot.log`.
- **New test:** a rendered UI flow test runs in the *exported* build on the same stripped engine profile as the APK: main menu, tap Skirmish, lobby, tap Start battle, the match runs. It also checks that every screen's scripts compile on that engine.
- Version 0.1.1-m1.

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
