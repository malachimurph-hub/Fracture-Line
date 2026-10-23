# M2.9 — Malachi's TPLA / city / music feedback (branch `m29`, version 0.2.9, code 13)

1. **TPLA defence graphics.** The Tunnel Network, Wasp Nest, Demo Trap, Camo Net and Decoy are new procedural models
   (`tools/gfx_m29/tpla_m29.gd`). They have sandbag rings, timber, scrap plating and team markings. The Tunnel's HMG
   now sits on a raised pivot over the sandbag ring, scaled x1.5 so it shows. The Wasp Nest's camo net moved to a rear
   lean-to, so the launcher is no longer hidden.
2. **TPLA roster from the notes list.** Every infantry type is included. The CSV ids were kept so saves and AI keep
   working; the mapping is listed in `autoload/content.gd`.
   - Builders and economy: **Backhoe** (builder) and **Supply Pickup** (gatherer).
   - Infantry: **Rifleman**, **Rocket Man**, **Marksman** (new: SVD, stays hidden until it fires and for 2 s after) and
     **Insurgent** (new: unarmed scout, always stealthed, sight 13).
   - Vehicles: **Technical** (.50 cal pickup), **Striker** (MBT), **BMP-2 Transport** (30 mm, carries 8),
     **BHX-35** (SPAAG), **Koksan Heavy Gun** (170 mm, needs 5 s set-up before it fires) and **Fajr Rocket Launcher**.
   - Air: a new 8 x 8 **TPLA Airfield** (needs the Chop Shop) builds the **Mirage Fighter**, the
     **Fulcrum Interceptor (MiG-29)** and the **Falcon Bomber (F-16)**.
   - Removed: Laborer, Mule, Junkhammer, Sprayer, Earwig and Jackal.
3. **Builders and gatherers are separate.** TPLA starts with 1 Backhoe and 1 Supply Pickup. The Den builds both, and
   each Supply Stash builds Pickups and comes with one free. Backhoes only build and Pickups only haul. The TPLA AI
   keeps 1-2 Backhoes and 2-3 Pickups per stash (12 at most). The x1.2 home stash multiplier stays.
4. **Renames.** The MBT is now **Striker**, modelled on the Iranian Karrar (ERA wedge turret). The Rattler Truck is
   now **Technical**. All UI strings are updated. TPLA voice lines that said an old name were removed (see known issues).
5. **BHX-35.** Replaces the Hailstorm Quad Gun and is based on the UAE **Calidus DAMITA** SPAAG (unveiled at the Dubai
   Airshow, Nov 2025). DAMITA mounts a Rheinmetall Skyranger 35 turret (one 35 mm revolver cannon with AHEAD
   airburst, plus a high-energy laser) on an 8x8 chassis. As you asked, the BHX-35 puts a Skyranger-35-style faceted
   turret on a tank-like **tracked** hull. It has a single long 35 mm barrel with a muzzle ring, a roof search radar,
   an EO sensor and a small counter-drone laser head. Weapons: 35 mm AA (16 dmg, 7 tiles) and the laser.
6. **Two new 256 x 256 urban maps** (`tools/gen_maps_m29.py`), both 4 players and mirror-symmetric:
   - **Crescent City** (desert): a dense downtown fills the ground between the four bases, with a wide central
     boulevard cross.
   - **Riverside Metro** (temperate): a river through the city, with 4 avenue bridges and 2 edge fords.
   - On both maps: glass, office, apartment and slim towers and shop rows; about 1,600 parked cars per map in 7 types; 560-820 buildings per map; street
     lights on every pavement corner; double lights on the boulevard. Plazas hold the supplies and garrisonable blocks.
   - Starting stashes are 85000 / 20000, like M2.8.
   - Towers stand on blocking tiles, so units path around them.
7. **City props in the Map Builder.** Selected props can be rotated in 90° steps with the new Rotate button. A new "City & scenery props" category has the 5 building types, 7 car types,
   single and double street lights, wrecks, trees and rocks. Buildings block their footprint, saved as Cliff. The
   other props are decoration only. Props are saved in the map file (`decor`). Non-square footprints swap when rotated.
8. **Performance.** Props are now drawn as one MultiMesh per kind per 32 x 32-tile chunk, so props off screen are
   frustum-culled. Cars cast no shadows.
9. **Music.** Four new original rock tracks, synthesized by `tools/gen_music_m29.py` (no samples, no third-party
   audio; see `audio/music/MUSIC_SOURCES.md`):
   - Menu: **Breach Point**, a 150 bpm E-minor banger.
   - In-match: **Iron Convoy**, **Dust Devils** and **Last Light Rising** shuffle with the existing **Steel Rain**.
     The shuffle never repeats a track back to back.
10. **TPLA AI uses the Airfield.** On medium (after about 16 min) and hard (after about 13 min), once a Chop Shop is
    running, the TPLA AI builds an Airfield and fills its free slots with the Mirage, Fulcrum and Falcon. Fighters are
    weighted up when enemy aircraft are seen. The jets stay out of the ground waves and fly sorties instead: fighters
    scramble at enemy aircraft over the base or the wave, and bombers hit home threats or the wave's objective. The
    US AI already had this air layer, which now lives in `AIPlayer` and is shared by both. A new `tpla` test checks it.
11. **New TPLA voices.** Every new or renamed unit has its own voice set, with lines that say the unit's new name:
    Striker, Technical, BHX-35, Fajr, Koksan, BMP-2, Rocket Man, Marksman, Insurgent, Backhoe, Supply Pickup, Mirage,
    Fulcrum and Falcon.
    - Made with `tools/gen_voices_m29.py`: Chatterbox Multilingual (MIT) cloning the M2.5 Militia's male prompts with
      the Arabic language token, so it is the same Middle-Eastern-accented style.
    - Attack and under-fire lines are shouted (M2.7 intensity settings) and go through the TPLA radio chain.
    - Checked with Whisper, with retakes (`tools/voice_qa_m29.json`).
    - The old folders (rattler, hailstorm, scrapback, shrike, blight, rocket_cell, laborer) are gone.
12. **Towers go see-through.** Where a tall building stands between the camera and a unit near the screen centre,
    that part of the tower dithers out (`prop.gdshader`, up to 24 units). It stays in the opaque pipeline, so there is
    no sorting cost.
13. **Dark asphalt roads.** On city maps (any map with tall-building props), roads are drawn in dark asphalt. This
    includes Crescent City in the desert.
14. **EU Hearth is now light rocket artillery.** The Hearth Mortar is now the **Hearth Rocket Artillery**.
    - New model: a tracked carrier with an armoured cab (glass, hatch, antenna, exhaust), stowage bins and rails,
      jerrycans, a reload crate, a turntable with elevation ram, and a trainable 6-tube (2 x 3) rocket pod with
      straps and red rocket noses.
    - New weapon `eu_hearth_rockets` (replaces `eu_mortar`): a 6-rocket salvo, 29 dmg per rocket, 1.0 splash,
      0.3 s between rockets and a 12 s reload. It is drawn as rockets with trails.
    - Same range (10 tiles, minimum 2.5), same cost and HP, and about the same damage per second
      (≈12.9, the mortar's was ≈12.9).
15. **Dead structures removed.** I checked every faction's build list. These were removed because they did
    nothing in the sim, or only showed a [STUB]:
    - **EU Grid Pylon**: it only extended the Grid shield radius. The HQ and Reactors still project the Grid.
    - **EU Concord Pylon** (stub superweapon, no strike implemented).
    - **TPLA Decoy Yard**: its "decoy" tag was not used by any system, so it was just a 300 HP block.
    - **TPLA Rust Bloom Silo** (stub superweapon).
    - The data, views, strings, build orders, AI (EU pylon role, TPLA decoy build) and tests were updated. The lobby's
      stub "Superweapons" toggle is hidden; the option is kept in the config for old saves.
    - No US structure was removed: each one powers, produces, supplies, defends or unlocks tech. Built-in maps had
      no pre-placed copies of the removed structures.
16. **Ground graphics pass** (`terrain.gdshader`, `tools/gen_terrain_macro_m29.py`):
    - The macro variation texture was not seamless (edge difference 59 vs 1 inside). That caused the straight lines
      every 64 m. It is regenerated as periodic, smooth noise and now sampled at two unrelated scales and rotations.
    - Every ground layer, including city asphalt, blends in a rotated and rescaled second copy using low-frequency
      noise, which breaks up repeats. A second texture fetch happens only where that blend is mid-way.
    - The micro detail layer is about half as strong and still fades out with distance. Albedo and NRAO use a
      +0.4 mip bias, and the detail texture now uses anisotropic filtering. Together these remove grain and shimmer.
    - Blends between ground types are smoother: the splat map gets two blur passes and its edges get a
      larger-scale noise wobble.
    - The layer textures were checked and are already seamless; their imports keep mipmaps and VRAM compression.

