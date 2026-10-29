# M3.4 (in progress, not released)

From Malachi's play-test of 0.3.5.

## Night lights
- Vehicle headlights now follow the drawn (interpolated) vehicle every frame instead of 8 times a
  second, so they no longer stutter when vehicles move.
- Each beam comes from one of the model's own headlights. The lamp positions are read from the
  model geometry (warm LAMP-class vertices at the front of the hull), with one beam per lamp and a
  lens flare on each. The beam meets the ground just past the lower hull (a dozer blade or bumper,
  not the gun barrel). The 0.3.5 direction fix (hull forward, tilt-aware) is kept.
- Structures no longer sit in a glowing apron. They show only their own lamps and lit windows,
  plus 2 to 4 floodlights on their walls and roof corners: a lens flare, a faint shaft, and an
  oval pool where each one points. Colours are per faction: US cool LED, Germany neutral, Iran
  sodium, Russia warm. Walls and other 1-tile pieces have none, and civilian blocks keep only
  their windows.
- Still phone-light: no real lights, only additive MultiMesh quads (one draw call per group),
  capped at 240 floodlights, nearest first.

## Infantry
- All soldiers are new, original procedural models (tools/gfx_m34; no third-party assets). The
  former toon-kit base is gone from the game.
  - Adult proportions (about 7.6 heads tall).
  - Lofted, smooth-shaded body.
  - Gear per faction: helmets with cover, rails, NVG mount, goggles and chin strap; plate
    carriers or chest rigs with magazine, admin, radio and IFAK pouches; belts; knee pads;
    gloves; boots.
  - Packs per role: assault pack, hydration, radio with whip antenna, rocket pack, spare tube,
    engineer tools, ghillie, MG ammo.
- Faction looks:
  - US: coyote blotch camo.
  - Germany: spot camo.
  - Iran-style militia: shemagh, caps, wraps and beards.
  - Russia: fine green camo, Russian-style helmet.
  - Infiltrator and saboteur: black, with balaclavas.
- Camouflage is smooth noise anchored to the cloth: no grain, no tiling, and it does not swim
  during animation.
- Variety:
  - Four look variants per unit type: head gear and packs.
  - Per-soldier skin tone, uniform tint and height (+-4 %), with clip timing offsets.
- Weapons are held in both hands in every clip. The right hand is on the grip and the left on the
  handguard, front grip or tube.
- Aimed fire uses a bladed stance with the cheek on the stock and recoil. Launchers are fired
  from the shoulder, and pistols with both hands.
- New clips:
  - Breathing idle with a look-around, a walk, and a tactical run with the rifle at port arms.
  - Kneeling fire: marksmen always kneel, and some riflemen do.
  - Barricade lean.
  - Two deaths: falling backwards, and crumpling forwards. The weapon drops to the ground.
- New procedural weapons: combat shotgun (Breacher), compact PDW (Sturmtrupp), pistol
  (Insurgent and Saboteur), and an entrenching shovel (Labourer).
- Compact VAT format:
  - Position packed 11/11/10 bits in RGBA8, octahedral normals in RG8, 10 fps with frame
    blending.
  - About 2,900 triangles per soldier, with LODs.
  - All 21 bakes total about 15 MB, the same as before.
