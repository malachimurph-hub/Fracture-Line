extends Node
## Rendered end-to-end UI flow test for EXPORTED builds (LinuxVerify preset, same stripped
## engine profile as the Android template):  main menu -> tap Skirmish -> lobby ->
## tap Start battle -> match runs. Taps are real InputEventScreenTouch events (emulated to
## mouse like on a phone). Run:
##   xvfb-run -s "-screen 0 2340x1080x24" FractureLineVerify.x86_64 --rendering-method mobile \
##     --resolution 2340x1080 -- --fl-ui-test --fl-out=/tmp/ui
var out_dir := "/tmp/fl_ui"
var failures: PackedStringArray = PackedStringArray()
var checks := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fl-out="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _check(ok: bool, what: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", out_dir.path_join(name + ".png"), " ", img.get_size())

func _find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text and (root as Button).is_visible_in_tree():
		return root
	for c in root.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null

func _tap(ctrl: Control) -> void:
	var p: Vector2 = get_viewport().get_final_transform() * ctrl.get_global_rect().get_center()
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = p
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(3)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = p
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(3)

func _overlay_up() -> bool:
	return GameSession.get_node_or_null("ErrorOverlay") != null

func _run() -> void:
	await _frames(30)
	var cs := get_tree().current_scene
	_check(cs != null and cs.scene_file_path == "res://ui/main_menu.tscn", "boots to main menu")
	await _shot("ui_01_main_menu")
	# every UI scene's scripts compile in this engine build
	for p in ["res://ui/main_menu.tscn", "res://ui/skirmish_setup.tscn", "res://match/match.tscn", "res://ui/results.tscn", "res://ui/settings_screen.tscn", "res://ui/credits.tscn"]:
		var bad := GameSession.broken_dependencies(p)
		bad.append_array(GameSession.broken_scripts(load(p)))
		_check(bad.is_empty(), "scripts compile for %s %s" % [p, bad])
	var sk := _find_button(get_tree().current_scene, tr("MENU_SKIRMISH"))
	_check(sk != null, "Skirmish button found")
	if sk != null:
		await _tap(sk)
	await _frames(20)
	cs = get_tree().current_scene
	_check(cs != null and cs.scene_file_path == "res://ui/skirmish_setup.tscn", "tap Skirmish opens the lobby (scene=%s)" % (cs.scene_file_path if cs else "null"))
	var start := _find_button(cs, tr("LOBBY_START_GAME")) if cs != null else null
	_check(start != null and not start.disabled, "lobby built: Start battle button present and enabled")
	_check(cs != null and cs.find_children("*", "OptionButton", true, false).size() >= 16, "lobby built: slot dropdowns present")
	_check(not _overlay_up(), "no error panel on the lobby")
	await _shot("ui_02_lobby")
	if start != null:
		await _tap(start)
	await _frames(60)
	cs = get_tree().current_scene
	_check(cs != null and cs.scene_file_path == "res://match/match.tscn", "tap Start battle opens the match (scene=%s)" % (cs.scene_file_path if cs else "null"))
	var t0 := -1
	if cs != null and "runner" in cs and cs.runner != null:
		t0 = cs.runner.sim.tick
	await get_tree().create_timer(8.0).timeout
	var t1 := -1
	if cs != null and is_instance_valid(cs) and "runner" in cs and cs.runner != null:
		t1 = cs.runner.sim.tick
	_check(t0 >= 0 and t1 > t0 + 40, "match simulation advancing (tick %d -> %d)" % [t0, t1])
	_check(not _overlay_up(), "no error panel in the match")
	await _shot("ui_03_match")
	# M2: full names everywhere in the bottom panel; no button text overflows or is clipped
	var chk := func(name: String, ok: bool, info = null): _check(ok, name + ("" if info == null else " %s" % [info]))
	if cs != null and is_instance_valid(cs) and "hud" in cs:
		await HudTextCheck.exercise(cs, &"eu", get_tree(), chk)
		await _shot("ui_03b_eu_hud")
	# the error panel itself works (shown for a missing scene, instead of a blank screen)
	var ok := GameSession.goto("res://does/not/exist.tscn")
	await _frames(5)
	_check(not ok and _overlay_up() and get_tree().current_scene == cs, "missing scene shows the error panel and keeps the current screen")
	_check(FileAccess.file_exists(GameSession.ERROR_LOG_PATH), "error log written to user://")
	await _shot("ui_04_error_panel")
	GameSession._hide_overlay()
	# M2: a TPLA match from the lobby config, same HUD checks
	var cfg: Dictionary = SkirmishConfig.default_setup()
	cfg["slots"][0]["faction"] = "tpla"
	cfg["slots"][1]["faction"] = "eu"
	GameSession.setup = cfg
	GameSession.goto("res://match/match.tscn")
	await _frames(60)
	var tm := get_tree().current_scene
	_check(tm != null and "runner" in tm and tm.runner != null and tm.runner.sim.faction_of(tm.local_pid) == &"tpla", "TPLA match starts from the lobby config")
	if tm != null and "hud" in tm:
		await HudTextCheck.exercise(tm, &"tpla", get_tree(), chk)
		await _shot("ui_05_tpla_hud")
	_check(not _overlay_up(), "no error panel in the TPLA match")
	print("=== UI FLOW RESULT: %s (%d checks, %d failed)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
