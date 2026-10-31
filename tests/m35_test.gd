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
	_squad_data(t)
	_squad_sim(t)
	await _squad_view(t)
	_drones(t)
	await _artillery(t)
	_factions(t)
	await _paint_oil(t)

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
	# Malachi's Russia / Iran tracks: 3+ of their own, so they no longer borrow; Germany still does
	var own_ok := true
	for fac in [&"ecc", &"tpla"]:
		ad.battle_faction = fac
		var pl: Array = ad.battle_playlist()
		own_ok = own_ok and pl.size() >= ad.MIN_POOL and ad.battle_pool() == pl
		for p in pl:
			var st = load(p)
			own_ok = own_ok and st is AudioStreamOggVorbis and (st as AudioStream).get_length() > 90.0
	ad.battle_faction = &"ecc"
	var ru: Array = ad.battle_playlist()
	ad.battle_faction = &"tpla"
	var ir: Array = ad.battle_playlist()
	ad.battle_faction = &"eu"
	var eu_borrows: bool = ad.battle_pool().size() > ad.battle_playlist().size()
	ad.battle_faction = &""
	own_ok = own_ok and ru.size() == 7 and ru[0].ends_with("battle_ru_steppe_march.ogg") and ru.filter(func(x): return String(x).contains("/ru_")).size() == 6
	own_ok = own_ok and ir.size() == 8 and ir.filter(func(x): return String(x).contains("/ir_")).size() == 7
	own_ok = own_ok and not str(ad.FACTION_PLAYLISTS).contains("red_bounce") and eu_borrows
	t._check(own_ok, "music: Russia (Steppe March + 6 of Malachi's) and Iran (7 of Malachi's + Zagros) shuffle only their own tracks; Germany still borrows")

# ------------------------------------------------------------------ 11 Combat Squads
const SQUADS := {
	&"us_squad": [&"us_barracks", "us_m16", "us_m240b", "us_javelin", "us_m203", [&"us_grunt", &"us_javelin"]],
	&"eu_squad": [&"eu_barracks", "eu_rifle", "eu_mg3", "eu_lancer_missile", "eu_ag36", [&"eu_grenadier", &"eu_lancer"]],
	&"tpla_squad": [&"tpla_camp", "tpla_carbine", "tpla_pkm", "tpla_rpg", "tpla_gp25", [&"tpla_militia", &"tpla_rocket_cell"]],
	&"ecc_squad": [&"ecc_barracks", "ecc_ak74", "ecc_pkm", "ecc_rpg7", "ecc_gp25", [&"ecc_rifleman", &"ecc_machine_gunner", &"ecc_rpg"]],
}

static func _squad_data(t: Node) -> void:
	for sid: StringName in SQUADS:
		var info: Array = SQUADS[sid]
		var ud := Content.unit(sid)
		var ms := Content.squad_members(sid)
		var rifle := 0
		var mg := 0
		var at := 0
		var gl := 0
		for m in ms:
			var ws: Array = []
			for x in m[1]:
				ws.append(String(x))
			if ws == [info[1]]: rifle += 1
			elif ws == [info[2]]: mg += 1
			elif ws == [info[3]]: at += 1
			elif ws.has(info[4]): gl += 1
		t._check(ms.size() == 6 and rifle == 3 and mg == 1 and at == 1 and gl == 1, "%s: 3 riflemen, MG, AT, grenadier (%d/%d/%d/%d)" % [sid, rifle, mg, at, gl])
		t._check(ud != null and ud.tags.has("squad") and ud.tags.has("infantry") and ud.pop == 3, "%s is a pop-3 infantry squad" % sid)
		var b := Content.building(info[0])
		t._check(b.produces.has(String(sid)), "%s trains the %s" % [info[0], sid])
		for old: StringName in info[5]:
			t._check(not b.produces.has(String(old)) and Content.unit(old) != null, "%s no longer trains %s (def kept for saves)" % [info[0], old])
		var c := Content.squad_carriers(ud)
		var full: PackedInt32Array = c[6]
		var one: PackedInt32Array = c[1]
		t._check(full.count(0) == 0, "%s: a full squad fires all its weapons" % sid)
		t._check(one[ud.weapons.find(StringName(info[1]))] == 1 and one.count(0) == ud.weapons.size() - 1, "%s: the last man standing is a rifleman" % sid)
	t._check(Content.unit(&"us_squad").weapons.has(&"us_m240b") and Content.unit(&"eu_squad").weapons.has(&"eu_mg3") and Content.unit(&"tpla_squad").weapons.has(&"tpla_pkm") and Content.unit(&"ecc_squad").weapons.has(&"ecc_pkm"), "machine guns: M240B / MG3 / PKM / PKM")
	t._check(Content.unit(&"us_sniper") != null and Content.building(&"us_barracks").produces.has("us_sniper") and Content.building(&"eu_barracks").produces.has("eu_sturmtrupp"), "special infantry stay single units")
	for bid in [&"us_barricade", &"eu_barricade", &"eu_sandbags", &"us_sandbags"]:
		if Content.building(bid) != null:
			t._check(Content.building(bid).garrison_capacity == 1, "%s holds one squad" % bid)

static func _squad_sim(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	var c := Vector2i(w.map.w / 2, w.map.h / 2)
	var at := FX.tile_center(c)
	var sq := w.spawn_unit(&"us_squad", 0, null, at)
	sq.pos = at
	var single := w.spawn_unit(&"us_grunt", 0, null, FX.tile_center(c + Vector2i(2, 0)))
	t._check(w.squad_alive(sq) == 6, "a full squad has six soldiers")
	sq.hp = sq.max_hp / 2
	t._check(w.squad_alive(sq) == 3, "half health: three soldiers (%d)" % w.squad_alive(sq))
	sq.hp = 1
	t._check(w.squad_alive(sq) == 1, "last hit point: one soldier")
	sq.hp = sq.max_hp
	var h0 := single.hp
	w.damage(sq, 30, null)
	w.damage(single, 30, null)
	t._check(sq.max_hp - sq.hp == 20 and h0 - single.hp == 30, "squads take a third less damage (+50 %% resistance): %d vs %d" % [sq.max_hp - sq.hp, h0 - single.hp])
	sq.hp = sq.max_hp
	# foxhole
	r.issue({"p": 0, "t": "dig", "ids": [sq.id, single.id]})
	M33._ticks(r, 2)
	t._check(w.digging(sq) and single.dig == 0, "Dig foxhole: squads start digging, single soldiers can't")
	M33._ticks(r, SimWorld.DIG_TICKS + 2)
	t._check(w.dug_in(sq), "the squad is dug in after %d ticks" % SimWorld.DIG_TICKS)
	w.damage(sq, 50, null)
	t._check(sq.max_hp - sq.hp == 50 * SimWorld.SQUAD_DMG_PCT / 100 * SimWorld.FOXHOLE_PCT / 100, "a foxhole cuts damage further (%d)" % (sq.max_hp - sq.hp))
	sq.hp = sq.max_hp
	# dug in: holds position, does not chase an enemy in sight but out of range
	var foe := w.spawn_unit(&"ecc_rifleman", 1, null, FX.tile_center(c + Vector2i(7, 0)))
	foe.pos = FX.tile_center(c + Vector2i(7, 0))
	foe.goal = Vector2i(-1, -1)
	var p0 := sq.pos
	M33._ticks(r, 60)
	t._check(sq.pos == p0 and w.dug_in(sq), "a dug-in squad holds its foxhole")
	w._kill(foe, null)
	r.issue({"p": 0, "t": "move", "ids": [sq.id], "pos": FX.tile_center(c + Vector2i(0, 4))})
	M33._ticks(r, 3)
	t._check(sq.dig == 0, "moving out leaves the foxhole")
	var h1 := sq.hp
	w.damage(sq, 30, null)
	t._check(h1 - sq.hp == 20, "out of the foxhole: squad resistance only")
	# barricade: one squad
	var bar := M33.place(w, 0, &"us_barricade", c + Vector2i(-6, -6))
	if bar == null:
		bar = M33.place(w, 0, &"eu_barricade", c + Vector2i(-6, -6))
	var sqs: Array = []
	for k in 2:
		var s2 := w.spawn_unit(&"us_squad", 0, null, FX.tile_center(c + Vector2i(-6 + k, -3)))
		s2.pos = FX.tile_center(c + Vector2i(-6 + k, -3))
		sqs.append(s2.id)
	r.issue({"p": 0, "t": "garrison", "ids": sqs, "target": bar.id})
	M33._ticks(r, 240)
	var inside := 0
	for id in sqs:
		if w.ents[id].res_id == -bar.id:
			inside += 1
	t._check(inside == 1, "one squad per barricade (%d inside)" % inside)
	# transports: a squad takes SQUAD_SEATS seats
	t._check(RosterSys.seats(w, sq) == RosterSys.SQUAD_SEATS and RosterSys.seats(w, single) == 1, "a squad takes %d transport seats" % RosterSys.SQUAD_SEATS)
	# civilian buildings count squads
	t._check(hq != null, "test world has an HQ")
	# save / load keeps the dig state
	sq.dig = w.tick + 5
	var w2 := SimWorld.new()
	w2.deserialize(w.serialize())
	t._check(w2.ents[sq.id].dig == sq.dig and w2.state_hash() == w.state_hash(), "dig state survives save / load")

static func _squad_view(t: Node) -> void:
	for sid: StringName in SQUADS:
		var v: InfantryView = (load(Content.unit(sid).view_scene) as PackedScene).instantiate()
		t.add_child(v)
		await _frames(t, 1)
		var models := {}
		for m in Content.squad_members(sid):
			models[m[0]] = true
		t._check(v._n == 6 and v.mmis.size() == models.size(), "%s view: six soldiers in %d model sets" % [sid, v.mmis.size()])
		var mg_wid := StringName(SQUADS[sid][2])
		var who: Array = v.shooters(mg_wid)
		t._check(who.size() == 1, "%s: only the machine gunner fires the MG" % sid)
		if who.size() == 1:
			var i: int = who[0]
			t._check(v.can_prone(i), "%s: the machine gunner can go prone" % sid)
			v.on_fire(mg_wid)
			for k in 12:
				v._process(0.1)
			t._check(v._state[i] == 7, "%s: the machine gunner lies prone while firing (state %d)" % [sid, v._state[i]])
			for k in 12:
				if v._fire_left[i] > 0.0:
					break
			for k in 50:
				v._process(0.1)
			t._check(v._state[i] != 7 and v._state[i] != 6, "%s: ...and gets up after the burst (state %d)" % [sid, v._state[i]])
		var at_wid := StringName(SQUADS[sid][3])
		for i: int in v.shooters(at_wid):
			var vat: VatModel = v._vats[i]
			t._check(v._clip_name(2, i).contains("kneel") or vat.fire_kneel == 2, "%s: the AT soldier kneels to fire" % sid)
		v.set_health(0.5)
		t._check(v._alive == 3, "%s: soldiers fall as the squad loses health (%d left)" % [sid, v._alive])
		v.set_dig(1.0)
		t._check(v.get_node_or_null("Foxhole") != null and v.get_node("Foxhole").visible, "%s: a dug-in squad shows its foxhole" % sid)
		v.queue_free()
	await _frames(t, 1)

# ------------------------------------------------------------------ 7/8 drone operators
static func _drones(t: Node) -> void:
	t._check(Content.operator_drone(&"us_drone_operator", "scout") == &"us_scout_drone" and Content.operator_drone(&"us_drone_operator", "bomb") == &"", "US Drone Operator: scout drones only")
	t._check(Content.operator_drone(&"ecc_drone_operator", "bomb") == &"ecc_bomb_drone" and Content.operator_drone(&"ecc_drone_operator", "scout") == &"", "Russian Drone Operator: explosive drones only")
	t._check(Content.building(&"ecc_barracks").produces.has("ecc_drone_operator"), "Russian barracks train the Drone Operator")
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := Vector2i(w.map.w / 2, w.map.h / 2)
	var us := w.spawn_unit(&"us_drone_operator", 0, null, FX.tile_center(c))
	var ru := w.spawn_unit(&"ecc_drone_operator", 1, null, FX.tile_center(c + Vector2i(4, 0)))
	for kind in ["bomb", "scout"]:
		r.issue({"p": 0, "t": "drone", "ids": [us.id], "kind": kind})
		r.issue({"p": 1, "t": "drone", "ids": [ru.id], "kind": kind})
	M33._ticks(r, 4)
	var got := {}
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and Content.unit(e.def_id).tags.has("drone"):
			got[e.air_home] = got.get(e.air_home, []) + [e.def_id]
	t._check(got.get(us.id, []) == [&"us_scout_drone"], "US operator launches only a scout drone (%s)" % str(got.get(us.id, [])))
	t._check(got.get(ru.id, []) == [&"ecc_bomb_drone"], "Russian operator launches only an explosive drone (%s)" % str(got.get(ru.id, [])))

# ------------------------------------------------------------------ 12 artillery elevation
static func _artillery(t: Node) -> void:
	var n := 0
	for uid: StringName in Content.units:
		var ud := Content.unit(uid)
		if not ud.tags.has("artillery") or ud.view_scene == "":
			continue
		var v = (load(ud.view_scene) as PackedScene).instantiate()
		t.add_child(v)
		await _frames(t, 1)
		if not v is VehicleView or v.barrel == null:
			t._check(false, "%s has a barrel / launcher to raise" % uid)
			v.queue_free()
			continue
		n += 1
		if v.elevate <= 0.0:
			v.elevate = WorldView.ARTY_ELEVATE
		v.set_process(false)
		var rx0: float = v.barrel.rotation.x
		v.aiming = true
		for k in 15:
			v._process(0.1)
		var up: float = rx0 - v.barrel.rotation.x
		v.aiming = false
		for k in 40:
			v._process(0.1)
		var back: float = absf(v.barrel.rotation.x - rx0)
		t._check(up > 0.3 and back < 0.01, "%s raises its gun before firing (%.2f rad) and lowers it after (%.3f)" % [uid, up, back])
		v.queue_free()
	t._check(n >= 6, "every artillery piece checked (%d)" % n)
	await _frames(t, 1)

# ------------------------------------------------------------------ 15/16/17 factions
static func _factions(t: Node) -> void:
	t._check(not Content.BUILDING_ORDER.has(&"eu_heavy_factory") and not Content.building(&"eu_heavy_factory").buildable, "Germany: the Heavy Factory is gone (def kept for saves)")
	var mp := Content.building(&"eu_motor_pool")
	t._check(mp.produces.has("eu_leopold") and mp.produces.has("eu_thunderhead") and mp.produces.has("eu_wolfhound"), "Germany: one vehicle factory builds every vehicle")
	t._check(Content.unit(&"eu_leopold").prereqs.has("eu_motor_pool") and not Content.unit(&"eu_leopold").prereqs.has("eu_heavy_factory"), "the Leopard needs only the Motor Pool")
	for uid in ["eu_spectre", "eu_sentinel"]:
		var held := false
		for bid in Content.buildings:
			if Content.building(bid).buildable and Content.building(bid).produces.has(uid):
				held = true
		t._check(not held and Content.unit(uid) != null, "non-lethal %s removed from production" % uid)
	# no unarmed vehicle left in any factory, except builders / harvesters / transports / drones
	for bid in Content.buildings:
		var b := Content.building(bid)
		if not b.buildable:
			continue
		for uid in b.produces:
			var ud := Content.unit(uid)
			if ud == null or not ud.tags.has("vehicle") or not ud.weapons.is_empty():
				continue
			var ok := ud.harvest_capacity > 0 or ud.transport_capacity > 0 or ud.tags.has("builder") or ud.role == "builder" or ud.tags.has("drone")
			t._check(ok, "%s: unarmed %s is a builder / harvester / transport" % [bid, uid])
	t._check(Content.building(&"ecc_power").footprint == Vector2i(4, 4) and Content.building(&"tpla_cc_plant").footprint == Vector2i(3, 3), "Russia / Iran power stations swapped (footprints)")
	t._check(TranslationServer.translate("BLD_ECC_POWER") == "Combined-Cycle Gas Plant" and TranslationServer.translate("BLD_TPLA_CC_PLANT") == "Gas Processing Plant", "power station names swapped")
	for pair in [["us", "us_vanguard"], ["eu", "eu_ironclad"], ["tpla", "tpla_scrapjack"], ["ecc", "ecc_steppe"]]:
		var ai: Resource = load("res://data/ai/%s.tres" % pair[1])
		var uw: Dictionary = ai.unit_weights
		t._check(uw.has(pair[0] + "_squad") and not uw.has("eu_spectre") and not uw.has("eu_sentinel"), "%s AI builds Combat Squads" % pair[0])

# ------------------------------------------------------------------ 13/14 paint + crude oil
static func _paint_oil(t: Node) -> void:
	for f in ["us", "eu", "tpla", "ecc"]:
		t._check(Palette.FACTION_PAINT.has(StringName(f)), "%s has a vehicle base paint" % f)
	var v: Node3D = (load(Content.unit(&"us_longreach").view_scene) as PackedScene).instantiate()
	t.add_child(v)
	Palette.apply_paint(v, &"us")
	var painted := 0
	for g in v.find_children("*", "GeometryInstance3D", true, false):
		var pc = (g as GeometryInstance3D).get_instance_shader_parameter(&"paint_color")
		if pc is Color and (pc as Color).a > 0.0:
			painted += 1
	t._check(painted > 0, "vehicles get their faction paint (%d parts)" % painted)
	t._check(TranslationServer.translate("RES_CACHE") == "Crude Oil Reserve", "supply stashes are Crude Oil Reserves")
	var cache: Node3D = (load("res://view/neutral/cache.tscn") as PackedScene).instantiate()
	t._check(cache.find_children("*", "MeshInstance3D", true, false).size() > 0, "the reserve has its tanks-and-barrels model")
	cache.free()
	var tr_v: Node3D = (load(Content.unit(&"us_supply_truck").view_scene) as PackedScene).instantiate()
	t.add_child(tr_v)
	await _frames(t, 1)
	var cap := Content.unit(&"us_supply_truck").harvest_capacity
	OilLoad.update(tr_v, 0, cap)
	t._check(tr_v.get_node_or_null("OilLoad") == null, "an empty truck carries no drums")
	OilLoad.update(tr_v, cap / 2, cap)
	var ol: MeshInstance3D = tr_v.get_node_or_null("OilLoad")
	t._check(ol != null and ol.visible and int(ol.get_meta("n")) == OilLoad.MAX / 2, "a half-loaded truck shows half its drums")
	OilLoad.update(tr_v, cap, cap)
	t._check(int(ol.get_meta("n")) == OilLoad.MAX, "a full truck shows all its drums")
	OilLoad.update(tr_v, 0, cap)
	t._check(not ol.visible, "drums gone after unloading for export")
	v.queue_free()
	tr_v.queue_free()
	await _frames(t, 1)
