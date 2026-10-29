class_name HudTextCheck
extends RefCounted
## UI test helper (M2): walks the HUD and returns every button whose text overflows or would
## be clipped. HudButtons use their own fit result (full name, <= 2 lines, >= 9 dp font,
## price/count on its own line); plain Buttons are measured against their content box. Also
## checks the 44 dp minimum tap target (M2.1: 10% smaller HUD) on the command card, filters, queue chips, top bar.

static func problems(hud) -> Array:
	var out: Array = []
	_walk(hud.root, out)
	# nothing may hang off the selection panel or the screen (that would clip the label)
	var panel: Rect2 = hud.sel_panel.get_global_rect().grow(0.5)
	var screen: Rect2 = hud.root.get_global_rect().grow(0.5)
	for box in [hud.sel_types, hud.queue_box]:
		for c in box.get_children():
			if c is Control and (c as Control).is_visible_in_tree() and not panel.encloses((c as Control).get_global_rect()):
				out.append("'%s' sticks out of the selection panel" % (c.label_text if c is HudButton else c.get("text")))
	_on_screen(hud.root, screen, out)
	if not hud.portrait_fit_ok:
		out.append("selection portrait name does not fit")
	return out

static func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is HudButton:
			var b: HudButton = c
			if b.label_text != "" or b.sub != "":
				if not b.text_fits():
					out.append("'%s' / '%s' does not fit in %s (font %d)" % [b.label_text.replace("\n", " "), b.sub, b.size, b.fit_size])
				if b.fit_size < HudButton.MIN_FONT and b.label_text != "":
					out.append("'%s' font below minimum" % b.label_text)
				var hs: Vector2 = b.size + Vector2.ONE * b.hit_pad * 2.0   # M2.6: invisible tap padding counts
				if minf(hs.x, hs.y) < 43.5:
					out.append("'%s' tap target %s < 44 dp" % [b.label_text.replace("\n", " "), hs])
		elif c is Button:
			var pb: Button = c
			if minf(pb.size.x, pb.size.y) < 39.5:
				out.append("button '%s' tap target %s too small" % [pb.text, pb.size])
			if pb.text != "":
				var f := pb.get_theme_font("font")
				var fs := pb.get_theme_font_size("font_size")
				var sb := pb.get_theme_stylebox("normal")
				var avail := pb.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
				var w := 0.0
				for line in pb.text.split("\n"):
					w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if w > avail + 0.5:
					out.append("button '%s' text %.0f > %.0f" % [pb.text.replace("\n", " "), w, avail])
		_walk(c, out)

static func _on_screen(n: Node, screen: Rect2, out: Array) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is BaseButton and not screen.encloses((c as Control).get_global_rect()):
			out.append("button '%s' is partly off screen %s" % [(c.label_text if c is HudButton else c.get("text")), (c as Control).get_global_rect()])
		_on_screen(c, screen, out)

## Exercises every bottom-panel state for a faction: builder build menu, each producer's card
## with a full queue, multi-selection type filters, special buildings.
static func exercise(m, fac: StringName, tree: SceneTree, check: Callable) -> void:
	var sim: SimWorld = m.runner.sim
	var pid: int = m.local_pid
	var fd: Dictionary = Content.faction(fac)
	sim.players[pid].supply += 30000
	var builder := _sel(m, fd["builder"])
	await _chk(m, tree, check, "%s builder menu" % fac)
	await _pages(m, tree, check, "%s builder menu" % fac)
	# every building's card (spawn missing ones next to the HQ so the card can be inspected)
	var hq := _find(m, pid, fd["hq"])
	var k := 0
	for bid in fd["buildings"]:
		var b := _find(m, pid, bid)
		if b == null and hq != null:
			var bd: BuildingDef = Content.building(bid)
			var spot := Vector2i(-1, -1)
			for r in range(4, 30):
				for dx in range(-r, r + 1, 2):
					var t := FX.to_tile(hq.pos) + Vector2i(dx, r if (k % 2 == 0) else -r)
					var why := sim.can_place(pid, bid, t, false)
					if why == "" or why == "REASON_SHROUD":
						spot = t
						break
				if spot.x >= 0:
					break
			if spot.x >= 0:
				b = sim._place_building(bd, pid, spot, 0, true)
				m.world.on_tick([{"t": "spawn", "id": b.id}])
			k += 1
		if b == null:
			continue
		m.ctl.set_selection([b.id])
		var bdef: BuildingDef = Content.building(bid)
		for uid in bdef.produces:
			m.ctl.queue_unit(b, StringName(uid), 2)
		m.runner.advance()
		await _chk(m, tree, check, "%s %s card" % [fac, bid])
		await _pages(m, tree, check, "%s %s card" % [fac, bid])
	# multi-selection: one of every unit type
	var ids: Array = []
	var at := FX.to_tile(hq.pos) + Vector2i(6, 6) if hq != null else Vector2i(20, 20)
	for uid in fd["units"]:
		var u := sim.spawn_unit(StringName(uid), pid, null, FX.tile_center(at + Vector2i(ids.size() % 4, ids.size() / 4)))
		m.world.on_tick([{"t": "spawn", "id": u.id}])
		ids.append(u.id)
		var u2 := sim.spawn_unit(StringName(uid), pid, null, FX.tile_center(at + Vector2i(ids.size() % 4, ids.size() / 4)))
		m.world.on_tick([{"t": "spawn", "id": u2.id}])
		ids.append(u2.id)
	m.ctl.set_selection(ids)
	await _chk(m, tree, check, "%s multi-selection filters" % fac)
	for uid in fd["units"]:
		var one := _find(m, pid, StringName(uid))
		if one != null:
			m.ctl.set_selection([one.id])
			for _f in 2:
				await tree.process_frame
			check.call("portrait name fits: %s" % uid, m.hud.portrait_fit_ok)
	if builder != null:
		m.ctl.set_selection([builder.id])

## M2.4: paged command cards: every page must fit too, and every produced unit / structure
## must be reachable on some page.
static func _pages(m, tree: SceneTree, check: Callable, label: String) -> void:
	var more := -1
	for i in m.hud.card.size():
		if m.hud.card[i].get("text", "") == m.hud.tr("CMD_MORE"):
			more = i
	if more < 0:
		return
	var pages := int(String(m.hud.card[more].get("sub", "1/1")).get_slice("/", 1))
	for pg in range(1, pages):
		m.hud.card_page = pg
		m.hud._refresh_card()
		await _chk(m, tree, check, "%s page %d" % [label, pg + 1])
	m.hud.card_page = 0
	m.hud._refresh_card()

static func _chk(m, tree: SceneTree, check: Callable, label: String) -> void:
	for _f in 4:
		await tree.process_frame
	var probs: Array = problems(m.hud)
	check.call("HUD text fits (%s)" % label, probs.is_empty(), probs.slice(0, 6) if not probs.is_empty() else null)
	_icons(m, check, label)
	await _info_cards(m, tree, check, label)

## M3.3 Phase 4: every unit / structure entry on the command card, every queued item and every
## selection type chip shows its icon.
static func _icons(m, check: Callable, label: String) -> void:
	var probs: Array = []
	for i in mini(m.hud.card.size(), m.hud.grid_buttons.size()):
		var inf: Variant = m.hud.card[i].get("info")
		if inf is Array and String(inf[0]) in ["unit", "building"] and (m.hud.grid_buttons[i] as HudButton).icon_tex == null:
			probs.append("card %s has no icon" % inf[1])
	for box in [m.hud.sel_types, m.hud.queue_box]:
		for c in box.get_children():
			if c is HudButton and (c as HudButton).is_visible_in_tree() and (c as HudButton).label_text != "" \
					and not (c as HudButton).label_text.begins_with("+") and (c as HudButton).icon_tex == null:
				probs.append("chip '%s' has no icon" % (c as HudButton).label_text.replace("\n", " "))
	for q in m.hud.queue_slots:
		if (q as HudButton).label_text != "" and (q as HudButton).icon_tex == null:
			probs.append("queue slot '%s' has no icon" % (q as HudButton).label_text)
	check.call("icons shown (%s)" % label, probs.is_empty(), probs.slice(0, 6) if not probs.is_empty() else null)

## M3.2: every build / train / research entry has a press-and-hold info card that is fully
## translated, data-driven and fits on screen next to its button.
static func _info_cards(m, tree: SceneTree, check: Callable, label: String) -> void:
	var probs: Array = []
	var n := 0
	var screen: Rect2 = m.hud.root.get_global_rect().grow(0.5)
	for i in mini(m.hud.card.size(), m.hud.grid_buttons.size()):
		var c: Dictionary = m.hud.card[i]
		if not c.has("info"):
			continue
		var inf: Array = c["info"]
		var d: Dictionary = InfoCard.build(inf[0], StringName(inf[1]), m.runner.sim, m.local_pid)
		if d.is_empty() or String(d.get("title", "")) == "":
			probs.append("%s %s: empty card" % inf)
			continue
		for line in d["lines"]:
			if "INFO_" in line or "_DESC" in line or _has_fmt(line):
				probs.append("%s: untranslated '%s'" % [inf[1], line])
		var dd: Variant = Content.building(StringName(inf[1])) if inf[0] == "building" else null
		if dd != null:
			var body := "\n".join(d["lines"])
			if (dd.passive_income > 0 or dd.income_amount > 0) and not ("/ min" in body):
				probs.append("%s: income per minute missing" % inf[1])
			if dd.power > 0 and not ("+%d" % dd.power in body):
				probs.append("%s: power produced missing" % inf[1])
			if not dd.weapons.is_empty() and not ("range" in body):
				probs.append("%s: turret damage / range missing" % inf[1])
		m.hud.show_info(d, (m.hud.grid_buttons[i] as Control).get_global_rect())
		await tree.process_frame
		var r: Rect2 = m.hud.info_panel.get_global_rect()
		if not screen.encloses(r):
			probs.append("%s info card off screen %s" % [inf[1], r])
		n += 1
	m.hud.hide_info()
	check.call("info cards OK (%s, %d cards)" % [label, n], probs.is_empty(), probs.slice(0, 6) if not probs.is_empty() else null)

## M3.2: press-and-hold on a (locked or ready) grid button shows the card and the release does
## not build; a quick tap still fires.
static func hold_gesture(check: Callable, tree: SceneTree, parent: Node) -> void:
	var b := HudButton.new()
	parent.add_child(b)
	b.size = Vector2(80, 60)
	b.has_info = true
	var got := {"info": 0, "primary": 0}
	b.hold_info.connect(func(on): if on: got["info"] += 1)
	b.primary.connect(func(): got["primary"] += 1)
	var old := WorldInput.test_clock_ms
	WorldInput.test_clock_ms = 1000
	for dis in [true, false]:
		b.disabled = dis
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		if dis:
			b._gui_input(ev)
		else:
			b._down_ms = HudButton._now()
			b._fired = false
			b.toggle_mode = true
			b.button_pressed = true
		WorldInput.test_clock_ms += 450
		b._process(0.0)
		if dis:
			ev.pressed = false
			b._gui_input(ev)
		else:
			b._on_pressed()
	WorldInput.test_clock_ms = old
	check.call("press-and-hold shows the info card (locked + ready) and the release does not build", got["info"] == 2 and got["primary"] == 0, got)
	b.queue_free()

static func _find(m, pid: int, def_id: StringName) -> SimEntity:
	for id in m.runner.sim.ids:
		var e: SimEntity = m.runner.sim.ents[id]
		if e.owner == pid and e.def_id == def_id:
			return e
	return null

static func _sel(m, def_id: StringName) -> SimEntity:
	var e := _find(m, m.local_pid, def_id)
	if e != null:
		m.ctl.set_selection([e.id])
	return e

## M2.1: the skirmish lobby at the phone size. Every visible button / dropdown (Player,
## Difficulty, Faction, Color, Team, Start) must keep its full text (dropdown arrow
## excluded), be at least 40 dp tall/wide, and lie fully on screen.
static func lobby_problems(root: Control) -> Array:
	var out: Array = []
	var screen := root.get_viewport_rect().grow(0.5)
	for c in root.find_children("*", "BaseButton", true, false):
		var b := c as Control
		if b == null or not b.is_visible_in_tree():
			continue
		if _scrolled_out(b):
			continue   # M3.3: 8-slot lobby - rows below the fold are reached by scrolling
		if not screen.encloses(b.get_global_rect()):
			out.append("'%s' partly off screen %s" % [b.get("text"), b.get_global_rect()])
		if b is Button:
			var pb: Button = b
			if minf(pb.size.x, pb.size.y) < 39.5:
				out.append("'%s' tap target %s too small" % [pb.text, pb.size])
			if pb.text == "":
				continue
			var f := pb.get_theme_font("font")
			var fs := pb.get_theme_font_size("font_size")
			var sb := pb.get_theme_stylebox("normal")
			var avail := pb.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
			if pb is OptionButton:
				var arrow := pb.get_theme_icon("arrow")
				avail -= (arrow.get_width() if arrow != null else 0) + pb.get_theme_constant("arrow_margin") + pb.get_theme_constant("h_separation")
			var w := f.get_string_size(pb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if w > avail + 0.5:
				out.append("'%s' text %.0f > %.0f" % [pb.text, w, avail])
	return out


## a leftover format placeholder such as %s, %d, %.1f or %+d (no RegEx: the stripped release
## engine is built without the regex module)
static func _has_fmt(line: String) -> bool:
	var i := line.find("%")
	while i >= 0:
		var j := i + 1
		while j < line.length() and "-+0123456789.".contains(line[j]):
			j += 1
		if j < line.length() and "sdfv".contains(line[j]):
			return true
		i = line.find("%", i + 1)
	return false

## inside a ScrollContainer and not fully within its visible area (reached by scrolling)
static func _scrolled_out(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return not (p as Control).get_global_rect().grow(0.5).encloses(c.get_global_rect())
		p = p.get_parent()
	return false
