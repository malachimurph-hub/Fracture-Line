extends RefCounted
## M3.2 new-items models (tool-time only, original procedural):
##   <fac>_sandbags  - 2 x 1 sandbag wall: three staggered courses, slight arc, loose bags
##   <fac>_barricade - 2 x 1 line of concrete Jersey barriers with lifting loops and chips
##   us_firebase     - M777A2 pad now ringed by concrete Jersey barriers (was sandbags)
##   us_bomb_drone   - M3.3: heavy quadcopter, slung warhead, red lamps (was a fixed-wing munition)
##   us_scout_drone  - quadcopter (4 spinning rotors, camera gimbal, M3.3 green lamps)
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const UM := preload("res://tools/gfx_m30/us_m30.gd")
const Y0 := 0.08
const CON := "#b4afa3"
const CON_D := "#8f8a7e"
const CON_L := "#cdc8bb"

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func V8():
	return load("res://tools/gfx_m7/us_v8.gd")

static func jobs() -> Dictionary:
	var j := {}
	for f in ["us", "eu", "tpla", "ecc"]:
		j[f + "_sandbags"] = func() -> void: U()._make("sandbags", Vector2(2, 1), 0.3, _sandbags, Callable(), Vector3.ZERO, f, _dirt)
		j[f + "_barricade"] = func() -> void: U()._make("barricade", Vector2(2, 1), 0.3, _jersey_line, Callable(), Vector3.ZERO, f, _dirt)
	j["us_firebase"] = func() -> void: U()._make("firebase", Vector2(2, 2), 0.9, _m777_pad_concrete, UM._m777, Vector3(0, Y0 + 0.02, 0))
	j["us_bomb_drone"] = func() -> void: _bomb_drone()
	j["us_scout_drone"] = func() -> void: _scout_drone()
	return j

## Low trampled-earth strip instead of a concrete foundation.
static func _dirt(g, fp: Vector2) -> void:
	g.color("#7d6e52", Geo.SANDBAG)
	g.cbox(Vector3(0, 0.012, 0), Vector3(fp.x - 0.1, 0.024, fp.y - 0.3), 0.01)
	g.color("#6b5e45", Geo.SANDBAG)
	for i in 5:
		g.cyl(0.05 + 0.02 * (i % 3), 0.04, 0.012, 7, Transform3D(Basis.IDENTITY, Vector3(-0.8 + i * 0.4, 0.024, 0.28 * (1 if i % 2 else -1))))

## One Jersey barrier along local x (length l) at c, yaw degrees.
static func _jersey(g, c: Vector3, l: float, yaw: float, chip := 0) -> void:
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c)
	g.color(CON if chip % 2 == 0 else CON_L, Geo.CONCRETE)
	# classic safety-shape profile (z, y): wide foot, steep upper face
	g.prism_x([Vector2(-0.1, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.025), Vector2(0.06, 0.06), Vector2(0.035, 0.2), Vector2(-0.035, 0.2), Vector2(-0.06, 0.06), Vector2(-0.1, 0.025)], -l * 0.5, l * 0.5, t)
	g.color(CON_D, Geo.CONCRETE)
	g.box(Vector3(0, 0.201, 0), Vector3(l - 0.01, 0.006, 0.06), t)   # weathered top
	g.color("#3a3936", Geo.STEEL)
	for s in [-1.0, 1.0]:   # lifting loops
		g.box(Vector3(s * l * 0.3, 0.215, 0), Vector3(0.012, 0.025, 0.035), t)
	g.color("#55524b", Geo.DARK)   # drain slot, chipped corner, stencil band
	g.box(Vector3(0, 0.012, 0), Vector3(0.12, 0.022, 0.205), t)
	if chip % 3 == 1:
		g.color("#9a958a", Geo.CONCRETE)
		g.rbox(t * Vector3(l * 0.46, 0.18, 0.04), Vector3(0.05, 0.04, 0.03), Vector3(20, yaw, 30))
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0, 0.14, 0.047), Vector3(l * 0.5, 0.02, 0.004), t)

static func _jersey_line(g) -> void:
	var xs := [-0.62, 0.0, 0.62]
	for i in 3:
		_jersey(g, Vector3(xs[i], Y0 * 0.3, (0.03 if i == 1 else -0.02)), 0.6, (3.0 if i == 0 else (-4.0 if i == 2 else 0.0)), i)
	# rubble chunks and a bent rebar stub
	g.color("#a19c90", Geo.CONCRETE)
	for i in 4:
		g.rbox(Vector3(-0.85 + i * 0.55, 0.03, 0.2 - (i % 2) * 0.38), Vector3(0.06, 0.04, 0.05), Vector3(10 * i, 35 * i, 5))
	g.color("#5a3e2a", Geo.STEEL)
	g.tube(Vector3(0.95, 0.02, 0.15), Vector3(0.98, 0.12, 0.2), 0.006, 4)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, 0.12, 0.085), Vector3(0.16, 0.035, 0.004))

static func _sandbags(g) -> void:
	for ring in 3:
		var n := 7
		for k in n:
			var u := (k + (0.5 if ring % 2 == 1 else 0.0)) / float(n) - 0.5
			if ring % 2 == 1 and k == n - 1:
				continue
			var x := u * 1.75
			var z := -0.06 + x * x * 0.08
			g.sandbag(Vector3(x, Y0 * 0.3 + 0.03 + ring * 0.07, z), 0.28, -rad_to_deg(x * 0.16), "#a39168" if (k + ring) % 3 else "#8f7f5a")
	g.sandbag(Vector3(0.8, 0.03, 0.25), 0.26, 40.0, "#9a8a62")   # loose bags
	g.sandbag(Vector3(-0.75, 0.03, 0.26), 0.26, -25.0, "#8f7f5a")
	g.color("#5e5a3e", Geo.WOOD)   # ammo crate behind the wall
	g.cbox(Vector3(0.35, 0.05, -0.3), Vector3(0.18, 0.08, 0.12), 0.008)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, 0.18, 0.02), Vector3(0.14, 0.03, 0.004))

## M777 pad: ring of concrete Jersey barriers (gap toward the ammo side) on a gravel pad.
static func _m777_pad_concrete(g) -> void:
	g.color("#8d887a", Geo.CONCRETE)
	g.cyl(0.78, 0.78, 0.012, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	for a in 9:
		if a == 2:
			continue
		var ang := TAU * (a + 0.5) / 9.0
		_jersey(g, Vector3(cos(ang) * 0.86, Y0, sin(ang) * 0.86), 0.56, rad_to_deg(-ang + PI * 0.5), a)
	g.color("#5b5f3e", Geo.PAINT)
	for i in 6:
		g.tube(Vector3(-0.6 + (i % 3) * 0.06, Y0 + 0.03 + (i / 3) * 0.05, -0.3), Vector3(-0.6 + (i % 3) * 0.06, Y0 + 0.03 + (i / 3) * 0.05, -0.05), 0.025, 6, 0.01)
	g.color("#8a7650", Geo.WOOD)
	g.cbox(Vector3(-0.54, Y0 + 0.01, -0.18), Vector3(0.22, 0.02, 0.3), 0.004)
	g.color("#4d5741", Geo.PAINT)
	for i in 3:
		g.cbox(Vector3(0.5, Y0 + 0.06, -0.4 + i * 0.12), Vector3(0.18, 0.1, 0.1), 0.01)
	g.color("#66704f", Geo.CANVAS)
	g.prism_x([Vector2(-0.5, Y0), Vector2(-0.24, Y0), Vector2(-0.37, Y0 + 0.18)], 0.3, 0.62)

# ------------------------------------------------------------------ drones
const DR := "#7a7f72"
const DR_D := "#5d6258"
const DR_S := "#33363a"

## M3.3 (Malachi: "make the bomb drone a quadcopter with red lights"): a heavier quadcopter
## than the scout, olive body, a warhead slung under the belly (yellow HE band) and red
## navigation lamps on the four motor pods.
static func _bomb_drone() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.5, "bar_height": 0.6, "recoil": 0.0, "wreck_s": 2.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(DR_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.31, 0), Vector3(0.17, 0.07, 0.26), 0.022)   # body
	h.color(DR, Geo.PAINT)
	h.cbox(Vector3(0, 0.355, -0.02), Vector3(0.12, 0.03, 0.17), 0.014)   # battery lid
	for k in 4:   # X arms with motor pods
		var a := PI * 0.25 + PI * 0.5 * k
		var tip := Vector3(cos(a) * 0.27, 0.32, sin(a) * 0.27)
		h.color(DR_S, Geo.STEEL)
		h.tube(Vector3(0, 0.32, 0), tip, 0.017, 6)
		h.cyl(0.03, 0.03, 0.045, 8, Transform3D(Basis.IDENTITY, tip + Vector3(0, -0.01, 0)))
		h.tube(tip, tip + Vector3(0, -0.11, 0), 0.007, 4)   # landing leg
		h.color("#ff2a1a", Geo.LAMP)
		h.box(tip + Vector3(0, -0.04, 0), Vector3(0.022, 0.018, 0.022))   # red lamp under the pod
	# slung warhead: tube with a blunt nose, HE band, stub fins
	h.color(DR_D, Geo.PAINT)
	h.tube(Vector3(0, 0.215, 0.13), Vector3(0, 0.215, -0.11), 0.04, 10, 0.03)
	h.lathe([[0.0, 0.04], [0.035, 0.032], [0.065, 0.0]], 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.215, 0.13)))
	h.color("#c9a227", Geo.PAINT)
	h.tube(Vector3(0, 0.215, 0.07), Vector3(0, 0.215, 0.045), 0.042, 10)
	h.color(DR_S, Geo.STEEL)
	h.box(Vector3(0, 0.255, 0.0), Vector3(0.03, 0.04, 0.1))   # release clamp
	for k in 4:
		var a2 := PI * 0.5 * k
		var d := Vector3(cos(a2), sin(a2), 0)
		h.box(Vector3(0, 0.215, -0.1) + d * 0.05, Vector3(0.006 + absf(d.y) * 0.04, 0.006 + absf(d.x) * 0.04, 0.05))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.372, -0.02), Vector3(0.07, 0.004, 0.07))
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		V8()._rotor(model, root, mat, "Rotor" if k == 0 else ("TailRotor" if k == 1 else "Rotor%d" % k), Vector3(cos(a) * 0.27, 0.345, sin(a) * 0.27), 0.15, 2)
		if k % 2 == 1:
			(model.get_node("TailRotor" if k == 1 else "Rotor%d" % k) as Node3D).set_meta("rotor_dir", -1.0)
	U()._vfinish(root, model, h, mat, "bomb_drone", [], 0.6, "us")

static func _scout_drone() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.5, "bar_height": 0.6, "recoil": 0.0, "wreck_s": 2.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(DR_S, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, 0), Vector3(0.14, 0.06, 0.22), 0.02)   # body
	h.color(DR, Geo.PAINT)
	h.cbox(Vector3(0, 0.34, -0.02), Vector3(0.1, 0.03, 0.14), 0.012)
	for k in 4:   # X arms with motor pods
		var a := PI * 0.25 + PI * 0.5 * k
		var tip := Vector3(cos(a) * 0.24, 0.31, sin(a) * 0.24)
		h.color(DR_S, Geo.STEEL)
		h.tube(Vector3(0, 0.31, 0), tip, 0.014, 6)
		h.cyl(0.025, 0.025, 0.04, 8, Transform3D(Basis.IDENTITY, tip + Vector3(0, -0.01, 0)))
		h.tube(tip, tip + Vector3(0, -0.1, 0), 0.006, 4)   # landing leg
		h.color("#2aff5a", Geo.LAMP)   # M3.3: green navigation lamp under each pod
		h.box(tip + Vector3(0, -0.035, 0), Vector3(0.018, 0.015, 0.018))
	h.color("#1d1f1e", Geo.DARK)
	h.cyl(0.03, 0.03, 0.04, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.23, 0.08)))   # gimbal
	h.color("#2a3a46", Geo.GLASS)
	h.box(Vector3(0, 0.245, 0.11), Vector3(0.025, 0.025, 0.01))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.356, -0.02), Vector3(0.06, 0.004, 0.06))
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		V8()._rotor(model, root, mat, "Rotor" if k == 0 else ("TailRotor" if k == 1 else "Rotor%d" % k), Vector3(cos(a) * 0.24, 0.33, sin(a) * 0.24), 0.13, 2)
		if k % 2 == 1:
			(model.get_node("TailRotor" if k == 1 else "Rotor%d" % k) as Node3D).set_meta("rotor_dir", -1.0)
	U()._vfinish(root, model, h, mat, "scout_drone", [], 0.6, "us")
