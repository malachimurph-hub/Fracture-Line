extends "res://tests/m30_shots.gd"
## T-90 beside the rebuilt BMPT and Grim Reaper, in the match sun.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tests/m47_pair.tscn -- /tmp/m47pair
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m47pair"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["ecc", "eu"], false)
	for layer in m.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var spot := Vector2i(48, 48)
	var only := OS.get_environment("FL_ONLY")
	for spec in [["bmpt", &"ecc_bmpt", 4.2, 3], ["bmp3", &"ecc_bmp3", 4.2, 3], ["t14", &"ecc_t14", 5.4, 3],
			["mi8", &"ecc_mi8", 7.2, 4], ["pantsir", &"ecc_pantsir", 6.4, 4]]:
		if only != "" and spec[0] != only:
			continue
		var u := _unit(spec[1], spot, 0)
		if spec[0] == "mi8":
			u.air_state = AirSys.PARKED
			m.world.air_alt[u.id] = 0.0
		var beside: StringName = &"ecc_t90" if spec[0] == "bmpt" else &"ecc_bmpt"
		var t90 := _unit(beside, spot + Vector2i(0, int(spec[3])), 0)
		await frames(4)
		await _frame(u, t90, spec[0] + "_play", float(spec[2]) * 1.35, 0.42)
		await _frame(u, t90, spec[0] + "_close", float(spec[2]) * 0.9, 0.95)
		if spec[0] == "bmpt":
			await _hatches(u, spec[0] + "_hatches")
		if spec[0] == "pantsir":
			_plant(u)
			await frames(3)
			await _frame(u, t90, spec[0] + "_deployed", float(spec[2]) * 1.15, 0.55)
		for e in [u, t90]:
			e.alive = false
			if m.world.views.has(e.id):
				m.world.views[e.id].visible = false
	print("=== M47 PAIR DONE")
	get_tree().quit(0)

func _sun() -> Vector3:
	for n in m.find_children("*", "DirectionalLight3D", true, false):
		return -(n as DirectionalLight3D).global_transform.basis.z
	return Vector3(0.3, 0.8, 0.4)

func _frame(u: SimEntity, t90: SimEntity, name: String, dist: float, fwd_k: float) -> void:
	var v: Node3D = m.world.views[u.id]
	var fwd: Vector3 = v.global_transform.basis.z
	var side: Vector3 = v.global_transform.basis.x
	if side.dot(_sun()) < 0.0:
		side = -side
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 28.0
	cam.current = true
	var focus: Vector3 = v.global_position.lerp(m.world.views[t90.id].global_position, 0.22) + Vector3(0, 0.7, 0)
	cam.global_position = focus + side * dist * 0.75 + fwd * dist * fwd_k + Vector3(0, dist * 0.32, 0)
	cam.look_at(focus, Vector3.UP)
	await frames(5)
	await shot(name)
	cam.queue_free()
	m.cam.cam.current = true

func _farside(u: SimEntity, name: String) -> void:
	var v: Node3D = m.world.views[u.id]
	var fwd: Vector3 = v.global_transform.basis.z
	var side: Vector3 = v.global_transform.basis.x
	if side.dot(_sun()) > 0.0:
		side = -side
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 28.0
	cam.current = true
	var focus: Vector3 = v.global_position + Vector3(0, 0.8, 0)
	cam.global_position = focus + side * 5.4 + fwd * 2.6 + Vector3(0, 1.8, 0)
	cam.look_at(focus, Vector3.UP)
	await frames(5)
	await shot(name)
	cam.queue_free()
	m.cam.cam.current = true

func _compare(u: SimEntity, name: String) -> void:
	var live: Node3D = m.world.views[u.id]
	var old := (load("res://view/units/ecc/pantsir_i23d.tscn") as PackedScene).instantiate() as Node3D
	m.add_child(old)
	var fwd: Vector3 = live.global_transform.basis.z
	var side: Vector3 = live.global_transform.basis.x
	if side.dot(_sun()) < 0.0:
		side = -side
	old.global_transform = live.global_transform
	old.global_position = live.global_position - side * 4.2
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 32.0
	cam.current = true
	var focus: Vector3 = live.global_position - side * 2.1 + Vector3(0, 0.8, 0)
	cam.global_position = focus + side * 5.2 + fwd * 3.4 + Vector3(0, 2.4, 0)
	cam.look_at(focus, Vector3.UP)
	await frames(5)
	await shot(name)
	cam.queue_free()
	old.queue_free()
	m.cam.cam.current = true

func _plant(u: SimEntity) -> void:
	var v: VehicleView = m.world.views[u.id]
	v.set_plant(1.0)
	v._plant_k = 1.0
	if v._outriggers != null:
		v._outriggers.position.y = 0.0
	if v._radar != null:
		v._radar.rotation.x = v._radar_rx

func _hatches(u: SimEntity, name: String) -> void:
	var v: Node3D = m.world.views[u.id]
	var fwd: Vector3 = v.global_transform.basis.z
	var side: Vector3 = v.global_transform.basis.x
	if side.dot(_sun()) < 0.0:
		side = -side
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30.0
	cam.current = true
	var focus: Vector3 = v.global_position + fwd * 0.48 + Vector3(0, 0.55, 0)
	cam.global_position = focus + side * 1.15 + fwd * 1.35 + Vector3(0, 0.85, 0)
	cam.look_at(focus, Vector3.UP)
	await frames(5)
	await shot(name)
	cam.queue_free()
	m.cam.cam.current = true
