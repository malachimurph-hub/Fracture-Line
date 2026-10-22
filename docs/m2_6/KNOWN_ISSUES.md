# M2.6 known issues

- **US is still too strong against the TPLA.** The numbers-only pass fixed US vs EU (it now lands
  near 50%), but US vs TPLA is still about 88% US (14-2) (hard vs hard, 4 maps). EU vs TPLA leans toward
  the TPLA (about 58% TPLA). Seeds and the full table are in SOAK.md. Next numbers to try: TPLA
  infantry/rocket-cell damage against US armour, plus the Harrier again (it is still the US
  unit with the highest kill value).
- **40:00 stalemates still happen** (2 of 15 EU-US games and 1 of 12 EU-TPLA games in the r3
  soak). The winning AI sits at 50k supply but never finds the loser's last outlying production
  building or Supply Center. The M2.6 hunt sweep (spawns, then resource sites, then a 20-tile
  grid) did not change the one case that was replayed (Kessel Pass, seed 1001). STALL-DIAG lines
  in the soak logs record the state. The root cause is not fixed yet.
- **New voices deferred.** M2.6 ships the M2.5 voices unchanged. The TPLA lines still come from
  Chatterbox, prompted with Persian Piper voices derived from "lessac" (research-only dataset
  terms, see LICENCE_REVIEW.md). Do not use them commercially. Regenerated voices arrive in a
  later update.
- **Voice QA not redone.** The Whisper QA before/after for TPLA lines was dropped with the voice
  scope change. There is only a partial baseline log, builds/m2_6/tpla_qa_before_partial.log.
- **Long single-word names** ("Thunderlance") are drawn with 1 px tighter letter spacing at
  9 dp so they fit the 63 dp command card.
- **Main-menu battle** is silent, has no AI economy and runs at a 30 FPS cap. Phone frame time
  has not been measured on hardware.
- **Software-renderer screenshots.** builds/m2_6/screens were rendered with llvmpipe (the
  OpenGL fallback), so they look darker and softer than on the phone's Vulkan renderer.
- **Balance soak sample size** is 4 seeds per map per matchup (about 15 per matchup), so each
  cell has a wide error margin. A few late r3 games ran with the new hunt code (it only
  matters after 10 minutes, when the attacker knows no enemy structure).
- The M2.5 issues still apply: the air layer is simplified, US buildings are placeholders
  pending Malachi's list, Lynx passengers cannot fire from inside, phone performance is not
  measured for the new maps and aircraft, and the M2.4 issues remain (damage on fire, GL shader
  instance cap, generic construction rigs, debug-key signature, arm64-only).
