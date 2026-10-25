extends RefCounted
## M3.0 "F. Russia" (internal faction id ecc; tool-time only). Original procedural models that
## resemble real Russian equipment; no brand names in game text. Green paint, camo pattern 0.
## Malachi's units:
##   T-90M (t90)        - MBT, welded turret with ERA wedges, 125 mm gun, RWS
##   Tiger-M (tigr)     - armoured 4x4, long rounded bonnet, roof 12.7 mm gun
##   BTR (btr)          - BTR-82A-style 8x8 APC, wedge nose, small 30 mm turret
##   Typhoon (typhoon)  - heavy 6x6 MRAP, armoured cab and troop module, remote gun
##   2S Msta (msta)     - 2S19-style tracked SPG, big box turret, 152 mm gun
##   Zeus (zeus)        - ZSU-23-4-style tracked AA, wide turret, quad 23 mm, radar dish
## Engineer and cargo truck (kept, polished in M3.2): engineer (tracked engineering vehicle with blade and
## crane), cargo_truck (6x6 bonneted cargo truck), and the buildings hq / power / depot /
## barracks / factory / bunker / aa_site.
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const RU := "#5b6442"
const RU_D := "#474f34"
const RU_L := "#6a7350"
const RU_S := "#3a3d38"
const ERA := "#525b3b"
const GLASS_C := "#2a3a46"
const CON := "#a9a598"
const CON_D := "#8f8b7f"
const Y0 := 0.08

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func V8():
	return load("res://tools/gfx_m7/us_v8.gd")

static func jobs() -> Dictionary:
	return {
		"ecc_t90": func() -> void: _t90(),
		"ecc_tigr": func() -> void: _tigr(),
		"ecc_btr": func() -> void: _btr(),
		"ecc_typhoon": func() -> void: _typhoon(),
		"ecc_msta": func() -> void: _msta(),
		"ecc_zeus": func() -> void: _zeus(),
		"ecc_engineer": func() -> void: _engineer(),
		"ecc_cargo_truck": func() -> void: _cargo_truck(),
		"ecc_hq": func() -> void: U()._make("hq", Vector2(4, 4), 1.9, _hq, Callable(), Vector3.ZERO, "ecc"),
		"ecc_power": func() -> void: U()._make("power", Vector2(3, 3), 2.1, _power, Callable(), Vector3.ZERO, "ecc"),
		"ecc_depot": func() -> void: U()._make("depot", Vector2(3, 3), 1.3, _depot, Callable(), Vector3.ZERO, "ecc"),
		"ecc_barracks": func() -> void: U()._make("barracks", Vector2(3, 3), 1.3, _barracks, Callable(), Vector3.ZERO, "ecc"),
		"ecc_factory": func() -> void: U()._make("factory", Vector2(4, 4), 1.6, _factory, Callable(), Vector3.ZERO, "ecc"),
		"ecc_bunker": func() -> void: U()._make("bunker", Vector2(2, 2), 0.9, _bunker, _bunker_turret, Vector3(0, 0.5, 0), "ecc"),
		"ecc_aa_site": func() -> void: U()._make("aa_site", Vector2(2, 2), 1.0, _aa_site, _aa_turret, Vector3(0, 0.3, 0), "ecc"),
	}

static func _team_stripe(h, x: float, y: float, z: float, l: float) -> void:
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * x, y, z), Vector3(0.006, 0.03, l))

## Low tracked hull (T-72/T-90 family): sloped glacis, flat deck, side fenders with stowage boxes.
static func _mbt_hull(h, hw: float, l: float, n: int) -> void:
	h.track_run(hw - 0.12, l, n, 0.1, 0.26, RU_S)
	var hl := l * 0.5
	h.color(RU_D, Geo.PAINT)
	h.xloft([[hl, K.sect(0.2, 0.26, 0.32, hw - 0.28, hw - 0.22, hw - 0.2, 0.0)], [hl - 0.2, K.sect(0.13, 0.2, 0.34, hw - 0.22, hw - 0.18, hw - 0.18, 0.0)], [-hl + 0.02, K.sect(0.13, 0.2, 0.34, hw - 0.22, hw - 0.18, hw - 0.18, 0.0)]])
	h.color(RU, Geo.PAINT)
	h.xloft([[hl + 0.04, K.sect(0.32, 0.34, 0.37, hw - 0.04, hw - 0.02, hw - 0.1, 0.012)], [hl - 0.32, K.sect(0.32, 0.36, 0.47, hw, hw, hw - 0.04, 0.015)],
		[-hl + 0.02, K.sect(0.32, 0.36, 0.47, hw, hw, hw - 0.04, 0.015)], [-hl - 0.02, K.sect(0.32, 0.36, 0.44, hw, hw, hw - 0.06, 0.015)]])
	h.color(RU_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for i in 3:
			h.cbox(Vector3(s * (hw - 0.1), 0.5, -hl + 0.25 + i * 0.28), Vector3(0.16, 0.06, 0.24), 0.01)   # fender stowage bins
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.472, -hl + 0.28), hw * 1.1, 0.36, 7)
	V4._lamps(h, hw - 0.18, 0.42, hl + 0.03)
	h.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.25, 0.3, -hl - 0.02), Vector3(s * 0.25, 0.42, -hl - 0.08), 0.06, 8)   # rear fuel drums (unditching log mounts)
	h.color("#6b5236", Geo.WOOD)
	h.tube(Vector3(-hw + 0.1, 0.5, -hl - 0.06), Vector3(hw - 0.1, 0.5, -hl - 0.06), 0.045, 6)   # unditching log

## ERA brick row on an angled plate.
static func _era_row(h, c: Vector3, n: int, step: Vector3, s: Vector3, deg: Vector3) -> void:
	h.color(ERA, Geo.PAINT)
	for i in n:
		h.rcbox(c + step * (i - (n - 1) * 0.5), s, 0.006, deg)

# ------------------------------------------------------------------ T-90M
static func _t90() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.5, "recoil": 0.18, "wreck_s": 9.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_mbt_hull(h, 0.68, 1.9, 6)
	_era_row(h, Vector3(0, 0.41, 0.88), 6, Vector3(0.2, 0, 0), Vector3(0.18, 0.04, 0.2), Vector3(-14, 0, 0))   # glacis ERA
	for s in [-1.0, 1.0]:
		for i in 4:   # skirt ERA at the front, rubber skirt behind
			h.color(ERA if i < 2 else RU_D, Geo.PAINT)
			h.plate(Vector3(s * 0.7, 0.33, 0.7 - i * 0.42), Vector3(0.04, 0.2 if i < 2 else 0.14, 0.4), Vector3(0, 0, -s * 3.0))
	_team_stripe(h, 0.72, 0.4, -0.3, 0.9)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.47, 0.05))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cyl(0.42, 0.42, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	# welded turret: low, wide, faceted cheeks, flat roof, large rear stowage box
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.4, -0.46), Vector2(0.4, -0.46), Vector2(0.5, 0.0), Vector2(0.4, 0.36), Vector2(0.12, 0.46), Vector2(-0.12, 0.46), Vector2(-0.4, 0.36), Vector2(-0.5, 0.0)], 0.02, 0.24, Vector2(0.86, 0.86))
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.15, -0.6), Vector3(0.78, 0.18, 0.22), 0.015)   # bustle stowage box (slat armour behind)
	for s in [-1.0, 1.0]:   # Relikt wedges on the turret front
		_era_row(t, Vector3(s * 0.28, 0.2, 0.42), 2, Vector3(s * 0.16, 0, -0.06), Vector3(0.15, 0.1, 0.12), Vector3(-30, s * 25.0, 0))
	_era_row(t, Vector3(0, 0.27, 0.15), 4, Vector3(0.18, 0, 0), Vector3(0.16, 0.03, 0.24), Vector3(0, 0, 0))   # roof ERA
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(-0.28, 0.3, -0.1), Vector3(0.14, 0.1, 0.14), 0.012)   # commander's sight
	t.cbox(Vector3(0.22, 0.3, 0.12), Vector3(0.12, 0.08, 0.14), 0.01)    # gunner's sight
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.28, 0.31, -0.028), Vector3(0.1, 0.05, 0.006))
	t.box(Vector3(0.22, 0.305, 0.192), Vector3(0.09, 0.04, 0.006))
	t.color(RU_S, Geo.STEEL)   # remote 7.62 mm on the commander's hatch
	t.cbox(Vector3(-0.28, 0.38, -0.25), Vector3(0.1, 0.06, 0.12), 0.01)
	t.tube(Vector3(-0.28, 0.4, -0.2), Vector3(-0.28, 0.4, 0.1), 0.012, 6)
	for s in [-1.0, 1.0]:
		for k in 3:
			t.color(RU_S, Geo.STEEL)
			t.tube(Vector3(s * (0.36 + k * 0.03), 0.22, 0.16 - k * 0.07), Vector3(s * (0.42 + k * 0.03), 0.27, 0.22 - k * 0.07), 0.022, 6)   # smoke grenade tubes
	V4._antenna(t, Vector3(0.3, 0.26, -0.5), 0.6)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.15, -0.712), Vector3(0.5, 0.05, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	U()._barrel(piv, root, mat, Vector3(0, 0.13, 0.46), func(b) -> void:
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, -0.02), Vector3(0.16, 0.13, 0.1), 0.015)
		b.color(RU, Geo.PAINT)
		b.gun(0.03, 1.25, 0.05, 0.04, 0.6, false, 10)   # 125 mm with thermal sleeve and fume extractor
		b.color(RU_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 1.22), Vector3(0, 0, 1.26), 0.043, 10))
	U()._vfinish(root, model, h, mat, "t90", [t], 1.5, "ecc")

# ------------------------------------------------------------------ Tiger-M (armoured 4x4)
static func _tigr() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.25, "recoil": 0.02, "wreck_s": 6.5, "steer_max": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.4, [0.5, -0.46], 0.17, 0.14, 1, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, 0.0), Vector3(0.6, 0.1, 1.4), 0.02)
	# long rounded bonnet with a big vertical grille, slab-sided cabin, flat roof
	h.color(RU, Geo.PAINT)
	h.xloft([[0.82, K.sect(0.32, 0.4, 0.5, 0.36, 0.38, 0.3, 0.05)], [0.66, K.sect(0.3, 0.42, 0.58, 0.44, 0.45, 0.38, 0.05)], [0.34, K.sect(0.3, 0.42, 0.62, 0.45, 0.46, 0.42, 0.04)]])
	var c0 := K.sect(0.3, 0.42, 0.92, 0.46, 0.46, 0.4, 0.035)
	h.xloft([[0.34, K.sect(0.3, 0.42, 0.66, 0.46, 0.46, 0.42, 0.035)], [0.3, c0], [-0.72, c0], [-0.76, K.sect(0.3, 0.42, 0.9, 0.45, 0.45, 0.39, 0.035)]])
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.44, 0.83), 0.4, 0.14, 7)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.2, 0.2]:
		h.plate(Vector3(x, 0.78, 0.33), Vector3(0.34, 0.2, 0.008), Vector3(-20, 0, 0))   # two-piece windscreen
	for s in [-1.0, 1.0]:
		for z in [0.1, -0.3]:
			h.box(Vector3(s * 0.463, 0.76, z), Vector3(0.006, 0.14, 0.26))   # small armoured side windows
		h.color(RU_D, Geo.PAINT)
		for z in [0.5, -0.46]:
			h.prism_x([Vector2(z - 0.21, 0.35), Vector2(z + 0.21, 0.35), Vector2(z + 0.17, 0.48), Vector2(z - 0.17, 0.48)], s * 0.4, s * 0.48)
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.468, 0.62, -0.05), Vector3(0.008, 0.02, 0.06))
		h.color(GLASS_C, Geo.GLASS)
	h.color(RU_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.36, 0.86), Vector3(0.7, 0.07, 0.05), 0.01)   # bull bar
	h.tyre(Vector3(0, 0.62, -0.79), 0.16, 0.08, false, RU_S, 12)    # spare wheel on the rear door
	V4._lamps(h, 0.3, 0.5, 0.83)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.38, 0.38]:
		h.box(Vector3(x, 0.5, -0.765), Vector3(0.04, 0.03, 0.008))
	_team_stripe(h, 0.462, 0.56, -0.2, 0.8)
	V4._antenna(h, Vector3(-0.36, 0.92, -0.6), 0.55)
	# roof hatch ring with the 12.7 mm gun (TurretPivot)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.93, -0.25))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.ccyl(0.16, 0.05, 0.01, 12, Transform3D.IDENTITY)
	t.color(RU_D, Geo.PAINT)
	t.plate(Vector3(0, 0.13, 0.12), Vector3(0.3, 0.16, 0.025), Vector3(-10, 0, 0))   # gun shield
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.16, 0.02), func(b) -> void:
		b.color(RU_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, -0.04), Vector3(0.07, 0.08, 0.2), 0.01)
		b.gun(0.06, 0.48, 0.016, 0.013, -1.0, true, 6)
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(0.07, -0.02, -0.02), Vector3(0.06, 0.07, 0.1), 0.008))   # ammo box
	U()._vfinish(root, model, h, mat, "tigr", [t, b], 1.25, "ecc")

# ------------------------------------------------------------------ BTR (BTR-82A-style 8x8)
static func _btr() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.9, "bar_height": 1.3, "recoil": 0.03, "wreck_s": 7.5, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.47, [0.68, 0.3, -0.3, -0.68], 0.17, 0.14, 2, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, -0.02), Vector3(0.7, 0.12, 1.9), 0.02)
	# boat hull: sharp wedge nose, sloped upper sides, flat roof, sloped rear
	h.color(RU, Geo.PAINT)
	h.xloft([[1.06, K.sect(0.34, 0.36, 0.38, 0.12, 0.16, 0.14, 0.01)], [0.86, K.sect(0.28, 0.42, 0.52, 0.42, 0.52, 0.4, 0.02)], [0.6, K.sect(0.28, 0.44, 0.66, 0.5, 0.56, 0.42, 0.02)],
		[-0.8, K.sect(0.28, 0.44, 0.66, 0.5, 0.56, 0.42, 0.02)], [-1.0, K.sect(0.32, 0.44, 0.58, 0.46, 0.52, 0.38, 0.02)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.22, 0.22]:
		h.plate(Vector3(x, 0.6, 0.74), Vector3(0.22, 0.08, 0.008), Vector3(-55, 0, 0))   # driver / commander vision blocks
	h.color(RU_D, Geo.PAINT)
	for x in [-0.22, 0.22]:
		h.hatch(Vector3(x, 0.665, 0.5), 0.12)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.5, 0.48, 0.0), Vector3(0.02, 0.18, 0.2), Vector3(0, 0, -s * 30.0))   # side door between axles 2 and 3
		h.color(RU_S, Geo.STEEL)
		for z in [0.5, 0.1, -0.2, -0.55]:
			h.box(Vector3(s * 0.54, 0.43, z), Vector3(0.02, 0.025, 0.04))   # firing ports
		h.color(RU_D, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.665, -0.6), 0.6, 0.4, 6)
	V4._lamps(h, 0.28, 0.46, 0.92)
	_team_stripe(h, 0.52, 0.5, -0.3, 0.9)
	V4._antenna(h, Vector3(0.36, 0.66, -0.8), 0.6)
	V4._antenna(h, Vector3(-0.36, 0.66, -0.8), 0.6)
	# small conical turret with 30 mm cannon and coaxial MG, smoke tubes
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.66, 0.2))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.cyl(0.22, 0.17, 0.16, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)))
	t.color(RU_D, Geo.PAINT)
	t.cyl(0.16, 0.1, 0.05, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.185, 0)))
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0.12, 0.24, 0.0), Vector3(0.08, 0.07, 0.08), 0.008)   # sight
	for s in [-1.0, 1.0]:
		for k in 3:
			t.tube(Vector3(s * 0.18, 0.12 + k * 0.035, -0.08), Vector3(s * 0.22, 0.15 + k * 0.035, -0.12), 0.016, 6)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.09, -0.212), Vector3(0.2, 0.035, 0.008))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.1, 0.16), func(b) -> void:
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, 0.0), Vector3(0.12, 0.08, 0.08), 0.01)
		b.color(RU_S, Geo.STEEL)
		b.gun(0.04, 0.68, 0.022, 0.016, -1.0, true, 8)   # 30 mm
		b.tube(Vector3(0.07, 0.0, 0.04), Vector3(0.07, 0.0, 0.32), 0.009, 5))   # coaxial PKT
	U()._vfinish(root, model, h, mat, "btr", [t, b], 1.3, "ecc")

# ------------------------------------------------------------------ Typhoon (heavy 6x6 MRAP)
static func _typhoon() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.55, "recoil": 0.02, "wreck_s": 8.0, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.44, [0.68, -0.32, -0.74], 0.2, 0.15, 1, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.36, -0.02), Vector3(0.58, 0.1, 2.0), 0.02)
	h.prism_x([Vector2(-0.9, 0.42), Vector2(0.4, 0.42), Vector2(0.2, 0.28), Vector2(-0.7, 0.28)], -0.36, 0.36)   # V-shaped belly plate
	# armoured cab: short bonnet, tall flat front with three armoured windows
	h.color(RU, Geo.PAINT)
	h.xloft([[1.02, K.sect(0.42, 0.48, 0.62, 0.42, 0.44, 0.4, 0.03)], [0.86, K.sect(0.42, 0.5, 0.7, 0.48, 0.5, 0.46, 0.03)]])
	var c0 := K.sect(0.42, 0.52, 1.12, 0.52, 0.52, 0.46, 0.03)
	h.xloft([[0.86, K.sect(0.42, 0.52, 1.06, 0.52, 0.52, 0.46, 0.03)], [0.78, c0], [0.36, c0], [0.34, K.sect(0.42, 0.52, 1.1, 0.51, 0.51, 0.45, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.3, 0.0, 0.3]:
		h.plate(Vector3(x, 0.9, 0.84), Vector3(0.26, 0.2, 0.008), Vector3(-8, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.523, 0.9, 0.58), Vector3(0.006, 0.16, 0.24))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.63, 1.025), 0.6, 0.06, 7)
	# troop module: tall box with small windows, rear ramp door, side steps
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.82, -0.42), Vector3(1.04, 0.78, 1.0), 0.04)
	h.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		for z in [-0.12, -0.42, -0.72]:
			h.box(Vector3(s * 0.523, 0.95, z), Vector3(0.006, 0.12, 0.14))
		h.color(RU_D, Geo.PAINT)
		for z in [0.68, -0.32, -0.74]:
			h.prism_x([Vector2(z - 0.24, 0.42), Vector2(z + 0.24, 0.42), Vector2(z + 0.2, 0.56), Vector2(z - 0.2, 0.56)], s * 0.42, s * 0.53)
		h.color(GLASS_C, Geo.GLASS)
	h.color(RU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.78, -0.935), Vector3(0.6, 0.6, 0.03), Vector3.ZERO)   # rear door
	h.color(RU_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.38, -1.0), Vector3(0.5, 0.05, 0.1), 0.01)   # step
	h.cbox(Vector3(0, 0.46, 1.04), Vector3(0.84, 0.07, 0.05), 0.01)   # bumper
	V4._lamps(h, 0.36, 0.58, 1.02)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.44, 0.44]:
		h.box(Vector3(x, 0.5, -0.935), Vector3(0.04, 0.03, 0.008))
	_team_stripe(h, 0.522, 0.7, -0.42, 0.9)
	V4._antenna(h, Vector3(0.42, 1.12, 0.4), 0.55)
	V4._antenna(h, Vector3(-0.42, 1.21, -0.85), 0.5)
	# remote weapon station on the module roof
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.0, 1.21, -0.3))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.ccyl(0.12, 0.04, 0.01, 10, Transform3D.IDENTITY)
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.1, 0.0), Vector3(0.2, 0.14, 0.2), 0.015)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.12, 0.08), func(b) -> void:
		b.color(RU_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, 0.0), Vector3(0.08, 0.08, 0.16), 0.01)
		b.gun(0.08, 0.46, 0.016, 0.013, -1.0, true, 6)
		b.color(GLASS_C, Geo.GLASS)
		b.box(Vector3(-0.08, 0.02, 0.06), Vector3(0.05, 0.05, 0.04)))   # sight head
	U()._vfinish(root, model, h, mat, "typhoon", [t, b], 1.55, "ecc")

# ------------------------------------------------------------------ 2S Msta (2S19-style SPG)
static func _msta() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.7, "recoil": 0.12, "wreck_s": 9.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_mbt_hull(h, 0.68, 2.0, 6)
	_team_stripe(h, 0.69, 0.4, 0.2, 1.0)
	# large box turret set back, ammunition hatches, commander's cupola with MG
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.47, -0.2))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cyl(0.44, 0.44, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.6, -0.7), Vector2(0.6, -0.7), Vector2(0.6, 0.34), Vector2(0.42, 0.56), Vector2(-0.42, 0.56), Vector2(-0.6, 0.34)], 0.02, 0.5, Vector2(0.95, 0.95))
	t.color(RU_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.585, 0.26, -0.2), Vector3(0.02, 0.22, 0.4), Vector3.ZERO)   # side ammo hatches
	t.cbox(Vector3(0, 0.3, -0.73), Vector3(0.5, 0.3, 0.06), 0.01)   # rear ammo conveyor door
	t.color(RU_S, Geo.STEEL)
	t.ccyl(0.12, 0.06, 0.01, 12, Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.52, -0.25)))   # cupola
	t.tube(Vector3(-0.3, 0.62, -0.2), Vector3(-0.3, 0.62, 0.15), 0.014, 6)   # 12.7 mm
	t.cbox(Vector3(0.3, 0.55, 0.1), Vector3(0.12, 0.08, 0.14), 0.01)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.3, 0.555, 0.172), Vector3(0.09, 0.04, 0.006))
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(0.0, 0.525, -0.45), 0.14)
	for s in [-1.0, 1.0]:
		for k in 3:
			t.color(RU_S, Geo.STEEL)
			t.tube(Vector3(s * 0.5, 0.32 + k * 0.05, 0.44), Vector3(s * 0.56, 0.36 + k * 0.05, 0.5), 0.022, 6)
	V4._antenna(t, Vector3(0.45, 0.5, -0.6), 0.6)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.38, -0.765), Vector3(0.7, 0.05, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	U()._barrel(piv, root, mat, Vector3(0, 0.28, 0.56), func(b) -> void:
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, -0.02), Vector3(0.22, 0.2, 0.14), 0.015)   # mantlet
		b.color(RU, Geo.PAINT)
		b.gun(0.04, 1.55, 0.05, 0.042, 0.8, true, 10))   # 152 mm, fume extractor, muzzle brake
	U()._vfinish(root, model, h, mat, "msta", [t], 1.7, "ecc")

# ------------------------------------------------------------------ Zeus (ZSU-23-4-style)
static func _zeus() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.45, "recoil": 0.03, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.5, 1.6, 6, 0.08, 0.2, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[0.8, K.sect(0.2, 0.25, 0.3, 0.3, 0.36, 0.38, 0.0)], [0.62, K.sect(0.13, 0.2, 0.32, 0.36, 0.38, 0.38, 0.0)], [-0.8, K.sect(0.13, 0.2, 0.32, 0.36, 0.38, 0.38, 0.0)]])
	h.color(RU, Geo.PAINT)
	h.xloft([[0.84, K.sect(0.3, 0.32, 0.34, 0.54, 0.56, 0.5, 0.01)], [0.5, K.sect(0.3, 0.34, 0.44, 0.6, 0.6, 0.56, 0.015)], [-0.82, K.sect(0.3, 0.34, 0.44, 0.6, 0.6, 0.56, 0.015)]])
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.442, -0.6), 0.8, 0.3, 6)
	h.color(RU_D, Geo.PAINT)
	h.hatch(Vector3(-0.3, 0.445, 0.62), 0.12)
	V4._lamps(h, 0.4, 0.38, 0.84)
	_team_stripe(h, 0.605, 0.38, 0.0, 1.0)
	# wide flat box turret, quad guns in the front, radar dish on a folding mast at the rear
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.44, 0.02))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.56, -0.52), Vector2(0.56, -0.52), Vector2(0.58, 0.3), Vector2(0.48, 0.46), Vector2(-0.48, 0.46), Vector2(-0.58, 0.3)], 0.0, 0.3, Vector2(0.94, 0.92))
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.33, -0.15), Vector3(0.5, 0.06, 0.4), 0.01)
	t.hatch(Vector3(-0.2, 0.37, -0.15), 0.11)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.3, -0.42), Vector3(0, 0.62, -0.42), 0.03, 6)   # radar mast
	t.color(RU_L, Geo.PAINT)
	t.cyl(0.24, 0.2, 0.06, 14, Transform3D(Basis(Vector3.RIGHT, -PI * 0.42), Vector3(0, 0.7, -0.44)))   # RPK-2-style dish
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.7, -0.4), Vector3(0, 0.72, -0.24), 0.012, 4)   # feed horn
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.16, -0.523), Vector3(0.6, 0.05, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U()._barrel(piv, root, mat, Vector3(0, 0.18, 0.4), func(b) -> void:
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, -0.02), Vector3(0.6, 0.18, 0.12), 0.015)   # gun cradle
		b.color(RU_S, Geo.STEEL)
		for i in 4:
			var o := Vector3([-0.24, -0.14, 0.14, 0.24][i], 0.035 if i % 2 == 0 else -0.035, 0)
			b.tube(o + Vector3(0, 0, 0.04), o + Vector3(0, 0, 0.62), 0.014, 6)   # 23 mm barrels
			b.tube(o + Vector3(0, 0, 0.12), o + Vector3(0, 0, 0.3), 0.022, 6)   # barrel jackets
			b.tube(o + Vector3(0, 0, 0.6), o + Vector3(0, 0, 0.66), 0.02, 6))   # flash hiders
	U()._vfinish(root, model, h, mat, "zeus", [t, b], 1.45, "ecc")

# ------------------------------------------------------------------ Engineer Vehicle (stand-in)
static func _engineer() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.4, "recoil": 0.0, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_mbt_hull(h, 0.62, 1.7, 6)
	# armoured superstructure with vision blocks, crane boom with a grab, dozer blade at the front
	h.color(RU, Geo.PAINT)
	h.plan_loft([Vector2(-0.4, -0.3), Vector2(0.4, -0.3), Vector2(0.42, 0.2), Vector2(0.3, 0.36), Vector2(-0.3, 0.36), Vector2(-0.42, 0.2)], 0.47, 0.72, Vector2(0.88, 0.85))
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.16, 0.0, 0.16]:
		h.plate(Vector3(x, 0.64, 0.33), Vector3(0.1, 0.05, 0.006), Vector3(-30, 0, 0))
	h.color(RU_S, Geo.STEEL)
	h.cyl(0.12, 0.12, 0.08, 10, Transform3D(Basis.IDENTITY, Vector3(0.26, 0.76, -0.2)))   # crane turntable
	h.color(RU_L, Geo.PAINT)
	h.rcbox(Vector3(0.26, 0.96, -0.55), Vector3(0.1, 0.1, 0.8), 0.01, Vector3(-28, 0, 0))   # boom, stowed backwards
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0.26, 1.13, -0.9), Vector3(0.26, 0.9, -0.95), 0.01, 4)
	for x in [0.2, 0.32]:
		h.rbox(Vector3(x, 0.85, -0.97), Vector3(0.02, 0.1, 0.06), Vector3(0, 0, 0))   # grab jaws
	h.tube(Vector3(-0.26, 0.72, -0.3), Vector3(-0.26, 0.9, -0.3), 0.02, 6)   # exhaust
	for s in [-0.34, 0.34]:   # blade push arms + rams
		h.tube(Vector3(s, 0.22, 0.5), Vector3(s, 0.24, 1.0), 0.032, 6)
		h.tube(Vector3(s * 0.8, 0.45, 0.6), Vector3(s * 0.85, 0.3, 0.98), 0.022, 6)
	h.color(RU_D, Geo.PAINT)
	h.prism_x([Vector2(1.0, 0.03), Vector2(1.08, 0.05), Vector2(1.14, 0.2), Vector2(1.14, 0.38), Vector2(1.08, 0.5), Vector2(1.01, 0.48)], -0.7, 0.7)
	h.color(RU_S, Geo.STEEL)
	h.plate(Vector3(0, 0.05, 1.13), Vector3(1.42, 0.04, 0.06), Vector3(20, 0, 0))
	h.color("#ff9a2a", Geo.LAMP)
	h.cbox(Vector3(-0.3, 0.76, 0.15), Vector3(0.05, 0.04, 0.05), 0.01)   # beacon
	_team_stripe(h, 0.63, 0.42, -0.3, 0.8)
	V4._antenna(h, Vector3(-0.35, 0.72, -0.15), 0.5)
	# M3.2 polish: side tool boxes, spare track links on the glacis, rear beacon, tow cable
	h.color(RU_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.5, 0.56, -0.55), Vector3(0.16, 0.1, 0.36), 0.01)
	h.color(RU_S, Geo.STEEL)
	for k in 4:
		h.rcbox(Vector3(-0.3 + k * 0.2, 0.43, 0.8), Vector3(0.16, 0.025, 0.08), 0.004, Vector3(-14, 0, 0))
	h.tube(Vector3(-0.45, 0.5, -0.85), Vector3(0.45, 0.5, -0.85), 0.018, 6)
	h.color("#ff9a2a", Geo.LAMP)
	h.cbox(Vector3(0.3, 0.76, -0.25), Vector3(0.05, 0.04, 0.05), 0.01)
	U()._vfinish(root, model, h, mat, "engineer", [], 1.4, "ecc")

# ------------------------------------------------------------------ Cargo Truck (stand-in, 6x6)
static func _cargo_truck() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.3, "recoil": 0.0, "wreck_s": 7.0, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8()._tyres(h, 0.4, [0.66, -0.3, -0.66], 0.17, 0.14, 1, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.34, -0.02), Vector3(0.46, 0.08, 1.9), 0.015)
	# bonnet in front of the cab with a flat grille, separate mudguards, round-cornered cab
	h.color(RU, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.4, 0.46, 0.56, 0.26, 0.28, 0.24, 0.04)], [0.6, K.sect(0.38, 0.46, 0.62, 0.3, 0.31, 0.28, 0.04)]])
	var c0 := K.sect(0.38, 0.5, 0.92, 0.42, 0.42, 0.38, 0.05)
	h.xloft([[0.6, K.sect(0.38, 0.5, 0.66, 0.42, 0.42, 0.4, 0.04)], [0.56, c0], [0.2, c0], [0.18, K.sect(0.38, 0.5, 0.9, 0.41, 0.41, 0.37, 0.04)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.18, 0.18]:
		h.plate(Vector3(x, 0.8, 0.565), Vector3(0.3, 0.16, 0.008), Vector3(-8, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.423, 0.8, 0.38), Vector3(0.006, 0.14, 0.22))
		h.color(RU_D, Geo.PAINT)
		h.prism_x([Vector2(0.48, 0.4), Vector2(0.88, 0.4), Vector2(0.84, 0.5), Vector2(0.52, 0.5)], s * 0.26, s * 0.42)   # front mudguards
		h.color(RU_S, Geo.STEEL)
		h.tube(Vector3(s * 0.42, 0.78, 0.56), Vector3(s * 0.5, 0.86, 0.56), 0.008, 3)
		h.cbox(Vector3(s * 0.51, 0.88, 0.56), Vector3(0.02, 0.08, 0.04), 0.006)
		h.color(GLASS_C, Geo.GLASS)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.5, 1.005), 0.36, 0.1, 5)
	h.color(RU_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.4, 1.04), Vector3(0.6, 0.06, 0.05), 0.01)
	h.tube(Vector3(-0.32, 0.4, 0.2), Vector3(-0.32, 0.4, -0.05), 0.07, 8)   # fuel tank
	# cargo bed with wooden drop sides and a canvas cover on hoops
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.46, -0.45), Vector3(0.84, 0.06, 1.2), 0.012)
	h.color("#5e5a3e", Geo.WOOD)
	for x in [-0.41, 0.41]:
		h.cbox(Vector3(x, 0.58, -0.45), Vector3(0.03, 0.18, 1.2), 0.006)
	h.cbox(Vector3(0, 0.58, -1.04), Vector3(0.84, 0.18, 0.03), 0.006)
	h.color("#5d6346", Geo.CANVAS)
	h.xloft([[0.14, K.sect(0.66, 0.72, 1.02, 0.42, 0.42, 0.34, 0.08)], [-1.05, K.sect(0.66, 0.72, 1.02, 0.42, 0.42, 0.34, 0.08)]])
	h.color("#4b5036", Geo.CANVAS)
	for z in [-0.1, -0.45, -0.8]:
		h.box(Vector3(0, 1.023, z), Vector3(0.6, 0.01, 0.02))   # hoops showing through
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.43, 0.6, -0.45), Vector3(0.006, 0.04, 0.6))
	V4._lamps(h, 0.24, 0.5, 1.0)
	# M3.2 polish: spare wheel behind the cab, roof hatch, tool box, mud flaps
	h.color(RU_S, Geo.STEEL)
	h.tyre(Vector3(0.0, 0.62, 0.14), 0.15, 0.1, false, RU_S, 12)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.93, 0.36), Vector3(0.22, 0.03, 0.22), 0.008)
	h.cbox(Vector3(0.32, 0.38, -0.2), Vector3(0.12, 0.12, 0.3), 0.01)
	h.color("#1d1c1b", Geo.RUBBER)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.4, 0.2, -0.86), Vector3(0.16, 0.14, 0.01))
	U()._vfinish(root, model, h, mat, "cargo_truck", [], 1.3, "ecc")

# ================================================================== buildings (stand-ins)
static func _ru_flag(g, p: Vector3, hgt: float) -> void:
	g.color("#c9ccce", Geo.STEEL)
	g.tube(p, p + Vector3(0, hgt, 0), 0.01, 4)
	var c := p + Vector3(0.14, hgt - 0.05, 0)
	g.color("#e8e8e4", Geo.PAINT)
	g.box(c + Vector3(0, 0.045, 0), Vector3(0.26, 0.045, 0.01))
	g.color("#2a4fa0", Geo.PAINT)
	g.box(c, Vector3(0.26, 0.045, 0.01))
	g.color("#c0302a", Geo.PAINT)
	g.box(c - Vector3(0, 0.045, 0), Vector3(0.26, 0.045, 0.01))

static func _star(g, c: Vector3, r: float) -> void:
	g.color("#b8352b", Geo.PAINT)
	var pts: Array = []
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(Vector2(cos(a) * rr, sin(a) * rr))
	for i in 10:   # thin fan of triangles as flat boxes is costly; use a prism per spike
		if i % 2 == 0:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 9) % 10]
			var d: Vector2 = pts[(i + 1) % 10]
			g.faces([[c + Vector3(0, 0, 0.004), c + Vector3(b.x, b.y, 0.004), c + Vector3(a.x, a.y, 0.004)], [c + Vector3(0, 0, 0.004), c + Vector3(a.x, a.y, 0.004), c + Vector3(d.x, d.y, 0.004)]])

## Concrete block with flat roof, parapet, windows on +z and -z.
static func _block(g, c: Vector3, s: Vector3, wn: int) -> void:
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, s.y * 0.5, 0), s, 0.03)
	g.color(CON_D, Geo.CONCRETE)
	g.box(c + Vector3(0, s.y + 0.02, 0), Vector3(s.x + 0.02, 0.04, s.z + 0.02))
	g.color("#5f625c", Geo.CONCRETE)
	g.box(c + Vector3(0, s.y + 0.045, 0), Vector3(s.x - 0.06, 0.01, s.z - 0.06))
	if wn > 0:
		for row in int(maxf(1.0, floorf(s.y / 0.42))):
			var y := 0.26 + row * 0.4
			g.windows(c + Vector3(0, y, s.z * 0.5 + 0.004), s.x * 0.8, 0.14, wn)
			g.windows(Vector3(-c.x, c.y + y, -c.z + s.z * 0.5 + 0.004), s.x * 0.8, 0.14, wn, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))   # rear face

static func _hq(g) -> void:
	_block(g, Vector3(-0.2, Y0, -0.3), Vector3(2.6, 0.95, 1.6), 9)
	_block(g, Vector3(0.6, Y0 + 0.95, -0.4), Vector3(1.0, 0.45, 1.0), 3)   # command floor
	g.color("#3a3c3a", Geo.DARK)
	g.box(Vector3(-0.2, Y0 + 0.25, 0.51), Vector3(0.4, 0.42, 0.012))   # entrance
	g.color(RU_D, Geo.PAINT)
	g.prism_x([Vector2(0.5, 0.5), Vector2(0.85, 0.44), Vector2(0.85, 0.47), Vector2(0.5, 0.54)], -0.45, 0.45, Transform3D(Basis.IDENTITY, Vector3(-0.2, Y0, 0)))
	_star(g, Vector3(-0.2, Y0 + 0.72, 0.505), 0.14)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.2, Y0 + 0.92, 0.505), Vector3(2.4, 0.04, 0.01))
	g.color(RU_S, Geo.STEEL)   # lattice comms mast + dish
	for k in 6:
		g.tube(Vector3(0.6, Y0 + 1.45 + k * 0.12, -0.4), Vector3(0.6, Y0 + 1.57 + k * 0.12, -0.4), 0.02 - k * 0.002, 4)
	g.color("#c9c6bc", Geo.PAINT)
	g.cyl(0.16, 0.12, 0.05, 12, Transform3D(Basis(Vector3.RIGHT, -PI * 0.35), Vector3(0.3, Y0 + 1.5, -0.1)))
	_ru_flag(g, Vector3(-1.5, Y0, 0.6), 1.2)
	for k in 6:   # sandbag wall at the gate
		g.sandbag(Vector3(0.9 + (k % 3) * 0.24, Y0 + (k / 3) * 0.07, 1.4), 0.22, 0)
	V4._antenna(g, Vector3(-1.2, Y0 + 0.95, -0.8), 0.5)

static func _power(g) -> void:
	_block(g, Vector3(-0.3, Y0, -0.2), Vector3(1.6, 0.8, 1.4), 5)   # diesel generator hall
	g.color(RU_D, Geo.CORR)
	g.prism_x([Vector2(-0.72, 0.8), Vector2(0.72, 0.8), Vector2(0.0, 1.08)], -1.1, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, Y0, -0.2)))
	g.color(CON_D, Geo.CONCRETE)
	for x in [0.85, 1.15]:   # two tall exhaust stacks with red/white bands
		g.cyl(0.11, 0.08, 1.9, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0, -0.8)))
		g.color("#b8352b", Geo.PAINT)
		g.cyl(0.085, 0.082, 0.12, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 1.72, -0.8)))
		g.color(CON_D, Geo.CONCRETE)
	g.color(RU_S, Geo.STEEL)   # radiator bank with fans
	g.cbox(Vector3(1.0, Y0 + 0.2, 0.3), Vector3(0.7, 0.4, 0.6), 0.02)
	g.color("#2b2d2c", Geo.DARK)
	for x in [0.83, 1.17]:
		for z in [0.15, 0.45]:
			g.cyl(0.12, 0.12, 0.01, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.405, z)))
	g.color("#6a6d68", Geo.STEEL)   # transformer + insulators
	g.cbox(Vector3(-0.6, Y0 + 0.2, 1.05), Vector3(0.5, 0.4, 0.4), 0.02)
	g.color("#c9c6bc", Geo.PAINT)
	for x in [-0.75, -0.6, -0.45]:
		g.tube(Vector3(x, Y0 + 0.4, 1.05), Vector3(x, Y0 + 0.6, 1.05), 0.02, 6)
	g.color(RU_S, Geo.STEEL)
	g.tube(Vector3(0.5, Y0 + 0.6, -0.7), Vector3(0.85, Y0 + 0.6, -0.8), 0.04, 6)   # exhaust duct
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.3, Y0 + 0.74, 0.505), Vector3(1.4, 0.04, 0.01))
	U()._lamp(g, Vector3(1.0, Y0 + 1.92, -0.8))

static func _depot(g) -> void:
	g.color(CON, Geo.CONCRETE)   # loading dock
	g.cbox(Vector3(0, Y0 + 0.1, -0.4), Vector3(2.4, 0.2, 1.4), 0.02)
	g.color(RU_S, Geo.STEEL)   # open shed: posts + green corrugated roof
	for x in [-1.1, 0.0, 1.1]:
		for z in [-1.0, 0.2]:
			g.tube(Vector3(x, Y0 + 0.2, z), Vector3(x, Y0 + 1.0, z), 0.025, 6)
	g.color(RU_D, Geo.CORR)
	g.prism_x([Vector2(-1.15, 0.98), Vector2(0.35, 0.98), Vector2(-0.4, 1.2)], -1.2, 1.2)
	var cols := ["#7c6a45", "#5d6346", "#6b5a3a", "#4f5634", "#8a7650", "#5d6650"]
	for i in 6:   # crates and ammo boxes under the shed
		g.color(cols[i], Geo.WOOD)
		g.cbox(Vector3(-0.8 + (i % 3) * 0.7, Y0 + 0.36, -0.7 + (i / 3) * 0.55), Vector3(0.5, 0.32, 0.4), 0.02)
	g.color(RU, Geo.PAINT)   # fuel tanks
	for x in [-0.6, 0.0]:
		g.tube(Vector3(x - 0.25, Y0 + 0.2, 0.95), Vector3(x + 0.25, Y0 + 0.2, 0.95), 0.16, 10)
	g.color(RU_S, Geo.STEEL)
	g.cbox(Vector3(0.8, Y0 + 0.3, 0.9), Vector3(0.4, 0.6, 0.3), 0.02)   # pump house
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.19, 0.305), Vector3(2.2, 0.04, 0.01))
	_ru_flag(g, Vector3(1.3, Y0, 1.3), 1.0)

static func _barracks(g) -> void:
	var c := Vector3(-0.2, Y0, -0.35)
	_block(g, c, Vector3(2.3, 0.6, 1.2), 7)
	g.color(RU_D, Geo.CORR)
	g.prism_x([Vector2(-0.66, 0.6), Vector2(0.66, 0.6), Vector2(0.0, 0.92)], -1.2, 1.2, Transform3D(Basis.IDENTITY, c))
	g.color("#3a3c3a", Geo.DARK)
	g.box(c + Vector3(0.0, 0.22, 0.603), Vector3(0.3, 0.42, 0.012))
	_star(g, c + Vector3(0.0, 0.5, 0.608), 0.08)
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0, 0.56, 0.605), Vector3(2.1, 0.04, 0.01))
	g.color(RU_S, Geo.STEEL)   # pull-up bars and parade ground markings
	for x in [0.6, 1.0]:
		g.tube(Vector3(x, Y0, 0.9), Vector3(x, Y0 + 0.5, 0.9), 0.015, 4)
	g.tube(Vector3(0.6, Y0 + 0.5, 0.9), Vector3(1.0, Y0 + 0.5, 0.9), 0.012, 4)
	g.color("#e8e8e4", Geo.PAINT)
	for k in 4:
		g.box(Vector3(-0.9 + k * 0.3, Y0 + 0.002, 0.9), Vector3(0.2, 0.004, 0.03))
	_ru_flag(g, Vector3(-1.3, Y0, 1.1), 1.1)

static func _factory(g) -> void:
	var c := Vector3(-0.1, Y0, -0.3)
	g.color(CON, Geo.CONCRETE)
	g.cbox(c + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 2.2), 0.03)
	g.color(RU_D, Geo.CORR)
	g.prism_x([Vector2(-1.12, 0.9), Vector2(1.12, 0.9), Vector2(0.0, 1.4)], -1.52, 1.52, Transform3D(Basis.IDENTITY, c))
	g.color(RU_S, Geo.STEEL)
	g.box(c + Vector3(0, 1.405, 0), Vector3(3.1, 0.03, 0.06))
	for x in [-0.8, 0.8]:   # two big vehicle doors
		g.rollup(c + Vector3(x, 0.38, 1.105), 0.8, 0.7)
	g.windows(c + Vector3(0, 0.8, 1.106), 2.6, 0.1, 10)
	g.windows(Vector3(-c.x, c.y + 0.6, -c.z + 1.106), 2.6, 0.14, 10, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
	_star(g, c + Vector3(0, 1.08, 1.12), 0.14)
	g.color("#ffffff", Geo.TEAM)
	g.box(c + Vector3(0, 0.84, 1.108), Vector3(0.3, 0.04, 0.01))
	g.color(RU_S, Geo.STEEL)   # gantry crane over the yard
	for x in [-1.3, 1.3]:
		g.tube(Vector3(x, Y0, 1.5), Vector3(x, Y0 + 0.9, 1.5), 0.03, 6)
	g.color("#c9a531", Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 0.92, 1.5), Vector3(2.7, 0.08, 0.1), 0.01)
	g.color(CON_D, Geo.CONCRETE)
	g.cyl(0.1, 0.08, 1.2, 10, Transform3D(Basis.IDENTITY, Vector3(1.6, Y0, -1.4)))   # boiler chimney
	_ru_flag(g, Vector3(-1.75, Y0, 1.6), 1.2)

static func _bunker(g) -> void:
	g.color(CON, Geo.CONCRETE)
	g.cyl(0.78, 0.66, 0.42, 8, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))   # octagonal concrete casemate
	g.color(CON_D, Geo.CONCRETE)
	g.cyl(0.66, 0.6, 0.06, 8, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.42, 0)))
	g.color("#2b2d2c", Geo.DARK)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.125
		g.rbox(Vector3(cos(a) * 0.72, Y0 + 0.28, sin(a) * 0.72), Vector3(0.2, 0.05, 0.02), Vector3(0, -rad_to_deg(a) + 90.0, 0))   # firing slits
	for k in 10:
		var a := TAU * k / 10.0
		g.sandbag(Vector3(cos(a) * 0.86, Y0, sin(a) * 0.86), 0.2, rad_to_deg(-a + PI * 0.5))
	g.color("#ffffff", Geo.TEAM)
	g.cyl(0.665, 0.665, 0.03, 8, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.36, 0)), false)

static func _bunker_turret(t) -> void:
	t.color(RU_S, Geo.STEEL)
	t.ccyl(0.3, 0.06, 0.01, 12, Transform3D.IDENTITY)
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.24, -0.26), Vector2(0.24, -0.26), Vector2(0.26, 0.12), Vector2(0.14, 0.26), Vector2(-0.14, 0.26), Vector2(-0.26, 0.12)], 0.06, 0.24, Vector2(0.85, 0.85))
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.14, 0.3), Vector3(0.12, 0.1, 0.1), 0.01)
	t.tube(Vector3(0, 0.14, 0.32), Vector3(0, 0.14, 0.95), 0.022, 8)   # 30 mm
	t.tube(Vector3(0, 0.14, 0.88), Vector3(0, 0.14, 0.97), 0.03, 8)
	t.cbox(Vector3(0.14, 0.27, -0.05), Vector3(0.08, 0.06, 0.08), 0.008)   # sight

static func _aa_site(g) -> void:
	g.color(CON, Geo.CONCRETE)
	for a in 6:   # earth / concrete revetment
		var ang := TAU * (a + 0.5) / 6.0
		if a == 1:
			continue
		g.prism_x([Vector2(-0.09, 0.0), Vector2(0.09, 0.0), Vector2(0.05, 0.2), Vector2(-0.05, 0.2)], -0.28, 0.28, Transform3D(Basis(Vector3.UP, -ang + PI * 0.5), Vector3(cos(ang) * 0.84, Y0, sin(ang) * 0.84)))
	g.color(RU_D, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 0.1, 0), Vector3(0.66, 0.2, 0.66), 0.03)
	g.color(RU, Geo.PAINT)   # radar cabin with a rotating-array mast
	g.cbox(Vector3(-0.55, Y0 + 0.2, -0.5), Vector3(0.34, 0.3, 0.3), 0.02)
	g.color(RU_S, Geo.STEEL)
	g.tube(Vector3(-0.55, Y0 + 0.35, -0.5), Vector3(-0.55, Y0 + 0.8, -0.5), 0.02, 6)
	g.color(RU_L, Geo.PAINT)
	g.cbox(Vector3(-0.55, Y0 + 0.84, -0.5), Vector3(0.36, 0.1, 0.03), 0.01)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.17, 0.335), Vector3(0.5, 0.04, 0.01))

static func _aa_turret(t) -> void:
	t.color(RU_S, Geo.STEEL)
	t.ccyl(0.25, 0.06, 0.015, 14, Transform3D.IDENTITY)
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.12, -0.05), Vector3(0.24, 0.16, 0.24), 0.015)
	for k in 4:   # four launch tubes, two each side, raised 30 degrees
		var s := -0.24 if k < 2 else 0.24
		var y := 0.22 + (k % 2) * 0.12
		t.color(RU, Geo.PAINT)
		t.rcbox(Vector3(s, y, 0.0), Vector3(0.1, 0.1, 0.7), 0.02, Vector3(-30, 0, 0))
		t.color("#2b2d2c", Geo.DARK)
		t.rcbox(Vector3(s, y + 0.18, 0.31), Vector3(0.08, 0.08, 0.01), 0.005, Vector3(-30, 0, 0))
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0, 0.22, 0.075), Vector3(0.1, 0.06, 0.006))
