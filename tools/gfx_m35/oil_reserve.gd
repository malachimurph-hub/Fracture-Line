extends SceneTree
## M3.5 (Malachi: "Supply stashes - change to crude oil reserves"): the supply cache resource
## re-modelled as a crude oil reserve - two storage tanks with a catwalk, ladder and manifold,
## stacks of oil drums on pallets ready for export, on a stained concrete pad. Original
## procedural model on the m3 surface (one mesh, one draw).
##   godot --headless --path . -s res://tools/gfx_m35/oil_reserve.gd
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const OUT := "res://view/neutral/cache.tscn"
const DRUMS := ["#2f4560", "#7a2b22", "#2c2d2b", "#2f4560", "#4a5a3a", "#7a2b22"]

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/wrappers/entity_view.gd"))
	root.set("selection_radius", 0.8)
	root.set("bar_height", 0.79)
	var model := VK._n3(root, root, "Model")
	var g = Geo.new()
	# pad + oil stains
	g.color("#a9a497", Geo.CONCRETE)
	g.box(Vector3(0.05, 0.02, 0.0), Vector3(1.12, 0.04, 0.86))
	g.color("#2a2622", Geo.DARK)
	g.cyl(0.16, 0.16, 0.004, 12, Transform3D(Basis.IDENTITY, Vector3(0.18, 0.04, 0.14)))
	g.cyl(0.09, 0.09, 0.004, 10, Transform3D(Basis.IDENTITY, Vector3(-0.22, 0.04, 0.28)))
	# two vertical storage tanks (back row) with roof cones, a stencil band, ladders
	for k in 2:
		var c := Vector3(-0.28 + k * 0.4, 0.04, -0.2)
		g.color("#c9c4b6", Geo.PAINT)
		g.cyl(0.17, 0.17, 0.34, 18, Transform3D(Basis.IDENTITY, c))
		g.color("#bdb7a8", Geo.PAINT)
		g.cyl(0.175, 0.02, 0.06, 18, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.34, 0)))
		g.color("#8f3a2a", Geo.PAINT)
		g.cyl(0.172, 0.172, 0.03, 18, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.22, 0)), false)
		g.color("#45474a", Geo.STEEL)
		for s in [-1.0, 1.0]:
			g.box(c + Vector3(0.025 * s, 0.17, 0.178), Vector3(0.008, 0.34, 0.008))   # ladder rails
		for r in 6:
			g.box(c + Vector3(0, 0.03 + r * 0.055, 0.178), Vector3(0.05, 0.006, 0.006))   # rungs
		g.tube(c + Vector3(0, 0.05, 0.17), c + Vector3(0, 0.05, 0.3), 0.022, 8)   # outlet
	# catwalk between the tanks
	g.color("#4c4f52", Geo.STEEL)
	g.box(Vector3(-0.08, 0.385, -0.2), Vector3(0.12, 0.012, 0.08))
	g.tube(Vector3(-0.28, 0.09, 0.1), Vector3(0.12, 0.09, 0.1), 0.02, 8)    # manifold
	g.color("#c9a227", Geo.PAINT)
	g.box(Vector3(-0.08, 0.09, 0.1), Vector3(0.05, 0.06, 0.06))              # valve
	# loading rack: drums on pallets, some stacked two high, ready for export
	var spots := [Vector3(0.3, 0, 0.05), Vector3(0.42, 0, 0.05), Vector3(0.3, 0, 0.18), Vector3(0.42, 0, 0.18),
		Vector3(-0.3, 0, 0.3), Vector3(-0.18, 0, 0.3), Vector3(0.3, 0, 0.31)]
	g.color("#8a6e4a", Geo.WOOD)
	g.box(Vector3(0.36, 0.055, 0.12), Vector3(0.28, 0.03, 0.3))
	g.box(Vector3(-0.24, 0.055, 0.3), Vector3(0.26, 0.03, 0.16))
	for i in spots.size():
		var p: Vector3 = spots[i] + Vector3(0, 0.07, 0)
		_drum(g, p, DRUMS[i % DRUMS.size()])
		if i < 2 or i == 4:
			_drum(g, p + Vector3(0, 0.125, 0), DRUMS[(i + 3) % DRUMS.size()])
	# a couple lying on their side
	g.color(DRUMS[1], Geo.PAINT)
	g.tube(Vector3(0.0, 0.085, 0.33), Vector3(0.12, 0.085, 0.36), 0.045, 12)
	VK._mi(model, root, "Body", g.commit(mat))
	VK._save(root, OUT, 0.79)
	print("WROTE ", OUT, " tris ", g.tris)
	quit(0)

static func _drum(g, p: Vector3, col: String) -> void:
	g.color(col, Geo.PAINT)
	g.cyl(0.045, 0.045, 0.12, 12, Transform3D(Basis.IDENTITY, p))
	g.color("#3a3b3c", Geo.STEEL)
	for y in [0.035, 0.085]:
		g.cyl(0.047, 0.047, 0.008, 12, Transform3D(Basis.IDENTITY, p + Vector3(0, y, 0)), false)
	g.cyl(0.03, 0.03, 0.004, 10, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.12, 0)))
