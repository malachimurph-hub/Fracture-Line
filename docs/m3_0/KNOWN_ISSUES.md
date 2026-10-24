# M3.0 known issues (0.3.0)

- **"Boxer" is a product name.** It is Malachi's choice for the EU IFV. Revisit before the store launch.
- **Internal ids are unchanged.** The old ids are still in the data: us_halberd = M1A3, us_lynx = JLTV,
  us_picket = MAAS, us_javelin = Anti Armor Soldier, us_firebase = M777A2, us_patriot = LPWS,
  us_drop_zone = Data Center, us_garage = Motor Pool, eu_leopold = Panther Tank, eu_wolfhound = LTV,
  eu_thunderhead = RCH SPA, eu_flakwerk = Thunderbolt, tpla_mirage = Delta Fighter. Players never see them.
- **Some voice lines still say an old name**, where that line was the only one for its event:
  - Wolfhound veteran
  - Leopold veteran
  - Flakwerk veteran ("Flak crew promoted")
  - Mirage created, select and veteran
- **No new voice lines.** The Bradley and the Boxer reuse the JLTV and LTV voice sets, and nothing new
  was generated. `tools/voice_manifest_src.py` does not have the new entries yet; they were added straight
  to `data/audio/voice_manifest.json`.
- **The Panther model is unchanged.** It was already Leopard 2-based, so it was only renamed.
- **Building turrets only turn.** The M777A2 and LPWS rotate as a whole and do not elevate.
- **Lit windows and rooftop beacons** use a fixed glow. There is no day/night cycle, so they read as
  "lights on" in daylight.
- **Mountains are taller.** Large massifs can now hide units behind them. Tower see-through does not apply
  to terrain.
- **Sidewalks are decoration.** They are drawn on the tiles next to roads. Units still walk over them at
  ground height.
- **Preview screenshots** were rendered with the GLES3 fallback on the box (no Vulkan), so they are not
  the Mobile renderer. Performance on the S24 Ultra has not been measured for M3.0. Leaf cards are about
  70-150 triangles per tree, cars about 300, and towers gained about 1-2k triangles each.
- Carried over from M2.9:
  - The TPLA AI only uses the Airfield on medium and hard, and builds just one.
  - The Samavat SPAAG (old BHX-35) still uses the tracked 35 mm turret model.
  - 24 of the M2.9 TPLA AI voice lines score under 0.8 on Whisper word match (`tools/voice_qa_m29.json`).
    The Fajr "created" line reuses its select line.
  - The Hearth uses the Wolfhound/LTV voice set, which has no rocket lines.
  - Tower see-through only follows the 24 units nearest the screen centre.
  - Map Builder props are decoration, except the five building types.
  - M2.8 saves with removed TPLA units may not load.
  - The Superweapons lobby option is hidden.
  - Map load is about 0.5 s slower on large maps because of the splat blur.
  - Germany, Iran and Russia still use the old internal ids `eu_`, `tpla_` and `ecc_` (ids, file names,
    folders, the faction key in saves and Map Builder maps). This is on purpose, so saves and maps keep working.
  - E. National rosters:
    - Some voice lines still say an old name, because they are the only line for that event: Lancer veteran,
      Flak Tower veteran, BHX-35 / BMP-2 / Koksan created and veteran, Falcon / Mirage created, select and veteran,
      and Insurgent created.
    - The Fateh Missile Barrage keeps the old Blight mechanic, which leaves a lasting damage zone. Its effect still
      looks rusty.
    - The Puma IFV keeps the Salamander's short range and flame damage type, so its balance stays the same.
    - The German AI builds the Airfield, but in tests it seldom builds a Tiger or a fighter, likely because of
      the pop cap.
    - The Boragh, Samavat, Basij infantry and all Iran building models are unchanged. Only their names and text
      changed. The Anti-Tank Mine still looks like the old wired trap. The salvage mechanic stays as battlefield
      recovery.
    - The Germany Harvester (Logistics Truck) and Air Defence Gun models are unchanged.
  - Russia is "Coming soon" and locked in this release. Its open items (stand-in builder, gatherer,
    buildings and powers pending Malachi's list, mostly reused voices, no aircraft) are deferred to the
    release that unlocks it. The branch notes are in the M3.0 F section of the CHANGELOG.
  - Iran voices still have Persian accents. Faction voice lines do not say the nation names.
  - Older items: `docs/m2_8/KNOWN_ISSUES.md`.
