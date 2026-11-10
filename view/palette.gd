class_name Palette
## Player colors (colorblind-considerate set) and team shapes. Team identity is never color-only:
## each team also has a shape used on selection rings, minimap dots and health bars (GDD 9).
const COLORS := [Color("#2f7fe0"), Color("#e2572b"), Color("#f0d23c"), Color("#b268d9"), Color("#2dbb8a"), Color("#f09a2a"),
	Color("#f27fb8"), Color("#62d6ea")]   # M3.3 P3 (21): pink and cyan for 7-8 player maps
const COLOR_KEYS := ["COLOR_BLUE", "COLOR_RED", "COLOR_YELLOW", "COLOR_PURPLE", "COLOR_GREEN", "COLOR_ORANGE", "COLOR_PINK", "COLOR_CYAN"]
const SHAPES := ["circle", "square", "triangle", "diamond"]
const NEUTRAL := Color("#c8c2b4")
static var _team_mats: Dictionary = {}
static var _flat: Dictionary = {}

static func color(i: int) -> Color:
	return NEUTRAL if i < 0 else COLORS[i % COLORS.size()]

static func team_material(i: int) -> Material:
	if _team_mats.has(i):
		return _team_mats[i]
	var m := Weathering.team_material(color(i))
	_team_mats[i] = m
	return m

static func flat(c: Color, alpha: float = 1.0, unshaded: bool = true) -> StandardMaterial3D:
	var key := "%s_%f_%s" % [c.to_html(), alpha, unshaded]
	if _flat.has(key):
		return _flat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	_flat[key] = m
	return m

## Flat ring outline mesh in the shape of the team (y-up, radius 1).
static func ring_mesh(shape: String, width: float = 0.14) -> ArrayMesh:
	var pts: Array = []
	match shape:
		"square":
			pts = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			for i in pts.size(): pts[i] = pts[i] * 0.85
		"triangle":
			for i in 3: pts.append(Vector2.from_angle(-PI / 2 + i * TAU / 3) * 1.15)
		"diamond":
			pts = [Vector2(0, -1.15), Vector2(1.15, 0), Vector2(0, 1.15), Vector2(-1.15, 0)]
		_:
			for i in 24: pts.append(Vector2.from_angle(i * TAU / 24))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var ai := a * (1.0 - width)
		var bi := b * (1.0 - width)
		for v in [a, b, bi, a, bi, ai]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, 0, v.y))
	return st.commit()

## M3.5 faction vehicle paint (Malachi): USA light tan (M3.7, was FDE #a08a68), Germany dark earthy pine
## green, Iran modern desert khaki (M4.2 face lift), Russia dark grey. Team colour stays on the accent parts.
const FACTION_PAINT := {&"us": Color("#c9b48c"), &"eu": Color("#44523a"), &"tpla": Color("#8a7f5c"), &"ecc": Color("#5d6163")}
## structures restyled with their faction's paint (M3.5 power station swap)
const PAINT_BUILDINGS := {&"ecc_power": 0.8, &"tpla_cc_plant": 0.8}

## M4.2 (Malachi): per-unit paint overrides. US aircraft and the US dozer are grey, the UH-60
## Black Hawk is black. The M1A3 is CARC Tan 686A. The chip is about #A08D69; the in-game
## value is #E0C080 so baked AO, grime and the match sun still read as desert tan.
## Every other US vehicle stays the light faction tan.
const US_AIR_GREY := Color("#7f868c")
const M1A3_TAN := Color("#E0C080")
const UNIT_PAINT := {&"us_blackhawk": Color("#1d1f21"), &"us_dozer": Color("#80868a"), &"us_ripsaw": Color("#5e655f"),
	&"us_halberd": M1A3_TAN}

static func paint_for(def_id: StringName) -> Color:
	if UNIT_PAINT.has(def_id):
		return UNIT_PAINT[def_id]
	var fac := Content.faction_of_id(def_id)
	var ud: UnitDef = Content.unit(def_id)
	if fac == &"us" and ud != null and ud.move_layer == &"air":
		return US_AIR_GREY
	return FACTION_PAINT.get(fac, Color(0, 0, 0, 0))

## M4.3 (Malachi): Iran's civilian pickups (Technical, supply pickup) roll out of the garage in a
## random civilian colour - blue, white, black, red or yellow - fixed per unit (by entity id).
const CIVVY_PAINT := [Color("#2f5d9e"), Color("#e8e8e4"), Color("#1c1d1f"), Color("#a3241f"), Color("#e0b526")]
const CIVVY_UNITS := [&"tpla_rattler", &"tpla_pickup"]
static func civvy_paint(eid: int) -> Color:
	return CIVVY_PAINT[((eid * 2654435761) >> 7) % CIVVY_PAINT.size()]

static func apply_color(n: Node, c: Color) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if _is_m3(g):
			(g as GeometryInstance3D).set_instance_shader_parameter(&"paint_color", c)

## Paint for one unit type (faction paint plus the overrides above).
static func apply_unit_paint(n: Node, def_id: StringName) -> void:
	var c := paint_for(def_id)
	if c.a <= 0.0:
		return
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if _is_m3(g):
			(g as GeometryInstance3D).set_instance_shader_parameter(&"paint_color", c)

## Sets the faction paint on every m3-shaded mesh under n (vehicles, aircraft, drones).
static func apply_paint(n: Node, fac: StringName, strength := 1.0) -> void:
	if not FACTION_PAINT.has(fac):
		return
	var c: Color = FACTION_PAINT[fac]
	c.a = strength
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if _is_m3(g):
			(g as GeometryInstance3D).set_instance_shader_parameter(&"paint_color", c)

static func _is_m3(g: Node) -> bool:
	var m: Material = (g as GeometryInstance3D).material_override
	if m == null and g is MeshInstance3D and (g as MeshInstance3D).mesh != null and (g as MeshInstance3D).mesh.get_surface_count() > 0:
		m = (g as MeshInstance3D).get_active_material(0)
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.contains("model_m3")
