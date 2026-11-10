extends SceneTree
## SEP v3 read of the M1A3, built on the same kit8 path as the current US vehicles
## (tools/gfx_m7/us_v8.gd). Writes a separate scene. Does not touch halberd.tscn.
##   godot --headless --path . -s res://tools/gfx_m7/sepv3_m1.gd
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const U := preload("res://tools/gfx_m7/us_m7.gd")
const US := "#7e8a5c"
const US_D := "#66704a"
const US_S := "#464a46"
const GLASS_C := "#2a3a46"
const OUT := "res://view/units/us/halberd_sepv3.tscn"
# Public SEP v3 figures at the game's 0.25 world-unit per metre.
const HULL_L := 7.93 * 0.25
const WIDTH := 3.66 * 0.25
const ROOF := 2.44 * 0.25

func _initialize() -> void:
	_build()
	quit(0)

func _build() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.35, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var half := HULL_L * 0.5
	var h = K.new()
	# Seven road wheels, rear sprocket, front idler, return rollers. Same spinner classes as the kit.
	h.track_run(WIDTH * 0.40, HULL_L * 0.86, 7, 0.078, 0.15, US_S)
	h.color(US_D, Geo.PAINT)
	h.xloft([
		[half, K.sect(0.10, 0.16, 0.22, 0.26, 0.30, 0.28, 0.008)],
		[half - 0.55, K.sect(0.12, 0.26, 0.40, 0.30, 0.38, 0.36, 0.016)],
		[0.28, K.sect(0.14, 0.30, 0.46, 0.32, 0.40, 0.38, 0.018)],
		[-0.62, K.sect(0.14, 0.30, 0.46, 0.32, 0.40, 0.38, 0.018)],
		[-half, K.sect(0.14, 0.24, 0.38, 0.28, 0.36, 0.34, 0.014)],
	])
	# Skirts sit above the wheel centres so the lower half of each wheel shows. Front panel is raked.
	for s in [-1.0, 1.0]:
		var x: float = s * (WIDTH * 0.5 - 0.012)
		for i in 6:
			var zc := lerpf(-0.62, 0.62, (float(i) + 0.5) / 6.0)
			h.color(US if i > 0 else US_D, Geo.PAINT)
			h.plate(Vector3(x, 0.26, zc), Vector3(0.028, 0.16, 0.20), Vector3(0, 0, -s * 4.0))
			h.plate(Vector3(x - s * 0.01, 0.17, zc), Vector3(0.024, 0.04, 0.20), Vector3(0, 0, s * 22.0))
		h.color(US, Geo.PAINT)
		h.plate(Vector3(s * 0.42, 0.24, 0.86), Vector3(0.028, 0.14, 0.16), Vector3(-28.0, s * 22.0, 0))
	h.color(US_D, Geo.PAINT)
	h.hatch(Vector3(0, 0.42, 0.55), 0.14)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.06, 0.0, 0.06]:
		h.box(Vector3(x, 0.435, 0.66), Vector3(0.045, 0.016, 0.022))
	V4._lamps(h, 0.42, 0.34, half - 0.04)
	h.color(US_S, Geo.STEEL)
	for x in [-0.42, 0.42]:
		h.tube(Vector3(x, 0.2, half - 0.02), Vector3(x, 0.2, half + 0.04), 0.016, 6)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.468, -0.55), 0.55, 0.36, 8)
	h.vent(Vector3(0, 0.30, -half + 0.01), 0.62, 0.12, 5, 180)
	h.color("#4d5741", Geo.PAINT)
	h.jerrycan(Vector3(-0.34, 0.50, -0.42), 0)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.38, 0.38]:
		h.box(Vector3(x, 0.36, -half + 0.02), Vector3(0.04, 0.025, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * (WIDTH * 0.5 - 0.004), 0.30, 0.0), Vector3(0.006, 0.03, 1.05), Vector3(0, 0, -s * 4.0))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.45, 0.04))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.32, 0.32, 0.035, 14, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	# Low wide wedge. The front face stops short of the cheek plates.
	var plan := [Vector2(-0.34, -0.50), Vector2(0.34, -0.50), Vector2(0.40, 0.06),
		Vector2(0.30, 0.36), Vector2(-0.30, 0.36), Vector2(-0.40, 0.06)]
	t.color(US_D, Geo.PAINT)
	var low: Array = []
	for p: Vector2 in plan:
		low.append(p * 0.92)
	t.plan_loft(low, -0.02, 0.04, Vector2(1.06, 1.04))
	t.color(US, Geo.PAINT)
	t.plan_loft(plan, 0.04, 0.14, Vector2(0.94, 0.96), Vector2(0, -0.01))
	t.color(US_D, Geo.PAINT)
	t.plan_loft([Vector2(-0.32, -0.72), Vector2(0.32, -0.72), Vector2(0.34, -0.48), Vector2(-0.34, -0.48)], 0.03, 0.13, Vector2(0.96, 0.96))
	# Cheeks forward of the mantlet.
	t.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.24, 0.09, 0.50), Vector3(0.18, 0.12, 0.30), Vector3(0, s * 16.0, s * -6.0))
	t.color(US_D, Geo.PAINT)
	t.xloft([[0.40, K.sect(0.02, 0.05, 0.14, 0.10, 0.13, 0.12, 0.02)], [0.30, K.sect(0.015, 0.04, 0.16, 0.12, 0.15, 0.13, 0.02)]])
	# Bustle rack.
	t.color(US_S, Geo.STEEL)
	t.rail([Vector3(-0.34, 0.14, -0.48), Vector3(-0.36, 0.14, -0.78), Vector3(0.36, 0.14, -0.78), Vector3(0.34, 0.14, -0.48)], 0.07, 0.10, 0.006)
	t.color("#6b5a3a", Geo.CANVAS)
	t.cbox(Vector3(-0.12, 0.17, -0.64), Vector3(0.22, 0.06, 0.16), 0.02)
	# Spare road wheel lying flat on the roof.
	t.color("#1d1c1b", Geo.RUBBER)
	t.cyl(0.11, 0.11, 0.02, 12, Transform3D(Basis.IDENTITY, Vector3(-0.02, 0.145, -0.28)))
	t.color(US_S, Geo.STEEL)
	t.cyl(0.04, 0.04, 0.024, 8, Transform3D(Basis.IDENTITY, Vector3(-0.02, 0.144, -0.28)))
	# Gunner's sight and the commander's thermal viewer: square housings.
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.22, 0.20, 0.22), Vector3(0.10, 0.12, 0.11), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.22, 0.22, 0.278), Vector3(0.07, 0.04, 0.008))
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.06, 0.19, 0.02), Vector3(0.09, 0.11, 0.09), 0.01)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.06, 0.21, 0.068), Vector3(0.06, 0.035, 0.008))
	# Commander's hatch open, pintle .50. Loader's hatch on the left.
	t.color(US_D, Geo.PAINT)
	t.ccyl(0.09, 0.07, 0.012, 10, Transform3D(Basis.IDENTITY, Vector3(0.16, 0.145, -0.06)))
	U._mg(t, Vector3(0.16, 0.26, -0.02), 0.0, 0.34)
	t.color(US_D, Geo.PAINT)
	t.hatch(Vector3(-0.16, 0.15, -0.08), 0.11)
	U._mg(t, Vector3(-0.22, 0.24, -0.02), -8.0, 0.16)
	# Six-tube smoke banks.
	_smoke6(t, Vector3(0.38, 0.10, 0.18), 36.0)
	_smoke6(t, Vector3(-0.38, 0.10, 0.18), -36.0)
	t.color("#3f4633", Geo.PAINT)
	for k in 2:
		t.box(Vector3(-0.12 + k * 0.24, 0.152, -0.42), Vector3(0.16, 0.006, 0.12))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.10, -0.74), Vector3(0.46, 0.04, 0.01))
	V4._antenna(t, Vector3(-0.28, 0.15, -0.46), 0.5)
	V4._antenna(t, Vector3(0.30, 0.15, -0.5), 0.4)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = U._barrel(piv, root, mat, Vector3(0, 0.08, 0.36), func(g) -> void:
		g.color(US, Geo.PAINT)
		g.gun(0.0, 1.08, 0.048, 0.032, 0.46, false, 10)
		g.color(US_D, Geo.PAINT)
		for z in [0.22, 0.7]:
			g.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.025), 0.04, 10)
		g.color(US_S, Geo.STEEL)
		g.tube(Vector3(0, 0, 1.05), Vector3(0, 0, 1.10), 0.036, 10)
		g.cbox(Vector3(0, 0.045, 1.02), Vector3(0.028, 0.022, 0.04), 0.004))
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	var ntris: int = int(h.tris) + int(t.tris) + int(b.tris)
	print("SEPV3 tris %d (hull %d turret %d gun %d) roof_y %.3f hull_l %.3f width %.3f" % [ntris, h.tris, t.tris, b.tris, ROOF, HULL_L, WIDTH])
	VK._save(root, OUT, 1.35)
	print("WROTE ", OUT)

func _smoke6(t, p: Vector3, yaw: float) -> void:
	t.color(US_S, Geo.STEEL)
	var d := Vector3(sin(deg_to_rad(yaw)), 0.35, cos(deg_to_rad(yaw))).normalized()
	for i in 6:
		var o := p + Vector3((i % 3) * 0.028 * signf(yaw), (i / 3) * 0.03, 0)
		t.tube(o, o + d * 0.07, 0.011, 5)
