extends RefCounted
## M2.4 roster structures (tool-time only). Same build as the M2.2 barracks kit: concrete or dirt
## pad (Foundation), the structure (Hull), construction Scaffold, DamageLight / DamageHeavy
## overlays, Rubble and Fire* anchors for BuildingView; defences get a TurretPivot. Original
## procedural geometry (tools/gfx_m3/geo.gd), one draw call per part.
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const Y0 := 0.08

static func build_all() -> void:
	_make("eu", "flak_tower", Vector2(2, 2), 1.55, _flak_tower, _flak_turret, Vector3(0, 1.05, 0))
	_make("eu", "signals", Vector2(3, 3), 1.9, _signals)
	_make("eu", "relay", Vector2(2, 2), 2.1, _relay)
	_make("eu", "exchange", Vector2(3, 3), 1.35, _exchange)
	_make("eu", "airstrip", Vector2(4, 4), 1.4, _airstrip)
	_make("eu", "minefield", Vector2(1, 1), 0.35, _minefield)
	_make("eu", "concord", Vector2(3, 3), 2.9, _concord)
	_make("tpla", "wasp_nest", Vector2(2, 2), 1.0, _wasp_nest, _wasp_turret, Vector3(0, 0.42, 0))
	_make("tpla", "decoy", Vector2(3, 3), 1.3, _decoy)
	_make("tpla", "rust_silo", Vector2(3, 3), 2.0, _rust_silo)

static func _make(fac: String, short: String, fp: Vector2, top: float, hull_fn: Callable, turret_fn: Callable = Callable(), tpos := Vector3.ZERO) -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/buildings/building_view.gd"))
	root.set("selection_radius", maxf(fp.x, fp.y) * 0.5)
	root.set("bar_height", top + 0.15)
	root.set("footprint", fp)
	root.set("is_structure", true)
	root.set("top_y", top + 0.05)
	root.set("scaffold_top", top * 0.8)
	var model := VK._n3(root, root, "Model")
	var tpla := fac == "tpla"
	var f = _foundation(fp, tpla)
	VK._mi(model, root, "Foundation", f.commit(mat))
	var h = Geo.new()
	hull_fn.call(h)
	VK._mi(model, root, "Hull", h.commit(mat))
	var parts: Array = [h, f]
	if turret_fn.is_valid():
		var pv := VK._n3(model, root, "TurretPivot", tpos)
		var t = Geo.new()
		turret_fn.call(t)
		VK._mi(pv, root, "Turret", t.commit(mat))
		parts.append(t)
	var s = _scaffold(fp, top * 0.8)
	VK._mi(model, root, "Scaffold", s.commit(mat)).visible = false
	var l = _damage_light(fp, tpla)
	VK._mi(model, root, "DamageLight", l.commit(mat)).visible = false
	var hv = _damage_heavy(fp, top, tpla)
	VK._mi(model, root, "DamageHeavy", hv.commit(mat)).visible = false
	var rb = _rubble(fp, tpla)
	VK._mi(model, root, "Rubble", rb.commit(mat)).visible = false
	parts.append_array([s, l, hv, rb])
	var hx := fp.x * 0.3
	var hz := fp.y * 0.3
	var i := 0
	for p in [Vector3(-hx, top * 0.6, hz * 0.5), Vector3(hx, top * 0.5, -hz), Vector3(0, top * 0.3, hz)]:
		var mk := Marker3D.new()
		mk.name = "Fire%d" % i
		mk.position = p
		model.add_child(mk)
		mk.owner = root
		i += 1
	VK._report(short, parts)
	VK._save(root, "res://view/buildings/%s/%s.tscn" % [fac, short], top + 0.15)

# ------------------------------------------------------------------ shared parts
static func _foundation(fp: Vector2, tpla: bool):
	var g = Geo.new()
	if tpla:
		g.color("#8d7a5c", Geo.CONCRETE)   # packed dirt and broken slabs
		g.bbox(Vector3(0, Y0 * 0.4, 0), Vector3(fp.x - 0.06, Y0 * 0.8, fp.y - 0.06), 0.03)
		g.color("#9a9384", Geo.CONCRETE)
		g.rbox(Vector3(-fp.x * 0.25, Y0 * 0.85, fp.y * 0.3), Vector3(fp.x * 0.3, 0.03, fp.y * 0.22), Vector3(0, 12, 2))
		g.rbox(Vector3(fp.x * 0.28, Y0 * 0.85, -fp.y * 0.28), Vector3(fp.x * 0.26, 0.03, fp.y * 0.2), Vector3(0, -9, -2))
	else:
		g.color("#a39b8b", Geo.CONCRETE)
		g.bbox(Vector3(0, Y0 * 0.5, 0), Vector3(fp.x - 0.06, Y0, fp.y - 0.06), 0.03)
		g.color("#d8a531", Geo.PAINT)
		for z in [fp.y * 0.5 - 0.14, -fp.y * 0.5 + 0.14]:
			g.box(Vector3(0, Y0 + 0.004, z), Vector3(fp.x - 0.4, 0.008, 0.04))
	return g

static func _scaffold(fp: Vector2, top: float):
	var g = Geo.new()
	var x0 := -fp.x * 0.5 + 0.08
	var x1 := fp.x * 0.5 - 0.08
	var z0 := -fp.y * 0.5 + 0.08
	var z1 := fp.y * 0.5 - 0.08
	g.color("#9aa0a4", Geo.STEEL)
	var nx := maxi(2, int(fp.x * 1.5))
	var nz := maxi(2, int(fp.y * 1.5))
	for i in nx + 1:
		var x := lerpf(x0, x1, float(i) / nx)
		for z in [z0, z1]:
			g.tube(Vector3(x, Y0, z), Vector3(x, Y0 + top, z), 0.012, 4)
	for i in range(1, nz):
		var z2 := lerpf(z0, z1, float(i) / nz)
		for x2 in [x0, x1]:
			g.tube(Vector3(x2, Y0, z2), Vector3(x2, Y0 + top, z2), 0.012, 4)
	var y := 0.4
	while y < top:
		for z in [z0, z1]:
			g.tube(Vector3(x0, Y0 + y, z), Vector3(x1, Y0 + y, z), 0.009, 4)
		for x in [x0, x1]:
			g.tube(Vector3(x, Y0 + y, z0), Vector3(x, Y0 + y, z1), 0.009, 4)
		y += 0.42
	g.color("#8a6a43", Geo.WOOD)
	g.box(Vector3(0, Y0 + 0.42, z1 - 0.08), Vector3(x1 - x0, 0.025, 0.16))
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0, Y0 + minf(top, 0.9), z1 + 0.012), Vector3(minf(0.6, fp.x * 0.4), 0.1, 0.01))
	return g

static func _debris(g, c: Vector3, n: int, spread: float, size: float, seed_i: int, tpla: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var cols := ["#8d7a5c", "#7b4a2a", "#3a3734"] if tpla else ["#9a9384", "#6f7b5f", "#3a3734"]
	for i in n:
		var p := c + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var s := Vector3(rng.randf_range(0.5, 1.0), rng.randf_range(0.3, 0.7), rng.randf_range(0.5, 1.0)) * size
		var k := rng.randi() % 3
		g.color(cols[k], [Geo.CONCRETE, Geo.SCRAP if tpla else Geo.CORR, Geo.CHAR][k])
		g.rbox(p + Vector3(0, s.y * 0.4, 0), s, Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 180), rng.randf_range(-25, 25)))

static func _damage_light(fp: Vector2, tpla: bool):
	var g = Geo.new()
	_debris(g, Vector3(fp.x * 0.32, Y0, fp.y * 0.32), 6, fp.x * 0.1, 0.08, 31, tpla)
	_debris(g, Vector3(-fp.x * 0.3, Y0, -fp.y * 0.3), 4, fp.x * 0.08, 0.07, 32, tpla)
	return g

static func _damage_heavy(fp: Vector2, top: float, tpla: bool):
	var g = Geo.new()
	g.color("#2a2724", Geo.CHAR)   # scorch marks on the pad
	g.box(Vector3(fp.x * 0.15, Y0 + 0.006, fp.y * 0.2), Vector3(fp.x * 0.5, 0.008, fp.y * 0.35))
	g.color("#0c0b0a", Geo.DARK)
	for k in 3:   # blackened breaches hanging off the sides
		var a := TAU * k / 3.0 + 0.4
		var p := Vector3(cos(a) * fp.x * 0.33, Y0 + top * (0.35 + 0.15 * k), sin(a) * fp.y * 0.33)
		g.rbox(p, Vector3(0.24, 0.16, 0.24), Vector3(10 * k, rad_to_deg(a), 15))
	_debris(g, Vector3(0, Y0, fp.y * 0.38), 10, fp.x * 0.25, 0.11, 33, tpla)
	_debris(g, Vector3(-fp.x * 0.38, Y0, 0), 6, fp.y * 0.15, 0.1, 34, tpla)
	return g

static func _rubble(fp: Vector2, tpla: bool):
	var g = Geo.new()
	g.color("#3a3734", Geo.CHAR)
	g.box(Vector3(0, Y0 + 0.003, 0), Vector3(fp.x * 0.85, 0.006, fp.y * 0.85))
	g.color("#7b6a52" if tpla else "#6b655b", Geo.CONCRETE)
	var r := minf(fp.x, fp.y) * 0.36
	g.plan_loft([Vector2(-r, -r * 0.8), Vector2(r * 0.9, -r), Vector2(r, r * 0.6), Vector2(0.1, r), Vector2(-r, r * 0.7)], Y0, Y0 + 0.08 + 0.1 * r, Vector2(0.55, 0.5))
	_debris(g, Vector3(0, Y0 + 0.08, 0), int(10 + fp.x * fp.y * 1.5), r, 0.18, 35, tpla)
	g.color("#3e3a35", Geo.STEEL)
	g.tube(Vector3(-r * 0.4, Y0, r * 0.2), Vector3(-r * 0.2, Y0 + 0.45, r * 0.35), 0.025, 4)
	g.tube(Vector3(r * 0.5, Y0, -r * 0.3), Vector3(r * 0.2, Y0 + 0.35, -r * 0.5), 0.02, 4)
	return g

static func _lamp(g, p: Vector3, c := "#ff3a2a") -> void:
	g.color(c, Geo.LAMP)
	g.box(p, Vector3(0.05, 0.05, 0.05))

# ------------------------------------------------------------------ EU
## Flak Tower: hexagonal concrete tower with sandbagged roof ring; rotary-gun turret on top.
static func _flak_tower(g) -> void:
	var hexr: Array = []
	var hext: Array = []
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		hexr.append(Vector2(cos(a), sin(a)) * 0.72)
	g.color("#8f8a7c", Geo.CONCRETE)
	g.plan_loft(hexr, Y0, Y0 + 0.9, Vector2(0.78, 0.78))
	g.color("#6f7b5f", Geo.PAINT)
	g.plan_loft(hexr, Y0 + 0.88, Y0 + 0.96, Vector2(0.84, 0.84), Vector2.ZERO, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	g.color("#ffffff", Geo.TEAM)
	for i in 6:
		var a := TAU * i / 6.0
		g.box(Vector3(cos(a) * 0.62, Y0 + 0.62, sin(a) * 0.62), Vector3(0.05, 0.08, 0.3), Transform3D(Basis(Vector3.UP, -a), Vector3.ZERO))
	g.color("#1d1f1e", Geo.DARK)   # firing slits + door
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		g.box(Vector3.ZERO, Vector3(0.04, 0.05, 0.22), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.63, Y0 + 0.42, sin(a) * 0.63)))
	g.color("#3b3f3a", Geo.STEEL)
	g.box(Vector3(0, Y0 + 0.24, 0.68), Vector3(0.28, 0.46, 0.04))
	for i in 10:   # roof sandbags
		var a := TAU * i / 10.0
		g.sandbag(Vector3(cos(a) * 0.52, Y0 + 0.99, sin(a) * 0.52), 0.24, -rad_to_deg(a) + 90.0)
	g.color("#4a5056", Geo.STEEL)   # ladder
	for x in [-0.6, -0.48]:
		g.tube(Vector3(x, Y0, -0.5), Vector3(x, Y0 + 0.98, -0.5), 0.01, 4)
	for k in 6:
		g.tube(Vector3(-0.6, Y0 + 0.12 + k * 0.15, -0.5), Vector3(-0.48, Y0 + 0.12 + k * 0.15, -0.5), 0.007, 3)
	for c in [Vector3(0.75, 0, 0.75), Vector3(-0.78, 0, 0.7)]:
		g.sandbag(Vector3(c.x, Y0 + 0.035, c.z), 0.2, 45)
		g.sandbag(Vector3(c.x, Y0 + 0.1, c.z), 0.2, 45)

static func _flak_turret(g) -> void:
	g.color("#5f6648", Geo.PAINT)
	g.cyl(0.3, 0.26, 0.12, 12, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	g.bbox(Vector3(0, 0.24, -0.02), Vector3(0.42, 0.22, 0.42), 0.04)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.215, 0.26, 0), Vector3(0.01, 0.06, 0.3))
	g.box(Vector3(-0.215, 0.26, 0), Vector3(0.01, 0.06, 0.3))
	g.color("#2b2d2f", Geo.STEEL)
	var tilt := Basis(Vector3.RIGHT, -0.35)
	for side in [-0.13, 0.13]:   # two rotary gun packs
		var o := Vector3(side, 0.26, 0.18)
		g.cyl(0.07, 0.07, 0.16, 8, Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), o))
		for k in 6:
			var a := TAU * k / 6.0
			var off := tilt * Vector3(cos(a) * 0.04, sin(a) * 0.04, 0)
			g.tube(o + off, o + off + tilt * Vector3(0, 0, 0.55), 0.011, 4)
		g.cyl(0.05, 0.05, 0.03, 8, Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), o + tilt * Vector3(0, 0, 0.44)))
	g.color("#5f6648", Geo.PAINT)
	g.box(Vector3(0, 0.4, -0.18), Vector3(0.2, 0.08, 0.14))   # ammo drum
	g.color("#2a3a46", Geo.GLASS)
	g.box(Vector3(0, 0.3, 0.2), Vector3(0.12, 0.06, 0.02))

## Signals Center: low armoured command block, glazed ops room, big tracking dish, mast array.
static func _signals(g) -> void:
	g.color("#6f7b5f", Geo.PAINT)
	g.bbox(Vector3(0, Y0 + 0.36, 0.15), Vector3(2.5, 0.72, 1.9), 0.06)
	g.color("#5d6650", Geo.PAINT)
	g.bbox(Vector3(-0.45, Y0 + 0.9, 0.3), Vector3(1.3, 0.36, 1.2), 0.04)
	g.color("#2a3a46", Geo.GLASS)   # ops room window band
	g.box(Vector3(-0.45, Y0 + 0.92, 0.91), Vector3(1.2, 0.16, 0.02))
	g.box(Vector3(-1.11, Y0 + 0.92, 0.3), Vector3(0.02, 0.16, 1.0))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.55, 1.105), Vector3(2.2, 0.08, 0.02))
	g.color("#3b3f3a", Geo.STEEL)
	g.box(Vector3(0.75, Y0 + 0.25, 1.11), Vector3(0.4, 0.5, 0.02))
	g.color("#ffd27a", Geo.LAMP)
	g.box(Vector3(0.75, Y0 + 0.55, 1.13), Vector3(0.1, 0.03, 0.03))
	# tracking dish on a pedestal
	var dc := Vector3(0.7, Y0 + 0.72, -0.35)
	g.color("#7d8287", Geo.STEEL)
	g.cyl(0.16, 0.12, 0.3, 10, Transform3D(Basis.IDENTITY, dc))
	g.color("#c9ccce", Geo.PAINT)
	var db := Basis(Vector3.RIGHT, -0.75) * Basis(Vector3.UP, 0.5)
	g.cyl(0.62, 0.2, 0.18, 16, Transform3D(db, dc + Vector3(0, 0.45, 0)))
	g.color("#4a5056", Geo.STEEL)
	g.tube(dc + Vector3(0, 0.5, 0), dc + Vector3(0, 0.5, 0) + db * Vector3(0, 0.55, 0), 0.015, 4)
	g.box(dc + Vector3(0, 0.5, 0) + db * Vector3(0, 0.57, 0), Vector3(0.06, 0.06, 0.06))
	# lattice mast with cross arms
	var mb := Vector3(-1.0, Y0 + 0.72, -0.6)
	g.color("#8d949a", Geo.STEEL)
	for c in [Vector3(-0.06, 0, -0.06), Vector3(0.06, 0, -0.06), Vector3(0, 0, 0.06)]:
		g.tube(mb + c, mb + Vector3(0, 1.15, 0), 0.01, 4)
	for y in [0.45, 0.8, 1.05]:
		g.tube(mb + Vector3(-0.22, y, 0), mb + Vector3(0.22, y, 0), 0.008, 3)
	_lamp(g, mb + Vector3(0, 1.17, 0))
	# roof clutter: AC units, cable trays, generator, sandbags at the door
	g.color("#7d8287", Geo.PAINT)
	for x in [0.2, 0.55]:
		g.bbox(Vector3(x, Y0 + 0.8, 0.6), Vector3(0.24, 0.16, 0.24), 0.02)
		g.color("#2e322b", Geo.DARK)
		g.cyl(0.08, 0.08, 0.01, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.885, 0.6)))
		g.color("#7d8287", Geo.PAINT)
	g.color("#4a5056", Geo.STEEL)
	g.box(Vector3(0.3, Y0 + 0.74, -0.75), Vector3(0.9, 0.04, 0.1))
	for i in 4:
		g.sandbag(Vector3(0.45 + i * 0.16, Y0 + 0.035, 1.3), 0.16, 0)

## Field Relay Mast: guyed lattice mast, repair arms and a green cross beacon; generator shed.
static func _relay(g) -> void:
	var mb := Vector3(0.1, Y0, -0.1)
	g.color("#a39b8b", Geo.CONCRETE)
	g.bbox(mb + Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), 0.03)
	g.color("#c9ccce", Geo.STEEL)
	var top := 1.85
	for c in [Vector3(-0.12, 0, -0.12), Vector3(0.12, 0, -0.12), Vector3(0.12, 0, 0.12), Vector3(-0.12, 0, 0.12)]:
		g.tube(mb + c + Vector3(0, 0.16, 0), mb + c * 0.35 + Vector3(0, top, 0), 0.013, 4)
	var y := 0.4
	while y < top - 0.1:
		var k := 1.0 - 0.65 * y / top
		g.tube(mb + Vector3(-0.12 * k, y, -0.12 * k), mb + Vector3(0.12 * k, y, 0.12 * k), 0.007, 3)
		g.tube(mb + Vector3(0.12 * k, y, -0.12 * k), mb + Vector3(-0.12 * k, y, 0.12 * k), 0.007, 3)
		y += 0.3
	g.color("#4a5056", Geo.STEEL)   # guy wires
	for a in [0.3, 2.4, 4.4]:
		g.tube(mb + Vector3(0, top * 0.8, 0), Vector3(cos(a) * 0.85, Y0, sin(a) * 0.85), 0.004, 3)
	g.color("#e8e8e0", Geo.PAINT)   # emitter pods with repair arms
	for a in [0.0, PI]:
		var arm := Vector3(cos(a) * 0.38, 1.3, sin(a) * 0.38)
		g.tube(mb + Vector3(0, 1.3, 0), mb + arm, 0.02, 5)
		g.cyl(0.07, 0.05, 0.16, 8, Transform3D(Basis.IDENTITY, mb + arm - Vector3(0, 0.08, 0)))
		g.color("#46d36a", Geo.LAMP)
		g.box(mb + arm - Vector3(0, 0.1, 0), Vector3(0.06, 0.03, 0.06))
		g.color("#e8e8e0", Geo.PAINT)
	g.color("#46d36a", Geo.LAMP)   # green cross beacon
	g.box(mb + Vector3(0, top + 0.08, 0), Vector3(0.2, 0.06, 0.06))
	g.box(mb + Vector3(0, top + 0.08, 0), Vector3(0.06, 0.2, 0.06))
	g.color("#ffffff", Geo.TEAM)
	g.box(mb + Vector3(0, 0.95, 0.095), Vector3(0.12, 0.3, 0.01))
	g.color("#5f6648", Geo.PAINT)   # generator shed
	g.bbox(Vector3(-0.55, Y0 + 0.18, 0.5), Vector3(0.6, 0.36, 0.4), 0.03)
	g.color("#3b3f3a", Geo.STEEL)
	g.box(Vector3(-0.55, Y0 + 0.37, 0.5), Vector3(0.66, 0.03, 0.46))
	g.tube(Vector3(-0.35, Y0 + 0.38, 0.4), Vector3(-0.35, Y0 + 0.6, 0.4), 0.02, 5)
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(-0.55, Y0 + 0.2, 0.705), Vector3(0.3, 0.12, 0.01))
	g.color("#2e322b", Geo.RUBBER)   # cable reels
	for p in [Vector3(0.6, Y0 + 0.1, 0.55), Vector3(0.6, Y0 + 0.1, 0.25)]:
		g.cyl(0.1, 0.1, 0.12, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p + Vector3(0.06, 0, 0)))

## Data Exchange: stepped glass-and-panel trading hall, roof cooling fans, dish farm.
static func _exchange(g) -> void:
	g.color("#7d8287", Geo.PAINT)
	g.bbox(Vector3(0, Y0 + 0.3, 0.1), Vector3(2.5, 0.6, 2.1), 0.05)
	g.color("#2a3a46", Geo.GLASS)
	g.box(Vector3(0, Y0 + 0.36, 1.155), Vector3(2.2, 0.36, 0.02))
	g.color("#6c7177", Geo.PAINT)
	g.bbox(Vector3(-0.3, Y0 + 0.8, 0.0), Vector3(1.6, 0.4, 1.5), 0.04)
	g.color("#2a3a46", Geo.GLASS)
	g.box(Vector3(-0.3, Y0 + 0.82, 0.755), Vector3(1.45, 0.24, 0.02))
	g.box(Vector3(0.505, Y0 + 0.82, 0.0), Vector3(0.02, 0.24, 1.3))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.62, 1.16), Vector3(2.4, 0.05, 0.02))
	g.color("#5aa9ff", Geo.LAMP)   # ticker board
	g.box(Vector3(-0.3, Y0 + 1.07, 0.76), Vector3(1.0, 0.07, 0.02))
	g.color("#3b3f3a", Geo.STEEL)   # roof cooling fans
	for x in [-0.8, -0.3, 0.2]:
		g.cyl(0.17, 0.17, 0.08, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 1.0, -0.3)))
		g.color("#1d1f1e", Geo.DARK)
		g.cyl(0.14, 0.14, 0.01, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 1.08, -0.3)))
		g.color("#3b3f3a", Geo.STEEL)
	g.color("#c9ccce", Geo.PAINT)   # small dish farm on the low roof
	for p in [Vector3(0.85, Y0 + 0.6, -0.6), Vector3(0.85, Y0 + 0.6, -0.1), Vector3(0.85, Y0 + 0.6, 0.4)]:
		g.tube(p, p + Vector3(0, 0.15, 0), 0.015, 4)
		g.cyl(0.16, 0.04, 0.06, 10, Transform3D(Basis(Vector3.RIGHT, -0.9), p + Vector3(0, 0.15, 0)))
	g.color("#4a5056", Geo.STEEL)   # cable trays down the side
	g.box(Vector3(-1.27, Y0 + 0.35, -0.2), Vector3(0.05, 0.6, 0.12))
	g.box(Vector3(-1.27, Y0 + 0.02, 0.4), Vector3(0.05, 0.04, 1.4))

## Airstrip: runway apron with markings, small control tower and a quonset hangar.
static func _airstrip(g) -> void:
	g.color("#55524c", Geo.CONCRETE)   # runway strip
	g.box(Vector3(0.45, Y0 + 0.01, 0), Vector3(1.5, 0.02, 3.8))
	g.color("#e4e0d6", Geo.PAINT)
	for i in 6:
		g.box(Vector3(0.45, Y0 + 0.022, -1.6 + i * 0.64), Vector3(0.06, 0.004, 0.3))
	for x in [-0.25, 1.15]:
		g.box(Vector3(x, Y0 + 0.022, 0), Vector3(0.03, 0.004, 3.7))
	g.color("#ffd27a", Geo.LAMP)   # edge lights
	for i in 7:
		for x in [-0.32, 1.22]:
			g.box(Vector3(x, Y0 + 0.03, -1.8 + i * 0.6), Vector3(0.03, 0.02, 0.03))
	# hangar (west side): corrugated half-cylinder along z
	var hx := -1.2
	var arc: Array = []
	for i in 13:
		var a := PI * i / 12.0
		arc.append(Vector2(cos(a) * 0.62, Y0 + sin(a) * 0.62))
	g.color("#6f7b5f", Geo.CORR)
	var t := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hx, 0, -0.3))
	g.prism_x(arc, -0.9, 0.9, t)
	g.color("#1d1f1e", Geo.DARK)
	g.box(Vector3(hx, Y0 + 0.28, 0.61), Vector3(0.8, 0.5, 0.02))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(hx, Y0 + 0.62, 0.61), Vector3(0.5, 0.07, 0.02))
	# control tower (north-west)
	var tc := Vector3(-1.35, Y0, 1.35)
	g.color("#8f8a7c", Geo.CONCRETE)
	g.bbox(tc + Vector3(0, 0.45, 0), Vector3(0.36, 0.9, 0.36), 0.02)
	g.color("#5d6650", Geo.PAINT)
	g.plan_loft([Vector2(-0.28, -0.28), Vector2(0.28, -0.28), Vector2(0.28, 0.28), Vector2(-0.28, 0.28)], 0.9, 1.15, Vector2(1.1, 1.1), Vector2.ZERO, Transform3D(Basis.IDENTITY, tc))
	g.color("#2a3a46", Geo.GLASS)
	g.plan_loft([Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3), Vector2(-0.3, 0.3)], 0.96, 1.1, Vector2(1.04, 1.04), Vector2.ZERO, Transform3D(Basis.IDENTITY, tc))
	g.color("#3b3f3a", Geo.STEEL)
	g.box(tc + Vector3(0, 1.17, 0), Vector3(0.66, 0.04, 0.66))
	g.color("#c9ccce", Geo.STEEL)
	g.tube(tc + Vector3(0.15, 1.19, 0.15), tc + Vector3(0.15, 1.42, 0.15), 0.008, 4)
	_lamp(g, tc + Vector3(0.15, 1.44, 0.15))
	g.color("#ff8a2a", Geo.CANVAS)   # windsock
	g.tube(Vector3(1.7, Y0, -1.7), Vector3(1.7, Y0 + 0.6, -1.7), 0.01, 4)
	g.tube(Vector3(1.7, Y0 + 0.58, -1.7), Vector3(1.88, Y0 + 0.55, -1.7), 0.04, 6, 0.02)
	# fuel bowser + crates
	g.color("#5f6648", Geo.PAINT)
	g.cyl(0.14, 0.14, 0.5, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.3, Y0 + 0.16, -1.65)))
	g.color("#7a5d3c", Geo.WOOD)
	g.bbox(Vector3(-1.6, Y0 + 0.1, -1.6), Vector3(0.2, 0.2, 0.2), 0.012)

## Minefield: a marked plot with half-buried mine discs and a warning sign.
static func _minefield(g) -> void:
	g.color("#7d6a4c", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.005, 0), Vector3(0.86, 0.01, 0.86))
	g.color("#4a5038", Geo.PAINT)
	for p in [Vector2(-0.22, -0.2), Vector2(0.2, -0.24), Vector2(0.0, 0.05), Vector2(-0.25, 0.27), Vector2(0.26, 0.22)]:
		g.cyl(0.08, 0.07, 0.03, 10, Transform3D(Basis.IDENTITY, Vector3(p.x, Y0, p.y)))
		g.color("#2b2d2f", Geo.STEEL)
		g.cyl(0.02, 0.02, 0.045, 6, Transform3D(Basis.IDENTITY, Vector3(p.x, Y0, p.y)))
		g.color("#4a5038", Geo.PAINT)
	g.color("#7a5d3c", Geo.WOOD)
	g.tube(Vector3(0.38, Y0, 0.4), Vector3(0.38, Y0 + 0.3, 0.4), 0.012, 4)
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0.38, Y0 + 0.27, 0.41), Vector3(0.14, 0.1, 0.01))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.38, Y0 + 0.27, 0.418), Vector3(0.06, 0.04, 0.004))

## Concord Pylon (superweapon, [STUB] effect): tapering tower, three coil rings, emitter crown.
static func _concord(g) -> void:
	var sq := [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(0.9, 0.9), Vector2(-0.9, 0.9)]
	g.color("#8f8a7c", Geo.CONCRETE)
	g.plan_loft(sq, Y0, Y0 + 0.35, Vector2(0.8, 0.8))
	g.color("#6c7177", Geo.PAINT)
	var oct: Array = []
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		oct.append(Vector2(cos(a), sin(a)) * 0.5)
	g.plan_loft(oct, Y0 + 0.35, Y0 + 2.3, Vector2(0.45, 0.45))
	g.color("#3b3f3a", Geo.STEEL)
	for k in 3:
		var y := Y0 + 0.8 + k * 0.5
		var rr := 0.5 - 0.11 * (k + 1) + 0.16
		g.cyl(rr, rr, 0.08, 16, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
		g.color("#6fe3ff", Geo.LAMP)
		g.cyl(rr + 0.01, rr + 0.01, 0.02, 16, Transform3D(Basis.IDENTITY, Vector3(0, y + 0.03, 0)), false)
		g.color("#3b3f3a", Geo.STEEL)
	g.color("#c9ccce", Geo.STEEL)
	for a in [0.0, TAU / 3.0, 2.0 * TAU / 3.0]:   # crown prongs
		var p := Vector3(cos(a) * 0.2, Y0 + 2.3, sin(a) * 0.2)
		g.tube(p, p * Vector3(1.6, 1, 1.6) + Vector3(0, 0.5, 0), 0.025, 5)
	g.color("#6fe3ff", Geo.LAMP)
	g.cyl(0.1, 0.0, 0.3, 8, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 2.45, 0)))
	g.color("#ffffff", Geo.TEAM)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		g.box(Vector3.ZERO, Vector3(0.5, 0.08, 0.02), Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.72, Y0 + 0.25, cos(a) * 0.72)))
	g.color("#4a5056", Geo.STEEL)   # capacitor banks
	for p in [Vector3(-1.05, 0, 0.9), Vector3(1.05, 0, 0.9), Vector3(1.05, 0, -0.9)]:
		g.bbox(p + Vector3(0, Y0 + 0.2, 0), Vector3(0.3, 0.4, 0.3), 0.03)
		_lamp(g, p + Vector3(0, Y0 + 0.42, 0), "#6fe3ff")
		g.color("#4a5056", Geo.STEEL)

# ------------------------------------------------------------------ TPLA
## Wasp Nest: sandbag ring around a pit; rocket pod turret made of salvaged tubes.
static func _wasp_nest(g) -> void:
	g.color("#6b5a40", Geo.CONCRETE)
	g.cyl(0.62, 0.56, 0.14, 12, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	for row in 3:
		for i in 12:
			var a := TAU * (i + row * 0.5) / 12.0
			g.sandbag(Vector3(cos(a) * 0.75, Y0 + 0.035 + row * 0.07, sin(a) * 0.75), 0.36, -rad_to_deg(a) + 90.0, "#a08a5c")
	g.color("#7b4a2a", Geo.SCRAP)   # scrap plates leaning on the ring
	g.rbox(Vector3(0.7, Y0 + 0.2, 0.45), Vector3(0.36, 0.3, 0.03), Vector3(-15, 35, 5))
	g.rbox(Vector3(-0.72, Y0 + 0.18, -0.4), Vector3(0.3, 0.28, 0.03), Vector3(12, -40, -6))
	g.color("#5d4a36", Geo.WOOD)   # rocket crates
	g.bbox(Vector3(-0.55, Y0 + 0.08, 0.55), Vector3(0.28, 0.16, 0.16), 0.01)
	g.bbox(Vector3(-0.45, Y0 + 0.22, 0.6), Vector3(0.28, 0.12, 0.16), 0.01)

static func _wasp_turret(g) -> void:
	g.color("#3a3734", Geo.STEEL)
	g.cyl(0.12, 0.1, 0.2, 8, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	var tilt := Basis(Vector3.RIGHT, -0.3)
	var o := Vector3(0, 0.3, 0)
	g.color("#8a5a2e", Geo.SCRAP)
	g.box(Vector3.ZERO, Vector3(0.46, 0.26, 0.5), Transform3D(tilt, o))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.235, 0, 0), Vector3(0.01, 0.1, 0.4), Transform3D(tilt, o))
	g.color("#2b2d2f", Geo.STEEL)
	for r in 2:
		for c in 3:
			var p := Vector3(-0.14 + c * 0.14, -0.06 + r * 0.12, 0.26)
			g.tube(o + tilt * (p - Vector3(0, 0, 0.1)), o + tilt * (p + Vector3(0, 0, 0.04)), 0.045, 8)
			g.color("#b23a2a", Geo.PAINT)
			g.cyl(0.03, 0.0, 0.06, 6, Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), o + tilt * (p + Vector3(0, 0, 0.04))))
			g.color("#2b2d2f", Geo.STEEL)
	g.color("#6b5a40", Geo.CANVAS)
	g.box(Vector3.ZERO, Vector3(0.5, 0.03, 0.56), Transform3D(tilt, o + Vector3(0, 0.15, -0.03)))

## Decoy Yard: a fake TPLA compound: painted canvas fronts propped up by poles from behind.
static func _decoy(g) -> void:
	g.color("#9c8a62", Geo.CANVAS)
	g.box(Vector3(-0.2, Y0 + 0.5, 0.6), Vector3(1.8, 1.0, 0.03))   # front facade
	g.color("#7b4a2a", Geo.SCRAP)
	g.prism_x([Vector2(0.6, Y0 + 1.0), Vector2(0.35, Y0 + 1.22), Vector2(0.1, Y0 + 1.0)], -1.1, 0.7)
	g.color("#3a3734", Geo.DARK)   # painted-on door and windows
	g.box(Vector3(-0.2, Y0 + 0.3, 0.62), Vector3(0.4, 0.55, 0.005))
	for x in [-0.8, 0.4]:
		g.box(Vector3(x, Y0 + 0.65, 0.62), Vector3(0.3, 0.22, 0.005))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.2, Y0 + 0.86, 0.62), Vector3(0.9, 0.08, 0.005))
	g.color("#7a5d3c", Geo.WOOD)   # props behind the facade
	for x in [-0.9, -0.2, 0.5]:
		g.tube(Vector3(x, Y0, -0.2), Vector3(x, Y0 + 0.95, 0.57), 0.02, 4)
		g.tube(Vector3(x, Y0, 0.57), Vector3(x, Y0 + 1.0, 0.57), 0.018, 4)
	g.color("#8a7550", Geo.CANVAS)   # second fake shed: canvas tent block
	g.prism_x([Vector2(-1.0, Y0), Vector2(-0.6, Y0 + 0.7), Vector2(-0.2, Y0)], 0.4, 1.3)
	g.color("#6b5a40", Geo.CANVAS)   # fake "vehicle" silhouette made of crates and a tarp
	g.bbox(Vector3(0.95, Y0 + 0.16, 0.5), Vector3(0.5, 0.3, 0.32), 0.02)
	g.color("#7a5d3c", Geo.WOOD)
	g.tube(Vector3(0.85, Y0 + 0.3, 0.5), Vector3(1.3, Y0 + 0.34, 0.5), 0.03, 5)
	g.color("#2b2d2f", Geo.RUBBER)
	for z in [0.3, 0.7]:
		g.cyl(0.08, 0.08, 0.06, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.75, Y0 + 0.08, z)))

## Rust Bloom Silo (superweapon, [STUB] effect): corroded silo, half-open blast doors, pipework.
static func _rust_silo(g) -> void:
	g.color("#7b6a52", Geo.CONCRETE)
	g.cyl(1.05, 1.0, 0.3, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	g.color("#8a5a2e", Geo.SCRAP)
	g.cyl(0.62, 0.6, 1.35, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.3, 0)))
	g.color("#5b4630", Geo.SCRAP)
	for y in [0.55, 0.95, 1.35]:
		g.cyl(0.64, 0.64, 0.05, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + y, 0)))
	g.color("#0c0b0a", Geo.DARK)
	g.cyl(0.5, 0.5, 0.02, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 1.65, 0)))
	g.color("#9ad84a", Geo.LAMP)   # glowing payload
	g.cyl(0.25, 0.0, 0.35, 10, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 1.55, 0)))
	g.color("#6b5a40", Geo.STEEL)   # blast doors, half open
	g.rbox(Vector3(-0.42, Y0 + 1.82, 0), Vector3(0.12, 0.5, 1.0), Vector3(0, 0, 35))
	g.rbox(Vector3(0.42, Y0 + 1.82, 0), Vector3(0.12, 0.5, 1.0), Vector3(0, 0, -35))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.75, 0.62), Vector3(0.5, 0.1, 0.02))
	g.color("#4a5056", Geo.STEEL)   # pipework to tanks
	for a in [0.6, 2.2, 4.1]:
		var p := Vector3(cos(a) * 1.15, Y0, sin(a) * 1.15)
		g.cyl(0.18, 0.18, 0.55, 10, Transform3D(Basis.IDENTITY, p))
		g.color("#9ad84a", Geo.LAMP)
		g.box(p + Vector3(0, 0.6, 0), Vector3(0.06, 0.04, 0.06))
		g.color("#4a5056", Geo.STEEL)
		g.tube(p + Vector3(0, 0.42, 0), Vector3(cos(a) * 0.6, Y0 + 0.75, sin(a) * 0.6), 0.03, 5)
