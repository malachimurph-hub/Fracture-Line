extends SceneTree
## M2.7: give every vehicle / building view mesh that has no LOD chain one (older M2.2-M2.6
## models such as the Leopold shipped LOD0 only, so big fights drew full detail at any range).
## View-only resource change: same vertices, same surfaces/materials, extra index LODs.
##   godot --headless --path . -s res://tools/gfx_m7/add_lods.gd [-- scene.tscn ...]
const MIN_TRIS := 120

func _initialize() -> void:
	var paths: Array = Array(OS.get_cmdline_user_args())
	if paths.is_empty():
		for base in ["res://view/units", "res://view/buildings"]:
			_scan(base, paths)
	var n_scenes := 0
	var n_meshes := 0
	for p in paths:
		var ps: PackedScene = load(p)
		if ps == null:
			continue
		var root: Node = ps.instantiate()
		var changed := 0
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh as ArrayMesh
			if m == null or _has_lods(m) or _tris(m) < MIN_TRIS:
				continue
			(mi as MeshInstance3D).mesh = _with_lods(m)
			changed += 1
		if changed > 0:
			var out := PackedScene.new()
			out.pack(root)
			var err := ResourceSaver.save(out, p)
			print("  LODs %s: %d meshes %s" % [p.get_file(), changed, "" if err == OK else "SAVE ERROR %d" % err])
			n_scenes += 1
			n_meshes += changed
		root.free()
	print("LODs added to %d meshes in %d scenes" % [n_meshes, n_scenes])
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

func _has_lods(m: ArrayMesh) -> bool:
	for s in m.get_surface_count():
		if RenderingServer.mesh_get_surface(m.get_rid(), s).get("lods", []).size() > 0:
			return true
	return false

func _tris(m: ArrayMesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		t += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t

func _with_lods(m: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s in m.get_surface_count():
		im.add_surface(m.surface_get_primitive_type(s), m.surface_get_arrays(s), [], {}, m.surface_get_material(s), m.surface_get_name(s))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	for s in im.get_surface_count():
		var ld := {}
		for l in im.get_surface_lod_count(s):
			ld[im.get_surface_lod_size(s, l)] = im.get_surface_lod_indices(s, l)
		out.add_surface_from_arrays(im.get_surface_primitive_type(s), im.get_surface_arrays(s), [], ld)
		out.surface_set_material(s, im.get_surface_material(s))
	for k in m.get_meta_list():
		out.set_meta(k, m.get_meta(k))
	return out
