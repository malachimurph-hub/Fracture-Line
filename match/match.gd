extends Node3D
## Rendered skirmish match. Fixed 20 Hz simulation via a tick accumulator (max 4 catch-up
## ticks per frame), interpolated rendering, active pause, speed, autosave every 2 minutes
## and on app pause/background, results on game over.

const DT := 0.05
const AUTOSAVE_TICKS := 2400

var runner: MatchRunner
var world: WorldView
var cam: CameraRig
var ctl: PlayerController
var input: WorldInput
var hud: Hud
var overlay: WorldOverlay
var acc: float = 0.0
var paused: bool = false
var _menu_pause: bool = false
var speed: float = 1.0
var avg_tick_ms: float = 0.0
var local_pid: int = -1
var _over_t: float = -1.0
var _last_save_tick: int = 0
var banner: Label

func _ready() -> void:
	runner = MatchRunner.new()
	if not GameSession.resume_save.is_empty():
		runner.deserialize(GameSession.resume_save["match"])
		GameSession.setup = runner.setup_cfg
	else:
		var cfg: Dictionary = GameSession.setup
		if cfg.is_empty():
			cfg = SkirmishConfig.default_setup()
			GameSession.setup = cfg
		cfg = SkirmishConfig.resolve(cfg)
		runner.start(cfg)
	runner.record_replay = false
	for i in runner.setup_cfg["slots"].size():
		if runner.setup_cfg["slots"][i]["kind"] == "human":
			local_pid = i
	_build_scene()
	if not GameSession.resume_save.is_empty():
		var v: Dictionary = GameSession.resume_save.get("view", {})
		cam.focus = v.get("focus", cam.focus)
		cam.set_level(int(v.get("level", 1)))
		ctl.groups = v.get("groups", ctl.groups)
		GameSession.resume_save = {}
	_last_save_tick = runner.sim.tick
	get_tree().set_auto_accept_quit(false)

func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0d0f12")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#9fa8b8")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	sun.light_color = Color("#fff3e0")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	world = WorldView.new()
	add_child(world)
	world.setup(runner, local_pid)
	cam = CameraRig.new()
	cam.map_size = Vector2(runner.sim.map.w, runner.sim.map.h)
	add_child(cam)
	cam.zoom_level_changed.connect(func(l): world.icon_mode = l >= 2)
	ctl = PlayerController.new()
	add_child(ctl)
	ctl.setup(runner, world, cam, local_pid)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	overlay = WorldOverlay.new()
	overlay.ctl = ctl
	overlay.world = world
	overlay.cam = cam
	ui.add_child(overlay)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self, ctl, world, cam)
	input = WorldInput.new()
	input.ctl = ctl
	input.cam = cam
	input.hud = hud
	add_child(input)
	input.box_changed.connect(overlay.on_box)
	input.hold_progress.connect(overlay.on_hold)
	banner = UiTheme.label("", 40, UiTheme.GOLD)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.visible = false
	hud.root.add_child(banner)
	# start looking at our HQ
	var focus_pid := local_pid if local_pid >= 0 else 0
	for id in runner.sim.ids:
		var en: SimEntity = runner.sim.ents[id]
		if en.owner == focus_pid and en.kind == SimEntity.Kind.BUILDING and Content.building(en.def_id).is_hq:
			cam.jump_to(FX.to_world(en.pos) + Vector3(4, 0, 3), false)
			break
	cam.set_level(1)

func _process(delta: float) -> void:
	if not paused and not runner.sim.game_over:
		acc += delta * speed
		var steps := 0
		while acc >= DT and steps < 4:
			var t0 := Time.get_ticks_usec()
			runner.advance()
			avg_tick_ms = lerpf(avg_tick_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
			var evs := runner.sim.events.duplicate()
			world.on_tick(evs)
			hud.on_events(evs)
			_income_floaters(evs)
			acc -= DT
			steps += 1
		if steps == 4:
			acc = minf(acc, DT)
		if runner.sim.tick - _last_save_tick >= AUTOSAVE_TICKS:
			autosave()
	world.frame(clampf(acc / DT, 0.0, 1.0) if not paused else 1.0, delta)
	if runner.sim.game_over:
		_game_over(delta)

func _income_floaters(evs: Array) -> void:
	for ev in evs:
		if ev["t"] == "unload":
			var u := runner.sim.get_ent(int(ev["id"]))
			if u != null and u.owner == local_pid:
				overlay.floater(FX.to_world(u.pos), "+$%d" % int(ev["amount"]), Color("#ffd166"))

func _game_over(delta: float) -> void:
	if _over_t < 0.0:
		_over_t = 0.0
		var sim := runner.sim
		var my_team := sim.player_team(local_pid) if local_pid >= 0 else -1
		var won := my_team >= 0 and sim.winner_team == my_team
		banner.text = tr("RESULT_VICTORY") if won else (tr("RESULT_DEFEAT") if my_team >= 0 else tr("RESULT_TEAM_WINS") % (sim.winner_team + 1))
		banner.visible = true
		banner.position = Vector2(UiScale.logical_size().x * 0.5 - 200, 90)
		banner.size = Vector2(400, 60)
		GameSession.last_result = build_result(won)
		SaveSystem.clear_suspend()
	_over_t += delta
	if _over_t > 3.5:
		get_tree().change_scene_to_file("res://ui/results.tscn")

func build_result(won: bool) -> Dictionary:
	var sim := runner.sim
	var players: Array = []
	for p: SimPlayer in sim.players:
		players.append({"id": p.id, "team": p.team, "color": p.color, "ai": p.is_ai, "rank": p.rank,
			"stats": p.stats.duplicate(), "eliminated": p.eliminated,
			"difficulty": runner.setup_cfg["slots"][p.id].get("difficulty", "")})
	return {"won": won, "winner_team": sim.winner_team, "local_pid": local_pid, "ticks": sim.tick, "players": players}

func set_paused(p: bool, from_menu: bool = false) -> void:
	if from_menu:
		if p and not paused:
			_menu_pause = true
			paused = true
		elif not p and _menu_pause:
			_menu_pause = false
			paused = false
		return
	paused = p
	_menu_pause = false

func cycle_speed() -> void:
	var sp := [1.0, 1.5, 2.0, 0.5]
	speed = sp[(sp.find(speed) + 1) % sp.size()]

func restart() -> void:
	SaveSystem.clear_suspend()
	get_tree().change_scene_to_file("res://match/match.tscn")

func surrender() -> void:
	if local_pid >= 0:
		runner.issue({"t": "surrender", "p": local_pid})
		hud.toggle_pause_menu()

func quit_to_menu() -> void:
	autosave()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func autosave() -> void:
	if runner.sim.game_over or local_pid < 0:
		return
	_last_save_tick = runner.sim.tick
	var md := runner.serialize()
	SaveSystem.save_suspend({"sim": md["sim"], "match": md,
		"view": {"focus": cam.focus, "level": cam.level, "groups": ctl.groups}, "saved_at": Time.get_unix_time_from_system()})

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if runner != null:
				autosave()
				if what == NOTIFICATION_APPLICATION_PAUSED:
					set_paused(true)
		NOTIFICATION_WM_CLOSE_REQUEST:
			if runner != null:
				autosave()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if hud != null:
				if ctl.mode != PlayerController.Mode.NONE:
					ctl.cancel_mode()
				else:
					hud.toggle_pause_menu()
