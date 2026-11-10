extends SceneTree
## Live T-90M: the shipped mesh plus photo fittings. Shape is not rebuilt.
## ActiveArmor is a hidden child (hull under Model, turret blocks under TurretPivot).
##   godot --headless --path . -s res://tools/gfx_m30/t90_detail.gd
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const SRC := "res://view/units/ecc/t90_legacy.tscn"
const OUT := "res://view/units/ecc/t90.tscn"
const GREEN := "#B4C97A"
const RU_S := "#3a3d38"
const GLASS_C := "#2a3a46"
const MAT := "res://view/materials/m3.tres"

var dirs: Array = []

func _initialize() -> void:
	for i in 16:
		var u := (float(i) + 0.5) / 16.0
		var r := sqrt(u)
		var a := float(i) * 2.39996323
		dirs.append(Vector3(r * cos(a), r * sin(a), sqrt(maxf(0.0, 1.0 - u))))
	_run.call_deferred()

func _run() -> void:
	var root: Node3D = (load(SRC) as PackedScene).instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).mesh = (mi as MeshInstance3D).mesh.duplicate()
	var turret := root.find_child("Turret", true, false) as MeshInstance3D
	var barrel := root.find_child("BarrelMesh", true, false) as MeshInstance3D
	var hull := root.find_child("Hull", true, false) as MeshInstance3D
	var mat: Material = load(MAT)
	var before := _tris(hull.mesh) + _tris(turret.mesh) + _tris(barrel.mesh)
	var t_add := _kit(_turret_parts, mat)
	var b_add := _kit(_barrel_parts, mat)
	var base_t := _merge(turret, t_add)
	var base_b := _merge(barrel, b_add)
	_recolor(hull)
	_recolor(turret)
	_recolor(barrel)
	var model := root.find_child("Model", true, false) as Node3D
	var piv := root.find_child("TurretPivot", true, false) as Node3D
	var hull_armor := _own(model, root, "ActiveArmor", _kit(_hull_armor, mat))
	var tur_armor := _own(piv, root, "ActiveArmor", _kit(_turret_armor, mat))
	get_root().add_child(root)
	var body := _collider(root)
	get_root().add_child(body)
	await physics_frame
	await physics_frame
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.hit_back_faces = true
	_ao_new(space, q, root, turret, base_t)
	_ao_new(space, q, root, barrel, base_b)
	_ao_new(space, q, root, hull_armor, 0)
	_ao_new(space, q, root, tur_armor, 0)
	body.queue_free()
	get_root().remove_child(root)
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, OUT)
	var total := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "ActiveArmor":
			continue
		total += _tris(mi.mesh)
	var armor := _tris(hull_armor.mesh) + _tris(tur_armor.mesh)
	print("t90 live %d tris (was %d, +%d) armor %d save %s" % [total, before, total - before, armor, "OK" if err == OK else str(err)])
	root.free()
	quit(0)

func _kit(parts: Callable, mat: Material) -> ArrayMesh:
	var g = K.new()
	g.lods = false
	parts.call(g)
	return g.commit(mat)

func _turret_parts(t) -> void:
	# Taller panoramic sight stacked beside the existing commander sight.
	t.color(GREEN, Geo.PAINT)
	t.cbox(Vector3(-0.26, 0.42, -0.02), Vector3(0.12, 0.14, 0.12), 0.01)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.26, 0.44, 0.042), Vector3(0.08, 0.06, 0.006))
	# Remote weapon station above the existing roof gun.
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(-0.28, 0.5, -0.22), Vector3(0.12, 0.07, 0.14), 0.01)
	t.tube(Vector3(-0.28, 0.52, -0.16), Vector3(-0.28, 0.52, 0.12), 0.014, 6)
	t.tube(Vector3(-0.28, 0.44, -0.22), Vector3(-0.28, 0.5, -0.22), 0.012, 5)
	# Smoke banks, one each side, pitched up and out.
	_bank(t, 1.0)
	_bank(t, -1.0)
	# Extra stowage on the existing rear bustle, plus a second antenna.
	t.color("#5a5344", Geo.CANVAS)
	t.cbox(Vector3(0.18, 0.3, -0.62), Vector3(0.22, 0.1, 0.16), 0.02)
	V4._antenna(t, Vector3(-0.34, 0.26, -0.46), 0.55)

func _barrel_parts(b) -> void:
	# Thermal sleeve over the existing tube. The fume bulge stays.
	b.color(GREEN, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.18), Vector3(0, 0, 0.95), 0.058, 8)
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0, 0, 0.18), Vector3(0, 0, 0.22), 0.064, 8)
	b.tube(Vector3(0, 0, 0.91), Vector3(0, 0, 0.95), 0.064, 8)

func _bank(t, side: float) -> void:
	var yaw := side * 55.0
	var dir := Vector3(sin(deg_to_rad(yaw)), 0.5, cos(deg_to_rad(yaw))).normalized()
	var origin := Vector3(side * 0.5, 0.2, 0.08)
	t.color(GREEN, Geo.PAINT)
	t.plate(origin - dir * 0.02, Vector3(0.02, 0.08, 0.16), Vector3(-10, 0, -side * 6))
	t.color(RU_S, Geo.STEEL)
	for i in 6:
		var o := origin + Vector3(0, (float(i % 2) - 0.5) * 0.03, (float(i / 2) - 1.0) * 0.034)
		t.tube(o, o + dir * 0.1, 0.012, 5)

func _hull_armor(h) -> void:
	h.color(GREEN, Geo.PAINT)
	for i in 5:
		h.rcbox(Vector3(-0.4 + i * 0.2, 0.46, 0.94), Vector3(0.17, 0.05, 0.16), 0.006, Vector3(-16, 0, 0))
	for s in [-1.0, 1.0]:
		for i in 4:
			h.box(Vector3(s * 0.74, 0.34, 0.62 - i * 0.38), Vector3(0.05, 0.16, 0.32))

func _turret_armor(t) -> void:
	t.color(GREEN, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.rcbox(Vector3(s * 0.34, 0.16, 0.36), Vector3(0.16, 0.12, 0.18), 0.008, Vector3(-28, s * 22, 0))
		t.rcbox(Vector3(s * 0.2, 0.2, 0.44), Vector3(0.14, 0.1, 0.12), 0.006, Vector3(-32, s * 12, 0))
	for i in 3:
		t.box(Vector3(-0.22 + i * 0.22, 0.28, 0.2), Vector3(0.18, 0.04, 0.16))

func _own(parent: Node3D, root: Node, name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name
	n.visible = false
	n.mesh = mesh
	parent.add_child(n)
	n.owner = root
	return n

func _merge(mi: MeshInstance3D, extra: ArrayMesh) -> int:
	var base := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var add := extra.surface_get_arrays(0)
	var vc: int = (base[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if add[Mesh.ARRAY_TANGENT] == null:
		var tg := PackedFloat32Array()
		tg.resize((add[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4)
		for i in tg.size() / 4:
			tg[i * 4] = 1.0
			tg[i * 4 + 3] = 1.0
		add[Mesh.ARRAY_TANGENT] = tg
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _cat3(base[Mesh.ARRAY_VERTEX], add[Mesh.ARRAY_VERTEX])
	arr[Mesh.ARRAY_NORMAL] = _cat3(base[Mesh.ARRAY_NORMAL], add[Mesh.ARRAY_NORMAL])
	arr[Mesh.ARRAY_TANGENT] = _catf(base[Mesh.ARRAY_TANGENT], add[Mesh.ARRAY_TANGENT])
	arr[Mesh.ARRAY_COLOR] = _catc(base[Mesh.ARRAY_COLOR], add[Mesh.ARRAY_COLOR])
	arr[Mesh.ARRAY_TEX_UV] = _cat2(base[Mesh.ARRAY_TEX_UV], add[Mesh.ARRAY_TEX_UV])
	arr[Mesh.ARRAY_TEX_UV2] = _cat2(base[Mesh.ARRAY_TEX_UV2], add[Mesh.ARRAY_TEX_UV2])
	var idx: PackedInt32Array = (base[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	for i in (add[Mesh.ARRAY_INDEX] as PackedInt32Array).size():
		idx.append((add[Mesh.ARRAY_INDEX] as PackedInt32Array)[i] + vc)
	arr[Mesh.ARRAY_INDEX] = idx
	mi.mesh = _lods(arr, mi.mesh)
	return vc

func _recolor(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	var arr := src.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var tan := Color(GREEN)
	var tl := tan.get_luminance()
	for i in cols.size():
		var c := cols[i]
		var cls := int(c.a * 20.0 + 0.5)
		if cls != 0 and cls != 20:
			continue
		var k := clampf(c.get_luminance() / maxf(tl, 0.001), 0.42, 1.15)
		cols[i] = Color(tan.r * k, tan.g * k, tan.b * k, c.a)
	arr[Mesh.ARRAY_COLOR] = cols
	mi.mesh = _lods(arr, src)

func _lods(arr: Array, src: ArrayMesh) -> ArrayMesh:
	var mat := src.surface_get_material(0)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat)
	im.generate_lods(25.0, 60.0, [])
	var ld := {}
	for l in im.get_surface_lod_count(0):
		ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
	m.surface_set_material(0, mat)
	for k in src.get_meta_list():
		m.set_meta(k, src.get_meta(k))
	m.set_meta("ao_baked", true)
	m.set_meta("camo", true)
	return m

func _collider(root: Node3D) -> StaticBody3D:
	var faces := PackedVector3Array()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := root.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		var f := ((mi as MeshInstance3D).mesh as ArrayMesh).get_faces()
		for i in f.size():
			faces.append(xf * f[i])
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	return body

func _ao_new(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, root: Node3D, mi: MeshInstance3D, base_n: int) -> void:
	var m := mi.mesh as ArrayMesh
	var arr := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var xf := root.global_transform.affine_inverse() * mi.global_transform
	var acc := PackedFloat32Array()
	acc.resize(verts.size())
	var cnt := PackedInt32Array()
	cnt.resize(verts.size())
	for ti in idx.size() / 3:
		var i0 := idx[ti * 3]
		if i0 < base_n:
			continue
		var cls := int(cols[i0].a * 20.0 + 0.5)
		if cls == 2 or cls == 5:
			continue
		var ctr: Vector3 = (verts[i0] + verts[idx[ti * 3 + 1]] + verts[idx[ti * 3 + 2]]) / 3.0
		for k in 3:
			var vi := idx[ti * 3 + k]
			var p: Vector3 = xf * verts[vi].lerp(ctr, 0.35)
			var nn: Vector3 = (xf.basis * nrms[vi]).normalized()
			var ao := _ao(space, q, p, nn)
			acc[vi] += ao
			cnt[vi] += 1
	for i in range(base_n, verts.size()):
		if cnt[i] == 0:
			continue
		var ao2 := acc[i] / float(cnt[i])
		var c := cols[i]
		cols[i] = Color(c.r * ao2, c.g * ao2, c.b * ao2, c.a)
	arr[Mesh.ARRAY_COLOR] = cols
	mi.mesh = _lods(arr, m)

func _ao(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, p: Vector3, n: Vector3) -> float:
	var t := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := n.cross(t)
	var o := p + n * 0.004
	var reach := 0.2
	var occ := 0.0
	for d: Vector3 in dirs:
		var w := (t * d.x + b * d.y + n * d.z).normalized()
		var hit_t := reach
		if w.y < -0.01 and o.y >= 0.0:
			hit_t = minf(hit_t, o.y / -w.y)
		q.from = o
		q.to = o + w * reach
		var r := space.intersect_ray(q)
		if not r.is_empty():
			hit_t = minf(hit_t, o.distance_to(r["position"]))
		if hit_t < reach:
			occ += 1.0 - hit_t / reach
	return clampf(1.0 - 0.75 * occ / float(dirs.size()), 0.42, 1.0)

func _cat3(a: PackedVector3Array, b: PackedVector3Array) -> PackedVector3Array:
	var o := a.duplicate()
	o.append_array(b)
	return o

func _cat2(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var o := a.duplicate()
	o.append_array(b)
	return o

func _catc(a: PackedColorArray, b: PackedColorArray) -> PackedColorArray:
	var o := a.duplicate()
	o.append_array(b)
	return o

func _catf(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var o := a.duplicate()
	o.append_array(b)
	return o

func _tris(m: ArrayMesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		t += m.surface_get_array_index_len(s) / 3
	return t
