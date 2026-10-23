# M2.9 known issues

- **Internal ids are unchanged.** The data still uses the old ids (tpla_rattler = Technical, tpla_scrapback = Striker,
  tpla_hailstorm = BHX-35, tpla_shrike = Fajr, tpla_blight = Koksan, tpla_bus = BMP-2, tpla_militia = Rifleman,
  tpla_rocket_cell = Rocket Man). Players never see them.
- **BHX-35 vs the real DAMITA.** The real DAMITA is wheeled (8x8). The BHX-35 is tracked on purpose, as requested.
- **The TPLA AI only uses the Airfield on medium and hard,** and builds just one. Easy never builds one.
- **The Rifleman (Militia) voice set is unchanged.** It is your M2.5 reference voice.
- **AI voice QA is not perfect.** 24 of the 166 new lines score under 0.8 on Whisper word match after retakes;
  see `tools/voice_qa_m29.json`. Most of these are acronyms Whisper writes differently ("BX-35", "30 mil").
  The Fajr "created" line reuses its select line, because generation was stopped before that line was made.
- **Removed voice folders.** The old voice folders were removed. Only the Rifleman (militia) folder and the
  announcer folders remain from earlier versions.
- **Tower see-through only follows units near the screen centre** (the nearest 24). Buildings away from the
  centre stay solid.
- **Map Builder props are decoration only,** except the five building types, which block their footprint.
- **Old saves from M2.8** that contain removed TPLA units (Laborer, Mule, Junkhammer, Sprayer, Earwig, Jackal) may not
  load.
- Carried over from M2.8: see `docs/m2_8/KNOWN_ISSUES.md`.
