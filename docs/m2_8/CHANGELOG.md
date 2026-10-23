# M2.8 — Malachi's feedback fixes (branch `m28-fixes`)

1. **Large maps** — the four built-in skirmish maps are now 256 x 256 (were 128). Run
   `tools/upscale_maps_m28.py` (re-runnable from the M2.7 maps at git `14da8e7`): the terrain and biome
   grids use EPX/Scale2x upscaling, so diagonals stay diagonal instead of turning into 2 x 2 steps. Spawns,
   neutrals and mid-map supplies move to x2 positions and stay mirror-exact. The home stashes keep their
   distance to the HQ. Each quadrant gets one extra 8000 cache, and props are 4x denser with sparse clutter.
   Camera limits, minimap, fog, pathing and the menu battle already read the map size.
2. **Spawn stashes last ~17 min** — the home seam is now 85000 and the home cache 20000 (were 30000 / 6000).
   TPLA spawns get x1.2 through the new `home_stash_pct` faction field in `autoload/content.gd`, because 8 Laborers drain
   faster than 2 trucks or harvesters. Measured with the new headless `stash` test (AI vs AI medium 1v1, Varno Crossing):
   US 16.9 / 17.8 min, EU 16.6 / 17.2 min, TPLA 15.7 / 16.2 min, median 16.9 min.
3. **Water** — one new `water.gdshader`. Shorelines are smooth and curved, cut from a blurred wet field
   (4 px per tile) instead of per-tile quads. Bank heights are relaxed. The shader adds three scrolling layers of
   wave normals, depth colour, animated shore foam, a fresnel sky reflection and sun glints. The terrain gets a damp band
   along the waterline. Cost per pixel: 2 texture reads and about 6 value-noise taps.
4. **Faction rename** — "Western Alliance" is now **Eastern Communist Coalition (ECC)** everywhere. The id `wa` is now `ecc`
   (skirmish slot, `FACTION_ECC` string, voice manifest, placeholder model, docs). No units were added.
5. **Single-soldier infantry** — Grenadier, Lancer, Militia and Rocket Cell are now one soldier each (the view formation
   is a single soldier). The Javelin team stays at 2. Balance per soldier: Grenadier 250 / 180 HP, Lancer 300 / 130 HP (missile 60 dmg),
   Militia 140 HP, Rocket Cell 250 / 120 HP. UI names drop "Squad".
6. **Aircraft crashes** — a destroyed aircraft no longer vanishes. Jets roll and drop their nose; helicopters spin.
   Both trail smoke and fire, then hit the ground with a big explosion, dust and debris, leaving a burnt, crumpled
   wreck that burns for about 9 s. This is view only (`WorldView._update_crashes`), so the sim stays deterministic.
7. **Airfields** — the US Airfield and the EU Airstrip are now 8 x 8 (were 4 x 4). The new model has three numbered
   hangar bays under arched shelters, painted pads, lead-in lines, stop bars, a runway strip with lights, and a tower
   on the roof. `AirSys.parking_pos` now uses bays: a fighter takes 1 bay (2 slots) and a bomber takes 2 adjacent
   bays (4 slots), so the 6 slots fit 1 bomber + 1 fighter or 3 fighters. Bombers always get the first bays, and a
   new bomber tows parked fighters to the free bay. Parking accounts for all 4 rotations. The bomber model is scaled
   x1.5 and the fighter x1.1 so they fit their bays.
8. **Infantry detail** — weapons are built procedurally in metres from reusable parts (`tools/gfx_m28/inf_kit.gd`):
   M16 (Marine rifleman), M4 + PEQ + red dot (JTAC), Javelin CLU + tube, a scoped bolt-action sniper with bipod,
   AK with wood furniture and curved mag (Militia), RPG-7 (Rocket Cell), an EU rifle with underslung GL (Grenadier),
   and an EU NLAW-style launcher (Lancer). An SVD is in the kit but no unit uses it yet. Faction gear: plate
   carriers with mag pouches, chest rigs, packs, a radio pack with whip antenna and team panel, a headset, a ghillie veil,
   shemagh wraps, a spare tube, rocket packs and a helmet band with NVG mount. The parts are rigidly skinned to the
   hand, torso and head bones in `tools/bake_infantry.gd` and add 230-380 tris per soldier (not decimated, about
   1.4-1.8k total). Existing LODs are kept.
9. **Turrets** — fixed units with a long-range anti-air weapon and a short ground gun (US Picket: Stinger 8 tiles,
   M2 5 tiles). They used to stop at missile range from a ground target, turn the turret and never fire.
   `OrderSys.max_range` now only counts weapons that can hit the target's layer. Defence turrets now traverse
   smoothly onto moving targets and swing back to rest when idle, instead of snapping or freezing. New headless
   `turret` test with 124 cases: every armed ground unit (attack order / idle auto-acquire / circling target /
   target beyond ground range) and every armed structure (idle / circling) must hit. Before the fix it failed on
   `us_picket/far`.

Tests: `tools/run_m28_suite.sh` runs the 13 headless tests plus `turret` and `stash`. Screenshots are in
`builds/m2_8_fixes/` (one per item; `tests/m28_shots.tscn`).
