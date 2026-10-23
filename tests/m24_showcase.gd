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
const EU_ROW := [&"eu_hq", &"eu_barracks", &"eu_reactor", &"eu_motor_pool", &"eu_heavy_factory", &"eu_gun_bunker", &"eu_hub",
	&"eu_flak_tower", &"eu_signals", &"eu_relay", &"eu_exchange", &"eu_airstrip", &"eu_minefield"]
const TPLA_ROW := [&"tpla_den", &"tpla_camp", &"tpla_stash", &"tpla_workshop", &"tpla_chop_shop", &"tpla_bazaar", &"tpla_tunnel",
	&"tpla_camo_net", &"tpla_demo_trap", &"tpla_wasp_nest"]

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
func _tough(e: SimEntity) -> SimEntity:
	e.max_hp *= 1000
	e.hp = e.max_hp
	return e

func _army(spec: Array, owner: int, o: Vector2i, cols: int) -> Array:
	var ids: Array = []
	var i := 0
	for it in spec:
		for k in int(it[1]):
			var t := o + Vector2i((i % cols) * 2, (i / cols) * 2)
			ids.append(_tough(_unit(it[0], owner, t)).id)
			i += 1
	return ids

func run_fight() -> void:
	var o := _open_block(22, 16)
	# EU (south) vs TPLA (north), about 7 tiles apart: tanks, missile and rifle infantry, flak,
	# a flamer and artillery behind; TPLA rifles, RPG cells, technicals, rocket buggy, quad gun
	var eu := _army([[&"eu_leopold", 2], [&"eu_brennus", 1], [&"eu_lancer", 2], [&"eu_grenadier", 3], [&"eu_flakwerk", 1], [&"eu_salamander", 1]], 0, o + Vector2i(1, 11), 5)
	eu += _army([[&"eu_thunderhead", 1], [&"eu_hearth", 1]], 0, o + Vector2i(6, 15), 2)
	var tp := _army([[&"tpla_militia", 4], [&"tpla_rocket_cell", 2], [&"tpla_rattler", 2], [&"tpla_shrike", 1], [&"tpla_hailstorm", 1], [&"tpla_scrapback", 1], [&"tpla_sprayer", 1]], 1, o + Vector2i(1, 1), 6)
	tp += _army([[&"tpla_blight", 1]], 1, o + Vector2i(14, 0), 1)
	m.runner.issue({"p": 0, "t": "amove", "ids": eu, "pos": FX.tile_center(o + Vector2i(6, 3))})
	m.runner.issue({"p": 1, "t": "amove", "ids": tp, "pos": FX.tile_center(o + Vector2i(6, 12))})
	_look(o + Vector2i(6, 7), 0)
	await frames(10)
	var wfx: WeaponFx = m.world.wfx
	var best := -1
	var n := 0
	var shots_taken := 0
	# software rendering runs at ~1 frame/s, which would let a 0.2 s shell flight start and land
	# between two frames; once the guns open up, slow game time (sim and view alike) so a frame
	# is ~1/30 s of battle, like on the phone
	for f in 420:
		await get_tree().process_frame
		if Engine.time_scale == 1.0 and int(wfx.stats["fired"]) > 0:
			Engine.time_scale = clampf(0.033 / maxf(0.033, get_process_delta_time()), 0.01, 1.0)
			print("FIREFIGHT engaged at frame %d, time_scale %.3f" % [f, Engine.time_scale])
		var c := wfx.count_class(["cannon", "artillery"])
		var r := wfx.count_class(["rocket", "missile", "salvo"])
		var t := wfx.count_class(["rifle", "mg", "quad", "autocannon"])
		var score := mini(c, 2) * 4 + mini(r, 2) * 4 + mini(t, 6)
		if c >= 1 and r >= 1 and t >= 2 and score > best and f > 60:
			best = score
			await shot("firefight_mid_shot")
			shots_taken += 1
			print("FIREFIGHT frame %d cannon=%d rockets=%d tracers=%d streams=%d" % [f, c, r, t, wfx.streams.size()])
			if score >= 18 or shots_taken >= 4:
				break
		n = f
	Engine.time_scale = 1.0
	check("firefight shot caught shells, rockets and tracers in flight", best > 0, best)
	_look(o + Vector2i(6, 7), 1)
	await frames(30)
	await shot("firefight_wide")
	var st: Dictionary = wfx.stats
	print("WEAPONFX ", JSON.stringify(st))
	check("rounds fired", int(st["rounds"]) > 50, st["rounds"])
	check("misses land on the ground", int(st["ground_misses"]) > 0, st["ground_misses"])
	check("flak airbursts", int(st["airbursts"]) > 0, st["airbursts"])
	check("rocket / missile smoke trails", int(st["trail_puffs"]) > 0, st["trail_puffs"])
	check("flame / spray streams", int(st["stream_particles"]) > 0, st["stream_particles"])
	var beams := 0
	for it in m.world.vfx.items:
		if it["k"] == "box":
			beams += 1
	check("no beam / laser line meshes", beams == 0 and not m.world.vfx.has_method("tracer"), beams)
	for id in eu + tp:
		var e: SimEntity = sim.ents.get(id)
		if e != null:
			sim._kill(e, null)
	m.world.on_tick(sim.events.duplicate())
	sim.events.clear()
	await frames(30)

# ------------------------------------------------------------------ big battle counters
func _counters(label: String) -> Dictionary:
	var dc := 0
	var prims := 0
	var objs := 0
	var proc_ms := 0.0
	var t0 := Time.get_ticks_usec()
	for k in 30:
		await get_tree().process_frame
		dc = maxi(dc, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objs = maxi(objs, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		proc_ms = maxf(proc_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var vx: Vfx = m.world.vfx
	var r := {"label": label, "draw_calls": dc, "primitives": prims, "objects": objs, "process_ms_max": proc_ms,
		"frame_ms_llvmpipe": (Time.get_ticks_usec() - t0) / 30000.0, "view_ms_avg": m.avg_view_ms, "tick_ms_avg": m.avg_tick_ms,
		"rounds_in_flight": m.world.wfx.shots.size(), "streams": m.world.wfx.streams.size(),
		"particles": vx.smoke.live + vx.fire.live + vx.debris.live + vx.spark_layer.live, "streaks": m.world.wfx.glow.n + m.world.wfx.solid.n,
		"units": _count_units()}
	print("GFXPERF ", JSON.stringify(r))
	return r

func _count_units() -> int:
	var c := 0
	for id in sim.ids:
		c += 1 if sim.ents[id].kind == SimEntity.Kind.UNIT else 0
	return c

func run_perf() -> void:
	var o := _open_block(30, 22)
	var mix_eu := [[&"eu_leopold", 10], [&"eu_brennus", 3], [&"eu_wolfhound", 4], [&"eu_lancer", 8], [&"eu_grenadier", 14], [&"eu_flakwerk", 3], [&"eu_salamander", 3], [&"eu_hearth", 3], [&"eu_thunderhead", 2]]
	var mix_tp := [[&"tpla_militia", 16], [&"tpla_rocket_cell", 8], [&"tpla_rattler", 8], [&"tpla_shrike", 4], [&"tpla_hailstorm", 4], [&"tpla_scrapback", 4], [&"tpla_jackal", 4], [&"tpla_junkhammer", 2]]
	var eu := _army(mix_eu, 0, o + Vector2i(0, 14), 13)
	var tp := _army(mix_tp, 1, o + Vector2i(0, 0), 13)
	# both sides attack-move into each other
	m.runner.issue({"p": 0, "t": "amove", "ids": eu, "pos": FX.tile_center(o + Vector2i(13, 2))})
	m.runner.issue({"p": 1, "t": "amove", "ids": tp, "pos": FX.tile_center(o + Vector2i(13, 18))})
	_look(o + Vector2i(13, 10), 1)
	# as in the firefight: once the guns open, ~1/30 s of battle per software-rendered frame so the
	# counters see rounds in flight the way the phone would
	for k in 300:
		await get_tree().process_frame
		if Engine.time_scale == 1.0 and int(m.world.wfx.stats["fired"]) > 0:
			Engine.time_scale = clampf(0.033 / maxf(0.033, get_process_delta_time()), 0.01, 1.0)
		if m.world.wfx.shots.size() > 30 and k > 40:
			break
	var res := {}
	for lvl in [0, 1, 2]:
		m.cam.set_level(lvl)
		await frames(15)
		res[lvl] = await _counters("big_battle_zoom%d" % lvl)
	m.cam.set_level(1)
	await frames(5)
	await shot("big_battle_perf")
	# where the draw calls go (default zoom): without the M2.4 weapon / construction effects, and
	# without the sun's shadow pass
	var fx_nodes: Array = [m.world.wfx, m.world.vfx]
	for n in fx_nodes:
		n.visible = false
	res["no_fx"] = await _counters("big_battle_zoom1_effects_hidden")
	for n in fx_nodes:
		n.visible = true
	var suns := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	for l in suns:
		(l as DirectionalLight3D).shadow_enabled = false
	res["no_shadow"] = await _counters("big_battle_zoom1_no_shadows")
	for l in suns:
		(l as DirectionalLight3D).shadow_enabled = true
	Engine.time_scale = 1.0
	print("M24PERF ", JSON.stringify(res))
	var worst_dc := 0
	var worst_pr := 0
	for lvl in [0, 1, 2]:
		worst_dc = maxi(worst_dc, int(res[lvl]["draw_calls"]))
		worst_pr = maxi(worst_pr, int(res[lvl]["primitives"]))
	check("big battle draw calls <= 300 (%d)" % worst_dc, worst_dc <= 300, worst_dc)
	check("big battle primitives <= 600k (%d)" % worst_pr, worst_pr <= 600000, worst_pr)
