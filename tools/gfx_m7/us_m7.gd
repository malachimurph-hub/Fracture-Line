extends RefCounted
## M2.7 United States detail pass (tool-time only). Original procedural models, "inspired by"
## modern US equipment roles only (no EA assets; the C&C source is reference for nothing here).
## Kit: tools/gfx_m7/kit7.gd (chamfers, lathes, rails, pipes, spinners, pulse lamps) on the
## m3 shader; AO baked afterwards by tools/gfx_m7/bake_ao.gd.
const K := preload("res://tools/gfx_m7/kit7.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const Y0 := 0.08
# M2.7 US palette: lighter olive drab so the forms read at RTS distance (M2.5 was near-black)
const US := "#6f7a52"
const US_D := "#586240"
const US_L := "#8a946a"
const US_S := "#3b3e3b"
const CON := "#b8b2a3"     # light concrete
const CON_D := "#9c9686"
const CON_L := "#cdc8bb"
const ROOF := "#6c706b"
const WHITE := "#dcdcd6"

static var wrote: Array = []

static func build(only: Array) -> void:
	var all := only.is_empty() or "all" in only
	var jobs := {
		"us_reactor": func() -> void: _make("reactor", Vector2(3, 3), 2.1, _reactor),
	}
	for k in jobs:
		if all or k in only:
			jobs[k].call()
	var f := FileAccess.open("/tmp/gfx_m7_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line("WROTE " + p)

# ------------------------------------------------------------------ building assembly
static func _make(short: String, fp: Vector2, top: float, hull_fn: Callable, turret_fn: Callable = Callable(), tpos := Vector3.ZERO) -> void:
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
	var s = B4._scaffold(fp, top * 0.8)
	VK._mi(model, root, "Scaffold", s.commit(mat)).visible = false
	var l = B4._damage_light(fp, false)
	VK._mi(model, root, "DamageLight", l.commit(mat)).visible = false
	var hv = B4._damage_heavy(fp, top, false)
	VK._mi(model, root, "DamageHeavy", hv.commit(mat)).visible = false
	var rb = B4._rubble(fp, false)
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
	print("  us_%s: hull %d + foundation %d%s tris (LOD0)" % [short, h.tris, f.tris, (" + turret %d" % parts[2].tris) if parts.size() > 2 else ""])
	var path := "res://view/buildings/us/%s.tscn" % short
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
	g.lathe([[1.25, 0.37], [1.64, 0.435]], 20, tt, true, false)
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
