extends "res://tests/m30_shots.gd"
## Old T-90 beside the live one, then close-ups with armor off and on.
##   godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://tests/t90_shots.tscn -- /opt/cursor/artifacts

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["ecc", "eu"], false)
	var spot := _open_spot(Vector2i(6, 4), Vector2i(48, 48))
	var u := _unit(&"ecc_t90", spot, 0)
	await frames(8)
	var neu := m.world.views[u.id] as Node3D
	var old := (load("res://view/units/ecc/t90_legacy.tscn") as PackedScene).instantiate()
	m.world.add_child(old)
	old.global_position = neu.global_position + neu.global_transform.basis.x * 5.0
	old.global_rotation = neu.global_rotation
	await frames(2)
	Palette.apply_paint(old, &"ecc")
	Weathering.apply(old, &"ecc")
	var src := neu.find_child("Hull", true, false) as GeometryInstance3D
	var team: Variant = src.get_instance_shader_parameter(&"team_color")
	for g in old.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter(&"team_color", team)
	var mid: Vector3 = (old.global_position + neu.global_position) * 0.5
	m.cam.focus = mid + Vector3(0, 0.45, 0)
	m.cam.dist = 20.0
	m.cam.target_dist = 20.0
	m.cam.yaw = 0.9
	await frames(36)
	await shot("t90_rts")
	old.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30.0
	cam.current = true
	var fwd: Vector3 = neu.global_transform.basis.z
	var right: Vector3 = neu.global_transform.basis.x
	cam.global_position = neu.global_position + fwd * 3.6 + right * 2.6 + Vector3(0, 2.0, 0)
	cam.look_at(neu.global_position + Vector3(0, 0.7, 0.05), Vector3.UP)
	await frames(10)
	await shot("t90_close")
	for n in neu.find_children("ActiveArmor", "", true, false):
		n.visible = true
	await frames(8)
	await shot("t90_armor")
	print("=== T90 SHOTS DONE")
	get_tree().quit(0)
