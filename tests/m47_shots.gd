extends "res://tests/m30_shots.gd"
## Side views of the rebuilt Russian vehicles in the match lighting, plus a roster and the conscript squad.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tests/m47_shots.tscn -- /opt/cursor/artifacts
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["ecc", "eu"], false)
	for layer in m.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var part := OS.get_environment("FL_SHOT")
	var spot := Vector2i(48, 48)
	var units := [
		["bmp3", &"ecc_bmp3", 4.2, 0.7],
		["bmpt", &"ecc_bmpt", 4.4, 0.75],
		["t14", &"ecc_t14", 5.2, 0.7],
		["tos", &"ecc_tos", 4.6, 0.85],
		["iskander", &"ecc_iskander", 6.2, 0.9],
		["mi8", &"ecc_mi8", 6.5, 1.1],
		["reaper", &"ecc_reaper", 7.2, 1.0],
	]
	for spec in units:
		if part == "people":
			break
		var u := _unit(spec[1], spot, 0)
		if spec[0] == "mi8":
			u.air_state = AirSys.PARKED
			m.world.air_alt[u.id] = 0.0
		await frames(3)
		await _side(u, spec[0], float(spec[2]), float(spec[3]))
		u.alive = false
		if m.world.views.has(u.id):
			m.world.views[u.id].visible = false
	if part != "vehicles":
		var squad := _unit(&"ecc_squad", spot, FX.ANG / 8)
		await frames(4)
		await _side(squad, "conscripts", 3.6, 0.9)
		squad.alive = false
		if m.world.views.has(squad.id):
			m.world.views[squad.id].visible = false
	# roster: two tight rows on open ground, the match sun
	if part == "vehicles":
		print("=== M47 SHOTS DONE")
		get_tree().quit(0)
		return
	var front := [&"ecc_bmp3", &"ecc_bmpt", &"ecc_t14", &"ecc_tos"]
	var back := [&"ecc_iskander", &"ecc_reaper", &"ecc_mi8"]
	for i in front.size():
		_unit(front[i], spot + Vector2i(-5 + i * 3, 6), FX.ANG / 4)
		await frames(1)
	for i in back.size():
		var uu := _unit(back[i], spot + Vector2i(-4 + i * 4, 10), FX.ANG / 4)
		if back[i] == &"ecc_mi8":
			uu.air_state = AirSys.PARKED
			m.world.air_alt[uu.id] = 0.0
		await frames(1)
	var sq2 := _unit(&"ecc_squad", spot + Vector2i(1, 4), FX.ANG / 6)
	await frames(3)
	var sun2 := _sun()
	var flat := Vector3(sun2.x, 0, sun2.z).normalized()
	var mid := FX.to_world(FX.tile_center(spot + Vector2i(0, 8)))
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 38.0
	cam.current = true
	cam.global_position = mid + flat * 13.0 + Vector3(0, 9.0, 0)
	cam.look_at(mid + Vector3(0, 0.4, 0), Vector3.UP)
	await frames(8)
	await shot("russia_roster_game")
	cam.queue_free()
	print("=== M47 SHOTS DONE")
	sq2.alive = true
	get_tree().quit(0)

func _sun() -> Vector3:
	for n in m.find_children("*", "DirectionalLight3D", true, false):
		return -(n as DirectionalLight3D).global_transform.basis.z
	return Vector3(0.3, 0.8, 0.4)

func _side(u: SimEntity, name: String, dist: float, eye: float) -> void:
	var v: Node3D = m.world.views[u.id]
	var fwd: Vector3 = v.global_transform.basis.z
	var side: Vector3 = v.global_transform.basis.x
	if side.dot(_sun()) < 0.0:
		side = -side
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 26.0
	cam.current = true
	var focus := v.global_position + Vector3(0, eye * 0.45, 0)
	# Sunlit front quarter, high enough that the deck catches the match sun.
	cam.global_position = focus + side * dist * 0.8 + fwd * dist * 0.62 + Vector3(0, dist * 0.38, 0)
	cam.look_at(focus, Vector3.UP)
	await frames(4)
	await shot("side_" + name)
	cam.queue_free()
	m.cam.cam.current = true
