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
7. **City props in the Map Builder.** A new "City & scenery props" category has the 5 building types, 7 car types,
   single and double street lights, wrecks, trees and rocks. Buildings block their footprint, saved as Cliff. The
   other props are decoration only. Props are saved in the map file (`decor`).
8. **Performance.** Props are now drawn as one MultiMesh per kind per 32 x 32-tile chunk, so props off screen are
   frustum-culled. Cars cast no shadows.
9. **Music.** Four new original rock tracks, synthesized by `tools/gen_music_m29.py` (no samples, no third-party
   audio; see `audio/music/MUSIC_SOURCES.md`):
   - Menu: **Breach Point**, a 150 bpm E-minor banger.
   - In-match: **Iron Convoy**, **Dust Devils** and **Last Light Rising** shuffle with the existing **Steel Rain**.
     The shuffle never repeats a track back to back.
