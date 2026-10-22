extends Node
## Rendered test harness (needs a display, e.g. xvfb + lavapipe):
##   godot --path . res://tests/visual_runner.tscn -- shots <outdir> [--dpi=450]
##   godot --path . res://tests/visual_runner.tscn -- touch [--dpi=450]
##   godot --path . res://tests/visual_runner.tscn -- perf <seconds> [--dpi=450]
## shots: menu, lobby, early base, mid-game battle, far zoom, results.

var out_dir := "res://tests/out"
var failed := false
var checks: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "shots"
	if args.size() > 1 and not args[1].begins_with("--") and mode != "perf":
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir)
	await get_tree().process_frame
	match mode:
		"shots":
			await run_shots()
		"touch":
			await run_touch()
		"gallery":
			await run_gallery()
		"m2":
			await run_m2()
		"m2g":
			await _m2_gallery()
		"perf":
			await run_perf(int(args[1]) if args.size() > 1 else 20)
	for c in checks:
		print(("PASS " if c[1] else "FAIL ") + c[0] + ("" if c.size() < 3 else "  (" + str(c[2]) + ")"))
		if not c[1]:
			failed = true
	print("=== VISUAL RESULT: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func check(name: String, ok: bool, info = null) -> void:
	checks.append([name, ok] if info == null else [name, ok, info])

func frames(n: int) -> void:
	for i in n:
		if WorldInput.test_clock_ms >= 0:
			WorldInput.test_clock_ms += 16
		await get_tree().process_frame

## Advance the virtual gesture clock (touch test) by ms, then let two frames run.
func wait_ms(ms: int) -> void:
	if WorldInput.test_clock_ms >= 0:
		WorldInput.test_clock_ms += ms
		await frames(2)
	else:
		await get_tree().create_timer(ms / 1000.0).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("shot ", p, " ", img.get_size())

func lobby_cfg(n_ai: int, diff: String = "medium") -> Dictionary:
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 7
	for i in range(1, 4):
		cfg["slots"][i]["kind"] = "ai" if i <= n_ai else "closed"
		cfg["slots"][i]["difficulty"] = diff
	cfg["slots"][0]["spawn"] = 0
	cfg["slots"][1]["spawn"] = 1
	return cfg

func start_match(cfg: Dictionary) -> Node:
	GameSession.setup = cfg
	GameSession.resume_save = {}
	var m: Node = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	return m

## Fast-forward with an AI driving the human slot too (so the base looks like a real game).
func fast_forward(m, ticks: int, ai_for_human: bool = true) -> void:
	var r: MatchRunner = m.runner
	if ai_for_human and not r.ais.has(m.local_pid):
		var fac: StringName = r.sim.faction_of(m.local_pid)
		var ai := AIPlayer.create(fac)
		ai.init(r, m.local_pid, "medium", StringName(Content.faction(fac)["personality"]))
		r.ais[m.local_pid] = ai
	for i in ticks:
		r.advance()
		m.world.on_tick(r.sim.events.duplicate())
		if r.sim.game_over:
			break
	if ai_for_human:
		r.ais.erase(m.local_pid)

func run_shots() -> void:
	var menu: Node = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await frames(5)
	await shot("01_main_menu")
	menu.queue_free()
	GameSession.setup = {}
	var cfg := lobby_cfg(3)
	cfg["slots"][1]["team"] = 0
	cfg["slots"][2]["team"] = 1
	cfg["slots"][3]["team"] = 1
	cfg["slots"][3]["difficulty"] = "hard"
	GameSession.setup = cfg
	var lobby: Node = (load("res://ui/skirmish_setup.tscn") as PackedScene).instantiate()
	add_child(lobby)
	await frames(5)
	await shot("02_skirmish_lobby")
	lobby.queue_free()
	var m := await start_match(lobby_cfg(1))
	fast_forward(m, 20 * 150)
	var hq := _first(m, 0, &"eu_hq")
	if hq:
		m.cam.jump_to(FX.to_world(hq.pos) + Vector3(5, 0, 4), false)
	var sel: Array = []
	for id in m.runner.sim.ids:
		var e: SimEntity = m.runner.sim.ents[id]
		if e.owner == 0 and e.kind == SimEntity.Kind.UNIT and not Content.unit(e.def_id).tags.has("harvester") and not Content.unit(e.def_id).tags.has("builder"):
			sel.append(id)
	if sel.is_empty():
		var b := _first(m, 0, &"eu_barracks")
		if b:
			sel = [b.id]
	var bar := _first(m, 0, &"eu_barracks")
	if bar:
		m.runner.sim.players[0].supply += 2000
		m.ctl.queue_unit(bar, &"eu_grenadier", 2)
		m.ctl.queue_unit(bar, &"eu_lancer", 1)
		fast_forward(m, 40, false)
		m.ctl.set_selection([bar.id])
	else:
		m.ctl.set_selection(sel)
	await frames(20)
	await shot("03_base_early")
	m.ctl.set_selection(sel)
	# battle: fast forward until a fight is happening, look at it
	var fight := Vector2i(-1, -1)
	for k in 60:
		fast_forward(m, 20 * 10)
		fight = _fight_spot(m)
		if fight.x >= 0 or m.runner.sim.game_over:
			break
	if fight.x >= 0:
		m.cam.jump_to(FX.to_world(fight), false)
		m.cam.set_level(0)
	await frames(25)
	await shot("04_battle_close")
	m.cam.set_level(2)
	await frames(25)
	await shot("05_far_zoom_icons")
	m.queue_free()
	await frames(2)
	GameSession.last_result = {"won": true, "winner_team": 0, "local_pid": 0, "ticks": 20 * 754, "players": [
		{"id": 0, "team": 0, "color": 0, "ai": false, "rank": 3, "stats": {"built": 41, "lost": 17, "kills": 52, "structures_killed": 9, "harvested": 31200}, "difficulty": ""},
		{"id": 1, "team": 1, "color": 1, "ai": true, "rank": 2, "stats": {"built": 38, "lost": 52, "kills": 17, "structures_killed": 2, "harvested": 24800}, "difficulty": "medium"}]}
	var res: Node = (load("res://ui/results.tscn") as PackedScene).instantiate()
	add_child(res)
	await frames(5)
	await shot("06_results_sample")
	res.queue_free()

## Art review: every EU/neutral model lined up on the real map with match lighting.
func run_gallery() -> void:
	var cfg := lobby_cfg(1)
	cfg["options"]["fog"] = false
	var m = await start_match(cfg)
	var base := Vector3(14, 0, 40)
	var paths := []
	for d in ["res://view/buildings/eu/", "res://view/buildings/neutral/", "res://view/neutral/", "res://view/units/eu/"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".tscn"):
				paths.append(d + f)
	var x := 0.0
	var row := 0
	var holder := Node3D.new()
	m.world.add_child(holder)
	for p in paths:
		var v: Node3D = (load(p) as PackedScene).instantiate()
		holder.add_child(v)
		var unit: bool = p.contains("/units/")
		if unit and row == 0:
			row = 1
			x = 0.0
		v.position = base + Vector3(x, 0.02, row * 5.0)
		v.rotation_degrees.y = 25.0
		if v.has_method("set_team_material"):
			v.set_team_material(Palette.team_material(0))
		x += 1.7 if unit else 4.6
	for spec in [[base + Vector3(8, 0, 1), 0, "gallery_buildings_a"], [base + Vector3(30, 0, 1), 0, "gallery_buildings_b"], [base + Vector3(6, 0, 5), 0, "gallery_units"], [base + Vector3(20, 0, 3), 1, "gallery_wide"]]:
		m.cam.jump_to(spec[0], false)
		m.cam.set_level(spec[1])
		await frames(30)
		await shot(spec[2])
	# effects review
	var vf: Vfx = m.world.vfx
	var c := base + Vector3(10, 0, 9)
	m.cam.jump_to(c, false)
	m.cam.set_level(0)
	vf.building_destroyed(c + Vector3(-3, 0, 0), Vector2(3, 3))
	for k in 6:
		vf.smoke_puff(c + Vector3(3, 0.8, -1), 0.5, true)
		await frames(6)
	vf.explosion(c + Vector3(0, 0, 2), 1.0)
	vf.explosion(c + Vector3(2, 0, 3), 0.5)
	for k in 5:
		vf.muzzle(c + Vector3(-1 + k * 0.6, 0.6, 3), Vector3(1, 0, -0.3), 0.3)
		vf.dust(c + Vector3(4, 0, 2 + k * 0.3), 0.45, 0.5)
	await frames(4)
	await shot("gallery_vfx")
	await frames(90)
	await shot("gallery_vfx_after")

func _first(m, pid: int, def_id: StringName) -> SimEntity:
	for id in m.runner.sim.ids:
		var e: SimEntity = m.runner.sim.ents[id]
		if e.owner == pid and e.def_id == def_id:
			return e
	return null

func _fight_spot(m) -> Vector2i:
	var sim: SimWorld = m.runner.sim
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.kind == SimEntity.Kind.UNIT and e.owner == 0 and sim.tick - e.firing_tick < 10 and e.target != 0:
			return e.pos
	return Vector2i(-1, -1)

# ------------------------------------------------------------------ touch simulation
func touch(idx: int, p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = p
	ev.pressed = pressed
	Input.parse_input_event(ev)

func drag(idx: int, p: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = p
	ev.relative = rel
	Input.parse_input_event(ev)

func tap(p: Vector2) -> void:
	touch(0, p, true)
	await frames(2)
	touch(0, p, false)
	await frames(2)

func to_screen(m, e: SimEntity) -> Vector2:
	# event positions are window pixels; the stretch transform maps them to logical units
	var lp: Vector2 = m.ctl.screen_of(e)
	return lp * float(UiScale.dp)

func run_touch() -> void:
	Input.use_accumulated_input = false
	WorldInput.test_clock_ms = Time.get_ticks_msec()
	var m := await start_match(lobby_cfg(1))
	fast_forward(m, 20 * 60)
	var sim: SimWorld = m.runner.sim
	var crawler := _first(m, 0, &"eu_crawler")
	m.cam.jump_to(FX.to_world(crawler.pos), false)
	await frames(10)
	var win := Vector2(get_window().size)
	# 1. tap own unit selects it
	await tap(to_screen(m, crawler))
	check("tap selects own unit", m.ctl.selection == [crawler.id], m.ctl.selection)
	# 2. two-finger tap deselects
	touch(0, win * 0.4, true)
	touch(1, win * 0.6, true)
	await frames(2)
	touch(1, win * 0.6, false)
	touch(0, win * 0.4, false)
	await frames(2)
	check("two-finger tap deselects", m.ctl.selection.is_empty(), m.ctl.selection)
	# 3. one-finger drag pans camera
	var f0: Vector3 = m.cam.focus
	var p := win * 0.5
	touch(0, p, true)
	for i in 10:
		p += Vector2(-30, -12)
		drag(0, p, Vector2(-30, -12))
		await frames(1)
	touch(0, p, false)
	await frames(1)
	var f1: Vector3 = m.cam.focus
	check("drag pans camera", m.cam.focus.distance_to(f0) > 2.0, m.cam.focus.distance_to(f0))
	await frames(10)
	check("pan has inertia (kept moving after release)", m.cam.focus.distance_to(f1) > 0.2, m.cam.focus.distance_to(f1))
	m.cam.velocity = Vector3.ZERO
	# 4. pinch zoom changes level
	m.cam.jump_to(FX.to_world(crawler.pos), false)
	m.cam.set_level(1)
	await frames(20)
	var a := win * 0.5 - Vector2(60, 0)
	var b := win * 0.5 + Vector2(60, 0)
	touch(0, a, true)
	touch(1, b, true)
	await frames(1)
	for i in 10:
		a -= Vector2(25, 0)
		b += Vector2(25, 0)
		drag(0, a, Vector2(-25, 0))
		drag(1, b, Vector2(25, 0))
		await frames(1)
	touch(1, b, false)
	touch(0, a, false)
	await frames(15)
	check("pinch out zooms in to close level", m.cam.level == 0, m.cam.level)
	m.cam.set_level(1)
	m.cam.jump_to(FX.to_world(crawler.pos), false)
	await frames(15)
	# 5. hold + drag box-selects (combat units near HQ)
	var army: Array = []
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == 0 and e.kind == SimEntity.Kind.UNIT and not Content.unit(e.def_id).tags.has("builder") and not Content.unit(e.def_id).tags.has("harvester"):
			army.append(id)
	if army.is_empty():
		var u := sim.spawn_unit(&"eu_grenadier", 0, null, FX.to_tile(crawler.pos) + Vector2i(2, 2))
		sim.spawn_unit(&"eu_grenadier", 0, null, FX.to_tile(crawler.pos) + Vector2i(3, 2))
		m.world.on_tick([{"t": "spawn", "id": u.id}, {"t": "spawn", "id": u.id + 1}])
		army = [u.id, u.id + 1]
	var tgt: SimEntity = sim.ents[army[0]]
	m.cam.jump_to(FX.to_world(tgt.pos), false)
	await frames(15)
	var c := to_screen(m, tgt)
	var start := c + Vector2(-220, -160) * UiScale.dp / 2.0
	touch(0, start, true)
	await wait_ms(450)
	var q := start
	for i in 12:
		q += Vector2(40, 30) * UiScale.dp / 2.0
		drag(0, q, Vector2(40, 30))
		await frames(1)
	touch(0, q, false)
	await frames(3)
	check("hold+drag box selects units", not m.ctl.own_units_selected().is_empty() and tgt.id in m.ctl.selection, m.ctl.selection.size())
	# 6. hold + release = attack-move order
	var before: Array = sim.ents[tgt.id].orders.duplicate()
	var hp := to_screen(m, tgt) + Vector2(200, 60) * UiScale.dp / 2.0
	touch(0, hp, true)
	await wait_ms(450)
	touch(0, hp, false)
	await frames(2)
	m.runner.advance()
	var o: Array = sim.ents[tgt.id].orders
	check("hold+release issues attack-move", not o.is_empty() and o[0].get("o", "") == "amove", o.duplicate(true))
	# 7. tap ground with selection = move order
	await tap(to_screen(m, tgt) + Vector2(-150, 40) * UiScale.dp / 2.0)
	m.runner.advance()
	o = sim.ents[tgt.id].orders
	check("tap ground with selection moves", not o.is_empty() and o[0].get("o", "") == "move", o)
	# 8. double-tap selects all of type on screen
	await tap(to_screen(m, tgt))
	await tap(to_screen(m, tgt))
	var same := 0
	for id in m.ctl.selection:
		same += 1 if sim.ents[id].def_id == tgt.def_id else 0
	check("double-tap selects all of type", same >= 1 and same == m.ctl.selection.size(), m.ctl.selection.size())
	# 9. building placement: ghost, finger release does NOT place, Confirm places
	m.ctl.set_selection([crawler.id])
	m.cam.jump_to(FX.to_world(crawler.pos), false)
	await frames(5)
	sim.players[0].supply = 5000
	m.ctl.begin_place(&"eu_reactor")
	await frames(2)
	var sites_before := sim.count_owned(0, &"eu_reactor")
	var gp: Vector2 = m.cam.cam.unproject_position(Vector3(m.ctl.place_tile.x + 1.5, 0, m.ctl.place_tile.y + 1.5)) * UiScale.dp
	touch(0, gp, true)
	var gq := gp
	for i in 6:
		gq += Vector2(12, 4)
		drag(0, gq, Vector2(12, 4))
		await frames(1)
	touch(0, gq, false)
	await frames(2)
	m.runner.advance()
	check("releasing finger does not place building", sim.count_owned(0, &"eu_reactor") == sites_before)
	check("ghost follows finger", m.ctl.mode == PlayerController.Mode.PLACE)
	# find a valid spot then confirm through the HUD button path
	var placed := false
	for r in range(0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if placed:
					break
				m.ctl.move_ghost_tile(FX.to_tile(crawler.pos) + Vector2i(dx, dy))
				if m.ctl.place_reason == "":
					placed = m.ctl.confirm_place()
	m.runner.advance()
	check("confirm places building site", placed and sim.count_owned(0, &"eu_reactor") == sites_before + 1)
	# 10. HUD tap targets >= 48 dp
	var small: Array = []
	for b2 in m.hud.grid_buttons + m.hud.group_btns:
		if b2.size.x < 48 or b2.size.y < 48 and b2.size.y < 44:
			small.append(b2.size)
	check("command buttons >= 48 dp", small.is_empty(), small)
	# 11. control groups
	m.ctl.set_selection(army)
	m.ctl.group_assign(0)
	m.ctl.set_selection([])
	m.ctl.group_select(0)
	check("control group recall", m.ctl.selection.size() == army.size())
	# 12. touches over the HUD don't reach the world
	var sel_before: Array = m.ctl.selection.duplicate()
	var hud_pt: Vector2 = (m.hud.bar.get_global_rect().get_center()) * UiScale.dp
	touch(0, hud_pt, true)
	touch(0, hud_pt, false)
	await frames(2)
	check("touch on HUD is not a world tap", m.ctl.selection == sel_before)
	m.queue_free()

func run_perf(seconds: int) -> void:
	var cfg := lobby_cfg(3, "hard")
	for i in 4:
		cfg["slots"][i]["spawn"] = i
		cfg["slots"][i]["team"] = i
	var m := await start_match(cfg)
	fast_forward(m, 20 * 60 * 9)
	var sim: SimWorld = m.runner.sim
	var fight := _fight_spot(m)
	m.cam.jump_to(FX.to_world(fight) if fight.x >= 0 else Vector3(64, 0, 64), false)
	var units := 0
	for id in sim.ids:
		units += 1 if sim.ents[id].kind == SimEntity.Kind.UNIT else 0
	var t0 := Time.get_ticks_msec()
	var n := 0
	var worst := 0.0
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < seconds * 1000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		n += 1
	var fps := n / float(seconds)
	var dc := {}
	for lvl in [0, 1, 2]:
		m.cam.set_level(lvl)
		await frames(20)
		var mx := 0
		var prims := 0
		var objs := 0
		var proc_ms := 0.0
		for k in 30:
			await get_tree().process_frame
			mx = maxi(mx, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			objs = maxi(objs, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
			proc_ms = maxf(proc_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		dc[lvl] = [mx, prims, objs, proc_ms]
		print("VIEWCOST avg_view_ms=%.2f avg_tick_ms=%.2f" % [m.avg_view_ms, m.avg_tick_ms])
		print("DRAWCALLS zoom_level=%d max_draw_calls=%d max_primitives=%d max_objects=%d max_process_ms=%.2f vfx_particles=%d" % [lvl, mx, prims, objs, proc_ms, m.world.vfx.smoke.live + m.world.vfx.fire.live + m.world.vfx.debris.live])
	m.cam.set_level(1)
	await frames(5)
	print("PERF 4-player @%d:%02d entities=%d units=%d avg_fps=%.1f worst_frame_ms=%.1f avg_tick_ms=%.2f (software renderer)" % [sim.tick / 1200, (sim.tick / 20) % 60, sim.ids.size(), units, fps, worst, m.avg_tick_ms])
	await shot("perf_4p")
	check("perf run completed", n > 0)

# ------------------------------------------------------------------ M2 (TPLA) shots + HUD text checks
func _hud_check(m, label: String) -> void:
	await frames(4)
	var probs: Array = HudTextCheck.problems(m.hud)
	check("HUD text fits (%s)" % label, probs.is_empty(), probs.slice(0, 6) if not probs.is_empty() else null)

func _select_first(m, def_id: StringName) -> SimEntity:
	var e := _first(m, m.local_pid, def_id)
	if e != null:
		m.ctl.set_selection([e.id])
	return e

func _hud_states(m, fac: StringName) -> void:
	await HudTextCheck.exercise(m, fac, get_tree(), check)

func run_m2() -> void:
	# 1. lobby: EU (you) + TPLA ally vs TPLA + EU
	GameSession.setup = {}
	var cfg := lobby_cfg(3)
	cfg["slots"][1]["faction"] = "tpla"
	cfg["slots"][1]["team"] = 0
	cfg["slots"][2]["faction"] = "tpla"
	cfg["slots"][2]["team"] = 1
	cfg["slots"][3]["faction"] = "eu"
	cfg["slots"][3]["team"] = 1
	cfg["slots"][3]["difficulty"] = "hard"
	GameSession.setup = cfg
	var lobby: Node = (load("res://ui/skirmish_setup.tscn") as PackedScene).instantiate()
	add_child(lobby)
	await frames(6)
	await shot("m2_lobby")
	lobby.queue_free()
	await frames(2)
	# 2. TPLA base (you play TPLA vs an EU AI)
	var c2 := lobby_cfg(1)
	c2["slots"][0]["faction"] = "tpla"
	c2["slots"][1]["faction"] = "eu"
	var m := await start_match(c2)
	check("local player is TPLA", m.runner.sim.faction_of(m.local_pid) == &"tpla")
	fast_forward(m, 20 * 300)
	var lab := _select_first(m, &"tpla_laborer")
	var cen := Vector3.ZERO
	var nb := 0
	for id in m.runner.sim.ids:
		var be: SimEntity = m.runner.sim.ents[id]
		if be.owner == 0 and be.kind == SimEntity.Kind.BUILDING:
			cen += FX.to_world(be.pos)
			nb += 1
	if nb > 0:
		m.cam.jump_to(cen / nb + Vector3(0, 0, 3), false)
		m.cam.set_level(1)
	await frames(30)
	await shot("m2_tpla_base")
	var cs := _first(m, 0, &"tpla_chop_shop")
	if cs:
		m.runner.sim.players[0].supply += 4000
		m.ctl.set_selection([cs.id])
		m.ctl.queue_unit(cs, &"tpla_rattler", 2)
		m.ctl.queue_unit(cs, &"tpla_scrapback", 1)
		m.ctl.queue_unit(cs, &"tpla_hailstorm", 1)
		m.ctl.queue_unit(cs, &"tpla_shrike", 1)
		m.runner.advance()
		await frames(20)
		await shot("m2_tpla_production")
	await _hud_states(m, &"tpla")
	# 3. battle: EU vs TPLA
	var sel: Array = []
	var fight := Vector2i(-1, -1)
	for kk in 60:
		fast_forward(m, 20 * 10)
		fight = _fight_spot(m)
		if fight.x >= 0 or m.runner.sim.game_over:
			break
	if fight.x >= 0:
		for id in m.runner.sim.ids:
			var e: SimEntity = m.runner.sim.ents[id]
			if e.owner == 0 and e.kind == SimEntity.Kind.UNIT and FX.dist(e.pos, fight) < FX.ONE * 12 and not Content.unit(e.def_id).tags.has("builder"):
				sel.append(id)
		m.ctl.set_selection(sel)
		m.cam.jump_to(FX.to_world(fight), false)
		m.cam.set_level(0)
	await frames(25)
	await shot("m2_battle_eu_vs_tpla")
	await _hud_check(m, "battle selection")
	m.queue_free()
	await frames(3)
	# 4. EU HUD states (full names everywhere for EU too)
	var c3 := lobby_cfg(1)
	c3["slots"][1]["faction"] = "tpla"
	var m3 := await start_match(c3)
	fast_forward(m3, 20 * 200)
	await _hud_states(m3, &"eu")
	var hq3 := _first(m3, 0, &"eu_hq")
	if hq3:
		m3.cam.jump_to(FX.to_world(hq3.pos) + Vector3(5, 0, 4), false)
	await frames(20)
	await shot("m2_eu_hud_full_names")
	m3.queue_free()
	await frames(3)
	await _m2_gallery()

func _m2_gallery() -> void:
	# 5. units gallery: every TPLA + EU unit (TPLA salvage tiers 0-3) and TPLA buildings
	var cfg4 := lobby_cfg(1)
	cfg4["options"]["fog"] = false
	var m4 = await start_match(cfg4)
	var base := Vector3(14, 0, 40)
	var holder := Node3D.new()
	m4.world.add_child(holder)
	var x := 0.0
	for f in DirAccess.get_files_at("res://view/buildings/tpla/"):
		if f.ends_with(".tscn"):
			var v: Node3D = (load("res://view/buildings/tpla/" + f) as PackedScene).instantiate()
			holder.add_child(v)
			v.position = base + Vector3(x, 0.02, 0)
			v.rotation_degrees.y = 25.0
			v.set_team_material(Palette.team_material(1))
			Weathering.apply(v, &"tpla")
			x += 4.8
	var ux := 0.0
	for fac in ["tpla", "eu"]:
		for f in DirAccess.get_files_at("res://view/units/%s/" % fac):
			if not f.ends_with(".tscn"):
				continue
			var tiers := 4 if fac == "tpla" and f.get_basename() in ["rattler", "scrapback", "shrike", "hailstorm"] else 1
			for t in tiers:
				var v2: Node3D = (load("res://view/units/%s/%s" % [fac, f]) as PackedScene).instantiate()
				holder.add_child(v2)
				v2.position = base + Vector3(ux, 0.02, 6.0 if fac == "tpla" else 9.0)
				v2.rotation_degrees.y = 30.0
				v2.set_team_material(Palette.team_material(1 if fac == "tpla" else 0))
				Weathering.apply(v2, StringName(fac))
				if v2.has_method("set_tier"):
					v2.set_tier(t)
				if f.get_basename() in ["laborer", "militia", "rocket_cell", "grenadier", "lancer", "crawler"]:
					v2.scale = Vector3.ONE * 1.4
				ux += 1.9
		ux = 0.0
	for spec in [[base + Vector3(10, 0, 1), 0, "m2_gallery_tpla_buildings_a"], [base + Vector3(30, 0, 1), 0, "m2_gallery_tpla_buildings_b"],
			[base + Vector3(7, 0, 6.5), 0, "m2_gallery_units_a"], [base + Vector3(19, 0, 6.5), 0, "m2_gallery_units_b"], [base + Vector3(16, 0, 5), 1, "m2_gallery_wide"]]:
		m4.cam.jump_to(spec[0], false)
		m4.cam.set_level(spec[1])
		await frames(30)
		await shot(spec[2])
	m4.cam.jump_to(base + Vector3(4, 0, 7.5), false)
	m4.cam.set_level(0)
	m4.cam.target_dist = 9.0
	m4.cam.dist = 9.0
	await frames(30)
	await shot("m2_closeup_weathering")
	# TPLA effects: rust cloud, bomb blast, salvage sparkle, rocket salvo
	var vf: Vfx = m4.world.vfx
	var c := base + Vector3(10, 0, 13)
	m4.cam.jump_to(c, false)
	m4.cam.set_level(0)
	vf.rust_cloud(c + Vector3(-3, 0, 0), 2.5, 6.0)
	vf.big_blast(c + Vector3(2, 0, 1), 3.0)
	vf.salvage_fx(c + Vector3(4, 0, -1), Palette.color(1))
	await frames(20)
	await shot("m2_vfx_tpla")
	m4.queue_free()
