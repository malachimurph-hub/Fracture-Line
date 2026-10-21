extends ScreenBase
## Generals-style skirmish lobby: 4 slots (player / open / closed / AI difficulty), faction,
## color, team 1-4, start position; map, starting money, fog, superweapons. Start is blocked
## with a clear message when the setup is invalid (e.g. everyone on one team).

const KIND_ITEMS := ["human", "open", "closed", "ai:easy", "ai:medium", "ai:hard"]
const FACTIONS := [["eu", "FACTION_EU", true], ["iron_pact", "FACTION_PACT", false], ["free_coalition", "FACTION_COALITION", false]]

var cfg: Dictionary
var err_lbl: Label
var start_btn: Button
var rows: VBoxContainer
var preview: Control

func build() -> void:
	cfg = GameSession.setup.duplicate(true) if not GameSession.setup.is_empty() and GameSession.setup.get("slots", []).size() == 4 else SkirmishConfig.default_setup()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := UiTheme.button("‹ " + tr("BACK"), Vector2(80, 44))
	back.pressed.connect(go_back)
	head.add_child(back)
	head.add_child(UiTheme.label("  " + tr("LOBBY_TITLE"), 22, UiTheme.GOLD))
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(main)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.clip_contents = true
	main.add_child(left)
	var hdr := HBoxContainer.new()
	for t in [["LOBBY_PLAYER", 144], ["LOBBY_FACTION", 134], ["LOBBY_COLOR", 114], ["LOBBY_TEAM", 68], ["LOBBY_START", 96]]:
		var l := UiTheme.label(tr(t[0]), 11, Color(0.7, 0.7, 0.7))
		l.custom_minimum_size = Vector2(t[1], 0)
		hdr.add_child(l)
	left.add_child(hdr)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	left.add_child(rows)
	_build_rows()
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(190, 0)
	right.add_theme_constant_override("separation", 6)
	main.add_child(right)
	right.add_child(UiTheme.label(tr("MAP_VARNO_CROSSING") + "  (4)", 13, UiTheme.CYAN))
	preview = Control.new()
	preview.custom_minimum_size = Vector2(110, 110)
	preview.draw.connect(_draw_preview)
	right.add_child(preview)
	var money := OptionButton.new()
	money.custom_minimum_size = Vector2(190, 44)
	for mv in SkirmishConfig.MONEY:
		money.add_item(tr("LOBBY_MONEY") % mv)
	money.selected = SkirmishConfig.MONEY.find(int(cfg["options"]["start_money"]))
	money.item_selected.connect(func(i): cfg["options"]["start_money"] = SkirmishConfig.MONEY[i])
	right.add_child(money)
	var fog := CheckButton.new()
	fog.text = tr("LOBBY_FOG")
	fog.button_pressed = bool(cfg["options"]["fog"])
	fog.custom_minimum_size = Vector2(190, 44)
	fog.toggled.connect(func(on): cfg["options"]["fog"] = on)
	right.add_child(fog)
	var sw := CheckButton.new()
	sw.text = tr("LOBBY_SUPERWEAPONS") + " [STUB]"
	sw.button_pressed = bool(cfg["options"]["superweapons"])
	sw.tooltip_text = tr("STUB_SUPERWEAPONS")
	sw.custom_minimum_size = Vector2(190, 44)
	sw.toggled.connect(func(on): cfg["options"]["superweapons"] = on)
	right.add_child(sw)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	err_lbl = UiTheme.label("", 13, Color("#ff8a7a"))
	err_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(err_lbl)
	start_btn = UiTheme.button(tr("LOBBY_START_GAME"), Vector2(180, 54))
	start_btn.add_theme_font_size_override("font_size", 17)
	start_btn.pressed.connect(_start)
	foot.add_child(start_btn)
	_validate()

func _build_rows() -> void:
	for c in rows.get_children():
		c.queue_free()
	for i in 4:
		var s: Dictionary = cfg["slots"][i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		rows.add_child(r)
		var kind := OptionButton.new()
		kind.custom_minimum_size = Vector2(140, 44)
		kind.fit_to_longest_item = false
		if i == 0:
			kind.add_item(tr("LOBBY_YOU"))
			kind.disabled = true
		else:
			for k in KIND_ITEMS.slice(1):
				kind.add_item(tr("LOBBY_KIND_" + k.replace(":", "_").to_upper()))
			var cur: String = s["kind"] if s["kind"] != "ai" else "ai:" + s["difficulty"]
			kind.selected = KIND_ITEMS.slice(1).find(cur)
			kind.item_selected.connect(func(idx):
				var k: String = KIND_ITEMS.slice(1)[idx]
				if k.begins_with("ai:"):
					s["kind"] = "ai"
					s["difficulty"] = k.substr(3)
				else:
					s["kind"] = k
				_refresh_row_state()
				_validate())
		r.add_child(kind)
		var fac := OptionButton.new()
		fac.custom_minimum_size = Vector2(130, 44)
		fac.fit_to_longest_item = false
		fac.clip_text = true
		for f in FACTIONS:
			fac.add_item(tr(f[1]) + ("" if f[2] else " — " + tr("LOBBY_COMING_LATER")))
			fac.set_item_disabled(fac.item_count - 1, not f[2])
		fac.selected = 0
		r.add_child(fac)
		var col := OptionButton.new()
		col.custom_minimum_size = Vector2(110, 44)
		col.fit_to_longest_item = false
		for ci in Palette.COLORS.size():
			col.add_icon_item(_swatch(Palette.COLORS[ci]), tr(Palette.COLOR_KEYS[ci]))
		col.selected = int(s["color"])
		col.item_selected.connect(func(idx): s["color"] = idx; _validate())
		r.add_child(col)
		var team := OptionButton.new()
		team.custom_minimum_size = Vector2(64, 44)
		team.fit_to_longest_item = false
		for t in 4:
			team.add_item(str(t + 1))
		team.selected = int(s["team"])
		team.item_selected.connect(func(idx): s["team"] = idx; _validate())
		r.add_child(team)
		var sp := OptionButton.new()
		sp.custom_minimum_size = Vector2(92, 44)
		sp.fit_to_longest_item = false
		sp.add_item(tr("LOBBY_RANDOM"))
		for t in 4:
			sp.add_item(str(t + 1))
		sp.selected = int(s["spawn"]) + 1
		sp.item_selected.connect(func(idx): s["spawn"] = idx - 1; _validate(); preview.queue_redraw())
		r.add_child(sp)
	_refresh_row_state.call_deferred()

func _refresh_row_state() -> void:
	for i in rows.get_child_count():
		var r := rows.get_child(i)
		var on: bool = cfg["slots"][i]["kind"] in ["human", "ai"]
		for j in range(1, r.get_child_count()):
			(r.get_child(j) as OptionButton).disabled = not on
			r.get_child(j).modulate = Color(1, 1, 1, 1.0 if on else 0.35)
	if preview:
		preview.queue_redraw()

func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _validate() -> bool:
	var e := SkirmishConfig.validate(cfg)
	err_lbl.text = tr(e) if e != "" else tr("LOBBY_READY") % SkirmishConfig.active(cfg).size()
	err_lbl.add_theme_color_override("font_color", Color("#ff8a7a") if e != "" else Color("#9dff9a"))
	start_btn.disabled = e != ""
	if preview:
		preview.queue_redraw()
	return e == ""

func _draw_preview() -> void:
	var md: MapDef = Content.maps[&"varno_crossing"]
	var s := preview.size
	preview.draw_rect(Rect2(Vector2.ZERO, s), Color("#3d5a2e"))
	preview.draw_rect(Rect2(Vector2(s.x * 0.47, 0), Vector2(s.x * 0.06, s.y)), Color("#2e5f86"))
	preview.draw_rect(Rect2(Vector2.ZERO, s), UiTheme.GOLD, false, 1)
	var f := preview.get_theme_default_font()
	for i in md.spawns.size():
		var p := Vector2(md.spawns[i]) / 128.0 * s
		var owner_color := Color(0.8, 0.8, 0.8, 0.6)
		for sl in cfg["slots"]:
			if int(sl["spawn"]) == i and sl["kind"] in ["human", "ai"]:
				owner_color = Palette.COLORS[int(sl["color"])]
		preview.draw_circle(p, 9, owner_color)
		preview.draw_string(f, p + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

func _start() -> void:
	if not _validate():
		return
	GameSession.setup = cfg.duplicate(true)
	GameSession.resume_save = {}
	SaveSystem.clear_suspend()
	get_tree().change_scene_to_file("res://match/match.tscn")

func go_back() -> void:
	GameSession.setup = cfg.duplicate(true)
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
