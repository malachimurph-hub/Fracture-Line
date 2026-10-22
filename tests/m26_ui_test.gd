extends Node
## M2.6 rendered UI test + screenshots (Malachi's M2.5 feedback):
##  1 app pause/resume never leaves the game stuck on "Paused"
##  2 placement: tap / drag the ghost, it stays until the floating ✓ / ✗ (✓ disabled when invalid)
##  3 command bar slides out with nothing selected, minimap grows, slides back on selection
##  4 top strip ~15% smaller with >= 44 dp touch targets
##  5 faction-themed HUD (EU / TPLA / US)
##  6 main menu live battle background
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m26_ui_test.tscn -- <out_dir> --dpi=450
var out_dir := "/tmp/m26"
var m: Node
var sim: SimWorld
var checks: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	# virtual gesture clock (as in the touch test): slow software-rendered frames must not turn a
	# tap into a long-press
	WorldInput.test_clock_ms = 1000
	var parts := "pause,place,bar,themes,menu"
	if args.size() > 1 and not args[1].begins_with("--"):
		parts = args[1]
	if "pause" in parts: await test_pause()
	if "place" in parts: await test_placement()
	if "bar" in parts: await test_bar_and_top()
	if "themes" in parts: await test_themes()
	if "menu" in parts: await test_menu_battle()
	var failed := false
	for c in checks:
		print(("PASS " if c[1] else "FAIL ") + c[0] + ("" if c.size() < 3 else "  (" + str(c[2]) + ")"))
		failed = failed or not c[1]
	print("=== M26 UI RESULT: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func check(name: String, ok: bool, info = null) -> void:
	checks.append([name, ok] if info == null else [name, ok, info])

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout

func shot(name: String) -> String:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())
	return p

func tap_at(logical: Vector2) -> void:
	var p: Vector2 = get_viewport().get_final_transform() * logical
	for down in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = p
		t.pressed = down
		Input.parse_input_event(t)
		await frames(3)

func tap(c: Control) -> void:
	await tap_at(c.get_global_rect().get_center())

func drag(a: Vector2, b: Vector2, steps: int = 8) -> void:
	var xf := get_viewport().get_final_transform()
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = xf * a
	t.pressed = true
	Input.parse_input_event(t)
	await frames(2)
	for i in steps:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = xf * a.lerp(b, float(i + 1) / steps)
		d.relative = xf.basis_xform((b - a) / steps)
		Input.parse_input_event(d)
		await frames(1)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = xf * b
	r.pressed = false
	Input.parse_input_event(r)
	await frames(3)

func _start(fac: String, enemy: String = "tpla") -> void:
	if m != null:
		m.queue_free()
		await frames(2)
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 26
	for i in 4:
		cfg["slots"][i]["kind"] = "closed"
	cfg["slots"][0]["kind"] = "human"
	cfg["slots"][0]["faction"] = fac
	cfg["slots"][1]["kind"] = "ai"
	cfg["slots"][1]["faction"] = enemy
	cfg["options"]["fog"] = false
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(5)
	sim = m.runner.sim
	m.runner.ais.clear()

func _builder() -> SimEntity:
	var bid: StringName = Content.faction(sim.faction_of(0))["builder"]
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == 0 and e.def_id == bid:
			return e
	return null

func _hq() -> SimEntity:
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == 0 and e.kind == SimEntity.Kind.BUILDING:
			return e
	return null

# ------------------------------------------------------------------ 1 pause / resume
func test_pause() -> void:
	await _start("eu")
	await secs(0.5)
	var t0: int = sim.tick
	# plain background -> foreground
	m._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	m._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	await frames(5)
	check("app pause: game paused behind the pause menu", m.paused and m.hud.pause_menu.visible)
	m._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	m._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(5)
	check("app resume: pause menu up with Resume", m.hud.pause_menu.visible and m.hud.pause_menu.find_child("PAUSE_RESUME", true, false) != null)
	await shot("m26_pause_after_resume")
	await tap(m.hud.pause_menu.find_child("PAUSE_RESUME", true, false))
	await secs(0.6)
	check("tapping Resume after reopening the app un-pauses the game", not m.paused and not m.hud.pause_menu.visible and sim.tick > t0, "tick %d -> %d" % [t0, sim.tick])
	# the M2.5 bug: app paused while the pause menu was already open
	m.hud.toggle_pause_menu()
	await frames(3)
	m._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	m._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await frames(3)
	await tap(m.hud.pause_menu.find_child("PAUSE_RESUME", true, false))
	var t1: int = sim.tick
	await secs(0.6)
	check("M2.5 bug: menu open + app paused/resumed -> Resume still resumes", not m.paused and sim.tick > t1, "tick %d -> %d" % [t1, sim.tick])
	# pause button, then app pause, then Resume
	m.hud.toggle_pause()
	m._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	m._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await frames(3)
	await tap(m.hud.pause_menu.find_child("PAUSE_RESUME", true, false))
	await frames(3)
	check("pause button + app pause -> Resume resumes", not m.paused)

# ------------------------------------------------------------------ 2 placement
func test_placement() -> void:
	for fac in ["eu", "us", "tpla"]:
		await _start(fac)
		sim.players[0].supply = 50000
		var b := _builder()
		m.ctl.set_selection([b.id])
		m.cam.jump_to(FX.to_world(b.pos), false)
		m.cam.set_level(1)
		await frames(10)
		var bid: StringName = {"eu": &"eu_reactor", "us": &"us_reactor", "tpla": &"tpla_camp"}[fac]
		m.ctl.begin_place(bid)
		await frames(5)
		var pc: PlaceConfirm = m.hud.place_confirm
		check("%s: ✓/✗ shown above the ghost" % fac, pc.visible and m.ctl.mode == PlayerController.Mode.PLACE)
		# tap an open spot: the ghost moves there and stays (no build yet)
		var hq := _hq()
		var d := Content.building(bid)
		var spot := Vector2i(-1, -1)
		var vis := Rect2(Vector2(UiScale.logical_size().x * 0.3, UiScale.logical_size().y * 0.3), UiScale.logical_size() * Vector2(0.4, 0.3))
		for rr in range(4, 18):
			for dx in range(-rr, rr + 1):
				for sy in [1, -1]:
					var t: Vector2i = hq.tile + Vector2i(dx, rr * sy)
					if spot.x < 0 and t.distance_to(m.ctl.place_tile) > 4.0 and sim.can_place(0, bid, t, true, [b.id]) == "" \
							and vis.has_point(m.cam.cam.unproject_position(Vector3(t.x + d.footprint.x * 0.5, 0, t.y + d.footprint.y * 0.5))):
						spot = t
		if spot.x < 0:
			m.cam.jump_to(FX.to_world(hq.pos), false)
			await frames(5)
			for rr in range(4, 18):
				for dx in range(-rr, rr + 1):
					var t2: Vector2i = hq.tile + Vector2i(dx, rr)
					if spot.x < 0 and sim.can_place(0, bid, t2, true, [b.id]) == "" and vis.has_point(m.cam.cam.unproject_position(Vector3(t2.x + d.footprint.x * 0.5, 0, t2.y + d.footprint.y * 0.5))):
						spot = t2
		var tap_p: Vector2 = m.cam.cam.unproject_position(Vector3(spot.x + d.footprint.x * 0.5, 0, spot.y + d.footprint.y * 0.5))
		await tap_at(tap_p)
		check("%s: tap moves the ghost and keeps it until confirmed" % fac, m.ctl.mode == PlayerController.Mode.PLACE and m.ctl.place_tile.distance_to(spot) <= 1.5, "%s vs %s" % [m.ctl.place_tile, spot])
		check("%s: ✓ enabled on a valid spot" % fac, not pc.ok_btn.disabled and m.ctl.place_reason == "")
		# ✓/✗ sit above the ghost
		var ghost_top: Vector2 = m.cam.cam.unproject_position(Vector3(m.ctl.place_tile.x + d.footprint.x * 0.5, 2.2, m.ctl.place_tile.y + d.footprint.y * 0.5))
		check("%s: ✓/✗ float just above the silhouette" % fac, pc.get_global_rect().end.y <= ghost_top.y + 1.0 and absf(pc.get_global_rect().get_center().x - ghost_top.x) < 80.0)
		await shot("m26_place_valid_%s" % fac)
		# drag the ghost onto the HQ: invalid -> red, ✓ disabled
		var cur: Vector2 = m.cam.cam.unproject_position(Vector3(m.ctl.place_tile.x + d.footprint.x * 0.5, 0, m.ctl.place_tile.y + d.footprint.y * 0.5))
		var hqd := Content.building(hq.def_id)
		var onhq: Vector2 = m.cam.cam.unproject_position(Vector3(hq.tile.x + hqd.footprint.x * 0.5, 0, hq.tile.y + hqd.footprint.y * 0.5))
		var goff := Vector2(0, -UiScale.mm(float(Settings.g("ghost_offset_mm"))))   # ghost rides above the finger
		await drag(cur, onhq - goff)
		check("%s: drag moves the ghost; invalid spot disables ✓" % fac, m.ctl.mode == PlayerController.Mode.PLACE and m.ctl.place_reason != "" and pc.ok_btn.disabled, m.ctl.place_reason)
		await shot("m26_place_invalid_%s" % fac)
		await tap(pc.ok_btn)
		check("%s: disabled ✓ does not place" % fac, m.ctl.mode == PlayerController.Mode.PLACE)
		# back to the valid spot and confirm
		m.ctl.move_ghost_tile(spot)
		await frames(3)
		var n0 := _count_sites(bid)
		await tap(pc.ok_btn)
		await secs(0.4)
		check("%s: ✓ places the building" % fac, m.ctl.mode == PlayerController.Mode.NONE and _count_sites(bid) > n0)
		# ✗ cancels
		m.ctl.set_selection([b.id])
		m.ctl.begin_place(bid)
		await frames(3)
		await tap(pc.cancel_btn)
		check("%s: ✗ cancels placement" % fac, m.ctl.mode == PlayerController.Mode.NONE and not pc.visible)

func _count_sites(bid: StringName) -> int:
	var n := 0
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == 0 and e.def_id == bid:
			n += 1
	return n

# ------------------------------------------------------------------ 3 + 4 bar slide, top strip
func test_bar_and_top() -> void:
	await _start("eu")
	var h: Hud = m.hud
	m.ctl.set_selection([])
	await secs(0.6)
	check("nothing selected: command bar slid out", h.bar_k >= 0.999 and h.bar.position.y >= UiScale.safe_rect.end.y - 1.0, "k=%.2f" % h.bar_k)
	check("nothing selected: minimap enlarged", h.minimap.size.x >= 150.0, h.minimap.size)
	check("money / power / Build still on screen", h.res_panel.get_global_rect().end.y <= UiScale.logical_size().y + 0.5 and h.money_lbl.is_visible_in_tree())
	await shot("m26_bar_hidden")
	m.ctl.set_selection([_builder().id])
	h._process(0.05)
	check("bar animates (one 50 ms step = partway)", h.bar_k > 0.5 and h.bar_k < 0.9, "k=%.2f" % h.bar_k)
	await secs(0.5)
	check("selection: bar back up, minimap docked", h.bar_k <= 0.001 and h.minimap.size.x < 110.0, "k=%.2f mm=%s" % [h.bar_k, h.minimap.size])
	await shot("m26_bar_shown")
	# top strip: drawn ~15% smaller than M2.5 (44 dp) with >= 44 dp touch targets
	var ok := true
	var info := []
	for c in [h.army_btn, h.idle_btn, h.pause_btn, h.top.get_node("MenuBtn"), h.groups_btn]:
		var r: Rect2 = c.get_global_rect()
		var hr: Rect2 = c.hit_rect()
		info.append("%s %.0fx%.0f hit %.0fx%.0f" % [c.name, r.size.x, r.size.y, hr.size.x, hr.size.y])
		ok = ok and r.size.y <= 44.0 * 0.87 and hr.size.y >= 44.0 and hr.size.x >= 44.0
	check("top buttons ~15%% smaller, >= 44 dp touch targets", ok, ", ".join(info))
	# the padding is real: a tap just outside the drawn pause button still toggles pause
	var pr: Rect2 = h.pause_btn.get_global_rect()
	var was: bool = m.paused
	await tap_at(Vector2(pr.get_center().x, pr.end.y + 2.5))
	check("tap in the invisible padding hits the button", m.paused != was)
	if m.paused:
		h.toggle_pause()

# ------------------------------------------------------------------ 5 faction themes
func test_themes() -> void:
	var looks := {}
	for fac in ["eu", "tpla", "us"]:
		await _start(fac, "eu" if fac != "eu" else "us")
		var b := _builder()
		m.ctl.set_selection([b.id])
		m.cam.jump_to(FX.to_world(b.pos), false)
		await secs(0.5)
		var h: Hud = m.hud
		var sb: StyleBoxFlat = h.bar.get_theme_stylebox("panel")
		looks[fac] = [sb.bg_color, sb.border_color, sb.skew]
		check("%s HUD uses the %s theme + emblem" % [fac, fac], h.root.theme == UiTheme.faction_theme(StringName(fac)) and h.emblem.fac == StringName(fac))
		await shot("m26_hud_%s" % fac)
		# every command-card / selection caption fits in the faction font (US: "Marine Rifleman")
		var chk := func(name: String, ok: bool, info = null): check(fac + " text fit: " + name, ok, info)
		await HudTextCheck.exercise(m, StringName(fac), get_tree(), chk)
	check("three distinct faction looks", looks["eu"][0] != looks["tpla"][0] and looks["tpla"][0] != looks["us"][0] and looks["eu"][1] != looks["us"][1], looks)

# ------------------------------------------------------------------ 6 main menu battle
func test_menu_battle() -> void:
	if m != null:
		m.queue_free()
		m = null
	await frames(2)
	var mm: Node = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(mm)
	await secs(1.0)
	var bg: Node = mm.find_child("MenuBattle", true, false)
	check("main menu has a live battle behind it", bg != null)
	if bg == null:
		return
	var t0: int = bg.runner.sim.tick
	var c0: Vector3 = bg.cam.focus
	# wait for ~25 s of game time (the box renders in software, so wall time varies)
	var waited := 0.0
	while bg.runner.sim.tick < t0 + 500 and waited < 120.0:
		await secs(1.0)
		waited += 1.0
	check("menu battle sim runs and units fight", bg.runner.sim.tick > t0 + 60 and bg.shots_seen > 0, "tick %d->%d shots %d" % [t0, bg.runner.sim.tick, bg.shots_seen])
	check("menu camera drifts", bg.cam.focus.distance_to(c0) > 0.5, bg.cam.focus.distance_to(c0))
	var facs := {}
	for id in bg.runner.sim.ids:
		var e: SimEntity = bg.runner.sim.ents[id]
		if e.kind == SimEntity.Kind.UNIT:
			facs[String(e.def_id).split("_")[0]] = true
	check("menu battle fields roster units from the content (not a hard-coded list)", bg.pool_size() >= 10 and facs.size() >= 2, "pool %d facs %s map %s" % [bg.pool_size(), facs.keys(), bg.runner.sim.map_id])
	await shot("m26_main_menu_battle")
	await secs(4.0)
	await shot("m26_main_menu_battle_2")
	mm.queue_free()
