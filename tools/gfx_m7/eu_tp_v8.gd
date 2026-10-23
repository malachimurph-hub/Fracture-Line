extends RefCounted
## M2.7b EU / TPLA vehicle remodels (tool-time only; run through tools/gfx_m7/build_v8.sh).
## Leopold: Leopard 2A6-style MBT with the arrowhead wedge add-on armour, chamfered hull, full
## track run, tapered L55 gun. Rattler: the M2.2 technical rebuilt on kit8 (treaded tyres).
## Node layout and pivots match the M2.2 scenes.
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const EU := "#7d8669"
const EU_D := "#5c6551"
const EU_S := "#3c3f40"
const GLASS_C := "#2a3a46"

static func _rattler() -> void:
	VK._rattler(load(VK.MAT_PATH))

static func _leopold() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.43, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.44, 1.5, 7, 0.08, 0.24, EU_S)
	# lower hull: raked nose
	h.color(EU_D, Geo.PAINT)
	h.prism_x([Vector2(-0.7, 0.12), Vector2(0.5, 0.12), Vector2(0.76, 0.3), Vector2(0.76, 0.35), Vector2(-0.74, 0.36), Vector2(-0.76, 0.2)], -0.32, 0.32)
	# upper hull: short steep glacis, flat deck, bevelled edges
	h.color(EU, Geo.PAINT)
	h.xloft([[0.84, K.sect(0.33, 0.34, 0.37, 0.5, 0.55, 0.52, 0.012)], [0.6, K.sect(0.33, 0.36, 0.455, 0.56, 0.58, 0.56, 0.025)],
		[-0.7, K.sect(0.33, 0.36, 0.46, 0.56, 0.58, 0.56, 0.025)], [-0.79, K.sect(0.33, 0.35, 0.42, 0.54, 0.56, 0.54, 0.02)]])
	# skirts: heavy front panels with raked lower edge, lighter rear panels, team band
	for s in [-1.0, 1.0]:
		for i in 5:
			var z0 := -0.7 + i * 0.29
			var heavy := i >= 3
			h.color(EU if i % 2 == 0 else "#727b60", Geo.PAINT)
			h.plate(Vector3(s * (0.595 if heavy else 0.585), 0.29, z0 + 0.14), Vector3(0.045 if heavy else 0.025, 0.15, 0.28), Vector3(0, 0, -s * 5.0))
			if heavy:
				h.plate(Vector3(s * 0.585, 0.205, z0 + 0.14), Vector3(0.04, 0.04, 0.28), Vector3(0, 0, s * 30.0))
			h.color(EU_S, Geo.STEEL)
			for bz in [z0 + 0.05, z0 + 0.23]:
				h.box(Vector3(s * 0.615, 0.34, bz), Vector3(0.01, 0.015, 0.015))
		h.color("#ffffff", Geo.TEAM)
		h.plate(Vector3(s * 0.612, 0.352, -0.06), Vector3(0.012, 0.03, 1.3), Vector3(0, 0, -s * 5.0))
		h.color(EU, Geo.PAINT)   # angled nose plate closing the skirt
		h.plate(Vector3(s * 0.56, 0.27, 0.76), Vector3(0.03, 0.15, 0.1), Vector3(-30, s * 25.0, 0))
	# glacis: driver hatch + periscopes, spare track links, lamps with guards, tow hooks
	h.color(EU_D, Geo.PAINT)
	h.plate(Vector3(-0.18, 0.445, 0.6), Vector3(0.16, 0.022, 0.14), Vector3(0, 0, 0))
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.24, -0.18, -0.12]:
		h.box(Vector3(x, 0.465, 0.55), Vector3(0.04, 0.025, 0.03))
	h.color(EU_S, Geo.STEEL)
	for i in 4:
		h.plate(Vector3(0.12 + i * 0.085, 0.41, 0.725), Vector3(0.075, 0.018, 0.1), Vector3(-24, 0, 0))
	for s in [-1.0, 1.0]:
		h.color("#ffe2a0", Geo.LAMP)
		h.box(Vector3(s * 0.44, 0.39, 0.8), Vector3(0.07, 0.05, 0.02))
		h.color(EU_S, Geo.STEEL)
		h.tube(Vector3(s * 0.44 - 0.05, 0.43, 0.81), Vector3(s * 0.44 + 0.05, 0.43, 0.81), 0.008, 4)
		h.box(Vector3(s * 0.24, 0.27, 0.77), Vector3(0.05, 0.05, 0.06))
	# engine deck: grille, exhaust louvres, tool box, jerry cans, tow cables, rear plate
	h.color("#2e322b", Geo.DARK)
	h.grille(Vector3(0, 0.467, -0.46), 0.52, 0.32, 8)
	h.vent(Vector3(0, 0.38, -0.795), 0.6, 0.08, 4, 180)
	h.color(EU_D, Geo.PAINT)
	h.cbox(Vector3(0.45, 0.5, -0.15), Vector3(0.14, 0.07, 0.44), 0.015)
	h.color("#596245", Geo.PAINT)
	for z in [-0.52, -0.43]:
		h.jerrycan(Vector3(-0.47, 0.51, z), 90)
	h.color("#55524c", Geo.STEEL)
	for x in [-0.5, -0.42]:
		h.tube(Vector3(x, 0.468, -0.3), Vector3(x, 0.468, 0.36), 0.012, 4)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.5, 0.5]:
		h.box(Vector3(x, 0.42, -0.79), Vector3(0.04, 0.03, 0.01))
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	# ---- turret: vertical-sided Leopard box with the arrowhead wedge armour on the front
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.45, -0.06))
	piv.scale = Vector3.ONE * 1.12
	var t = K.new()
	t.color("#35392f", Geo.STEEL)
	t.cyl(0.31, 0.31, 0.03, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.33, -0.36), Vector2(0.33, -0.36), Vector2(0.36, -0.1), Vector2(0.36, 0.22), Vector2(-0.36, 0.22), Vector2(-0.36, -0.1)], 0.0, 0.19, Vector2(0.95, 0.97))
	for s in [-1.0, 1.0]:   # wedge add-on armour: sloped in plan and in elevation
		t.plan_loft([Vector2(s * 0.12, 0.2), Vector2(s * 0.37, 0.2), Vector2(s * 0.16, 0.5), Vector2(s * 0.12, 0.5)], 0.0, 0.18, Vector2(0.93, 0.9), Vector2(0, -0.02))
		t.color(EU_S, Geo.STEEL)
		t.rivets(Vector3(s * 0.33, 0.17, 0.27), Vector3(s * 0.19, 0.17, 0.44), 3, Vector3(0, 1, 0), 0.007)
		t.color(EU, Geo.PAINT)
	# team band around the turret sides and bustle
	t.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.357, 0.11, -0.07), Vector3(0.008, 0.04, 0.5), Vector3(0, 0, s * 1.5))
	t.box(Vector3(0, 0.11, -0.505), Vector3(0.5, 0.04, 0.008))
	t.color(EU_D, Geo.PAINT)
	t.xloft([[-0.34, K.sect(0.02, 0.05, 0.17, 0.27, 0.28, 0.27, 0.025)], [-0.5, K.sect(0.03, 0.06, 0.16, 0.25, 0.26, 0.25, 0.025)]])   # bustle
	t.xloft([[0.48, K.sect(0.04, 0.06, 0.17, 0.1, 0.11, 0.09, 0.025)], [0.3, K.sect(0.02, 0.05, 0.18, 0.12, 0.12, 0.11, 0.025)]])   # mantlet
	# bustle basket + stowage
	t.color("#3d4238", Geo.STEEL)
	t.rail([Vector3(-0.3, 0.17, -0.5), Vector3(-0.3, 0.17, -0.6), Vector3(0.3, 0.17, -0.6), Vector3(0.3, 0.17, -0.5)], 0.07, 0.1, 0.006)
	t.color("#7f7556", Geo.CANVAS)
	t.tube(Vector3(-0.26, 0.21, -0.54), Vector3(0.06, 0.21, -0.54), 0.045, 8)
	t.color("#7a5c3a", Geo.WOOD)
	t.cbox(Vector3(0.18, 0.21, -0.54), Vector3(0.14, 0.08, 0.1), 0.012)
	# PERI on a raised mount, commander's hatch ring, gunner's sight, MG, smoke dischargers, antennas
	t.color(EU_D, Geo.PAINT)
	t.ccyl(0.085, 0.05, 0.012, 10, Transform3D(Basis.IDENTITY, Vector3(-0.15, 0.19, -0.12)))
	t.color(GLASS_C, Geo.GLASS)
	for i in 6:
		var a := TAU * float(i) / 6.0
		t.box(Vector3(-0.15 + cos(a) * 0.08, 0.225, -0.12 + sin(a) * 0.08), Vector3(0.025, 0.018, 0.025))
	t.color(EU_D, Geo.PAINT)
	t.tube(Vector3(-0.2, 0.19, 0.08), Vector3(-0.2, 0.3, 0.08), 0.035, 8)   # PERI R17 head
	t.cbox(Vector3(-0.2, 0.33, 0.08), Vector3(0.08, 0.07, 0.09), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.2, 0.335, 0.127), Vector3(0.055, 0.04, 0.006))
	t.color(EU_D, Geo.PAINT)
	t.cbox(Vector3(0.22, 0.215, 0.14), Vector3(0.1, 0.06, 0.12), 0.012)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.22, 0.22, 0.202), Vector3(0.07, 0.035, 0.006))
	t.color(EU_D, Geo.PAINT)
	t.hatch(Vector3(0.14, 0.19, -0.1), 0.13)
	t.color("#2b2b2a", Geo.STEEL)
	t.tube(Vector3(0.14, 0.27, -0.12), Vector3(0.14, 0.28, 0.1), 0.01, 5)
	t.box(Vector3(0.14, 0.27, -0.1), Vector3(0.035, 0.04, 0.08))
	for s in [-1.0, 1.0]:
		for i in 4:
			var o := Vector3(s * 0.34, 0.2, -0.3 + i * 0.035)
			t.tube(o, o + Vector3(s * 0.05, 0.035, 0.02), 0.012, 6)
		t.tube(Vector3(s * 0.26, 0.19, -0.42), Vector3(s * 0.26, 0.75, -0.44), 0.005, 3)
		t.box(Vector3(s * 0.26, 0.19, -0.42), Vector3(0.03, 0.03, 0.03))
	VK._mi(piv, root, "Turret", t.commit(mat))
	# ---- barrel (recoils along -z): long L55, thermal sleeve, fume extractor, muzzle reference
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.11, 0.47))
	var b = K.new()
	b.color(EU_D, Geo.PAINT)
	b.tube(Vector3(0, 0, -0.04), Vector3(0, 0, 0.06), 0.06, 10, 0.05)
	b.color(EU, Geo.PAINT)
	b.gun(0.0, 1.08, 0.04, 0.032, 0.42, false, 10)
	b.color(EU_D, Geo.PAINT)
	for z in [0.2, 0.7, 0.9]:
		b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.025), 0.044, 10)
	b.color("#2b2b2a", Geo.STEEL)
	b.tube(Vector3(0, 0, 1.05), Vector3(0, 0, 1.1), 0.038, 10)
	b.box(Vector3(0, 0.045, 1.07), Vector3(0.025, 0.02, 0.04))
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	print("  leopold: %d tris in 3 meshes" % [h.tris + t.tris + b.tris])
	VK._save(root, "res://view/units/eu/leopold.tscn", 1.43)
