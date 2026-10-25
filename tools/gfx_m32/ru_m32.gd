extends RefCounted
## M3.2 Russia buildings + aircraft (internal faction id ecc; tool-time only). Original procedural
## models from Malachi's list (rts-design/notes/RUSSIA_FACTION_NOTES_malachi_2026-10-23.md):
##   hq        - Kremlin-inspired: red-brick walls with swallowtail merlons, towers with green tent
##               spires and ruby stars, cream palace block, golden-domed cathedral, and a brick gate
##               house whose arch lines up with the sim exit tile (rot 0: local x +0.5, front +z)
##   depot / barracks / factory - brutalist: raw concrete slabs, repetitive window grids, pilotis,
##               heavy cantilevers
##   power     - natural gas processing plant (columns, pipe rack, spherical tanks, flare stack)
##   ministry  - Ministry of Defense: Stalinist stepped tower over a colonnaded wing
##   black_market - warehouse trading post: containers, stall awnings, crates, string lights
##   bunker    - Kornet Nest: sandbag ring, turret = two tripod-mounted AT launchers
##   aa_site   - ZAK-30 Citadel: naval-style turret with twin six-barrel 30 mm guns on a plinth
##   airfield  - the shared 8 x 8 air base (M3.1 taxi/runway layout) in Russian colours
##   su57 / tu160 / ka52 - aircraft
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const R := preload("res://tools/gfx_m30/ru_m30.gd")
const UM := preload("res://tools/gfx_m30/us_m30.gd")
const Y0 := 0.08
const GLASS_C := "#2a3a46"
const RU := "#5b6442"
const RU_D := "#474f34"
const RU_S := "#3a3d38"
# Kremlin
const BRICK := "#9a3a2c"
const BRICK_D := "#7c2c22"
const BRICK_L := "#ad4a38"
const SPIRE := "#3e7652"
const SPIRE_D := "#2e5a3e"
const TRIM := "#e4ddcc"
const PALACE := "#dccb9e"
const PALACE_D := "#c4b386"
const GOLD := "#d0a83a"
# brutalist concrete
const BC := "#a29e93"
const BC_D := "#878378"
const BC_L := "#b7b3a7"
const BC_X := "#6f6c64"
# stone (Stalinist)
const ST := "#c9bfa6"
const ST_D := "#a99f88"
const ST_L := "#ddd4bd"
# aircraft
const SU := "#808d99"
const SU_D := "#5f6a75"
const SU_L := "#9aa6b0"
const TU := "#e4e4df"
const TU_D := "#c4c6c4"
const AIR_S := "#43484c"

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func V8():
	return load("res://tools/gfx_m7/us_v8.gd")

static func jobs() -> Dictionary:
	return {
		"ecc_hq": func() -> void: U()._make("hq", Vector2(4, 4), 2.1, _kremlin, Callable(), Vector3.ZERO, "ecc"),
		"ecc_power": func() -> void: U()._make("power", Vector2(3, 3), 2.3, _gas_plant, Callable(), Vector3.ZERO, "ecc"),
		"ecc_depot": func() -> void: U()._make("depot", Vector2(3, 3), 1.1, _depot, Callable(), Vector3.ZERO, "ecc"),
		"ecc_barracks": func() -> void: U()._make("barracks", Vector2(3, 3), 1.2, _barracks, Callable(), Vector3.ZERO, "ecc"),
		"ecc_factory": func() -> void: U()._make("factory", Vector2(4, 4), 1.5, _factory, Callable(), Vector3.ZERO, "ecc"),
		"ecc_ministry": func() -> void: U()._make("ministry", Vector2(4, 4), 2.2, _ministry, Callable(), Vector3.ZERO, "ecc"),
		"ecc_black_market": func() -> void: U()._make("black_market", Vector2(3, 3), 1.0, _black_market, Callable(), Vector3.ZERO, "ecc"),
		"ecc_bunker": func() -> void: U()._make("bunker", Vector2(2, 2), 0.7, _kornet_nest, _kornet_turret, Vector3(0, Y0 + 0.06, 0.05), "ecc"),
		"ecc_aa_site": func() -> void: U()._make("aa_site", Vector2(2, 2), 1.1, _zak_base, _zak_turret, Vector3(0, Y0 + 0.42, 0), "ecc"),
		"ecc_airfield": func() -> void: U()._make("airfield", Vector2(8, 8), 2.2, _airfield, Callable(), Vector3.ZERO, "ecc"),
		"ecc_su57": func() -> void: _su57(),
		"ecc_tu160": func() -> void: _tu160(),
		"ecc_ka52": func() -> void: _ka52(),
	}

# ================================================================== shared detail
static func _wgrid(g, c: Vector3, w: float, h: float, cols: int, rows: int, yaw: float, seed_i: int, lit := 0.3, frame := "#2b2d2c") -> void:
	UM._win_grid(g, Vector3.ZERO, w, h, cols, rows, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c), seed_i, lit, frame)

## Glowing five-point star (ruby glass) facing +z (or rotated by yaw), both faces.
static func _ruby(g, c: Vector3, r: float, yaw := 0.0) -> void:
	g.color("#ff3a26", Geo.LAMP)
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var pts: Array = []
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(Vector3(cos(a) * rr, sin(a) * rr, 0.0))
	var fs: Array = []
	for i in 10:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % 10]
		fs.append([c + b * Vector3(0, 0, 0.02), c + b * (p0 + Vector3(0, 0, 0.0)), c + b * (p1 + Vector3(0, 0, 0.0))])
		fs.append([c + b * Vector3(0, 0, -0.02), c + b * (p1 + Vector3(0, 0, 0.0)), c + b * (p0 + Vector3(0, 0, 0.0))])
	g.faces(fs)

## Swallowtail ("M") merlons along a wall top from a to b (y = top).
static func _merlons(g, a: Vector3, b: Vector3, th: float, n: int) -> void:
	var d := b - a
	var yaw := atan2(d.x, d.z)
	var bs := Basis(Vector3.UP, yaw)
	for i in n:
		var p := a + d * ((i + 0.5) / float(n))
		var w := d.length() / float(n) * 0.55
		for s in [-1.0, 1.0]:   # two horns per merlon
			g.box(Vector3.ZERO, Vector3(th, 0.09, w * 0.42), Transform3D(bs, p + bs * Vector3(0, 0.045, s * w * 0.29)))
		g.box(Vector3.ZERO, Vector3(th, 0.05, w), Transform3D(bs, p + Vector3(0, -0.005, 0)))

## Brick wall segment a -> b (ground points) with walkway parapet merlons.
static func _kwall(g, a: Vector3, b: Vector3, h: float, th: float) -> void:
	var d := b - a
	var yaw := atan2(d.x, d.z)
	g.color(BRICK, Geo.CONCRETE)
	g.cbox(Vector3.ZERO, Vector3(th, h, d.length()), 0.01, Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5 + Vector3(0, h * 0.5, 0)))
	g.color(BRICK_D, Geo.CONCRETE)
	g.box(Vector3.ZERO, Vector3(th + 0.03, 0.06, d.length()), Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5 + Vector3(0, 0.03, 0)))   # plinth
	g.color(BRICK_L, Geo.CONCRETE)
	_merlons(g, a + Vector3(0, h, 0), b + Vector3(0, h, 0), th * 0.8, int(d.length() / 0.26))

## Kremlin tower: square brick shaft, white-trimmed tiers, green tent spire, ruby star.
static func _ktower(g, p: Vector3, w: float, h: float, spire: float, star: float, clock := false) -> void:
	g.color(BRICK, Geo.CONCRETE)
	g.cbox(p + Vector3(0, h * 0.5, 0), Vector3(w, h, w), 0.012)
	g.color(BRICK_D, Geo.CONCRETE)
	g.cbox(p + Vector3(0, h + 0.03, 0), Vector3(w + 0.05, 0.06, w + 0.05), 0.01)   # machicolation band
	g.color(BRICK_L, Geo.CONCRETE)
	for k in 4:
		var bs := Basis(Vector3.UP, PI * 0.5 * k)
		for s in [-1.0, 0.0, 1.0]:
			g.box(Vector3.ZERO, Vector3(0.05, 0.07, 0.03), Transform3D(bs, p + bs * Vector3(s * w * 0.36, h + 0.095, w * 0.5)))
	g.color("#2b2d2c", Geo.DARK)   # loop windows
	for k in 4:
		var bs := Basis(Vector3.UP, PI * 0.5 * k)
		g.box(Vector3.ZERO, Vector3(0.04, 0.1, 0.01), Transform3D(bs, p + bs * Vector3(0, h * 0.62, w * 0.5 + 0.004)))
	# upper tier(s)
	var y := p.y + h + 0.06
	var w2 := w * 0.72
	g.color(BRICK, Geo.CONCRETE)
	g.cbox(Vector3(p.x, y + spire * 0.14, p.z), Vector3(w2, spire * 0.28, w2), 0.01)
	g.color(TRIM, Geo.CONCRETE)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			g.tube(Vector3(p.x + s * w2 * 0.5, y, p.z + t * w2 * 0.5), Vector3(p.x + s * w2 * 0.5, y + spire * 0.28, p.z + t * w2 * 0.5), 0.012, 4)   # white corner pinnacles
	g.box(Vector3(p.x, y + spire * 0.28 + 0.012, p.z), Vector3(w2 + 0.03, 0.024, w2 + 0.03))
	if clock:
		g.color(TRIM, Geo.PAINT)
		g.cyl(w2 * 0.33, w2 * 0.33, 0.012, 16, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(p.x, y + spire * 0.14, p.z + w2 * 0.5 + 0.006)))
		g.color(GOLD, Geo.STEEL)
		g.cyl(w2 * 0.36, w2 * 0.36, 0.006, 16, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(p.x, y + spire * 0.14, p.z + w2 * 0.5 + 0.002)))
		g.color("#1d1e20", Geo.DARK)
		g.box(Vector3(p.x, y + spire * 0.14 + w2 * 0.1, p.z + w2 * 0.5 + 0.014), Vector3(0.012, w2 * 0.2, 0.004))
		g.box(Vector3(p.x + w2 * 0.07, y + spire * 0.14, p.z + w2 * 0.5 + 0.014), Vector3(w2 * 0.14, 0.012, 0.004))
	# octagonal green tent spire with a gilt finial
	var y2 := y + spire * 0.28 + 0.024
	g.color(SPIRE, Geo.PAINT)
	g.lathe([[0.0, w2 * 0.56], [spire * 0.72, 0.012]], 8, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3(p.x, y2, p.z)))
	g.color(SPIRE_D, Geo.PAINT)
	g.lathe([[0.0, w2 * 0.6], [0.03, w2 * 0.56]], 8, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3(p.x, y2, p.z)), true, false)
	g.color(GOLD, Geo.STEEL)
	g.tube(Vector3(p.x, y2 + spire * 0.72, p.z), Vector3(p.x, y2 + spire * 0.72 + 0.06, p.z), 0.008, 4)
	if star > 0.0:
		_ruby(g, Vector3(p.x, y2 + spire * 0.72 + 0.06 + star, p.z), star)
		_ruby(g, Vector3(p.x, y2 + spire * 0.72 + 0.06 + star, p.z), star, 90.0)

static func _sphere(g, c: Vector3, r: float, seg := 14, rings := 8) -> void:
	var prof: Array = []
	for i in rings + 1:
		var a := PI * float(i) / float(rings)
		prof.append([-cos(a) * r, maxf(sin(a) * r, 0.0003 if i == 0 else 0.0)])
	g.lathe(prof, seg, Transform3D(Basis.IDENTITY, c), false, false)

static func _onion(g, c: Vector3, r: float) -> void:
	g.color(PALACE_D, Geo.CONCRETE)
	g.cyl(r * 0.62, r * 0.62, r * 0.9, 10, Transform3D(Basis.IDENTITY, c))   # drum
	g.color(GOLD, Geo.STEEL)
	g.lathe([[0.0, r * 0.66], [r * 0.4, r * 1.0], [r * 0.9, r * 0.82], [r * 1.35, r * 0.32], [r * 1.7, 0.0]], 12, Transform3D(Basis.IDENTITY, c + Vector3(0, r * 0.9, 0)), true, false)
	g.tube(c + Vector3(0, r * 2.55, 0), c + Vector3(0, r * 3.0, 0), 0.006, 4)
	g.box(c + Vector3(0, r * 2.85, 0), Vector3(r * 0.4, 0.008, 0.008))

# ================================================================== Kremlin (HQ)
static func _kremlin(g) -> void:
	# paving and the drive-out lane to the exit tile
	g.color("#8d8a82", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.01, 0), Vector3(3.84, 0.02, 3.84), 0.01)
	g.color("#7a776f", Geo.CONCRETE)
	g.box(Vector3(0.5, Y0 + 0.022, 1.6), Vector3(0.95, 0.006, 0.75))
	g.color("#e8d34a", Geo.PAINT)
	for x in [0.04, 0.96]:
		g.box(Vector3(x, Y0 + 0.027, 1.6), Vector3(0.03, 0.004, 0.75))
	var b0 := Y0 + 0.02
	var wh := 0.42
	var zf := 1.12   # front wall line
	var zb := -1.78
	var xs := 1.78
	# walls (front wall split by the gate house at x -0.1 .. 1.1)
	_kwall(g, Vector3(-xs, b0, zb), Vector3(xs, b0, zb), wh, 0.12)
	_kwall(g, Vector3(-xs, b0, zb), Vector3(-xs, b0, zf), wh, 0.12)
	_kwall(g, Vector3(xs, b0, zb), Vector3(xs, b0, zf), wh, 0.12)
	_kwall(g, Vector3(-xs, b0, zf), Vector3(-0.1, b0, zf), wh, 0.12)
	_kwall(g, Vector3(1.1, b0, zf), Vector3(xs, b0, zf), wh, 0.12)
	# corner towers (round-ish corner towers read as octagonal drums), wall towers
	for c in [Vector3(-xs, b0, zb), Vector3(xs, b0, zb), Vector3(xs, b0, zf)]:
		_ktower(g, c, 0.34, 0.62, 0.5, 0.0)
	_ktower(g, Vector3(0.0, b0, zb), 0.32, 0.6, 0.62, 0.065)
	_ktower(g, Vector3(-xs, b0, -0.3), 0.3, 0.56, 0.48, 0.0)
	_ktower(g, Vector3(xs, b0, -0.3), 0.3, 0.56, 0.48, 0.0)
	# main gate tower (Spasskaya-style) on the front-left corner: clock, tall spire, ruby star
	_ktower(g, Vector3(-xs + 0.05, b0, zf), 0.46, 0.85, 0.78, 0.085, true)
	# gate house + vehicle bay: brick block, arched opening facing the exit tile
	var bx := 0.5
	g.color(BRICK, Geo.CONCRETE)
	g.cbox(Vector3(bx, b0 + 0.36, 0.86), Vector3(1.24, 0.72, 0.72), 0.012)
	g.color(BRICK_D, Geo.CONCRETE)
	g.cbox(Vector3(bx, b0 + 0.74, 0.86), Vector3(1.28, 0.05, 0.76), 0.01)
	g.color("#16171a", Geo.DARK)
	g.box(Vector3(bx, b0 + 0.25, 1.215), Vector3(0.82, 0.5, 0.02))
	g.lathe([[0.0, 0.41], [0.02, 0.41], [0.02, 0.0]], 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(bx, b0 + 0.5, 1.205)).scaled_local(Vector3(1, 1, 0.38)), true, true)
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3(bx, b0 + 0.003, 1.0), Vector3(0.82, 0.004, 0.45))
	g.color(TRIM, Geo.CONCRETE)   # white stone arch trim + jambs
	for x in [bx - 0.44, bx + 0.44]:
		g.box(Vector3(x, b0 + 0.3, 1.225), Vector3(0.05, 0.6, 0.02))
	g.box(Vector3(bx, b0 + 0.64, 1.225), Vector3(0.94, 0.04, 0.02))
	g.color("#fff3c4", Geo.LAMP)
	for x in [bx - 0.32, bx + 0.32]:
		g.box(Vector3(x, b0 + 0.6, 1.235), Vector3(0.07, 0.03, 0.03))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(bx, b0 + 0.69, 1.226), Vector3(0.36, 0.04, 0.006))
	_ktower(g, Vector3(bx, b0 + 0.72, 0.8), 0.34, 0.26, 0.5, 0.06)   # gate tower over the bay
	# Grand Palace block: cream facade, white window surrounds, green roof, flag dome
	var pc := Vector3(-0.55, b0, -0.95)
	g.color(PALACE, Geo.CONCRETE)
	g.cbox(pc + Vector3(0, 0.36, 0), Vector3(1.9, 0.72, 0.95), 0.012)
	g.color(PALACE_D, Geo.CONCRETE)
	g.box(pc + Vector3(0, 0.05, 0), Vector3(1.94, 0.1, 0.99))
	g.box(pc + Vector3(0, 0.74, 0), Vector3(1.96, 0.04, 1.01))
	_wgrid(g, pc + Vector3(0, 0.42, 0.481), 1.7, 0.46, 11, 2, 0.0, 31, 0.35, TRIM)
	_wgrid(g, pc + Vector3(0.951, 0.42, 0), 0.8, 0.46, 5, 2, 90.0, 32, 0.3, TRIM)
	g.color(SPIRE, Geo.PAINT)
	g.prism_x([Vector2(-0.5, 0.0), Vector2(0.5, 0.0), Vector2(0.18, 0.2), Vector2(-0.18, 0.2)], -0.98, 0.98, Transform3D(Basis.IDENTITY, pc + Vector3(0, 0.76, 0)))
	g.color(PALACE_D, Geo.CONCRETE)
	g.cyl(0.16, 0.16, 0.14, 12, Transform3D(Basis.IDENTITY, pc + Vector3(0, 0.96, 0)))
	g.color(SPIRE, Geo.PAINT)
	g.dome(0.17, 0.14, 4, 12, Transform3D(Basis.IDENTITY, pc + Vector3(0, 1.1, 0)))
	R._ru_flag(g, pc + Vector3(0, 1.22, 0), 0.4)
	# cathedral square: white church with five golden onion domes
	var cc := Vector3(0.95, b0, -0.95)
	g.color(TRIM, Geo.CONCRETE)
	g.cbox(cc + Vector3(0, 0.3, 0), Vector3(0.62, 0.6, 0.6), 0.01)
	g.color("#cfc7b4", Geo.CONCRETE)
	for k in 3:   # zakomary arches on the front
		g.cyl(0.1, 0.1, 0.02, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), cc + Vector3(-0.2 + k * 0.2, 0.6, 0.31)))
	g.color("#2b2d2c", Geo.DARK)
	for k in 3:
		g.box(cc + Vector3(-0.2 + k * 0.2, 0.32, 0.305), Vector3(0.05, 0.16, 0.01))
	_onion(g, cc + Vector3(0, 0.6, 0), 0.12)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			_onion(g, cc + Vector3(s * 0.19, 0.6, t * 0.19), 0.075)
	# fir trees along the inner wall and a lamp at the gate
	g.color("#2f4a2e", Geo.CANVAS)
	for p in [Vector3(-1.5, b0, 0.6), Vector3(-1.1, b0, 0.75), Vector3(1.5, b0, 0.4), Vector3(-0.2, b0, 0.4), Vector3(-1.5, b0, 0.15)]:
		g.lathe([[0.0, 0.12], [0.32, 0.0]], 7, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.06, 0)))
	U()._lamp(g, Vector3(bx, b0 + 1.6, 0.8))

# ================================================================== brutalist helpers
## Raw concrete slab box with a darker underside line and board-joint bands every ~0.35.
static func _slab(g, c: Vector3, s: Vector3, col := BC) -> void:
	g.color(col, Geo.CONCRETE)
	g.cbox(c + Vector3(0, s.y * 0.5, 0), s, 0.01)
	g.color(BC_D, Geo.CONCRETE)
	g.box(c + Vector3(0, 0.008, 0), Vector3(s.x + 0.004, 0.016, s.z + 0.004))

## Deep-set repetitive window grid on a +z face (rotated by yaw): concrete fins between bays.
static func _bgrid(g, c: Vector3, w: float, h: float, cols: int, rows: int, yaw: float, seed_i: int) -> void:
	var bs := Basis(Vector3.UP, deg_to_rad(yaw))
	_wgrid(g, c, w, h, cols, rows, yaw, seed_i, 0.28)
	g.color(BC_L, Geo.CONCRETE)
	for k in cols + 1:
		var x := -w * 0.5 + w * k / float(cols)
		g.box(Vector3.ZERO, Vector3(0.035, h + 0.04, 0.06), Transform3D(bs, c + bs * Vector3(x, 0, 0.03)))
	for r in rows + 1:
		var y := -h * 0.5 + h * r / float(rows)
		g.box(Vector3.ZERO, Vector3(w + 0.04, 0.03, 0.07), Transform3D(bs, c + bs * Vector3(0, y, 0.035)))

# ================================================================== Supply Depot (brutalist)
static func _depot(g) -> void:
	# raised loading dock in front of a concrete store, all under a heavy cantilevered roof slab
	_slab(g, Vector3(0, Y0, 0.45), Vector3(2.7, 0.16, 1.0), BC_D)
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0, Y0 + 0.162, 0.95), Vector3(2.7, 0.006, 0.04))
	g.color("#1d1e1d", Geo.RUBBER)
	for x in [-0.9, -0.3, 0.3, 0.9]:
		g.box(Vector3(x, Y0 + 0.09, 0.96), Vector3(0.1, 0.08, 0.03))   # dock bumpers
	_slab(g, Vector3(-0.2, Y0, -0.75), Vector3(2.3, 1.0, 1.3))
	_bgrid(g, Vector3(-0.2, Y0 + 0.8, -0.095), 2.0, 0.26, 9, 1, 0.0, 41)
	g.rollup(Vector3(-0.75, Y0 + 0.27, -0.09), 0.5, 0.3)
	g.rollup(Vector3(0.35, Y0 + 0.27, -0.09), 0.5, 0.3)
	g.color(BC_L, Geo.CONCRETE)
	g.box(Vector3(-0.2, Y0 + 1.02, -0.75), Vector3(2.34, 0.04, 1.34))
	# cantilever: thick slab pushed out from the face over the dock, on two raking concrete legs
	_slab(g, Vector3(-0.1, Y0 + 0.58, 0.3), Vector3(2.7, 0.14, 1.0), BC_L)
	g.color(BC, Geo.CONCRETE)
	for x in [-1.3, 1.1]:
		g.prism_x([Vector2(-0.2, 0.0), Vector2(0.05, 0.0), Vector2(0.5, 0.58), Vector2(-0.2, 0.58)], x - 0.07, x + 0.07)
	g.color(BC_X, Geo.CONCRETE)
	for k in 6:   # beam ends showing on the slab edge
		g.box(Vector3(-1.35 + k * 0.5, Y0 + 0.65, 0.805), Vector3(0.12, 0.1, 0.012))
	# stair / lift tower and water tank
	_slab(g, Vector3(1.2, Y0, -1.0), Vector3(0.45, 1.05, 0.45))
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3(1.2, Y0 + 0.6, -0.774), Vector3(0.06, 0.6, 0.01))
	# cargo on the dock
	var cols := ["#6b5a3a", "#5d6346", "#7c6a45", "#4f5634"]
	for i in 6:
		g.color(cols[i % 4], Geo.WOOD)
		g.cbox(Vector3(-1.0 + (i % 3) * 0.32, Y0 + 0.27 + (i / 3) * 0.2, 0.55), Vector3(0.28, 0.2, 0.3), 0.012)
	g.color(RU, Geo.PAINT)
	for k in 3:
		g.cyl(0.07, 0.07, 0.2, 10, Transform3D(Basis.IDENTITY, Vector3(0.5 + k * 0.16, Y0 + 0.16, 0.5)))   # fuel drums
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.65, 0.808), Vector3(0.6, 0.06, 0.006))
	R._star(g, Vector3(-0.2, Y0 + 0.86, -0.088), 0.07)

# ================================================================== Barracks (brutalist slab block)
static func _barracks(g) -> void:
	var c := Vector3(-0.1, Y0, -0.55)
	# ground floor on pilotis, two repetitive upper floors that overhang it, roof plant box
	_slab(g, c + Vector3(0, 0, -0.05), Vector3(2.2, 0.32, 0.9), BC_D)
	g.color(BC, Geo.CONCRETE)
	for k in 7:
		g.cbox(c + Vector3(-1.2 + k * 0.4, 0.16, 0.5), Vector3(0.08, 0.32, 0.08), 0.008)   # pilotis
	_slab(g, c + Vector3(0, 0.32, 0), Vector3(2.6, 0.66, 1.1))
	_bgrid(g, c + Vector3(0, 0.65, 0.551), 2.4, 0.52, 12, 2, 0.0, 51)
	_bgrid(g, c + Vector3(0, 0.65, -0.551), 2.4, 0.52, 12, 2, 180.0, 52)
	g.color(BC_L, Geo.CONCRETE)
	g.box(c + Vector3(0, 1.0, 0), Vector3(2.64, 0.05, 1.14))
	_slab(g, c + Vector3(0.7, 1.02, -0.1), Vector3(0.7, 0.18, 0.5), BC_D)
	g.color("#2b2d2c", Geo.DARK)
	g.vent(c + Vector3(0.7, 1.12, 0.152), 0.5, 0.08, 6)
	# entrance under the overhang
	g.color("#3a3c3a", Geo.DARK)
	g.box(c + Vector3(0, 0.14, 0.406), Vector3(0.36, 0.26, 0.012))
	R._star(g, c + Vector3(0, 0.42, 0.57), 0.07)
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0, 0.36, 0.556), Vector3(2.4, 0.04, 0.008))
	# parade ground: painted lines, flag, pull-up bars
	g.color("#e8e8e4", Geo.PAINT)
	for k in 5:
		g.box(Vector3(-0.9 + k * 0.35, Y0 + 0.002, 0.85), Vector3(0.22, 0.004, 0.03))
	g.color(RU_S, Geo.STEEL)
	for x in [0.85, 1.2]:
		g.tube(Vector3(x, Y0, 0.85), Vector3(x, Y0 + 0.45, 0.85), 0.015, 4)
	g.tube(Vector3(0.85, Y0 + 0.45, 0.85), Vector3(1.2, Y0 + 0.45, 0.85), 0.012, 4)
	R._ru_flag(g, Vector3(-1.3, Y0, 1.1), 1.05)

# ================================================================== Vehicle Factory (brutalist hall)
static func _factory(g) -> void:
	var c := Vector3(0, Y0, -0.35)
	_slab(g, c, Vector3(3.3, 0.85, 2.3))
	# vertical fins along the sides, sawtooth roof lights
	g.color(BC_L, Geo.CONCRETE)
	for k in 9:
		for s in [-1.0, 1.0]:
			g.box(Vector3(s * 1.68, Y0 + 0.42, c.z - 1.05 + k * 0.26), Vector3(0.06, 0.84, 0.05))
	for k in 4:
		g.color(BC, Geo.CONCRETE)
		g.prism_x([Vector2(-0.24, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.22)], -1.5, 1.5, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.85, -0.85 + k * 0.48)))
		g.color(GLASS_C, Geo.GLASS)
		g.box(c + Vector3(0, 0.96, -0.85 + k * 0.48 + 0.245), Vector3(2.9, 0.18, 0.01))
	# two vehicle doors under a heavy cantilevered office bridge
	for x in [-0.8, 0.8]:
		g.rollup(Vector3(x, Y0 + 0.3, c.z + 1.155), 0.9, 0.58)
	g.color("#e8d34a", Geo.PAINT)
	for x in [-1.27, -0.33, 0.33, 1.27]:
		g.hazard(Vector3(x, Y0 + 0.3, c.z + 1.16), 0.05, 0.58, 4)
	_slab(g, Vector3(0, Y0 + 0.66, c.z + 1.25), Vector3(3.5, 0.42, 0.75), BC_L)
	_bgrid(g, Vector3(0, Y0 + 0.87, c.z + 1.626), 3.2, 0.22, 14, 1, 0.0, 61)
	g.color(BC, Geo.CONCRETE)
	for x in [-1.62, 1.62]:   # raking struts holding the bridge
		g.rcbox(Vector3(x, Y0 + 0.36, c.z + 1.45), Vector3(0.1, 0.7, 0.1), 0.01, Vector3(-22, 0, 0))
	# chimney + gantry yard
	g.color(BC_D, Geo.CONCRETE)
	g.cyl(0.13, 0.1, 1.45, 10, Transform3D(Basis.IDENTITY, Vector3(1.55, Y0, -1.6)))
	g.color("#b8352b", Geo.PAINT)
	g.cyl(0.103, 0.1, 0.1, 10, Transform3D(Basis.IDENTITY, Vector3(1.55, Y0 + 1.3, -1.6)))
	R._star(g, Vector3(0, Y0 + 0.93, c.z + 1.64), 0.1)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.5, c.z + 1.628), Vector3(3.3, 0.04, 0.006))
	R._ru_flag(g, Vector3(-1.75, Y0, 1.7), 1.1)

# ================================================================== Gas Processing Plant (power)
static func _gas_plant(g) -> void:
	g.color("#7d7a72", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.01, 0), Vector3(2.86, 0.02, 2.86), 0.01)
	# three processing columns with platforms, ladders and caps
	var cols := [[Vector3(-0.95, Y0, -0.85), 0.17, 1.95], [Vector3(-0.5, Y0, -0.95), 0.13, 1.6], [Vector3(-0.1, Y0, -0.85), 0.19, 1.75]]
	for cd in cols:
		var p: Vector3 = cd[0]
		var r: float = cd[1]
		var h: float = cd[2]
		g.color("#d9d9d2", Geo.STEEL)
		g.cyl(r, r, h, 14, Transform3D(Basis.IDENTITY, p))
		g.dome(r, r * 0.6, 3, 14, Transform3D(Basis.IDENTITY, p + Vector3(0, h, 0)))
		g.color("#9a9c98", Geo.STEEL)
		g.cyl(r * 1.15, r * 1.15, 0.12, 14, Transform3D(Basis.IDENTITY, p))   # skirt
		for k in 3:
			g.color("#c9a531", Geo.PAINT)
			g.cyl(r + 0.05, r + 0.05, 0.015, 14, Transform3D(Basis.IDENTITY, p + Vector3(0, h * (0.3 + k * 0.25), 0)))   # platforms
			g.rail_ring(r + 0.05, p.y + h * (0.3 + k * 0.25) + 0.015, 10, 0.06, Transform3D(Basis.IDENTITY, Vector3(p.x, 0, p.z)))
		g.ladder(p + Vector3(0, 0.1, r + 0.02), h - 0.15, Vector3(0, 0, 1))
	# spherical storage tanks on legs
	for sc in [Vector3(0.7, Y0, -0.85), Vector3(0.7, Y0, 0.2)]:
		g.color("#5a5d5a", Geo.STEEL)
		for k in 6:
			var a := TAU * k / 6.0
			g.tube(sc + Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), sc + Vector3(cos(a) * 0.3, 0.42, sin(a) * 0.3), 0.022, 5)
		g.color("#e6e6df", Geo.PAINT)
		_sphere(g, sc + Vector3(0, 0.62, 0), 0.38, 16, 9)
		g.color("#9a9c98", Geo.STEEL)
		g.band(0.385, 0.6, 0.03, 0.004, 16, Transform3D(Basis.IDENTITY, sc))
		g.color("#c9a531", Geo.PAINT)
		g.cyl(0.08, 0.08, 0.02, 8, Transform3D(Basis.IDENTITY, sc + Vector3(0, 1.0, 0)))
		g.pipe([sc + Vector3(0.3, 0.98, 0), sc + Vector3(0.3, 0.1, 0)], 0.008, 4)
	# pipe rack running across the plant (steel portal frames + bundled pipes)
	g.color("#55595a", Geo.STEEL)
	for k in 5:
		var x := -1.3 + k * 0.62
		for z in [-0.3, -0.05]:
			g.tube(Vector3(x, Y0, z), Vector3(x, Y0 + 0.55, z), 0.02, 4)
		g.box(Vector3(x, Y0 + 0.55, -0.175), Vector3(0.04, 0.04, 0.32))
		g.box(Vector3(x, Y0 + 0.36, -0.175), Vector3(0.03, 0.03, 0.32))
	var pcols := ["#c9a531", "#a8acaa", "#6f8a9a", "#b8352b", "#a8acaa"]
	for i in 5:
		g.color(pcols[i], Geo.STEEL)
		var z := -0.29 + i * 0.058
		g.tube(Vector3(-1.38, Y0 + 0.6, z), Vector3(1.38, Y0 + 0.6, z), 0.024, 6)
	for i in 3:
		g.color("#a8acaa", Geo.STEEL)
		g.tube(Vector3(-1.38, Y0 + 0.4, -0.25 + i * 0.07), Vector3(1.38, Y0 + 0.4, -0.25 + i * 0.07), 0.02, 6)
	g.color("#a8acaa", Geo.STEEL)
	for cd in cols:   # risers from each column into the rack
		var p: Vector3 = cd[0]
		g.pipe([p + Vector3(0.0, 0.5, cd[1]), p + Vector3(0.0, 0.62, cd[1] + 0.05), Vector3(p.x, Y0 + 0.62, -0.18)], 0.02, 5)
	# flare stack with a burning flame + guy wires
	var fp := Vector3(1.15, Y0, 1.05)
	g.color("#d9d9d2", Geo.STEEL)
	g.cyl(0.05, 0.035, 2.0, 8, Transform3D(Basis.IDENTITY, fp))
	g.color("#b8352b", Geo.PAINT)
	for k in 3:
		g.cyl(0.042, 0.04, 0.12, 8, Transform3D(Basis.IDENTITY, fp + Vector3(0, 1.4 + k * 0.22, 0)))
	g.color("#3a3c3a", Geo.STEEL)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		g.tube(fp + Vector3(0, 1.6, 0), fp + Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), 0.004, 3)
	g.pulse_color("#ffb03a", 0.0)
	g.lathe([[0.0, 0.05], [0.12, 0.07], [0.3, 0.0]], 8, Transform3D(Basis.IDENTITY, fp + Vector3(0, 2.0, 0)))
	g.end_pulse()
	g.color("#fff0a0", Geo.LAMP)
	g.lathe([[0.0, 0.03], [0.14, 0.0]], 6, Transform3D(Basis.IDENTITY, fp + Vector3(0, 2.0, 0)))
	# control room, compressor shed and transformer
	_slab(g, Vector3(-0.7, Y0, 0.75), Vector3(1.1, 0.42, 0.7))
	_bgrid(g, Vector3(-0.7, Y0 + 0.26, 1.101), 0.9, 0.14, 6, 1, 0.0, 71)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.7, Y0 + 0.4, 1.102), Vector3(1.0, 0.03, 0.006))
	g.color(RU_D, Geo.CORR)
	g.cbox(Vector3(0.2, Y0 + 0.17, 0.95), Vector3(0.5, 0.34, 0.55), 0.01)
	g.color("#2b2d2c", Geo.DARK)
	g.vent(Vector3(0.2, Y0 + 0.2, 1.226), 0.36, 0.14, 5)
	g.color("#6a6d68", Geo.STEEL)
	g.cbox(Vector3(-1.2, Y0 + 0.15, 0.2), Vector3(0.3, 0.3, 0.3), 0.012)
	for x in [-1.28, -1.2, -1.12]:
		g.insulator(Vector3(x, Y0 + 0.3, 0.2), 0.14)
	U()._lamp(g, Vector3(-0.95, Y0 + 2.1, -0.85))

# ================================================================== Ministry of Defense
static func _ministry(g) -> void:
	g.color("#8d8a82", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.01, 0), Vector3(3.84, 0.02, 3.84), 0.01)
	var b0 := Y0 + 0.02
	# wide stone wing with rusticated base, window grid, cornice
	g.color(ST_D, Geo.CONCRETE)
	g.cbox(Vector3(0, b0 + 0.11, -0.35), Vector3(3.5, 0.22, 1.7), 0.01)
	g.color(ST, Geo.CONCRETE)
	g.cbox(Vector3(0, b0 + 0.22 + 0.27, -0.35), Vector3(3.4, 0.54, 1.6), 0.01)
	g.color(ST_L, Geo.CONCRETE)
	g.box(Vector3(0, b0 + 0.78, -0.35), Vector3(3.5, 0.05, 1.7))
	for s in [-1.0, 1.0]:
		_wgrid(g, Vector3(s * 1.1, b0 + 0.5, 0.451), 1.1, 0.4, 7, 2, 0.0, 80 + int(s), 0.35, ST_D)
	_wgrid(g, Vector3(1.701, b0 + 0.5, -0.35), 1.4, 0.4, 8, 2, 90.0, 83, 0.3, ST_D)
	_wgrid(g, Vector3(-1.701, b0 + 0.5, -0.35), 1.4, 0.4, 8, 2, -90.0, 84, 0.3, ST_D)
	# colonnaded portico with a pediment and a star
	g.color(ST_L, Geo.CONCRETE)
	g.cbox(Vector3(0, b0 + 0.04, 0.72), Vector3(1.3, 0.08, 0.6), 0.01)   # steps
	for k in 6:
		var x := -0.55 + k * 0.22
		g.cyl(0.045, 0.04, 0.62, 10, Transform3D(Basis.IDENTITY, Vector3(x, b0 + 0.08, 0.9)))
		g.box(Vector3(x, b0 + 0.71, 0.9), Vector3(0.11, 0.03, 0.11))
	g.box(Vector3(0, b0 + 0.75, 0.68), Vector3(1.4, 0.07, 0.56))
	g.prism_x([Vector2(0.4, 0.0), Vector2(0.96, 0.0), Vector2(0.96, 0.2)], -0.7, 0.7, Transform3D(Basis.IDENTITY, Vector3(0, b0 + 0.785, 0)))
	g.color("#3a3c3a", Geo.DARK)
	g.box(Vector3(0, b0 + 0.3, 0.452), Vector3(0.9, 0.44, 0.01))
	g.color("#fff3c4", Geo.LAMP)
	for x in [-0.28, 0.0, 0.28]:
		g.box(Vector3(x, b0 + 0.3, 0.459), Vector3(0.12, 0.3, 0.004))
	R._star(g, Vector3(0, b0 + 0.88, 0.962), 0.07)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, b0 + 0.75, 0.962), Vector3(1.1, 0.04, 0.006))
	# stepped central tower (three setbacks) with pinnacles, spire and ruby star
	var tz := -0.55
	var tiers := [[1.3, 0.95, 0.42], [0.9, 0.7, 0.36], [0.56, 0.45, 0.3]]
	var y := b0 + 0.8
	var i := 0
	for td in tiers:
		var w: float = td[0]
		var d: float = td[1]
		var h: float = td[2]
		g.color(ST, Geo.CONCRETE)
		g.cbox(Vector3(0, y + h * 0.5, tz), Vector3(w, h, d), 0.01)
		g.color(ST_L, Geo.CONCRETE)
		g.box(Vector3(0, y + h + 0.015, tz), Vector3(w + 0.04, 0.03, d + 0.04))
		_wgrid(g, Vector3(0, y + h * 0.5, tz + d * 0.5 + 0.001), w * 0.8, h * 0.6, int(w * 6), 2, 0.0, 90 + i, 0.4, ST_D)
		_wgrid(g, Vector3(w * 0.5 + 0.001, y + h * 0.5, tz), d * 0.7, h * 0.6, int(d * 5), 2, 90.0, 95 + i, 0.3, ST_D)
		g.color(ST_L, Geo.CONCRETE)
		for s in [-1.0, 1.0]:
			for t in [-1.0, 1.0]:
				g.lathe([[0.0, 0.035], [0.12, 0.0]], 4, Transform3D(Basis.IDENTITY, Vector3(s * (w * 0.5 - 0.03), y + h + 0.03, tz + t * (d * 0.5 - 0.03))))
		y += h + 0.03
		i += 1
	g.color(GOLD, Geo.STEEL)
	g.lathe([[0.0, 0.1], [0.06, 0.09], [0.5, 0.008]], 8, Transform3D(Basis.IDENTITY, Vector3(0, y, tz)))
	_ruby(g, Vector3(0, y + 0.58, tz), 0.06)
	_ruby(g, Vector3(0, y + 0.58, tz), 0.06, 90.0)
	R._ru_flag(g, Vector3(1.55, b0 + 0.8, 0.3), 0.45)
	V4._antenna(g, Vector3(-1.4, b0 + 0.8, -1.0), 0.45)
	g.color("#c9c6bc", Geo.PAINT)
	g.cyl(0.14, 0.1, 0.04, 12, Transform3D(Basis(Vector3.RIGHT, -PI * 0.35), Vector3(-1.1, b0 + 0.95, -0.9)))

# ================================================================== Black Market (passive income)
static func _black_market(g) -> void:
	g.color("#77736a", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.01, 0), Vector3(2.86, 0.02, 2.86), 0.01)
	# old warehouse with a half-open shutter and a hand-painted sign board
	g.color("#6d6f66", Geo.CORR)
	g.cbox(Vector3(-0.35, Y0 + 0.36, -0.85), Vector3(2.0, 0.72, 1.0), 0.01)
	g.color("#5a5c55", Geo.CORR)
	g.prism_x([Vector2(-0.52, 0.0), Vector2(0.52, 0.0), Vector2(0.0, 0.2)], -1.38, 0.68, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.72, -0.85)))
	g.color("#16171a", Geo.DARK)
	g.box(Vector3(-0.6, Y0 + 0.2, -0.345), Vector3(0.6, 0.38, 0.01))
	g.rollup(Vector3(-0.6, Y0 + 0.5, -0.34), 0.62, 0.2)
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3(0.3, Y0 + 0.62, -0.343), Vector3(0.6, 0.12, 0.01))
	g.color("#ffb03a", Geo.LAMP)
	g.box(Vector3(0.3, Y0 + 0.62, -0.336), Vector3(0.5, 0.06, 0.004))   # lit sign
	# stacked shipping containers (mixed liveries)
	var ccol := ["#8a3b2a", "#2f5a7a", "#7a6a2f", "#3f6a45", "#8a3b2a"]
	var cpos := [Vector3(1.0, Y0, -1.0), Vector3(1.0, Y0 + 0.3, -1.0), Vector3(1.0, Y0, -0.35), Vector3(-1.1, Y0, 0.95), Vector3(1.05, Y0, 0.85)]
	for i in 5:
		var p: Vector3 = cpos[i]
		var rot := 0.0 if i < 3 else PI * 0.5
		g.color(ccol[i], Geo.CORR)
		g.cbox(Vector3.ZERO, Vector3(0.6, 0.3, 0.28) if i < 3 else Vector3(0.6, 0.3, 0.28), 0.008, Transform3D(Basis(Vector3.UP, rot + PI * 0.5), p + Vector3(0, 0.15, 0)))
		g.color("#2b2d2c", Geo.DARK)
		g.box(Vector3.ZERO, Vector3(0.006, 0.26, 0.24), Transform3D(Basis(Vector3.UP, rot + PI * 0.5), p + Vector3(0, 0.15, 0) + Basis(Vector3.UP, rot + PI * 0.5) * Vector3(0.302, 0, 0)))
	# market stalls with striped canvas awnings, crates, drums
	var acol := [["#b8352b", "#e4ddcc"], ["#2f5a7a", "#e4ddcc"], ["#3f6a45", "#d8a531"]]
	for i in 3:
		var x := -0.9 + i * 0.62
		g.color("#5e5a3e", Geo.WOOD)
		g.cbox(Vector3(x, Y0 + 0.1, 0.25), Vector3(0.48, 0.2, 0.3), 0.01)   # counter
		g.color(RU_S, Geo.STEEL)
		for s in [-1.0, 1.0]:
			g.tube(Vector3(x + s * 0.25, Y0, 0.45), Vector3(x + s * 0.25, Y0 + 0.42, 0.45), 0.01, 4)
		for k in 4:
			g.color(acol[i][k % 2], Geo.CANVAS)
			g.rbox(Vector3(x - 0.195 + k * 0.13, Y0 + 0.44, 0.3), Vector3(0.13, 0.012, 0.42), Vector3(-14, 0, 0))
		var goods := ["#7c6a45", "#5d6346", "#4a5a6a"]
		for k in 3:
			g.color(goods[(i + k) % 3], Geo.WOOD)
			g.cbox(Vector3(x - 0.14 + k * 0.14, Y0 + 0.24, 0.25), Vector3(0.1, 0.08, 0.12), 0.006)
	var crates := ["#6b5a3a", "#7c6a45", "#5d6346"]
	for i in 7:
		g.color(crates[i % 3], Geo.WOOD)
		g.cbox(Vector3(-0.2 + (i % 4) * 0.2, Y0 + 0.08 + (i / 4) * 0.15, 0.95), Vector3(0.17, 0.15, 0.17), 0.008)
	g.color("#3f4a3a", Geo.PAINT)
	for k in 3:
		g.cyl(0.06, 0.06, 0.17, 10, Transform3D(Basis.IDENTITY, Vector3(0.65 + k * 0.13, Y0, 0.3)))
	# string lights over the alley
	g.color("#2b2d2c", Geo.STEEL)
	g.tube(Vector3(-1.35, Y0 + 0.62, 0.55), Vector3(0.8, Y0 + 0.56, 0.55), 0.004, 3)
	g.tube(Vector3(-1.35, Y0, 0.55), Vector3(-1.35, Y0 + 0.62, 0.55), 0.012, 4)
	g.tube(Vector3(0.8, Y0, 0.55), Vector3(0.8, Y0 + 0.56, 0.55), 0.012, 4)
	g.color("#ffd27a", Geo.LAMP)
	for k in 10:
		var t := k / 9.0
		g.cbox(Vector3(lerpf(-1.3, 0.75, t), Y0 + 0.6 - 0.06 * t - 0.04 * sin(t * PI), 0.55), Vector3(0.025, 0.025, 0.025), 0.005)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.35, Y0 + 0.69, -0.343), Vector3(1.9, 0.04, 0.006))

# ================================================================== Kornet Nest (AT defence)
static func _kornet_nest(g) -> void:
	g.color("#7d6e52", Geo.SANDBAG)
	g.cyl(0.82, 0.86, 0.04, 14, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))   # trampled earth floor
	for ring in 3:   # three courses of sandbags, staggered, with a gap at the back for the crew
		var r := 0.78 - ring * 0.04
		var n := 16
		for k in n:
			var a := TAU * (k + (0.5 if ring % 2 == 1 else 0.0)) / float(n)
			if absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.32:
				continue
			g.sandbag(Vector3(cos(a) * r, Y0 + 0.02 + ring * 0.075, sin(a) * r), 0.3, rad_to_deg(-a + PI * 0.5), "#a39168" if (k + ring) % 3 else "#8f7f5a")
	# ammo: missile transport-launch containers in an open crate, spare tubes
	g.color("#5e5a3e", Geo.WOOD)
	g.cbox(Vector3(-0.45, Y0 + 0.08, -0.35), Vector3(0.3, 0.12, 0.4), 0.01)
	g.color(RU_D, Geo.PAINT)
	for k in 3:
		g.tube(Vector3(-0.53 + k * 0.08, Y0 + 0.17, -0.53), Vector3(-0.53 + k * 0.08, Y0 + 0.17, -0.17), 0.035, 8)
	g.tube(Vector3(0.35, Y0 + 0.06, -0.5), Vector3(0.62, Y0 + 0.06, -0.3), 0.035, 8)
	g.color("#3f4a3a", Geo.PAINT)
	g.cbox(Vector3(0.45, Y0 + 0.07, -0.2), Vector3(0.18, 0.1, 0.12), 0.01)   # radio
	V4._antenna(g, Vector3(0.5, Y0 + 0.12, -0.22), 0.4)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.2, 0.79), Vector3(0.3, 0.04, 0.01))

static func _kornet_launcher(t, x: float) -> void:
	# tripod
	t.color(RU_S, Geo.STEEL)
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5
		t.tube(Vector3(x, 0.3, 0), Vector3(x + cos(a) * 0.2, 0.0, sin(a) * 0.2 - 0.04), 0.012, 4)
	t.cyl(0.03, 0.03, 0.06, 8, Transform3D(Basis.IDENTITY, Vector3(x, 0.27, 0)))
	# guidance unit (box with optics) under the launch tube
	t.color("#4a5038", Geo.PAINT)
	t.cbox(Vector3(x, 0.38, -0.04), Vector3(0.11, 0.1, 0.16), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(x, 0.39, 0.042), Vector3(0.07, 0.05, 0.006))
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(x + 0.07, 0.4, -0.08), Vector3(0.05, 0.05, 0.08), 0.008)   # thermal sight
	# transport-launch container
	t.color(RU_D, Geo.PAINT)
	t.tube(Vector3(x, 0.48, -0.42), Vector3(x, 0.48, 0.42), 0.045, 10)
	t.color(RU, Geo.PAINT)
	for z in [-0.36, 0.0, 0.36]:
		t.tube(Vector3(x, 0.48, z - 0.02), Vector3(x, 0.48, z + 0.02), 0.052, 10)
	t.color("#1d1e1d", Geo.DARK)
	t.tube(Vector3(x, 0.48, 0.42), Vector3(x, 0.48, 0.43), 0.035, 10)

static func _kornet_turret(t) -> void:
	t.xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.35), Vector3.ZERO)
	_kornet_launcher(t, -0.22)
	_kornet_launcher(t, 0.22)
	t.xf = Transform3D.IDENTITY

# ================================================================== ZAK-30 Citadel (AA)
static func _zak_base(g) -> void:
	g.color(BC_D, Geo.CONCRETE)
	g.cyl(0.88, 0.8, 0.14, 6, Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3(0, Y0, 0)))
	g.color(BC, Geo.CONCRETE)
	g.cyl(0.6, 0.5, 0.26, 6, Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3(0, Y0 + 0.14, 0)))   # plinth
	g.color("#6f7472", Geo.STEEL)
	g.cyl(0.46, 0.46, 0.03, 18, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.4, 0)))   # deck ring
	g.color("#2b2d2c", Geo.DARK)
	g.hatch(Vector3(-0.3, Y0 + 0.401, 0.62), 0.16)
	g.color("#55595a", Geo.STEEL)   # ammo feed hatch + cabinet, ladder
	g.cbox(Vector3(0.6, Y0 + 0.2, -0.45), Vector3(0.28, 0.4, 0.22), 0.01)
	g.ladder(Vector3(0.0, Y0 + 0.14, 0.59), 0.26, Vector3(0, 0, 1))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.28, 0.555), Vector3(0.3, 0.04, 0.01))
	g.color(RU_S, Geo.STEEL)   # fire-control radar mast
	g.tube(Vector3(-0.62, Y0 + 0.14, -0.4), Vector3(-0.62, Y0 + 0.95, -0.4), 0.025, 6)
	g.color("#8c9396", Geo.PAINT)
	g.cbox(Vector3(-0.62, Y0 + 0.98, -0.4), Vector3(0.24, 0.12, 0.08), 0.02)

static func _rotary(t, c: Vector3) -> void:
	t.color("#3e4346", Geo.STEEL)
	t.cyl(0.055, 0.055, 0.14, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, 0, 0.0)))   # breech drum
	for k in 6:
		var a := TAU * k / 6.0
		var o := Vector3(cos(a) * 0.028, sin(a) * 0.028, 0)
		t.tube(c + o + Vector3(0, 0, 0.07), c + o + Vector3(0, 0, 0.6), 0.009, 4)
	for z in [0.32, 0.56]:
		t.cyl(0.045, 0.045, 0.02, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, 0, z)))   # barrel clamps

static func _zak_turret(t) -> void:
	# low faceted naval-style housing (stealthy angled faces), radar/optronic head on top
	t.color("#7c8386", Geo.PAINT)
	t.plan_loft([Vector2(-0.3, -0.36), Vector2(0.3, -0.36), Vector2(0.38, -0.05), Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(-0.38, -0.05)], 0.0, 0.32, Vector2(0.78, 0.8), Vector2(0, -0.03))
	t.color("#6a7174", Geo.PAINT)
	t.cbox(Vector3(0, 0.36, -0.12), Vector3(0.3, 0.1, 0.26), 0.02)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0, 0.37, 0.012), Vector3(0.16, 0.05, 0.006))
	t.color("#8c9396", Geo.PAINT)
	t.cyl(0.05, 0.05, 0.08, 10, Transform3D(Basis.IDENTITY, Vector3(0.1, 0.41, -0.18)))
	t.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.335, 0.16, -0.1), Vector3(0.006, 0.05, 0.2), Vector3(0, 0, s * -12.0))
	# twin six-barrel 30 mm guns either side, ammo drums behind
	for s in [-1.0, 1.0]:
		t.color("#6a7174", Geo.PAINT)
		t.cbox(Vector3(s * 0.3, 0.2, 0.1), Vector3(0.12, 0.14, 0.24), 0.015)
		_rotary(t, Vector3(s * 0.3, 0.2, 0.2))
		t.color("#55595a", Geo.STEEL)
		t.cyl(0.08, 0.08, 0.1, 12, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(s * 0.33, 0.14, -0.22)))

# ================================================================== Airfield (shared air base)
static func _airfield(g) -> void:
	U()._airbase8(g, "ecc")
	var bw := 8.0 / 3.0
	for b in 3:
		var cx := -4.0 + bw * (b + 0.5)
		R._star(g, Vector3(cx, Y0 + 1.87, -1.73), 0.13)
	R._ru_flag(g, Vector3(2.9, Y0, -1.55), 1.3)

# ================================================================== aircraft helpers
static func _nozzle(h, c: Vector3, r: float, l: float) -> void:
	h.color(AIR_S, Geo.STEEL)
	h.tube(c, c + Vector3(0, 0, -l), r, 10, r * 0.86)
	h.color("#2a2c2e", Geo.DARK)
	h.tube(c + Vector3(0, 0, -l), c + Vector3(0, 0, -l - 0.005), r * 0.86, 10, r * 0.6)
	h.color("#ff7a2a", Geo.LAMP)
	h.tube(c + Vector3(0, 0, -l + 0.03), c + Vector3(0, 0, -l - 0.004), r * 0.55, 8)

static func _gear(h, pts: Array, r: float) -> void:
	h.color(AIR_S, Geo.STEEL)
	for p: Vector3 in pts:
		h.tube(p + Vector3(0, r, 0), p + Vector3(0, r + 0.12, 0), 0.013, 4)
		h.tyre(p + Vector3(0, r, 0), r, r * 0.8, false, AIR_S, 8)

# ================================================================== Su-57 fighter
static func _su57() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.9, "bar_height": 1.0, "recoil": 0.0, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.plain = true   # own two-tone grey-blue scheme (no ground camo)
	# slim central fuselage + wide flat lifting body between widely spaced engine nacelles
	h.color(SU, Geo.PAINT)
	h.xloft([[1.06, K.sect(0.235, 0.24, 0.25, 0.004, 0.01, 0.004, 0.0)], [0.75, K.sect(0.18, 0.23, 0.31, 0.04, 0.08, 0.045, 0.015)],
		[0.4, K.sect(0.16, 0.22, 0.33, 0.07, 0.12, 0.07, 0.03)], [-0.2, K.sect(0.17, 0.22, 0.3, 0.08, 0.13, 0.08, 0.03)],
		[-0.72, K.sect(0.18, 0.22, 0.28, 0.05, 0.07, 0.05, 0.02)], [-1.02, K.sect(0.2, 0.22, 0.25, 0.02, 0.03, 0.02, 0.006)]])
	h.color(SU_D, Geo.PAINT)
	_surf(h, [Vector3(-0.08, 0.205, 0.42), Vector3(0.08, 0.205, 0.42), Vector3(0.3, 0.2, -0.75), Vector3(-0.3, 0.2, -0.75)], Vector3(0, 1, 0), 0.06, 0.06)   # flat centre body
	# IRST ball + bubble canopy
	h.color(GLASS_C, Geo.GLASS)
	h.cyl(0.022, 0.022, 0.02, 8, Transform3D(Basis.IDENTITY, Vector3(0.03, 0.29, 0.72)))
	h.color("#a07a2a", Geo.GLASS)
	h.xloft([[0.7, K.sect(0.3, 0.305, 0.31, 0.02, 0.025, 0.02, 0.004)], [0.55, K.sect(0.29, 0.31, 0.375, 0.04, 0.048, 0.032, 0.014)],
		[0.36, K.sect(0.29, 0.31, 0.365, 0.04, 0.046, 0.03, 0.014)], [0.22, K.sect(0.3, 0.31, 0.32, 0.018, 0.022, 0.018, 0.004)]])
	# engine nacelles under the body with rectangular raked intakes and round nozzles
	for s in [-1.0, 1.0]:
		h.color(SU_D, Geo.PAINT)
		h.xloft([[0.42, K.sect(0.08, 0.13, 0.2, 0.065, 0.075, 0.065, 0.015)], [-0.2, K.sect(0.08, 0.14, 0.21, 0.07, 0.08, 0.07, 0.02)], [-0.8, K.sect(0.1, 0.15, 0.2, 0.06, 0.065, 0.06, 0.02)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.2, 0, 0)))
		h.color("#1d1f1e", Geo.DARK)
		h.plate(Vector3(s * 0.2, 0.135, 0.43), Vector3(0.13, 0.1, 0.008), Vector3(-15, 0, 0))
		_nozzle(h, Vector3(s * 0.2, 0.15, -0.8), 0.06, 0.16)
	# LEVCONs, trapezoid wings, all-moving twin fins (canted), tailerons
	for s in [-1.0, 1.0]:
		h.color(SU, Geo.PAINT)
		_surf(h, [Vector3(s * 0.12, 0.21, 0.5), Vector3(s * 0.32, 0.2, 0.24), Vector3(s * 0.32, 0.2, 0.18), Vector3(s * 0.12, 0.21, 0.28)], Vector3(0, 1, 0), 0.025, 0.01)
		_surf(h, [Vector3(s * 0.3, 0.2, 0.22), Vector3(s * 0.82, 0.19, -0.38), Vector3(s * 0.82, 0.19, -0.52), Vector3(s * 0.3, 0.2, -0.62)], Vector3(0, 1, 0), 0.05, 0.012)
		h.color(SU_D, Geo.PAINT)   # darker splinter patch
		_surf(h, [Vector3(s * 0.45, 0.205, 0.02), Vector3(s * 0.7, 0.2, -0.26), Vector3(s * 0.7, 0.2, -0.42), Vector3(s * 0.45, 0.205, -0.36)], Vector3(0, 1, 0), 0.054, 0.016)
		h.color(SU, Geo.PAINT)
		_surf(h, [Vector3(s * 0.26, 0.19, -0.66), Vector3(s * 0.62, 0.18, -0.86), Vector3(s * 0.62, 0.18, -0.98), Vector3(s * 0.26, 0.19, -0.92)], Vector3(0, 1, 0), 0.025, 0.008)
		var fb := Basis(Vector3.FORWARD, s * deg_to_rad(24.0))
		h.color(SU_L, Geo.PAINT)
		_surf(h, [Vector3(0, 0, -0.5), Vector3(0, 0.3, -0.74), Vector3(0, 0.3, -0.86), Vector3(0, 0, -0.84)], Vector3(1, 0, 0), 0.02, 0.008, Transform3D(fb, Vector3(s * 0.22, 0.22, 0)))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.58, 0.2, -0.33), Vector3(0.16, 0.012, 0.08))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.33, -0.2), Vector3(0.05, 0.008, 0.3))
	_gear(h, [Vector3(0, 0.0, 0.55), Vector3(-0.2, 0.0, -0.18), Vector3(0.2, 0.0, -0.18)], 0.04)
	U()._vfinish(root, model, h, mat, "su57", [], 1.0, "ecc")

static func _surf(h, pts: Array, up: Vector3, th0: float, th1: float, t := Transform3D.IDENTITY) -> void:
	V8()._surf(h, pts, up, th0, th1, t)

# ================================================================== Tu-160 heavy bomber
static func _tu160() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 1.45, "bar_height": 1.3, "recoil": 0.0, "wreck_s": 8.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.plain = true   # anti-flash white
	# long slender fuselage, pointed nose with refuelling probe, blended into a wide wing glove
	h.color(TU, Geo.PAINT)
	h.xloft([[1.62, K.sect(0.29, 0.3, 0.31, 0.004, 0.01, 0.004, 0.0)], [1.32, K.sect(0.22, 0.29, 0.38, 0.05, 0.08, 0.05, 0.02)],
		[0.95, K.sect(0.19, 0.29, 0.44, 0.09, 0.13, 0.09, 0.04)], [0.45, K.sect(0.17, 0.29, 0.44, 0.12, 0.17, 0.11, 0.05)],
		[-0.6, K.sect(0.17, 0.29, 0.42, 0.12, 0.16, 0.1, 0.05)], [-1.2, K.sect(0.24, 0.3, 0.39, 0.06, 0.08, 0.05, 0.03)],
		[-1.52, K.sect(0.3, 0.32, 0.35, 0.02, 0.03, 0.02, 0.008)]])
	h.color(AIR_S, Geo.STEEL)
	h.tube(Vector3(0, 0.36, 1.45), Vector3(0, 0.33, 1.72), 0.01, 4)   # refuelling probe
	h.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.06, 0.42, 1.18), Vector3(0.006, 0.045, 0.14), Vector3(-22, s * -8.0, s * -38.0))
	h.plate(Vector3(0, 0.44, 1.14), Vector3(0.09, 0.006, 0.1), Vector3(-22, 0, 0))
	h.color(TU_D, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.42, 0.44, 0.47, 0.04, 0.05, 0.035, 0.012)], [-0.9, K.sect(0.39, 0.41, 0.45, 0.04, 0.05, 0.035, 0.012)]])   # dorsal spine
	# fixed glove (long LE root extension) + swing wings swept for the run, tailplanes on the fin
	for s in [-1.0, 1.0]:
		h.color(TU, Geo.PAINT)
		_surf(h, [Vector3(s * 0.1, 0.29, 0.85), Vector3(s * 0.46, 0.27, 0.05), Vector3(s * 0.46, 0.27, -0.5), Vector3(s * 0.12, 0.29, -0.5)], Vector3(0, 1, 0), 0.07, 0.04)
		_surf(h, [Vector3(s * 0.44, 0.27, 0.02), Vector3(s * 1.28, 0.25, -0.92), Vector3(s * 1.28, 0.25, -1.05), Vector3(s * 0.44, 0.27, -0.42)], Vector3(0, 1, 0), 0.05, 0.012)
		_surf(h, [Vector3(s * 0.03, 0.66, -1.12), Vector3(s * 0.58, 0.66, -1.36), Vector3(s * 0.58, 0.66, -1.47), Vector3(s * 0.03, 0.66, -1.46)], Vector3(0, 1, 0), 0.03, 0.01)
		# paired engine nacelle under the glove: long box, splitter intakes, four nozzles total
		h.color(TU_D, Geo.PAINT)
		h.xloft([[0.0, K.sect(0.05, 0.1, 0.19, 0.15, 0.16, 0.14, 0.03)], [-0.95, K.sect(0.06, 0.11, 0.2, 0.15, 0.16, 0.14, 0.03)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.4, 0, 0)))
		h.color("#1d1f1e", Geo.DARK)
		h.plate(Vector3(s * 0.4, 0.12, 0.0), Vector3(0.28, 0.1, 0.008), Vector3(-10, 0, 0))
		h.color(TU, Geo.PAINT)
		h.box(Vector3(s * 0.4, 0.12, -0.05), Vector3(0.01, 0.12, 0.1))   # splitter
		for k in 2:
			_nozzle(h, Vector3(s * (0.33 + 0.14 * k), 0.12, -0.95), 0.055, 0.14)
	# tall fin with an all-moving upper section
	h.color(TU, Geo.PAINT)
	_surf(h, [Vector3(0, 0.38, -0.78), Vector3(0, 0.82, -1.18), Vector3(0, 0.82, -1.36), Vector3(0, 0.36, -1.5)], Vector3(1, 0, 0), 0.05, 0.03)
	h.color(TU_D, Geo.PAINT)
	_surf(h, [Vector3(0, 0.82, -1.18), Vector3(0, 1.06, -1.38), Vector3(0, 1.06, -1.52), Vector3(0, 0.82, -1.36)], Vector3(1, 0, 0), 0.03, 0.018)
	h.color("#b8352b", Geo.PAINT)   # red star on the fin
	h.plate(Vector3(0, 0.78, -1.3), Vector3(0.036, 0.09, 0.09), Vector3.ZERO)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.95, 0.262, -0.62), Vector3(0.26, 0.012, 0.11))
	h.box(Vector3(0, 0.455, 0.4), Vector3(0.06, 0.008, 0.5))
	_gear(h, [Vector3(0, 0.0, 1.0), Vector3(-0.28, 0.0, -0.32), Vector3(0.28, 0.0, -0.32), Vector3(-0.28, 0.0, -0.5), Vector3(0.28, 0.0, -0.5)], 0.055)
	U()._vfinish(root, model, h, mat, "tu160", [], 1.3, "ecc")

# ================================================================== Ka-52 attack helicopter (coaxial)
static func _ka52() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.9, "bar_height": 1.3, "recoil": 0.02, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# broad side-by-side cockpit nose, deep fuselage, slim tail boom
	h.color(RU, Geo.PAINT)
	h.xloft([[0.8, K.sect(0.22, 0.26, 0.3, 0.03, 0.05, 0.03, 0.012)], [0.62, K.sect(0.13, 0.24, 0.36, 0.1, 0.13, 0.09, 0.03)],
		[0.3, K.sect(0.1, 0.25, 0.48, 0.15, 0.17, 0.13, 0.05)], [-0.25, K.sect(0.12, 0.27, 0.52, 0.15, 0.17, 0.13, 0.05)],
		[-0.48, K.sect(0.24, 0.3, 0.46, 0.08, 0.09, 0.07, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)   # wide two-seat canopy, flat panes
	h.xloft([[0.58, K.sect(0.36, 0.37, 0.4, 0.11, 0.115, 0.09, 0.015)], [0.42, K.sect(0.36, 0.4, 0.52, 0.135, 0.14, 0.1, 0.03)], [0.2, K.sect(0.36, 0.41, 0.54, 0.135, 0.14, 0.1, 0.03)], [0.14, K.sect(0.38, 0.42, 0.5, 0.12, 0.125, 0.09, 0.02)]])
	h.color(RU_S, Geo.PAINT)
	h.box(Vector3(0, 0.53, 0.3), Vector3(0.02, 0.012, 0.3))   # canopy centre frame
	h.color("#5a5e55", Geo.PAINT)
	h.lathe([[0.0, 0.07], [0.06, 0.06], [0.1, 0.0]], 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.27, 0.78)))   # radar nose
	h.color(GLASS_C, Geo.GLASS)
	h.cyl(0.05, 0.05, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0.62)))   # sensor ball
	# engines high on the sides, exhausts, hump
	for s in [-1.0, 1.0]:
		h.color(RU_D, Geo.PAINT)
		h.tube(Vector3(s * 0.2, 0.47, 0.12), Vector3(s * 0.2, 0.47, -0.36), 0.075, 8, 0.07)
		h.color("#1d1f1e", Geo.DARK)
		h.tube(Vector3(s * 0.2, 0.47, 0.125), Vector3(s * 0.2, 0.47, 0.135), 0.055, 8)
		h.color(RU_S, Geo.STEEL)
		h.plate(Vector3(s * 0.26, 0.45, -0.38), Vector3(0.06, 0.1, 0.12), Vector3(-20, 0, s * 25.0))
	h.color(RU, Geo.PAINT)
	h.xloft([[0.1, K.sect(0.48, 0.53, 0.62, 0.11, 0.12, 0.08, 0.03)], [-0.35, K.sect(0.48, 0.53, 0.6, 0.11, 0.12, 0.08, 0.03)], [-0.48, K.sect(0.46, 0.48, 0.5, 0.06, 0.07, 0.05, 0.01)]])
	# tall coaxial mast: two hubs, lower and upper rotor
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.6, -0.08), Vector3(0, 0.98, -0.08), 0.035, 8)
	h.cyl(0.06, 0.05, 0.06, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.82, -0.08)))
	# tail boom, twin end-plate fins on a tailplane, tail wheel
	h.color(RU_D, Geo.PAINT)
	h.tube(Vector3(0, 0.36, -0.46), Vector3(0, 0.42, -1.24), 0.08, 8, 0.045)
	h.color(RU, Geo.PAINT)
	_surf(h, [Vector3(-0.3, 0.44, -1.06), Vector3(0.3, 0.44, -1.06), Vector3(0.3, 0.44, -1.2), Vector3(-0.3, 0.44, -1.2)], Vector3(0, 1, 0), 0.025, 0.025)
	for s in [-1.0, 1.0]:
		_surf(h, [Vector3(s * 0.3, 0.32, -1.04), Vector3(s * 0.3, 0.66, -1.14), Vector3(s * 0.3, 0.66, -1.24), Vector3(s * 0.3, 0.32, -1.22)], Vector3(1, 0, 0), 0.025, 0.02)
	_surf(h, [Vector3(0, 0.44, -1.1), Vector3(0, 0.62, -1.22), Vector3(0, 0.62, -1.3), Vector3(0, 0.42, -1.28)], Vector3(1, 0, 0), 0.025, 0.02)
	# stub wings: Vikhr tube racks outboard, rocket pods inboard
	for s in [-1.0, 1.0]:
		h.color(RU, Geo.PAINT)
		_surf(h, [Vector3(s * 0.14, 0.34, 0.04), Vector3(s * 0.6, 0.31, 0.02), Vector3(s * 0.6, 0.31, -0.12), Vector3(s * 0.14, 0.34, -0.18)], Vector3(0, 1, 0), 0.035, 0.022)
		h.color("#4a4e44", Geo.PAINT)
		h.tube(Vector3(s * 0.32, 0.24, 0.14), Vector3(s * 0.32, 0.24, -0.22), 0.055, 8)
		h.color("#1d1f1e", Geo.DARK)
		h.tube(Vector3(s * 0.32, 0.24, 0.141), Vector3(s * 0.32, 0.24, 0.15), 0.045, 8)
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.52, 0.28, -0.05), Vector3(0.12, 0.014, 0.34))
		for k in 3:
			h.color("#6a6d5a", Geo.PAINT)
			h.tube(Vector3(s * (0.47 + 0.05 * k), 0.25, 0.14), Vector3(s * (0.47 + 0.05 * k), 0.25, -0.22), 0.02, 6)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.276, 0.47, -0.15), Vector3(0.008, 0.05, 0.28))
		h.box(Vector3(s * 0.31, 0.5, -1.14), Vector3(0.008, 0.08, 0.06))
	_gear(h, [Vector3(-0.2, 0.0, 0.42), Vector3(0.2, 0.0, 0.42)], 0.05)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.36, -0.95), Vector3(0, 0.05, -1.0), 0.01, 4)
	h.tyre(Vector3(0, 0.04, -1.0), 0.035, 0.03, false, RU_S, 8)
	V8()._rotor(model, root, mat, "Rotor", Vector3(0, 0.76, -0.08), 1.4, 3)
	V8()._rotor(model, root, mat, "TailRotor", Vector3(0, 0.94, -0.08), 1.4, 3)
	(model.get_node("TailRotor") as Node3D).set_meta("rotor_dir", -1.0)   # coaxial: upper rotor counter-rotates
	# 30 mm cannon on the starboard side (limited traverse mount)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.17, 0.2, 0.15))
	var t = K.new()
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0, 0), Vector3(0.08, 0.08, 0.2), 0.012)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = V8()._barrel(piv, root, mat, Vector3(0, 0, 0.08), func(bb) -> void:
		bb.color(RU_S, Geo.STEEL)
		bb.gun(0.0, 0.42, 0.016, 0.014, -1.0, false, 6)
		bb.tube(Vector3(0, 0, 0.38), Vector3(0, 0, 0.44), 0.022, 6))
	U()._vfinish(root, model, h, mat, "ka52", [t, b], 1.3, "ecc")
