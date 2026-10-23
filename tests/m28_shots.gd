extends Node
## M2.8 rendered screenshots (one per feedback item):
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m28_shots.tscn -- <out_dir> [all|water|map|airfield|infantry|crash] --dpi=450
var out_dir := "/tmp/m28"
var part := "all"
var m: Node
var sim: SimWorld

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	if args.size() > 1 and not args[1].begins_with("--"):
		part = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if part == "all" or "water" in part:
		await run_water()
	if part == "all" or "map" in part:
		await run_map()
	if part == "all" or "airfield" in part:
		await run_airfield()
	if part == "all" or "infantry" in part:
		await run_infantry()
	if part == "all" or "crash" in part:
		await run_crash()
	print("=== M28 SHOTS DONE")
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())

func _start(mid: String, facs: Array, fog: bool) -> void:
	if m != null:
		m.queue_free()
		await frames(2)
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 28
	cfg["map"] = mid
	for i in 4:
		cfg["slots"][i]["kind"] = "closed"
	for i in facs.size():
		cfg["slots"][i]["kind"] = "human" if i == 0 else "ai"
		cfg["slots"][i]["faction"] = facs[i]
		cfg["slots"][i]["team"] = i
		cfg["slots"][i]["spawn"] = i
	cfg["options"]["fog"] = fog
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	sim = m.runner.sim
	m.runner.ais.clear()

func _look(t: Vector2, lvl: int) -> void:
	m.cam.jump_to(Vector3(t.x, 0, t.y), false)
	m.cam.set_level(lvl)

func _find(ch: Array, from: Vector2i) -> Vector2i:
	## nearest tile of a type to `from`
	for r in 200:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := from + Vector2i(dx, dy)
				if sim.map.in_bounds(t) and ch.has(sim.map.ttype(t)):
					return t
	return from

func run_water() -> void:
	await _start("kessel_pass", ["us", "eu"], false)
	var t := _find([SimMap.T.WATER], Vector2i(40, 128))
	_look(Vector2(t.x + 2, t.y + 3), 0)
	await frames(40)
	await shot("water_kessel_winter")

func run_map() -> void:
	await _start("varno_crossing", ["us", "eu"], false)
	m.cam.jump_to(Vector3(128, 0, 128), false)
	m.cam.set_level(2)
	await frames(30)
	await shot("map_varno_256_overview")

func _open_spot(fp: Vector2i, near: Vector2i) -> Vector2i:
	for r in 60:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := near + Vector2i(dx, dy)
				var ok := true
				for yy in fp.y + 2:
					for xx in fp.x + 2:
						var c := t + Vector2i(xx - 1, yy - 1)
						ok = ok and sim.map.in_bounds(c) and sim.map.passable(c, true) and sim.map.occ[c.y * sim.map.w + c.x] == 0
				if ok:
					return t
	return near

func run_airfield() -> void:
	await _start("varno_crossing", ["us", "eu"], false)
	var bd: BuildingDef = Content.building(&"us_airfield")
	var t := _open_spot(bd.footprint, Vector2i(52, 40))
	var af := sim._place_building(bd, 0, t, 0, true)
	for def in [&"us_thunderlance", &"us_wraith"]:
		var u := sim.spawn_unit(def, 0, null, af.pos)
		AirSys.park_new(sim, af, u)
	var af2 := sim._place_building(Content.building(&"eu_airstrip"), 1, _open_spot(bd.footprint, t + Vector2i(12, 0)), 0, true)
	await frames(5)
	_look(Vector2(t.x + 4, t.y + 5), 0)
	m.cam.dist = 20.0
	m.cam.target_dist = 20.0
	await frames(40)
	await shot("airfield_us_parked_bomber_fighter")

func run_infantry() -> void:
	await _start("harrow_junction", ["us", "eu", "tpla"], false)
	var c := _open_spot(Vector2i(12, 6), Vector2i(60, 40))
	var row := [[0, [&"us_grunt", &"us_javelin", &"us_jtac", &"us_sniper"]], [1, [&"eu_grenadier", &"eu_lancer"]], [2, [&"tpla_militia", &"tpla_rocket_cell", &"tpla_laborer"]]]
	var z := 0
	for r in row:
		var x := 0
		for def in r[1]:
			var u := sim.spawn_unit(def, r[0], null, FX.tile_center(c + Vector2i(2 + x * 2, 1 + z * 2)))
			u.pos = FX.tile_center(c + Vector2i(2 + x * 2, 1 + z * 2))
			u.face = FX.ANG / 2
			u.dir = FX.dir_of(u.face)
			u.home = u.pos
			x += 1
		z += 1
	await frames(5)
	_look(Vector2(c.x + 5, c.y + 3.5), 0)
	m.cam.dist = 9.0
	m.cam.target_dist = 9.0
	await frames(40)
	await shot("infantry_weapons_us_eu_tpla")

func run_crash() -> void:
	await _start("varno_crossing", ["us", "eu"], false)
	var p := Vector2i(128, 100)
	var us: Array = []
	for k in 2:
		var u := sim.spawn_unit([&"us_thunderlance", &"us_harrier"][k], 0, null, FX.tile_center(p + Vector2i(k * 6, 0)))
		u.air_state = AirSys.FLYING
		us.append(u)
		m.runner.issue({"p": 0, "t": "move", "ids": [u.id], "pos": FX.tile_center(p + Vector2i(k * 6 - 30, 2))})
	_look(Vector2(p.x - 6, p.y + 6), 1)
	await frames(120)
	for u: SimEntity in us:
		sim._kill(u, null)
	await frames(18)
	await shot("aircraft_crash")
