extends SceneTree
## Builds the live M1A3 from the legacy mesh plus the approved SEP v3 fittings.
## The hull, turret plan and barrel of halberd_legacy.tscn are not rebuilt or moved.
##   godot --headless --path . -s res://tools/gfx_m7/halberd_v3detail.gd
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const OUT := "res://view/units/us/halberd_v3detail.tscn"
const SRC := "res://view/units/us/halberd_legacy.tscn"
const US := "#7e8a5c"
const US_D := "#66704a"
const US_S := "#464a46"
const GLASS_C := "#2a3a46"
const SKIP_CLS := [2, 5, 7, 8, 15, 18, 19]
const STRENGTH := 0.75
const AO_MIN := 0.42

var dirs: Array = []

func _initialize() -> void:
	var n := 16
	for i in n:
		var u := (float(i) + 0.5) / float(n)
		var r := sqrt(u)
		var a := float(i) * 2.39996323
		dirs.append(Vector3(r * cos(a), r * sin(a), sqrt(maxf(0.0, 1.0 - u))))
	_run.call_deferred()

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

func _run() -> void:
	var turret_extra := _kit(_turret_parts)
	var barrel_extra := _kit(_barrel_parts)
	var root: Node3D = (load(SRC) as PackedScene).instantiate()
	var added := 0
	var ranges := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).mesh as ArrayMesh
		if src == null:
			continue
		(mi as MeshInstance3D).mesh = src.duplicate()
	var turret := root.find_child("Turret", true, false) as MeshInstance3D
	var barrel := root.find_child("BarrelMesh", true, false) as MeshInstance3D
	ranges["Turret"] = _merge(turret, turret_extra)
	ranges["BarrelMesh"] = _merge(barrel, barrel_extra)
	added = _tris(turret_extra) + _tris(barrel_extra)
	get_root().add_child(root)
	var mis: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mis.append(mi)
	var faces := PackedVector3Array()
	for mi: MeshInstance3D in mis:
		var xf := root.global_transform.affine_inverse() * mi.global_transform
		var f := (mi.mesh as ArrayMesh).get_faces()
		for i in f.size():
			faces.append(xf * f[i])
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	get_root().add_child(body)
	await physics_frame
	await physics_frame
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.hit_back_faces = true
	for mi: MeshInstance3D in [turret, barrel]:
		_ao_new(space, q, root, mi, int(ranges[mi.name]))
	body.queue_free()
	get_root().remove_child(root)
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, OUT)
	var total := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		total += _tris((mi as MeshInstance3D).mesh)
	print("halberd_v3detail: %d tris (LOD0), +%d added, save %s" % [total, added, "OK" if err == OK else str(err)])
	root.free()
	quit(0)

func _kit(parts: Callable) -> ArrayMesh:
	var g = K.new()
	g.lods = false
	parts.call(g)
	return g.commit(load("res://view/materials/m3.tres"))

func _turret_parts(t) -> void:
	_spare_wheel(t, Vector3(0.18, 0.25, -0.36), 0.105)
	_smoke_bank(t, 1.0)
	_smoke_bank(t, -1.0)
	_tall_sights(t)

func _barrel_parts(b) -> void:
	_bore_and_mrs(b)

## Flat spare road wheel on the right turret roof. Rubber and steel stay fixed (not wheel classes).
func _spare_wheel(t, c: Vector3, r: float) -> void:
	t.color(US_S, Geo.STEEL)
	t.box(c + Vector3(0, -0.026, 0), Vector3(0.07, 0.012, 0.07))
	t.color("#1d1c1b", Geo.RUBBER)
	t.tube(c - Vector3(0, 0.016, 0), c + Vector3(0, 0.016, 0), r, 12)
	t.tube(c - Vector3(0, 0.02, 0), c - Vector3(0, 0.01, 0), r * 0.9, 12)
	t.tube(c + Vector3(0, 0.01, 0), c + Vector3(0, 0.02, 0), r * 0.9, 12)
	t.color(US_S, Geo.STEEL)
	t.tube(c - Vector3(0, 0.018, 0), c + Vector3(0, 0.022, 0), r * 0.55, 8)
	t.tube(c + Vector3(0, 0.012, 0), c + Vector3(0, 0.03, 0), r * 0.2, 6)
	for i in 5:
		var a := TAU * float(i) / 5.0
		t.box(c + Vector3(cos(a) * r * 0.36, 0.024, sin(a) * r * 0.36), Vector3(0.016, 0.01, 0.016))

## Six-tube bank on each front cheek, pitched up and out. Two staggered rows of three.
func _smoke_bank(t, side: float) -> void:
	var yaw := side * 62.0
	var dir := Vector3(sin(deg_to_rad(yaw)), 0.58, cos(deg_to_rad(yaw))).normalized()
	var across := Vector3(-dir.z * side, 0.0, dir.x * side).normalized()
	var origin := Vector3(side * 0.5, 0.16, 0.2)
	t.color(US_D, Geo.PAINT)
	t.plate(origin - dir * 0.015, Vector3(0.02, 0.07, 0.16), Vector3(-12.0, 0.0, -side * 8.0))
	t.color(US_S, Geo.STEEL)
	for i in 6:
		var o := origin + across * ((float(i) - 2.5) * 0.028) + Vector3(0, float(i % 2) * 0.03, 0)
		t.tube(o, o + dir * 0.11, 0.012, 5)

## Taller tan CITV (left) and GPS (right front) heads stacked on the existing housings.
func _tall_sights(t) -> void:
	t.color(US, Geo.PAINT)
	t.cbox(Vector3(-0.05, 0.395, 0.01), Vector3(0.11, 0.13, 0.1), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.05, 0.4, 0.064), Vector3(0.07, 0.07, 0.006))
	t.color(US, Geo.PAINT)
	t.cbox(Vector3(0.3, 0.33, 0.19), Vector3(0.14, 0.16, 0.13), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.3, 0.345, 0.258), Vector3(0.09, 0.07, 0.006))

## Bore evacuator over the barrel's existing fume bulge, plus a muzzle sensor head.
func _bore_and_mrs(b) -> void:
	var zf := lerpf(0.08, 1.14, 0.42)
	b.color(US, Geo.PAINT)
	b.tube(Vector3(0, 0, zf - 0.1), Vector3(0, 0, zf + 0.1), 0.064, 10)
	b.color(US_S, Geo.STEEL)
	b.tube(Vector3(0, 0, zf - 0.1), Vector3(0, 0, zf - 0.082), 0.07, 8)
	b.tube(Vector3(0, 0, zf + 0.082), Vector3(0, 0, zf + 0.1), 0.07, 8)
	b.tube(Vector3(0, 0.058, 1.1), Vector3(0, 0.086, 1.1), 0.008, 4)
	b.box(Vector3(0, 0.094, 1.1), Vector3(0.028, 0.016, 0.034))

## Append extra onto a duplicated mesh. Paint becomes US desert camo (class 20, pattern 3).
## Returns the original vertex count so AO can skip those vertices. LOD0 indices are rebuilt.
func _merge(mi: MeshInstance3D, extra: ArrayMesh) -> int:
	var base := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var add := extra.surface_get_arrays(0)
	var vc: int = (base[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cols: PackedColorArray = add[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = add[Mesh.ARRAY_TEX_UV2]
	for i in cols.size():
		if int(cols[i].a * 20.0 + 0.5) == 0 and uv2[i].y < 0.5:
			cols[i].a = 1.0
			uv2[i] = Vector2(3.0, 0.0)
	add[Mesh.ARRAY_COLOR] = cols
	add[Mesh.ARRAY_TEX_UV2] = uv2
	if add[Mesh.ARRAY_TANGENT] == null:
		var tg := PackedFloat32Array()
		tg.resize(cols.size() * 4)
		for i in cols.size():
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
	var ei: PackedInt32Array = add[Mesh.ARRAY_INDEX]
	for i in ei.size():
		idx.append(ei[i] + vc)
	arr[Mesh.ARRAY_INDEX] = idx
	var src: ArrayMesh = mi.mesh
	mi.mesh = _with_lods(arr, src.surface_get_material(0), src)
	return vc

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

func _with_lods(arr: Array, mat: Material, src: ArrayMesh) -> ArrayMesh:
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
	var cache := {}
	var reach := 0.22
	for ti in idx.size() / 3:
		var i0 := idx[ti * 3]
		if i0 < base_n:
			continue
		var cls := int(cols[i0].a * 20.0 + 0.5)
		if cls in SKIP_CLS:
			continue
		var ctr: Vector3 = (verts[i0] + verts[idx[ti * 3 + 1]] + verts[idx[ti * 3 + 2]]) / 3.0
		for k in 3:
			var vi := idx[ti * 3 + k]
			var pl: Vector3 = verts[vi].lerp(ctr, 0.35)
			var p: Vector3 = xf * pl
			var nn: Vector3 = (xf.basis * nrms[vi]).normalized()
			var key := Vector3i((p * 400.0).round()) * 1000 + Vector3i((nn * 50.0).round())
			var ao: float = cache[key] if cache.has(key) else _ao(space, q, p, nn, reach)
			cache[key] = ao
			acc[vi] += ao
			cnt[vi] += 1
	for i in range(base_n, verts.size()):
		if cnt[i] == 0:
			continue
		var ao2 := acc[i] / float(cnt[i])
		var c := cols[i]
		cols[i] = Color(c.r * ao2, c.g * ao2, c.b * ao2, c.a)
	arr[Mesh.ARRAY_COLOR] = cols
	mi.mesh = _with_lods(arr, m.surface_get_material(0), m)

func _ao(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, p: Vector3, n: Vector3, reach: float) -> float:
	var t := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := n.cross(t)
	var o := p + n * 0.004
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
	return clampf(1.0 - STRENGTH * occ / float(dirs.size()), AO_MIN, 1.0)

func _tris(m: ArrayMesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		t += m.surface_get_array_index_len(s) / 3
	return t
