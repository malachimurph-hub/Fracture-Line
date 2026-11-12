extends SceneTree
## Packs a Blender glb into a vehicle view.
##   godot --headless --path . -s res://tools/m47/import_mesh.gd -- <glb> <out.tscn> <bar_h> <sel_r>
const MAT_PATH := "res://view/materials/m3.tres"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: import_mesh.gd -- <glb> <out> [bar_h] [sel_r]")
		quit(1)
		return
	var glb := String(args[0])
	var out := String(args[1])
	var bar_h := float(args[2]) if args.size() > 2 else 1.4
	var sel_r := float(args[3]) if args.size() > 3 else 1.1
	var mat: Material = load(MAT_PATH)
	var src: Node = (load(glb) as PackedScene).instantiate()
	var model := _find(src, "Model")
	if model == null:
		model = src
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/vehicles/vehicle_view.gd"))
	root.set("recoil", 0.04)
	root.set("selection_radius", sel_r)
	root.set("bar_height", bar_h)
	if model.get_parent() != null:
		model.owner = null
		model.get_parent().remove_child(model)
	root.add_child(model)
	model.name = "Model"
	model.owner = root
	_claim(model, root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_convert(mi, mat)
		var nm := String(mi.name)
		if nm.begins_with("Hull"):
			mi.name = "Hull"
			mi.set_meta("moves", true)
		elif nm.begins_with("TracksFar"):
			mi.name = "TracksFar"
			mi.set_meta("moves", true)
			mi.visibility_range_begin = 18.0
			mi.visibility_range_begin_margin = 4.0
		elif nm.begins_with("Tracks"):
			mi.name = "Tracks"
			mi.set_meta("moves", true)
			mi.visibility_range_end = 24.0
			mi.visibility_range_end_margin = 5.0
		elif nm.begins_with("Turret") and not nm.begins_with("TurretPivot"):
			mi.name = "Turret"
		elif nm.begins_with("BarrelMesh"):
			mi.name = "BarrelMesh"
		elif nm.begins_with("Outriggers"):
			mi.name = "Outriggers"
		elif nm.begins_with("Radar"):
			mi.name = "Radar"
	var tail := root.find_child("TailRotor", true, false)
	if tail != null:
		tail.set_meta("rotor_axis", "x")
	var bar := Marker3D.new()
	bar.name = "HealthBarAnchor"
	bar.position = Vector3(0, bar_h, 0)
	root.add_child(bar)
	bar.owner = root
	var tris := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		if m != null and m.get_surface_count() > 0:
			var n := m.surface_get_array_index_len(0) / 3
			tris += n
			print("  ", mi.name, " ", n)
	print("LOD0 ", out.get_file(), " ", tris)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, out)
	print("SAVED ", out, " ", err)
	quit(0)

func _convert(mi: MeshInstance3D, mat: Material) -> void:
	var src := mi.mesh
	if src == null:
		return
	var arr: Array = src.surface_get_arrays(0)
	var cols: Variant = arr[Mesh.ARRAY_COLOR]
	if cols == null or (cols is PackedColorArray and (cols as PackedColorArray).is_empty()):
		print("  NO COLOR on ", mi.name)
		cols = PackedColorArray()
		cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		cols.fill(Color(0.52, 0.56, 0.43, 0.0))
		arr[Mesh.ARRAY_COLOR] = cols
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat)
	im.generate_lods(25.0, 60.0, [])
	var ld := {}
	for l in im.get_surface_lod_count(0):
		ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
	m.surface_set_material(0, mat)
	mi.mesh = m
	mi.material_override = null

func _claim(n: Node, root: Node) -> void:
	if n != root and n.owner != root:
		n.owner = root
	for c in n.get_children():
		_claim(c, root)

func _find(n: Node, name: String) -> Node:
	if String(n.name).begins_with(name):
		return n
	for c in n.get_children():
		var hit := _find(c, name)
		if hit != null:
			return hit
	return null
