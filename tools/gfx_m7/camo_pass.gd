extends SceneTree
## M2.7b faction camo (tool-time only, view-only resource change):
##   godot --headless --path . -s res://tools/gfx_m7/camo_pass.gd [-- scene.tscn ...]
## With no args processes every vehicle view under res://view/units. Plain paint (class 0) on the
## hull / turret / barrel meshes becomes camo paint (class 20) with the faction pattern in UV2.x
## (0 US soft three-tone, 1 EU splinter, 2 TPLA sprayed bands; see model_m3.gdshaderinc). Paint
## flagged plain by the generator (UV2.y = 1, e.g. safety-yellow dozer parts) is kept. Same
## vertex format, count and LOD chain; idempotent (mesh meta "camo").
const PAT := {"us": 3, "eu": 1, "tpla": 2}   # M3.0: every US vehicle is desert tan
## M3.0 per-vehicle overrides (3 = US desert tan, 4 = woodland, unused since M3.0 all-tan)
const PAT_FILE := {"us/wraith": 0, "us/thunderlance": 0, "us/dozer": 0, "us/supply_truck": 0, "us/longreach": 0}   # pattern 0 = original US olive-green blotches (jets: their own grey)

func _initialize() -> void:
	var paths: Array = Array(OS.get_cmdline_user_args())
	if paths.is_empty():
		_scan("res://view/units", paths)
	var n := 0
	for p in paths:
		var fac := String(p).get_base_dir().get_file()
		if not PAT.has(fac):
			continue
		var ps: PackedScene = load(p)
		if ps == null:
			continue
		var root: Node = ps.instantiate()
		var scr: Script = root.get_script()
		if scr == null or not scr.resource_path.ends_with("vehicle_view.gd"):
			root.free()
			continue
		var changed := 0
		var verts := 0
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh as ArrayMesh
			if m == null or m.has_meta("camo") or m.get_surface_count() != 1:
				continue
			var arr := m.surface_get_arrays(0)
			if arr[Mesh.ARRAY_COLOR] == null or arr[Mesh.ARRAY_TEX_UV2] == null:
				continue
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			var k := 0
			for i in cols.size():
				if int(cols[i].a * 20.0 + 0.5) == 0 and uv2[i].y < 0.5:
					cols[i].a = 1.0
					uv2[i] = Vector2(float(PAT_FILE.get(fac + "/" + String(p).get_file().get_basename(), PAT[fac])), 0.0)
					k += 1
			if k == 0:
				continue
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_TEX_UV2] = uv2
			(mi as MeshInstance3D).mesh = _rebuild(m, arr)
			changed += 1
			verts += k
		if changed > 0:
			var out := PackedScene.new()
			out.pack(root)
			var err := ResourceSaver.save(out, p)
			print("  CAMO %s: %d meshes, %d verts %s" % [p.get_file(), changed, verts, "" if err == OK else "SAVE ERROR %d" % err])
			n += 1
		root.free()
	print("camo pass: %d scenes" % n)
	quit()

func _scan(dir: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir + "/" + f)

func _rebuild(m: ArrayMesh, arr: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	var lods: bool = RenderingServer.mesh_get_surface(m.get_rid(), 0).get("lods", []).size() > 0
	if lods:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
		im.generate_lods(25.0, 60.0, [])
		var ld := {}
		for l in im.get_surface_lod_count(0):
			ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
	else:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	out.surface_set_material(0, m.surface_get_material(0))
	for k in m.get_meta_list():
		out.set_meta(k, m.get_meta(k))
	out.set_meta("camo", true)
	return out
