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
