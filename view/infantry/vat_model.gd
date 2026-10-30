class_name VatModel
extends Resource
## Baked vertex-animation model (M2.2): a decimated, merged soldier mesh whose vertices are
## driven entirely by textures, so a whole squad (or a 150-soldier crowd) draws as one
## MultiMesh with no skeletons on the CPU. Baked offline by tools/bake_infantry.gd from CC0
## Quaternius characters. Vertex id lives in UV2 (x + y * 256).
## pos_tex: RGBAH, one texel per vertex, `rows` texel rows per frame, frames stacked in y.
## nrm_tex: RGBA8 normals (n * 0.5 + 0.5), same layout.
@export var mesh: ArrayMesh
@export var pos_tex: Texture2D
@export var nrm_tex: Texture2D
@export var width: int = 1
@export var rows: int = 1
@export var vertex_count: int = 0
## name -> [first_frame, frame_count, fps, loop(0/1)]
@export var anims: Dictionary = {}
@export var height: float = 0.5
@export var source: String = ""
## M3.4: look variants baked into the mesh (vertex variant masks; the view picks one per soldier)
@export var variants: int = 1
## M3.4: 0 = always fires standing, 1 = some soldiers kneel to fire, 2 = always kneels (marksmen)
@export var fire_kneel: int = 0
## vertex colour packing: 1 = M2.6 (B + 1000 * team), 2 = M3.4 (B + 256 * (flags + 16 * mask))
@export var fmt: int = 1
## fmt 3 (M3.4 compact VAT): pos_tex RGBA8 = position packed 11/11/10 bits over pos_min..pos_max,
## nrm_tex RG8 = octahedral normal
@export var pos_min: Vector3 = Vector3.ZERO
@export var pos_max: Vector3 = Vector3.ONE
