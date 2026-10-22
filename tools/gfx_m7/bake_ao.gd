extends SceneTree
## M2.7 baked ambient occlusion (tool-time only):
##   godot --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- [scene.tscn ...]
## With no args bakes every vehicle / building view under res://view/units and res://view/buildings.
## For each generated m3-kit model: all its meshes (rest pose) become one physics trimesh, every
## vertex casts 16 short hemisphere rays (plus the ground plane at y = 0), and the occlusion is
## multiplied into the vertex colour (rgb; the part class in alpha is untouched). Lamps, glass and
## spinning wheels/fans are left unbaked. LODs are rebuilt. The mesh gets meta "ao_baked" so the
## pass is idempotent; re-running a generator produces fresh (unbaked) meshes.
## Mobile cost: zero (same vertex format and count).
const SKIP_CLS := [2, 5, 7, 8, 15, 18, 19]
const STRENGTH := 0.8
const AO_MIN := 0.32
var dirs: Array = []

func _initialize() -> void:
	_dirs()
	_run.call_deferred()

func _dirs() -> void:
	# cosine-weighted hemisphere (z up), Fibonacci spiral
	var n := 16
	for i in n:
		var u := (float(i) + 0.5) / float(n)
		var r := sqrt(u)
		var a := float(i) * 2.39996323
		dirs.append(Vector3(r * cos(a), r * sin(a), sqrt(maxf(0.0, 1.0 - u))))

func _run() -> void:
	var paths: Array = []
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		for base in ["res://view/units", "res://view/buildings"]:
			_scan(base, paths)
	else:
		paths = Array(args)
	var t0 := Time.get_ticks_msec()
	var n_done := 0
	for p in paths:
		if await _bake_scene(p):
			n_done += 1
	print("AO baked %d scenes in %.1f s" % [n_done, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)

func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))

func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)

func _bake_scene(path: String) -> bool:
	var ps: PackedScene = load(path)
	if ps == null:
		return false
	var root: Node3D = ps.instantiate()
	var mis: Array = []
	_meshes(root, mis)
	var todo: Array = []
	for mi: MeshInstance3D in mis:
		var m: ArrayMesh = mi.mesh
		if m.has_meta("ao_baked") or m.get_surface_count() != 1:
			continue
		var fmt := m.surface_get_format(0)
		if (fmt & Mesh.ARRAY_FORMAT_COLOR) == 0:
			continue
		todo.append(mi)
	if todo.is_empty():
		root.free()
		return false
	get_root().add_child(root)
	# occluders: every visible-at-rest mesh (not hidden damage / rubble / scaffold / tier parts)
	var faces := PackedVector3Array()
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for mi: MeshInstance3D in mis:
		if not mi.visible or mi.name in [&"Scaffold", &"DamageLight", &"DamageHeavy", &"Rubble"]:
			continue
		var xf := root.global_transform.affine_inverse() * mi.global_transform
		var f := (mi.mesh as ArrayMesh).get_faces()
		for i in f.size():
			var v: Vector3 = xf * f[i]
			faces.append(v)
			lo = lo.min(v)
			hi = hi.max(v)
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
	var size := (hi - lo)
	var reach := clampf(maxf(size.x, size.z) * 0.16, 0.14, 0.6)
	var q := PhysicsRayQueryParameters3D.new()
	q.hit_back_faces = true
	var tris := 0
	for mi: MeshInstance3D in todo:
		var xf2 := root.global_transform.affine_inverse() * mi.global_transform
		var m: ArrayMesh = mi.mesh
		var arr := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var cache := {}
		for i in verts.size():
			var c := cols[i]
			var cls := int(c.a * 20.0 + 0.5)
			if cls in SKIP_CLS:
				continue
			var p: Vector3 = xf2 * verts[i]
			var nn: Vector3 = (xf2.basis * nrms[i]).normalized()
			var key := Vector3i((p * 500.0).round()) * 1000 + Vector3i((nn * 50.0).round())
			var ao: float
			if cache.has(key):
				ao = cache[key]
			else:
				ao = _ao(space, q, p, nn, reach)
				cache[key] = ao
			cols[i] = Color(c.r * ao, c.g * ao, c.b * ao, c.a)
		arr[Mesh.ARRAY_COLOR] = cols
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else verts.size() / 3
		mi.mesh = _rebuild(arr, m.surface_get_material(0), m.get_surface_count() > 0 and _had_lods(m))
	body.queue_free()
	get_root().remove_child(root)
	for c in root.get_children():
		_own(c, root)
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, path)
	root.free()
	print("  AO %s: %d meshes, %d tris, reach %.2f %s" % [path.get_file(), todo.size(), tris, reach, "" if err == OK else "SAVE ERROR %d" % err])
	return true

func _own(n: Node, root: Node) -> void:
	if n.owner == null:
		n.owner = root
	for c in n.get_children():
		_own(c, root)

func _had_lods(m: ArrayMesh) -> bool:
	return RenderingServer.mesh_get_surface(m.get_rid(), 0).get("lods", []).size() > 0

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
	var ao := 1.0 - STRENGTH * occ / float(dirs.size())
	return clampf(ao, AO_MIN, 1.0)

func _rebuild(arr: Array, mat: Material, lods: bool) -> ArrayMesh:
	var m := ArrayMesh.new()
	if lods:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
		im.generate_lods(25.0, 60.0, [])
		var ld := {}
		for l in im.get_surface_lod_count(0):
			ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
	else:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	m.set_meta("ao_baked", true)
	return m
