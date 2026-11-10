extends "res://tests/m30_shots.gd"
## Live M1A3 on Varno Crossing with match lighting.
##   godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://tests/sepv3_shots.tscn -- /opt/cursor/artifacts

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["us", "eu"], false)
	var spot := _open_spot(Vector2i(6, 4), Vector2i(48, 48))
	var u := _unit(&"us_halberd", spot, 0)
	await frames(8)
	var tank := m.world.views[u.id] as Node3D
	m.cam.focus = tank.global_position + Vector3(0, 0.45, 0)
	m.cam.dist = 18.0
	m.cam.target_dist = 18.0
	m.cam.yaw = 0.9
	await frames(36)
	await shot("m1a3_v3detail_rts")
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30.0
	cam.current = true
	var fwd: Vector3 = tank.global_transform.basis.z
	var right: Vector3 = tank.global_transform.basis.x
	cam.global_position = tank.global_position + fwd * 3.5 + right * 2.55 + Vector3(0, 2.05, 0)
	cam.look_at(tank.global_position + Vector3(0, 0.7, 0.05), Vector3.UP)
	await frames(12)
	await shot("m1a3_v3detail_close")
	print("=== V3DETAIL SHOTS DONE")
	get_tree().quit(0)
