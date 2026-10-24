extends "res://tests/m28_shots.gd"
## M3.0 preview screenshots (no release build):
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m30_shots.tscn -- <out_dir> <part>
## part: usbase | city | nature | eu | de | ir | ru | all  (de / ir / ru: national roster lineups)
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
	if p in ["de", "all"]:
		await run_lineup("eu", [[&"eu_leopold", &"eu_brennus", &"eu_salamander", &"eu_boxer", &"eu_wolfhound", &"eu_flakwerk", &"eu_hearth"],
			[&"eu_aegis", &"eu_spectre", &"eu_sentinel", &"eu_thunderhead", &"eu_kestrel", &"eu_corvid"]], "m30e_germany_lineup")
	if p in ["ir", "all"]:
		await run_lineup("tpla", [[&"tpla_scrapback", &"tpla_bus", &"tpla_hailstorm", &"tpla_blight", &"tpla_shrike", &"tpla_rattler"],
			[&"tpla_f16", &"tpla_mirage", &"tpla_mig29", &"tpla_pickup", &"tpla_backhoe"]], "m30e_iran_lineup")
	if p in ["ru", "all"]:
		await run_ru()
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

## M3.0 E: two rows of a faction's vehicles and aircraft on open ground.
func run_lineup(fac: String, rows: Array, name: String) -> void:
	await _start("varno_crossing", [fac, "us"], false)
	var t := _open_spot(Vector2i(24, 9), Vector2i(60, 50))
	for r in rows.size():
		var row: Array = rows[r]
		for k in row.size():
			_unit(row[k], t + Vector2i(1 + k * 3 + r * 4, 1 + r * 4), FX.ANG / 4)
	_look(Vector2(t.x + 8, t.y + 2), 0)
	m.cam.dist = 21.0
	m.cam.target_dist = 21.0
	await frames(60)
	await shot(name)

## M3.0 F: Russia lineup framed in the clear middle of the screen (away from minimap and panels).
func run_ru() -> void:
	await _start("varno_crossing", ["ecc", "us"], false)
	var t := _open_spot(Vector2i(14, 12), Vector2i(60, 50))
	var rows := [[&"ecc_t90", &"ecc_msta", &"ecc_zeus", &"ecc_engineer"], [&"ecc_btr", &"ecc_typhoon", &"ecc_tigr", &"ecc_cargo_truck"],
		[&"ecc_rifleman", &"ecc_machine_gunner", &"ecc_rpg", &"ecc_infiltrator"]]
	for r in rows.size():
		for k in rows[r].size():
			var sp := 3 if r < 2 else 2
			_unit(rows[r][k], t + Vector2i(2 + k * sp + (3 if r == 2 else 0), 1 + r * 3 - (1 if r == 2 else 0)), FX.ANG / 4)
	_look(Vector2(t.x + 7, t.y + 4), 0)
	m.cam.dist = 16.0
	m.cam.target_dist = 16.0
	await frames(60)
	await shot("m30f_russia_lineup")
	if OS.get_environment("RU_BASE") != "":   # tool check of the stand-in buildings (not a deliverable)
		var bt := _open_spot(Vector2i(18, 10), Vector2i(40, 60))
		var bl := [[&"ecc_hq", Vector2i(2, 2)], [&"ecc_power", Vector2i(7, 2)], [&"ecc_depot", Vector2i(11, 2)], [&"ecc_barracks", Vector2i(15, 2)],
			[&"ecc_factory", Vector2i(2, 7)], [&"ecc_bunker", Vector2i(8, 7)], [&"ecc_aa_site", Vector2i(11, 7)]]
		for e in bl:
			var b := sim._place_building(Content.building(e[0]), 0, bt + e[1], 0, true)
			_ensure(b)
		_look(Vector2(bt.x + 9, bt.y + 5), 0)
		m.cam.dist = 18.0
		m.cam.target_dist = 18.0
		await frames(60)
		await shot("ru_base_check")
