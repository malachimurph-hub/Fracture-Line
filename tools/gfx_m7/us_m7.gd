extends RefCounted
## M2.7 United States detail pass (tool-time only). Original procedural models, "inspired by"
## modern US equipment roles only (no EA assets; the C&C source is reference for nothing here).
## Kit: tools/gfx_m7/kit7.gd (chamfers, lathes, rails, pipes, spinners, pulse lamps) on the
## m3 shader; AO baked afterwards by tools/gfx_m7/bake_ao.gd.
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const Y0 := 0.08
# M2.7 US palette: lighter olive drab so the forms read at RTS distance (M2.5 was near-black)
const US := "#7e8a5c"
const US_D := "#66704a"
const US_L := "#8a946a"
const US_S := "#464a46"
const CON := "#b8b2a3"     # light concrete
const CON_D := "#9c9686"
const CON_L := "#cdc8bb"
const ROOF := "#6c706b"
const WHITE := "#dcdcd6"
const GLASS_C := "#2a3a46"

static var wrote: Array = []

static func build(only: Array) -> void:
	var all := only.is_empty() or "all" in only
	var jobs := {
		"us_reactor": func() -> void: _make("reactor", Vector2(3, 3), 2.1, _reactor),
		"us_command": func() -> void: _make("command", Vector2(4, 4), 1.9, _command),
		"us_supply_center": func() -> void: _make("supply_center", Vector2(3, 3), 1.4, _supply_center),
		"us_barracks": func() -> void: _make("barracks", Vector2(3, 3), 1.3, _barracks),
		"us_garage": func() -> void: _make("garage", Vector2(4, 4), 1.55, _garage),
		"us_airfield": func() -> void: _make("airfield", Vector2(4, 4), 1.5, _airfield),
		"us_strategy": func() -> void: _make("strategy", Vector2(3, 3), 2.0, _strategy),
		"us_patriot": func() -> void: _make("patriot", Vector2(2, 2), 0.95, _patriot, _patriot_turret, Vector3(0, 0.32, 0)),
		"us_firebase": func() -> void: _make("firebase", Vector2(2, 2), 1.0, _firebase, _firebase_turret, Vector3(0, 0.55, 0)),
		"us_drop_zone": func() -> void: _make("drop_zone", Vector2(3, 3), 1.7, _drop_zone),
		"us_halberd": func() -> void: _halberd(),
		"us_lynx": func() -> void: _lynx(),
		"us_picket": func() -> void: _picket(),
		"us_longreach": func() -> void: _longreach(),
		"us_dozer": func() -> void: _dozer(),
		"us_supply_truck": func() -> void: _supply_truck(),
	}
	var et = load("res://tools/gfx_m7/eu_tp_m7.gd")
	jobs.merge(et.jobs())
	jobs.merge(et.vjobs())
	jobs.merge(load("res://tools/gfx_m7/us_v8.gd").jobs(), true)   # M2.7b vehicle remodel supersedes M2.7
	for k in jobs:
		if all or k in only:
			jobs[k].call()
	var f := FileAccess.open("/tmp/gfx_m7_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line("WROTE " + p)

# ------------------------------------------------------------------ building assembly
static func _make(short: String, fp: Vector2, top: float, hull_fn: Callable, turret_fn: Callable = Callable(), tpos := Vector3.ZERO, fac := "us", found_fn: Callable = Callable()) -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/buildings/building_view.gd"))
	root.set("selection_radius", maxf(fp.x, fp.y) * 0.5)
	root.set("bar_height", top + 0.15)
	root.set("footprint", fp)
	root.set("is_structure", true)
	root.set("top_y", top + 0.05)
	root.set("scaffold_top", top * 0.8)
	var model := VK._n3(root, root, "Model")
	var f = K.new()
	if found_fn.is_valid():
		found_fn.call(f, fp)
	else:
		_foundation(f, fp)
	VK._mi(model, root, "Foundation", f.commit(mat))
	var h = K.new()
	hull_fn.call(h)
	VK._mi(model, root, "Hull", h.commit(mat))
	var parts: Array = [h, f]
	if turret_fn.is_valid():
		var pv := VK._n3(model, root, "TurretPivot", tpos)
		var t = K.new()
		turret_fn.call(t)
		VK._mi(pv, root, "Turret", t.commit(mat))
		parts.append(t)
	var tp := fac == "tpla"
	var s = B4._scaffold(fp, top * 0.8)
	VK._mi(model, root, "Scaffold", s.commit(mat)).visible = false
	var l = B4._damage_light(fp, tp)
	VK._mi(model, root, "DamageLight", l.commit(mat)).visible = false
	var hv = B4._damage_heavy(fp, top, tp)
	VK._mi(model, root, "DamageHeavy", hv.commit(mat)).visible = false
	var rb = B4._rubble(fp, tp)
	VK._mi(model, root, "Rubble", rb.commit(mat)).visible = false
	var hx := fp.x * 0.3
	var hz := fp.y * 0.3
	var i := 0
	for p in [Vector3(-hx, top * 0.6, hz * 0.5), Vector3(hx, top * 0.5, -hz), Vector3(0, top * 0.3, hz)]:
		var mk := Marker3D.new()
		mk.name = "Fire%d" % i
		mk.position = p
		model.add_child(mk)
		mk.owner = root
		i += 1
	print("  %s_%s: hull %d + foundation %d%s tris (LOD0)" % [fac, short, h.tris, f.tris, (" + turret %d" % parts[2].tris) if parts.size() > 2 else ""])
	var path := "res://view/buildings/%s/%s.tscn" % [fac, short]
	VK._save(root, path, top + 0.15)
	wrote.append(path)

## Concrete pad with chamfered kerb, expansion joints, drain grates and painted edge lines.
static func _foundation(g, fp: Vector2) -> void:
	var hx := fp.x * 0.5 - 0.03
	var hz := fp.y * 0.5 - 0.03
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 * 0.5, 0), Vector3(hx * 2, Y0, hz * 2), 0.025)
	g.color("#8d887a", Geo.CONCRETE)   # joints
	for k in range(1, int(fp.x)):
		g.box(Vector3(-hx + k * hx * 2 / fp.x, Y0 + 0.001, 0), Vector3(0.012, 0.003, hz * 2 - 0.08))
	for k in range(1, int(fp.y)):
		g.box(Vector3(0, Y0 + 0.001, -hz + k * hz * 2 / fp.y), Vector3(hx * 2 - 0.08, 0.003, 0.012))
	g.color("#d8a531", Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.box(Vector3(0, Y0 + 0.003, s * (hz - 0.1)), Vector3(hx * 2 - 0.3, 0.004, 0.035))
	g.color("#3a3c3a", Geo.STEEL)
	for c in [Vector3(-hx + 0.16, Y0, hz - 0.16), Vector3(hx - 0.16, Y0, -hz + 0.16)]:
		g.grille(c + Vector3(0, 0.002, 0), 0.16, 0.1, 5)

static func _lamp(g, p: Vector3, c := "#ff3a2a") -> void:
	g.color(c, Geo.LAMP)
	g.cbox(p, Vector3(0.045, 0.045, 0.045), 0.01)

# ================================================================== Fusion Plant (reactor)
## Containment dome on a ribbed base with a breathing cyan core band, a hyperbolic cooling tower,
## turbine hall with spinning roof fans, coolant pipe runs, a transformer yard and a pylon.
static func _reactor(g) -> void:
	var dc := Vector3(-0.42, Y0, -0.32)
	var dt := Transform3D(Basis.IDENTITY, dc)
	# --- containment building
	g.color(CON_L, Geo.CONCRETE)
	g.lathe([[0.0, 0.8], [0.06, 0.8], [0.08, 0.77], [0.56, 0.77], [0.6, 0.74]], 20, dt)
	g.color(CON_D, Geo.CONCRETE)
	g.ribs(0.77, 0.08, 0.56, 16, 0.05, 0.05, dt, 0.1)
	g.pulse_color("#6fd3ff", 0.0)
	for i in 8:   # core viewing slits between the ribs
		var a := TAU * (float(i) + 0.5) / 8.0 + 0.1
		g.box(Vector3.ZERO, Vector3(0.02, 0.16, 0.12), dt * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.775, 0.3, sin(a) * 0.775)))
	g.band(0.77, 0.14, 0.025, 0.012, 20, dt)
	g.band(0.77, 0.46, 0.025, 0.012, 20, dt)
	g.end_pulse()
	g.color("#ffffff", Geo.TEAM)
	g.band(0.77, 0.5, 0.035, 0.016, 20, dt)
	# catwalk ring with railing, dome, crown
	g.color(US_S, Geo.STEEL)
	g.lathe([[0.6, 0.86], [0.625, 0.86]], 20, dt)
	g.rail_ring(0.84, 0.625, 16, 0.1, dt)
	g.color(WHITE, Geo.PAINT)
	g.dome(0.72, 0.6, 5, 20, Transform3D(Basis.IDENTITY, dc + Vector3(0, 0.6, 0)))
	g.color(CON_D, Geo.CONCRETE)
	g.lathe([[1.17, 0.2], [1.22, 0.2], [1.25, 0.16]], 12, dt)
	g.color(US_S, Geo.STEEL)
	g.hatch(dc + Vector3(0.0, 1.25, 0.0), 0.12)
	g.tube(dc + Vector3(0.08, 1.2, -0.05), dc + Vector3(0.08, 1.5, -0.05), 0.008, 4)
	_lamp(g, dc + Vector3(0.08, 1.52, -0.05))
	g.color(US_S, Geo.STEEL)
	g.ladder(dc + Vector3(0.0, 0.06, 0.8), 0.56, Vector3.RIGHT)
	# airlock / personnel entrance facing front
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(dc + Vector3(0.3, 0.17, 0.78), Vector3(0.3, 0.26, 0.24), 0.02)
	g.color("#4a4d4a", Geo.STEEL)
	g.box(dc + Vector3(0.3, 0.14, 0.905), Vector3(0.14, 0.2, 0.01))
	g.color("#d8a531", Geo.PAINT)
	g.box(dc + Vector3(0.3, 0.27, 0.905), Vector3(0.22, 0.025, 0.012))
	# --- hyperbolic cooling tower
	var tc := Vector3(0.86, Y0, -0.78)
	var tt := Transform3D(Basis.IDENTITY, tc)
	g.color(CON_L, Geo.CONCRETE)
	g.lathe([[0.0, 0.58], [0.12, 0.55], [0.45, 0.45], [0.9, 0.37], [1.3, 0.38], [1.62, 0.45]], 20, tt, true, false)
	g.color(CON_D, Geo.CONCRETE)
	g.lathe([[1.62, 0.46], [1.68, 0.46]], 20, tt, false, false)
	g.color("#2a2b2a", Geo.DARK)   # inner shell + deep floor (reads as a hollow tower)
	g.cyl(0.39, 0.39, 0.01, 16, Transform3D(Basis.IDENTITY, tc + Vector3(0, 1.25, 0)))
	for i in 16:   # inner wall as thin slabs (each a closed solid, so the inside faces render)
		var a0 := TAU * float(i) / 16.0
		g.box(Vector3.ZERO, Vector3(0.02, 0.4, 0.17), tt * Transform3D(Basis(Vector3.UP, -a0) * Basis(Vector3.FORWARD, -0.08), Vector3(cos(a0) * 0.41, 1.45, sin(a0) * 0.41)))
	g.color("#ffffff", Geo.TEAM)
	g.band(0.44, 1.48, 0.04, 0.012, 20, tt)
	g.color(CON_D, Geo.CONCRETE)
	for i in 12:   # raker columns at the air inlet
		var a := TAU * float(i) / 12.0
		g.box(Vector3.ZERO, Vector3(0.035, 0.14, 0.035), tt * Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.25), Vector3(cos(a) * 0.57, 0.06, sin(a) * 0.57)))
	g.color(US_S, Geo.STEEL)
	g.ladder(tc + Vector3(-0.5, 0.0, 0.18), 0.5, Vector3(0.3, 0, 0.9))
	for p in [tc + Vector3(0.3, 1.7, 0.33), tc + Vector3(-0.33, 1.7, -0.3)]:
		_lamp(g, p)
	# --- turbine hall
	var hc := Vector3(0.55, Y0, 0.62)
	g.color(CON, Geo.CONCRETE)
	g.cbox(hc + Vector3(0, 0.27, 0), Vector3(1.5, 0.54, 0.7), 0.035)
	g.color(US, Geo.CORR)
	g.prism_x([Vector2(-0.37, 0.54), Vector2(0.37, 0.54), Vector2(0.3, 0.62), Vector2(-0.3, 0.62)], -0.76, 0.76, Transform3D(Basis.IDENTITY, hc))
	g.color(US_S, Geo.STEEL)
	g.fan(hc + Vector3(-0.38, 0.6, 0.0), 0.15, 5, 7.0)
	g.fan(hc + Vector3(0.05, 0.6, 0.0), 0.15, 5, -6.0)
	g.color("#2b2d2c", Geo.DARK)
	g.vent(hc + Vector3(0.48, 0.6, 0.0), 0.2, 0.12, 4, 90)
	g.windows(hc + Vector3(-0.25, 0.4, 0.352), 0.85, 0.1, 7)
	g.rollup(hc + Vector3(0.48, 0.2, 0.352), 0.34, 0.32)
	g.hazard(hc + Vector3(0.48, 0.385, 0.356), 0.4, 0.03, 6)
	g.color("#ffffff", Geo.TEAM)
	g.box(hc + Vector3(-0.25, 0.27, 0.353), Vector3(0.8, 0.05, 0.01))
	g.color(US_S, Geo.STEEL)
	g.tube(hc + Vector3(0.66, 0.5, -0.2), hc + Vector3(0.66, 0.95, -0.2), 0.04, 8)   # exhaust stack
	g.tube(hc + Vector3(0.66, 0.92, -0.2), hc + Vector3(0.66, 0.97, -0.2), 0.05, 8)
	_lamp(g, hc + Vector3(0.66, 1.0, -0.2))
	# --- coolant pipe runs (dome -> hall, tower -> hall) on supports
	g.color("#8d9196", Geo.STEEL)
	g.pipe([dc + Vector3(0.74, 0.3, 0.25), Vector3(0.2, Y0 + 0.3, 0.05), Vector3(0.2, Y0 + 0.3, 0.27)], 0.045)
	g.pipe([dc + Vector3(0.7, 0.18, 0.42), Vector3(0.0, Y0 + 0.18, 0.18), Vector3(0.0, Y0 + 0.18, 0.27)], 0.035)
	g.pipe([tc + Vector3(-0.1, 0.22, 0.5), Vector3(0.76, Y0 + 0.22, 0.27)], 0.04)
	g.color(US_S, Geo.STEEL)
	for p in [Vector3(0.2, Y0, 0.05), Vector3(0.0, Y0, 0.18), Vector3(0.78, Y0, -0.12)]:
		g.box(p + Vector3(0, 0.12, 0), Vector3(0.03, 0.24, 0.03))
		g.box(p + Vector3(0, 0.25, 0), Vector3(0.12, 0.02, 0.06))
	# --- transformer yard (front left) and pylon
	for k in 2:
		var xc := Vector3(-1.15 + k * 0.42, Y0, 0.95)
		g.color(US_D, Geo.PAINT)
		g.cbox(xc + Vector3(0, 0.14, 0), Vector3(0.3, 0.26, 0.22), 0.02)
		g.color(US_S, Geo.STEEL)
		for j in 5:   # radiator fins
			g.box(xc + Vector3(-0.12 + j * 0.06, 0.13, 0.13), Vector3(0.012, 0.2, 0.05))
		for j in 3:
			g.insulator(xc + Vector3(-0.09 + j * 0.09, 0.27, -0.03), 0.11)
		g.color("#d8a531", Geo.PAINT)
		g.box(xc + Vector3(0, 0.22, 0.112), Vector3(0.1, 0.05, 0.004))
	g.color("#8d9196", Geo.STEEL)
	g.rail([Vector3(-1.38, Y0, 0.7), Vector3(-0.55, Y0, 0.7), Vector3(-0.55, Y0, 1.28)], 0.14, 0.2, 0.005)
	g.color(US_S, Geo.STEEL)
	g.lattice(Vector3(-1.25, Y0, 0.42), 1.05, 0.1, 5)
	g.box(Vector3(-1.25, Y0 + 0.95, 0.42), Vector3(0.36, 0.02, 0.02))
	for s in [-0.16, 0.16]:
		g.insulator(Vector3(-1.25 + s, Y0 + 0.86, 0.42), 0.08)
	_lamp(g, Vector3(-1.25, Y0 + 1.08, 0.42))
	# cable from pylon to transformers
	g.color("#1d1e1d", Geo.STEEL)
	g.tube(Vector3(-1.41, Y0 + 0.86, 0.42), Vector3(-1.15, Y0 + 0.38, 0.92), 0.004, 3)
	g.tube(Vector3(-1.09, Y0 + 0.86, 0.42), Vector3(-0.73, Y0 + 0.38, 0.92), 0.004, 3)

# ------------------------------------------------------------------ shared building bits
static func _flag(g, p: Vector3, hgt: float) -> void:
	g.color("#c9ccce", Geo.STEEL)
	g.tube(p, p + Vector3(0, hgt, 0), 0.01, 4)
	g.cbox(p + Vector3(0, hgt + 0.01, 0), Vector3(0.03, 0.02, 0.03), 0.006)
	g.color("#ffffff", Geo.TEAM)
	g.rbox(p + Vector3(0.14, hgt - 0.08, 0), Vector3(0.26, 0.15, 0.01), Vector3(0, -12, 0))

static func _ac_unit(g, c: Vector3) -> void:
	g.color("#9a9d96", Geo.STEEL)
	g.cbox(c + Vector3(0, 0.06, 0), Vector3(0.26, 0.12, 0.2), 0.012)
	g.fan(c + Vector3(0, 0.12, 0), 0.075, 4, 9.0)

static func _floodlight(g, p: Vector3, hgt: float, yaw: float) -> void:
	g.color(US_S, Geo.STEEL)
	g.tube(p, p + Vector3(0, hgt, 0), 0.012, 4)
	var d := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	g.box(p + Vector3(0, hgt, 0), Vector3(0.16, 0.015, 0.015) if absf(d.x) < 0.5 else Vector3(0.015, 0.015, 0.16))
	g.color("#fff3c4", Geo.LAMP)
	for k in [-0.05, 0.05]:
		var o := Vector3(k, 0, 0) if absf(d.x) < 0.5 else Vector3(0, 0, k)
		g.box(p + Vector3(0, hgt + 0.02, 0) + o + d * 0.012, Vector3(0.04, 0.035, 0.04))

static func _jersey(g, c: Vector3, l: float, yaw: float) -> void:
	g.color(CON_L, Geo.CONCRETE)
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c)
	g.prism_x([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.03, 0.04), Vector2(0.015, 0.11), Vector2(-0.015, 0.11), Vector2(-0.03, 0.04)], -l * 0.5, l * 0.5, t)

static func _crates(g, c: Vector3, n: int, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var cols := ["#7c6a45", "#6b5a3a", "#5d6650", "#8a7650"]
	for i in n:
		var p := c + Vector3((i % 2) * 0.27, 0.0, ((i / 2) % 2) * 0.3) + Vector3(0, (i / 4) * 0.22, 0)
		g.color(cols[rng.randi() % 4], Geo.WOOD)
		g.rcbox(p + Vector3(0, 0.11, 0), Vector3(0.24, 0.21, 0.27), 0.015, Vector3(0, rng.randf_range(-8, 8), 0))
		g.color("#3d3f37", Geo.CANVAS)
		g.box(p + Vector3(0, 0.11, 0), Vector3(0.25, 0.02, 0.28))

# ================================================================== Command Center (HQ)
static func _command(g) -> void:
	var c := Vector3(-0.35, Y0, -0.35)
	# ground floor with recessed window band and chamfered corners
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.36, 0), Vector3(2.5, 0.72, 2.3), 0.06)
	g.windows(c + Vector3(-0.35, 0.42, 1.152), 1.5, 0.16, 10)
	g.windows(c + Vector3(0, 0.42, 0), 1.6, 0.16, 10, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.252, 0, 0)))
	g.color(US, Geo.PAINT)
	g.cbox(c + Vector3(0, 0.74, 0), Vector3(2.58, 0.06, 2.38), 0.02)   # parapet band
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0.55, 0.6, 1.153), Vector3(0.7, 0.07, 0.01))
	# upper operations deck: sloped glass
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(c + Vector3(-0.2, 0.98, -0.25), Vector3(1.6, 0.44, 1.4), 0.05)
	g.color("#2a3a46", Geo.GLASS)
	g.faces([[Vector3(-0.98, 0.78, 0.47), Vector3(0.58, 0.78, 0.47), Vector3(0.58, 1.18, 0.4), Vector3(-0.98, 1.18, 0.4)],
		[Vector3(-0.98, 0.78, 0.5), Vector3(0.58, 0.78, 0.5), Vector3(0.58, 1.18, 0.43), Vector3(-0.98, 1.18, 0.43)]], Transform3D(Basis.IDENTITY, c))
	g.color(US_S, Geo.STEEL)
	for k in 7:
		g.box(c + Vector3(-0.96 + k * 0.255, 0.98, 0.47), Vector3(0.018, 0.4, 0.04))
	g.color(US, Geo.PAINT)
	g.cbox(c + Vector3(-0.2, 1.22, -0.25), Vector3(1.66, 0.05, 1.46), 0.015)
	# roof: radar on a pedestal, AC units, comms mast, hatch
	g.color(CON_L, Geo.CONCRETE)
	g.ccyl(0.18, 0.18, 0.03, 12, Transform3D(Basis.IDENTITY, c + Vector3(-0.6, 1.24, -0.55)))
	g.dish(c + Vector3(-0.6, 1.52, -0.55), 0.3, 25, 0.9)
	_ac_unit(g, c + Vector3(0.25, 1.245, -0.6))
	_ac_unit(g, c + Vector3(0.25, 1.245, -0.25))
	g.color(US_S, Geo.STEEL)
	g.hatch(c + Vector3(-0.2, 1.245, 0.15), 0.14)
	g.lattice(c + Vector3(0.75, 0.77, -0.85), 1.0, 0.07, 5)
	for y in [1.35, 1.55]:
		g.box(c + Vector3(0.75, y, -0.85), Vector3(0.22, 0.012, 0.012))
	_lamp(g, c + Vector3(0.75, 1.8, -0.85))
	g.color(WHITE, Geo.PAINT)
	g.dome(0.16, 0.14, 3, 12, Transform3D(Basis.IDENTITY, c + Vector3(-1.0, 0.77, 0.8)))   # satcom radome
	g.color(US_S, Geo.STEEL)
	g.rail([c + Vector3(-1.2, 0.77, 1.1), c + Vector3(1.2, 0.77, 1.1), c + Vector3(1.2, 0.77, -1.1)], 0.09, 0.25, 0.005)
	# entrance canopy with columns and steps
	g.color(US, Geo.PAINT)
	g.cbox(c + Vector3(-0.35, 0.5, 1.33), Vector3(0.7, 0.04, 0.36), 0.01)
	g.color(CON_L, Geo.CONCRETE)
	for x in [-0.64, -0.06]:
		g.box(c + Vector3(x, 0.25, 1.46), Vector3(0.04, 0.5, 0.04))
	for k in 3:
		g.box(c + Vector3(-0.35, 0.015 + k * 0.03, 1.38 + 0.08 * (2 - k)), Vector3(0.6, 0.03, 0.12 + 0.08 * k))
	g.color("#3a3c3a", Geo.DARK)
	g.box(c + Vector3(-0.35, 0.22, 1.153), Vector3(0.34, 0.4, 0.012))
	# helipad (east) with H and edge lights
	var hp := Vector3(1.25, Y0, 1.15)
	g.color("#5a5750", Geo.CONCRETE)
	g.ccyl(0.62, 0.035, 0.012, 20, Transform3D(Basis.IDENTITY, hp))
	g.color("#e4e0d6", Geo.PAINT)
	g.lathe([[0.036, 0.56], [0.04, 0.56]], 20, Transform3D(Basis.IDENTITY, hp), false, true)
	g.color("#5a5750", Geo.CONCRETE)
	g.cyl(0.52, 0.52, 0.042, 20, Transform3D(Basis.IDENTITY, hp))
	g.color("#e4e0d6", Geo.PAINT)
	for x in [-0.15, 0.15]:
		g.box(hp + Vector3(x, 0.045, 0), Vector3(0.06, 0.004, 0.42))
	g.box(hp + Vector3(0, 0.045, 0), Vector3(0.3, 0.004, 0.06))
	g.color("#ffd27a", Geo.LAMP)
	for i in 8:
		var a := TAU * i / 8.0
		g.box(hp + Vector3(cos(a) * 0.6, 0.05, sin(a) * 0.6), Vector3(0.03, 0.02, 0.03))
	_flag(g, Vector3(1.65, Y0, -1.6), 1.2)
	for k in 3:
		_jersey(g, Vector3(-1.5 + k * 0.42, Y0, 1.7), 0.38, 0)
	_floodlight(g, Vector3(-1.75, Y0, -1.7), 0.9, 45)
	g.color(US_D, Geo.PAINT)   # generator skid
	g.cbox(Vector3(1.55, Y0 + 0.12, -0.6), Vector3(0.3, 0.24, 0.5), 0.02)
	g.color("#2b2d2c", Geo.DARK)
	g.vent(Vector3(1.55, Y0 + 0.14, -0.34), 0.2, 0.14, 4)
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(1.6, Y0 + 0.24, -0.75), Vector3(1.6, Y0 + 0.45, -0.75), 0.02, 6)

# ================================================================== Supply Center
static func _supply_center(g) -> void:
	var c := Vector3(-0.3, Y0, -0.35)
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.36, 0), Vector3(2.1, 0.72, 1.5), 0.04)
	# barrel-vault corrugated roof
	g.color(US, Geo.CORR)
	var prof: Array = []
	for i in 9:
		var a := PI * float(i) / 8.0
		prof.append(Vector2(cos(a) * 0.78, 0.72 + sin(a) * 0.32))
	g.prism_x(prof, -1.08, 1.08, Transform3D(Basis.IDENTITY, c))
	g.color(US_D, Geo.PAINT)
	for x in [-1.08, 1.08]:
		g.box(c + Vector3(x, 0.82, 0), Vector3(0.03, 0.2, 1.56))
	# roof vents / skylights
	g.color("#9a9d96", Geo.STEEL)
	for x in [-0.6, 0.0, 0.6]:
		g.cyl(0.06, 0.05, 0.1, 8, Transform3D(Basis.IDENTITY, c + Vector3(x, 1.02, 0.0)))
		g.cyl(0.08, 0.0, 0.05, 8, Transform3D(Basis.IDENTITY, c + Vector3(x, 1.12, 0.0)))
	for x in [-0.75, -0.25, 0.25]:
		g.rollup(c + Vector3(x, 0.27, 0.752), 0.36, 0.48)
	g.hazard(c + Vector3(-0.25, 0.56, 0.754), 1.4, 0.04, 14)
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0.75, 0.55, 0.753), Vector3(0.42, 0.12, 0.01))
	g.windows(c + Vector3(0.75, 0.35, 0.752), 0.4, 0.12, 3)
	# loading dock with ramp, bumpers
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(c + Vector3(-0.25, 0.07, 0.95), Vector3(1.5, 0.14, 0.4), 0.015)
	g.prism_x([Vector2(1.15, 0.0), Vector2(1.45, 0.0), Vector2(1.15, 0.14)], -0.25 - 0.2, -0.25 + 0.2, Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(0, 0, 0)))
	g.color("#1d1c1b", Geo.RUBBER)
	for x in [-0.75, -0.25, 0.25]:
		for s in [-0.2, 0.2]:
			g.box(c + Vector3(x + s, 0.1, 1.155), Vector3(0.04, 0.07, 0.02))
	# fuel tank on cradles + pallets + forklift-ish pallet jack
	g.color(WHITE, Geo.PAINT)
	g.tube(Vector3(1.0, Y0 + 0.2, -1.2), Vector3(1.0, Y0 + 0.2, -0.45), 0.17, 12)
	g.color(US_S, Geo.STEEL)
	for z in [-1.05, -0.6]:
		g.box(Vector3(1.0, Y0 + 0.06, z), Vector3(0.3, 0.12, 0.05))
	g.color("#d8a531", Geo.PAINT)
	g.lathe([[0.0, 0.172], [0.04, 0.172]], 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(1.0, Y0 + 0.2, -0.85)), false, false)
	_crates(g, Vector3(0.95, Y0, 0.3), 6, 7)
	_crates(g, Vector3(-1.35, Y0, 0.95), 3, 9)
	_floodlight(g, Vector3(1.35, Y0, 1.3), 0.85, 200)
	_flag(g, Vector3(-1.35, Y0, -1.3), 0.9)

# ================================================================== Barracks
static func _barracks(g) -> void:
	var c := Vector3(-0.25, Y0, -0.35)
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 1.2), 0.04)
	g.color(US_D, Geo.CORR)
	g.prism_x([Vector2(-0.66, 0.6), Vector2(0.66, 0.6), Vector2(0.0, 0.95)], -1.15, 1.15, Transform3D(Basis.IDENTITY, c))
	g.color(US_S, Geo.STEEL)
	g.box(c + Vector3(0, 0.955, 0), Vector3(2.32, 0.03, 0.05))   # ridge cap
	for x in [-0.7, 0.0, 0.7]:   # ridge vents
		g.cbox(c + Vector3(x, 0.99, 0), Vector3(0.16, 0.06, 0.12), 0.01)
	g.windows(c + Vector3(-0.6, 0.38, 0.602), 0.7, 0.16, 4)
	g.windows(c + Vector3(0.65, 0.38, 0.602), 0.6, 0.16, 3)
	g.windows(c + Vector3(0, 0.38, -0.602), 1.8, 0.16, 9, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
	# entrance porch
	g.color(US, Geo.PAINT)
	g.prism_x([Vector2(0.6, 0.5), Vector2(0.95, 0.42), Vector2(0.95, 0.45), Vector2(0.6, 0.55)], -0.3, 0.3, Transform3D(Basis.IDENTITY, c + Vector3(0.05, 0, 0)))
	g.color(CON_L, Geo.CONCRETE)
	for x in [-0.22, 0.32]:
		g.box(c + Vector3(x, 0.22, 0.92), Vector3(0.035, 0.44, 0.035))
	g.color("#3a3c3a", Geo.DARK)
	g.box(c + Vector3(0.05, 0.22, 0.603), Vector3(0.3, 0.42, 0.012))
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0.05, 0.5, 0.605), Vector3(0.8, 0.05, 0.01))
	# sandbag fighting position + obstacle course + water tank
	for k in 5:
		var a := PI * (0.15 + 0.7 * k / 4.0)
		g.sandbag(Vector3(1.05 + cos(a) * 0.3, Y0, 0.85 + sin(a) * 0.3), 0.22, rad_to_deg(-a + PI * 0.5))
		g.sandbag(Vector3(1.05 + cos(a) * 0.3, Y0 + 0.07, 0.85 + sin(a) * 0.3), 0.2, rad_to_deg(-a + PI * 0.5))
	g.color("#6b5236", Geo.WOOD)
	for x in [-1.25, -0.85, -0.45]:
		g.tube(Vector3(x, Y0, 1.1), Vector3(x, Y0 + 0.45, 1.1), 0.02, 4)
	g.tube(Vector3(-1.25, Y0 + 0.45, 1.1), Vector3(-0.45, Y0 + 0.45, 1.1), 0.018, 4)
	g.tube(Vector3(-1.25, Y0 + 0.25, 1.1), Vector3(-0.85, Y0 + 0.25, 1.1), 0.014, 4)
	g.color("#3d3f37", Geo.CANVAS)   # cargo net
	g.rbox(Vector3(-0.65, Y0 + 0.22, 1.18), Vector3(0.38, 0.4, 0.01), Vector3(-18, 0, 0))
	g.color(US_S, Geo.STEEL)
	for p in [Vector3(1.0, Y0, -1.15), Vector3(1.3, Y0, -1.15), Vector3(1.0, Y0, -0.85), Vector3(1.3, Y0, -0.85)]:
		g.tube(p, p + Vector3(0, 0.55, 0), 0.012, 4)
	g.color(US_D, Geo.PAINT)
	g.ccyl(0.22, 0.32, 0.03, 12, Transform3D(Basis.IDENTITY, Vector3(1.15, Y0 + 0.55, -1.0)))
	g.cyl(0.22, 0.0, 0.08, 12, Transform3D(Basis.IDENTITY, Vector3(1.15, Y0 + 0.87, -1.0)))
	_ac_unit(g, c + Vector3(-1.32, 0.0, 0.0))
	_flag(g, Vector3(1.35, Y0, -0.4), 1.15)
	V4._antenna(g, c + Vector3(-0.9, 0.85, -0.3), 0.45)

# ================================================================== Garage (war factory)
static func _garage(g) -> void:
	var c := Vector3(0.0, Y0, -0.55)
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.5, 0), Vector3(3.4, 1.0, 2.3), 0.05)
	# saw-tooth roof with north glazing
	for k in 4:
		var z0 := -1.12 + k * 0.56
		g.color(US, Geo.CORR)
		g.prism_x([Vector2(z0, 1.0), Vector2(z0 + 0.56, 1.0), Vector2(z0, 1.28)], -1.68, 1.68, Transform3D(Basis.IDENTITY, c))
		g.color("#2a3a46", Geo.GLASS)
		g.box(c + Vector3(0, 1.14, z0 - 0.006), Vector3(3.2, 0.22, 0.01))
	g.color(US_S, Geo.STEEL)
	for k in 4:
		g.box(c + Vector3(0, 1.29, -1.12 + k * 0.56), Vector3(3.38, 0.025, 0.03))
	for x in [-1.1, 0.0, 1.1]:
		g.rollup(c + Vector3(x, 0.4, 1.152), 0.86, 0.76)
		g.hazard(c + Vector3(x, 0.84, 1.155), 0.9, 0.05, 9)
		g.color("#ffd27a", Geo.LAMP)
		g.box(c + Vector3(x, 0.92, 1.17), Vector3(0.1, 0.03, 0.03))
	g.color(CON_D, Geo.CONCRETE)
	for x in [-1.65, -0.55, 0.55, 1.65]:   # pilasters between bays
		g.cbox(c + Vector3(x, 0.5, 1.17), Vector3(0.12, 1.0, 0.08), 0.015)
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0, 0.96, 1.156), Vector3(2.0, 0.06, 0.01))
	# side annex with fans and stacks
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(c + Vector3(-1.2, 1.12, -0.7), Vector3(0.7, 0.24, 0.6), 0.02)
	_ac_unit(g, c + Vector3(-1.35, 1.24, -0.7))
	_ac_unit(g, c + Vector3(-1.02, 1.24, -0.7))
	g.color(US_S, Geo.STEEL)
	for x in [1.2, 1.45]:
		g.tube(c + Vector3(x, 1.0, -0.85), c + Vector3(x, 1.6, -0.85), 0.05, 8)
		g.tube(c + Vector3(x, 1.56, -0.85), c + Vector3(x, 1.62, -0.85), 0.06, 8)
	g.ladder(c + Vector3(1.71, 0.0, -0.3), 1.0, Vector3.BACK)
	# gantry crane over the yard
	var y := Vector3(0, Y0, 1.45)
	g.color("#d8a531", Geo.PAINT)
	for x in [-1.75, 1.75]:
		g.cbox(y + Vector3(x, 0.55, 0), Vector3(0.08, 1.1, 0.08), 0.01)
		g.cbox(y + Vector3(x, 0.03, 0), Vector3(0.12, 0.06, 0.4), 0.01)
	g.cbox(y + Vector3(0, 1.1, 0), Vector3(3.6, 0.09, 0.12), 0.012)
	g.color(US_S, Geo.STEEL)
	g.cbox(y + Vector3(0.45, 1.02, 0), Vector3(0.22, 0.1, 0.18), 0.012)
	g.tube(y + Vector3(0.45, 0.98, 0), y + Vector3(0.45, 0.55, 0), 0.006, 3)
	g.cbox(y + Vector3(0.45, 0.53, 0), Vector3(0.06, 0.04, 0.06), 0.008)
	# fuel pumps + parts
	g.color(US, Geo.PAINT)
	for x in [-1.5, -1.25]:
		g.cbox(Vector3(x, Y0 + 0.12, 1.85), Vector3(0.14, 0.24, 0.1), 0.012)
	_crates(g, Vector3(1.3, Y0, -1.75), 2, 3)
	g.color("#1d1c1b", Geo.RUBBER)   # tyre stack
	for k in 3:
		g.cyl(0.1, 0.1, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(-1.65, Y0 + k * 0.06, -1.75)))

# ================================================================== Airfield
static func _airfield(g) -> void:
	# apron in concrete panels (parking stands stay clear: AirSys.parking_pos 3 x 2)
	g.color("#6a665e", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.01, 0), Vector3(3.9, 0.02, 3.9))
	g.color("#55524b", Geo.CONCRETE)
	for k in range(1, 6):
		g.box(Vector3(-1.95 + k * 0.65, Y0 + 0.021, 0), Vector3(0.012, 0.003, 3.86))
		g.box(Vector3(0, Y0 + 0.021, -1.95 + k * 0.65), Vector3(3.86, 0.003, 0.012))
	for r in 2:
		for cc in 3:
			var p := Vector3(-1.333 + cc * 1.333, Y0 + 0.024, -1.0 + r * 2.0)
			g.color("#e4e0d6", Geo.PAINT)
			g.box(p + Vector3(-0.45, 0, 0), Vector3(0.035, 0.004, 1.4))
			g.box(p + Vector3(0.45, 0, 0), Vector3(0.035, 0.004, 1.4))
			g.box(p + Vector3(0, 0, -0.7), Vector3(0.9, 0.004, 0.035))
			g.color("#d8a531", Geo.PAINT)
			g.box(p + Vector3(0, 0, 0.05), Vector3(0.03, 0.004, 1.1))   # lead-in line
			g.cyl(0.08, 0.08, 0.004, 10, Transform3D(Basis.IDENTITY, p + Vector3(0, 0, -0.35)))
			g.color("#ffffff", Geo.TEAM)
			g.box(p + Vector3(0, 0, 0.62), Vector3(0.3, 0.004, 0.06))
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0, Y0 + 0.024, 0.0), Vector3(3.8, 0.004, 0.06))
	g.color("#ffd27a", Geo.LAMP)
	for i in 8:
		for z in [1.92, -1.92]:
			g.cbox(Vector3(-1.85 + i * 0.53, Y0 + 0.035, z), Vector3(0.035, 0.03, 0.035), 0.008)
	g.color("#4fa0ff", Geo.LAMP)
	for i in 6:
		g.box(Vector3(-1.92, Y0 + 0.035, -1.6 + i * 0.64), Vector3(0.03, 0.025, 0.03))
	# blast walls (chamfered) along the west edge
	g.color(CON_L, Geo.CONCRETE)
	for z in [-1.0, 1.0]:
		g.prism_x([Vector2(-0.6, 0.0), Vector2(0.6, 0.0), Vector2(0.55, 0.42), Vector2(-0.55, 0.42)], -0.05, 0.05, Transform3D(Basis.IDENTITY, Vector3(-1.9, Y0, z)))
	# control tower (NE corner) with cab, radar and antenna
	var tc := Vector3(1.72, Y0, 1.72)
	g.color(CON, Geo.CONCRETE)
	g.cbox(tc + Vector3(0, 0.5, 0), Vector3(0.32, 1.0, 0.32), 0.03)
	g.color(US_S, Geo.STEEL)
	g.ladder(tc + Vector3(-0.17, 0.0, 0.0), 1.0, Vector3.BACK)
	g.color(US, Geo.PAINT)
	g.cbox(tc + Vector3(0, 1.02, 0), Vector3(0.5, 0.05, 0.5), 0.012)
	g.color("#2a3a46", Geo.GLASS)
	g.plan_loft([Vector2(-0.22, -0.22), Vector2(0.22, -0.22), Vector2(0.22, 0.22), Vector2(-0.22, 0.22)], 1.045, 1.22, Vector2(1.12, 1.12), Vector2.ZERO, Transform3D(Basis.IDENTITY, tc))
	g.color(US, Geo.PAINT)
	g.cbox(tc + Vector3(0, 1.24, 0), Vector3(0.56, 0.05, 0.56), 0.015)
	g.color("#ffffff", Geo.TEAM)
	g.box(tc + Vector3(0, 0.82, -0.163), Vector3(0.22, 0.07, 0.01))
	g.color(US_S, Geo.STEEL)
	g.tube(tc + Vector3(0, 1.26, 0), tc + Vector3(0, 1.34, 0), 0.02, 6)
	g.dish(tc + Vector3(0, 1.36, 0), 0.16, 10, 1.6, "#cfd2cc")
	V4._antenna(g, tc + Vector3(0.2, 1.26, 0.2), 0.35)
	_lamp(g, tc + Vector3(-0.2, 1.3, -0.2))
	# fuel bowser + tug parked off the stands
	g.color(US_D, Geo.PAINT)
	g.cbox(Vector3(1.75, Y0 + 0.12, -0.05), Vector3(0.24, 0.16, 0.5), 0.02)
	g.color(WHITE, Geo.PAINT)
	g.tube(Vector3(1.75, Y0 + 0.24, -0.25), Vector3(1.75, Y0 + 0.24, 0.12), 0.09, 10)
	g.color("#1d1c1b", Geo.RUBBER)
	for z in [-0.22, 0.14]:
		for s in [-0.13, 0.13]:
			g.cyl(0.05, 0.05, 0.04, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(1.75 + s - 0.02, Y0 + 0.05, z)))
	g.color("#ff8a2a", Geo.CANVAS)   # windsock
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(-1.82, Y0, -1.82), Vector3(-1.82, Y0 + 0.62, -1.82), 0.01, 4)
	g.color("#ff8a2a", Geo.CANVAS)
	g.tube(Vector3(-1.82, Y0 + 0.6, -1.82), Vector3(-1.62, Y0 + 0.56, -1.8), 0.04, 6, 0.02)

# ================================================================== Strategy Center
static func _strategy(g) -> void:
	g.color(CON, Geo.CONCRETE)
	g.plan_loft([Vector2(-1.2, -1.0), Vector2(1.2, -1.0), Vector2(1.3, 0.6), Vector2(0.8, 1.1), Vector2(-0.8, 1.1), Vector2(-1.3, 0.6)], Y0, Y0 + 0.7, Vector2(0.84, 0.84))
	g.color(CON_D, Geo.CONCRETE)
	g.plan_loft([Vector2(-1.22, -1.02), Vector2(1.22, -1.02), Vector2(1.32, 0.61), Vector2(0.81, 1.12), Vector2(-0.81, 1.12), Vector2(-1.32, 0.61)], Y0, Y0 + 0.08, Vector2(1, 1))
	g.color(US_D, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 0.88, -0.05), Vector3(1.2, 0.36, 0.95), 0.04)
	g.windows(Vector3(0, Y0 + 0.9, 0.428), 1.0, 0.12, 8)
	g.color(US, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 1.08, -0.05), Vector3(1.28, 0.04, 1.03), 0.012)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.45, 0.93), Vector3(0.9, 0.08, 0.01))
	g.color("#2a3a46", Geo.GLASS)
	g.rbox(Vector3(0, Y0 + 0.45, 0.88), Vector3(1.2, 0.1, 0.01), Vector3(-17, 0, 0))
	# big slow-turning satellite dish on a drum mount
	g.color(CON_L, Geo.CONCRETE)
	g.ccyl(0.22, 0.32, 0.03, 14, Transform3D(Basis.IDENTITY, Vector3(-0.72, Y0 + 0.7, -0.55)))
	g.dish(Vector3(-0.72, Y0 + 1.32, -0.55), 0.5, 35, 0.35)
	# antenna farm
	g.color(US_S, Geo.STEEL)
	g.lattice(Vector3(0.8, Y0 + 0.7, -0.5), 1.15, 0.08, 6)
	for y in [1.3, 1.55, 1.75]:
		g.box(Vector3(0.8, Y0 + y, -0.5), Vector3(0.26, 0.012, 0.012))
	_lamp(g, Vector3(0.8, Y0 + 1.88, -0.5))
	for p in [Vector3(0.3, Y0 + 1.1, -0.35), Vector3(-0.3, Y0 + 1.1, -0.35)]:
		V4._antenna(g, p, 0.42)
	g.color(WHITE, Geo.PAINT)
	g.dome(0.14, 0.12, 3, 12, Transform3D(Basis.IDENTITY, Vector3(0.35, Y0 + 1.1, 0.2)))
	g.color(US_S, Geo.STEEL)
	g.rail([Vector3(-0.6, Y0 + 1.1, 0.46), Vector3(0.6, Y0 + 1.1, 0.46)], 0.08, 0.2, 0.005)
	g.color("#3a3c3a", Geo.DARK)
	g.box(Vector3(0.0, Y0 + 0.25, 1.06), Vector3(0.3, 0.34, 0.02))
	_floodlight(g, Vector3(1.25, Y0, 0.95), 0.8, 210)

# ================================================================== Bulwark SAM battery
static func _patriot(g) -> void:
	g.color(CON_L, Geo.CONCRETE)   # chamfered revetment walls
	for a in 6:
		var ang := TAU * (a + 0.5) / 6.0
		if a == 1:
			continue
		g.prism_x([Vector2(-0.09, 0.0), Vector2(0.09, 0.0), Vector2(0.05, 0.2), Vector2(-0.05, 0.2)], -0.28, 0.28, Transform3D(Basis(Vector3.UP, -ang + PI * 0.5), Vector3(cos(ang) * 0.84, Y0, sin(ang) * 0.84)))
	g.color(US_D, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 0.1, 0), Vector3(0.66, 0.2, 0.66), 0.03)
	g.color(US_S, Geo.STEEL)
	g.grille(Vector3(0, Y0 + 0.2, 0.0), 0.5, 0.5, 8)
	# phased-array radar trailer
	g.color(US, Geo.PAINT)
	g.cbox(Vector3(-0.55, Y0 + 0.18, -0.55), Vector3(0.36, 0.2, 0.3), 0.02)
	g.color("#2f3330", Geo.DARK)
	g.rbox(Vector3(-0.6, Y0 + 0.4, -0.6), Vector3(0.34, 0.3, 0.04), Vector3(-25, 45, 0))
	g.color("#53584f", Geo.STEEL)
	g.rbox(Vector3(-0.588, Y0 + 0.4, -0.588), Vector3(0.28, 0.24, 0.02), Vector3(-25, 45, 0))
	g.color("#1d1c1b", Geo.RUBBER)
	for s in [-0.12, 0.12]:
		g.cyl(0.06, 0.06, 0.04, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.55 + s, Y0 + 0.06, -0.42)))
	# generator
	g.color(US_D, Geo.PAINT)
	g.cbox(Vector3(0.6, Y0 + 0.1, -0.55), Vector3(0.24, 0.18, 0.3), 0.02)
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(0.66, Y0 + 0.19, -0.62), Vector3(0.66, Y0 + 0.36, -0.62), 0.015, 6)
	g.color("#1d1e1d", Geo.STEEL)
	g.tube(Vector3(0.48, Y0 + 0.1, -0.5), Vector3(0.2, Y0 + 0.03, -0.2), 0.008, 3)

static func _patriot_turret(g) -> void:
	g.color(US_S, Geo.STEEL)
	g.ccyl(0.25, 0.06, 0.015, 14, Transform3D.IDENTITY)
	g.color(US_D, Geo.PAINT)
	for s in [-0.3, 0.3]:   # elevating frame arms
		g.rcbox(Vector3(s, 0.14, 0.0), Vector3(0.04, 0.2, 0.3), 0.01, Vector3(35, 0, 0))
	g.color(US, Geo.PAINT)
	for k in 4:   # four canisters in a 2 x 2 box, raised 35 degrees
		var s := -0.13 + (k % 2) * 0.26
		var y := 0.3 + (k / 2) * 0.13
		g.rcbox(Vector3(s, y, -0.04 + (k / 2) * -0.08), Vector3(0.24, 0.12, 0.82), 0.02, Vector3(35, 0, 0))
	g.color("#1d1f1e", Geo.DARK)
	for k in 4:
		var s2 := -0.13 + (k % 2) * 0.26
		var y2 := 0.3 + (k / 2) * 0.13
		g.rbox(Vector3(s2, y2 + 0.24, 0.3 + (k / 2) * -0.08), Vector3(0.2, 0.09, 0.02), Vector3(35, 0, 0))
	g.color("#ffffff", Geo.TEAM)
	g.rbox(Vector3(0, 0.22, -0.15), Vector3(0.52, 0.04, 0.3), Vector3(35, 0, 0))

# ================================================================== Fire Base
static func _firebase(g) -> void:
	g.color(CON, Geo.CONCRETE)
	g.lathe([[0.0, 0.95], [0.06, 0.95], [0.42, 0.82], [0.5, 0.76]], 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	g.color("#2b2d2c", Geo.DARK)
	for a in 6:   # firing slits
		var ang := TAU * a / 6.0 + 0.3
		g.box(Vector3.ZERO, Vector3(0.05, 0.06, 0.22), Transform3D(Basis(Vector3.UP, -ang), Vector3(cos(ang) * 0.86, Y0 + 0.3, sin(ang) * 0.86)))
	g.color("#ffffff", Geo.TEAM)
	g.band(0.77, Y0 + 0.44, 0.03, 0.01, 16, Transform3D.IDENTITY)
	g.color(US_S, Geo.STEEL)
	g.rail_ring(0.7, Y0 + 0.5, 12, 0.08)
	for a in 4:
		var ang2 := TAU * a / 4.0 + 0.78
		g.sandbag(Vector3(cos(ang2) * 1.0, Y0, sin(ang2) * 1.0), 0.32, rad_to_deg(-ang2 + PI * 0.5))
	_crates(g, Vector3(0.62, Y0, 0.62), 1, 4)
	g.color(US_D, Geo.PAINT)
	g.cbox(Vector3(-0.72, Y0 + 0.08, 0.62), Vector3(0.26, 0.16, 0.14), 0.015)   # ammo boxes

static func _firebase_turret(g) -> void:
	g.color(US_D, Geo.PAINT)
	g.lathe([[0.0, 0.42], [0.2, 0.4], [0.26, 0.34]], 14, Transform3D.IDENTITY)
	g.color(US, Geo.PAINT)
	g.cbox(Vector3(0, 0.36, 0.05), Vector3(0.44, 0.22, 0.48), 0.04)   # gun house
	g.color(US_S, Geo.STEEL)
	g.hatch(Vector3(-0.1, 0.47, -0.08), 0.12)
	g.color(US, Geo.PAINT)
	g.tube(Vector3(0, 0.36, 0.25), Vector3(0, 0.42, 1.15), 0.05, 10, 0.042)
	g.color(US_D, Geo.PAINT)
	g.tube(Vector3(0, 0.38, 0.55), Vector3(0, 0.385, 0.68), 0.06, 10)
	g.color(US_S, Geo.STEEL)
	g.cbox(Vector3(0, 0.425, 1.17), Vector3(0.12, 0.09, 0.12), 0.012)
	for s in [-0.08, 0.08]:
		g.tube(Vector3(s, 0.33, 0.3), Vector3(s, 0.35, 0.6), 0.018, 6)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.223, 0.36, 0.05), Vector3(0.01, 0.06, 0.3))
	g.box(Vector3(-0.223, 0.36, 0.05), Vector3(0.01, 0.06, 0.3))

# ================================================================== Supply Drop Zone
static func _drop_zone(g) -> void:
	g.color("#6a665e", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.01, 0), Vector3(2.8, 0.02, 2.8))
	g.color("#d8a531", Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 1.3, Y0 + 0.022, 0), Vector3(0.12, 0.004, 2.7))
		g.box(Vector3(0, Y0 + 0.022, s * 1.3), Vector3(2.7, 0.004, 0.12))
	g.color("#e4e0d6", Geo.PAINT)
	g.rbox(Vector3(0, Y0 + 0.024, 0), Vector3(1.4, 0.004, 0.12), Vector3(0, 45, 0))
	g.rbox(Vector3(0, Y0 + 0.024, 0), Vector3(1.4, 0.004, 0.12), Vector3(0, -45, 0))
	g.color("#ffffff", Geo.TEAM)
	g.lathe([[0.022, 0.55], [0.026, 0.55]], 20, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)), false, true)
	g.color("#6a665e", Geo.CONCRETE)
	g.cyl(0.48, 0.48, 0.028, 20, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	# beacon lattice mast with strobe
	g.color(US_S, Geo.STEEL)
	g.lattice(Vector3(1.15, Y0, -1.15), 1.5, 0.09, 6)
	g.pulse_color("#ffb02a", 1.0)
	g.cbox(Vector3(1.15, Y0 + 1.55, -1.15), Vector3(0.07, 0.07, 0.07), 0.015)
	g.end_pulse()
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(1.15, Y0 + 1.3, -1.15), Vector3(0.1, 0.2, 0.012))
	# dropped pallets with parachutes and straps
	var cols := ["#7c6a45", "#5d6650", "#6b5a3a"]
	for i in 3:
		var p := Vector3(-0.75 + i * 0.5, Y0, 0.7 - (i % 2) * 0.32)
		g.color("#5a4630", Geo.WOOD)
		g.cbox(p + Vector3(0, 0.025, 0), Vector3(0.4, 0.05, 0.4), 0.008)
		g.color(cols[i], Geo.WOOD)
		g.cbox(p + Vector3(0, 0.2, 0), Vector3(0.34, 0.3, 0.34), 0.02)
		g.color("#2e2f2b", Geo.CANVAS)
		g.box(p + Vector3(0, 0.2, 0), Vector3(0.35, 0.3, 0.03))
		g.box(p + Vector3(0, 0.2, 0), Vector3(0.03, 0.3, 0.35))
		g.color("#d9d9d4", Geo.CANVAS)
		g.rbox(p + Vector3(0.05, 0.02, 0.32), Vector3(0.45, 0.025, 0.26), Vector3(4, 20 * i + 10, 3))
	# control hut + smoke pot + floodlight
	g.color(CON, Geo.CONCRETE)
	g.cbox(Vector3(-1.0, Y0 + 0.22, -1.0), Vector3(0.6, 0.44, 0.5), 0.03)
	g.color(US, Geo.CORR)
	g.cbox(Vector3(-1.0, Y0 + 0.46, -1.0), Vector3(0.66, 0.04, 0.56), 0.01)
	g.windows(Vector3(-1.0, Y0 + 0.28, -0.748), 0.4, 0.1, 2)
	V4._antenna(g, Vector3(-1.2, Y0 + 0.48, -1.15), 0.5)
	_ac_unit(g, Vector3(-0.85, Y0 + 0.48, -1.05))
	g.color("#3a3c3a", Geo.STEEL)
	g.ccyl(0.06, 0.1, 0.01, 8, Transform3D(Basis.IDENTITY, Vector3(0.9, Y0, 1.0)))
	g.color("#ff6a2a", Geo.LAMP)
	g.cyl(0.04, 0.04, 0.02, 8, Transform3D(Basis.IDENTITY, Vector3(0.9, Y0 + 0.1, 1.0)))
	_floodlight(g, Vector3(-1.3, Y0, 1.25), 0.9, 135)

# ================================================================== vehicles
static func _vfinish(root: Node3D, model: Node3D, h, mat: Material, name: String, extra: Array, bar: float, fac := "us") -> void:
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	var t := 0
	for g in [h] + extra:
		t += g.tris
	print("  %s_%s: %d tris (LOD0) in %d meshes" % [fac, name, t, 1 + extra.size()])
	var path := "res://view/units/%s/%s.tscn" % [fac, name]
	VK._save(root, path, bar)
	wrote.append(path)

static func _barrel(piv: Node3D, root: Node3D, mat: Material, at: Vector3, parts: Callable):
	var bn := VK._n3(piv, root, "Barrel", at)
	var b = K.new()
	parts.call(b)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	return b

## Segmented armour skirt over the running gear with bolt rows and a chamfered lower lip.
static func _skirt(h, x: float, z0: float, z1: float, y0: float, y1: float, n: int, col: String) -> void:
	var s := signf(x)
	var seg := (z1 - z0) / float(n)
	for i in n:
		var zc := z0 + seg * (float(i) + 0.5)
		h.color(col, Geo.PAINT)
		h.box(Vector3(x, (y0 + y1) * 0.5, zc), Vector3(0.035, y1 - y0, seg - 0.012))
		if i % 2 == 0:
			h.color(US_S, Geo.STEEL)
			h.rivets(Vector3(x + s * 0.018, y1 - 0.02, zc - seg * 0.3), Vector3(x + s * 0.018, y1 - 0.02, zc + seg * 0.3), 2, Vector3(s, 0, 0), 0.006)

## Road-wheel suspension: torsion arms + bump stops visible above the wheels.
static func _susp(h, sx: float, zs: Array, y: float) -> void:
	h.color(US_S, Geo.STEEL)
	for z in zs:
		for s in [-sx, sx]:
			h.box(Vector3(s * 0.92, y, z + 0.05), Vector3(0.03, 0.03, 0.12))

## Smoke grenade launcher cluster (4 tubes) at p, pointing yaw degrees.
static func _smoke(t, p: Vector3, yaw: float) -> void:
	t.color(US_S, Geo.STEEL)
	var d := Vector3(sin(deg_to_rad(yaw)), 0.3, cos(deg_to_rad(yaw))).normalized()
	for i in 4:
		var o := p + Vector3(0, (i % 2) * 0.03, (i / 2) * 0.03)
		t.tube(o, o + d * 0.06, 0.012, 6)

## Heavy MG on a pintle (tube + receiver + ammo can).
static func _mg(t, p: Vector3, yaw: float, l := 0.22) -> void:
	t.color(US_S, Geo.STEEL)
	var d := Vector3(sin(deg_to_rad(yaw)), 0.05, cos(deg_to_rad(yaw))).normalized()
	t.tube(p - Vector3(0, 0.06, 0), p, 0.008, 4)
	t.cbox(p + d * 0.03, Vector3(0.04, 0.04, 0.09), 0.006)
	t.tube(p + d * 0.06, p + d * l, 0.009, 6)
	t.tube(p + d * l * 0.7, p + d * l, 0.012, 6)
	t.color("#4d5741", Geo.PAINT)
	t.cbox(p + Vector3(0.04, -0.02, 0), Vector3(0.03, 0.04, 0.05), 0.005)

# ------------------------------------------------------------------ Halberd MBT (Abrams-inspired)
static func _halberd() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.35, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._tracks(h, 0.5, 1.8, 7, 0.085, US_D, US_S, 0.24)
	# lower hull and upper hull with long glacis and flat engine deck
	h.color(US_D, Geo.PAINT)
	h.prism_x([Vector2(-0.88, 0.14), Vector2(0.7, 0.14), Vector2(0.9, 0.3), Vector2(0.9, 0.34), Vector2(-0.9, 0.36), Vector2(-0.9, 0.18)], -0.38, 0.38)
	h.color(US, Geo.PAINT)
	h.prism_x([Vector2(-0.9, 0.34), Vector2(0.9, 0.34), Vector2(0.92, 0.37), Vector2(0.45, 0.44), Vector2(-0.86, 0.45), Vector2(-0.92, 0.41)], -0.62, 0.62)
	_skirt(h, 0.64, -0.74, 0.78, 0.2, 0.36, 6, US)
	_skirt(h, -0.64, -0.74, 0.78, 0.2, 0.36, 6, US)
	# glacis: driver hatch + periscopes, headlight guards, tow hooks
	h.color(US_D, Geo.PAINT)
	h.hatch(Vector3(0, 0.425, 0.5), 0.16)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.07, 0.0, 0.07]:
		h.box(Vector3(x, 0.445, 0.6), Vector3(0.05, 0.02, 0.025))
	V4._lamps(h, 0.5, 0.39, 0.9)
	h.color(US_S, Geo.STEEL)
	for x in [-0.5, 0.5]:
		h.tube(Vector3(x - 0.05, 0.36, 0.92), Vector3(x + 0.05, 0.42, 0.92), 0.005, 3)
		h.tube(Vector3(x, 0.16, 0.9), Vector3(x, 0.16, 0.96), 0.02, 6)
	# engine deck: grilles, access panels, exhaust grille at the rear
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.448, -0.55), 0.7, 0.36, 9)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.3, -0.905), 0.7, 0.12, 5, 180)
	h.color(US_D, Geo.PAINT)
	for x in [-0.45, 0.45]:   # rear stowage boxes on the fenders
		h.cbox(Vector3(x, 0.5, -0.8), Vector3(0.24, 0.1, 0.16), 0.012)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.55, 0.55]:
		h.box(Vector3(x, 0.38, -0.92), Vector3(0.05, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.665, 0.665]:
		h.box(Vector3(s, 0.33, 0.02), Vector3(0.006, 0.035, 1.2))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.43, -0.12))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.36, 0.36, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(US, Geo.PAINT)
	# faceted wedge turret: flat sloped cheeks, long bustle
	t.plan_loft([Vector2(-0.44, -0.5), Vector2(0.44, -0.5), Vector2(0.5, 0.12), Vector2(0.28, 0.5), Vector2(-0.28, 0.5), Vector2(-0.5, 0.12)], 0.0, 0.2, Vector2(0.93, 0.95), Vector2(0, -0.02))
	t.color(US_D, Geo.PAINT)
	t.plan_loft([Vector2(-0.4, -0.78), Vector2(0.4, -0.78), Vector2(0.42, -0.48), Vector2(-0.42, -0.48)], 0.03, 0.19, Vector2(0.96, 0.96))
	# bustle rack + stowed bags
	t.color(US_S, Geo.STEEL)
	t.rail([Vector3(-0.42, 0.19, -0.5), Vector3(-0.42, 0.19, -0.84), Vector3(0.42, 0.19, -0.84), Vector3(0.42, 0.19, -0.5)], 0.08, 0.12, 0.006)
	t.color("#6b5a3a", Geo.CANVAS)
	t.cbox(Vector3(-0.22, 0.24, -0.7), Vector3(0.3, 0.09, 0.2), 0.03)
	t.color("#56604a", Geo.CANVAS)
	t.cbox(Vector3(0.16, 0.235, -0.68), Vector3(0.36, 0.08, 0.22), 0.03)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.12, -0.785), Vector3(0.6, 0.05, 0.01))
	for s in [-1.0, 1.0]:
		t.box(Vector3(s * 0.485, 0.1, -0.1), Vector3(0.008, 0.05, 0.45))
	# roof: commander's cupola + HMG, loader's hatch + MG, CITV sight, blow-out panels, wind sensor
	t.color(US_D, Geo.PAINT)
	t.ccyl(0.1, 0.07, 0.015, 10, Transform3D(Basis.IDENTITY, Vector3(0.2, 0.19, -0.15)))
	t.color(GLASS_C, Geo.GLASS)
	for i in 6:
		var a := TAU * i / 6.0
		t.box(Vector3(0.2 + cos(a) * 0.09, 0.225, -0.15 + sin(a) * 0.09), Vector3(0.025, 0.015, 0.025))
	_mg(t, Vector3(0.2, 0.33, -0.1), 0.0, 0.26)
	t.color(US_D, Geo.PAINT)
	t.hatch(Vector3(-0.2, 0.19, -0.18), 0.14)
	_mg(t, Vector3(-0.3, 0.3, -0.12), -10.0, 0.18)
	t.color(US_S, Geo.STEEL)
	t.tube(Vector3(-0.05, 0.19, 0.0), Vector3(-0.05, 0.26, 0.0), 0.02, 6)
	t.cbox(Vector3(-0.05, 0.29, 0.0), Vector3(0.09, 0.07, 0.08), 0.01)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.05, 0.29, 0.042), Vector3(0.06, 0.045, 0.006))
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.3, 0.215, 0.18), Vector3(0.12, 0.05, 0.12), 0.01)   # gunner's primary sight
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.3, 0.22, 0.242), Vector3(0.09, 0.03, 0.006))
	t.color("#3f4633", Geo.PAINT)
	for k in 2:
		t.box(Vector3(-0.15 + k * 0.3, 0.193, -0.62), Vector3(0.2, 0.006, 0.14))
	t.color(US_S, Geo.STEEL)
	t.tube(Vector3(0.0, 0.19, -0.6), Vector3(0.0, 0.34, -0.6), 0.006, 3)
	t.box(Vector3(0.0, 0.345, -0.6), Vector3(0.05, 0.02, 0.02))
	V4._antenna(t, Vector3(-0.36, 0.19, -0.6), 0.55)
	V4._antenna(t, Vector3(0.36, 0.19, -0.62), 0.45)
	_smoke(t, Vector3(0.44, 0.13, 0.25), 40.0)
	_smoke(t, Vector3(-0.44, 0.13, 0.25), -40.0)
	t.color(US, Geo.PAINT)
	t.cbox(Vector3(0, 0.1, 0.5), Vector3(0.3, 0.16, 0.1), 0.02)   # mantlet
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.11, 0.54), func(b) -> void:
		b.color(US_D, Geo.PAINT)
		b.tube(Vector3(0, 0, -0.04), Vector3(0, 0, 0.12), 0.07, 12)
		b.color(US, Geo.PAINT)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 1.12), 0.042, 12, 0.036)
		b.color(US_D, Geo.PAINT)
		b.tube(Vector3(0, 0, 0.48), Vector3(0, 0, 0.62), 0.056, 12)   # fume extractor
		for z in [0.25, 0.8]:
			b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.03), 0.046, 12)   # thermal sleeve clamps
		b.color(US_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 1.08), Vector3(0, 0, 1.13), 0.044, 12)
		b.cbox(Vector3(0, 0.05, 1.09), Vector3(0.03, 0.025, 0.04), 0.005))   # muzzle reference sensor
	_vfinish(root, model, h, mat, "halberd", [t, b], 1.35)

# ------------------------------------------------------------------ Lynx JLTV (JLTV-inspired)
static func _lynx_body(h) -> void:
	V4._wheelset(h, 0.42, [0.52, -0.46], 0.17, 0.15, 1, US_S)
	h.color(US_S, Geo.STEEL)   # independent suspension arms + half shafts
	for z in [0.52, -0.46]:
		for s in [-1.0, 1.0]:
			h.tube(Vector3(s * 0.12, 0.2, z), Vector3(s * 0.34, 0.17, z), 0.015, 4)
			h.tube(Vector3(s * 0.14, 0.27, z + 0.06), Vector3(s * 0.3, 0.27, z + 0.04), 0.01, 4)
	h.color(US_D, Geo.PAINT)
	h.prism_x([Vector2(-0.82, 0.22), Vector2(0.72, 0.22), Vector2(0.84, 0.34), Vector2(0.86, 0.5), Vector2(-0.82, 0.5)], -0.34, 0.34)   # V-hull tub
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:   # high flared fenders over the wheels
		for z in [0.52, -0.46]:
			h.prism_x([Vector2(z - 0.24, 0.42), Vector2(z + 0.24, 0.42), Vector2(z + 0.2, 0.5), Vector2(z - 0.2, 0.5)], s * 0.34, s * 0.47)
	h.prism_x([Vector2(0.24, 0.5), Vector2(0.86, 0.5), Vector2(0.88, 0.58), Vector2(0.84, 0.64), Vector2(0.28, 0.68)], -0.4, 0.4)   # hood
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.66, 0.55), 0.4, 0.18, 7)
	h.vent(Vector3(0, 0.56, 0.885), 0.4, 0.07, 4)
	# armoured crew cab: chamfered, thick glass, door seams and handles
	h.color(US, Geo.PAINT)
	h.cbox(Vector3(0, 0.79, -0.2), Vector3(0.8, 0.34, 0.86), 0.05)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, 0.84, 0.235), Vector3(0.62, 0.17, 0.03), Vector3(-10, 0, 0))
	for s in [-0.402, 0.402]:
		for z in [-0.04, -0.4]:
			h.box(Vector3(s, 0.85, z), Vector3(0.02, 0.13, 0.22))
	h.color(US_D, Geo.PAINT)
	for s in [-0.405, 0.405]:
		for z in [0.1, -0.22, -0.56]:
			h.box(Vector3(s, 0.74, z), Vector3(0.008, 0.28, 0.008))   # door seams
		for z2 in [-0.12, -0.46]:
			h.box(Vector3(s * 1.02, 0.72, z2), Vector3(0.015, 0.015, 0.05))   # handles
	h.color(US_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.49, 0.9), Vector3(0.66, 0.08, 0.05), 0.01)   # brush bar / winch
	for s in [-0.3, 0.3]:
		h.tube(Vector3(s, 0.45, 0.9), Vector3(s, 0.62, 0.93), 0.012, 4)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.6, -0.78), Vector3(0.56, 0.18, 0.14), 0.02)   # rear stowage
	h.color("#1d1c1b", Geo.RUBBER)   # spare tyre
	h.tube(Vector3(0.22, 0.63, -0.86), Vector3(0.22, 0.63, -0.93), 0.13, 12)
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.22, 0.63, -0.93), Vector3(0.22, 0.63, -0.94), 0.07, 8)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.33, 0.33]:
		h.box(Vector3(x, 0.55, -0.83), Vector3(0.04, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.406, 0.406]:
		h.box(Vector3(s, 0.62, -0.2), Vector3(0.006, 0.04, 0.7))
	V4._lamps(h, 0.3, 0.56, 0.87)
	V4._antenna(h, Vector3(-0.34, 0.96, -0.55), 0.5)
	V4._antenna(h, Vector3(0.34, 0.96, -0.58), 0.4)

static func _lynx() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.35, "recoil": 0.03, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_lynx_body(h)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.97, -0.25))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.ccyl(0.17, 0.04, 0.01, 14, Transform3D.IDENTITY)
	t.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:   # gunner shield with view blocks
		t.rcbox(Vector3(s * 0.14, 0.11, 0.05), Vector3(0.03, 0.17, 0.2), 0.008, Vector3(0, s * 25, 0))
	t.cbox(Vector3(0, 0.11, 0.13), Vector3(0.2, 0.17, 0.03), 0.008)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0, 0.15, 0.147), Vector3(0.08, 0.05, 0.006))
	t.color(US_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.08, -0.14), Vector3(0.22, 0.12, 0.08), 0.01)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.13, 0.12), func(b) -> void:
		b.color(US_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, 0.05), Vector3(0.06, 0.07, 0.16), 0.008)
		b.tube(Vector3(0, 0, 0.1), Vector3(0, 0, 0.42), 0.014, 8)
		b.tube(Vector3(0, 0, 0.33), Vector3(0, 0, 0.43), 0.019, 8)
		b.color("#4d5741", Geo.PAINT)
		b.cbox(Vector3(0.055, -0.01, 0.02), Vector3(0.05, 0.06, 0.08), 0.006))
	_vfinish(root, model, h, mat, "lynx", [t, b], 1.35)

# ------------------------------------------------------------------ Picket SHORAD (Avenger-inspired)
static func _picket() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.5, "recoil": 0.02, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._wheelset(h, 0.42, [0.5, -0.45], 0.16, 0.14, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.prism_x([Vector2(-0.82, 0.2), Vector2(0.74, 0.2), Vector2(0.84, 0.32), Vector2(0.86, 0.46), Vector2(-0.82, 0.46)], -0.36, 0.36)
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [0.5, -0.45]:
			h.prism_x([Vector2(z - 0.22, 0.4), Vector2(z + 0.22, 0.4), Vector2(z + 0.18, 0.47), Vector2(z - 0.18, 0.47)], s * 0.36, s * 0.46)
	h.prism_x([Vector2(0.15, 0.46), Vector2(0.86, 0.46), Vector2(0.86, 0.54), Vector2(0.2, 0.6)], -0.42, 0.42)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.58, 0.45), 0.36, 0.16, 6)
	h.color(US, Geo.PAINT)
	h.cbox(Vector3(0, 0.66, 0.05), Vector3(0.8, 0.3, 0.4), 0.035)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, 0.72, 0.258), Vector3(0.68, 0.15, 0.025), Vector3(-10, 0, 0))
	for s in [-0.402, 0.402]:
		h.box(Vector3(s, 0.72, 0.05), Vector3(0.02, 0.13, 0.26))
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.5, -0.5), Vector3(0.82, 0.08, 0.62), 0.015)   # flat bed
	h.color(US_S, Geo.STEEL)
	h.rail([Vector3(-0.4, 0.54, -0.8), Vector3(-0.4, 0.54, -0.2)], 0.08, 0.15, 0.005)
	h.rail([Vector3(0.4, 0.54, -0.8), Vector3(0.4, 0.54, -0.2)], 0.08, 0.15, 0.005)
	h.cbox(Vector3(0, 0.48, 0.9), Vector3(0.6, 0.07, 0.04), 0.01)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(-0.28, 0.6, -0.72), Vector3(0.2, 0.12, 0.12), 0.012)   # generator / cooling
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.42, 0.42]:
		h.box(Vector3(s * 1.01, 0.52, 0.05), Vector3(0.006, 0.04, 0.36))
	V4._lamps(h, 0.3, 0.48, 0.87)
	V4._antenna(h, Vector3(0.34, 0.82, -0.1), 0.45)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.56, -0.48))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.ccyl(0.23, 0.05, 0.012, 14, Transform3D.IDENTITY)
	t.color(US, Geo.PAINT)
	t.cbox(Vector3(0, 0.22, 0), Vector3(0.34, 0.36, 0.34), 0.04)   # gunner pod
	t.color(GLASS_C, Geo.GLASS)
	t.rbox(Vector3(0, 0.31, 0.168), Vector3(0.24, 0.13, 0.012), Vector3(-12, 0, 0))
	t.color(US_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.42, -0.02), Vector3(0.22, 0.04, 0.2), 0.01)
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.0, 0.47, -0.04), Vector3(0.12, 0.08, 0.1), 0.012)   # FLIR / laser rangefinder head
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.0, 0.47, 0.012), Vector3(0.07, 0.05, 0.006))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.36, -0.172), Vector3(0.26, 0.04, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.24, 0.0), func(b) -> void:
		for s in [-0.3, 0.3]:   # twin 4-round missile pods
			b.color(US, Geo.PAINT)
			b.cbox(Vector3(s, 0.0, 0.08), Vector3(0.2, 0.22, 0.52), 0.025)
			b.color(US_D, Geo.PAINT)
			b.box(Vector3(s, 0.0, 0.08), Vector3(0.21, 0.02, 0.5))
			b.color("#1d1f1e", Geo.DARK)
			for k in 4:
				b.ccyl(0.035, 0.012, 0.006, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s - 0.05 + (k % 2) * 0.1, -0.05 + (k / 2) * 0.1, 0.336)))
			b.color(US_S, Geo.STEEL)
			b.box(Vector3(s * 0.62, 0.0, 0.05), Vector3(0.06, 0.06, 0.12))
		b.color(US_S, Geo.STEEL)
		b.tube(Vector3(0.3, -0.15, 0.08), Vector3(0.3, -0.15, 0.5), 0.014, 6)
		b.cbox(Vector3(0.3, -0.15, 0.06), Vector3(0.05, 0.06, 0.12), 0.008))
	_vfinish(root, model, h, mat, "picket", [t, b], 1.5)

# ------------------------------------------------------------------ Longreach howitzer (M777-inspired, with prime mover)
static func _longreach() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.3, "recoil": 0.3, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# prime mover (front): 4x4 truck cab + crew bay
	V4._wheelset(h, 0.38, [0.85, 0.35], 0.14, 0.12, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.27, 0.55), Vector3(0.52, 0.08, 0.9), 0.01)
	h.color(US, Geo.PAINT)
	h.cbox(Vector3(0, 0.5, 0.82), Vector3(0.7, 0.36, 0.36), 0.04)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, 0.6, 1.0), Vector3(0.56, 0.14, 0.025), Vector3(-10, 0, 0))
	for s in [-0.352, 0.352]:
		h.box(Vector3(s, 0.6, 0.85), Vector3(0.02, 0.12, 0.2))
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.4, 1.0), 0.4, 0.1, 4)
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [0.85, 0.35]:
			h.prism_x([Vector2(z - 0.19, 0.27), Vector2(z + 0.19, 0.27), Vector2(z + 0.15, 0.33), Vector2(z - 0.15, 0.33)], s * 0.26, s * 0.38)
	h.color("#5d5236", Geo.CANVAS)   # canvas crew bay on hoops
	h.cbox(Vector3(0, 0.52, 0.34), Vector3(0.64, 0.34, 0.54), 0.07)
	h.color(US_S, Geo.STEEL)
	for z in [0.15, 0.34, 0.53]:
		h.box(Vector3(0, 0.69, z), Vector3(0.66, 0.012, 0.02))
	V4._lamps(h, 0.26, 0.42, 1.0)
	V4._antenna(h, Vector3(0.3, 0.7, 0.75), 0.4)
	# towed gun: carriage, split trails with spades, wheels, shield
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.25, 0.12), Vector3(0, 0.25, -0.2), 0.03, 6)
	for s in [-1.0, 1.0]:
		h.color(US, Geo.PAINT)
		h.tube(Vector3(s * 0.08, 0.22, -0.2), Vector3(s * 0.32, 0.12, -0.95), 0.035, 6)
		h.color(US_S, Geo.STEEL)
		h.rcbox(Vector3(s * 0.33, 0.08, -1.0), Vector3(0.14, 0.1, 0.03), 0.008, Vector3(-30, 0, 0))   # spade
		h.wheel(Vector3(s * 0.4, 0.17, -0.42), 0.17, 0.12, false, US_S, 12, 8)
		h.color(US, Geo.PAINT)
		h.prism_x([Vector2(-0.6, 0.3), Vector2(-0.25, 0.3), Vector2(-0.3, 0.36), Vector2(-0.55, 0.36)], s * 0.32, s * 0.48)
	h.color(US, Geo.PAINT)
	h.cbox(Vector3(0, 0.33, -0.42), Vector3(0.5, 0.1, 0.34), 0.02)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.38, -0.2), Vector3(0.6, 0.03, 0.06), 0.008)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.36, 0.36]:
		h.box(Vector3(s * 1.0, 0.5, 0.82), Vector3(0.008, 0.05, 0.3))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.4, -0.42))
	var t = K.new()
	t.color(US, Geo.PAINT)
	for x in [-0.14, 0.14]:   # cradle cheeks with trunnions
		t.cbox(Vector3(x, 0.12, 0.0), Vector3(0.05, 0.22, 0.3), 0.012)
		t.color(US_S, Geo.STEEL)
		t.tube(Vector3(x * 1.4, 0.18, 0), Vector3(x * 0.9, 0.18, 0), 0.03, 8)
		t.color(US, Geo.PAINT)
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.03, 0.0), Vector3(0.36, 0.05, 0.36), 0.012)
	t.cbox(Vector3(0.2, 0.1, -0.08), Vector3(0.06, 0.1, 0.08), 0.01)   # sight box
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.2, 0.12, -0.035), Vector3(0.04, 0.03, 0.006))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.18, 0.0))
	bn.rotation.x = -0.5
	var b = K.new()
	b.color(US_D, Geo.PAINT)
	b.cbox(Vector3(0, 0, -0.02), Vector3(0.16, 0.13, 0.56), 0.02)   # cradle / recoil housing
	b.color(US, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 1.55), 0.045, 10, 0.04)
	b.color(US_S, Geo.STEEL)
	b.cbox(Vector3(0, 0, 1.56), Vector3(0.13, 0.08, 0.15), 0.015)   # muzzle brake
	b.color("#1d1f1e", Geo.DARK)
	for s in [-0.068, 0.068]:
		b.box(Vector3(s, 0, 1.56), Vector3(0.006, 0.05, 0.1))
	b.color(US_S, Geo.STEEL)
	for x in [-0.07, 0.07]:
		b.tube(Vector3(x, 0.06, -0.25), Vector3(x, 0.06, 0.3), 0.022, 8)   # recuperators
	b.tube(Vector3(0, -0.07, -0.25), Vector3(0, -0.07, 0.2), 0.02, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_vfinish(root, model, h, mat, "longreach", [t, b], 1.3)

# ------------------------------------------------------------------ Dozer (builder)
static func _dozer() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._tracks(h, 0.4, 1.3, 4, 0.09, US_D, US_S)
	h.color(US, Geo.PAINT)
	h.cbox(Vector3(0, 0.34, -0.12), Vector3(0.6, 0.24, 0.86), 0.03)   # engine body
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.465, 0.12), 0.46, 0.3, 8)
	h.vent(Vector3(0, 0.36, -0.555), 0.46, 0.14, 5, 180)
	# ROPS cab: safety-yellow frame, glass, roof
	h.color("#d8a531", Geo.PAINT)
	for p in [Vector3(-0.23, 0, -0.04), Vector3(0.23, 0, -0.04), Vector3(-0.23, 0, -0.42), Vector3(0.23, 0, -0.42)]:
		h.cbox(p + Vector3(0, 0.66, 0), Vector3(0.04, 0.4, 0.04), 0.008)
	h.cbox(Vector3(0, 0.88, -0.23), Vector3(0.54, 0.05, 0.48), 0.012)
	h.color(GLASS_C, Geo.GLASS)
	h.box(Vector3(0, 0.66, -0.04), Vector3(0.42, 0.3, 0.008))
	for s in [-0.23, 0.23]:
		h.box(Vector3(s, 0.66, -0.23), Vector3(0.008, 0.3, 0.34))
	h.color("#2e2f2b", Geo.DARK)
	h.cbox(Vector3(0, 0.55, -0.25), Vector3(0.2, 0.08, 0.16), 0.02)   # seat
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.18, 0.46, 0.2), Vector3(0.18, 0.92, 0.2), 0.028, 8)   # exhaust
	h.tube(Vector3(0.18, 0.9, 0.2), Vector3(0.18, 0.95, 0.2), 0.036, 8)
	h.color("#ff9a2a", Geo.LAMP)
	h.cbox(Vector3(-0.2, 0.92, -0.42), Vector3(0.05, 0.04, 0.05), 0.01)   # beacon
	# blade on push arms with hydraulic rams
	h.color(US_S, Geo.STEEL)
	for s in [-0.36, 0.36]:
		h.tube(Vector3(s, 0.2, 0.05), Vector3(s, 0.2, 0.72), 0.03, 6)
		h.tube(Vector3(s * 0.7, 0.5, 0.25), Vector3(s * 0.8, 0.32, 0.7), 0.022, 6)
		h.color("#c9ccce", Geo.STEEL)
		h.tube(Vector3(s * 0.75, 0.41, 0.48), Vector3(s * 0.8, 0.32, 0.7), 0.012, 6)
		h.color(US_S, Geo.STEEL)
	h.color("#d8a531", Geo.PAINT)
	h.prism_x([Vector2(0.72, 0.04), Vector2(0.8, 0.06), Vector2(0.86, 0.3), Vector2(0.8, 0.48), Vector2(0.73, 0.46)], -0.54, 0.54)
	h.color("#b88d25", Geo.PAINT)
	for x in [-0.36, -0.12, 0.12, 0.36]:   # blade ribs (back side)
		h.box(Vector3(x, 0.28, 0.72), Vector3(0.03, 0.36, 0.05))
	h.color(US_S, Geo.STEEL)
	h.box(Vector3(0, 0.05, 0.84), Vector3(1.06, 0.04, 0.06))   # cutting edge
	for x in [-0.53, 0.53]:
		h.cbox(Vector3(x, 0.25, 0.8), Vector3(0.03, 0.42, 0.12), 0.008)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.302, 0.302]:
		h.box(Vector3(s, 0.4, -0.12), Vector3(0.006, 0.05, 0.6))
	V4._lamps(h, 0.18, 0.84, 0.0)
	_vfinish(root, model, h, mat, "dozer", [], 1.2)

# ------------------------------------------------------------------ Supply Truck (harvester; FMTV-inspired 6x6)
static func _supply_truck() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._wheelset(h, 0.4, [0.55, -0.25, -0.6], 0.15, 0.13, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, -0.05), Vector3(0.5, 0.08, 1.62), 0.01)   # frame
	h.color(US, Geo.PAINT)
	h.cbox(Vector3(0, 0.56, 0.55), Vector3(0.74, 0.44, 0.44), 0.05)   # cab
	h.prism_x([Vector2(0.77, 0.32), Vector2(0.92, 0.36), Vector2(0.92, 0.52), Vector2(0.77, 0.56)], -0.34, 0.34)   # nose
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.545, 0.84), 0.4, 0.12, 6)
	h.vent(Vector3(0, 0.44, 0.925), 0.4, 0.12, 5)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, 0.68, 0.775), Vector3(0.6, 0.16, 0.02), Vector3(-12, 0, 0))
	for s in [-0.372, 0.372]:
		h.box(Vector3(s, 0.68, 0.55), Vector3(0.012, 0.14, 0.26))
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.prism_x([Vector2(0.36, 0.35), Vector2(0.74, 0.35), Vector2(0.7, 0.42), Vector2(0.4, 0.42)], s * 0.3, s * 0.42)   # front fenders
		h.color(US_S, Geo.STEEL)
		h.tube(Vector3(s * 0.4, 0.55, 0.78), Vector3(s * 0.46, 0.7, 0.72), 0.008, 3)   # mirror arms
		h.cbox(Vector3(s * 0.46, 0.72, 0.72), Vector3(0.02, 0.07, 0.04), 0.004)
		h.color(US, Geo.PAINT)
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.3, 0.6, 0.32), Vector3(0.3, 0.98, 0.32), 0.022, 6)   # exhaust stack
	h.cbox(Vector3(-0.3, 0.42, 0.3), Vector3(0.1, 0.12, 0.12), 0.01)   # air tank
	# cargo bed with drop sides + crates under nets, fuel cans, spare tyre
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -0.38), Vector3(0.76, 0.08, 0.92), 0.012)
	for x in [-0.37, 0.37]:
		h.cbox(Vector3(x, 0.55, -0.38), Vector3(0.03, 0.18, 0.92), 0.006)
		for z in [-0.7, -0.38, -0.06]:
			h.box(Vector3(x * 1.03, 0.55, z), Vector3(0.012, 0.18, 0.02))
	h.cbox(Vector3(0, 0.55, -0.83), Vector3(0.76, 0.18, 0.03), 0.006)
	var cols := ["#7c6a45", "#6b5a3a", "#8a7650", "#5d6650"]
	for i in 4:
		h.color(cols[i], Geo.WOOD)
		h.cbox(Vector3(-0.17 + (i % 2) * 0.34, 0.6, -0.17 - (i / 2) * 0.42), Vector3(0.3, 0.26, 0.36), 0.018)
	h.color("#66704f", Geo.CANVAS)
	h.cbox(Vector3(0, 0.74, -0.38), Vector3(0.7, 0.025, 0.86), 0.01)
	for z in [-0.6, -0.17]:
		h.box(Vector3(0, 0.7, z), Vector3(0.72, 0.1, 0.02))
	h.color("#4d5741", Geo.PAINT)
	for z in [0.15, 0.22]:
		h.jerrycan(Vector3(-0.4, 0.32, z), 90)
	h.color("#1d1c1b", Geo.RUBBER)
	h.tube(Vector3(0.38, 0.36, 0.1), Vector3(0.44, 0.36, 0.1), 0.12, 12)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.376, 0.376]:
		h.box(Vector3(s * 1.0, 0.56, 0.55), Vector3(0.006, 0.05, 0.3))
	V4._lamps(h, 0.28, 0.42, 0.93)
	V4._antenna(h, Vector3(-0.32, 0.78, 0.4), 0.4)
	_vfinish(root, model, h, mat, "supply_truck", [], 1.2)
