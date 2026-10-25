extends SceneTree
## M3.2 item 14 (tool-time): write the bake placement into the view scenes: per MeshInstance3D
## instance uniforms bake_o / bake_s / bake_r (see model_m3.gdshaderinc). With a mesh override
## dir (from the detail pass in detail.py) the mesh arrays are replaced first (LODs rebuilt).
##   godot --headless --path . -s res://tools/gfx_m32/tex14/apply.gd -- <placement.json> [mesh_dir]
const STRENGTH := 1.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var pl: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var mesh_dir: String = args[1] if args.size() > 1 else ""
	var n := 0
	for scene in pl["scenes"]:
		var e: Dictionary = pl["scenes"][scene]
		var ps: PackedScene = load(scene)
		if ps == null:
			continue
		var root: Node = ps.instantiate()
		var nm := String(scene).trim_prefix("res://view/").replace("/", "__").trim_suffix(".tscn")
		var swapped := 0
		if mesh_dir != "" and FileAccess.file_exists(mesh_dir.path_join(nm + ".json")):
			swapped = _swap_meshes(root, mesh_dir, nm)
		var set_n := 0
		for path in e["meshes"]:
			var mi := root.get_node_or_null(NodePath(path)) as MeshInstance3D
			if mi == null:
				continue
			var v: Array = e["meshes"][path]
			mi.set_instance_shader_parameter(&"bake_o", Vector4(v[0], v[1], v[2], float(e["layer"])))
			mi.set_instance_shader_parameter(&"bake_s", Vector4(v[3], v[4], v[5], STRENGTH))
			mi.set_instance_shader_parameter(&"bake_r", Vector4(v[6], v[7], v[8], v[9]))
			set_n += 1
		var out := PackedScene.new()
		out.pack(root)
		var err := ResourceSaver.save(out, scene)
		root.free()
		n += 1
		print("  BAKE %s: %d meshes%s %s" % [nm, set_n, (", %d new meshes" % swapped) if swapped else "", "" if err == OK else "SAVE ERROR %d" % err])
	print("APPLIED %d scenes" % n)
	quit(0)

## detail.py output: dump.gd layout (<nm>.json "meshes" list + <nm>.bin); only meshes flagged
## "changed" are replaced
func _swap_meshes(root: Node, dir: String, nm: String) -> int:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(nm + ".json")))
	var buf := StreamPeerBuffer.new()
	buf.data_array = FileAccess.get_file_as_bytes(dir.path_join(nm + ".bin"))
	var k := 0
	for d: Dictionary in j["meshes"]:
		if not d.get("changed", false):
			continue
		var mi := root.get_node_or_null(NodePath(String(d["path"]))) as MeshInstance3D
		if mi == null:
			continue
		var old := mi.mesh as ArrayMesh
		buf.seek(int(d["off"]))
		var nv := int(d["nv"])
		var v := PackedVector3Array(); v.resize(nv)
		var nr := PackedVector3Array(); nr.resize(nv)
		var c := PackedColorArray(); c.resize(nv)
		var u := PackedVector2Array(); u.resize(nv)
		var u2 := PackedVector2Array(); u2.resize(nv)
		for i in nv:
			v[i] = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
			nr[i] = Vector3(buf.get_float(), buf.get_float(), buf.get_float())
			c[i] = Color(buf.get_float(), buf.get_float(), buf.get_float(), buf.get_float())
			u[i] = Vector2(buf.get_float(), buf.get_float())
			u2[i] = Vector2(buf.get_float(), buf.get_float())
		var idx := PackedInt32Array(); idx.resize(int(d["ni"]))
		for i in idx.size():
			idx[i] = buf.get_32()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nr
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = u
		arr[Mesh.ARRAY_TEX_UV2] = u2
		arr[Mesh.ARRAY_INDEX] = idx
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
		im.generate_lods(25.0, 60.0, [])
		var ld := {}
		for l in im.get_surface_lod_count(0):
			ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
		m.surface_set_material(0, old.surface_get_material(0))
		for key in old.get_meta_list():
			m.set_meta(key, old.get_meta(key))
		m.set_meta("detail14", true)
		mi.mesh = m
		k += 1
	return k
