extends RefCounted
## M3.0 USA list (tool-time only): original procedural models that resemble the real equipment
## (no EA assets, no brand names in text). Buildings reuse the M2.7 assembly (us_m7._make:
## foundation, scaffold, damage states, rubble); vehicles reuse the M2.7b kit and node layout.
## Camo: tools/gfx_m7/camo_pass.gd - all US vehicles desert tan (pattern 3).
##   tools/gfx_m30/build_m30.sh [names...]
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const Y0 := 0.08
const US := "#7e8a5c"
const US_D := "#66704a"
const US_S := "#464a46"
const GLASS_C := "#2a3a46"
const LIT := "#ffd98a"
const WHITE := "#e4e4df"
const WHITE_D := "#c9cac4"
const GREY := "#b4b8ba"
const GREY_D := "#9a9ea0"
const GREY_L := "#a9adae"
const BRICK := "#8c4a35"
const BRICK_D := "#6f3a2a"
const LIME := "#c9c1ae"
const ROOF := "#a3a6a4"

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func V8():
	return load("res://tools/gfx_m7/us_v8.gd")

static func jobs() -> Dictionary:
	var u = U()
	return {
		"us_command": func() -> void: u._make("command", Vector2(4, 4), 1.2, _hq),   # M3.0.1: command compound with vehicle bay
		"us_supply_center": func() -> void: u._make("supply_center", Vector2(3, 3), 1.1, _depot),
		"us_barracks": func() -> void: u._make("barracks", Vector2(3, 3), 1.3, _barracks),
		"us_garage": func() -> void: u._make("garage", Vector2(4, 4), 1.55, _motor_pool),
		"us_reactor": func() -> void: u._make("reactor", Vector2(3, 3), 2.1, _reactor_white),
		"us_strategy": func() -> void: u._make("strategy", Vector2(3, 3), 1.0, _pentagon),   # M3.0.1: Pentagon-style (was the office block, _office)
		"us_airfield": func() -> void: u._make("airfield", Vector2(8, 8), 2.2, _airfield_lit),
		"us_drop_zone": func() -> void: u._make("drop_zone", Vector2(3, 3), 1.0, _data_center),
		"us_firebase": func() -> void: u._make("firebase", Vector2(2, 2), 0.9, _m777_pad, _m777, Vector3(0, Y0 + 0.02, 0)),
		"us_patriot": func() -> void: u._make("patriot", Vector2(2, 2), 1.0, _lpws_trailer, _lpws_mount, Vector3(0.05, Y0 + 0.36, 0.1)),
		"us_halberd": func() -> void: V8()._halberd(),
		"us_lynx": func() -> void: V8()._lynx(),
		"us_picket": func() -> void: V8()._picket(),
		"us_bradley": func() -> void: _bradley(),
		"us_supply_truck": func() -> void: _fmtv(),
	}

# ------------------------------------------------------------------ shared building detail
## Rooftop lights: red aviation beacons (pulsing, staggered) at the given points, white at centre.
static func _roof_lights(g, pts: Array, white := Vector3.INF) -> void:
	var i := 0
	for p: Vector3 in pts:
		g.color(US_S, Geo.STEEL)
		g.tube(p, p + Vector3(0, 0.06, 0), 0.007, 4)
		g.pulse_color("#ff3020", float(i) * 0.37)
		g.cbox(p + Vector3(0, 0.075, 0), Vector3(0.04, 0.035, 0.04), 0.01)
		g.end_pulse()
		i += 1
	if white != Vector3.INF:
		g.color("#fff6dc", Geo.LAMP)
		g.cbox(white, Vector3(0.05, 0.04, 0.05), 0.012)

static func _corners(cx: float, cz: float, hx: float, hz: float, y: float) -> Array:
	return [Vector3(cx - hx, y, cz - hz), Vector3(cx + hx, y, cz - hz), Vector3(cx + hx, y, cz + hz), Vector3(cx - hx, y, cz + hz)]

## Window grid on a face (local +z normal, transformed by t): rows x cols panes, a mix of lit
## (emissive) and dark glass picked from a fixed hash so every build looks the same.
static func _win_grid(g, c: Vector3, w: float, h: float, cols: int, rows: int, t: Transform3D, seed_i: int, lit_frac := 0.4, frame := "#2b2d2c") -> void:
	g.color(frame, Geo.DARK if frame == "#2b2d2c" else Geo.CONCRETE)
	g.box(c, Vector3(w, h, 0.01), t)
	var pw := w / float(cols)
	var ph := h / float(rows)
	for r in rows:
		for k in cols:
			var hsh := absi(hash(Vector3i(k, r, seed_i))) % 1000
			if hsh < int(lit_frac * 1000.0):
				g.color(LIT, Geo.LAMP)
			else:
				g.color(GLASS_C, Geo.GLASS)
			g.box(c + Vector3(-w * 0.5 + pw * (k + 0.5), -h * 0.5 + ph * (r + 0.5), 0.007), Vector3(pw * 0.72, ph * 0.66, 0.006), t)

static func _face_t(yaw_deg: float, at: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)

# ================================================================== HQ (military command compound)
## M3.0.1 (Malachi: dozers coming out of a Pentagon looked odd): a low hardened command building
## in desert-tan concrete with battered walls, slit windows, roof comms (lattice mast, whip
## antennas, satcom dish), a flag, blast walls, and a large vehicle bay on the front whose open
## door lines up with the sim's exit tile (rot 0: local x +0.5, front +z), so the dozers drive
## out of it. 4 x 4 pad, footprint and gameplay unchanged; rooftop beacons kept.
const TAN := "#c9b48a"
const TAN_D := "#a8956c"
const TAN_L := "#dccaa2"
const CONC := "#b3ab9a"
static func _hq(g) -> void:
	# apron + drive-out lane to the exit tile
	g.color(CONC, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.01, 0), Vector3(3.8, 0.02, 3.8), 0.01)
	g.color("#8f897c", Geo.CONCRETE)
	g.box(Vector3(0.5, Y0 + 0.022, 1.45), Vector3(1.0, 0.006, 0.95))
	g.color("#e8d34a", Geo.PAINT)
	for x in [0.02, 0.98]:
		g.box(Vector3(x, Y0 + 0.027, 1.45), Vector3(0.03, 0.004, 0.95))
	# main command block: low, battered (sloped) walls, parapet roof
	var by0 := Y0 + 0.02
	var bh := 0.55
	var plan := [Vector2(-1.75, -1.6), Vector2(1.6, -1.6), Vector2(1.6, 0.55), Vector2(-1.75, 0.55)]
	g.color(TAN, Geo.CONCRETE)
	g.plan_loft(plan, by0, by0 + bh, Vector2(0.95, 0.92), Vector2(-0.004, -0.04))
	g.color(TAN_D, Geo.CONCRETE)
	g.cbox(Vector3(-0.075, by0 + bh + 0.02, -0.565), Vector3(3.2, 0.05, 1.95), 0.01)   # roof slab
	g.color(TAN_L, Geo.CONCRETE)
	for z in [-1.52, 0.4]:   # parapet lips
		g.box(Vector3(-0.075, by0 + bh + 0.07, z), Vector3(3.15, 0.06, 0.05))
	for x in [-1.62, 1.47]:
		g.box(Vector3(x, by0 + bh + 0.07, -0.565), Vector3(0.05, 0.06, 1.9))
	# slit windows (few lit), front and sides
	_win_grid(g, Vector3(0, by0 + 0.36, 0), 1.3, 0.06, 7, 1, _face_t(0, Vector3(-0.95, 0, 0.535)), 3, 0.3, TAN_D)
	_win_grid(g, Vector3(0, by0 + 0.36, 0), 1.5, 0.06, 7, 1, _face_t(90, Vector3(1.585, 0, -0.55)), 4, 0.25, TAN_D)
	_win_grid(g, Vector3(0, by0 + 0.36, 0), 1.5, 0.06, 7, 1, _face_t(-90, Vector3(-1.735, 0, -0.55)), 5, 0.25, TAN_D)
	# armoured personnel door with canopy (front left)
	g.color("#4a4c48", Geo.STEEL)
	g.box(Vector3(-1.2, by0 + 0.12, 0.555), Vector3(0.2, 0.24, 0.02))
	g.color(TAN_L, Geo.CONCRETE)
	g.cbox(Vector3(-1.2, by0 + 0.27, 0.65), Vector3(0.34, 0.03, 0.22), 0.006)
	g.color("#fff3c4", Geo.LAMP)
	g.box(Vector3(-1.2, by0 + 0.3, 0.57), Vector3(0.05, 0.025, 0.02))
	# vehicle bay: tall block projecting from the front, open door with the shutter half up
	var bx := 0.5
	g.color(TAN, Geo.CONCRETE)
	g.cbox(Vector3(bx, by0 + 0.4, 0.62), Vector3(1.2, 0.8, 0.9), 0.015)
	g.color(TAN_D, Geo.CONCRETE)
	g.cbox(Vector3(bx, by0 + 0.82, 0.62), Vector3(1.24, 0.05, 0.94), 0.01)
	g.color("#16171a", Geo.DARK)   # dark interior seen through the opening
	g.box(Vector3(bx, by0 + 0.27, 1.06), Vector3(0.84, 0.54, 0.02))
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3(bx, by0 + 0.002, 0.85), Vector3(0.84, 0.004, 0.45))
	g.rollup(Vector3(bx, by0 + 0.62, 1.075), 0.86, 0.14)   # shutter rolled up into the head
	g.color("#3a3c3a", Geo.STEEL)   # door frame
	for x in [bx - 0.45, bx + 0.45]:
		g.box(Vector3(x, by0 + 0.35, 1.075), Vector3(0.05, 0.7, 0.04))
	g.box(Vector3(bx, by0 + 0.71, 1.075), Vector3(0.95, 0.04, 0.04))
	g.color("#e8d34a", Geo.PAINT)   # hazard chevrons on the jambs
	for i in 4:
		for x in [bx - 0.45, bx + 0.45]:
			g.box(Vector3(x, by0 + 0.08 + i * 0.16, 1.097), Vector3(0.05, 0.06, 0.004))
	g.color("#fff3c4", Geo.LAMP)   # bay floodlights
	for x in [bx - 0.3, bx + 0.3]:
		g.box(Vector3(x, by0 + 0.76, 1.1), Vector3(0.08, 0.03, 0.04))
	g.color("#ffffff", Geo.TEAM)   # team band over the bay
	g.box(Vector3(bx, by0 + 0.765, 1.072), Vector3(0.3, 0.05, 0.006))
	# roof: lattice comms mast, whip antennas, satcom dish, AC unit, hatch
	g.color(US_S, Geo.STEEL)
	g.lattice(Vector3(-1.3, by0 + bh + 0.05, -1.25), 0.95, 0.07, 5)
	for p in [Vector3(-0.2, by0 + bh + 0.05, -1.35), Vector3(0.4, by0 + bh + 0.05, -1.3), Vector3(1.3, by0 + bh + 0.05, -0.2)]:
		V4._antenna(g, p, 0.45)
	g.dish(Vector3(0.9, by0 + bh + 0.06, -1.05), 0.14, 35.0, 0.25)
	U()._ac_unit(g, Vector3(-0.5, by0 + bh + 0.05, -0.5))
	g.color(US_S, Geo.STEEL)
	g.hatch(Vector3(0.3, by0 + bh + 0.06, -0.4), 0.14)
	# flag on a plinth by the entrance, blast walls (T-walls) along the front left
	g.color(TAN_L, Geo.CONCRETE)
	g.cbox(Vector3(-0.55, Y0 + 0.04, 1.15), Vector3(0.18, 0.06, 0.18), 0.01)
	U()._flag(g, Vector3(-0.55, Y0 + 0.07, 1.15), 0.95)
	g.color(CONC, Geo.CONCRETE)
	for i in 5:
		var x := -1.75 + i * 0.22
		g.cbox(Vector3(x, Y0 + 0.17, 1.62), Vector3(0.2, 0.32, 0.07), 0.01)
		g.cbox(Vector3(x, Y0 + 0.03, 1.62), Vector3(0.2, 0.04, 0.2), 0.01)
	g.sandbag(Vector3(1.55, Y0 + 0.03, 1.35), 0.5, 90.0, "#b8a47a")
	_roof_lights(g, _corners(-0.075, -0.565, 1.55, 0.9, by0 + bh + 0.1) + [Vector3(bx - 0.55, by0 + 0.85, 1.02), Vector3(bx + 0.55, by0 + 0.85, 1.02)], Vector3(-1.3, by0 + bh + 1.05, -1.25))

# ================================================================== Strategic Center (Pentagon-style)
## Five-sided ring of stepped office wings round a courtyard: limestone facade with window bands,
## inner ring a storey higher, courtyard with a small pavilion, flag and a comms mast.
## M3.0.1: moved here from the HQ (Malachi: dozers driving out of it looked odd), scaled to the
## Strategic Center's 3 x 3 pad (S = 0.74 of the old 4 x 4 layout).
const PS := 0.74
static func _pentagon(g) -> void:
	var c := Vector3(0, Y0, 0)
	var rings := [[1.82 * PS, 1.32 * PS, 0.0, 0.42, LIME], [1.3 * PS, 0.86 * PS, 0.0, 0.56, "#d3ccba"]]
	for ri in rings.size():
		var ro: float = rings[ri][0]
		var rin: float = rings[ri][1]
		var hgt: float = rings[ri][3]
		for i in 5:
			var a0 := TAU * i / 5.0 - PI * 0.5 + PI / 5.0
			var a1 := TAU * (i + 1) / 5.0 - PI * 0.5 + PI / 5.0
			var plan := [Vector2(cos(a0) * ro, sin(a0) * ro), Vector2(cos(a1) * ro, sin(a1) * ro), Vector2(cos(a1) * rin, sin(a1) * rin), Vector2(cos(a0) * rin, sin(a0) * rin)]
			g.color(rings[ri][4], Geo.CONCRETE)
			g.plan_loft(plan, Y0, Y0 + hgt, Vector2.ONE, Vector2.ZERO)
			g.color(ROOF, Geo.CONCRETE)   # slate roof slab, slightly inset
			var inset: Array = []
			var mid: Vector2 = (plan[0] + plan[1] + plan[2] + plan[3]) * 0.25
			for p: Vector2 in plan:
				inset.append(mid + (p - mid) * 0.94)
			g.plan_loft(inset, Y0 + hgt, Y0 + hgt + 0.05, Vector2(0.97, 0.97), mid * 0.03)
			# window bands on the outer facade (lit / dark mix)
			var am := (a0 + a1) * 0.5
			var apo := ro * cos(PI / 5.0)
			var fw := 2.0 * ro * sin(PI / 5.0) * 0.86
			var t := Transform3D(Basis(Vector3.UP, -am + PI * 0.5), Vector3(cos(am) * (apo + 0.004), 0, sin(am) * (apo + 0.004)))
			var floors := 3 if ri == 0 else 4
			for f in floors:
				_win_grid(g, Vector3(0, Y0 + 0.08 + f * (hgt - 0.12) / floors, 0), fw, 0.06, 10, 1, t, i * 10 + f + ri * 100, 0.35)
	# courtyard: lawn, paths, pavilion
	g.color("#5f7a3e", Geo.CONCRETE)
	g.cyl(0.84 * PS, 0.84 * PS, 0.012, 5, Transform3D(Basis(Vector3.UP, PI / 5.0 + PI * 0.5), c))
	g.color(LIME, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.07, 0), Vector3(0.28, 0.14, 0.28) * PS, 0.02)
	g.color("#3c5a7a", Geo.PAINT)
	g.dome(0.12 * PS, 0.08, 3, 10, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.14, 0)))
	# entrance portico on the front wing (+z)
	g.color("#e0dbcc", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.2, 1.62 * PS), Vector3(0.5 * PS, 0.06, 0.16), 0.01)
	for x in [-0.2, -0.07, 0.07, 0.2]:
		g.tube(Vector3(x * PS, Y0, 1.66 * PS), Vector3(x * PS, Y0 + 0.18, 1.66 * PS), 0.015, 6)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.25, 1.705 * PS), Vector3(0.46 * PS, 0.04, 0.01))
	# parking + flags + comms mast on the roof
	U()._flag(g, Vector3(-0.5 * PS, Y0, 1.82 * PS), 0.5)
	U()._flag(g, Vector3(0.5 * PS, Y0, 1.82 * PS), 0.5)
	g.color(US_S, Geo.STEEL)
	g.lattice(Vector3(0.75 * PS, Y0 + 0.61, -0.62 * PS), 0.5, 0.05, 4)
	g.dish(Vector3(-0.8 * PS, Y0 + 0.64, -0.55 * PS), 0.08, 30.0, 0.4)
	var lights: Array = []
	for i in 5:
		var a := TAU * i / 5.0 - PI * 0.5 + PI / 5.0
		lights.append(Vector3(cos(a) * 1.72 * PS, Y0 + 0.47, sin(a) * 1.72 * PS))
		lights.append(Vector3(cos(a) * 1.22 * PS, Y0 + 0.61, sin(a) * 1.22 * PS))
	_roof_lights(g, lights, Vector3(0.75 * PS, Y0 + 1.13, -0.62 * PS))

# ================================================================== Supply Depot (warehouse)
## Grey corrugated warehouse with three roll-up bay doors over a raised loading dock (bumpers,
## dock lights), a low-pitch roof with vents, a forklift-pallet yard and the truck drop-off apron.
static func _depot(g) -> void:
	var cz := -0.32
	g.color(GREY, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.36, cz), Vector3(2.6, 0.72, 1.7), 0.02)
	g.color(GREY_D, Geo.PAINT)
	g.prism_x([Vector2(cz - 0.87, Y0 + 0.72), Vector2(cz + 0.87, Y0 + 0.72), Vector2(cz, Y0 + 0.9)], -1.32, 1.32)
	g.color(GREY_L, Geo.STEEL)
	for x in [-1.31, 1.31]:   # gutters / corner trims
		for z in [cz - 0.86, cz + 0.86]:
			g.box(Vector3(x, Y0 + 0.36, z), Vector3(0.03, 0.72, 0.03))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.66, cz + 0.856), Vector3(2.5, 0.05, 0.01))
	# loading dock + three bay doors (front, +z)
	g.color("#9a968c", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.08, cz + 1.0), Vector3(2.3, 0.16, 0.32), 0.015)
	for i in 3:
		var x := -0.78 + i * 0.78
		g.rollup(Vector3(x, Y0 + 0.4, cz + 0.851), 0.52, 0.44)
		g.color("#1d1c1b", Geo.RUBBER)   # dock bumpers
		for s in [-0.2, 0.2]:
			g.box(Vector3(x + s, Y0 + 0.11, cz + 1.17), Vector3(0.05, 0.08, 0.03))
		g.color("#d8a531", Geo.PAINT)   # dock edge stripe + bay number plate
		g.box(Vector3(x, Y0 + 0.163, cz + 1.15), Vector3(0.6, 0.004, 0.03))
		g.color("#fff3c4", Geo.LAMP)
		g.box(Vector3(x + 0.33, Y0 + 0.66, cz + 0.87), Vector3(0.05, 0.03, 0.03))
	g.color("#d8a531", Geo.PAINT)
	for x in [-1.2, 1.2]:
		g.box(Vector3(x, Y0 + 0.09, cz + 1.0), Vector3(0.03, 0.18, 0.33))
	# steps, personnel door, side office with windows
	g.color("#9a968c", Geo.CONCRETE)
	g.cbox(Vector3(1.25, Y0 + 0.04, cz + 1.05), Vector3(0.14, 0.08, 0.2), 0.01)
	_win_grid(g, Vector3(0, Y0 + 0.52, 0), 1.2, 0.08, 10, 1, _face_t(90, Vector3(1.304, 0, cz)), 7, 0.5)
	_win_grid(g, Vector3(0, Y0 + 0.52, 0), 1.2, 0.08, 10, 1, _face_t(-90, Vector3(-1.304, 0, cz)), 8, 0.3)
	# roof vents
	g.color(GREY_L, Geo.STEEL)
	for x in [-0.8, 0.0, 0.8]:
		g.ccyl(0.05, 0.08, 0.01, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.86, cz)))
	# pallet yard + drop-off apron stripes
	U()._crates(g, Vector3(-1.25, Y0, cz + 1.25), 3, 11)
	g.color("#e8e4d6", Geo.PAINT)
	for i in 4:
		g.box(Vector3(-0.6 + i * 0.4, Y0 + 0.002, 1.28), Vector3(0.025, 0.004, 0.3))
	_roof_lights(g, _corners(0, cz, 1.25, 0.8, Y0 + 0.72), Vector3(0, Y0 + 0.93, cz))

# ================================================================== Barracks (brick dorm)
## Three-storey red-brick dormitory: mortar courses, limestone quoins and lintels, lit / dark
## windows, flat roof with AC units, entrance canopy and a flagpole on a plinth out front.
static func _barracks(g) -> void:
	var cz := -0.25
	var hx := 1.2
	var hz := 0.62
	var top := 0.95
	g.color(BRICK, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + top * 0.5, cz), Vector3(hx * 2, top, hz * 2), 0.01)
	g.color(BRICK_D, Geo.CONCRETE)   # mortar / course lines
	for k in 9:
		var y := Y0 + 0.06 + k * 0.1
		g.box(Vector3(0, y, cz + hz + 0.002), Vector3(hx * 2, 0.008, 0.004))
		g.box(Vector3(0, y, cz - hz - 0.002), Vector3(hx * 2, 0.008, 0.004))
	g.color(LIME, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + top + 0.03, cz), Vector3(hx * 2 + 0.06, 0.06, hz * 2 + 0.06), 0.01)   # cornice
	g.cbox(Vector3(0, Y0 + 0.03, cz), Vector3(hx * 2 + 0.04, 0.06, hz * 2 + 0.04), 0.01)   # plinth
	g.color("#6d6e6a", Geo.CONCRETE)   # tar roof inside the parapet
	g.box(Vector3(0, Y0 + top + 0.062, cz), Vector3(hx * 2 - 0.08, 0.006, hz * 2 - 0.08))
	for x in [-hx, hx]:
		for z in [cz - hz, cz + hz]:
			g.box(Vector3(x, Y0 + top * 0.5, z), Vector3(0.06, top, 0.06))   # quoins
	for f in 3:
		var y := Y0 + 0.2 + f * 0.29
		for s in [-1.0, 1.0]:
			_win_grid(g, Vector3(0, y, 0), 2.1, 0.14, 9, 1, _face_t(0 if s > 0 else 180, Vector3(0, 0, cz + s * (hz + 0.003))), f * 3 + int(s + 1), 0.4, "#e2dccb")
		_win_grid(g, Vector3(0, y, 0), 0.9, 0.14, 3, 1, _face_t(90, Vector3(hx + 0.003, 0, cz)), 30 + f, 0.4, "#e2dccb")
		_win_grid(g, Vector3(0, y, 0), 0.9, 0.14, 3, 1, _face_t(-90, Vector3(-hx - 0.003, 0, cz)), 40 + f, 0.4, "#e2dccb")
	# entrance: canopy on posts, double door, steps
	g.color("#3d3a36", Geo.DARK)
	g.box(Vector3(0, Y0 + 0.12, cz + hz + 0.01), Vector3(0.24, 0.2, 0.01))
	g.color(WHITE, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 0.26, cz + hz + 0.16), Vector3(0.44, 0.03, 0.32), 0.008)
	for x in [-0.19, 0.19]:
		g.tube(Vector3(x, Y0, cz + hz + 0.29), Vector3(x, Y0 + 0.25, cz + hz + 0.29), 0.012, 6)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.3, cz + hz + 0.32), Vector3(0.42, 0.04, 0.01))
	g.color(LIME, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.015, cz + hz + 0.2), Vector3(0.5, 0.03, 0.4), 0.006)
	# roof AC units + hatch
	U()._ac_unit(g, Vector3(-0.6, Y0 + top + 0.06, cz))
	U()._ac_unit(g, Vector3(0.6, Y0 + top + 0.06, cz - 0.15))
	# flagpole on a plinth with a walkway and hedges in front
	g.color(LIME, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.03, 1.05), Vector3(0.24, 0.06, 0.24), 0.01)
	U()._flag(g, Vector3(0, Y0 + 0.06, 1.05), 1.1)
	g.color("#9a968c", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.003, cz + hz + 0.45), Vector3(0.3, 0.006, 0.35))
	g.color("#3f5a2c", Geo.CANVAS)
	for x in [-0.8, -0.45, 0.45, 0.8]:
		g.cbox(Vector3(x, Y0 + 0.05, cz + hz + 0.1), Vector3(0.3, 0.1, 0.1), 0.03)
	_roof_lights(g, _corners(0, cz, hx - 0.05, hz - 0.05, Y0 + top + 0.06), Vector3(0, Y0 + top + 0.09, cz + 0.3))

# ================================================================== Motor Pool (old garage)
static func _motor_pool(g) -> void:
	U()._garage(g)
	_roof_lights(g, _corners(-0.2, -0.3, 1.5, 1.2, 1.3))

# ================================================================== Reactor (all white)
static func _reactor_white(g) -> void:
	K.remap = {US: WHITE, US_D: WHITE_D, "#8a946a": WHITE, "#6fd3ff": "#dff3ff", U().CON: WHITE, U().CON_D: WHITE_D, U().CON_L: "#f1f1ec", "#2a2b2a": "#b9bbb8", "#4a4d4a": "#c6c8c5"}
	U()._reactor(g)
	K.remap = {}
	_roof_lights(g, [Vector3(-0.42, 1.6, -0.32), Vector3(0.75, 1.95, 0.55), Vector3(0.9, 0.7, -0.9), Vector3(-1.0, 0.6, 0.9)])

# ================================================================== Strategic Center (office)
## Six-storey glass-and-stone office block on a podium: lit / dark window grid on all faces,
## recessed lobby, roof plant + antenna, rooftop beacons.
static func _office(g) -> void:
	var c := Vector3(0, Y0, -0.15)
	g.color("#b9b6ad", Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.14, 0), Vector3(2.5, 0.28, 2.0), 0.02)   # podium
	g.color("#c3c6c4", Geo.CONCRETE)
	var tw := 1.5
	var td := 1.2
	var th := 1.45
	g.cbox(c + Vector3(0, 0.28 + th * 0.5, 0), Vector3(tw, th, td), 0.015)
	for f in 7:
		var y := 0.36 + f * 0.2
		for s in [-1.0, 1.0]:
			_win_grid(g, Vector3(0, c.y + y, 0), tw - 0.08, 0.15, 8, 1, _face_t(0 if s > 0 else 180, Vector3(c.x, 0, c.z + s * (td * 0.5 + 0.003))), f * 7 + int(s + 3), 0.45, "#d2d4d1")
			_win_grid(g, Vector3(0, c.y + y, 0), td - 0.08, 0.15, 6, 1, _face_t(90 if s > 0 else -90, Vector3(c.x + s * (tw * 0.5 + 0.003), 0, c.z)), f * 11 + int(s + 5), 0.45, "#d2d4d1")
	# lobby
	g.color(GLASS_C, Geo.GLASS)
	g.box(c + Vector3(0, 0.15, 1.003), Vector3(0.8, 0.2, 0.01))
	g.color(LIT, Geo.LAMP)
	g.box(c + Vector3(0, 0.26, 1.005), Vector3(0.8, 0.02, 0.01))
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0, 0.3 + th, td * 0.5 + 0.01), Vector3(tw * 0.9, 0.05, 0.01))
	# roof plant
	g.color("#8d9196", Geo.STEEL)
	g.cbox(c + Vector3(0.3, 0.28 + th + 0.09, -0.15), Vector3(0.5, 0.18, 0.4), 0.02)
	U()._ac_unit(g, c + Vector3(-0.4, 0.28 + th, 0.2))
	g.dish(c + Vector3(-0.45, 0.28 + th + 0.02, -0.3), 0.1, 35.0, 0.3)
	V4._antenna(g, c + Vector3(0.5, 0.28 + th + 0.18, -0.2), 0.35)
	# podium planters
	g.color("#3f5a2c", Geo.CANVAS)
	for x in [-1.0, 1.0]:
		g.cbox(c + Vector3(x, 0.32, 0.8), Vector3(0.3, 0.08, 0.2), 0.03)
	_roof_lights(g, _corners(c.x, c.z, tw * 0.5 - 0.04, td * 0.5 - 0.04, c.y + 0.28 + th) + [c + Vector3(1.15, 0.28, 0.9), c + Vector3(-1.15, 0.28, 0.9)], c + Vector3(0.5, 0.28 + th + 0.55, -0.2))

static func _airfield_lit(g) -> void:
	U()._airbase8(g, "us")
	_roof_lights(g, _corners(0, 0, 3.8, 3.8, Y0 + 0.02))

# ================================================================== Data Center
## Long windowless server hall with louvred cooling walls, a row of roof chillers (spinning fans),
## backup generators + fuel tank, a fibre/cable tray, perimeter fence posts and security lights.
static func _data_center(g) -> void:
	var cz := -0.2
	g.color("#cfd1d0", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.3, cz), Vector3(2.4, 0.6, 1.5), 0.02)
	g.color("#3a5f8a", Geo.PAINT)
	g.box(Vector3(0, Y0 + 0.56, cz + 0.752), Vector3(2.4, 0.06, 0.006))   # accent band
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.8, Y0 + 0.45, cz + 0.754), Vector3(0.5, 0.06, 0.006))
	g.color("#5d6163", Geo.STEEL)
	for i in 6:   # louvre panels
		g.vent(Vector3(-1.0 + i * 0.4, Y0 + 0.28, cz + 0.755), 0.3, 0.3, 6)
	g.vent(Vector3(1.205, Y0 + 0.3, cz), 0.8, 0.3, 6, 90)
	# entrance
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(0.9, Y0 + 0.13, cz + 0.756), Vector3(0.24, 0.22, 0.006))
	g.color(LIT, Geo.LAMP)
	g.box(Vector3(0.9, Y0 + 0.26, cz + 0.76), Vector3(0.24, 0.015, 0.01))
	# roof chillers
	for i in 4:
		var p := Vector3(-0.84 + i * 0.56, Y0 + 0.6, cz)
		g.color("#9a9d96", Geo.STEEL)
		g.cbox(p + Vector3(0, 0.06, 0), Vector3(0.44, 0.12, 0.9), 0.012)
		g.fan(p + Vector3(0, 0.12, -0.22), 0.11, 5, 7.0 + i)
		g.fan(p + Vector3(0, 0.12, 0.22), 0.11, 5, 8.0 - i)
	# generators + tank
	for i in 2:
		var p := Vector3(-0.9 + i * 0.55, Y0, 0.95)
		g.color("#d0ccc0", Geo.PAINT)
		g.cbox(p + Vector3(0, 0.1, 0), Vector3(0.44, 0.2, 0.24), 0.015)
		g.color("#2b2d2c", Geo.DARK)
		g.vent(p + Vector3(0, 0.1, 0.121), 0.3, 0.1, 4)
		g.color(US_S, Geo.STEEL)
		g.tube(p + Vector3(0.15, 0.2, -0.05), p + Vector3(0.15, 0.36, -0.05), 0.015, 6)
	g.color("#e4e2da", Geo.STEEL)
	g.tube(Vector3(0.5, Y0 + 0.1, 0.95), Vector3(1.15, Y0 + 0.1, 0.95), 0.1, 10)
	g.color(US_S, Geo.STEEL)   # cable tray to the hall
	g.box(Vector3(-0.6, Y0 + 0.3, 0.68), Vector3(0.9, 0.02, 0.06))
	for x in [-1.0, -0.2]:
		g.tube(Vector3(x, Y0, 0.68), Vector3(x, Y0 + 0.3, 0.68), 0.01, 4)
	# fence posts + security lights
	for i in 7:
		var x := -1.4 + i * 0.466
		g.tube(Vector3(x, Y0, 1.42), Vector3(x, Y0 + 0.22, 1.42), 0.008, 4)
	g.box(Vector3(0, Y0 + 0.2, 1.42), Vector3(2.8, 0.008, 0.008))
	g.box(Vector3(0, Y0 + 0.12, 1.42), Vector3(2.8, 0.008, 0.008))
	U()._floodlight(g, Vector3(1.3, Y0, 1.2), 0.5, 180)
	_roof_lights(g, _corners(0, cz, 1.15, 0.7, Y0 + 0.6), Vector3(0, Y0 + 0.78, cz))

# ================================================================== M777A2 (emplaced howitzer)
static func _m777_pad(g) -> void:
	g.color("#9c8a62", Geo.SANDBAG)
	for a in 8:
		var ang := TAU * (a + 0.5) / 8.0
		if a == 2:
			continue
		g.sandbag(Vector3(cos(ang) * 0.86, Y0, sin(ang) * 0.86), 0.5, rad_to_deg(-ang + PI * 0.5))
		g.sandbag(Vector3(cos(ang) * 0.86, Y0 + 0.08, sin(ang) * 0.86), 0.44, rad_to_deg(-ang + PI * 0.5))
	g.color("#7a6a4a", Geo.CONCRETE)
	g.cyl(0.74, 0.74, 0.01, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	# ammo: 155 projectiles on a pallet, charge canisters, crew tent
	g.color("#5b5f3e", Geo.PAINT)
	for i in 6:
		g.tube(Vector3(-0.72 + (i % 3) * 0.06, Y0 + 0.03 + (i / 3) * 0.05, -0.3), Vector3(-0.72 + (i % 3) * 0.06, Y0 + 0.03 + (i / 3) * 0.05, -0.05), 0.025, 6, 0.01)
	g.color("#8a7650", Geo.WOOD)
	g.cbox(Vector3(-0.66, Y0 + 0.01, -0.18), Vector3(0.22, 0.02, 0.3), 0.004)
	g.color("#4d5741", Geo.PAINT)
	for i in 3:
		g.cbox(Vector3(0.6, Y0 + 0.06, -0.4 + i * 0.12), Vector3(0.18, 0.1, 0.1), 0.01)
	g.color("#66704f", Geo.CANVAS)
	g.prism_x([Vector2(-0.6, Y0), Vector2(-0.3, Y0), Vector2(-0.45, Y0 + 0.2)], 0.45, 0.8)
	_roof_lights(g, [Vector3(0.75, Y0 + 0.16, 0.6), Vector3(-0.75, Y0 + 0.16, 0.6)])

## M777A2: low titanium-grey-green carriage, four splayed trail legs (two forward, two rear),
## long 155 mm barrel with the double-baffle muzzle brake, saddle + recoil cylinders above the
## barrel, digital fire-control box and two spades. Whole gun rotates on the pad.
static func _m777(g) -> void:
	var C := "#6b7253"
	var CD := "#575d43"
	g.color(CD, Geo.PAINT)
	g.cbox(Vector3(0, 0.08, 0.0), Vector3(0.36, 0.08, 0.5), 0.02)   # lower carriage
	for s in [-1.0, 1.0]:
		# rear trails splayed out
		g.color(C, Geo.PAINT)
		g.tube(Vector3(s * 0.12, 0.07, -0.2), Vector3(s * 0.42, 0.03, -0.9), 0.03, 6)
		g.color(US_S, Geo.STEEL)
		g.plate(Vector3(s * 0.43, 0.04, -0.92), Vector3(0.14, 0.1, 0.02), Vector3(-20, 0, 0))   # spade
		# forward outriggers
		g.color(C, Geo.PAINT)
		g.tube(Vector3(s * 0.15, 0.07, 0.2), Vector3(s * 0.45, 0.03, 0.45), 0.025, 6)
		g.color(US_S, Geo.STEEL)
		g.cyl(0.05, 0.05, 0.015, 8, Transform3D(Basis.IDENTITY, Vector3(s * 0.46, 0.0, 0.46)))
		# wheels raised in firing position
		g.tyre(Vector3(s * 0.25, 0.13, -0.08), 0.11, 0.07, false, US_S, 10)
	# upper carriage / cradle sides
	g.color(C, Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.prism_x([Vector2(-0.18, 0.1), Vector2(0.18, 0.1), Vector2(0.1, 0.32), Vector2(-0.1, 0.32)], s * 0.13, s * 0.1)
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(-0.15, 0.3, 0.0), Vector3(0.15, 0.3, 0.0), 0.03, 8)   # trunnion
	# barrel at ~20 deg elevation through the cradle
	var el := Basis(Vector3.RIGHT, deg_to_rad(-20))
	var o := Vector3(0, 0.3, 0.0)
	g.color(C, Geo.PAINT)
	g.tube(o + el * Vector3(0, 0, -0.35), o + el * Vector3(0, 0, 0.3), 0.06, 10)   # cradle / breech ring
	g.color(CD, Geo.PAINT)
	g.cbox(o + el * Vector3(0, 0, -0.42), Vector3(0.12, 0.12, 0.12), 0.015)   # breech
	g.color(C, Geo.PAINT)
	g.tube(o + el * Vector3(0, 0, 0.3), o + el * Vector3(0, 0, 1.45), 0.036, 10, 0.03)
	g.color(US_S, Geo.STEEL)
	for s in [-1.0, 1.0]:   # recoil / recuperator cylinders above the barrel
		g.tube(o + el * Vector3(s * 0.045, 0.07, -0.25), o + el * Vector3(s * 0.045, 0.07, 0.4), 0.022, 8)
	g.color(CD, Geo.PAINT)
	g.cbox(o + el * Vector3(0, 0, 1.5), Vector3(0.11, 0.07, 0.1), 0.01)   # muzzle brake
	g.color("#2b2d2c", Geo.DARK)
	for s in [-1.0, 1.0]:
		g.box(o + el * Vector3(s * 0.056, 0, 1.49), Vector3(0.006, 0.04, 0.06))
	# fire-control box + sight, hand wheels, team stripe
	g.color("#4d5741", Geo.PAINT)
	g.cbox(Vector3(-0.2, 0.3, -0.05), Vector3(0.08, 0.1, 0.12), 0.01)
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(-0.241, 0.32, -0.05), Vector3(0.004, 0.05, 0.07))
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(0.18, 0.22, 0.0), Vector3(0.22, 0.22, 0.0), 0.04, 8)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, 0.125, -0.25), Vector3(0.3, 0.02, 0.01))

# ================================================================== LPWS (C-RAM)
## Flatbed trailer with outriggers, generator and cooling unit; the turret is the mount.
static func _lpws_trailer(g) -> void:
	g.color("#8b8f88", Geo.PAINT)
	g.cbox(Vector3(0.05, Y0 + 0.28, 0.1), Vector3(0.7, 0.06, 1.3), 0.01)   # bed
	g.color(US_S, Geo.STEEL)
	g.box(Vector3(0.05, Y0 + 0.22, 0.1), Vector3(0.12, 0.06, 1.4))
	g.tube(Vector3(0.05, Y0 + 0.22, 0.75), Vector3(0.05, Y0 + 0.15, 0.95), 0.02, 6)   # tow bar
	for z in [-0.35, -0.15]:
		g.tyre(Vector3(-0.32, Y0 + 0.11, z), 0.11, 0.07, false, US_S, 10)
		g.tyre(Vector3(0.42, Y0 + 0.11, z), 0.11, 0.07, false, US_S, 10)
	for c in [Vector3(-0.38, 0, 0.6), Vector3(0.48, 0, 0.6), Vector3(-0.38, 0, -0.5), Vector3(0.48, 0, -0.5)]:
		g.tube(c + Vector3(0, Y0 + 0.25, 0), c + Vector3(0, Y0, 0), 0.018, 6)   # outrigger jacks
		g.box(c + Vector3(0, Y0 + 0.01, 0), Vector3(0.1, 0.02, 0.1))
	g.color("#8b8f88", Geo.PAINT)
	g.cbox(Vector3(0.05, Y0 + 0.4, -0.42), Vector3(0.6, 0.2, 0.3), 0.015)   # generator / cooler
	g.color("#2b2d2c", Geo.DARK)
	g.vent(Vector3(0.05, Y0 + 0.4, -0.571), 0.4, 0.12, 5, 180)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.405, Y0 + 0.28, 0.1), Vector3(0.006, 0.04, 1.1))
	# ops shelter + sandbags
	g.color("#7e8a5c", Geo.PAINT)
	g.cbox(Vector3(-0.68, Y0 + 0.16, -0.62), Vector3(0.34, 0.32, 0.4), 0.02)
	for a in 3:
		g.sandbag(Vector3(-0.8 + a * 0.4, Y0, 0.9), 0.36, 0)
	_roof_lights(g, [Vector3(-0.68, Y0 + 0.33, -0.62), Vector3(0.3, Y0 + 0.5, -0.42)])

## Phalanx-style mount: off-white search-radar dome on a drum, track radar under it, 6-barrel
## rotary gun with ammo drum, all on a yoke that trains with the turret pivot.
static func _lpws_mount(g) -> void:
	var W := "#dcdcd4"
	var WD := "#c2c3bc"
	g.color(WD, Geo.PAINT)
	g.ccyl(0.18, 0.08, 0.015, 14, Transform3D.IDENTITY)   # train base
	g.cbox(Vector3(0, 0.16, -0.04), Vector3(0.26, 0.16, 0.34), 0.03)   # yoke / ammo drum housing
	g.color(W, Geo.PAINT)
	g.tube(Vector3(0, 0.26, -0.16), Vector3(0, 0.26, 0.1), 0.13, 12)   # ammo drum (horizontal)
	g.ccyl(0.13, 0.22, 0.02, 14, Transform3D(Basis.IDENTITY, Vector3(0, 0.33, -0.02)))   # radar drum
	g.dome(0.13, 0.17, 4, 14, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.02)))   # search radome
	g.color("#2b2d2c", Geo.DARK)
	g.cbox(Vector3(0, 0.42, 0.13), Vector3(0.12, 0.1, 0.03), 0.01)   # track antenna
	# rotary barrel cluster under the drum, with a shroud
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(0, 0.2, 0.1), Vector3(0, 0.2, 0.25), 0.05, 10)
	for i in 6:
		var a := TAU * i / 6.0
		var o := Vector3(cos(a) * 0.025, 0.2 + sin(a) * 0.025, 0)
		g.tube(o + Vector3(0, 0, 0.24), o + Vector3(0, 0, 0.62), 0.008, 4)
	g.tube(Vector3(0, 0.2, 0.5), Vector3(0, 0.2, 0.53), 0.045, 10)   # barrel clamp
	g.color("#ffffff", Geo.TEAM)
	g.band(0.131, 0.3, 0.03, 0.004, 14, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.02)))

# ================================================================== M3 Bradley (new unit)
## Boxy aluminium-armour IFV: tall slab sides with applique tiles, sloped bow, rear troop ramp,
## two-man turret offset right with the 25 mm chain gun, coaxial MG, TOW twin launcher box on the
## left, commander's sight, smoke dischargers. Desert tan.
static func _bradley() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.2, "recoil": 0.03, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.47, 1.56, 6, 0.08, 0.22, US_S)
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.8, K.sect(0.2, 0.26, 0.32, 0.28, 0.34, 0.35, 0.0)], [0.6, K.sect(0.13, 0.2, 0.34, 0.32, 0.36, 0.36, 0.0)],
		[-0.78, K.sect(0.13, 0.2, 0.34, 0.32, 0.36, 0.36, 0.0)]])
	# upper hull: tall slab sides, sloped bow plate, flat roof
	h.color(US, Geo.PAINT)
	var s_bow := K.sect(0.32, 0.34, 0.4, 0.58, 0.58, 0.5, 0.015)
	var s_roof := K.sect(0.32, 0.4, 0.62, 0.6, 0.6, 0.55, 0.025)
	h.xloft([[0.86, s_bow], [0.42, s_roof], [-0.78, s_roof], [-0.8, K.sect(0.32, 0.4, 0.6, 0.59, 0.59, 0.54, 0.02)]])
	# applique armour tiles on the sides (two rows), skirt lip
	for s in [-1.0, 1.0]:
		for row in 2:
			for i in 5:
				var zc := lerpf(-0.66, 0.5, (float(i) + 0.5) / 5.0)
				h.color(US if (i + row) % 2 == 0 else US_D, Geo.PAINT)
				h.plate(Vector3(s * 0.615, 0.4 + row * 0.13, zc), Vector3(0.025, 0.12, 0.225), Vector3(0, 0, 0))
		h.color(US_S, Geo.STEEL)
		h.rivets(Vector3(s * 0.63, 0.46, -0.6), Vector3(s * 0.63, 0.46, 0.45), 6, Vector3(s, 0, 0), 0.006)
		h.color(US_D, Geo.PAINT)
		h.plate(Vector3(s * 0.6, 0.27, 0.0), Vector3(0.025, 0.07, 1.5), Vector3(0, 0, s * 20.0))
	# bow: driver hatch, trim vane, headlights, tow hooks
	h.color(US_D, Geo.PAINT)
	h.hatch(Vector3(-0.3, 0.63, 0.35), 0.14)
	h.plate(Vector3(0, 0.36, 0.86), Vector3(0.9, 0.08, 0.02), Vector3(-20, 0, 0))
	V4._lamps(h, 0.45, 0.42, 0.85)
	h.color(US_S, Geo.STEEL)
	for x in [-0.35, 0.35]:
		h.tube(Vector3(x, 0.24, 0.8), Vector3(x, 0.24, 0.88), 0.02, 6)
	# roof: troop hatch, exhaust grille (front right), stowage
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.635, -0.55), Vector3(0.42, 0.02, 0.3), 0.01)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0.36, 0.628, 0.5), 0.22, 0.18, 5)
	h.color("#6b5a3a", Geo.CANVAS)
	h.cbox(Vector3(-0.42, 0.67, -0.55), Vector3(0.16, 0.08, 0.36), 0.025)
	# rear ramp with door, tail lamps, team stripes
	h.color(US_D, Geo.PAINT)
	h.plate(Vector3(0, 0.42, -0.805), Vector3(0.7, 0.36, 0.03), Vector3(6, 0, 0))
	h.color(US, Geo.PAINT)
	h.plate(Vector3(0.18, 0.44, -0.825), Vector3(0.2, 0.26, 0.01), Vector3(6, 0, 0))
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.5, 0.5]:
		h.box(Vector3(x, 0.52, -0.81), Vector3(0.04, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.629, 0.585, -0.08), Vector3(0.006, 0.03, 1.0))
	V4._antenna(h, Vector3(-0.5, 0.62, -0.7), 0.5)
	# turret (offset right, as on the real vehicle)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.08, 0.62, 0.02))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.3, 0.3, 0.03, 14, Transform3D(Basis.IDENTITY, Vector3(0, -0.005, 0)))
	var plan := [Vector2(-0.3, -0.36), Vector2(0.3, -0.36), Vector2(0.33, 0.1), Vector2(0.2, 0.34), Vector2(-0.2, 0.34), Vector2(-0.33, 0.1)]
	t.color(US, Geo.PAINT)
	t.plan_loft(plan, 0.02, 0.17, Vector2(0.88, 0.86), Vector2(0, -0.02))
	t.color(US_D, Geo.PAINT)
	t.plan_loft([Vector2(-0.26, -0.5), Vector2(0.26, -0.5), Vector2(0.28, -0.34), Vector2(-0.28, -0.34)], 0.03, 0.15, Vector2(0.95, 0.95))   # bustle
	# TOW launcher box on the left, folded flat
	t.color(US_D, Geo.PAINT)
	t.cbox(Vector3(-0.39, 0.12, -0.04), Vector3(0.12, 0.13, 0.46), 0.012)
	t.color("#2b2d2c", Geo.DARK)
	for y in [0.09, 0.15]:
		t.box(Vector3(-0.39, y, 0.195), Vector3(0.08, 0.04, 0.006))
	# hatches, commander's independent viewer, sights, smoke
	t.color(US_D, Geo.PAINT)
	t.hatch(Vector3(0.12, 0.175, -0.12), 0.13)
	t.hatch(Vector3(-0.14, 0.175, -0.15), 0.12)
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.18, 0.22, 0.04), Vector3(0.1, 0.08, 0.1), 0.01)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.18, 0.225, 0.092), Vector3(0.07, 0.04, 0.006))
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(-0.08, 0.2, 0.2), Vector3(0.1, 0.06, 0.08), 0.01)
	U()._smoke(t, Vector3(0.3, 0.12, 0.22), 35.0)
	U()._smoke(t, Vector3(-0.3, 0.12, 0.26), -35.0)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.1, -0.505), Vector3(0.4, 0.04, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0.06, 0.1, 0.3), func(b) -> void:
		b.color(US_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.02), Vector3(0.09, 0.09, 0.1), 0.012)   # mantlet
		b.color(US_S, Geo.STEEL)
		b.gun(0.06, 0.66, 0.022, 0.016, -1.0, false, 8)   # 25 mm chain gun
		b.tube(Vector3(0, 0, 0.62), Vector3(0, 0, 0.68), 0.024, 8)   # flash eliminator
		b.tube(Vector3(-0.05, -0.02, 0.06), Vector3(-0.05, -0.02, 0.24), 0.008, 4))   # coax
	U()._vfinish(root, model, h, mat, "bradley", [t, b], 1.2)

# ================================================================== M1083A1P2 5-ton FMTV cargo
## Conventional-cab (cab-over-engine) 6x6 5-ton: flat-fronted cab with split windscreen and
## grille, three equally spaced axles with single tyres, drop-side cargo bed with a canvas cover
## on bows, side fuel tank, exhaust stack, spare. Desert tan (PAT_FILE 3).
static func _fmtv() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.3, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.4, [0.58, -0.3, -0.68], 0.16, 0.14, 1)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, -0.05), Vector3(0.5, 0.08, 1.72), 0.015)   # frame rails
	# cab: tall, flat-fronted with a slight rake, roof hatch
	h.color(US, Geo.PAINT)
	var c0 := K.sect(0.34, 0.6, 0.92, 0.42, 0.42, 0.4, 0.03)
	var c1 := K.sect(0.34, 0.6, 0.95, 0.42, 0.42, 0.41, 0.03)
	h.xloft([[0.92, c0], [0.86, c1], [0.48, c1], [0.46, K.sect(0.34, 0.6, 0.93, 0.41, 0.41, 0.4, 0.02)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.18, 0.18]:
		h.plate(Vector3(x, 0.78, 0.915), Vector3(0.3, 0.17, 0.006), Vector3(-6, 0, 0))   # split windscreen
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.423, 0.78, 0.7), Vector3(0.006, 0.15, 0.26))   # door windows
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.5, 0.925), 0.5, 0.16, 6)   # grille
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.37, 0.95), Vector3(0.86, 0.08, 0.06), 0.012)   # bumper
	h.hatch(Vector3(0.12, 0.955, 0.7), 0.14)
	for s in [-1.0, 1.0]:
		h.prism_x([Vector2(0.4, 0.3), Vector2(0.78, 0.3), Vector2(0.74, 0.36), Vector2(0.44, 0.36)], s * 0.32, s * 0.45)   # fenders
		h.color(US_S, Geo.STEEL)
		h.tube(Vector3(s * 0.42, 0.85, 0.85), Vector3(s * 0.52, 0.86, 0.85), 0.008, 3)
		h.cbox(Vector3(s * 0.53, 0.8, 0.85), Vector3(0.02, 0.12, 0.05), 0.006)   # mirrors
		h.color(US, Geo.PAINT)
	V4._lamps(h, 0.33, 0.45, 0.93)
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.34, 0.4, 0.42), Vector3(0.34, 1.05, 0.42), 0.022, 6)   # exhaust stack
	h.tube(Vector3(-0.32, 0.4, 0.3), Vector3(-0.32, 0.4, 0.05), 0.08, 10)   # fuel tank
	h.cbox(Vector3(0.32, 0.42, 0.2), Vector3(0.12, 0.14, 0.16), 0.015)   # battery box
	# cargo bed: drop sides, canvas on bows
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -0.42), Vector3(0.84, 0.06, 1.04), 0.012)
	h.color(US, Geo.PAINT)
	for x in [-0.41, 0.41]:
		h.cbox(Vector3(x, 0.54, -0.42), Vector3(0.025, 0.18, 1.04), 0.006)
		for z in [-0.82, -0.55, -0.28, -0.02]:
			h.box(Vector3(x * 1.035, 0.54, z), Vector3(0.012, 0.18, 0.02))
	h.cbox(Vector3(0, 0.54, -0.93), Vector3(0.84, 0.18, 0.025), 0.006)
	h.color("#8c7f5e", Geo.CANVAS)
	h.xloft([[-0.04, K.sect(0.62, 0.86, 0.98, 0.42, 0.42, 0.34, 0.08)], [-0.94, K.sect(0.62, 0.86, 0.98, 0.42, 0.42, 0.34, 0.08)]])
	h.color("#7a6e50", Geo.CANVAS)
	for z in [-0.26, -0.5, -0.74]:
		h.box(Vector3(0, 0.98, z), Vector3(0.6, 0.012, 0.02))
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.36, 0.36]:
		h.box(Vector3(x, 0.4, -0.95), Vector3(0.05, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.426, 0.55, -0.42), Vector3(0.006, 0.05, 0.8))
	V4._antenna(h, Vector3(-0.34, 0.95, 0.5), 0.4)
	U()._vfinish(root, model, h, mat, "supply_truck", [], 1.3)
