extends RefCounted
## M2.6 core-asset upgrade (tool-time only): replaces the last M1/M2 programmer-art views of the
## most visible EU and TPLA units and main base buildings with detailed m3-kit models (panel
## seams, rivets, hatches, vents, stowage, lights, team bands), articulated turrets, construction
## stages + damage states for buildings, and LODs (tools/gfx_m3/geo.gd commit()).
##   godot --headless --path . -s res://tools/gen_gfx_m6.gd
## All shapes original; "inspired by" vehicle roles only.
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const Y0 := 0.08
const EU := "#7d8669"
const EU_D := "#5c6551"
const EU_S := "#3c3f40"
const TP := "#b89c70"
const TP_D := "#9a8058"
const TP_S := "#34322f"
const GLASS := "#2a3a46"
const OWNED := ["res://view/units/eu/wolfhound.tscn", "res://view/units/eu/flakwerk.tscn", "res://view/units/eu/aegis.tscn",
	"res://view/units/tpla/scrapback.tscn", "res://view/units/tpla/hailstorm.tscn",
	"res://view/buildings/eu/hq.tscn", "res://view/buildings/eu/heavy_factory.tscn", "res://view/buildings/eu/reactor.tscn",
	"res://view/buildings/tpla/camp.tscn", "res://view/buildings/tpla/den.tscn", "res://view/buildings/tpla/workshop.tscn",
	"res://view/units/eu/lancer.tscn", "res://view/units/tpla/rocket_cell.tscn", "res://view/units/tpla/laborer.tscn"]

static func build_all() -> void:
	var mat: Material = load(VK.MAT_PATH)
	_wolfhound(mat)
	_flakwerk(mat)
	_aegis(mat)
	_scrapback(mat)
	_hailstorm(mat)
	B4._make("eu", "hq", Vector2(4, 4), 3.2, _eu_hq)
	B4._make("eu", "heavy_factory", Vector2(4, 4), 3.3, _eu_factory)
	B4._make("eu", "reactor", Vector2(3, 3), 2.0, _eu_reactor)
	B4._make("tpla", "camp", Vector2(3, 3), 1.65, _tp_camp)
	B4._make("tpla", "den", Vector2(4, 4), 2.5, _tp_den)
	B4._make("tpla", "workshop", Vector2(3, 3), 2.1, _tp_workshop)

static func _tier(parent: Node3D, root: Node3D, mat: Material, name: String, g, tier: int) -> void:
	var m := VK._mi(parent, root, name, g.commit(mat))
	m.visible = false
	m.set_meta("tier", tier)

static func _band(h, hw: float, y: float, l: float, z := 0.0) -> void:
	h.color("#ffffff", Geo.TEAM)
	for s in [-hw - 0.004, hw + 0.004]:
		h.box(Vector3(s, y, z), Vector3(0.012, 0.035, l))

static func _smoke_launchers(t, x: float, y: float, z: float, yaw: float) -> void:
	t.color(EU_S, Geo.STEEL)
	for i in 3:
		var p := Vector3(x, y + i * 0.028, z)
		t.tube(p, p + Vector3(sin(deg_to_rad(yaw)), 0.25, cos(deg_to_rad(yaw))).normalized() * 0.07, 0.013, 6)

# ================================================================== EU Wolfhound (8x8 armoured car)
static func _wolfhound(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.3, "recoil": 0.06, "wreck_s": 7.0, "steer_max": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._wheelset(h, 0.37, [0.56, 0.22, -0.18, -0.52], 0.125, 0.12, 2, EU_S)
	# V-shaped belly and faceted upper hull (side profile z,y)
	h.color(EU_D, Geo.PAINT)
	h.prism_x([Vector2(-0.78, 0.2), Vector2(0.62, 0.2), Vector2(0.84, 0.36), Vector2(0.84, 0.42), Vector2(-0.8, 0.44)], -0.24, 0.24)
	h.color(EU, Geo.PAINT)
	h.prism_x([Vector2(-0.8, 0.4), Vector2(0.84, 0.4), Vector2(0.86, 0.46), Vector2(0.55, 0.58), Vector2(-0.74, 0.6), Vector2(-0.8, 0.54)], -0.36, 0.36)
	# sponsons over the wheels with stowage bins
	for s in [-1.0, 1.0]:
		h.color(EU, Geo.PAINT)
		h.prism_x([Vector2(-0.7, 0.34), Vector2(0.72, 0.34), Vector2(0.78, 0.42), Vector2(-0.74, 0.42)], s * 0.36, s * 0.43)
		h.color(EU_D, Geo.PAINT)
		h.bbox(Vector3(s * 0.4, 0.47, -0.42), Vector3(0.06, 0.1, 0.28), 0.008)
		h.bbox(Vector3(s * 0.4, 0.47, 0.02), Vector3(0.06, 0.1, 0.22), 0.008)
		h.color(EU_S, Geo.STEEL)
		h.rivets(Vector3(s * 0.437, 0.39, -0.66), Vector3(s * 0.437, 0.39, 0.7), 12, Vector3(s, 0, 0), 0.007)
		h.color("#4d5741", Geo.PAINT)
		for z in [-0.6, -0.68]:
			h.jerrycan(Vector3(s * 0.4, 0.52, z), 90)
	# glacis: driver hatch, periscopes, trim vane, headlight guards
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(-0.16, 0.555, 0.48), 0.13)
	h.rbox(Vector3(0, 0.4, 0.86), Vector3(0.62, 0.12, 0.02), Vector3(-35, 0, 0))   # trim vane
	h.color(GLASS, Geo.GLASS)
	for x in [-0.22, -0.16, -0.1]:
		h.box(Vector3(x, 0.585, 0.56), Vector3(0.035, 0.02, 0.025))
	V4._lamps(h, 0.28, 0.47, 0.86)
	h.color(EU_S, Geo.STEEL)
	for s in [-0.28, 0.28]:
		h.tube(Vector3(s - 0.04, 0.44, 0.88), Vector3(s + 0.04, 0.5, 0.88), 0.005, 3)
	# engine deck: grilles, exhaust, tow cable, rear door
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0.12, 0.6, -0.45), 0.34, 0.26, 6, 0)
	h.color(EU_S, Geo.STEEL)
	h.box(Vector3(0.12, 0.605, -0.45), Vector3(0.36, 0.006, 0.28))
	h.tube(Vector3(0.3, 0.55, -0.62), Vector3(0.42, 0.55, -0.78), 0.022, 6)
	h.tube(Vector3(-0.3, 0.61, -0.7), Vector3(-0.3, 0.61, 0.0), 0.009, 4)   # tow cable
	h.color(EU_D, Geo.PAINT)
	h.bbox(Vector3(0, 0.44, -0.81), Vector3(0.36, 0.22, 0.02), 0.006)
	h.color("#b33a2a", Geo.LAMP)
	for s in [-0.3, 0.3]:
		h.box(Vector3(s, 0.5, -0.81), Vector3(0.04, 0.03, 0.01))
	_band(h, 0.43, 0.43, 1.1)
	V4._antenna(h, Vector3(-0.28, 0.6, -0.62), 0.5)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.6, 0.02))
	var t = Geo.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.26, 0.26, 0.03, 14, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.26, -0.3), Vector2(0.26, -0.3), Vector2(0.28, 0.08), Vector2(0.12, 0.3), Vector2(-0.12, 0.3), Vector2(-0.28, 0.08)], 0.0, 0.2, Vector2(0.84, 0.86), Vector2(0, -0.02))
	t.color(EU_D, Geo.PAINT)
	t.bbox(Vector3(0, 0.08, -0.36), Vector3(0.44, 0.1, 0.1), 0.01)   # bustle box
	t.hatch(Vector3(-0.1, 0.2, -0.1), 0.12)
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.06, 0.055, 0.06, 8, Transform3D(Basis.IDENTITY, Vector3(0.11, 0.2, -0.08)))   # commander cupola
	t.color(GLASS, Geo.GLASS)
	t.box(Vector3(0.11, 0.24, -0.02), Vector3(0.07, 0.025, 0.02))
	t.color(EU_S, Geo.STEEL)
	t.bbox(Vector3(0.17, 0.24, 0.14), Vector3(0.07, 0.07, 0.08), 0.008)   # gunner sight
	t.color(GLASS, Geo.GLASS)
	t.box(Vector3(0.17, 0.24, 0.185), Vector3(0.05, 0.04, 0.01))
	_smoke_launchers(t, 0.24, 0.07, 0.18, 30)
	_smoke_launchers(t, -0.24, 0.07, 0.18, -30)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.1, -0.415), Vector3(0.36, 0.04, 0.012))
	V4._antenna(t, Vector3(-0.2, 0.2, -0.28), 0.42)
	VK._mi(piv, root, "Turret", t.commit(mat))
	V4._barrel(piv, root, mat, Vector3(0, 0.1, 0.3), func(b) -> void:
		b.color(EU, Geo.PAINT)
		b.bbox(Vector3(0, 0, 0.02), Vector3(0.12, 0.09, 0.08), 0.01)
		b.color(EU_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 0.62), 0.022, 8, 0.018)
		b.tube(Vector3(0, 0, 0.56), Vector3(0, 0, 0.66), 0.03, 8)   # muzzle brake
		b.tube(Vector3(0.05, -0.01, 0.02), Vector3(0.05, -0.01, 0.22), 0.01, 6))   # coax
	V4._finish(root, model, h, mat, "wolfhound", [t], "res://view/units/eu/wolfhound.tscn", 1.3)

# ================================================================== EU Flakwerk (tracked twin-gun SPAAG)
static func _flakwerk(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.6, "recoil": 0.05, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._tracks(h, 0.44, 1.56, 5, 0.085, EU_D, EU_S, 0.2)
	V4._armour_hull(h, 0.56, 1.56, 0.12, 0.38, EU, EU_D, 0.26, 0.06)
	for s in [-1.0, 1.0]:
		h.color(EU, Geo.PAINT)
		h.box(Vector3(s * 0.565, 0.3, 0.06), Vector3(0.025, 0.13, 1.3))   # side skirts
		h.color(EU_S, Geo.STEEL)
		h.rivets(Vector3(s * 0.58, 0.35, -0.55), Vector3(s * 0.58, 0.35, 0.68), 10, Vector3(s, 0, 0), 0.006)
	h.hatch(Vector3(-0.2, 0.44, 0.5), 0.13)
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.45, -0.55), 0.5, 0.2, 5)
	h.color(EU_S, Geo.STEEL)
	h.box(Vector3(0, 0.455, -0.55), Vector3(0.52, 0.006, 0.22))
	V4._lamps(h, 0.36, 0.34, 0.79)
	h.color("#4d5741", Geo.PAINT)
	for z in [-0.72, -0.64]:
		h.jerrycan(Vector3(0.42, 0.44, z), 90)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.45, -0.08))
	var t = Geo.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.32, 0.32, 0.03, 14, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.3, -0.36), Vector2(0.3, -0.36), Vector2(0.32, 0.18), Vector2(0.16, 0.34), Vector2(-0.16, 0.34), Vector2(-0.32, 0.18)], 0.0, 0.32, Vector2(0.88, 0.9))
	# gun pods on both sides
	for s in [-1.0, 1.0]:
		t.color(EU_D, Geo.PAINT)
		t.bbox(Vector3(s * 0.36, 0.2, 0.0), Vector3(0.1, 0.16, 0.42), 0.012)
		t.color("#ffffff", Geo.TEAM)
		t.box(Vector3(s * 0.413, 0.22, -0.05), Vector3(0.006, 0.04, 0.3))
	# search radar (back) and tracking radar (front)
	t.color(EU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.32, -0.26), Vector3(0, 0.5, -0.26), 0.02, 6)
	t.color("#8f948a", Geo.PAINT)
	t.rbox(Vector3(0, 0.56, -0.26), Vector3(0.46, 0.1, 0.04), Vector3(-12, 0, 0))
	t.color(EU_D, Geo.PAINT)
	t.cyl(0.09, 0.09, 0.05, 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.26, 0.32)))
	t.hatch(Vector3(0.12, 0.32, 0.0), 0.12)
	t.color(GLASS, Geo.GLASS)
	t.box(Vector3(-0.12, 0.3, 0.3), Vector3(0.1, 0.03, 0.02))
	_smoke_launchers(t, 0.2, 0.1, 0.32, 20)
	_smoke_launchers(t, -0.2, 0.1, 0.32, -20)
	VK._mi(piv, root, "Turret", t.commit(mat))
	V4._barrel(piv, root, mat, Vector3(0, 0.2, 0.2), func(b) -> void:
		for s in [-1.0, 1.0]:
			b.color(EU_S, Geo.STEEL)
			b.tube(Vector3(s * 0.36, 0, 0), Vector3(s * 0.36, 0.02, 0.7), 0.018, 8, 0.015)
			b.tube(Vector3(s * 0.36, 0.015, 0.6), Vector3(s * 0.36, 0.018, 0.72), 0.026, 8))
	V4._finish(root, model, h, mat, "flakwerk", [t], "res://view/units/eu/flakwerk.tscn", 1.6)

# ================================================================== EU Aegis (6x6 shield projector)
static func _aegis(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.95, "recoil": 0.0, "wreck_s": 7.0, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._wheelset(h, 0.36, [0.5, 0.0, -0.5], 0.13, 0.12, 1, EU_S)
	h.color(EU_D, Geo.PAINT)
	h.prism_x([Vector2(-0.74, 0.22), Vector2(0.6, 0.22), Vector2(0.78, 0.36), Vector2(0.78, 0.44), Vector2(-0.76, 0.44)], -0.3, 0.3)
	h.color(EU, Geo.PAINT)
	h.bbox(Vector3(0, 0.62, 0.48), Vector3(0.66, 0.36, 0.42), 0.04)   # cab
	h.color(GLASS, Geo.GLASS)
	h.rbox(Vector3(0, 0.68, 0.7), Vector3(0.56, 0.16, 0.02), Vector3(-15, 0, 0))
	for s in [-0.335, 0.335]:
		h.box(Vector3(s, 0.68, 0.48), Vector3(0.01, 0.14, 0.3))
	h.color(EU, Geo.PAINT)
	h.bbox(Vector3(0, 0.6, -0.3), Vector3(0.7, 0.32, 0.9), 0.03)   # equipment body
	h.color("#2b2d2c", Geo.DARK)
	for s in [-1.0, 1.0]:
		h.vent(Vector3(s * 0.352, 0.6, -0.5), 0.2, 0.16, 4, s * 90)
	h.color(EU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.rivets(Vector3(s * 0.352, 0.74, -0.72), Vector3(s * 0.352, 0.74, 0.12), 9, Vector3(s, 0, 0), 0.006)
	# projector mast with emitter dish and glowing coil rings (team lamp)
	h.color(EU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.76, -0.35), Vector3(0, 1.4, -0.35), 0.045, 8)
	for i in 3:
		h.color("#ffffff", Geo.TEAM_LAMP)
		h.cyl(0.085, 0.085, 0.025, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.95 + i * 0.13, -0.35)))
	h.color("#b8bdb6", Geo.PAINT)
	h.cyl(0.08, 0.3, 0.12, 16, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, -0.35)))
	h.color("#ffffff", Geo.TEAM_LAMP)
	h.cyl(0.05, 0.02, 0.1, 8, Transform3D(Basis.IDENTITY, Vector3(0, 1.48, -0.35)))
	for a in 4:   # stays
		var d := Vector3(cos(a * PI * 0.5 + 0.78), 0, sin(a * PI * 0.5 + 0.78)) * 0.3
		h.color(EU_S, Geo.STEEL)
		h.tube(Vector3(0, 1.2, -0.35), Vector3(d.x, 0.77, -0.35 + d.z), 0.008, 4)
	V4._lamps(h, 0.26, 0.46, 0.79)
	_band(h, 0.355, 0.5, 0.9, -0.3)
	V4._antenna(h, Vector3(0.28, 0.8, 0.4), 0.45)
	V4._finish(root, model, h, mat, "aegis", [], "res://view/units/eu/aegis.tscn", 1.95)

# ================================================================== TPLA Scrapback (rebuilt old tank)
static func _scrapback(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.33, "recoil": 0.14, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._tracks(h, 0.44, 1.6, 5, 0.1, "#5d5a52", TP_S, 0.22)
	V4._armour_hull(h, 0.56, 1.6, 0.12, 0.36, TP, TP_D, 0.3, 0.06)
	# mismatched welded plates and rust patches
	for b in [[0.57, 0.3, -0.35, "#5d6f7a"], [-0.57, 0.28, 0.25, "#8a4a34"], [0.57, 0.31, 0.38, "#6f6a52"], [-0.57, 0.3, -0.4, "#7a6a4a"]]:
		h.color(b[3], Geo.SCRAP)
		h.rbox(Vector3(b[0], b[1], b[2]), Vector3(0.02, 0.17, 0.36), Vector3(2.0, 0, 4))
		h.color(TP_S, Geo.STEEL)
		h.rivets(Vector3(b[0] * 1.02, b[1] + 0.07, b[2] - 0.15), Vector3(b[0] * 1.02, b[1] + 0.07, b[2] + 0.15), 4, Vector3(signf(b[0]), 0, 0), 0.008)
	# rear fuel drums, front mud guard, tow hooks, headlights in cages
	h.color("#4e5a3a", Geo.SCRAP)
	for s in [-0.22, 0.22]:
		h.cyl(0.08, 0.08, 0.34, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(s - 0.17, 0.5, -0.78)))
	h.color(TP_S, Geo.STEEL)
	for s in [-0.3, 0.3]:
		h.tube(Vector3(s, 0.22, 0.82), Vector3(s, 0.22, 0.9), 0.02, 5)
	V4._lamps(h, 0.34, 0.42, 0.72)
	h.color("#2b2a28", Geo.DARK)
	h.vent(Vector3(0, 0.43, -0.5), 0.5, 0.22, 5)
	h.color("#6b5a3a", Geo.CANVAS)
	h.bbox(Vector3(-0.38, 0.47, 0.0), Vector3(0.12, 0.08, 0.4), 0.02)   # tarp roll
	h.color("#ffffff", Geo.TEAM)
	h.rbox(Vector3(0.3, 0.44, 0.3), Vector3(0.22, 0.01, 0.24), Vector3(0, 12, 0))   # team cloth
	var t1 = Geo.new()
	t1.color("#7a7048", Geo.SANDBAG)
	for i in 4:
		t1.sandbag(Vector3(-0.27 + i * 0.18, 0.42, 0.66), 0.16, 0)
	t1.color("#6e5a46", Geo.SCRAP)
	for s in [-0.6, 0.6]:
		t1.rbox(Vector3(s, 0.3, 0.0), Vector3(0.015, 0.2, 1.1), Vector3(0, 0, -signf(s) * 8))
	_tier(model, root, mat, "Tier1", t1, 1)
	var t3 = Geo.new()
	t3.color("#4a4640", Geo.STEEL)
	for i in 8:
		var z := -0.6 + i * 0.17
		for s in [-0.64, 0.64]:
			t3.tube(Vector3(s, 0.2, z), Vector3(s, 0.48, z), 0.008, 4)
	for y in [0.26, 0.46]:
		for s in [-0.64, 0.64]:
			t3.tube(Vector3(s, y, -0.62), Vector3(s, y, 0.62), 0.008, 4)
	_tier(model, root, mat, "Tier3", t3, 3)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.42, 0.04))
	var t = Geo.new()
	t.color(TP_S, Geo.STEEL)
	t.cyl(0.36, 0.36, 0.03, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(TP_D, Geo.PAINT)
	t.cyl(0.36, 0.3, 0.12, 16, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))   # cast dome turret
	t.cyl(0.3, 0.16, 0.1, 16, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)))
	t.color(TP_S, Geo.STEEL)
	t.cyl(0.07, 0.065, 0.05, 8, Transform3D(Basis.IDENTITY, Vector3(-0.1, 0.2, -0.06)))
	t.hatch(Vector3(0.1, 0.21, -0.08), 0.1)
	t.tube(Vector3(-0.1, 0.27, -0.06), Vector3(-0.1, 0.3, 0.16), 0.01, 4)   # DShK-like roof MG
	t.color("#6f6a52", Geo.SCRAP)
	t.rbox(Vector3(0.27, 0.08, 0.12), Vector3(0.02, 0.14, 0.28), Vector3(0, 30, -14))
	t.color("#7a7048", Geo.SANDBAG)
	t.sandbag(Vector3(-0.22, 0.14, -0.26), 0.18, 30)
	t.sandbag(Vector3(0.06, 0.14, -0.32), 0.18, 0)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var t2 = Geo.new()
	t2.color("#5d6f7a", Geo.SCRAP)
	for s in [-1.0, 1.0]:
		t2.rbox(Vector3(s * 0.33, 0.08, 0.05), Vector3(0.02, 0.15, 0.32), Vector3(0, s * 20, -s * 12))
	_tier(piv, root, mat, "TurretTier2", t2, 2)
	var t3t = Geo.new()
	t3t.color(TP_S, Geo.STEEL)
	t3t.bbox(Vector3(0.22, 0.24, -0.12), Vector3(0.12, 0.08, 0.2), 0.01)   # salvaged rocket pod
	t3t.color("#2b2a28", Geo.DARK)
	for i in 2:
		t3t.box(Vector3(0.19 + i * 0.06, 0.24, -0.015), Vector3(0.04, 0.04, 0.01))
	_tier(piv, root, mat, "TurretTier3", t3t, 3)
	V4._barrel(piv, root, mat, Vector3(0, 0.1, 0.3), func(b) -> void:
		b.color(TP_D, Geo.PAINT)
		b.bbox(Vector3(0, 0, 0.0), Vector3(0.16, 0.12, 0.1), 0.02)
		b.color(TP_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 1.0), 0.04, 10, 0.034)
		b.tube(Vector3(0, 0, 0.82), Vector3(0, 0, 0.9), 0.05, 10)   # fume extractor
		b.color("#8a4a34", Geo.SCRAP)
		b.tube(Vector3(0, 0, 0.3), Vector3(0, 0, 0.42), 0.048, 10))
	V4._finish(root, model, h, mat, "scrapback", [t], "res://view/units/tpla/scrapback.tscn", 1.33)

# ================================================================== TPLA Hailstorm (quad AA truck)
static func _hailstorm(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.2, "recoil": 0.04, "wreck_s": 7.0, "steer_max": 0.45})
	var model := VK._n3(root, root, "Model")
	var h = Geo.new()
	V4._wheelset(h, 0.36, [0.5, -0.32, -0.6], 0.14, 0.12, 1, TP_S)
	h.color("#3a3631", Geo.STEEL)
	h.box(Vector3(0, 0.27, -0.05), Vector3(0.46, 0.07, 1.5))   # chassis
	h.color(TP, Geo.PAINT)
	h.bbox(Vector3(0, 0.5, 0.48), Vector3(0.68, 0.36, 0.44), 0.04)   # cab
	h.prism_x([Vector2(0.7, 0.3), Vector2(0.86, 0.34), Vector2(0.86, 0.48), Vector2(0.7, 0.52)], -0.3, 0.3)   # bonnet
	h.color(GLASS, Geo.GLASS)
	h.rbox(Vector3(0, 0.6, 0.705), Vector3(0.56, 0.15, 0.02), Vector3(-10, 0, 0))
	h.color("#2b2a28", Geo.DARK)
	h.box(Vector3(0, 0.42, 0.865), Vector3(0.4, 0.1, 0.012))   # grille
	h.color(TP_S, Geo.STEEL)
	h.box(Vector3(0, 0.3, 0.9), Vector3(0.66, 0.05, 0.05))   # bumper
	h.color("#8a4a34", Geo.SCRAP)
	h.rbox(Vector3(-0.35, 0.5, 0.48), Vector3(0.015, 0.22, 0.3), Vector3(0, 0, 4))   # mismatched door
	V4._lamps(h, 0.24, 0.45, 0.87)
	h.color(TP_D, Geo.PAINT)
	h.bbox(Vector3(0, 0.36, -0.36), Vector3(0.72, 0.08, 0.92), 0.02)   # flatbed
	for s in [-0.36, 0.36]:
		h.box(Vector3(s, 0.45, -0.36), Vector3(0.02, 0.12, 0.92))
	h.color("#7a7048", Geo.SANDBAG)
	for i in 3:
		h.sandbag(Vector3(-0.22 + i * 0.22, 0.44, 0.15), 0.2, 0)
	h.color("#4e5a3a", Geo.SCRAP)
	h.cyl(0.06, 0.06, 0.18, 8, Transform3D(Basis.IDENTITY, Vector3(0.28, 0.4, -0.75)))
	h.color("#6b5a3a", Geo.WOOD)
	h.bbox(Vector3(-0.24, 0.46, -0.72), Vector3(0.16, 0.1, 0.12), 0.01)   # ammo crate
	h.color("#ffffff", Geo.TEAM)
	h.rbox(Vector3(0, 0.69, 0.46), Vector3(0.5, 0.01, 0.3), Vector3(0, 6, 0))   # team cloth on roof
	V4._antenna(h, Vector3(0.3, 0.68, 0.32), 0.4)
	var t1 = Geo.new()
	t1.color("#6e5a46", Geo.SCRAP)
	t1.rbox(Vector3(0, 0.5, 0.88), Vector3(0.6, 0.18, 0.015), Vector3(-6, 0, 0))
	for s in [-0.37, 0.37]:
		t1.rbox(Vector3(s, 0.55, 0.48), Vector3(0.015, 0.2, 0.34), Vector3(0, 0, -signf(s) * 5))
	_tier(model, root, mat, "Tier1", t1, 1)
	var t3 = Geo.new()
	t3.color("#4a4640", Geo.STEEL)
	for i in 6:
		var z := 0.28 + i * 0.08
		for s in [-0.38, 0.38]:
			t3.tube(Vector3(s, 0.32, z), Vector3(s, 0.7, z), 0.008, 4)
	_tier(model, root, mat, "Tier3", t3, 3)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.42, -0.4))
	var t = Geo.new()
	t.color(TP_S, Geo.STEEL)
	t.cyl(0.2, 0.2, 0.04, 12, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	t.tube(Vector3(0, 0.04, 0), Vector3(0, 0.2, 0), 0.05, 8)
	t.color("#5b6442", Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.bbox(Vector3(s * 0.15, 0.24, 0.0), Vector3(0.06, 0.16, 0.2), 0.008)   # side frames
		t.color(TP_S, Geo.STEEL)
		t.box(Vector3(s * 0.15, 0.12, -0.12), Vector3(0.12, 0.02, 0.02))   # seat arms
		t.color("#5b6442", Geo.PAINT)
	t.color("#2b2a28", Geo.DARK)
	t.bbox(Vector3(0, 0.16, -0.2), Vector3(0.14, 0.03, 0.12), 0.005)   # gunner seat
	t.color("#5f6b4a", Geo.SCRAP)
	t.rbox(Vector3(0, 0.3, 0.2), Vector3(0.36, 0.14, 0.015), Vector3(-15, 0, 0))   # gun shield
	VK._mi(piv, root, "Turret", t.commit(mat))
	var t2 = Geo.new()
	t2.color("#6f6a52", Geo.SCRAP)
	for s in [-1.0, 1.0]:
		t2.rbox(Vector3(s * 0.24, 0.3, 0.14), Vector3(0.12, 0.16, 0.014), Vector3(-12, -s * 30, 0))
	_tier(piv, root, mat, "TurretTier2", t2, 2)
	V4._barrel(piv, root, mat, Vector3(0, 0.28, 0.04), func(b) -> void:
		b.color("#2b2a28", Geo.STEEL)
		for p in [Vector2(-0.07, 0.04), Vector2(0.07, 0.04), Vector2(-0.07, -0.04), Vector2(0.07, -0.04)]:
			b.tube(Vector3(p.x, p.y, -0.12), Vector3(p.x, p.y + 0.06, 0.62), 0.012, 6)
			b.tube(Vector3(p.x, p.y + 0.01, -0.06), Vector3(p.x, p.y + 0.02, 0.12), 0.022, 6)
			b.tube(Vector3(p.x, p.y + 0.05, 0.54), Vector3(p.x, p.y + 0.06, 0.62), 0.018, 6)
		b.color("#5a4c38", Geo.STEEL)
		for s in [-1.0, 1.0]:
			b.bbox(Vector3(s * 0.13, 0.0, -0.08), Vector3(0.06, 0.08, 0.1), 0.006))   # ammo boxes
	V4._finish(root, model, h, mat, "hailstorm", [t], "res://view/units/tpla/hailstorm.tscn", 1.2)

# ================================================================== EU buildings
static func _windows(g, x0: float, x1: float, y: float, z: float, n: int, w: float, hgt: float, face := 1.0) -> void:
	for i in n:
		var x := lerpf(x0, x1, (float(i) + 0.5) / float(n))
		g.color("#5d625f", Geo.STEEL)
		g.box(Vector3(x, y, z), Vector3(w + 0.03, hgt + 0.03, 0.012))
		g.color(GLASS, Geo.GLASS)
		g.box(Vector3(x, y, z + face * 0.008), Vector3(w, hgt, 0.01))

static func _ac_unit(g, p: Vector3) -> void:
	g.color("#8d9089", Geo.STEEL)
	g.bbox(p + Vector3(0, 0.07, 0), Vector3(0.2, 0.14, 0.16), 0.01)
	g.color("#2b2d2c", Geo.DARK)
	g.cyl(0.055, 0.055, 0.01, 10, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.142, 0)))

static func _floodlight(g, p: Vector3, hgt: float) -> void:
	g.color("#3c3f40", Geo.STEEL)
	g.tube(p, p + Vector3(0, hgt, 0), 0.016, 5)
	g.box(p + Vector3(0, hgt, 0), Vector3(0.18, 0.02, 0.02))
	g.color("#fff2c0", Geo.LAMP)
	for s in [-0.07, 0.07]:
		g.box(p + Vector3(s, hgt + 0.03, 0.02), Vector3(0.05, 0.04, 0.03))

## EU Command HQ: three-storey concrete command block with glazed ops deck, tower with radar
## and antenna farm, vehicle bay, helipad, sandbagged entrance, floodlights.
static func _eu_hq(g) -> void:
	var c1 := "#a8a397"
	var c2 := "#959082"
	g.color(c1, Geo.CONCRETE)
	g.bbox(Vector3(-0.3, Y0 + 0.5, -0.35), Vector3(2.6, 1.0, 2.2), 0.04)   # ground floor
	g.color(c2, Geo.CONCRETE)
	g.bbox(Vector3(-0.45, Y0 + 1.3, -0.5), Vector3(2.0, 0.6, 1.6), 0.03)    # 2nd floor
	g.color(c1, Geo.CONCRETE)
	g.bbox(Vector3(-0.55, Y0 + 1.82, -0.6), Vector3(1.3, 0.44, 1.1), 0.03)  # ops deck
	# floor slabs / cornices (panel lines that read at RTS distance)
	g.color("#7f7b70", Geo.CONCRETE)
	g.box(Vector3(-0.3, Y0 + 1.02, -0.35), Vector3(2.66, 0.05, 2.26))
	g.box(Vector3(-0.45, Y0 + 1.62, -0.5), Vector3(2.06, 0.05, 1.66))
	g.box(Vector3(-0.55, Y0 + 2.06, -0.6), Vector3(1.36, 0.05, 1.16))
	_windows(g, -1.5, 0.9, Y0 + 0.62, 0.76, 7, 0.18, 0.22)
	_windows(g, -1.35, 0.45, Y0 + 1.33, 0.31, 5, 0.2, 0.2)
	g.color(GLASS, Geo.GLASS)   # wrap-around ops glazing
	g.box(Vector3(-0.55, Y0 + 1.86, -0.04), Vector3(1.2, 0.22, 0.02))
	g.box(Vector3(0.1, Y0 + 1.86, -0.6), Vector3(0.02, 0.22, 1.0))
	g.color(EU, Geo.PAINT)
	g.box(Vector3(-0.55, Y0 + 2.08, -0.6), Vector3(1.4, 0.03, 1.2))   # roof edge
	# entrance: canopy, doors, team sign, sandbags, steps
	g.color(EU_D, Geo.PAINT)
	g.box(Vector3(-0.3, Y0 + 0.55, 0.95), Vector3(0.8, 0.04, 0.4))
	g.color("#3c3f40", Geo.STEEL)
	g.box(Vector3(-0.3, Y0 + 0.28, 0.765), Vector3(0.44, 0.44, 0.02))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.3, Y0 + 0.68, 0.77), Vector3(0.7, 0.12, 0.02))
	g.color("#ffffff", Geo.TEAM_LAMP)
	g.box(Vector3(-0.3, Y0 + 0.52, 1.15), Vector3(0.6, 0.015, 0.015))
	g.color("#8f8a7c", Geo.CONCRETE)
	for i in 3:
		g.box(Vector3(-0.3, Y0 + 0.02 + i * 0.04, 1.05 + 0.08 * (2 - i)), Vector3(0.6, 0.04, 0.1))
	for x in [-0.95, 0.35]:
		for k in 3:
			g.sandbag(Vector3(x + (k - 1) * 0.16, Y0 + 0.03, 1.25), 0.15, 0)
			g.sandbag(Vector3(x + (k - 1) * 0.16 + 0.08, Y0 + 0.09, 1.25), 0.15, 0)
	# command tower with radar and antenna farm
	g.color(c2, Geo.CONCRETE)
	g.bbox(Vector3(0.75, Y0 + 1.25, -1.0), Vector3(0.5, 2.5, 0.5), 0.03)
	g.color("#7f7b70", Geo.CONCRETE)
	for y in [0.9, 1.6, 2.3]:
		g.box(Vector3(0.75, Y0 + y, -1.0), Vector3(0.54, 0.04, 0.54))
	g.color(GLASS, Geo.GLASS)
	g.box(Vector3(0.75, Y0 + 2.35, -0.745), Vector3(0.4, 0.14, 0.01))
	g.color(EU_S, Geo.STEEL)
	g.tube(Vector3(0.75, Y0 + 2.5, -1.0), Vector3(0.75, Y0 + 2.7, -1.0), 0.04, 8)
	g.color("#c9ccc6", Geo.PAINT)
	g.rbox(Vector3(0.75, Y0 + 2.78, -1.0), Vector3(0.62, 0.14, 0.05), Vector3(-15, 30, 0))   # radar array
	B4._lamp(g, Vector3(0.75, Y0 + 2.9, -1.0))
	g.color(EU_S, Geo.STEEL)
	for p in [Vector3(-1.0, 0, -1.0), Vector3(-0.2, 0, -1.0), Vector3(-0.9, 0, -0.25)]:
		g.tube(p + Vector3(0, Y0 + 2.08, 0), p + Vector3(0, Y0 + 2.9, 0), 0.008, 4)
		g.box(p + Vector3(0, Y0 + 2.6, 0), Vector3(0.12, 0.008, 0.008))
	g.color("#d9d9d4", Geo.PAINT)   # satcom dish
	g.cyl(0.02, 0.22, 0.08, 12, Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(-0.15, Y0 + 2.18, -0.3)))
	for p in [Vector3(-1.3, Y0 + 1.02, 0.4), Vector3(-1.1, Y0 + 1.02, 0.4), Vector3(0.5, Y0 + 1.02, 0.4)]:
		_ac_unit(g, p)
	g.color("#2b2d2c", Geo.DARK)
	g.vent(Vector3(0.95, Y0 + 0.5, 0.765), 0.3, 0.3, 5)
	g.color(EU_S, Geo.STEEL)
	g.rivets(Vector3(-1.58, Y0 + 0.98, 0.77), Vector3(0.98, Y0 + 0.98, 0.77), 16, Vector3(0, 0, 1), 0.012)
	# vehicle bay (west) with roll-up door
	g.color(c2, Geo.CONCRETE)
	g.bbox(Vector3(-1.55, Y0 + 0.35, 0.35), Vector3(0.6, 0.7, 0.9), 0.03)
	g.color("#6d7266", Geo.CORR)
	g.box(Vector3(-1.55, Y0 + 0.3, 0.805), Vector3(0.46, 0.5, 0.02))
	g.color("#d8a531", Geo.PAINT)
	for i in 4:
		g.rbox(Vector3(-1.72 + i * 0.11, Y0 + 0.62, 0.81), Vector3(0.05, 0.08, 0.01), Vector3(0, 0, 40))
	# helipad
	g.color("#55524c", Geo.CONCRETE)
	g.cyl(0.55, 0.55, 0.03, 20, Transform3D(Basis.IDENTITY, Vector3(1.25, Y0 + 0.01, 1.2)))
	g.color("#e4e0d6", Geo.PAINT)
	for x in [1.1, 1.4]:
		g.box(Vector3(x, Y0 + 0.032, 1.2), Vector3(0.05, 0.004, 0.44))
	g.box(Vector3(1.25, Y0 + 0.032, 1.2), Vector3(0.3, 0.004, 0.05))
	for k in 6:
		B4._lamp(g, Vector3(1.25 + cos(k * TAU / 6.0) * 0.52, Y0 + 0.04, 1.2 + sin(k * TAU / 6.0) * 0.52), "#9bd0ff")
	_floodlight(g, Vector3(1.75, Y0, 0.2), 1.1)
	_floodlight(g, Vector3(-1.8, Y0, -1.6), 1.1)
	g.color("#c9ccce", Geo.STEEL)
	g.tube(Vector3(1.75, Y0, -1.75), Vector3(1.75, Y0 + 1.5, -1.75), 0.012, 4)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(1.6, Y0 + 1.4, -1.75), Vector3(0.28, 0.16, 0.01))

## EU Heavy Factory: steel-framed assembly hall with sawtooth skylight roof, big team-striped
## door, gantry crane over the yard, stacks, side workshop.
static func _eu_factory(g) -> void:
	g.color("#8a8d84", Geo.CONCRETE)
	g.bbox(Vector3(0, Y0 + 0.35, -0.4), Vector3(3.4, 0.7, 2.6), 0.03)   # plinth walls
	g.color("#6d7266", Geo.CORR)
	g.box(Vector3(0, Y0 + 1.2, -0.4), Vector3(3.3, 1.0, 2.5))
	# sawtooth roof: 5 teeth along x
	for i in 5:
		var x0 := -1.65 + i * 0.66
		g.color("#5d6257", Geo.CORR)
		g.prism_x([Vector2(-1.65, Y0 + 1.7), Vector2(0.85, Y0 + 1.7), Vector2(-1.65, Y0 + 2.2)], x0, x0 + 0.66)
		g.color(GLASS, Geo.GLASS)
		g.box(Vector3(x0 + 0.33, Y0 + 1.95, -1.66), Vector3(0.62, 0.48, 0.015))
		g.color(EU_S, Geo.STEEL)
		g.box(Vector3(x0 + 0.005, Y0 + 1.95, -0.4), Vector3(0.03, 0.03, 2.5))
	g.color(EU_S, Geo.STEEL)   # frame columns
	for x in [-1.66, -0.55, 0.55, 1.66]:
		g.box(Vector3(x, Y0 + 1.0, 0.86), Vector3(0.08, 1.4, 0.08))
	g.box(Vector3(0, Y0 + 1.72, 0.86), Vector3(3.4, 0.08, 0.1))
	# main door
	g.color("#4d524a", Geo.CORR)
	g.box(Vector3(0, Y0 + 0.62, 0.87), Vector3(1.4, 1.1, 0.02))
	g.color("#ffffff", Geo.TEAM)
	for i in 7:
		g.rbox(Vector3(-0.6 + i * 0.2, Y0 + 1.25, 0.885), Vector3(0.08, 0.14, 0.01), Vector3(0, 0, 40))
	g.color("#fff2c0", Geo.LAMP)
	for x in [-0.8, 0.8]:
		g.box(Vector3(x, Y0 + 1.38, 0.92), Vector3(0.1, 0.04, 0.05))
	_windows(g, -1.6, -0.85, Y0 + 1.0, 0.88, 2, 0.2, 0.3)
	_windows(g, 0.85, 1.6, Y0 + 1.0, 0.88, 2, 0.2, 0.3)
	# stacks with bands and lamps
	for p in [Vector3(1.3, 0, -1.3), Vector3(0.9, 0, -1.3)]:
		g.color("#7f7b70", Geo.CONCRETE)
		g.cyl(0.13, 0.1, 2.8, 12, Transform3D(Basis.IDENTITY, p + Vector3(0, Y0, 0)))
		g.color("#b33a2a", Geo.PAINT)
		g.cyl(0.11, 0.105, 0.14, 12, Transform3D(Basis.IDENTITY, p + Vector3(0, Y0 + 2.5, 0)))
		B4._lamp(g, p + Vector3(0, Y0 + 2.85, 0))
	# side workshop + vents + pipes
	g.color("#9a9384", Geo.CONCRETE)
	g.bbox(Vector3(-1.45, Y0 + 0.45, -1.45), Vector3(0.9, 0.9, 0.6), 0.03)
	g.color("#2b2d2c", Geo.DARK)
	for x in [-1.7, -1.2]:
		g.vent(Vector3(x, Y0 + 0.55, -1.14), 0.24, 0.2, 4)
	g.color(EU_S, Geo.STEEL)
	g.tube(Vector3(-1.0, Y0 + 0.8, -1.3), Vector3(0.7, Y0 + 0.8, -1.3), 0.04, 6)
	for x in [-0.4, 0.3]:
		_ac_unit(g, Vector3(x, Y0 + 2.2, -1.2))
	# gantry crane over the front yard
	g.color("#d8a531", Geo.PAINT)
	for x in [-1.75, 1.75]:
		g.box(Vector3(x, Y0 + 0.9, 1.45), Vector3(0.08, 1.8, 0.08))
	g.box(Vector3(0, Y0 + 1.82, 1.45), Vector3(3.6, 0.1, 0.12))
	g.color(EU_S, Geo.STEEL)
	g.bbox(Vector3(0.4, Y0 + 1.7, 1.45), Vector3(0.24, 0.12, 0.2), 0.01)
	g.tube(Vector3(0.4, Y0 + 1.64, 1.45), Vector3(0.4, Y0 + 1.1, 1.45), 0.006, 3)
	g.box(Vector3(0.4, Y0 + 1.08, 1.45), Vector3(0.1, 0.05, 0.06))
	# yard markings + crates
	g.color("#d8a531", Geo.PAINT)
	for x in [-0.75, 0.75]:
		g.box(Vector3(x, Y0 + 0.004, 1.35), Vector3(0.05, 0.008, 1.0))
	g.color("#6b5a3a", Geo.WOOD)
	g.bbox(Vector3(-1.5, Y0 + 0.12, 1.5), Vector3(0.3, 0.24, 0.26), 0.01)
	g.bbox(Vector3(-1.5, Y0 + 0.34, 1.5), Vector3(0.24, 0.2, 0.22), 0.01)

## EU Reactor: hyperboloid cooling tower, containment dome, transformer yard with insulators.
static func _eu_reactor(g) -> void:
	var rs := [0.62, 0.55, 0.48, 0.43, 0.41, 0.42, 0.46]
	for i in rs.size() - 1:
		g.color("#b5afa2" if i % 2 == 0 else "#aaa496", Geo.CONCRETE)
		g.cyl(rs[i], rs[i + 1], 0.27, 20, Transform3D(Basis.IDENTITY, Vector3(-0.55, Y0 + i * 0.27, -0.45)), false)
	g.color("#b33a2a", Geo.PAINT)
	g.cyl(0.465, 0.465, 0.06, 20, Transform3D(Basis.IDENTITY, Vector3(-0.55, Y0 + 1.55, -0.45)), false)
	g.color("#3a3734", Geo.CHAR)
	g.cyl(0.4, 0.4, 0.02, 20, Transform3D(Basis.IDENTITY, Vector3(-0.55, Y0 + 1.5, -0.45)))
	B4._lamp(g, Vector3(-0.1, Y0 + 1.64, -0.45))
	# containment dome + ring building
	g.color("#9a9384", Geo.CONCRETE)
	g.cyl(0.5, 0.5, 0.5, 20, Transform3D(Basis.IDENTITY, Vector3(0.6, Y0, 0.45)))
	g.color("#d0ccc2", Geo.PAINT)
	g.cyl(0.5, 0.36, 0.2, 20, Transform3D(Basis.IDENTITY, Vector3(0.6, Y0 + 0.5, 0.45)))
	g.cyl(0.36, 0.0, 0.22, 20, Transform3D(Basis.IDENTITY, Vector3(0.6, Y0 + 0.7, 0.45)))
	g.color("#ffffff", Geo.TEAM)
	g.cyl(0.505, 0.505, 0.06, 20, Transform3D(Basis.IDENTITY, Vector3(0.6, Y0 + 0.4, 0.45)), false)
	g.color("#ffffff", Geo.TEAM_LAMP)
	for k in 6:
		g.box(Vector3(0.6 + cos(k * TAU / 6.0) * 0.5, Y0 + 0.25, 0.45 + sin(k * TAU / 6.0) * 0.5), Vector3(0.05, 0.12, 0.05))
	# pipes between tower and dome, control hut, transformer yard
	g.color(EU_S, Geo.STEEL)
	g.tube(Vector3(-0.1, Y0 + 0.3, -0.3), Vector3(0.2, Y0 + 0.3, 0.2), 0.05, 8)
	g.tube(Vector3(-0.1, Y0 + 0.15, -0.2), Vector3(0.25, Y0 + 0.15, 0.3), 0.04, 8)
	g.color("#a8a397", Geo.CONCRETE)
	g.bbox(Vector3(0.75, Y0 + 0.22, -0.8), Vector3(0.6, 0.44, 0.4), 0.02)
	_windows(g, 0.5, 1.0, Y0 + 0.28, -0.595, 2, 0.14, 0.12)
	_ac_unit(g, Vector3(0.9, Y0 + 0.44, -0.85))
	g.color("#55524c", Geo.CONCRETE)
	g.box(Vector3(-0.75, Y0 + 0.02, 0.85), Vector3(1.0, 0.04, 0.5))
	for k in 3:
		var p := Vector3(-1.1 + k * 0.32, Y0 + 0.04, 0.85)
		g.color("#5f6458", Geo.PAINT)
		g.bbox(p + Vector3(0, 0.14, 0), Vector3(0.2, 0.28, 0.24), 0.01)
		g.color("#2b2d2c", Geo.DARK)
		g.vent(p + Vector3(0, 0.14, 0.125), 0.16, 0.2, 4)
		g.color("#8a5a3a", Geo.PAINT)
		for s in [-0.05, 0.05]:
			g.cyl(0.02, 0.012, 0.16, 6, Transform3D(Basis.IDENTITY, p + Vector3(s, 0.28, 0)))
	g.color(EU_S, Geo.STEEL)   # fence posts
	for k in 8:
		g.tube(Vector3(-1.4 + k * 0.4, Y0, 1.42), Vector3(-1.4 + k * 0.4, Y0 + 0.3, 1.42), 0.008, 3)
	g.box(Vector3(0, Y0 + 0.28, 1.42), Vector3(2.8, 0.008, 0.008))
	g.box(Vector3(0, Y0 + 0.16, 1.42), Vector3(2.8, 0.008, 0.008))

# ================================================================== TPLA buildings
const MUD := "#b49a72"
const MUD_D := "#9a8260"
static func _mud_block(g, c: Vector3, s: Vector3, col := MUD) -> void:
	g.color(col, Geo.CONCRETE)
	g.bbox(c, s, 0.04)
	g.color(MUD_D, Geo.CONCRETE)   # parapet lip
	g.box(c + Vector3(0, s.y * 0.5 + 0.02, 0), Vector3(s.x + 0.03, 0.05, s.z + 0.03))

static func _arch_door(g, c: Vector3, w: float, hgt: float, yaw := 0.0) -> void:
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c)
	g.color("#1a1714", Geo.DARK)
	g.box(Vector3(0, hgt * 0.5, 0), Vector3(w, hgt, 0.02), t)
	g.cyl(w * 0.5, w * 0.5, 0.02, 10, t * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, hgt, 0.01)))
	g.color("#6b5236", Geo.WOOD)
	g.box(Vector3(0, hgt + w * 0.5 + 0.03, 0.01), Vector3(w + 0.1, 0.04, 0.04), t)

static func _water_tank(g, p: Vector3) -> void:
	g.color("#3c3f40", Geo.STEEL)
	for s in [-0.08, 0.08]:
		g.box(p + Vector3(s, 0.06, 0), Vector3(0.02, 0.12, 0.2))
	g.color("#2f4a6a", Geo.PAINT)
	g.cyl(0.11, 0.11, 0.22, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0.22, -0.11)))

static func _tarp(g, c: Vector3, w: float, d: float, hgt: float, team := true) -> void:
	g.color("#3c3f40", Geo.WOOD)
	for p in [Vector2(-w, -d), Vector2(w, -d), Vector2(-w, d), Vector2(w, d)]:
		g.tube(c + Vector3(p.x * 0.5, 0, p.y * 0.5), c + Vector3(p.x * 0.5, hgt - (0.08 if p.y > 0 else 0.0), p.y * 0.5), 0.012, 4)
	g.color("#ffffff" if team else "#8a7a5a", Geo.TEAM if team else Geo.CANVAS)
	g.rbox(c + Vector3(0, hgt - 0.04, 0), Vector3(w + 0.06, 0.012, d + 0.06), Vector3(10, 0, 0))

## TPLA Camp (command): walled mud-brick compound, two-storey command house with rooftop radio
## room, water tanks, satellite dish, team tarps, sandbag gun nest, crates and a gate.
static func _tp_camp(g) -> void:
	_mud_block(g, Vector3(-0.2, Y0 + 0.45, -0.35), Vector3(1.5, 0.9, 1.2))
	_mud_block(g, Vector3(-0.45, Y0 + 1.15, -0.55), Vector3(0.8, 0.5, 0.7), "#a88e68")
	_arch_door(g, Vector3(-0.2, Y0, 0.26), 0.26, 0.38)
	for x in [-0.75, 0.35]:   # small deep windows with wooden lintels
		g.color("#1a1714", Geo.DARK)
		g.box(Vector3(x, Y0 + 0.6, 0.255), Vector3(0.14, 0.16, 0.02))
		g.color("#6b5236", Geo.WOOD)
		g.box(Vector3(x, Y0 + 0.7, 0.262), Vector3(0.2, 0.03, 0.03))
	g.color("#1a1714", Geo.DARK)
	g.box(Vector3(-0.45, Y0 + 1.18, -0.195), Vector3(0.3, 0.14, 0.02))
	g.color("#6b5236", Geo.WOOD)   # protruding roof beams
	for k in 5:
		g.tube(Vector3(-0.85 + k * 0.32, Y0 + 0.86, 0.2), Vector3(-0.85 + k * 0.32, Y0 + 0.86, 0.32), 0.018, 4)
	_water_tank(g, Vector3(0.3, Y0 + 0.92, -0.7))
	_water_tank(g, Vector3(0.3, Y0 + 0.92, -0.35))
	g.color("#d9d9d4", Geo.PAINT)
	g.cyl(0.02, 0.17, 0.06, 10, Transform3D(Basis(Vector3.RIGHT, -0.8), Vector3(-0.2, Y0 + 1.45, -0.7)))
	g.color("#3c3f40", Geo.STEEL)
	g.tube(Vector3(-0.7, Y0 + 1.4, -0.75), Vector3(-0.7, Y0 + 2.1, -0.75), 0.01, 4)   # radio mast
	g.tube(Vector3(-0.7, Y0 + 1.9, -0.75), Vector3(-0.4, Y0 + 1.4, -0.4), 0.003, 3)
	B4._lamp(g, Vector3(-0.7, Y0 + 2.12, -0.75))
	_tarp(g, Vector3(0.75, Y0, 0.45), 0.6, 0.5, 0.55)
	g.color("#6b5a3a", Geo.WOOD)
	for k in 4:
		g.bbox(Vector3(0.6 + (k % 2) * 0.24, Y0 + 0.1 + (k / 2) * 0.2, 0.4), Vector3(0.2, 0.18, 0.2), 0.01)
	# compound wall with gate and gun nest
	g.color(MUD_D, Geo.CONCRETE)
	g.bbox(Vector3(-1.4, Y0 + 0.2, 0.0), Vector3(0.12, 0.4, 2.6), 0.02)
	g.bbox(Vector3(0.0, Y0 + 0.2, -1.38), Vector3(2.9, 0.4, 0.12), 0.02)
	g.bbox(Vector3(1.4, Y0 + 0.2, -0.6), Vector3(0.12, 0.4, 1.5), 0.02)
	g.bbox(Vector3(-0.9, Y0 + 0.2, 1.36), Vector3(1.0, 0.4, 0.12), 0.02)
	g.color("#6b5236", Geo.WOOD)
	g.box(Vector3(0.6, Y0 + 0.5, 1.36), Vector3(0.05, 0.6, 0.05))
	g.box(Vector3(-0.35, Y0 + 0.5, 1.36), Vector3(0.05, 0.6, 0.05))
	g.box(Vector3(0.12, Y0 + 0.78, 1.36), Vector3(1.05, 0.06, 0.06))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.12, Y0 + 0.66, 1.37), Vector3(0.5, 0.16, 0.01))
	for k in 6:
		var a := k * PI / 5.0
		g.sandbag(Vector3(1.1 + cos(a) * 0.22, Y0 + 0.03, 1.05 + sin(a) * 0.22), 0.14, rad_to_deg(-a) + 90)
		g.sandbag(Vector3(1.1 + cos(a) * 0.22, Y0 + 0.09, 1.05 + sin(a) * 0.22), 0.14, rad_to_deg(-a) + 90)
	g.color("#2b2a28", Geo.STEEL)
	g.tube(Vector3(1.1, Y0 + 0.15, 1.05), Vector3(1.1, Y0 + 0.24, 1.35), 0.012, 4)
	g.color("#1e1d1c", Geo.RUBBER)
	for p in [Vector3(-1.15, Y0, 0.9), Vector3(-1.05, Y0 + 0.05, 1.0)]:
		g.cyl(0.1, 0.1, 0.05, 10, Transform3D(Basis.IDENTITY, p))

## TPLA Den (barracks): two arcaded mud-brick halls around a courtyard, rooftop shade tarps,
## stairs, laundry lines, rifles rack, tyres and oil drums.
static func _tp_den(g) -> void:
	_mud_block(g, Vector3(-0.6, Y0 + 0.55, -0.7), Vector3(2.4, 1.1, 1.4))
	_mud_block(g, Vector3(0.95, Y0 + 0.45, 0.35), Vector3(1.2, 0.9, 1.9), "#a88e68")
	for k in 5:   # arcade
		_arch_door(g, Vector3(-1.5 + k * 0.45, Y0, 0.005), 0.24, 0.42)
	for k in 3:
		_arch_door(g, Vector3(0.345, Y0, -0.3 + k * 0.5), 0.22, 0.38, -90)
	g.color("#6b5236", Geo.WOOD)
	for k in 7:
		g.tube(Vector3(-1.75 + k * 0.38, Y0 + 1.06, 0.0), Vector3(-1.75 + k * 0.38, Y0 + 1.06, 0.12), 0.018, 4)
	# stairs to the roof
	g.color(MUD_D, Geo.CONCRETE)
	for i in 6:
		g.box(Vector3(0.2 - i * 0.0, Y0 + 0.08 + i * 0.17, 0.2 + 0.1 * (5 - i)), Vector3(0.3, 0.06, 0.12))
	_tarp(g, Vector3(-1.1, Y0 + 1.1, -0.7), 0.9, 0.8, 0.45)
	_tarp(g, Vector3(0.95, Y0 + 0.9, 0.7), 0.7, 0.6, 0.4, false)
	_water_tank(g, Vector3(-0.1, Y0 + 1.12, -1.0))
	g.color("#3c3f40", Geo.STEEL)
	g.tube(Vector3(0.6, Y0 + 1.12, -1.2), Vector3(0.6, Y0 + 2.2, -1.2), 0.01, 4)
	B4._lamp(g, Vector3(0.6, Y0 + 2.22, -1.2))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0.74, Y0 + 2.05, -1.2), Vector3(0.26, 0.15, 0.01))
	g.color("#8a7a5a", Geo.CANVAS)   # laundry line
	g.tube(Vector3(-1.7, Y0 + 0.6, 0.6), Vector3(-0.3, Y0 + 0.6, 1.2), 0.004, 3)
	for k in 4:
		g.box(Vector3(-1.5 + k * 0.32, Y0 + 0.52, 0.68 + k * 0.13), Vector3(0.12, 0.14, 0.01))
	g.color("#4e5a3a", Geo.SCRAP)
	for p in [Vector3(-1.75, Y0, 1.5), Vector3(-1.55, Y0, 1.6), Vector3(1.7, Y0, -1.6)]:
		g.cyl(0.08, 0.08, 0.24, 10, Transform3D(Basis.IDENTITY, p))
	g.color("#1e1d1c", Geo.RUBBER)
	g.cyl(0.12, 0.12, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(1.6, Y0, 1.5)))
	g.cyl(0.12, 0.12, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(1.6, Y0 + 0.06, 1.5)))
	for k in 5:
		g.sandbag(Vector3(-0.5 + k * 0.17, Y0 + 0.03, 1.7), 0.16, 0)

## TPLA Workshop: corrugated lean-to shed on a mud wall, engine hoist, car on blocks, scrap heaps.
static func _tp_workshop(g) -> void:
	_mud_block(g, Vector3(-0.2, Y0 + 0.5, -1.1), Vector3(2.4, 1.0, 0.4))
	g.color("#3c3f40", Geo.STEEL)
	for x in [-1.3, -0.45, 0.4, 1.0]:
		g.tube(Vector3(x, Y0, 0.4), Vector3(x, Y0 + 1.35, 0.4), 0.025, 5)
	g.color("#7d6f5e", Geo.CORR)
	g.rbox(Vector3(-0.15, Y0 + 1.45, -0.35), Vector3(2.6, 0.03, 1.7), Vector3(-14, 0, 0))
	g.color("#8a4a34", Geo.SCRAP)
	g.rbox(Vector3(0.6, Y0 + 1.47, -0.3), Vector3(0.6, 0.035, 0.8), Vector3(-14, 0, 0))   # rusty patch
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.15, Y0 + 1.25, 0.43), Vector3(1.2, 0.12, 0.01))
	# engine hoist (A-frame) with an engine block hanging
	g.color("#d8a531", Geo.PAINT)
	g.tube(Vector3(-0.9, Y0, -0.2), Vector3(-0.7, Y0 + 1.0, 0.0), 0.02, 4)
	g.tube(Vector3(-0.5, Y0, -0.2), Vector3(-0.7, Y0 + 1.0, 0.0), 0.02, 4)
	g.tube(Vector3(-0.7, Y0 + 1.0, 0.0), Vector3(-0.7, Y0 + 1.0, 0.4), 0.02, 4)
	g.color("#3a3631", Geo.STEEL)
	g.tube(Vector3(-0.7, Y0 + 0.98, 0.35), Vector3(-0.7, Y0 + 0.62, 0.35), 0.004, 3)
	g.bbox(Vector3(-0.7, Y0 + 0.52, 0.35), Vector3(0.22, 0.18, 0.28), 0.02)
	# pickup on blocks, no wheels
	g.color("#6f7a83", Geo.PAINT)
	g.bbox(Vector3(0.5, Y0 + 0.36, -0.1), Vector3(0.5, 0.2, 1.0), 0.03)
	g.bbox(Vector3(0.5, Y0 + 0.55, 0.12), Vector3(0.46, 0.2, 0.4), 0.03)
	g.color(GLASS, Geo.GLASS)
	g.rbox(Vector3(0.5, Y0 + 0.58, 0.33), Vector3(0.4, 0.13, 0.01), Vector3(-12, 0, 0))
	g.color("#6b5236", Geo.WOOD)
	for p in [Vector3(0.3, 0, 0.25), Vector3(0.7, 0, 0.25), Vector3(0.3, 0, -0.45), Vector3(0.7, 0, -0.45)]:
		g.box(p + Vector3(0, Y0 + 0.12, 0), Vector3(0.1, 0.24, 0.1))
	# scrap heaps, tyre stacks, drums, workbench
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	for k in 14:
		var p := Vector3(rng.randf_range(0.9, 1.4), Y0 + 0.05, rng.randf_range(0.6, 1.4))
		g.color(["#5d6f7a", "#8a4a34", "#6f6a52", "#3a3631"][k % 4], Geo.SCRAP)
		g.rbox(p, Vector3(rng.randf_range(0.1, 0.3), 0.05, rng.randf_range(0.08, 0.2)), Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 180), rng.randf_range(-20, 20)))
	g.color("#1e1d1c", Geo.RUBBER)
	for i in 4:
		g.cyl(0.12, 0.12, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(-1.3, Y0 + i * 0.06, 0.9)))
	g.color("#4e5a3a", Geo.SCRAP)
	for p in [Vector3(-1.0, Y0, 1.25), Vector3(-0.8, Y0, 1.3)]:
		g.cyl(0.08, 0.08, 0.24, 10, Transform3D(Basis.IDENTITY, p))
	g.color("#6b5236", Geo.WOOD)
	g.bbox(Vector3(-0.2, Y0 + 0.3, -0.8), Vector3(0.7, 0.04, 0.25), 0.005)
	for x in [-0.5, 0.1]:
		g.box(Vector3(x, Y0 + 0.14, -0.8), Vector3(0.04, 0.28, 0.2))
	g.color("#fff2c0", Geo.LAMP)
	g.box(Vector3(-0.15, Y0 + 1.3, -0.2), Vector3(0.1, 0.03, 0.05))
