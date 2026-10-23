# Last Command (formerly FRACTURE LINE) 0.2.2 (M2.2 graphics test batch), versionCode 6

This is the first step of GRAPHICS_PLAN.md. The new art is wired into the real game: the same view scene paths that the unit and structure data use.

## Infantry
- EU Grenadier and TPLA Militia squads now use CC0 animated soldiers: Quaternius "Toon Shooter Game Kit".
  - Each squad has 4 soldiers.
  - Animations: idle, run, fire (held for 0.7 s after each shot) and die. Soldiers drop as squad HP falls, and the whole squad falls on death.
- The animation is baked to vertex-animation textures (`tools/bake_infantry.gd`). One MultiMesh draws each squad, and no skeletons run at runtime.
  - Meshes are decimated to about 1.4–1.7k tris per soldier.
- Faction looks:
  - EU: olive fatigues, SMG and a team-coloured helmet band.
  - TPLA: desert wraps, AK and a team-coloured face wrap.
- [STUB] A US/Western Alliance placeholder rifleman (`assets/models/infantry/wa_rifleman_placeholder.res`) is baked but not used, because the game has no WA faction yet.
- A 150-soldier crowd test (38 squads, 152 soldiers) is in `tests/gfx_showcase.gd`.

## Vehicles (new original procedural models, `tools/gfx_m3/vehicle_kit.gd`)
- **EU Leopold MBT**
  - Hull: track loops, 6 road wheels, sprocket, idler and return rollers per side, bolted side skirts with a team band.
  - Deck details: glacis hatch and periscopes, lights with guards, engine grille, exhausts, stowage and tow cables.
  - Turret: wedge shape with a team band, bustle rack and stowage, cupola with vision blocks, MG, smoke dischargers and antennas.
  - Gun: fume extractor and thermal sleeve.
- **TPLA Rattler technical**
  - Lifted pickup with lugged tyres, mismatched scrap panels, bull bar, light bar, team roof cloth and flag, and bed cargo.
  - Pedestal HMG with a scrap gun shield.
  - Salvage tier bolt-ons kept: armour plates and sandbags, shield wings, slat cage.
- **Animation (VehicleView)**
  - Turret turns (as before).
  - Barrel recoils on every shot.
  - Wheels spin and track links scroll with the distance actually travelled. This is done in the vertex shader, so each moving part is still 1 draw call.
  - Rattler front wheels steer with the turn rate.
  - Soot and scorch build up with damage. On death the vehicle becomes a burnt-out wreck with a skewed turret, which lingers for 7–8 s and then sinks.
- New single-material shader `view/materials/model_m3.gdshader`:
  - The part class (paint, team, glass, rubber, track, lamp, steel, canvas, concrete, corrugated, wood, sandbag, char, …) is stored in vertex alpha.
  - Weathering is the same as M2's: panel lines, chipped paint, rust, grime, ground dirt, stencils.

## EU Barracks (`tools/gfx_m3/barracks_kit.gd`, BuildingView)
- Rebuilt Quonset-style hall:
  - ribs, team stripes, entrance vestibule with a lit door and team sign, dormer windows, vents and generator;
  - comms mast with dish and beacon, floodlights, team flag, sandbag positions and crates.
- Construction stages:
  - the scaffold climbs first (0–25 %);
  - the hall then rises inside it, with a glowing build edge (12–95 %);
  - the scaffold is struck at completion.
  - The clipping shader variant is used only while building.
- Damage states:
  - light (≤75 % HP): soot, debris, boarded windows, a smoke wisp;
  - heavy (≤40 %): breaches with bent ribs, collapsed vestibule roof, fallen sheeting, fires and smoke at 3 anchors;
  - destroyed: smouldering rubble with standing bent ribs, which lingers 14 s and then sinks.

## Other
- CREDITS (docs and in-game) list the Quaternius CC0 soldiers.
- Version is 0.2.2, versionCode 6.
