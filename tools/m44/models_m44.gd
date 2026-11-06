extends "res://tools/m41/models_m41.gd"
## M4.4 US tech-tree models. Smooth flat colour, no grain. Original geometry.
##   godot --headless --path . -s res://tools/m44/models_m44.gd

const OLIVE := "#6d7358"
const OLIVE_D := "#545a46"
const GREY := "#8b9194"
const GREY_D := "#5c6368"
const CREAM := "#d5d2c8"

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	struct_fac = "us"
	_substation(mat)
	_nuclear(mat)
	_darpa(mat)
	_socom(mat)
	_robotics(mat)
	_zeus_launcher(mat)
	_zeus_pylon(mat)
	_littlebird(mat)
	_ah64(mat)
	_reaper(mat)
	_f16(mat)
	_yf22(mat)
	_f35(mat)
	_b1(mat)
	_ripsaw(mat)
	_upgrade(mat, "up_aero", func(h) -> void:
		h.color(GREY, Geo.PAINT)
		h.cbox(Vector3(0, 0.15, 0), Vector3(1.4, 0.08, 0.35), 0.01)
		h.cbox(Vector3(0.15, 0.22, -0.15), Vector3(0.2, 0.12, 0.7), 0.02)
	)
	_upgrade(mat, "up_robotics", func(h) -> void:
		h.color(GREY_D, Geo.STEEL)
		h.cyl(0.28, 0.28, 0.1, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)))
		h.box(Vector3(0, 0.28, 0), Vector3(0.1, 0.35, 0.1))
		h.box(Vector3(0.22, 0.22, 0), Vector3(0.28, 0.08, 0.08))
	)
	_upgrade(mat, "up_nuclear", func(h) -> void:
		h.color(CREAM, Geo.CONCRETE)
		h.cyl(0.32, 0.32, 0.28, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
		h.dome(0.32, 0.28, 5, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0)))
	)
	_upgrade(mat, "up_zeus", func(h) -> void:
		h.color(OLIVE, Geo.PAINT)
		h.cbox(Vector3(0, 0.4, 0), Vector3(0.18, 0.7, 0.18), 0.02)
		h.color(GREY_D, Geo.STEEL)
		h.cyl(0.1, 0.06, 0.1, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0)))
	)
	var f := FileAccess.open("/tmp/m44_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line(p)
	print("M44 wrote %d scenes" % wrote.size())
	quit(0)

func _bld(short: String, fp: Vector2, top: float, mat: Material, hull_fn: Callable) -> void:
	_structure(short, fp, top, mat, hull_fn, Callable(), Vector3.ZERO, {})

func _substation(mat: Material) -> void:
	_bld("substation", Vector2(3, 3), 1.7, mat, func(g) -> void:
		g.color(GREY_D, Geo.STEEL)
		g.cbox(Vector3(-0.7, Y0 + 0.28, -0.2), Vector3(0.9, 0.5, 0.7), 0.02)
		g.color(CREAM, Geo.PAINT)
		g.cbox(Vector3(-0.7, Y0 + 0.56, -0.2), Vector3(0.96, 0.06, 0.76), 0.01)
		g.color("#2a3a46", Geo.GLASS)
		g.box(Vector3(-0.7, Y0 + 0.32, 0.16), Vector3(0.5, 0.18, 0.02))
		g.color(GREY, Geo.STEEL)
		for i in 3:
			var x := 0.15 + float(i) * 0.48
			g.cyl(0.22, 0.22, 0.55, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0, -0.55)))
			g.color(OLIVE, Geo.PAINT)
			g.cyl(0.16, 0.16, 0.12, 10, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.55, -0.55)))
			g.color(GREY, Geo.STEEL)
		g.color(GREY_D, Geo.STEEL)
		for y in [0.7, 0.95, 1.2]:
			g.box(Vector3(0.55, Y0 + y, 0.35), Vector3(1.6, 0.03, 0.03))
		for x2 in [-0.15, 0.55, 1.25]:
			g.tube(Vector3(x2, Y0, 0.35), Vector3(x2, Y0 + 1.35, 0.35), 0.035, 6)
			g.color("#c9b48c", Geo.PAINT)
			g.cyl(0.06, 0.08, 0.16, 8, Transform3D(Basis.IDENTITY, Vector3(x2, Y0 + 0.35, 0.35)))
			g.color(GREY_D, Geo.STEEL)
	)

func _nuclear(mat: Material) -> void:
	_structure("reactor", Vector2(4, 4), 3.2, mat, func(g) -> void:
		g.color(CREAM, Geo.CONCRETE)
		g.cyl(0.85, 0.85, 0.7, 16, Transform3D(Basis.IDENTITY, Vector3(-0.55, Y0, -0.35)))
		g.color("#e7e4da", Geo.CONCRETE)
		g.dome(0.85, 0.7, 6, 16, Transform3D(Basis.IDENTITY, Vector3(-0.55, Y0 + 0.7, -0.35)))
		g.color("#7fd0ea", Geo.GLASS)
		g.cyl(0.55, 0.55, 0.08, 16, Transform3D(Basis.IDENTITY, Vector3(-0.55, Y0 + 0.42, -0.35)))
		g.color(GREY, Geo.STEEL)
		g.cbox(Vector3(0.85, Y0 + 0.4, 0.15), Vector3(1.5, 0.8, 1.6), 0.03)
		g.color(GREY_D, Geo.STEEL)
		g.cbox(Vector3(0.85, Y0 + 0.84, 0.15), Vector3(1.58, 0.08, 1.68), 0.01)
		for s in [-1.0, 1.0]:
			g.color(CREAM, Geo.CONCRETE)
			g.cyl(0.28, 0.38, 1.7, 12, Transform3D(Basis.IDENTITY, Vector3(s * 1.15, Y0, -1.25)))
			g.cyl(0.34, 0.28, 0.28, 12, Transform3D(Basis.IDENTITY, Vector3(s * 1.15, Y0 + 1.7, -1.25)))
	, Callable(), Vector3.ZERO, {"model": {"Stack0": Vector3(-1.15, Y0 + 2.05, -1.25), "Stack1": Vector3(1.15, Y0 + 2.05, -1.25)}})

func _darpa(mat: Material) -> void:
	_bld("darpa", Vector2(4, 4), 1.7, mat, func(g) -> void:
		g.color("#d9d6cc", Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.45, -0.15), Vector3(2.8, 0.9, 2.2), 0.04)
		g.color("#9aa3a8", Geo.STEEL)
		g.cbox(Vector3(0, Y0 + 0.95, -0.15), Vector3(2.9, 0.08, 2.3), 0.01)
		g.color("#243640", Geo.GLASS)
		g.box(Vector3(0, Y0 + 0.5, 0.96), Vector3(2.2, 0.42, 0.02))
		g.color(GREY, Geo.STEEL)
		g.cyl(0.02, 0.02, 0.7, 6, Transform3D(Basis.IDENTITY, Vector3(1.15, Y0 + 1.0, -0.9)))
		g.dome(0.28, 0.12, 4, 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(1.15, Y0 + 1.45, -0.7)))
		g.cyl(0.015, 0.015, 0.55, 6, Transform3D(Basis.IDENTITY, Vector3(-1.2, Y0 + 1.0, -1.0)))
		g.dome(0.18, 0.08, 3, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.2, Y0 + 1.32, -0.85)))
	)

func _socom(mat: Material) -> void:
	_bld("socom", Vector2(3, 3), 1.35, mat, func(g) -> void:
		g.color(OLIVE_D, Geo.CONCRETE)
		g.cbox(Vector3(0, Y0 + 0.32, 0), Vector3(2.2, 0.64, 1.8), 0.03)
		g.color(OLIVE, Geo.PAINT)
		g.cbox(Vector3(0, Y0 + 0.68, 0), Vector3(2.3, 0.08, 1.9), 0.01)
		g.color("#1c2420", Geo.DARK)
		g.box(Vector3(0, Y0 + 0.28, 0.92), Vector3(0.4, 0.46, 0.04))
		g.color(GREY_D, Geo.STEEL)
		for x in [-0.7, -0.2, 0.35, 0.8]:
			g.tube(Vector3(x, Y0 + 0.72, -0.4), Vector3(x, Y0 + 1.15, -0.4), 0.02, 5)
		g.box(Vector3(0.1, Y0 + 1.2, -0.4), Vector3(1.3, 0.02, 0.02))
	)

func _robotics(mat: Material) -> void:
	_bld("robotics", Vector2(4, 3), 1.8, mat, func(g) -> void:
		g.color(GREY, Geo.STEEL)
		g.cbox(Vector3(0, Y0 + 0.55, -0.15), Vector3(3.2, 1.1, 2.0), 0.03)
		g.color("#243038", Geo.GLASS)
		g.box(Vector3(0, Y0 + 0.55, 0.86), Vector3(2.4, 0.6, 0.02))
		g.color(GREY_D, Geo.STEEL)
		g.box(Vector3(0, Y0 + 1.25, 0.2), Vector3(2.6, 0.08, 0.12))
		g.box(Vector3(-1.2, Y0 + 0.85, 0.2), Vector3(0.08, 0.8, 0.08))
		g.box(Vector3(1.2, Y0 + 0.85, 0.2), Vector3(0.08, 0.8, 0.08))
		g.box(Vector3(0.2, Y0 + 0.7, 0.35), Vector3(0.08, 0.7, 0.08))
		g.box(Vector3(0.45, Y0 + 0.4, 0.55), Vector3(0.5, 0.06, 0.08))
	)

func _zeus_launcher(mat: Material) -> void:
	_bld("zeus_launcher", Vector2(4, 3), 1.6, mat, func(g) -> void:
		g.color(OLIVE_D, Geo.PAINT)
		g.cbox(Vector3(0, Y0 + 0.18, 0.15), Vector3(3.3, 0.22, 1.3), 0.02)
		g.color("#2a2c2a", Geo.RUBBER)
		for z in [-0.45, 0.55]:
			for x in [-1.2, 1.2]:
				g.cyl(0.18, 0.18, 0.12, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, Y0 + 0.18, z)))
		g.color(OLIVE, Geo.PAINT)
		for i in 6:
			var x := -1.05 + float(i) * 0.42
			g.cbox(Vector3(x, Y0 + 0.85, -0.05), Vector3(0.26, 1.15, 0.26), 0.02)
			g.color(GREY_D, Geo.STEEL)
			g.cyl(0.08, 0.08, 0.08, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 1.45, -0.05)))
			g.color(OLIVE, Geo.PAINT)
		g.color(GREY_D, Geo.STEEL)
		g.cbox(Vector3(-1.45, Y0 + 0.48, -0.15), Vector3(0.45, 0.45, 0.75), 0.02)
	)

func _zeus_pylon(mat: Material) -> void:
	_bld("zeus_pylon", Vector2(2, 2), 2.4, mat, func(g) -> void:
		g.color(GREY_D, Geo.STEEL)
		g.tube(Vector3(-0.28, Y0, -0.28), Vector3(-0.1, Y0 + 2.0, -0.1), 0.04, 5)
		g.tube(Vector3(0.28, Y0, -0.28), Vector3(0.1, Y0 + 2.0, -0.1), 0.04, 5)
		g.tube(Vector3(-0.28, Y0, 0.28), Vector3(-0.1, Y0 + 2.0, 0.1), 0.04, 5)
		g.tube(Vector3(0.28, Y0, 0.28), Vector3(0.1, Y0 + 2.0, 0.1), 0.04, 5)
		for y in [0.6, 1.2, 1.8]:
			g.box(Vector3(0, Y0 + y, 0), Vector3(0.5, 0.03, 0.03))
			g.box(Vector3(0, Y0 + y, 0), Vector3(0.03, 0.03, 0.5))
		g.color(GREY, Geo.STEEL)
		g.cyl(0.22, 0.22, 0.06, 12, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 2.05, 0)))
		g.box(Vector3(0, Y0 + 2.18, 0.16), Vector3(0.55, 0.32, 0.04))
	)

func _heli(mat: Material, name: String, bar: float, rotor_at: Vector3, rotor_r: float, body: Callable) -> void:
	var root := VK._root({"selection_radius": maxf(0.6, rotor_r * 0.55), "bar_height": bar})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	body.call(h)
	UV8._rotor(model, root, mat, "Rotor", rotor_at, rotor_r, 4 if rotor_r < 1.6 else 5)
	_finish(root, model, h, mat, "res://view/units/us/%s.tscn" % name, bar, [])

func _littlebird(mat: Material) -> void:
	_heli(mat, "littlebird", 0.95, Vector3(0, 0.62, 0.05), 1.15, func(h) -> void:
		h.color(GREY, Geo.PAINT)
		h.cbox(Vector3(0, 0.28, 0.05), Vector3(0.5, 0.34, 1.05), 0.04)
		h.color("#243038", Geo.GLASS)
		h.box(Vector3(0, 0.36, 0.4), Vector3(0.36, 0.14, 0.02))
		h.color(GREY_D, Geo.STEEL)
		h.tube(Vector3(-0.26, 0.06, -0.4), Vector3(-0.26, 0.06, 0.5), 0.018, 5)
		h.tube(Vector3(0.26, 0.06, -0.4), Vector3(0.26, 0.06, 0.5), 0.018, 5)
		h.color(GREY, Geo.PAINT)
		h.box(Vector3(0, 0.3, -0.72), Vector3(0.07, 0.08, 0.4))
		h.box(Vector3(0, 0.38, -0.92), Vector3(0.26, 0.1, 0.03))
	)

func _ah64(mat: Material) -> void:
	_heli(mat, "ah64", 1.15, Vector3(0, 0.72, -0.05), 1.45, func(h) -> void:
		h.color(OLIVE, Geo.PAINT)
		h.cbox(Vector3(0, 0.32, 0.05), Vector3(0.55, 0.4, 1.45), 0.03)
		h.color(OLIVE_D, Geo.PAINT)
		h.cbox(Vector3(0, 0.22, 0.15), Vector3(1.35, 0.08, 0.28), 0.01)   # stub wings
		h.color(GREY_D, Geo.STEEL)
		for s in [-1.0, 1.0]:
			h.tube(Vector3(s * 0.4, 0.22, 0.15), Vector3(s * 0.4, 0.22, 0.45), 0.035, 6)
			h.tube(Vector3(s * 0.62, 0.22, 0.15), Vector3(s * 0.62, 0.22, 0.42), 0.03, 6)
		h.color(OLIVE, Geo.PAINT)
		h.box(Vector3(0, 0.34, -0.95), Vector3(0.1, 0.12, 0.55))
		h.box(Vector3(0, 0.48, -1.25), Vector3(0.32, 0.16, 0.04))
		# chin turret, no cockpit crew figure
		h.color(GREY_D, Geo.STEEL)
		h.cyl(0.1, 0.1, 0.1, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0.62)))
		h.tube(Vector3(0.08, 0.16, 0.62), Vector3(0.08, 0.14, 0.95), 0.025, 6)
	)

func _reaper(mat: Material) -> void:
	# Fixed-wing drone: long wings, sensor ball, no canopy.
	var root := VK._root({"selection_radius": 1.6, "bar_height": 0.7})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(GREY, Geo.PAINT)
	h.cbox(Vector3(0, 0.28, 0), Vector3(0.28, 0.22, 1.7), 0.02)
	h.cbox(Vector3(0, 0.3, 0.05), Vector3(3.1, 0.05, 0.42), 0.005)   # wing
	h.color(GREY_D, Geo.STEEL)
	h.box(Vector3(0, 0.42, -0.85), Vector3(0.04, 0.22, 0.28))   # V tail posts
	h.box(Vector3(-0.16, 0.52, -0.9), Vector3(0.28, 0.02, 0.16))
	h.box(Vector3(0.16, 0.52, -0.9), Vector3(0.28, 0.02, 0.16))
	h.color("#1e2428", Geo.DARK)
	h.cyl(0.07, 0.07, 0.08, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0.35)))   # sensor ball
	h.color(GREY_D, Geo.STEEL)
	h.cyl(0.08, 0.1, 0.16, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, -0.55)))   # pusher
	_finish(root, model, h, mat, "res://view/units/us/reaper.tscn", 0.7, [])

func _jet(mat: Material, name: String, bar: float, body: Callable) -> void:
	var root := VK._root({"selection_radius": 1.3, "bar_height": bar})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	body.call(h)
	_finish(root, model, h, mat, "res://view/units/us/%s.tscn" % name, bar, [])

func _f16(mat: Material) -> void:
	_jet(mat, "f16", 0.7, func(h) -> void:
		h.color(GREY, Geo.PAINT)
		h.cbox(Vector3(0, 0.22, 0), Vector3(0.32, 0.26, 1.7), 0.03)
		h.cbox(Vector3(0, 0.2, 0.05), Vector3(1.55, 0.05, 0.55), 0.008)
		h.box(Vector3(0, 0.42, -0.55), Vector3(0.04, 0.32, 0.4))
		h.color("#243038", Geo.GLASS)
		h.box(Vector3(0, 0.36, 0.35), Vector3(0.18, 0.1, 0.28))
		h.color(GREY_D, Geo.STEEL)
		h.cyl(0.1, 0.14, 0.2, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.85)))
	)

func _yf22(mat: Material) -> void:
	_jet(mat, "yf22", 0.75, func(h) -> void:
		h.color(GREY_D, Geo.PAINT)
		h.cbox(Vector3(0, 0.22, 0.05), Vector3(0.7, 0.22, 1.8), 0.04)   # diamond body
		h.cbox(Vector3(0, 0.2, 0.1), Vector3(1.9, 0.05, 0.7), 0.006)
		h.color(GREY, Geo.PAINT)
		h.box(Vector3(-0.22, 0.4, -0.7), Vector3(0.28, 0.28, 0.04))
		h.box(Vector3(0.22, 0.4, -0.7), Vector3(0.28, 0.28, 0.04))
		h.color("#1c2428", Geo.DARK)
		h.box(Vector3(0, 0.34, 0.55), Vector3(0.16, 0.06, 0.22))   # flush canopy, no bubble
	)

func _f35(mat: Material) -> void:
	_jet(mat, "f35", 0.72, func(h) -> void:
		h.color(GREY, Geo.PAINT)
		h.cbox(Vector3(0, 0.24, 0), Vector3(0.55, 0.28, 1.65), 0.04)
		h.cbox(Vector3(0, 0.2, 0.05), Vector3(1.7, 0.05, 0.6), 0.006)
		h.box(Vector3(0, 0.46, -0.6), Vector3(0.05, 0.28, 0.38))
		h.color("#1c2428", Geo.DARK)
		h.box(Vector3(0, 0.38, 0.4), Vector3(0.2, 0.08, 0.26))
		h.color(GREY_D, Geo.STEEL)
		h.cyl(0.12, 0.16, 0.18, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.82)))
	)

func _b1(mat: Material) -> void:
	_jet(mat, "b1", 0.85, func(h) -> void:
		h.color(GREY, Geo.PAINT)
		h.cbox(Vector3(0, 0.28, 0), Vector3(0.7, 0.32, 2.6), 0.03)
		h.cbox(Vector3(0, 0.26, 0.1), Vector3(2.6, 0.06, 0.85), 0.008)
		h.color(GREY_D, Geo.STEEL)
		for s in [-1.0, 1.0]:
			h.cyl(0.08, 0.1, 0.22, 8, Transform3D(Basis.IDENTITY, Vector3(s * 0.35, 0.18, -0.3)))
			h.cyl(0.08, 0.1, 0.22, 8, Transform3D(Basis.IDENTITY, Vector3(s * 0.55, 0.18, 0.25)))
		h.color("#243038", Geo.GLASS)
		h.box(Vector3(0, 0.46, 0.85), Vector3(0.28, 0.1, 0.3))
	)

func _upgrade(mat: Material, name: String, body: Callable) -> void:
	var root := Node3D.new()
	root.name = "View"
	var h = K.new()
	body.call(h)
	VK._mi(root, root, "Hull", h.commit(mat))
	VK._save(root, "res://view/units/us/%s.tscn" % name, 0.6)
	wrote.append("res://view/units/us/%s.tscn" % name)

func _ripsaw(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.55, "bar_height": 0.7, "steer_max": 0.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color("#5e655f", Geo.PAINT)
	h.cbox(Vector3(0, 0.22, 0), Vector3(0.7, 0.28, 1.15), 0.03)
	h.color("#2a2c2a", Geo.RUBBER)
	h.box(Vector3(-0.38, 0.16, 0), Vector3(0.1, 0.28, 1.05))
	h.box(Vector3(0.38, 0.16, 0), Vector3(0.1, 0.28, 1.05))
	# remote turret: sensor mast, no hatch
	var pv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.38, 0.05))
	var t = K.new()
	t.color("#4e554f", Geo.PAINT)
	t.cbox(Vector3(0, 0.06, 0), Vector3(0.38, 0.14, 0.5), 0.02)
	t.color(GREY_D, Geo.STEEL)
	t.tube(Vector3(0, 0.1, 0.12), Vector3(0, 0.08, 0.55), 0.03, 6)   # main gun, short
	t.tube(Vector3(0.1, 0.12, 0.05), Vector3(0.1, 0.12, 0.38), 0.015, 5)   # coaxial
	t.cyl(0.04, 0.04, 0.12, 6, Transform3D(Basis.IDENTITY, Vector3(0, 0.18, -0.05)))   # sensor, no crew
	VK._mi(pv, root, "Turret", t.commit(mat))
	var bn := VK._n3(pv, root, "Barrel", Vector3(0, 0.1, 0.2))
	var b = K.new()
	b.color(GREY_D, Geo.STEEL)
	b.tube(Vector3(0, 0, 0), Vector3(0, 0, 0.28), 0.028, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/us/ripsaw.tscn", 0.72, [t, b])
