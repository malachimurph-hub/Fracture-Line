class_name ConstructionRig
extends Node3D
## Zero Hour-style construction site (M2.4), view only. WorldView attaches one to every structure
## that is still under construction, of any faction, and frees it on completion:
##  - the structure rises inside the rig (world-space clip with a glowing build edge; staged
##    BuildingViews clip their own hull),
##  - EU: steel tube scaffold, plank decks, debris netting, ladder, material stacks, concrete pad
##    with survey stakes and a tower crane on larger sites; welding sparks while work goes on,
##  - TPLA: lashed timber poles, sagging ledgers, tarps, leaning scrap, sandbags, a rope hoist
##    tripod and a staked dirt pad; dust and wood chips while work goes on,
##  - paused scaffolds (no builder) stand still: no sparks, dust or crane motion.
## Construction never shows damage: smoke, fire and soot only come from damage actually taken
## (WorldView passes HP relative to the HP the scaffold has reached so far).
const MAT := preload("res://view/materials/m3.tres")
const MAT_REVEAL := preload("res://view/materials/m3_reveal.tres")
const W_REVEAL := preload("res://view/materials/weathered_reveal.gdshader")
const SKIP := [&"Scaffold", &"DamageLight", &"DamageHeavy", &"Rubble", &"Foundation", &"HealthBarAnchor"]
const EDGE_EU := Color(1.6, 0.9, 0.35, 1.0)
const EDGE_TPLA := Color(1.1, 0.75, 0.4, 0.35)
static var _mesh_cache: Dictionary = {}   ## key -> {scaffold, pad, mast, jib}
static var _reveal_cache: Dictionary = {}  ## original material -> clip variant

var view: EntityView
var tpla := false
var bounds := AABB()           ## structure bounds in view space
var scaffold: MeshInstance3D
var pad: MeshInstance3D
var mast: MeshInstance3D
var jib: MeshInstance3D
var staged := false            ## BuildingView: clips its own hull
var _swaps: Array = []         ## [GeometryInstance3D, surface (-1 = override), previous material]
var _clip_geos: Array = []
var _prog := -1.0
var _idle_t := 99.0            ## seconds since construction last advanced
var _fx_t := 0.0
var _crane_t := 0.0
var stats := {"swapped": 0}

static func scaffold_top_for(b: AABB) -> float:
	return maxf(0.55, b.end.y * 0.88)

func setup(v: EntityView, faction: StringName) -> void:
	view = v
	name = "ConstructionRig"
	tpla = faction == &"tpla"
	staged = v is BuildingView
	bounds = _measure(v)
	var key := "%s_%d_%d_%d_%d" % [faction, roundi(bounds.position.x * 20), roundi(bounds.size.x * 20), roundi(bounds.size.z * 20), roundi(bounds.end.y * 20)]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _build_meshes(bounds, tpla)
	var ms: Dictionary = _mesh_cache[key]
	scaffold = _mi(ms["scaffold"], MAT_REVEAL)
	scaffold.set_instance_shader_parameter(&"rust_amt", 0.45 if tpla else 0.1)
	scaffold.set_instance_shader_parameter(&"reveal_y", -0.05)
	if not staged or v.get_node_or_null("Model/Foundation") == null:
		pad = _mi(ms["pad"], MAT)
	if ms.has("mast"):
		mast = _mi(ms["mast"], MAT)
		jib = _mi(ms["jib"], MAT)
		jib.position = ms["jib_pos"]
	if staged:
		(v as BuildingView).external_scaffold = true
		var h: GeometryInstance3D = (v as BuildingView).hull
		if h != null:
			h.set_instance_shader_parameter(&"reveal_edge", EDGE_TPLA if tpla else EDGE_EU)
	else:
		_swap_to_clip(v.model if v.model != null else v)

func _mi(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi

## Structure bounds in view space (hidden damage / rubble / scaffold parts excluded).
static func _measure(v: EntityView) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[v.model if v.model != null else v, Transform3D.IDENTITY if v.model == null else v.model.transform]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var xf: Transform3D = it[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var a: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
			out = a if first else out.merge(a)
			first = false
		for c in n.get_children():
			if c is Node3D and not (c.name in SKIP):
				stack.append([c, xf * (c as Node3D).transform])
	if first:
		out = AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.2, 1.6))
	out.position.y = maxf(0.0, out.position.y)
	out.size.y = maxf(0.4, out.size.y)
	return out

# ------------------------------------------------------------------ materials (legacy views)
func _swap_to_clip(root: Node) -> void:
	for c in root.get_children():
		if c is MeshInstance3D and not (c.name in SKIP):
			var mi: MeshInstance3D = c
			if mi.material_override != null:
				_swaps.append([mi, -1, mi.material_override])
				mi.material_override = _reveal_of(mi.material_override)
			elif mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var prev := mi.get_surface_override_material(s)
					var cur := prev if prev != null else mi.mesh.surface_get_material(s)
					_swaps.append([mi, s, prev])
					mi.set_surface_override_material(s, _reveal_of(cur))
			_clip_geos.append(mi)
		if c is Node3D and not (c.name in SKIP):
			_swap_to_clip(c)
	stats["swapped"] = _swaps.size()

## The clipping twin of a model material: weathered materials keep every parameter; plain
## StandardMaterial3D lamps / glass become an unlit-off weathered surface (no power on site).
static func _reveal_of(m: Material) -> Material:
	if m == null:
		m = load("res://view/materials/base.tres")
	if _reveal_cache.has(m):
		return _reveal_cache[m]
	var r: ShaderMaterial
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.ends_with("weathered.gdshader"):
		r = (m as ShaderMaterial).duplicate() as ShaderMaterial
		r.shader = W_REVEAL
	elif m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.ends_with("model_m3.gdshader"):
		r = MAT_REVEAL
	else:
		r = (load("res://view/materials/base.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		r.shader = W_REVEAL
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			r.set_shader_parameter("albedo", bm.albedo_color * 0.6)
			r.set_shader_parameter("use_vertex_color", bm.vertex_color_use_as_albedo)
	_reveal_cache[m] = r
	return r

func _restore() -> void:
	for sw in _swaps:
		var g: MeshInstance3D = sw[0]
		if not is_instance_valid(g):
			continue
		if int(sw[1]) < 0:
			g.material_override = sw[2]
		else:
			g.set_surface_override_material(int(sw[1]), sw[2])
	_swaps.clear()
	_clip_geos.clear()

## The owner swapped the team colour while a legacy view was clipped.
func refresh_team() -> void:
	if staged or view == null:
		return
	_restore()
	_swap_to_clip(view.model if view.model != null else view)
	_prog = -1.0

# ------------------------------------------------------------------ per frame
## k = construction progress 0..1; vfx may be null (headless).
func update(k: float, delta: float, vfx: Vfx, on_screen: bool) -> void:
	if k > _prog + 0.00001:
		if _prog >= 0.0:
			_idle_t = 0.0
		_prog = k
	else:
		_idle_t += delta
	var working := _idle_t < 0.6
	var top := scaffold_top_for(bounds)
	var rk := clampf((k - 0.12) / 0.83, 0.0, 1.0)
	var ry := bounds.position.y + (bounds.size.y + 0.06) * rk - 0.02
	# the scaffold goes up first, then climbs about one lift ahead of the rising structure
	var sy := maxf(top * 0.4 * clampf(k / 0.12, 0.0, 1.0), ry + 0.5)
	scaffold.set_instance_shader_parameter(&"reveal_y", minf(top + 0.3, sy) - 0.03)
	if not staged:
		var wy := view.global_position.y + ry
		for g in _clip_geos:
			(g as GeometryInstance3D).set_instance_shader_parameter(&"reveal_wy", wy)
			(g as GeometryInstance3D).set_instance_shader_parameter(&"reveal_edge", (EDGE_TPLA if tpla else EDGE_EU) * Color(1, 1, 1, 1.0 if working else 0.35))
	elif (view as BuildingView).hull != null:
		(view as BuildingView).hull.set_instance_shader_parameter(&"reveal_edge", (EDGE_TPLA if tpla else EDGE_EU) * Color(1, 1, 1, 1.0 if working else 0.35))
	if jib != null and working:
		_crane_t += delta
		jib.rotation.y = sin(_crane_t * 0.35) * 1.1
	if vfx == null or not on_screen or not working:
		return
	_fx_t += delta
	var every := 0.34 if tpla else 0.22
	if _fx_t < every:
		return
	_fx_t = 0.0
	# a point on the rising build edge (or the scaffold while it goes up)
	var y := maxf(0.08, ry if rk > 0.0 else top * clampf(k / 0.25, 0.0, 1.0))
	var side := randi() % 4
	var u := randf()
	var lp := Vector3(lerpf(bounds.position.x, bounds.end.x, u), y, bounds.end.z if side == 0 else bounds.position.z)
	if side >= 2:
		lp = Vector3(bounds.end.x if side == 2 else bounds.position.x, y, lerpf(bounds.position.z, bounds.end.z, u))
	var wp := view.global_transform * lp
	if tpla:
		vfx.dust(wp, 0.35, 0.35)
		if randf() < 0.3:
			vfx.chips(wp, 3)
	else:
		vfx.sparks(wp, Vector3(0, 0.6, 0), 7, 1.6)

## A builder advanced the site within the last 0.6 s (paused scaffolds stand still).
func working() -> bool:
	return _idle_t < 0.6

func finish() -> void:
	_restore()
	if staged and is_instance_valid(view):
		(view as BuildingView).external_scaffold = false
	queue_free()

# ------------------------------------------------------------------ geometry
static func _build_meshes(b: AABB, is_tpla: bool) -> Dictionary:
	var out := {}
	var top := scaffold_top_for(b)
	var off := 0.14
	var x0 := b.position.x - off
	var x1 := b.end.x + off
	var z0 := b.position.z - off
	var z1 := b.end.z + off
	var g := RigGeo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(b.size.x * 1000.0 + b.size.z * 37.0 + top * 11.0))
	var spacing := 0.7 if is_tpla else 0.68
	var nx := maxi(2, ceili((x1 - x0) / spacing))
	var nz := maxi(2, ceili((z1 - z0) / spacing))
	var poles: Array = []
	for i in nx + 1:
		var x := lerpf(x0, x1, float(i) / nx)
		poles.append(Vector3(x, 0, z0))
		poles.append(Vector3(x, 0, z1))
	for i in range(1, nz):
		var z := lerpf(z0, z1, float(i) / nz)
		poles.append(Vector3(x0, 0, z))
		poles.append(Vector3(x1, 0, z))
	var lev := 0.45 if is_tpla else 0.42
	var levels: Array = []
	var yy := lev
	while yy < top - 0.05:
		levels.append(yy)
		yy += lev
	levels.append(top)
	var corners := [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
	if b.end.y < 0.5:
		# low emplacements (minefield, traps): marker stakes and tape, no scaffold
		for c in corners:
			g.color("#6d5034" if is_tpla else "#e0e0dc", RigGeo.WOOD)
			g.tube(c, c + Vector3(0, 0.25, 0), 0.01)
		g.color("#d8c79a" if is_tpla else "#e8642a", RigGeo.CANVAS)
		for e in 4:
			g.tube(corners[e] + Vector3(0, 0.2, 0), corners[(e + 1) % 4] + Vector3(0, 0.2, 0), 0.004)
	elif not is_tpla:
		# --- EU: galvanised tube scaffold
		g.color("#a9afb3", RigGeo.STEEL)
		for p in poles:
			g.tube(p + Vector3(0, 0.0, 0), p + Vector3(0, top + 0.12, 0), 0.011)
			g.box(p + Vector3(0, 0.01, 0), Vector3(0.07, 0.02, 0.07))   # base plate
		for y in levels:
			for e in 4:
				g.tube(corners[e] + Vector3(0, y, 0), corners[(e + 1) % 4] + Vector3(0, y, 0), 0.008)
			g.tube(Vector3(x0, y + 0.22, z1), Vector3(x1, y + 0.22, z1), 0.006)   # guard rail
		# face braces (zig-zag)
		for e in 4:
			var a: Vector3 = corners[e]
			var c: Vector3 = corners[(e + 1) % 4]
			for li in levels.size():
				var ya: float = 0.0 if li == 0 else levels[li - 1]
				var yb: float = levels[li]
				var t0 := 0.0 if li % 2 == 0 else 1.0
				g.tube(a.lerp(c, t0) + Vector3(0, ya, 0), a.lerp(c, 0.5) + Vector3(0, yb, 0), 0.006)
		# plank decks front and back, a yellow toe board on the front
		for y in levels:
			g.color("#8a6a43", RigGeo.WOOD)
			g.box(Vector3((x0 + x1) * 0.5, y + 0.012, z1 - 0.05), Vector3(x1 - x0, 0.016, 0.085))
			g.box(Vector3((x0 + x1) * 0.5, y + 0.012, z0 + 0.05), Vector3(x1 - x0, 0.016, 0.085))
			g.color("#d8a531", RigGeo.PAINT)
			g.box(Vector3((x0 + x1) * 0.5, y + 0.035, z1 + 0.004), Vector3(x1 - x0, 0.03, 0.006))
		# debris netting on the back and left faces (keeps the front open to see it rise)
		g.color("#3f6a58", RigGeo.CANVAS)
		g.sheet(Vector3(x0, 0.25, z0 - 0.012), Vector3(x1, 0.25, z0 - 0.012), top - 0.2, 0.004)
		g.sheet(Vector3(x0 - 0.012, 0.25, z0), Vector3(x0 - 0.012, 0.25, lerpf(z0, z1, 0.6)), top - 0.2, 0.004)
		# ladder at the front-right corner
		g.color("#c9c2b0", RigGeo.STEEL)
		var lx := x1 - 0.2
		g.tube(Vector3(lx - 0.06, 0, z1 + 0.05), Vector3(lx - 0.06, top + 0.2, z1 + 0.05), 0.006)
		g.tube(Vector3(lx + 0.06, 0, z1 + 0.05), Vector3(lx + 0.06, top + 0.2, z1 + 0.05), 0.006)
		var ry := 0.12
		while ry < top + 0.15:
			g.tube(Vector3(lx - 0.06, ry, z1 + 0.05), Vector3(lx + 0.06, ry, z1 + 0.05), 0.004)
			ry += 0.1
		# material stacks: steel beams, pipe bundle, cement pallet
		g.color("#6c7378", RigGeo.STEEL)
		for i in 3:
			g.box(Vector3(x0 + 0.35, 0.03 + i * 0.045, z1 + 0.2 - i * 0.01), Vector3(0.6, 0.04, 0.05))
		g.color("#8f969a", RigGeo.STEEL)
		for i in 4:
			g.tube(Vector3(x1 - 0.1, 0.03 + (i % 2) * 0.04, z0 + 0.2 + i * 0.045), Vector3(x1 - 0.1, 0.03 + (i % 2) * 0.04, z0 + 0.7 + i * 0.045), 0.018)
		g.color("#8a6a43", RigGeo.WOOD)
		g.box(Vector3(x0 + 0.95, 0.03, z1 + 0.18), Vector3(0.28, 0.05, 0.22))
		g.color("#c9c3b4", RigGeo.SANDBAG)
		g.box(Vector3(x0 + 0.95, 0.1, z1 + 0.18), Vector3(0.24, 0.1, 0.18))
	else:
		# --- TPLA: lashed timber poles, sagging ledgers, tarps, scrap
		var jit: Array = []
		for p in poles:
			var lean := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
			var h := top + rng.randf_range(0.0, 0.22)
			jit.append(lean)
			g.color(["#6d5034", "#7c5c3b", "#5f4630"][rng.randi() % 3], RigGeo.WOOD)
			g.tube(p, p + Vector3(0, h, 0) + lean, 0.016)
		for y in levels:
			g.color("#9a7a50", RigGeo.WOOD)
			for e in 4:
				var a: Vector3 = corners[e] + Vector3(0, y, 0)
				var c: Vector3 = corners[(e + 1) % 4] + Vector3(0, y, 0)
				var m := a.lerp(c, 0.5) + Vector3(0, -0.03, 0)   # sags in the middle
				g.tube(a, m, 0.011)
				g.tube(m, c, 0.011)
			# a few loose boards for a walkway on the front
			g.color("#a88b5c", RigGeo.WOOD)
			var nb := maxi(2, int((x1 - x0) / 0.34))
			for i in nb:
				if rng.randf() < 0.35:
					continue
				var bx := lerpf(x0 + 0.15, x1 - 0.15, (i + 0.5) / nb)
				g.box(Vector3(bx, y + 0.015, z1 - 0.06), Vector3(0.26, 0.018, 0.1), rng.randf_range(-0.12, 0.12))
		# X bracing on the sides (rope-lashed sticks)
		g.color("#86663f", RigGeo.WOOD)
		g.tube(Vector3(x0, 0.05, z0), Vector3(x0, top * 0.9, z1), 0.009)
		g.tube(Vector3(x0, 0.05, z1), Vector3(x0, top * 0.9, z0), 0.009)
		g.tube(Vector3(x1, 0.05, z0), Vector3(x1, top * 0.9, z1), 0.009)
		# tarps: dusty khaki on the back, olive on the left, a sunshade across one top corner
		g.color("#a8936a", RigGeo.CANVAS)
		g.sheet(Vector3(x0, top * 0.35, z0 - 0.02), Vector3(lerpf(x0, x1, 0.7), top * 0.35, z0 - 0.02), top * 0.6, 0.006, -0.02)
		g.color("#6f7a55", RigGeo.CANVAS)
		g.sheet(Vector3(x0 - 0.02, 0.15, lerpf(z0, z1, 0.15)), Vector3(x0 - 0.02, 0.15, lerpf(z0, z1, 0.65)), top * 0.55, 0.006)
		g.color("#b9a37a", RigGeo.CANVAS)
		g.obox(Vector3(lerpf(x0, x1, 0.75), top + 0.1, lerpf(z0, z1, 0.25)), Vector3((x1 - x0) * 0.22, 0.006, (z1 - z0) * 0.22), Basis(Vector3(1, 0, 0.3).normalized(), 0.12))
		# leaning scrap sheets, sandbags, mud-brick stack, oil drums
		g.color("#7a5236", RigGeo.SCRAP)
		g.obox(Vector3(x1 + 0.06, 0.22, lerpf(z0, z1, 0.6)), Vector3(0.01, 0.22, 0.2), Basis(Vector3.FORWARD, 0.25))
		g.obox(Vector3(lerpf(x0, x1, 0.3), 0.2, z1 + 0.07), Vector3(0.22, 0.2, 0.01), Basis(Vector3.RIGHT, -0.22))
		for c in corners:
			for i in 2:
				g.color("#9c8a62", RigGeo.SANDBAG)
				g.box(c + Vector3(0, 0.035 + i * 0.06, 0), Vector3(0.2, 0.06, 0.11), rng.randf_range(0, PI))
		g.color("#b08a6a", RigGeo.CONCRETE)
		for i in 3:
			for j in 2:
				g.box(Vector3(x0 + 0.25 + j * 0.13, 0.03 + i * 0.055, z1 + 0.2), Vector3(0.12, 0.05, 0.09))
		g.color("#4a4038", RigGeo.SCRAP)
		for i in 2:
			g.obox(Vector3(x1 - 0.15 - i * 0.16, 0.1, z1 + 0.18), Vector3(0.065, 0.1, 0.065), Basis(Vector3.UP, 0.785))
		# rope hoist tripod at the back-right corner with a hanging bucket
		var hc := Vector3(x1 - 0.1, 0, z0 + 0.1)
		var apex := hc + Vector3(0, top + 0.55, 0)
		g.color("#6d5034", RigGeo.WOOD)
		for i in 3:
			var a2 := TAU * i / 3.0 + 0.4
			g.tube(hc + Vector3(cos(a2), 0, sin(a2)) * 0.32, apex, 0.013)
		g.color("#cdb98d", RigGeo.CANVAS)
		g.tube(apex, apex - Vector3(0, top * 0.55, 0), 0.004)
		g.color("#4a4038", RigGeo.SCRAP)
		g.box(apex - Vector3(0, top * 0.55 + 0.06, 0), Vector3(0.1, 0.1, 0.1))
	out["scaffold"] = g.commit(MAT_REVEAL)
	# --- pad (construction ground) slightly larger than the rig
	var p := RigGeo.new()
	var px0 := x0 - 0.12
	var px1 := x1 + 0.12
	var pz0 := z0 - 0.12
	var pz1 := z1 + 0.12
	if is_tpla:
		p.color("#8d7a5c", RigGeo.CONCRETE)
		p.box(Vector3((px0 + px1) * 0.5, 0.015, (pz0 + pz1) * 0.5), Vector3(px1 - px0, 0.03, pz1 - pz0))
		p.color("#7a6a4e", RigGeo.CONCRETE)
		p.box(Vector3(px0 + 0.4, 0.04, pz1 - 0.3), Vector3(0.5, 0.03, 0.35), 0.3)
		for c in [Vector3(px0, 0, pz0), Vector3(px1, 0, pz0), Vector3(px1, 0, pz1), Vector3(px0, 0, pz1)]:
			p.color("#6d5034", RigGeo.WOOD)
			p.tube(c, c + Vector3(0, 0.22, 0), 0.012)
		p.color("#d8c79a", RigGeo.CANVAS)
		p.tube(Vector3(px0, 0.18, pz1), Vector3(px1, 0.18, pz1), 0.003)
		p.tube(Vector3(px1, 0.18, pz0), Vector3(px1, 0.18, pz1), 0.003)
	else:
		p.color("#a39b8b", RigGeo.CONCRETE)
		p.box(Vector3((px0 + px1) * 0.5, 0.02, (pz0 + pz1) * 0.5), Vector3(px1 - px0, 0.04, pz1 - pz0))
		for c in [Vector3(px0 + 0.06, 0, pz0 + 0.06), Vector3(px1 - 0.06, 0, pz0 + 0.06), Vector3(px1 - 0.06, 0, pz1 - 0.06), Vector3(px0 + 0.06, 0, pz1 - 0.06)]:
			p.color("#d8a531", RigGeo.PAINT)
			p.box(c + Vector3(0, 0.045, 0), Vector3(0.12, 0.01, 0.12))
			p.color("#e0e0dc", RigGeo.WOOD)
			p.tube(c + Vector3(0.1, 0, 0.1), c + Vector3(0.1, 0.2, 0.1), 0.008)
			p.color("#e8642a", RigGeo.PAINT)
			p.box(c + Vector3(0.1, 0.2, 0.1), Vector3(0.022, 0.04, 0.022))
	out["pad"] = p.commit(MAT)
	# --- EU tower crane on bigger sites (mast fixed, jib turns while work goes on)
	if not is_tpla and (b.size.x >= 2.4 or b.size.z >= 2.4 or b.end.y > 1.7):
		var cm := RigGeo.new()
		var mc := Vector3(x0 - 0.05, 0, z0 - 0.05)
		var mh := top + 1.0
		var s := 0.07
		cm.color("#e0b020", RigGeo.PAINT)
		for q in [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s)]:
			cm.tube(mc + q, mc + q + Vector3(0, mh, 0), 0.012)
		var hy := 0.0
		var flip := false
		while hy < mh - 0.15:
			var a3 := Vector3(-s, hy, -s) if not flip else Vector3(s, hy, -s)
			var b3 := Vector3(s, hy + 0.18, -s) if not flip else Vector3(-s, hy + 0.18, -s)
			cm.tube(mc + a3, mc + b3, 0.005)
			cm.tube(mc + a3 + Vector3(0, 0, 2 * s), mc + b3 + Vector3(0, 0, 2 * s), 0.005)
			hy += 0.18
			flip = not flip
		cm.color("#6c7378", RigGeo.CONCRETE)
		cm.box(mc + Vector3(0, 0.05, 0), Vector3(0.36, 0.1, 0.36))
		out["mast"] = cm.commit(MAT)
		var jm := RigGeo.new()
		var reach := maxf(b.size.x, b.size.z) * 0.95 + 0.4
		jm.color("#e0b020", RigGeo.PAINT)
		jm.tube(Vector3(0, 0.0, 0), Vector3(reach, 0.0, 0.0), 0.022)
		jm.tube(Vector3(0, 0.14, 0), Vector3(reach * 0.8, 0.02, 0.0), 0.008)
		jm.tube(Vector3(0, 0.0, 0), Vector3(-0.55, 0.0, 0), 0.022)
		jm.box(Vector3(0, 0.12, 0), Vector3(0.12, 0.28, 0.12))
		jm.color("#9a948a", RigGeo.CONCRETE)
		jm.box(Vector3(-0.5, -0.06, 0), Vector3(0.16, 0.14, 0.16))
		jm.color("#d0cfc8", RigGeo.GLASS)
		jm.box(Vector3(0.1, -0.08, 0.09), Vector3(0.1, 0.1, 0.06))
		jm.color("#ff3b2a", RigGeo.LAMP)
		jm.box(Vector3(0, 0.28, 0), Vector3(0.03, 0.03, 0.03))
		var hx := reach * 0.62
		jm.color("#2b2a28", RigGeo.DARK)
		jm.tube(Vector3(hx, 0, 0), Vector3(hx, -mh * 0.45, 0), 0.003)
		jm.color("#7a8288", RigGeo.STEEL)
		jm.box(Vector3(hx, -mh * 0.45 - 0.03, 0), Vector3(0.45, 0.035, 0.05))
		out["jib"] = jm.commit(MAT)
		out["jib_pos"] = mc + Vector3(0, mh, 0)
	return out
