class_name Weathering
## M2 model weathering: shared ShaderMaterial factory for view/materials/weathered.gdshader
## and per-faction instance amounts (EU: kept-up paint; TPLA: ramshackle, rusty, dusty).
const SHADER := "res://view/materials/weathered.gdshader"
const TEX := "res://assets/textures/materials/"
const FACTION := {
	&"eu": {"rust": 0.12, "wear": 0.45, "dirt": 0.55},
	&"tpla": {"rust": 0.15, "wear": 0.5, "dirt": 0.65},   # M3.3 item 34: a modern army, not ramshackle (was 0.55 / 0.85 / 0.85)
	&"ecc": {"rust": 0.2, "wear": 0.55, "dirt": 0.7},   # M3.0 F Russia: worn field paint
}
const NEUTRAL := {"rust": 0.35, "wear": 0.6, "dirt": 0.7}

static func make_material(tex: String, rough: float, metal: float, tex_amt: float, panels: float, stencil: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	m.set_shader_parameter("weather_tex", load(TEX + "weather.png"))
	m.set_shader_parameter("rust_tex", load(TEX + "rust.png"))
	m.set_shader_parameter("stencil_tex", load(TEX + "stencils.png"))
	if tex != "":
		m.set_shader_parameter("base_tex", load(tex))
	m.set_shader_parameter("base_tex_amount", tex_amt if tex != "" else 0.0)
	m.set_shader_parameter("base_tex_scale", 0.6)
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("emission_v", 0.0)
	m.set_shader_parameter("emission_color", Color.BLACK)
	m.set_shader_parameter("roughness_v", rough)
	m.set_shader_parameter("metallic_v", metal)
	m.set_shader_parameter("panel_amount", panels)
	m.set_shader_parameter("stencil_amount", stencil)
	return m

static func team_material(c: Color) -> ShaderMaterial:
	var m := make_material("", 0.5, 0.2, 0.0, 1.0, 1.0)
	m.set_shader_parameter("use_vertex_color", false)
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("emission_v", 0.25)
	m.set_shader_parameter("emission_color", Color.WHITE)
	return m

## Applies the faction's rust / wear / dirt amounts to every mesh under `root`.
static func apply(root: Node, faction: StringName) -> void:
	var a: Dictionary = FACTION.get(faction, NEUTRAL)
	_apply(root, a)

static func _apply(n: Node, a: Dictionary) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			var g: GeometryInstance3D = c
			g.set_instance_shader_parameter(&"rust_amt", a["rust"])
			g.set_instance_shader_parameter(&"wear_amt", a["wear"])
			g.set_instance_shader_parameter(&"dirt_amt", a["dirt"])
		_apply(c, a)
