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
