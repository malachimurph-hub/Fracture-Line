extends "res://tests/m30_shots.gd"
## M3.2 screenshots (no release build):
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m32_shots.tscn -- <out_dir> <gfx|new> [name]
## gfx: the same RTS-zoom base + battle scene (graphics before/after)
## new: barricades (manned), Drone Operator + drones, Field Engineer + mines, a bridge
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m32"
	var p: String = args[1] if args.size() > 1 else "gfx"
	var nm: String = args[2] if args.size() > 2 else "m32_" + p
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if p == "gfx":
		await run_gfx(nm)
	elif p == "new":
		await run_new(nm)
	get_tree().quit(0)

func run_gfx(nm: String) -> void:
	await _start("ochre_wells", ["us", "eu"], false)
	var c := Vector2i(40, 40)
	_bld(&"us_command", c)
	_bld(&"us_barracks", c + Vector2i(6, 0))
	_bld(&"us_reactor", c + Vector2i(11, 1))
	_bld(&"us_patriot", c + Vector2i(11, 5))
	_bld(&"us_garage", c + Vector2i(0, 6))
	var row := [&"us_halberd", &"us_halberd", &"us_bradley", &"us_lynx", &"us_dozer"]
	for k in row.size():
		_unit(row[k], c + Vector2i(6 + k * 2, 8), FX.ANG / 8)
	for k in 6:
		_unit(&"us_grunt", c + Vector2i(5 + k, 11), FX.ANG / 8)
	var foe := [&"eu_leopold", &"eu_leopold", &"eu_boxer", &"eu_wolfhound"]
	for k in foe.size():
		_unit(foe[k], c + Vector2i(8 + k * 2, 15), FX.ANG / 2 + FX.ANG / 8, 1)
	_look(Vector2(c.x + 8, c.y + 8), 1)
	await frames(60)
	await shot(nm)

func run_new(nm: String) -> void:
	pass
