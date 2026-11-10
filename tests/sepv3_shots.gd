extends "res://tests/m30_shots.gd"
## Live M1A3 beside the detail candidate, on Varno Crossing with match lighting.
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
	var neu := (load("res://view/units/us/halberd_v3detail.tscn") as PackedScene).instantiate()
	m.world.add_child(neu)
	neu.global_position = old.global_position + old.global_transform.basis.x * 4.6
	neu.global_rotation = old.global_rotation
	await frames(2)
	_match_paint(neu, old)
	var mid: Vector3 = (old.global_position + neu.global_position) * 0.5
	m.cam.focus = mid + Vector3(0, 0.4, 0)
	m.cam.dist = 20.0
	m.cam.target_dist = 20.0
	m.cam.yaw = 0.9
	await frames(36)
	await shot("m1a3_v3detail_rts")
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30.0
	cam.current = true
	var fwd: Vector3 = neu.global_transform.basis.z
	var right: Vector3 = neu.global_transform.basis.x
	cam.global_position = neu.global_position + fwd * 3.5 + right * 2.55 + Vector3(0, 2.05, 0)
	cam.look_at(neu.global_position + Vector3(0, 0.7, 0.05), Vector3.UP)
	await frames(12)
	await shot("m1a3_v3detail_close")
	print("=== V3DETAIL SHOTS DONE")
	get_tree().quit(0)

## Copy the live tank's faction paint, team colour and weathering onto the candidate.
func _match_paint(neu: Node, old: Node) -> void:
	var src := old.find_child("Hull", true, false) as GeometryInstance3D
	for key in [&"paint_color", &"rust_amt", &"wear_amt", &"dirt_amt", &"team_color"]:
		var v: Variant = src.get_instance_shader_parameter(key)
		for g in neu.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).set_instance_shader_parameter(key, v)
