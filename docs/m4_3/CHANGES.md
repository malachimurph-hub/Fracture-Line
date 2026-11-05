# M4.3 (0.4.3 candidate) - Malachi's list

Branch m43 off master 3d620b5 (0.4.2). Not built, merged, bumped or uploaded.

| # | Item | Status |
|---|------|--------|
| 1 | Transport cash pop-up on unload | Fixed: floater only for depot drop-offs (events with an amount) |
| 2 | Vehicle speed variety | Tiers in units.csv: MBTs 1450 (Scrapback 1500, Brennus 1150), SPGs 1250, IFV/AA 1750-2000, wheeled APCs 2400, light 2600-3300. Harvesters unchanged |
| 3 | Front arrow on placement ghost | Green arrow at the exit edge, follows rotation |
| 4 | Boarding before landing / rappel | Helis descend to ground in LANDING before troops board; mid-air unload plays a fast-rope slide (1.4 s) |
| 5 | Iran camo net | Unbuildable; TPLA AI skips it |
| 6 | Technical / supply pickup | Technical remounted on same Hilux-style body as the supply pickup (was Safir jeep); chrome grille + side steps; random blue/white/black/red/yellow paint |
| 7 | Iran HQ / Workshop / Garage | New models: stone municipal hall (arched portico, cornices, clock turret, flag); glass office block; steel-clad vehicle depot with office. AO + texture bake + icons redone |
| 8 | Country maps, debris | Debris clearing done. Four new country-staged review maps added (Prairie Crossing — USA, Rheinbruck — Germany, Qanat Gate — Iran, Severny Bridge — Russia) with themed civilian props; existing maps unchanged pending look-and-feel sign-off |
| 9 | Crude Oil Reserves | Kept (Malachi): same harvest loop as Supply Stashes |
| 10 | Movement audio | Engine loops per class: tank rumble, IFV diesel, light V8, rotor, jet + take-off roar |
| 11 | Weapon size distinction | New heavy rocket, heavy missile, reverberant artillery and big-gun sounds |
| 12 | Germany gun bunker + AA gun | Unbuildable; EU AI uses guard tower / Mantis |
| 13 | No-power defences | Javelin Foxhole, guard tower, M777 firebase: power 0 |
| 14 | Low power | Powered structures stop completely (no production, no fire, no income except depot drop-offs); bolt shown above them; AI builds power first |

Tests: new `m43` suite (test_runner "m43"). Minefield test reduced to trigger-only (mines disabled in game since 0.4.2).
Audio generator: tools/m43/gen_sfx_m43.py. Models: tools/m43/models_m43.gd.

Country maps: tools/gen_maps_m43.py. Props: PropMeshes themed houses/blocks/gas (us/de/ir/ru). MapDef.civ_theme.
