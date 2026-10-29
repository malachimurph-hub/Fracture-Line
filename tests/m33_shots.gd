extends "res://tests/m30_shots.gd"
## M3.3 Phase 3 screenshots (no release build):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
##     --rendering-method mobile res://tests/m33_shots.tscn -- <out_dir> <part>
## part: night | civ | mine | hills | maps
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m33"
	var p: String = args[1] if args.size() > 1 else "night"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if p == "night":
		await run_night()
	elif p == "civ":
		await run_civ()
	elif p == "mine":
		await run_mine()
	elif p == "hills":
		await run_hills()
	elif p.begins_with("map:"):
		await run_map_view(p.substr(4))
	print("=== M33 SHOTS DONE")
	get_tree().quit(0)

func _nearest_lamp(to: Vector2) -> Vector2:
	var best := Vector2(-1, -1)
	for l in m.world.terrain.lamps:
		var p := Vector2(l[0], l[1])
		if best.x < 0 or p.distance_to(to) < best.distance_to(to):
			best = p
	return best

func run_night() -> void:
	await _start("riverside_metro_night", ["us", "eu"], false)
	var hq := Vector2i(30, 30)
	_bld(&"us_barracks", hq + Vector2i(6, 0))
	_bld(&"us_reactor", hq + Vector2i(0, 6))
	_bld(&"us_garage", hq + Vector2i(6, 6))
	for k in 4:
		_unit([&"us_halberd", &"us_bradley", &"us_lynx", &"us_halberd"][k], hq + Vector2i(12, 2 + k * 3), FX.ANG / 4)
	_look(Vector2(hq.x + 8, hq.y + 7), 0)
	m.cam.dist = 24.0
	m.cam.target_dist = 24.0
	await frames(50)
	await shot("night_base")
	var lp := _nearest_lamp(Vector2(90, 70))
	for k in 3:
		_unit([&"us_halberd", &"us_bradley", &"us_lynx"][k], Vector2i(int(lp.x) + k * 3 - 3, int(lp.y) + 2), FX.ANG / 4)
	_look(lp + Vector2(0, 3), 0)
	m.cam.dist = 20.0
	m.cam.target_dist = 20.0
	await frames(50)
	await shot("night_city")

func run_civ() -> void:
	await _start("riverside_metro", ["us", "eu"], false)
	var house: SimEntity = null
	var lp := _nearest_lamp(Vector2(100, 80))
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if sim.is_civilian(e) and (house == null or Vector2(FX.to_tile(e.pos)).distance_to(lp) < Vector2(FX.to_tile(house.pos)).distance_to(lp)):
			house = e
	var c := Vector2(FX.to_tile(house.pos))
	m.world._ensure_view(house)
	await frames(5)
	m.world._on_death({"t": "death", "id": house.id, "kind": house.kind, "def": house.def_id, "pos": house.pos, "owner": -1})
	house.alive = false
	sim.map.unstamp(house.tile, house.fp)
	# wreck the parked cars nearest the ruin
	for k in 4:
		var best: Variant = null
		for tk in m.world.terrain._cars:
			for car in m.world.terrain._cars[tk]:
				if best == null or (car[2] as Vector2).distance_to(c) < (best[2] as Vector2).distance_to(c):
					best = car
		if best != null:
			m.world._wreck_cars(Vector3(best[2].x, 0, best[2].y), 0.4)
	_unit(&"us_halberd", Vector2i(int(c.x) + 4, int(c.y) + 4), FX.ANG / 3)
	_look(c + Vector2(1, 3), 0)
	m.cam.dist = 16.0
	m.cam.target_dist = 16.0
	await frames(60)
	await shot("civ_rubble_cars")

func run_mine() -> void:
	await _start("ochre_wells", ["ecc", "us"], false)
	var c := Vector2i(44, 40)
	var t := _bld(&"ecc_black_market", c)
	var u := _unit(&"ecc_mine_mobile", c + Vector2i(7, 1), FX.ANG / 4)
	_unit(&"ecc_engineer", c + Vector2i(7, 5), FX.ANG / 4)
	_look(Vector2(c.x + 5, c.y + 3), 0)
	m.cam.dist = 16.0
	m.cam.target_dist = 16.0
	await frames(50)
	await shot("mine_move")

func run_map_view(mid: String) -> void:
	await _start(mid, ["us", "eu"], false)
	var md: MapDef = Content.maps[StringName(mid)]
	_look(Vector2(md.size.x * 0.5, md.size.y * 0.5), 0)
	m.cam.dist = 30.0
	m.cam.target_dist = 30.0
	await frames(50)
	await shot("map_" + mid)

## M3.3 P3 (17): vehicles tilt on a hillside; a structure on a slope stands on a concrete plinth.
func run_hills() -> void:
	await _start("harvest_valley", ["us", "tpla"], false)
	var md: MapDef = Content.maps[&"harvest_valley"]
	var hl: Array = md.hills[2]
	var c := Vector2i(int(hl[0]), int(hl[1]))
	_bld(&"us_barracks", c + Vector2i(-int(hl[2]) / 2 - 2, -2))
	for k in 5:
		_unit([&"us_halberd", &"us_bradley", &"us_lynx", &"us_halberd", &"us_bradley"][k], c + Vector2i(k * 3 - 6, 3 + (k % 2) * 3), FX.ANG / 4 + k * 200)
	_look(Vector2(c.x - 2, c.y + 3), 0)
	m.cam.dist = 22.0
	m.cam.target_dist = 22.0
	await frames(60)
	await shot("hills_valley2")
	_look(Vector2(md.size.x * 0.3, md.size.y * 0.32), 0)
	m.cam.dist = 34.0
	m.cam.target_dist = 34.0
	await frames(50)
	await shot("hills_fields2")
