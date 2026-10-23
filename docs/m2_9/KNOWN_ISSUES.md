# M2.9 known issues

- **TPLA AI does not build the Airfield or use jets.** The Mirage, MiG-29 and F-16 are for human players only for now.
- **Voice lines with the new names are missing.** TPLA lines that said an old name ("Rattler", "Hailstorm",
  "Scrapback", "Mule", ...) were removed. New Arabic/Persian-accented recordings were too slow to generate on the box CPU.
  - Renamed units use their remaining generic lines.
  - Backhoe and Pickup reuse the old Laborer voices.
  - Marksman and Insurgent reuse the Militia voices.
  - The three jets reuse the Fajr (ex-Shrike) voices.
  - BHX-35 and Fajr "created" lines reuse a select line.
- **Internal ids are unchanged.** The data still uses the old ids (tpla_rattler = Technical, tpla_scrapback = Striker,
  tpla_hailstorm = BHX-35, tpla_shrike = Fajr, tpla_blight = Koksan, tpla_bus = BMP-2, tpla_militia = Rifleman,
  tpla_rocket_cell = Rocket Man). Players never see them.
- **BHX-35 vs the real DAMITA.** The real DAMITA is wheeled (8x8). The BHX-35 is tracked on purpose, as requested.
- **Tall towers can hide units behind them** at low camera angles. Selection boxes and health bars still show.
- **City roads in the desert map use the desert road texture,** not dark asphalt.
- **Map Builder props are decoration only,** except the five building types, which block their footprint. You can't
  rotate props in the builder yet.
- **Old saves from M2.8** that contain removed TPLA units (Laborer, Mule, Junkhammer, Sprayer, Earwig, Jackal) may not
  load.
- Carried over from M2.8: see `docs/m2_8/KNOWN_ISSUES.md`.
