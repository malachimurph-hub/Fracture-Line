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
	for spec in [["bmpt", &"ecc_bmpt", 4.2, 3]]:
		var u := _unit(spec[1], spot, 0)
		var t90 := _unit(&"ecc_t90", spot + Vector2i(0, int(spec[3])), 0)
		await frames(4)
		await _frame(u, t90, spec[0] + "_play", float(spec[2]) * 1.35, 0.42)
		await _frame(u, t90, spec[0] + "_close", float(spec[2]) * 0.9, 0.95)
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
