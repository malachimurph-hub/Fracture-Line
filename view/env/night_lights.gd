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

var mat_pool: ShaderMaterial
var mat_beam: ShaderMaterial
var bld_mm: MultiMesh
var veh_mm: MultiMesh
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
	bld_mm = _group("NightFlood", mat_pool, MAX_BLD)
	veh_mm = _group("NightBeams", mat_beam, MAX_VEH)

func _group(nm: String, mat: Material, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
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

## items: [[Vector3 centre, Vector2 footprint, Color team], ...]
func set_buildings(items: Array) -> void:
	var n := mini(items.size(), MAX_BLD)
	for i in n:
		var it: Array = items[i]
		var fp: Vector2 = it[1]
		var s := maxf(fp.x, fp.y) * 1.25 + 4.0
		bld_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, 1, s)), (it[0] as Vector3) + Vector3(0, 0.04, 0)))
		var c: Color = FLOOD_COL.lerp(it[2], 0.25)
		bld_mm.set_instance_color(i, Color(c, 0.75))
	bld_mm.visible_instance_count = n

## items: [[Vector3 position, float yaw (+Z forward), float size], ...]
func set_vehicles(items: Array) -> void:
	var n := mini(items.size(), MAX_VEH)
	for i in n:
		var it: Array = items[i]
		var yaw: float = it[1]
		var sz: float = it[2]
		var len := 3.2 + sz
		var b := Basis(Vector3.UP, yaw)
		var c := (it[0] as Vector3) + b * Vector3(0, 0, sz * 0.5 + len * 0.5) + Vector3(0, 0.05, 0)
		# quad: UV.y runs along +Z after this rotation; flip so UV.y = 0 is at the vehicle
		veh_mm.set_instance_transform(i, Transform3D(b * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(1.6 + sz * 0.6, 1, len)), c))
		veh_mm.set_instance_color(i, Color(BEAM_COL, 0.7))
	veh_mm.visible_instance_count = n
