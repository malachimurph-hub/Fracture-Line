extends "res://tools/m41/models_m41.gd"
## Russian vehicles rebuilt to published proportions. Scale is 0.30 model-units per metre for
## the tracked family (the approved T-90 hull is about 1.9 units for a 6.9 m hull). The two
## missile trucks use 0.24 so a 13 m TEL still fits the camera.
##   godot --headless --path . -s res://tools/m47/vehicles_m47.gd -- bmp3 t14
## The BMPT and the Grim Reaper are not written here. Then bake_ao on the scenes.
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

const HULLS := preload("res://tools/m47/ru_hulls.gd")

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var only := OS.get_cmdline_user_args()
	var names: Array = ["bmp3", "t14", "tos", "iskander", "mi8", "pantsir", "shilka"]
	if only.size() > 0:
		names = []
		for a in only:
			names.append(String(a))
	for name in names:
		match String(name):
			"bmp3":
				HULLS.bmp3(mat)
			"bmp3_v2":
				HULLS.bmp3_v2(mat)
			"t14":
				HULLS.t14(mat)
			"t14_super":
				HULLS.t14_super(mat)
			"tos":
				HULLS.tos(mat)
			"iskander":
				HULLS.iskander(mat)
			"mi8":
				HULLS.mi8(mat)
			"mi8_v2":
				HULLS.mi8_v2(mat)
			"pantsir":
				HULLS.pantsir(mat)
			"shilka":
				HULLS.shilka(mat)
			"mzkt_base":
				HULLS.mzkt_base(mat)
			"mzkt_radar":
				HULLS.mzkt_radar(mat)
			_:
				push_error("unknown vehicle %s" % name)
	# The BMPT stays the Blender mesh. The Grim Reaper stays the photo rebuild. Neither is written here.
	print("VEHICLES wrote %s" % str(names))
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
