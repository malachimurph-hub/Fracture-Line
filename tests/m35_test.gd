## M3.5 headless checks (test_runner "m35"): Malachi's M3.5 list - photo menu, touch scrolling,
## lobby layout, locked roster, music shuffle, squads, poses, artillery elevation, factions.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	await _menu_layout(t)
	await _touch_scroll(t)
	await _lobby_layout(t)
	await _roster_lock(t)
	_music_shuffle(t)

static func _frames(t: Node, n: int) -> void:
	for i in n:
		await t.get_tree().process_frame

## Resizes the (headless) window; UiScale turns it into the logical screen the UI lays out in.
## Returns that logical size (a window up to 420 px tall is 1:1).
static func _screen(t: Node, sz: Vector2) -> Vector2:
	t.get_window().size = Vector2i(sz)
	await _frames(t, 2)
	return UiScale.logical_size()

# ------------------------------------------------------------------ 1/2 photo menu
static func _menu_layout(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://ui/main_menu.gd")
	t._check(not ResourceLoader.exists("res://ui/menu_battle.gd") and not src.contains("MenuBattle") and not src.contains("SubViewport"), "the live menu battle is gone (script and wiring)")
	var old_win := t.get_window().size
	# small landscape phones (dp): 19.5:9 at 450 dpi, 16:9, a short 2:1, a 4:3 tablet
	for wsz in [Vector2(832, 384), Vector2(731, 411), Vector2(640, 320), Vector2(1024, 768)]:
		var sz: Vector2 = await _screen(t, wsz)
		var mm: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
		t.add_child(mm)
		await _frames(t, 4)
		var scr := Rect2(Vector2.ZERO, sz).grow(0.5)
		var bad: Array = []
		var right := 0.0
		for b in mm.find_children("*", "Button", true, false):
			var r := (b as Control).get_global_rect()
			right = maxf(right, r.end.x)
			if not scr.encloses(r) or r.end.x > sz.x * 0.5:
				bad.append("%s %s" % [b.name, r])
		var lr: Rect2 = mm._logo.get_global_rect() if mm._logo != null else Rect2()
		var art: TextureRect = mm.find_child("KeyArt", true, false)
		t._check(bad.is_empty() and mm._logo != null and scr.encloses(lr) and lr.position.x >= right and lr.get_center().x > sz.x * 0.65
			and lr.position.y < sz.y * 0.15 and lr.size.y <= sz.y * 0.36 and lr.size.y >= 60.0,
			"menu %dx%d: buttons in a left column inside the screen, small logo top right clear of them %s logo %s" % [sz.x, sz.y, bad, lr])
		t._check(art != null and art.texture != null and art.texture.resource_path == "res://assets/ui/menu_photo.jpg" and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"menu %dx%d: Malachi's photo, cover-fit" % [sz.x, sz.y])
		var cb := mm.find_child("Campaign", true, false) as Button
		var soon := mm.find_child("CampaignSoon", true, false) as Label
		t._check(cb != null and soon != null and soon.text == "Coming soon", "menu keeps Campaign 'Coming soon'")
		mm.queue_free()
		await _frames(t, 1)
	var tex: Texture2D = load("res://assets/ui/menu_photo.jpg")
	var imp := FileAccess.get_file_as_string("res://assets/ui/menu_photo.jpg.import")
	t._check(tex.get_width() <= 2048 and tex.get_width() >= 1600 and imp.contains("compress/mode=1") and imp.contains("mipmaps/generate=false"),
		"menu photo imported phone-sized (%dx%d) with lossy (WebP) compression, no mipmaps" % [tex.get_width(), tex.get_height()])
	t._check(load("res://ui/fonts/BlackOpsOne-Regular.ttf") != null and src.contains("TITLE_FONT"), "menu buttons use the bundled stencil face")
	await _screen(t, Vector2(old_win))

# ------------------------------------------------------------------ 3 touch scrolling
static func _press(vp: Viewport, at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	vp.push_input(e, true)

static func _move(vp: Viewport, at: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(e, true)

static func _touch_scroll(t: Node) -> void:
	var old_win := t.get_window().size
	await _screen(t, Vector2(1280, 720))
	var host := Control.new()
	host.position = Vector2.ZERO
	host.size = Vector2(300, 300)
	t.add_child(host)
	var sc := TouchScroll.new()
	sc.position = Vector2(0, 0)
	sc.size = Vector2(300, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var hits := [0]
	for i in 30:
		var b := Button.new()
		b.text = "Map %d" % i
		b.custom_minimum_size = Vector2(280, 60)
		b.pressed.connect(func(): hits[0] += 1)
		v.add_child(b)
	await _frames(t, 3)
	var vp := t.get_viewport()
	t._check(not sc.follow_focus and sc.scroll_deadzone > 0 and (v.get_child(0) as Button).mouse_filter == Control.MOUSE_FILTER_PASS,
		"scroll lists: deadzone %d, follow_focus off, buttons pass drags to the list" % sc.scroll_deadzone)
	# a tap still presses the button
	_press(vp, Vector2(100, 30), true)
	await _frames(t, 1)
	_press(vp, Vector2(100, 30), false)
	await _frames(t, 1)
	t._check(hits[0] == 1 and sc.scroll_vertical == 0, "a tap on a list button still presses it (hits %d)" % hits[0])
	# a drag that starts on a button scrolls the list and never fires the button
	hits[0] = 0
	var y := 250.0
	_press(vp, Vector2(100, y), true)
	await _frames(t, 1)
	for k in 8:
		y -= 22.0
		_move(vp, Vector2(100, y), Vector2(0, -22))
		await _frames(t, 1)
	var dragged := sc.scroll_vertical
	_press(vp, Vector2(100, y), false)
	await _frames(t, 1)
	t._check(dragged >= 140 and hits[0] == 0, "dragging on a button scrolls the list (%d px) and does not press it (hits %d)" % [dragged, hits[0]])
	# fling: the list keeps gliding after release, then settles
	var after := sc.scroll_vertical
	await _frames(t, 10)
	t._check(sc.scroll_vertical > after, "release flings the list on (%d -> %d)" % [after, sc.scroll_vertical])
	var t0 := Time.get_ticks_msec()
	while sc.is_scrolling() and Time.get_ticks_msec() - t0 < 5000:
		await t.get_tree().process_frame
	t._check(not sc.is_scrolling(), "the fling decays and stops")
	host.queue_free()
	await _screen(t, Vector2(old_win))
	var users := 0
	for p in ["res://ui/skirmish_setup.gd", "res://ui/settings_screen.gd", "res://ui/credits.gd", "res://ui/map_builder.gd"]:
		var s := FileAccess.get_file_as_string(p)
		if s.contains("TouchScroll.new()") and not s.contains("ScrollContainer.new()"):
			users += 1
	t._check(users == 4, "lobby, map picker, settings, credits and Map Builder lists all use the touch scroller (%d/4 files)" % users)

# ------------------------------------------------------------------ 4 lobby layout / map picker
static func _lobby_layout(t: Node) -> void:
	var old_win := t.get_window().size
	for wsz in [Vector2(832, 384), Vector2(731, 411), Vector2(640, 360), Vector2(600, 450), Vector2(1024, 768)]:
		var sz: Vector2 = await _screen(t, wsz)
		var lobby: Control = (load("res://ui/skirmish_setup.tscn") as PackedScene).instantiate()
		t.add_child(lobby)
		await _frames(t, 5)
		var scr := Rect2(Vector2.ZERO, sz).grow(0.5)
		var col: Control = lobby.find_child("MapColumn", true, false)
		var pv: Control = lobby.find_child("MapPreview", true, false)
		var md: MapDef = Content.maps[StringName(lobby.cfg["map"])]
		var pr: Rect2 = lobby.preview_rect(pv.size, Vector2(md.size))
		var pg := Rect2(pv.global_position + pr.position, pr.size)
		var ok := scr.encloses(col.get_global_rect()) and scr.encloses(pg) and pg.size.x >= 60.0 and absf(pg.size.x / pg.size.y - float(md.size.x) / md.size.y) < 0.05
		var start: Control = lobby.start_btn
		t._check(ok and scr.encloses(start.get_global_rect()), "lobby %dx%d: map column and the whole preview (%s, map aspect kept) on screen" % [sz.x, sz.y, pg])
		lobby.queue_free()
		await _frames(t, 1)
	await _screen(t, Vector2(832, 384))
	var lb: Control = (load("res://ui/skirmish_setup.tscn") as PackedScene).instantiate()
	t.add_child(lb)
	await _frames(t, 4)
	lb.map_option.pressed.emit()
	await _frames(t, 3)
	var pk: Control = lb.find_child("MapPicker", true, false)
	var grid: GridContainer = lb.find_child("MapGrid", true, false)
	t._check(pk != null and grid != null and grid.get_child_count() == SkirmishConfig.map_ids().size() and lb.find_child("MapScroll", true, false) is TouchScroll,
		"map picker: a touch-scrolling grid with every map")
	var pick: StringName = SkirmishConfig.map_ids()[1]
	(lb.find_child("Map_" + String(pick), true, false) as Button).pressed.emit()
	await _frames(t, 2)
	t._check(String(lb.cfg["map"]) == String(pick) and lb.picker == null and lb.map_option.text.begins_with(t.tr(Content.maps[pick].name_key)), "tapping a map card picks it and closes the picker")
	lb.queue_free()
	await _frames(t, 1)
	await _screen(t, Vector2(old_win))

# ------------------------------------------------------------------ 5 locked roster
static func _roster_lock(t: Node) -> void:
	var lobby: Control = (load("res://ui/skirmish_setup.tscn") as PackedScene).instantiate()
	t.add_child(lobby)
	await _frames(t, 3)
	var want := {"Japan": false, "Poland": false, "China": false, "United Kingdom": false}
	var drops := 0
	var ok := true
	for o in lobby.find_children("*", "OptionButton", true, false):
		var ob := o as OptionButton
		var has_ecc := false
		for k in ob.item_count:
			has_ecc = has_ecc or ob.get_item_text(k).begins_with("Russia")
		if not has_ecc:
			continue
		drops += 1
		for k in ob.item_count:
			var tx := ob.get_item_text(k)
			for nm in want:
				if tx.begins_with(nm):
					want[nm] = true
					ok = ok and ob.is_item_disabled(k) and tx.contains("Coming soon")
					var ic := ob.get_item_icon(k).get_image()
					ok = ok and ic.get_pixel(ic.get_width() / 2, ic.get_height() / 2).get_luminance() < 0.45
			if tx.begins_with("Russia") or tx.begins_with("Germany") or tx.begins_with("Iran") or tx.begins_with("United States"):
				ok = ok and not ob.is_item_disabled(k)
	t._check(drops >= 4 and ok and not want.values().has(false), "roster: Japan, Poland, China and UK listed darkened, locked 'Coming soon' in every faction list (%d lists) %s" % [drops, want])
	t._check(Content.playable_factions().size() == 4 and not Content.faction_enabled(&"jp"), "locked factions are never playable")
	lobby.queue_free()
	await _frames(t, 1)

# ------------------------------------------------------------------ 6 music shuffle
static func _music_shuffle(t: Node) -> void:
	var ad = AudioDirector
	var w := SimWorld.new()
	w.rng.seed(77)
	var sim_before: Dictionary = w.rng.to_dict()
	seed(1234)
	var g_before := randi()
	seed(1234)
	var ok := true
	var info := {}
	for fac in [&"us", &"eu", &"tpla", &"ecc"]:
		ad.battle_faction = fac
		var firsts := {}
		var orders := {}
		for i in 24:
			ad.music_track = ""
			ad.play_music("battle")
			var o: Array = ad.match_order
			firsts[o[0]] = true
			orders[str(o)] = true
			ok = ok and o[0] != ad.MUSIC["menu"] and o.size() >= 3 and ad.battle_pool().all(func(x): return o.has(x))
		info[fac] = "%d openers, %d orders" % [firsts.size(), orders.size()]
		ok = ok and firsts.size() >= 2 and orders.size() >= 3
	ad.battle_faction = &""
	ad.play_music("menu")
	t._check(ok, "music: every faction's match gets its own random order, different openers, never the menu track first (Base Command stays the menu music) %s" % [info])
	t._check(randi() == g_before and w.rng.to_dict() == sim_before, "the music shuffle uses its own RNG (global and sim RNG untouched)")
