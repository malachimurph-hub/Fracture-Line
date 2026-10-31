extends ScreenBase
## Generals-style skirmish lobby: 4 slots (player: You / AI / Closed; a separate Difficulty
## column for AI slots, default Medium), faction,
## color, team 1-4, start position; map, starting money, fog, superweapons. Start is blocked
## with a clear message when the setup is invalid (e.g. everyone on one team).

const KIND_ITEMS := ["ai", "closed"]          ## slots 2-4 (slot 1 is always You)
const DIFFS := ["easy", "medium", "hard"]
## column widths (M2.1: 10% smaller UI, difficulty split out of the player column)
const COLS := {"player": 84, "diff": 92, "faction": 112, "color": 92, "team": 48, "start": 90}
## M3.5: Japan, Poland, China and the UK join the roster locked ("Coming soon", greyed, darkened
## flag); they cannot be picked by players, the AI or Random (Content.COMING_SOON).
const FACTIONS := [["eu", "FACTION_EU", true], ["tpla", "FACTION_TPLA", true], ["us", "FACTION_US", true], ["ecc", "FACTION_ECC", true],
	["jp", "FACTION_JP", false], ["pl", "FACTION_PL", false], ["cn", "FACTION_CN", false], ["uk", "FACTION_UK", false]]
const RIGHT_W := 172.0

var cfg: Dictionary
var err_lbl: Label
var start_btn: Button
var rows: VBoxContainer
var preview: Control

func build() -> void:
	var n_sl: int = GameSession.setup.get("slots", []).size()
	cfg = SkirmishConfig.normalize(GameSession.setup) if not GameSession.setup.is_empty() and (n_sl == 4 or n_sl == SkirmishConfig.SLOTS) else SkirmishConfig.default_setup()
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
	left.name = "SlotColumn"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.clip_contents = true
	main.add_child(left)
	var hdr := HBoxContainer.new()
	hdr.name = "SlotHeader"
	for t in [["LOBBY_PLAYER", COLS["player"] + 4], ["LOBBY_DIFFICULTY", COLS["diff"] + 4], ["LOBBY_FACTION", COLS["faction"] + 4], ["LOBBY_COLOR", COLS["color"] + 4], ["LOBBY_TEAM", COLS["team"] + 4], ["LOBBY_START", COLS["start"] + 4]]:
		var l := UiTheme.label(tr(t[0]), 11, Color(0.7, 0.7, 0.7))
		l.custom_minimum_size = Vector2(t[1], 0)
		hdr.add_child(l)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	# M3.3 P3 (21): 8 slots scroll inside the lobby (the phone shows about four at a time).
	# M3.5: the header scrolls with the rows and the table also scrolls sideways, so on a narrow
	# screen the slot table shrinks instead of pushing the map column (and its preview) off the
	# right edge.
	var rs := TouchScroll.new()
	rs.name = "SlotScroll"
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 4)
	table.add_child(hdr)
	table.add_child(rows)
	rs.add_child(table)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(rs)
	_build_rows()
	var right := VBoxContainer.new()
	right.name = "MapColumn"
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_theme_constant_override("separation", 4)
	main.add_child(right)
	# M2.5: map choice (every map is 4-player), with a biome preview below.
	# M3.5: a button that opens a scrolling map picker (the dropdown list was sticky to scroll)
	var mbtn := UiTheme.button("", Vector2(RIGHT_W, 44))
	mbtn.name = "MapButton"
	mbtn.clip_text = true
	mbtn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mbtn.pressed.connect(_open_map_picker)
	map_option = mbtn
	right.add_child(mbtn)
	_update_map_button()
	preview = Control.new()
	preview.name = "MapPreview"
	preview.custom_minimum_size = Vector2(RIGHT_W, 72)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.clip_contents = true
	preview.draw.connect(_draw_preview)
	right.add_child(preview)
	var money := OptionButton.new()
	money.custom_minimum_size = Vector2(RIGHT_W, 44)
	for mv in SkirmishConfig.MONEY:
		money.add_item(tr("LOBBY_MONEY") % mv)
	# M3.3: a lobby remembered from M3.2 may hold more than the $50k start limit
	cfg["options"]["start_money"] = SkirmishConfig.clamp_money(int(cfg["options"]["start_money"]))
	money.selected = SkirmishConfig.MONEY.find(int(cfg["options"]["start_money"]))
	money.item_selected.connect(func(i): cfg["options"]["start_money"] = SkirmishConfig.MONEY[i])
	right.add_child(money)
	var fog := CheckButton.new()
	fog.text = tr("LOBBY_FOG")
	fog.button_pressed = bool(cfg["options"]["fog"])
	fog.custom_minimum_size = Vector2(RIGHT_W, 44)
	fog.toggled.connect(func(on): cfg["options"]["fog"] = on)
	right.add_child(fog)
	var sw := CheckButton.new()
	sw.text = tr("LOBBY_SUPERWEAPONS") + " [STUB]"
	sw.button_pressed = bool(cfg["options"]["superweapons"])
	sw.tooltip_text = tr("STUB_SUPERWEAPONS")
	sw.custom_minimum_size = Vector2(RIGHT_W, 44)
	sw.toggled.connect(func(on): cfg["options"]["superweapons"] = on)
	sw.visible = false   # M2.9: the stub superweapon structures were removed; option kept for old saves
	right.add_child(sw)
	# M2.1: Start sits under the slot rows so the lobby fits 2340x1080 (384 dp tall)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	left.add_child(foot)
	err_lbl = UiTheme.label("", 13, Color("#ff8a7a"))
	err_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(err_lbl)
	start_btn = UiTheme.button(tr("LOBBY_START_GAME"), Vector2(170, 50))
	start_btn.add_theme_font_size_override("font_size", 17)
	start_btn.pressed.connect(_start)
	foot.add_child(start_btn)
	_validate()

func _build_rows() -> void:
	for c in rows.get_children():
		c.queue_free()
	for i in cfg["slots"].size():
		var s: Dictionary = cfg["slots"][i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		rows.add_child(r)
		if s["kind"] == "open":
			s["kind"] = "closed"   # skirmish only: no open (network) slots
		var kind := OptionButton.new()
		kind.name = "Kind"
		kind.custom_minimum_size = Vector2(COLS["player"], 44)
		kind.fit_to_longest_item = false
		if i == 0:
			kind.add_item(tr("LOBBY_YOU"))
			kind.disabled = true
		else:
			for k in KIND_ITEMS:
				kind.add_item(tr("LOBBY_KIND_" + k.to_upper()))
			kind.selected = KIND_ITEMS.find(s["kind"])
			kind.item_selected.connect(func(idx):
				s["kind"] = KIND_ITEMS[idx]
				if s["kind"] == "ai" and not String(s.get("difficulty", "")) in DIFFS:
					s["difficulty"] = "medium"
				_refresh_row_state()
				_validate())
		r.add_child(kind)
		var diff := OptionButton.new()
		diff.name = "Difficulty"
		diff.custom_minimum_size = Vector2(COLS["diff"], 44)
		diff.fit_to_longest_item = false
		for d in DIFFS:
			diff.add_item(tr("LOBBY_DIFF_" + d.to_upper()))
		if s["kind"] != "human" and not String(s.get("difficulty", "")) in DIFFS:
			s["difficulty"] = "medium"
		diff.selected = maxi(0, DIFFS.find(String(s.get("difficulty", "medium")))) if s["kind"] != "human" else 1
		diff.item_selected.connect(func(idx): s["difficulty"] = DIFFS[idx]; _validate())
		r.add_child(diff)
		var fac := OptionButton.new()
		fac.custom_minimum_size = Vector2(COLS["faction"], 44)
		fac.fit_to_longest_item = false
		fac.clip_text = true
		for f in FACTIONS:
			var on: bool = f[2] and Content.faction_enabled(f[0])   # M3.0: locked factions show "Coming soon", greyed out
			fac.add_icon_item(FactionEmblem.flag_texture(StringName(f[0]), 24, 16, not on), tr(f[1]) + ("" if on else " — " + tr("LOBBY_COMING_SOON")))   # M3.0 flag icon (darkened when locked)
			fac.set_item_disabled(fac.item_count - 1, not on)
		var fi := 0
		for k in FACTIONS.size():
			if FACTIONS[k][0] == String(s.get("faction", "eu")) and not fac.is_item_disabled(k):
				fi = k
		s["faction"] = FACTIONS[fi][0]
		fac.selected = fi
		fac.item_selected.connect(func(idx): s["faction"] = FACTIONS[idx][0]; _validate())
		r.add_child(fac)
		var col := OptionButton.new()
		col.custom_minimum_size = Vector2(COLS["color"], 44)
		col.fit_to_longest_item = false
		for ci in Palette.COLORS.size():
			col.add_icon_item(_swatch(Palette.COLORS[ci]), tr(Palette.COLOR_KEYS[ci]))
		col.selected = int(s["color"])
		col.item_selected.connect(func(idx): s["color"] = idx; _validate())
		r.add_child(col)
		var team := OptionButton.new()
		team.custom_minimum_size = Vector2(COLS["team"], 44)
		team.fit_to_longest_item = false
		for t in SkirmishConfig.SLOTS:
			team.add_item(str(t + 1))
		team.selected = int(s["team"])
		team.item_selected.connect(func(idx): s["team"] = idx; _validate())
		r.add_child(team)
		var sp := OptionButton.new()
		sp.custom_minimum_size = Vector2(COLS["start"], 44)
		sp.fit_to_longest_item = false
		sp.add_item(tr("LOBBY_RANDOM"))
		for t in SkirmishConfig.SLOTS:
			sp.add_item(str(t + 1))
		sp.selected = int(s["spawn"]) + 1
		sp.item_selected.connect(func(idx): s["spawn"] = idx - 1; _validate(); preview.queue_redraw())
		r.add_child(sp)
	_refresh_row_state.call_deferred()

func _refresh_row_state() -> void:
	for i in rows.get_child_count():
		var r := rows.get_child(i)
		var kind: String = cfg["slots"][i]["kind"]
		var on: bool = kind in ["human", "ai"]
		for j in range(1, r.get_child_count()):
			(r.get_child(j) as OptionButton).disabled = not on
			r.get_child(j).modulate = Color(1, 1, 1, 1.0 if on else 0.35)
		# difficulty only means something for AI slots: hidden (blank) for You and Closed
		var dd: OptionButton = r.get_node("Difficulty")
		dd.disabled = kind != "ai"
		dd.modulate = Color(1, 1, 1, 1.0 if kind == "ai" else 0.0)
	if preview:
		preview.queue_redraw()

func _swatch(c: Color) -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
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

var _preview_tex: ImageTexture = null
var map_option: Button
const BIOME_PREVIEW := {"s": Color("#c9a878"), "d": Color("#9c8160"), "g": Color("#a09656"), "G": Color("#5f7a3a"),
	"a": Color("#4f4c47"), "c": Color("#b0aa9e"), "r": Color("#857563"), "w": Color("#3f6f8f")}
## M2.5: natural ground colours per environment (asphalt / concrete / rock / water shared)
const ENV_PREVIEW := {&"winter": {"s": Color("#e9eef3"), "d": Color("#8c8378"), "g": Color("#c9d3d6"), "G": Color("#7d9080"), "w": Color("#a9c3d2"), "r": Color("#7c7f86")},
	&"temperate": {"s": Color("#8fa65a"), "d": Color("#7a6248"), "g": Color("#6f8f45"), "G": Color("#4f7034"), "c": Color("#9d9a92")},
	&"arid": {"s": Color("#cfa56a"), "d": Color("#a08654"), "g": Color("#a8966f"), "r": Color("#6e5a4c"), "w": Color("#8f7a5c")}}

## Map preview from the map's biome layer (what the terrain actually looks like).
func _biome_preview(md: MapDef) -> ImageTexture:
	var lines: PackedStringArray
	if md.custom:
		# M2.8: map-builder maps have no biome layer; colour from the tile grid
		lines = MapBuilderCanvas.biome_rows(md.tiles_text)
	else:
		var bp := md.tiles_path.replace(".txt", ".biome.txt")
		if not FileAccess.file_exists(bp):
			return null
		lines = FileAccess.get_file_as_string(bp).split("\n", false)
	if lines.is_empty():
		return null
	var w := lines[0].length()
	var img := Image.create_empty(w, lines.size(), false, Image.FORMAT_RGBA8)
	for y in lines.size():
		var ln: String = lines[y]
		for x in mini(w, ln.length()):
			var pal: Dictionary = ENV_PREVIEW.get(md.env, {})
			img.set_pixel(x, y, pal.get(ln[x], BIOME_PREVIEW.get(ln[x], Color("#b59a6c"))))
	return ImageTexture.create_from_image(img)

func _draw_preview() -> void:
	var md: MapDef = Content.maps.get(StringName(cfg.get("map", "varno_crossing")), Content.maps[&"varno_crossing"])
	if _preview_tex == null:
		_preview_tex = _biome_preview(md)
	var r := preview_rect(preview.size, Vector2(md.size))
	if _preview_tex != null:
		preview.draw_texture_rect(_preview_tex, r, false)
	else:
		preview.draw_rect(r, Color("#b59a6c"))
	preview.draw_rect(r, UiTheme.GOLD, false, 1)
	var f := preview.get_theme_default_font()
	var dot := clampf(r.size.x / 14.0, 6.0, 9.0)
	for i in md.spawns.size():
		var p := r.position + (Vector2(md.spawns[i]) + Vector2(2, 2)) / Vector2(md.size) * r.size
		var owner_color := Color(0.8, 0.8, 0.8, 0.6)
		for sl in cfg["slots"]:
			if int(sl["spawn"]) == i and sl["kind"] in ["human", "ai"]:
				owner_color = Palette.COLORS[int(sl["color"])]
		preview.draw_circle(p, dot, owner_color)
		preview.draw_string(f, p + Vector2(-dot * 0.45, dot * 0.55), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(dot * 1.3), Color.BLACK)

## M3.5: the largest rect of the map's aspect that fits the preview box, centred (the preview was
## stretched to the column and could run past the right edge on narrow screens).
static func preview_rect(box: Vector2, map_size: Vector2) -> Rect2:
	if box.x <= 0.0 or box.y <= 0.0 or map_size.x <= 0.0 or map_size.y <= 0.0:
		return Rect2(Vector2.ZERO, box)
	var k := minf(box.x / map_size.x, box.y / map_size.y)
	var sz := map_size * k
	return Rect2((box - sz) * 0.5, sz)

func _map_label(mid: StringName) -> String:
	var mdef: MapDef = Content.maps[mid]
	return ("%s  (%d)" % [tr(mdef.name_key), mdef.spawns.size()]) + (tr("LOBBY_CUSTOM_TAG") if mdef.custom else "")

func _update_map_button() -> void:
	var ids := SkirmishConfig.map_ids()
	var mid := StringName(cfg.get("map", "varno_crossing"))
	if not ids.has(mid) and not ids.is_empty():
		mid = ids[0]
		cfg["map"] = String(mid)
	if map_option != null:
		map_option.text = _map_label(mid) + "  ▾"

func select_map(mid: StringName) -> void:
	cfg["map"] = String(mid)
	_preview_tex = null
	_update_map_button()
	preview.queue_redraw()
	_close_map_picker()

## M3.5 map picker: a full-screen panel with a smooth-scrolling grid of map cards (biome
## thumbnail + name); tap a card to pick it, Back to keep the current map.
var picker: Control
static var _thumbs: Dictionary = {}
func _open_map_picker() -> void:
	if picker != null:
		return
	picker = PanelContainer.new()
	picker.name = "MapPicker"
	picker.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.055, 0.065, 0.97), UiTheme.GOLD, 1, 4, 10))
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sr := UiScale.safe_rect if UiScale.safe_rect.size.x > 0.0 else Rect2(Vector2.ZERO, UiScale.logical_size())
	picker.position = sr.position + Vector2(8, 6)
	picker.size = sr.size - Vector2(16, 12)
	picker.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	add_child(picker)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	picker.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := UiTheme.button("‹ " + tr("BACK"), Vector2(80, 44))
	back.name = "PickerBack"
	back.pressed.connect(_close_map_picker)
	head.add_child(back)
	head.add_child(UiTheme.label("  " + tr("LOBBY_MAP"), 18, UiTheme.GOLD))
	var sc := TouchScroll.new()
	sc.name = "MapScroll"
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var grid := GridContainer.new()
	grid.name = "MapGrid"
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_w := 150.0
	grid.columns = maxi(1, int((picker.size.x - 24.0) / (card_w + 8.0)))
	sc.add_child(grid)
	var cur := StringName(cfg.get("map", "varno_crossing"))
	for mid in SkirmishConfig.map_ids():
		var md: MapDef = Content.maps[mid]
		var b := UiTheme.button(_map_label(mid), Vector2(card_w, 124))
		b.name = "Map_" + String(mid)
		b.icon = _thumb(md)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 11)
		if mid == cur:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.GUNMETAL_LIGHT, UiTheme.GOLD, 2))
		b.pressed.connect(select_map.bind(mid))
		grid.add_child(b)

func _close_map_picker() -> void:
	if picker != null:
		picker.queue_free()
		picker = null

func _thumb(md: MapDef) -> Texture2D:
	var key := String(md.id) + ("#" + str(md.tiles_text.hash()) if md.custom else "")
	if not _thumbs.has(key):
		_thumbs[key] = _biome_preview(md)
	return _thumbs[key]

func _start() -> void:
	if GameSession.busy or not _validate():
		return
	start_btn.disabled = true   # M3.0.1: one tap starts one battle
	GameSession.setup = cfg.duplicate(true)
	GameSession.resume_save = {}
	SaveSystem.clear_suspend()
	GameSession.goto_with_loading("res://match/match.tscn", tr("LOADING_BATTLE"))

func go_back() -> void:
	if picker != null:
		_close_map_picker()
		return
	GameSession.setup = cfg.duplicate(true)
	GameSession.goto("res://ui/main_menu.tscn")
