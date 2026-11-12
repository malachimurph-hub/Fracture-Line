extends SceneTree
## Turns the Blender BMPT glb into the live vehicle view.
##   godot --headless --path . -s res://tools/m47/import_bmpt.gd
const MAT_PATH := "res://view/materials/m3.tres"
const GLB := "res://assets/models/ecc/bmpt.glb"
const OUT := "res://view/units/ecc/bmpt.tscn"

func _initialize() -> void:
	var mat: Material = load(MAT_PATH)
	var src: Node = (load(GLB) as PackedScene).instantiate()
	_dump(src, 0)
	var model := _find(src, "Model")
	if model == null:
		model = src
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/vehicles/vehicle_view.gd"))
	root.set("recoil", 0.04)
	root.set("selection_radius", 1.05)
	root.set("bar_height", 1.45)
	# Re-parent the imported model under the view. glTF may wrap it.
	var holder := model
	if holder.get_parent() != null:
		holder.owner = null
		holder.get_parent().remove_child(holder)
	root.add_child(holder)
	holder.name = "Model"
	holder.owner = root
	_claim(holder, root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_convert(mi, mat)
		if String(mi.name).begins_with("Hull"):
			mi.name = "Hull"
			mi.set_meta("moves", true)
		elif String(mi.name).begins_with("Turret") and not String(mi.name).begins_with("TurretPivot"):
			mi.name = "Turret"
		elif String(mi.name).begins_with("BarrelMesh"):
			mi.name = "BarrelMesh"
	var bar := Marker3D.new()
	bar.name = "HealthBarAnchor"
	bar.position = Vector3(0, 1.35, 0)
	root.add_child(bar)
	bar.owner = root
	var tris := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		if m != null:
			tris += m.surface_get_array_index_len(0) / 3
			var aabb := m.get_aabb()
			print("  ", mi.name, " tris ", m.surface_get_array_index_len(0) / 3, " aabb ", aabb, " at ", (mi as Node3D).position)
	print("BMPT LOD0 tris ", tris)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, OUT)
	print("SAVED ", OUT, " ", err)
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
		cols.fill(Color(0.353, 0.392, 0.282, 0.0))
		arr[Mesh.ARRAY_COLOR] = cols
	else:
		var c0: Color = cols[0]
		print("  color0 ", mi.name, " ", c0, " class ", int(c0.a * 20.0 + 0.5), " n ", cols.size())
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

func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var aabb: AABB = (n as MeshInstance3D).mesh.get_aabb()
		extra = " mesh " + str(aabb)
	print("  ".repeat(d), n.name, " ", n.get_class(), extra)
	for c in n.get_children():
		_dump(c, d + 1)
