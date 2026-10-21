# FRACTURE LINE M1: Known issues

> **0.1.2-m1.2 update (visual pass, build-anywhere, audio v1).** See CHANGELOG. Verification logs are in `verification/m1.2/`.
>
> | Test | Result |
> |---|---|
> | Rendered UI flow on the exported, stripped engine (LinuxVerify, Vulkan Mobile/llvmpipe) | 17/17 PASS. Every screen's scripts compile. No deprecated-API errors. |
> | Exported build (stripped engine): content, save/load, replay | PASS. Save/load: hash matches, 0 mismatches over 3000 ticks. Replay: 30 checkpoints, 0 mismatches. |
> | Exported build: placement test (build anywhere) | 5/5 PASS |
> | Exported build: audio and voice test | 24/24 PASS. 0 of 65 manifest event slots recorded yet; all fall back to placeholders. |
> | AI matches on the exported build (Medium) | 1v1 seed 21: team 0 wins at 25:01. 2v2 seed 22: team 1 wins at 9:52. FFA seed 23: team 1 wins at 19:34 (team numbers as in the logs, 0-based). 0 ally-damage events. Avg tick 3.8–6.0 ms; worst single tick 46–90 ms. |
> | Touch simulation 2340×1080 @450 dpi | 15/15 PASS |
> | Perf, 4 players at 9:36 (142 entities, 67 units) | 92–103 draw calls (close / mid / far zoom). About 255k primitives including shadow passes. View update 0.5 ms per frame. Sim 7.4 ms per tick. FPS was not measured on hardware (software renderer on the box). |
>
> **Known issues in 0.1.2:**
> - **Not tested on the S24 Ultra or any phone.** 60 fps with the new terrain, shadows and effects is unverified on hardware; the box only has a software GPU.
>   - If it drops below 60, the first things to cut are: render scale (Settings), the second shadow split, and decor shadows.
> - **Not tested with real audio.** The box has no audio device; the audio tests use the Dummy driver. Mix levels, music volume and 3D attenuation still need tuning by ear on the phone.
> - **Voices are placeholders.** Every voice line is still robotic TTS until you record it (VOICE_SCRIPT.md). The game says so in Settings.
>   - Placeholders exist only per event, not per unit, so all EU units share the same placeholder lines.
> - **Draw calls with effects active were not measured.** The perf sample at 9:36 had no live effects on screen. The effects are drawn as 4 batched layers (fire, smoke, debris, decals), so they should add at most about 4 draw calls; this is not measured.
> - **The battle-with-effects screenshots are staged.** `06_battle_vfx_staged` and `07_…` trigger explosions and smoke directly in a review scene; they are not from a live battle.
> - **Before and after shots are on different maps.** The "before" screenshots show the old Varno Crossing; "after" shows v2. The camera setups are the same, but the content differs.
> - **The APK's own assets could not be rendered on the box.** It ships ETC2 textures only, which the box's software GPU and the stripped desktop engine can't decode.
>   - This build's APK assets were therefore checked on the full engine instead (it converts ETC2). The lobby and match loaded without script errors, but the screen capture there stayed on the lobby frame, so there is no in-match screenshot from the APK assets.
>   - The same scripts and scenes pass the rendered UI flow test in the LinuxVerify export on the stripped engine.
> - **Sim cost went up.** The 4-player sim tick averages about 7.4 ms, up from about 4–6 ms, because build-anywhere searches more spots. There are single-tick spikes up to about 90 ms during AI build searches (the 4-tick catch-up absorbs them, but they could cause a hitch on a phone).
> - **Bridges can't be destroyed** yet, and the river can only be crossed by bridges and fords, as designed. Cliffs are visual height only; the sim map still decides what is passable.
> - **Models are procedural low-poly stand-ins,** made in the Zero Hour style. Final hand-made art is planned later (GDD §14.6).
> - **The music and SFX are first-pass synthesized originals.** There is no adaptive music yet (GDD §14.5).

> **0.1.1-m1 update:** 0.1.0-m1 showed a blank screen after tapping Skirmish on Android (fixed; see CHANGELOG). The desktop tests missed it because they ran on the full editor engine, which still has deprecated APIs. The exported-build tests were headless and never loaded the UI scripts. A rendered UI flow test on the exported, stripped engine now covers this. The fix is still **not confirmed on the S24 Ultra**: an Android emulator could not run on the box (no KVM access), so there is no logcat. Evidence: the 0.1.1 APK's own assets were run on the matching stripped engine (Linux build, Vulkan Mobile via llvmpipe), and tapping Skirmish then Start battle opens the lobby and the match.
Build 0.1.0-m1, project commit ac97149 (the APK and web build were exported from 038490e; ac97149 only changes a test cap).

## Verification results (actual)
All matches are AI-only (Medium vs Medium), headless, deterministic sim, on the box CPU. Logs are in `verification/`.

| Test | Result |
|---|---|
| 1v1, seed 21 | Team 2 wins at 8:18, PASS. 0 friendly-fire events. Avg tick 2.07 ms, worst 12.3 ms. |
| 2v2, seed 22 | Team 2 wins at 42:19, PASS. 0 damage events between allies. Avg tick 4.24 ms, worst 65 ms. |
| 4-player FFA, seed 23 | Team 3 wins at 42:41, PASS. 0 ally damage. Avg tick 4.31 ms, worst 68 ms. |
| Extra soak, mixed difficulties | 1v1: 8:18, 17:40 and 15:24, plus 8:18 (H/E, E/H mixes). 2v2: 11:12. All finished with a winner. |
| Touch simulation (2340x1080, 450 dpi) | 15/15 PASS: tap select, two-finger deselect, pan, inertia, pinch, hold-box, hold attack-move, tap move, double-tap type select, finger-release doesn't place, ghost follows finger, Confirm places, buttons ≥48 dp, group recall, HUD touch isn't a world tap. |
| Exported build (stripped release engine, LinuxVerify preset) | Content PASS; save/load: hash matches, 3000 ticks, 0 mismatches; replay: 30 checkpoints, 0 mismatches; 1v1 PASS at 8:18. |
| Web build in headless Chrome (SwiftShader WebGL2) | Boots to the main menu, the lobby works, and a match starts and runs (HUD and clock checked by screenshot). Not played to completion in a browser. |

In the table, "Team N" uses the in-game 1-4 numbering. The test logs print 0-based team numbers.

## Not verified
- **Not run on a real phone, the S24 Ultra included.** 60 fps, Vulkan Mobile, safe areas, the cutout, haptics, the S Pen and the Back gesture are untested on hardware. Visual tests used software GL in Xvfb. Sim tick costs come from the box CPU; a phone will be slower, but 4-player average sim cost (about 4-6 ms per 50 ms tick) leaves a lot of headroom.
- No human-vs-AI full match has been played. Touch was checked by simulation, not by hand.

## Gameplay and AI
- **Seeds barely matter.** AI matches with the same slot setup and difficulties play out identically whatever the seed, because the sim uses almost no randomness. In mirror matches, one side (team 2 in 1v1) wins consistently. That points to map or spawn asymmetry or ordering bias; needs investigation.
- **4-player AI games run long** (about 42 minutes). Late game, both sides run low on supply and grind against bunkers. A late-game wave ramp and field repair now make games end, but pacing is slower than ZH. The 4-player test cap is 60 minutes.
- **The AI "cheats" on target choice.** It scores enemies by real army and base size, not only by what it has scouted. Attacks themselves use fog memory.
- **Worst tick spikes** of about 65 ms happened while other jobs shared the CPU. These are single ticks; the 4-tick catch-up absorbs them, but they could hitch on a phone.
- **Field repair** (2% HP/s near your own HQ or a production building after 10 s without being hit) is a stand-in until real repair structures exist.
- One map only (Varno Crossing, 4 spawns) and one faction (EU Alliance).

## Stubs (shown as [STUB] in game; see STUBS.md)
- **Superweapons lobby toggle:** saved, but no superweapons exist.
- **Grid Blackout** (rank-4 power): cannot be bought or fired.
- **Wolfhound IFV transport:** cannot carry infantry.
- **Other factions:** greyed out as "coming later".

## Not implemented (not shown in game)
- Supply crates, aircraft, naval units, upgrades and research, and repair structures.
- Audio and music: the game is silent.
- Multiplayer, campaign, tutorial (deferred, GDD §19.3), monetization and store.

## Technical
- **Pathfinding** is grid A* (AStarGrid2D), not the flowfields in the GDD. Large groups can bunch up at chokepoints and bridges.
- **The terrain is flat** (height tint only), and the art is simple placeholder geometry.
- **Web build:** the engine wasm is about 39.5 MB (official template, the zip is 10.4 MB). The page has to be served over http (see README.txt in the zip). Default-font glyph gaps were fixed by using ASCII labels.
- **Export workaround.** `editor/export/convert_text_resources_to_binary=false` must stay off. Binary conversion emptied PackedStringArray fields in the data resources in this engine version. Content validation fails loudly if this comes back.
- **The APK is debug-signed** (CN=Android Debug), so Play Protect will warn on install. It uses a custom size-optimized arm64 engine build (16.1 MB APK).
- `ERROR: n resources still in use at exit` appears in headless test logs. It is harmless shutdown noise.
