class_name NightLights
extends Node3D
## M3.3 Phase 3 (20): lights for the night maps (view only). Phone-light: no Light3D nodes,
## only additive ground quads in three MultiMeshes:
##   - static: a warm pool under every street lamp (+ a small glow at the lamp head)
##   - buildings: a floodlit apron around each visible structure (team-tinted near the base)
##   - vehicles: white headlight beams ahead of each visible ground vehicle
## The dynamic groups are refreshed a few times a second by WorldView.
const LAMP_COL := Color(1.0, 0.78, 0.48)
const FLOOD_COL := Color(1.0, 0.86, 0.62)
const BEAM_COL := Color(0.92, 0.95, 1.0)
const MAX_BLD := 200
const MAX_VEH := 240
const MAX_FLOOD := 240          ## floodlight fixtures on screen at once (pooled, nearest first)
const MAX_BEAMS := MAX_VEH * 2  ## one beam per headlight
## floodlight colour per faction: US cool LED, Germany neutral white, Iran sodium, Russia warm
const FLOOD_COLS := {&"us": Color(0.82, 0.9, 1.0), &"eu": Color(1.0, 0.96, 0.88), &"tpla": Color(1.0, 0.68, 0.36), &"ecc": Color(1.0, 0.84, 0.58)}

var mat_pool: ShaderMaterial
var mat_beam: ShaderMaterial
var bld_mm: MultiMesh          ## floodlight ground pools
var veh_mm: MultiMesh          ## headlight beams
var mat_flare: ShaderMaterial
var mat_shaft: ShaderMaterial
var flare_mm: MultiMesh        ## lens flares (floodlights and headlights)
var shaft_mm: MultiMesh        ## floodlight shafts
var flood_count := 0
var flare_count := 0
var lamp_count := 0

static func _quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	return q

func setup(fog_tex: Texture2D, map_size: Vector2) -> void:
	var sh: Shader = load("res://view/env/light_pool.gdshader")
	mat_pool = ShaderMaterial.new()
	mat_pool.shader = sh
	mat_pool.set_shader_parameter("fog_tex", fog_tex)
	mat_pool.set_shader_parameter("map_size", map_size)
	mat_beam = mat_pool.duplicate()
	mat_beam.set_shader_parameter("cone", 1.0)
	bld_mm = _group("NightFlood", mat_pool, MAX_FLOOD)
	veh_mm = _group("NightBeams", mat_beam, MAX_BEAMS)
	var sp: Shader = load("res://view/env/night_sprite.gdshader")
	mat_flare = ShaderMaterial.new()
	mat_flare.shader = sp
	mat_flare.set_shader_parameter("fog_tex", fog_tex)
	mat_flare.set_shader_parameter("map_size", map_size)
	mat_shaft = mat_flare.duplicate()
	mat_shaft.set_shader_parameter("axial", 1.0)
	flare_mm = _group("NightFlares", mat_flare, MAX_FLOOD + MAX_BEAMS, true)
	shaft_mm = _group("NightShafts", mat_shaft, MAX_FLOOD, true)

func _group(nm: String, mat: Material, n: int, upright := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	if upright:
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		mm.mesh = q
	else:
		mm.mesh = _quad()
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4096.0
	add_child(mi)
	return mm

## lamps: [[x, z, rot90, double?], ...] in tile space; ground(x, z) -> height.
func add_lamps(lamps: Array, ground: Callable) -> void:
	if lamps.is_empty():
		return
	var pts: Array = []
	for l in lamps:
		var yaw: float = float(l[2]) * PI * 0.5
		var offs: Array = [-0.6, 0.6] if l[3] else [0.55]
		for o in offs:
			var p := Vector3(l[0], 0, l[1]) + Basis(Vector3.UP, yaw) * Vector3(o, 0, 0)
			pts.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad()
	mm.instance_count = pts.size() * 2
	for i in pts.size():
		var p: Vector3 = pts[i]
		var gy: float = ground.call(p.x, p.z)
		mm.set_instance_transform(i * 2, Transform3D(Basis().scaled(Vector3(4.6, 1, 4.6)), Vector3(p.x, gy + 0.03, p.z)))
		mm.set_instance_color(i * 2, Color(LAMP_COL, 0.8))
		mm.set_instance_transform(i * 2 + 1, Transform3D(Basis().scaled(Vector3(0.55, 1, 0.55)), Vector3(p.x, gy + (3.0 if lamps[0][3] else 2.68), p.z)))
		mm.set_instance_color(i * 2 + 1, Color(1.0, 0.92, 0.7, 2.2))
	var mi := MultiMeshInstance3D.new()
	mi.name = "NightLamps"
	mi.multimesh = mm
	mi.material_override = mat_pool
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	lamp_count = pts.size()

## M3.4 floodlights. fixtures: [[Vector3 lens (world), Vector3 aim point on the ground, Color], ...]
## Each gets a lens flare, a faint shaft down to where it points and an oval pool there
## (stretched along the aim). The caller sends the visible ones, nearest the camera first.
var _flood_flares := 0
func set_floodlights(fixtures: Array) -> void:
	var n := mini(fixtures.size(), MAX_FLOOD)
	for i in n:
		var f: Array = fixtures[i]
		var lens: Vector3 = f[0]
		var aim: Vector3 = f[1]
		var c: Color = f[2]
		var flat := Vector3(aim.x - lens.x, 0, aim.z - lens.z)
		var reach := maxf(0.5, flat.length())
		var z := flat / reach
		var x := Vector3.UP.cross(z).normalized()
		var pool_c := aim + z * 0.4
		pool_c.y = FX.ground_y(pool_c.x, pool_c.z) + 0.05
		var pw := 1.1 + reach * 0.25
		bld_mm.set_instance_transform(i, Transform3D(Basis(x * pw, Vector3.UP, z * (pw * 1.35)), pool_c))
		bld_mm.set_instance_color(i, Color(c, 0.26))   # M4.1: dialled back (was 0.4)
		flare_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.3, 0.3, 0.3)), lens))   # M4.1: was 0.55
		flare_mm.set_instance_color(i, Color(c, 0.7))
		var ax := lens - aim
		shaft_mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT * 0.45, ax, Vector3.FORWARD), (lens + aim) * 0.5))
		shaft_mm.set_instance_color(i, Color(c, 0.14))
	bld_mm.visible_instance_count = n
	shaft_mm.visible_instance_count = n
	_flood_flares = n
	flood_count = n
	_sync_flares()

## Vehicles: items = [[Transform3D view (world, interpolated this frame), Array lamps (local), float size,
## float start z (local: where the light clears the lower hull)], ...]
## Each headlight throws its own beam forward along the hull (+Z, tilt included, flattened onto
## the ground) from just below the lens; a flare sits on the lens. Called every rendered frame.
var beam_ends: Array = []   ## [lamp end, far end] per beam (read back by the tests)
var _veh_flares := 0
func set_vehicle_lamps(items: Array) -> void:
	var nb := 0
	beam_ends.clear()
	var base := _flood_flares
	for it in items:
		if nb >= MAX_BEAMS:
			break
		var xf: Transform3D = it[0]
		var sz: float = it[2]
		var fw := xf.basis.z
		fw.y = 0.0
		if fw.length_squared() < 1e-6:
			continue
		fw = fw.normalized()
		var lamps: Array = it[1]
		var sz0: float = it[3] if it.size() > 3 else 0.0
		var len := 3.2 + sz * 1.2
		var wid := (1.3 + sz * 0.45) / sqrt(float(maxi(1, lamps.size())))
		for lp: Vector3 in lamps:
			if nb >= MAX_BEAMS:
				break
			var lw := xf * lp
			var a := xf * Vector3(lp.x, lp.y, maxf(lp.z, sz0) + 0.06)
			var b := a + fw * len
			a.y = FX.ground_y(a.x, a.z) + 0.06
			b.y = FX.ground_y(b.x, b.z) + 0.06
			var z := (b - a).normalized()
			var x := Vector3.UP.cross(z).normalized()
			var y := z.cross(x)
			veh_mm.set_instance_transform(nb, Transform3D(Basis(x * wid, y, z * (b - a).length()), (a + b) * 0.5))
			veh_mm.set_instance_color(nb, Color(BEAM_COL, 0.62))
			beam_ends.append([a, b])
			if base + nb < flare_mm.instance_count:
				flare_mm.set_instance_transform(base + nb, Transform3D(Basis().scaled(Vector3(0.32, 0.32, 0.32)), lw + fw * 0.02))
				flare_mm.set_instance_color(base + nb, Color(1.0, 0.97, 0.9, 1.0))
			nb += 1
	veh_mm.visible_instance_count = nb
	_veh_flares = nb
	_sync_flares()

func _sync_flares() -> void:
	flare_mm.visible_instance_count = mini(flare_mm.instance_count, _flood_flares + _veh_flares)
	flare_count = flare_mm.visible_instance_count
