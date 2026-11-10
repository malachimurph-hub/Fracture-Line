# Graphics review assets

Original geometry and textures, made for this review. No model, texture, or image from another game is included.

## How they were made

`tools/gfx_review/author_demo.py` runs in Blender (4.0 or newer; the bake here used 4.0.2). Blender is the authoring tool only. Its own license does not apply to these outputs.

The script builds the meshes, lays out UVs, and bakes:

- unique UV islands for the large surfaces
- hemisphere ambient occlusion by ray tests against the mesh plus a ground plane (`mathutils.bvhtree`)
- panel seams, bolts, a tactical number, mud on the lower hull, a light snow dusting on upward faces, and soot at the exhaust
- a normal map from those seams and from the roof corrugation
- an ORM map (red ambient occlusion, green roughness, blue metal)

Small repeated parts (wheel segments, bolts, pipe runs) share a painted swatch so the large surfaces keep the texture space.

## Proportions

The in-game name stays M1A3. Malachi specified the real M1A2 SEP v3 as the counterpart. Public figures used for the mesh:

| Measure | Value used |
|---|---|
| Hull length | 7.93 m |
| Width over the side skirts | 3.66 m |
| Height to the turret roof | 2.44 m |
| Length, gun forward | 9.77 m (the muzzle sits 1.84 m past the hull nose) |
| Ground clearance | 0.48 m |
| Track width | 635 mm |
| Road-wheel diameter | 0.64 m |

Running gear is seven road wheels a side, a drive sprocket at the rear, an idler at the front, and two return rollers. The gun is a 120 mm tube with a thermal sleeve, a bore evacuator, and a muzzle reference sensor. It has no muzzle brake.

Roof fittings follow the SEP v3 layout. The commander's hatch is on the right, with a low-profile remote weapon station over it (a 12.7 mm gun, a forward sensor, and an ammunition box). The gunner's primary sight is the armored housing on the right front of the roof. The commander's independent thermal viewer sits just ahead of his hatch. The loader's hatch is on the left, with a periscope and a shielded 7.62 mount. Blow-out panels sit on the bustle roof, and a bar basket extends behind the turret.

The ammunition data link on the real vehicle is a breech interface plus the fire-control electronics inside the turret, so it has no large external box. The mesh shows the two parts that can be seen: a collar at the breech and a small housing on the roof, with a conduit between them. The under-armor auxiliary power unit sits inside the left rear hull. The mesh shows the intake louvers and a low exhaust, not an external generator. No company names are on the model.

The game scale is 0.25 world units per metre. The power station in this scene is an original compact industrial hall, not a measured real building and not the live power-station scene. The ground uses the game's existing winter snow layer, not a separate review texture.

## Files

| File | Role |
|---|---|
| `m1a3.glb` | Hull, tracks, turret, barrel, aim markers |
| `plant.glb` | Intact hall, wreck, debris chunks, impact marker |
| `ground.glb` | Snow field mesh. Its colour is the game's winter ground array, not a map in this folder |
| `tree.glb`, `rock.glb` | Instanced props |
| `m1a3_*.png`, `plant_*.png`, `props_*.png` | Baked surface maps for the tank, the hall, and the props |
| `tread.png`, `tread_n.png` | Tileable track shoe |
| `scorch.png` | Impact mark |
| `layout.json` | Where the tank, station, trees and rocks sit |

Nothing in this folder is a third-party texture. No ambientCG set, no imported vehicle, no Decal node (scorch is a mesh quad so the Compatibility renderer draws the same mark as Mobile).
