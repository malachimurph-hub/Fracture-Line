extends ScreenBase
## M2.8 Map Builder screen: top bar (back, undo/redo, fit, check, save, maps), the map canvas
## and a side panel with Terrain tools, the categorised Assets list and the selection box.
## Saved maps go to user://maps (MapStore) and show up in the Skirmish lobby marked custom.

var canvas: MapBuilderCanvas
var title_lbl: Label
var undo_btn: Button
var redo_btn: Button
var panel_box: VBoxContainer
var terrain_page: Control
var assets_page: Control
var asset_scroll: ScrollContainer
var sel_box: VBoxContainer
var sel_lbl: Label
var sel_amount: HBoxContainer
var sel_amount_lbl: Label
var sel_owner: Button
var toast: Label
var overlay: Control = null
var _tabs: Dictionary = {}
var _back_armed := false
var _tool_group := ButtonGroup.new()
var _tile_group := ButtonGroup.new()
var _brush_group := ButtonGroup.new()
var _asset_group := ButtonGroup.new()
var _owner_btn: Button
var last_messages := PackedStringArray()

const ENV_NAMES := {&"desert": "Desert", &"winter": "Winter", &"arid": "Arid", &"temperate": "Temperate"}

func build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	body.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)
	_top_btn(top, "‹ " + tr("BACK"), go_back, 70)
	title_lbl = UiTheme.label("", 13, UiTheme.GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title_lbl)
	undo_btn = _top_btn(top, "↶ Undo", func(): canvas.undo(), 66)
	redo_btn = _top_btn(top, "↷ Redo", func(): canvas.redo(), 66)
	_top_btn(top, "Fit", func(): canvas.fit(), 48)
	_top_btn(top, "Check", func(): check_map(), 62)
	var sv := _top_btn(top, "Save", func(): save_map(), 62)
	sv.add_theme_color_override("font_color", UiTheme.GOLD)
	_top_btn(top, "Maps…", func(): show_maps(), 66)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	canvas = MapBuilderCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.doc_changed.connect(_refresh_top)
	canvas.selection_changed.connect(_refresh_sel)
	row.add_child(canvas)
	toast = UiTheme.label("", 13, Color("#9dff9a"))
	toast.position = Vector2(8, 6)
	toast.add_theme_constant_override("outline_size", 4)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	canvas.add_child(toast)
	_build_panel(row)
	var d := MapStore.blank("New map", MapStore.SIZES[MapStore.DEFAULT_SIZE], &"desert")
	canvas.load_doc.call_deferred(d)
	show_new_dialog.call_deferred(true)

func _top_btn(p: Control, text: String, cb: Callable, wmin: float) -> Button:
	var b := UiTheme.button(text, Vector2(wmin, 44))
	b.pressed.connect(cb)
	p.add_child(b)
	return b

# ------------------------------------------------------------------ side panel
func _build_panel(row: Control) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(236, 0)
	row.add_child(pc)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 4)
	pc.add_child(panel_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	panel_box.add_child(tabs)
	var tg := ButtonGroup.new()
	for t in [["terrain", "Terrain"], ["assets", "Assets"], ["select", "Select"]]:
		var b := UiTheme.button(t[1], Vector2(74, 44))
		b.toggle_mode = true
		b.button_group = tg
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t[0]))
		tabs.add_child(b)
		_tabs[t[0]] = b
	terrain_page = _build_terrain()
	panel_box.add_child(terrain_page)
	assets_page = _build_assets()
	panel_box.add_child(assets_page)
	sel_box = VBoxContainer.new()
	sel_box.add_theme_constant_override("separation", 3)
	panel_box.add_child(sel_box)
	sel_lbl = UiTheme.label("", 12, UiTheme.CYAN)
	sel_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_box.add_child(sel_lbl)
	sel_amount = HBoxContainer.new()
	sel_box.add_child(sel_amount)
	var minus := UiTheme.button("−", Vector2(48, 44))
	minus.pressed.connect(func(): _bump_amount(-1))
	sel_amount.add_child(minus)
	sel_amount_lbl = UiTheme.label("", 13)
	sel_amount_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel_amount.add_child(sel_amount_lbl)
	var plus := UiTheme.button("+", Vector2(48, 44))
	plus.pressed.connect(func(): _bump_amount(1))
	sel_amount.add_child(plus)
	var srow := HBoxContainer.new()
	sel_box.add_child(srow)
	sel_owner = UiTheme.button("Owner: Start 1", Vector2(120, 44))
	sel_owner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_owner.pressed.connect(func():
		if canvas.selected >= 0:
			canvas.set_selected_slot((int(canvas.items[canvas.selected]["slot"]) + 1) % 4))
	srow.add_child(sel_owner)
	var del := UiTheme.button("Delete", Vector2(80, 44))
	del.add_theme_color_override("font_color", Color("#ff8a7a"))
	del.pressed.connect(func(): canvas.delete_selected())
	srow.add_child(del)
	show_tab("terrain")
	_refresh_sel()

func show_tab(t: String) -> void:
	_tabs[t].button_pressed = true
	terrain_page.visible = t == "terrain"
	assets_page.visible = t == "assets"
	if t == "select":
		canvas.tool = "select"
		terrain_page.visible = false
		assets_page.visible = false
		_toast("Tap an item to select it, drag to move it. Two fingers pan / zoom.")
	elif t == "terrain" and not canvas.tool in ["paint", "fill", "erase"]:
		canvas.tool = "paint"
		_sync_tool_buttons()
	elif t == "assets" and canvas.place.is_empty():
		canvas.tool = "select"
	elif t == "assets":
		canvas.tool = "place"

func _section(p: Control, text: String) -> void:
	var l := UiTheme.label(text, 12, UiTheme.GOLD)
	p.add_child(l)

func _grid(p: Control, cols: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	p.add_child(g)
	return g

func _tbtn(p: Control, text: String, group: ButtonGroup, cb: Callable, wmin := 70.0) -> Button:
	var b := UiTheme.button(text, Vector2(wmin, 44))
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.pressed.connect(cb)
	p.add_child(b)
	return b

var _tool_btns := {}
func _build_terrain() -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	sc.add_child(v)
	_section(v, "Tool")
	var g := _grid(v, 3)
	for t in [["paint", "Paint"], ["fill", "Fill"], ["erase", "Erase"]]:
		_tool_btns[t[0]] = _tbtn(g, t[1], _tool_group, func(): canvas.tool = t[0], 60)
	_section(v, "Brush size")
	var bg := _grid(v, 5)
	for b in MapBuilderCanvas.BRUSHES:
		var bb := _tbtn(bg, str(b), _brush_group, func(): canvas.brush = b, 38)
		if b == 3:
			bb.button_pressed = true
	_section(v, "Terrain type")
	var tg := _grid(v, 2)
	for i in MapBuilderCanvas.TILE_NAMES.size():
		var tb := _tbtn(tg, MapBuilderCanvas.TILE_NAMES[i], _tile_group, func():
			canvas.paint_t = i
			if canvas.tool == "erase":
				canvas.tool = "paint"
				_sync_tool_buttons(), 100)
		tb.icon = _swatch_tex(i)
		tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == 0:
			tb.button_pressed = true
	_tool_btns["paint"].button_pressed = true
	return sc

func _sync_tool_buttons() -> void:
	if _tool_btns.has(canvas.tool):
		_tool_btns[canvas.tool].button_pressed = true

func _swatch_tex(t: int) -> ImageTexture:
	var img := Image.create_empty(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(canvas.tile_color(t) if canvas != null else Color.GRAY)
	return ImageTexture.create_from_image(img)

## The asset list: every placeable map asset, by category.
func asset_categories() -> Array:
	var cats: Array = []
	cats.append(["Start positions", [{"t": "spawn", "slot": 0, "label": "Start 1"}, {"t": "spawn", "slot": 1, "label": "Start 2"},
		{"t": "spawn", "slot": 2, "label": "Start 3"}, {"t": "spawn", "slot": 3, "label": "Start 4"}]])
	cats.append(["Supplies", [{"t": "res", "kind": "seam", "label": "Supply seam"}, {"t": "res", "kind": "cache", "label": "Supply cache"}]])
	var neu: Array = []
	var nids: Array = Content.buildings.keys()
	nids.sort()
	for id in nids:
		if Content.faction_of_id(id) == &"neutral":
			neu.append({"t": "neutral", "kind": String(id), "label": MapStore._name(id)})
	cats.append(["Neutral structures", neu])
	for f in [[&"us", "US"], [&"eu", "EU"], [&"tpla", "TPLA"]]:
		var fd: Dictionary = Content.faction(f[0])
		var us: Array = []
		for id in fd["units"]:
			us.append({"t": "pre", "kind": String(id), "label": MapStore._name(id)})
		cats.append([f[1] + " units", us])
		var bs: Array = []
		for id in fd["buildings"]:
			bs.append({"t": "pre", "kind": String(id), "label": MapStore._name(id)})
		cats.append([f[1] + " buildings", bs])
	return cats

func _build_assets() -> Control:
	var v0 := VBoxContainer.new()
	v0.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var orow := HBoxContainer.new()
	v0.add_child(orow)
	_owner_btn = UiTheme.button("Units/buildings for: Start 1", Vector2(200, 40))
	_owner_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_owner_btn.pressed.connect(func():
		canvas.owner_slot = (canvas.owner_slot + 1) % 4
		_owner_btn.text = "Units/buildings for: Start %d" % (canvas.owner_slot + 1))
	orow.add_child(_owner_btn)
	asset_scroll = ScrollContainer.new()
	asset_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v0.add_child(asset_scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	asset_scroll.add_child(v)
	for cat in asset_categories():
		_section(v, "%s (%d)" % [cat[0], cat[1].size()])
		var g := _grid(v, 2)
		for a in cat[1]:
			var what: Dictionary = a
			var b := _tbtn(g, what["label"], _asset_group, func():
				canvas.place = what
				canvas.tool = "place"
				_toast("Tap the map to place: " + what["label"]), 100)
			b.tooltip_text = what["label"]
			if what["t"] == "pre":
				b.add_theme_color_override("font_color", MapBuilderCanvas.FAC_COL.get(Content.faction_of_id(what["kind"]), Color.WHITE))
	return v0

func _bump_amount(dir: int) -> void:
	if canvas.selected < 0:
		return
	var it: Dictionary = canvas.items[canvas.selected]
	var step := 5000 if it["kind"] == "seam" else 1000
	canvas.set_selected_amount(int(it["amount"]) + dir * step)

func _refresh_sel() -> void:
	if sel_box == null:
		return
	var i := canvas.selected
	sel_box.visible = i >= 0
	if i < 0:
		return
	var it: Dictionary = canvas.items[i]
	sel_lbl.text = "Selected: %s at %d,%d" % [canvas.item_label(it), it["tile"].x, it["tile"].y]
	sel_amount.visible = it["t"] == "res"
	if it["t"] == "res":
		sel_amount_lbl.text = "Amount %d" % int(it["amount"])
	sel_owner.visible = it["t"] == "pre"
	if it["t"] == "pre":
		sel_owner.text = "Owner: Start %d" % (int(it["slot"]) + 1)

func _refresh_top() -> void:
	title_lbl.text = "  %s%s · %d×%d · %s" % [canvas.map_name, " *" if canvas.dirty else "", canvas.w, canvas.h, ENV_NAMES.get(canvas.env, String(canvas.env))]
	undo_btn.disabled = not canvas.can_undo()
	redo_btn.disabled = not canvas.can_redo()
	_back_armed = false

var _toast_t := 0
func _toast(s: String, col := Color("#9dff9a")) -> void:
	toast.text = s
	toast.add_theme_color_override("font_color", col)
	_toast_t += 1
	var my := _toast_t
	get_tree().create_timer(4.0).timeout.connect(func(): if my == _toast_t and is_instance_valid(toast): toast.text = "")

# ------------------------------------------------------------------ check / save
func check_map() -> PackedStringArray:
	last_messages = MapStore.validate(canvas.to_doc())
	if last_messages.is_empty():
		show_message("Map check", PackedStringArray(["Ready to play: every start reaches every other start and has supplies nearby."]), false)
	else:
		show_message("Map check: %d problem%s" % [last_messages.size(), "" if last_messages.size() == 1 else "s"], last_messages, true)
	return last_messages

## Valid maps are saved and listed in Skirmish; invalid ones are kept as a draft (not listed).
func save_map() -> bool:
	var d := canvas.to_doc()
	if canvas.map_id == "":
		canvas.map_id = MapStore.new_id(canvas.map_name, Content.maps)
		d["id"] = canvas.map_id
	last_messages = MapStore.validate(d)
	d["draft"] = not last_messages.is_empty()
	var err := MapStore.save_dict(d)
	if err != OK:
		show_message("Save failed", PackedStringArray(["Could not write the map (%s)." % error_string(err)]), true)
		return false
	canvas.dirty = false
	_refresh_top()
	if last_messages.is_empty():
		_toast("Saved “%s” — it is in the Skirmish map list." % canvas.map_name)
	else:
		var msgs := PackedStringArray(["Saved as a draft. It will appear in Skirmish once these are fixed:"])
		msgs.append_array(last_messages)
		show_message("Saved as draft", msgs, true)
	return last_messages.is_empty()

# ------------------------------------------------------------------ dialogs
func _open_overlay(title: String, wmin := 420.0) -> VBoxContainer:
	close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	var sr := UiScale.safe_rect if UiScale.safe_rect.size.x > 0 else Rect2(Vector2.ZERO, UiScale.logical_size())
	cc.position = sr.position
	cc.size = sr.size
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(minf(wmin, sr.size.x - 24), 0)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(UiTheme.label(title, 17, UiTheme.GOLD))
	return v

func close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null

func show_message(title: String, lines: PackedStringArray, is_err: bool) -> void:
	var v := _open_overlay(title, 520)
	var sc := ScrollContainer.new()
	var sr := UiScale.safe_rect if UiScale.safe_rect.size.x > 0 else Rect2(Vector2.ZERO, UiScale.logical_size())
	sc.custom_minimum_size = Vector2(0, minf(lines.size() * 34.0 + 8.0, sr.size.y - 150))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for i in lines.size():
		var l := UiTheme.label(("•  " if is_err and lines.size() > 1 and not lines[i].ends_with(":") else "") + lines[i], 14,
			Color("#ff8a7a") if is_err and not lines[i].ends_with(":") else Color("#9dff9a") if not is_err else UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_child(l)
	var ok := UiTheme.button("OK", Vector2(120, 48))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(close_overlay)
	v.add_child(ok)

var new_name_edit: LineEdit
var _new_size := MapStore.DEFAULT_SIZE
var _new_env: StringName = &"desert"
var _new_src := 0
func show_new_dialog(first := false) -> void:
	var v := _open_overlay("New map", 560)
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(UiTheme.label("Name ", 14))
	new_name_edit = LineEdit.new()
	new_name_edit.text = "My map %d" % (MapStore.list_ids().size() + 1)
	new_name_edit.max_length = 32
	new_name_edit.custom_minimum_size = Vector2(260, 44)
	new_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(new_name_edit)
	v.add_child(UiTheme.label("Size", 13, UiTheme.CYAN))
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	var sg := ButtonGroup.new()
	var size_names := ["Small", "Medium", "Large", "Huge"]
	var size_btns: Array = []
	for i in MapStore.SIZES.size():
		var s: Vector2i = MapStore.SIZES[i]
		var b := _tbtn(r2, "%s %d×%d" % [size_names[i], s.x, s.y], sg, func(): _new_size = i, 110)
		b.button_pressed = i == _new_size
		size_btns.append(b)
	v.add_child(UiTheme.label("Environment", 13, UiTheme.CYAN))
	var r3 := HBoxContainer.new()
	v.add_child(r3)
	var eg := ButtonGroup.new()
	for e in MapEnv.ENVS.keys():
		var b := _tbtn(r3, ENV_NAMES.get(e, String(e)), eg, func(): _new_env = e, 100)
		b.button_pressed = e == _new_env
	var r4 := HBoxContainer.new()
	v.add_child(r4)
	r4.add_child(UiTheme.label("Start from ", 13, UiTheme.CYAN))
	var src := OptionButton.new()
	src.custom_minimum_size = Vector2(260, 44)
	src.add_item("Blank map")
	var builtins: Array = []
	for id in SkirmishConfig.map_ids():
		var md: MapDef = Content.maps[id]
		if not md.custom:
			builtins.append(id)
			src.add_item("Copy of " + tr(md.name_key) + " (%d×%d)" % [md.size.x, md.size.y])
	src.selected = 0
	src.item_selected.connect(func(i):
		_new_src = i
		for b in size_btns:
			b.disabled = i > 0)
	r4.add_child(src)
	var r5 := HBoxContainer.new()
	r5.alignment = BoxContainer.ALIGNMENT_END
	r5.add_theme_constant_override("separation", 8)
	v.add_child(r5)
	if first:
		var mm := UiTheme.button("Open saved map…", Vector2(170, 48))
		mm.pressed.connect(show_maps)
		r5.add_child(mm)
	var cancel := UiTheme.button("Cancel" if not first else "Menu", Vector2(110, 48))
	cancel.pressed.connect(func():
		if first:
			GameSession.goto("res://ui/main_menu.tscn")
		else:
			close_overlay())
	r5.add_child(cancel)
	var create := UiTheme.button("Create", Vector2(130, 48))
	create.add_theme_color_override("font_color", UiTheme.GOLD)
	create.pressed.connect(func():
		var bid: StringName = builtins[_new_src - 1] if _new_src > 0 else &""
		new_map(new_name_edit.text.strip_edges(), MapStore.SIZES[_new_size], _new_env, bid))
	r5.add_child(create)

## Creates a blank map (or a copy of a built-in map) and opens it in the editor.
func new_map(name: String, size: Vector2i, env: StringName, from_builtin: StringName = &"") -> void:
	if name == "":
		name = "My map"
	var d: Dictionary
	if from_builtin != &"":
		d = MapStore.to_dict(Content.maps[from_builtin])
		d["env"] = String(env)
	else:
		d = MapStore.blank(name, size, env)
	d["id"] = ""
	d["name"] = name
	canvas.load_doc(d)
	canvas.dirty = true
	_refresh_top()
	close_overlay()
	show_tab("terrain")

func open_map(id: String) -> bool:
	var d := MapStore.load_dict(id)
	if d.is_empty():
		_toast("Could not open that map.", Color("#ff8a7a"))
		return false
	canvas.load_doc(d)
	_refresh_top()
	close_overlay()
	return true

func show_maps() -> void:
	var v := _open_overlay("Your maps", 560)
	var ids := MapStore.list_ids()
	var sc := ScrollContainer.new()
	var sr := UiScale.safe_rect if UiScale.safe_rect.size.x > 0 else Rect2(Vector2.ZERO, UiScale.logical_size())
	sc.custom_minimum_size = Vector2(0, minf(maxf(1, ids.size()) * 50.0, sr.size.y - 150))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	if ids.is_empty():
		lv.add_child(UiTheme.label("No saved maps yet.", 14))
	for id in ids:
		var d := MapStore.load_dict(id)
		if d.is_empty():
			continue
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		lv.add_child(r)
		var sz := MapStore._v(d["size"])
		var l := UiTheme.label("%s  (%d×%d, %d starts)%s" % [d["name"], sz.x, sz.y, d["spawns"].size(), "  — draft" if d.get("draft", false) else ""], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		r.add_child(l)
		var o := UiTheme.button("Open", Vector2(80, 44))
		o.pressed.connect(open_map.bind(id))
		r.add_child(o)
		var del := UiTheme.button("Delete", Vector2(80, 44))
		del.add_theme_color_override("font_color", Color("#ff8a7a"))
		del.pressed.connect(func():
			if del.text != "Sure?":
				del.text = "Sure?"
				return
			MapStore.delete(id)
			if canvas.map_id == id:
				canvas.map_id = ""
				canvas.dirty = true
			show_maps())
		r.add_child(del)
	var r5 := HBoxContainer.new()
	r5.alignment = BoxContainer.ALIGNMENT_END
	r5.add_theme_constant_override("separation", 8)
	v.add_child(r5)
	var nm := UiTheme.button("New map…", Vector2(130, 48))
	nm.pressed.connect(func(): show_new_dialog())
	r5.add_child(nm)
	var cl := UiTheme.button("Close", Vector2(110, 48))
	cl.pressed.connect(close_overlay)
	r5.add_child(cl)

func go_back() -> void:
	if overlay != null:
		close_overlay()
		return
	if canvas.dirty and not _back_armed:
		_back_armed = true
		_toast("Unsaved changes — press Back again to leave without saving.", Color("#ffd166"))
		return
	GameSession.goto("res://ui/main_menu.tscn")
