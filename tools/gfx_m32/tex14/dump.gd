extends SceneTree
## M3.2 item 14 (tool-time): dump every m3-kit mesh of the vehicle / building views to raw
## arrays for the Python detail + texture baker (tools/gfx_m32/tex14/bake.py).
##   godot --headless --path . -s res://tools/gfx_m32/tex14/dump.gd -- <out_dir> [scene.tscn ...]
## Per scene: <name>.json (mesh list: node path, rest transform in scene space, visibility,
## counts) + <name>.bin (per mesh: float32 pos3 nrm3 col4 uv2 uv2_2, then int32 indices).
const SKIP_NODES := [&"Scaffold", &"DamageLight", &"DamageHeavy", &"Rubble"]

func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out_dir: String = args.pop_front()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var paths: Array = args
	if paths.is_empty():
		for base in ["res://view/units", "res://view/buildings", "res://view/neutral"]:
			_scan(base, paths)
	var n := 0
	for p in paths:
		if _dump(p, out_dir):
			n += 1
	print("DUMPED %d scenes" % n)
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

func _dump(path: String, out_dir: String) -> bool:
	var ps: PackedScene = load(path)
	if ps == null:
		return false
	var root: Node = ps.instantiate()
	if not root is Node3D:
		root.free()
		return false
	var meshes: Array = []
	var buf := StreamPeerBuffer.new()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		if m == null or m.get_surface_count() != 1:
			continue
		var mat := m.surface_get_material(0)
		if mat == null or not mat.resource_path.ends_with("m3.tres"):
			continue
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var u: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var u2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var off := buf.get_position()
		for i in v.size():
			buf.put_float(v[i].x); buf.put_float(v[i].y); buf.put_float(v[i].z)
			buf.put_float(nr[i].x); buf.put_float(nr[i].y); buf.put_float(nr[i].z)
			var cc: Color = c[i] if c.size() > i else Color.WHITE
			buf.put_float(cc.r); buf.put_float(cc.g); buf.put_float(cc.b); buf.put_float(cc.a)
			var a: Vector2 = u[i] if u.size() > i else Vector2.ZERO
			var b: Vector2 = u2[i] if u2.size() > i else Vector2.ZERO
			buf.put_float(a.x); buf.put_float(a.y); buf.put_float(b.x); buf.put_float(b.y)
		for i in idx.size():
			buf.put_32(idx[i])
		var xf := Transform3D.IDENTITY
		var nd: Node = mi
		var vis := true
		var skip := false
		while nd != root:
			if nd is Node3D:
				xf = (nd as Node3D).transform * xf
				vis = vis and (nd as Node3D).visible
			skip = skip or nd.name in SKIP_NODES
			nd = nd.get_parent()
		var bs := xf.basis
		meshes.append({"path": String(root.get_path_to(mi)), "off": off, "nv": v.size(), "ni": idx.size(),
			"xf": [bs.x.x, bs.x.y, bs.x.z, bs.y.x, bs.y.y, bs.y.z, bs.z.x, bs.z.y, bs.z.z, xf.origin.x, xf.origin.y, xf.origin.z],
			"visible": vis and not skip, "lods": RenderingServer.mesh_get_surface(m.get_rid(), 0).get("lods", []).size() > 0,
			"ao_baked": m.has_meta("ao_baked"), "detail14": m.has_meta("detail14")})
	root.free()
	if meshes.is_empty():
		return false
	var nm := path.trim_prefix("res://view/").replace("/", "__").trim_suffix(".tscn")
	var f := FileAccess.open(out_dir.path_join(nm + ".bin"), FileAccess.WRITE)
	f.store_buffer(buf.data_array)
	f.close()
	var j := FileAccess.open(out_dir.path_join(nm + ".json"), FileAccess.WRITE)
	j.store_string(JSON.stringify({"scene": path, "meshes": meshes}))
	j.close()
	return true
