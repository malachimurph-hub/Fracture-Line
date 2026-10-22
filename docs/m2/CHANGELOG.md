# FRACTURE LINE: Changelog

## 0.2.0-m2 (versionCode 4), 2026-10-21

APK: `FractureLine-M2.apk`. It is arm64-v8a, 38,302,465 bytes (36.5 MiB), signed with the debug key. `apksigner verify` passes (v2 and v3 schemes). Details are in `verification/apksigner.txt`.

### New faction: TPLA (GLA-like, original)
- **Buildings (10):** Den (HQ), Supply Stash, Militia Camp, Chop Shop, Tunnel Network, Workshop, Night Bazaar, Demo Trap, Camo Net, and Hole (rebuilds a destroyed building).
- **Units (9):** Laborer, Militia, Rocket Cell, Rattler Truck, Scrapback, Shrike, Hailstorm, Blight, and Mule. The Mule's disguise is [STUB].
- **Powers (4):** Ambush, Blight Shells, Scrap Rain and Uprising.
- **Mechanics:**
  - TPLA needs no power.
  - Laborers harvest and build.
  - Tunnel Network: units share one network, enter, heal inside, evacuate at any tunnel, and die if the last tunnel falls.
  - Salvage crates raise units up to tier 3; any extra crates become cash.
  - Holes rebuild destroyed buildings.
  - Demo Traps are stealthed and trigger on contact.
  - The Camo Net hides buildings under it.
  - Stealth is part of fog of war.
  - Rust zones.
- **AI (Easy, Medium and Hard):** TPLA has its own AI. It handles Laborers, tunnels, raids, salvage, traps and powers. Waves regroup at a forward rally point before attacking.
- **Lobby:** each slot has a faction picker (EU Alliance or TPLA). There is also a per-faction announcer.
- The faction has its own views, effects and sound effects: crates, tier markers, holes, stealth ghosting, rust clouds and blasts.

### Voices: AI-generated
- **Every EU and TPLA voice line is AI-generated.** They were made offline with Kokoro-82M (Apache-2.0) through kokoro-onnx (MIT).
- Voices are distinct per faction and per unit. No stereotyped ethnic accents are used.
- No human voice actors were recorded. Recorded files dropped into the voice folders still replace the AI lines (see VOICE_SCRIPT.md and VOICE_CHECKLIST.csv).

### Textures and materials
- **Terrain:** CC0 PBR terrain from ambientCG, at 1K, with colour, normal, roughness and AO maps.
  - The 7 layers are packed into two texture arrays: albedo as ETC2, and normal/roughness/AO as ASTC 4x4. All have mipmaps.
  - A near-camera detail layer and macro variation hide tiling.
- **Ground decals (static):** tire tracks, cracks, oil, sand drifts and rubble.
- **Weathered model shader:** panel lines, edge wear and scratches, rust, grime, dirt at the base and stencils. Amounts differ per faction: EU is clean, TPLA is rusty.
- **New setting, Texture quality:** High (default) or Medium. Medium skips the normal map and detail layer and uses a coarser mip level.

### HUD
- Unit and building names are written in full, on at most 2 lines. Text shrinks automatically down to about 9–10 sp. Every tap target is at least 48 dp, and the price has its own line.
- Command buttons are wider. The number of queue and type chips adapts to the screen width. EU power and population now share one line.
- **New test (part of the exported UI flow test):** checks that no button text overflows or is clipped, and that every button is fully on screen. It runs on every EU and TPLA build card and every unit portrait.

### Balance (data/balance/*.csv)
- New `hmg` damage type, used by the Rattler and the tunnel MGs.
- Autocannon vs infantry: 90 → 75.
- EU grenade damage: 40 → 34.
- Laborer capacity: 75 → 100. Militia HP: 150 → 170.
- **AI fixes:**
  - TPLA builders no longer drift back to harvesting.
  - TPLA builds fewer Militia when the enemy fields armor.
  - Attack waves regroup before attacking.
  - **Late-game hunt sweep:** a winning AI no longer stalls into a 40:00 draw when it can't see the enemy's last buildings.
- Honest results are in KNOWN_ISSUES. **EU still wins most EU vs TPLA matches.**

### Engine and tests
- Fog memory is rewritten only when something changes. There is a spike profiler, and death events record the killer.
- New TPLA mechanics test (20 checks), plus `ediag`, `spike` and `duel` diagnostic modes.
- **Touch test:** it now runs on a virtual gesture clock. The box's software renderer is down to about 3 fps with the PBR terrain, which broke the timing-based gestures.
- **Camera fix:** pan inertia decay no longer depends on frame rate. It used to stop dead below 5 fps.
- Replaced a deprecated TextServer flag. The trimmed export engine rejects it.
