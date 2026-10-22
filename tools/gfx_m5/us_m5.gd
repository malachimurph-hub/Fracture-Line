extends RefCounted
## M2.5 United States views (tool-time only): original procedural models in the M2.2+ style
## (tools/gfx_m3/geo.gd kit, m3 shader, team bands, articulated TurretPivot / Barrel, aircraft
## Rotor nodes). Shapes are "inspired by" modern US equipment roles, not replicas.
##   godot --headless --path . -s res://tools/gen_gfx_m5.gd
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const Y0 := 0.08

# US palette: dark olive drab vehicles, air-superiority grey aircraft
const US := "#5a6447"
const US_D := "#454d36"
const US_S := "#2f3230"
const AIR := "#8a9097"
const AIR_D := "#6c737a"

static func build_all() -> void:
	var mat: Material = load(VK.MAT_PATH)
	_dozer(mat)
	_supply_truck(mat)
	_halberd(mat)
	_lynx(mat)
	_picket(mat)
	_longreach(mat)
	_harrier(mat)
	_wraith(mat)
	_thunderlance(mat)
	B4._make("us", "command", Vector2(4, 4), 1.7, _command)
	B4._make("us", "reactor", Vector2(3, 3), 1.9, _reactor)
	B4._make("us", "supply_center", Vector2(3, 3), 1.4, _supply_center)
	B4._make("us", "barracks", Vector2(3, 3), 1.2, _barracks)
	B4._make("us", "garage", Vector2(4, 4), 1.45, _garage)
	B4._make("us", "airfield", Vector2(4, 4), 1.3, _airfield)
	B4._make("us", "strategy", Vector2(3, 3), 1.9, _strategy)
	B4._make("us", "patriot", Vector2(2, 2), 0.9, _patriot, _patriot_turret, Vector3(0, 0.32, 0))
	B4._make("us", "firebase", Vector2(2, 2), 0.95, _firebase, _firebase_turret, Vector3(0, 0.55, 0))
	B4._make("us", "drop_zone", Vector2(3, 3), 1.6, _drop_zone)

static func _team_band(h, hw: float, y: float, l: float) -> void:
	h.color("#ffffff", Geo.TEAM)
	for s in [-hw - 0.004, hw + 0.004]:
		h.box(Vector3(s, y, 0), Vector3(0.02, 0.03, l))

# ------------------------------------------------------------------ Dozer (builder)
static func _dozer(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._tracks(h, 0.4, 1.3, 4, 0.09, US_D, US_S)
	h.color(US, Geo.PAINT)
	h.bbox(Vector3(0, 0.34, -0.05), Vector3(0.62, 0.24, 1.0), 0.03)
	h.color("#d8a531", Geo.PAINT)   # safety-yellow cab frame
	h.bbox(Vector3(0, 0.62, -0.2), Vector3(0.5, 0.34, 0.46), 0.02)
	h.color("#2a3a46", Geo.GLASS)
	h.box(Vector3(0, 0.66, 0.035), Vector3(0.42, 0.2, 0.01))
	for s in [-0.252, 0.252]:
		h.box(Vector3(s, 0.66, -0.2), Vector3(0.01, 0.2, 0.36))
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.18, 0.46, -0.45), Vector3(0.18, 0.92, -0.45), 0.03, 6)   # exhaust
	# blade on push arms
	for s in [-0.36, 0.36]:
		h.tube(Vector3(s, 0.22, 0.2), Vector3(s, 0.22, 0.72), 0.03, 6)
	h.color("#d8a531", Geo.PAINT)
	h.prism_x([Vector2(0.72, 0.04), Vector2(0.8, 0.06), Vector2(0.84, 0.3), Vector2(0.78, 0.46), Vector2(0.72, 0.44)], -0.52, 0.52)
	h.color(US_S, Geo.STEEL)
	h.box(Vector3(0, 0.05, 0.83), Vector3(1.04, 0.04, 0.05))
	_team_band(h, 0.31, 0.44, 0.8)
	V4._lamps(h, 0.2, 0.78, 0.04)
	V4._finish(root, model, h, mat, "dozer", [], "res://view/units/us/dozer.tscn", 1.2)

# ------------------------------------------------------------------ Supply Truck (harvester)
static func _supply_truck(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._wheelset(h, 0.4, [0.55, -0.25, -0.6], 0.15, 0.13, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.box(Vector3(0, 0.3, -0.05), Vector3(0.56, 0.08, 1.6))   # frame
	h.color(US, Geo.PAINT)
	h.bbox(Vector3(0, 0.55, 0.52), Vector3(0.74, 0.44, 0.5), 0.04)   # cab
	h.prism_x([Vector2(0.77, 0.33), Vector2(0.9, 0.36), Vector2(0.9, 0.52), Vector2(0.77, 0.56)], -0.34, 0.34)
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.68, 0.775), Vector3(0.6, 0.16, 0.02), Vector3(-12, 0, 0))
	h.color(US_D, Geo.PAINT)
	h.bbox(Vector3(0, 0.46, -0.38), Vector3(0.76, 0.16, 0.92), 0.02)   # bed
	for x in [-0.37, 0.37]:
		h.box(Vector3(x, 0.6, -0.38), Vector3(0.03, 0.18, 0.92))
	# supply crates and a strapped pallet
	var cols := ["#7c6a45", "#6b5a3a", "#8a7650"]
	for i in 4:
		h.color(cols[i % 3], Geo.WOOD)
		h.bbox(Vector3(-0.17 + (i % 2) * 0.34, 0.66, -0.17 - (i / 2) * 0.42), Vector3(0.3, 0.26, 0.36), 0.015)
	h.color("#3d4a5a", Geo.CANVAS)
	h.box(Vector3(0, 0.8, -0.38), Vector3(0.7, 0.02, 0.04))
	_team_band(h, 0.38, 0.52, 1.0)
	V4._lamps(h, 0.28, 0.42, 0.91)
	V4._finish(root, model, h, mat, "supply_truck", [], "res://view/units/us/supply_truck.tscn", 1.2)

# ------------------------------------------------------------------ Halberd MBT (Abrams-inspired)
static func _halberd(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.35, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._tracks(h, 0.5, 1.8, 7, 0.085, US_D, US_S, 0.24)
	V4._armour_hull(h, 0.64, 1.8, 0.12, 0.36, US, US_D, 0.32, 0.05)
	for s in [-0.645, 0.645]:   # side skirts
		h.color(US, Geo.PAINT)
		h.box(Vector3(s, 0.27, 0.1), Vector3(0.03, 0.15, 1.5))
	h.color(US_S, Geo.STEEL)
	h.box(Vector3(0, 0.44, -0.86), Vector3(0.7, 0.07, 0.08))   # rear grille
	V4._lamps(h, 0.45, 0.36, 0.9)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.43, -0.12))
	var t = Geo.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.36, 0.36, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(US, Geo.PAINT)
	# flat wedge turret with long rear bustle
	t.plan_loft([Vector2(-0.46, -0.62), Vector2(0.46, -0.62), Vector2(0.5, 0.18), Vector2(0.2, 0.56), Vector2(-0.2, 0.56), Vector2(-0.5, 0.18)], 0.0, 0.22, Vector2(0.9, 0.92), Vector2(0, -0.02))
	t.color(US_D, Geo.PAINT)
	t.bbox(Vector3(0, 0.12, -0.72), Vector3(0.84, 0.14, 0.18), 0.015)   # bustle rack
	t.color("#6b5a3a", Geo.CANVAS)
	t.bbox(Vector3(-0.2, 0.22, -0.72), Vector3(0.3, 0.08, 0.14), 0.02)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.15, -0.81), Vector3(0.6, 0.05, 0.02))
	t.color(US_S, Geo.STEEL)
	t.box(Vector3(0.24, 0.27, -0.1), Vector3(0.14, 0.08, 0.16))   # commander's sight
	t.tube(Vector3(-0.22, 0.25, -0.05), Vector3(-0.22, 0.32, 0.12), 0.012, 4)   # roof MG
	t.color("#2a3a46", Geo.GLASS)
	t.box(Vector3(0.24, 0.29, -0.015), Vector3(0.1, 0.04, 0.01))
	V4._antenna(t, Vector3(-0.36, 0.22, -0.55), 0.55)
	VK._mi(piv, root, "Turret", t.commit(mat))
	V4._barrel(piv, root, mat, Vector3(0, 0.11, 0.54), func(b) -> void:
		b.color(US, Geo.PAINT)
		b.tube(Vector3(0, 0, -0.04), Vector3(0, 0, 0.14), 0.07, 10)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 1.12), 0.042, 10, 0.036)
		b.color(US_D, Geo.PAINT)
		b.tube(Vector3(0, 0, 0.5), Vector3(0, 0, 0.62), 0.055, 10))   # bore evacuator
	V4._finish(root, model, h, mat, "halberd", [t], "res://view/units/us/halberd.tscn", 1.35)

# ------------------------------------------------------------------ Lynx JLTV (JLTV-inspired)
static func _lynx_body(h, col: String) -> void:
	V4._wheelset(h, 0.4, [0.5, -0.45], 0.17, 0.14, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.prism_x([Vector2(-0.8, 0.22), Vector2(0.74, 0.22), Vector2(0.84, 0.36), Vector2(0.84, 0.5), Vector2(-0.8, 0.5)], -0.38, 0.38)   # V-hull tub
	h.color(col, Geo.PAINT)
	h.prism_x([Vector2(0.2, 0.5), Vector2(0.86, 0.5), Vector2(0.84, 0.62), Vector2(0.24, 0.66)], -0.4, 0.4)   # high hood
	h.bbox(Vector3(0, 0.78, -0.2), Vector3(0.78, 0.36, 0.86), 0.04)   # crew cabin
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.84, 0.235), Vector3(0.66, 0.2, 0.02), Vector3(-8, 0, 0))
	for s in [-0.392, 0.392]:
		h.box(Vector3(s, 0.84, -0.05), Vector3(0.01, 0.14, 0.24))
		h.box(Vector3(s, 0.84, -0.4), Vector3(0.01, 0.14, 0.24))
	h.color(US_S, Geo.STEEL)
	h.box(Vector3(0, 0.5, 0.88), Vector3(0.62, 0.08, 0.05))   # brush bar
	h.color(US_D, Geo.PAINT)
	h.bbox(Vector3(0, 0.6, -0.8), Vector3(0.5, 0.16, 0.12), 0.02)   # rear stowage
	_team_band(h, 0.4, 0.66, 0.9)
	V4._lamps(h, 0.3, 0.52, 0.86)

static func _lynx(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.35, "recoil": 0.03, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	_lynx_body(h, US)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.97, -0.25))
	var t = Geo.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.16, 0.16, 0.04, 12, Transform3D.IDENTITY)
	t.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:   # gunner shield
		t.rbox(Vector3(s * 0.13, 0.1, 0.06), Vector3(0.03, 0.16, 0.18), Vector3(0, s * 25, 0))
	t.box(Vector3(0, 0.1, 0.13), Vector3(0.18, 0.16, 0.03))
	VK._mi(piv, root, "Turret", t.commit(mat))
	V4._barrel(piv, root, mat, Vector3(0, 0.13, 0.12), func(b) -> void:
		b.color(US_S, Geo.STEEL)
		b.box(Vector3(0, 0, 0.05), Vector3(0.06, 0.07, 0.16))
		b.tube(Vector3(0, 0, 0.1), Vector3(0, 0, 0.42), 0.014, 6))
	V4._finish(root, model, h, mat, "lynx", [t], "res://view/units/us/lynx.tscn", 1.35)

# ------------------------------------------------------------------ Picket SHORAD (Avenger-inspired)
static func _picket(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.5, "recoil": 0.02, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._wheelset(h, 0.4, [0.5, -0.45], 0.16, 0.14, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.prism_x([Vector2(-0.8, 0.2), Vector2(0.74, 0.2), Vector2(0.84, 0.34), Vector2(0.84, 0.46), Vector2(-0.8, 0.46)], -0.4, 0.4)
	h.color(US, Geo.PAINT)
	h.prism_x([Vector2(0.15, 0.46), Vector2(0.86, 0.46), Vector2(0.84, 0.56), Vector2(0.2, 0.6)], -0.42, 0.42)
	h.bbox(Vector3(0, 0.66, 0.05), Vector3(0.8, 0.3, 0.4), 0.03)   # two-door cab
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.72, 0.255), Vector3(0.68, 0.16, 0.02), Vector3(-10, 0, 0))
	h.color(US_D, Geo.PAINT)
	h.box(Vector3(0, 0.5, -0.5), Vector3(0.8, 0.08, 0.6))   # flat bed for the launcher
	_team_band(h, 0.42, 0.56, 0.9)
	V4._lamps(h, 0.3, 0.48, 0.86)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.56, -0.48))
	var t = Geo.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.22, 0.22, 0.05, 12, Transform3D.IDENTITY)
	t.color(US, Geo.PAINT)
	t.bbox(Vector3(0, 0.22, 0), Vector3(0.34, 0.36, 0.34), 0.03)   # gunner pod
	t.color("#2a3a46", Geo.GLASS)
	t.box(Vector3(0, 0.3, 0.172), Vector3(0.22, 0.12, 0.01))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.36, -0.172), Vector3(0.26, 0.04, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	V4._barrel(piv, root, mat, Vector3(0, 0.24, 0.0), func(b) -> void:
		for s in [-0.3, 0.3]:   # twin missile pods
			b.color(US, Geo.PAINT)
			b.bbox(Vector3(s, 0.0, 0.08), Vector3(0.2, 0.2, 0.5), 0.02)
			b.color("#1d1f1e", Geo.DARK)
			for k in 4:
				b.box(Vector3(s - 0.05 + (k % 2) * 0.1, -0.05 + (k / 2) * 0.1, 0.335), Vector3(0.06, 0.06, 0.01))
		b.color(US_S, Geo.STEEL)
		b.tube(Vector3(0.3, -0.14, 0.1), Vector3(0.3, -0.14, 0.48), 0.014, 6))   # MG under the right pod
	V4._finish(root, model, h, mat, "picket", [t], "res://view/units/us/picket.tscn", 1.5)

# ------------------------------------------------------------------ Longreach howitzer (M777-inspired, with prime mover)
static func _longreach(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.3, "recoil": 0.3, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	# prime mover (front)
	V4._wheelset(h, 0.38, [0.85, 0.35], 0.14, 0.12, 1, US_S)
	h.color(US_D, Geo.PAINT)
	h.box(Vector3(0, 0.28, 0.55), Vector3(0.54, 0.08, 0.86))
	h.color(US, Geo.PAINT)
	h.bbox(Vector3(0, 0.5, 0.8), Vector3(0.7, 0.36, 0.38), 0.04)
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.6, 0.995), Vector3(0.58, 0.14, 0.02), Vector3(-10, 0, 0))
	h.color("#5d5236", Geo.CANVAS)
	h.bbox(Vector3(0, 0.52, 0.32), Vector3(0.66, 0.34, 0.52), 0.06)   # canvas crew bay
	V4._lamps(h, 0.26, 0.42, 1.0)
	# towed gun carriage (rear): split trails toward the tow hitch
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.25, 0.1), Vector3(0, 0.25, -0.2), 0.03, 6)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.08, 0.2, -0.2), Vector3(s * 0.32, 0.12, -0.95), 0.035, 6)
		h.wheel(Vector3(s * 0.4, 0.17, -0.42), 0.17, 0.12, false, US_S, 12, 8)
	h.color(US, Geo.PAINT)
	h.bbox(Vector3(0, 0.33, -0.42), Vector3(0.5, 0.1, 0.34), 0.02)
	_team_band(h, 0.36, 0.5, 0.6)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.4, -0.42))
	var t = Geo.new()
	t.color(US, Geo.PAINT)
	for x in [-0.14, 0.14]:   # cradle cheeks
		t.box(Vector3(x, 0.12, 0.0), Vector3(0.05, 0.22, 0.3))
	t.color(US_S, Geo.STEEL)
	t.box(Vector3(0, 0.03, 0.0), Vector3(0.36, 0.05, 0.36))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.18, 0.0))
	bn.rotation.x = -0.5
	var b = Geo.new()
	b.color(US_D, Geo.PAINT)
	b.tube(Vector3(0, 0, -0.3), Vector3(0, 0, 0.25), 0.075, 10)
	b.color(US, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 1.55), 0.045, 10, 0.04)
	b.color(US_S, Geo.STEEL)
	b.bbox(Vector3(0, 0, 1.55), Vector3(0.12, 0.08, 0.14), 0.01)   # muzzle brake
	for x in [-0.07, 0.07]:
		b.tube(Vector3(x, 0.05, -0.2), Vector3(x, 0.05, 0.3), 0.02, 6)   # recuperators
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	V4._finish(root, model, h, mat, "longreach", [t, b], "res://view/units/us/longreach.tscn", 1.3)

# ------------------------------------------------------------------ aircraft
## Rotor node (spun by VehicleView when the aircraft flies): blades in the XZ plane.
static func _rotor(model: Node3D, root: Node3D, mat: Material, name: String, at: Vector3, r: float, n: int, axis_x := false) -> void:
	var rn := VK._n3(model, root, name, at)
	rn.set_meta("rotor_axis", "x" if axis_x else "y")
	var g = Geo.new()
	g.color("#2b2d2f", Geo.STEEL)
	if axis_x:
		g.cyl(0.03, 0.03, 0.04, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
		for i in n:
			var a := TAU * float(i) / float(n)
			g.rbox(Vector3(0, sin(a) * r * 0.5, cos(a) * r * 0.5), Vector3(0.01, 0.04, r), Vector3(-rad_to_deg(a), 0, 0))
	else:
		g.cyl(0.05, 0.04, 0.06, 8, Transform3D.IDENTITY)
		for i in n:
			var a := TAU * float(i) / float(n)
			g.rbox(Vector3(cos(a) * r * 0.5, 0.03, sin(a) * r * 0.5), Vector3(r, 0.012, 0.06), Vector3(0, -rad_to_deg(a), 0))
	VK._mi(rn, root, "RotorMesh", g.commit(mat))

## Harrier Gunship (Apache-inspired attack helicopter)
static func _harrier(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.2, "recoil": 0.02, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	h.color(US_D, Geo.PAINT)
	h.plan_loft([Vector2(-0.16, -0.45), Vector2(0.16, -0.45), Vector2(0.2, 0.2), Vector2(0.12, 0.62), Vector2(-0.12, 0.62), Vector2(-0.2, 0.2)], 0.12, 0.5, Vector2(0.8, 0.85))
	h.color("#2a3a46", Geo.GLASS)   # stepped tandem canopy
	h.rbox(Vector3(0, 0.5, 0.42), Vector3(0.2, 0.14, 0.26), Vector3(-14, 0, 0))
	h.rbox(Vector3(0, 0.58, 0.14), Vector3(0.22, 0.16, 0.28), Vector3(-10, 0, 0))
	h.color(US_D, Geo.PAINT)
	h.bbox(Vector3(0, 0.56, -0.18), Vector3(0.3, 0.16, 0.42), 0.04)   # engine hump
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.21, 0.46, 0.0), Vector3(s * 0.21, 0.46, -0.4), 0.075, 8)   # engine nacelles
	h.tube(Vector3(0, 0.36, -0.45), Vector3(0, 0.42, -1.35), 0.09, 8, 0.045)   # tail boom
	h.box(Vector3(0, 0.6, -1.32), Vector3(0.03, 0.36, 0.2))
	h.box(Vector3(0, 0.42, -1.2), Vector3(0.46, 0.025, 0.14))   # tailplane
	# stub wings with rocket pods and missile rails
	h.color(US, Geo.PAINT)
	h.box(Vector3(0, 0.36, -0.05), Vector3(1.0, 0.03, 0.2))
	for s in [-1.0, 1.0]:
		h.color(US_S, Geo.STEEL)
		h.tube(Vector3(s * 0.32, 0.28, 0.12), Vector3(s * 0.32, 0.28, -0.2), 0.055, 8)
		h.color("#3d3f37", Geo.DARK)
		for k in 2:
			h.tube(Vector3(s * (0.43 + 0.05 * k), 0.29, 0.06), Vector3(s * (0.43 + 0.05 * k), 0.29, -0.16), 0.022, 6)
	h.color(US_S, Geo.STEEL)   # landing gear
	for s in [-0.2, 0.2]:
		h.tube(Vector3(s, 0.12, 0.3), Vector3(s, 0.02, 0.3), 0.015, 4)
		h.wheel(Vector3(s, 0.05, 0.3), 0.05, 0.04, false, US_S, 8)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.205, 0.205]:
		h.box(Vector3(s, 0.3, -0.1), Vector3(0.01, 0.06, 0.4))
	h.box(Vector3(0, 0.44, -0.95), Vector3(0.1, 0.02, 0.18))
	_rotor(model, root, mat, "Rotor", Vector3(0, 0.72, -0.08), 1.5, 4)
	_rotor(model, root, mat, "TailRotor", Vector3(0.04, 0.62, -1.38), 0.36, 4, true)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.12, 0.5))
	var t = Geo.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.06, 0.06, 0.07, 8, Transform3D.IDENTITY)
	VK._mi(piv, root, "Turret", t.commit(mat))
	V4._barrel(piv, root, mat, Vector3(0, -0.02, 0.04), func(b) -> void:
		b.color(US_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 0.3), 0.016, 6))
	V4._finish(root, model, h, mat, "harrier", [t], "res://view/units/us/harrier.tscn", 1.2)

static func _wing(h, s: float, root_z0: float, root_z1: float, tip_x: float, tip_z0: float, tip_z1: float, y: float, th: float) -> void:
	h.faces([[Vector3(s * 0.1, y, root_z0), Vector3(s * tip_x, y, tip_z0), Vector3(s * tip_x, y, tip_z1), Vector3(s * 0.1, y, root_z1)],
		[Vector3(s * 0.1, y + th, root_z0), Vector3(s * tip_x, y + th * 0.4, tip_z0), Vector3(s * tip_x, y + th * 0.4, tip_z1), Vector3(s * 0.1, y + th, root_z1)]])

## Wraith Fighter (F-22-inspired: diamond wing, canted twin fins, twin engines)
static func _wraith(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.0, "recoil": 0.0, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	h.color(AIR, Geo.PAINT)
	h.plan_loft([Vector2(-0.2, -0.85), Vector2(0.2, -0.85), Vector2(0.24, 0.1), Vector2(0.12, 0.62), Vector2(0.0, 0.95), Vector2(-0.12, 0.62), Vector2(-0.24, 0.1)], 0.14, 0.3, Vector2(0.75, 0.9))
	h.color("#a07a2a", Geo.GLASS)   # gold-tinted canopy
	h.rbox(Vector3(0, 0.33, 0.45), Vector3(0.12, 0.08, 0.34), Vector3(-5, 0, 0))
	h.color(AIR_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		_wing(h, s, 0.2, -0.75, 0.82, -0.48, -0.78, 0.18, 0.05)
		h.faces([[Vector3(s * 0.16, 0.2, -0.65), Vector3(s * 0.48, 0.2, -0.88), Vector3(s * 0.48, 0.2, -1.0), Vector3(s * 0.16, 0.2, -0.95)],
			[Vector3(s * 0.16, 0.23, -0.65), Vector3(s * 0.48, 0.22, -0.88), Vector3(s * 0.48, 0.22, -1.0), Vector3(s * 0.16, 0.23, -0.95)]])   # tailplanes
		h.rbox(Vector3(s * 0.2, 0.4, -0.7), Vector3(0.02, 0.3, 0.3), Vector3(0, 0, s * 26))   # canted fins
		h.color(US_S, Geo.STEEL)
		h.box(Vector3(s * 0.1, 0.21, -0.9), Vector3(0.14, 0.09, 0.08))   # nozzles
		h.color(AIR_D, Geo.PAINT)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.55, 0.55]:
		h.box(Vector3(s, 0.205, -0.5), Vector3(0.18, 0.012, 0.1))
	h.color("#ff7a2a", Geo.LAMP)   # afterburner glow
	for s in [-0.1, 0.1]:
		h.box(Vector3(s, 0.21, -0.95), Vector3(0.08, 0.05, 0.02))
	h.color(US_S, Geo.STEEL)   # gear (visible when parked)
	for p in [Vector3(0, 0.0, 0.5), Vector3(-0.18, 0.0, -0.15), Vector3(0.18, 0.0, -0.15)]:
		h.tube(p + Vector3(0, 0.04, 0), p + Vector3(0, 0.15, 0), 0.012, 4)
		h.wheel(p + Vector3(0, 0.04, 0), 0.04, 0.03, false, US_S, 8)
	V4._finish(root, model, h, mat, "wraith", [], "res://view/units/us/wraith.tscn", 1.0)

## Thunderlance Bomber (B-1-inspired: long blended fuselage, swept wings, four engines)
static func _thunderlance(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.2, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	h.color("#5f6468", Geo.PAINT)
	h.tube(Vector3(0, 0.3, -1.2), Vector3(0, 0.3, 1.0), 0.17, 12, 0.12)
	h.cyl(0.12, 0.0, 0.42, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.3, 1.0)))
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.43, 0.9), Vector3(0.16, 0.06, 0.2), Vector3(-12, 0, 0))
	h.color("#55595d", Geo.PAINT)
	h.plan_loft([Vector2(-0.34, -0.5), Vector2(0.34, -0.5), Vector2(0.3, 0.45), Vector2(-0.3, 0.45)], 0.2, 0.36, Vector2(0.7, 0.85))   # blended wing root
	for s in [-1.0, 1.0]:
		_wing(h, s, 0.25, -0.35, 1.25, -0.62, -0.85, 0.28, 0.04)   # swept wings
		h.color(US_S, Geo.STEEL)
		for k in 2:   # paired engines under the wing root
			h.tube(Vector3(s * (0.24 + 0.17 * k), 0.15, -0.05), Vector3(s * (0.24 + 0.17 * k), 0.15, -0.6), 0.075, 8)
		h.color("#ff7a2a", Geo.LAMP)
		for k2 in 2:
			h.box(Vector3(s * (0.24 + 0.17 * k2), 0.15, -0.61), Vector3(0.09, 0.09, 0.01))
		h.color("#55595d", Geo.PAINT)
		h.faces([[Vector3(s * 0.05, 0.32, -0.95), Vector3(s * 0.62, 0.32, -1.15), Vector3(s * 0.62, 0.32, -1.27), Vector3(s * 0.05, 0.32, -1.22)],
			[Vector3(s * 0.05, 0.35, -0.95), Vector3(s * 0.62, 0.34, -1.15), Vector3(s * 0.62, 0.34, -1.27), Vector3(s * 0.05, 0.35, -1.22)]])
	h.box(Vector3(0, 0.6, -1.08), Vector3(0.03, 0.5, 0.32))   # fin
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.85, 0.85]:
		h.box(Vector3(s, 0.315, -0.45), Vector3(0.22, 0.012, 0.12))
	h.box(Vector3(0, 0.75, -1.12), Vector3(0.035, 0.08, 0.2))
	h.color(US_S, Geo.STEEL)
	for p in [Vector3(0, 0.0, 0.75), Vector3(-0.22, 0.0, -0.3), Vector3(0.22, 0.0, -0.3)]:
		h.tube(p + Vector3(0, 0.05, 0), p + Vector3(0, 0.16, 0), 0.015, 4)
		h.wheel(p + Vector3(0, 0.05, 0), 0.05, 0.04, false, US_S, 8)
	V4._finish(root, model, h, mat, "thunderlance", [], "res://view/units/us/thunderlance.tscn", 1.2)

# ------------------------------------------------------------------ structures
static func _lamp(g, p: Vector3, c := "#ff3a2a") -> void:
	g.color(c, Geo.LAMP)
	g.box(p, Vector3(0.05, 0.05, 0.05))

static func _flag(g, p: Vector3, hgt: float) -> void:
	g.color("#c9ccce", Geo.STEEL)
	g.tube(p, p + Vector3(0, hgt, 0), 0.01, 4)
	g.color("#ffffff", Geo.TEAM)
	g.box(p + Vector3(0.14, hgt - 0.08, 0), Vector3(0.26, 0.15, 0.01))

## Command Center: low two-storey concrete block, glass operations room, radar dome, helipad.
static func _command(g) -> void:
	g.color("#a8a397", Geo.CONCRETE)
	g.bbox(Vector3(-0.35, Y0 + 0.4, -0.3), Vector3(2.6, 0.8, 2.4), 0.04)
	g.color("#8f8a7c", Geo.CONCRETE)
	g.bbox(Vector3(-0.55, Y0 + 1.0, -0.45), Vector3(1.6, 0.4, 1.5), 0.03)
	g.color("#2a3a46", Geo.GLASS)
	g.box(Vector3(-0.55, Y0 + 1.02, 0.31), Vector3(1.4, 0.24, 0.02))
	g.box(Vector3(-0.35, Y0 + 0.45, 0.91), Vector3(2.2, 0.16, 0.02))
	g.color(US, Geo.PAINT)
	g.box(Vector3(-0.35, Y0 + 0.82, -0.3), Vector3(2.66, 0.05, 2.46))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.35, Y0 + 0.7, 0.915), Vector3(1.0, 0.08, 0.02))
	g.color("#d9d9d4", Geo.PAINT)   # radar dome
	g.cyl(0.32, 0.0, 0.34, 14, Transform3D(Basis.IDENTITY, Vector3(-1.0, Y0 + 1.2, -0.9)))
	g.cyl(0.3, 0.32, 0.12, 14, Transform3D(Basis.IDENTITY, Vector3(-1.0, Y0 + 1.14, -0.9)))
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(0.2, Y0 + 1.2, -0.8), Vector3(0.2, Y0 + 1.75, -0.8), 0.015, 4)
	_lamp(g, Vector3(0.2, Y0 + 1.77, -0.8))
	# helipad (east)
	g.color("#55524c", Geo.CONCRETE)
	g.cyl(0.6, 0.6, 0.03, 18, Transform3D(Basis.IDENTITY, Vector3(1.3, Y0 + 0.01, 1.1)))
	g.color("#e4e0d6", Geo.PAINT)
	g.box(Vector3(1.3, Y0 + 0.03, 1.1), Vector3(0.06, 0.004, 0.5))
	g.box(Vector3(1.15, Y0 + 0.03, 1.1), Vector3(0.06, 0.004, 0.5))
	g.box(Vector3(1.45, Y0 + 0.03, 1.1), Vector3(0.06, 0.004, 0.5))
	g.box(Vector3(1.3, Y0 + 0.03, 1.1), Vector3(0.3, 0.004, 0.06))
	_flag(g, Vector3(1.6, Y0, -1.6), 1.2)
	for x in [-1.4, 0.7]:
		g.sandbag(Vector3(x, Y0, 1.6), 0.5, 0.0)

## Fusion Plant: two squat containment drums with cooling fins and a control hut.
static func _reactor(g) -> void:
	for p in [Vector3(-0.6, 0, -0.35), Vector3(0.55, 0, 0.3)]:
		g.color("#b9b6ad", Geo.CONCRETE)
		g.cyl(0.55, 0.48, 1.3, 16, Transform3D(Basis.IDENTITY, p + Vector3(0, Y0 + 0.65, 0)))
		g.color("#d9d9d4", Geo.PAINT)
		g.cyl(0.48, 0.0, 0.32, 16, Transform3D(Basis.IDENTITY, p + Vector3(0, Y0 + 1.46, 0)))
		g.color(US, Geo.PAINT)
		g.cyl(0.565, 0.56, 0.1, 16, Transform3D(Basis.IDENTITY, p + Vector3(0, Y0 + 0.9, 0)))
		g.color("#6fd3ff", Geo.LAMP)
		g.cyl(0.57, 0.57, 0.04, 16, Transform3D(Basis.IDENTITY, p + Vector3(0, Y0 + 0.5, 0)))
	g.color(US_S, Geo.STEEL)
	for i in 6:
		g.box(Vector3(-0.2 + i * 0.08, Y0 + 0.4, -1.2), Vector3(0.02, 0.6, 0.4))
	g.color("#8f8a7c", Geo.CONCRETE)
	g.bbox(Vector3(0.75, Y0 + 0.25, -0.85), Vector3(0.7, 0.5, 0.5), 0.02)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.75, Y0 + 0.4, -0.595), Vector3(0.4, 0.07, 0.02))
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(-0.6, Y0 + 0.9, -0.35), Vector3(0.55, Y0 + 0.9, 0.3), 0.05, 6)

## Supply Center: warehouse with roll-up doors, loading dock and stacked supply pallets.
static func _supply_center(g) -> void:
	g.color("#8f8a7c", Geo.CONCRETE)
	g.bbox(Vector3(-0.35, Y0 + 0.45, -0.3), Vector3(2.1, 0.9, 1.6), 0.03)
	g.color(US, Geo.CORR)
	g.prism_x([Vector2(-1.1, Y0 + 0.9), Vector2(0.5, Y0 + 0.9), Vector2(-0.3, Y0 + 1.25)], -1.4, 0.7, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.35, 0, 0.0)))
	g.color("#3a3c3a", Geo.DARK)
	for x in [-0.9, -0.35, 0.2]:
		g.box(Vector3(x, Y0 + 0.32, 0.505), Vector3(0.42, 0.56, 0.02))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.35, Y0 + 0.75, 0.505), Vector3(1.2, 0.08, 0.02))
	g.color("#55524c", Geo.CONCRETE)
	g.box(Vector3(-0.35, Y0 + 0.08, 0.85), Vector3(2.1, 0.12, 0.6))   # dock apron
	var cols := ["#7c6a45", "#6b5a3a", "#5d6650"]
	for i in 6:
		g.color(cols[i % 3], Geo.WOOD)
		g.bbox(Vector3(1.05 + (i % 2) * 0.32, Y0 + 0.14 + (i / 4) * 0.26, -0.9 + ((i / 2) % 2) * 0.4), Vector3(0.28, 0.26, 0.34), 0.015)
	_flag(g, Vector3(1.3, Y0, 1.25), 0.9)

## Barracks: long hut with sandbagged entrance, flagpole, obstacle frame.
static func _barracks(g) -> void:
	g.color("#9a9384", Geo.CONCRETE)
	g.bbox(Vector3(-0.2, Y0 + 0.35, -0.35), Vector3(2.2, 0.7, 1.3), 0.03)
	g.color(US_D, Geo.CORR)
	g.prism_x([Vector2(-0.65, Y0 + 0.7), Vector2(0.65, Y0 + 0.7), Vector2(0.0, Y0 + 1.05)], -1.32, 0.92, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.2, 0, -0.35)))
	g.color("#3a3c3a", Geo.DARK)
	g.box(Vector3(-0.2, Y0 + 0.28, 0.31), Vector3(0.4, 0.5, 0.02))
	g.color("#2a3a46", Geo.GLASS)
	for x in [-1.0, -0.65, 0.3, 0.65]:
		g.box(Vector3(x, Y0 + 0.45, 0.31), Vector3(0.2, 0.14, 0.02))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.2, Y0 + 0.62, 0.315), Vector3(0.6, 0.07, 0.02))
	for x in [-0.55, 0.15]:
		g.sandbag(Vector3(x, Y0, 0.6), 0.35, 0.0)
	g.color("#6b5236", Geo.WOOD)   # obstacle course frame
	for x in [0.7, 1.2]:
		g.tube(Vector3(x, Y0, 1.0), Vector3(x, Y0 + 0.5, 1.0), 0.02, 4)
	g.tube(Vector3(0.7, Y0 + 0.5, 1.0), Vector3(1.2, Y0 + 0.5, 1.0), 0.02, 4)
	_flag(g, Vector3(1.25, Y0, -1.2), 1.1)

## Garage: big vehicle hall, three bays, a gantry crane over the yard.
static func _garage(g) -> void:
	g.color("#a39b8b", Geo.CONCRETE)
	g.bbox(Vector3(0, Y0 + 0.55, -0.6), Vector3(3.4, 1.1, 2.4), 0.04)
	g.color(US, Geo.CORR)
	g.box(Vector3(0, Y0 + 1.14, -0.6), Vector3(3.5, 0.08, 2.5))
	g.color("#3a3c3a", Geo.DARK)
	for x in [-1.1, 0.0, 1.1]:
		g.box(Vector3(x, Y0 + 0.42, 0.605), Vector3(0.9, 0.8, 0.02))
	g.color("#d8a531", Geo.PAINT)
	for x in [-1.1, 0.0, 1.1]:
		g.box(Vector3(x, Y0 + 0.86, 0.61), Vector3(0.94, 0.05, 0.02))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 1.0, 0.61), Vector3(1.6, 0.08, 0.02))
	g.color(US_S, Geo.STEEL)   # gantry crane over the yard
	for x in [-1.6, 1.6]:
		g.tube(Vector3(x, Y0, 1.5), Vector3(x, Y0 + 1.0, 1.5), 0.03, 4)
	g.box(Vector3(0, Y0 + 1.0, 1.5), Vector3(3.3, 0.08, 0.1))
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0.4, Y0 + 0.93, 1.5), Vector3(0.2, 0.1, 0.16))
	g.color("#2b2b2a", Geo.STEEL)
	g.tube(Vector3(0.4, Y0 + 0.9, 1.5), Vector3(0.4, Y0 + 0.5, 1.5), 0.008, 3)
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(1.3, Y0 + 1.15, -1.4), Vector3(1.3, Y0 + 1.6, -1.4), 0.06, 8)   # vent stack

## Airfield: apron with 6 parking stands (3 x 2, matching AirSys.parking_pos), hangar and tower.
static func _airfield(g) -> void:
	g.color("#55524c", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.01, 0), Vector3(3.9, 0.02, 3.9))
	g.color("#e4e0d6", Geo.PAINT)
	for r in 2:
		for c in 3:
			var p := Vector3(-1.333 + c * 1.333, Y0 + 0.022, -1.0 + r * 2.0)
			g.box(p + Vector3(0, 0, 0), Vector3(0.9, 0.004, 0.04))
			g.box(p + Vector3(-0.45, 0, 0), Vector3(0.04, 0.004, 1.4))
			g.box(p + Vector3(0.45, 0, 0), Vector3(0.04, 0.004, 1.4))
	g.color("#d8a531", Geo.PAINT)
	g.box(Vector3(0, Y0 + 0.022, 0.0), Vector3(3.8, 0.004, 0.06))   # taxi line
	g.color("#ffd27a", Geo.LAMP)
	for i in 8:
		g.box(Vector3(-1.85 + i * 0.53, Y0 + 0.03, 1.92), Vector3(0.03, 0.02, 0.03))
		g.box(Vector3(-1.85 + i * 0.53, Y0 + 0.03, -1.92), Vector3(0.03, 0.02, 0.03))
	# control tower (corner) and blast walls
	var tc := Vector3(1.75, Y0, 1.75)
	g.color("#8f8a7c", Geo.CONCRETE)
	g.bbox(tc + Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 0.3), 0.02)
	g.color("#2a3a46", Geo.GLASS)
	g.plan_loft([Vector2(-0.24, -0.24), Vector2(0.24, -0.24), Vector2(0.24, 0.24), Vector2(-0.24, 0.24)], 1.0, 1.18, Vector2(1.08, 1.08), Vector2.ZERO, Transform3D(Basis.IDENTITY, tc))
	g.color(US, Geo.PAINT)
	g.box(tc + Vector3(0, 1.2, 0), Vector3(0.56, 0.04, 0.56))
	g.color("#ffffff", Geo.TEAM)
	g.box(tc + Vector3(0, 0.8, -0.155), Vector3(0.22, 0.07, 0.01))
	_lamp(g, tc + Vector3(0, 1.26, 0))
	g.color("#9a9384", Geo.CONCRETE)
	for z in [-1.0, 1.0]:
		g.box(Vector3(-1.95, Y0 + 0.2, z), Vector3(0.08, 0.4, 1.2))
	g.color("#ff8a2a", Geo.CANVAS)   # windsock
	g.tube(Vector3(-1.85, Y0, -1.85), Vector3(-1.85, Y0 + 0.6, -1.85), 0.01, 4)
	g.tube(Vector3(-1.85, Y0 + 0.58, -1.85), Vector3(-1.67, Y0 + 0.55, -1.85), 0.04, 6, 0.02)

## Strategy Center: angular command bunker with a satellite dish and antenna mast.
static func _strategy(g) -> void:
	g.color("#9a9384", Geo.CONCRETE)
	g.plan_loft([Vector2(-1.2, -1.0), Vector2(1.2, -1.0), Vector2(1.3, 0.6), Vector2(0.8, 1.1), Vector2(-0.8, 1.1), Vector2(-1.3, 0.6)], Y0, Y0 + 0.75, Vector2(0.82, 0.82))
	g.color(US_D, Geo.PAINT)
	g.plan_loft([Vector2(-0.6, -0.5), Vector2(0.6, -0.5), Vector2(0.6, 0.5), Vector2(-0.6, 0.5)], Y0 + 0.75, Y0 + 1.05, Vector2(0.9, 0.9))
	g.color("#2a3a46", Geo.GLASS)
	g.box(Vector3(0, Y0 + 0.9, 0.46), Vector3(1.0, 0.14, 0.02))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.5, 1.0), Vector3(0.9, 0.08, 0.02))
	g.color("#d9d9d4", Geo.PAINT)   # dish
	g.cyl(0.45, 0.12, 0.16, 16, Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(-0.7, Y0 + 1.25, -0.5)))
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(-0.7, Y0 + 0.75, -0.5), Vector3(-0.7, Y0 + 1.2, -0.5), 0.04, 6)
	g.tube(Vector3(0.75, Y0 + 1.05, -0.4), Vector3(0.75, Y0 + 1.85, -0.4), 0.015, 4)
	for y in [1.3, 1.55]:
		g.box(Vector3(0.75, Y0 + y, -0.4), Vector3(0.24, 0.015, 0.015))
	_lamp(g, Vector3(0.75, Y0 + 1.87, -0.4))

## Bulwark SAM battery: sandbagged pad with a radar trailer; launcher on the TurretPivot.
static func _patriot(g) -> void:
	for a in 6:
		var ang := TAU * a / 6.0
		g.sandbag(Vector3(cos(ang) * 0.82, Y0, sin(ang) * 0.82), 0.4, rad_to_deg(-ang + PI * 0.5))
	g.color(US_D, Geo.PAINT)
	g.bbox(Vector3(0, Y0 + 0.12, 0), Vector3(0.7, 0.16, 0.7), 0.02)
	g.color(US, Geo.PAINT)
	g.bbox(Vector3(-0.55, Y0 + 0.25, -0.55), Vector3(0.36, 0.3, 0.3), 0.02)
	g.color("#d9d9d4", Geo.PAINT)
	g.rbox(Vector3(-0.55, Y0 + 0.5, -0.55), Vector3(0.32, 0.26, 0.03), Vector3(-20, 45, 0))

static func _patriot_turret(g) -> void:
	g.color(US_S, Geo.STEEL)
	g.cyl(0.24, 0.24, 0.06, 12, Transform3D.IDENTITY)
	g.color(US, Geo.PAINT)
	for s in [-0.17, 0.17]:   # two canisters raised at 35 degrees
		g.rbox(Vector3(s, 0.32, -0.05), Vector3(0.28, 0.24, 0.8), Vector3(35, 0, 0))
	g.color("#1d1f1e", Geo.DARK)
	for s in [-0.17, 0.17]:
		g.rbox(Vector3(s, 0.55, 0.28), Vector3(0.24, 0.2, 0.02), Vector3(35, 0, 0))
	g.color("#ffffff", Geo.TEAM)
	g.rbox(Vector3(0, 0.28, -0.1), Vector3(0.62, 0.05, 0.3), Vector3(35, 0, 0))

## Fire Base: low concrete bunker ring; howitzer turret on top.
static func _firebase(g) -> void:
	g.color("#9a9384", Geo.CONCRETE)
	g.cyl(0.92, 0.8, 0.5, 12, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.25, 0)))
	g.color("#3a3c3a", Geo.DARK)
	for a in 4:
		var ang := TAU * a / 4.0 + 0.4
		g.box(Vector3(cos(ang) * 0.86, Y0 + 0.3, sin(ang) * 0.86), Vector3(0.2, 0.08, 0.2))
	g.color("#ffffff", Geo.TEAM)
	g.cyl(0.81, 0.81, 0.05, 12, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.47, 0)))
	for a in 4:
		var ang2 := TAU * a / 4.0
		g.sandbag(Vector3(cos(ang2) * 0.95, Y0, sin(ang2) * 0.95), 0.35, rad_to_deg(-ang2 + PI * 0.5))

static func _firebase_turret(g) -> void:
	g.color(US_D, Geo.PAINT)
	g.cyl(0.42, 0.4, 0.22, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	g.color(US, Geo.PAINT)
	g.tube(Vector3(0, 0.22, 0.2), Vector3(0, 0.36, 1.15), 0.05, 10, 0.042)
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(0, 0.34, 1.05), Vector3(0, 0.37, 1.2), 0.065, 10)

## Supply Drop Zone: marked landing square with beacon mast, smoke pot and dropped pallets.
static func _drop_zone(g) -> void:
	g.color("#55524c", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.01, 0), Vector3(2.8, 0.02, 2.8))
	g.color("#d8a531", Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 1.3, Y0 + 0.022, 0), Vector3(0.12, 0.004, 2.7))
		g.box(Vector3(0, Y0 + 0.022, s * 1.3), Vector3(2.7, 0.004, 0.12))
	g.color("#e4e0d6", Geo.PAINT)
	g.rbox(Vector3(0, Y0 + 0.024, 0), Vector3(1.4, 0.004, 0.12), Vector3(0, 45, 0))
	g.rbox(Vector3(0, Y0 + 0.024, 0), Vector3(1.4, 0.004, 0.12), Vector3(0, -45, 0))
	g.color(US_S, Geo.STEEL)
	g.tube(Vector3(1.2, Y0, -1.2), Vector3(1.2, Y0 + 1.5, -1.2), 0.025, 4)
	_lamp(g, Vector3(1.2, Y0 + 1.52, -1.2), "#ffb02a")
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(1.2, Y0 + 1.2, -1.2), Vector3(0.08, 0.3, 0.08))
	var cols := ["#7c6a45", "#5d6650"]
	for i in 3:
		g.color(cols[i % 2], Geo.WOOD)
		g.bbox(Vector3(-0.7 + i * 0.45, Y0 + 0.16, 0.65 - (i % 2) * 0.3), Vector3(0.36, 0.3, 0.36), 0.02)
		g.color("#d9d9d4", Geo.CANVAS)   # spent parachute
		g.rbox(Vector3(-0.7 + i * 0.45, Y0 + 0.04, 0.95 - (i % 2) * 0.3), Vector3(0.4, 0.03, 0.25), Vector3(0, 20 * i, 0))
	g.color("#8f8a7c", Geo.CONCRETE)
	g.bbox(Vector3(-1.0, Y0 + 0.25, -1.0), Vector3(0.6, 0.5, 0.5), 0.02)
