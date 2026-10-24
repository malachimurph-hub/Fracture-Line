extends "res://tests/m28_shots.gd"
## M3.0 preview screenshots (no release build):
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m30_shots.tscn -- <out_dir> <part>
## part: usbase | city | nature | eu | all
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m30"
	var p: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if p in ["usbase", "all"]:
		await run_usbase()
	if p in ["city", "all"]:
		await run_city()
	if p in ["nature", "all"]:
		await run_nature()
	if p in ["eu", "all"]:
		await run_eu()
	print("=== M30 SHOTS DONE")
	get_tree().quit(0)

func _unit(def: StringName, t: Vector2i, face: int, owner := 0) -> SimEntity:
	var u := sim.spawn_unit(def, owner, null, FX.tile_center(t))
	u.pos = FX.tile_center(t)
	u.face = face
	u.dir = FX.dir_of(u.face)
	u.home = u.pos
	_ensure(u)
	return u

func _bld(id: StringName, at: Vector2i) -> Vector2i:
	var bd: BuildingDef = Content.building(id)
	var t := _open_spot(bd.footprint, at)
	var b := sim._place_building(bd, 0, t, 0, true)
	_ensure(b)
	return t

func run_usbase() -> void:
	await _start("ochre_wells", ["us", "eu"], false)
	var c := Vector2i(40, 40)
	var ids := [&"us_command", &"us_supply_center", &"us_barracks", &"us_garage", &"us_reactor", &"us_strategy", &"us_drop_zone", &"us_firebase", &"us_patriot"]
	var spots := [Vector2i(0, 0), Vector2i(6, 0), Vector2i(11, 0), Vector2i(0, 6), Vector2i(6, 6), Vector2i(11, 6), Vector2i(16, 0), Vector2i(16, 6), Vector2i(16, 10)]
	for i in ids.size():
		_bld(ids[i], c + spots[i])
	var row := [&"us_halberd", &"us_bradley", &"us_lynx", &"us_picket", &"us_supply_truck", &"us_javelin"]
	for k in row.size():
		_unit(row[k], c + Vector2i(1 + k * 2, 11), FX.ANG / 4)
	_look(Vector2(c.x + 9, c.y + 7), 0)
	m.cam.dist = 22.0
	m.cam.target_dist = 22.0
	await frames(60)
	await shot("m30_us_base")

func run_city() -> void:
	await _start("crescent_city", ["us", "eu"], false)
	_unit(&"us_halberd", Vector2i(64, 70), FX.ANG / 4)
	_unit(&"us_bradley", Vector2i(66, 72), FX.ANG / 4)
	_look(Vector2(66, 74), 0)
	m.cam.dist = 20.0
	m.cam.target_dist = 20.0
	await frames(60)
	await shot("m30_city")

func run_nature() -> void:
	for mp in ["kessel_pass", "varno_crossing"]:
		await _start(mp, ["us", "eu"], false)
		var cl := _find([SimMap.T.CLIFF], Vector2i(60, 120))
		var t := _find([SimMap.T.FOREST], cl)
		_look(Vector2(cl.x * 0.7 + t.x * 0.3 + 3, cl.y * 0.7 + t.y * 0.3 + 3), 0)
		m.cam.dist = 26.0
		m.cam.target_dist = 26.0
		await frames(60)
		await shot("m30_nature_" + mp)

func run_eu() -> void:
	await _start("varno_crossing", ["eu", "us"], false)
	var c := Vector2i(60, 50)
	var t := _open_spot(Vector2i(18, 5), c)
	var row := [&"eu_leopold", &"eu_wolfhound", &"eu_boxer", &"eu_thunderhead", &"eu_flakwerk", &"eu_hearth"]
	for k in row.size():
		if Content.unit(row[k]) != null:
			_unit(row[k], t + Vector2i(k * 3, 1 + (k % 2) * 2), FX.ANG / 4)
	_look(Vector2(t.x + 8, t.y + 3), 0)
	m.cam.dist = 15.0
	m.cam.target_dist = 15.0
	await frames(60)
	await shot("m30_eu_units")
