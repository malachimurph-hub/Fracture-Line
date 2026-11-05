extends EntityView
## M4.3: civilian apartment/shop block; mesh follows MapDef.civ_theme (us|de|ir|ru).
func _ready() -> void:
	var mdl := Node3D.new()
	mdl.name = "Model"
	add_child(mdl)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = PropMeshes.make(PropMeshes.themed("civ_block", TerrainView.civ_theme))
	if TerrainView.shared_house_material != null:
		body.material_override = TerrainView.shared_house_material
	else:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.85
		body.material_override = m
	mdl.add_child(body)
	super._ready()
