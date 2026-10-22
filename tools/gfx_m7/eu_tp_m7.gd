extends RefCounted
## M2.7 detail pass, EU Alliance + TPLA (tool-time only). Replaces the last flat-box views of
## key EU / TPLA structures with kit7 models (same node layout as the US pass, AO baked after).
## Original shapes; real-world equipment roles as loose inspiration only.
const K := preload("res://tools/gfx_m7/kit7.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const U := preload("res://tools/gfx_m7/us_m7.gd")
const Y0 := 0.08
# EU: warm grey-green paint, pale concrete, white trim; TPLA: sun-bleached tan, rust, timber
const EU := "#8a9378"
const EU_D := "#6c7460"
const EU_S := "#4a4e50"
const EU_W := "#d9dad3"
const CON := "#bcb7a9"
const CON_D := "#a29d90"
const TP := "#b89c70"
const TP_D := "#9a8058"
const TP_S := "#3e3a35"
const RUST := "#8a5a3a"
const RUST_D := "#6e4630"
const MUD := "#a88c66"
const MUD_D := "#a8916c"
const WOODC := "#7a5c3c"
const SB := "#cdbb92"     # sandbags: lighter than the earth pads so they read

static func jobs() -> Dictionary:
	return {
		"eu_reactor": func() -> void: U._make("reactor", Vector2(3, 3), 2.0, _eu_reactor, Callable(), Vector3.ZERO, "eu"),
		"eu_motor_pool": func() -> void: U._make("motor_pool", Vector2(4, 4), 1.5, _eu_motor_pool, Callable(), Vector3.ZERO, "eu"),
		"eu_hub": func() -> void: U._make("hub", Vector2(3, 3), 1.7, _eu_hub, Callable(), Vector3.ZERO, "eu"),
		"tpla_chop_shop": func() -> void: U._make("chop_shop", Vector2(4, 4), 1.5, _tp_chop_shop, Callable(), Vector3.ZERO, "tpla", _tp_found),
		"tpla_stash": func() -> void: U._make("stash", Vector2(3, 3), 1.2, _tp_stash, Callable(), Vector3.ZERO, "tpla", _tp_found),
	}

# ------------------------------------------------------------------ shared bits
## Packed-earth pad for TPLA: low rounded mound, tyre ruts, scattered stones and planks.
static func _tp_found(g, fp: Vector2) -> void:
	var hx := fp.x * 0.5 - 0.04
	var hz := fp.y * 0.5 - 0.04
	g.color(MUD_D, Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 * 0.5, 0), Vector3(hx * 2, Y0, hz * 2), 0.05)
	g.color("#94805f", Geo.CONCRETE)
	for x in [-0.35, 0.35]:
		g.box(Vector3(x, Y0 + 0.001, hz * 0.55), Vector3(0.12, 0.004, hz * 0.9))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(fp.x * 31 + fp.y)
	g.color("#8f8a7e", Geo.CONCRETE)
	for i in 10:
		var p := Vector3(rng.randf_range(-hx, hx) * 0.95, Y0, rng.randf_range(-hz, hz) * 0.95)
		if absf(p.x) < hx - 0.15 and absf(p.z) < hz - 0.15:
			continue
		g.rcbox(p + Vector3(0, 0.02, 0), Vector3(0.07, 0.04, 0.06), 0.012, Vector3(0, rng.randf_range(0, 90), 0))

static func _drums(g, c: Vector3, n: int, cols: Array) -> void:
	for i in n:
		var p := c + Vector3((i % 3) * 0.1, 0, (i / 3) * 0.1)
		g.color(cols[i % cols.size()], Geo.STEEL)
		g.lathe([[0.0, 0.042], [0.13, 0.042]], 8, Transform3D(Basis.IDENTITY, p))
		g.color("#2e2c29", Geo.STEEL)
		g.band(0.042, 0.04, 0.008, 0.003, 8, Transform3D(Basis.IDENTITY, p))
		g.band(0.042, 0.09, 0.008, 0.003, 8, Transform3D(Basis.IDENTITY, p))

static func _tyres(g, c: Vector3, n: int) -> void:
	for i in n:
		g.color("#232322", Geo.RUBBER)
		g.lathe([[0.0, 0.09], [0.012, 0.1], [0.05, 0.1], [0.062, 0.09]], 10, Transform3D(Basis(Vector3.UP, i * 0.4), c + Vector3(0, i * 0.062, 0)), true, true)

## Hyperbolic cooling tower (open top with an inner wall and floor so it reads hollow).
static func _tower(g, c: Vector3, r: float, h: float, col: String, col_d: String) -> void:
	var t := Transform3D(Basis.IDENTITY, c)
	var prof := [[0.0, r], [h * 0.25, r * 0.86], [h * 0.55, r * 0.7], [h * 0.8, r * 0.66], [h, r * 0.72]]
	g.color(col, Geo.CONCRETE)
	g.lathe(prof, 20, t, true, false)
	g.color(col_d, Geo.CONCRETE)
	g.band(r * 0.72, h - 0.04, 0.04, 0.01, 20, t)
	g.color("#3b3936", Geo.CHAR)
	g.lathe([[h * 0.7, r * 0.6], [h * 0.7 + 0.01, r * 0.6]], 16, t, false, true)
	g.color(col_d, Geo.CONCRETE)
	for i in 16:   # inner shell slabs
		var a := TAU * float(i) / 16.0
		g.box(Vector3.ZERO, Vector3(0.02, h * 0.3, r * 0.29), t * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * r * 0.66, h * 0.85, sin(a) * r * 0.66)))
	g.color(col_d, Geo.CONCRETE)
	for i in 12:   # raker columns at the base
		var a2 := TAU * float(i) / 12.0
		var p0 := c + Vector3(cos(a2) * r * 1.02, 0, sin(a2) * r * 1.02)
		g.tube(p0, p0 + Vector3(cos(a2 + 0.3) * -0.02, 0.16, sin(a2 + 0.3) * -0.02), 0.018, 4)

# ================================================================== EU Fusion Reactor
## Tokamak hall: a drum with a glowing torus belt of magnet coils under a white containment
## dome, cooling tower, turbine annex with roof fans, coolant loops and a switchyard.
static func _eu_reactor(g) -> void:
	var c := Vector3(0.3, Y0, 0.25)
	var t := Transform3D(Basis.IDENTITY, c)
	g.color(CON, Geo.CONCRETE)
	g.lathe([[0.0, 0.82], [0.04, 0.82], [0.06, 0.79], [0.5, 0.79], [0.54, 0.76]], 22, t)
	g.color(CON_D, Geo.CONCRETE)
	g.ribs(0.79, 0.06, 0.5, 12, 0.05, 0.06, t, 0.13)
	g.color("#ffffff", Geo.TEAM)
	g.band(0.79, 0.4, 0.04, 0.012, 22, t)
	# torus belt (magnet ring) with coils and a breathing plasma window
	g.color(EU_S, Geo.STEEL)
	g.lathe([[0.54, 0.7], [0.6, 0.8], [0.7, 0.84], [0.8, 0.8], [0.86, 0.7]], 22, t)
	g.pulse_color("#7fc8ff", 0.0)
	g.band(0.8, 0.66, 0.08, 0.045, 22, t)
	g.end_pulse()
	g.color("#c58a3a", Geo.STEEL)   # copper-clad coils
	for i in 12:
		var a := TAU * float(i) / 12.0
		g.box(Vector3.ZERO, Vector3(0.1, 0.36, 0.09), t * Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.86, 0.7, sin(a) * 0.86)))
	g.color(EU_W, Geo.PAINT)
	g.lathe([[0.86, 0.66], [0.9, 0.62]], 22, t, false, false)
	g.dome(0.62, 0.48, 5, 22, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.9, 0)))
	g.color(CON_D, Geo.CONCRETE)
	g.lathe([[1.36, 0.12], [1.42, 0.1], [1.42, 0.0]], 10, t, false, true)   # top vent cap
	g.rail_ring(0.84, 0.86, 18, 0.1, t)
	g.color(EU_S, Geo.STEEL)
	g.ladder(c + Vector3(0.0, 0.0, 0.86), 0.86, Vector3.RIGHT)
	U._lamp(g, c + Vector3(0, 1.43, 0))
	# airlock / entrance
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(c + Vector3(0.62, 0.17, 0.62), Vector3(0.36, 0.34, 0.3), 0.02, Transform3D(Basis(Vector3.UP, -PI * 0.25), Vector3.ZERO))
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3.ZERO, Vector3(0.16, 0.22, 0.01), Transform3D(Basis(Vector3.UP, -PI * 0.25), c + Vector3(0.74, 0.13, 0.74)))
	# cooling tower, back left
	_tower(g, Vector3(-0.78, Y0, -0.72), 0.5, 1.75, "#c7c2b4", "#aaa597")
	g.color("#ffffff", Geo.TEAM)
	g.band(0.36, 1.55, 0.05, 0.003, 20, Transform3D(Basis.IDENTITY, Vector3(-0.78, Y0, -0.72)))
	U._lamp(g, Vector3(-0.78 + 0.37, Y0 + 1.76, -0.72))
	# turbine annex with barrel roof and fans, back right
	var a := Vector3(0.62, Y0, -1.02)
	g.color(EU, Geo.PAINT)
	g.cbox(a + Vector3(0, 0.24, 0), Vector3(1.4, 0.48, 0.66), 0.03)
	g.color(EU_D, Geo.CORR)
	var vault: Array = []
	for k in 9:
		var an := PI * float(k) / 8.0
		vault.append(Vector2(cos(an) * 0.34, 0.48 + sin(an) * 0.13))
	g.prism_x(vault, -0.7, 0.7, Transform3D(Basis.IDENTITY, a))
	g.fan(a + Vector3(-0.3, 0.62, 0), 0.09, 5, 7.0)
	g.fan(a + Vector3(0.2, 0.62, 0), 0.09, 5, -6.0)
	g.windows(a + Vector3(0, 0.3, 0.334), 1.1, 0.1, 8)
	g.color(EU_S, Geo.STEEL)
	g.tube(a + Vector3(0.55, 0.4, 0.0), a + Vector3(0.55, 1.05, 0.0), 0.05, 8)
	g.tube(a + Vector3(0.55, 1.0, 0.0), a + Vector3(0.55, 1.07, 0.0), 0.062, 8)
	# coolant loops: hall -> tower, hall -> annex
	g.color("#b9bdb7", Geo.STEEL)
	g.pipe([c + Vector3(-0.78, 0.3, -0.2), Vector3(-0.5, Y0 + 0.3, -0.2), Vector3(-0.5, Y0 + 0.3, -0.42)], 0.045)
	g.pipe([c + Vector3(-0.8, 0.16, 0.1), Vector3(-0.85, Y0 + 0.16, 0.35), Vector3(-0.85, Y0 + 0.16, -0.25)], 0.035)
	g.color("#4f87b8", Geo.STEEL)
	g.pipe([c + Vector3(0.2, 0.22, -0.78), Vector3(0.5, Y0 + 0.22, -0.69)], 0.04)
	g.color(EU_S, Geo.STEEL)
	for z in [-0.05, 0.25]:
		g.box(Vector3(-0.85, Y0 + 0.07, z), Vector3(0.1, 0.14, 0.04))
	# switchyard, front left
	var y := Vector3(-0.85, Y0, 0.85)
	g.color("#7d7f7a", Geo.STEEL)
	g.cbox(y + Vector3(0, 0.12, 0), Vector3(0.32, 0.24, 0.22), 0.02)
	g.color("#5d5f5b", Geo.STEEL)
	for x in [-0.12, -0.04, 0.04, 0.12]:
		g.box(y + Vector3(x, 0.12, 0.115), Vector3(0.02, 0.2, 0.02))
	for x in [-0.08, 0.0, 0.08]:
		g.insulator(y + Vector3(x, 0.24, -0.04), 0.14)
	g.lattice(y + Vector3(0.0, 0.0, -0.38), 0.8, 0.09, 4)
	g.color("#2e302f", Geo.STEEL)
	g.tube(y + Vector3(0, 0.38, 0), y + Vector3(0, 0.8, -0.38), 0.004, 3)
	g.color("#8a8c86", Geo.STEEL)
	g.rail([Vector3(-1.4, Y0, 0.5), Vector3(-1.4, Y0, 1.4), Vector3(-0.35, Y0, 1.4)], 0.14, 0.18)
	U._floodlight(g, Vector3(1.35, Y0, 1.35), 0.75, 225.0)

# ================================================================== EU Motor Pool
## Twin barrel-vault vehicle hangars with roll-up doors, a front apron with fuel island,
## wash rack, gantry hoist, office annex with fans, floodlights and stowage.
static func _eu_motor_pool(g) -> void:
	var rot := Basis(Vector3.UP, PI * 0.5)
	for hx in [-0.9, 0.9]:
		var h := Vector3(hx, Y0, -0.55)
		g.color(CON_D, Geo.CONCRETE)
		g.cbox(h + Vector3(0, 0.12, 0), Vector3(1.62, 0.24, 2.6), 0.03)
		var vault: Array = []
		for k in 11:
			var an := PI * float(k) / 10.0
			vault.append(Vector2(cos(an) * 0.8, 0.24 + sin(an) * 0.78))
		g.color("#a3aa92", Geo.CORR)
		g.prism_x(vault, -1.28, 1.28, Transform3D(rot, h))
		g.color(EU_D, Geo.STEEL)
		for z in [-1.0, -0.4, 0.2, 0.8]:   # vault ribs
			var rib: Array = []
			for k in 11:
				var an2 := PI * float(k) / 10.0
				rib.append(Vector2(cos(an2) * 0.825, 0.24 + sin(an2) * 0.805))
			g.prism_x(rib, z - 0.03, z + 0.03, Transform3D(rot, h))
		g.color("#2a3a46", Geo.GLASS)   # roof skylight strip
		g.box(h + Vector3(0, 1.025, -0.1), Vector3(0.18, 0.02, 1.6))
		# front gable wall with the big door
		g.color(CON, Geo.CONCRETE)
		var gable: Array = []
		for k in 11:
			var an3 := PI * float(k) / 10.0
			gable.append(Vector2(cos(an3) * 0.78, 0.24 + sin(an3) * 0.76))
		g.prism_x(gable, 1.26, 1.31, Transform3D(rot, h))
		g.rollup(h + Vector3(0, 0.44, 1.32), 0.96, 0.72)
		g.hazard(h + Vector3(0, 0.84, 1.322), 1.0, 0.05, 10)
		g.color("#ffffff", Geo.TEAM)
		g.box(h + Vector3(0, 0.94, 1.315), Vector3(0.6, 0.07, 0.01))
		g.color("#ffd27a", Geo.LAMP)
		g.box(h + Vector3(0, 1.02, 1.33), Vector3(0.12, 0.03, 0.03))
		g.fan(h + Vector3(0.0, 1.03, -0.85), 0.08, 4, 8.0 if hx < 0 else -8.0)
	# central link / office between the hangars at the back
	var o := Vector3(0, Y0, -1.55)
	g.color(CON, Geo.CONCRETE)
	g.cbox(o + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5), 0.02)
	g.windows(o + Vector3(0, 0.42, 0.252), 0.4, 0.1, 3)
	U._ac_unit(g, o + Vector3(0, 0.6, 0))
	g.color(EU_S, Geo.STEEL)
	g.tube(o + Vector3(0.12, 0.6, -0.12), o + Vector3(0.12, 1.2, -0.12), 0.012, 4)   # antenna
	g.tube(o + Vector3(-0.12, 0.6, -0.12), o + Vector3(-0.12, 0.95, -0.12), 0.008, 3)
	# apron: fuel island, wash rack, gantry hoist
	var f := Vector3(-1.35, Y0, 1.25)
	g.color(CON_D, Geo.CONCRETE)
	g.cbox(f + Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.55), 0.015)
	g.color("#b84a2e", Geo.PAINT)
	for z in [-0.14, 0.14]:
		g.cbox(f + Vector3(0, 0.17, z), Vector3(0.1, 0.22, 0.08), 0.01)
	g.color("#d9d6cb", Geo.PAINT)
	g.cbox(f + Vector3(0, 0.5, 0), Vector3(0.42, 0.04, 0.7), 0.01)
	g.color(EU_S, Geo.STEEL)
	for z in [-0.28, 0.28]:
		g.tube(f + Vector3(0, 0.06, z), f + Vector3(0, 0.48, z), 0.014, 4)
	g.color("#2a2a2a", Geo.RUBBER)
	g.tube(f + Vector3(0.05, 0.2, -0.14), f + Vector3(0.12, 0.06, -0.2), 0.006, 3)
	var w := Vector3(0.5, Y0, 1.45)
	g.color("#5a6a76", Geo.STEEL)
	g.grille(w + Vector3(0, 0.003, 0), 0.9, 0.36, 9)
	g.color(EU_S, Geo.STEEL)
	for x in [-0.48, 0.48]:
		g.tube(w + Vector3(x, 0, 0), w + Vector3(x, 0.55, 0), 0.016, 4)
	g.tube(w + Vector3(-0.48, 0.55, 0), w + Vector3(0.48, 0.55, 0), 0.016, 4)
	g.color("#6fa8d6", Geo.STEEL)
	for x in [-0.3, 0.0, 0.3]:
		g.box(w + Vector3(x, 0.52, 0), Vector3(0.04, 0.03, 0.04))
	# gantry hoist over the right hangar door
	g.color("#d8a531", Geo.PAINT)
	for x in [1.72, 0.08]:
		g.cbox(Vector3(x, Y0 + 0.55, 1.0), Vector3(0.07, 1.1, 0.07), 0.01)
	g.cbox(Vector3(0.9, Y0 + 1.1, 1.0), Vector3(1.72, 0.07, 0.09), 0.01)
	g.color(EU_S, Geo.STEEL)
	g.cbox(Vector3(1.2, Y0 + 1.03, 1.0), Vector3(0.1, 0.07, 0.12), 0.01)
	g.tube(Vector3(1.2, Y0 + 1.0, 1.0), Vector3(1.2, Y0 + 0.7, 1.0), 0.004, 3)
	g.box(Vector3(1.2, Y0 + 0.68, 1.0), Vector3(0.04, 0.04, 0.02))
	# stowage + lights
	U._crates(g, Vector3(1.55, Y0, -1.75), 4, 7)
	_drums(g, Vector3(-1.85, Y0, -1.8), 5, ["#4e6a8a", "#5d6650", "#4e6a8a"])
	_tyres(g, Vector3(-1.8, Y0, 0.45), 3)
	U._floodlight(g, Vector3(-1.9, Y0, 1.9), 0.85, 135.0)
	U._floodlight(g, Vector3(1.9, Y0, 1.9), 0.85, 225.0)

# ================================================================== EU Supply Hub
## Containerised depot: twin hopper silos with a conveyor tower, loading bay with a canopy,
## stacked shipping containers, dispatch office with a dish.
static func _eu_hub(g) -> void:
	for i in 2:
		var s := Vector3(-0.75 + i * 0.62, Y0, -0.7)
		var t := Transform3D(Basis.IDENTITY, s)
		g.color(EU_S, Geo.STEEL)
		for k in 4:
			var an := TAU * (float(k) + 0.5) / 4.0
			g.tube(s + Vector3(cos(an) * 0.24, 0, sin(an) * 0.24), s + Vector3(cos(an) * 0.22, 0.5, sin(an) * 0.22), 0.018, 4)
		g.color("#c9c9c0", Geo.CORR)
		g.lathe([[0.32, 0.04], [0.5, 0.28], [1.25, 0.28], [1.42, 0.06]], 16, t)
		g.color(EU_D, Geo.STEEL)
		for y in [0.62, 0.86, 1.1]:
			g.band(0.28, y, 0.025, 0.008, 16, t)
		g.color("#ffffff", Geo.TEAM)
		g.band(0.28, 0.98, 0.06, 0.004, 16, t)
		g.rail_ring(0.28, 1.36, 10, 0.08, t)
	# conveyor tower + inclined belt to the silo tops
	var ct := Vector3(0.45, Y0, -0.95)
	g.color(EU, Geo.PAINT)
	g.cbox(ct + Vector3(0, 0.75, 0), Vector3(0.3, 1.5, 0.3), 0.02)
	g.color(EU_D, Geo.CORR)
	g.cbox(ct + Vector3(0, 1.56, 0), Vector3(0.36, 0.14, 0.36), 0.02)
	g.windows(ct + Vector3(0, 1.2, 0.152), 0.22, 0.08, 2)
	g.color("#9a9b94", Geo.STEEL)
	g.tube(Vector3(-0.13, Y0 + 1.46, -0.7), ct + Vector3(-0.12, 1.5, 0.0), 0.05, 4)
	g.tube(ct + Vector3(0.0, 0.3, 0.16), ct + Vector3(0.0, 1.4, 0.16), 0.04, 4)
	# loading bay with a canopy over a truck lane
	var lb := Vector3(0.55, Y0, 0.55)
	g.color(CON, Geo.CONCRETE)
	g.cbox(lb + Vector3(0, 0.12, -0.15), Vector3(1.6, 0.24, 0.5), 0.02)
	g.color(EU_S, Geo.STEEL)
	for x in [-0.75, 0.0, 0.75]:
		g.tube(lb + Vector3(x, 0.24, 0.45), lb + Vector3(x, 0.78, 0.45), 0.018, 4)
	g.color(EU, Geo.CORR)
	g.rcbox(lb + Vector3(0, 0.8, 0.15), Vector3(1.7, 0.04, 0.8), 0.01, Vector3(-6, 0, 0))
	g.color("#ffd27a", Geo.LAMP)
	for x in [-0.4, 0.4]:
		g.box(lb + Vector3(x, 0.76, 0.3), Vector3(0.1, 0.02, 0.04))
	g.hazard(lb + Vector3(0, 0.2, 0.102), 1.5, 0.05, 14)
	# shipping containers
	var cols := ["#4e6a8a", "#a5553a", "#5d6650", "#c4a052"]
	var cp := [Vector3(-1.05, 0, 0.55), Vector3(-1.05, 0, 1.05), Vector3(-1.05, 0.28, 0.8), Vector3(-0.45, 0, 1.2)]
	for i in cp.size():
		var p: Vector3 = cp[i] + Vector3(0, Y0, 0)
		var l := Vector3(0.62, 0.26, 0.26) if i != 3 else Vector3(0.26, 0.26, 0.5)
		g.color(cols[i], Geo.CORR)
		g.cbox(p + Vector3(0, 0.13, 0), l, 0.01)
		g.color("#2e2f2c", Geo.STEEL)
		g.box(p + Vector3(l.x * 0.5 if i != 3 else 0, 0.13, 0 if i != 3 else l.z * 0.5), Vector3(0.01, 0.22, 0.2) if i != 3 else Vector3(0.2, 0.22, 0.01))
	# dispatch office with dish
	var o := Vector3(1.1, Y0, -0.35)
	g.color(EU_W, Geo.PAINT)
	g.cbox(o + Vector3(0, 0.22, 0), Vector3(0.5, 0.44, 0.44), 0.02)
	g.windows(o + Vector3(0, 0.28, 0.222), 0.38, 0.1, 3)
	g.color(EU_S, Geo.STEEL)
	g.tube(o + Vector3(0, 0.44, 0), o + Vector3(0, 0.6, 0), 0.015, 4)
	g.dish(o + Vector3(0, 0.62, 0), 0.13, 35.0, 0.6)
	U._lamp(g, Vector3(0.45, Y0 + 1.64, -0.95))
	U._floodlight(g, Vector3(1.38, Y0, 1.38), 0.7, 225.0)

# ================================================================== TPLA Chop Shop
## Junkyard vehicle works: corrugated lean-to sheds on timber posts with a car up on blocks,
## a lattice scrap crane with a hook, tyre stacks, scrap heaps, drums, sandbags, string lights.
static func _tp_chop_shop(g) -> void:
	# main shed: open front lean-to (built at 1.0 and scaled up to fill the yard)
	var shed := Transform3D(Basis.from_scale(Vector3(1.22, 1.25, 1.2)), Vector3(0.05, 0, -0.1))
	g.xf = shed
	var s := Vector3(-0.35, Y0 / 1.25, -0.6)
	g.color(MUD, Geo.CONCRETE)
	g.cbox(s + Vector3(0, 0.36, -0.68), Vector3(2.5, 0.72, 0.18), 0.03)   # back wall (block)
	g.cbox(s + Vector3(-1.2, 0.33, -0.1), Vector3(0.14, 0.66, 1.2), 0.03)
	g.color(WOODC, Geo.WOOD)
	for x in [-0.6, 0.0, 0.6, 1.2]:
		g.cbox(s + Vector3(x, 0.38, 0.5), Vector3(0.07, 0.76, 0.07), 0.01)
	g.box(s + Vector3(0, 0.77, 0.5), Vector3(2.5, 0.06, 0.08))
	g.color(RUST, Geo.CORR)
	g.rcbox(s + Vector3(0, 0.86, -0.1), Vector3(2.7, 0.03, 1.4), 0.008, Vector3(-9, 0, 0))
	g.color(RUST_D, Geo.CORR)   # mismatched patch sheets
	g.rcbox(s + Vector3(-0.7, 0.885, 0.1), Vector3(0.6, 0.02, 0.5), 0.005, Vector3(-9, 4, 0))
	g.color("#7d8270", Geo.CORR)
	g.rcbox(s + Vector3(0.6, 0.88, -0.3), Vector3(0.5, 0.02, 0.6), 0.005, Vector3(-9, -3, 0))
	# car on blocks inside
	var car := s + Vector3(-0.3, 0, 0.0)
	g.color("#3e3a35", Geo.CONCRETE)
	for p in [Vector3(-0.28, 0.05, -0.15), Vector3(0.28, 0.05, -0.15), Vector3(-0.28, 0.05, 0.15), Vector3(0.28, 0.05, 0.15)]:
		g.box(car + p, Vector3(0.08, 0.1, 0.08))
	g.color("#6c7a5a", Geo.PAINT)
	g.cbox(car + Vector3(0, 0.2, 0), Vector3(0.82, 0.16, 0.4), 0.04)
	g.cbox(car + Vector3(0.05, 0.33, 0), Vector3(0.42, 0.12, 0.36), 0.04)
	g.color("#2a3a46", Geo.GLASS)
	g.box(car + Vector3(0.05, 0.33, 0.185), Vector3(0.34, 0.08, 0.01))
	g.color("#2b2b2a", Geo.DARK)
	g.box(car + Vector3(-0.32, 0.29, 0), Vector3(0.18, 0.02, 0.36))   # hood up
	g.color("#ffe7a0", Geo.LAMP)   # work lamp + welding glow
	g.box(s + Vector3(0.3, 0.7, -0.1), Vector3(0.06, 0.03, 0.06))
	g.color("#bfe8ff", Geo.LAMP)
	g.box(car + Vector3(0.45, 0.12, 0.25), Vector3(0.03, 0.03, 0.03))
	# workbench + tool wall
	g.color(WOODC, Geo.WOOD)
	g.box(s + Vector3(0.75, 0.2, -0.45), Vector3(0.7, 0.04, 0.22))
	for x in [0.45, 1.05]:
		g.box(s + Vector3(x, 0.1, -0.45), Vector3(0.04, 0.2, 0.18))
	g.color("#5a5752", Geo.STEEL)
	g.box(s + Vector3(0.75, 0.48, -0.585), Vector3(0.7, 0.3, 0.01))
	_drums(g, s + Vector3(1.0, 0, 0.0), 3, [RUST, "#3d5a6e", RUST_D])
	g.xf = Transform3D.IDENTITY
	# scrap crane: lattice boom on a counterweighted base
	var cr := Vector3(1.45, Y0, 0.45)
	g.color(TP_S, Geo.STEEL)
	g.cbox(cr + Vector3(0, 0.1, 0), Vector3(0.36, 0.2, 0.36), 0.02)
	g.color("#c4932e", Geo.PAINT)
	g.cbox(cr + Vector3(0, 0.3, 0.05), Vector3(0.26, 0.2, 0.3), 0.02)
	g.lattice(cr + Vector3(0, 0.38, 0), 1.0, 0.07, 4)
	var tip := cr + Vector3(-0.8, 1.32, 0.35)
	g.color("#c4932e", Geo.PAINT)
	g.tube(cr + Vector3(0, 1.32, 0), tip, 0.03, 4)
	g.tube(cr + Vector3(0, 1.38, 0), cr + Vector3(0.3, 1.2, -0.1), 0.02, 4)
	g.color(TP_S, Geo.STEEL)
	g.cbox(cr + Vector3(0.32, 1.15, -0.1), Vector3(0.14, 0.14, 0.14), 0.02)   # counterweight
	g.tube(tip, tip + Vector3(0, -0.6, 0), 0.004, 3)
	g.box(tip + Vector3(0, -0.63, 0), Vector3(0.05, 0.05, 0.03))
	g.color("#7d8270", Geo.SCRAP)   # car body hanging off the hook
	g.rcbox(tip + Vector3(0, -0.78, 0), Vector3(0.34, 0.14, 0.2), 0.02, Vector3(8, 25, 12))
	# scrap heaps, tyres, sandbags, string lights
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for hp in [Vector3(-1.4, Y0, 1.3), Vector3(1.45, Y0, 1.5)]:
		for i in 9:
			var col: String = [RUST, RUST_D, "#7d8270", "#5a5752", "#9a8058"][rng.randi() % 5]
			g.color(col, Geo.SCRAP)
			g.rcbox(hp + Vector3(rng.randf_range(-0.25, 0.25), 0.04 + rng.randf() * 0.12, rng.randf_range(-0.18, 0.18)), Vector3(rng.randf_range(0.08, 0.24), rng.randf_range(0.04, 0.1), rng.randf_range(0.06, 0.18)), 0.01, Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 180), rng.randf_range(-25, 25)))
	_tyres(g, Vector3(-0.6, Y0, 1.45), 4)
	_tyres(g, Vector3(-0.38, Y0, 1.6), 2)
	_tyres(g, Vector3(0.95, Y0, 1.2), 1)
	for i in 5:
		g.sandbag(Vector3(-1.6, Y0 + 0.04 + (i / 3) * 0.07, 0.6 + (i % 3) * 0.24), 0.22, 90.0, SB)
	g.xf = shed
	g.color("#2e2c29", Geo.STEEL)
	g.tube(s + Vector3(-1.25, 0.82, 0.55), s + Vector3(1.25, 0.82, 0.55), 0.003, 3)
	for i in 8:
		g.color(["#ffd27a", "#ff7a5a", "#7affb0"][i % 3], Geo.LAMP)
		g.box(s + Vector3(-1.1 + i * 0.32, 0.79, 0.56), Vector3(0.025, 0.03, 0.025))
	# banner on the back wall in the team colour
	g.color("#ffffff", Geo.TEAM)
	g.box(s + Vector3(-0.2, 0.5, -0.585), Vector3(0.5, 0.26, 0.01))
	g.xf = Transform3D.IDENTITY
	U._lamp(g, cr + Vector3(0, 1.4, 0))
	# scrap-sheet perimeter fence on the back and left edges
	var fr := RandomNumberGenerator.new()
	fr.seed = 5
	for i in 7:
		for side in 2:
			var p := Vector3(-1.75 + i * 0.5, Y0, -1.9) if side == 0 else Vector3(-1.9, Y0, -1.75 + i * 0.5)
			if side == 1 and i > 4:
				continue
			g.color([RUST, RUST_D, "#7d8270", "#8f8a7e", "#5d6650"][fr.randi() % 5], Geo.CORR)
			var hh := fr.randf_range(0.3, 0.42)
			g.rcbox(p + Vector3(0, hh * 0.5, 0), Vector3(0.52, hh, 0.02) if side == 0 else Vector3(0.02, hh, 0.52), 0.004, Vector3(fr.randf_range(-4, 4), 0, fr.randf_range(-3, 3)))
			g.color(WOODC, Geo.WOOD)
			g.box(p + Vector3(-0.25 if side == 0 else 0, 0.22, 0 if side == 0 else -0.25), Vector3(0.04, 0.44, 0.04))
	# a half-built technical on the apron
	var tk := Vector3(0.55, Y0, 1.1)
	var tt := Transform3D(Basis(Vector3.UP, 0.5), tk)
	g.color("#c9b48a", Geo.PAINT)
	g.cbox(Vector3(0, 0.17, 0.12), Vector3(0.36, 0.14, 0.34), 0.03, tt)
	g.cbox(Vector3(0, 0.27, -0.05), Vector3(0.34, 0.16, 0.2), 0.04, tt)
	g.color("#2a3a46", Geo.GLASS)
	g.box(Vector3(0, 0.29, 0.052), Vector3(0.3, 0.1, 0.01), tt)
	g.color(RUST, Geo.SCRAP)
	g.cbox(Vector3(0, 0.15, -0.32), Vector3(0.36, 0.1, 0.32), 0.01, tt)
	g.color(TP_S, Geo.STEEL)
	g.tube(tt * Vector3(0, 0.2, -0.3), tt * Vector3(0, 0.38, -0.3), 0.02, 4)
	g.tube(tt * Vector3(0, 0.38, -0.3), tt * Vector3(0, 0.42, -0.05), 0.012, 4)
	g.color("#232322", Geo.RUBBER)
	for wp in [Vector3(-0.19, 0.07, 0.18), Vector3(0.19, 0.07, 0.18), Vector3(-0.19, 0.07, -0.3), Vector3(0.19, 0.07, -0.3)]:
		g.box(wp, Vector3(0.06, 0.14, 0.14), tt)

# ================================================================== TPLA Supply Stash
## Fortified dump: mud-brick hut with a tarp lean-to over crates, sandbag ring, drums,
## a container on blocks and a radio mast with the team flag.
static func _tp_stash(g) -> void:
	var h := Vector3(-0.55, Y0, -0.55)
	g.color(MUD, Geo.CONCRETE)
	g.cbox(h + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.8), 0.06)
	g.color(MUD_D, Geo.CONCRETE)
	g.cbox(h + Vector3(0, 0.63, 0), Vector3(0.96, 0.06, 0.86), 0.02)
	g.color(WOODC, Geo.WOOD)
	for x in [-0.3, -0.1, 0.1, 0.3]:   # roof beams poking out
		g.box(h + Vector3(x, 0.58, 0.45), Vector3(0.04, 0.04, 0.12))
	g.color("#2b2b2a", Geo.DARK)
	g.box(h + Vector3(0.15, 0.22, 0.402), Vector3(0.2, 0.36, 0.01))
	g.box(h + Vector3(-0.25, 0.38, 0.402), Vector3(0.12, 0.1, 0.01))
	g.color(WOODC, Geo.WOOD)
	g.box(h + Vector3(-0.25, 0.38, 0.41), Vector3(0.14, 0.012, 0.01))
	_drums(g, h + Vector3(0.25, 0.66, -0.2), 3, ["#3d5a6e", RUST, "#5d6650"])
	g.color("#2e2c29", Geo.STEEL)
	g.tube(h + Vector3(-0.3, 0.66, -0.25), h + Vector3(-0.3, 1.55, -0.25), 0.012, 4)
	g.tube(h + Vector3(-0.3, 1.0, -0.25), h + Vector3(-0.05, 0.66, -0.45), 0.003, 3)
	g.color("#ffffff", Geo.TEAM)
	g.rbox(h + Vector3(-0.17, 1.45, -0.25), Vector3(0.24, 0.14, 0.01), Vector3(0, -15, 0))
	# tarp lean-to over crates
	var tp := Vector3(0.55, Y0, -0.3)
	g.color(WOODC, Geo.WOOD)
	for p in [Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45), Vector3(0.45, 0, -0.45)]:
		g.tube(tp + p, tp + p + Vector3(0, 0.62 if p.z < 0 else 0.48, 0), 0.02, 4)
	g.color("#7c7a5a", Geo.CANVAS)
	g.rcbox(tp + Vector3(0, 0.57, 0), Vector3(1.04, 0.02, 1.04), 0.005, Vector3(-8, 0, 0))
	g.color("#6a684c", Geo.CANVAS)
	g.rcbox(tp + Vector3(0, 0.4, 0.52), Vector3(1.0, 0.24, 0.015), 0.004, Vector3(14, 0, 0))
	U._crates(g, tp + Vector3(-0.35, 0, -0.35), 6, 3)
	g.color("#5a6a4a", Geo.WOOD)
	g.rcbox(tp + Vector3(0.25, 0.1, 0.1), Vector3(0.3, 0.2, 0.4), 0.02, Vector3(0, 12, 0))
	# container on blocks, front left
	var ct := Vector3(-0.85, Y0, 0.75)
	g.color("#3e3a35", Geo.CONCRETE)
	for x in [-0.3, 0.3]:
		g.box(ct + Vector3(x, 0.03, 0), Vector3(0.1, 0.06, 0.3))
	g.color("#7a4a34", Geo.CORR)
	g.cbox(ct + Vector3(0, 0.2, 0), Vector3(0.8, 0.28, 0.3), 0.01)
	g.color("#9a8058", Geo.SCRAP)
	g.box(ct + Vector3(0.1, 0.2, 0.152), Vector3(0.3, 0.2, 0.01))
	g.color("#2e2c29", Geo.STEEL)
	g.box(ct + Vector3(0.401, 0.2, 0), Vector3(0.01, 0.24, 0.22))
	# sandbag ring (open to the front), drums, tyres
	for i in 30:
		var an := lerpf(-2.45, 2.45, float(i) / 29.0) - PI * 0.5
		var r := 1.3
		var p := Vector3(cos(an) * r, Y0 + 0.03, sin(an) * r)
		g.sandbag(p, 0.27, rad_to_deg(-an) + 90.0, SB)
		var an2 := an + 0.08
		g.sandbag(Vector3(cos(an2) * r, Y0 + 0.09, sin(an2) * r), 0.25, rad_to_deg(-an2) + 90.0, "#bfae86")
	_drums(g, Vector3(0.5, Y0, 0.75), 5, [RUST, "#3d5a6e", "#5d6650"])
	_tyres(g, Vector3(1.05, Y0, 0.55), 3)
	g.color("#5d6650", Geo.STEEL)
	g.jerrycan(Vector3(0.25, Y0, 0.95), 20.0)
	g.jerrycan(Vector3(0.35, Y0, 0.98), -10.0)
	g.color("#ffd27a", Geo.LAMP)
	g.box(h + Vector3(0.15, 0.48, 0.42), Vector3(0.04, 0.04, 0.03))
