extends "res://tests/m30_shots.gd"
## In-match shots of the SEP v3 M1A3 on a real map, with the match's own light and ground.
##   godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://tests/sepv3_shots.tscn -- /opt/cursor/artifacts

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["us", "eu"], false)
	var spot := _open_spot(Vector2i(8, 8), Vector2i(48, 48))
	var units: Array = []
	for k in 4:
		units.append(_unit(&"us_halberd", spot + Vector2i(0, k * 3), 0))
	await frames(10)
	var live := m.world.views[units[0].id] as Node3D
	var legacy := (load("res://view/units/us/halberd_legacy.tscn") as PackedScene).instantiate()
	m.world.add_child(legacy)
	legacy.global_position = live.global_position + live.global_transform.basis.x * 5.0
	legacy.global_rotation = live.global_rotation
	var mid := (live.global_position + legacy.global_position) * 0.5 as Vector3
	m.cam.focus = mid + Vector3(0, 0.4, 0)
	m.cam.dist = 26.0
	m.cam.target_dist = 26.0
	m.cam.yaw = 0.9
	await frames(40)
	await shot("m1a3_old_and_new")
	legacy.visible = false
	var far := m.world.views[units[3].id] as Node3D
	m.cam.focus = (live.global_position + far.global_position) * 0.5 + Vector3(0, 0.3, 0)
	m.cam.dist = 32.4
	m.cam.target_dist = 32.4
	m.cam.yaw = 0.5
	await frames(24)
	await shot("m1a3_gameplay")
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 32.0
	cam.current = true
	var fwd := live.global_transform.basis.z
	var right := live.global_transform.basis.x
	cam.global_position = live.global_position + fwd * 5.2 + right * 3.4 + Vector3(0, 1.55, 0)
	cam.look_at(live.global_position + Vector3(0, 0.55, 0), Vector3.UP)
	await frames(12)
	await shot("m1a3_front")
	print("=== SEPV3 SHOTS DONE")
	get_tree().quit(0)
