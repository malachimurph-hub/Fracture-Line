extends Node3D
## Isolated graphics review. One M1A3, one power station, one scripted shot.
## Does not start a match and does not touch the live unit or building scenes.
##
## Play from the main menu (Graphics review), or:
##   godot --path . --rendering-method mobile res://demo/gfx_quality/combat_review.tscn
## Screenshots (writes rts / close / impact / aftermath PNGs and a stats json):
##   godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://demo/gfx_quality/combat_review.tscn -- --shots /tmp/gfx_shots
##
## Scorch marks and smoke are mesh quads. The Decal node is not used: the Compatibility
## renderer does not draw it, and this scene has to match Mobile. Particles are a capped
## MultiMesh, not GPUParticles3D, for the same reason.

const LAYOUT := "res://assets/gfx_review/layout.json"
const SMOKE_MAX := 20
const FIRE_MAX := 6
const SMOKE_LIFE := 3.4
const FIRE_LIFE := 0.42
const DUST_LIFE := 0.65
const APPROACH_END := 4.2
const AIM_END := 6.0
const FLIGHT := 0.36

var layout: Dictionary = {}
var clock := 0.0
var phase := "approach"
var cam_mode := "rts"
var shot_dir := ""
var shot_i := 0
var shot_busy := false
var warmed := 0
var fired := false
var wrecked := false
var impacts := 0

var cam: Camera3D
var sun: DirectionalLight3D
var tank_root: Node3D
var hull_fwd: Node3D
var pivot: Node3D
var aim_fwd: Node3D
var barrel: Node3D
var muzzle: Node3D
var tracks: MeshInstance3D
var spinners: Array = []
var _travel := 0.0
var plant_root: Node3D
var intact: Node3D
var wreck: Node3D
var impact_pt: Node3D
var plant_fwd: Node3D
var tread_mat: StandardMaterial3D
var shell: MeshInstance3D
var streak: MeshInstance3D
var flash_a: MeshInstance3D
var flash_b: MeshInstance3D
var scorch_ground: MeshInstance3D
var scorch_wall: MeshInstance3D
var smoke_mm: MultiMesh
var fire_mm: MultiMesh
var smoke_age: PackedFloat32Array
var fire_age: PackedFloat32Array
var smoke_pos: PackedVector3Array
var fire_pos: PackedVector3Array
var smoke_kind: PackedInt32Array  # 0 smoke, 1 dust
var debris: Array = []
var debris_home: Array = []
var debris_vel: Array = []
var debris_age: Array = []
var cannon: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
var rest_pivot := Vector3.ZERO
var muzzle_local := Vector3.ZERO
var fire_from := Vector3.ZERO
var fire_to := Vector3.ZERO
var recoil := 0.0
var tank_start := Vector3(-9, 0, 2.2)
var tank_end := Vector3(-1.4, 0, 0.5)
var shoe_len := 0.045

var _shots := [
	{"t": 2.6, "cam": "rts", "name": "gfx_review_rts"},
	{"t": 5.15, "cam": "close", "name": "gfx_review_close"},
	{"t": 6.50, "cam": "impact", "name": "gfx_review_impact"},
	{"t": 8.4, "cam": "impact", "name": "gfx_review_aftermath"},
]


func _ready() -> void:
	rng.seed = 9863
	var args := OS.get_cmdline_user_args()
	var si := args.find("--shots")
	if si >= 0 and si + 1 < args.size():
		shot_dir = args[si + 1]
		DirAccess.make_dir_recursive_absolute(shot_dir)
	# The shipped game renders at 0.75. This review is judged at full resolution.
	get_viewport().scaling_3d_scale = 1.0
	_load_layout()
	_world()
	_load_tank()
	_load_plant()
	_load_props()
	_effects()
	_hud()
	_place_tank(0.0)
	_log_renderer()
	print("GFX-NODES tank=", tank_root != null, " hull_fwd=", hull_fwd != null, " muzzle=", muzzle != null, " plant=", plant_root != null, " impact=", impact_pt != null, " debris=", debris.size())


func _process(delta: float) -> void:
	if shot_busy:
		return
	if warmed < (24 if shot_dir != "" else 6):
		warmed += 1
		_apply_camera()
		return
	var step := 1.0 / 30.0 if shot_dir != "" else minf(delta, 0.05)
	_advance(step)
	_apply_camera()
	if shot_dir == "" or shot_i >= _shots.size():
		return
	if clock >= float(_shots[shot_i]["t"]):
		shot_busy = true
		cam_mode = str(_shots[shot_i]["cam"])
		_apply_camera()
		_grab(str(_shots[shot_i]["name"]))


func _advance(dt: float) -> void:
	clock += dt
	var u := clampf(clock / APPROACH_END, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	if clock < APPROACH_END:
		phase = "approach"
		_place_tank(u)
		if fmod(clock, 0.18) < dt:
			_puff(tank_root.global_position + Vector3(0, 0.15, 0), DUST_LIFE, Color(0.45, 0.40, 0.34), 0.35, 1)
	elif clock < AIM_END:
		phase = "aim"
		_place_tank(1.0)
		_aim_turret(dt)
	else:
		_place_tank(1.0)
		if not fired:
			_fire()
		var k := clampf((clock - AIM_END) / FLIGHT, 0.0, 1.0)
		if not wrecked:
			phase = "flight"
			_fly(k)
			if k >= 1.0:
				_impact()
		else:
			phase = "aftermath"
	_recoil(dt)
	_sim_pools(dt)
	_sim_debris(dt)


func _place_tank(u: float) -> void:
	if tank_root == null:
		return
	tank_root.position = tank_start.lerp(tank_end, u)
	if hull_fwd != null:
		_face(tank_root, hull_fwd, tank_end - tank_start)
	var dist := tank_start.distance_to(tank_root.position)
	if tread_mat != null:
		tread_mat.uv1_offset.y = dist / shoe_len
	# Road-wheel radius is 0.32 m at 0.25 units per metre.
	var spin := (dist - _travel) / 0.08
	_travel = dist
	for w in spinners:
		(w as Node3D).rotate_object_local(Vector3.RIGHT, spin)


func _aim_turret(dt: float) -> void:
	if pivot == null or aim_fwd == null or impact_pt == null:
		return
	var fwd := aim_fwd.global_position - pivot.global_position
	fwd.y = 0.0
	var to := impact_pt.global_position - pivot.global_position
	to.y = 0.0
	if fwd.length() < 0.01 or to.length() < 0.01:
		return
	var err := fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP)
	pivot.rotate_y(clampf(err, -1.15 * dt, 1.15 * dt))


func _fire() -> void:
	fired = true
	recoil = 1.0
	if muzzle != null:
		fire_from = muzzle.global_position
	elif tank_root != null:
		fire_from = tank_root.global_position + Vector3(0, 0.5, 0)
	else:
		fire_from = Vector3(0, 0.5, 0)
	fire_to = impact_pt.global_position if impact_pt != null else fire_from + Vector3(4, 0.4, 0)
	shell.visible = true
	streak.visible = true
	flash_a.visible = true
	flash_b.visible = true
	_fly(0.0)
	if cannon != null and cannon.stream != null:
		cannon.play()


func _fly(k: float) -> void:
	var p := fire_from.lerp(fire_to, k)
	shell.global_position = p
	streak.global_position = p
	var dir := (fire_to - fire_from).normalized()
	if dir.length() > 0.1:
		shell.look_at(p + dir, Vector3.UP)
		streak.look_at(p + dir, Vector3.UP)
	if muzzle != null:
		flash_a.global_position = muzzle.global_position
		flash_b.global_position = muzzle.global_position


func _impact() -> void:
	wrecked = true
	impacts += 1
	phase = "aftermath"
	shell.visible = false
	streak.visible = false
	flash_a.visible = false
	flash_b.visible = false
	if intact != null:
		intact.visible = false
	if wreck != null:
		wreck.visible = true
	scorch_ground.visible = true
	scorch_wall.visible = true
	var at := fire_to
	for i in 12:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.05, 0.7)
		_puff(at + Vector3(cos(ang) * rad, rng.randf_range(0.1, 0.8), sin(ang) * rad), SMOKE_LIFE,
			Color(0.62, 0.64, 0.66).lerp(Color(0.42, 0.40, 0.38), rng.randf_range(0.0, 0.35)),
			rng.randf_range(0.45, 1.15), 0)
	for i in FIRE_MAX:
		_burst(at + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.1, 0.55), rng.randf_range(-0.2, 0.2)),
			Color(1.0, rng.randf_range(0.42, 0.58), 0.08), rng.randf_range(0.22, 0.55))
	_fling_debris(at)


func _recoil(dt: float) -> void:
	if barrel == null:
		return
	recoil = move_toward(recoil, 0.0, dt * 3.2)
	var back := muzzle_local.normalized() if muzzle_local.length() > 0.01 else Vector3(0, 0, -1)
	barrel.position = -back * recoil * 0.07
	if flash_a.visible and recoil < 0.82:
		flash_a.visible = false
		flash_b.visible = false


func _puff(at: Vector3, life: float, col: Color, size: float, kind: int) -> void:
	var slot := _free_slot(smoke_age)
	if slot < 0:
		slot = _oldest(smoke_age)
	smoke_age[slot] = 0.001
	smoke_pos[slot] = at
	smoke_kind[slot] = kind
	# life is encoded by kind; size rides on the basis
	_set_instance(smoke_mm, slot, at, size, col, 0.85)


func _burst(at: Vector3, col: Color, size: float) -> void:
	var slot := _free_slot(fire_age)
	if slot < 0:
		slot = _oldest(fire_age)
	fire_age[slot] = 0.001
	fire_pos[slot] = at
	_set_instance(fire_mm, slot, at, size, col, 1.0)


func _sim_pools(dt: float) -> void:
	for i in SMOKE_MAX:
		if smoke_age[i] < 0.0:
			continue
		smoke_age[i] += dt
		var life := DUST_LIFE if smoke_kind[i] == 1 else SMOKE_LIFE
		var k := smoke_age[i] / life
		if k >= 1.0:
			smoke_age[i] = -1.0
			_set_instance(smoke_mm, i, smoke_pos[i], 0.0, Color(0, 0, 0, 0), 0.0)
			continue
		smoke_pos[i] += Vector3(0, dt * (0.25 + k * 0.55), 0)
		var size := lerpf(0.32, 1.25, k) * (0.5 if smoke_kind[i] == 1 else 1.0)
		var a := (1.0 - k) * (0.5 if smoke_kind[i] == 1 else 0.7)
		var col := Color(0.38, 0.32, 0.26) if smoke_kind[i] == 1 else Color(0.34, 0.35, 0.37)
		_set_instance(smoke_mm, i, smoke_pos[i], size, Color(col.r, col.g, col.b, a), a)
	for i in FIRE_MAX:
		if fire_age[i] < 0.0:
			continue
		fire_age[i] += dt
		var k2 := fire_age[i] / FIRE_LIFE
		if k2 >= 1.0:
			fire_age[i] = -1.0
			_set_instance(fire_mm, i, fire_pos[i], 0.0, Color(0, 0, 0, 0), 0.0)
			continue
		fire_pos[i] += Vector3(0, dt * 0.4, 0)
		var size2 := lerpf(0.18, 0.85, k2)
		var hot := Color(1.0, lerpf(0.75, 0.35, k2), 0.12, 1.0 - k2)
		_set_instance(fire_mm, i, fire_pos[i], size2, hot, hot.a)


func _fling_debris(at: Vector3) -> void:
	for i in debris.size():
		var d: Node3D = debris[i]
		var xf := d.global_transform
		d.reparent(self)
		d.global_transform = xf
		d.visible = true
		var away := (d.global_position - at)
		away.y = 0.0
		if away.length() < 0.05:
			away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		away = away.normalized()
		debris_vel[i] = away * rng.randf_range(1.6, 3.4) + Vector3(0, rng.randf_range(1.8, 3.6), 0)
		debris_age[i] = 0.0


func _sim_debris(dt: float) -> void:
	for i in debris.size():
		if debris_age[i] < 0.0 or debris_vel[i] == Vector3.ZERO and debris_age[i] > 0.2:
			continue
		debris_age[i] += dt
		var d: Node3D = debris[i]
		var v: Vector3 = debris_vel[i]
		v.y -= 9.8 * dt
		d.global_position += v * dt
		d.rotate_x(dt * 1.4)
		if d.global_position.y < 0.04 and v.y < 0.0:
			d.global_position.y = 0.04
			v = Vector3.ZERO
		debris_vel[i] = v
		# hard stop so chunks don't keep spinning after they land
		if debris_age[i] > 1.7:
			debris_vel[i] = Vector3.ZERO


func live_smoke() -> int:
	return _live(smoke_age)


func live_fire() -> int:
	return _live(fire_age)


func _live(ages: PackedFloat32Array) -> int:
	var n := 0
	for a in ages:
		if a >= 0.0:
			n += 1
	return n


func _free_slot(ages: PackedFloat32Array) -> int:
	for i in ages.size():
		if ages[i] < 0.0:
			return i
	return -1


func _oldest(ages: PackedFloat32Array) -> int:
	var best := 0
	for i in ages.size():
		if ages[i] > ages[best]:
			best = i
	return best


func _set_instance(mm: MultiMesh, i: int, at: Vector3, size: float, col: Color, alpha: float) -> void:
	var b := Basis.IDENTITY.scaled(Vector3.ONE * maxf(size, 0.0))
	mm.set_instance_transform(i, Transform3D(b, at))
	mm.set_instance_custom_data(i, Color(col.r, col.g, col.b, alpha))


func replay() -> void:
	clock = 0.0
	fired = false
	wrecked = false
	recoil = 0.0
	phase = "approach"
	if intact != null:
		intact.visible = true
	if wreck != null:
		wreck.visible = false
	shell.visible = false
	streak.visible = false
	flash_a.visible = false
	flash_b.visible = false
	scorch_ground.visible = false
	scorch_wall.visible = false
	if pivot != null:
		pivot.rotation = rest_pivot
	if barrel != null:
		barrel.position = Vector3.ZERO
	for i in debris.size():
		var d: Node3D = debris[i]
		var home: Dictionary = debris_home[i]
		d.reparent(home["parent"])
		d.transform = home["xf"]
		d.visible = false
		debris_vel[i] = Vector3.ZERO
		debris_age[i] = -1.0
	for i in SMOKE_MAX:
		smoke_age[i] = -1.0
		_set_instance(smoke_mm, i, Vector3.ZERO, 0.0, Color(0, 0, 0, 0), 0.0)
	for i in FIRE_MAX:
		fire_age[i] = -1.0
		_set_instance(fire_mm, i, Vector3.ZERO, 0.0, Color(0, 0, 0, 0), 0.0)
	_place_tank(0.0)
	cam_mode = "rts"


func _load_layout() -> void:
	if FileAccess.file_exists(LAYOUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
		if typeof(parsed) == TYPE_DICTIONARY:
			layout = parsed
	if layout.has("tank_start"):
		tank_start = _v3(layout["tank_start"])
	if layout.has("tank_end"):
		tank_end = _v3(layout["tank_end"])
	if layout.has("shoe_len"):
		shoe_len = float(layout["shoe_len"])


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]) if a.size() > 1 else 0.0, float(a[2]) if a.size() > 2 else 0.0)


func _world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.07, 0.10, 0.16)
	mat.sky_horizon_color = Color(0.55, 0.46, 0.36)
	mat.ground_horizon_color = Color(0.28, 0.24, 0.20)
	mat.ground_bottom_color = Color(0.07, 0.07, 0.07)
	mat.sun_angle_max = 6.0
	mat.energy_multiplier = 0.62
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.22
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.007
	env.fog_light_color = Color(0.48, 0.44, 0.38)
	env.fog_aerial_perspective = 0.40
	# A little bloom so the muzzle and the fire read warm. Threshold stays
	# above the tank paint so the body does not blow out.
	env.glow_enabled = true
	env.glow_intensity = 0.10
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.55
	env.glow_hdr_scale = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0.93, 0.80, 0.64)
	sun.light_energy = 1.65
	sun.light_specular = 0.22
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.005
	sun.shadow_normal_bias = 0.04
	sun.shadow_blur = 0.45
	sun.directional_shadow_blend_splits = true
	# About 20 degrees up, warm, from the south-west. One light. The lower
	# angle lengthens the contact shadow without dropping the field into dusk.
	sun.rotation_degrees = Vector3(-20.0, -48.0, 0.0)
	add_child(sun)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 46.0
	cam.near = 0.05
	cam.far = 80.0
	add_child(cam)


func _load_tank() -> void:
	var tank_scene := load("res://assets/gfx_review/m1a3.glb") as PackedScene
	if tank_scene == null:
		push_error("M1A3 glb is not imported")
		return
	tank_root = tank_scene.instantiate()
	tank_root.name = "Tank"
	add_child(tank_root)
	hull_fwd = tank_root.find_child("HullForward", true, false)
	pivot = tank_root.find_child("TurretPivot", true, false)
	aim_fwd = tank_root.find_child("AimForward", true, false)
	barrel = tank_root.find_child("Barrel", true, false)
	muzzle = tank_root.find_child("Muzzle", true, false)
	tracks = tank_root.find_child("Tracks", true, false)
	var body := _pbr("res://assets/gfx_review/m1a3_albedo.png", "res://assets/gfx_review/m1a3_normal.png", "res://assets/gfx_review/m1a3_orm.png")
	# The raytraced occlusion stair-steps across the big panels, and a normal
	# scale tilts each triangle on its own tangent. Both read as a chevron.
	# Seams, grime and edge wear stay in the albedo. Roughness stays in the ORM.
	body.normal_enabled = false
	body.ao_enabled = false
	body.metallic_specular = 0.22
	_override_meshes(tank_root, body, ["Tracks"])
	tread_mat = StandardMaterial3D.new()
	tread_mat.albedo_texture = load("res://assets/gfx_review/tread.png")
	tread_mat.normal_enabled = true
	tread_mat.normal_texture = load("res://assets/gfx_review/tread_n.png")
	tread_mat.normal_scale = 0.7
	tread_mat.roughness = 0.88
	tread_mat.metallic = 0.12
	tread_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if tracks != null:
		tracks.material_override = tread_mat
		tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for prefix in ["Wheel", "Sprocket", "Idler", "Roller"]:
		for n in tank_root.find_children(prefix + "*", "MeshInstance3D", true, false):
			spinners.append(n)
	print("GFX-SPINNERS ", spinners.size())
	if barrel != null and muzzle != null:
		muzzle_local = muzzle.position
	if pivot != null:
		rest_pivot = pivot.rotation
	var gnd := (load("res://assets/gfx_review/ground.glb") as PackedScene).instantiate()
	gnd.name = "Ground"
	add_child(gnd)
	var gm := _pbr("res://assets/gfx_review/ground_albedo.png", "res://assets/gfx_review/ground_normal.png", "res://assets/gfx_review/ground_orm.png")
	gm.roughness = 1.0
	gm.metallic = 0.0
	gm.metallic_specular = 0.12
	gm.ao_light_affect = 0.75
	gm.normal_scale = 0.7
	_override_meshes(gnd, gm, [])


func _load_plant() -> void:
	var plant_scene := load("res://assets/gfx_review/plant.glb") as PackedScene
	if plant_scene == null:
		push_error("plant glb is not imported")
		return
	plant_root = plant_scene.instantiate()
	plant_root.name = "Plant"
	add_child(plant_root)
	intact = plant_root.find_child("PlantIntact", true, false)
	wreck = plant_root.find_child("PlantWreck", true, false)
	impact_pt = plant_root.find_child("ImpactPoint", true, false)
	plant_fwd = plant_root.find_child("PlantForward", true, false)
	var mat := _pbr("res://assets/gfx_review/plant_albedo.png", "res://assets/gfx_review/plant_normal.png", "res://assets/gfx_review/plant_orm.png")
	_override_meshes(plant_root, mat, [])
	if layout.has("plant_pos"):
		plant_root.position = _v3(layout["plant_pos"])
	if plant_fwd != null and layout.has("plant_face"):
		_face(plant_root, plant_fwd, _v3(layout["plant_face"]))
	if wreck != null:
		wreck.visible = false
	for c in plant_root.find_children("Debris*", "MeshInstance3D", true, false):
		debris.append(c)
		debris_home.append({"parent": c.get_parent(), "xf": c.transform})
		debris_vel.append(Vector3.ZERO)
		debris_age.append(-1.0)
		c.visible = false


func _load_props() -> void:
	var mat := _pbr("res://assets/gfx_review/props_albedo.png", "res://assets/gfx_review/props_normal.png", "res://assets/gfx_review/props_orm.png")
	var trees: Array = layout.get("trees", [])
	_scatter("res://assets/gfx_review/tree.glb", "Trunk", trees, mat)
	var needles := StandardMaterial3D.new()
	needles.albedo_texture = load("res://assets/gfx_review/needle.png")
	needles.albedo_color = Color(0.55, 0.95, 0.62)
	needles.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	needles.cull_mode = BaseMaterial3D.CULL_DISABLED
	needles.roughness = 0.9
	needles.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_scatter("res://assets/gfx_review/tree.glb", "Foliage", trees, needles, 0.55)
	var rocks: Array = layout.get("rocks", [])
	var even: Array = []
	var odd: Array = []
	for i in rocks.size():
		if i % 2 == 0:
			even.append(rocks[i])
		else:
			odd.append(rocks[i])
	_scatter("res://assets/gfx_review/rock.glb", "Rock", even, mat)
	_scatter("res://assets/gfx_review/rock.glb", "RockB", odd, mat)


func _scatter(scene_path: String, mesh_name: String, items: Array, mat: Material, scale_mul := 1.0) -> void:
	if items.is_empty():
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("missing prop %s" % scene_path)
		return
	var inst := packed.instantiate()
	var src := inst.find_child(mesh_name, true, false) as MeshInstance3D
	if src == null or src.mesh == null:
		inst.free()
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = src.mesh
	mm.instance_count = items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var p := _v3(it["pos"])
		var yaw := float(it.get("yaw", 0.0))
		var sc := float(it.get("scale", 1.0)) * scale_mul
		var basis := Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * sc)
		mm.set_instance_transform(i, Transform3D(basis, p))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)
	inst.free()


func _effects() -> void:
	var disc := _disc_tex()
	smoke_mm = _pool(SMOKE_MAX, preload("res://demo/gfx_quality/billboard.gdshader"), disc, "Smoke")
	fire_mm = _pool(FIRE_MAX, preload("res://demo/gfx_quality/billboard_add.gdshader"), disc, "Fire")
	smoke_age.resize(SMOKE_MAX)
	smoke_pos.resize(SMOKE_MAX)
	smoke_kind.resize(SMOKE_MAX)
	fire_age.resize(FIRE_MAX)
	fire_pos.resize(FIRE_MAX)
	for i in SMOKE_MAX:
		smoke_age[i] = -1.0
		_set_instance(smoke_mm, i, Vector3.ZERO, 0.0, Color(0, 0, 0, 0), 0.0)
	for i in FIRE_MAX:
		fire_age[i] = -1.0
		_set_instance(fire_mm, i, Vector3.ZERO, 0.0, Color(0, 0, 0, 0), 0.0)
	var tracer := StandardMaterial3D.new()
	tracer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.emission = Color(1.0, 0.78, 0.35)
	tracer.emission_energy_multiplier = 3.5
	tracer.albedo_color = Color(1.0, 0.85, 0.45)
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.55)
	shell = MeshInstance3D.new()
	shell.mesh = box
	shell.material_override = tracer
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visible = false
	add_child(shell)
	var streak_box := BoxMesh.new()
	streak_box.size = Vector3(0.035, 0.035, 1.35)
	streak = MeshInstance3D.new()
	streak.mesh = streak_box
	streak.material_override = tracer
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.visible = false
	add_child(streak)
	flash_a = _flash_quad(disc)
	flash_b = _flash_quad(disc)
	flash_b.rotate_object_local(Vector3.UP, PI * 0.5)
	var scorch_mat := StandardMaterial3D.new()
	scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scorch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scorch_mat.albedo_texture = load("res://assets/gfx_review/scorch.png")
	scorch_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	scorch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 1.7)
	scorch_ground = MeshInstance3D.new()
	scorch_ground.name = "ScorchGround"
	scorch_ground.mesh = quad
	scorch_ground.material_override = scorch_mat
	scorch_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scorch_ground.rotation_degrees = Vector3(-90, 20, 0)
	scorch_ground.visible = false
	add_child(scorch_ground)
	var wall := QuadMesh.new()
	wall.size = Vector2(1.45, 1.15)
	scorch_wall = MeshInstance3D.new()
	scorch_wall.name = "ScorchWall"
	scorch_wall.mesh = wall
	scorch_wall.material_override = scorch_mat.duplicate()
	scorch_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scorch_wall.visible = false
	add_child(scorch_wall)
	cannon = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/sfx/tank_cannon.ogg"):
		cannon.stream = load("res://audio/sfx/tank_cannon.ogg")
		cannon.volume_db = -6.0
	add_child(cannon)


func _pool(n: int, shader: Shader, disc: Texture2D, node_name: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = n
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("disc", disc)
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return mm


func _flash_quad(disc: Texture2D) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = disc
	m.albedo_color = Color(1.0, 0.78, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func _disc_tex() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - smoothstep(0.15, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _pbr(albedo: String, normal: String, orm: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(albedo)
	m.normal_enabled = true
	m.normal_texture = load(normal)
	m.normal_scale = 0.8
	if orm != "":
		var ot: Texture2D = load(orm)
		m.ao_enabled = true
		m.ao_texture = ot
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.45
		m.roughness_texture = ot
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic_texture = ot
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.metallic = 1.0
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = false
	return m


func _override_meshes(root: Node, mat: Material, skip: Array) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name in skip:
			continue
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _face(node: Node3D, marker: Node3D, dir: Vector3) -> void:
	var fwd := marker.global_position - node.global_position
	fwd.y = 0.0
	var to := dir
	to.y = 0.0
	if fwd.length() < 0.001 or to.length() < 0.001:
		return
	node.rotate_y(fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP))


func _apply_camera() -> void:
	if cam == null:
		return
	var eye := Vector3()
	var focus := Vector3()
	match cam_mode:
		"close":
			if tank_root != null:
				focus = tank_root.global_transform * Vector3(0.15, 0.42, 0.05)
				eye = tank_root.global_transform * Vector3(1.15, 0.72, 1.55)
			else:
				focus = Vector3.ZERO
				eye = Vector3(2, 1, 2)
		"impact":
			var ip := impact_pt.global_position if impact_pt != null else Vector3(4, 1, 0)
			var origin := tank_root.global_position if tank_root != null else ip + Vector3(-6, 0, 0)
			var side := (ip - origin).cross(Vector3.UP)
			if side.length() < 0.2:
				side = Vector3(0, 0, 1)
			side = side.normalized()
			var mid := origin.lerp(ip, 0.62)
			eye = mid + Vector3(0, 2.6, 0) + side * 8.4
			focus = mid + Vector3(0, 0.7, 0)
		_:
			# Steep enough that the frame stays on the detailed field. The apron only
			# covers whatever still reaches past that mesh.
			focus = Vector3(2.2, 0.45, 0.2)
			eye = focus + Vector3(-1.8, 9.2, 6.4)
	cam.global_position = eye
	cam.look_at(focus, Vector3.UP)
	if scorch_ground != null and impact_pt != null:
		scorch_ground.global_position = Vector3(impact_pt.global_position.x, 0.035, impact_pt.global_position.z)
	if scorch_wall != null and impact_pt != null:
		scorch_wall.global_position = impact_pt.global_position + Vector3(0, 0.05, 0)
		if tank_root != null:
			scorch_wall.look_at(tank_root.global_position + Vector3(0, impact_pt.global_position.y, 0), Vector3.UP)


func _hud() -> void:
	if shot_dir != "":
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := Panel.new()
	bar.position = Vector2(12, 12)
	bar.size = Vector2(560, 86)
	layer.add_child(bar)
	var title := Label.new()
	title.text = "Graphics review  ·  M1A3 and power station  ·  not a match"
	title.position = Vector2(10, 6)
	title.size = Vector2(540, 22)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = "One shot, then the wreck holds. Keys: 1 RTS   2 close-up   3 impact   R replay   Esc back"
	hint.position = Vector2(10, 28)
	hint.size = Vector2(540, 20)
	bar.add_child(hint)
	var names := [["RTS", "rts"], ["Close-up", "close"], ["Impact", "impact"], ["Replay", "replay"], ["Back", "back"]]
	for i in names.size():
		var b := Button.new()
		b.text = names[i][0]
		b.position = Vector2(10 + i * 108, 52)
		b.size = Vector2(100, 26)
		var id: String = names[i][1]
		b.pressed.connect(_hud_pressed.bind(id))
		bar.add_child(b)


func _hud_pressed(id: String) -> void:
	match id:
		"rts", "close", "impact":
			cam_mode = id
		"replay":
			replay()
		"back":
			_back()


func _unhandled_input(event: InputEvent) -> void:
	if shot_dir != "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			cam_mode = "rts"
		KEY_2:
			cam_mode = "close"
		KEY_3:
			cam_mode = "impact"
		KEY_R:
			replay()
		KEY_ESCAPE:
			_back()


func _back() -> void:
	if Engine.get_singleton("GameSession") != null or get_node_or_null("/root/GameSession") != null:
		GameSession.goto("res://ui/main_menu.tscn")
	else:
		get_tree().quit()


func _log_renderer() -> void:
	var method := RenderingServer.get_current_rendering_method()
	var decal := method == "forward_plus" or method == "mobile"
	print("GFX-REVIEW renderer=%s decal_node_supported=%s scorch=mesh_quad particles=multimesh_capped smoke_max=%d fire_max=%d" % [method, decal, SMOKE_MAX, FIRE_MAX])


func _grab(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := shot_dir.rstrip("/") + "/" + name + ".png"
	img.save_png(path)
	var stats := _stats()
	stats["file"] = path
	stats["phase"] = phase
	stats["clock"] = clock
	stats["camera"] = cam_mode
	var jf := FileAccess.open(shot_dir.rstrip("/") + "/" + name + ".json", FileAccess.WRITE)
	if jf != null:
		jf.store_string(JSON.stringify(stats, "  "))
	print("GFX-SHOT ", path, " ", JSON.stringify(stats))
	shot_i += 1
	shot_busy = false
	if shot_i >= _shots.size():
		_write_summary()
		get_tree().quit()


func _stats() -> Dictionary:
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var mem := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	return {
		"renderer": RenderingServer.get_current_rendering_method(),
		"draw_calls_frame": draws,
		"primitives_frame": prims,
		"video_mem_bytes": mem,
		"scene_tris": _scene_tris(),
		"live_smoke": live_smoke(),
		"live_fire": live_fire(),
		"smoke_cap": SMOKE_MAX,
		"fire_cap": FIRE_MAX,
		"note": "draw_calls and primitives include the shadow pass. scene_tris is the unshadowed mesh walk. video_mem is the backend total, not only these textures.",
	}


func _mesh_tris(m: Mesh) -> int:
	if m == null:
		return 0
	# Primitive meshes (the tracer box, the puff quad) have no index array until committed.
	return m.get_faces().size() / 3


func _scene_tris() -> int:
	var n := 0
	for mi in find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).visible:
			continue
		n += _mesh_tris((mi as MeshInstance3D).mesh)
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		if mm == null:
			continue
		n += _mesh_tris(mm.mesh) * mm.visible_instance_count
	return n


func _write_summary() -> void:
	var files := {}
	var dir := DirAccess.open("res://assets/gfx_review")
	if dir != null:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if not dir.current_is_dir():
				files[fn] = FileAccess.get_file_as_bytes("res://assets/gfx_review/" + fn).size()
			fn = dir.get_next()
	var total := 0
	for k in files:
		total += int(files[k])
	var summary := {"asset_bytes": files, "asset_bytes_total": total, "last": _stats()}
	var jf := FileAccess.open(shot_dir.rstrip("/") + "/gfx_review_summary.json", FileAccess.WRITE)
	if jf != null:
		jf.store_string(JSON.stringify(summary, "  "))
	print("GFX-ASSETS total_bytes=", total)
