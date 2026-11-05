extends "res://tools/m42/models_m42.gd"
## M4.3 (Malachi): Iran's base reads as a modern state, not a militia camp. Original procedural
## models on the m3 kit (front = +Z, the side units leave from).
##   godot --headless --path . -s res://tools/m43/models_m43.gd
## Writes view/buildings/tpla/den (municipality-style HQ), workshop (modern office block),
## chop_shop (modern vehicle depot).
const STONE := "#d9ceb4"
const STONE_D := "#bfb293"
const TRIM := "#ece6d6"
const CLAD := "#b9bcbb"
const CLAD_D := "#8e9294"

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	struct_fac = "tpla"
	_municipality(mat)
	_office(mat)
	_depot(mat)
	var f := FileAccess.open("/tmp/m43_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line(p)
	print("M43 wrote %d scenes" % wrote.size())
	quit(0)

static func _rot(a: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)

## window rows on all four faces of a w x d block from y0, n floors of fh
static func _facades(g, cx: float, cz: float, w: float, d: float, y0: float, floors: int, fh: float, per_m: float) -> void:
	for side in 4:
		var a := side * PI * 0.5
		var span := w if side % 2 == 0 else d
		var half := (d if side % 2 == 0 else w) * 0.5
		var n := maxi(2, int(span * per_m))
		for fl in floors:
			var y := y0 + fh * (fl + 0.55)
			var c := Vector3(cx, y, cz).rotated(Vector3.UP, -a) + Vector3(0, 0, half + 0.004)
			g.windows(c, span * 0.86, fh * 0.5, n, _rot(a))

## Municipality-style HQ: three-storey dressed-stone block with a raised central bay, a deep
## arched portico on columns, cornices, roof clock turret and a flagpole; a stepped plaza in front.
func _municipality(mat: Material) -> void:
	_structure("den", Vector2(4, 4), 2.5, mat, func(g) -> void:
		var y := Y0
		# plaza + steps
		g.color("#cfc7b2", Geo.CONCRETE)
		g.cbox(Vector3(0, y + 0.03, 0.2), Vector3(3.8, 0.06, 3.5), 0.01)
		for i in 3:
			g.cbox(Vector3(0, y + 0.07 + i * 0.04, 1.3 - i * 0.1), Vector3(1.3 - i * 0.12, 0.04, 0.4), 0.005)
		# main block (wings) and raised central bay
		g.color(STONE, Geo.CONCRETE)
		g.cbox(Vector3(0, y + 0.06 + 0.75, -0.35), Vector3(3.3, 1.5, 2.0), 0.02)
		g.color(STONE_D, Geo.CONCRETE)
		g.cbox(Vector3(0, y + 0.06 + 0.95, 0.15), Vector3(1.3, 1.9, 1.1), 0.02)
		# cornices / string courses
		g.color(TRIM, Geo.PAINT)
		g.cbox(Vector3(0, y + 1.6, -0.35), Vector3(3.42, 0.07, 2.12), 0.01)
		g.cbox(Vector3(0, y + 0.58, -0.35), Vector3(3.36, 0.04, 2.06), 0.005)
		g.cbox(Vector3(0, y + 2.0, 0.15), Vector3(1.42, 0.08, 1.22), 0.01)
		# windows: wings 3 floors, tall arched-style bay windows
		_facades(g, 0, -0.35, 3.3, 2.0, y + 0.06, 3, 0.5, 2.6)
		g.color("#2a3a46", Geo.GLASS)
		for sx in [-0.38, 0.0, 0.38]:
			g.box(Vector3(sx, y + 1.45, 0.705), Vector3(0.22, 0.55, 0.01))
		# arched portico: columns and a semicircular arch over the entrance
		g.color(TRIM, Geo.PAINT)
		for sx in [-0.55, -0.2, 0.2, 0.55]:
			g.cyl(0.055, 0.055, 0.9, 10, Transform3D(Basis.IDENTITY, Vector3(sx, y + 0.06, 0.95)))
		g.cbox(Vector3(0, y + 1.02, 0.95), Vector3(1.32, 0.1, 0.34), 0.01)
		for k in 9:
			var a := PI * float(k) / 8.0
			g.box(Vector3(cos(a) * 0.2, y + 0.66 + sin(a) * 0.2, 1.05), Vector3(0.07, 0.05, 0.1))
		g.color("#3b2f24", Geo.DARK)
		g.box(Vector3(0, y + 0.38, 0.71), Vector3(0.34, 0.6, 0.02))   # doors
		# roof: clock turret with a small dome, AC units
		g.color(STONE, Geo.CONCRETE)
		g.cbox(Vector3(0, y + 2.22, 0.15), Vector3(0.42, 0.36, 0.42), 0.01)
		g.color(TRIM, Geo.PAINT)
		g.dome(0.2, 0.18, 4, 12, Transform3D(Basis.IDENTITY, Vector3(0, y + 2.4, 0.15)))
		g.color("#f2efe6", Geo.PAINT)
		g.cyl(0.11, 0.11, 0.01, 14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y + 2.24, 0.37)))
		g.color("#6f7376", Geo.STEEL)
		for sx in [-1.2, -0.8, 0.9]:
			g.cbox(Vector3(sx, y + 1.7, -0.9), Vector3(0.24, 0.14, 0.2), 0.01)
		# flagpole with a team-colour flag
		g.color("#8a8d90", Geo.STEEL)
		g.tube(Vector3(1.45, y + 0.06, 1.35), Vector3(1.45, y + 2.3, 1.35), 0.02, 6)
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(1.63, y + 2.12, 1.35), Vector3(0.34, 0.22, 0.01))
		# low planters along the plaza
		g.color("#5f7a43", Geo.PAINT)
		for sx in [-1.3, 1.0]:
			g.cbox(Vector3(sx, y + 0.12, 1.2), Vector3(0.6, 0.12, 0.22), 0.02),
		Callable(), Vector3.ZERO, {})

## Defense Workshop as a modern office block: glass curtain wall with spandrel bands, a stone
## base, roof parapet with plant, an entrance canopy.
func _office(mat: Material) -> void:
	_structure("workshop", Vector2(3, 3), 2.1, mat, func(g) -> void:
		var y := Y0
		g.color("#cfc9b8", Geo.CONCRETE)
		g.cbox(Vector3(0, y + 0.03, 0), Vector3(2.85, 0.06, 2.85), 0.01)
		g.color(STONE, Geo.CONCRETE)
		g.cbox(Vector3(0, y + 0.06 + 0.2, -0.15), Vector3(2.3, 0.4, 1.9), 0.02)   # stone base storey
		g.color("#2f4352", Geo.GLASS)
		g.cbox(Vector3(0, y + 0.46 + 0.7, -0.15), Vector3(2.2, 1.4, 1.8), 0.01)     # curtain wall
		g.color(CLAD, Geo.PAINT)
		for i in 4:
			g.cbox(Vector3(0, y + 0.5 + i * 0.35, -0.15), Vector3(2.24, 0.05, 1.84), 0.003)   # spandrels
		for sx in [-1.1, -0.55, 0.0, 0.55, 1.1]:
			g.box(Vector3(sx, y + 1.16, 0.756), Vector3(0.03, 1.4, 0.02))   # mullions front
		g.color(CLAD_D, Geo.PAINT)
		g.cbox(Vector3(0, y + 1.9, -0.15), Vector3(2.3, 0.1, 1.9), 0.01)    # parapet
		g.color("#6f7376", Geo.STEEL)
		g.cbox(Vector3(-0.5, y + 2.0, -0.4), Vector3(0.6, 0.16, 0.5), 0.01)
		g.cbox(Vector3(0.55, y + 2.0, -0.6), Vector3(0.3, 0.12, 0.3), 0.01)
		_facades(g, 0, -0.15, 2.3, 1.9, y + 0.06, 1, 0.4, 2.2)
		# entrance canopy on two posts
		g.color(CLAD, Geo.PAINT)
		g.cbox(Vector3(0, y + 0.5, 0.98), Vector3(0.9, 0.04, 0.45), 0.005)
		g.color("#8a8d90", Geo.STEEL)
		for sx in [-0.4, 0.4]:
			g.tube(Vector3(sx, y + 0.06, 1.15), Vector3(sx, y + 0.5, 1.15), 0.02, 6)
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, y + 1.98, 0.78), Vector3(0.8, 0.07, 0.01)),
		Callable(), Vector3.ZERO, {})

## Garage as a modern vehicle depot: insulated steel-clad hall with two roll-up doors, a glazed
## two-storey office on the side, roof ventilators, painted forecourt bays.
func _depot(mat: Material) -> void:
	_structure("chop_shop", Vector2(4, 4), 1.5, mat, func(g) -> void:
		var y := Y0
		g.color("#8f8d87", Geo.CONCRETE)
		g.cbox(Vector3(0, y + 0.03, 0), Vector3(3.85, 0.06, 3.85), 0.01)
		g.color("#ece7d8", Geo.PAINT)
		for sx in [-0.6, 0.6]:
			g.box(Vector3(sx, y + 0.065, 1.45), Vector3(0.04, 0.005, 0.8))   # bay lines
		g.color(CLAD, Geo.PAINT)
		g.cbox(Vector3(-0.35, y + 0.06 + 0.6, -0.35), Vector3(2.9, 1.2, 2.6), 0.02)
		g.color(CLAD_D, Geo.PAINT)
		g.cbox(Vector3(-0.35, y + 1.3, -0.35), Vector3(3.0, 0.08, 2.7), 0.01)    # roof edge
		for sx in [-0.95, 0.25]:
			g.rollup(Vector3(sx, y + 0.5, 0.955), 0.85, 0.85)
		g.color(STONE, Geo.CONCRETE)
		g.cbox(Vector3(1.55, y + 0.06 + 0.55, 0.3), Vector3(0.7, 1.1, 1.3), 0.02)   # office block
		g.color("#2f4352", Geo.GLASS)
		g.box(Vector3(1.55, y + 0.4, 0.955), Vector3(0.6, 0.28, 0.01))
		g.box(Vector3(1.55, y + 0.85, 0.955), Vector3(0.6, 0.28, 0.01))
		g.box(Vector3(1.905, y + 0.62, 0.3), Vector3(0.01, 0.7, 1.1))
		g.color("#6f7376", Geo.STEEL)
		for sx in [-1.3, -0.35, 0.6]:
			g.cyl(0.09, 0.07, 0.14, 10, Transform3D(Basis.IDENTITY, Vector3(sx, y + 1.34, -0.6)))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(-0.35, y + 1.12, 0.955), Vector3(1.6, 0.08, 0.01)),
		Callable(), Vector3.ZERO, {})
