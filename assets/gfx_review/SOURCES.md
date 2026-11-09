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

The tank follows public Abrams-family figures so it reads as the in-game M1A3: hull about 7.93 m, gun forward about 9.77 m, width about 3.66 m, height about 2.44 m. The game scale is 0.25 world units per metre, the same scale as the civilian cars. The power station is an original compact industrial hall (layered roof, pipes, two stacks) sized like a 4-tile structure. It is not the live Nuclear Power Station scene.

## Files

| File | Role |
|---|---|
| `m1a3.glb` | Hull, tracks, turret, barrel, aim markers |
| `plant.glb` | Intact hall, wreck, debris chunks, impact marker |
| `ground.glb` | Snow field mesh |
| `tree.glb`, `rock.glb` | Instanced props |
| `*_albedo.png`, `*_normal.png`, `*_orm.png` | Baked surface maps |
| `tread.png`, `tread_n.png` | Tileable track shoe |
| `scorch.png` | Impact mark |
| `layout.json` | Where the tank, station, trees and rocks sit |

Nothing in this folder is a third-party texture. No ambientCG set, no imported vehicle, no Decal node (scorch is a mesh quad so the Compatibility renderer draws the same mark as Mobile).
