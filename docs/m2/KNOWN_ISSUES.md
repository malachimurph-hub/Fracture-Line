# FRACTURE LINE 0.2.1 (M2.1): Known issues and verification

## Verification (logs are in `verification/m2.1/`, build from commit 08ec4af)

| Test | Result |
|---|---|
| APK signature (`apksigner verify`) | Passes (v2 and v3). versionCode 5, version 0.2.1, arm64-v8a, 38,306,561 bytes. Signed with the debug key. |
| Rendered UI flow on the exported build (LinuxVerify, Vulkan Mobile on llvmpipe, 2340×1080 at 450 dpi) | 60/60 PASS. Covers the lobby Difficulty column (default Medium), lobby text-fit and on-screen checks, an EU and a TPLA match, and HUD text-fit on every card. |
| Exported: content, save/load, replay | PASS. Save/load: 0 mismatches over 3000 ticks after loading. Replay: 30 checkpoints, 0 mismatches. |
| Exported: placement | 5/5 PASS |
| Exported: far corners (both factions, 4 shrouded corners) | 12/12 PASS |
| Exported: resume build | 8/8 PASS |
| Exported: TPLA mechanics | 20/20 PASS |
| Exported: audio and voice | 40/40 PASS |
| Exported: difficulty, Hard vs Easy mirrors, 2 per faction | Hard wins 4/4. Hard harvested 1.6–2.9× more and lost 0–1 structures; Easy lost 9–17. |
| Touch simulation (editor build, rendered) | 26/26 PASS, including 44 dp targets, groups chevron, X deselect and resume build |
| Visual `m21` mode (editor build) | 43/43 PASS. Lobby fit and HUD text-fit for both factions. Screenshots: `screens/m21_hud_groups_x.png`, `screens/m21_lobby_difficulty.png` |

### Failures found while verifying, and their fixes
- **Save/load diverged (2999/3000 mismatches).**
  - Cause: pending path requests (the per-tick path budget queue) were not saved, so after a load those units never got a path. It was latent since M1; the M2.1 data changes made the 6000-tick test hit it.
  - Fix: the queue is now saved and restored (6a3928a).
- **TPLA test "extra crates become Supply" (+330 instead of +150).**
  - Cause: the test measured the raw Supply change, which also included Laborer harvest income (changed by capacity 90). The game logic was correct.
  - Fix: the test now counts the crate payout event exactly (+150) and checks that Supply rose by at least that much (0fdd708).
- **UI flow: "Mule Bomb Truck / $600 [STUB]" did not fit the 63 dp button** on the export's text server.
  - Fix: on [STUB] items the price uses 9 dp next to the tag, with tighter margins (08ec4af).
- **Touch test: HUD taps failing under load** (groups arrow, group 1, the Resume build grid button).
  - Cause: HudButton timed long-presses on the real clock, so a slow software-rendered frame turned a tap into a long-press.
  - Fix: it now uses the same gesture clock as world input (08ec4af).

## Balance: EU vs TPLA, Medium vs Medium 1v1 (honest)

| Batch | Seeds | EU | TPLA | Draws |
|---|---|---|---|---|
| M2 baseline | 12 | 7 | 5 | 0 |
| f1 | 12 | 9 | 3 | 0 |
| f2 | 12 | 4 | 7 | 1 |
| f3 (after idle-push fix) | 12 | 4 | 8 | 0 |
| f4 | 12 | 4 | 8 | 0 |
| g1, all spawn pairs | 24 | 9 | 15 | 0 |
| g2 | 24 | 9 | 15 | 0 |
| g3 (reverted) | 24 | 5 | 19 | 0 |
| g4 | 24 | 9 | 15 | 0 |
| **g5, final, kept** | 24 | **10** | **14** | **0** |

- **Outcomes depend strongly on the spawn pair.**
- **The one-builder rule (resume build, 893cf47) and the save/load fix came after g5.** No 24-seed batch has been run since, so the final balance is unverified after those changes. On the user's instruction, there was no further tuning.
- **Hard vs Hard (2 seeds, editor build, after the one-builder rule):** TPLA won both, in under 6 minutes, with early raids. Hard-level balance is not tuned.

## AI difficulty: what actually differs
- **Reaction:** the AI thinks every 12, 4 or 2 ticks (Easy, Medium, Hard).
- **Economy and build order:**
  - harvesters per hub 2/2/3
  - expansion at 600, 330 or 240 s
  - production queue slack 3/1/0
  - TPLA: Laborers 5/6/7; Hard adds extra traps and up to 3 Chop Shops
- **Attacks:**
  - first wave at 420, 300 or 225 s
  - wave size ×0.7, ×1.0 or ×1.1
  - TPLA raids 0, 3 or 4
- **Defences:** bunkers 0/1/2. **Scouting, capturing and powers:** off on Easy, on for Medium and Hard.
- **Micro:** Easy never retreats damaged units; Medium and Hard do.
  - This is the only micro difference. There is no focus-fire or kiting difference yet, which is a known gap.
- **No resource cheats at any level.** The GDD reserves an income bonus for a later "Brutal" tier only, which is not implemented.
- **Medium vs Easy and Hard vs Medium** were not measured separately in M2.1.

## Known issues
- **Not tested on the S24 Ultra or any phone.** 60 fps is unverified, and the APK's ETC2/ASTC textures could not be rendered on the box.
- **Exported compile check finds 0 scripts** (they are precompiled). The rendered UI flow is what proves the exported scripts load.
- **Alerts are 40 dp tall,** below the 44 dp target. They are notices; tapping one is optional.
- The unused `LOBBY_KIND_OPEN` string is still in strings.csv.
- **Sim spikes:** single ticks reach 60–112 ms (AI think plus pathing bursts).
- The M2 issues below still apply:
  - stealth detection is proximity-only
  - decals are static
  - voices are AI-generated
  - models are procedural stand-ins (see GRAPHICS_PLAN.md)
  - bridges can't be destroyed
- Stubs are listed in STUBS.md.

---

# FRACTURE LINE 0.2.0-m2: Known issues and verification

## Verification (logs are in `verification/`)

| Test | Result |
|---|---|
| APK signature (`apksigner verify`) | Passes (v2 and v3). versionCode 4, version 0.2.0-m2, arm64-v8a, 38,302,465 bytes. Signed with the debug key. |
| Rendered UI flow on the exported, trimmed engine (LinuxVerify, Vulkan Mobile on llvmpipe, 2340×1080 at 450 dpi) | 57/57 PASS. Covers an EU match and a TPLA match. 21 of the checks are HUD text-fit/on-screen checks. |
| Exported build: content, save/load, replay | PASS. Save/load: the hash matches after loading, with 0 mismatches over 3000 ticks. Replay: 30 checkpoints, 0 mismatches. |
| Exported build: placement | 5/5 PASS |
| Exported build: audio and voice | 40/40 PASS. Every EU and TPLA line has a voice (AI-generated). |
| Exported build: TPLA mechanics | 20/20 PASS |
| Exported build: compile check | PASS, but it checks nothing here: it finds 0 scripts because they are precompiled in the export. The rendered UI flow is what proves the exported scripts load. |
| Touch simulation (editor build, rendered, 2340×1080 at 450 dpi) | 15/15 PASS, after the test-clock and inertia fixes (see CHANGELOG) |
| AI 1v1, EU vs TPLA, seed 21 (Medium vs Medium) | **TPLA** wins at 34:32. Avg tick 5.3 ms, worst 61.5 ms. |
| AI 2v2 mixed, seed 22 (team 0 = EU Hard + TPLA Medium; team 1 = TPLA Medium + EU Hard) | Team 1 wins at 13:13. Avg tick 10.1 ms, worst 112 ms. |
| AI FFA, seed 23 (EU Medium, TPLA Hard, EU Easy, TPLA Medium) | Slot 1 (**EU** Medium) wins at 11:54. Avg tick 6.3 ms, worst 82.7 ms. |
| Ally damage across all AI matches | 0 events |

- The three AI matches ran on the export at commit c0f69cf. The later commit only changed the touch test clock and the camera inertia, not the simulation.
- The other exported-build tests and the APK are from fe280f6.

## Balance: EU vs TPLA (honest)

| Batch | Code | Matches | EU wins | TPLA wins | Draws |
|---|---|---|---|---|---|
| b1 | Before the M2 balance passes | 12 | 9 | 2 | 1 |
| b2 | Balance pass 1 | 12 | 10 | 2 | 0 |
| b3 | Balance pass 2 (stopped early) | 8 | 5 | 1 | 2 (40:00 timeouts) |

- Each batch is a 1v1 soak. Factions and spawns alternate each seed. The difficulty pairs cycle Medium/Medium, Hard/Hard and Easy/Easy.
- **Across all batches that is EU 24, TPLA 5, 3 draws. TPLA is clearly weaker in AI vs AI.**
- **What the diagnostics show:**
  - TPLA loses most games fast (about 8 minutes) to early EU pushes. Grenadiers and Wolfhounds kill Militia very efficiently.
  - In equal-cost duels, TPLA vehicles win, but TPLA infantry lose.
  - The b3 draw on seed 1000 was a game TPLA had won: by minute 25 the EU had 2 buildings and no army. But the TPLA AI never found the last buildings.
  - The late-game hunt sweep (c0f69cf) fixes this: the same game now ends at about 35:00.
- **The hunt fix came after these batches.** No full batch has been run since it, apart from the single 1v1 above (a TPLA win).
- Next tuning step: TPLA's early defence and economy, and the Militia vs Grenadier matchup.

## Known issues
- **Not tested on the S24 Ultra or any phone.** 60 fps is unverified.
  - The PBR terrain (texture arrays, normal maps, detail layer, decals) and the weathered material cost more per pixel than M1. On the box's software renderer, frame rate fell from 9.3 to 2.9 fps in the 4-player perf scene. That number says nothing about the phone, but the shader cost really went up.
  - Texture quality **Medium** is the fallback. It saves shader work and bandwidth, not memory (the same textures are loaded).
- **The APK's ETC2/ASTC textures could not be rendered on the box.** Screenshots come from the desktop build of the same scenes.
- **Sim spikes:** single ticks reach 60–112 ms (AI think plus pathing bursts). The average is 5–10 ms per tick. The catch-up step absorbs them, but they may cause hitches on a phone.
- **Stealth detection is proximity-only.** There are no detector units yet.
- **Ground decals are static.** Units don't leave new tire tracks.
- **Voices are AI-generated** (Kokoro), not recorded actors. Mix and attenuation have not been tuned by ear on a phone (the box has no audio device).
- **Models are procedural low-poly stand-ins** in the Zero Hour style. Final hand-made art is planned later.
- **Bridges can't be destroyed.**
- **Some screenshots are staged** by the visual test runner (`m2_vfx_tpla` and the galleries). The base and battle shots come from AI-played matches that were fast-forwarded.
- Stubs and deferred content are listed in STUBS.md.
