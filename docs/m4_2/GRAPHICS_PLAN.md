# Graphics overhaul (item 14) - first pass done in M4.2, plan for the rest

Done (M4.2): US aircraft + dozer grey, Black Hawk black (Palette.UNIT_PAINT), Iran vehicles repainted as clean
modern panels (tpla_modern pass on 8 vehicle scenes) with desert-khaki paint, 4-hangar airfields rebuilt for all
four factions, Sayad-3 site modelled, Javelin Foxhole crews use the animated infantry models; icons re-rendered.

Plan (one milestone per group, most-seen first; every model built from public reference drawings / photos of the
real vehicle's proportions, original geometry, smooth baked textures, <= current triangle + LOD budgets on S24):
1. Main battle tanks: Abrams-class (US), Leopard-class (Germany), T-90 (Russia), Iran MBT - hull/turret
   proportions, road wheels, ERA/armour blocks, gun mantlet, tex14 rebake.
2. IFVs / APCs: Bradley, Boxer, BTR-82A, Typhoon-K, Iran wheeled carriers.
3. Helicopters: Black Hawk, H145M, Mi-24 Hind, Ka-52, attack heli (rotor heads, sponsons, glazing).
4. Jets: F-16, Mirage, MiG-29, Su-57, US strike / stealth jets (wing planform, intakes, pylons).
5. Artillery / AA: Msta-S, MLRS, Gepard-class, Patriot, Sayad-3 launcher detail.
6. Support vehicles: dozers, supply trucks, engineer vehicles; then infantry kit; then structures.
Each step: regenerate (gen_gfx_m7 / m29), add_lods + bake_ao on that scene list only, bake_m33, icons, viewcost test.
