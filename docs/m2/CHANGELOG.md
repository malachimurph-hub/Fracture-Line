# Rules of Engagement (formerly FRACTURE LINE): Changelog

## 0.2.1 (M2.1, versionCode 5), 2026-10-22

APK: `FractureLine-M2.1.apk`. It is arm64-v8a, 38,306,561 bytes (36.5 MiB), signed with the debug key. `apksigner verify` passes (v2 and v3). Built from commit 08ec4af. Details are in `verification/m2.1/apksigner.txt`.

### Balance (data and AI only)
- **TPLA:**
  - Tunnel Network: cost 800→600, build time 10→8 s. Tunnel MG damage 13→15.
  - Rattler: build time 7→6 s, HP 380→400 (cost stays 500).
  - Laborer harvest capacity 100→90.
  - The AI is more vehicle-heavy (Rattler 7, Militia 3, Rocket Cell 3, Scrapback 5, Hailstorm 2, Shrike 2, Mule 1, Blight 2). It builds fewer rockets when enemy infantry outnumbers armour 2:1, and favours Hailstorms against infantry. First wave value 3000→4000.
- **EU:** grenade splash 1.2→1.1 m.
- **AI fixes:**
  - Late-game hunt sweep when no enemy structure is known.
  - The idle part of a strung-out wave pushes on by itself.
  - Both fixes remove the 40:00 stall draws.
- **Result, Medium vs Medium 1v1 over 24 seeds (every spawn pair): EU 10, TPLA 14, 0 draws.** The full history is in KNOWN_ISSUES.

### Build range fix (Zero Hour rules)
- There is no build range at all, and building on unexplored or shrouded ground is allowed. A builder drives to any spot it can physically reach.
- **Root cause of the "limited range" on device:**
  1. Placement still required explored ground.
  2. Reachability used vehicle regions for foot builders, so TPLA Laborers in forests or fords were "unreachable" almost everywhere.
- Now reachability uses the selected builders and the right movement layer (foot or vehicle). An unreachable spot says "No path for the selected builder (water or cliffs in the way)".
- New corners test: both factions build at all four shrouded far corners. It runs in the exported build.

### Resume build (Zero Hour)
- Unfinished structures stay as scaffolds and keep their progress.
- **One builder constructs a structure at a time.** A second builder does not speed it up, as in ZH.
- Ways to resume:
  - With builders selected, tap your scaffold.
  - Select a scaffold and press **Resume build**. It sends the nearest idle builder, or the nearest builder if none is idle.
  - An interrupted builder shows a **Resume build** button.
- The AI resumes its own scaffolds.

### HUD (10% smaller)
- The bar, command buttons (63×49 dp), portrait, minimap frame, top bar and alerts are all 10% smaller.
- Every tap target is at least 44 dp, and full names still fit. Alerts stay 40 dp tall; they are notices, not buttons.
- **Control groups 1–5** collapse into a chevron (›). They start collapsed and expand or collapse on tap. A badge shows how many groups are assigned.
- **X deselect** button left of the portrait, visible whenever something is selected. The two-finger tap still deselects.
- TPLA shows only population in the resource panel, because it needs no power bar.
- A queued [STUB] item shows the [STUB] tag instead of its price, which stays in the tooltip.

### Lobby
- The Player column is now **You / AI / Closed**.
- There is a separate **Difficulty** column (Easy, Medium, Hard) for AI slots only. It is blank for You and Closed, and defaults to Medium.
- The layout is compacted to fit 2340×1080 (384 dp tall): Start battle moves under the slot rows.

### Fixes
- **Save/load divergence:** pending path requests are now saved. Before, loading dropped them, so units waiting for a path stood still and a loaded game slowly diverged from the original. This was a latent bug since M1, exposed by the M2.1 data changes.
- **HUD long-press timing:** it now uses the shared gesture clock, so a slow frame can't turn a tap into a long-press under test.

### Tests
- New: `corners`, `resume`, and a visual `m21` mode (lobby fit, groups arrow and X, HUD text-fit for both factions).
- Touch test steps 10–13: 44 dp targets, groups, X, and resume.
- UI flow now also checks the lobby Difficulty column and lobby text-fit.

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
