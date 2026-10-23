extends "res://tests/m28_shots.gd"
## M2.9 terrain before/after: the same Varno Crossing view.
##   xvfb-run ... res://tests/m29_terrain_shot.tscn -- <out_dir> <name>
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m29"
	var nm: String = args[1] if args.size() > 1 else "terrain"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["us", "eu"], false)
	_look(Vector2(70, 52), 1)
	m.cam.dist = 42.0
	m.cam.target_dist = 42.0
	await frames(60)
	await shot(nm)
	get_tree().quit(0)
