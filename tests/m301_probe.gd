extends Node
## M3.0.1 timing probe: wall time of each screen change (the goto call itself and the
## following frames until they settle). Headless: CPU-side cost only (no GPU / shaders).
var log := []

func _t() -> float:
	return Time.get_ticks_usec() / 1000.0

func _measure(label: String, f: Callable, frames := 40) -> void:
	var t0 := _t()
	f.call()
	var t1 := _t()
	var worst := 0.0
	var prev := t1
	var first := -1.0
	for i in frames:
		await get_tree().process_frame
		var n := _t()
		if first < 0:
			first = n - t1
		worst = maxf(worst, n - prev)
		prev = n
	var line := "TIMING %-28s call=%7.0fms first_frame=%7.0fms worst_frame=%7.0fms total=%7.0fms" % [label, t1 - t0, first, worst, prev - t0]
	print(line)
	printerr(line)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await _measure("menu (first)", func(): GameSession.goto("res://ui/main_menu.tscn"), 30)
	await _measure("menu -> settings", func(): GameSession.goto("res://ui/settings_screen.tscn"), 20)
	await _measure("settings back -> menu", func(): get_tree().current_scene.go_back(), 30)
	await _measure("menu -> settings (2)", func(): GameSession.goto("res://ui/settings_screen.tscn"), 20)
	await _measure("settings back -> menu (2)", func(): get_tree().current_scene.go_back(), 30)
	await _measure("menu -> lobby", func(): GameSession.goto("res://ui/skirmish_setup.tscn"), 20)
	await _measure("lobby back -> menu", func(): get_tree().current_scene.go_back(), 30)
	await _measure("menu -> lobby (2)", func(): GameSession.goto("res://ui/skirmish_setup.tscn"), 20)
	var t0 := _t()
	get_tree().current_scene._start()
	var tap_frame := -1.0
	var worst := 0.0
	var prev := _t()
	var after := 0
	while after < 15 and _t() - t0 < 120000.0:
		await get_tree().process_frame
		var n := _t()
		if tap_frame < 0:
			tap_frame = n - t0
		worst = maxf(worst, n - prev)
		prev = n
		var cs := get_tree().current_scene
		if cs != null and cs.scene_file_path == "res://match/match.tscn":
			after += 1
	print("TIMING %-28s first_frame=%7.0fms worst_frame=%7.0fms total=%7.0fms" % ["lobby start battle", tap_frame, worst, prev - t0])
	await _measure("match -> menu (fresh)", func(): GameSession.goto("res://ui/main_menu.tscn"), 30)
	await _measure("menu -> map builder", func(): GameSession.goto("res://ui/map_builder.tscn"), 20)
	await _measure("map builder back -> menu", func(): get_tree().current_scene.go_back(), 30)
	get_tree().quit()
