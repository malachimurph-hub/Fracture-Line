extends SceneTree
## Generates the view wrapper scenes (ORIGINAL procedural low-poly art, M1.2 art pass) and
## shared materials. Parts are merged into one multi-surface ArrayMesh per node (body /
## turret) to keep draw calls low: surfaces are base (vertex colour), concrete and
## corrugated metal (vertex colour x CC0 triplanar texture), glow (emissive) and team.
## Run: godot --headless --path . -s tools/gen_views.gd

const M := "res://view/materials/"
const SURF := ["base", "concrete", "metal", "glow", "team"]
## key -> [surface, colour]   (Zero Hour-like semi-realistic palette; EU = blue-grey steel,
## sand-gold trim, cyan Grid glow)
const C := {
	"steel": ["base", "#6d747a"], "steel_dark": ["base", "#4a5056"], "steel_light": ["base", "#8d949a"],
	"olive": ["base", "#5f6648"], "trim": ["base", "#c49a46"], "hazard": ["base", "#d8a531"],
	"tread": ["base", "#2a2b2c"], "wheel": ["base", "#222324"], "rubber": ["base", "#1b1b1c"],
	"skin": ["base", "#c79a76"], "uniform": ["base", "#596049"], "vest": ["base", "#3f4535"],
	"gun": ["base", "#2c2e30"], "glass": ["base", "#2c3a48"], "window": ["base", "#27313b"],
	"wood": ["base", "#8a6a43"], "crate": ["base", "#8b6d3f"], "rust": ["base", "#7b5638"],
	"sand": ["base", "#b8a37a"], "sand_dark": ["base", "#a38d64"], "paint_y": ["base", "#e0c045"],
	"paint_w": ["base", "#e4e0d6"], "black": ["base", "#151617"], "barrel": ["base", "#4d6a3a"],
	"red": ["base", "#a6382a"], "fence": ["base", "#7f8489"], "roof": ["base", "#77746c"],
	"concrete": ["concrete", "#cfc7b6"], "concrete_dark": ["concrete", "#a59d8d"], "plaster": ["concrete", "#d8c9a8"],
	"plaster2": ["concrete", "#c9b08a"], "corr": ["metal", "#a9adb1"], "corr_dark": ["metal", "#7d8287"],
	"corr_green": ["metal", "#6e7a5e"], "corr_rust": ["metal", "#9a6a48"],
	"cyan": ["glow", "#6fe3ff"], "lamp": ["glow", "#ffd27a"], "crystal": ["glow", "#5ce0a0"],
	"team": ["team", "#ffffff"],
	# TPLA: desert camo, mismatched scrap panels, canvas tarps, acid-green "rust" agent glow
	"tan": ["base", "#c2a476"], "khaki": ["base", "#a58f63"], "camo_brown": ["base", "#7d6646"],
	"camo_olive": ["base", "#6b6a45"], "scrap_blue": ["base", "#5d6f7a"], "scrap_green": ["base", "#5f6b4a"],
	"scrap_red": ["base", "#8a4a34"], "tarp": ["base", "#8a8064"], "tarp_blue": ["base", "#4f6170"],
	"cloth": ["base", "#b9a888"], "bone": ["base", "#d8cfb8"], "rust_dark": ["base", "#5e3a26"],
	"dirt": ["base", "#8a7356"], "mud": ["concrete", "#b49a74"], "mud_dark": ["concrete", "#9a8160"],
	"plank": ["base", "#7a5d3c"], "tire": ["base", "#1e1d1c"], "net": ["base", "#7b7a52"],
	"acid": ["glow", "#b6e04a"], "fire": ["glow", "#ff9a3a"],
}
var mats := {}

func _init() -> void:
	_make_mats()
	_defs()
	UNITS["grenadier"] = _squad(4, false)
	UNITS["lancer"] = _squad(3, true)
	for id in UNITS:
		_save(UNITS[id], "res://view/units/eu/%s.tscn" % id, false, Vector2.ONE)
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		_save(b["parts"], b["path"], true, b["fp"])
	for id in PROPS:
		_save(PROPS[id], "res://view/neutral/%s.tscn" % id, false, Vector2.ONE)
	_tpla_defs()
	for id in TP_UNITS:
		_save(TP_UNITS[id], "res://view/units/tpla/%s.tscn" % id, false, Vector2.ONE)
	for id in TP_BUILDINGS:
		var tb: Dictionary = TP_BUILDINGS[id]
		_save(tb["parts"], "res://view/buildings/tpla/%s.tscn" % id, true, tb["fp"])
	print("views generated")
	quit()

func _std(name: String, tex: String = "", emit: float = 0.0, rough: float = 0.75, metal: float = 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic = metal
	if tex != "":
		m.albedo_texture = load(tex)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3(0.6, 0.6, 0.6)
		m.albedo_color = Color(1.25, 1.25, 1.25)
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_energy_multiplier = emit
		m.emission_on_uv2 = false
	ResourceSaver.save(m, M + name + ".tres")
	mats[name] = load(M + name + ".tres")

func _make_mats() -> void:
	DirAccess.make_dir_recursive_absolute("res://view/materials")
	_std("base", "", 0.0, 0.72, 0.15)
	_std("concrete", "res://assets/textures/materials/concrete.png", 0.0, 0.95)
	_std("metal", "res://assets/textures/materials/corrugated.png", 0.0, 0.6, 0.35)
	_std("glow", "", 1.8, 0.3)
	var t := StandardMaterial3D.new()
	t.albedo_color = Color.WHITE
	t.roughness = 0.5
	ResourceSaver.save(t, M + "team.tres")
	mats["team"] = load(M + "team.tres")

# part: [shape, size(Vector3), pos(Vector3), rot_deg(Vector3), colour key, parent]
# shapes: box (size), cyl (x=radius, y=height, z=sides), cone (x=bottom r, y=h, z=top r),
# sph (x,y,z radii; y/z 0 = round), cap (x=radius, y=height), wedge (prism, size)
func _prim(shape: String, s: Vector3) -> PrimitiveMesh:
	match shape:
		"box":
			var b := BoxMesh.new(); b.size = s; return b
		"cyl":
			var c := CylinderMesh.new(); c.top_radius = s.x; c.bottom_radius = s.x; c.height = s.y
			c.radial_segments = int(s.z) if s.z > 0 else 10; c.rings = 1; return c
		"cone":
			var k := CylinderMesh.new(); k.top_radius = s.z; k.bottom_radius = s.x; k.height = s.y; k.radial_segments = 10; k.rings = 1; return k
		"sph":
			var p := SphereMesh.new(); p.radius = 1.0; p.height = 2.0; p.radial_segments = 10; p.rings = 5; return p
		"hsph":
			var h := SphereMesh.new(); h.radius = 1.0; h.height = 1.0; h.is_hemisphere = true; h.radial_segments = 12; h.rings = 4; return h
		"cap":
			var q := CapsuleMesh.new(); q.radius = s.x; q.height = s.y; q.radial_segments = 8; q.rings = 2; return q
		"wedge":
			var w := PrismMesh.new(); w.size = s; return w
	var bb := BoxMesh.new(); bb.size = s; return bb

func _merge(parts: Array) -> Dictionary:
	## returns {mesh, top, extent, team_surface}
	var sts := {}
	var top := 0.0
	var extent := 0.3
	for p in parts:
		var key: String = p[4]
		var info: Array = C[key]
		var surf: String = info[0]
		if not sts.has(surf):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[surf] = st
		var shape: String = p[0]
		var s: Vector3 = p[1]
		var basis := Basis.from_euler(p[3] * PI / 180.0)
		if shape == "sph" or shape == "hsph":
			basis = basis * Basis().scaled(Vector3(s.x, s.y if s.y > 0 else s.x, s.z if s.z > 0 else s.x))
		var col := Color(info[1])
		if p.size() > 6:
			col = col * Color(p[6], p[6], p[6])
		PropMeshes.add_prim(sts[surf], _prim(shape, s), Transform3D(basis, p[2]), col)
		var hy: float = (s.y if s.y > 0 else s.x) if shape in ["sph", "hsph"] else s.y * 0.5
		top = maxf(top, p[2].y + hy)
		extent = maxf(extent, maxf(absf(p[2].x) + s.x * 0.5, absf(p[2].z) + s.z * 0.5))
	var mesh := ArrayMesh.new()
	var team_surface := -1
	for name in SURF:
		if not sts.has(name):
			continue
		var st: SurfaceTool = sts[name]
		st.index()
		st.commit(mesh)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_material(idx, mats[name])
		mesh.surface_set_name(idx, name)
		if name == "team":
			team_surface = idx
	return {"mesh": mesh, "top": top, "extent": extent, "team": team_surface}

func _save(parts: Array, path: String, structure: bool, fp: Vector2) -> void:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/wrappers/entity_view.gd"))
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	# groups: "" body, "turret", "tier1".."tier3" (salvage bolt-ons, hidden until earned),
	# "turret:tier2" (bolt-on riding the turret)
	var groups := {}
	for p in parts:
		var g: String = p[5] if p.size() > 5 else ""
		if not groups.has(g):
			groups[g] = []
		groups[g].append(p)
	var top := 0.0
	var extent := 0.3
	var order := [["", "Body"], ["turret", "Turret"], ["tier1", "Tier1"], ["tier2", "Tier2"], ["tier3", "Tier3"],
		["turret:tier1", "TurretTier1"], ["turret:tier2", "TurretTier2"], ["turret:tier3", "TurretTier3"]]
	var pivot: Node3D = null
	for grp0 in order:
		if not groups.has(grp0[0]):
			continue
		var grp := [groups[grp0[0]], grp0[1]]
		var r := _merge(grp[0])
		if grp[1] in ["Body", "Turret"]:
			top = maxf(top, r["top"])
			extent = maxf(extent, r["extent"])
		var mi := MeshInstance3D.new()
		mi.name = grp[1]
		mi.mesh = r["mesh"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if r["team"] >= 0:
			mi.set_meta("team_surface", r["team"])
		var parent: Node3D = model
		if grp[1].begins_with("Turret"):
			if pivot == null:
				pivot = Node3D.new()
				pivot.name = "TurretPivot"
				model.add_child(pivot)
				pivot.owner = root
			parent = pivot
		if grp[1].contains("Tier"):
			mi.visible = false
			mi.set_meta("tier", int(grp[1].right(1)))
		parent.add_child(mi)
		mi.owner = root
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

# ---------------------------------------------------------------- part helpers
static func P(shape: String, s: Vector3, pos: Vector3, key: String, rot: Vector3 = Vector3.ZERO, parent: String = "", shade: float = 1.0) -> Array:
	if shade != 1.0:
		return [shape, s, pos, rot, key, parent, shade]
	return [shape, s, pos, rot, key, parent]

static func T(shape: String, s: Vector3, pos: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> Array:
	return [shape, s, pos, rot, key, "turret"]

## Track assembly: belt, road wheels, sprocket, mud guard.
static func tracks(x: float, length: float, h: float, w: float, wheels: int) -> Array:
	var o: Array = []
	for sx in [-x, x]:
		o.append(P("box", Vector3(w, h, length), Vector3(sx, h * 0.5, 0), "tread"))
		for i in wheels:
			var z := lerpf(-length * 0.5 + h * 0.5, length * 0.5 - h * 0.5, float(i) / float(maxi(1, wheels - 1)))
			o.append(P("cyl", Vector3(h * 0.38, w + 0.04, 10), Vector3(sx, h * 0.42, z), "wheel", Vector3(0, 0, 90)))
		o.append(P("box", Vector3(w + 0.06, 0.04, length + 0.06), Vector3(sx, h + 0.02, 0), "steel_dark"))
	return o

## Wheels for a wheeled vehicle at the given z positions.
static func wheels(x: float, zs: Array, r: float, w: float) -> Array:
	var o: Array = []
	for z in zs:
		for sx in [-x, x]:
			o.append(P("cyl", Vector3(r, w, 12), Vector3(sx, r, z), "rubber", Vector3(0, 0, 90)))
			o.append(P("cyl", Vector3(r * 0.5, w + 0.02, 8), Vector3(sx, r, z), "steel_dark", Vector3(0, 0, 90)))
	return o

## Sandbag wall from a to b (xz), one or two courses.
static func sandbags(a: Vector2, b: Vector2, courses: int = 2) -> Array:
	var o: Array = []
	var d := b - a
	var n := maxi(1, int(d.length() / 0.32))
	var ang := -rad_to_deg(atan2(d.y, d.x))
	for c in courses:
		for i in n:
			var t := (float(i) + (0.5 if c % 2 == 0 else 0.0)) / float(n)
			if t > 1.0:
				continue
			var p := a + d * t
			o.append(P("sph", Vector3(0.17, 0.075, 0.1), Vector3(p.x, 0.08 + c * 0.13, p.y), "sand" if (i + c) % 3 else "sand_dark", Vector3(0, ang, 0)))
	return o

## Chain-link fence: posts + rails + mesh panel.
static func fence(a: Vector2, b: Vector2, h: float = 0.55) -> Array:
	var o: Array = []
	var d := b - a
	var n := maxi(1, int(d.length() / 0.8))
	var ang := -rad_to_deg(atan2(d.y, d.x))
	for i in n + 1:
		var p := a + d * (float(i) / float(n))
		o.append(P("box", Vector3(0.04, h, 0.04), Vector3(p.x, h * 0.5, p.y), "fence"))
	var m := (a + b) * 0.5
	o.append(P("box", Vector3(d.length(), 0.025, 0.025), Vector3(m.x, h, m.y), "fence", Vector3(0, ang, 0)))
	o.append(P("box", Vector3(d.length(), h * 0.85, 0.01), Vector3(m.x, h * 0.48, m.y), "fence", Vector3(0, ang, 0), "", 0.75))
	return o

## Concrete foundation pad with painted edge lines.
static func pad(fp: Vector2, h: float = 0.12) -> Array:
	var sx := fp.x - 0.1
	var sz := fp.y - 0.1
	return [
		P("box", Vector3(sx, h, sz), Vector3(0, h * 0.5, 0), "concrete_dark"),
		P("box", Vector3(sx - 0.2, 0.01, 0.06), Vector3(0, h + 0.005, sz * 0.5 - 0.15), "paint_y"),
		P("box", Vector3(sx - 0.2, 0.01, 0.06), Vector3(0, h + 0.005, -sz * 0.5 + 0.15), "paint_y"),
	]

static func crates(c: Vector3, n: int, sz: float = 0.32) -> Array:
	var o: Array = []
	var offs := [Vector3(0, 0, 0), Vector3(1.05, 0, 0.1), Vector3(0.1, 0, 1.05), Vector3(0.55, 1, 0.5), Vector3(1.0, 0, 1.1), Vector3(-1.0, 0, 0.2)]
	for i in n:
		var o3: Vector3 = offs[i % offs.size()]
		o.append(P("box", Vector3(sz, sz * 0.8, sz), c + Vector3(o3.x * sz, sz * 0.4 + o3.y * sz * 0.8, o3.z * sz), "crate", Vector3(0, (i * 23) % 40 - 20, 0), "", 1.0 - 0.07 * (i % 3)))
	return o

static func barrels(c: Vector3, n: int) -> Array:
	var o: Array = []
	for i in n:
		o.append(P("cyl", Vector3(0.09, 0.26, 8), c + Vector3((i % 3) * 0.2, 0.13, (i / 3) * 0.2), "barrel" if i % 2 == 0 else "rust"))
	return o

static func flag(pos: Vector3, h: float) -> Array:
	return [
		P("cyl", Vector3(0.025, h, 6), pos + Vector3(0, h * 0.5, 0), "steel_light"),
		P("box", Vector3(0.36, 0.22, 0.02), pos + Vector3(0.19, h - 0.14, 0), "team"),
	]

func _squad(n: int, tube: bool) -> Array:
	var out: Array = []
	var offs := [Vector2(-0.22, -0.18), Vector2(0.22, -0.16), Vector2(-0.18, 0.22), Vector2(0.2, 0.2), Vector2(0, 0)]
	for i in n:
		var o: Vector2 = offs[i]
		var x := o.x
		var z := o.y
		out.append(P("box", Vector3(0.05, 0.22, 0.06), Vector3(x - 0.035, 0.11, z), "uniform", Vector3(8 if i % 2 else -8, 0, 0)))
		out.append(P("box", Vector3(0.05, 0.22, 0.06), Vector3(x + 0.035, 0.11, z), "uniform", Vector3(-8 if i % 2 else 8, 0, 0)))
		out.append(P("box", Vector3(0.15, 0.2, 0.09), Vector3(x, 0.32, z), "vest"))
		out.append(P("box", Vector3(0.155, 0.05, 0.095), Vector3(x, 0.38, z), "team"))
		out.append(P("box", Vector3(0.1, 0.12, 0.06), Vector3(x, 0.32, z - 0.07), "olive"))
		out.append(P("sph", Vector3(0.05, 0, 0), Vector3(x, 0.47, z), "skin"))
		out.append(P("hsph", Vector3(0.062, 0.05, 0.062), Vector3(x, 0.48, z), "olive"))
		out.append(P("box", Vector3(0.04, 0.16, 0.05), Vector3(x - 0.09, 0.31, z + 0.03), "uniform", Vector3(-30, 0, 0)))
		out.append(P("box", Vector3(0.04, 0.16, 0.05), Vector3(x + 0.09, 0.31, z + 0.03), "uniform", Vector3(-30, 0, 0)))
		if tube:
			out.append(P("cyl", Vector3(0.035, 0.42, 8), Vector3(x + 0.08, 0.43, z + 0.02), "olive", Vector3(90, 0, 0)))
			out.append(P("cone", Vector3(0.05, 0.08, 0.035), Vector3(x + 0.08, 0.43, z + 0.26), "steel_dark", Vector3(90, 0, 0)))
		else:
			out.append(P("box", Vector3(0.03, 0.04, 0.3), Vector3(x + 0.05, 0.3, z + 0.12), "gun", Vector3(-10, 0, 0)))
	return out

var UNITS := {}
var BUILDINGS := {}
var PROPS := {}

func _defs() -> void:
	# ---------------- units (+z = front) ----------------
	UNITS["crawler"] = tracks(0.36, 1.0, 0.26, 0.2, 4) + [
		P("box", Vector3(0.52, 0.28, 0.8), Vector3(0, 0.36, -0.08), "steel"),
		P("box", Vector3(0.38, 0.3, 0.36), Vector3(-0.04, 0.64, -0.2), "steel_light"),
		P("box", Vector3(0.39, 0.12, 0.3), Vector3(-0.04, 0.7, -0.18), "glass"),
		P("box", Vector3(0.42, 0.04, 0.4), Vector3(-0.04, 0.81, -0.2), "steel_dark"),
		P("box", Vector3(0.96, 0.3, 0.08), Vector3(0, 0.22, 0.62), "hazard", Vector3(-14, 0, 0)),
		P("box", Vector3(0.96, 0.05, 0.1), Vector3(0, 0.08, 0.66), "steel_dark"),
		P("box", Vector3(0.06, 0.06, 0.5), Vector3(-0.3, 0.32, 0.38), "steel_dark", Vector3(-12, 0, 0)),
		P("box", Vector3(0.06, 0.06, 0.5), Vector3(0.3, 0.32, 0.38), "steel_dark", Vector3(-12, 0, 0)),
		P("cyl", Vector3(0.035, 0.3, 6), Vector3(0.2, 0.68, -0.35), "black"),
		P("box", Vector3(0.53, 0.07, 0.2), Vector3(0, 0.52, 0.2), "team"),
		P("box", Vector3(0.18, 0.12, 0.05), Vector3(0.18, 0.86, -0.2), "lamp"),
	]
	UNITS["harvester"] = wheels(0.38, [0.45, -0.1, -0.45], 0.16, 0.13) + [
		P("box", Vector3(0.66, 0.18, 1.35), Vector3(0, 0.3, 0), "steel_dark"),
		P("box", Vector3(0.64, 0.42, 0.42), Vector3(0, 0.56, 0.42), "steel"),
		P("box", Vector3(0.6, 0.16, 0.05), Vector3(0, 0.66, 0.64), "glass"),
		P("box", Vector3(0.66, 0.05, 0.44), Vector3(0, 0.79, 0.42), "steel_dark"),
		P("box", Vector3(0.66, 0.3, 0.82), Vector3(0, 0.53, -0.22), "olive"),
		P("box", Vector3(0.68, 0.07, 0.84), Vector3(0, 0.45, -0.22), "team"),
	] + crates(Vector3(-0.2, 0.68, -0.45), 4, 0.2) + [
		P("box", Vector3(0.14, 0.1, 0.1), Vector3(0.22, 0.82, 0.42), "lamp"),
		T("cyl", Vector3(0.07, 0.12, 8), Vector3(0.22, 0.76, -0.05), "steel_dark"),
		T("box", Vector3(0.05, 0.05, 0.5), Vector3(0.22, 0.9, -0.2), "hazard", Vector3(-25, 0, 0)),
	]
	UNITS["wolfhound"] = wheels(0.34, [0.42, 0.0, -0.42], 0.17, 0.14) + [
		P("box", Vector3(0.62, 0.3, 1.2), Vector3(0, 0.4, 0), "steel"),
		P("wedge", Vector3(0.62, 0.22, 0.34), Vector3(0, 0.44, 0.68), "steel", Vector3(90, 0, 180)),
		P("box", Vector3(0.66, 0.05, 1.1), Vector3(0, 0.26, 0), "steel_dark"),
		P("box", Vector3(0.63, 0.06, 0.24), Vector3(0, 0.58, -0.36), "team"),
		P("box", Vector3(0.12, 0.08, 0.18), Vector3(-0.2, 0.6, -0.5), "crate"),
		P("box", Vector3(0.3, 0.06, 0.08), Vector3(0, 0.5, 0.78), "glass", Vector3(-30, 0, 0)),
		T("box", Vector3(0.34, 0.16, 0.38), Vector3(0, 0.64, -0.02), "steel_light"),
		T("wedge", Vector3(0.34, 0.1, 0.12), Vector3(0, 0.62, 0.22), "steel_light", Vector3(90, 0, 180)),
		T("cyl", Vector3(0.03, 0.55, 8), Vector3(0.05, 0.66, 0.42), "gun", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.045, 0.1, 8), Vector3(0.05, 0.66, 0.7), "gun", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.012, 0.35, 4), Vector3(-0.12, 0.88, -0.15), "black"),
	]
	UNITS["leopold"] = tracks(0.44, 1.45, 0.3, 0.26, 6) + [
		P("box", Vector3(0.66, 0.26, 1.3), Vector3(0, 0.4, -0.04), "steel"),
		P("wedge", Vector3(0.66, 0.2, 0.3), Vector3(0, 0.42, 0.75), "steel", Vector3(90, 0, 180)),
		P("box", Vector3(0.1, 0.18, 1.4), Vector3(-0.53, 0.34, 0), "steel_dark"),
		P("box", Vector3(0.1, 0.18, 1.4), Vector3(0.53, 0.34, 0), "steel_dark"),
		P("box", Vector3(0.5, 0.06, 0.3), Vector3(0, 0.55, -0.55), "steel_dark"),
		P("cyl", Vector3(0.04, 0.2, 6), Vector3(0.24, 0.5, -0.66), "black", Vector3(90, 0, 0)),
		T("box", Vector3(0.6, 0.24, 0.66), Vector3(0, 0.66, -0.08), "steel_light"),
		T("wedge", Vector3(0.6, 0.18, 0.2), Vector3(0, 0.63, 0.34), "steel_light", Vector3(90, 0, 180)),
		T("box", Vector3(0.62, 0.08, 0.22), Vector3(0, 0.74, -0.22), "team"),
		T("box", Vector3(0.44, 0.14, 0.18), Vector3(0, 0.64, -0.48), "steel_dark"),
		T("cyl", Vector3(0.05, 1.0, 10), Vector3(0, 0.68, 0.72), "steel_dark", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.075, 0.18, 10), Vector3(0, 0.68, 0.9), "steel", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.08, 0.1, 8), Vector3(0, 0.68, 1.22), "gun", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.09, 0.08, 8), Vector3(0.15, 0.82, -0.18), "steel_dark"),
		T("box", Vector3(0.02, 0.03, 0.22), Vector3(0.15, 0.88, -0.08), "gun"),
		T("cyl", Vector3(0.01, 0.4, 4), Vector3(-0.2, 0.98, -0.3), "black"),
	]
	UNITS["aegis"] = tracks(0.38, 1.2, 0.28, 0.22, 5) + [
		P("box", Vector3(0.58, 0.34, 1.15), Vector3(0, 0.42, 0), "steel"),
		P("wedge", Vector3(0.58, 0.16, 0.3), Vector3(0, 0.44, 0.66), "steel", Vector3(90, 0, 180)),
		P("box", Vector3(0.6, 0.07, 0.22), Vector3(0, 0.62, 0.3), "team"),
		P("box", Vector3(0.36, 0.16, 0.5), Vector3(0, 0.67, -0.2), "steel_light"),
		P("cyl", Vector3(0.05, 0.9, 6), Vector3(0, 1.1, -0.2), "steel_dark"),
		P("cyl", Vector3(0.32, 0.06, 10), Vector3(0, 1.5, -0.2), "trim"),
		P("cyl", Vector3(0.26, 0.08, 10), Vector3(0, 1.56, -0.2), "cyan"),
		P("sph", Vector3(0.1, 0, 0), Vector3(0, 1.66, -0.2), "cyan"),
		P("cyl", Vector3(0.2, 0.12, 8), Vector3(0, 0.78, -0.2), "cyan"),
	]
	UNITS["flakwerk"] = tracks(0.38, 1.2, 0.28, 0.22, 5) + [
		P("box", Vector3(0.58, 0.3, 1.15), Vector3(0, 0.4, 0), "steel"),
		P("wedge", Vector3(0.58, 0.14, 0.26), Vector3(0, 0.42, 0.66), "steel", Vector3(90, 0, 180)),
		P("box", Vector3(0.6, 0.07, 0.22), Vector3(0, 0.58, -0.4), "team"),
		T("cyl", Vector3(0.24, 0.12, 10), Vector3(0, 0.62, 0.0), "steel_dark"),
		T("box", Vector3(0.46, 0.26, 0.4), Vector3(0, 0.8, 0.0), "steel_light"),
		T("box", Vector3(0.47, 0.07, 0.2), Vector3(0, 0.95, -0.08), "team"),
		T("cyl", Vector3(0.028, 0.75, 6), Vector3(-0.17, 1.02, 0.3), "gun", Vector3(50, 0, 0)),
		T("cyl", Vector3(0.028, 0.75, 6), Vector3(-0.27, 1.02, 0.3), "gun", Vector3(50, 0, 0)),
		T("cyl", Vector3(0.028, 0.75, 6), Vector3(0.17, 1.02, 0.3), "gun", Vector3(50, 0, 0)),
		T("cyl", Vector3(0.028, 0.75, 6), Vector3(0.27, 1.02, 0.3), "gun", Vector3(50, 0, 0)),
		T("cyl", Vector3(0.16, 0.03, 10), Vector3(0, 1.08, -0.2), "steel_dark", Vector3(-60, 0, 0)),
	]
	# ---------------- buildings (+z = front / door side) ----------------
	BUILDINGS["hq"] = {"fp": Vector2(4, 4), "path": "res://view/buildings/eu/hq.tscn", "parts": pad(Vector2(4, 4)) + [
		P("box", Vector3(2.6, 1.0, 1.9), Vector3(-0.45, 0.62, -0.6), "concrete"),
		P("box", Vector3(2.7, 0.08, 2.0), Vector3(-0.45, 1.16, -0.6), "concrete_dark"),
		P("box", Vector3(2.5, 0.18, 0.04), Vector3(-0.45, 0.85, 0.36), "window"),
		P("box", Vector3(0.6, 0.55, 0.06), Vector3(-0.45, 0.39, 0.37), "steel_dark"),
		P("box", Vector3(2.62, 0.12, 0.05), Vector3(-0.45, 1.02, 0.37), "team"),
		P("box", Vector3(1.1, 1.0, 1.2), Vector3(-1.2, 1.7, -0.9), "concrete"),
		P("box", Vector3(1.12, 0.14, 0.04), Vector3(-1.2, 1.85, -0.29), "window"),
		P("box", Vector3(1.15, 0.06, 1.25), Vector3(-1.2, 2.22, -0.9), "concrete_dark"),
		P("cyl", Vector3(0.05, 0.9, 6), Vector3(-1.4, 2.65, -1.1), "steel_light"),
		P("sph", Vector3(0.38, 0.12, 0.38), Vector3(-0.9, 2.4, -0.85), "steel_light", Vector3(-30, 0, 0)),
		P("box", Vector3(1.2, 0.8, 1.5), Vector3(1.25, 0.52, -0.85), "corr"),
		P("cyl", Vector3(0.75, 1.2, 12), Vector3(1.25, 0.92, -0.85), "corr_dark", Vector3(90, 0, 0), "", 1.0),
		P("cyl", Vector3(0.6, 0.02, 16), Vector3(1.1, 0.13, 1.1), "concrete_dark"),
		P("box", Vector3(0.08, 0.01, 0.5), Vector3(0.95, 0.15, 1.1), "paint_w"),
		P("box", Vector3(0.08, 0.01, 0.5), Vector3(1.25, 0.15, 1.1), "paint_w"),
		P("box", Vector3(0.3, 0.01, 0.08), Vector3(1.1, 0.15, 1.1), "paint_w"),
		P("box", Vector3(0.22, 0.12, 0.06), Vector3(-1.0, 1.0, 0.38), "lamp"),
	] + sandbags(Vector2(-1.9, 1.85), Vector2(0.1, 1.85)) + flag(Vector3(1.75, 0.12, 1.7), 1.6) + barrels(Vector3(-1.75, 0.12, 0.7), 4)}
	BUILDINGS["reactor"] = {"fp": Vector2(3, 3), "path": "res://view/buildings/eu/reactor.tscn", "parts": pad(Vector2(3, 3)) + [
		P("cone", Vector3(0.85, 1.7, 0.6), Vector3(-0.4, 0.97, -0.4), "concrete"),
		P("cyl", Vector3(0.62, 0.1, 14), Vector3(-0.4, 1.85, -0.4), "concrete_dark"),
		P("cyl", Vector3(0.55, 0.04, 14), Vector3(-0.4, 1.9, -0.4), "black"),
		P("box", Vector3(1.3, 0.6, 0.9), Vector3(0.5, 0.42, 0.65), "corr"),
		P("box", Vector3(1.32, 0.06, 0.92), Vector3(0.5, 0.75, 0.65), "roof"),
		P("hsph", Vector3(0.5, 0.45, 0.5), Vector3(0.75, 0.12, -0.6), "steel_light"),
		P("cyl", Vector3(0.52, 0.08, 14), Vector3(0.75, 0.2, -0.6), "cyan"),
		P("cyl", Vector3(0.06, 1.2, 6), Vector3(0.2, 0.55, -0.1), "steel_dark", Vector3(0, 0, 90)),
		P("cyl", Vector3(0.06, 0.9, 6), Vector3(-0.4, 0.3, 0.45), "steel_dark", Vector3(90, 0, 0)),
		P("box", Vector3(0.9, 0.1, 0.04), Vector3(0.5, 0.55, 1.11), "team"),
		P("box", Vector3(0.3, 0.3, 0.04), Vector3(-0.4, 1.0, 0.24), "trim"),
	] + fence(Vector2(-1.4, 1.4), Vector2(-0.3, 1.4))}
	BUILDINGS["pylon"] = {"fp": Vector2(1, 1), "path": "res://view/buildings/eu/pylon.tscn", "parts": [
		P("box", Vector3(0.85, 0.1, 0.85), Vector3(0, 0.05, 0), "concrete_dark"),
		P("box", Vector3(0.05, 2.0, 0.05), Vector3(-0.22, 1.0, -0.22), "steel_dark", Vector3(-5, 0, 5)),
		P("box", Vector3(0.05, 2.0, 0.05), Vector3(0.22, 1.0, -0.22), "steel_dark", Vector3(-5, 0, -5)),
		P("box", Vector3(0.05, 2.0, 0.05), Vector3(-0.22, 1.0, 0.22), "steel_dark", Vector3(5, 0, 5)),
		P("box", Vector3(0.05, 2.0, 0.05), Vector3(0.22, 1.0, 0.22), "steel_dark", Vector3(5, 0, -5)),
		P("box", Vector3(0.42, 0.03, 0.03), Vector3(0, 0.7, 0.2), "steel_dark", Vector3(0, 0, 30)),
		P("box", Vector3(0.42, 0.03, 0.03), Vector3(0, 1.3, 0.16), "steel_dark", Vector3(0, 0, -30)),
		P("box", Vector3(0.9, 0.06, 0.06), Vector3(0, 1.75, 0), "steel"),
		P("cyl", Vector3(0.05, 0.14, 6), Vector3(-0.4, 1.68, 0), "cyan"),
		P("cyl", Vector3(0.05, 0.14, 6), Vector3(0.4, 1.68, 0), "cyan"),
		P("sph", Vector3(0.13, 0, 0), Vector3(0, 2.08, 0), "cyan"),
		P("box", Vector3(0.24, 0.16, 0.02), Vector3(0, 0.5, 0.24), "team"),
	]}
	BUILDINGS["hub"] = {"fp": Vector2(3, 3), "path": "res://view/buildings/eu/hub.tscn", "parts": pad(Vector2(3, 3)) + [
		P("box", Vector3(2.2, 0.9, 1.3), Vector3(-0.2, 0.57, -0.7), "corr"),
		P("wedge", Vector3(2.25, 0.3, 1.35), Vector3(-0.2, 1.17, -0.7), "corr_dark", Vector3(0, 90, 0)),
		P("box", Vector3(0.9, 0.7, 0.05), Vector3(-0.5, 0.47, -0.03), "steel_dark"),
		P("box", Vector3(2.22, 0.1, 0.05), Vector3(-0.2, 0.92, -0.04), "team"),
		P("cyl", Vector3(0.32, 1.4, 12), Vector3(1.05, 0.82, -0.85), "steel_light"),
		P("cone", Vector3(0.32, 0.2, 0.05), Vector3(1.05, 1.62, -0.85), "steel_light"),
		P("cyl", Vector3(0.32, 1.1, 12), Vector3(1.05, 0.67, -0.15), "steel_light", Vector3.ZERO, "", 0.92),
		P("box", Vector3(1.0, 0.25, 0.9), Vector3(-0.6, 0.25, 0.85), "concrete"),
		P("box", Vector3(0.9, 0.04, 0.06), Vector3(-0.6, 0.38, 1.3), "paint_y"),
	] + crates(Vector3(0.6, 0.12, 0.65), 5, 0.26) + [P("box", Vector3(0.2, 0.1, 0.06), Vector3(0.3, 0.8, -0.03), "lamp")]}
	BUILDINGS["barracks"] = {"fp": Vector2(3, 3), "path": "res://view/buildings/eu/barracks.tscn", "parts": pad(Vector2(3, 3)) + [
		P("cyl", Vector3(0.85, 2.3, 14), Vector3(0, 0.12, -0.35), "corr_green", Vector3(0, 0, 90)),
		P("box", Vector3(2.32, 0.9, 1.0), Vector3(0, -0.33, -0.35), "concrete_dark"),
		P("box", Vector3(0.5, 0.6, 0.05), Vector3(0.45, 0.42, 0.5), "steel_dark", Vector3(0, 90, 0)),
		P("box", Vector3(0.06, 0.62, 0.55), Vector3(-1.16, 0.42, -0.35), "steel_dark"),
		P("box", Vector3(0.05, 0.12, 1.75), Vector3(1.16, 0.75, -0.35), "team"),
		P("box", Vector3(0.05, 0.12, 1.75), Vector3(-1.17, 0.75, -0.35), "team"),
		P("box", Vector3(0.05, 0.22, 0.35), Vector3(1.16, 0.5, 0.0), "window"),
		P("box", Vector3(0.05, 0.22, 0.35), Vector3(1.16, 0.5, -0.7), "window"),
	] + sandbags(Vector2(-1.3, 0.9), Vector2(-0.2, 0.9)) + sandbags(Vector2(0.4, 0.9), Vector2(1.3, 0.9)) + flag(Vector3(1.2, 0.12, 1.25), 1.4) + crates(Vector3(-1.1, 0.12, 1.15), 3, 0.22)}
	BUILDINGS["motor_pool"] = {"fp": Vector2(4, 4), "path": "res://view/buildings/eu/motor_pool.tscn", "parts": pad(Vector2(4, 4)) + [
		P("box", Vector3(3.2, 1.25, 2.4), Vector3(0, 0.74, -0.55), "corr"),
		P("wedge", Vector3(3.25, 0.35, 2.45), Vector3(0, 1.54, -0.55), "corr_dark", Vector3(0, 90, 0)),
		P("box", Vector3(1.6, 1.0, 0.05), Vector3(-0.5, 0.62, 0.66), "black"),
		P("box", Vector3(1.7, 0.1, 0.08), Vector3(-0.5, 1.15, 0.67), "hazard"),
		P("box", Vector3(0.9, 0.9, 0.9), Vector3(1.05, 0.57, 0.95), "concrete"),
		P("box", Vector3(0.92, 0.18, 0.04), Vector3(1.05, 0.75, 1.41), "window"),
		P("box", Vector3(3.22, 0.14, 0.05), Vector3(0, 1.3, 0.66), "team"),
		P("box", Vector3(0.1, 1.6, 0.1), Vector3(-1.6, 0.9, 1.6), "hazard"),
		P("box", Vector3(0.1, 1.6, 0.1), Vector3(0.6, 0.9, 1.6), "hazard"),
		P("box", Vector3(2.3, 0.1, 0.12), Vector3(-0.5, 1.7, 1.6), "hazard"),
		P("box", Vector3(1.4, 0.01, 0.08), Vector3(-0.5, 0.125, 1.35), "paint_w"),
	] + barrels(Vector3(1.4, 0.12, -1.7), 5)}
	BUILDINGS["heavy_factory"] = {"fp": Vector2(4, 4), "path": "res://view/buildings/eu/heavy_factory.tscn", "parts": pad(Vector2(4, 4)) + [
		P("box", Vector3(3.5, 1.6, 2.8), Vector3(0, 0.92, -0.4), "corr_dark"),
		P("box", Vector3(3.55, 0.1, 2.85), Vector3(0, 1.75, -0.4), "roof"),
		P("box", Vector3(3.0, 0.3, 0.6), Vector3(0, 1.95, -0.6), "corr"),
		P("box", Vector3(2.0, 1.25, 0.05), Vector3(-0.3, 0.75, 1.0), "black"),
		P("box", Vector3(2.1, 0.12, 0.08), Vector3(-0.3, 1.42, 1.02), "hazard"),
		P("box", Vector3(3.52, 0.18, 0.05), Vector3(0, 1.6, 1.01), "team"),
		P("cyl", Vector3(0.18, 1.6, 10), Vector3(-1.3, 2.4, -1.4), "steel_dark"),
		P("cyl", Vector3(0.2, 0.1, 10), Vector3(-1.3, 3.2, -1.4), "rust"),
		P("cyl", Vector3(0.18, 1.3, 10), Vector3(-0.8, 2.25, -1.4), "steel_dark"),
		P("box", Vector3(0.7, 0.5, 0.7), Vector3(1.2, 2.05, -1.0), "steel"),
		P("cyl", Vector3(0.25, 0.9, 10), Vector3(1.5, 0.57, 1.45), "steel_light"),
		P("box", Vector3(0.3, 0.12, 0.06), Vector3(1.1, 1.3, 1.0), "lamp"),
	] + fence(Vector2(-1.9, 1.85), Vector2(-1.4, 1.85)) + barrels(Vector3(0.9, 0.12, 1.5), 3)}
	BUILDINGS["gun_bunker"] = {"fp": Vector2(2, 2), "path": "res://view/buildings/eu/gun_bunker.tscn", "parts": [
		P("cyl", Vector3(0.82, 0.12, 14), Vector3(0, 0.06, 0), "concrete_dark"),
		P("cone", Vector3(0.72, 0.5, 0.58), Vector3(0, 0.37, 0), "concrete"),
		P("box", Vector3(0.9, 0.08, 0.06), Vector3(0, 0.5, 0.6), "black"),
		P("box", Vector3(0.9, 0.07, 0.25), Vector3(0, 0.6, -0.45), "team"),
	] + sandbags(Vector2(-0.95, 0.9), Vector2(0.95, 0.9)) + sandbags(Vector2(-0.95, -0.9), Vector2(-0.95, 0.9)) + sandbags(Vector2(0.95, -0.9), Vector2(0.95, 0.9)) + [
		T("cyl", Vector3(0.36, 0.22, 10), Vector3(0, 0.73, 0), "steel"),
		T("box", Vector3(0.4, 0.18, 0.32), Vector3(0, 0.9, 0.05), "steel_light"),
		T("cyl", Vector3(0.04, 0.8, 8), Vector3(-0.09, 0.9, 0.55), "gun", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.04, 0.8, 8), Vector3(0.09, 0.9, 0.55), "gun", Vector3(90, 0, 0)),
		T("box", Vector3(0.41, 0.05, 0.2), Vector3(0, 0.98, -0.05), "team"),
	]}
	BUILDINGS["civ_block"] = {"fp": Vector2(3, 3), "path": "res://view/buildings/neutral/civ_block.tscn", "parts": [
		P("box", Vector3(2.6, 1.9, 2.4), Vector3(0, 0.95, 0), "plaster"),
		P("box", Vector3(2.7, 0.12, 2.5), Vector3(0, 1.94, 0), "plaster2"),
		P("box", Vector3(2.62, 0.08, 2.42), Vector3(0, 0.98, 0), "plaster2"),
		P("box", Vector3(1.0, 0.6, 0.06), Vector3(-0.5, 0.45, 1.21), "window"),
		P("box", Vector3(0.45, 0.75, 0.06), Vector3(0.75, 0.38, 1.21), "wood"),
		P("box", Vector3(1.3, 0.05, 0.45), Vector3(-0.5, 0.85, 1.42), "red", Vector3(-12, 0, 0)),
		P("box", Vector3(0.28, 0.38, 0.06), Vector3(-0.8, 1.45, 1.21), "window"),
		P("box", Vector3(0.28, 0.38, 0.06), Vector3(-0.1, 1.45, 1.21), "window"),
		P("box", Vector3(0.28, 0.38, 0.06), Vector3(0.6, 1.45, 1.21), "window"),
		P("box", Vector3(0.06, 0.38, 0.28), Vector3(1.31, 1.45, -0.5), "window"),
		P("box", Vector3(0.06, 0.38, 0.28), Vector3(1.31, 1.45, 0.4), "window"),
		P("box", Vector3(0.06, 0.38, 0.28), Vector3(-1.31, 1.45, 0.0), "window"),
		P("box", Vector3(0.06, 0.38, 0.28), Vector3(1.31, 0.5, -0.5), "window"),
		P("box", Vector3(0.28, 0.38, 0.06), Vector3(0.3, 1.45, -1.21), "window"),
		P("box", Vector3(0.9, 0.06, 0.4), Vector3(0.25, 1.22, 1.38), "plaster2"),
		P("cyl", Vector3(0.22, 0.4, 10), Vector3(0.75, 2.2, -0.6), "steel_light"),
		P("box", Vector3(0.4, 0.22, 0.3), Vector3(-0.7, 2.11, -0.5), "steel_light"),
		P("box", Vector3(0.6, 0.04, 0.04), Vector3(-0.1, 2.3, 0.4), "black"),
		P("box", Vector3(2.7, 0.12, 0.04), Vector3(0, 2.06, 1.25), "plaster2"),
		P("box", Vector3(0.32, 0.22, 0.02), Vector3(-1.0, 2.38, 0.8), "team"),
		P("cyl", Vector3(0.015, 0.45, 4), Vector3(-1.17, 2.22, 0.8), "steel_light"),
	]}
	BUILDINGS["pump"] = {"fp": Vector2(2, 2), "path": "res://view/buildings/neutral/pump.tscn", "parts": [
		P("box", Vector3(1.9, 0.12, 1.9), Vector3(0, 0.06, 0), "concrete_dark"),
		# derrick lattice
		P("box", Vector3(0.06, 2.3, 0.06), Vector3(-0.45, 1.15, -0.45), "rust", Vector3(-6, 0, 6)),
		P("box", Vector3(0.06, 2.3, 0.06), Vector3(-0.05, 1.15, -0.45), "rust", Vector3(-6, 0, -6)),
		P("box", Vector3(0.06, 2.3, 0.06), Vector3(-0.45, 1.15, -0.05), "rust", Vector3(6, 0, 6)),
		P("box", Vector3(0.06, 2.3, 0.06), Vector3(-0.05, 1.15, -0.05), "rust", Vector3(6, 0, -6)),
		P("box", Vector3(0.42, 0.04, 0.04), Vector3(-0.25, 0.8, -0.08), "rust", Vector3(0, 0, 32)),
		P("box", Vector3(0.36, 0.04, 0.04), Vector3(-0.25, 1.5, -0.12), "rust", Vector3(0, 0, -32)),
		P("box", Vector3(0.2, 0.08, 0.2), Vector3(-0.25, 2.3, -0.25), "rust"),
		# pumpjack
		P("box", Vector3(0.08, 0.7, 0.08), Vector3(0.45, 0.45, 0.35), "steel_dark", Vector3(0, 0, 10)),
		P("box", Vector3(0.08, 0.7, 0.08), Vector3(0.45, 0.45, 0.6), "steel_dark", Vector3(0, 0, 10)),
		P("box", Vector3(1.2, 0.08, 0.1), Vector3(0.45, 0.82, 0.47), "hazard", Vector3(0, 0, -10)),
		P("box", Vector3(0.12, 0.35, 0.16), Vector3(-0.12, 0.8, 0.47), "hazard", Vector3(0, 0, -10)),
		P("box", Vector3(0.3, 0.3, 0.3), Vector3(0.95, 0.25, 0.47), "steel"),
		P("cyl", Vector3(0.05, 0.4, 6), Vector3(-0.15, 0.3, 0.47), "steel_dark"),
		P("cyl", Vector3(0.28, 0.6, 12), Vector3(0.55, 0.42, -0.5), "steel_light"),
		P("cyl", Vector3(0.29, 0.06, 12), Vector3(0.55, 0.6, -0.5), "team"),
	] + barrels(Vector3(-0.8, 0.12, 0.55), 3)}
	PROPS["seam"] = [P("box", Vector3(2.2, 0.06, 2.2), Vector3(0, 0.03, 0), "wood", Vector3.ZERO, "", 0.8)] + crates(Vector3(-0.7, 0.06, -0.7), 6, 0.36) + crates(Vector3(0.2, 0.06, 0.1), 5, 0.36) + crates(Vector3(-0.6, 0.06, 0.5), 4, 0.36) + barrels(Vector3(0.45, 0.06, -0.8), 4) + [
		P("box", Vector3(0.7, 0.08, 0.7), Vector3(0.6, 0.1, 0.65), "wood"),
		P("box", Vector3(0.6, 0.35, 0.6), Vector3(0.6, 0.31, 0.65), "olive"),
	]
	PROPS["cache"] = crates(Vector3(-0.25, 0, -0.2), 4, 0.34) + barrels(Vector3(0.3, 0, 0.3), 2)

# =====================================================================================
# TPLA (M2): ramshackle, scavenged, tarp and scrap metal, sandbags, desert camo; team colour
# on cloth (scarves, tarps, flags). Original designs.
# =====================================================================================
var TP_UNITS := {}
var TP_BUILDINGS := {}

static func Q(n: int, shape: String, s: Vector3, pos: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> Array:
	return [shape, s, pos, rot, key, "tier%d" % n]

static func QT(n: int, shape: String, s: Vector3, pos: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> Array:
	return [shape, s, pos, rot, key, "turret:tier%d" % n]

## One insurgent figure at (x, z). head: wrap | cap | helmet | hardhat. item: rifle | rpg | shovel | sack | none
static func person(x: float, z: float, shirt: String, pants: String, head: String, item: String, lean: float = 0.0) -> Array:
	var o: Array = []
	o.append(P("box", Vector3(0.05, 0.22, 0.06), Vector3(x - 0.035, 0.11, z), pants, Vector3(8 + lean, 0, 0)))
	o.append(P("box", Vector3(0.05, 0.22, 0.06), Vector3(x + 0.035, 0.11, z), pants, Vector3(-8 + lean, 0, 0)))
	o.append(P("box", Vector3(0.14, 0.2, 0.085), Vector3(x, 0.32, z), shirt, Vector3(lean, 0, 0)))
	o.append(P("box", Vector3(0.15, 0.04, 0.09), Vector3(x, 0.235, z), "camo_brown"))                     # belt
	o.append(P("box", Vector3(0.16, 0.05, 0.1), Vector3(x, 0.4, z + 0.005), "team", Vector3(0, 0, 8)))      # scarf
	o.append(P("sph", Vector3(0.05, 0, 0), Vector3(x, 0.47, z), "skin"))
	match head:
		"wrap":
			o.append(P("hsph", Vector3(0.058, 0.045, 0.058), Vector3(x, 0.485, z), "cloth"))
			o.append(P("box", Vector3(0.03, 0.06, 0.02), Vector3(x, 0.45, z - 0.06), "cloth", Vector3(20, 0, 0)))
		"cap":
			o.append(P("hsph", Vector3(0.055, 0.035, 0.055), Vector3(x, 0.49, z), "camo_olive"))
			o.append(P("box", Vector3(0.07, 0.01, 0.05), Vector3(x, 0.49, z + 0.06), "camo_olive"))
		"helmet":
			o.append(P("hsph", Vector3(0.062, 0.05, 0.062), Vector3(x, 0.48, z), "scrap_green"))
		"hardhat":
			o.append(P("hsph", Vector3(0.06, 0.045, 0.06), Vector3(x, 0.49, z), "paint_y"))
	o.append(P("box", Vector3(0.04, 0.16, 0.05), Vector3(x - 0.09, 0.31, z + 0.03), shirt, Vector3(-30, 0, 0)))
	o.append(P("box", Vector3(0.04, 0.16, 0.05), Vector3(x + 0.09, 0.31, z + 0.03), shirt, Vector3(-30, 0, 0)))
	match item:
		"rifle":
			o.append(P("box", Vector3(0.03, 0.045, 0.28), Vector3(x + 0.05, 0.3, z + 0.12), "gun", Vector3(-10, 0, 0)))
			o.append(P("box", Vector3(0.025, 0.07, 0.03), Vector3(x + 0.05, 0.27, z + 0.12), "plank", Vector3(-10, 0, 0)))
		"rpg":
			o.append(P("cyl", Vector3(0.03, 0.46, 8), Vector3(x + 0.08, 0.43, z + 0.02), "camo_olive", Vector3(90, 0, 0)))
			o.append(P("cone", Vector3(0.06, 0.12, 0.02), Vector3(x + 0.08, 0.43, z + 0.3), "khaki", Vector3(90, 0, 0)))
		"shovel":
			o.append(P("cyl", Vector3(0.012, 0.42, 5), Vector3(x + 0.09, 0.32, z + 0.06), "plank", Vector3(-25, 0, 0)))
			o.append(P("box", Vector3(0.07, 0.09, 0.01), Vector3(x + 0.09, 0.13, z + 0.15), "steel_dark", Vector3(-25, 0, 0)))
		"sack":
			o.append(P("sph", Vector3(0.08, 0.06, 0.06), Vector3(x, 0.36, z - 0.08), "cloth"))
	return o

## Pickup-truck chassis (technical / Hailstorm / Mule base): front at +z.
static func pickup(body_col: String, bed_len: float = 0.5) -> Array:
	var o := wheels(0.3, [0.36, -0.36], 0.14, 0.11)
	o += [
		P("box", Vector3(0.6, 0.12, 1.25), Vector3(0, 0.24, 0), "steel_dark"),
		P("box", Vector3(0.58, 0.2, 0.38), Vector3(0, 0.38, 0.42), body_col),                  # bonnet
		P("box", Vector3(0.56, 0.26, 0.34), Vector3(0, 0.55, 0.08), body_col),                 # cab
		P("box", Vector3(0.5, 0.13, 0.03), Vector3(0, 0.58, 0.26), "glass", Vector3(-15, 0, 0)),
		P("box", Vector3(0.57, 0.04, 0.36), Vector3(0, 0.69, 0.08), body_col, Vector3.ZERO, "", 0.85),
		P("box", Vector3(0.6, 0.06, 0.08), Vector3(0, 0.3, 0.63), "steel_light"),               # bumper
		P("box", Vector3(0.6, 0.18, 0.03), Vector3(0, 0.38, -0.12 - bed_len), body_col, Vector3.ZERO, "", 0.9),
		P("box", Vector3(0.03, 0.16, bed_len + 0.04), Vector3(-0.29, 0.38, -0.1 - bed_len * 0.5), body_col, Vector3.ZERO, "", 0.9),
		P("box", Vector3(0.03, 0.16, bed_len + 0.04), Vector3(0.29, 0.38, -0.1 - bed_len * 0.5), body_col, Vector3.ZERO, "", 0.9),
		P("box", Vector3(0.15, 0.1, 0.02), Vector3(-0.18, 0.4, 0.62), "lamp"),
		P("box", Vector3(0.15, 0.1, 0.02), Vector3(0.18, 0.4, 0.62), "lamp"),
		P("box", Vector3(0.3, 0.14, 0.02), Vector3(0.12, 0.45, 0.25 + 0.0), "scrap_red", Vector3(0, 0, 4)),   # mismatched door
		P("box", Vector3(0.2, 0.03, 0.22), Vector3(-0.15, 0.71, 0.08), "team"),                    # cloth on roof
	]
	return o

func _tpla_defs() -> void:
	# ---------------- units ----------------
	TP_UNITS["laborer"] = person(0, 0, "khaki", "camo_brown", "hardhat", "shovel") + [P("sph", Vector3(0.08, 0.06, 0.06), Vector3(0, 0.36, -0.08), "cloth")]
	TP_UNITS["militia"] = person(-0.2, -0.16, "tan", "camo_olive", "wrap", "rifle") + person(0.2, -0.14, "camo_olive", "khaki", "cap", "rifle") \
		+ person(-0.16, 0.2, "camo_brown", "tan", "wrap", "rifle") + person(0.2, 0.2, "khaki", "camo_brown", "helmet", "rifle")
	TP_UNITS["rocket_cell"] = person(-0.16, 0, "camo_olive", "tan", "wrap", "rpg") + person(0.18, 0.04, "tan", "camo_brown", "cap", "rpg") \
		+ [P("box", Vector3(0.1, 0.07, 0.14), Vector3(0.0, 0.035, -0.18), "camo_olive")]
	TP_UNITS["rattler"] = pickup("tan") + [
		P("box", Vector3(0.2, 0.12, 0.3), Vector3(-0.15, 0.36, -0.42), "crate"),
		P("cyl", Vector3(0.12, 0.08, 10), Vector3(0.18, 0.37, -0.58), "tire", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.025, 0.36, 6), Vector3(0, 0.5, -0.32), "steel_dark"),
		T("box", Vector3(0.24, 0.16, 0.03), Vector3(0, 0.74, -0.2), "scrap_green"),              # gun shield
		T("box", Vector3(0.06, 0.08, 0.2), Vector3(0, 0.72, -0.3), "gun"),
		T("cyl", Vector3(0.02, 0.5, 6), Vector3(0, 0.73, 0.0), "gun", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.03, 0.06, 6), Vector3(0, 0.73, 0.26), "black", Vector3(90, 0, 0)),
		# salvage tier 1: side armour plates + spare tire on the bonnet
		Q(1, "box", Vector3(0.03, 0.2, 0.5), Vector3(-0.31, 0.42, 0.15), "scrap_blue", Vector3(0, 0, -6)),
		Q(1, "box", Vector3(0.03, 0.2, 0.5), Vector3(0.31, 0.42, 0.15), "corr_rust", Vector3(0, 0, 6)),
		Q(1, "cyl", Vector3(0.11, 0.07, 10), Vector3(0, 0.52, 0.45), "tire"),
		# tier 2: 40 mm cannon on the mount
		QT(2, "cyl", Vector3(0.045, 0.7, 8), Vector3(0.1, 0.78, 0.06), "steel_dark", Vector3(90, 0, 0)),
		QT(2, "box", Vector3(0.12, 0.12, 0.22), Vector3(0.1, 0.78, -0.26), "steel"),
		# tier 3: sandbagged bed, cab cage, extra armour
		Q(3, "box", Vector3(0.62, 0.05, 0.05), Vector3(0, 0.8, 0.26), "steel_dark"),
		Q(3, "box", Vector3(0.05, 0.3, 0.05), Vector3(-0.27, 0.65, 0.26), "steel_dark"),
		Q(3, "box", Vector3(0.05, 0.3, 0.05), Vector3(0.27, 0.65, 0.26), "steel_dark"),
		Q(3, "box", Vector3(0.5, 0.1, 0.02), Vector3(0, 0.46, 0.67), "scrap_red"),
	] + _tierify(3, sandbags(Vector2(-0.24, -0.66), Vector2(0.24, -0.66), 1))
	TP_UNITS["hailstorm"] = pickup("khaki", 0.55) + [
		P("box", Vector3(0.5, 0.06, 0.5), Vector3(0, 0.33, -0.36), "steel_dark"),
		T("cyl", Vector3(0.17, 0.1, 10), Vector3(0, 0.42, -0.36), "camo_olive"),
		T("box", Vector3(0.3, 0.2, 0.26), Vector3(0, 0.58, -0.36), "camo_olive"),
		T("box", Vector3(0.31, 0.05, 0.14), Vector3(0, 0.7, -0.4), "team"),
		T("box", Vector3(0.36, 0.2, 0.03), Vector3(0, 0.6, -0.2), "scrap_green", Vector3(-15, 0, 0)),
		T("cyl", Vector3(0.022, 0.6, 6), Vector3(-0.12, 0.66, -0.05), "gun", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.022, 0.6, 6), Vector3(-0.06, 0.66, -0.05), "gun", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.022, 0.6, 6), Vector3(0.06, 0.66, -0.05), "gun", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.022, 0.6, 6), Vector3(0.12, 0.66, -0.05), "gun", Vector3(70, 0, 0)),
		T("box", Vector3(0.08, 0.14, 0.1), Vector3(-0.2, 0.55, -0.42), "crate"),
		Q(1, "box", Vector3(0.03, 0.2, 0.55), Vector3(-0.31, 0.42, 0.15), "scrap_blue"),
		Q(1, "box", Vector3(0.03, 0.2, 0.55), Vector3(0.31, 0.42, 0.15), "scrap_red"),
		QT(2, "box", Vector3(0.4, 0.16, 0.03), Vector3(0, 0.62, -0.18), "corr_rust", Vector3(-25, 0, 0)),
		Q(3, "box", Vector3(0.5, 0.1, 0.02), Vector3(0, 0.46, 0.67), "scrap_red"),
	] + _tierify(3, sandbags(Vector2(-0.26, -0.7), Vector2(0.26, -0.7), 1))
	TP_UNITS["scrapback"] = tracks(0.4, 1.3, 0.28, 0.22, 5) + [
		P("box", Vector3(0.62, 0.24, 1.18), Vector3(0, 0.38, -0.02), "camo_olive"),
		P("wedge", Vector3(0.62, 0.18, 0.28), Vector3(0, 0.4, 0.68), "camo_olive", Vector3(90, 0, 180)),
		P("box", Vector3(0.3, 0.02, 0.4), Vector3(-0.15, 0.51, -0.25), "scrap_blue"),             # patch plate
		P("box", Vector3(0.22, 0.02, 0.3), Vector3(0.18, 0.51, 0.25), "corr_rust"),
		P("box", Vector3(0.05, 0.16, 1.2), Vector3(-0.47, 0.34, 0), "scrap_red"),
		P("box", Vector3(0.05, 0.16, 1.2), Vector3(0.47, 0.34, 0), "tan"),
		P("cyl", Vector3(0.1, 0.4, 8), Vector3(0.2, 0.55, -0.55), "barrel", Vector3(0, 0, 90)),  # fuel drum
		T("cyl", Vector3(0.28, 0.2, 9), Vector3(0, 0.6, -0.05), "tan"),
		T("box", Vector3(0.36, 0.14, 0.32), Vector3(0, 0.66, 0.04), "tan"),
		T("box", Vector3(0.37, 0.06, 0.14), Vector3(0, 0.72, -0.18), "team"),
		T("cyl", Vector3(0.045, 0.85, 8), Vector3(0, 0.66, 0.6), "steel_dark", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.06, 0.12, 8), Vector3(0, 0.66, 1.0), "rust", Vector3(90, 0, 0)),
		T("cyl", Vector3(0.05, 0.08, 6), Vector3(-0.12, 0.79, -0.08), "steel_dark"),
		Q(1, "box", Vector3(0.04, 0.22, 1.0), Vector3(-0.51, 0.3, 0.05), "corr_rust", Vector3(0, 0, -8)),
		Q(1, "box", Vector3(0.04, 0.22, 1.0), Vector3(0.51, 0.3, 0.05), "scrap_blue", Vector3(0, 0, 8)),
		QT(2, "box", Vector3(0.14, 0.14, 0.34), Vector3(0.27, 0.72, 0.02), "scrap_green"),          # rocket pod
		QT(2, "cyl", Vector3(0.035, 0.04, 6), Vector3(0.24, 0.75, 0.2), "black", Vector3(90, 0, 0)),
		QT(2, "cyl", Vector3(0.035, 0.04, 6), Vector3(0.3, 0.69, 0.2), "black", Vector3(90, 0, 0)),
		QT(3, "box", Vector3(0.4, 0.18, 0.03), Vector3(0, 0.66, 0.22), "corr_dark", Vector3(-20, 0, 0)),
		Q(3, "box", Vector3(0.66, 0.03, 0.3), Vector3(0, 0.55, 0.7), "steel_light", Vector3(-30, 0, 0)),
	]
	TP_UNITS["shrike"] = [
		P("box", Vector3(0.48, 0.08, 1.0), Vector3(0, 0.25, 0), "steel_dark"),
		P("box", Vector3(0.4, 0.14, 0.4), Vector3(0, 0.33, 0.3), "tan"),
		P("box", Vector3(0.03, 0.03, 0.8), Vector3(-0.2, 0.62, -0.02), "steel_dark"),              # roll cage
		P("box", Vector3(0.03, 0.03, 0.8), Vector3(0.2, 0.62, -0.02), "steel_dark"),
		P("box", Vector3(0.43, 0.03, 0.03), Vector3(0, 0.62, 0.36), "steel_dark"),
		P("box", Vector3(0.03, 0.34, 0.03), Vector3(-0.2, 0.45, 0.38), "steel_dark", Vector3(-20, 0, 0)),
		P("box", Vector3(0.03, 0.34, 0.03), Vector3(0.2, 0.45, 0.38), "steel_dark", Vector3(-20, 0, 0)),
		P("box", Vector3(0.03, 0.36, 0.03), Vector3(-0.2, 0.44, -0.4), "steel_dark"),
		P("box", Vector3(0.03, 0.36, 0.03), Vector3(0.2, 0.44, -0.4), "steel_dark"),
		P("box", Vector3(0.12, 0.12, 0.14), Vector3(-0.08, 0.38, -0.02), "camo_brown"),            # seat
		P("box", Vector3(0.4, 0.03, 0.12), Vector3(0, 0.64, -0.3), "team"),
	] + wheels(0.27, [0.36, -0.34], 0.15, 0.13) + [
		T("box", Vector3(0.34, 0.06, 0.24), Vector3(0, 0.68, -0.22), "steel_dark"),
		T("box", Vector3(0.32, 0.2, 0.34), Vector3(0, 0.82, -0.22), "camo_olive", Vector3(-20, 0, 0)),
		T("cyl", Vector3(0.03, 0.04, 6), Vector3(-0.1, 0.9, -0.04), "black", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.03, 0.04, 6), Vector3(0.0, 0.9, -0.04), "black", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.03, 0.04, 6), Vector3(0.1, 0.9, -0.04), "black", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.03, 0.04, 6), Vector3(-0.05, 0.82, -0.02), "black", Vector3(70, 0, 0)),
		T("cyl", Vector3(0.03, 0.04, 6), Vector3(0.05, 0.82, -0.02), "black", Vector3(70, 0, 0)),
		Q(1, "box", Vector3(0.44, 0.12, 0.03), Vector3(0, 0.38, 0.52), "scrap_blue"),
		QT(2, "box", Vector3(0.1, 0.16, 0.3), Vector3(0.24, 0.8, -0.22), "camo_olive", Vector3(-20, 0, 0)),
		QT(2, "box", Vector3(0.1, 0.16, 0.3), Vector3(-0.24, 0.8, -0.22), "camo_olive", Vector3(-20, 0, 0)),
		Q(3, "box", Vector3(0.03, 0.18, 0.7), Vector3(-0.27, 0.36, 0.0), "corr_rust"),
		Q(3, "box", Vector3(0.03, 0.18, 0.7), Vector3(0.27, 0.36, 0.0), "corr_rust"),
	]
	TP_UNITS["mule"] = wheels(0.3, [0.4, -0.25, -0.5], 0.14, 0.12) + [
		P("box", Vector3(0.6, 0.12, 1.4), Vector3(0, 0.25, 0), "steel_dark"),
		P("box", Vector3(0.56, 0.36, 0.34), Vector3(0, 0.49, 0.5), "scrap_blue"),
		P("box", Vector3(0.5, 0.14, 0.03), Vector3(0, 0.58, 0.68), "glass", Vector3(-10, 0, 0)),
		P("box", Vector3(0.6, 0.48, 0.92), Vector3(0, 0.56, -0.18), "tarp"),                          # tarp-covered cargo
		P("box", Vector3(0.62, 0.05, 0.94), Vector3(0, 0.81, -0.18), "tarp", Vector3(0, 0, 3), "", 0.85),
		P("box", Vector3(0.3, 0.3, 0.03), Vector3(0.12, 0.5, -0.65), "team"),
		P("cyl", Vector3(0.1, 0.26, 8), Vector3(-0.18, 0.46, -0.66), "barrel"),
		P("cyl", Vector3(0.1, 0.26, 8), Vector3(-0.18, 0.46, -0.66), "barrel"),
		P("box", Vector3(0.14, 0.06, 0.02), Vector3(-0.18, 0.42, 0.68), "lamp"),
		P("box", Vector3(0.14, 0.06, 0.02), Vector3(0.18, 0.42, 0.68), "lamp"),
		P("box", Vector3(0.012, 0.3, 0.012), Vector3(0.25, 0.97, -0.5), "black"),                    # wire antenna
	]
	TP_UNITS["blight"] = pickup("camo_olive", 0.55) + [
		P("cyl", Vector3(0.1, 0.42, 10), Vector3(-0.14, 0.42, -0.4), "scrap_green", Vector3(90, 0, 0)),
		P("cyl", Vector3(0.1, 0.42, 10), Vector3(0.14, 0.42, -0.4), "scrap_green", Vector3(90, 0, 0)),
		P("box", Vector3(0.05, 0.05, 0.3), Vector3(-0.14, 0.53, -0.4), "acid"),
		P("box", Vector3(0.05, 0.05, 0.3), Vector3(0.14, 0.53, -0.4), "acid"),
		T("box", Vector3(0.3, 0.1, 0.3), Vector3(0, 0.56, -0.62), "steel_dark"),
		T("cyl", Vector3(0.07, 0.62, 10), Vector3(0, 0.82, -0.5), "camo_olive", Vector3(55, 0, 0)),
		T("cyl", Vector3(0.08, 0.06, 10), Vector3(0, 1.0, -0.33), "acid", Vector3(55, 0, 0)),
		T("box", Vector3(0.32, 0.04, 0.12), Vector3(0, 0.62, -0.75), "team"),
	]
	# ---------------- buildings (+z = front / exit side) ----------------
	TP_BUILDINGS["den"] = {"fp": Vector2(4, 4), "parts": [
		P("box", Vector3(3.8, 0.06, 3.8), Vector3(0, 0.03, 0), "dirt"),
		P("box", Vector3(2.3, 1.1, 1.8), Vector3(-0.55, 0.55, -0.7), "mud"),
		P("box", Vector3(2.45, 0.08, 1.95), Vector3(-0.55, 1.12, -0.7), "corr_rust", Vector3(0, 0, 3)),
		P("box", Vector3(1.1, 0.75, 1.1), Vector3(-1.0, 1.5, -1.0), "mud_dark"),
		P("box", Vector3(1.2, 0.06, 1.2), Vector3(-1.0, 1.9, -1.0), "corr_dark", Vector3(-4, 0, 0)),
		P("box", Vector3(0.5, 0.7, 0.05), Vector3(-0.3, 0.35, 0.21), "plank"),
		P("box", Vector3(0.3, 0.25, 0.05), Vector3(-1.3, 0.7, 0.21), "window"),
		P("box", Vector3(0.3, 0.25, 0.05), Vector3(0.3, 0.7, 0.21), "window"),
		P("box", Vector3(0.28, 0.22, 0.05), Vector3(-1.0, 1.55, -0.44), "window"),
		# team-cloth awning on poles over the door
		P("box", Vector3(1.6, 0.03, 0.8), Vector3(-0.5, 0.95, 0.62), "team", Vector3(12, 0, 0)),
		P("cyl", Vector3(0.025, 0.9, 5), Vector3(-1.25, 0.45, 0.98), "plank"),
		P("cyl", Vector3(0.025, 0.9, 5), Vector3(0.25, 0.45, 0.98), "plank"),
		# radio mast + water tank + generator shed
		P("cyl", Vector3(0.03, 2.4, 5), Vector3(1.4, 1.2, -1.4), "steel_dark"),
		P("box", Vector3(0.5, 0.02, 0.02), Vector3(1.4, 2.2, -1.4), "steel_dark"),
		P("box", Vector3(0.02, 0.02, 0.5), Vector3(1.4, 1.9, -1.4), "steel_dark"),
		P("cyl", Vector3(0.35, 0.55, 10), Vector3(1.05, 1.15, -0.4), "scrap_blue"),
		P("box", Vector3(0.05, 0.85, 0.05), Vector3(0.8, 0.42, -0.6), "steel_dark"),
		P("box", Vector3(0.05, 0.85, 0.05), Vector3(1.3, 0.42, -0.2), "steel_dark"),
		P("box", Vector3(0.05, 0.85, 0.05), Vector3(0.8, 0.42, -0.2), "steel_dark"),
		P("box", Vector3(0.05, 0.85, 0.05), Vector3(1.3, 0.42, -0.6), "steel_dark"),
		P("box", Vector3(0.9, 0.5, 0.7), Vector3(1.2, 0.25, 0.7), "corr_rust"),
		P("box", Vector3(0.95, 0.04, 0.75), Vector3(1.2, 0.52, 0.7), "corr_dark", Vector3(0, 0, -6)),
		P("box", Vector3(0.36, 0.22, 0.02), Vector3(-1.75, 2.2, -0.3), "team"),
		P("cyl", Vector3(0.02, 2.2, 5), Vector3(-1.75, 1.1, -0.48), "plank"),
	] + sandbags(Vector2(-1.85, 1.6), Vector2(-0.6, 1.6)) + sandbags(Vector2(0.4, 1.6), Vector2(1.85, 1.6)) + barrels(Vector3(1.4, 0.06, 1.25), 3) + crates(Vector3(-1.7, 0.06, 0.6), 4, 0.24) + tires(Vector3(0.5, 0.06, -1.6), 4)}
	TP_BUILDINGS["stash"] = {"fp": Vector2(3, 3), "parts": [
		P("box", Vector3(2.8, 0.05, 2.8), Vector3(0, 0.025, 0), "dirt"),
		P("box", Vector3(2.0, 0.05, 1.6), Vector3(-0.2, 1.05, -0.5), "corr_rust", Vector3(6, 0, 0)),
		P("cyl", Vector3(0.03, 1.05, 5), Vector3(-1.1, 0.52, -1.2), "plank"),
		P("cyl", Vector3(0.03, 1.05, 5), Vector3(0.7, 0.52, -1.2), "plank"),
		P("cyl", Vector3(0.03, 1.05, 5), Vector3(-1.1, 0.52, 0.2), "plank"),
		P("cyl", Vector3(0.03, 1.05, 5), Vector3(0.7, 0.52, 0.2), "plank"),
		P("box", Vector3(1.4, 0.55, 0.9), Vector3(-0.3, 0.3, -0.6), "tarp_blue"),
		P("box", Vector3(1.5, 0.05, 1.0), Vector3(-0.3, 0.6, -0.6), "tarp_blue", Vector3(0, 0, 4), "", 0.85),
		P("box", Vector3(0.6, 0.02, 0.4), Vector3(-0.7, 0.62, -0.5), "team"),
		P("box", Vector3(0.9, 0.35, 0.6), Vector3(0.9, 0.18, 0.75), "cloth"),                         # sacks
	] + crates(Vector3(-1.0, 0.05, 0.55), 6, 0.28) + barrels(Vector3(0.9, 0.05, -0.9), 6) + flag(Vector3(1.2, 0.05, 1.2), 1.3)}
	TP_BUILDINGS["camp"] = {"fp": Vector2(3, 3), "parts": [
		P("box", Vector3(2.8, 0.05, 2.8), Vector3(0, 0.025, 0), "dirt"),
		P("wedge", Vector3(1.3, 0.75, 1.0), Vector3(-0.6, 0.4, -0.6), "tarp", Vector3(0, 90, 0)),
		P("wedge", Vector3(1.1, 0.65, 0.9), Vector3(0.65, 0.35, -0.75), "team", Vector3(0, 90, 0)),
		P("wedge", Vector3(1.0, 0.6, 0.8), Vector3(0.75, 0.32, 0.3), "camo_olive", Vector3(0, 0, 0)),
		P("box", Vector3(0.2, 0.3, 0.02), Vector3(-0.6, 0.18, -0.09), "black"),
		P("cyl", Vector3(0.12, 0.25, 8), Vector3(-0.3, 0.13, 0.55), "rust"),
		P("box", Vector3(0.1, 0.08, 0.1), Vector3(-0.3, 0.3, 0.55), "fire"),
		P("box", Vector3(0.05, 0.6, 0.35), Vector3(-1.2, 0.35, 0.6), "plank"),                          # target board
		P("cyl", Vector3(0.11, 0.02, 10), Vector3(-1.17, 0.45, 0.6), "paint_w", Vector3(0, 0, 90)),
	] + sandbags(Vector2(-1.4, 1.35), Vector2(-0.2, 1.35)) + sandbags(Vector2(0.4, 1.35), Vector2(1.4, 1.35)) + flag(Vector3(1.3, 0.05, -1.3), 1.5) + crates(Vector3(0.1, 0.05, 0.9), 3, 0.22)}
	TP_BUILDINGS["chop_shop"] = {"fp": Vector2(4, 4), "parts": [
		P("box", Vector3(3.8, 0.06, 3.8), Vector3(0, 0.03, 0), "concrete_dark"),
		P("box", Vector3(3.2, 0.06, 2.2), Vector3(0, 1.35, -0.6), "corr_rust", Vector3(5, 0, 0)),
		P("box", Vector3(0.08, 1.35, 0.08), Vector3(-1.5, 0.67, -1.6), "steel_dark"),
		P("box", Vector3(0.08, 1.35, 0.08), Vector3(1.5, 0.67, -1.6), "steel_dark"),
		P("box", Vector3(0.08, 1.35, 0.08), Vector3(-1.5, 0.67, 0.4), "steel_dark"),
		P("box", Vector3(0.08, 1.35, 0.08), Vector3(1.5, 0.67, 0.4), "steel_dark"),
		P("box", Vector3(3.1, 1.3, 0.05), Vector3(0, 0.65, -1.65), "corr", Vector3.ZERO, "", 0.8),
		P("box", Vector3(0.05, 1.0, 1.4), Vector3(-1.55, 0.5, -0.95), "corr_rust"),
		P("box", Vector3(3.25, 0.18, 0.05), Vector3(0, 1.25, 0.42), "team"),
		# crane gantry
		P("box", Vector3(0.08, 2.0, 0.08), Vector3(1.75, 1.0, 1.4), "hazard"),
		P("box", Vector3(1.6, 0.08, 0.08), Vector3(1.0, 2.0, 1.4), "hazard"),
		P("box", Vector3(0.015, 0.7, 0.015), Vector3(0.4, 1.65, 1.4), "black"),
		P("box", Vector3(0.3, 0.2, 0.3), Vector3(0.4, 1.2, 1.4), "steel_dark"),
		# car hulk under repair + engine block + welding light
		P("box", Vector3(0.55, 0.25, 1.0), Vector3(-0.4, 0.25, -0.6), "scrap_red"),
		P("box", Vector3(0.5, 0.2, 0.4), Vector3(-0.4, 0.45, -0.75), "scrap_red", Vector3.ZERO, "", 0.8),
		P("box", Vector3(0.3, 0.25, 0.3), Vector3(0.6, 0.18, -0.9), "steel_dark"),
		P("box", Vector3(0.08, 0.08, 0.08), Vector3(0.45, 0.4, -0.9), "lamp"),
	] + tires(Vector3(-1.5, 0.06, 1.2), 6) + barrels(Vector3(0.9, 0.06, 1.0), 4) + crates(Vector3(-0.6, 0.06, 1.3), 3, 0.24)}
	TP_BUILDINGS["tunnel"] = {"fp": Vector2(2, 2), "parts": [
		P("cyl", Vector3(0.9, 0.08, 12), Vector3(0, 0.04, 0), "dirt"),
		P("cyl", Vector3(0.5, 0.04, 12), Vector3(0, 0.09, 0.2), "black"),
		P("box", Vector3(0.08, 0.55, 0.08), Vector3(-0.45, 0.28, 0.55), "plank"),
		P("box", Vector3(0.08, 0.55, 0.08), Vector3(0.45, 0.28, 0.55), "plank"),
		P("box", Vector3(1.05, 0.08, 0.08), Vector3(0, 0.55, 0.55), "plank"),
		P("box", Vector3(1.1, 0.05, 0.9), Vector3(0, 0.5, 0.15), "tarp", Vector3(-14, 0, 0)),
		P("box", Vector3(0.5, 0.02, 0.4), Vector3(0.2, 0.53, 0.1), "team", Vector3(-14, 0, 0)),
	] + sandbags(Vector2(-0.85, -0.7), Vector2(0.85, -0.7)) + sandbags(Vector2(-0.85, -0.7), Vector2(-0.85, 0.5), 1) + sandbags(Vector2(0.85, -0.7), Vector2(0.85, 0.5), 1) + [
		T("cyl", Vector3(0.14, 0.12, 8), Vector3(0, 0.62, -0.35), "steel_dark"),
		T("box", Vector3(0.26, 0.16, 0.03), Vector3(0, 0.76, -0.2), "scrap_green"),
		T("cyl", Vector3(0.022, 0.5, 6), Vector3(0, 0.75, -0.02), "gun", Vector3(90, 0, 0)),
	]}
	TP_BUILDINGS["workshop"] = {"fp": Vector2(3, 3), "parts": [
		P("box", Vector3(2.8, 0.05, 2.8), Vector3(0, 0.025, 0), "dirt"),
		P("box", Vector3(2.0, 1.0, 1.5), Vector3(-0.2, 0.5, -0.5), "mud"),
		P("box", Vector3(1.5, 0.8, 1.2), Vector3(-0.4, 1.4, -0.6), "plaster2"),
		P("box", Vector3(1.6, 0.06, 1.3), Vector3(-0.4, 1.83, -0.6), "corr_rust", Vector3(0, 0, -5)),
		P("box", Vector3(1.4, 0.05, 0.4), Vector3(-0.4, 1.0, 0.25), "plank"),                           # balcony
		P("box", Vector3(1.4, 0.2, 0.03), Vector3(-0.4, 1.12, 0.45), "plank"),
		P("box", Vector3(1.0, 0.5, 0.02), Vector3(-0.4, 1.5, 0.01), "team"),                            # banner
		P("box", Vector3(0.4, 0.6, 0.05), Vector3(-0.2, 0.3, 0.26), "plank"),
		P("box", Vector3(0.3, 0.22, 0.05), Vector3(0.55, 0.6, 0.26), "window"),
		P("hsph", Vector3(0.28, 0.12, 0.28), Vector3(0.2, 1.9, -0.9), "steel_light", Vector3(-50, 0, 0)),
		P("box", Vector3(0.5, 0.35, 0.4), Vector3(1.0, 0.18, 0.6), "camo_olive"),                      # generator
		P("cyl", Vector3(0.03, 0.4, 5), Vector3(1.15, 0.55, 0.5), "black"),
		P("box", Vector3(0.07, 0.07, 0.07), Vector3(1.0, 0.4, 0.82), "lamp"),
	] + sandbags(Vector2(-1.3, 1.2), Vector2(0.4, 1.2)) + barrels(Vector3(0.9, 0.05, -1.1), 3)}
	TP_BUILDINGS["bazaar"] = {"fp": Vector2(3, 3), "parts": [
		P("box", Vector3(2.8, 0.05, 2.8), Vector3(0, 0.025, 0), "dirt"),
		P("box", Vector3(1.8, 0.9, 1.0), Vector3(-0.3, 0.45, -0.85), "mud"),
		P("box", Vector3(1.9, 0.05, 1.1), Vector3(-0.3, 0.92, -0.85), "corr_dark"),
		P("box", Vector3(0.8, 0.03, 0.7), Vector3(-0.85, 0.75, 0.1), "team", Vector3(15, 0, 0)),          # stall awnings
		P("box", Vector3(0.8, 0.03, 0.7), Vector3(0.1, 0.75, 0.1), "paint_y", Vector3(15, 0, 0), "", 0.8),
		P("box", Vector3(0.8, 0.03, 0.7), Vector3(1.0, 0.7, -0.1), "red", Vector3(15, 0, 0)),
		P("box", Vector3(0.7, 0.3, 0.4), Vector3(-0.85, 0.15, 0.25), "plank"),
		P("box", Vector3(0.7, 0.3, 0.4), Vector3(0.1, 0.15, 0.25), "plank"),
		P("box", Vector3(0.7, 0.3, 0.4), Vector3(1.0, 0.15, 0.05), "plank"),
		P("box", Vector3(0.6, 0.01, 0.4), Vector3(0.4, 0.06, 0.95), "red"),                               # rug
		P("box", Vector3(0.3, 0.12, 0.2), Vector3(-0.85, 0.36, 0.25), "gun"),
		P("box", Vector3(0.25, 0.2, 0.2), Vector3(0.1, 0.4, 0.25), "crate"),
	] + crates(Vector3(1.0, 0.05, 1.0), 4, 0.22) + tires(Vector3(-1.2, 0.05, 1.1), 3) + barrels(Vector3(0.9, 0.05, -1.2), 2) + flag(Vector3(-1.3, 0.05, -1.3), 1.6)}
	TP_BUILDINGS["demo_trap"] = {"fp": Vector2(1, 1), "parts": [
		P("cyl", Vector3(0.1, 0.24, 8), Vector3(-0.1, 0.12, 0.0), "rust"),
		P("cyl", Vector3(0.1, 0.24, 8), Vector3(0.12, 0.12, 0.05), "barrel"),
		P("box", Vector3(0.18, 0.1, 0.12), Vector3(0.0, 0.05, -0.2), "crate"),
		P("box", Vector3(0.4, 0.008, 0.01), Vector3(0.0, 0.01, 0.2), "red", Vector3(0, 30, 0)),
		P("box", Vector3(0.05, 0.03, 0.03), Vector3(0.0, 0.11, -0.2), "fire"),
	]}
	TP_BUILDINGS["camo_net"] = {"fp": Vector2(1, 1), "parts": [
		P("cyl", Vector3(0.03, 0.9, 5), Vector3(0, 0.45, 0), "plank"),
		P("cone", Vector3(0.95, 0.55, 0.05), Vector3(0, 0.62, 0), "net"),
		P("cone", Vector3(0.75, 0.4, 0.05), Vector3(0.1, 0.66, 0.05), "camo_brown", Vector3(0, 40, 0), "", 0.9),
		P("box", Vector3(0.25, 0.02, 0.15), Vector3(0.0, 0.92, 0.0), "team"),
	]}
	TP_BUILDINGS["hole"] = {"fp": Vector2(2, 2), "parts": [
		P("cyl", Vector3(0.9, 0.06, 12), Vector3(0, 0.03, 0), "dirt"),
		P("cyl", Vector3(0.55, 0.03, 12), Vector3(0, 0.07, 0), "black"),
		P("box", Vector3(1.0, 0.08, 0.1), Vector3(0.1, 0.12, 0.3), "plank", Vector3(0, 25, 8)),
		P("box", Vector3(0.9, 0.08, 0.1), Vector3(-0.2, 0.1, -0.35), "plank", Vector3(0, -30, -6)),
		P("box", Vector3(0.3, 0.12, 0.25), Vector3(0.6, 0.08, -0.3), "mud_dark", Vector3(0, 20, 10)),
		P("box", Vector3(0.25, 0.1, 0.3), Vector3(-0.6, 0.07, 0.4), "mud", Vector3(0, -15, -8)),
		P("box", Vector3(0.12, 0.02, 0.12), Vector3(0, 0.08, 0), "team"),
	] + _scatter_rubble()}
	PROPS["salvage_crate"] = [
		P("box", Vector3(0.36, 0.26, 0.28), Vector3(0, 0.13, 0), "hazard"),
		P("box", Vector3(0.37, 0.04, 0.29), Vector3(0, 0.2, 0), "steel_dark"),
		P("cyl", Vector3(0.14, 0.07, 10), Vector3(0.28, 0.035, 0.18), "tire"),
		P("box", Vector3(0.3, 0.05, 0.12), Vector3(-0.22, 0.03, 0.2), "corr_rust", Vector3(0, 30, 10)),
		P("box", Vector3(0.2, 0.1, 0.16), Vector3(-0.2, 0.05, -0.2), "steel", Vector3(0, -20, 0)),
	]
	_save(PROPS["salvage_crate"], "res://view/neutral/salvage_crate.tscn", false, Vector2.ONE)

static func tires(c: Vector3, n: int) -> Array:
	var o: Array = []
	for i in n:
		o.append(P("cyl", Vector3(0.14, 0.08, 10), c + Vector3((i % 3) * 0.3, 0.04 + (i / 3) * 0.08, (i / 3) * 0.05), "tire"))
	return o

static func _scatter_rubble() -> Array:
	var o: Array = []
	for i in 7:
		var a := i * 0.9
		o.append(P("box", Vector3(0.14, 0.08, 0.1), Vector3(cos(a) * 0.8, 0.05, sin(a) * 0.75), "mud_dark" if i % 2 else "corr_rust", Vector3(0, i * 37, 12)))
	return o

static func _tierify(n: int, parts: Array) -> Array:
	var o: Array = []
	for p in parts:
		var q: Array = p.duplicate()
		while q.size() < 6:
			q.append("")
		q[5] = "tier%d" % n
		o.append(q)
	return o
