extends "res://tools/m41/models_m41.gd"
## M4.5: the 0.4.4 US tech-tree views, rebuilt on the same kit as the M1A3, Black Hawk and
## barracks (lofted hulls, glazing, tracks, fittings). Not the flat box pass.
##   godot --headless --path . -s res://tools/m44/models_m44.gd
## Then camo_pass, bake_ao (rebuilds LODs) on the scenes this writes.
const UM := preload("res://tools/gfx_m7/us_m7.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const CON := "#b8b2a3"
const CON_D := "#9c9686"
const CON_L := "#cdc8bb"
const AIR := "#8a9097"
const AIR_D := "#6c737a"
const YEL := "#d8a531"
## Cooling-tower lips. Steam markers sit on the lip; the footprint stays 4 x 4.
const TW_A := Vector3(-1.12, 0.08, -1.05)
const TW_B := Vector3(0.95, 0.08, -1.18)
const NUC_H := 2.08

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	struct_fac = "us"
	_substation(mat)
	_nuclear(mat)
	_darpa(mat)
	_socom(mat)
	_robotics(mat)
	_zeus_launcher(mat)
	_zeus_pylon(mat)
	_littlebird(mat)
	_ah64(mat)
	_reaper(mat)
	_f16(mat)
	_yf22(mat)
	_f35(mat)
	_b1(mat)
	_ripsaw(mat)
	_upgrade(mat, "up_aero", func(h) -> void: _up_aero(h))
	_upgrade(mat, "up_robotics", func(h) -> void: _up_robotics(h))
	_upgrade(mat, "up_nuclear", func(h) -> void: _up_nuclear(h))
	_upgrade(mat, "up_zeus", func(h) -> void: _up_zeus(h))
	var f := FileAccess.open("/tmp/m44_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line(p)
	print("M44 wrote %d scenes" % wrote.size())
	quit(0)

func _bld(short: String, fp: Vector2, top: float, mat: Material, hull_fn: Callable) -> void:
	_structure(short, fp, top, mat, hull_fn, Callable(), Vector3.ZERO, {})

func _missile(h, a: Vector3, b: Vector3, r := 0.018) -> void:
	h.color("#4a4e44", Geo.PAINT)
	h.tube(a, b, r, 6)
	h.color("#c9b48c", Geo.PAINT)
	h.tube(a + (b - a) * 0.55, a + (b - a) * 0.72, r * 1.15, 6)
	var dir := (b - a).normalized()
	h.color(DRK, Geo.DARK)
	h.tube(b, b + dir * 0.035, r, 6, r * 0.25)

func _pod(h, a: Vector3, b: Vector3, r: float) -> void:
	h.color("#5a5e55", Geo.PAINT)
	h.tube(a, b, r, 8)
	h.color(DRK, Geo.DARK)
	var dir := (b - a).normalized()
	h.tube(b, b + dir * 0.012, r * 0.82, 8)

# ---------------------------------------------------------------- Sub Station (3 x 3)
func _substation(mat: Material) -> void:
	_bld("substation", Vector2(3, 3), 1.85, mat, func(g) -> void:
		# control house
		g.color(CON, Geo.CONCRETE)
		g.cbox(Vector3(-0.72, Y0 + 0.38, 0.15), Vector3(1.05, 0.7, 0.85), 0.03)
		g.color(CON_D, Geo.CONCRETE)
		g.cbox(Vector3(-0.72, Y0 + 0.76, 0.15), Vector3(1.12, 0.08, 0.92), 0.012)
		g.color(STL, Geo.STEEL)
		g.prism_x([Vector2(-0.48, Y0 + 0.8), Vector2(0.48, Y0 + 0.8), Vector2(0.0, Y0 + 0.98)], -0.55, 0.55, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.72, 0, 0.15)))
		g.windows(Vector3(-0.72, Y0 + 0.42, 0.58), 0.7, 0.22, 4)
		g.color("#3a3c3a", Geo.DARK)
		g.box(Vector3(-0.38, Y0 + 0.22, 0.582), Vector3(0.22, 0.4, 0.02))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(-0.72, Y0 + 0.62, 0.585), Vector3(0.7, 0.045, 0.012))
		g.color(STL, Geo.STEEL)
		g.fan(Vector3(-1.05, Y0 + 0.85, 0.15), 0.12, 4, 6.0)
		V4._antenna(g, Vector3(-1.1, Y0 + 0.82, -0.15), 0.55)
		# transformer row: tanks, radiator fins, bushings
		for i in 3:
			var x := 0.15 + float(i) * 0.48
			var p := Vector3(x, Y0, -0.35)
			g.color(CON_L, Geo.CONCRETE)
			g.cbox(p + Vector3(0, 0.22, 0), Vector3(0.34, 0.4, 0.28), 0.015)
			g.color(STL, Geo.STEEL)
			for j in 6:
				g.box(p + Vector3(-0.14 + j * 0.05, 0.2, 0.16), Vector3(0.012, 0.32, 0.04))
			g.color("#7a7f7a", Geo.STEEL)
			g.cbox(p + Vector3(0, 0.44, 0), Vector3(0.3, 0.06, 0.24), 0.008)
			for j in 3:
				g.insulator(p + Vector3(-0.08 + j * 0.08, 0.47, -0.02), 0.16)
			g.color(YEL, Geo.PAINT)
			g.box(p + Vector3(0, 0.28, 0.15), Vector3(0.1, 0.06, 0.008))
		# bus gantry and drop leads
		g.color(STL, Geo.STEEL)
		for x2 in [-0.05, 0.62, 1.28]:
			g.tube(Vector3(x2, Y0, 0.95), Vector3(x2, Y0 + 1.45, 0.95), 0.04, 6)
			g.insulator(Vector3(x2, Y0 + 0.55, 0.95), 0.22)
		for y in [0.85, 1.15, 1.4]:
			g.tube(Vector3(-0.05, Y0 + y, 0.95), Vector3(1.28, Y0 + y, 0.95), 0.018, 5)
		g.color("#1d1e1d", Geo.STEEL)
		for i in 3:
			var x3 := 0.15 + float(i) * 0.48
			g.tube(Vector3(x3, Y0 + 0.63, -0.35), Vector3(x3, Y0 + 1.15, 0.95), 0.008, 4)
		# fence, gate, hazard, lamps
		g.color(STL, Geo.STEEL)
		g.rail([Vector3(-1.35, Y0, -1.25), Vector3(1.35, Y0, -1.25), Vector3(1.35, Y0, 1.25), Vector3(-1.35, Y0, 1.25), Vector3(-1.35, Y0, 0.35)], 0.16, 0.28, 0.008)
		g.rail([Vector3(-1.35, Y0, -0.15), Vector3(-1.35, Y0, -1.25)], 0.16, 0.28, 0.008)
		g.color(YEL, Geo.PAINT)
		g.hazard(Vector3(-1.35, Y0 + 0.12, 0.1), 0.4, 0.06, 5, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
		UM._lamp(g, Vector3(1.2, Y0 + 1.5, 0.95))
		UM._lamp(g, Vector3(-1.15, Y0 + 1.15, -0.15), "#fff3c4")
		g.color(CON, Geo.CONCRETE)
		for x4 in [-1.2, 1.2]:
			g.box(Vector3(x4, Y0 + 0.08, 1.15), Vector3(0.18, 0.16, 0.45))
	)

# ---------------------------------------------------------------- Nuclear plant (4 x 4) — containment, two towers, hall, yard
func _tower(g, c: Vector3, r: float, hgt: float) -> void:
	var tt := Transform3D(Basis.IDENTITY, c)
	g.color(CON_L, Geo.CONCRETE)
	g.lathe([[0.0, r], [hgt * 0.08, r * 0.96], [hgt * 0.28, r * 0.78], [hgt * 0.55, r * 0.66], [hgt * 0.82, r * 0.62], [hgt * 0.94, r * 0.7], [hgt, r * 0.76]], 16, tt, true, false)
	g.color(CON_D, Geo.CONCRETE)
	g.lathe([[hgt, r * 0.78], [hgt + 0.06, r * 0.78]], 16, tt, false, false)
	g.color("#2a2b2a", Geo.DARK)
	g.cyl(r * 0.62, r * 0.62, 0.012, 14, Transform3D(Basis.IDENTITY, c + Vector3(0, hgt * 0.72, 0)))
	g.color("#ffffff", Geo.TEAM)
	g.band(r * 0.7, hgt * 0.9, 0.045, 0.012, 16, tt)
	g.color(CON_D, Geo.CONCRETE)
	for i in 10:
		var a := TAU * float(i) / 10.0
		g.box(Vector3.ZERO, Vector3(0.03, hgt * 0.07, 0.03), tt * Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.22), Vector3(cos(a) * r * 0.98, hgt * 0.04, sin(a) * r)))
	g.color(STL, Geo.STEEL)
	g.rail_ring(r * 0.8, hgt * 0.55, 12, 0.08, tt)

func _nuclear(mat: Material) -> void:
	_structure("reactor", Vector2(4, 4), 2.35, mat, func(g) -> void:
		var dc := Vector3(-0.55, Y0, 0.55)
		var dt := Transform3D(Basis.IDENTITY, dc)
		g.color(CON_L, Geo.CONCRETE)
		g.lathe([[0.0, 0.72], [0.06, 0.72], [0.08, 0.68], [0.78, 0.68], [0.84, 0.64]], 18, dt)
		g.color(CON_D, Geo.CONCRETE)
		g.ribs(0.68, 0.1, 0.74, 14, 0.045, 0.04, dt, 0.12)
		g.pulse_color("#6fd3ff", 0.0)
		for i in 8:
			var a := TAU * (float(i) + 0.5) / 8.0
			g.box(Vector3.ZERO, Vector3(0.02, 0.18, 0.1), dt * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.69, 0.4, sin(a) * 0.69)))
		g.end_pulse()
		g.band(0.68, 0.22, 0.03, 0.012, 18, dt)
		g.band(0.68, 0.62, 0.03, 0.012, 18, dt)
		g.color("#ffffff", Geo.TEAM)
		g.band(0.685, 0.7, 0.04, 0.014, 18, dt)
		g.color(STL, Geo.STEEL)
		g.lathe([[0.84, 0.78], [0.88, 0.78]], 18, dt)
		g.rail_ring(0.76, 0.88, 14, 0.1, dt)
		g.color(CON_L, Geo.CONCRETE)
		g.dome(0.62, 0.48, 5, 18, Transform3D(Basis.IDENTITY, dc + Vector3(0, 0.84, 0)))
		g.color(STL, Geo.STEEL)
		g.hatch(dc + Vector3(0, 1.32, 0), 0.1)
		g.ladder(dc + Vector3(0, 0.02, 0.7), 0.82, Vector3.RIGHT)
		g.color(CON_D, Geo.CONCRETE)
		g.cbox(dc + Vector3(0.42, 0.2, 0.62), Vector3(0.36, 0.32, 0.22), 0.02)
		g.color("#4a4d4a", Geo.STEEL)
		g.box(dc + Vector3(0.42, 0.16, 0.74), Vector3(0.16, 0.26, 0.016))
		UM._lamp(g, dc + Vector3(0.15, 1.4, 0), "#fff3c4")
		_tower(g, TW_A, 0.5, NUC_H)
		_tower(g, TW_B, 0.44, NUC_H)
		g.color(STL, Geo.STEEL)
		g.ladder(TW_A + Vector3(0.52, 0, 0.1), 1.1, Vector3(0.4, 0, 0.9))
		UM._lamp(g, TW_A + Vector3(0.2, NUC_H + 0.08, 0.2))
		UM._lamp(g, TW_B + Vector3(-0.15, NUC_H + 0.08, -0.15))
		# turbine hall
		var hc := Vector3(0.85, Y0, 0.72)
		g.color(CON, Geo.CONCRETE)
		g.cbox(hc + Vector3(0, 0.32, 0), Vector3(1.55, 0.64, 0.85), 0.03)
		g.color(PNT, Geo.CORR)
		g.prism_x([Vector2(-0.42, 0.64), Vector2(0.42, 0.64), Vector2(0.28, 0.78), Vector2(-0.28, 0.78)], -0.78, 0.78, Transform3D(Basis.IDENTITY, hc))
		g.color(STL, Geo.STEEL)
		g.fan(hc + Vector3(-0.35, 0.8, 0), 0.16, 5, 7.0)
		g.fan(hc + Vector3(0.2, 0.8, 0), 0.16, 5, -6.0)
		g.windows(hc + Vector3(-0.15, 0.38, 0.43), 0.9, 0.16, 6)
		g.rollup(hc + Vector3(0.55, 0.24, 0.43), 0.38, 0.4)
		g.hazard(hc + Vector3(0.55, 0.48, 0.44), 0.42, 0.04, 6)
		g.color("#ffffff", Geo.TEAM)
		g.box(hc + Vector3(-0.15, 0.55, 0.435), Vector3(0.7, 0.05, 0.012))
		g.color("#8d9196", Geo.STEEL)
		g.pipe([dc + Vector3(0.62, 0.4, 0.15), Vector3(0.15, Y0 + 0.4, 0.55), hc + Vector3(-0.7, 0.4, 0)], 0.05)
		g.pipe([dc + Vector3(0.55, 0.22, -0.2), Vector3(0.2, Y0 + 0.22, 0.15), hc + Vector3(-0.55, 0.22, -0.2)], 0.038)
		g.pipe([TW_A + Vector3(0.35, 0.35, 0.35), Vector3(-0.2, Y0 + 0.35, -0.15), hc + Vector3(-0.4, 0.28, -0.45)], 0.042)
		g.pipe([TW_B + Vector3(-0.2, 0.3, 0.4), hc + Vector3(0.3, 0.3, -0.45)], 0.04)
		g.color(STL, Geo.STEEL)
		for p in [Vector3(0.15, Y0, 0.55), Vector3(0.2, Y0, 0.15), Vector3(-0.2, Y0, -0.15)]:
			g.box(p + Vector3(0, 0.16, 0), Vector3(0.04, 0.32, 0.04))
		# switchyard
		for k in 2:
			var xc := Vector3(-1.35 + k * 0.48, Y0, 1.35)
			g.color(PNT_D, Geo.PAINT)
			g.cbox(xc + Vector3(0, 0.16, 0), Vector3(0.34, 0.3, 0.26), 0.015)
			g.color(STL, Geo.STEEL)
			for j in 5:
				g.box(xc + Vector3(-0.12 + j * 0.06, 0.15, 0.15), Vector3(0.012, 0.22, 0.04))
			for j in 3:
				g.insulator(xc + Vector3(-0.08 + j * 0.08, 0.32, 0), 0.12)
		g.color(STL, Geo.STEEL)
		g.lattice(Vector3(1.45, Y0, 1.15), 1.35, 0.12, 6)
		g.box(Vector3(1.45, Y0 + 1.2, 1.15), Vector3(0.4, 0.02, 0.02))
		for s in [-0.16, 0.16]:
			g.insulator(Vector3(1.45 + s, Y0 + 1.05, 1.15), 0.1)
		g.color("#1d1e1d", Geo.STEEL)
		g.tube(Vector3(1.29, Y0 + 1.05, 1.15), Vector3(-0.9, Y0 + 0.44, 1.35), 0.006, 3)
		UM._lamp(g, Vector3(1.45, Y0 + 1.4, 1.15))
		g.color(CON_L, Geo.CONCRETE)
		UM._jersey(g, Vector3(1.35, Y0, 0.15), 0.7, 90)
		UM._flag(g, Vector3(1.55, Y0, 0.55), 1.15)
	, Callable(), Vector3.ZERO, {"model": {"Stack0": TW_A + Vector3(0, NUC_H + 0.02, 0), "Stack1": TW_B + Vector3(0, NUC_H + 0.02, 0)}})

# ---------------------------------------------------------------- DARPA (4 x 4) research hall
func _darpa(mat: Material) -> void:
	_bld("darpa", Vector2(4, 4), 1.85, mat, func(g) -> void:
		g.color(CON_L, Geo.CONCRETE)
		g.cbox(Vector3(-0.35, Y0 + 0.45, 0.05), Vector3(2.3, 0.9, 1.7), 0.04)
		g.color(CON, Geo.CONCRETE)
		g.cbox(Vector3(1.15, Y0 + 0.7, -0.35), Vector3(0.7, 1.4, 1.15), 0.03)   # taller lab wing
		g.color(STL, Geo.STEEL)
		g.cbox(Vector3(-0.35, Y0 + 0.95, 0.05), Vector3(2.4, 0.08, 1.8), 0.01)
		g.color(GLS, Geo.GLASS)
		g.box(Vector3(-0.35, Y0 + 0.48, 0.91), Vector3(1.8, 0.48, 0.02))
		g.color(STL, Geo.STEEL)
		for x in [-1.1, -0.55, 0.0, 0.5]:
			g.box(Vector3(x, Y0 + 0.48, 0.92), Vector3(0.03, 0.5, 0.012))
		g.box(Vector3(-0.3, Y0 + 0.74, 0.92), Vector3(1.7, 0.02, 0.012))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(-0.35, Y0 + 0.82, 0.925), Vector3(1.4, 0.05, 0.012))
		# roof plant: chillers, dishes, radome, mast
		g.color(STL, Geo.STEEL)
		for x in [-1.15, -0.75]:
			g.cbox(Vector3(x, Y0 + 1.08, -0.35), Vector3(0.32, 0.18, 0.45), 0.012)
			g.fan(Vector3(x, Y0 + 1.18, -0.35), 0.1, 4, 8.0)
		g.dish(Vector3(0.15, Y0 + 1.15, -0.45), 0.28, 35.0, 0.4, "#d9d9d4")
		g.dish(Vector3(-0.15, Y0 + 1.22, 0.35), 0.18, 55.0, -0.25, "#c5c8c2")
		g.color(CON_L, Geo.CONCRETE)
		g.dome(0.22, 0.16, 4, 12, Transform3D(Basis.IDENTITY, Vector3(1.15, Y0 + 1.42, -0.35)))
		g.color(STL, Geo.STEEL)
		g.tube(Vector3(1.15, Y0 + 1.4, -0.35), Vector3(1.15, Y0 + 1.7, -0.35), 0.02, 6)
		V4._antenna(g, Vector3(1.35, Y0 + 1.42, 0.05), 0.7)
		g.ladder(Vector3(0.85, Y0, 0.9), 0.95, Vector3.RIGHT)
		# loading dock and bollards
		g.color(CON_D, Geo.CONCRETE)
		g.box(Vector3(-1.15, Y0 + 0.08, 0.95), Vector3(0.7, 0.12, 0.35))
		g.rollup(Vector3(-1.15, Y0 + 0.38, 0.9), 0.55, 0.5)
		g.color(YEL, Geo.PAINT)
		g.hazard(Vector3(-1.15, Y0 + 0.68, 0.91), 0.6, 0.04, 7)
		for x in [-1.55, -0.75]:
			g.color(STL, Geo.STEEL)
			g.tube(Vector3(x, Y0, 1.15), Vector3(x, Y0 + 0.35, 1.15), 0.04, 6)
			g.color(YEL, Geo.PAINT)
			g.band(0.045, 0.22, 0.06, 0.004, 6, Transform3D(Basis.IDENTITY, Vector3(x, Y0, 1.15)))
		UM._lamp(g, Vector3(1.15, Y0 + 1.55, 0.15), "#fff3c4")
		UM._flag(g, Vector3(-1.45, Y0, -1.2), 1.3)
	)

# ---------------------------------------------------------------- SOCOM compound (3 x 3)
func _socom(mat: Material) -> void:
	_bld("socom", Vector2(3, 3), 1.45, mat, func(g) -> void:
		g.color("#5c624c", Geo.CONCRETE)
		g.cbox(Vector3(-0.15, Y0 + 0.32, 0.05), Vector3(1.7, 0.64, 1.15), 0.03)
		g.color(PNT, Geo.CANVAS)
		# camo net over the roof, sagging between poles
		for i in 4:
			var z := -0.4 + float(i) * 0.28
			g.tube(Vector3(-0.95, Y0 + 0.7, z), Vector3(0.7, Y0 + 0.62, z), 0.012, 4)
		g.color("#4a5138", Geo.CANVAS)
		g.box(Vector3(-0.15, Y0 + 0.66, 0.05), Vector3(1.75, 0.02, 1.2))
		g.color(STL, Geo.STEEL)
		for x in [-0.9, 0.65]:
			for z in [-0.5, 0.55]:
				g.tube(Vector3(x, Y0, z), Vector3(x, Y0 + 0.72, z), 0.02, 5)
		g.color("#1c2420", Geo.DARK)
		g.box(Vector3(0.15, Y0 + 0.28, 0.63), Vector3(0.36, 0.48, 0.03))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(-0.15, Y0 + 0.58, 0.64), Vector3(0.8, 0.04, 0.012))
		# sandbag ring, conex, antenna farm, range target
		for k in 7:
			var a := PI * (0.15 + 0.7 * float(k) / 6.0)
			g.sandbag(Vector3(0.95 + cos(a) * 0.28, Y0, 0.7 + sin(a) * 0.22), 0.22, rad_to_deg(-a))
			g.sandbag(Vector3(0.95 + cos(a) * 0.28, Y0 + 0.07, 0.7 + sin(a) * 0.22), 0.2, rad_to_deg(-a))
		g.color("#6a6248", Geo.PAINT)
		g.cbox(Vector3(0.85, Y0 + 0.28, -0.55), Vector3(0.55, 0.5, 1.05), 0.02)
		g.color(STL, Geo.STEEL)
		g.box(Vector3(0.85, Y0 + 0.42, -0.02), Vector3(0.5, 0.02, 0.02))
		for x in [-0.55, -0.15, 0.25]:
			g.tube(Vector3(x, Y0 + 0.68, -0.35), Vector3(x, Y0 + 1.15, -0.35), 0.015, 4)
		g.tube(Vector3(-0.55, Y0 + 1.15, -0.35), Vector3(0.25, Y0 + 1.15, -0.35), 0.012, 4)
		V4._antenna(g, Vector3(-0.7, Y0 + 0.7, -0.4), 0.65)
		g.color(CON_D, Geo.CONCRETE)
		g.box(Vector3(-1.05, Y0 + 0.35, 0.85), Vector3(0.08, 0.7, 0.45))
		g.color("#c23b2a", Geo.PAINT)
		g.cyl(0.08, 0.08, 0.01, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.0, Y0 + 0.4, 0.85)))
		g.color(STL, Geo.STEEL)
		g.tube(Vector3(-1.15, Y0, 0.55), Vector3(-1.15, Y0, 1.05), 0.015, 4)
		UM._lamp(g, Vector3(0.55, Y0 + 0.85, -0.35), "#fff3c4")
		UM._crates(g, Vector3(-0.85, Y0, -0.85), 3, 44)
	)

# ---------------------------------------------------------------- Robotics plant (4 x 3)
func _robotics(mat: Material) -> void:
	_bld("robotics", Vector2(4, 3), 1.7, mat, func(g) -> void:
		g.color("#8d9390", Geo.STEEL)
		g.cbox(Vector3(0.05, Y0 + 0.55, -0.05), Vector3(3.15, 1.05, 1.85), 0.03)
		# sawtooth roof
		for k in 3:
			var z0 := -0.85 + float(k) * 0.55
			g.color(PNT_D, Geo.CORR)
			g.prism_x([Vector2(z0, 1.05), Vector2(z0 + 0.55, 1.05), Vector2(z0, 1.32)], -1.55, 1.6, Transform3D(Basis.IDENTITY, Vector3(0.05, Y0, -0.05)))
			g.color(GLS, Geo.GLASS)
			g.box(Vector3(0.05, Y0 + 1.16, z0 - 0.06), Vector3(3.0, 0.22, 0.015))
		g.color(STL, Geo.STEEL)
		# gantry crane
		g.tube(Vector3(-1.4, Y0 + 1.05, -0.7), Vector3(-1.4, Y0 + 1.45, -0.7), 0.04, 6)
		g.tube(Vector3(1.45, Y0 + 1.05, -0.7), Vector3(1.45, Y0 + 1.45, -0.7), 0.04, 6)
		g.tube(Vector3(-1.4, Y0 + 1.05, 0.55), Vector3(-1.4, Y0 + 1.45, 0.55), 0.04, 6)
		g.tube(Vector3(1.45, Y0 + 1.05, 0.55), Vector3(1.45, Y0 + 1.45, 0.55), 0.04, 6)
		g.box(Vector3(0.05, Y0 + 1.48, -0.08), Vector3(2.9, 0.06, 0.08))
		g.color(YEL, Geo.PAINT)
		g.cbox(Vector3(0.2, Y0 + 1.38, -0.08), Vector3(0.22, 0.14, 0.16), 0.01)
		g.color(STL, Geo.STEEL)
		g.tube(Vector3(0.2, Y0 + 1.3, -0.08), Vector3(0.2, Y0 + 0.7, -0.08), 0.012, 4)
		g.box(Vector3(0.2, Y0 + 0.68, -0.08), Vector3(0.16, 0.04, 0.1))
		# robot arm over a chassis jig
		g.color("#5c6368", Geo.STEEL)
		g.tube(Vector3(-0.7, Y0 + 0.05, 0.15), Vector3(-0.7, Y0 + 0.55, 0.15), 0.06, 8)
		g.tube(Vector3(-0.7, Y0 + 0.55, 0.15), Vector3(-0.25, Y0 + 0.85, 0.35), 0.045, 8)
		g.tube(Vector3(-0.25, Y0 + 0.85, 0.35), Vector3(0.15, Y0 + 0.55, 0.45), 0.035, 6)
		g.color(PNT, Geo.PAINT)
		g.cbox(Vector3(0.35, Y0 + 0.16, 0.2), Vector3(0.7, 0.18, 1.05), 0.02)   # hull jig
		g.color(DRK, Geo.DARK)
		g.box(Vector3(0.35, Y0 + 0.28, 0.2), Vector3(0.4, 0.06, 0.55))
		g.windows(Vector3(0.05, Y0 + 0.55, 0.88), 2.2, 0.4, 8)
		g.rollup(Vector3(-1.15, Y0 + 0.4, 0.88), 0.7, 0.7)
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0.4, Y0 + 0.95, 0.89), Vector3(1.2, 0.05, 0.012))
		g.hazard(Vector3(-1.15, Y0 + 0.8, 0.89), 0.75, 0.04, 8)
		UM._lamp(g, Vector3(0.2, Y0 + 1.55, -0.08), "#fff3c4")
	)

# ---------------------------------------------------------------- ZEUS launch station (4 x 3)
func _zeus_launcher(mat: Material) -> void:
	_bld("zeus_launcher", Vector2(4, 3), 1.7, mat, func(g) -> void:
		# deployed pad and outriggers
		g.color(CON_D, Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.06, 0.15), Vector3(3.3, 0.1, 1.3), 0.015)
		g.color(PNT_D, Geo.PAINT)
		for s in [-1.0, 1.0]:
			g.cbox(Vector3(s * 1.15, Y0 + 0.1, 0.85), Vector3(0.9, 0.08, 0.22), 0.01)
			g.box(Vector3(s * 1.55, Y0 + 0.08, 0.85), Vector3(0.28, 0.16, 0.28))
			g.box(Vector3(s * 1.15, Y0 + 0.08, -0.7), Vector3(0.28, 0.16, 0.28))
		# six launch cells
		for i in 6:
			var x := -1.05 + float(i) * 0.42
			g.color(PNT, Geo.PAINT)
			g.cbox(Vector3(x, Y0 + 0.72, -0.05), Vector3(0.3, 1.15, 0.3), 0.02)
			g.color(STL, Geo.STEEL)
			g.tube(Vector3(x, Y0 + 0.2, -0.05), Vector3(x, Y0 + 1.22, -0.05), 0.09, 8)
			g.color(DRK, Geo.DARK)
			g.cyl(0.07, 0.07, 0.02, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 1.28, -0.05)))
			g.color(STL, Geo.STEEL)
			g.band(0.16, 0.35, 0.02, 0.008, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0, -0.05)))
			g.band(0.16, 1.05, 0.02, 0.008, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0, -0.05)))
		# control cabin, generator, radar, cable run
		g.color(PNT_D, Geo.PAINT)
		g.cbox(Vector3(-1.4, Y0 + 0.38, -0.15), Vector3(0.55, 0.55, 0.7), 0.02)
		g.color(GLS, Geo.GLASS)
		g.box(Vector3(-1.4, Y0 + 0.48, 0.21), Vector3(0.36, 0.18, 0.015))
		g.color(STL, Geo.STEEL)
		g.cbox(Vector3(1.4, Y0 + 0.28, -0.35), Vector3(0.4, 0.4, 0.55), 0.015)
		g.fan(Vector3(1.4, Y0 + 0.5, -0.35), 0.12, 4, 9.0)
		g.tube(Vector3(-1.15, Y0 + 0.15, -0.15), Vector3(1.15, Y0 + 0.15, -0.55), 0.02, 5)
		g.dish(Vector3(1.35, Y0 + 0.85, 0.35), 0.22, 25.0, 0.8, "#d0d4d0")
		g.tube(Vector3(1.35, Y0 + 0.2, 0.35), Vector3(1.35, Y0 + 0.7, 0.35), 0.03, 6)
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, Y0 + 1.35, -0.05), Vector3(1.6, 0.04, 0.012))
		g.color(YEL, Geo.PAINT)
		g.hazard(Vector3(0, Y0 + 0.14, 0.82), 1.4, 0.05, 10)
		UM._lamp(g, Vector3(-1.4, Y0 + 0.72, -0.15), "#fff3c4")
	)

# ---------------------------------------------------------------- ZEUS pylon (2 x 2) relay mast
func _zeus_pylon(mat: Material) -> void:
	_bld("zeus_pylon", Vector2(2, 2), 2.55, mat, func(g) -> void:
		g.color(CON, Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.1, 0.35), Vector3(0.7, 0.2, 0.55), 0.015)   # equipment hut
		g.color(STL, Geo.STEEL)
		g.box(Vector3(0, Y0 + 0.22, 0.62), Vector3(0.28, 0.16, 0.02))
		g.fan(Vector3(0.22, Y0 + 0.22, 0.35), 0.08, 4, 5.0)
		g.lattice(Vector3(0, Y0, -0.15), 2.15, 0.22, 8)
		g.color("#c5c8c2", Geo.STEEL)
		g.box(Vector3(0, Y0 + 2.05, 0.05), Vector3(0.55, 0.42, 0.06))   # panel array
		for i in 3:
			g.box(Vector3(0, Y0 + 1.9 + float(i) * 0.12, 0.09), Vector3(0.48, 0.02, 0.02))
		g.dish(Vector3(0.15, Y0 + 1.7, 0.05), 0.16, 20.0, 0.6)
		g.color(STL, Geo.STEEL)
		g.tube(Vector3(0, Y0 + 2.15, -0.15), Vector3(0, Y0 + 2.45, -0.15), 0.015, 4)
		UM._lamp(g, Vector3(0, Y0 + 2.48, -0.15), "#ff3a2a")
		# guy wires to pad eyes
		g.color("#1d1e1d", Geo.STEEL)
		for p in [Vector3(-0.7, Y0, -0.7), Vector3(0.7, Y0, -0.7), Vector3(-0.7, Y0, 0.55), Vector3(0.7, Y0, 0.55)]:
			g.tube(p, Vector3(0, Y0 + 1.3, -0.15), 0.006, 3)
			g.tube(p, p + Vector3(0, 0.08, 0), 0.02, 5)
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, Y0 + 1.15, 0.12), Vector3(0.08, 0.16, 0.012))
	)

# ---------------------------------------------------------------- AH-6 Little Bird
func _littlebird(mat: Material) -> void:
	var root := _heli_root(0.63, 1.05)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.72, K.sect(0.16, 0.2, 0.26, 0.03, 0.05, 0.03, 0.012)], [0.52, K.sect(0.1, 0.2, 0.4, 0.14, 0.18, 0.12, 0.03)],
		[0.22, K.sect(0.08, 0.2, 0.46, 0.16, 0.2, 0.14, 0.04)], [-0.22, K.sect(0.1, 0.22, 0.44, 0.14, 0.18, 0.13, 0.035)],
		[-0.42, K.sect(0.18, 0.26, 0.38, 0.08, 0.1, 0.08, 0.02)]])
	h.color(GLS, Geo.GLASS)
	h.xloft([[0.62, K.sect(0.32, 0.34, 0.4, 0.1, 0.12, 0.08, 0.02)], [0.4, K.sect(0.34, 0.4, 0.52, 0.14, 0.16, 0.1, 0.03)], [0.18, K.sect(0.32, 0.38, 0.48, 0.12, 0.14, 0.09, 0.025)]])
	for s in [-1.0, 1.0]:
		h.pane([Vector3(s * 0.2, 0.28, 0.48), Vector3(s * 0.2, 0.46, 0.4), Vector3(s * 0.19, 0.44, 0.18), Vector3(s * 0.19, 0.26, 0.22)], Vector3(s, 0, 0))
		h.color("#141615", Geo.DARK)
		h.pane([Vector3(s * 0.205, 0.16, 0.12), Vector3(s * 0.205, 0.4, 0.12), Vector3(s * 0.2, 0.4, -0.12), Vector3(s * 0.2, 0.16, -0.12)], Vector3(s, 0, 0), 0.004, 0.001)
		h.color(PNT, Geo.PAINT)
	h.color(PNT_D, Geo.PAINT)
	h.tube(Vector3(0, 0.5, -0.02), Vector3(0, 0.5, -0.28), 0.09, 8, 0.07)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.52, -0.05), Vector3(0, 0.62, -0.05), 0.025, 6)
	# skids
	h.color(STL, Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.22, 0.02, 0.48), Vector3(s * 0.22, 0.02, -0.38), 0.014, 5)
		h.tube(Vector3(s * 0.22, 0.02, 0.48), Vector3(s * 0.2, 0.05, 0.58), 0.014, 5)
		for z in [0.28, -0.16]:
			h.tube(Vector3(s * 0.22, 0.02, z), Vector3(s * 0.12, 0.14, z), 0.012, 4)
	# tail
	h.color(PNT, Geo.PAINT)
	h.tube(Vector3(0, 0.32, -0.4), Vector3(0, 0.4, -1.15), 0.055, 8, 0.028)
	UV8._surf(h, [Vector3(0, 0.38, -1.0), Vector3(0, 0.62, -1.12), Vector3(0, 0.62, -1.2), Vector3(0, 0.38, -1.16)], Vector3(1, 0, 0), 0.028, 0.014)
	UV8._surf(h, [Vector3(-0.16, 0.38, -1.02), Vector3(0.16, 0.38, -1.02), Vector3(0.16, 0.38, -1.1), Vector3(-0.16, 0.38, -1.1)], Vector3(0, 1, 0), 0.016, 0.008)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.19, 0.28, 0.35), Vector3(0.006, 0.04, 0.16))
	# light stores: one rocket pod and a gun pod each side
	for s in [-1.0, 1.0]:
		h.color(PNT, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.16, 0.22, 0.05), Vector3(s * 0.42, 0.2, 0.02), Vector3(s * 0.42, 0.2, -0.08), Vector3(s * 0.16, 0.22, -0.12)], Vector3(0, 1, 0), 0.02, 0.01)
		_pod(h, Vector3(s * 0.32, 0.16, 0.12), Vector3(s * 0.32, 0.16, -0.16), 0.035)
		h.color(STL, Geo.STEEL)
		h.tube(Vector3(s * 0.42, 0.18, 0.02), Vector3(s * 0.42, 0.16, 0.28), 0.012, 5)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.64, -0.05), 1.15, 4)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(0.045, 0.52, -1.16), 0.22, 2, true)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.14, 0.62))
	var t = K.new()
	t.color(STL, Geo.STEEL)
	t.cyl(0.045, 0.04, 0.05, 8, Transform3D.IDENTITY)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0, 0.02))
	var b = K.new()
	b.color(STL, Geo.STEEL)
	b.gun(0.0, 0.22, 0.012, 0.008, -1.0, false, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/us/littlebird.tscn", 1.05, [t, b])

# ---------------------------------------------------------------- AH-64
func _ah64(mat: Material) -> void:
	var root := _heli_root(0.8, 1.2)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(PNT_D, Geo.PAINT)
	h.xloft([[0.95, K.sect(0.18, 0.22, 0.28, 0.035, 0.05, 0.03, 0.012)], [0.72, K.sect(0.12, 0.22, 0.38, 0.08, 0.11, 0.07, 0.025)],
		[0.4, K.sect(0.1, 0.22, 0.42, 0.1, 0.13, 0.09, 0.035)], [-0.15, K.sect(0.1, 0.24, 0.48, 0.12, 0.16, 0.11, 0.04)],
		[-0.48, K.sect(0.18, 0.28, 0.44, 0.08, 0.1, 0.08, 0.025)]])
	h.color(GLS, Geo.GLASS)
	h.xloft([[0.78, K.sect(0.32, 0.34, 0.38, 0.06, 0.07, 0.05, 0.012)], [0.58, K.sect(0.32, 0.36, 0.46, 0.08, 0.09, 0.06, 0.02)], [0.42, K.sect(0.32, 0.36, 0.46, 0.08, 0.09, 0.06, 0.02)]])
	h.xloft([[0.44, K.sect(0.4, 0.42, 0.46, 0.08, 0.09, 0.06, 0.015)], [0.22, K.sect(0.4, 0.44, 0.56, 0.09, 0.1, 0.07, 0.025)], [0.02, K.sect(0.4, 0.44, 0.55, 0.09, 0.1, 0.07, 0.02)]])
	h.color(STL, Geo.PAINT)
	for z in [0.58, 0.22]:
		h.box(Vector3(0, 0.46 if z > 0.4 else 0.55, z), Vector3(0.14, 0.01, 0.012))
	# nose TADS, no mast ball (that read belonged to the retired gunship)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.2, 0.9), Vector3(0, 0.2, 1.02), 0.055, 8)
	h.color(GLS, Geo.GLASS)
	h.box(Vector3(0, 0.2, 1.03), Vector3(0.06, 0.04, 0.012))
	h.color(DRK, Geo.DARK)
	h.cyl(0.035, 0.035, 0.04, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.14, 0.95)))
	for s in [-1.0, 1.0]:
		h.color(PNT_D, Geo.PAINT)
		h.tube(Vector3(s * 0.18, 0.42, 0.05), Vector3(s * 0.18, 0.42, -0.32), 0.065, 8, 0.07)
		h.color(DRK, Geo.DARK)
		h.tube(Vector3(s * 0.18, 0.42, 0.055), Vector3(s * 0.18, 0.42, 0.065), 0.045, 8)
		# IR suppressor
		h.color("#2a2c2a", Geo.STEEL)
		h.plate(Vector3(s * 0.24, 0.4, -0.36), Vector3(0.08, 0.1, 0.14), Vector3(-18, 0, s * 20))
		h.color(PNT, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.14, 0.32, 0.08), Vector3(s * 0.62, 0.28, 0.02), Vector3(s * 0.62, 0.28, -0.12), Vector3(s * 0.14, 0.32, -0.18)], Vector3(0, 1, 0), 0.03, 0.016)
		_pod(h, Vector3(s * 0.28, 0.22, 0.14), Vector3(s * 0.28, 0.22, -0.18), 0.05)
		h.color(STL, Geo.STEEL)
		h.box(Vector3(s * 0.48, 0.26, -0.05), Vector3(0.12, 0.012, 0.32))
		for k in 4:
			var mx: float = s * (0.44 + 0.05 * float(k % 2))
			var my: float = 0.23 - 0.045 * float(k / 2)
			_missile(h, Vector3(mx, my, 0.1), Vector3(mx, my, -0.16))
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.1, K.sect(0.46, 0.5, 0.58, 0.1, 0.11, 0.07, 0.02)], [-0.4, K.sect(0.46, 0.5, 0.58, 0.1, 0.11, 0.07, 0.02)]])
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.58, -0.1), Vector3(0, 0.7, -0.1), 0.03, 6)
	h.color(PNT, Geo.PAINT)
	h.tube(Vector3(0, 0.34, -0.46), Vector3(0, 0.42, -1.35), 0.08, 8, 0.035)
	UV8._surf(h, [Vector3(0, 0.4, -1.15), Vector3(0, 0.78, -1.32), Vector3(0, 0.78, -1.42), Vector3(0, 0.4, -1.38)], Vector3(1, 0, 0), 0.035, 0.018)
	UV8._surf(h, [Vector3(-0.28, 0.4, -1.18), Vector3(0.28, 0.4, -1.18), Vector3(0.28, 0.4, -1.28), Vector3(-0.28, 0.4, -1.28)], Vector3(0, 1, 0), 0.018, 0.01)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.22, 0.4, -0.1), Vector3(0.008, 0.045, 0.28))
	h.box(Vector3(0, 0.62, -1.36), Vector3(0.04, 0.1, 0.05))
	UV8._gear(h, [Vector3(-0.22, 0.0, 0.15), Vector3(0.22, 0.0, 0.15)], 0.05)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.34, -1.15), Vector3(0, 0.04, -1.2), 0.01, 4)
	h.tyre(Vector3(0, 0.035, -1.2), 0.032, 0.028, false, STL, 8)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.72, -0.1), 1.45, 4)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(0.05, 0.62, -1.36), 0.32, 4, true)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.12, 0.72))
	var t = K.new()
	t.color(STL, Geo.STEEL)
	t.cyl(0.07, 0.055, 0.08, 10, Transform3D.IDENTITY)
	t.cbox(Vector3(0, -0.02, 0.04), Vector3(0.08, 0.05, 0.12), 0.01)
	t.color(GLS, Geo.GLASS)
	t.box(Vector3(0.04, 0.0, 0.06), Vector3(0.02, 0.03, 0.02))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, -0.015, 0.06))
	var b = K.new()
	b.color(STL, Geo.STEEL)
	b.gun(0.0, 0.38, 0.016, 0.012, -1.0, false, 6)
	b.tube(Vector3(0, 0, 0.32), Vector3(0, 0, 0.4), 0.02, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/us/ah64.tscn", 1.2, [t, b])

# ---------------------------------------------------------------- Reaper (pusher drone)
func _reaper(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.6, "bar_height": 0.85, "recoil": 0.0, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[0.95, K.sect(0.2, 0.22, 0.26, 0.02, 0.04, 0.02, 0.008)], [0.7, K.sect(0.14, 0.2, 0.28, 0.06, 0.08, 0.05, 0.015)],
		[0.2, K.sect(0.12, 0.18, 0.26, 0.07, 0.09, 0.06, 0.015)], [-0.45, K.sect(0.12, 0.18, 0.24, 0.06, 0.08, 0.05, 0.012)],
		[-0.85, K.sect(0.14, 0.18, 0.22, 0.04, 0.05, 0.035, 0.01)]])
	# high aspect wings, slight anhedral via the tip drop
	for s in [-1.0, 1.0]:
		h.color(AIR_D, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.08, 0.22, 0.15), Vector3(s * 1.55, 0.16, -0.15), Vector3(s * 1.55, 0.16, -0.32), Vector3(s * 0.08, 0.22, -0.35)], Vector3(0, 1, 0), 0.035, 0.008)
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 1.35, 0.175, -0.22), Vector3(0.16, 0.01, 0.06))
		h.color(AIR, Geo.PAINT)
		# hardpoint and a strike store
		h.color(STL, Geo.STEEL)
		h.box(Vector3(s * 0.55, 0.16, -0.05), Vector3(0.02, 0.06, 0.08))
		_missile(h, Vector3(s * 0.55, 0.1, 0.12), Vector3(s * 0.55, 0.1, -0.22), 0.022)
	# V tail
	for s in [-1.0, 1.0]:
		var fb := Basis(Vector3.FORWARD, s * deg_to_rad(40.0))
		h.color(AIR_D, Geo.PAINT)
		UV8._surf(h, [Vector3(0, 0, -0.55), Vector3(0, 0.28, -0.85), Vector3(0, 0.28, -0.98), Vector3(0, 0, -0.9)], Vector3(1, 0, 0), 0.02, 0.008, Transform3D(fb, Vector3(s * 0.02, 0.24, 0)))
	# pusher nacelle
	h.color(AIR_D, Geo.PAINT)
	h.tube(Vector3(0, 0.2, -0.7), Vector3(0, 0.2, -0.95), 0.06, 8, 0.05)
	h.color(DRK, Geo.DARK)
	h.tube(Vector3(0, 0.2, -0.94), Vector3(0, 0.2, -0.96), 0.04, 8)
	# sensor turret under the nose (fixed; the airframe has no yaw turret)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.14, 0.55), Vector3(0, 0.08, 0.55), 0.02, 6)
	h.color("#1e2428", Geo.DARK)
	h.cyl(0.055, 0.055, 0.07, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0.62)))
	h.color(GLS, Geo.GLASS)
	h.box(Vector3(0, 0.05, 0.66), Vector3(0.04, 0.03, 0.008))
	V4._antenna(h, Vector3(0, 0.28, -0.2), 0.35)
	UV8._gear(h, [Vector3(0, 0.0, 0.45), Vector3(-0.16, 0.0, -0.25), Vector3(0.16, 0.0, -0.25)], 0.035)
	_pusher(model, root, mat, Vector3(0, 0.2, -0.98), 0.28)
	_marker(model, root, "Muzzle0", Vector3(0, 0.05, 0.7))
	_finish(root, model, h, mat, "res://view/units/us/reaper.tscn", 0.85, [])

func _pusher(model: Node3D, root: Node3D, mat: Material, at: Vector3, r: float) -> void:
	var rn := VK._n3(model, root, "PusherRotor", at)
	rn.set_meta("rotor_axis", "z")
	var g = K.new()
	g.color("#2b2d2f", Geo.STEEL)
	g.tube(Vector3(0, 0, -0.02), Vector3(0, 0, 0.03), 0.045, 8)
	for i in 3:
		var a := TAU * float(i) / 3.0
		g.rbox(Vector3(cos(a) * r * 0.48, sin(a) * r * 0.48, 0.01), Vector3(r * 0.9, 0.055, 0.012), Vector3(0, 0, rad_to_deg(a)))
	g.plain = true
	g.color("#c9b23a", Geo.PAINT)
	for i in 3:
		var a2 := TAU * float(i) / 3.0
		g.rbox(Vector3(cos(a2) * r * 0.88, sin(a2) * r * 0.88, 0.012), Vector3(0.06, 0.04, 0.014), Vector3(0, 0, rad_to_deg(a2)))
	VK._mi(rn, root, "RotorMesh", g.commit(mat))

# ---------------------------------------------------------------- fighters and the bomber
func _jet_root(bar: float, sel := 1.3) -> Node3D:
	return VK._root({"selection_radius": sel, "bar_height": bar, "recoil": 0.0, "wreck_s": 6.0})

func _f16(mat: Material) -> void:
	var root := _jet_root(0.85)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[1.05, K.sect(0.2, 0.22, 0.24, 0.012, 0.02, 0.01, 0.0)], [0.82, K.sect(0.14, 0.2, 0.32, 0.06, 0.09, 0.05, 0.02)],
		[0.45, K.sect(0.12, 0.2, 0.36, 0.1, 0.16, 0.08, 0.03)], [-0.15, K.sect(0.12, 0.2, 0.34, 0.12, 0.18, 0.09, 0.03)],
		[-0.55, K.sect(0.14, 0.2, 0.3, 0.08, 0.12, 0.07, 0.02)], [-0.85, K.sect(0.16, 0.2, 0.26, 0.04, 0.06, 0.04, 0.012)]])
	h.color(GLS, Geo.GLASS)
	h.xloft([[0.72, K.sect(0.3, 0.32, 0.36, 0.04, 0.05, 0.035, 0.01)], [0.52, K.sect(0.28, 0.32, 0.44, 0.07, 0.08, 0.05, 0.02)], [0.32, K.sect(0.28, 0.3, 0.36, 0.04, 0.045, 0.03, 0.01)]])
	h.color(AIR_D, Geo.PAINT)
	h.box(Vector3(0, 0.42, 0.52), Vector3(0.12, 0.012, 0.012))
	# chin intake
	h.color(AIR_D, Geo.PAINT)
	h.xloft([[0.35, K.sect(0.08, 0.1, 0.16, 0.1, 0.12, 0.09, 0.02)], [-0.05, K.sect(0.08, 0.12, 0.18, 0.08, 0.1, 0.08, 0.015)]], Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)))
	h.color(DRK, Geo.DARK)
	h.box(Vector3(0, 0.1, 0.36), Vector3(0.16, 0.08, 0.012))
	# wings, single fin, ventral strakes, wingtip rails
	for s in [-1.0, 1.0]:
		h.color(AIR, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.12, 0.2, 0.25), Vector3(s * 0.85, 0.18, -0.35), Vector3(s * 0.78, 0.18, -0.55), Vector3(s * 0.1, 0.2, -0.15)], Vector3(0, 1, 0), 0.04, 0.01)
		UV8._surf(h, [Vector3(s * 0.08, 0.16, -0.15), Vector3(s * 0.22, 0.14, -0.45), Vector3(s * 0.18, 0.14, -0.55), Vector3(s * 0.06, 0.16, -0.35)], Vector3(0, 1, 0), 0.02, 0.008)
		h.color(STL, Geo.STEEL)
		h.box(Vector3(s * 0.82, 0.18, -0.4), Vector3(0.02, 0.04, 0.16))
		_missile(h, Vector3(s * 0.55, 0.14, 0.05), Vector3(s * 0.55, 0.14, -0.28))
		_missile(h, Vector3(s * 0.32, 0.14, 0.08), Vector3(s * 0.32, 0.14, -0.22))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.6, 0.2, -0.15), Vector3(0.14, 0.01, 0.05))
	h.color(AIR, Geo.PAINT)
	UV8._surf(h, [Vector3(0, 0.28, -0.35), Vector3(0, 0.62, -0.7), Vector3(0, 0.62, -0.82), Vector3(0, 0.28, -0.78)], Vector3(1, 0, 0), 0.03, 0.012)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.18, -0.82), Vector3(0, 0.18, -0.98), 0.07, 10, 0.055)
	h.color("#ff7a2a", Geo.LAMP)
	h.tube(Vector3(0, 0.18, -0.98), Vector3(0, 0.18, -0.99), 0.045, 8)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.5, -0.74), Vector3(0.012, 0.1, 0.04))
	UV8._gear(h, [Vector3(0, 0.0, 0.55), Vector3(-0.2, 0.0, -0.15), Vector3(0.2, 0.0, -0.15)], 0.04)
	_finish(root, model, h, mat, "res://view/units/us/f16.tscn", 0.85, [])

func _yf22(mat: Material) -> void:
	var root := _jet_root(0.9)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR_D, Geo.PAINT)
	h.xloft([[1.05, K.sect(0.2, 0.21, 0.23, 0.006, 0.015, 0.006, 0.0)], [0.7, K.sect(0.15, 0.19, 0.26, 0.05, 0.12, 0.05, 0.015)],
		[0.25, K.sect(0.13, 0.18, 0.28, 0.14, 0.28, 0.1, 0.025)], [-0.4, K.sect(0.13, 0.18, 0.26, 0.16, 0.26, 0.12, 0.025)],
		[-0.85, K.sect(0.15, 0.18, 0.24, 0.1, 0.16, 0.09, 0.015)]])
	h.color("#8a7040", Geo.GLASS)
	h.xloft([[0.62, K.sect(0.24, 0.25, 0.28, 0.03, 0.035, 0.025, 0.006)], [0.42, K.sect(0.24, 0.26, 0.34, 0.05, 0.055, 0.04, 0.012)], [0.22, K.sect(0.24, 0.25, 0.28, 0.03, 0.035, 0.025, 0.006)]])
	for s in [-1.0, 1.0]:
		h.color(AIR, Geo.PAINT)
		h.xloft([[0.35, K.sect(0.13, 0.16, 0.22, 0.035, 0.045, 0.035, 0.01)], [0.05, K.sect(0.13, 0.16, 0.24, 0.045, 0.055, 0.04, 0.012)]], Transform3D(Basis(Vector3.FORWARD, s * 0.3), Vector3(s * 0.22, 0, 0)))
		h.color(DRK, Geo.DARK)
		h.plate(Vector3(s * 0.24, 0.18, 0.36), Vector3(0.08, 0.07, 0.008), Vector3(0, s * 18.0, s * 16.0))
		UV8._surf(h, [Vector3(s * 0.22, 0.18, 0.28), Vector3(s * 0.95, 0.16, -0.42), Vector3(s * 0.9, 0.16, -0.62), Vector3(s * 0.18, 0.18, -0.55)], Vector3(0, 1, 0), 0.045, 0.01)
		UV8._surf(h, [Vector3(s * 0.12, 0.18, -0.55), Vector3(s * 0.48, 0.17, -0.85), Vector3(s * 0.42, 0.17, -0.98), Vector3(s * 0.1, 0.18, -0.9)], Vector3(0, 1, 0), 0.022, 0.008)
		var fb := Basis(Vector3.FORWARD, s * deg_to_rad(28.0))
		UV8._surf(h, [Vector3(0, 0, -0.45), Vector3(0, 0.32, -0.78), Vector3(0, 0.32, -0.9), Vector3(0, 0, -0.82)], Vector3(1, 0, 0), 0.018, 0.008, Transform3D(fb, Vector3(s * 0.18, 0.26, 0)))
		h.color(STL, Geo.STEEL)
		h.xloft([[-0.72, K.sect(0.14, 0.17, 0.24, 0.055, 0.065, 0.05, 0.015)], [-0.95, K.sect(0.16, 0.18, 0.22, 0.05, 0.055, 0.05, 0.01)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.1, 0, 0)))
		h.color("#ff7a2a", Geo.LAMP)
		h.box(Vector3(s * 0.1, 0.19, -0.96), Vector3(0.08, 0.04, 0.01))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.62, 0.185, -0.35), Vector3(0.14, 0.01, 0.06))
	UV8._gear(h, [Vector3(0, 0.0, 0.55), Vector3(-0.2, 0.0, -0.2), Vector3(0.2, 0.0, -0.2)], 0.04)
	_finish(root, model, h, mat, "res://view/units/us/yf22.tscn", 0.9, [])

func _f35(mat: Material) -> void:
	var root := _jet_root(0.88)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[0.95, K.sect(0.2, 0.22, 0.25, 0.015, 0.03, 0.015, 0.0)], [0.65, K.sect(0.14, 0.2, 0.32, 0.08, 0.14, 0.07, 0.02)],
		[0.2, K.sect(0.12, 0.2, 0.36, 0.16, 0.26, 0.12, 0.03)], [-0.35, K.sect(0.13, 0.2, 0.34, 0.14, 0.22, 0.11, 0.025)],
		[-0.75, K.sect(0.15, 0.2, 0.28, 0.08, 0.12, 0.07, 0.015)]])
	h.color("#8a7040", Geo.GLASS)
	h.xloft([[0.7, K.sect(0.28, 0.3, 0.34, 0.04, 0.05, 0.035, 0.01)], [0.48, K.sect(0.28, 0.32, 0.42, 0.07, 0.08, 0.05, 0.018)], [0.28, K.sect(0.28, 0.3, 0.34, 0.04, 0.05, 0.03, 0.01)]])
	# bay doors as dark seams, single nozzle, trapezoid wings, canted fins
	h.color(DRK, Geo.DARK)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.1, 0.145, -0.05), Vector3(0.008, 0.01, 0.45))
	for s in [-1.0, 1.0]:
		h.color(AIR, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.18, 0.2, 0.15), Vector3(s * 0.82, 0.16, -0.4), Vector3(s * 0.7, 0.16, -0.62), Vector3(s * 0.14, 0.2, -0.25)], Vector3(0, 1, 0), 0.04, 0.01)
		var fb := Basis(Vector3.FORWARD, s * deg_to_rad(22.0))
		UV8._surf(h, [Vector3(0, 0, -0.4), Vector3(0, 0.28, -0.68), Vector3(0, 0.28, -0.8), Vector3(0, 0, -0.72)], Vector3(1, 0, 0), 0.018, 0.008, Transform3D(fb, Vector3(s * 0.12, 0.28, 0)))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.55, 0.185, -0.28), Vector3(0.12, 0.01, 0.05))
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.18, -0.72), Vector3(0, 0.18, -0.92), 0.09, 10, 0.07)
	h.color("#ff7a2a", Geo.LAMP)
	h.tube(Vector3(0, 0.18, -0.92), Vector3(0, 0.18, -0.93), 0.055, 8)
	h.color(AIR_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.34, -0.1), Vector3(0.16, 0.06, 0.35), 0.01)   # spine
	UV8._gear(h, [Vector3(0, 0.0, 0.5), Vector3(-0.22, 0.0, -0.2), Vector3(0.22, 0.0, -0.2)], 0.042)
	_finish(root, model, h, mat, "res://view/units/us/f35.tscn", 0.88, [])

func _b1(mat: Material) -> void:
	var root := _jet_root(1.05, 1.3)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[1.4, K.sect(0.22, 0.24, 0.27, 0.012, 0.02, 0.01, 0.0)], [1.05, K.sect(0.15, 0.24, 0.38, 0.07, 0.12, 0.07, 0.03)],
		[0.55, K.sect(0.13, 0.24, 0.42, 0.12, 0.2, 0.1, 0.04)], [0.05, K.sect(0.12, 0.24, 0.4, 0.22, 0.38, 0.14, 0.05)],
		[-0.5, K.sect(0.13, 0.24, 0.38, 0.2, 0.32, 0.13, 0.045)], [-1.0, K.sect(0.18, 0.26, 0.34, 0.07, 0.12, 0.07, 0.025)],
		[-1.3, K.sect(0.22, 0.26, 0.3, 0.03, 0.045, 0.03, 0.01)]])
	h.color(GLS, Geo.GLASS)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.07, 0.38, 1.05), Vector3(0.006, 0.05, 0.14), Vector3(-22, s * -8.0, s * -35.0))
	h.plate(Vector3(0, 0.4, 1.02), Vector3(0.1, 0.006, 0.1), Vector3(-22, 0, 0))
	h.color(AIR_D, Geo.PAINT)
	h.xloft([[0.9, K.sect(0.38, 0.4, 0.44, 0.04, 0.05, 0.03, 0.01)], [-0.85, K.sect(0.34, 0.36, 0.4, 0.035, 0.045, 0.03, 0.01)]])
	for s in [-1.0, 1.0]:
		h.color(AIR, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.32, 0.26, 0.15), Vector3(s * 1.35, 0.24, -0.55), Vector3(s * 1.35, 0.24, -0.75), Vector3(s * 0.32, 0.26, -0.22)], Vector3(0, 1, 0), 0.05, 0.012)
		UV8._surf(h, [Vector3(s * 0.06, 0.3, -0.95), Vector3(s * 0.55, 0.3, -1.15), Vector3(s * 0.55, 0.3, -1.28), Vector3(s * 0.06, 0.3, -1.22)], Vector3(0, 1, 0), 0.025, 0.008)
		h.color(AIR_D, Geo.PAINT)
		h.xloft([[0.1, K.sect(0.06, 0.1, 0.18, 0.12, 0.13, 0.11, 0.025)], [-0.55, K.sect(0.07, 0.11, 0.18, 0.12, 0.13, 0.11, 0.025)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.34, 0, 0)))
		h.color(DRK, Geo.DARK)
		h.box(Vector3(s * 0.34, 0.12, 0.11), Vector3(0.2, 0.07, 0.012))
		for k in 2:
			var x: float = s * (0.28 + 0.12 * float(k))
			h.color(STL, Geo.STEEL)
			h.tube(Vector3(x, 0.12, -0.55), Vector3(x, 0.12, -0.66), 0.045, 8, 0.036)
			h.color("#ff7a2a", Geo.LAMP)
			h.tube(Vector3(x, 0.12, -0.66), Vector3(x, 0.12, -0.668), 0.03, 8)
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.9, 0.265, -0.4), Vector3(0.18, 0.01, 0.08))
	h.color(AIR, Geo.PAINT)
	UV8._surf(h, [Vector3(0, 0.36, -0.7), Vector3(0, 0.82, -1.05), Vector3(0, 0.82, -1.18), Vector3(0, 0.36, -1.22)], Vector3(1, 0, 0), 0.035, 0.016)
	UV8._gear(h, [Vector3(0, 0.0, 0.85), Vector3(-0.28, 0.0, -0.15), Vector3(0.28, 0.0, -0.15), Vector3(-0.28, 0.0, -0.45), Vector3(0.28, 0.0, -0.45)], 0.045)
	_finish(root, model, h, mat, "res://view/units/us/b1.tscn", 1.05, [])

# ---------------------------------------------------------------- Ripsaw (unmanned, small tracked)
func _ripsaw(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.55, "bar_height": 0.85, "steer_max": 0.0, "recoil": 0.1, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.34, 1.25, 5, 0.065, 0.16, STL)
	h.color(PNT_D, Geo.PAINT)
	h.xloft([[0.62, K.sect(0.16, 0.22, 0.28, 0.2, 0.24, 0.24, 0.0)], [0.4, K.sect(0.12, 0.18, 0.28, 0.22, 0.26, 0.26, 0.0)],
		[-0.55, K.sect(0.12, 0.18, 0.28, 0.22, 0.26, 0.26, 0.0)], [-0.64, K.sect(0.16, 0.22, 0.28, 0.2, 0.24, 0.24, 0.0)]])
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.64, K.sect(0.27, 0.28, 0.32, 0.38, 0.4, 0.38, 0.012)], [0.35, K.sect(0.27, 0.3, 0.38, 0.4, 0.42, 0.4, 0.02)],
		[-0.5, K.sect(0.27, 0.3, 0.36, 0.4, 0.42, 0.4, 0.015)], [-0.62, K.sect(0.27, 0.29, 0.33, 0.38, 0.4, 0.38, 0.012)]])
	for s in [-1.0, 1.0]:
		for i in 4:
			var zc := lerpf(-0.45, 0.48, (float(i) + 0.5) / 4.0)
			h.color(PNT if i > 0 else PNT_D, Geo.PAINT)
			h.plate(Vector3(s * 0.44, 0.26, zc), Vector3(0.02, 0.1, 0.2), Vector3(0, 0, -s * 8.0))
	h.color(DRK, Geo.DARK)
	h.grille(Vector3(0, 0.375, -0.4), 0.4, 0.18, 6)
	h.color(STL, Geo.STEEL)
	h.vent(Vector3(0, 0.3, -0.63), 0.35, 0.08, 4, 180)
	V4._lamps(h, 0.28, 0.32, 0.64)
	V4._antenna(h, Vector3(-0.22, 0.38, -0.2), 0.4)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.45, 0.28, 0.05), Vector3(0.006, 0.03, 0.5), Vector3(0, 0, -s * 8.0))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.36, 0.05))
	var t = K.new()
	t.color(STL, Geo.STEEL)
	t.cyl(0.16, 0.16, 0.03, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)))
	t.color(PNT_D, Geo.PAINT)
	var plan := [Vector2(-0.2, -0.22), Vector2(0.2, -0.22), Vector2(0.22, 0.12), Vector2(0.1, 0.28), Vector2(-0.1, 0.28), Vector2(-0.22, 0.12)]
	t.plan_loft(plan, 0.02, 0.12, Vector2(0.9, 0.92))
	t.color(STL, Geo.STEEL)
	t.cbox(Vector3(0, 0.16, -0.02), Vector3(0.1, 0.06, 0.12), 0.008)   # sensor head, no hatch
	t.color(GLS, Geo.GLASS)
	t.box(Vector3(0, 0.16, 0.045), Vector3(0.06, 0.03, 0.008))
	t.color(STL, Geo.STEEL)
	t.tube(Vector3(0.08, 0.1, 0.05), Vector3(0.08, 0.1, 0.28), 0.012, 5)   # coaxial
	V4._antenna(t, Vector3(0.12, 0.14, -0.1), 0.28)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.16))
	var b = K.new()
	b.color(STL, Geo.STEEL)
	b.gun(0.0, 0.55, 0.028, 0.02, 0.45, true, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/us/ripsaw.tscn", 0.85, [t, b])

# ---------------------------------------------------------------- research tokens (shown on the card, not battlefield units)
func _upgrade(mat: Material, name: String, body: Callable) -> void:
	var root := Node3D.new()
	root.name = "View"
	var h = K.new()
	body.call(h)
	VK._mi(root, root, "Hull", h.commit(mat))
	VK._save(root, "res://view/units/us/%s.tscn" % name, 0.7)
	wrote.append("res://view/units/us/%s.tscn" % name)

func _up_aero(h) -> void:
	h.color(AIR, Geo.PAINT)
	h.xloft([[0.55, K.sect(0.2, 0.22, 0.26, 0.02, 0.04, 0.02, 0.008)], [0.1, K.sect(0.16, 0.22, 0.32, 0.08, 0.12, 0.06, 0.02)], [-0.4, K.sect(0.18, 0.22, 0.28, 0.04, 0.06, 0.04, 0.01)]])
	h.color(GLS, Geo.GLASS)
	h.xloft([[0.35, K.sect(0.28, 0.3, 0.36, 0.04, 0.05, 0.03, 0.01)], [0.15, K.sect(0.28, 0.32, 0.4, 0.05, 0.06, 0.04, 0.012)]])
	for s in [-1.0, 1.0]:
		UV8._surf(h, [Vector3(s * 0.08, 0.24, 0.05), Vector3(s * 0.55, 0.22, -0.25), Vector3(s * 0.5, 0.22, -0.38), Vector3(s * 0.06, 0.24, -0.15)], Vector3(0, 1, 0), 0.03, 0.008)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.22, -0.4), Vector3(0, 0.22, -0.52), 0.05, 8, 0.04)

func _up_robotics(h) -> void:
	h.color(STL, Geo.STEEL)
	h.cyl(0.22, 0.22, 0.08, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)))
	h.tube(Vector3(0, 0.08, 0), Vector3(0, 0.28, 0), 0.04, 8)
	h.tube(Vector3(0, 0.28, 0), Vector3(0.28, 0.38, 0.05), 0.03, 6)
	h.tube(Vector3(0.28, 0.38, 0.05), Vector3(0.42, 0.22, 0.12), 0.025, 6)
	h.color(PNT, Geo.PAINT)
	h.cbox(Vector3(0.42, 0.16, 0.12), Vector3(0.08, 0.06, 0.1), 0.008)
	h.color(GLS, Geo.GLASS)
	h.box(Vector3(0.46, 0.16, 0.12), Vector3(0.012, 0.03, 0.04))

func _up_nuclear(h) -> void:
	h.color(CON_L, Geo.CONCRETE)
	h.lathe([[0.0, 0.28], [0.22, 0.28], [0.26, 0.24]], 14, Transform3D.IDENTITY)
	h.color(CON_D, Geo.CONCRETE)
	h.ribs(0.28, 0.04, 0.2, 8, 0.02, 0.02, Transform3D.IDENTITY)
	h.color(CON_L, Geo.CONCRETE)
	h.dome(0.22, 0.16, 4, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.26, 0)))
	h.color("#ffffff", Geo.TEAM)
	h.band(0.28, 0.18, 0.02, 0.006, 12, Transform3D.IDENTITY)

func _up_zeus(h) -> void:
	h.color(PNT, Geo.PAINT)
	h.cbox(Vector3(0, 0.08, 0), Vector3(0.55, 0.1, 0.35), 0.012)
	for i in 3:
		var x := -0.16 + float(i) * 0.16
		h.cbox(Vector3(x, 0.38, 0), Vector3(0.12, 0.5, 0.12), 0.01)
		h.color(STL, Geo.STEEL)
		h.tube(Vector3(x, 0.16, 0), Vector3(x, 0.6, 0), 0.03, 6)
		h.color(PNT, Geo.PAINT)
	h.color(STL, Geo.STEEL)
	h.dish(Vector3(0.28, 0.45, 0), 0.1, 30.0, 0.5)
