extends Node
## M2.2 graphics showcase + render counters (also runs on the M2.1 commit for "before" shots).
## Real sim entities in a real match (AIs removed, fog off): EU Leopold / TPLA Rattler, rifle
## squads (EU Grenadier, TPLA Militia), EU Barracks construction stages + damage states, and a
## 150-soldier crowd. Run (rendered):
##   xvfb-run -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/gfx_showcase.tscn -- <out_dir> [tag] --dpi=450
var out_dir := "/tmp/gfx"
var tag := "new"
var m: Node
var sim: SimWorld

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	if args.size() > 1 and not args[1].begins_with("--"):
		tag = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await run()
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join("%s_%s.png" % [tag, name])
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())

func _cfg() -> Dictionary:
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
	return cfg

var _used: Array = []   ## Rect2i blocks already taken

## First block of open, unoccupied buildable ground of size w x h (not overlapping earlier
## blocks), scanning outward from the middle of the map.
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
				if not (tt == SimMap.T.GRASS or tt == SimMap.T.ROUGH or tt == SimMap.T.ROAD) or not sim.map.passable(t, true):
					ok = false
					break
			if not ok:
				break
		if ok:
			_used.append(r)
			return c
	push_error("no open block %dx%d" % [w, h])
	return Vector2i(40, 40)

func _bld(def_id: StringName, owner: int, t: Vector2i, k: float, hpk: float) -> SimEntity:
	var e: SimEntity = sim._place_building(Content.building(def_id), owner, t, 0, k >= 1.0)
	if k < 1.0:
		e.built = false
		e.progress = int(k * e.build_ticks)
	e.hp = maxi(1, int(e.max_hp * hpk))
	m.world._ensure_view(e)
	return e

func _unit(def_id: StringName, owner: int, t: Vector2i) -> SimEntity:
	var e := sim.spawn_unit(def_id, owner, null, FX.tile_center(t))
	# spawned outside a sim step, so the "spawn" event never reaches the view: make it here
	m.world._ensure_view(e)
	m.world.cur[e.id] = m.world._world_pos(e)
	m.world.prev[e.id] = m.world.cur[e.id]
	return e

## Showcase units fight but do not die before the shots (real combat, inflated HP).
func _tough(e: SimEntity) -> SimEntity:
	e.max_hp *= 1000
	e.hp = e.max_hp
	return e

func _counters(label: String) -> Dictionary:
	var dc := 0
	var prims := 0
	var objs := 0
	var proc_ms := 0.0
	var t0 := Time.get_ticks_usec()
	for k in 20:
		await get_tree().process_frame
		dc = maxi(dc, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objs = maxi(objs, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		proc_ms = maxf(proc_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var frame_ms := (Time.get_ticks_usec() - t0) / 20000.0
	var tex_mb := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0
	var vid_mb := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	var buf_mb := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
	var r := {"label": label, "draw_calls": dc, "primitives": prims, "objects": objs, "process_ms": proc_ms,
		"frame_ms_llvmpipe": frame_ms, "texture_mb": tex_mb, "video_mb": vid_mb, "buffer_mb": buf_mb,
		"render_cpu_ms": cpu_ms, "gpu_ms_llvmpipe": gpu_ms, "view_ms": m.avg_view_ms if "avg_view_ms" in m else -1.0}
	print("GFXPERF ", JSON.stringify(r))
	return r

func run() -> void:
	GameSession.setup = _cfg()
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	sim = m.runner.sim
	m.runner.ais.clear()
	var o := _open_block(20, 10)
	print("GFX barracks block at ", o)
	# --- barracks: construction stages (top row) and damage states (bottom row)
	var stages := [0.08, 0.35, 0.7, 1.0]
	for i in stages.size():
		_bld(&"eu_barracks", 0, o + Vector2i(i * 5, 0), stages[i], 1.0)
	var dmg := [0.7, 0.4, 0.18]
	var dead: SimEntity = null
	for i in dmg.size():
		_bld(&"eu_barracks", 0, o + Vector2i(i * 5, 5), 1.0, dmg[i])
	dead = _bld(&"eu_barracks", 0, o + Vector2i(15, 5), 1.0, 1.0)
	# --- vehicles + rifle squads facing each other (EU south, TPLA north)
	var u := _open_block(16, 8)
	print("GFX units block at ", u)
	var eu_ids: Array = []
	var tp_ids: Array = []
	for i in 2:
		eu_ids.append(_tough(_unit(&"eu_leopold", 0, u + Vector2i(2 + i * 3, 5))).id)
		tp_ids.append(_tough(_unit(&"tpla_rattler", 1, u + Vector2i(3 + i * 3, 2))).id)
	for i in 3:
		eu_ids.append(_tough(_unit(&"eu_grenadier", 0, u + Vector2i(9 + i * 1, 5))).id)
		tp_ids.append(_tough(_unit(&"tpla_militia", 1, u + Vector2i(9 + i * 1, 2))).id)
	await frames(6)
	# let them face off and start shooting
	m.cam.jump_to(FX.to_world(FX.tile_center(u + Vector2i(7, 4))), false)
	m.cam.set_level(0)
	await frames(40)
	await shot("units_close")
	var perf_units := await _counters("units_close")
	m.cam.jump_to(FX.to_world(FX.tile_center(o + Vector2i(9, 1))), false)
	m.cam.set_level(0)
	await frames(25)
	await shot("barracks_construction")
	# destroyed state: killed outside a sim step, so hand the death event to the view directly
	sim._kill(dead, null)
	for ev in sim.events:
		if ev["t"] == "death" and int(ev["id"]) == dead.id:
			m.world._on_death(ev)
	m.cam.jump_to(FX.to_world(FX.tile_center(o + Vector2i(9, 6))), false)
	await frames(12)
	await shot("barracks_damage")
	m.cam.jump_to(FX.to_world(FX.tile_center(o + Vector2i(10, 5))), false)
	m.cam.set_level(1)
	await frames(25)
	await shot("overview")
	var perf_over := await _counters("overview")
	# --- 150-soldier crowd: 38 Grenadier squads (4 each = 152 soldiers), walking
	var c0 := _open_block(18, 12)
	print("GFX crowd block at ", c0)
	var crowd: Array = []
	for i in 38:
		var e := _tough(_unit(&"eu_grenadier" if i % 2 == 0 else &"tpla_militia", i % 2, c0 + Vector2i((i % 8) * 2, (i / 8) * 2)))
		crowd.append(e.id)
	m.runner.issue({"p": 0, "t": "move", "ids": crowd.filter(func(id): return sim.ents[id].owner == 0), "pos": FX.tile_center(c0 + Vector2i(8, 11))})
	m.runner.issue({"p": 1, "t": "move", "ids": crowd.filter(func(id): return sim.ents[id].owner == 1), "pos": FX.tile_center(c0 + Vector2i(8, 0))})
	m.cam.jump_to(FX.to_world(FX.tile_center(c0 + Vector2i(8, 5))), false)
	m.cam.set_level(1)
	await frames(30)
	await shot("crowd_150")
	var perf_crowd := await _counters("crowd_150")
	print("GFXSUMMARY ", JSON.stringify({"tag": tag, "units_close": perf_units, "overview": perf_over, "crowd_150": perf_crowd}))
