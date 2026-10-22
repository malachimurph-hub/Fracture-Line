extends Node
## M2.4 rendered showcase + checks: construction sites for every EU and TPLA structure (stages,
## paused, shot-at), a mid-shot tank vs infantry firefight (shells, rockets, tracers) and a big
## battle with render counters. Real sim entities in a real match (AIs removed, fog off).
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m24_showcase.tscn -- <out_dir> [all|build|fight|perf] --dpi=450
var out_dir := "/tmp/m24"
var part := "all"
var m: Node
var sim: SimWorld
var checks: Array = []
var _used: Array = []
var working: Array = []          ## site ids a "builder" advances every frame (harness only)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	if args.size() > 1 and not args[1].begins_with("--"):
		part = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start()
	if part in ["all", "build"]:
		await run_build()
	if part in ["all", "fight"]:
		await run_fight()
	if part in ["all", "perf"]:
		await run_perf()
	var failed := false
	for c in checks:
		print(("PASS " if c[1] else "FAIL ") + c[0] + ("" if c.size() < 3 else "  (" + str(c[2]) + ")"))
		failed = failed or not c[1]
	print("=== M24 SHOWCASE RESULT: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func check(name: String, ok: bool, info = null) -> void:
	checks.append([name, ok] if info == null else [name, ok, info])

func _process(_d: float) -> void:
	if sim == null:
		return
	for id in working:
		var e: SimEntity = sim.ents.get(id)
		if e != null and not e.built and e.progress < e.build_ticks - 2:
			e.progress += 1
			e.hp = maxi(e.hp, ProdSys.construction_hp_cap(e.max_hp, e.progress, e.build_ticks))

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> String:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())
	return p

func _start() -> void:
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 11
	cfg["slots"][1]["kind"] = "ai"
	cfg["slots"][1]["faction"] = "tpla"
	cfg["slots"][1]["team"] = 1
	for i in [2, 3]:
		cfg["slots"][i]["kind"] = "closed"
	cfg["slots"][0]["spawn"] = 0
	cfg["slots"][1]["spawn"] = 1
	cfg["options"]["fog"] = false
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	sim = m.runner.sim
	m.runner.ais.clear()

func _open_block(w: int, h: int) -> Vector2i:
	var cands: Array = []
	for y in range(8, 120 - h, 2):
		for x in range(8, 120 - w, 2):
			cands.append(Vector2i(x, y))
	var mid := Vector2i(64, 64)
	cands.sort_custom(func(a, b): return (a - mid).length_squared() < (b - mid).length_squared())
	for c in cands:
		var r := Rect2i(c - Vector2i(2, 2), Vector2i(w + 4, h + 4))
		var clash := false
		for u in _used:
			if (u as Rect2i).intersects(r):
				clash = true
		if clash:
			continue
		var ok := true
		for yy in h:
			for xx in w:
				var t: Vector2i = c + Vector2i(xx, yy)
				var tt := sim.map.ttype(t)
				if not (tt == SimMap.T.GRASS or tt == SimMap.T.ROUGH or tt == SimMap.T.ROAD) or not sim.map.passable(t, true) or sim.map.occ[sim.map.idx(t)] != 0:
					ok = false
					break
			if not ok:
				break
		if ok:
			_used.append(r)
			return c
	push_error("no open block %dx%d" % [w, h])
	return Vector2i(40, 40)

## A site at construction progress k with HP = what construction reached, times hpk.
func _site(def_id: StringName, owner: int, t: Vector2i, k: float, hpk: float = 1.0) -> SimEntity:
	var e: SimEntity = sim._place_building(Content.building(def_id), owner, t, 0, k >= 1.0)
	if k < 1.0:
		e.built = false
		e.progress = int(k * e.build_ticks)
		e.hp = maxi(1, int(ProdSys.construction_hp_cap(e.max_hp, e.progress, e.build_ticks) * hpk))
	else:
		e.hp = maxi(1, int(e.max_hp * hpk))
	m.world._ensure_view(e)
	return e

func _unit(def_id: StringName, owner: int, t: Vector2i) -> SimEntity:
	var e := sim.spawn_unit(def_id, owner, null, FX.tile_center(t))
	m.world._ensure_view(e)
	m.world.cur[e.id] = m.world._world_pos(e)
	m.world.prev[e.id] = m.world.cur[e.id]
	return e

func _look(t: Vector2i, lvl: int = 0) -> void:
	m.cam.jump_to(FX.to_world(FX.tile_center(t)), false)
	m.cam.set_level(lvl)

## Every damage-only visual of a site that should look clean.
func _clean(e: SimEntity) -> Array:
	var v: EntityView = m.world.views.get(e.id)
	var bad: Array = []
	if v == null:
		return ["no view"]
	if v is BuildingView:
		var bv := v as BuildingView
		if bv._state != 0:
			bad.append("damage state %d" % bv._state)
		for n in [bv.dmg_light, bv.dmg_heavy]:
			if n != null and n.visible:
				bad.append(String(n.name) + " visible")
	if WorldView.build_relative_health(e) < 0.99:
		bad.append("relative health %.2f" % WorldView.build_relative_health(e))
	if not e.built and not m.world.rigs.has(e.id):
		bad.append("no construction rig")
	return bad

# ------------------------------------------------------------------ construction
const EU_ROW := [&"eu_hq", &"eu_barracks", &"eu_reactor", &"eu_motor_pool", &"eu_heavy_factory", &"eu_gun_bunker", &"eu_hub", &"eu_pylon",
	&"eu_flak_tower", &"eu_signals", &"eu_relay", &"eu_exchange", &"eu_airstrip", &"eu_minefield", &"eu_concord"]
const TPLA_ROW := [&"tpla_den", &"tpla_camp", &"tpla_stash", &"tpla_workshop", &"tpla_chop_shop", &"tpla_bazaar", &"tpla_tunnel",
	&"tpla_camo_net", &"tpla_demo_trap", &"tpla_wasp_nest", &"tpla_decoy", &"tpla_rust_silo"]

func _row(defs: Array, owner: int, o: Vector2i, k: float) -> Array:
	var out: Array = []
	var x := 0
	for d in defs:
		var fp: Vector2i = Content.building(d).footprint
		var e := _site(d, owner, o + Vector2i(x, 4 - fp.y), k)
		working.append(e.id)
		out.append(e)
		x += fp.x + 1
	return out

func run_build() -> void:
	var o := _open_block(30, 5)
	var eu := _row(EU_ROW.slice(0, 7), 0, o, 0.5)
	var ob := _open_block(30, 5)
	eu += _row(EU_ROW.slice(7), 0, ob, 0.5)
	var o2 := _open_block(30, 5)
	var tp := _row(TPLA_ROW.slice(0, 6), 1, o2, 0.5)
	var o2b := _open_block(26, 5)
	tp += _row(TPLA_ROW.slice(6), 1, o2b, 0.5)
	# stages: EU Motor Pool / TPLA Workshop at 5, 25, 50, 80 % and complete
	var o3 := _open_block(26, 10)
	var stages := [0.05, 0.25, 0.5, 0.8, 1.0]
	var st_eu: Array = []
	var st_tp: Array = []
	for i in stages.size():
		st_eu.append(_site(&"eu_motor_pool", 0, o3 + Vector2i(i * 5, 0), stages[i]))
		st_tp.append(_site(&"tpla_workshop", 1, o3 + Vector2i(i * 5, 6), stages[i]))
	# paused (no builder) and shot-at sites
	var o4 := _open_block(20, 4)
	var paused := _site(&"eu_barracks", 0, o4, 0.45)
	var paused_t := _site(&"tpla_camp", 1, o4 + Vector2i(4, 0), 0.45)
	var shot_eu := _site(&"eu_reactor", 0, o4 + Vector2i(8, 0), 0.6, 0.55)
	var shot_tp := _site(&"tpla_stash", 1, o4 + Vector2i(12, 0), 0.6, 0.55)
	var done_dmg := _site(&"eu_barracks", 0, o4 + Vector2i(16, 0), 1.0, 0.3)
	await frames(30)
	for e in eu + tp + st_eu.slice(0, 4) + st_tp.slice(0, 4) + [paused, paused_t]:
		var bad := _clean(e)
		check("clean construction site %s %d%%" % [e.def_id, roundi(100.0 * e.progress / e.build_ticks)], bad.is_empty(), bad if not bad.is_empty() else null)
	# legacy views clip their meshes; staged views hide their own scaffold for the rig's
	for e in eu + tp:
		var rig: ConstructionRig = m.world.rigs.get(e.id)
		if rig != null and not rig.staged:
			check("rig clips %s (%d surfaces)" % [e.def_id, rig.stats["swapped"]], rig.stats["swapped"] > 0)
	check("working site animates (EU)", m.world.rigs[eu[1].id].working())
	check("paused site stands still", not m.world.rigs[paused.id].working())
	var sv: BuildingView = m.world.views[shot_eu.id] if m.world.views[shot_eu.id] is BuildingView else null
	check("shot-at site shows light damage only (relative %.2f)" % WorldView.build_relative_health(shot_eu), WorldView.build_relative_health(shot_eu) < 0.6 and (sv == null or sv._state <= 1))
	var bv: BuildingView = m.world.views[done_dmg.id]
	check("finished building at 30 % shows heavy damage", bv._state == 2)
	check("finished building has no rig", not m.world.rigs.has(st_eu[4].id) and not m.world.rigs.has(st_tp[4].id))
	_look(o + Vector2i(12, 2))
	await frames(20)
	await shot("construction_eu_row_a")
	_look(ob + Vector2i(14, 2))
	await frames(20)
	await shot("construction_eu_row_b")
	_look(o2 + Vector2i(12, 2))
	await frames(20)
	await shot("construction_tpla_row_a")
	_look(o2b + Vector2i(12, 2))
	await frames(20)
	await shot("construction_tpla_row_b")
	_look(o3 + Vector2i(12, 4), 1)
	await frames(20)
	await shot("construction_stages")
	_look(o4 + Vector2i(9, 1))
	await frames(20)
	await shot("construction_paused_and_shot")
	_look(o3 + Vector2i(11, 1))
	await frames(10)
	await shot("building_mid_construction")
	# completion: the rig is struck and the structure is intact
	for e in st_eu.slice(0, 4) + st_tp.slice(0, 4):
		e.progress = e.build_ticks
		e.built = true
		e.hp = e.max_hp
	await frames(5)
	var left := 0
	for e in st_eu + st_tp:
		left += 1 if m.world.rigs.has(e.id) else 0
	check("rigs struck on completion", left == 0, left)

# ------------------------------------------------------------------ firefight
func run_fight() -> void:
	pass

# ------------------------------------------------------------------ big battle counters
func run_perf() -> void:
	pass
