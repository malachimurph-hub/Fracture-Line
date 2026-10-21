class_name ParticleLayer
extends MultiMeshInstance3D
## CPU particle layer drawn as ONE MultiMesh (one draw call): smoke, dust, fire puffs or
## debris chunks. Fixed capacity ring buffer; oldest particle is recycled when full.
## Purely visual (never touches the simulation).

var cap: int
var billboard: bool
var gravity: float
var drag: float
var pos: PackedVector3Array
var vel: PackedVector3Array
var age: PackedFloat32Array
var life: PackedFloat32Array
var s0: PackedFloat32Array
var s1: PackedFloat32Array
var c0: PackedColorArray
var c1: PackedColorArray
var rot: PackedFloat32Array
var spin: PackedFloat32Array
var seed: PackedFloat32Array
var heat: PackedFloat32Array
var next := 0
var live := 0
var buf: PackedFloat32Array

func setup(capacity: int, mesh: Mesh, mat: Material, is_billboard: bool, grav: float, drg: float) -> void:
	cap = capacity
	billboard = is_billboard
	gravity = grav
	drag = drg
	for a in ["pos", "vel"]:
		var v := PackedVector3Array(); v.resize(cap); set(a, v)
	for a in ["age", "life", "s0", "s1", "rot", "spin", "seed", "heat"]:
		var f := PackedFloat32Array(); f.resize(cap); set(a, f)
	for a in ["c0", "c1"]:
		var c := PackedColorArray(); c.resize(cap); set(a, c)
	for i in cap:
		age[i] = 1.0
		life[i] = 0.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if billboard else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	buf.resize(cap * 20)
	custom_aabb = AABB(Vector3(-50, -10, -50), Vector3(400, 80, 400))

func emit(p: Vector3, v: Vector3, lifetime: float, size_from: float, size_to: float, col_from: Color, col_to: Color, h: float = 0.0) -> void:
	var i := next
	next = (next + 1) % cap
	pos[i] = p
	vel[i] = v
	age[i] = 0.0
	life[i] = lifetime
	s0[i] = size_from
	s1[i] = size_to
	c0[i] = col_from
	c1[i] = col_to
	rot[i] = randf() * TAU
	spin[i] = randf_range(-1.5, 1.5) if billboard else randf_range(-8.0, 8.0)
	seed[i] = randf()
	heat[i] = h

func _process(delta: float) -> void:
	var n := 0
	var dmp := maxf(0.0, 1.0 - drag * delta)
	for i in cap:
		if age[i] >= life[i]:
			continue
		age[i] += delta
		if age[i] >= life[i]:
			continue
		var v := vel[i]
		v.y -= gravity * delta
		v *= dmp
		var p := pos[i] + v * delta
		if not billboard and p.y < 0.03:
			p.y = 0.03
			v = Vector3(v.x * 0.4, -v.y * 0.25, v.z * 0.4)
			spin[i] *= 0.5
		pos[i] = p
		vel[i] = v
		rot[i] += spin[i] * delta
		var k := age[i] / life[i]
		var s := lerpf(s0[i], s1[i], k)
		var c := c0[i].lerp(c1[i], k)
		var o := n * 20
		if billboard:
			buf[o] = 1.0; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = p.x
			buf[o + 4] = 0.0; buf[o + 5] = 1.0; buf[o + 6] = 0.0; buf[o + 7] = p.y
			buf[o + 8] = 0.0; buf[o + 9] = 0.0; buf[o + 10] = 1.0; buf[o + 11] = p.z
		else:
			var b := Basis(Vector3(0.3, 1, 0.5).normalized(), rot[i]).scaled(Vector3.ONE * s)
			buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = p.x
			buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = p.y
			buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = p.z
		buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
		buf[o + 16] = s; buf[o + 17] = rot[i]; buf[o + 18] = seed[i]; buf[o + 19] = heat[i]
		n += 1
	live = n
	if n > 0:
		multimesh.buffer = buf
	multimesh.visible_instance_count = n
