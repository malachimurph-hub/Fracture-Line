extends EntityView
## M3.2.1: garrisonable civilian house (neutral, like the civilian block): the same procedural
## European house mesh as the village props, as a real structure with a health bar.
@export var house_kind := "house_a"

func _ready() -> void:
	var mdl := Node3D.new()
	mdl.name = "Model"
	add_child(mdl)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var kind := PropMeshes.themed(house_kind, TerrainView.civ_theme)
	body.mesh = PropMeshes.make(kind)
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
