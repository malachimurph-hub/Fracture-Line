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
