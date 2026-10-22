extends RefCounted
## M2.2 EU Barracks (tool-time): Quonset-style corrugated hall on a concrete pad with an
## entrance vestibule, dormer windows, roof vents, comms mast, floodlights, flag and sandbag
## positions; plus the construction scaffold, two damage overlays, rubble and fire anchors for
## BuildingView. Original procedural geometry (tools/gfx_m3/geo.gd).
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")

const CX := 0.0
const CZ := -0.3        ## hall axis z
const R := 0.86         ## hall radius
const HL := 1.12        ## hall half length (x)
const Y0 := 0.1         ## pad top

static func build_all() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/buildings/building_view.gd"))
	root.set("selection_radius", 1.5)
	root.set("bar_height", 1.77)
	root.set("footprint", Vector2(3, 3))
	root.set("is_structure", true)
	root.set("top_y", Y0 + R + 0.95)
	root.set("scaffold_top", 1.3)
	var model := VK._n3(root, root, "Model")
	var f = _foundation()
	VK._mi(model, root, "Foundation", f.commit(mat))
	var h = _hall()
	VK._mi(model, root, "Hull", h.commit(mat))
	var s = _scaffold()
	var sm := VK._mi(model, root, "Scaffold", s.commit(mat))
	sm.visible = false
	var l = _damage_light()
	var lm := VK._mi(model, root, "DamageLight", l.commit(mat))
	lm.visible = false
	var hv = _damage_heavy()
	var hm := VK._mi(model, root, "DamageHeavy", hv.commit(mat))
	hm.visible = false
	var rb = _rubble()
	var rm := VK._mi(model, root, "Rubble", rb.commit(mat))
	rm.visible = false
	var i := 0
	for p in [Vector3(-0.55, 0.95, CZ + 0.2), Vector3(0.45, 0.9, CZ - 0.25), Vector3(0.1, 0.6, 0.55)]:
		var mk := Marker3D.new()
		mk.name = "Fire%d" % i
		mk.position = p
		model.add_child(mk)
		mk.owner = root
		i += 1
	VK._report("barracks (hull/scaffold/foundation/light/heavy/rubble)", [h, s, f, l, hv, rb])
	VK._save(root, "res://view/buildings/eu/barracks.tscn", 1.77)

static func _foundation():
	var g = Geo.new()
	g.color("#a39b8b", Geo.CONCRETE)
	g.bbox(Vector3(0, Y0 * 0.5, 0), Vector3(2.92, Y0, 2.92), 0.03)
	g.color("#8f8879", Geo.CONCRETE)
	g.box(Vector3(0, 0.05, 1.5), Vector3(0.8, 0.05, 0.12))      # entrance step
	g.color("#d8a531", Geo.PAINT)
	for z in [1.28, -1.28]:
		g.box(Vector3(0, Y0 + 0.004, z), Vector3(2.5, 0.008, 0.05))
	g.color("#e4e0d6", Geo.PAINT)
	for i in 5:   # parking / assembly marks
		g.box(Vector3(-1.0 + i * 0.5, Y0 + 0.004, 1.0), Vector3(0.04, 0.008, 0.3))
	return g

## Hall arc profile in (z, y), segs points over 180 degrees.
static func _arc(r: float, segs: int) -> Array:
	var pts: Array = []
	for i in segs + 1:
		var a := PI * float(i) / float(segs)
		pts.append(Vector2(CZ + cos(a) * r, Y0 + sin(a) * r))
	return pts

static func _hall():
	var g = Geo.new()
	# corrugated half-cylinder shell, end walls (caps), ribs
	g.color("#6f7b5f", Geo.CORR)
	g.prism_x(_arc(R, 16), -HL, HL)
	g.color("#4e5646", Geo.STEEL)
	for x in [-HL + 0.02, -0.55, 0.0, 0.55, HL - 0.02]:
		g.prism_x(_arc(R + 0.018, 16), x - 0.025, x + 0.025)
	# base kerb + team stripes along both sides
	g.color("#8f8879", Geo.CONCRETE)
	for z in [CZ + R, CZ - R]:
		g.box(Vector3(0, Y0 + 0.05, z), Vector3(HL * 2.0 + 0.06, 0.1, 0.08))
	g.color("#ffffff", Geo.TEAM)
	for side in [1.0, -1.0]:
		var a := deg_to_rad(90.0 - side * 72.0)
		var p := Vector3(0, Y0 + sin(a) * (R + 0.012), CZ + cos(a) * (R + 0.012))
		g.box(Vector3.ZERO, Vector3(HL * 2.0 - 0.1, 0.07, 0.02), Transform3D(Basis(Vector3.RIGHT, -(a - PI * 0.5)), p))
	# end walls: east door + windows, west window + AC unit
	g.color("#3b3f3a", Geo.STEEL)
	g.box(Vector3(HL + 0.012, Y0 + 0.3, CZ), Vector3(0.02, 0.6, 0.42))
	g.color("#1d1f1e", Geo.DARK)
	g.box(Vector3(HL + 0.024, Y0 + 0.28, CZ), Vector3(0.01, 0.54, 0.34))
	g.color("#ffd27a", Geo.LAMP)
	g.box(Vector3(HL + 0.04, Y0 + 0.66, CZ), Vector3(0.03, 0.04, 0.08))
	for ex in [HL, -HL]:
		var sx := signf(ex)
		for dz in ([-0.45, 0.45] if sx > 0 else [-0.35, 0.0, 0.35]):
			g.color("#3b3f3a", Geo.STEEL)
			g.box(Vector3(ex + sx * 0.012, Y0 + 0.5, CZ + dz), Vector3(0.02, 0.2, 0.2))
			g.color("#2a3a46", Geo.GLASS)
			g.box(Vector3(ex + sx * 0.024, Y0 + 0.5, CZ + dz), Vector3(0.01, 0.16, 0.16))
	g.color("#7d8287", Geo.PAINT)
	g.bbox(Vector3(-HL - 0.12, Y0 + 0.16, CZ + 0.5), Vector3(0.22, 0.3, 0.34), 0.02)
	g.color("#2e322b", Geo.DARK)
	g.cyl(0.11, 0.11, 0.01, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-HL - 0.23, Y0 + 0.17, CZ + 0.5)))
	# entrance vestibule (front, +z)
	g.color("#66705c", Geo.PAINT)
	g.bbox(Vector3(0, Y0 + 0.34, CZ + R + 0.06), Vector3(0.72, 0.68, 0.5), 0.02)
	g.color("#4e5646", Geo.PAINT)
	g.bbox(Vector3(0, Y0 + 0.71, CZ + R + 0.1), Vector3(0.82, 0.06, 0.62), 0.015)
	g.color("#3b3f3a", Geo.STEEL)
	g.box(Vector3(0, Y0 + 0.27, CZ + R + 0.315), Vector3(0.36, 0.54, 0.02))
	g.color("#1d1f1e", Geo.DARK)
	g.box(Vector3(0, Y0 + 0.25, CZ + R + 0.33), Vector3(0.3, 0.5, 0.01))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.6, CZ + R + 0.315), Vector3(0.5, 0.1, 0.02))
	g.color("#ffd27a", Geo.LAMP)
	g.box(Vector3(0, Y0 + 0.55, CZ + R + 0.33), Vector3(0.08, 0.03, 0.03))
	# dormer windows on the front slope
	for x in [-0.82, -0.5, 0.5, 0.82]:
		var a := deg_to_rad(52.0)
		var p := Vector3(x, Y0 + sin(a) * R, CZ + cos(a) * R)
		var t := Transform3D(Basis(Vector3.RIGHT, -(a - PI * 0.5) * 0.5), p)
		g.color("#4e5646", Geo.PAINT)
		g.box(Vector3(0, 0.0, 0.02), Vector3(0.22, 0.2, 0.14), t)
		g.color("#2a3a46", Geo.GLASS)
		g.box(Vector3(0, 0.0, 0.095), Vector3(0.17, 0.14, 0.01), t)
	# roof vents + generator, comms mast with dish + beacon, floodlights, flag
	g.color("#55524c", Geo.STEEL)
	for x in [-0.7, 0.0, 0.7]:
		g.cyl(0.05, 0.05, 0.12, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + R - 0.02, CZ)))
		g.cyl(0.075, 0.0, 0.05, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + R + 0.11, CZ)))
	g.color("#5f6648", Geo.PAINT)
	g.bbox(Vector3(1.0, Y0 + 0.14, -1.25), Vector3(0.5, 0.28, 0.3), 0.02)
	g.color("#2b2b2a", Geo.STEEL)
	g.tube(Vector3(1.18, Y0 + 0.28, -1.25), Vector3(1.18, Y0 + 0.5, -1.25), 0.02, 6)
	var mb := Vector3(-1.22, Y0, -1.22)
	g.color("#8d949a", Geo.STEEL)
	for c in [Vector3(-0.07, 0, -0.07), Vector3(0.07, 0, -0.07), Vector3(0, 0, 0.07)]:
		g.tube(mb + c, mb + Vector3(0, 1.75, 0), 0.01, 4)
	for y in [0.4, 0.8, 1.2]:
		var k := 1.0 - float(y) / 1.75
		g.tube(mb + Vector3(-0.07, y, -0.07) * Vector3(k, 1, k), mb + Vector3(0.07, y, -0.07) * Vector3(k, 1, k), 0.006, 3)
	g.color("#b9bcbf", Geo.PAINT)
	g.cyl(0.16, 0.03, 0.08, 10, Transform3D(Basis(Vector3.RIGHT, -1.1), mb + Vector3(0.04, 1.3, 0.06)))
	g.color("#ff3a2a", Geo.LAMP)
	g.box(mb + Vector3(0, 1.77, 0), Vector3(0.04, 0.04, 0.04))
	for fx in [-1.35, 1.35]:
		g.color("#4a5056", Geo.STEEL)
		g.tube(Vector3(fx, Y0, 1.32), Vector3(fx, Y0 + 0.95, 1.32), 0.015, 5)
		g.box(Vector3(fx, Y0 + 0.97, 1.3), Vector3(0.12, 0.07, 0.06))
		g.color("#fff0c8", Geo.LAMP)
		g.box(Vector3(fx, Y0 + 0.96, 1.27), Vector3(0.1, 0.05, 0.01))
	g.color("#c9ccce", Geo.STEEL)
	g.tube(Vector3(1.05, Y0, 1.0), Vector3(1.05, Y0 + 1.45, 1.0), 0.012, 5)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(1.05 - 0.17, Y0 + 1.33, 1.0), Vector3(0.32, 0.2, 0.01))
	# sandbag positions either side of the entrance + supply crates
	for row in 2:
		for i in 6:
			g.sandbag(Vector3(-1.32 + i * 0.16 + row * 0.08, Y0 + 0.035 + row * 0.07, 1.22), 0.16, 0)
			g.sandbag(Vector3(0.55 + i * 0.16 + row * 0.08, Y0 + 0.035 + row * 0.07, 1.22), 0.16, 0)
	g.color("#7a5d3c", Geo.WOOD)
	g.bbox(Vector3(-1.1, Y0 + 0.1, 0.85), Vector3(0.22, 0.2, 0.22), 0.012)
	g.bbox(Vector3(-0.86, Y0 + 0.08, 0.88), Vector3(0.18, 0.16, 0.18), 0.012)
	g.color("#5f6648", Geo.PAINT)
	g.bbox(Vector3(-1.02, Y0 + 0.27, 0.86), Vector3(0.2, 0.14, 0.14), 0.012)
	return g

static func _scaffold():
	var g = Geo.new()
	var x0 := -HL - 0.12
	var x1 := HL + 0.12
	var z0 := CZ - R - 0.12
	var z1 := CZ + R + 0.12
	var top := 1.25
	g.color("#9aa0a4", Geo.STEEL)
	var xs: Array = []
	for i in 7:
		xs.append(lerpf(x0, x1, float(i) / 6.0))
	var zs: Array = []
	for i in 5:
		zs.append(lerpf(z0, z1, float(i) / 4.0))
	var posts: Array = []
	for x in xs:
		posts.append(Vector2(x, z0))
		posts.append(Vector2(x, z1))
	for z in zs.slice(1, 4):
		posts.append(Vector2(x0, z))
		posts.append(Vector2(x1, z))
	for p in posts:
		g.tube(Vector3(p.x, Y0, p.y), Vector3(p.x, Y0 + top, p.y), 0.012, 4)
	for y in [0.42, 0.84, 1.22]:
		for z in [z0, z1]:
			g.tube(Vector3(x0, Y0 + y, z), Vector3(x1, Y0 + y, z), 0.009, 4)
		for x in [x0, x1]:
			g.tube(Vector3(x, Y0 + y, z0), Vector3(x, Y0 + y, z1), 0.009, 4)
	for i in 6:   # diagonal bracing, alternating bays
		var a: float = xs[i]
		var b: float = xs[i + 1]
		for z in [z0, z1]:
			if (i + int(z > 0.0)) % 2 == 0:
				g.tube(Vector3(a, Y0 + 0.02, z), Vector3(b, Y0 + 0.84, z), 0.007, 3)
	# plank decks on both long sides + toe boards, hazard panel, safety netting bays
	g.color("#8a6a43", Geo.WOOD)
	for z in [z0 + 0.09, z1 - 0.09]:
		g.box(Vector3(0, Y0 + 0.85, z), Vector3(x1 - x0, 0.025, 0.18))
		g.box(Vector3(0, Y0 + 0.43, z), Vector3(x1 - x0, 0.025, 0.18))
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0, Y0 + 0.98, z1 + 0.012), Vector3(0.6, 0.12, 0.01))
	g.color("#5d7a4a", Geo.CANVAS)
	for i in [0, 3, 5]:
		g.box(Vector3((xs[i] + xs[i + 1]) * 0.5, Y0 + 0.95, z0 - 0.01), Vector3(xs[i + 1] - xs[i] - 0.03, 0.55, 0.008))
	# materials on the pad: sheet stacks, beams on pallets
	g.color("#a9adb1", Geo.CORR)
	g.box(Vector3(-0.7, Y0 + 0.08, 1.12), Vector3(0.7, 0.12, 0.3))
	g.color("#7a5d3c", Geo.WOOD)
	g.box(Vector3(0.75, Y0 + 0.03, 1.1), Vector3(0.6, 0.05, 0.36))
	g.color("#6d747a", Geo.STEEL)
	for i in 3:
		g.box(Vector3(0.75, Y0 + 0.08 + i * 0.045, 1.1), Vector3(0.58, 0.04, 0.05))
	return g

static func _debris(g, c: Vector3, n: int, spread: float, size: float, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	for i in n:
		var p := c + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var s := Vector3(rng.randf_range(0.5, 1.0), rng.randf_range(0.3, 0.7), rng.randf_range(0.5, 1.0)) * size
		var k := rng.randi() % 3
		g.color(["#9a9384", "#6f7b5f", "#3a3734"][k], [Geo.CONCRETE, Geo.CORR, Geo.CHAR][k])
		g.rbox(p + Vector3(0, s.y * 0.4, 0), s, Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 180), rng.randf_range(-25, 25)))

static func _damage_light():
	var g = Geo.new()
	_debris(g, Vector3(0.9, Y0, 0.9), 7, 0.3, 0.09, 3)
	_debris(g, Vector3(-0.6, Y0, -1.25), 5, 0.25, 0.08, 4)
	g.color("#8a6a43", Geo.WOOD)   # boarded-up dormers
	for x in [-0.5, 0.82]:
		var a := deg_to_rad(52.0)
		var p := Vector3(x, Y0 + sin(a) * R, CZ + cos(a) * R)
		var t := Transform3D(Basis(Vector3.RIGHT, -(a - PI * 0.5) * 0.5), p)
		g.box(Vector3(0, 0.02, 0.105), Vector3(0.21, 0.035, 0.01), t * Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3.ZERO))
		g.box(Vector3(0, -0.03, 0.105), Vector3(0.21, 0.035, 0.01), t * Transform3D(Basis(Vector3.FORWARD, -0.2), Vector3.ZERO))
	return g

static func _damage_heavy():
	var g = Geo.new()
	# blown-through breaches in the shell (charred, with bent ribs showing)
	for b in [[-0.55, 70.0, 0.42], [0.45, 118.0, 0.36], [0.95, 40.0, 0.25]]:
		var a := deg_to_rad(b[1])
		var p := Vector3(b[0], Y0 + sin(a) * (R + 0.02), CZ + cos(a) * (R + 0.02))
		var t := Transform3D(Basis(Vector3.RIGHT, -(a - PI * 0.5)), p)
		g.color("#0c0b0a", Geo.DARK)
		g.box(Vector3.ZERO, Vector3(b[2], 0.012, b[2] * 0.75), t)
		g.color("#2a2724", Geo.CHAR)
		g.box(Vector3(0, -0.002, 0), Vector3(b[2] * 1.45, 0.008, b[2] * 1.1), t)
		g.color("#5a5550", Geo.STEEL)
		for k in 3:
			g.box(Vector3((k - 1) * b[2] * 0.3, 0.03, 0), Vector3(0.018, 0.05, b[2] * 0.8), t * Transform3D(Basis(Vector3.RIGHT, 0.4 * (k - 1)), Vector3.ZERO))
	# vestibule roof collapsed, sheets fallen against the wall, rubble piles
	g.color("#3a3734", Geo.CHAR)
	g.rbox(Vector3(0.0, Y0 + 0.55, CZ + R + 0.2), Vector3(0.84, 0.05, 0.6), Vector3(18, 0, 6))
	g.color("#6f7b5f", Geo.CORR)
	g.rbox(Vector3(-0.9, Y0 + 0.25, CZ + R + 0.18), Vector3(0.5, 0.012, 0.42), Vector3(62, 10, 0))
	g.rbox(Vector3(0.7, Y0 + 0.08, CZ - R - 0.25), Vector3(0.6, 0.012, 0.35), Vector3(-12, -20, 0))
	_debris(g, Vector3(0.3, Y0, 1.0), 12, 0.45, 0.12, 9)
	_debris(g, Vector3(-1.2, Y0, -0.2), 8, 0.25, 0.12, 10)
	return g

static func _rubble():
	var g = Geo.new()
	g.color("#3a3734", Geo.CHAR)   # scorched pad + low mound
	g.box(Vector3(0, Y0 + 0.003, CZ), Vector3(2.5, 0.006, 1.9))
	g.color("#6b655b", Geo.CONCRETE)
	g.plan_loft([Vector2(-1.1, -0.7), Vector2(1.0, -0.8), Vector2(1.2, 0.5), Vector2(0.2, 0.9), Vector2(-1.2, 0.6)], Y0, Y0 + 0.34, Vector2(0.55, 0.5), Vector2(0, CZ), Transform3D(Basis.IDENTITY, Vector3(0, 0, CZ * 0.5)))
	_debris(g, Vector3(0, Y0 + 0.12, CZ), 30, 0.95, 0.24, 21)
	# a few arch ribs still standing, bent
	g.color("#3e3a35", Geo.STEEL)
	for x in [-0.55, 0.55]:
		var pts := _arc(R, 8).slice(0, 5)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var lean := 0.15 * float(i)
			g.tube(Vector3(x + lean * 0.4, a.y, a.x), Vector3(x + lean * 0.4 + 0.06, b.y, b.x), 0.02, 4)
	g.color("#6f7b5f", Geo.CORR)
	g.rbox(Vector3(0.6, Y0 + 0.2, 0.4), Vector3(0.7, 0.012, 0.4), Vector3(30, 25, 10))
	g.rbox(Vector3(-0.7, Y0 + 0.15, CZ - 0.5), Vector3(0.6, 0.012, 0.5), Vector3(-25, -10, 15))
	return g
