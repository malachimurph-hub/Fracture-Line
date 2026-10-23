# M2.8 known issues

- **Maps**: bridges, roads and rivers are 2x wider after the upscale (by design: layout preserved). Mid-map
  supplies keep their M2.7 amounts. AI expansion over the longer distances is unchanged and was only checked by
  the existing soak tests.
- **Stashes**: TPLA spawns run dry about 1 min earlier (15.7-16.2 min) than US / EU (16.6-17.8). Only Varno Crossing
  was measured; the other maps use the same amounts and HQ distances.
- **Water**: the shoreline field is 4 px per tile, so very thin (1-tile) water features render slightly narrower
  than their tiles. Fords use the same shader and read as shallow water.
- **Single infantry**: old voice lines still say "Grenadier Squad" / "Lancer Squad" until the next voice pass.
  Infantry balance values are first-pass and were not soak-tested per matchup.
- **Crashes**: the crash path is view-only and ignores terrain height (it lands at ground level 0), so a crash
  on a cliff top clips into the cliff. The wreck is the aircraft model darkened, with no separate debris meshes.
- **Airfields**: EU aircraft are still stubs (`air_slots` 0), so the EU Airstrip shows empty bays. The larger
  footprint can make airfields harder to place in tight bases.
- **Infantry models**: under the software renderer used for screenshots (llvmpipe, GL compatibility) VAT soldiers
  render darker than on device; this was already true before M2.8. Weapon and gear detail is small at default zoom
  and reads best at close zoom. The Laborer keeps its kit shovel.
- **ECC**: still a locked placeholder slot with no roster (as requested).
