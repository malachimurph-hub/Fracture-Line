extends RefCounted
## M3.0 "E. National rosters", Germany (internal faction id eu; tool-time only). Original procedural
## models resembling real German equipment; no brand names in game text. Node layout matches the
## older EU scenes (Model / TurretPivot / Turret / Barrel / BarrelMesh / Hull, Rotor / TailRotor).
##   Thunderbolt (flakwerk.tscn)  - Ozelot-style light tracked carrier, 4-round MANPADS launcher
##   Hearth (hearth.tscn)         - MARS II-style tracked rocket launcher, armoured cab, 12-round pod
##   Puma IFV (salamander.tscn)   - Puma-style tracked IFV with an unmanned 30 mm turret
##   Fuchs ECM (aegis.tscn)       - Fuchs-style 6x6 with jammer domes (protection aura)
##   Fuchs EW (spectre.tscn)      - Fuchs-style 6x6 with a telescopic EW mast and whip antennas
##   Fennek Recon (sentinel.tscn) - Fennek-style low 4x4 scout with a raised sensor mast
##   Heavy Tank (brennus.tscn)    - 130 mm next-generation heavy tank (single gun, angular turret)
##   Tiger (kestrel.tscn)         - Tiger-style tandem attack helicopter, stub wings, mast sight
##   Multirole Fighter (corvid)   - canard-delta twin-engine fighter (grey, own camo pattern 0)
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const EU := "#7d8669"
const EU_D := "#5c6551"
const EU_S := "#3c3f40"
const GLASS_C := "#2a3a46"
const AIR := "#8e9396"
const AIR_D := "#73787b"

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func V8():
	return load("res://tools/gfx_m7/us_v8.gd")

static func jobs() -> Dictionary:
	return {
		"eu_thunderbolt": func() -> void: _ozelot(),
		"eu_hearth": func() -> void: _mars(),
		"eu_puma": func() -> void: _puma(),
		"eu_fuchs_ecm": func() -> void: _fuchs(false),
		"eu_fuchs_ew": func() -> void: _fuchs(true),
		"eu_fennek": func() -> void: _fennek(),
		"eu_heavy": func() -> void: _heavy(),
		"eu_tiger": func() -> void: _tiger(),
		"eu_fighter": func() -> void: _fighter(),
	}

static func _team_stripe(h, x: float, y: float, z: float, l: float) -> void:
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * x, y, z), Vector3(0.006, 0.03, l))

## Wiesel-style low tracked hull: tiny track run, sloped glacis, driver hatch front left, engine
## grille front right (engine is front-mounted), flat rear deck for the mission kit.
static func _wiesel_hull(h, hw: float, l: float) -> void:
	h.track_run(hw - 0.08, l, 4, 0.08, 0.17, EU_S)
	var hl := l * 0.5
	h.color(EU_D, Geo.PAINT)
	h.xloft([[hl + 0.02, K.sect(0.16, 0.2, 0.26, hw - 0.12, hw - 0.1, hw - 0.12, 0.0)], [hl - 0.16, K.sect(0.12, 0.16, 0.3, hw - 0.1, hw - 0.08, hw - 0.08, 0.0)], [-hl + 0.02, K.sect(0.12, 0.16, 0.3, hw - 0.1, hw - 0.08, hw - 0.08, 0.0)]])
	h.color(EU, Geo.PAINT)
	h.xloft([[hl + 0.04, K.sect(0.26, 0.28, 0.3, hw - 0.02, hw, hw - 0.04, 0.01)], [hl - 0.24, K.sect(0.26, 0.3, 0.46, hw, hw, hw - 0.04, 0.02)],
		[-hl + 0.04, K.sect(0.26, 0.3, 0.46, hw, hw, hw - 0.04, 0.02)], [-hl - 0.01, K.sect(0.26, 0.3, 0.43, hw, hw, hw - 0.05, 0.02)]])
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(-hw * 0.45, 0.465, hl - 0.34), 0.12)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(hw * 0.4, 0.462, hl - 0.34), 0.22, 0.2, 5)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.06, 0.0, 0.06]:
		h.box(Vector3(-hw * 0.45 + x, 0.47, hl - 0.25), Vector3(0.04, 0.02, 0.01))   # driver periscopes
	V4._lamps(h, hw - 0.1, 0.36, hl + 0.02)
	h.color(EU_S, Geo.STEEL)
	for x in [-hw + 0.12, hw - 0.12]:
		h.tube(Vector3(x, 0.24, hl), Vector3(x, 0.24, hl + 0.06), 0.018, 6)   # tow eyes
	h.color("#b33a2a", Geo.LAMP)
	for x in [-hw + 0.1, hw - 0.1]:
		h.box(Vector3(x, 0.4, -hl - 0.012), Vector3(0.04, 0.03, 0.008))

# ------------------------------------------------------------------ Thunderbolt (Ozelot-style)
static func _ozelot() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.2, "recoil": 0.02, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_wiesel_hull(h, 0.46, 1.3)
	# rear superstructure: crew box with vision blocks, launcher ring on top
	h.color(EU, Geo.PAINT)
	h.cbox(Vector3(0, 0.55, -0.3), Vector3(0.74, 0.2, 0.6), 0.03)
	h.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.372, 0.58, -0.2), Vector3(0.006, 0.05, 0.12))
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0.24, 0.67, -0.5), Vector3(0.16, 0.06, 0.16), 0.01)   # sensor / IFF box
	V4._antenna(h, Vector3(-0.3, 0.65, -0.55), 0.5)
	h.color("#6b5a3a", Geo.CANVAS)
	h.cbox(Vector3(0, 0.36, -0.65), Vector3(0.6, 0.12, 0.06), 0.02)   # rear stowage roll
	_team_stripe(h, 0.462, 0.4, -0.1, 0.7)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.65, -0.28))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.ccyl(0.16, 0.04, 0.01, 14, Transform3D.IDENTITY)
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.12, -0.02), Vector3(0.1, 0.18, 0.12), 0.012)   # pedestal
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.22, 0.0), func(b) -> void:
		b.color(EU, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.0), Vector3(0.12, 0.12, 0.16), 0.012)   # sight head
		b.color(GLASS_C, Geo.GLASS)
		b.box(Vector3(0, 0.02, 0.082), Vector3(0.07, 0.04, 0.006))
		for s in [-1.0, 1.0]:
			b.color(EU_D, Geo.PAINT)
			b.cbox(Vector3(s * 0.17, 0, 0.0), Vector3(0.16, 0.17, 0.04), 0.01)   # launcher frame
			for k in 2:
				var o := Vector3(s * (0.13 + k * 0.08), 0.0, 0.0)
				b.color("#6f7360", Geo.PAINT)
				b.tube(o + Vector3(0, 0, -0.26), o + Vector3(0, 0, 0.28), 0.034, 8)
				b.color("#2b2d2c", Geo.DARK)
				b.tube(o + Vector3(0, 0, 0.28), o + Vector3(0, 0, 0.29), 0.027, 8))
	U()._vfinish(root, model, h, mat, "flakwerk", [t, b], 1.2, "eu")

# ------------------------------------------------------------------ Hearth (MARS II-style)
static func _mars() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.35, "recoil": 0.05, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.46, 1.66, 6, 0.08, 0.22, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.xloft([[0.84, K.sect(0.2, 0.26, 0.32, 0.28, 0.34, 0.35, 0.0)], [0.64, K.sect(0.13, 0.2, 0.34, 0.32, 0.36, 0.36, 0.0)], [-0.82, K.sect(0.13, 0.2, 0.34, 0.32, 0.36, 0.36, 0.0)]])
	h.color(EU, Geo.PAINT)
	h.xloft([[0.86, K.sect(0.32, 0.34, 0.38, 0.56, 0.58, 0.5, 0.015)], [0.5, K.sect(0.32, 0.38, 0.46, 0.58, 0.58, 0.54, 0.02)], [-0.84, K.sect(0.32, 0.38, 0.46, 0.58, 0.58, 0.54, 0.02)]])
	# armoured crew cab up front: slab sides, three armoured windows, roof hatch
	h.cbox(Vector3(0, 0.64, 0.52), Vector3(1.0, 0.36, 0.5), 0.03)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.3, 0.0, 0.3]:
		h.plate(Vector3(x, 0.7, 0.775), Vector3(0.24, 0.13, 0.008), Vector3(-6, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.503, 0.7, 0.56), Vector3(0.006, 0.1, 0.18))
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(0.22, 0.825, 0.48), 0.13)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.48, 0.865), 0.5, 0.08, 6)
	V4._lamps(h, 0.42, 0.5, 0.87)
	V4._antenna(h, Vector3(-0.4, 0.82, 0.36), 0.55)
	# rear launcher bed + traverse ring
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.5, -0.4), Vector3(1.0, 0.08, 0.84), 0.015)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.44, 0.44]:
		h.box(Vector3(x, 0.44, -0.845), Vector3(0.04, 0.03, 0.01))
	_team_stripe(h, 0.585, 0.42, -0.1, 1.2)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.55, -0.35))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.ccyl(0.3, 0.05, 0.01, 16, Transform3D.IDENTITY)
	t.color(EU, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.cbox(Vector3(s * 0.36, 0.12, -0.1), Vector3(0.06, 0.2, 0.3), 0.012)   # cradle cheeks
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.22, -0.05), func(b) -> void:
		# two six-round pods side by side in one box cradle, raised a little
		for s in [-1.0, 1.0]:
			b.color(EU, Geo.PAINT)
			b.cbox(Vector3(s * 0.17, 0.0, 0.0), Vector3(0.32, 0.24, 0.92), 0.015)
			b.color("#2b2d2c", Geo.DARK)
			for i in 3:
				for j in 2:
					b.ccyl(0.035, 0.008, 0.002, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.17 + (i - 1) * 0.095, (j - 0.5) * 0.11, 0.462)))
			b.color(EU_D, Geo.PAINT)
			for z in [-0.3, 0.0, 0.3]:
				b.box(Vector3(s * 0.17, 0.122, z), Vector3(0.3, 0.008, 0.03))   # pod ribs
		b.color("#ffffff", Geo.TEAM)
		b.box(Vector3(0, 0.0, -0.462), Vector3(0.5, 0.04, 0.006)))
	U()._vfinish(root, model, h, mat, "hearth", [t, b], 1.35, "eu")

# ------------------------------------------------------------------ Puma IFV (salamander.tscn)
static func _puma() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.25, "recoil": 0.03, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.5, 1.7, 6, 0.08, 0.24, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.xloft([[0.86, K.sect(0.2, 0.26, 0.32, 0.3, 0.36, 0.38, 0.0)], [0.66, K.sect(0.13, 0.2, 0.34, 0.34, 0.38, 0.38, 0.0)], [-0.84, K.sect(0.13, 0.2, 0.34, 0.34, 0.38, 0.38, 0.0)]])
	# very boxy upper hull with full-length side armour modules and a steep short glacis
	h.color(EU, Geo.PAINT)
	var top := K.sect(0.32, 0.42, 0.62, 0.66, 0.66, 0.6, 0.02)
	h.xloft([[0.9, K.sect(0.32, 0.36, 0.44, 0.62, 0.64, 0.56, 0.015)], [0.6, top], [-0.84, top], [-0.88, K.sect(0.32, 0.42, 0.6, 0.65, 0.65, 0.58, 0.02)]])
	for s in [-1.0, 1.0]:
		for i in 4:
			h.color(EU if i % 2 == 0 else EU_D, Geo.PAINT)
			h.plate(Vector3(s * 0.675, 0.44, -0.62 + i * 0.4), Vector3(0.03, 0.22, 0.38), Vector3(0, 0, 0))
		h.color(EU_S, Geo.STEEL)
		h.rivets(Vector3(s * 0.693, 0.53, -0.75), Vector3(s * 0.693, 0.53, 0.7), 8, Vector3(s, 0, 0), 0.006)
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(-0.32, 0.625, 0.55), 0.14)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0.34, 0.622, 0.55), 0.24, 0.2, 5)
	V4._lamps(h, 0.5, 0.42, 0.89)
	h.color(EU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.46, -0.885), Vector3(0.74, 0.32, 0.03), Vector3(4, 0, 0))   # rear ramp
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.52, 0.52]:
		h.box(Vector3(x, 0.55, -0.9), Vector3(0.04, 0.03, 0.01))
	V4._antenna(h, Vector3(-0.5, 0.62, -0.7), 0.5)
	_team_stripe(h, 0.692, 0.6, -0.05, 1.3)
	# unmanned turret: low flat box offset slightly left, 30 mm gun, sight heads, missile box
	var piv := VK._n3(model, root, "TurretPivot", Vector3(-0.04, 0.62, 0.0))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.28, 0.28, 0.03, 14, Transform3D.IDENTITY)
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.3, -0.34), Vector2(0.3, -0.34), Vector2(0.32, 0.18), Vector2(0.18, 0.36), Vector2(-0.18, 0.36), Vector2(-0.32, 0.18)], 0.02, 0.16, Vector2(0.9, 0.88))
	t.color(EU_S, Geo.STEEL)
	t.cbox(Vector3(0.2, 0.22, -0.02), Vector3(0.12, 0.1, 0.12), 0.012)   # commander's sight
	t.cbox(Vector3(-0.16, 0.2, 0.12), Vector3(0.1, 0.08, 0.1), 0.01)    # gunner's sight
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.2, 0.225, 0.042), Vector3(0.08, 0.05, 0.006))
	t.box(Vector3(-0.16, 0.2, 0.172), Vector3(0.07, 0.04, 0.006))
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(-0.38, 0.12, -0.05), Vector3(0.1, 0.12, 0.36), 0.012)   # missile launcher box
	U()._smoke(t, Vector3(0.3, 0.1, 0.2), 35.0)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.09, -0.345), Vector3(0.4, 0.04, 0.008))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0.02, 0.1, 0.3), func(b) -> void:
		b.color(EU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.0), Vector3(0.1, 0.1, 0.12), 0.012)
		b.color(EU_S, Geo.STEEL)
		b.gun(0.05, 0.7, 0.026, 0.018, -1.0, false, 8)   # 30 mm
		b.tube(Vector3(0, 0, 0.64), Vector3(0, 0, 0.72), 0.028, 8))
	U()._vfinish(root, model, h, mat, "salamander", [t, b], 1.25, "eu")

# ------------------------------------------------------------------ Fuchs-style 6x6 (aegis / spectre)
static func _fuchs(ew: bool) -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.5 if ew else 1.3, "recoil": 0.0, "wreck_s": 7.0, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.44, [0.56, 0.0, -0.56], 0.17, 0.14, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, 0.0), Vector3(0.62, 0.12, 1.7), 0.02)
	# boat-shaped hull: sharply sloped nose with the driver's big windscreen, tall flat sides
	h.color(EU, Geo.PAINT)
	h.xloft([[0.96, K.sect(0.34, 0.38, 0.42, 0.3, 0.34, 0.3, 0.02)], [0.82, K.sect(0.3, 0.42, 0.56, 0.44, 0.48, 0.44, 0.03)], [0.52, K.sect(0.3, 0.44, 0.82, 0.5, 0.52, 0.48, 0.03)],
		[-0.84, K.sect(0.3, 0.44, 0.82, 0.5, 0.52, 0.48, 0.03)], [-0.9, K.sect(0.32, 0.44, 0.78, 0.48, 0.5, 0.46, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.2, 0.2]:
		h.plate(Vector3(x, 0.7, 0.66), Vector3(0.3, 0.16, 0.008), Vector3(-50, 0, 0))   # sloped windscreens
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.523, 0.64, 0.32), Vector3(0.006, 0.12, 0.14))
		h.color(EU_D, Geo.PAINT)
		for z in [0.56, 0.0, -0.56]:
			h.prism_x([Vector2(z - 0.2, 0.36), Vector2(z + 0.2, 0.36), Vector2(z + 0.16, 0.5), Vector2(z - 0.16, 0.5)], s * 0.44, s * 0.53)   # wheel arches
		h.color(EU_S, Geo.STEEL)
		h.box(Vector3(s * 0.528, 0.6, -0.3), Vector3(0.008, 0.02, 0.06))   # side door handle
		h.color(EU, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(-0.28, 0.822, -0.2), 0.26, 0.3, 5)
	h.color(EU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.56, -0.905), Vector3(0.7, 0.42, 0.02), Vector3(0, 0, 0))   # rear doors
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.42, 0.42]:
		h.box(Vector3(x, 0.44, -0.915), Vector3(0.04, 0.03, 0.008))
	V4._lamps(h, 0.32, 0.42, 0.95)
	h.color(EU_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.36, 0.97), Vector3(0.6, 0.06, 0.04), 0.01)
	_team_stripe(h, 0.522, 0.52, -0.2, 1.1)
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(0.24, 0.825, -0.5), 0.13)
	if not ew:
		# ECM / protection kit: two jammer domes, roof sensor bar, smoke dischargers on the nose
		h.color("#c9c6bc", Geo.PAINT)
		for z in [0.2, -0.55]:
			h.dome(0.13, 0.11, 3, 12, Transform3D(Basis.IDENTITY, Vector3(-0.18 if z > 0 else 0.0, 0.82, z)))
		h.color(EU_S, Geo.STEEL)
		h.cbox(Vector3(0.26, 0.86, 0.15), Vector3(0.16, 0.06, 0.3), 0.01)
		for s in [-1.0, 1.0]:
			U()._smoke(h, Vector3(s * 0.4, 0.6, 0.5), s * 35.0)
		V4._antenna(h, Vector3(0.4, 0.82, -0.75), 0.6)
		V4._antenna(h, Vector3(-0.4, 0.82, -0.75), 0.6)
		U()._vfinish(root, model, h, mat, "aegis", [], 1.3, "eu")
		return
	# EW: telescopic mast with an antenna head (rotates on TurretPivot), whip antennas, generator
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(-0.28, 0.87, -0.65), Vector3(0.28, 0.1, 0.36), 0.015)
	for x in [-0.4, 0.4]:
		for z in [0.3, -0.8]:
			V4._antenna(h, Vector3(x, 0.82, z), 0.7)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.12, 0.82, -0.1))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.ccyl(0.09, 0.05, 0.01, 10, Transform3D.IDENTITY)
	t.tube(Vector3(0, 0.0, 0), Vector3(0, 0.4, 0), 0.04, 8)
	t.tube(Vector3(0, 0.4, 0), Vector3(0, 0.62, 0), 0.028, 8)
	t.color("#c9c6bc", Geo.PAINT)
	t.cbox(Vector3(0, 0.68, 0), Vector3(0.36, 0.1, 0.08), 0.02)   # antenna head
	t.color(EU_S, Geo.STEEL)
	for x in [-0.14, 0.0, 0.14]:
		t.tube(Vector3(x, 0.73, 0), Vector3(x, 0.84, 0), 0.006, 4)
	VK._mi(piv, root, "Turret", t.commit(mat))
	U()._vfinish(root, model, h, mat, "spectre", [t], 1.5, "eu")

# ------------------------------------------------------------------ Fennek-style recon (sentinel.tscn)
static func _fennek() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 6.5, "steer_max": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.38, [0.46, -0.44], 0.16, 0.13, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.27, 0.0), Vector3(0.56, 0.1, 1.3), 0.02)
	# very low, wide wedge body with a flat roof and a long sloped front
	h.color(EU, Geo.PAINT)
	h.xloft([[0.74, K.sect(0.3, 0.34, 0.38, 0.3, 0.36, 0.3, 0.02)], [0.5, K.sect(0.28, 0.4, 0.5, 0.42, 0.44, 0.4, 0.03)], [0.2, K.sect(0.28, 0.42, 0.62, 0.44, 0.44, 0.4, 0.03)],
		[-0.62, K.sect(0.28, 0.42, 0.62, 0.44, 0.44, 0.4, 0.03)], [-0.68, K.sect(0.3, 0.42, 0.58, 0.42, 0.42, 0.38, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.17, 0.17]:
		h.plate(Vector3(x, 0.56, 0.35), Vector3(0.28, 0.1, 0.008), Vector3(-45, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.443, 0.53, 0.1), Vector3(0.006, 0.07, 0.2))
		h.color(EU_D, Geo.PAINT)
		for z in [0.46, -0.44]:
			h.prism_x([Vector2(z - 0.19, 0.32), Vector2(z + 0.19, 0.32), Vector2(z + 0.15, 0.44), Vector2(z - 0.15, 0.44)], s * 0.36, s * 0.45)
		h.color(EU, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.36, 0.745), 0.4, 0.06, 5)
	V4._lamps(h, 0.28, 0.38, 0.74)
	h.color("#6b5a3a", Geo.CANVAS)
	h.cbox(Vector3(0, 0.66, -0.4), Vector3(0.5, 0.07, 0.32), 0.025)   # roof stowage
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.36, 0.36]:
		h.box(Vector3(x, 0.45, -0.685), Vector3(0.04, 0.03, 0.008))
	_team_stripe(h, 0.442, 0.46, -0.2, 0.7)
	V4._antenna(h, Vector3(-0.34, 0.62, -0.55), 0.5)
	# sensor mast (radar / camera / laser head) on the TurretPivot, as the old Sentinel
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.1, 0.62, -0.1))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.ccyl(0.07, 0.04, 0.01, 10, Transform3D.IDENTITY)
	t.tube(Vector3(0, 0, 0), Vector3(0, 0.46, 0), 0.025, 8)
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.52, 0.0), Vector3(0.22, 0.12, 0.12), 0.015)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.05, 0.53, 0.062), Vector3(0.06, 0.06, 0.006))
	t.box(Vector3(0.05, 0.53, 0.062), Vector3(0.05, 0.05, 0.006))
	VK._mi(piv, root, "Turret", t.commit(mat))
	U()._vfinish(root, model, h, mat, "sentinel", [t], 1.2, "eu")

# ------------------------------------------------------------------ Heavy tank, 130 mm (brennus.tscn)
static func _heavy() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.6, "recoil": 0.18, "wreck_s": 9.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.6, 2.0, 7, 0.1, 0.28, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.22, 0.28, 0.34, 0.36, 0.44, 0.46, 0.0)], [0.78, K.sect(0.14, 0.22, 0.36, 0.42, 0.46, 0.46, 0.0)], [-0.96, K.sect(0.14, 0.22, 0.36, 0.42, 0.46, 0.46, 0.0)]])
	h.color(EU, Geo.PAINT)
	var top := K.sect(0.34, 0.4, 0.5, 0.76, 0.76, 0.7, 0.02)
	h.xloft([[1.04, K.sect(0.34, 0.36, 0.4, 0.7, 0.72, 0.62, 0.015)], [0.7, top], [-0.98, top], [-1.02, K.sect(0.34, 0.4, 0.48, 0.74, 0.74, 0.68, 0.02)]])
	# skirts: thick armour panels in two tones, angled lower lip
	for s in [-1.0, 1.0]:
		for i in 5:
			h.color(EU if i % 2 == 0 else EU_D, Geo.PAINT)
			h.plate(Vector3(s * 0.79, 0.36, -0.78 + i * 0.4), Vector3(0.04, 0.2, 0.38), Vector3(0, 0, -s * 4.0))
		h.color(EU_S, Geo.STEEL)
		h.rivets(Vector3(s * 0.815, 0.43, -0.9), Vector3(s * 0.815, 0.43, 0.9), 10, Vector3(s, 0, 0), 0.007)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.502, -0.72), 0.9, 0.36, 8)
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(-0.3, 0.505, 0.78), 0.14)
	V4._lamps(h, 0.58, 0.42, 1.03)
	_team_stripe(h, 0.81, 0.48, 0.0, 1.5)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.5, -0.05))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.44, 0.44, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	# large angular turret: faceted front cheeks, flat roof, long bustle
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.46, -0.6), Vector2(0.46, -0.6), Vector2(0.52, 0.12), Vector2(0.34, 0.56), Vector2(0.12, 0.62), Vector2(-0.12, 0.62), Vector2(-0.34, 0.56), Vector2(-0.52, 0.12)], 0.02, 0.26, Vector2(0.9, 0.9), Vector2(0, -0.02))
	t.color(EU_D, Geo.PAINT)
	t.plan_loft([Vector2(-0.4, -0.78), Vector2(0.4, -0.78), Vector2(0.44, -0.56), Vector2(-0.44, -0.56)], 0.04, 0.24, Vector2(0.95, 0.95))   # bustle
	t.cbox(Vector3(0.34, 0.33, -0.3), Vector3(0.14, 0.1, 0.14), 0.012)   # commander's panoramic sight
	t.cbox(Vector3(-0.3, 0.3, -0.5), Vector3(0.24, 0.08, 0.3), 0.015)   # loitering-munition launcher box
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.34, 0.335, -0.228), Vector3(0.1, 0.05, 0.006))
	t.color(EU_S, Geo.STEEL)
	t.cbox(Vector3(-0.38, 0.3, 0.3), Vector3(0.1, 0.08, 0.12), 0.01)   # gunner's sight
	t.color("#2b2d2c", Geo.DARK)
	for i in 3:
		t.box(Vector3(-0.3 + (i - 1) * 0.07, 0.345, -0.5), Vector3(0.05, 0.006, 0.26))
	U()._smoke(t, Vector3(0.44, 0.16, 0.28), 30.0)
	U()._smoke(t, Vector3(-0.44, 0.16, 0.28), -30.0)
	V4._antenna(t, Vector3(-0.36, 0.26, -0.7), 0.6)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.14, -0.785), Vector3(0.6, 0.05, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	U()._barrel(piv, root, mat, Vector3(0, 0.14, 0.62), func(b) -> void:
		b.color(EU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, -0.02), Vector3(0.18, 0.16, 0.12), 0.02)   # mantlet
		b.color(EU, Geo.PAINT)
		b.gun(0.04, 1.3, 0.055, 0.044, 0.55, false, 10)   # 130 mm, fume extractor, no brake
		b.color(EU_S, Geo.STEEL)
		b.tube(Vector3(0, 0.06, 1.28), Vector3(0, 0.06, 1.3), 0.012, 4))   # muzzle reference
	U()._vfinish(root, model, h, mat, "brennus", [t], 1.6, "eu")

# ------------------------------------------------------------------ Tiger-style attack helicopter (kestrel.tscn)
static func _tiger() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.2, "recoil": 0.02, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var S = V8()
	# slim rounded tandem fuselage (narrower and smoother than the US gunship), short tail boom
	h.color(EU_D, Geo.PAINT)
	h.xloft([[0.78, K.sect(0.22, 0.27, 0.32, 0.03, 0.05, 0.03, 0.015)], [0.6, K.sect(0.15, 0.25, 0.38, 0.08, 0.1, 0.07, 0.03)],
		[0.2, K.sect(0.13, 0.25, 0.44, 0.1, 0.12, 0.09, 0.04)], [-0.28, K.sect(0.14, 0.27, 0.48, 0.12, 0.14, 0.1, 0.05)],
		[-0.5, K.sect(0.24, 0.3, 0.44, 0.07, 0.08, 0.06, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)   # tandem canopy, both seats under one long stepped glazing
	h.xloft([[0.64, K.sect(0.33, 0.34, 0.37, 0.06, 0.065, 0.05, 0.012)], [0.46, K.sect(0.33, 0.37, 0.46, 0.085, 0.09, 0.06, 0.025)],
		[0.24, K.sect(0.4, 0.43, 0.54, 0.085, 0.09, 0.06, 0.025)], [0.02, K.sect(0.42, 0.45, 0.54, 0.08, 0.085, 0.06, 0.02)], [-0.04, K.sect(0.44, 0.46, 0.5, 0.06, 0.065, 0.05, 0.01)]])
	h.color(EU_S, Geo.PAINT)
	h.box(Vector3(0, 0.47, 0.3), Vector3(0.13, 0.012, 0.015))
	# engine humps either side of the mast, exhausts angled up and out
	for s in [-1.0, 1.0]:
		h.color(EU, Geo.PAINT)
		h.tube(Vector3(s * 0.13, 0.48, 0.02), Vector3(s * 0.13, 0.48, -0.36), 0.065, 8, 0.05)
		h.color(EU_S, Geo.STEEL)
		h.plate(Vector3(s * 0.16, 0.52, -0.38), Vector3(0.06, 0.06, 0.1), Vector3(-30, 0, s * 30.0))
	h.color(EU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.54, -0.1), Vector3(0, 0.72, -0.1), 0.03, 6)
	h.color("#5a5e55", Geo.PAINT)   # mast-mounted sight ball
	h.ccyl(0.06, 0.08, 0.02, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.78, -0.1)))
	h.color(GLASS_C, Geo.GLASS)
	h.box(Vector3(0, 0.82, -0.04), Vector3(0.06, 0.04, 0.006))
	# tail boom, H-tail with end plates, fin with tail rotor
	h.color(EU_D, Geo.PAINT)
	h.tube(Vector3(0, 0.36, -0.48), Vector3(0, 0.42, -1.22), 0.075, 8, 0.04)
	S._surf(h, [Vector3(0, 0.42, -1.08), Vector3(0, 0.74, -1.22), Vector3(0, 0.74, -1.32), Vector3(0, 0.42, -1.3)], Vector3(1, 0, 0), 0.03, 0.02)
	S._surf(h, [Vector3(-0.26, 0.42, -1.1), Vector3(0.26, 0.42, -1.1), Vector3(0.26, 0.42, -1.2), Vector3(-0.26, 0.42, -1.2)], Vector3(0, 1, 0), 0.02, 0.012)
	for s in [-1.0, 1.0]:
		S._surf(h, [Vector3(s * 0.26, 0.36, -1.08), Vector3(s * 0.26, 0.5, -1.12), Vector3(s * 0.26, 0.5, -1.2), Vector3(s * 0.26, 0.36, -1.2)], Vector3(1, 0, 0), 0.012, 0.008)
	# stub wings: inner rocket pods, outer anti-tank missile quads, wingtip AAMs
	for s in [-1.0, 1.0]:
		h.color(EU, Geo.PAINT)
		S._surf(h, [Vector3(s * 0.1, 0.36, 0.06), Vector3(s * 0.5, 0.36, 0.04), Vector3(s * 0.5, 0.36, -0.08), Vector3(s * 0.1, 0.36, -0.14)], Vector3(0, 1, 0), 0.03, 0.02)
		h.color("#5a5e55", Geo.PAINT)
		h.tube(Vector3(s * 0.26, 0.26, 0.12), Vector3(s * 0.26, 0.26, -0.18), 0.05, 8)
		h.color("#1d1f1e", Geo.DARK)
		h.tube(Vector3(s * 0.26, 0.26, 0.121), Vector3(s * 0.26, 0.26, 0.13), 0.04, 8)
		h.color("#4a4e44", Geo.PAINT)
		for k in 4:
			var mx: float = s * (0.4 + 0.055 * float(k % 2))
			var my := 0.29 - 0.05 * float(k / 2)
			h.tube(Vector3(mx, my, 0.1), Vector3(mx, my, -0.2), 0.02, 6)
		h.color(EU_S, Geo.STEEL)
		h.tube(Vector3(s * 0.52, 0.36, 0.08), Vector3(s * 0.52, 0.36, -0.12), 0.014, 5)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.135, 0.3, -0.1), Vector3(0.006, 0.05, 0.3))
	h.box(Vector3(0, 0.6, -1.24), Vector3(0.04, 0.08, 0.06))
	S._gear(h, [Vector3(-0.18, 0.0, 0.3), Vector3(0.18, 0.0, 0.3), Vector3(0, 0.0, -1.1)], 0.045)
	S._rotor(model, root, mat, "Rotor", Vector3(0, 0.7, -0.1), 1.4, 4)
	S._rotor(model, root, mat, "TailRotor", Vector3(0.05, 0.6, -1.28), 0.3, 3, true)
	# chin turret for the gun pod / targeting (TurretPivot, as on the US gunship)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.14, 0.52))
	var t = K.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.055, 0.045, 0.06, 8, Transform3D.IDENTITY)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, -0.02, 0.04), func(b) -> void:
		b.color(EU_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, 0.02), Vector3(0.07, 0.06, 0.1), 0.012)
		b.gun(0.06, 0.3, 0.016, 0.012, -1.0, false, 6))
	U()._vfinish(root, model, h, mat, "kestrel", [t, b], 1.2, "eu")

# ------------------------------------------------------------------ Multirole fighter (corvid.tscn)
## Canard delta, twin engines, a big chin intake split in two, single fin. Grey (camo pattern 0).
static func _fighter() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.0, "recoil": 0.0, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var S = V8()
	h.color(AIR, Geo.PAINT)
	h.xloft([[1.02, K.sect(0.24, 0.245, 0.25, 0.003, 0.008, 0.003, 0.0)], [0.66, K.sect(0.18, 0.24, 0.31, 0.04, 0.07, 0.05, 0.015)],
		[0.2, K.sect(0.16, 0.23, 0.32, 0.09, 0.12, 0.08, 0.03)], [-0.6, K.sect(0.16, 0.22, 0.3, 0.13, 0.15, 0.1, 0.03)], [-0.84, K.sect(0.17, 0.22, 0.27, 0.12, 0.13, 0.09, 0.02)]])
	h.color("#5a6a78", Geo.GLASS)
	h.xloft([[0.74, K.sect(0.3, 0.305, 0.315, 0.025, 0.03, 0.025, 0.004)], [0.6, K.sect(0.29, 0.31, 0.38, 0.045, 0.05, 0.034, 0.016)],
		[0.42, K.sect(0.29, 0.31, 0.37, 0.045, 0.05, 0.034, 0.016)], [0.3, K.sect(0.3, 0.31, 0.32, 0.02, 0.025, 0.02, 0.004)]])
	h.color(AIR_D, Geo.PAINT)   # chin intake (split box)
	h.xloft([[0.36, K.sect(0.07, 0.1, 0.17, 0.1, 0.11, 0.1, 0.02)], [-0.1, K.sect(0.08, 0.11, 0.18, 0.11, 0.12, 0.1, 0.02)]])
	h.color("#1d1f1e", Geo.DARK)
	for x in [-0.05, 0.05]:
		h.box(Vector3(x, 0.115, 0.362), Vector3(0.08, 0.07, 0.008))
	for s in [-1.0, 1.0]:
		h.color(AIR_D, Geo.PAINT)
		S._surf(h, [Vector3(s * 0.1, 0.24, 0.62), Vector3(s * 0.3, 0.24, 0.48), Vector3(s * 0.3, 0.24, 0.42), Vector3(s * 0.1, 0.24, 0.46)], Vector3(0, 1, 0), 0.015, 0.006)   # canards
		S._surf(h, [Vector3(s * 0.12, 0.2, 0.22), Vector3(s * 0.74, 0.19, -0.56), Vector3(s * 0.74, 0.19, -0.66), Vector3(s * 0.12, 0.2, -0.7)], Vector3(0, 1, 0), 0.045, 0.01)   # delta wing
		h.color("#5d6250", Geo.PAINT)
		h.tube(Vector3(s * 0.5, 0.13, -0.2), Vector3(s * 0.5, 0.13, -0.5), 0.017, 6)   # AAM
		h.tube(Vector3(s * 0.3, 0.11, 0.0), Vector3(s * 0.3, 0.11, -0.32), 0.03, 8)   # guided bomb
		h.color(EU_S, Geo.STEEL)
		h.tube(Vector3(s * 0.75, 0.19, -0.3), Vector3(s * 0.75, 0.19, -0.62), 0.014, 5)   # wingtip pods
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.48, 0.205, -0.45), Vector3(0.14, 0.01, 0.08))
		h.color(EU_S, Geo.STEEL)
		h.tube(Vector3(s * 0.07, 0.22, -0.84), Vector3(s * 0.07, 0.22, -0.98), 0.055, 10, 0.048)
		h.color("#ff7a2a", Geo.LAMP)
		h.tube(Vector3(s * 0.07, 0.22, -0.98), Vector3(s * 0.07, 0.22, -0.985), 0.04, 10)
	h.color(AIR_D, Geo.PAINT)
	S._surf(h, [Vector3(0, 0.3, -0.38), Vector3(0, 0.66, -0.72), Vector3(0, 0.66, -0.82), Vector3(0, 0.3, -0.84)], Vector3(1, 0, 0), 0.025, 0.01)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.58, -0.75), Vector3(0.03, 0.06, 0.1))
	S._gear(h, [Vector3(0, 0.0, 0.48), Vector3(-0.16, 0.0, -0.22), Vector3(0.16, 0.0, -0.22)], 0.04)
	U()._vfinish(root, model, h, mat, "corvid", [], 1.0, "eu")
