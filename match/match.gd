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
## M2.6: pause reasons ("user" = pause button, "menu" = pause menu, "app" = Android sent the app
## to the background). paused = any reason. Resume in the pause menu clears every reason, so the
## game can never be left paused with no visible way out (M2.5 bug: closing and reopening the app
## while the pause menu was open left the game stuck on "Paused").
var _pause_reasons: Dictionary = {}
var speed: float = 1.0
var avg_tick_ms: float = 0.0
var avg_view_ms: float = 0.0   ## WorldView.frame cost (interpolation, fog, VFX emitters)
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
	# Zero Hour-style lighting (art bible baseline, GDD 15.1): strong warm sun with crisp
	# shadows, slightly cool ambient for the shadow side, light warm distance haze,
	# slightly saturated filmic grade.
	var menv := MapEnv.for_map(runner.sim.map_id)   # M2.5: per-map lighting
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b0c0e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = menv["ambient"]
	e.ambient_light_energy = menv["ambient_energy"]
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = menv["exposure"]
	e.fog_enabled = true
	e.fog_light_color = menv["fog_col"]
	e.fog_light_energy = 0.9
	e.fog_density = menv["fog_density"]
	e.fog_sky_affect = 0.0
	e.fog_aerial_perspective = 0.0
	e.adjustment_enabled = true
	e.adjustment_saturation = menv["saturation"]
	e.adjustment_contrast = menv["contrast"]
	e.adjustment_brightness = 1.0
	e.tonemap_white = 6.0
	# M3.2: subtle bloom on muzzle flashes, fire, lamps and sun-hot highlights (Ultra / High)
	e.glow_enabled = bool(Settings.preset().get("glow", false))
	e.glow_intensity = 0.55
	e.glow_strength = 0.9
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = menv["sun_rot"]
	sun.light_energy = menv["sun_energy"]
	sun.light_color = menv["sun_col"]
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 0.4   # M3.2: crisper, darker ZH-style shadows
	sun.shadow_opacity = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_split_1 = 0.35
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
	AudioDirector.world_root = world
	AudioDirector.announcer_faction = String(runner.sim.faction_of(focus_pid))
	AudioDirector.play_music("battle")
	AudioDirector.play_ambient("wind")
	if runner.sim.tick < 10:
		AudioDirector.announce("battle_start")

func _exit_tree() -> void:
	AudioDirector.on_match_end()

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
	var tv := Time.get_ticks_usec()
	world.frame(clampf(acc / DT, 0.0, 1.0) if not paused else 1.0, delta)
	avg_view_ms = lerpf(avg_view_ms, (Time.get_ticks_usec() - tv) / 1000.0, 0.05)
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
		if my_team >= 0:
			AudioDirector.announce("victory" if won else "defeat")
		SaveSystem.clear_suspend()
	_over_t += delta
	if _over_t > 3.5:
		GameSession.goto("res://ui/results.tscn")

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
		if p:
			_pause_reasons["menu"] = true
		else:
			_pause_reasons.clear()      # Resume: always back to a running game
	else:
		if p:
			_pause_reasons["user"] = true
		else:
			_pause_reasons.clear()
	paused = not _pause_reasons.is_empty()

## Android pause / focus loss: save, then pause behind the pause menu so that reopening the app
## shows the menu with a working Resume (instead of a bare "Paused" label).
func app_backgrounded() -> void:
	if runner == null:
		return
	autosave()
	if runner.sim.game_over:
		return
	_pause_reasons["app"] = true
	paused = true
	if hud != null:
		hud.show_pause_menu()

## Back in the foreground: stay paused behind the menu (the player taps Resume), but make sure the
## menu really is up and the frame clock does not try to catch up on the time spent away.
func app_foregrounded() -> void:
	acc = 0.0
	if paused and hud != null:
		hud.show_pause_menu()

func cycle_speed() -> void:
	var sp := [1.0, 1.5, 2.0, 0.5]
	speed = sp[(sp.find(speed) + 1) % sp.size()]

func restart() -> void:
	SaveSystem.clear_suspend()
	GameSession.goto("res://match/match.tscn")

func surrender() -> void:
	if local_pid >= 0:
		runner.issue({"t": "surrender", "p": local_pid})
		hud.toggle_pause_menu()

func quit_to_menu() -> void:
	autosave()
	GameSession.goto("res://ui/main_menu.tscn")

func autosave() -> void:
	if runner.sim.game_over or local_pid < 0:
		return
	_last_save_tick = runner.sim.tick
	var md := runner.serialize()
	SaveSystem.save_suspend({"sim": md["sim"], "match": md,
		"view": {"focus": cam.focus, "level": cam.level, "groups": ctl.groups}, "saved_at": Time.get_unix_time_from_system()})

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			app_backgrounded()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if runner != null:
				autosave()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if runner != null:
				app_foregrounded()
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
