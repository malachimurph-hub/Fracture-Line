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
	# Vehicles live in vehicles_m47.gd (real proportions). This script keeps the buildings.
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

# Vehicle meshes are built by tools/m47/vehicles_m47.gd (published proportions).
# They are not rebuilt here, so running this script cannot put the old hulls back.

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
