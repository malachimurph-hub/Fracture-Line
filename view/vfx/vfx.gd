class_name Vfx
extends Node3D
## Pooled, view-only effects (weapon rounds live in WeaponFx): muzzle flashes, explosions, rings, scorch decals,
## command markers. Never touches the simulation. Respects the "reduce flashing" idea by
## keeping flashes small and short.

var items: Array = []      ## [{node, t, life, kind, data}]
var pool: Dictionary = {}  ## kind -> Array[MeshInstance3D]
var _box := BoxMesh.new()
var _sph := SphereMesh.new()
var _quad := PlaneMesh.new()
var _ring: ArrayMesh
var smoke: ParticleLayer
var fire: ParticleLayer
var debris: ParticleLayer
var spark_layer: ParticleLayer   ## M2.4: falling bright sparks (welding, bullet strikes on metal)
var decals: MultiMeshInstance3D
var decal_mat: ShaderMaterial
var _decal_next := 0
var _decal_t: PackedFloat32Array
var _decal_age_acc := 0.0
var sources: Array = []    ## lingering smoke columns [pos, t_left, strength, acc]
var rust: Array = []       ## lingering rust (corrosive) clouds [pos, radius, t_left, acc]
const RUST := Color("#9fbf3a")
const DECAL_CAP := 160
const SMOKE := Color("#3d3833")
const DUST := Color("#c2a77e")
## M2.7: the menu background battle tones explosions / smoke down so they never blanket the
## view (1.0 in matches). Scales particle counts and smoke size/opacity, never the sim.
var fx_mul := 1.0

func _ready() -> void:
	_box.size = Vector3.ONE
	_sph.radius = 0.5
	_sph.height = 1.0
	_sph.radial_segments = 10
	_sph.rings = 5
	_quad.size = Vector2.ONE
	_ring = Palette.ring_mesh("circle", 0.12)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://view/vfx/puff.gdshader")
	sm.render_priority = 2
	var fm := ShaderMaterial.new()
	fm.shader = load("res://view/vfx/puff_add.gdshader")
	fm.render_priority = 3
	smoke = ParticleLayer.new()
	smoke.setup(700, quad, sm, true, -0.15, 0.6)
	add_child(smoke)
	fire = ParticleLayer.new()
	fire.setup(320, quad, fm, true, -0.6, 2.2)
	add_child(fire)
	var chunk := PropMeshes.make("debris_chunk")
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.vertex_color_is_srgb = true
	dm.roughness = 0.9
	debris = ParticleLayer.new()
	debris.setup(240, chunk, dm, false, 9.8, 0.3)
	add_child(debris)
	spark_layer = ParticleLayer.new()
	spark_layer.setup(260, quad, fm, true, 9.0, 0.8)
	add_child(spark_layer)
	decal_mat = ShaderMaterial.new()
	decal_mat.shader = load("res://view/vfx/decal.gdshader")
	decal_mat.render_priority = -1
	var dq := PlaneMesh.new()
	dq.size = Vector2(2, 2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = dq
	mm.instance_count = DECAL_CAP
	for i in DECAL_CAP:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0)))
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	decals = MultiMeshInstance3D.new()
	decals.multimesh = mm
	decals.material_override = decal_mat
	decals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decals.custom_aabb = AABB(Vector3(-50, -10, -50), Vector3(400, 40, 400))
	add_child(decals)
	_decal_t.resize(DECAL_CAP)

func set_fog(tex: Texture2D, map_size: Vector2) -> void:
	decal_mat.set_shader_parameter("fog_tex", tex)
	decal_mat.set_shader_parameter("map_size", map_size)

## kind: 0 scorch, 1 crater, 2 rubble
func decal(p: Vector3, size: float, kind: int) -> void:
	var i := _decal_next
	_decal_next = (_decal_next + 1) % DECAL_CAP
	var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(size, 1, size))
	decals.multimesh.set_instance_transform(i, Transform3D(b, Vector3(p.x, 0.035 + 0.002 * (i % 8), p.z)))
	decals.multimesh.set_instance_custom_data(i, Color(kind, randf(), 0.92, 0))
	_decal_t[i] = 0.0

func muzzle(p: Vector3, dir: Vector3, size: float) -> void:
	var d := dir.normalized()
	for k in 3:
		fire.emit(p + d * (0.1 + k * 0.12) * size * 2.0, d * 1.5, 0.07, size * (0.9 - k * 0.2), size * 0.3, Color("#fff1b8"), Color(1.0, 0.55, 0.15, 0.0), 1.0)
	smoke.emit(p + d * 0.2, d * 0.6 + Vector3(0, 0.4, 0), 0.6, size * 0.6, size * 1.6, Color(0.55, 0.52, 0.48, 0.45), Color(0.55, 0.52, 0.48, 0.0))

func impact(p: Vector3, size: float, dusty: bool = true) -> void:
	fire.emit(p, Vector3.ZERO, 0.08, size * 0.7, size * 0.2, Color("#ffe3a0"), Color(1, 0.5, 0.1, 0), 1.0)
	if dusty:
		for k in 2:
			smoke.emit(p + Vector3(randf_range(-0.1, 0.1), 0.05, randf_range(-0.1, 0.1)), Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3)), 0.7, size * 0.5, size * 1.4, Color(DUST, 0.7), Color(DUST, 0.0))

func dust(p: Vector3, size: float, amount: float = 0.55) -> void:
	smoke.emit(p + Vector3(0, 0.08, 0), Vector3(randf_range(-0.25, 0.25), 0.35, randf_range(-0.25, 0.25)), 1.1, size * 0.5, size * 1.6, Color(DUST, amount), Color(DUST, 0.0))

## Bright sparks spraying from p (welding on a construction site, rounds striking metal).
func sparks(p: Vector3, dir: Vector3, n: int, speed: float) -> void:
	for k in n:
		var v := dir + Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)) * speed
		spark_layer.emit(p, v, randf_range(0.25, 0.5), 0.045, 0.015, Color("#fff4c8"), Color(1.0, 0.55, 0.1, 0.0), 1.0)

## Wood chips / grit kicked up by TPLA labourers on a site.
func chips(p: Vector3, n: int) -> void:
	for k in n:
		debris.emit(p, Vector3(randf_range(-1.2, 1.2), randf_range(1.2, 2.4), randf_range(-1.2, 1.2)), 1.2, 0.035, 0.03, Color("#a88b5c"), Color("#7c5c3b"))

func trail(p: Vector3) -> void:
	smoke.emit(p, Vector3(0, 0.25, 0), 0.9, 0.12, 0.4, Color(0.8, 0.78, 0.75, 0.55), Color(0.8, 0.78, 0.75, 0.0))

func flak_burst(p: Vector3) -> void:
	fire.emit(p, Vector3.ZERO, 0.09, 0.45, 0.2, Color("#fff6d0"), Color(1, 0.6, 0.2, 0), 1.0)
	smoke.emit(p, Vector3(0, 0.1, 0), 1.2, 0.3, 0.8, Color(0.12, 0.12, 0.12, 0.8), Color(0.12, 0.12, 0.12, 0.0))

## Burning building / wreck smoke column, called periodically by the world view.
func smoke_puff(p: Vector3, strength: float, burning: bool) -> void:
	if fx_mul < 1.0 and randf() > fx_mul:
		return
	var w := Vector3(0.35, 0, 0.12)   # light prevailing wind
	smoke.emit(p + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25)), Vector3(0, 1.1 + strength * 0.6, 0) + w, 2.6 + strength, 0.35 + strength * 0.25, 1.4 + strength, Color(0.16, 0.15, 0.14, 0.75), Color(0.35, 0.33, 0.31, 0.0))
	if burning:
		fire.emit(p + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), Vector3(0, 1.2, 0), 0.45, 0.35 + strength * 0.2, 0.1, Color("#ffb347"), Color(0.9, 0.25, 0.05, 0.0), 1.0)

func building_destroyed(p: Vector3, fp: Vector2) -> void:
	var r := maxf(fp.x, fp.y) * 0.5
	for k in 3:
		explosion(p + Vector3(randf_range(-r, r) * 0.6, 0, randf_range(-r, r) * 0.6), 1.2 + r * 0.4)
	for k in 26:
		debris.emit(p + Vector3(randf_range(-r, r), 0.5, randf_range(-r, r)), Vector3(randf_range(-3, 3), randf_range(3, 7), randf_range(-3, 3)), 3.5, randf_range(0.12, 0.3), randf_range(0.12, 0.3), Color("#8d877c"), Color("#5a5650"))
	decal(p, r * 1.15, 2)
	sources.append([p, 14.0, clampf(r * 0.6, 0.6, 1.4), 0.0])

## TPLA corrosive "rust" cloud: sickly yellow-green haze that lingers over the zone.
func rust_cloud(p: Vector3, radius: float, secs: float) -> void:
	rust.append([p, radius, secs, 0.0])
	decal(p, radius * 0.8, 0)

func _rust_puff(p: Vector3, radius: float) -> void:
	var a := randf() * TAU
	var d := sqrt(randf()) * radius
	var q := p + Vector3(cos(a) * d, 0.1, sin(a) * d)
	smoke.emit(q, Vector3(randf_range(-0.15, 0.15), 0.25, randf_range(-0.15, 0.15)), 2.2, 0.35, 1.3, Color(RUST, 0.55), Color(0.45, 0.5, 0.2, 0.0))

## Suicide truck / demo charge: big fireball with a shock ring.
func big_blast(p: Vector3, radius: float) -> void:
	explosion(p, 1.6 + radius * 0.25)
	explosion(p + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), 1.2)
	ring(p, radius, Color("#ffcf7a"), 0.5, false)
	decal(p, radius * 0.7, 1)

## Salvage pickup: brief sparkle and a rising ring in the team colour.
func salvage_fx(p: Vector3, col: Color) -> void:
	flash(p + Vector3(0, 0.5, 0), Color("#fff3c4"), 0.35, 0.2)
	ring(p, 1.0, col, 0.6, true)
	for k in 6:
		fire.emit(p + Vector3(0, 0.3, 0), Vector3(randf_range(-1.2, 1.2), randf_range(1.5, 3.0), randf_range(-1.2, 1.2)), 0.4, 0.08, 0.02, Color("#ffe9a0"), Color(1, 0.6, 0.2, 0), 1.0)

func _take(kind: String, mesh: Mesh) -> MeshInstance3D:
	var arr: Array = pool.get(kind, [])
	var mi: MeshInstance3D
	if arr.is_empty():
		mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	else:
		mi = arr.pop_back()
		mi.visible = true
	return mi

func _add(kind: String, mi: MeshInstance3D, life: float, data: Dictionary = {}) -> void:
	items.append({"n": mi, "t": 0.0, "life": life, "k": kind, "d": data})

func flash(p: Vector3, col: Color, size: float, life: float = 0.12) -> void:
	if items.size() > 400:
		return
	var mi := _take("sph", _sph)
	mi.position = p
	mi.scale = Vector3.ONE * size
	mi.material_override = Palette.flat(col, 0.85)
	_add("sph", mi, life, {"grow": size * 0.6, "s": size})

func explosion(p: Vector3, size: float) -> void:
	var nf := int(clampf(6 + size * 5, 6, 18) * fx_mul)
	var sa := 0.85 * clampf(fx_mul * 1.2, 0.0, 1.0)
	for k in nf:
		var d := Vector3(randf_range(-1, 1), randf_range(0.3, 1.3), randf_range(-1, 1))
		fire.emit(p + Vector3(0, 0.25, 0) + d * 0.15 * size, d * 2.2 * size, randf_range(0.25, 0.5), size * randf_range(0.35, 0.6), size * 0.9, Color("#fff0b0"), Color(0.85, 0.22, 0.04, 0.0), 1.0)
	for k in int(nf * 0.7):
		var d2 := Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1))
		smoke.emit(p + Vector3(0, 0.4, 0) + d2 * 0.2 * size, d2 * 1.0 * size, randf_range(1.6, 2.6) * fx_mul, size * 0.45, size * 1.7 * fx_mul, Color(0.2, 0.18, 0.16, sa), Color(0.42, 0.4, 0.37, 0.0))
	for k in int(clampf(size * 5, 2, 10)):
		debris.emit(p + Vector3(0, 0.3, 0), Vector3(randf_range(-2.5, 2.5), randf_range(2.5, 5.5), randf_range(-2.5, 2.5)) * sqrt(size), 2.0, randf_range(0.06, 0.14) * sqrt(size), 0.08, Color("#3b3733"), Color("#2a2725"))
	for k in int(6 * fx_mul):
		var a := k * TAU / 6.0
		smoke.emit(p + Vector3(cos(a), 0.1, sin(a)) * 0.3 * size, Vector3(cos(a), 0.15, sin(a)) * 2.0 * size, 1.0, size * 0.4, size * 1.1, Color(DUST, 0.6), Color(DUST, 0.0))
	decal(p, size * 0.9, 1 if size >= 1.2 else 0)

func scorch_old(p: Vector3, size: float) -> void:
	var mi := _take("quad", _quad)
	mi.position = p + Vector3(0, 0.03, 0)
	mi.scale = Vector3(size * 1.4, 1, size * 1.4)
	mi.rotation = Vector3(0, fmod(p.x * 7.0 + p.z * 3.0, TAU), 0)
	mi.material_override = Palette.flat(Color(0.08, 0.07, 0.06), 0.6)
	_add("quad", mi, 60.0, {"fade": true})

func ring(p: Vector3, radius: float, col: Color, life: float = 0.6, shrink: bool = true) -> void:
	var mi := _take("ring", _ring)
	mi.position = p + Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * radius
	mi.material_override = Palette.flat(col, 0.9)
	_add("ring", mi, life, {"r": radius, "shrink": shrink})

func scorch(p: Vector3, size: float) -> void:
	decal(p, size * 0.7, 0)

func _process(delta: float) -> void:
	# lingering smoke columns from destroyed buildings
	var ks: Array = []
	for src in sources:
		src[1] -= delta
		src[3] += delta
		if src[3] > 0.18:
			src[3] = 0.0
			smoke_puff(src[0], src[2] * clampf(src[1] / 6.0, 0.2, 1.0), src[1] > 8.0)
		if src[1] > 0.0:
			ks.append(src)
	sources = ks
	var kr: Array = []
	for rz in rust:
		rz[2] -= delta
		rz[3] += delta
		if rz[3] > 0.12:
			rz[3] = 0.0
			_rust_puff(rz[0], rz[1])
		if rz[2] > 0.0:
			kr.append(rz)
	rust = kr
	# decals fade out after ~90 s
	_decal_age_acc += delta
	if _decal_age_acc > 1.0:
		var mm := decals.multimesh
		for i in DECAL_CAP:
			_decal_t[i] += _decal_age_acc
			if _decal_t[i] > 75.0 and _decal_t[i] < 92.0:
				var c := mm.get_instance_custom_data(i)
				c.b = clampf((90.0 - _decal_t[i]) / 15.0, 0.0, 0.92)
				mm.set_instance_custom_data(i, c)
		_decal_age_acc = 0.0
	var keep: Array = []
	for it in items:
		it["t"] += delta
		var mi: MeshInstance3D = it["n"]
		var k: float = it["t"] / it["life"]
		if k >= 1.0:
			mi.visible = false
			if not pool.has(it["k"]):
				pool[it["k"]] = []
			pool[it["k"]].append(mi)
			continue
		var d: Dictionary = it["d"]
		if d.has("grow"):
			mi.scale = Vector3.ONE * (d["s"] + d["grow"] * k)
		elif d.has("shrink"):
			var r: float = d["r"] * ((1.0 - 0.6 * k) if d["shrink"] else (0.4 + 0.6 * k))
			mi.scale = Vector3.ONE * r
		keep.append(it)
	items = keep
