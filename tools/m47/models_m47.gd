extends "res://tools/m41/models_m41.gd"
## Russia tech-tree views. Same kit as the T-90 and the M1A3: lofted hulls, tracks or tyres,
## glazing, fittings. Not a flat box pass.
##   godot --headless --path . -s res://tools/m47/models_m47.gd
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const RU := "#5b6442"
const RU_D := "#474f34"
const RU_L := "#6a7350"
const RU_S := "#3a3d38"
const GLASS_C := "#2a3a46"

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	struct_fac = "ecc"
	_bmp3(mat)
	_bmpt(mat)
	_t14(mat)
	_tos(mat)
	_iskander(mat)
	_reaper(mat)
	_mi8(mat)
	_fsb(mat)
	_black_market(mat)
	_towers(mat)
	_upgrades(mat)
	print("M47 wrote %d scenes" % wrote.size())
	quit(0)

func _prop(mat: Material, path: String, bar: float, body: Callable) -> void:
	var root := Node3D.new()
	root.name = "View"
	var h = K.new()
	body.call(h)
	VK._mi(root, root, "Hull", h.commit(mat))
	VK._save(root, path, bar)
	wrote.append(path)

func _tracked(h, hw: float, length: float, wheels: int) -> void:
	h.track_run(hw - 0.08, length, wheels, 0.11, 0.28, RU_S)

func _hull_band(h, hw: float, length: float, y: float) -> void:
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(hw - 0.02, y, 0), Vector3(0.012, 0.035, length * 0.55))
	h.box(Vector3(-(hw - 0.02), y, 0), Vector3(0.012, 0.035, length * 0.55))

func _stow(h, hw: float, z0: float) -> void:
	h.color(RU_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * (hw - 0.02), 0.52, z0), Vector3(0.16, 0.08, 0.28), 0.012)
		h.cbox(Vector3(s * (hw - 0.02), 0.52, z0 - 0.36), Vector3(0.14, 0.07, 0.18), 0.01)
	h.color("#6b5236", Geo.WOOD)
	h.tube(Vector3(-hw + 0.05, 0.58, z0 - 0.7), Vector3(hw - 0.05, 0.58, z0 - 0.7), 0.04, 6)

func _smoke(t, side: float) -> void:
	t.color(RU_S, Geo.STEEL)
	var dir := Vector3(side * 0.7, 0.45, 0.55).normalized()
	var o := Vector3(side * 0.28, 0.12, 0.05)
	for i in 4:
		var p := o + Vector3(0, (float(i % 2) - 0.5) * 0.035, (float(i / 2) - 0.5) * 0.04)
		t.tube(p, p + dir * 0.09, 0.012, 5)

# ------------------------------------------------------------------ BMP-3
func _bmp3(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.35, "recoil": 0.08, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked(h, 0.55, 2.15, 6)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[1.05, K.sect(0.22, 0.28, 0.36, 0.22, 0.28, 0.2, 0.02)], [0.72, K.sect(0.2, 0.32, 0.48, 0.42, 0.48, 0.36, 0.03)],
		[-0.85, K.sect(0.2, 0.32, 0.5, 0.46, 0.5, 0.4, 0.03)], [-1.08, K.sect(0.24, 0.34, 0.46, 0.4, 0.44, 0.32, 0.02)]])
	h.color(RU, Geo.PAINT)
	h.xloft([[0.55, K.sect(0.48, 0.5, 0.62, 0.4, 0.42, 0.3, 0.04)], [-0.15, K.sect(0.48, 0.52, 0.66, 0.42, 0.44, 0.32, 0.04)], [-0.7, K.sect(0.48, 0.5, 0.58, 0.4, 0.42, 0.3, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.16, 0.16]:
		h.plate(Vector3(x, 0.58, 0.62), Vector3(0.14, 0.06, 0.008), Vector3(-48, 0, 0))
	h.color(RU_D, Geo.PAINT)
	h.hatch(Vector3(-0.18, 0.64, 0.28), 0.1)
	h.hatch(Vector3(0.18, 0.64, 0.28), 0.1)
	for s in [-1.0, 1.0]:
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(s * 0.48, 0.4, -0.15), Vector3(0.02, 0.16, 0.22))
		for z in [0.15, -0.15, -0.45]:
			h.box(Vector3(s * 0.49, 0.38, z), Vector3(0.012, 0.02, 0.035))
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -1.02), Vector3(0.55, 0.28, 0.06), 0.01)
	V4._lamps(h, 0.22, 0.4, 0.95)
	_hull_band(h, 0.48, 1.6, 0.4)
	_stow(h, 0.5, -0.2)
	V4._antenna(h, Vector3(-0.32, 0.66, -0.55), 0.55)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.66, 0.05))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.xloft([[0.28, K.sect(0.0, 0.08, 0.2, 0.22, 0.28, 0.16, 0.03)], [-0.32, K.sect(0.0, 0.08, 0.22, 0.26, 0.32, 0.18, 0.03)], [-0.42, K.sect(0.0, 0.06, 0.14, 0.2, 0.24, 0.12, 0.02)]])
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(-0.12, 0.2, -0.08), 0.08)
	t.hatch(Vector3(0.12, 0.2, -0.08), 0.08)
	_smoke(t, 1.0)
	_smoke(t, -1.0)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0.16, 0.08, 0.05), Vector3(0.16, 0.08, 0.42), 0.018, 6)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.22))
	var b = K.new()
	b.color(RU_S, Geo.STEEL)
	b.gun(0.0, 0.95, 0.045, 0.032, 0.55, true, 8)
	b.tube(Vector3(0.07, -0.02, 0.15), Vector3(0.07, -0.02, 0.72), 0.016, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/bmp3.tscn", 1.35, [t, b])

# ------------------------------------------------------------------ BMPT
func _bmpt(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.9, "bar_height": 1.4, "recoil": 0.04, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked(h, 0.62, 2.25, 6)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[1.02, K.sect(0.24, 0.32, 0.4, 0.28, 0.36, 0.22, 0.03)], [0.55, K.sect(0.22, 0.36, 0.55, 0.5, 0.55, 0.4, 0.04)],
		[-0.9, K.sect(0.22, 0.36, 0.55, 0.52, 0.56, 0.42, 0.04)], [-1.1, K.sect(0.26, 0.36, 0.48, 0.46, 0.5, 0.36, 0.03)]])
	h.color(RU, Geo.PAINT)
	for i in 5:
		h.rcbox(Vector3(-0.36 + float(i) * 0.18, 0.58, 0.78), Vector3(0.15, 0.045, 0.14), 0.006, Vector3(-18, 0, 0))
	h.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.42, 0.48, 0.72), Vector3(0.12, 0.08, 0.16), 0.008)
		h.tube(Vector3(s * 0.42, 0.5, 0.78), Vector3(s * 0.42, 0.5, 0.95), 0.02, 6)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.52, 0.92), Vector3(0.28, 0.06, 0.008), Vector3(-55, 0, 0))
	V4._lamps(h, 0.28, 0.42, 0.98)
	_hull_band(h, 0.54, 1.7, 0.42)
	_stow(h, 0.58, -0.35)
	V4._antenna(h, Vector3(0.34, 0.62, -0.7), 0.6)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.62, -0.05))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.cbox(Vector3(0, 0.1, 0), Vector3(0.55, 0.16, 0.5), 0.02)
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.2, -0.05), Vector3(0.28, 0.08, 0.32), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0, 0.2, 0.12), Vector3(0.12, 0.04, 0.008))
	for s in [-1.0, 1.0]:
		t.color(RU_S, Geo.STEEL)
		t.cbox(Vector3(s * 0.22, 0.16, 0.02), Vector3(0.08, 0.1, 0.22), 0.008)
		t.tube(Vector3(s * 0.22, 0.18, 0.1), Vector3(s * 0.22, 0.18, 0.55), 0.02, 6)
		t.color(RU, Geo.PAINT)
		t.cbox(Vector3(s * 0.38, 0.14, -0.02), Vector3(0.1, 0.1, 0.36), 0.01)
		for i in 2:
			t.tube(Vector3(s * 0.38, 0.16 + float(i) * 0.04, 0.02), Vector3(s * 0.38, 0.16 + float(i) * 0.04, 0.38), 0.016, 5)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.16, 0.2))
	var b = K.new()
	b.color(RU_S, Geo.STEEL)
	b.gun(0.0, 0.15, 0.03, 0.03, -1.0, false, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/bmpt.tscn", 1.4, [t, b])

# ------------------------------------------------------------------ T-14
func _t14(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.45, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked(h, 0.66, 2.45, 7)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[1.15, K.sect(0.26, 0.34, 0.42, 0.3, 0.38, 0.24, 0.03)], [0.7, K.sect(0.24, 0.38, 0.58, 0.54, 0.58, 0.44, 0.04)],
		[-1.05, K.sect(0.24, 0.38, 0.58, 0.56, 0.6, 0.46, 0.04)], [-1.22, K.sect(0.28, 0.38, 0.5, 0.5, 0.54, 0.4, 0.03)]])
	h.color(RU, Geo.PAINT)
	for i in 3:
		h.hatch(Vector3(-0.22 + float(i) * 0.22, 0.6, 0.72), 0.09)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.55, 1.02), Vector3(0.36, 0.07, 0.008), Vector3(-50, 0, 0))
	for s in [-1.0, 1.0]:
		h.color(RU_D, Geo.PAINT)
		for i in 6:
			h.rcbox(Vector3(s * 0.52, 0.42, 0.45 - float(i) * 0.22), Vector3(0.06, 0.1, 0.16), 0.008, Vector3(0, 0, -s * 8))
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(s * 0.4, 0.55, -0.85), Vector3(0.18, 0.1, 0.28), 0.012)
	V4._lamps(h, 0.3, 0.44, 1.08)
	_hull_band(h, 0.58, 1.9, 0.44)
	V4._antenna(h, Vector3(-0.28, 0.62, 0.4), 0.7)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.62, -0.15))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.xloft([[0.22, K.sect(0.0, 0.06, 0.16, 0.16, 0.2, 0.1, 0.02)], [-0.15, K.sect(0.0, 0.08, 0.2, 0.22, 0.26, 0.14, 0.03)], [-0.38, K.sect(0.0, 0.05, 0.12, 0.16, 0.18, 0.1, 0.02)]])
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0.1, 0.16, -0.05), Vector3(0.08, 0.06, 0.1), 0.006)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.1, 0.17, 0.01), Vector3(0.05, 0.03, 0.006))
	t.color(RU_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.cbox(Vector3(s * 0.2, 0.1, -0.2), Vector3(0.08, 0.06, 0.16), 0.006)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.16))
	var b = K.new()
	b.color(RU_S, Geo.STEEL)
	b.gun(0.0, 1.15, 0.05, 0.034, 0.62, true, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/t14.tscn", 1.45, [t, b])

# ------------------------------------------------------------------ TOS-1A
func _tos(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.5, "recoil": 0.02, "wreck_s": 7.5, "elevate": 0.35})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked(h, 0.64, 2.3, 6)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.24, 0.32, 0.4, 0.26, 0.34, 0.2, 0.03)], [0.6, K.sect(0.22, 0.36, 0.52, 0.52, 0.56, 0.4, 0.04)],
		[-1.0, K.sect(0.22, 0.36, 0.52, 0.54, 0.58, 0.42, 0.04)], [-1.15, K.sect(0.26, 0.36, 0.46, 0.48, 0.5, 0.36, 0.03)]])
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.62, 0.55), Vector3(0.7, 0.16, 0.45), 0.02)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.7, 0.78), Vector3(0.4, 0.1, 0.008), Vector3(-28, 0, 0))
	h.color(RU_D, Geo.PAINT)
	h.hatch(Vector3(-0.18, 0.72, 0.45), 0.08)
	h.hatch(Vector3(0.18, 0.72, 0.45), 0.08)
	V4._lamps(h, 0.26, 0.42, 0.95)
	_hull_band(h, 0.56, 1.8, 0.4)
	V4._antenna(h, Vector3(-0.3, 0.74, 0.2), 0.45)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.7, -0.15))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.06, -0.15), Vector3(0.55, 0.1, 0.35), 0.015)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.12, -0.05))
	var b = K.new()
	b.color(RU, Geo.PAINT)
	b.cbox(Vector3(0, 0.12, 0.35), Vector3(0.72, 0.38, 0.95), 0.02)
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0.34, 0.35), Vector3(0.76, 0.06, 0.98), 0.008)
	b.color(RU_S, Geo.STEEL)
	for row in 4:
		for col in 6:
			var x := -0.26 + float(col) * 0.104
			var y := -0.02 + float(row) * 0.08
			b.tube(Vector3(x, y, 0.0), Vector3(x, y, 0.82), 0.028, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/tos.tscn", 1.55, [t, b])

# ------------------------------------------------------------------ Iskander
func _iskander(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.05, "bar_height": 1.7, "recoil": 0.0, "wreck_s": 8.0, "elevate": 0.55, "steer_max": 0.35})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	UV8._tyres(h, 0.55, [1.15, 0.62, -0.35, -0.95], 0.2, 0.16, 1, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.38, 0.05), Vector3(0.85, 0.16, 2.5), 0.02)
	h.color(RU, Geo.PAINT)
	h.xloft([[1.35, K.sect(0.42, 0.5, 0.72, 0.28, 0.36, 0.3, 0.04)], [0.85, K.sect(0.42, 0.55, 0.95, 0.48, 0.5, 0.4, 0.04)], [0.35, K.sect(0.42, 0.55, 0.9, 0.5, 0.52, 0.4, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.82, 1.05), Vector3(0.7, 0.22, 0.012), Vector3(-18, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.46, 0.78, 0.7), Vector3(0.012, 0.16, 0.28))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.58, 1.32), 0.4, 0.16, 6)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.55, -0.35), Vector3(0.9, 0.18, 1.3), 0.015)
	V4._lamps(h, 0.32, 0.55, 1.32)
	_hull_band(h, 0.46, 1.4, 0.7)
	V4._antenna(h, Vector3(-0.32, 0.95, 0.55), 0.5)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.66, -0.15))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.05, -0.2), Vector3(0.4, 0.08, 0.4), 0.01)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.1, 0.05))
	var b = K.new()
	b.color(RU, Geo.PAINT)
	b.cbox(Vector3(0, 0.1, 0.7), Vector3(0.42, 0.42, 1.7), 0.02)
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0.34, 0.7), Vector3(0.46, 0.06, 1.74), 0.008)
	b.color(RU_S, Geo.STEEL)
	for i in 8:
		var z := 0.05 + float(i) * 0.18
		b.box(Vector3(0.22, 0.1, z), Vector3(0.015, 0.28, 0.02))
		b.box(Vector3(-0.22, 0.1, z), Vector3(0.015, 0.28, 0.02))
	b.color("#c9b48c", Geo.PAINT)
	b.tube(Vector3(0, 0.1, 1.45), Vector3(0, 0.1, 1.62), 0.12, 8, 0.02)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/iskander.tscn", 1.7, [t, b])

# ------------------------------------------------------------------ Grim Reaper
func _reaper(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.2, "bar_height": 1.9, "recoil": 0.0, "wreck_s": 9.0, "elevate": 0.7, "steer_max": 0.28})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	UV8._tyres(h, 0.62, [1.55, 1.05, 0.15, -0.45, -1.15], 0.22, 0.18, 1, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, 0.1), Vector3(0.95, 0.18, 3.3), 0.02)
	h.color(RU, Geo.PAINT)
	h.xloft([[1.75, K.sect(0.46, 0.55, 0.78, 0.32, 0.4, 0.32, 0.04)], [1.15, K.sect(0.46, 0.58, 1.05, 0.52, 0.55, 0.42, 0.04)], [0.55, K.sect(0.46, 0.58, 1.0, 0.55, 0.58, 0.44, 0.03)]])
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.9, 1.35), Vector3(0.75, 0.24, 0.012), Vector3(-16, 0, 0))
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.5, 0.86, 0.95), Vector3(0.012, 0.18, 0.32))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.62, 1.7), 0.45, 0.18, 7)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.58, -0.35), Vector3(1.0, 0.16, 1.8), 0.015)
	V4._lamps(h, 0.36, 0.58, 1.72)
	_hull_band(h, 0.5, 1.6, 0.78)
	V4._antenna(h, Vector3(-0.36, 1.05, 0.7), 0.55)
	var og = K.new()
	og.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		for z in [0.85, -0.95]:
			og.tube(Vector3(s * 0.4, 0.35, z), Vector3(s * 0.95, 0.02, z), 0.035, 6)
			og.cbox(Vector3(s * 0.98, 0.04, z), Vector3(0.16, 0.04, 0.22), 0.006)
	VK._mi(model, root, "Outriggers", og.commit(mat))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.7, -0.2))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.06, -0.35), Vector3(0.5, 0.1, 0.55), 0.012)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.14, 0.1))
	var b = K.new()
	b.color(RU, Geo.PAINT)
	b.tube(Vector3(0, 0.12, 0.1), Vector3(0, 0.12, 2.15), 0.16, 10, 0.11)
	b.color(RU_D, Geo.PAINT)
	b.tube(Vector3(0, 0.12, 0.2), Vector3(0, 0.12, 0.45), 0.2, 10)
	b.color("#c9b48c", Geo.PAINT)
	b.tube(Vector3(0, 0.12, 2.05), Vector3(0, 0.12, 2.35), 0.1, 8, 0.02)
	b.color(RU_S, Geo.STEEL)
	for i in 6:
		var z := 0.4 + float(i) * 0.26
		b.tube(Vector3(0, 0.12, z), Vector3(0, 0.28, z), 0.012, 4)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/reaper.tscn", 1.9, [t, b, og])

# ------------------------------------------------------------------ Mi-8
func _mi8(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.15, "bar_height": 1.5, "recoil": 0.0, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(RU_D, Geo.PAINT)
	h.tube(Vector3(-0.55, 0.08, 0.15), Vector3(0.55, 0.08, 0.15), 0.06, 6)
	h.tyre(Vector3(-0.7, 0.16, 0.15), 0.16, 0.08, false, RU_S, 10)
	h.tyre(Vector3(0.7, 0.16, 0.15), 0.16, 0.08, false, RU_S, 10)
	h.tyre(Vector3(0, 0.14, -1.15), 0.14, 0.07, true, RU_S, 10)
	h.color(RU, Geo.PAINT)
	h.xloft([[1.15, K.sect(0.28, 0.4, 0.55, 0.08, 0.16, 0.1, 0.04)], [0.7, K.sect(0.22, 0.42, 0.72, 0.28, 0.38, 0.22, 0.05)],
		[-0.55, K.sect(0.22, 0.42, 0.7, 0.32, 0.4, 0.24, 0.05)], [-1.15, K.sect(0.28, 0.4, 0.5, 0.1, 0.16, 0.08, 0.03)], [-2.35, K.sect(0.42, 0.48, 0.55, 0.04, 0.06, 0.04, 0.01)]])
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(-0.28, 0.78, -0.05), Vector3(0.28, 0.16, 0.7), 0.02)
	h.cbox(Vector3(0.28, 0.78, -0.05), Vector3(0.28, 0.16, 0.7), 0.02)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(-0.28, 0.78, 0.32), 0.2, 0.12, 4)
	h.grille(Vector3(0.28, 0.78, 0.32), 0.2, 0.12, 4)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.58, 0.95), Vector3(0.4, 0.16, 0.012), Vector3(-22, 0, 0))
	for s in [-1.0, 1.0]:
		for z in [0.35, -0.05, -0.4]:
			h.box(Vector3(s * 0.4, 0.5, z), Vector3(0.012, 0.12, 0.22))
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(s * 0.38, 0.32, 0.15), Vector3(0.08, 0.06, 0.35), 0.008)
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.48, 0.55), Vector3(0.7, 0.22, 0.04), 0.008)
	V4._antenna(h, Vector3(0.15, 0.7, -0.3), 0.35)
	_hull_band(h, 0.38, 1.2, 0.55)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0.42, 0.42, 0.2), Vector3(0.55, 0.4, 0.55), 0.012, 5)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.95, -0.05), 2.15, 5)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(0.08, 0.55, -2.25), 0.28, 3, true)
	_finish(root, model, h, mat, "res://view/units/ecc/mi8.tscn", 1.35, [])

# ------------------------------------------------------------------ buildings
func _fsb(mat: Material) -> void:
	_structure("fsb", Vector2(3, 3), 1.65, mat, func(g) -> void:
		g.color("#4a4036", Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.55, 0.05), Vector3(2.15, 1.0, 1.7), 0.04)
		g.color("#3c342c", Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 1.08, 0.05), Vector3(2.25, 0.08, 1.8), 0.012)
		g.color(RU_S, Geo.STEEL)
		g.prism_x([Vector2(-0.9, Y0 + 1.12), Vector2(0.9, Y0 + 1.12), Vector2(0.0, Y0 + 1.38)], -0.7, 0.7, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, 0.05)))
		g.windows(Vector3(0, Y0 + 0.7, 0.9), 1.3, 0.28, 5)
		g.color("#2a241e", Geo.DARK)
		g.box(Vector3(0, Y0 + 0.32, 0.92), Vector3(0.55, 0.55, 0.04))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, Y0 + 0.95, 0.93), Vector3(1.4, 0.04, 0.012))
		g.color(RU, Geo.PAINT)
		g.cbox(Vector3(-0.95, Y0 + 0.35, -0.15), Vector3(0.22, 0.6, 0.4), 0.015)
		g.ladder(Vector3(0.95, Y0, -0.7), 1.15, Vector3(1, 0, 0))
		V4._antenna(g, Vector3(0.7, Y0 + 1.15, -0.45), 0.7)
		g.dish(Vector3(-0.55, Y0 + 1.2, -0.4), 0.22, -0.4, 0.2, RU_L)
		g.color(RU_S, Geo.STEEL)
		g.fan(Vector3(0.85, Y0 + 0.85, 0.9), 0.1, 4, 5.0)
	, Callable(), Vector3.ZERO, {"model": {"TowerMount": Vector3(0, Y0 + 1.42, 0.05)}})

func _black_market(mat: Material) -> void:
	_structure("black_market", Vector2(3, 3), 1.7, mat, func(g) -> void:
		g.color("#3e4550", Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.5, 0), Vector3(2.2, 0.9, 1.85), 0.035)
		g.color("#323840", Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.98, 0), Vector3(2.3, 0.08, 1.95), 0.01)
		g.color(RU_S, Geo.STEEL)
		for i in 3:
			var x := -0.7 + float(i) * 0.7
			g.cbox(Vector3(x, Y0 + 0.45, -0.15), Vector3(0.42, 0.7, 0.55), 0.012)
			g.color("#1c2228", Geo.DARK)
			g.grille(Vector3(x, Y0 + 0.5, 0.14), 0.28, 0.4, 6)
			g.color(RU_S, Geo.STEEL)
		g.pulse_color("#3ecf8e", 0.2)
		g.box(Vector3(0, Y0 + 0.72, 0.16), Vector3(0.5, 0.04, 0.01))
		g.end_pulse()
		g.color(GLASS_C, Geo.GLASS)
		g.windows(Vector3(0, Y0 + 0.7, 0.95), 1.5, 0.22, 6)
		g.color("#14181c", Geo.DARK)
		g.box(Vector3(0.7, Y0 + 0.28, 0.96), Vector3(0.4, 0.48, 0.03))
		g.dish(Vector3(-0.75, Y0 + 1.15, -0.45), 0.38, -0.6, 0.35, "#d0d4d2")
		g.dish(Vector3(0.15, Y0 + 1.22, -0.55), 0.22, -0.3, 0.8, "#d0d4d2")
		V4._antenna(g, Vector3(0.75, Y0 + 1.05, -0.2), 0.85)
		g.color(RU_S, Geo.STEEL)
		g.lattice(Vector3(0.85, Y0 + 1.02, 0.35), 0.55, 0.08, 3)
		g.ladder(Vector3(-1.05, Y0, 0.4), 1.05, Vector3(-1, 0, 0))
	, Callable(), Vector3.ZERO, {"model": {"TowerMount": Vector3(0, Y0 + 1.15, 0.15)}})

func _towers(mat: Material) -> void:
	_prop(mat, "res://view/buildings/ecc/tower_bal.tscn", 0.9, func(g) -> void:
		_tower_body(g, RU)
		g.color(RU_S, Geo.STEEL)
		g.tube(Vector3(0, 0.42, 0.06), Vector3(0, 0.42, 0.38), 0.03, 6)
	)
	_prop(mat, "res://view/buildings/ecc/tower_at.tscn", 0.95, func(g) -> void:
		_tower_body(g, RU_D)
		g.color(RU_S, Geo.STEEL)
		g.tube(Vector3(0, 0.4, 0.05), Vector3(0, 0.4, 0.55), 0.035, 6)
		g.cbox(Vector3(0.08, 0.46, 0.12), Vector3(0.08, 0.06, 0.22), 0.006)
	)
	_prop(mat, "res://view/buildings/ecc/tower_aa.tscn", 0.95, func(g) -> void:
		_tower_body(g, RU_L)
		g.color(RU_S, Geo.STEEL)
		for s in [-1.0, 1.0]:
			g.tube(Vector3(s * 0.06, 0.44, 0.04), Vector3(s * 0.06, 0.5, 0.32), 0.018, 5)
		g.dish(Vector3(0, 0.58, -0.02), 0.1, -0.8, 1.2, RU_L)
	)

func _tower_body(g, paint: String) -> void:
	g.color(RU_S, Geo.STEEL)
	g.tube(Vector3(0, 0, 0), Vector3(0, 0.28, 0), 0.06, 6)
	g.color(paint, Geo.PAINT)
	g.cbox(Vector3(0, 0.4, 0), Vector3(0.28, 0.16, 0.28), 0.012)
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(0, 0.42, 0.15), Vector3(0.1, 0.05, 0.008))

func _upgrades(mat: Material) -> void:
	_prop(mat, "res://view/units/ecc/up_tower_bal.tscn", 0.7, func(g) -> void: _tower_body(g, RU))
	_prop(mat, "res://view/units/ecc/up_tower_at.tscn", 0.7, func(g) -> void: _tower_body(g, RU_D))
	_prop(mat, "res://view/units/ecc/up_tower_aa.tscn", 0.7, func(g) -> void: _tower_body(g, RU_L))
	_prop(mat, "res://view/units/ecc/up_era.tscn", 0.45, func(g) -> void:
		g.color(RU, Geo.PAINT)
		for i in 4:
			g.rcbox(Vector3(-0.24 + float(i) * 0.16, 0.08, 0), Vector3(0.13, 0.05, 0.16), 0.006, Vector3(-12, 0, 0))
		g.color(RU_S, Geo.STEEL)
		g.cbox(Vector3(0, 0.02, 0), Vector3(0.7, 0.03, 0.22), 0.004)
	)
	_prop(mat, "res://view/units/ecc/up_red_dawn.tscn", 0.6, func(g) -> void:
		g.color(RU, Geo.PAINT)
		g.xloft([[0.45, K.sect(0.15, 0.2, 0.28, 0.04, 0.08, 0.04, 0.015)], [-0.35, K.sect(0.16, 0.22, 0.3, 0.1, 0.14, 0.06, 0.02)]])
		for s in [-1.0, 1.0]:
			g.box(Vector3(s * 0.22, 0.24, -0.05), Vector3(0.28, 0.03, 0.08))
	)
	_prop(mat, "res://view/units/ecc/up_reaper.tscn", 0.55, func(g) -> void:
		g.color(RU, Geo.PAINT)
		g.tube(Vector3(0, 0.08, -0.4), Vector3(0, 0.08, 0.45), 0.08, 8, 0.05)
		g.color("#c9b48c", Geo.PAINT)
		g.tube(Vector3(0, 0.08, 0.4), Vector3(0, 0.08, 0.55), 0.05, 6, 0.01)
	)
	_prop(mat, "res://view/units/ecc/up_hack_power.tscn", 0.4, func(g) -> void:
		g.color(RU_S, Geo.STEEL)
		g.cbox(Vector3(0, 0.08, 0), Vector3(0.28, 0.14, 0.18), 0.01)
		g.pulse_color("#ffb020", 0.0)
		g.box(Vector3(0, 0.16, 0.1), Vector3(0.06, 0.04, 0.01))
		g.end_pulse()
	)
	_prop(mat, "res://view/units/ecc/up_hack_radar.tscn", 0.45, func(g) -> void:
		g.color(RU_S, Geo.STEEL)
		g.tube(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.02, 5)
		g.dish(Vector3(0, 0.16, 0), 0.16, -0.5, 0.4, RU_L)
	)
	_prop(mat, "res://view/units/ecc/up_hack_funds.tscn", 0.35, func(g) -> void:
		g.color("#c6a15a", Geo.PAINT)
		g.ccyl(0.1, 0.03, 0.004, 10, Transform3D.IDENTITY)
		g.color(RU_S, Geo.STEEL)
		g.box(Vector3(0.14, 0.02, 0), Vector3(0.08, 0.012, 0.04))
	)
	_prop(mat, "res://view/units/ecc/up_hack_hijack.tscn", 0.4, func(g) -> void:
		g.color(RU, Geo.PAINT)
		g.cbox(Vector3(-0.1, 0.06, 0), Vector3(0.16, 0.08, 0.22), 0.008)
		g.cbox(Vector3(0.12, 0.06, 0), Vector3(0.16, 0.08, 0.22), 0.008)
		g.color("#d4654a", Geo.LAMP)
		g.box(Vector3(0.01, 0.12, 0), Vector3(0.08, 0.012, 0.012))
	)
