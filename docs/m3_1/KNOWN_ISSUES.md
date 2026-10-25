# M3.1 known issues / unverified

- **Not profiled on a phone.** Ultra (2x MSAA, 4096 shadows, extra normal-map fetches) is
  untested on real devices. If frame pacing suffers, pick High or Medium in Settings > Graphics.
- **Picking a graphics preset doesn't refresh the other settings controls on screen.** The
  render-scale slider and texture-quality option change underneath but only show the new values
  after reopening Settings.
- **Barrel elevation is cosmetic.** It lifts on the first shot rather than before it, and recoil
  still slides along the hull axis while the barrel is raised.
- **Runway edge cases**:
  - Re-tasking a jet while it taxis does not abort the take-off.
  - Orders given during landing are dropped; re-issue them once the jet is parked.
  - An airfield placed against the west map edge gets its approach fix clamped inside the map.
- **Two-finger box select and the twist rotation are covered by the scripted touch test**
  (`tests/visual_runner.tscn -- touch`), not on hardware. Thresholds are 0.35 s of hold,
  12 px of drift and 0.14 rad before a twist starts rotating.
- **The `touch` visual test still fails one pre-existing check** ("HUD buttons >= 44 dp": the
  37 dp top-strip buttons). It is not part of the release suite.
- **Key-art rendering**: the key art was rendered with the desktop compatibility renderer under
  xvfb, so lighting differs slightly from the Mobile renderer on the phone.
- **The 2048 px weathering and detail-normal textures ship as lossy WebP** (quality 0.75 / 0.85),
  not GPU-compressed. That keeps the APK under 100 MiB, but they take about 40 MB of GPU memory
  uncompressed.
- **The main-menu key-art open-time check in `m26_ui_test` was not run** for this build. The
  suite passed, but that UI test is outside it.
