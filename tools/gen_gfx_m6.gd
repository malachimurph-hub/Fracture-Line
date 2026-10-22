extends SceneTree
## M2.6 asset batch:  godot --headless --path . -s res://tools/gen_gfx_m6.gd
## Detailed EU / TPLA core units and main base buildings (tools/gfx_m6/core_m6.gd) and VAT
## infantry for the remaining old procedural squads (Lancer, Rocket Cell, Laborer).
func _initialize() -> void:
	load("res://tools/gfx_m6/core_m6.gd").build_all()
	_infantry("res://view/units/eu/lancer.tscn", "res://assets/models/infantry/eu_lancer.res",
		[Vector3(-0.2, 0, -0.12), Vector3(0.2, 0, -0.1), Vector3(0.0, 0, 0.22)], 0.89)
	_infantry("res://view/units/tpla/rocket_cell.tscn", "res://assets/models/infantry/tpla_rocket.res",
		[Vector3(-0.18, 0, -0.08), Vector3(0.18, 0, 0.1)], 0.85)
	_infantry("res://view/units/tpla/laborer.tscn", "res://assets/models/infantry/tpla_laborer.res",
		[Vector3(0, 0, 0)], 0.785)
	print("gfx m6 views generated")
	quit(0)

func _infantry(path: String, vat_path: String, formation: Array, bar: float) -> void:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/infantry/infantry_view.gd"))
	root.set("vat", load(vat_path))
	root.set("formation", PackedVector3Array(formation))
	root.set("selection_radius", 0.42)
	root.set("bar_height", bar)
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
	anchor.position = Vector3(0, bar, 0)
	root.add_child(anchor)
	anchor.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, path)
	root.free()
