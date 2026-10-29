extends Node
## M3.2.2 Play prep: long-session check. One 60-game-minute skirmish, 4 AI (free-for-all), full
## match scene (views, VFX, HUD), driven as fast as the box allows (4 sim ticks per frame) with an
## autosave every 2 game minutes as in play. If the match ends early a new one starts (map/seed
## change) until 60 game minutes have run. Logs memory / object / node counts once per game minute.
##   godot --headless --path . res://tests/long_session.tscn  [env LS_MINUTES=60 LS_MAP=harrow_junction]
var m: Node
var minutes := 60
var total_ticks := 0
var match_n := 0
var peak_mem := 0
var t_start := 0

func _ready() -> void:
	minutes = int(OS.get_environment("LS_MINUTES")) if OS.has_environment("LS_MINUTES") else 60
	t_start = Time.get_ticks_msec()
	print("LS minute,match,tick,static_mb,peak_mb,objects,nodes,orphans,resources,ents,ms_per_min,rss_mb")
	await _new_match()
	var last_ms := Time.get_ticks_msec()
	while total_ticks < minutes * 1200:
		for i in 4:
			m.runner.advance()
			var evs: Array = m.runner.sim.events.duplicate()
			m.world.on_tick(evs)
			m.hud.on_events(evs)
			total_ticks += 1
			if m.runner.sim.tick % 2400 == 0:
				m.autosave()
			if total_ticks % 1200 == 0:
				var mem := OS.get_static_memory_usage()
				peak_mem = maxi(peak_mem, OS.get_static_memory_peak_usage())
				var now := Time.get_ticks_msec()
				print("LS %d,%d,%d,%.1f,%.1f,%d,%d,%d,%d,%d,%d,%.1f" % [total_ticks / 1200, match_n, m.runner.sim.tick, mem / 1048576.0,
					peak_mem / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
					m.runner.sim.ids.size(), now - last_ms, _rss_mb()])
				last_ms = now
			if m.runner.sim.game_over:
				break
		m.world.frame(1.0, 0.05)
		await get_tree().process_frame
		if m.runner.sim.game_over:
			print("LS match %d over at tick %d (winner team %d)" % [match_n, m.runner.sim.tick, m.runner.sim.winner_team])
			await _new_match()
	print("=== LONG SESSION DONE: %d game minutes, %d match(es), peak static %.1f MB, wall %d s" % [minutes, match_n, peak_mem / 1048576.0, (Time.get_ticks_msec() - t_start) / 1000])
	get_tree().quit(0)

func _new_match() -> void:
	if m != null:
		m.queue_free()
		for i in 3:
			await get_tree().process_frame
	match_n += 1
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 6000 + match_n
	cfg["map"] = OS.get_environment("LS_MAP") if OS.has_environment("LS_MAP") else "harrow_junction"
	var facs := ["us", "eu", "tpla", "ecc"]
	for i in 4:
		cfg["slots"][i]["kind"] = "ai"
		cfg["slots"][i]["difficulty"] = "hard"
		cfg["slots"][i]["faction"] = facs[(i + match_n - 1) % 4]
		cfg["slots"][i]["team"] = i
		cfg["slots"][i]["spawn"] = i
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	for i in 3:
		await get_tree().process_frame
	m.paused = true   # this script drives the ticks

func _rss_mb() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	for l in f.get_as_text().split("\n"):
		if l.begins_with("VmRSS:"):
			return float(l.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	return -1.0
