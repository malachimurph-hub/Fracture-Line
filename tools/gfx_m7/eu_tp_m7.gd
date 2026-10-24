extends RefCounted
## M2.7 detail pass, EU Alliance + TPLA (tool-time only). Replaces the last flat-box views of
## key EU / TPLA structures with kit7 models (same node layout as the US pass, AO baked after).
## Original shapes; real-world equipment roles as loose inspiration only.
const K := preload("res://tools/gfx_m7/kit8.gd")
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
		"eu_gun_bunker": func() -> void: U._make("gun_bunker", Vector2(2, 2), 0.9, _eu_bunker, _eu_bunker_turret, Vector3(0, 0.5, 0.05), "eu"),
		"tpla_bazaar": func() -> void: U._make("bazaar", Vector2(3, 3), 1.5, _tp_bazaar, Callable(), Vector3.ZERO, "tpla", _tp_found),
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

# ================================================================== EU (Germany) Power Plant
## M3.0 E: gas-turbine plant (was the M2.7 tokamak); cooling tower, annex, pipes, switchyard.
static func _eu_reactor(g) -> void:
	# M3.0 E (Germany): gas-turbine power plant. Turbine hall with a low gable roof and a window
	# band, two heat-recovery boiler blocks on the roof, each with a tall banded exhaust stack.
	var c := Vector3(0.3, Y0, 0.25)
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.03, 0), Vector3(1.5, 0.06, 1.3), 0.02)   # plinth
	g.color(EU, Geo.PAINT)
	g.cbox(c + Vector3(0, 0.36, 0), Vector3(1.36, 0.6, 1.14), 0.03)   # turbine hall
	g.color(EU_D, Geo.CORR)
	g.prism_x([Vector2(-0.58, 0.66), Vector2(0.58, 0.66), Vector2(0.0, 0.82)], -0.69, 0.69, Transform3D(Basis.IDENTITY, c))   # gable roof
	g.windows(c + Vector3(0, 0.5, 0.572), 1.1, 0.1, 9)
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0, 0.3, 0.573), Vector3(1.2, 0.04, 0.006))
	g.color("#2b2d2c", Geo.DARK)
	g.rollup(c + Vector3(-0.35, 0.2, 0.573), 0.34, 0.3)
	for k in 2:
		var bx := c + Vector3(-0.32 + k * 0.62, 0.0, -0.15)
		g.color(EU_W, Geo.PAINT)
		g.cbox(bx + Vector3(0, 0.98, 0), Vector3(0.34, 0.34, 0.5), 0.02)   # heat-recovery boiler
		g.color(EU_S, Geo.STEEL)
		g.lathe([[0.0, 0.11], [0.95, 0.1], [0.97, 0.12], [1.0, 0.12]], 12, Transform3D(Basis.IDENTITY, bx + Vector3(0, 1.15, -0.08)))   # exhaust stack
		g.color("#ffffff", Geo.TEAM)
		g.band(0.105, 1.85, 0.06, 0.006, 12, Transform3D(Basis.IDENTITY, bx + Vector3(0, 0.0, -0.08)))
		U._lamp(g, bx + Vector3(0, 2.16, -0.08))
		g.color(EU_S, Geo.STEEL)
		g.rail_ring(0.13, 2.0, 10, 0.08, Transform3D(Basis.IDENTITY, bx + Vector3(0, 0, -0.08)))
	g.color(EU_S, Geo.STEEL)
	g.ladder(c + Vector3(0.69, 0.06, 0.2), 0.62, Vector3.RIGHT)
	for z in [-0.25, 0.05, 0.35]:
		g.box(c + Vector3(-0.69, 0.4, z), Vector3(0.03, 0.12, 0.16))   # intake filter housings
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

# ================================================================== vehicles
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const GLASS_C := "#2a3a46"

static func vjobs() -> Dictionary:
	return {
		"eu_harvester": func() -> void: _eu_harvester(),
		"eu_crawler": func() -> void: _eu_crawler(),
		"eu_salamander": func() -> void: _eu_salamander(),
		"tpla_mule": func() -> void: _tp_mule(),
		"tpla_blight": func() -> void: _tp_blight(),
	}

## Truck cab (forward +z) with windscreen, grille, bumper, mirrors and lamps.
static func _cab(h, z: float, w: float, hgt: float, l: float, y0: float, col: String, col_d: String) -> void:
	h.color(col, Geo.PAINT)
	h.cbox(Vector3(0, y0 + hgt * 0.5, z), Vector3(w, hgt, l), 0.045)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, y0 + hgt * 0.72, z + l * 0.5 + 0.005), Vector3(w * 0.84, hgt * 0.32, 0.015), Vector3(-10, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * (w * 0.5 + 0.004), y0 + hgt * 0.72, z + l * 0.12), Vector3(0.012, hgt * 0.28, l * 0.5))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, y0 + hgt * 0.3, z + l * 0.5 + 0.01), w * 0.6, 0.02, 6)
	h.vent(Vector3(0, y0 + hgt * 0.28, z + l * 0.5 + 0.012), w * 0.55, hgt * 0.26, 5)
	h.color(col_d, Geo.STEEL)
	h.cbox(Vector3(0, y0 + 0.04, z + l * 0.5 + 0.04), Vector3(w + 0.04, 0.06, 0.06), 0.01)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * w * 0.5, y0 + hgt * 0.62, z + l * 0.35), Vector3(s * (w * 0.5 + 0.07), y0 + hgt * 0.7, z + l * 0.3), 0.006, 3)
		h.cbox(Vector3(s * (w * 0.5 + 0.075), y0 + hgt * 0.72, z + l * 0.3), Vector3(0.02, 0.06, 0.035), 0.004)
	V4._lamps(h, w * 0.38, y0 + hgt * 0.32, z + l * 0.5 + 0.01)

# ------------------------------------------------------------------ EU Harvester (6x6 hauler)
static func _eu_harvester() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.25, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._wheelset(h, 0.42, [0.58, -0.3, -0.66], 0.16, 0.14, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.32, -0.05), Vector3(0.52, 0.09, 1.7), 0.01)
	_cab(h, 0.62, 0.78, 0.5, 0.42, 0.3, EU_W, EU_S)
	h.color(EU, Geo.PAINT)
	h.cbox(Vector3(0, 0.84, 0.56), Vector3(0.7, 0.05, 0.3), 0.012)   # roof sunshade
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.392, 0.5, 0.62), Vector3(0.006, 0.06, 0.34))
	# hopper body: tapered bin with ribs, ore heap, tailgate, side ladder
	h.color(EU, Geo.PAINT)
	h.plan_loft([Vector2(-0.4, -0.95), Vector2(0.4, -0.95), Vector2(0.4, 0.34), Vector2(-0.4, 0.34)], 0.38, 0.78, Vector2(1.08, 1.0))
	h.color(EU_D, Geo.STEEL)
	for z in [-0.75, -0.45, -0.15, 0.15]:
		for s in [-1.0, 1.0]:
			h.box(Vector3(s * 0.425, 0.58, z), Vector3(0.03, 0.38, 0.04))
	h.cbox(Vector3(0, 0.6, -0.97), Vector3(0.84, 0.4, 0.04), 0.008)
	h.color("#6fd3ff", Geo.LAMP)   # veridite load glinting in the bin
	h.color("#7d7a6c", Geo.CONCRETE)
	h.cbox(Vector3(0, 0.8, -0.3), Vector3(0.7, 0.06, 1.1), 0.03)
	h.color("#5ad1c4", Geo.LAMP)
	for p in [Vector3(-0.15, 0.85, -0.5), Vector3(0.12, 0.85, -0.1), Vector3(0.2, 0.84, -0.65), Vector3(-0.2, 0.84, 0.05)]:
		h.rcbox(p, Vector3(0.06, 0.1, 0.06), 0.012, Vector3(15, 30, -10))
	h.color(EU_S, Geo.STEEL)
	h.ladder(Vector3(0.45, 0.32, 0.25), 0.48, Vector3.BACK, 0.06)
	h.tube(Vector3(-0.3, 0.6, 0.38), Vector3(-0.3, 1.02, 0.38), 0.025, 6)   # exhaust stack
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.36, 0.36]:
		h.box(Vector3(x, 0.4, -0.98), Vector3(0.06, 0.03, 0.01))
	h.color("#ffb347", Geo.LAMP)
	h.cbox(Vector3(0.24, 0.88, 0.62), Vector3(0.05, 0.04, 0.05), 0.01)   # amber beacon
	# loader crane folded over the cab side
	h.color("#d8a531", Geo.PAINT)
	h.cbox(Vector3(0.3, 0.86, 0.34), Vector3(0.1, 0.1, 0.1), 0.01)
	h.tube(Vector3(0.3, 0.9, 0.34), Vector3(0.3, 0.98, -0.5), 0.022, 6)
	h.tube(Vector3(0.3, 0.98, -0.5), Vector3(0.28, 0.86, -0.75), 0.018, 6)
	V4._antenna(h, Vector3(-0.32, 0.82, 0.48), 0.35)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(-0.15, 0.82, 0.6))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.07, 0.07, 0.03, 10, Transform3D.IDENTITY)
	U._mg(t, Vector3(0, 0.1, 0), 0.0, 0.22)
	t.color(EU, Geo.PAINT)
	t.rbox(Vector3(0, 0.1, 0.06), Vector3(0.16, 0.08, 0.012), Vector3(-10, 0, 0))   # gun shield
	VK._mi(piv, root, "Turret", t.commit(mat))
	U._vfinish(root, model, h, mat, "harvester", [t], 1.25, "eu")

# ------------------------------------------------------------------ EU Crawler (tracked engineer)
static func _eu_crawler() -> void:
	# M3.1: European mobile site crane: 4-axle all-terrain carrier, low cab up front, slewing
	# superstructure with operator cab + counterweight, telescopic boom laid forward over the
	# carrier, hook block, outrigger beams and pads. Role and stats unchanged (builder).
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0, "steer_max": 0.3})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var V8 = load("res://tools/gfx_m7/us_v8.gd")
	const CY := "#e0b021"      # crane yellow
	const CY_D := "#b88a1a"
	const CAR := "#3d4245"     # carrier chassis
	V8._tyres(h, 0.4, [0.62, 0.3, -0.2, -0.52], 0.135, 0.12, 2, EU_S)
	# carrier: ladder chassis, fenders over each axle, deck
	h.color(CAR, Geo.STEEL)
	h.cbox(Vector3(0, 0.2, 0.0), Vector3(0.42, 0.1, 1.72), 0.012)
	h.color(EU, Geo.PAINT)
	h.xloft([[0.86, K.sect(0.24, 0.26, 0.36, 0.44, 0.47, 0.46, 0.015)], [-0.82, K.sect(0.24, 0.26, 0.36, 0.44, 0.47, 0.46, 0.015)], [-0.88, K.sect(0.24, 0.27, 0.34, 0.42, 0.45, 0.44, 0.012)]])
	h.plain = true   # crane livery (yellow / white / red-white) is exempt from the faction camo
	for s in [-1.0, 1.0]:
		for z in [0.62, 0.3, -0.2, -0.52]:
			h.color(EU_D, Geo.PAINT)
			h.prism_x([Vector2(z - 0.17, 0.34), Vector2(z + 0.17, 0.34), Vector2(z + 0.13, 0.38), Vector2(z - 0.13, 0.38)], s * 0.3, s * 0.49)
		h.color("#e4e0d6", Geo.PAINT)
		for k in 6:   # red/white hazard chevrons on the deck edge
			h.color("#c23a2a" if k % 2 == 0 else "#e4e0d6", Geo.PAINT)
			h.box(Vector3(s * 0.475, 0.31, -0.8 + k * 0.06), Vector3(0.006, 0.05, 0.055))
		# outrigger beams (stowed) + jack pads
		h.color(CY_D, Geo.PAINT)
		for z in [0.47, -0.7]:
			h.cbox(Vector3(s * 0.43, 0.27, z), Vector3(0.12, 0.07, 0.09), 0.008)
			h.color(EU_S, Geo.STEEL)
			h.tube(Vector3(s * 0.5, 0.25, z), Vector3(s * 0.5, 0.12, z), 0.022, 6)
			h.ccyl(0.05, 0.02, 0.005, 10, Transform3D(Basis.IDENTITY, Vector3(s * 0.5, 0.1, z)))
			h.color(CY_D, Geo.PAINT)
	# driver cab: low, offset left, sloped glazing, roof beacon
	h.color(EU_W, Geo.PAINT)
	var c0 := K.sect(0.36, 0.4, 0.66, 0.15, 0.15, 0.13, 0.025)
	h.xloft([[0.92, c0], [0.62, K.sect(0.36, 0.4, 0.68, 0.15, 0.15, 0.14, 0.025)]], Transform3D(Basis.IDENTITY, Vector3(-0.27, 0, 0)))
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(-0.27, 0.56, 0.925), Vector3(0.26, 0.15, 0.01), Vector3(-12, 0, 0))
	h.box(Vector3(-0.425, 0.56, 0.78), Vector3(0.01, 0.14, 0.22))
	h.color("#ffb347", Geo.LAMP)
	h.cbox(Vector3(-0.27, 0.7, 0.75), Vector3(0.05, 0.04, 0.05), 0.01)
	V4._lamps(h, 0.3, 0.34, 0.9)
	# engine box right of the cab, exhaust stack
	h.color(EU, Geo.PAINT)
	h.cbox(Vector3(0.2, 0.45, 0.72), Vector3(0.36, 0.18, 0.34), 0.02)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0.2, 0.545, 0.72), 0.28, 0.24, 6)
	h.color(EU_S, Geo.STEEL)
	h.tube(Vector3(0.38, 0.45, 0.58), Vector3(0.38, 0.7, 0.58), 0.02, 6)
	# superstructure: slewing ring, yellow deck house, operator cab (left), counterweight slabs
	h.color(EU_S, Geo.STEEL)
	h.cyl(0.26, 0.26, 0.05, 18, Transform3D(Basis.IDENTITY, Vector3(0, 0.385, -0.42)))
	h.color(CY, Geo.PAINT)
	h.cbox(Vector3(0.06, 0.52, -0.46), Vector3(0.6, 0.22, 0.6), 0.03)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0.364, 0.52, -0.5), 0.3, 0.12, 4, 90.0)
	h.color(EU_W, Geo.PAINT)
	h.cbox(Vector3(-0.32, 0.6, -0.26), Vector3(0.18, 0.28, 0.28), 0.02)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(-0.32, 0.64, -0.115), Vector3(0.15, 0.2, 0.01), Vector3(-8, 0, 0))
	h.box(Vector3(-0.415, 0.62, -0.26), Vector3(0.01, 0.2, 0.22))
	h.color(CY_D, Geo.PAINT)
	for k in 3:
		h.cbox(Vector3(0.06, 0.45 + k * 0.075, -0.82), Vector3(0.56, 0.065, 0.14), 0.01)   # counterweight
	h.color("#c23a2a", Geo.PAINT)
	h.box(Vector3(0.06, 0.53, -0.895), Vector3(0.5, 0.04, 0.006))
	# telescopic boom: 3 sections, laid forward over the cab on a boom rest; luffing ram
	var bt := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-4.0)), Vector3(0.1, 0.7, -0.55))
	h.color(CY, Geo.PAINT)
	h.xloft([[0.0, K.sect(-0.07, -0.06, 0.07, 0.09, 0.1, 0.08, 0.02)], [0.7, K.sect(-0.065, -0.055, 0.065, 0.085, 0.09, 0.075, 0.02)]], bt)
	h.color(CY_D, Geo.PAINT)
	h.xloft([[0.7, K.sect(-0.055, -0.045, 0.055, 0.07, 0.075, 0.06, 0.016)], [1.18, K.sect(-0.05, -0.04, 0.05, 0.065, 0.07, 0.055, 0.016)]], bt)
	h.color(CY, Geo.PAINT)
	h.xloft([[1.18, K.sect(-0.045, -0.035, 0.045, 0.055, 0.06, 0.045, 0.012)], [1.5, K.sect(-0.04, -0.032, 0.04, 0.05, 0.055, 0.042, 0.012)]], bt)
	h.color(EU_S, Geo.STEEL)
	h.tube(bt * Vector3(0, 0.0, 1.5), bt * Vector3(0, -0.03, 1.56), 0.05, 10)   # boom head sheaves
	h.tube(bt * Vector3(0, -0.05, 1.56), Vector3(0.1, 0.42, 1.0), 0.004, 3)    # hook rope
	h.color(CY_D, Geo.PAINT)
	h.cbox(Vector3(0.1, 0.4, 1.0), Vector3(0.07, 0.07, 0.04), 0.008)               # hook block (stowed at the bumper)
	h.color(EU_S, Geo.STEEL)
	h.tube(Vector3(0.1, 0.36, 1.0), Vector3(0.1, 0.33, 1.02), 0.012, 6)
	h.tube(Vector3(0.1, 0.44, -0.3), bt * Vector3(0, -0.07, 0.35), 0.035, 8)       # luffing ram
	h.cbox(Vector3(0.1, 0.62, 0.52), Vector3(0.12, 0.05, 0.06), 0.008)              # boom rest
	h.tube(Vector3(0.1, 0.36, 0.52), Vector3(0.1, 0.6, 0.52), 0.016, 6)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.472, 0.33, 0.1), Vector3(0.006, 0.035, 0.8))
		h.box(Vector3(0.06 + s * 0.302, 0.5, -0.46), Vector3(0.006, 0.05, 0.4))
	h.color("#ffb347", Geo.LAMP)
	h.cbox(Vector3(-0.32, 0.755, -0.26), Vector3(0.04, 0.03, 0.04), 0.008)
	V4._antenna(h, Vector3(-0.38, 0.7, 0.66), 0.3)
	U._vfinish(root, model, h, mat, "crawler", [], 1.2, "eu")

# ------------------------------------------------------------------ EU Salamander (flame tank)
static func _eu_salamander() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.3, "recoil": 0.0, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._tracks(h, 0.48, 1.7, 6, 0.09, EU_D, EU_S, 0.24)
	h.color(EU_D, Geo.PAINT)
	h.prism_x([Vector2(-0.82, 0.14), Vector2(0.62, 0.14), Vector2(0.86, 0.3), Vector2(0.84, 0.36), Vector2(-0.84, 0.38), Vector2(-0.86, 0.2)], -0.36, 0.36)
	h.color(EU, Geo.PAINT)
	# M2.7b: chamfered upper hull with a long glacis, raked skirts with a lower lip
	h.xloft([[0.87, K.sect(0.35, 0.36, 0.39, 0.54, 0.57, 0.55, 0.012)], [0.5, K.sect(0.35, 0.38, 0.465, 0.58, 0.6, 0.58, 0.03)],
		[-0.8, K.sect(0.35, 0.38, 0.475, 0.58, 0.6, 0.58, 0.03)], [-0.88, K.sect(0.35, 0.37, 0.43, 0.56, 0.58, 0.56, 0.02)]])
	for s in [-1.0, 1.0]:   # side skirts with EU shield emitters
		for i in 5:
			h.color(EU if i % 2 == 0 else "#7b846a", Geo.PAINT)
			h.plate(Vector3(s * 0.625, 0.31, -0.66 + i * 0.32), Vector3(0.035, 0.14, 0.31), Vector3(0, 0, -s * 6.0))
			h.plate(Vector3(s * 0.615, 0.225, -0.66 + i * 0.32), Vector3(0.03, 0.045, 0.31), Vector3(0, 0, s * 28.0))
		h.color("#6fe3ff", Geo.TEAM_LAMP)
		h.box(Vector3(s * 0.645, 0.33, 0.0), Vector3(0.01, 0.04, 0.12))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.473, -0.62), 0.6, 0.3, 8)
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(-0.2, 0.44, 0.55), 0.13)
	# armoured napalm tanks on the rear deck with pipework to the turret ring
	for s in [-0.3, 0.3]:
		h.plain = true
		h.color("#a0573a", Geo.PAINT)
		h.tube(Vector3(s, 0.6, -0.78), Vector3(s, 0.6, -0.2), 0.13, 12)
		h.color(EU_D, Geo.STEEL)
		for z in [-0.68, -0.3]:
			h.tube(Vector3(s, 0.6, z), Vector3(s, 0.6, z + 0.04), 0.137, 12)
		h.color("#d8a531", Geo.PAINT)
		h.tube(Vector3(s, 0.6, -0.5), Vector3(s, 0.6, -0.46), 0.138, 12)
		h.plain = false
		h.color(EU_S, Geo.STEEL)
		h.pipe([Vector3(s, 0.6, -0.18), Vector3(s * 0.6, 0.5, 0.05), Vector3(s * 0.3, 0.48, 0.15)], 0.02, 6)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.605, 0.605]:
		h.box(Vector3(s, 0.43, 0.0), Vector3(0.006, 0.03, 1.1))
	V4._lamps(h, 0.45, 0.38, 0.86)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.42, 0.3))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.26, 0.26, 0.04, 14, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.24, -0.3), Vector2(0.24, -0.3), Vector2(0.28, 0.0), Vector2(0.16, 0.24), Vector2(-0.16, 0.24), Vector2(-0.28, 0.0)], 0.03, 0.18, Vector2(0.86, 0.88))
	t.color(EU_D, Geo.PAINT)
	t.hatch(Vector3(0.08, 0.18, -0.1), 0.12)
	t.color(GLASS_C, Geo.GLASS)
	for x in [-0.12, -0.05]:
		t.box(Vector3(x, 0.19, 0.08), Vector3(0.04, 0.02, 0.03))
	t.color(EU_S, Geo.STEEL)
	t.pipe([Vector3(0.2, 0.08, -0.2), Vector3(0.22, 0.1, 0.1), Vector3(0.1, 0.1, 0.22)], 0.018, 6)
	V4._antenna(t, Vector3(-0.15, 0.18, -0.22), 0.4)
	U._smoke(t, Vector3(0.26, 0.12, 0.05), 50.0)
	U._smoke(t, Vector3(-0.26, 0.12, 0.05), -50.0)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U._barrel(piv, root, mat, Vector3(0, 0.08, 0.16), func(b) -> void:
		b.color(EU_D, Geo.PAINT)
		b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 0.14), 0.07, 10)
		b.color(EU_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 0.1), Vector3(0, 0, 0.5), 0.035, 10)
		b.tube(Vector3(0, 0, 0.44), Vector3(0, 0, 0.52), 0.05, 10)
		b.tube(Vector3(0, -0.05, 0.12), Vector3(0, -0.05, 0.4), 0.012, 4)
		b.color("#ff9a3a", Geo.LAMP)   # pilot light
		b.box(Vector3(0, -0.05, 0.42), Vector3(0.02, 0.02, 0.02)))
	U._vfinish(root, model, h, mat, "salamander", [t, b], 1.3, "eu")

# ------------------------------------------------------------------ TPLA Mule (truck bomb)
static func _tp_mule() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.37, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._wheelset(h, 0.4, [0.56, -0.38, -0.66], 0.15, 0.13, 1, TP_S)
	h.color(TP_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.3, -0.05), Vector3(0.5, 0.08, 1.62), 0.01)
	# rounded old-style cab with long bonnet, rusted panels
	h.color("#6f7d6a", Geo.PAINT)
	h.cbox(Vector3(0, 0.6, 0.38), Vector3(0.7, 0.44, 0.4), 0.07)
	h.prism_x([Vector2(0.58, 0.3), Vector2(0.92, 0.32), Vector2(0.92, 0.5), Vector2(0.58, 0.56)], -0.27, 0.27)
	h.color(RUST, Geo.SCRAP)
	h.box(Vector3(0.18, 0.5, 0.584), Vector3(0.2, 0.12, 0.01))
	h.box(Vector3(-0.351, 0.48, 0.3), Vector3(0.01, 0.16, 0.22))
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, 0.72, 0.585), Vector3(0.56, 0.15, 0.015), Vector3(-8, 0, 0))
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.42, 0.925), 0.4, 0.14, 5)
	h.color("#5d6650", Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.prism_x([Vector2(0.4, 0.34), Vector2(0.8, 0.34), Vector2(0.75, 0.43), Vector2(0.45, 0.43)], s * 0.28, s * 0.38)
	V4._lamps(h, 0.22, 0.44, 0.93)
	h.color(TP_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.33, 0.97), Vector3(0.66, 0.07, 0.05), 0.01)
	h.color(WOODC, Geo.WOOD)   # slat-sided cargo bed
	h.cbox(Vector3(0, 0.4, -0.45), Vector3(0.76, 0.06, 0.96), 0.01)
	for s in [-1.0, 1.0]:
		for y in [0.5, 0.62]:
			h.box(Vector3(s * 0.37, y, -0.45), Vector3(0.025, 0.06, 0.94))
		for z in [-0.9, -0.45, 0.0]:
			h.box(Vector3(s * 0.37, 0.55, z), Vector3(0.035, 0.24, 0.04))
	# the payload: gas cylinders, drums and wired charges under a torn tarp
	for i in 6:
		h.color(["#c8b14a", "#b33a2a", "#4e6a8a"][i % 3], Geo.STEEL)
		h.tube(Vector3(-0.22 + (i % 3) * 0.22, 0.45, -0.2 - (i / 3) * 0.3), Vector3(-0.22 + (i % 3) * 0.22, 0.75, -0.2 - (i / 3) * 0.3), 0.07, 8)
	h.color(RUST, Geo.STEEL)
	for i in 3:
		h.tube(Vector3(-0.2 + i * 0.2, 0.47, -0.82), Vector3(-0.2 + i * 0.2, 0.62, -0.82), 0.075, 8)
	h.color("#7c7a5a", Geo.CANVAS)
	h.rcbox(Vector3(0.1, 0.8, -0.35), Vector3(0.62, 0.02, 0.6), 0.005, Vector3(6, 0, -8))
	h.color("#d83a3a", Geo.STEEL)   # det wiring
	h.tube(Vector3(-0.22, 0.76, -0.2), Vector3(0.0, 0.8, -0.5), 0.005, 3)
	h.tube(Vector3(0.22, 0.76, -0.2), Vector3(0.0, 0.8, -0.5), 0.005, 3)
	h.tube(Vector3(0.0, 0.8, -0.5), Vector3(0.0, 0.82, 0.2), 0.005, 3)
	h.color("#ff3a2a", Geo.LAMP)
	h.box(Vector3(0.0, 0.82, -0.5), Vector3(0.06, 0.04, 0.05))
	h.color("#ffffff", Geo.TEAM)
	h.rbox(Vector3(0.2, 0.9, 0.38), Vector3(0.22, 0.13, 0.01), Vector3(0, -10, 0))   # flag on the cab
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(0.32, 0.82, 0.38), Vector3(0.32, 1.0, 0.38), 0.006, 3)
	h.color("#232322", Geo.RUBBER)
	h.tube(Vector3(-0.38, 0.62, 0.1), Vector3(-0.44, 0.62, 0.1), 0.11, 10)   # spare on the cab side
	U._vfinish(root, model, h, mat, "mule", [], 1.37, "tpla")

# ------------------------------------------------------------------ TPLA Blight (rust-shell mortar truck)
static func _tp_blight() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.38, "recoil": 0.12, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V4._wheelset(h, 0.38, [0.5, -0.45], 0.15, 0.13, 1, TP_S)
	h.color(TP_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.29, 0.0), Vector3(0.48, 0.07, 1.5), 0.01)
	# pickup cab, roll bar, open bed with stabiliser jacks
	h.color("#b9a67c", Geo.PAINT)
	h.cbox(Vector3(0, 0.44, 0.55), Vector3(0.68, 0.18, 0.5), 0.03)
	h.cbox(Vector3(0, 0.62, 0.32), Vector3(0.64, 0.2, 0.36), 0.05)
	h.color(GLASS_C, Geo.GLASS)
	h.rbox(Vector3(0, 0.63, 0.505), Vector3(0.54, 0.14, 0.015), Vector3(-25, 0, 0))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.45, 0.805), 0.4, 0.02, 6)
	h.color(RUST, Geo.SCRAP)
	h.box(Vector3(-0.2, 0.535, 0.62), Vector3(0.18, 0.01, 0.2))
	V4._lamps(h, 0.24, 0.45, 0.8)
	h.color(TP_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.36, 0.83), Vector3(0.72, 0.07, 0.06), 0.01)
	h.color("#a8956c", Geo.PAINT)
	h.cbox(Vector3(0, 0.38, -0.35), Vector3(0.7, 0.05, 0.8), 0.01)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.34, 0.47, -0.35), Vector3(0.03, 0.14, 0.8), 0.006)
		h.color(TP_S, Geo.STEEL)
		h.tube(Vector3(s * 0.38, 0.38, -0.66), Vector3(s * 0.48, 0.05, -0.7), 0.025, 4)   # jacks
		h.box(Vector3(s * 0.48, 0.02, -0.7), Vector3(0.1, 0.02, 0.1))
		h.tube(Vector3(s * 0.3, 0.5, 0.12), Vector3(s * 0.3, 0.8, 0.12), 0.014, 4)   # roll bar
		h.color("#a8956c", Geo.PAINT)
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(-0.3, 0.8, 0.12), Vector3(0.3, 0.8, 0.12), 0.014, 4)
	h.color("#ffd27a", Geo.LAMP)
	for x in [-0.15, 0.15]:
		h.box(Vector3(x, 0.82, 0.13), Vector3(0.06, 0.04, 0.03))
	# rust-shell ammo: corroded canisters in a rack, green seep
	for i in 4:
		h.color(RUST_D, Geo.SCRAP)
		h.tube(Vector3(-0.25 + i * 0.07, 0.42, -0.7), Vector3(-0.25 + i * 0.07, 0.58, -0.7), 0.03, 6)
	h.color("#9fbf3a", Geo.LAMP)
	h.box(Vector3(-0.15, 0.6, -0.7), Vector3(0.2, 0.01, 0.04))
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.356, 0.356]:
		h.box(Vector3(s, 0.47, -0.35), Vector3(0.006, 0.05, 0.6))
	_tyres(h, Vector3(0.22, 0.4, -0.66), 1)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.42, -0.3))
	var t = K.new()
	t.color(TP_S, Geo.STEEL)
	t.cyl(0.2, 0.22, 0.05, 12, Transform3D.IDENTITY)   # turntable
	t.color(RUST, Geo.SCRAP)
	for s in [-1.0, 1.0]:
		t.cbox(Vector3(s * 0.12, 0.13, 0.0), Vector3(0.04, 0.18, 0.18), 0.01)   # trunnion cheeks
	t.color("#c4932e", Geo.PAINT)
	t.cbox(Vector3(0.16, 0.14, -0.12), Vector3(0.08, 0.1, 0.1), 0.01)   # elevation wheel box
	t.color(TP_S, Geo.STEEL)
	t.tube(Vector3(0.21, 0.14, -0.12), Vector3(0.24, 0.14, -0.12), 0.04, 8)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U._barrel(piv, root, mat, Vector3(0, 0.18, 0.0), func(b) -> void:
		var bt := Transform3D(Basis(Vector3.RIGHT, -0.85), Vector3.ZERO)
		b.color(TP_S, Geo.STEEL)
		b.tube(bt * Vector3(0, 0, -0.18), bt * Vector3(0, 0, 0.6), 0.06, 10, 0.055)
		b.color(RUST, Geo.SCRAP)
		b.tube(bt * Vector3(0, 0, -0.2), bt * Vector3(0, 0, -0.08), 0.08, 10)   # breech
		b.tube(bt * Vector3(0, 0, 0.3), bt * Vector3(0, 0, 0.36), 0.068, 10)
		b.color(TP_S, Geo.STEEL)
		b.tube(bt * Vector3(0, 0, 0.56), bt * Vector3(0, 0, 0.62), 0.07, 10))
	U._vfinish(root, model, h, mat, "blight", [t, b], 1.38, "tpla")


# ================================================================== EU Gun Bunker
## Low chamfered casemate with a sloped concrete glacis, sandbag apron, periscope and vents;
## the turret is an armoured cupola with a twin-barrel cannon.
static func _eu_bunker(g) -> void:
	g.color(CON, Geo.CONCRETE)
	g.plan_loft([Vector2(-0.82, -0.7), Vector2(0.82, -0.7), Vector2(0.9, 0.5), Vector2(0.55, 0.85), Vector2(-0.55, 0.85), Vector2(-0.9, 0.5)], Y0, Y0 + 0.42, Vector2(0.86, 0.84), Vector2(0, -0.02))
	g.color(CON_D, Geo.CONCRETE)
	g.plan_loft([Vector2(-0.62, -0.55), Vector2(0.62, -0.55), Vector2(0.68, 0.38), Vector2(0.4, 0.62), Vector2(-0.4, 0.62), Vector2(-0.68, 0.38)], Y0 + 0.42, Y0 + 0.47, Vector2(0.97, 0.97))
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3(0, Y0 + 0.25, 0.79), Vector3(0.5, 0.06, 0.02))   # firing slit
	for x in [-0.6, 0.6]:
		g.vent(Vector3(x, Y0 + 0.2, -0.705), 0.22, 0.1, 4, 180)
	g.color(EU_S, Geo.STEEL)
	g.box(Vector3(0, Y0 + 0.22, -0.72), Vector3(0.26, 0.3, 0.02))   # rear blast door
	g.ladder(Vector3(0.35, Y0, -0.72), 0.42, Vector3.RIGHT, 0.06)
	g.tube(Vector3(-0.45, Y0 + 0.47, -0.3), Vector3(-0.45, Y0 + 0.62, -0.3), 0.02, 6)   # periscope
	g.cbox(Vector3(-0.45, Y0 + 0.64, -0.29), Vector3(0.05, 0.04, 0.07), 0.008)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.36, 0.745), Vector3(0.9, 0.04, 0.01))
	for i in 9:
		var x := -0.85 + i * 0.21
		g.sandbag(Vector3(x, Y0 + 0.03, 0.98), 0.22, 0.0, "#c2b08a")
		if i % 2 == 0:
			g.sandbag(Vector3(x + 0.1, Y0 + 0.09, 0.98), 0.2, 0.0, "#b5a47e")
	U._lamp(g, Vector3(0.5, Y0 + 0.5, -0.4))
	V4._antenna(g, Vector3(0.55, Y0 + 0.47, -0.45), 0.45)

static func _eu_bunker_turret(t) -> void:
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.38, 0.38, 0.05, 16, Transform3D.IDENTITY)
	t.color(EU, Geo.PAINT)
	t.lathe([[0.05, 0.36], [0.16, 0.34], [0.24, 0.27], [0.3, 0.12], [0.31, 0.0]], 16, Transform3D.IDENTITY, false, false)
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.15, 0.32), Vector3(0.3, 0.16, 0.12), 0.02)   # mantlet
	t.color(EU_S, Geo.STEEL)
	for x in [-0.07, 0.07]:
		t.tube(Vector3(x, 0.15, 0.36), Vector3(x, 0.15, 0.85), 0.028, 8)
		t.tube(Vector3(x, 0.15, 0.78), Vector3(x, 0.15, 0.87), 0.038, 8)
	t.hatch(Vector3(-0.1, 0.27, -0.08), 0.12)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.14, 0.25, 0.14), Vector3(0.08, 0.03, 0.03))
	t.color("#ffffff", Geo.TEAM)
	t.band(0.345, 0.1, 0.035, 0.01, 16, Transform3D.IDENTITY)
	U._smoke(t, Vector3(0.3, 0.12, 0.0), 80.0)
	U._smoke(t, Vector3(-0.3, 0.12, 0.0), -80.0)

# ================================================================== TPLA Night Bazaar
## Market court: canvas-roofed stalls around a well, string lights, a tea-house with a
## rooftop water tank, carpets, crates, sacks and a generator.
static func _tp_bazaar(g) -> void:
	var cols := ["#b33a2a", "#c4932e", "#3d6e8a", "#6e8a3d", "#8a3d6e"]
	var stalls := [Vector3(-0.9, 0, -0.95), Vector3(0.0, 0, -1.0), Vector3(0.9, 0, -0.95), Vector3(-1.05, 0, 0.1), Vector3(1.05, 0, 0.15)]
	for i in stalls.size():
		var c: Vector3 = stalls[i] + Vector3(0, Y0, 0)
		var side := i >= 3
		var sz := Vector3(0.6, 0, 0.5) if not side else Vector3(0.5, 0, 0.6)
		g.color(WOODC, Geo.WOOD)
		for px in [-1.0, 1.0]:
			for pz in [-1.0, 1.0]:
				var hgt := 0.62 if (pz < 0 and not side) or (side and px * signf(c.x) > 0) else 0.52
				g.tube(c + Vector3(px * sz.x * 0.45, 0, pz * sz.z * 0.45), c + Vector3(px * sz.x * 0.45, hgt, pz * sz.z * 0.45), 0.015, 4)
		g.color(cols[i], Geo.CANVAS)
		g.rcbox(c + Vector3(0, 0.58, 0), Vector3(sz.x + 0.1, 0.02, sz.z + 0.1), 0.005, Vector3(-9, 0, 0) if not side else Vector3(0, 0, 9 * signf(c.x)))
		g.color("#e8dcc0", Geo.CANVAS)
		g.rcbox(c + Vector3(0, 0.52, sz.z * 0.5 + 0.04 if not side else 0), Vector3(sz.x + 0.1, 0.06, 0.01) if not side else Vector3(0.01, 0.06, sz.z + 0.1), 0.002, Vector3.ZERO)
		g.color(WOODC, Geo.WOOD)
		g.box(c + Vector3(0, 0.16, 0.1 if not side else 0), Vector3(sz.x * 0.8, 0.04, 0.18) if not side else Vector3(0.18, 0.04, sz.z * 0.8))
		for k in 3:
			g.color(["#c8a24a", "#9fbf3a", "#d86a3a", "#e8dcc0"][(i + k) % 4], Geo.CANVAS)
			var o := Vector3((k - 1) * 0.15, 0.2, 0.1) if not side else Vector3(0, 0.2, (k - 1) * 0.15)
			g.cbox(c + o, Vector3(0.1, 0.06, 0.1), 0.02)
	# tea-house with water tank and team banner, front right
	var th := Vector3(0.85, Y0, 0.95)
	g.color(MUD, Geo.CONCRETE)
	g.cbox(th + Vector3(0, 0.32, 0), Vector3(0.7, 0.64, 0.6), 0.04)
	g.color(MUD_D, Geo.CONCRETE)
	g.cbox(th + Vector3(0, 0.66, 0), Vector3(0.74, 0.05, 0.64), 0.015)
	g.color("#2b2b2a", Geo.DARK)
	g.box(th + Vector3(-0.15, 0.24, 0.302), Vector3(0.2, 0.36, 0.01))
	g.color("#ffd27a", Geo.LAMP)
	g.box(th + Vector3(0.18, 0.36, 0.302), Vector3(0.16, 0.12, 0.01))
	g.color(TP_S, Geo.STEEL)
	for p in [Vector3(0.1, 0.68, -0.1), Vector3(0.25, 0.68, -0.1)]:
		g.tube(th + p, th + p + Vector3(0, 0.12, 0), 0.01, 3)
	g.color("#3d5a6e", Geo.STEEL)
	g.lathe([[0.8, 0.13], [1.02, 0.13], [1.06, 0.08]], 10, Transform3D(Basis.IDENTITY, th + Vector3(0.17, 0, -0.1)))
	g.color("#ffffff", Geo.TEAM)
	g.box(th + Vector3(0, 0.5, 0.305), Vector3(0.5, 0.08, 0.01))
	# central well with a rope frame
	var w := Vector3(-0.1, Y0, 0.2)
	g.color("#a99a7c", Geo.CONCRETE)
	g.lathe([[0.0, 0.2], [0.16, 0.2], [0.18, 0.17]], 12, Transform3D(Basis.IDENTITY, w))
	g.color("#2e2c29", Geo.DARK)
	g.lathe([[0.17, 0.14], [0.175, 0.14]], 10, Transform3D(Basis.IDENTITY, w), false, true)
	g.color(WOODC, Geo.WOOD)
	for x in [-0.18, 0.18]:
		g.tube(w + Vector3(x, 0.1, 0), w + Vector3(x, 0.45, 0), 0.015, 4)
	g.tube(w + Vector3(-0.2, 0.44, 0), w + Vector3(0.2, 0.44, 0), 0.015, 4)
	# carpets, sacks, generator
	for i in 3:
		g.color(cols[(i + 2) % 5], Geo.CANVAS)
		g.rcbox(Vector3(-0.6 + i * 0.4, Y0 + 0.005, 0.85), Vector3(0.3, 0.008, 0.44), 0.001, Vector3(0, -10 + i * 12, 0))
	g.color("#d0c09a", Geo.SANDBAG)
	for i in 5:
		g.rcbox(Vector3(-1.2 + (i % 3) * 0.13, Y0 + 0.06 + (i / 3) * 0.08, 1.1), Vector3(0.12, 0.1, 0.1), 0.03, Vector3(0, i * 20, 0))
	var gen := Vector3(-0.15, Y0, -0.45)
	g.color("#c4932e", Geo.PAINT)
	g.cbox(gen + Vector3(0, 0.08, 0), Vector3(0.24, 0.16, 0.16), 0.015)
	g.color(TP_S, Geo.STEEL)
	g.tube(gen + Vector3(0.09, 0.16, 0), gen + Vector3(0.09, 0.3, 0), 0.012, 4)
	# string lights criss-crossing the court
	g.color("#2e2c29", Geo.STEEL)
	var runs := [[Vector3(-1.2, 0.66, -0.7), Vector3(0.75, 0.75, 0.75)], [Vector3(1.2, 0.66, -0.7), Vector3(-1.2, 0.6, 0.6)]]
	for r in runs:
		var a: Vector3 = r[0] + Vector3(0, Y0, 0)
		var b: Vector3 = r[1] + Vector3(0, Y0, 0)
		g.color("#2e2c29", Geo.STEEL)
		g.tube(a, b, 0.003, 3)
		for k in 9:
			var p := a.lerp(b, (k + 0.5) / 9.0) - Vector3(0, 0.03 * sin(PI * (k + 0.5) / 9.0), 0)
			g.color(["#ffd27a", "#ff7a5a", "#7affb0", "#7ac8ff"][k % 4], Geo.LAMP)
			g.box(p, Vector3(0.025, 0.03, 0.025))
