extends RefCounted
## M3.0 EU list (tool-time only): original procedural models resembling the real vehicles; no
## brand names in game text. Node layout (Model / TurretPivot / Turret / Barrel / BarrelMesh /
## Hull) matches the older EU scenes; EU splinter camo is applied by camo_pass.gd.
##   LTV (wolfhound.tscn)        - Dingo / Eagle-style protected 4x4 with a roof .50 cal (M3.0 E)
##   Boxer IFV (boxer.tscn)      - 8x8 modular IFV with an unmanned 30 mm turret
##   RCH SPA (thunderhead.tscn)  - 6x6 wheeled 155 mm howitzer, armoured cab, rear gun module
## The Panther Tank keeps the M2.7b Leopard 2A6-style model (eu_tp_v8._leopold).
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const EU := "#7d8669"
const EU_D := "#5c6551"
const EU_S := "#3c3f40"
const GLASS_C := "#2a3a46"

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func V8():
	return load("res://tools/gfx_m7/us_v8.gd")

static func jobs() -> Dictionary:
	return {
		"eu_ltv": func() -> void: _ltv(),
		"eu_boxer": func() -> void: _boxer(),
		"eu_rch": func() -> void: _rch(),
	}

static func _glass_band(h, z0: float, z1: float, y0: float, y1: float, hw: float) -> void:
	h.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * (hw + 0.003), (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(0.006, y1 - y0, z1 - z0))

# ------------------------------------------------------------------ LTV (Dingo / Eagle-style)
static func _ltv() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.3, "recoil": 0.03, "wreck_s": 7.0, "steer_max": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.38, [0.48, -0.42], 0.15, 0.13, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.27, 0.02), Vector3(0.56, 0.1, 1.3), 0.02)   # chassis / belly
	# M3.0 E: Dingo / Eagle-style protected 4x4: short sloped bonnet, one tall armoured body
	# from the windscreen to the tail (crew and dismounts under armour), V-shaped belly
	h.color(EU, Geo.PAINT)
	h.xloft([[0.72, K.sect(0.3, 0.4, 0.48, 0.34, 0.36, 0.32, 0.03)], [0.4, K.sect(0.3, 0.44, 0.56, 0.38, 0.39, 0.36, 0.03)]])   # bonnet
	var c0 := K.sect(0.3, 0.5, 0.88, 0.4, 0.4, 0.35, 0.03)
	h.xloft([[0.42, K.sect(0.3, 0.5, 0.6, 0.39, 0.39, 0.37, 0.03)], [0.26, c0], [-0.66, c0], [-0.7, K.sect(0.32, 0.5, 0.84, 0.38, 0.38, 0.33, 0.03)]])   # armoured body
	h.color(EU_D, Geo.PAINT)
	h.prism_x([Vector2(-0.5, 0.2), Vector2(0.5, 0.2), Vector2(0.58, 0.3), Vector2(-0.58, 0.3)], -0.24, 0.24)   # V belly
	# glazing: steep two-piece armoured windscreen, small thick side windows
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.16, 0.16]:
		h.plate(Vector3(x, 0.72, 0.33), Vector3(0.27, 0.2, 0.006), Vector3(-22, 0, 0))
	_glass_band(h, 0.0, 0.2, 0.62, 0.78, 0.4)
	_glass_band(h, -0.42, -0.24, 0.64, 0.76, 0.4)
	h.color(EU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.6, -0.705), Vector3(0.44, 0.4, 0.02), Vector3(0, 0, 0))   # rear door
	h.color(EU, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.395, 0.7, -0.01), Vector3(0.008, 0.2, 0.03))   # B pillar
		h.box(Vector3(s * 0.392, 0.5, 0.0), Vector3(0.006, 0.008, 0.6))   # door seam
		h.color(EU_S, Geo.STEEL)
		h.box(Vector3(s * 0.4, 0.6, 0.15), Vector3(0.01, 0.02, 0.05))   # door handle
		h.tube(Vector3(s * 0.39, 0.78, 0.3), Vector3(s * 0.48, 0.8, 0.32), 0.008, 3)
		h.cbox(Vector3(s * 0.49, 0.76, 0.32), Vector3(0.02, 0.08, 0.05), 0.006)   # mirrors
		h.color(EU_D, Geo.PAINT)
		h.prism_x([Vector2(0.32, 0.34), Vector2(0.66, 0.34), Vector2(0.62, 0.44), Vector2(0.36, 0.44)], s * 0.34, s * 0.42)   # wheel arches
		h.prism_x([Vector2(-0.6, 0.34), Vector2(-0.26, 0.34), Vector2(-0.3, 0.44), Vector2(-0.56, 0.44)], s * 0.34, s * 0.42)
		h.color(EU, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.42, 0.705), 0.42, 0.12, 6)   # grille
	h.color(EU_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.33, 0.74), Vector3(0.72, 0.07, 0.05), 0.012)   # bumper + winch
	h.tube(Vector3(-0.2, 0.36, 0.77), Vector3(0.2, 0.36, 0.77), 0.025, 6)
	V4._lamps(h, 0.28, 0.45, 0.705)
	# roof: ring mount with gunner shield for the .50 cal (turret), antennas, jerrycans, spare
	h.color(EU_S, Geo.STEEL)
	h.ccyl(0.17, 0.03, 0.008, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.86, -0.06)))
	V4._antenna(h, Vector3(-0.32, 0.86, -0.28), 0.5)
	V4._antenna(h, Vector3(0.32, 0.86, -0.28), 0.4)
	h.color("#596245", Geo.PAINT)
	for x in [-0.25, -0.12]:
		h.jerrycan(Vector3(x, 0.62, -0.74), 0)
	h.tyre(Vector3(0.2, 0.6, -0.76), 0.12, 0.06, false, EU_S, 10)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.34, 0.34]:
		h.box(Vector3(x, 0.5, -0.725), Vector3(0.04, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.392, 0.82, 0.0), Vector3(0.006, 0.035, 0.56))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.89, -0.06))
	var t = K.new()
	t.color(EU, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.13, 0.1, 0.06), Vector3(0.02, 0.14, 0.18), Vector3(0, s * 30.0, 0))
	t.plate(Vector3(0, 0.1, 0.14), Vector3(0.18, 0.14, 0.02), Vector3(-6, 0, 0))   # gun shield
	t.color(GLASS_C, Geo.GLASS)
	t.plate(Vector3(0, 0.14, 0.152), Vector3(0.07, 0.04, 0.006), Vector3(-6, 0, 0))
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0.09, 0.05, -0.08), Vector3(0.08, 0.07, 0.1), 0.01)   # ammo can
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.12, 0.08), func(b) -> void:
		b.color(EU_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, 0.02), Vector3(0.05, 0.06, 0.16), 0.008)   # receiver
		b.gun(0.1, 0.46, 0.014, 0.012, -1.0, false, 8)   # .50 cal barrel
		b.tube(Vector3(0, 0, 0.4), Vector3(0, 0, 0.47), 0.019, 8)   # flash hider
		b.tube(Vector3(0, -0.04, -0.06), Vector3(0, -0.04, -0.02), 0.012, 4))   # spade grips
	U()._vfinish(root, model, h, mat, "wolfhound", [t, b], 1.3, "eu")

# ------------------------------------------------------------------ Boxer IFV (8x8, 30 mm RCT)
static func _boxer() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.3, "recoil": 0.03, "wreck_s": 7.5, "steer_max": 0.35})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.4, [0.6, 0.26, -0.3, -0.64], 0.15, 0.13, 2, EU_S)
	# tall slab-sided hull: sharp lower V, steep nose, mission-module seam, flat roof
	h.color(EU_D, Geo.PAINT)
	h.xloft([[0.9, K.sect(0.26, 0.3, 0.38, 0.3, 0.4, 0.44, 0.0)], [0.75, K.sect(0.17, 0.27, 0.4, 0.26, 0.44, 0.46, 0.0)],
		[-0.84, K.sect(0.17, 0.27, 0.4, 0.26, 0.44, 0.46, 0.0)], [-0.88, K.sect(0.2, 0.28, 0.4, 0.28, 0.43, 0.45, 0.0)]])
	h.color(EU, Geo.PAINT)
	var sn := K.sect(0.38, 0.4, 0.5, 0.47, 0.47, 0.42, 0.015)
	var sr := K.sect(0.38, 0.45, 0.74, 0.48, 0.48, 0.44, 0.03)
	h.xloft([[0.95, sn], [0.55, sr], [-0.86, sr], [-0.9, K.sect(0.38, 0.45, 0.72, 0.47, 0.47, 0.43, 0.025)]])
	# module seam + bolt rows, driver's hatch + periscopes (front left), side stowage boxes
	h.color(EU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.481, 0.56, 0.38), Vector3(0.006, 0.34, 0.012))
		h.rivets(Vector3(s * 0.483, 0.7, -0.8), Vector3(s * 0.483, 0.7, 0.3), 8, Vector3(s, 0, 0), 0.005)
		h.color(EU_D, Geo.PAINT)
		h.cbox(Vector3(s * 0.5, 0.48, -0.1), Vector3(0.05, 0.12, 0.5), 0.01)
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.483, 0.66, 0.65), Vector3(0.006, 0.04, 0.4))
		h.color(EU_S, Geo.STEEL)
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(-0.22, 0.745, 0.62), 0.14)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.3, -0.22, -0.14]:
		h.box(Vector3(x, 0.75, 0.73), Vector3(0.05, 0.02, 0.025))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0.2, 0.742, 0.66), 0.24, 0.22, 5)   # power-pack grille (front right)
	V4._lamps(h, 0.36, 0.46, 0.94)
	h.color(EU_S, Geo.STEEL)
	for x in [-0.3, 0.3]:
		h.tube(Vector3(x, 0.3, 0.9), Vector3(x, 0.3, 0.97), 0.02, 6)
	# rear: troop door in the ramp, tail lamps, roof hatches + stowage
	h.color(EU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.56, -0.905), Vector3(0.6, 0.32, 0.02), Vector3(4, 0, 0))
	h.color(EU, Geo.PAINT)
	h.plate(Vector3(0.12, 0.56, -0.92), Vector3(0.22, 0.26, 0.01), Vector3(4, 0, 0))
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.4, 0.4]:
		h.box(Vector3(x, 0.66, -0.9), Vector3(0.04, 0.03, 0.01))
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.75, -0.62), Vector3(0.3, 0.02, 0.24), 0.01)
	h.color("#7f7556", Geo.CANVAS)
	h.cbox(Vector3(0.32, 0.78, -0.7), Vector3(0.18, 0.07, 0.3), 0.02)
	V4._antenna(h, Vector3(-0.4, 0.74, -0.78), 0.5)
	# unmanned 30 mm turret: low faceted box, sensor heads, smoke grenades
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.74, 0.0))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.26, 0.26, 0.03, 14, Transform3D.IDENTITY)
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.28, -0.3), Vector2(0.28, -0.3), Vector2(0.3, 0.08), Vector2(0.16, 0.3), Vector2(-0.16, 0.3), Vector2(-0.3, 0.08)], 0.02, 0.16, Vector2(0.86, 0.85), Vector2(0, -0.02))
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(-0.18, 0.23, 0.0), Vector3(0.11, 0.1, 0.12), 0.012)   # commander's panoramic sight
	t.cbox(Vector3(0.2, 0.2, 0.1), Vector3(0.1, 0.07, 0.1), 0.01)   # gunner's sight
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.18, 0.235, 0.062), Vector3(0.08, 0.05, 0.006))
	t.box(Vector3(0.2, 0.2, 0.152), Vector3(0.07, 0.035, 0.006))
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0.33, 0.1, -0.08), Vector3(0.08, 0.1, 0.28), 0.01)   # ATGM pod (stowed)
	U()._smoke(t, Vector3(0.26, 0.1, 0.2), 35.0)
	U()._smoke(t, Vector3(-0.26, 0.1, 0.2), -35.0)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.09, -0.305), Vector3(0.36, 0.04, 0.008))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0.0, 0.09, 0.26), func(b) -> void:
		b.color(EU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.02), Vector3(0.1, 0.09, 0.1), 0.012)   # mantlet
		b.color(EU_S, Geo.STEEL)
		b.gun(0.06, 0.74, 0.024, 0.018, -1.0, false, 8)   # 30 mm cannon
		b.tube(Vector3(0, 0, 0.68), Vector3(0, 0, 0.76), 0.028, 8)   # muzzle brake
		b.tube(Vector3(0.06, -0.01, 0.05), Vector3(0.06, -0.01, 0.22), 0.008, 4))   # coax
	U()._vfinish(root, model, h, mat, "boxer", [t, b], 1.3, "eu")

# ------------------------------------------------------------------ RCH SPA (6x6 155 mm)
static func _rch() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.5, "recoil": 0.3, "wreck_s": 8.0, "steer_max": 0.3})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.4, [0.72, 0.02, -0.5], 0.16, 0.14, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, -0.05), Vector3(0.6, 0.1, 1.9), 0.015)   # chassis
	# armoured cab: wedge nose, small armoured windows, roof hatch
	h.color(EU, Geo.PAINT)
	var c0 := K.sect(0.3, 0.52, 0.78, 0.43, 0.43, 0.4, 0.03)
	h.xloft([[1.02, K.sect(0.3, 0.42, 0.56, 0.4, 0.42, 0.38, 0.03)], [0.92, c0], [0.48, c0], [0.44, K.sect(0.3, 0.5, 0.76, 0.42, 0.42, 0.39, 0.02)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.2, 0.2]:
		h.plate(Vector3(x, 0.66, 0.925), Vector3(0.24, 0.1, 0.006), Vector3(-18, 0, 0))
	_glass_band(h, 0.6, 0.86, 0.62, 0.72, 0.43)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.44, 1.02), 0.4, 0.08, 4)
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(0.18, 0.785, 0.68), 0.12)
	V4._lamps(h, 0.33, 0.46, 1.03)
	# engine / ammo bay behind the cab, gun module ring at the rear, stabiliser spades
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.52, 0.22), Vector3(0.82, 0.34, 0.42), 0.025)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.693, 0.22), 0.5, 0.3, 6)
	h.color(EU, Geo.PAINT)
	h.cbox(Vector3(0, 0.46, -0.48), Vector3(0.86, 0.22, 0.9), 0.02)   # rear deck
	h.color(EU_S, Geo.STEEL)
	h.ccyl(0.36, 0.04, 0.01, 16, Transform3D(Basis.IDENTITY, Vector3(0, 0.57, -0.5)))
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.3, 0.22, -0.98), Vector3(0.14, 0.18, 0.03), Vector3(-25, 0, 0))   # rear spades
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.433, 0.5, -0.45), Vector3(0.006, 0.05, 0.7))
		h.color(EU_S, Geo.STEEL)
		h.color(EU_D, Geo.PAINT)
		h.cbox(Vector3(s * 0.45, 0.42, 0.22), Vector3(0.04, 0.14, 0.4), 0.01)   # side lockers
		h.color(EU_S, Geo.STEEL)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.38, 0.38]:
		h.box(Vector3(x, 0.44, -0.935), Vector3(0.04, 0.03, 0.01))
	V4._antenna(h, Vector3(-0.35, 0.78, 0.5), 0.45)
	# unmanned gun module: boxy armoured turret, long 52-calibre barrel with a pepperpot brake
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.6, -0.5))
	var t = K.new()
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.34, -0.42), Vector2(0.34, -0.42), Vector2(0.36, 0.2), Vector2(0.22, 0.38), Vector2(-0.22, 0.38), Vector2(-0.36, 0.2)], 0.0, 0.3, Vector2(0.9, 0.92))
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.15, -0.46), Vector3(0.6, 0.24, 0.1), 0.02)   # ammo magazine bustle
	t.color(EU_S, Geo.STEEL)
	t.rivets(Vector3(-0.3, 0.25, -0.3), Vector3(0.3, 0.25, -0.3), 6, Vector3(0, 1, 0), 0.006)
	t.cbox(Vector3(0.22, 0.33, 0.0), Vector3(0.1, 0.07, 0.1), 0.01)   # sensor
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.22, 0.335, 0.052), Vector3(0.07, 0.035, 0.006))
	t.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		t.box(Vector3(s * 0.33, 0.16, -0.1), Vector3(0.006, 0.05, 0.4))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.25, 0.36), func(b) -> void:
		b.color(EU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.03), Vector3(0.16, 0.14, 0.12), 0.015)   # mantlet
		b.color(EU, Geo.PAINT)
		b.gun(0.08, 1.45, 0.045, 0.034, 0.5, false, 10)
		b.color(EU_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, 1.47), Vector3(0.09, 0.08, 0.1), 0.01)   # pepperpot muzzle brake
		b.color("#2b2d2c", Geo.DARK)
		for k in 3:
			for s in [-1.0, 1.0]:
				b.box(Vector3(s * 0.046, 0, 1.44 + k * 0.03), Vector3(0.004, 0.025, 0.015)))
	U()._vfinish(root, model, h, mat, "thunderhead", [t, b], 1.5, "eu")

# ------------------------------------------------------------------ Thunderbolt (Poprad-style)
static func _thunderbolt() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.45, "recoil": 0.02, "wreck_s": 7.0, "steer_max": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.38, [0.5, -0.45], 0.16, 0.14, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, 0.0), Vector3(0.56, 0.1, 1.4), 0.015)
	# armoured 4x4 cab (front), flat rear bed carrying the launcher turntable
	h.color(EU, Geo.PAINT)
	var c0 := K.sect(0.3, 0.52, 0.86, 0.4, 0.4, 0.37, 0.03)
	h.xloft([[0.76, K.sect(0.3, 0.42, 0.56, 0.38, 0.4, 0.36, 0.03)], [0.6, c0], [0.12, c0], [0.08, K.sect(0.3, 0.5, 0.84, 0.39, 0.39, 0.36, 0.02)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.17, 0.17]:
		h.plate(Vector3(x, 0.72, 0.615), Vector3(0.26, 0.14, 0.006), Vector3(-14, 0, 0))
	_glass_band(h, 0.24, 0.52, 0.64, 0.78, 0.4)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.44, 0.765), 0.4, 0.1, 5)
	V4._lamps(h, 0.3, 0.46, 0.77)
	h.color(EU_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.33, 0.8), Vector3(0.74, 0.07, 0.05), 0.012)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.4, 0.78, 0.55), Vector3(s * 0.5, 0.8, 0.57), 0.008, 3)
		h.cbox(Vector3(s * 0.51, 0.76, 0.57), Vector3(0.02, 0.08, 0.05), 0.006)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -0.36), Vector3(0.8, 0.14, 0.78), 0.02)   # bed / equipment boxes
	h.color(EU, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.32, 0.55, -0.62), Vector3(0.14, 0.14, 0.24), 0.015)   # generator + crew lockers
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.403, 0.44, -0.36), Vector3(0.006, 0.05, 0.6))
		h.color(EU, Geo.PAINT)
	h.color(EU_S, Geo.STEEL)
	h.ccyl(0.2, 0.05, 0.01, 14, Transform3D(Basis.IDENTITY, Vector3(0, 0.49, -0.3)))
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.36, 0.36]:
		h.box(Vector3(x, 0.42, -0.755), Vector3(0.04, 0.03, 0.01))
	V4._antenna(h, Vector3(-0.32, 0.86, 0.2), 0.5)
	# launcher: pedestal + yoke, sensor head (TV / IR + laser) between two 2-round MANPADS pods
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.54, -0.3))
	var t = K.new()
	t.color(EU_D, Geo.PAINT)
	t.ccyl(0.14, 0.18, 0.02, 12, Transform3D.IDENTITY)
	for s in [-1.0, 1.0]:
		t.cbox(Vector3(s * 0.12, 0.26, 0.0), Vector3(0.04, 0.2, 0.12), 0.01)   # yoke arms
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.32, 0.0), func(b) -> void:
		b.color(EU, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.02), Vector3(0.14, 0.16, 0.2), 0.015)   # sensor head
		b.color(GLASS_C, Geo.GLASS)
		b.box(Vector3(-0.03, 0.03, 0.123), Vector3(0.05, 0.05, 0.006))
		b.box(Vector3(0.035, 0.03, 0.123), Vector3(0.04, 0.04, 0.006))
		b.color("#2b2d2c", Geo.DARK)
		b.box(Vector3(0, -0.04, 0.123), Vector3(0.08, 0.02, 0.006))
		for s in [-1.0, 1.0]:
			b.color(EU_D, Geo.PAINT)
			b.cbox(Vector3(s * 0.2, 0, 0.0), Vector3(0.18, 0.18, 0.04), 0.01)   # pod frame
			for k in 2:
				var o := Vector3(s * (0.155 + k * 0.09), 0.0, 0.0)
				b.color("#6f7360", Geo.PAINT)
				b.tube(o + Vector3(0, 0, -0.3), o + Vector3(0, 0, 0.32), 0.038, 8)   # MANPADS tube
				b.color("#2b2d2c", Geo.DARK)
				b.tube(o + Vector3(0, 0, 0.32), o + Vector3(0, 0, 0.33), 0.03, 8)
			b.color("#ffffff", Geo.TEAM)
			b.box(Vector3(s * 0.2, 0.06, -0.1), Vector3(0.17, 0.006, 0.2)))
	U()._vfinish(root, model, h, mat, "flakwerk", [t, b], 1.45, "eu")
