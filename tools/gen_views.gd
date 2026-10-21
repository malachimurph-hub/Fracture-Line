extends SceneTree
## Generates the placeholder view wrapper scenes (original primitive art) and shared materials.
## Run: godot --headless --path . -s tools/gen_views.gd

const M := "res://view/materials/"
var mats := {}

func _init() -> void:
	UNITS["grenadier"] = _squad(4, false)
	UNITS["lancer"] = _squad(3, true)
	_make_mats()
	for id in UNITS:
		_save(UNITS[id], "res://view/units/eu/%s.tscn" % id, false, Vector2.ONE)
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		_save(b["parts"], b["path"], true, b["fp"])
	for id in PROPS:
		_save(PROPS[id], "res://view/neutral/%s.tscn" % id, false, Vector2.ONE)
	print("views generated")
	quit()

func _mat(name: String, col: Color, emit: float = 0.0, rough: float = 0.8, metal: float = 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	ResourceSaver.save(m, M + name + ".tres")
	mats[name] = load(M + name + ".tres")

func _make_mats() -> void:
	DirAccess.make_dir_recursive_absolute("res://view/materials")
	_mat("gunmetal", Color("#5a616b"), 0, 0.6, 0.3)
	_mat("gunmetal_dark", Color("#3c4148"), 0, 0.7, 0.2)
	_mat("gold", Color("#d4a73a"), 0, 0.45, 0.5)
	_mat("cyan", Color("#6fe3ff"), 1.6, 0.3)
	_mat("tread", Color("#23262b"), 0, 0.95)
	_mat("team", Color("#ffffff"), 0, 0.5)
	_mat("skin", Color("#c99b78"), 0, 0.9)
	_mat("concrete", Color("#b9b2a3"), 0, 0.95)
	_mat("window", Color("#2b3644"), 0.25, 0.2)
	_mat("crystal", Color("#5ce0a0"), 1.2, 0.2)
	_mat("crate", Color("#8a6a3a"), 0, 0.9)
	_mat("rust", Color("#7a5a3a"), 0, 0.8)

# part: [shape, size(Vector3), pos(Vector3), rot_deg(Vector3), mat, parent]
# shapes: box (size), cyl (x=radius, y=height, z=sides), cone, sph (x=radius), cap (x=radius, y=height)
func _mesh(shape: String, s: Vector3) -> Mesh:
	match shape:
		"box":
			var b := BoxMesh.new(); b.size = s; return b
		"cyl":
			var c := CylinderMesh.new(); c.top_radius = s.x; c.bottom_radius = s.x; c.height = s.y
			c.radial_segments = int(s.z) if s.z > 0 else 12; c.rings = 1; return c
		"cone":
			var k := CylinderMesh.new(); k.top_radius = s.z; k.bottom_radius = s.x; k.height = s.y; k.radial_segments = 10; k.rings = 1; return k
		"sph":
			var p := SphereMesh.new(); p.radius = s.x; p.height = s.x * 2; p.radial_segments = 12; p.rings = 6; return p
		"cap":
			var q := CapsuleMesh.new(); q.radius = s.x; q.height = s.y; q.radial_segments = 8; q.rings = 2; return q
	return BoxMesh.new()

func _save(parts: Array, path: String, structure: bool, fp: Vector2) -> void:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/wrappers/entity_view.gd"))
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	var turret: Node3D = null
	var top := 0.0
	var extent := 0.3
	for p in parts:
		var parent: Node3D = model
		if p.size() > 5 and p[5] == "turret":
			if turret == null:
				turret = Node3D.new()
				turret.name = "TurretPivot"
				model.add_child(turret)
				turret.owner = root
			parent = turret
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh(p[0], p[1])
		mi.position = p[2]
		mi.rotation_degrees = p[3]
		mi.material_override = mats[p[4]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if p[4] == "team":
			mi.set_meta("team", true)
		parent.add_child(mi)
		mi.owner = root
		top = maxf(top, p[2].y + (p[1].y * 0.5 if p[0] != "sph" else p[1].x))
		extent = maxf(extent, maxf(absf(p[2].x) + p[1].x * 0.5, absf(p[2].z) + p[1].z * 0.5))
	var anchor := Marker3D.new()
	anchor.name = "HealthBarAnchor"
	anchor.position = Vector3(0, top + 0.25, 0)
	root.add_child(anchor)
	anchor.owner = root
	root.set("bar_height", top + 0.25)
	root.set("is_structure", structure)
	root.set("footprint", fp)
	root.set("selection_radius", maxf(fp.x, fp.y) * 0.5 if structure else minf(extent, 0.8))
	var ps := PackedScene.new()
	ps.pack(root)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ResourceSaver.save(ps, path)
	root.free()

func _squad(n: int, tube: bool) -> Array:
	var out: Array = []
	var offs := [Vector2(-0.2, -0.18), Vector2(0.2, -0.18), Vector2(-0.2, 0.2), Vector2(0.2, 0.2), Vector2(0, 0)]
	for i in n:
		var o: Vector2 = offs[i]
		out.append(["cap", Vector3(0.11, 0.5, 0), Vector3(o.x, 0.27, o.y), Vector3.ZERO, "gunmetal"])
		out.append(["sph", Vector3(0.1, 0, 0), Vector3(o.x, 0.56, o.y), Vector3.ZERO, "team"])
		if tube:
			out.append(["cyl", Vector3(0.05, 0.5, 8), Vector3(o.x + 0.1, 0.5, o.y), Vector3(90, 0, 0), "gold"])
		else:
			out.append(["box", Vector3(0.05, 0.05, 0.36), Vector3(o.x + 0.1, 0.34, o.y + 0.12), Vector3.ZERO, "tread"])
	return out

var UNITS := {
	"crawler": [
		["box", Vector3(0.22, 0.26, 1.05), Vector3(-0.38, 0.13, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.22, 0.26, 1.05), Vector3(0.38, 0.13, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.62, 0.34, 0.9), Vector3(0, 0.36, -0.05), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.4, 0.3, 0.34), Vector3(0, 0.66, -0.22), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(1.0, 0.32, 0.1), Vector3(0, 0.22, 0.6), Vector3(-12, 0, 0), "gold"],
		["box", Vector3(0.08, 0.08, 0.9), Vector3(0.18, 0.85, 0.05), Vector3(28, 0, 0), "gold"],
		["box", Vector3(0.64, 0.07, 0.22), Vector3(0, 0.55, 0.22), Vector3.ZERO, "team"],
	],
	"harvester": [
		["box", Vector3(0.26, 0.3, 1.35), Vector3(-0.44, 0.15, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.26, 0.3, 1.35), Vector3(0.44, 0.15, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.74, 0.42, 1.25), Vector3(0, 0.42, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.7, 0.42, 0.62), Vector3(0, 0.82, -0.25), Vector3.ZERO, "gold"],
		["box", Vector3(0.5, 0.1, 0.4), Vector3(0, 1.08, -0.25), Vector3.ZERO, "crystal"],
		["box", Vector3(0.42, 0.3, 0.3), Vector3(0, 0.78, 0.38), Vector3.ZERO, "gunmetal_dark"],
		["cyl", Vector3(0.11, 0.14, 8), Vector3(0, 1.0, 0.38), Vector3.ZERO, "gunmetal", "turret"],
		["cyl", Vector3(0.03, 0.35, 6), Vector3(0, 1.02, 0.56), Vector3(90, 0, 0), "tread", "turret"],
		["box", Vector3(0.76, 0.08, 0.2), Vector3(0, 0.66, 0.1), Vector3.ZERO, "team"],
	],
	"grenadier": [],
	"lancer": [],
	"wolfhound": [
		["cyl", Vector3(0.17, 0.14, 10), Vector3(-0.38, 0.17, -0.42), Vector3(0, 0, 90), "tread"],
		["cyl", Vector3(0.17, 0.14, 10), Vector3(0.38, 0.17, -0.42), Vector3(0, 0, 90), "tread"],
		["cyl", Vector3(0.17, 0.14, 10), Vector3(-0.38, 0.17, 0), Vector3(0, 0, 90), "tread"],
		["cyl", Vector3(0.17, 0.14, 10), Vector3(0.38, 0.17, 0), Vector3(0, 0, 90), "tread"],
		["cyl", Vector3(0.17, 0.14, 10), Vector3(-0.38, 0.17, 0.42), Vector3(0, 0, 90), "tread"],
		["cyl", Vector3(0.17, 0.14, 10), Vector3(0.38, 0.17, 0.42), Vector3(0, 0, 90), "tread"],
		["box", Vector3(0.64, 0.34, 1.15), Vector3(0, 0.38, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.56, 0.18, 0.4), Vector3(0, 0.5, 0.42), Vector3(18, 0, 0), "gunmetal_dark"],
		["box", Vector3(0.66, 0.07, 0.22), Vector3(0, 0.56, -0.3), Vector3.ZERO, "team"],
		["box", Vector3(0.36, 0.18, 0.38), Vector3(0, 0.64, -0.02), Vector3.ZERO, "gold", "turret"],
		["cyl", Vector3(0.04, 0.6, 8), Vector3(0, 0.66, 0.42), Vector3(90, 0, 0), "tread", "turret"],
	],
	"leopold": [
		["box", Vector3(0.3, 0.32, 1.45), Vector3(-0.46, 0.16, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.3, 0.32, 1.45), Vector3(0.46, 0.16, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.78, 0.32, 1.32), Vector3(0, 0.4, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.62, 0.26, 0.62), Vector3(0, 0.68, -0.08), Vector3.ZERO, "gunmetal_dark", "turret"],
		["box", Vector3(0.64, 0.08, 0.3), Vector3(0, 0.84, -0.2), Vector3.ZERO, "team", "turret"],
		["cyl", Vector3(0.065, 1.05, 10), Vector3(0, 0.7, 0.68), Vector3(90, 0, 0), "gunmetal", "turret"],
		["cyl", Vector3(0.1, 0.14, 10), Vector3(0, 0.7, 1.18), Vector3(90, 0, 0), "gold", "turret"],
		["cyl", Vector3(0.09, 0.08, 8), Vector3(0.14, 0.86, -0.2), Vector3.ZERO, "gold", "turret"],
	],
	"aegis": [
		["box", Vector3(0.26, 0.28, 1.2), Vector3(-0.4, 0.14, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.26, 0.28, 1.2), Vector3(0.4, 0.14, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.7, 0.4, 1.15), Vector3(0, 0.4, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.72, 0.08, 0.22), Vector3(0, 0.64, 0.35), Vector3.ZERO, "team"],
		["cyl", Vector3(0.05, 1.0, 6), Vector3(0, 1.1, -0.2), Vector3.ZERO, "gold"],
		["cyl", Vector3(0.36, 0.1, 6), Vector3(0, 1.62, -0.2), Vector3.ZERO, "cyan"],
		["cyl", Vector3(0.22, 0.18, 6), Vector3(0, 0.7, -0.2), Vector3.ZERO, "cyan"],
	],
	"flakwerk": [
		["box", Vector3(0.26, 0.28, 1.2), Vector3(-0.4, 0.14, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.26, 0.28, 1.2), Vector3(0.4, 0.14, 0), Vector3.ZERO, "tread"],
		["box", Vector3(0.7, 0.34, 1.15), Vector3(0, 0.38, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.72, 0.08, 0.22), Vector3(0, 0.58, -0.38), Vector3.ZERO, "team"],
		["box", Vector3(0.5, 0.28, 0.46), Vector3(0, 0.7, 0.05), Vector3.ZERO, "gold", "turret"],
		["cyl", Vector3(0.04, 0.75, 8), Vector3(-0.12, 1.05, 0.3), Vector3(40, 0, 0), "tread", "turret"],
		["cyl", Vector3(0.04, 0.75, 8), Vector3(0.12, 1.05, 0.3), Vector3(40, 0, 0), "tread", "turret"],
	],
}

var BUILDINGS := {
	"hq": {"fp": Vector2(4, 4), "path": "res://view/buildings/eu/hq.tscn", "parts": [
		["box", Vector3(3.9, 0.22, 3.9), Vector3(0, 0.11, 0), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(3.0, 1.1, 2.4), Vector3(0, 0.76, -0.4), Vector3.ZERO, "gunmetal"],
		["box", Vector3(1.1, 1.6, 1.1), Vector3(-1.0, 1.0, -0.8), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(1.2, 0.12, 1.2), Vector3(-1.0, 1.86, -0.8), Vector3.ZERO, "gold"],
		["sph", Vector3(0.55, 0, 0), Vector3(0.7, 1.35, -0.6), Vector3.ZERO, "cyan"],
		["cyl", Vector3(0.05, 1.6, 6), Vector3(1.4, 2.0, -1.4), Vector3.ZERO, "gold"],
		["cyl", Vector3(0.05, 1.2, 6), Vector3(-1.5, 2.3, -1.5), Vector3.ZERO, "gold"],
		["box", Vector3(3.05, 0.16, 0.4), Vector3(0, 1.1, 0.82), Vector3.ZERO, "team"],
		["box", Vector3(0.5, 0.35, 0.05), Vector3(1.4, 2.55, -1.4), Vector3.ZERO, "team"],
		["box", Vector3(1.4, 0.06, 1.0), Vector3(0, 0.25, 1.35), Vector3.ZERO, "gold"],
	]},
	"reactor": {"fp": Vector2(3, 3), "path": "res://view/buildings/eu/reactor.tscn", "parts": [
		["box", Vector3(2.9, 0.2, 2.9), Vector3(0, 0.1, 0), Vector3.ZERO, "gunmetal_dark"],
		["cyl", Vector3(0.95, 1.2, 12), Vector3(-0.2, 0.8, -0.2), Vector3.ZERO, "gunmetal"],
		["cyl", Vector3(1.0, 0.16, 12), Vector3(-0.2, 1.2, -0.2), Vector3.ZERO, "cyan"],
		["cone", Vector3(0.5, 1.4, 0.32), Vector3(0.85, 0.9, 0.85), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(0.9, 0.12, 0.3), Vector3(-0.2, 1.46, -0.2), Vector3.ZERO, "team"],
		["sph", Vector3(0.35, 0, 0), Vector3(-0.2, 1.5, -0.2), Vector3.ZERO, "cyan"],
	]},
	"pylon": {"fp": Vector2(1, 1), "path": "res://view/buildings/eu/pylon.tscn", "parts": [
		["box", Vector3(0.8, 0.14, 0.8), Vector3(0, 0.07, 0), Vector3.ZERO, "gunmetal_dark"],
		["cyl", Vector3(0.08, 1.9, 6), Vector3(0, 1.05, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(0.8, 0.06, 0.06), Vector3(0, 1.6, 0), Vector3.ZERO, "gold"],
		["sph", Vector3(0.2, 0, 0), Vector3(0, 2.1, 0), Vector3.ZERO, "cyan"],
		["box", Vector3(0.3, 0.2, 0.04), Vector3(0, 1.25, 0.1), Vector3.ZERO, "team"],
	]},
	"hub": {"fp": Vector2(3, 3), "path": "res://view/buildings/eu/hub.tscn", "parts": [
		["box", Vector3(2.9, 0.2, 2.9), Vector3(0, 0.1, 0), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(2.4, 0.8, 1.3), Vector3(0, 0.6, -0.6), Vector3.ZERO, "gunmetal"],
		["cyl", Vector3(0.45, 1.5, 10), Vector3(-0.8, 1.0, -0.6), Vector3.ZERO, "gold"],
		["cyl", Vector3(0.45, 1.5, 10), Vector3(0.2, 1.0, -0.6), Vector3.ZERO, "gold"],
		["box", Vector3(0.5, 0.1, 0.5), Vector3(0.95, 1.05, -0.6), Vector3.ZERO, "crystal"],
		["box", Vector3(2.2, 0.06, 1.0), Vector3(0, 0.23, 0.85), Vector3.ZERO, "team"],
		["box", Vector3(0.2, 0.9, 0.2), Vector3(1.2, 0.6, 0.9), Vector3.ZERO, "gold"],
	]},
	"barracks": {"fp": Vector2(3, 3), "path": "res://view/buildings/eu/barracks.tscn", "parts": [
		["box", Vector3(2.9, 0.2, 2.9), Vector3(0, 0.1, 0), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(2.6, 0.8, 1.9), Vector3(0, 0.6, -0.2), Vector3.ZERO, "gunmetal"],
		["box", Vector3(2.7, 0.2, 1.0), Vector3(0, 1.08, -0.2), Vector3(0, 0, 0), "gunmetal_dark"],
		["box", Vector3(0.8, 0.55, 0.06), Vector3(0, 0.48, 0.76), Vector3.ZERO, "window"],
		["box", Vector3(2.62, 0.12, 0.3), Vector3(0, 0.9, 0.62), Vector3.ZERO, "team"],
		["cyl", Vector3(0.04, 1.4, 6), Vector3(1.2, 1.0, 1.1), Vector3.ZERO, "gold"],
		["box", Vector3(0.5, 0.32, 0.04), Vector3(1.0, 1.5, 1.1), Vector3.ZERO, "team"],
	]},
	"motor_pool": {"fp": Vector2(4, 4), "path": "res://view/buildings/eu/motor_pool.tscn", "parts": [
		["box", Vector3(3.9, 0.2, 3.9), Vector3(0, 0.1, 0), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(3.3, 1.1, 2.6), Vector3(0, 0.75, -0.4), Vector3.ZERO, "gunmetal"],
		["box", Vector3(1.6, 0.8, 0.06), Vector3(0, 0.6, 0.92), Vector3.ZERO, "window"],
		["box", Vector3(3.35, 0.16, 0.3), Vector3(0, 1.2, 0.8), Vector3.ZERO, "team"],
		["box", Vector3(0.14, 1.8, 0.14), Vector3(1.6, 0.9, 1.4), Vector3.ZERO, "gold"],
		["box", Vector3(1.4, 0.12, 0.12), Vector3(1.0, 1.8, 1.4), Vector3.ZERO, "gold"],
		["box", Vector3(1.6, 0.05, 1.2), Vector3(0, 0.23, 1.4), Vector3.ZERO, "gold"],
	]},
	"heavy_factory": {"fp": Vector2(4, 4), "path": "res://view/buildings/eu/heavy_factory.tscn", "parts": [
		["box", Vector3(3.9, 0.2, 3.9), Vector3(0, 0.1, 0), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(3.5, 1.6, 3.0), Vector3(0, 1.0, -0.3), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(3.6, 0.2, 0.3), Vector3(0, 1.75, 1.0), Vector3.ZERO, "gold"],
		["box", Vector3(1.8, 1.1, 0.06), Vector3(0, 0.75, 1.22), Vector3.ZERO, "window"],
		["cyl", Vector3(0.22, 1.4, 8), Vector3(-1.2, 2.4, -1.2), Vector3.ZERO, "gunmetal"],
		["cyl", Vector3(0.22, 1.1, 8), Vector3(-0.6, 2.25, -1.2), Vector3.ZERO, "gunmetal"],
		["box", Vector3(3.52, 0.2, 0.35), Vector3(0, 1.5, -1.6), Vector3.ZERO, "team"],
		["box", Vector3(0.8, 0.5, 0.8), Vector3(1.1, 2.05, -0.6), Vector3.ZERO, "gold"],
	]},
	"gun_bunker": {"fp": Vector2(2, 2), "path": "res://view/buildings/eu/gun_bunker.tscn", "parts": [
		["box", Vector3(1.9, 0.5, 1.9), Vector3(0, 0.25, 0), Vector3.ZERO, "gunmetal_dark"],
		["box", Vector3(1.5, 0.35, 1.5), Vector3(0, 0.6, 0), Vector3.ZERO, "gunmetal"],
		["box", Vector3(1.52, 0.08, 0.3), Vector3(0, 0.82, -0.5), Vector3.ZERO, "team"],
		["cyl", Vector3(0.38, 0.3, 8), Vector3(0, 0.95, 0), Vector3.ZERO, "gold", "turret"],
		["cyl", Vector3(0.06, 0.9, 8), Vector3(-0.1, 1.0, 0.5), Vector3(90, 0, 0), "tread", "turret"],
		["cyl", Vector3(0.06, 0.9, 8), Vector3(0.1, 1.0, 0.5), Vector3(90, 0, 0), "tread", "turret"],
	]},
	"civ_block": {"fp": Vector2(3, 3), "path": "res://view/buildings/neutral/civ_block.tscn", "parts": [
		["box", Vector3(2.7, 1.8, 2.5), Vector3(0, 0.9, 0), Vector3.ZERO, "concrete"],
		["box", Vector3(2.72, 0.22, 2.3), Vector3(0, 0.55, 0), Vector3.ZERO, "window"],
		["box", Vector3(2.72, 0.22, 2.3), Vector3(0, 1.2, 0), Vector3.ZERO, "window"],
		["box", Vector3(2.4, 0.2, 2.52), Vector3(0, 0.55, 0), Vector3.ZERO, "window"],
		["box", Vector3(2.4, 0.2, 2.52), Vector3(0, 1.2, 0), Vector3.ZERO, "window"],
		["box", Vector3(0.8, 0.4, 0.8), Vector3(0.6, 2.0, -0.5), Vector3.ZERO, "rust"],
		["box", Vector3(0.5, 0.3, 0.06), Vector3(-0.9, 1.95, 1.0), Vector3.ZERO, "team"],
	]},
	"pump": {"fp": Vector2(2, 2), "path": "res://view/buildings/neutral/pump.tscn", "parts": [
		["box", Vector3(1.9, 0.18, 1.9), Vector3(0, 0.09, 0), Vector3.ZERO, "rust"],
		["box", Vector3(0.12, 1.8, 0.12), Vector3(-0.5, 1.0, -0.5), Vector3(0, 0, 8), "rust"],
		["box", Vector3(0.12, 1.8, 0.12), Vector3(0.5, 1.0, -0.5), Vector3(0, 0, -8), "rust"],
		["box", Vector3(1.2, 0.12, 0.12), Vector3(0, 1.85, -0.5), Vector3.ZERO, "rust"],
		["cyl", Vector3(0.4, 0.7, 10), Vector3(0.3, 0.5, 0.45), Vector3.ZERO, "crystal"],
		["box", Vector3(0.9, 0.12, 0.12), Vector3(-0.1, 1.4, 0.0), Vector3(0, 0, 18), "gunmetal"],
		["box", Vector3(0.5, 0.3, 0.05), Vector3(-0.5, 0.5, 0.6), Vector3.ZERO, "team"],
	]},
}

var PROPS := {
	"seam": [
		["cyl", Vector3(1.3, 0.04, 10), Vector3(0, 0.02, 0), Vector3.ZERO, "tread"],
		["cone", Vector3(0.22, 0.9, 0.02), Vector3(-0.4, 0.45, -0.2), Vector3(10, 0, 8), "crystal"],
		["cone", Vector3(0.18, 0.7, 0.02), Vector3(0.35, 0.35, -0.35), Vector3(-8, 0, -10), "crystal"],
		["cone", Vector3(0.25, 1.1, 0.02), Vector3(0.05, 0.55, 0.3), Vector3(0, 0, 4), "crystal"],
		["cone", Vector3(0.16, 0.6, 0.02), Vector3(0.6, 0.3, 0.4), Vector3(12, 0, -14), "crystal"],
		["cone", Vector3(0.15, 0.55, 0.02), Vector3(-0.7, 0.27, 0.45), Vector3(-10, 0, 12), "crystal"],
	],
	"cache": [
		["box", Vector3(0.5, 0.4, 0.5), Vector3(-0.3, 0.2, 0), Vector3.ZERO, "crate"],
		["box", Vector3(0.5, 0.4, 0.5), Vector3(0.3, 0.2, 0.1), Vector3(0, 15, 0), "crate"],
		["box", Vector3(0.5, 0.4, 0.5), Vector3(0, 0.6, 0.05), Vector3(0, -10, 0), "crate"],
		["box", Vector3(0.3, 0.1, 0.3), Vector3(0, 0.85, 0.05), Vector3.ZERO, "crystal"],
	],
}

