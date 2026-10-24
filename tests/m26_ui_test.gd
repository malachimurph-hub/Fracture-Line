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
	var parts := "pause,place,bar,themes,menu,credits"
	if args.size() > 1 and not args[1].begins_with("--"):
		parts = args[1]
	if "pause" in parts: await test_pause()
	if "place" in parts: await test_placement()
	if "bar" in parts: await test_bar_and_top()
	if "themes" in parts: await test_themes()
	if "menu" in parts: await test_menu_battle()
	if "credits" in parts: await test_credits()
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
	for fac in ["eu", "us", "tpla", "ecc"]:   # M3.0 F: + Russia
		await _start(fac)
		sim.players[0].supply = 50000
		var b := _builder()
		m.ctl.set_selection([b.id])
		m.cam.jump_to(FX.to_world(b.pos), false)
		m.cam.set_level(1)
		await frames(10)
		var bid: StringName = {"eu": &"eu_reactor", "us": &"us_reactor", "tpla": &"tpla_camp", "ecc": &"ecc_power"}[fac]
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
	for fac in ["eu", "tpla", "us", "ecc"]:   # M3.0 F: + Russia
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
	check("four distinct faction looks", looks["eu"][0] != looks["tpla"][0] and looks["tpla"][0] != looks["us"][0] and looks["eu"][1] != looks["us"][1]
		and looks["ecc"][1] != looks["eu"][1] and looks["ecc"][1] != looks["tpla"][1] and looks["ecc"][1] != looks["us"][1], looks)

# ------------------------------------------------------------------ 6 main menu battle
## Menu layout: whatever the title (renamed game, long localisation), every menu button sits
## fully inside the screen and the title column never pushes the button column off the edge.
func test_menu_layout(mm: Node) -> void:
	var orig: String = mm._title.text
	for t in ["RULES OF ENGAGEMENT", "RULES OF ENGAGEMENT: THE EXTREMELY LONG LOCALISED SUBTITLE EDITION"]:
		mm._title.text = t
		mm._fit_title()
		await frames(4)
		var screen := get_viewport().get_visible_rect().grow(0.5)
		var bad: Array = []
		var n := 0
		for b in mm.find_children("*", "Button", true, false):
			if (b as Control).is_visible_in_tree():
				n += 1
				if not screen.encloses((b as Control).get_global_rect()):
					bad.append([(b as Button).text, (b as Control).get_global_rect()])
		var tr_ok: bool = not mm._title.visible or screen.encloses(mm._title.get_global_rect())
		if mm._logo != null:
			tr_ok = tr_ok and screen.encloses(mm._logo.get_global_rect()) and mm._logo.size.y >= 120.0
		check("menu buttons inside the screen with title '%s'" % t, n >= 3 and bad.is_empty() and tr_ok,
			"buttons %d outside %s title %s font %d screen %s" % [n, bad, mm._title.get_global_rect(), mm._title.get_theme_font_size("font_size"), screen])
	mm._title.text = orig
	mm._fit_title()
	if mm._logo != null:
		await frames(3)
		var lr: Rect2 = mm._logo.get_global_rect()
		var right_x := INF
		for b in mm.find_children("*", "Button", true, false):
			if (b as Control).is_visible_in_tree():
				right_x = minf(right_x, (b as Control).get_global_rect().position.x)
		check("menu logo shown, fits the left column, clear of the buttons", lr.size.y >= 120.0 and lr.end.x <= right_x and get_viewport().get_visible_rect().grow(0.5).encloses(lr),
			"logo %s buttons_x %.0f" % [lr, right_x])

func test_menu_battle() -> void:   # M3.1: static key art replaced the live battle
	if m != null:
		m.queue_free()
		m = null
	await frames(2)
	var t0 := Time.get_ticks_msec()
	var mm: Node = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(mm)
	await frames(2)
	var open_ms := Time.get_ticks_msec() - t0
	await test_menu_layout(mm)
	var art: TextureRect = mm.find_child("KeyArt", true, false)
	check("main menu shows the key-art battle image", art != null and art.texture != null and art.texture.get_width() >= 2560, art.texture.get_size() if art != null and art.texture != null else "none")
	check("no live battle behind the menu", mm.find_children("*", "SubViewport", true, false).is_empty())
	check("menu opens quickly", open_ms < 1500, "%d ms" % open_ms)
	await shot("m31_main_menu_keyart")
	mm.queue_free()

## M2.7: credits wrap inside the panel and scroll only vertically (nothing cut off or sideways).
func test_credits() -> void:
	if m != null:
		m.queue_free()
		m = null
	var cr: Node = (load("res://ui/credits.tscn") as PackedScene).instantiate()
	add_child(cr)
	await frames(3)
	await secs(0.5)
	var sc: ScrollContainer = cr.find_child("CreditsScroll", true, false)
	var t: Label = cr.find_child("CreditsText", true, false)
	check("credits text-fit: scroll + label exist", sc != null and t != null)
	if sc == null or t == null:
		cr.queue_free()
		return
	var screen := Rect2(Vector2.ZERO, UiScale.logical_size()).grow(0.5)
	check("credits text-fit: no sideways scroll", sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and sc.get_h_scroll_bar().max_value <= sc.size.x + 0.5,
		"h max %.1f view %.1f" % [sc.get_h_scroll_bar().max_value, sc.size.x])
	check("credits text-fit: text wraps within the panel", t.size.x <= sc.size.x + 0.5 and screen.encloses(sc.get_global_rect()), "label %.1f panel %.1f" % [t.size.x, sc.size.x])
	check("credits text-fit: body scrolls vertically", t.size.y > sc.size.y and sc.get_v_scroll_bar().max_value > sc.size.y, "text h %.0f view h %.0f" % [t.size.y, sc.size.y])
	check("credits text-fit: starts with the new name", t.text.begins_with("RULES OF ENGAGEMENT"))
	await shot("m27_credits_top")
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await frames(3)
	await shot("m27_credits_end")
	cr.queue_free()
	await frames(2)
