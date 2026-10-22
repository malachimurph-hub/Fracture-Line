extends SceneTree
## M2.2 graphics batch generator:  godot --headless --path . -s res://tools/gen_gfx_m3.gd
## Writes the view scenes that tools/gen_views.gd no longer owns (M3_OWNED there):
##   rifle squads (VAT soldiers), EU Leopold + TPLA Rattler (articulated), EU Barracks (staged).
func _initialize() -> void:
	_infantry("res://view/units/eu/grenadier.tscn", "res://assets/models/infantry/eu_rifleman.res",
		[Vector3(-0.2, 0, -0.17), Vector3(0.21, 0, -0.14), Vector3(-0.17, 0, 0.2), Vector3(0.2, 0, 0.21)])
	_infantry("res://view/units/tpla/militia.tscn", "res://assets/models/infantry/tpla_rifleman.res",
		[Vector3(-0.2, 0, -0.16), Vector3(0.2, 0, -0.13), Vector3(-0.15, 0, 0.21), Vector3(0.21, 0, 0.19)])
	var vk = load("res://tools/gfx_m3/vehicle_kit.gd")
	if vk != null:
		vk.build_all()
	var bk = load("res://tools/gfx_m3/barracks_kit.gd")
	if bk != null:
		bk.build_all()
	print("gfx m3 views generated")
	quit(0)

func _infantry(path: String, vat_path: String, formation: Array) -> void:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/infantry/infantry_view.gd"))
	root.set("vat", load(vat_path))
	root.set("formation", PackedVector3Array(formation))
	root.set("selection_radius", 0.42)
	root.set("bar_height", 0.78)
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Squad"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(mmi)
	mmi.owner = root
	var anchor := Marker3D.new()
	anchor.name = "HealthBarAnchor"
	anchor.position = Vector3(0, 0.78, 0)
	root.add_child(anchor)
	anchor.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, path)
	root.free()
