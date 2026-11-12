extends "res://tools/m41/models_m41.gd"
## Russian vehicles rebuilt to published proportions. Scale is 0.30 model-units per metre for
## the tracked family (the approved T-90 hull is about 1.9 units for a 6.9 m hull). The two
## missile trucks use 0.24 so a 13 m TEL still fits the camera.
##   godot --headless --path . -s res://tools/m47/vehicles_m47.gd
## Then bake_ao on the seven scenes.
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const RU := "#5b6442"
const RU_D := "#474f34"
const RU_L := "#6a7350"
const RU_S := "#3a3d38"
## Photo olive. Lighter than the old hull green so the match shader's shaded walls still read green.
const OLIVE := "#8f9b62"
const OLIVE_D := "#738252"
const OLIVE_L := "#a8b47a"
const ERA := "#525b3b"
const GLASS_C := "#2a3a46"
const S := 0.30

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var only := OS.get_cmdline_user_args()
	if only.size() > 0 and String(only[0]) == "pantsir":
		_pantsir(mat)
		print("PANTSIR KIT")
		quit(0)
		return
	_bmp3(mat)
	# BMPT is the Blender mesh at res://assets/models/ecc/bmpt.glb. Do not rebuild it here.
	_t14(mat)
	_tos(mat)
	_iskander(mat)
	_mi8(mat)
	_reaper(mat)
	print("VEHICLES wrote %d" % wrote.size())
	quit(0)

func _skirts(h, x: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var n := 5
	var seg := (z1 - z0) / float(n)
	for i in n:
		h.color(RU if i % 2 == 0 else RU_D, Geo.PAINT)
		h.box(Vector3(x, (y0 + y1) * 0.5, z0 + seg * (float(i) + 0.5)), Vector3(0.03, y1 - y0, seg - 0.02))

func _returns(h, sx: float, zs: Array, y: float) -> void:
	h.color(RU_S, Geo.STEEL)
	for z in zs:
		for s in [-sx, sx]:
			h.tube(Vector3(s - 0.04, y, z), Vector3(s + 0.04, y, z), 0.035, 6)

func _era(h, c: Vector3, n: int, step: Vector3, s: Vector3, deg: Vector3) -> void:
	h.color(ERA, Geo.PAINT)
	for i in n:
		h.rcbox(c + step * (float(i) - float(n - 1) * 0.5), s, 0.006, deg)

func _finish_v(root, model, h, mat, path: String, bar: float, parts: Array) -> void:
	_finish(root, model, h, mat, path, bar, parts)

# BMP-3. Hull 7.14 x 3.23 x 2.30 m. Six road wheels, drive sprocket at the rear,
# boat bow, two rear troop doors, central turret with 100 mm and 30 mm side by side.
func _bmp3(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.15, "recoil": 0.1, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 7.14 * S
	var sx := 3.23 * S * 0.42
	h.track_run(sx, L * 0.92, 6, 0.09, 0.22, RU_S)
	_returns(h, sx, [-0.35, 0.05, 0.4], 0.34)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[L * 0.52, K.sect(0.16, 0.2, 0.26, 0.08, 0.14, 0.1, 0.02)],
		[L * 0.36, K.sect(0.14, 0.22, 0.38, 0.32, 0.38, 0.28, 0.03)],
		[L * 0.1, K.sect(0.14, 0.24, 0.46, 0.4, 0.44, 0.34, 0.03)],
		[-L * 0.38, K.sect(0.14, 0.24, 0.46, 0.4, 0.44, 0.34, 0.03)],
		[-L * 0.5, K.sect(0.18, 0.26, 0.42, 0.36, 0.4, 0.3, 0.02)]])
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.46, -L * 0.4), Vector3(0.7, 0.12, 0.16), 0.01)   # engine sill under the doors
	for s in [-1.0, 1.0]:
		h.color(RU if s < 0.0 else RU_L, Geo.PAINT)
		h.plate(Vector3(s * 0.18, 0.46, -L * 0.48), Vector3(0.32, 0.42, 0.018), Vector3(0, s * 6.0, 0))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.34, 0.5, -L * 0.46), Vector3(0.015, 0.16, 0.02))   # door hinge
		h.box(Vector3(s * 0.06, 0.42, -L * 0.49), Vector3(0.02, 0.06, 0.012))  # handle
	h.color("#1c1d1c", Geo.DARK)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.16, 0.18, -L * 0.5), Vector3(s * 0.16, 0.18, -L * 0.58), 0.032, 6)  # water jets
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.22, 0.0, 0.22]:
		h.plate(Vector3(x, 0.46, L * 0.34), Vector3(0.1, 0.045, 0.008), Vector3(-46, 0, 0))
	h.color(RU_D, Geo.PAINT)
	h.hatch(Vector3(-0.2, 0.5, L * 0.2), 0.065)    # bow gunner
	h.hatch(Vector3(0.0, 0.5, L * 0.16), 0.07)     # driver
	h.hatch(Vector3(0.2, 0.5, L * 0.2), 0.065)     # bow gunner
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(-0.26, 0.4, L * 0.4), Vector3(-0.26, 0.4, L * 0.56), 0.01, 5)  # bow PKT
	h.tube(Vector3(0.26, 0.4, L * 0.4), Vector3(0.26, 0.4, L * 0.56), 0.01, 5)
	h.color(RU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.28, L * 0.5), Vector3(0.4, 0.14, 0.012), Vector3(72, 0, 0))  # folded trim vane
	h.color("#2a2c28", Geo.DARK)
	h.grille(Vector3(0.22, 0.48, -L * 0.22), 0.28, 0.16, 5)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0.34, 0.36, -L * 0.1), Vector3(0.42, 0.32, -L * 0.02), 0.03, 6)
	_skirts(h, sx + 0.06, -L * 0.28, L * 0.28, 0.16, 0.36)
	V4._lamps(h, 0.22, 0.36, L * 0.48)
	V4._antenna(h, Vector3(-0.28, 0.52, -0.15), 0.45)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(sx + 0.02, 0.32, 0.1), Vector3(0.01, 0.03, 0.4))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.5, 0.05))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.28, -0.32), Vector2(0.28, -0.32), Vector2(0.34, -0.05), Vector2(0.26, 0.28), Vector2(-0.26, 0.28), Vector2(-0.34, -0.05)], 0.0, 0.2, Vector2(0.82, 0.84))
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(-0.1, 0.2, -0.06), 0.07)
	t.hatch(Vector3(0.12, 0.2, -0.02), 0.06)
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0.16, 0.22, 0.02), Vector3(0.08, 0.06, 0.1), 0.006)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.16, 0.22, 0.075), Vector3(0.05, 0.03, 0.006))
	V4._antenna(t, Vector3(-0.18, 0.2, -0.16), 0.35)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.1, 0.22))
	var b = K.new()
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0.02, -0.01, -0.02), Vector3(0.18, 0.12, 0.1), 0.008)  # mantlet
	b.color(RU_S, Geo.STEEL)
	b.gun(0.0, 0.92, 0.036, 0.026, 0.48, true, 8)   # 100 mm 2A70
	# 30 mm 2A72 under the 100 mm, so a side view shows both
	b.tube(Vector3(0.05, -0.055, 0.02), Vector3(0.05, -0.055, 0.78), 0.013, 6)
	b.color(RU_D, Geo.PAINT)
	b.tube(Vector3(0.05, -0.055, 0.22), Vector3(0.05, -0.055, 0.36), 0.02, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/bmp3.tscn", 1.15, [t, b])

# BMPT. Same hull scale as the T-90 (about 7 m, six road wheels). The turret is a
# low platform: twin 30 mm up on a cradle, a two-tube armoured launcher each side,
# round grenade-launcher hatches on the front corners, boxy skirts, slatted rear.
func _bmpt(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.05, "bar_height": 1.4, "recoil": 0.04, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 2.05
	var sx := 0.58
	h.track_run(sx, L * 0.92, 6, 0.105, 0.24, RU_S)
	h.color(OLIVE_D, Geo.PAINT)
	h.xloft([[L * 0.50, K.sect(0.16, 0.24, 0.32, 0.18, 0.28, 0.16, 0.02)],
		[L * 0.32, K.sect(0.14, 0.26, 0.50, 0.44, 0.52, 0.38, 0.03)],
		[-L * 0.38, K.sect(0.14, 0.26, 0.52, 0.48, 0.54, 0.40, 0.03)],
		[-L * 0.50, K.sect(0.18, 0.28, 0.44, 0.42, 0.46, 0.34, 0.02)]])
	_era(h, Vector3(0, 0.40, L * 0.34), 6, Vector3(0.13, 0, 0.012), Vector3(0.11, 0.032, 0.13), Vector3(-18, 0, 0))
	for s in [-1.0, 1.0]:
		h.color(OLIVE, Geo.PAINT)
		h.cbox(Vector3(s * (sx + 0.07), 0.36, 0.22), Vector3(0.12, 0.22, 0.52), 0.012)
		h.cbox(Vector3(s * (sx + 0.07), 0.36, -0.28), Vector3(0.12, 0.22, 0.42), 0.012)
		h.color(OLIVE_D, Geo.PAINT)
		for i in 6:
			h.box(Vector3(s * (sx + 0.12), 0.26 + float(i) * 0.032, -0.58), Vector3(0.014, 0.012, 0.20))
		h.color(OLIVE, Geo.PAINT)
		h.ccyl(0.15, 0.07, 0.014, 16, Transform3D(Basis.IDENTITY, Vector3(s * 0.36, 0.52, L * 0.22)))
		h.color(OLIVE_D, Geo.PAINT)
		h.ccyl(0.11, 0.014, 0.004, 14, Transform3D(Basis.IDENTITY, Vector3(s * 0.36, 0.585, L * 0.22)))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.36, 0.605, L * 0.22), Vector3(0.14, 0.008, 0.016))
	h.color(OLIVE_D, Geo.PAINT)
	for i in 9:
		h.box(Vector3(-0.32 + float(i) * 0.08, 0.34, -L * 0.50), Vector3(0.012, 0.20, 0.016))
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(-0.34, 0.44, -L * 0.50), Vector3(0.34, 0.44, -L * 0.50), 0.012, 4)
	h.tube(Vector3(-0.34, 0.24, -L * 0.50), Vector3(0.34, 0.24, -L * 0.50), 0.01, 4)
	V4._lamps(h, 0.24, 0.36, L * 0.46)
	V4._antenna(h, Vector3(-0.20, 0.56, -0.2), 0.55)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(sx + 0.14, 0.40, -0.05), Vector3(0.008, 0.025, 0.45))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.52, 0.0))
	var t = K.new()
	t.color(OLIVE, Geo.PAINT)
	t.plan_loft([Vector2(-0.36, -0.26), Vector2(0.36, -0.26), Vector2(0.40, 0.04), Vector2(0.18, 0.20), Vector2(-0.18, 0.20), Vector2(-0.40, 0.04)], 0.0, 0.06, Vector2(0.88, 0.86))
	t.color(OLIVE_D, Geo.PAINT)
	t.cbox(Vector3(0.0, 0.09, -0.04), Vector3(0.14, 0.05, 0.16), 0.006)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.0, 0.11, 0.035), Vector3(0.07, 0.028, 0.006))
	for s in [-1.0, 1.0]:
		t.color(OLIVE, Geo.PAINT)
		t.rcbox(Vector3(s * 0.46, 0.20, 0.08), Vector3(0.26, 0.18, 0.58), 0.014, Vector3(-20, 0, s * 4.0))
		t.color(OLIVE_L, Geo.PAINT)
		t.rcbox(Vector3(s * 0.46, 0.30, 0.06), Vector3(0.28, 0.03, 0.60), 0.004, Vector3(-20, 0, s * 4.0))
		t.color("#1a1c18", Geo.DARK)
		for k in 2:
			var ox: float = s * 0.46 + (float(k) - 0.5) * 0.09
			t.tube(Vector3(ox, 0.12, 0.06), Vector3(ox, 0.26, 0.46), 0.038, 8)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.12, 0.06))
	var b = K.new()
	b.color(OLIVE_D, Geo.PAINT)
	b.cbox(Vector3(0, 0.02, 0.0), Vector3(0.11, 0.05, 0.12), 0.006)
	b.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		b.tube(Vector3(s * 0.045, 0.02, 0.02), Vector3(s * 0.045, 0.22, 0.92), 0.018, 8)
		b.tube(Vector3(s * 0.045, 0.20, 0.86), Vector3(s * 0.045, 0.24, 1.02), 0.026, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/bmpt.tscn", 1.4, [t, b])

# T-14. Hull about 8.7 m, 7 road wheels, slab sides, crew hatches in a row on the
# front deck, a low unmanned turret, slat basket at the rear.
func _t14(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.15, "bar_height": 1.2, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 8.7 * S
	var sx := 1.55 * S
	h.track_run(sx, L * 0.92, 7, 0.085, 0.22, RU_S)
	_returns(h, sx, [-0.7, -0.2, 0.3, 0.75], 0.36)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[L * 0.5, K.sect(0.18, 0.24, 0.32, 0.16, 0.24, 0.16, 0.03)],
		[L * 0.32, K.sect(0.16, 0.26, 0.48, 0.42, 0.48, 0.36, 0.04)],
		[-L * 0.42, K.sect(0.16, 0.26, 0.5, 0.46, 0.5, 0.38, 0.035)],
		[-L * 0.5, K.sect(0.2, 0.28, 0.42, 0.4, 0.44, 0.32, 0.03)]])
	h.color(RU, Geo.PAINT)
	for i in 3:
		h.hatch(Vector3(-0.22 + float(i) * 0.22, 0.52, L * 0.22), 0.07)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.42, L * 0.46), Vector3(0.3, 0.06, 0.008), Vector3(-50, 0, 0))
	_skirts(h, sx + 0.07, -L * 0.36, L * 0.3, 0.16, 0.38)
	h.color(RU_S, Geo.STEEL)
	for i in 7:
		var z := -L * 0.48
		h.tube(Vector3(-0.28 + float(i) * 0.09, 0.28, z), Vector3(-0.28 + float(i) * 0.09, 0.55, z - 0.06), 0.008, 4)
	h.tube(Vector3(-0.3, 0.52, -L * 0.5), Vector3(0.32, 0.52, -L * 0.5), 0.012, 4)
	h.tube(Vector3(-0.3, 0.32, -L * 0.48), Vector3(0.32, 0.32, -L * 0.48), 0.01, 4)
	h.tube(Vector3(-0.3, 0.3, -L * 0.42), Vector3(-0.3, 0.3, -L * 0.54), 0.01, 4)
	h.tube(Vector3(0.32, 0.3, -L * 0.42), Vector3(0.32, 0.3, -L * 0.54), 0.01, 4)
	V4._lamps(h, 0.22, 0.36, L * 0.48)
	V4._antenna(h, Vector3(-0.22, 0.54, L * 0.08), 0.55)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.02, 0.52, -0.15))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.32, -0.28), Vector2(0.32, -0.28), Vector2(0.36, 0.05), Vector2(0.22, 0.26), Vector2(-0.22, 0.26), Vector2(-0.36, 0.05)], 0.0, 0.12, Vector2(0.78, 0.8))
	t.color(RU_S, Geo.STEEL)
	for i in 6:
		var a := TAU * float(i) / 6.0
		t.tube(Vector3(cos(a) * 0.22, 0.1, sin(a) * 0.16), Vector3(cos(a) * 0.34, 0.14, sin(a) * 0.26), 0.012, 4)
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0.12, 0.14, -0.02), Vector3(0.08, 0.05, 0.1), 0.006)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.12, 0.15, 0.035), Vector3(0.05, 0.025, 0.006))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.2))
	var b = K.new()
	b.color(RU_S, Geo.STEEL)
	b.gun(0.0, 1.25, 0.045, 0.03, 0.62, true, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/t14.tscn", 1.2, [t, b])

# TOS-1A. Same T-72 hull. The turret is a 24-tube box, three rows of eight, which elevates.
func _tos(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.05, "bar_height": 1.35, "recoil": 0.02, "wreck_s": 7.5, "elevate": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 7.2 * S
	var sx := 1.7 * S
	h.track_run(sx, L, 6, 0.095, 0.24, RU_S)
	_returns(h, sx, [-0.35, 0.15], 0.4)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[L * 0.5, K.sect(0.2, 0.28, 0.36, 0.2, 0.28, 0.16, 0.03)],
		[L * 0.3, K.sect(0.18, 0.32, 0.5, 0.46, 0.5, 0.36, 0.04)],
		[-L * 0.42, K.sect(0.18, 0.32, 0.5, 0.48, 0.52, 0.38, 0.04)],
		[-L * 0.5, K.sect(0.22, 0.32, 0.42, 0.42, 0.46, 0.32, 0.03)]])
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.55, L * 0.22), Vector3(0.7, 0.14, 0.4), 0.015)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.62, L * 0.38), Vector3(0.36, 0.08, 0.008), Vector3(-24, 0, 0))
	h.color(RU_D, Geo.PAINT)
	h.hatch(Vector3(-0.16, 0.64, L * 0.16), 0.07)
	h.hatch(Vector3(0.16, 0.64, L * 0.16), 0.07)
	_skirts(h, sx + 0.08, -L * 0.28, L * 0.28, 0.18, 0.4)
	V4._lamps(h, 0.24, 0.4, L * 0.46)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.62, -0.05))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.04, -0.2), Vector3(0.4, 0.08, 0.3), 0.01)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.1, 0.0))
	var b = K.new()
	b.color(RU, Geo.PAINT)
	b.cbox(Vector3(0, 0.16, 0.28), Vector3(0.78, 0.42, 0.7), 0.016)
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0.38, 0.28), Vector3(0.82, 0.04, 0.74), 0.006)
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0.44, -0.08, -0.2), Vector3(0.44, 0.06, 0.2), 0.018, 6)  # elevate ram
	b.tube(Vector3(-0.44, -0.08, -0.2), Vector3(-0.44, 0.06, 0.2), 0.018, 6)
	for row in 3:
		for col in 8:
			var x := -0.3 + float(col) * 0.086
			var y := 0.02 + float(row) * 0.1
			b.color(RU_S, Geo.STEEL)
			b.tube(Vector3(x, y, -0.05), Vector3(x, y, 0.78), 0.028, 6)
			b.color("#1a1c1a", Geo.DARK)
			b.tube(Vector3(x, y, 0.72), Vector3(x, y, 0.82), 0.016, 5)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/tos.tscn", 1.4, [t, b])

# Iskander-M TEL, 9P78-1. MZKT-7930 8x8, about 13 m. Cab forward, twin canisters
# that erect together. Axles 1 and 2 steer.
func _iskander(mat: Material) -> void:
	var sc := 0.24
	var root := VK._root({"selection_radius": 1.4, "bar_height": 1.55, "recoil": 0.0, "wreck_s": 8.0, "elevate": 0.7, "steer_max": 0.32})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 13.0 * sc
	UV8._tyres(h, 1.15 * sc * 1.3, [L * 0.38, L * 0.22, -L * 0.08, -L * 0.28], 0.2, 0.15, 2, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.36, 0.0), Vector3(0.85, 0.16, L * 0.92), 0.02)
	h.color(RU, Geo.PAINT)
	var nose := L * 0.48
	h.xloft([[nose, K.sect(0.4, 0.48, 0.7, 0.22, 0.32, 0.26, 0.04)],
		[nose - 0.45, K.sect(0.38, 0.5, 0.92, 0.42, 0.46, 0.36, 0.04)],
		[nose - 0.85, K.sect(0.38, 0.5, 0.88, 0.44, 0.48, 0.36, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.78, nose - 0.15), Vector3(0.7, 0.22, 0.012), Vector3(-16, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.42, 0.74, nose - 0.42), Vector3(0.012, 0.16, 0.28))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.55, nose - 0.02), 0.4, 0.14, 6)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.5, -0.15), Vector3(0.9, 0.14, L * 0.45), 0.012)
	h.color(RU_S, Geo.STEEL)
	h.tyre(Vector3(0.35, 0.55, -L * 0.4), 0.14, 0.08, false, RU_S, 10)
	V4._lamps(h, 0.28, 0.5, nose)
	V4._antenna(h, Vector3(-0.3, 0.95, nose - 0.55), 0.5)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.48, 0.55, 0.2), Vector3(0.01, 0.03, 0.6))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.58, -0.2))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.04, -0.35), Vector3(0.5, 0.08, 0.4), 0.01)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.05))
	var b = K.new()
	for s in [-1.0, 1.0]:
		b.color(RU, Geo.PAINT)
		b.cbox(Vector3(s * 0.24, 0.12, 0.4), Vector3(0.18, 0.24, 1.55), 0.01)
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(s * 0.24, 0.26, 0.4), Vector3(0.2, 0.035, 1.58), 0.005)
		b.color("#c9b48c", Geo.PAINT)
		b.tube(Vector3(s * 0.24, 0.12, 1.12), Vector3(s * 0.24, 0.12, 1.32), 0.07, 8, 0.012)
		b.color(RU_S, Geo.STEEL)
		for i in 6:
			b.box(Vector3(s * 0.24, 0.12, -0.15 + float(i) * 0.26), Vector3(0.2, 0.016, 0.01))
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0.42, -0.02, 0.15), Vector3(0.42, 0.08, 0.85), 0.02, 6)  # erector arm
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/iskander.tscn", 1.55, [t, b])

# Pantsir-S1 on the MZKT-7930 8x8, same chassis scale as the Iskander. Search radar
# folds by name. Outriggers are modelled planted; the view drops that node on deploy.
func _pantsir(mat: Material) -> void:
	var sc := 0.24
	var root := VK._root({"selection_radius": 1.45, "bar_height": 1.65, "recoil": 0.04, "wreck_s": 8.0, "steer_max": 0.28})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 12.7 * sc
	UV8._tyres(h, 0.50, [L * 0.36, L * 0.22, -L * 0.14, -L * 0.32], 0.22, 0.16, 2, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.40, -0.05), Vector3(0.82, 0.16, L * 0.92), 0.015)
	h.color(RU, Geo.PAINT)
	var nose := L * 0.46
	h.xloft([[nose, K.sect(0.38, 0.46, 0.62, 0.2, 0.28, 0.22, 0.03)],
		[nose - 0.42, K.sect(0.36, 0.48, 0.86, 0.4, 0.44, 0.34, 0.04)],
		[nose - 0.78, K.sect(0.36, 0.48, 0.84, 0.42, 0.46, 0.34, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.74, nose - 0.12), Vector3(0.62, 0.22, 0.012), Vector3(-14, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.40, 0.70, nose - 0.38), Vector3(0.012, 0.16, 0.26))
		h.color(RU_S, Geo.STEEL)
		h.tube(Vector3(s * 0.42, 0.82, nose - 0.22), Vector3(s * 0.58, 0.86, nose - 0.18), 0.012, 4)
		h.box(Vector3(s * 0.62, 0.86, nose - 0.16), Vector3(0.05, 0.08, 0.07))
		h.color(RU, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.52, nose - 0.02), 0.36, 0.12, 5)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.48, nose - 0.04), Vector3(0.7, 0.08, 0.08), 0.008)
	# mid-body module and a door each side
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.72, 0.35), Vector3(0.78, 0.36, 0.62), 0.012)
	for s in [-1.0, 1.0]:
		h.color(RU_D, Geo.PAINT)
		h.box(Vector3(s * 0.40, 0.70, 0.35), Vector3(0.02, 0.24, 0.26))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.415, 0.70, 0.46), Vector3(0.012, 0.05, 0.03))
		h.cbox(Vector3(s * 0.46, 0.55, -0.55), Vector3(0.12, 0.18, 1.05), 0.008)
		h.box(Vector3(s * 0.50, 0.72, -0.7), Vector3(0.025, 0.025, 1.15))
		for i in 6:
			h.box(Vector3(s * 0.50, 0.62, -1.2 + float(i) * 0.18), Vector3(0.02, 0.16, 0.016))
	h.ladder(Vector3(-0.52, 0.22, 0.15), 0.55, Vector3(0, 0, 1), 0.08)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.55, -L * 0.46), Vector3(0.78, 0.32, 0.08), 0.008)
	V4._lamps(h, 0.26, 0.48, nose)
	V4._antenna(h, Vector3(-0.28, 1.05, 0.2), 0.45)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.48, 0.62, 0.05), Vector3(0.01, 0.03, 0.4))
	var og = K.new()
	og.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		for z in [0.85, -0.85]:
			og.tube(Vector3(s * 0.36, 0.42, z), Vector3(s * 0.78, 0.08, z), 0.022, 6)
			og.cbox(Vector3(s * 0.84, 0.03, z), Vector3(0.14, 0.04, 0.18), 0.004)
	VK._mi(model, root, "Outriggers", og.commit(mat))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.58, -0.25))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.cbox(Vector3(0, 0.06, 0.0), Vector3(0.55, 0.12, 0.48), 0.01)
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.16, 0.22), Vector3(0.16, 0.14, 0.08), 0.006)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.16, 0.26), Vector3(0, 0.16, 0.34), 0.09, 10)
	for s in [-1.0, 1.0]:
		t.color(RU_D, Geo.PAINT)
		t.cbox(Vector3(s * 0.38, 0.14, 0.02), Vector3(0.22, 0.20, 0.5), 0.008)
		for row in 2:
			for col in 3:
				var x: float = s * 0.38 + (float(col) - 1.0) * 0.055
				var y: float = 0.08 + float(row) * 0.08
				t.color(RU_L, Geo.PAINT)
				t.tube(Vector3(x, y, 0.22), Vector3(x, y, 0.36), 0.022, 6)
				t.color("#1a1c1a", Geo.DARK)
				t.tube(Vector3(x, y, 0.32), Vector3(x, y, 0.40), 0.012, 5)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var rd = K.new()
	rd.color(RU, Geo.PAINT)
	rd.cbox(Vector3(0, 0.10, 0), Vector3(0.06, 0.18, 0.06), 0.004)
	rd.cbox(Vector3(0, 0.24, 0.02), Vector3(0.40, 0.26, 0.04), 0.006)
	rd.color(RU_S, Geo.STEEL)
	rd.box(Vector3(0, 0.24, 0.045), Vector3(0.30, 0.16, 0.012))
	VK._mi(VK._n3(piv, root, "Radar", Vector3(0, 0.22, -0.08)), root, "RadarMesh", rd.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.16, 0.12))
	var b = K.new()
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0, 0), Vector3(0.50, 0.06, 0.08), 0.006)
	b.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		for k in 2:
			var y := -0.025 + float(k) * 0.05
			b.tube(Vector3(s * 0.18, y, 0.02), Vector3(s * 0.18, y, 0.62), 0.014, 6)
			b.tube(Vector3(s * 0.18, y, 0.56), Vector3(s * 0.18, y, 0.70), 0.02, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/pantsir.tscn", 1.65, [t, b, og])

# Mi-8. Round cabin, bulbous glazed nose, clamshell cargo doors, roof engines,
# external tanks, tricycle gear, five-blade rotor, three-blade tail rotor.
func _mi8(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.35, "bar_height": 1.35, "recoil": 0.0, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(RU, Geo.PAINT)
	h.xloft([[1.15, K.sect(0.22, 0.32, 0.42, 0.1, 0.16, 0.12, 0.04)],
		[0.85, K.sect(0.16, 0.34, 0.62, 0.28, 0.36, 0.26, 0.06)],
		[0.2, K.sect(0.14, 0.32, 0.7, 0.36, 0.42, 0.3, 0.06)],
		[-0.55, K.sect(0.16, 0.32, 0.66, 0.34, 0.4, 0.28, 0.05)],
		[-0.85, K.sect(0.22, 0.34, 0.5, 0.16, 0.22, 0.14, 0.03)]])
	h.color(RU_L, Geo.PAINT)
	h.dome(0.34, 0.26, 6, 16, Transform3D(Basis.IDENTITY.scaled(Vector3(1.05, 0.92, 1.15)), Vector3(0, 0.4, 1.02)))
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.42, 1.22), Vector3(0.42, 0.18, 0.01), Vector3(-38, 0, 0))
	h.plate(Vector3(-0.2, 0.46, 1.12), Vector3(0.16, 0.14, 0.01), Vector3(-18, 36, 0))
	h.plate(Vector3(0.2, 0.46, 1.12), Vector3(0.16, 0.14, 0.01), Vector3(-18, -36, 0))
	h.plate(Vector3(0, 0.58, 1.02), Vector3(0.3, 0.08, 0.01), Vector3(-8, 0, 0))
	for s in [-1.0, 1.0]:
		for z in [0.45, 0.15, -0.15, -0.4]:
			h.pane([Vector3(s * 0.4, 0.4, z + 0.1), Vector3(s * 0.4, 0.58, z + 0.1), Vector3(s * 0.4, 0.58, z - 0.08), Vector3(s * 0.4, 0.4, z - 0.08)], Vector3(s, 0.2, 0))
		h.color(RU_D, Geo.PAINT)
		h.cbox(Vector3(s * 0.42, 0.28, 0.05), Vector3(0.1, 0.12, 0.55), 0.02)
		h.color(GLASS_C, Geo.GLASS)
	h.color(RU_L, Geo.PAINT)
	h.plate(Vector3(-0.14, 0.4, -0.7), Vector3(0.26, 0.42, 0.02), Vector3(0, 14, 0))
	h.plate(Vector3(0.14, 0.4, -0.7), Vector3(0.26, 0.42, 0.02), Vector3(0, -14, 0))
	h.color("#1c1d1c", Geo.DARK)
	h.box(Vector3(0, 0.4, -0.72), Vector3(0.012, 0.36, 0.016))  # clamshell split
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(-0.22, 0.78, 0.05), Vector3(0.22, 0.14, 0.55), 0.015)
	h.cbox(Vector3(0.22, 0.78, 0.05), Vector3(0.22, 0.14, 0.55), 0.015)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(-0.22, 0.78, 0.34), Vector3(-0.22, 0.78, 0.42), 0.07, 8)  # engine intakes
	h.tube(Vector3(0.22, 0.78, 0.34), Vector3(0.22, 0.78, 0.42), 0.07, 8)
	h.color(RU, Geo.PAINT)
	h.box(Vector3(0.4, 0.48, -0.05), Vector3(0.012, 0.02, 0.5))  # sliding-door rail
	h.color("#2a2c28", Geo.DARK)
	h.tube(Vector3(-0.22, 0.78, -0.28), Vector3(-0.36, 0.72, -0.42), 0.04, 6)
	h.tube(Vector3(0.22, 0.78, -0.28), Vector3(0.36, 0.72, -0.42), 0.04, 6)
	h.color(RU, Geo.PAINT)
	h.tube(Vector3(0, 0.55, -0.9), Vector3(0, 0.62, -2.15), 0.07, 8, 0.035)
	h.color(RU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.85, -2.05), Vector3(0.04, 0.35, 0.16), Vector3(0, 0, 0))
	V4._antenna(h, Vector3(0.1, 0.7, -0.2), 0.3)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.22, 0.95), Vector3(0, 0.06, 1.05), 0.015, 4)
	h.tyre(Vector3(0, 0.07, 1.08), 0.07, 0.04, true, RU_S, 8)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.22, 0.22, 0.15), Vector3(s * 0.28, 0.06, 0.2), 0.016, 4)
		h.tyre(Vector3(s * 0.32, 0.09, 0.22), 0.09, 0.05, false, RU_S, 8)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0.42, 0.42, 0.35), Vector3(0.55, 0.4, 0.55), 0.012, 5)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.98, 0.05), 1.85, 5)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(-0.16, 0.82, -2.02), 0.42, 3, true)
	_finish_v(root, model, h, mat, "res://view/units/ecc/mi8.tscn", 1.4, [])

# Grim Reaper. Eight evenly spaced axles and a long ribbed canister at the T-90's
# scale (0.28 units per metre, about 22.7 m). Split cabs flank the rounded nose.
# The canister is the Barrel, so the existing elevate still erects it. No markings.
func _reaper(mat: Material) -> void:
	var U := 0.28
	var root := VK._root({"selection_radius": 3.2, "bar_height": 1.85, "recoil": 0.0, "wreck_s": 10.0, "elevate": 0.85, "steer_max": 0.18})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 22.7 * U
	var zs := []
	for i in 8:
		zs.append(lerpf(L * 0.38, -L * 0.40, float(i) / 7.0))
	UV8._tyres(h, 0.48, zs, 0.27, 0.18, 2, RU_S)
	h.color(OLIVE_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.50, -0.1), Vector3(0.62, 0.14, L * 0.90), 0.012)
	h.color(OLIVE, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for i in 6:
			h.cbox(Vector3(s * 0.42, 0.58, lerpf(1.3, -2.1, float(i) / 5.0)), Vector3(0.22, 0.16, 0.42), 0.008)
		h.color(RU_S, Geo.STEEL)
		h.ladder(Vector3(s * 0.56, 0.48, -0.35), 0.58, Vector3(0, 0, 1), 0.11)
		h.color(OLIVE, Geo.PAINT)
		h.cbox(Vector3(s * 0.62, 0.78, 2.05), Vector3(0.36, 0.48, 0.92), 0.015)
		h.color(OLIVE_D, Geo.PAINT)
		h.cbox(Vector3(s * 0.62, 1.04, 2.05), Vector3(0.38, 0.05, 0.94), 0.006)
		h.color(GLASS_C, Geo.GLASS)
		h.plate(Vector3(s * 0.62, 0.86, 2.48), Vector3(0.28, 0.18, 0.012), Vector3(-14, 0, 0))
		h.box(Vector3(s * 0.80, 0.80, 2.05), Vector3(0.012, 0.14, 0.30))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.86, 0.92, 2.22), Vector3(0.05, 0.08, 0.10))
		h.color(OLIVE_D, Geo.PAINT)
		h.box(Vector3(s * 0.62, 0.58, 2.50), Vector3(0.34, 0.08, 0.06))
	h.color(OLIVE_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, 2.64), Vector3(0.95, 0.10, 0.10), 0.008)
	V4._lamps(h, 0.50, 0.62, 2.60)
	V4._antenna(h, Vector3(-0.64, 1.02, 1.85), 0.5)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.56, 0.64, 0.3), Vector3(0.01, 0.03, 0.9))
	var og = K.new()
	og.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		for z in [1.15, -1.35]:
			og.tube(Vector3(s * 0.32, 0.42, z), Vector3(s * 0.98, 0.06, z), 0.028, 6)
			og.cbox(Vector3(s * 1.05, 0.035, z), Vector3(0.16, 0.04, 0.22), 0.004)
	VK._mi(model, root, "Outriggers", og.commit(mat))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.92, -2.35))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.0, 0.12), Vector3(0.34, 0.08, 0.28), 0.008)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0, 0.05))
	var b = K.new()
	b.color(OLIVE_D, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 0.26), 0.42, 16)
	b.color(OLIVE, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.20), Vector3(0, 0, 4.15), 0.38, 18)
	b.color(OLIVE_L, Geo.PAINT)
	b.dome(0.38, 0.95, 8, 18, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 4.15)))
	b.color(OLIVE_D, Geo.PAINT)
	for i in 5:
		b.box(Vector3(-0.14 + float(i) * 0.07, 0.42, 2.0), Vector3(0.022, 0.06, 3.6))
	b.color(RU_S, Geo.STEEL)
	b.box(Vector3(0, 0.48, 2.0), Vector3(0.03, 0.035, 3.9))
	b.color(OLIVE_D, Geo.PAINT)
	b.cbox(Vector3(0.22, 0.28, 3.35), Vector3(0.36, 0.32, 0.85), 0.014)
	b.color("#232420", Geo.DARK)
	for i in 7:
		b.box(Vector3(0.41, 0.16 + float(i) * 0.04, 3.35), Vector3(0.014, 0.012, 0.62))
	b.color(OLIVE_D, Geo.PAINT)
	for z in [0.7, 1.7, 2.8]:
		b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.06), 0.41, 16)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish_v(root, model, h, mat, "res://view/units/ecc/reaper.tscn", 1.9, [t, b, og])
