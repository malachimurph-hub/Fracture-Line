extends "res://tests/m30_shots.gd"
## Old live M1A3 beside the separate SEP v3 scene, on Varno Crossing with match lighting.
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
	await frames(10)
	var old := m.world.views[u.id] as Node3D
	var neu := (load("res://view/units/us/halberd_sepv3.tscn") as PackedScene).instantiate()
	m.world.add_child(neu)
	neu.global_position = old.global_position + old.global_transform.basis.x * 4.5
	neu.global_rotation = old.global_rotation
	var mid: Vector3 = (old.global_position + neu.global_position) * 0.5
	m.cam.focus = mid + Vector3(0, 0.35, 0)
	m.cam.dist = 22.0
	m.cam.target_dist = 22.0
	m.cam.yaw = 0.85
	await frames(36)
	await shot("m1a3_sepv3_compare")
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 32.0
	cam.current = true
	var fwd: Vector3 = neu.global_transform.basis.z
	var right: Vector3 = neu.global_transform.basis.x
	cam.global_position = neu.global_position + fwd * 4.6 + right * 3.1 + Vector3(0, 1.35, 0)
	cam.look_at(neu.global_position + Vector3(0, 0.4, 0), Vector3.UP)
	await frames(12)
	await shot("m1a3_sepv3_front")
	print("=== SEPV3 SHOTS DONE")
	get_tree().quit(0)
