class_name StreakLayer
extends MultiMeshInstance3D
## Fixed-capacity pool of camera-facing ribbons drawn as ONE MultiMesh (one draw call):
## tracers, shells, rocket flares, muzzle tongues (view/vfx/streak*.gdshader). Rebuilt every
## frame from the live projectiles: begin(), put() per streak, end(). View only.
var cap := 0
var n := 0
var buf: PackedFloat32Array
var dropped := 0               ## streaks that did not fit this frame (stats)

func setup(capacity: int, additive: bool) -> void:
	cap = capacity
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = cap
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/vfx/streak_add.gdshader" if additive else "res://view/vfx/streak_mix.gdshader")
	mat.render_priority = 4 if additive else 1
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-50, -10, -50), Vector3(400, 80, 400))
	buf.resize(cap * 20)

func begin() -> void:
	n = 0

## A ribbon from tail to head, half width w, colour col, core boost (hot centre) core.
func put(head: Vector3, tail: Vector3, w: float, col: Color, core: float = 1.0) -> void:
	if n >= cap:
		dropped += 1
		return
	var o := n * 20
	var ax := tail - head
	buf[o] = ax.x; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = head.x
	buf[o + 4] = ax.y; buf[o + 5] = 1.0; buf[o + 6] = 0.0; buf[o + 7] = head.y
	buf[o + 8] = ax.z; buf[o + 9] = 0.0; buf[o + 10] = 1.0; buf[o + 11] = head.z
	buf[o + 12] = col.r; buf[o + 13] = col.g; buf[o + 14] = col.b; buf[o + 15] = col.a
	buf[o + 16] = w; buf[o + 17] = core; buf[o + 18] = 0.0; buf[o + 19] = 0.0
	n += 1

func end() -> void:
	if n > 0:
		multimesh.buffer = buf
	multimesh.visible_instance_count = n
