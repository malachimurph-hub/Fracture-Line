extends "res://tests/m28_shots.gd"
## M2.9 screenshots: urban map, TPLA defences, BHX-35.
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m29_shots.tscn -- <out_dir> --dpi=450

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 and not args[0].begins_with("--") else "/tmp/m29"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("crescent_city", ["tpla", "us"], false)
	var row := [&"tpla_scrapback", &"tpla_hailstorm", &"tpla_rattler", &"tpla_bus", &"tpla_shrike", &"tpla_blight"]
	for k in row.size():
		_unit(row[k], Vector2i(59 + (k % 2) * 1, 64 + k * 3), FX.ANG / 4)
	_look(Vector2(66, 74), 1)
	m.cam.dist = 34.0
	m.cam.target_dist = 34.0
	await frames(60)
	await shot("m29_urban_crescent_city")
	# TPLA defences in the base
	var defs := [&"tpla_tunnel", &"tpla_wasp_nest", &"tpla_demo_trap", &"tpla_camo_net", &"tpla_decoy"]
	var x := 40
	for d in defs:
		var bd: BuildingDef = Content.building(d)
		var b := sim._place_building(bd, 0, Vector2i(x, 44), 0, true)
		_ensure(b)
		x += bd.footprint.x + 2
	for k in 2:
		_unit([&"tpla_militia", &"tpla_marksman"][k], Vector2i(42 + k * 6, 48), FX.ANG / 2)
	_look(Vector2(47, 46), 0)
	m.cam.dist = 15.0
	m.cam.target_dist = 15.0
	await frames(60)
	await shot("m29_tpla_defenses")
	# BHX-35 close-up
	var u := _unit(&"tpla_hailstorm", Vector2i(44, 20), FX.ANG * 3 / 8)
	_look(Vector2(44.5, 20.5), 0)
	m.cam.dist = 6.5
	m.cam.target_dist = 6.5
	await frames(60)
	await shot("m29_bhx35")
	print("=== M29 SHOTS DONE ", u.id)
	get_tree().quit(0)

func _unit(def: StringName, t: Vector2i, face: int) -> SimEntity:
	var u := sim.spawn_unit(def, 0, null, FX.tile_center(t))
	u.pos = FX.tile_center(t)
	u.face = face
	u.dir = FX.dir_of(u.face)
	u.home = u.pos
	_ensure(u)
	return u
