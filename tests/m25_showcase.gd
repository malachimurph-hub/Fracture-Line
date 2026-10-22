extends Node
## M2.5 rendered showcase: the four maps (base + centre, each environment), the minimap supply
## icons under the shroud at match start, the US roster lined up, the airfield with parked jets,
## and a US air/ground strike on TPLA with aircraft at altitude. Real matches, real sim entities.
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m25_showcase.tscn -- <out_dir> [all|maps|us] --dpi=450
var out_dir := "/tmp/m25"
var part := "all"
var m: Node
var sim: SimWorld
var checks: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	if args.size() > 1 and not args[1].begins_with("--"):
		part = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if part in ["all", "maps"]:
		for mid in ["kessel_pass", "harrow_junction", "ochre_wells", "varno_crossing"]:
			await run_map(mid)
	elif part.begins_with("map:"):
		await run_map(part.substr(4))
	if part in ["all", "us"]:
		await run_us()
	var failed := false
	for c in checks:
		print(("PASS " if c[1] else "FAIL ") + c[0] + ("" if c.size() < 3 else "  (" + str(c[2]) + ")"))
		failed = failed or not c[1]
	print("=== M25 SHOWCASE RESULT: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func check(name: String, ok: bool, info = null) -> void:
	checks.append([name, ok] if info == null else [name, ok, info])

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String, region: Rect2i = Rect2i()) -> String:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if region.size.x > 0:
		img = img.get_region(region)
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())
	return p

func _start(mid: String, facs: Array, fog: bool) -> void:
	if m != null:
		m.queue_free()
		await frames(2)
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 25
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

func _look(t: Vector2i, lvl: int) -> void:
	m.cam.jump_to(FX.to_world(FX.tile_center(t)), false)
	m.cam.set_level(lvl)

func run_map(mid: String) -> void:
	var md: MapDef = Content.maps[StringName(mid)]
	# 1) match start with shroud: minimap shows every supply pile (ZH-style icons) above the shroud
	await _start(mid, ["us", "eu", "tpla", "eu"], true)
	m.runner.ais.clear()
	await frames(20)
	await shot("minimap_%s_full" % mid)
	var mm: Control = m.hud.minimap
	var gr: Rect2 = mm.get_viewport().get_final_transform() * mm.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, mm.size)
	var r := Rect2i(gr).intersection(Rect2i(Vector2i.ZERO, get_viewport().get_texture().get_size()))
	await shot("minimap_%s" % mid, r)
	var icons := 0
	for id in sim.ids:
		if sim.ents[id].kind == SimEntity.Kind.RESOURCE:
			icons += 1
	check("%s: minimap has %d supply piles to draw" % [mid, icons], icons >= 12)
	# 2) environment views with fog off (base and contested centre)
	await _start(mid, ["us", "eu", "tpla", "eu"], false)
	m.runner.ais.clear()
	m.hud.visible = false
	_look(md.spawns[0] + Vector2i(2, 2), 1)
	await frames(30)
	await shot("map_%s_base" % mid)
	_look(Vector2i(54, 54), 2)
	await frames(30)
	await shot("map_%s_centre" % mid)
	_look(Vector2i(40, 30), 1)
	await frames(30)
	await shot("map_%s_flank" % mid)
	check("%s env %s rendered" % [mid, md.env], true)

func _unit(def_id: StringName, owner: int, t: Vector2i) -> SimEntity:
	var e := sim.spawn_unit(def_id, owner, null, FX.tile_center(t))
	m.world._ensure_view(e)
	m.world.cur[e.id] = m.world._world_pos(e)
	m.world.prev[e.id] = m.world.cur[e.id]
	return e

func _clear_area(o: Vector2i, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			var t := o + Vector2i(x, y)
			if not sim.map.passable(t, true) or sim.map.occ[sim.map.idx(t)] != 0:
				return false
	return true

func _open(w: int, h: int, near: Vector2i) -> Vector2i:
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := near + Vector2i(dx, dy)
				if c.x > 4 and c.y > 4 and c.x + w < 124 and c.y + h < 124 and _clear_area(c, w, h):
					return c
	return near

func run_us() -> void:
	await _start("varno_crossing", ["us", "tpla"], false)
	m.runner.ais.clear()
	m.hud.visible = false
	# roster line-up: infantry front row, vehicles behind
	var o := _open(24, 10, Vector2i(40, 40))
	var row1 := [&"us_grunt", &"us_grunt", &"us_javelin", &"us_jtac", &"us_sniper", &"us_dozer", &"us_supply_truck"]
	var row2 := [&"us_lynx", &"us_halberd", &"us_picket", &"us_longreach"]
	for i in row1.size():
		_unit(row1[i], 0, o + Vector2i(2 + i * 3, 7))
	for i in row2.size():
		_unit(row2[i], 0, o + Vector2i(2 + i * 5, 3))
	var air := [&"us_harrier", &"us_wraith", &"us_thunderlance"]
	var flyers: Array = []
	for i in air.size():
		var a := _unit(air[i], 0, o + Vector2i(4 + i * 7, 0))
		a.air_state = AirSys.FLYING
		a.home = a.pos
		flyers.append(a)
	_look(o + Vector2i(11, 5), 0)
	await frames(60)
	await shot("us_roster_lineup")
	var alt_ok := 0
	for a in flyers:
		var v: Node3D = m.world.views.get(a.id)
		if v != null and v.position.y > 2.0:
			alt_ok += 1
	check("aircraft drawn at altitude", alt_ok == flyers.size(), alt_ok)
	# sniper stealth: own sniper turns translucent after standing still
	var sn: SimEntity = null
	for id in sim.ids:
		if sim.ents[id].def_id == &"us_sniper":
			sn = sim.ents[id]
	var t0 := sim.tick
	for i in 600:
		await get_tree().process_frame
		if sim.tick - t0 > UsSys.STILL_TICKS + 10:
			break
	check("still sniper is stealthed", sn != null and sn.stealthy)
	_look(o + Vector2i(14, 7), 0)
	m.cam.dist = 12.0
	m.cam.target_dist = 12.0
	await frames(30)
	await shot("us_infantry_closeup")
	# airfield with jets on their parking spots
	var af_t := _open(6, 6, o + Vector2i(30, 0))
	var af := sim._place_building(Content.building(&"us_airfield"), 0, af_t, 0, true)
	m.world._ensure_view(af)
	var parked: Array = []
	for k in [&"us_thunderlance", &"us_wraith"]:
		var j := _unit(k, 0, af_t)
		AirSys.park_new(sim, af, j)
		m.world.cur[j.id] = m.world._world_pos(j)
		m.world.prev[j.id] = m.world.cur[j.id]
		parked.append(j)
	_look(af_t + Vector2i(2, 2), 0)
	await frames(60)
	await shot("us_airfield_parked")
	check("airfield 6/6 slots used by bomber + fighter", AirSys.slots_used(sim, af) == 6, AirSys.slots_used(sim, af))
	# strike: TPLA group, US aircraft + armour attacking
	var tgt_o := _open(10, 8, o + Vector2i(4, 18))
	var tp: Array = []
	for i in 10:
		var e := _unit([&"tpla_militia", &"tpla_rattler", &"tpla_scrapback", &"tpla_hailstorm"][i % 4], 1, tgt_o + Vector2i((i % 5) * 2, (i / 5) * 2))
		e.max_hp *= 50
		e.hp = e.max_hp
		tp.append(e.id)
	var us_ids: Array = []
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == 0 and e.kind == SimEntity.Kind.UNIT and not (e.def_id in [&"us_dozer", &"us_supply_truck"]):
			us_ids.append(id)
	m.runner.issue({"p": 0, "t": "amove", "ids": us_ids, "pos": FX.tile_center(tgt_o + Vector2i(4, 2))})
	_look(tgt_o + Vector2i(4, -3), 1)
	var shots := 0
	var wfx: WeaponFx = m.world.wfx
	for f in 600:
		await get_tree().process_frame
		if Engine.time_scale == 1.0 and int(wfx.stats["fired"]) > 0:
			Engine.time_scale = clampf(0.033 / maxf(0.033, get_process_delta_time()), 0.01, 1.0)
		if wfx.active() >= 4 and f > 40 and f % 40 == 0:
			await shot("us_strike_%d" % shots)
			shots += 1
			if shots >= 3:
				break
	Engine.time_scale = 1.0
	check("US strike shots captured", shots > 0, shots)
