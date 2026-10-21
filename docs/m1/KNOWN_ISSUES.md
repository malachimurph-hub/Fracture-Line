# FRACTURE LINE M1: Known issues
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
