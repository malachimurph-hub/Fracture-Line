extends SceneTree
## M3.3 Phase 3 (28): the packed-up Minerals Mining excavator as a vehicle view. Re-uses the
## structure's baked Hull and bucket wheel (same atlas cell) under a VehicleView root; the
## foundation pad, scaffold and damage states stay with the structure.
##   godot --headless --path . -s res://tools/gfx_m33/mine_mobile.gd
func _init() -> void:
	var src: Node3D = load("res://view/buildings/ecc/black_market.tscn").instantiate()
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/vehicles/vehicle_view.gd"))
	root.set("recoil", 0.0)
	root.set("wreck_s", 10.0)
	root.set("selection_radius", 1.5)
	root.set("bar_height", 2.2)
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	for n in ["Hull", "BucketWheel"]:
		var mi: MeshInstance3D = src.get_node("Model/" + n).duplicate()
		mi.position.y -= 0.08            # no foundation pad under the crawlers
		model.add_child(mi)
		mi.owner = root
	var anchor := Marker3D.new()
	anchor.name = "HealthBarAnchor"
	anchor.position = Vector3(0, 2.2, 0)
	root.add_child(anchor)
	anchor.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print("mine_mobile: ", ResourceSaver.save(ps, "res://view/units/ecc/mine_mobile.tscn"))
	src.free()
	root.free()
	quit()
