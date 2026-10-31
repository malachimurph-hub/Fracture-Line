class_name OilLoad
## M3.5 crude oil export: supply trucks / pickups show the oil drums they carry - up to MAX
## drums stand in the bed (or on the back) as the load grows while they harvest, gone when they
## unload at the depot. One cached mesh per drum count on the vehicle m3 surface; view only.
const MAX := 6
const LIFT := 0.15   ## mesh-space height (the m3 surface darkens parts near its own y = 0)
const COLS := [Color("#2f4560"), Color("#7a2b22"), Color("#2c2d2b"), Color("#4a5a3a")]
static var _meshes: Dictionary = {}

## n drums for carry / capacity on vehicle view v (creates / updates its "OilLoad" child).
static func update(v: Node3D, carry: int, capacity: int) -> void:
	var n := 0 if carry <= 0 or capacity <= 0 else clampi(int(ceil(float(carry) * MAX / capacity)), 1, MAX)
	var mi: MeshInstance3D = v.get_node_or_null("OilLoad")
	if mi == null:
		if n == 0:
			return
		mi = MeshInstance3D.new()
		mi.name = "OilLoad"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bb := _bounds(v)
		# the rear part of the vehicle, on top of the bed / load floor
		mi.position = Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.42, bb.position.z + bb.size.z * 0.27)
		var s := clampf(bb.size.x / 0.75, 0.6, 1.3)
		mi.scale = Vector3.ONE * s
		mi.position.y -= LIFT * s
		v.add_child(mi)
		mi.set_meta("n", -1)
	if int(mi.get_meta("n")) == n:
		return
	mi.set_meta("n", n)
	mi.visible = n > 0
	if n > 0:
		mi.mesh = _mesh(n)

static func _bounds(v: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	var inv := v.global_transform.affine_inverse() if v.is_inside_tree() else Transform3D()
	for g in v.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or mi.name == "OilLoad":
			continue
		var x := (inv * mi.global_transform) if v.is_inside_tree() else mi.transform
		var b := x * mi.mesh.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb if not first else AABB(Vector3(-0.3, 0, -0.5), Vector3(0.6, 0.5, 1.0))

static func _mesh(n: int) -> ArrayMesh:
	if _meshes.has(n):
		return _meshes[n]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var c := Vector3((i % 2 - 0.5) * 0.11, LIFT, -(i / 2) * 0.1 + 0.1)
		_drum(st, c, COLS[i % COLS.size()])
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, load("res://view/materials/m3.tres"))
	_meshes[n] = m
	return m

static func _drum(st: SurfaceTool, c: Vector3, col: Color) -> void:
	const SEG := 10
	const R := 0.045
	const H := 0.12
	col.a = 0.0   # m3 class 0: painted metal
	st.set_color(col)
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		var p0 := c + Vector3(cos(a0) * R, 0, sin(a0) * R)
		var p1 := c + Vector3(cos(a1) * R, 0, sin(a1) * R)
		var q0 := p0 + Vector3(0, H, 0)
		var q1 := p1 + Vector3(0, H, 0)
		st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(q1)   # clockwise = front in Godot
		st.add_vertex(p0); st.add_vertex(q1); st.add_vertex(q0)
		var top := c + Vector3(0, H, 0)
		st.add_vertex(top); st.add_vertex(q0); st.add_vertex(q1)
