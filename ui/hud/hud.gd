class_name Hud
extends CanvasLayer
## Zero Hour-style command bar adapted for touch (GDD 7 + ZH steering): bottom bar with
## minimap (left), selection portrait/info, 2x5 command grid, money/power/pop/rank panel;
## top strip with filters, 5 control groups, clock, pause and menu; alerts with jump/Back;
## placement Confirm/Rotate/Cancel; General powers tray; pause menu. All sizes in dp.

## M2.1: every HUD bubble is 10% smaller than M2 (user feedback: cluttered); tap targets stay >= 44 dp.
const BAR_H := 106.0
const PORTRAIT := Vector2(65, 47)
const BTN := Vector2(63, 49)
const TOP_H := 37.0           ## M2.6: top strip drawn ~15% smaller (was 44) ...
const TOP_PAD := 3.5          ## ... with invisible tap padding -> 44 dp touch targets
const MM_BIG := 168.0         ## M2.6: minimap size while the command bar is tucked away
const BAR_SLIDE_S := 0.22
const XBTN := Vector2(44, 44)

var m  ## Match node
var ctl: PlayerController
var world: WorldView
var cam: CameraRig
var sim: SimWorld
var pid: int

var root: Control
var bar: Panel
var minimap: Minimap
var sel_panel: Control
var sel_name: Label
var sel_info: Label
var sel_portrait: Control
var sel_types: HBoxContainer
var queue_box: HBoxContainer
var grid: GridContainer
var grid_buttons: Array = []
var money_lbl: Label
var power_lbl: Label
var power_bar: PowerSegBar
var econ_box: Control         ## M3.3: top-centre money box + 40-segment power bar
var money_box: Panel
var queue_grid: GridContainer ## M3.3: 8-slot production queue (right end of the bar)
var queue_slots: Array = []
const QUEUE_SLOTS := 8
const QSLOT := Vector2(34, 46)
const FLAG_ALPHA := 0.2
const ECON_W := 150.0
var pop_lbl: Label
var rank_lbl: Label
var general_btn: HudButton
var build_btn: HudButton
var idle_btn: HudButton
var compass_btn: HudCompass
var army_btn: HudButton
var top: HBoxContainer
var group_btns: Array = []
var groups_btn: HudButton   ## chevron that expands / collapses the 1-5 row
var groups_open := false
var deselect_btn: Button
var resume_btn: HudButton
var clock_lbl: Label
var pause_btn: HudButton
var res_panel: Panel          ## M2.6: money / power / Build / General, stays when the bar slides out
var emblem: FactionEmblem
var fac: StringName = &"eu"
var bar_k := 0.0              ## 0 = command bar up, 1 = slid out (nothing selected)
var alerts_box: VBoxContainer
var back_btn: Button
var place_bar: HBoxContainer
var place_reason: Label
var place_confirm: PlaceConfirm    ## M2.6: ✓ / ✗ floating above the ghost
var target_bar: HBoxContainer
var target_lbl: Label
var info_panel: PanelContainer
var info_title: Label
var info_body: Label
var info_shown: Dictionary = {}     ## last card (title / lines) for the UI test
var _hold := {"on": false, "t0": 0, "pos": Vector2.ZERO, "shown": false}
var _info_hide_ms := -100000
var _tray_info: Array = []          ## [[Control, power id], ...] for press-and-hold
const INFO_W := 380.0
var tray: PanelContainer
var tray_list: VBoxContainer
var pause_menu: Control
var paused_lbl: Label
var perf_lbl: Label
var toast_lbl: Label
var blockers: Array = []
var alerts: Array = []     ## {text, pos(Vector2i), t}
var last_alert_pos := Vector2i(-1, -1)
var _throttle: Dictionary = {}
var _card_key: String = ""
var _refresh_t: float = 0.0
var _toast_t: float = 0.0
var _last_supply: int = -1

func setup(match_node, c: PlayerController, w: WorldView, cm: CameraRig) -> void:
	m = match_node
	ctl = c
	world = w
	cam = cm
	sim = w.sim
	pid = c.pid
	layer = 10
	root = Control.new()
	fac = sim.faction_of(pid) if pid >= 0 else &"eu"
	root.theme = UiTheme.faction_theme(fac)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	UiScale.changed.connect(_layout)
	ctl.selection_changed.connect(_on_selection)
	ctl.mode_changed.connect(_on_mode)
	ctl.feedback.connect(toast)
	_layout()
	_on_selection()
	_on_mode()

# ------------------------------------------------------------------ build
func _build() -> void:
	var fp := UiTheme.pal(fac)
	bar = Panel.new()
	bar.name = "CommandBar"
	bar.add_theme_stylebox_override("panel", UiTheme.fbox(fac, fp["bg"], fp["frame"], -1, int(fp["radius"])))
	root.add_child(bar)
	blockers.append(bar)
	# M3.3 (Malachi: "Add emblem or country's flag in background of the task bar"): the national
	# flag drawn faintly behind the selection panel and command grid
	emblem = FactionEmblem.new()
	emblem.name = "BarFlag"
	emblem.fac = fac
	emblem.flag_mode = true
	emblem.modulate = Color(1, 1, 1, FLAG_ALPHA)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(emblem)
	minimap = Minimap.new()
	minimap.setup(world, cam, ctl)
	root.add_child(minimap)      # M2.6: own node so it can grow when the bar slides out
	blockers.append(minimap)
	# selection panel
	sel_panel = Control.new()
	bar.add_child(sel_panel)
	deselect_btn = UiTheme.button("X", XBTN)
	deselect_btn.name = "Deselect"
	deselect_btn.tooltip_text = tr("HUD_DESELECT")
	deselect_btn.visible = false
	deselect_btn.pressed.connect(func(): ctl.set_selection([]))
	sel_panel.add_child(deselect_btn)
	resume_btn = _hud_btn(tr("CMD_RESUME_BUILD"), Vector2(78, 44))
	resume_btn.visible = false
	resume_btn.accent = Color("#7dff8a")
	resume_btn.primary.connect(resume_selected_builders)
	sel_panel.add_child(resume_btn)
	sel_portrait = Control.new()
	sel_portrait.custom_minimum_size = PORTRAIT
	sel_portrait.draw.connect(_draw_portrait)
	sel_panel.add_child(sel_portrait)
	sel_name = UiTheme.label("", 13, UiTheme.pal(sim.faction_of(pid) if pid >= 0 else &"eu")["title"])
	sel_panel.add_child(sel_name)
	sel_info = UiTheme.label("", 10)
	sel_info.clip_text = true
	sel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_panel.add_child(sel_info)
	sel_types = HBoxContainer.new()
	sel_types.add_theme_constant_override("separation", 3)
	sel_panel.add_child(sel_types)
	queue_box = HBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 3)
	sel_panel.add_child(queue_box)
	# command grid
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	bar.add_child(grid)
	for i in 10:
		var b := HudButton.new()
		b.custom_minimum_size = BTN
		b.size = BTN
		b.add_theme_font_size_override("font_size", 11)
		b.primary.connect(_on_grid.bind(i, false))
		b.secondary.connect(_on_grid.bind(i, true))
		b.hold_info.connect(_on_grid_info.bind(i, b))
		grid.add_child(b)
		grid_buttons.append(b)
	# M3.3: production queue panel at the right end of the bar - 8 slots (4 x 2) like Zero Hour
	res_panel = Panel.new()
	res_panel.name = "QueuePanel"
	res_panel.add_theme_stylebox_override("panel", UiTheme.fbox(fac, fp["bg"], fp["frame"], -1, int(fp["radius"])))
	root.add_child(res_panel)
	blockers.append(res_panel)
	queue_grid = GridContainer.new()
	queue_grid.name = "Queue"
	queue_grid.columns = 4
	queue_grid.add_theme_constant_override("h_separation", 3)
	queue_grid.add_theme_constant_override("v_separation", 3)
	res_panel.add_child(queue_grid)
	for i in QUEUE_SLOTS:
		var q := _hud_btn("", QSLOT)
		q.add_theme_font_size_override("font_size", 10)
		q.hit_pad = 5.0   # 44 dp tap target
		var qi := i
		q.primary.connect(func(): _on_queue_slot(qi))
		q.has_info = true
		q.hold_info.connect(func(on: bool): _on_queue_info(qi, q, on))
		queue_grid.add_child(q)
		queue_slots.append(q)
	# M3.3 (Malachi: "Money amount and power, move to top of center screen, money in a colored box
	# with white letters. Power in a bar with ~40 squares"): top-centre economy box
	econ_box = Control.new()
	econ_box.name = "Econ"
	root.add_child(econ_box)
	money_box = Panel.new()
	money_box.name = "MoneyBox"
	money_box.add_theme_stylebox_override("panel", UiTheme.box(Color(fp["money"]).darkened(0.55), Color(fp["money"]), 1, 4, 2.0))
	econ_box.add_child(money_box)
	money_lbl = UiTheme.label("$0", 16, Color.WHITE)
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	money_lbl.add_theme_constant_override("outline_size", 3)
	money_box.add_child(money_lbl)
	power_bar = PowerSegBar.new()
	power_bar.name = "PowerBar"
	power_bar.hold_info.connect(_on_power_info)
	econ_box.add_child(power_bar)
	blockers.append(money_box)
	blockers.append(power_bar)
	power_lbl = UiTheme.label("", 10)   # low-power warning under the bar
	power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	power_lbl.add_theme_constant_override("outline_size", 3)
	econ_box.add_child(power_lbl)
	pop_lbl = power_lbl
	general_btn = _hud_btn(tr("HUD_GENERAL"), Vector2(77, TOP_H))
	general_btn.primary.connect(toggle_tray)
	general_btn.visible = Content.GENERALS_ENABLED   # M3.3: generals are off
	build_btn = _hud_btn(tr("HUD_BUILD"), Vector2(56, TOP_H))
	build_btn.name = "BuildBtn"
	build_btn.primary.connect(open_build)
	rank_lbl = UiTheme.label("", 11, fp["accent"])
	# top strip
	top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)
	var army := _hud_btn(tr("HUD_ARMY"), Vector2(50, TOP_H))
	army.primary.connect(ctl.select_all_army)
	top.add_child(army)
	army_btn = army
	var idle := _hud_btn(tr("HUD_IDLE_BUILDER") % tr(Content.unit(Content.faction(sim.faction_of(pid) if pid >= 0 else &"eu")["builder"]).name_key), Vector2(56, TOP_H))
	idle.primary.connect(ctl.select_idle_builder)
	top.add_child(idle)
	idle_btn = idle
	top.add_child(build_btn)   # M3.3: Build moved up here (the money panel became the queue)
	top.add_child(general_btn)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(TOP_PAD * 2 + 2, 1)
	top.add_child(sp)
	groups_btn = HudButton.new()
	groups_btn.custom_minimum_size = Vector2(TOP_H, TOP_H)
	groups_btn.label_text = "›"
	groups_btn.tooltip_text = tr("HUD_GROUPS_TIP")
	groups_btn.primary.connect(toggle_groups)
	top.add_child(groups_btn)
	for i in 5:
		var gb := HudButton.new()
		gb.custom_minimum_size = Vector2(TOP_H, TOP_H)
		gb.visible = false   # collapsed by default (M2.1)
		gb.label_text = str(i + 1)
		gb.primary.connect(func(): if not ctl.group_select(i): toast(tr("HUD_GROUP_HINT")))
		gb.secondary.connect(func(): ctl.group_assign(i))
		top.add_child(gb)
		group_btns.append(gb)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fill)
	compass_btn = HudCompass.new()   # M3.1: 360 camera; tap = north-up
	compass_btn.cam = cam
	compass_btn.name = "Compass"
	compass_btn.custom_minimum_size = Vector2(TOP_H, TOP_H)
	compass_btn.tooltip_text = tr("HUD_COMPASS_TIP")
	compass_btn.primary.connect(func(): cam.reset_north())
	top.add_child(compass_btn)
	clock_lbl = UiTheme.label("00:00", 14)
	top.add_child(clock_lbl)
	pause_btn = _hud_btn("II", Vector2(TOP_H, TOP_H))
	pause_btn.name = "PauseBtn"
	pause_btn.primary.connect(toggle_pause)
	top.add_child(pause_btn)
	var menu_btn := _hud_btn(tr("HUD_MENU"), Vector2(50, TOP_H))
	menu_btn.name = "MenuBtn"
	menu_btn.primary.connect(toggle_pause_menu)
	top.add_child(menu_btn)
	top.add_theme_constant_override("separation", int(TOP_PAD * 2))
	for c in [army, idle, build_btn, general_btn, pause_btn, menu_btn, groups_btn, compass_btn] + group_btns:
		c.hit_pad = TOP_PAD
		c.add_theme_font_size_override("font_size", 11)
		blockers.append(c)
	# alerts
	alerts_box = VBoxContainer.new()
	alerts_box.add_theme_constant_override("separation", 2)
	root.add_child(alerts_box)
	back_btn = UiTheme.button("‹ " + tr("HUD_BACK"), Vector2(64, 44))
	back_btn.visible = false
	back_btn.pressed.connect(func(): cam.back(); back_btn.visible = not cam.history.is_empty())
	root.add_child(back_btn)
	blockers.append(back_btn)
	toast_lbl = UiTheme.label("", 14, Color("#ffd8a8"))
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_lbl)
	# placement controls
	place_bar = HBoxContainer.new()
	place_bar.add_theme_constant_override("separation", 6)
	place_reason = UiTheme.label("", 13, Color("#ff9a8a"))
	place_bar.add_child(place_reason)
	var rot := UiTheme.button(tr("HUD_ROTATE"), Vector2(64, 56))
	rot.pressed.connect(ctl.rotate_ghost)
	place_bar.add_child(rot)
	root.add_child(place_bar)
	blockers.append(place_bar)
	# M2.6: confirm / cancel float above the ghost (tap or drag to move it; it stays until ✓ / ✗)
	place_confirm = PlaceConfirm.new()
	place_confirm.visible = false
	place_confirm.ok_btn.pressed.connect(func(): ctl.confirm_place())
	place_confirm.cancel_btn.pressed.connect(ctl.cancel_mode)
	root.add_child(place_confirm)
	blockers.append(place_confirm.ok_btn)
	blockers.append(place_confirm.cancel_btn)
	target_bar = HBoxContainer.new()
	target_lbl = UiTheme.label("", 14, Color("#ffd166"))
	target_bar.add_child(target_lbl)
	var tc := UiTheme.button(tr("HUD_CANCEL"), Vector2(64, 48))
	tc.pressed.connect(ctl.cancel_mode)
	target_bar.add_child(tc)
	root.add_child(target_bar)
	blockers.append(target_bar)
	# general tray
	tray = PanelContainer.new()
	tray.visible = false
	tray_list = VBoxContainer.new()
	tray_list.add_theme_constant_override("separation", 4)
	tray.add_child(tray_list)
	root.add_child(tray)
	blockers.append(tray)
	# M3.2 press-and-hold info card
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_theme_stylebox_override("panel", _info_style())
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_title = UiTheme.label("", 15, UiTheme.GOLD)
	info_body = UiTheme.label("", 12)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(INFO_W - 20, 0)
	iv.add_child(info_title)
	iv.add_child(info_body)
	info_panel.add_child(iv)
	root.add_child(info_panel)
	paused_lbl = UiTheme.label(tr("HUD_PAUSED"), 22, Color("#ffd166"))
	paused_lbl.visible = false
	paused_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paused_lbl)
	perf_lbl = UiTheme.label("", 11, Color(0.7, 1, 0.7))
	perf_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(perf_lbl)
	_build_pause_menu()

func _toggle_pause_options() -> void:
	var hb: Control = pause_menu.get_node("P").get_child(0)
	var o: Control = hb.get_node("Options")
	o.visible = not o.visible
	hb.get_node("Controls").visible = not o.visible

func _build_pause_menu() -> void:
	pause_menu = ColorRect.new()
	(pause_menu as ColorRect).color = Color(0, 0, 0, 0.55)
	pause_menu.visible = false
	root.add_child(pause_menu)
	var pc := PanelContainer.new()
	pc.name = "P"
	pause_menu.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	pc.add_child(hb)
	var v := VBoxContainer.new()
	v.name = "V"
	v.add_theme_constant_override("separation", 8)
	hb.add_child(v)
	v.add_child(UiTheme.label(tr("PAUSE_TITLE"), 20, UiTheme.GOLD))
	var bg := GridContainer.new()   # M3.3: two columns so every option fits on a phone
	bg.name = "Buttons"
	bg.columns = 2
	bg.add_theme_constant_override("h_separation", 8)
	bg.add_theme_constant_override("v_separation", 6)
	v.add_child(bg)
	# M3.1: touch controls help next to the buttons
	var hv := VBoxContainer.new()
	hv.name = "Controls"
	hv.add_theme_constant_override("separation", 4)
	hb.add_child(hv)
	hv.add_child(UiTheme.label(tr("HELP_CONTROLS"), 16, UiTheme.GOLD))
	var hl := UiTheme.label(tr("HELP_CONTROLS_BODY"), 11)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size = Vector2(250, 0)
	hv.add_child(hl)
	# M4.2 in-match options (volume levels and display toggles), swapped in for the controls help
	var ov := VBoxContainer.new()
	ov.name = "Options"
	ov.visible = false
	ov.add_theme_constant_override("separation", 2)
	hb.add_child(ov)
	ov.add_child(UiTheme.label(tr("PAUSE_OPTIONS"), 16, UiTheme.GOLD))
	for pair in [["SET_VOL_MASTER", "vol_master"], ["SET_VOL_MUSIC", "vol_music"], ["SET_VOL_SFX", "vol_sfx"], ["SET_VOL_VOICE", "vol_voice"], ["SET_VOL_UI", "vol_ui"]]:
		var l := UiTheme.label("", 11)
		ov.add_child(l)
		var sl := HSlider.new()
		sl.name = pair[1]
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Settings.g(pair[1]))
		sl.custom_minimum_size = Vector2(240, 30)
		var key: String = pair[0]
		var sk: String = pair[1]
		var upd := func(val: float):
			l.text = "%s: %d%%" % [tr(key), roundi(val * 100.0)]
			Settings.data[sk] = val
			AudioDirector.apply_volumes()
		upd.call(sl.value)
		sl.value_changed.connect(upd)
		sl.drag_ended.connect(func(_c): Settings.s(sk, sl.value))
		ov.add_child(sl)
	var items := [["PAUSE_RESUME", func(): toggle_pause_menu()],
		["PAUSE_SAVE", func(): show_save_slots(true)],
		["PAUSE_OPTIONS", func(): _toggle_pause_options()],
		["PAUSE_SPEED", func(): m.cycle_speed(); _update_pause_menu()],
		["PAUSE_HEALTHBARS", func(): Settings.s("always_health_bars", not Settings.g("always_health_bars")); _update_pause_menu()],
		["PAUSE_PERF", func(): Settings.s("perf_overlay", not Settings.g("perf_overlay")); _update_pause_menu()],
		["PAUSE_RESTART", func(): m.restart()],
		["PAUSE_SURRENDER", func(): m.surrender()],
		["PAUSE_QUIT", func(): m.quit_to_menu()]]
	for it in items:
		var b := UiTheme.button(tr(it[0]), Vector2(196, 44))
		b.name = it[0]
		b.pressed.connect(it[1])
		bg.add_child(b)

	# M3.3 save slots (replaces the button panel while open)
	var sp := PanelContainer.new()
	sp.name = "Slots"
	sp.visible = false
	pause_menu.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sp.add_child(sv)
	sv.add_child(UiTheme.label(tr("SAVE_TITLE"), 18, UiTheme.GOLD))
	var sg := GridContainer.new()
	sg.name = "SlotGrid"
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 8)
	sg.add_theme_constant_override("v_separation", 6)
	sv.add_child(sg)
	for i in SaveSystem.MANUAL_SLOTS:
		var b := UiTheme.button("", Vector2(250, 46))
		b.name = "Slot%d" % i
		b.add_theme_font_size_override("font_size", 11)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.pressed.connect(func(): save_slot_tap(i))
		sg.add_child(b)
	var bk := UiTheme.button("‹ " + tr("BACK"), Vector2(120, 42))
	bk.name = "SlotsBack"
	bk.pressed.connect(func(): show_save_slots(false))
	bk.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sv.add_child(bk)

## M3.3: save-slot picker in the pause menu. A filled slot asks for a second tap to overwrite.
var _slot_arm := -1
func show_save_slots(on: bool) -> void:
	_slot_arm = -1
	pause_menu.get_node("P").visible = not on
	pause_menu.get_node("Slots").visible = on
	if on:
		_fill_save_slots()
	_layout_pause_menu()

func _fill_save_slots() -> void:
	var g := pause_menu.get_node("Slots").find_child("SlotGrid", true, false)
	for e: Dictionary in SaveSystem.list_slots():
		var b: Button = g.get_node("Slot%d" % int(e["slot"]))
		var head := tr("SAVE_SLOT") % (int(e["slot"]) + 1)
		if e["empty"]:
			b.text = head + "  -  " + tr("SAVE_EMPTY")
		elif _slot_arm == int(e["slot"]):
			b.text = head + "  -  " + tr("SAVE_OVERWRITE")
		else:
			b.text = head + "  " + SaveSystem.stamp(float(e["saved_at"])) + "\n" + String(e["label"])

func save_slot_tap(i: int) -> void:
	var filled: bool = not bool((SaveSystem.list_slots()[i] as Dictionary)["empty"])
	if filled and _slot_arm != i:
		_slot_arm = i
		_fill_save_slots()
		return
	_slot_arm = -1
	if m.save_to_slot(i):
		toast(tr("SAVE_DONE") % (i + 1))
	_fill_save_slots()

func _update_pause_menu() -> void:
	var v := pause_menu.get_node("P").find_child("Buttons", true, false)
	v.get_node("PAUSE_SPEED").text = tr("PAUSE_SPEED") + ": %sx" % str(m.speed)
	v.get_node("PAUSE_HEALTHBARS").text = tr("PAUSE_HEALTHBARS") + ": " + (tr("ON") if Settings.g("always_health_bars") else tr("OFF"))
	v.get_node("PAUSE_PERF").text = tr("PAUSE_PERF") + ": " + (tr("ON") if Settings.g("perf_overlay") else tr("OFF"))
	if pid < 0:
		v.get_node("PAUSE_SURRENDER").visible = false

# ------------------------------------------------------------------ layout
func _layout() -> void:
	var sr := UiScale.safe_rect
	if sr.size.x <= 0:
		sr = Rect2(Vector2.ZERO, UiScale.logical_size())
	root.position = Vector2.ZERO
	root.size = UiScale.logical_size()
	var bh := BAR_H
	var vis_h := bar_visible_h()
	bar.position = Vector2(sr.position.x, sr.end.y - vis_h)
	bar.size = Vector2(sr.size.x, bh)
	var pad := 4.0
	# minimap: docked in the bar's left corner, grows to MM_BIG at the bottom-left when the bar is out
	var ek := ease(bar_k, -2.0)
	var mm_small := bh - pad * 2
	var mm_big := minf(MM_BIG, sr.size.y * 0.45)
	var mms := lerpf(mm_small, mm_big, ek)
	minimap.size = Vector2(mms, mms)
	minimap.position = Vector2(sr.position.x + pad, lerpf(bar.position.y + pad, sr.end.y - mms - pad, ek))
	var grid_w := BTN.x * 5 + 12.0
	# M3.3: 8-slot queue docked in the bar's right end (slides out with the bar)
	var res_w := QSLOT.x * 4 + 9.0
	res_panel.size = Vector2(res_w + pad * 2, bh)
	res_panel.position = Vector2(sr.end.x - res_panel.size.x, bar.position.y)
	res_panel.self_modulate = Color(1, 1, 1, 0.0)   # the bar's own frame shows behind it
	queue_grid.position = Vector2(pad, (bh - (QSLOT.y * 2 + 3)) * 0.5)
	res_w = res_w + pad
	var res_x := bar.size.x - res_w - pad
	grid.position = Vector2(res_x - grid_w - pad, pad)
	var sx := pad + mm_small + 8
	var sw := grid.position.x - sx - 8
	sel_panel.position = Vector2(sx, pad)
	sel_panel.size = Vector2(sw, bh - pad * 2)
	# faded national flag behind the selection panel (3:2), where the bar has open space
	var fh := bh - 8.0
	emblem.size = Vector2(fh * 1.5, fh)
	emblem.position = Vector2(sel_panel.position.x + maxf(0.0, sel_panel.size.x - emblem.size.x), 4.0)
	# X (clear selection) sits left of the portrait
	deselect_btn.position = Vector2(0, 2)
	deselect_btn.size = XBTN
	var px := XBTN.x + 3
	sel_portrait.position = Vector2(px, 2)
	sel_portrait.size = PORTRAIT
	var tx := px + PORTRAIT.x + 5
	sel_name.position = Vector2(tx, 0)
	sel_name.size = Vector2(sw - tx, 18)
	sel_info.position = Vector2(tx, 17)
	sel_info.size = Vector2(sw - tx, 32)
	var row_y := bh - pad * 2 - 44
	sel_types.position = Vector2(0, row_y)
	queue_box.position = Vector2(0, row_y)
	resume_btn.size = Vector2(78, 44)
	resume_btn.position = Vector2(sw - 78, row_y)
	top.position = sr.position + Vector2(4 + TOP_PAD, 4 + TOP_PAD)
	top.size = Vector2(sr.size.x - 8 - TOP_PAD * 2, TOP_H)
	# M3.3 top-centre economy: money box over the 40-segment power bar; nudged right when the
	# expanded control-group row would run under it
	var ew := ECON_W
	econ_box.size = Vector2(ew, 44)
	var ex := sr.position.x + (sr.size.x - ew) * 0.5
	ex = clampf(ex, _top_left_end() + 6.0, maxf(_top_left_end() + 6.0, _top_right_start() - ew - 6.0))
	econ_box.position = Vector2(ex, sr.position.y + 4)
	money_box.position = Vector2.ZERO
	money_box.size = Vector2(ew, 24)
	money_lbl.position = Vector2.ZERO
	money_lbl.size = money_box.size
	power_bar.position = Vector2(2, 28)
	power_bar.size = Vector2(ew - 4, 8)
	power_lbl.position = Vector2(0, 38)
	power_lbl.size = Vector2(ew, 14)
	alerts_box.position = sr.position + Vector2(6, 52)
	_layout_pause_menu()
	alerts_box.size = Vector2(minf(288, sr.size.x * 0.36), 10)
	var lift := maxf(vis_h, minimap.size.y + pad if bar_k > 0.0 else 0.0)
	back_btn.position = sr.position + Vector2(6, sr.size.y - lift - 56)
	toast_lbl.position = Vector2(sr.position.x, sr.end.y - vis_h - 34)
	toast_lbl.size = Vector2(sr.size.x, 24)
	place_bar.position = Vector2(sr.end.x - 360, sr.end.y - maxf(vis_h, bh) - 64)
	place_bar.size = Vector2(352, 56)
	if is_instance_valid(place_confirm):
		_place_confirm_follow()
	place_bar.alignment = BoxContainer.ALIGNMENT_END
	target_bar.position = Vector2(sr.position.x + sr.size.x * 0.5 - 140, sr.position.y + 54)
	tray.position = Vector2(sr.end.x - 300, sr.end.y - bh - 8 - 220)   # res panel keeps its height
	tray.size = Vector2(292, 220)
	paused_lbl.position = Vector2(sr.position.x + sr.size.x * 0.5 - 50, sr.position.y + 100)
	perf_lbl.position = sr.position + Vector2(sr.size.x - 210, 52)
	pause_menu.position = Vector2.ZERO
	pause_menu.size = root.size


## Right edge (local x in root) of the visible left-hand top-strip buttons, and left edge of the
## right-hand ones (the HBox lays out with fixed sizes, so this is computed from them).
func _top_left_end() -> float:
	var x := top.position.x
	var sep := float(top.get_theme_constant("separation"))
	for c: Control in top.get_children():
		if c.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			break
		if c.visible:
			x += c.custom_minimum_size.x + sep
	return x

func _top_right_start() -> float:
	var x := top.position.x + top.size.x
	var sep := float(top.get_theme_constant("separation"))
	var kids := top.get_children()
	kids.reverse()
	for c: Control in kids:
		if c.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			break
		if c.visible:
			x -= maxf(c.custom_minimum_size.x, c.get_combined_minimum_size().x) + sep
	return x

## M3.3 pause menu fix (Malachi: "cut off on bottom of screen, the last option is half
## showing"): buttons in a 2-column grid, the panel centred on its measured size and clamped
## inside the safe area; the controls help shrinks to fit beside it.
func _layout_pause_menu() -> void:
	var sr := UiScale.safe_rect
	if sr.size.x <= 0:
		sr = Rect2(Vector2.ZERO, UiScale.logical_size())
	for pn in ["P", "Slots"]:
		var pc: Control = pause_menu.get_node(pn)
		pc.reset_size()
		var sz := pc.get_combined_minimum_size()
		var avail := sr.size - Vector2(16, 16)
		pc.size = Vector2(minf(sz.x, avail.x), minf(sz.y, avail.y))
		pc.position = sr.position + ((sr.size - pc.size) * 0.5).max(Vector2(8, 8))

## M2.6 (Malachi): with nothing selected (and no placement / targeting going on) the command bar
## slides out of the way and the minimap grows; any selection slides it back up.
func bar_target() -> float:
	if pid < 0:
		return 0.0
	if ctl.mode != PlayerController.Mode.NONE or not ctl.selection.is_empty() or tray.visible:
		return 0.0
	return 1.0

func bar_visible_h() -> float:
	return BAR_H * (1.0 - ease(bar_k, -2.0))

## Screen point above the ghost's top centre (footprint centre, raised by the building height).
func _place_confirm_follow() -> void:
	if ctl.mode != PlayerController.Mode.PLACE or ctl.place_def == &"":
		return
	var d := Content.building(ctl.place_def)
	var fpv := d.footprint if ctl.place_rot % 2 == 0 else Vector2i(d.footprint.y, d.footprint.x)
	var top3 := Vector3(ctl.place_tile.x + fpv.x * 0.5, 2.2, ctl.place_tile.y + fpv.y * 0.5)
	if cam.cam.is_position_behind(top3):
		return
	var sp := cam.cam.unproject_position(top3)
	var sr := UiScale.safe_rect
	if sr.size.x <= 0:
		sr = Rect2(Vector2.ZERO, UiScale.logical_size())
	var bounds := Rect2(sr.position + Vector2(0, TOP_H + 8), Vector2(sr.size.x, sr.size.y - TOP_H - 8 - bar_visible_h() - 8))
	place_confirm.place_at(sp, bounds)

## True when a screen point (logical units) is over HUD chrome - world input ignores it.
func blocks(p: Vector2) -> bool:
	if pause_menu.visible:
		return true
	for b in blockers:
		if is_instance_valid(b) and b.is_visible_in_tree():
			var gr: Rect2 = b.hit_rect() if b is HudButton else b.get_global_rect()
			if gr.has_point(p):
				return true
	return false

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if sim == null:
		return
	_hold_tick()
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_lbl.text = ""
	var want := bar_target()
	if bar_k != want:
		bar_k = move_toward(bar_k, want, delta / BAR_SLIDE_S)
		_layout()
	if place_confirm.visible:
		_place_confirm_follow()
	if Settings.g("perf_overlay"):
		perf_lbl.visible = true
		perf_lbl.text = "FPS %d  tick %.2f ms  ents %d  draw %d" % [Engine.get_frames_per_second(), m.avg_tick_ms, sim.ids.size(),
			int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))]
	else:
		perf_lbl.visible = false
	var keep: Array = []
	for a in alerts:
		a["t"] -= delta
		if a["t"] > 0:
			keep.append(a)
		else:
			blockers.erase(a["node"])
			a["node"].queue_free()
	alerts = keep

func _refresh() -> void:
	ctl.prune()
	var secs := sim.tick / 20
	clock_lbl.text = "%02d:%02d" % [secs / 60, secs % 60]
	paused_lbl.visible = m.paused
	pause_btn.label_text = ">" if m.paused else "II"
	var assigned := 0
	for i in 5:
		var gb: HudButton = group_btns[i]
		gb.badge = str(ctl.groups[i].size()) if not ctl.groups[i].is_empty() else ""
		gb.queue_redraw()
		if not ctl.groups[i].is_empty():
			assigned += 1
	# collapsed arrow shows how many groups are assigned
	groups_btn.badge = str(assigned) if assigned > 0 and not groups_open else ""
	groups_btn.queue_redraw()
	if pid < 0:
		money_lbl.text = tr("HUD_OBSERVER")
		power_bar.visible = false
		power_lbl.text = ""
		pop_lbl.text = ""
		rank_lbl.text = ""
		general_btn.disabled = true
		build_btn.disabled = true
	else:
		var p: SimPlayer = sim.players[pid]
		money_lbl.text = _money(p.supply)
		var needs_power: bool = Content.faction(p.faction)["power"]
		power_bar.visible = needs_power
		if needs_power:
			power_bar.set_power(p.power_prod, p.power_used)
		# M3.3: the numbers live in the hold card; only a low-power warning shows under the bar
		power_lbl.text = tr("HUD_LOW_POWER_WARN") if needs_power and p.low_power else ""
		power_lbl.add_theme_color_override("font_color", Color("#ff7a6a") if p.low_power else UiTheme.TEXT)
		var next: int = SimPlayer.RANK_XP[p.rank + 1] if p.rank + 1 < SimPlayer.RANK_XP.size() else -1
		rank_lbl.text = tr("HUD_RANK") % p.rank + ("  XP %d/%d" % [p.xp, next] if next > 0 else "  XP %d" % p.xp)
		general_btn.sub = tr("HUD_RANK") % p.rank + (" +%d" % p.points if p.points > 0 else "")
		general_btn.queue_redraw()
	_refresh_selection_info()
	_refresh_card()
	if tray.visible:
		_fill_tray()
	world.update_rally(ctl.primary() if ctl.primary() != null and ctl.is_own(ctl.primary()) and ctl.primary().kind == SimEntity.Kind.BUILDING else null)

# ------------------------------------------------------------------ selection panel
func _on_selection() -> void:
	_card_key = ""
	_refresh_selection_info()
	_refresh_card()

func _draw_portrait() -> void:
	var e := ctl.primary()
	var s := sel_portrait.size
	sel_portrait.draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.06, 0.07))
	sel_portrait.draw_rect(Rect2(Vector2.ZERO, s), UiTheme.GOLD, false, 1.0)
	if e == null:
		return
	var col := Palette.color(sim.players[e.owner].color) if e.owner >= 0 else Palette.NEUTRAL
	var f := sel_portrait.get_theme_default_font()
	sel_portrait.draw_circle(s * 0.5, minf(s.x, s.y) * 0.42, col.darkened(0.45))
	# full name, wrapped to two lines and auto-shrunk (never an abbreviation)
	var box := Vector2(s.x - 6, s.y - 6)
	var fit: Array = HudButton.fit_paragraph(ent_name(e), f, box, 12)
	portrait_fit_ok = fit[1]
	var para: TextParagraph = fit[0]
	# M3.3 Phase 4: the portrait shows the unit / structure icon (its name is beside it)
	var ic := UnitIcons.of(e.def_id) if e.kind == SimEntity.Kind.UNIT or e.kind == SimEntity.Kind.BUILDING else null
	if ic != null:
		var side := minf(s.x, s.y) - 6.0
		sel_portrait.draw_texture_rect(ic, Rect2((s - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
		return
	var h := 0.0
	for i in para.get_line_count():
		h += para.get_line_size(i).y
	para.draw(sel_portrait.get_canvas_item(), Vector2(3, 3 + maxf(0.0, (box.y - h) * 0.5)), Color.WHITE)

var portrait_fit_ok := true

func ent_name(e: SimEntity) -> String:
	match e.kind:
		SimEntity.Kind.UNIT:
			return tr(Content.unit(e.def_id).name_key)
		SimEntity.Kind.RESOURCE:
			return tr("RES_" + String(e.def_id).to_upper())
		SimEntity.Kind.CRATE:
			return tr("HUD_CRATE")
	return tr(Content.building(e.def_id).name_key)

func _refresh_selection_info() -> void:
	sel_portrait.queue_redraw()
	var e := ctl.primary()
	deselect_btn.visible = e != null
	resume_btn.visible = e != null and pid >= 0 and resume_site_for(ctl.own_units_selected()) != null
	for c in queue_box.get_children():
		c.queue_free()
	_refresh_queue(e)
	if e == null:
		sel_name.text = ""
		sel_info.text = tr("HUD_NOTHING_SELECTED")
		_fill_types([])
		return
	var units := ctl.own_units_selected()
	if units.size() > 1:
		sel_name.text = tr("HUD_N_SELECTED") % units.size()
		sel_info.text = ""
		_fill_types(units)
		return
	_fill_types([])
	sel_name.text = ent_name(e)
	var lines: Array = []
	if e.kind == SimEntity.Kind.RESOURCE and e.def_id == &"cache":
		lines.append(tr("HUD_OIL_LEFT") % e.amount)   # M3.5: crude oil reserve, sold for export
		lines.append(tr("RES_CACHE_TIP"))
	elif e.kind == SimEntity.Kind.RESOURCE:
		lines.append(tr("HUD_SUPPLY_LEFT") % e.amount)
	elif e.kind == SimEntity.Kind.CRATE:
		lines.append(tr("HUD_CRATE_VALUE") % e.amount)
	else:
		var hp := "HP %d/%d" % [e.hp, e.max_hp]
		if e.max_shield > 0:
			hp += "  " + tr("HUD_SHIELD") % e.shield
		lines.append(hp)
	if e.owner >= 0 and e.owner != pid:
		lines.append(tr("HUD_OWNER") % (sim.players[e.owner].id + 1))
	if e.kind == SimEntity.Kind.UNIT:
		if e.vet > 0:
			lines.append(tr("VET_%d" % e.vet))
		var ud := Content.unit(e.def_id)
		var role_k := "ROLE_" + String(ud.role).to_upper()
		if tr(role_k) != role_k:
			lines[0] = tr(role_k) + "  ·  " + lines[0]
		if ud.tags.has("salvage"):
			lines.append(tr("HUD_SALVAGE_TIER") % e.tier)
		if ud.harvest_capacity > 0:
			lines.append(tr("HUD_CARRY") % [e.carry, ud.harvest_capacity])
		if ud.transport_capacity > 0:
			lines.append(tr("HUD_PASSENGERS") % [RosterSys.load_of(sim, e), ud.transport_capacity])
		if e.air_state == AirSys.PARKED and e.air_t > 0 and ud.move_layer == &"air":
			lines.append(tr("HUD_AIR_REARMING") % ceili(float(e.air_t) / FX.TICK_HZ))
		if e.stealthy and e.owner == pid:
			lines.append(tr("HUD_STEALTHED"))
		if Content.is_squad(e.def_id):   # M3.5 Combat Squad: soldiers left
			lines.append(tr("HUD_SQUAD_MEN") % [sim.squad_alive(e), Content.squad_members(e.def_id).size()])
		if e.owner >= 0 and RosterSys.is_jammed(sim, e, RosterSys.jammers(sim)):
			lines.append(tr("HUD_JAMMED"))
		if not ud.stubs.is_empty():
			lines.append("[STUB] " + ", ".join(Array(ud.stubs)))
		if e.owner == pid:
			lines.append(_unit_state(e))
	elif e.kind == SimEntity.Kind.BUILDING:
		var bd := Content.building(e.def_id)
		if not e.built:
			lines.append(tr("HUD_CONSTRUCTING") % int(100.0 * e.progress / maxi(1, e.build_ticks)))
		elif e.owner == pid:
			if bd.tags.has("hole"):
				lines.append(tr("HUD_HOLE_REBUILD") % maxi(0, (int(e.aux_t) - sim.tick) / FX.TICK_HZ))
			if TplaSys.is_tunnel(sim, e):
				lines.append(tr("HUD_TUNNEL_NET") % [TplaSys.network_units(sim, pid).size(), TplaSys.network_capacity()])
			if e.stealthy:
				lines.append(tr("HUD_STEALTHED"))
			if not e.powered and Content.faction(sim.faction_of(pid))["power"]:
				lines.append(tr("HUD_UNPOWERED"))
			if bd.power != 0:
				lines.append(tr("HUD_BLD_POWER") % bd.power)
			if bd.air_slots > 0:
				lines.append(tr("HUD_AIR_SLOTS") % [AirSys.slots_used(sim, e), bd.air_slots])
			if bd.garrison_capacity > 0 and bd.tags.has("barricade"):
				var ng := 0
				for uid3 in sim.ids:
					if sim.ents[uid3].res_id == -e.id:
						ng += 1
				lines.append(tr("HUD_GARRISON") % [ng, bd.garrison_capacity])
			if e.hold_reason != "":
				lines.append(tr(e.hold_reason))
	elif e.kind == SimEntity.Kind.NEUTRAL:
		var nd := Content.building(e.def_id)
		if nd.garrison_capacity > 0:
			var n := 0
			for uid in sim.ids:
				if sim.ents[uid].res_id == -e.id:
					n += 1
			lines.append(tr("HUD_GARRISON") % [n, nd.garrison_capacity])
		if nd.capturable:
			lines.append(tr("HUD_PUMP_INCOME") % nd.capture_income)
	sel_info.text = "\n".join(lines)

func _unit_state(e: SimEntity) -> String:
	if e.orders.is_empty():
		return tr("STATE_IDLE")
	var o: String = e.orders[0].get("o", "")
	return tr("STATE_" + o.to_upper())

var _types_key := ""
func _fill_types(units: Array) -> void:
	var counts := {}
	for id in units:
		var d0: StringName = sim.ents[id].def_id
		counts[d0] = counts.get(d0, 0) + 1
	var key := "%s|%.0f" % [counts, sel_panel.size.x]
	if key == _types_key:   # M3.2: keep the chips alive between refreshes (press-and-hold info)
		return
	_types_key = key
	for c in sel_types.get_children():
		c.queue_free()
	if units.is_empty():
		return
	var tmax := _chips_fit(59.0, _resume_reserve())
	var listed := 0
	for d in counts:
		if listed >= tmax:
			break
		listed += 1
		var b := _hud_btn(tr(Content.unit(d).name_key), Vector2(59, 44))
		b.sub = "×%d" % counts[d]
		b.icon_tex = UnitIcons.of(d)   # M3.3 Phase 4: selection chips show the unit's icon
		b.primary.connect(func():
			var only: Array = []
			for id in ctl.own_units_selected():
				if sim.ents[id].def_id == d:
					only.append(id)
			ctl.set_selection(only))
		b.has_info = true   # M3.2: hold a type chip -> its info card
		b.hold_info.connect(func(on: bool):
			if on:
				show_info(InfoCard.build("unit", d, sim, pid), b.get_global_rect())
			else:
				hide_info())
		sel_types.add_child(b)

## How many chips of width w (3 dp gaps) fit in the selection panel, keeping `reserve` dp free
## for a "+N" label. Chips are never squeezed below their tap size; the rest go to "+N".
func _chips_fit(w: float, reserve: float) -> int:
	var avail := sel_panel.size.x - reserve
	return clampi(int((avail + 3.0) / (w + 3.0)), 1, 4)

## M3.3: the 8 queue slots show the selected own producer's queue (first = in progress with its
## fill); tap a slot to cancel that item; an 8th slot with more behind it shows "+N".
var _queue_owner: SimEntity = null
func _refresh_queue(e: SimEntity) -> void:
	var b: SimEntity = null
	if e != null and e.kind == SimEntity.Kind.BUILDING and e.owner == pid and e.built and not Content.building(e.def_id).produces.is_empty():
		b = e
	_queue_owner = b
	for i in QUEUE_SLOTS:
		var q: HudButton = queue_slots[i]
		var has := b != null and i < b.queue.size()
		q.label_text = short_name(tr(Content.unit(b.queue[i]).name_key)) if has else ""
		q.icon_tex = UnitIcons.of(b.queue[i]) if has else null   # M3.3 Phase 4: queue icons
		q.progress = -1.0
		q.badge = ""
		q.disabled = not has
		q.modulate = Color(1, 1, 1, 1.0 if has else 0.45)
		q.tooltip_text = tr("HUD_TAP_CANCEL") if has else ""
		if has and i == 0:
			var need := FX.ms_to_ticks(Content.unit(b.queue[0]).build_time_ms) * 2
			q.progress = float(b.q_progress) / float(maxi(1, need))
		if has and i == QUEUE_SLOTS - 1 and b.queue.size() > QUEUE_SLOTS:
			q.badge = "+%d" % (b.queue.size() - QUEUE_SLOTS + 1)
		q.queue_redraw()

## Slot caption until unit icons land (plan item: icons): initials of a multi-word name, else
## the first 4 letters. The full name is on press-and-hold.
static func short_name(n: String) -> String:
	var words := n.replace("-", " ").split(" ", false)
	if words.size() > 1:
		var o := ""
		for w in words.slice(0, 3):
			o += w.substr(0, 1).to_upper()
		return o
	return n.substr(0, 4)

func _on_queue_slot(i: int) -> void:
	var b := _queue_owner
	if b != null and b.alive and i < b.queue.size():
		ctl.dequeue(b, i)
		_refresh_queue(b)

func _on_queue_info(i: int, q: HudButton, on: bool) -> void:
	var b := _queue_owner
	if on and b != null and i < b.queue.size():
		show_info(InfoCard.build("unit", b.queue[i], sim, pid), q.get_global_rect())
	else:
		hide_info()

## M3.3: hold the power bar -> produced / used numbers (+ population).
func _on_power_info(on: bool) -> void:
	if not on or pid < 0:
		hide_info()
		return
	var p: SimPlayer = sim.players[pid]
	var lines: Array = [tr("HUD_POWER_NUMBERS") % [p.power_used, p.power_prod]]
	if p.low_power:
		lines.append(tr("HUD_LOW_POWER"))
	lines.append(tr("HUD_POP1") % p.pop)
	show_info({"title": tr("HUD_POWER_TITLE"), "lines": lines}, power_bar.get_global_rect())

func _fill_queue(b: SimEntity) -> void:
	if b.queue.is_empty():
		return
	var qmax := _chips_fit(QUEUE_CHIP.x, 0.0)
	var shown := b.queue.size() if b.queue.size() <= qmax else maxi(1, _chips_fit(QUEUE_CHIP.x, 24.0))
	for i in shown:
		var q := _hud_btn(tr(Content.unit(b.queue[i]).name_key), QUEUE_CHIP)
		q.icon_tex = UnitIcons.of(b.queue[i])
		if i == 0:
			var need := FX.ms_to_ticks(Content.unit(b.queue[0]).build_time_ms) * 2
			q.progress = float(b.q_progress) / float(maxi(1, need))
		var idx := i
		q.primary.connect(func(): ctl.dequeue(b, idx))
		q.tooltip_text = tr("HUD_TAP_CANCEL")
		queue_box.add_child(q)
	if b.queue.size() > shown:
		queue_box.add_child(UiTheme.label("+%d" % (b.queue.size() - shown), 12))

# ------------------------------------------------------------------ command card
## Each card entry: {id, text, sub, act, alt, disabled, badge, stub, accent, tip}
var card: Array = []

var card_page := 0
var _card_owner := -1

## M2.4: a card with more than 10 entries pages: body entries fill the free slots, a "More"
## button cycles the pages, and entries marked "pin" (stop, rally, ...) stay on every page.
func _paginate(full: Array) -> Array:
	var pe := ctl.primary()
	var owner_id: int = pe.id if pe != null else -1
	if owner_id != _card_owner:
		_card_owner = owner_id
		card_page = 0
	if full.size() <= 10:
		return full
	var pins: Array = []
	var body: Array = []
	for c: Dictionary in full:
		if c.get("pin", false):
			pins.append(c)
		elif c.get("text", "") != "" or c.has("act"):
			body.append(c)
	var per := 10 - pins.size() - 1
	var pages := int(ceil(float(body.size()) / float(per)))
	card_page = card_page % maxi(1, pages)
	var out: Array = body.slice(card_page * per, card_page * per + per)
	while out.size() < per:
		out.append({"text": "", "disabled": true})
	out.append({"text": tr("CMD_MORE"), "sub": "%d/%d" % [card_page + 1, pages], "accent": Color("#9fd3ff"), "tip": tr("CMD_MORE_TIP"),
		"act": func():
			card_page += 1
			_refresh_card()})
	out.append_array(pins)
	return out

func _refresh_card() -> void:
	card = _paginate(_make_card())
	for i in 10:
		var b: HudButton = grid_buttons[i]
		if i < card.size():
			var c: Dictionary = card[i]
			b.visible = true
			b.label_text = c.get("text", "")
			b.sub = c.get("sub", "")
			b.disabled = c.get("disabled", false)
			b.badge = c.get("badge", "")
			b.stub = c.get("stub", false)
			b.progress = c.get("progress", -1.0)
			b.accent = c.get("accent", Color(0, 0, 0, 0))
			b.tooltip_text = c.get("tip", "")
			b.has_info = c.has("info")
			b.icon_tex = _entry_icon(c)
			b.modulate = Color(1, 1, 1, 1) if not b.disabled else Color(1, 1, 1, 0.75)
		else:
			b.visible = true
			b.label_text = ""
			b.sub = ""
			b.badge = ""
			b.stub = false
			b.progress = -1.0
			b.accent = Color(0, 0, 0, 0)
			b.disabled = true
			b.has_info = false
			b.icon_tex = null
			b.modulate = Color(1, 1, 1, 0.25)
		b.queue_redraw()

## M3.3 Phase 4: the icon of a train / build entry (its info card names the unit or structure).
func _entry_icon(c: Dictionary) -> Texture2D:
	var inf: Variant = c.get("info")
	if inf is Array and (inf as Array).size() >= 2 and String(inf[0]) in ["unit", "building"]:
		return UnitIcons.of(inf[1])
	return null

## M3.2: data-driven info card (InfoCard) for a build / train / research / power entry.
func _on_grid_info(on: bool, i: int, b: HudButton) -> void:
	if not on:
		hide_info()
		return
	if i < card.size() and card[i].has("info"):
		var inf: Array = card[i]["info"]
		show_info(InfoCard.build(inf[0], StringName(inf[1]), sim, pid), b.get_global_rect())

func show_info(d: Dictionary, anchor: Rect2) -> void:
	if d.is_empty():
		return
	info_shown = d
	info_title.text = d["title"]
	info_body.text = "\n".join(d["lines"])
	info_panel.size = Vector2(INFO_W, 0)
	info_panel.reset_size()
	info_panel.visible = true
	var vs := root.get_viewport_rect().size
	var sz := info_panel.get_combined_minimum_size()
	sz.x = INFO_W
	info_panel.size = sz
	var x := clampf(anchor.get_center().x - sz.x * 0.5, 8.0, vs.x - sz.x - 8.0)
	var y := anchor.position.y - sz.y - 10.0
	if y < 8.0:
		y = minf(anchor.end.y + 10.0, vs.y - sz.y - 8.0)
	info_panel.position = Vector2(x, maxf(8.0, y))

func hide_info() -> void:
	if info_panel.visible:
		_info_hide_ms = HudButton._now()
	info_panel.visible = false

func _info_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.94)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 8
	return sb

## Info card for the portrait (first selected entity) or a General-tray row under `p`.
func _info_at(p: Vector2) -> Array:
	if sel_panel.visible and sel_portrait.get_global_rect().has_point(p) and not ctl.selection.is_empty():
		var e := sim.get_ent(int(ctl.selection[0]))
		if e != null:
			if e.kind == SimEntity.Kind.UNIT:
				return [InfoCard.build("unit", e.def_id, sim, pid), sel_portrait.get_global_rect()]
			if e.kind == SimEntity.Kind.BUILDING or e.kind == SimEntity.Kind.NEUTRAL:
				return [InfoCard.build("building", e.def_id, sim, pid), sel_portrait.get_global_rect()]
	if tray.visible:
		for ti in _tray_info:
			var c: Control = ti[0]
			if is_instance_valid(c) and c.get_global_rect().has_point(p):
				return [InfoCard.build("power", StringName(ti[1]), sim, pid), c.get_global_rect()]
	return []

## Press-and-hold outside the command grid (portrait, tray rows). Grid buttons use HudButton.
func _input(ev: InputEvent) -> void:
	var down := false
	var up := false
	var pos := Vector2.ZERO
	if ev is InputEventScreenTouch and ev.index == 0:
		down = ev.pressed
		up = not ev.pressed
		pos = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		down = ev.pressed
		up = not ev.pressed
		pos = ev.position
	elif (ev is InputEventScreenDrag and ev.index == 0) or ev is InputEventMouseMotion:
		if _hold["on"] and not _hold["shown"] and ev.position.distance_to(_hold["pos"]) > 14.0:
			_hold["on"] = false
		return
	else:
		return
	if down:
		_hold = {"on": true, "t0": HudButton._now(), "pos": pos, "shown": false}
	elif up:
		var was: bool = _hold["shown"]
		_hold["on"] = false
		_hold["shown"] = false
		if was:
			hide_info()

func _hold_tick() -> void:
	if not _hold["on"] or _hold["shown"] or HudButton._now() - int(_hold["t0"]) < HudButton.HOLD_INFO_MS:
		return
	var r := _info_at(_hold["pos"])
	if r.is_empty():
		_hold["on"] = false
		return
	_hold["shown"] = true
	show_info(r[0], r[1])

## Tray / portrait taps right after a hold card closes are swallowed (release != buy).
func info_just_closed() -> bool:
	return HudButton._now() - _info_hide_ms < 250

func _on_grid(i: int, alt: bool) -> void:
	if i >= card.size():
		return
	var c: Dictionary = card[i]
	var f: Callable = c.get("alt" if alt else "act", Callable())
	if alt and not c.has("alt"):
		var tip: String = c.get("tip", "")
		if tip != "":
			toast(tip)
		return
	if c.get("disabled", false) and not alt:
		var why: String = c.get("tip", "")
		if why != "":
			toast(why)
		return
	if f.is_valid():
		f.call()
		_refresh_t = 0.0

func _make_card() -> Array:
	var out: Array = []
	if pid < 0:
		return out
	var e := ctl.primary()
	if e == null or not ctl.is_own(e):
		return out
	var units := ctl.own_units_selected()
	if e.kind == SimEntity.Kind.UNIT and not units.is_empty():
		var builders := ctl.constructors(units)
		var fe_only := ctl._filter(units, "builder").is_empty()   # M3.2: Field Engineers build barricades + minefields only
		if not builders.is_empty() and builders.size() == units.size():
			for bid in Content.building_order(sim.faction_of(pid)):
				var bd: BuildingDef = Content.building(bid)
				if not bd.buildable or bd.is_hq:
					continue
				if fe_only and not (bd.tags.has("barricade") or bd.tags.has("mine")):
					continue
				var why := sim.prereqs_met(pid, bd.prereqs)
				var lock := sim.build_lock(pid, bd)
				var funds: bool = sim.players[pid].supply >= bd.cost
				var block := lock if lock != "" else why
				out.append({"text": tr(bd.name_key), "sub": "$%d" % bd.cost,
					"act": ctl.begin_place.bind(bid), "disabled": block != "" or not funds,
					"tip": tr(bd.name_key) + (" — " + tr(lock) if lock != "" else (" — " + tr("HUD_NEEDS") % _prereq_names(bd.prereqs) if why != "" else (" — " + tr("REASON_FUNDS") if not funds else ""))),
					"accent": UiTheme.GOLD, "info": ["building", String(bid)]})
			var hvb := ctl._filter(units, "harvester")
			var tail := 2 if not hvb.is_empty() else 1
			# M2.4: more structures than slots -> the card pages (see _refresh_card); the
			# harvest / stop commands are pinned to the last slots on every page
			while out.size() < 10 - tail:
				out.append({"text": "", "disabled": true})
			if not hvb.is_empty():
				out.append({"text": tr("CMD_HARVEST"), "pin": true, "act": func():
					var r := ctl._nearest_resource(sim.ents[hvb[0]].pos)
					if r != 0:
						ctl.issue({"t": "harvest", "ids": hvb, "target": r})})
			out.append({"text": tr("CMD_STOP"), "pin": true, "act": ctl.simple.bind("stop")})
			return out
		var ops := ctl._filter(units, "drone_operator")
		if not ops.is_empty():   # M3.2: Drone Operator launches (one of each per operator, 60 s reload)
			for kd in [["bomb", "CMD_BOMB_DRONE", Color("#ff6a4a")], ["scout", "CMD_SCOUT_DRONE", Color("#6fe3ff")]]:
				var wait := 1 << 50
				var drone := &""
				for oid in ops:
					var dk := Content.operator_drone(sim.ents[oid].def_id, kd[0])   # M3.5: US scout only, Russia explosive only
					if dk != &"":
						drone = dk
						wait = mini(wait, sim.drone_wait(sim.ents[oid], kd[0]))
				if drone == &"":
					continue
				var busy := wait >= SimWorld.DRONE_BUSY / 2
				out.append({"text": tr(kd[1]), "sub": tr("CMD_DRONE_READY") if wait == 0 else ("—" if busy else "%ds" % ceili(wait / 20.0)),
					"disabled": wait > 0, "act": ctl.issue.bind({"t": "drone", "ids": ops, "kind": kd[0]}), "accent": kd[2],
					"tip": tr(Content.unit(drone).name_key + "_DESC"), "info": ["unit", String(drone)]})
		out.append({"text": tr("CMD_AMOVE"), "act": ctl.begin_target.bind("amove"), "accent": Color("#ff9a2a"), "tip": tr("CMD_AMOVE_TIP")})
		out.append({"text": tr("CMD_MOVE"), "act": ctl.begin_target.bind("move"), "accent": Color("#7dff8a")})
		out.append({"text": tr("CMD_STOP"), "act": ctl.simple.bind("stop")})
		out.append({"text": tr("CMD_GUARD"), "act": ctl.begin_target.bind("guard"), "accent": Color("#6fe3ff")})
		out.append({"text": tr("CMD_SCATTER"), "act": ctl.simple.bind("scatter")})
		var hv := ctl._filter(units, "harvester")
		if not hv.is_empty():
			out.append({"text": tr("CMD_HARVEST"), "act": func():
				var r := ctl._nearest_resource(sim.ents[hv[0]].pos)
				if r != 0:
					ctl.issue({"t": "harvest", "ids": hv, "target": r})})
		var mm := ctl._filter(units, "mobile_mine")
		if not mm.is_empty():   # M3.3 Phase 3: set the excavator up where it stands
			var me0: SimEntity = sim.ents[mm[0]]
			var up := MineSys.unpacking(me0)
			out.push_front({"text": tr("CMD_UNPACK_CANCEL") if up else tr("CMD_UNPACK"),
				"sub": tr("HUD_UNPACKING") % ceili(MineSys.ticks_left(sim, me0) / 20.0) if up else "",
				"act": func(): ctl.issue({"t": "unpack", "ids": mm}), "tip": tr("CMD_UNPACK_TIP"), "accent": Color("#7dff8a")})
		var ud := Content.unit(e.def_id)
		if units.size() > 1:
			# M4.2 mass unload: with several transports selected, one Unload empties them all
			var tr_ids: Array = []
			var n_all := 0
			var cap_all := 0
			for tid in units:
				var te: SimEntity = sim.ents.get(tid)
				if te != null and te.alive and Content.unit(te.def_id) != null and Content.unit(te.def_id).transport_capacity > 0:
					tr_ids.append(tid)
					n_all += RosterSys.load_of(sim, te)
					cap_all += Content.unit(te.def_id).transport_capacity
			if tr_ids.size() > 1:
				out.append({"text": tr("CMD_UNLOAD_ALL"), "sub": "%d / %d" % [n_all, cap_all], "disabled": n_all == 0,
					"act": func(): ctl.issue({"t": "unload", "ids": tr_ids}), "tip": tr("CMD_UNLOAD_ALL_TIP"), "accent": Color("#ffd166")})
		if ud.transport_capacity > 0 and units.size() == 1:
			var n_in := RosterSys.load_of(sim, e)
			out.append({"text": tr("CMD_UNLOAD"), "sub": "%d / %d" % [n_in, ud.transport_capacity], "disabled": n_in == 0,
				"act": func(): ctl.issue({"t": "unload", "ids": [e.id]}), "tip": tr("STUB_TRANSPORT"), "accent": Color("#ffd166")})
		return out
	if e.kind == SimEntity.Kind.NEUTRAL and e.owner == pid:
		var ng := 0
		for uid3 in sim.ids:
			if sim.ents[uid3].res_id == -e.id:
				ng += 1
		out.append({"text": tr("HUD_EVACUATE"), "sub": "%d / %d" % [ng, Content.building(e.def_id).garrison_capacity],
			"act": func(): ctl.issue({"t": "unload", "ids": [e.id]}), "accent": Color("#ffd166")})
		return out
	if e.kind != SimEntity.Kind.BUILDING:
		return out
	var bd2: BuildingDef = Content.building(e.def_id)
	if not e.built:
		out.append({"text": tr("CMD_RESUME_BUILD"), "act": resume_site.bind(e), "accent": Color("#7dff8a"), "tip": tr("CMD_RESUME_BUILD_TIP")})
		out.append({"text": tr("CMD_CANCEL_BUILD"), "act": func(): ctl.issue({"t": "cancel_build", "target": e.id}), "tip": tr("CMD_CANCEL_BUILD_TIP")})
		return out
	if bd2.produces.is_empty() and bd2.garrison_capacity > 0:   # M4.2: garrison structures keep a rally point
		out.append({"text": tr("CMD_RALLY"), "pin": true, "act": ctl.begin_target.bind("rally"), "accent": Color("#ffd166"),
			"alt": func(): ctl.issue({"t": "rally", "ids": [e.id], "clear": true})})
	if CommandSys.is_barricade(sim, e):   # M3.2: manned barricade -> troops step out
		var nb := 0
		for uid2 in sim.ids:
			if sim.ents[uid2].res_id == -e.id:
				nb += 1
		out.append({"text": tr("CMD_EXIT_BARRICADE"), "sub": "%d / %d" % [nb, bd2.garrison_capacity], "disabled": nb == 0,
			"act": func(): ctl.issue({"t": "unload", "ids": [e.id]}), "accent": Color("#ffd166")})
	if TplaSys.is_tunnel(sim, e):
		var inside := TplaSys.network_units(sim, pid).size()
		out.append({"text": tr("HUD_EVACUATE"), "sub": "%d / %d" % [inside, TplaSys.network_capacity()], "disabled": inside == 0,
			"act": func(): ctl.issue({"t": "unload", "ids": [e.id]}), "tip": tr("HUD_EVACUATE_TIP"), "accent": Color("#ffd166")})
	if MineSys.is_mobile_site(sim, e):   # M3.3 Phase 3: pack the excavator up to move it
		var pk := MineSys.packing(sim, e)
		out.append({"text": tr("CMD_PACK_CANCEL") if pk else tr("CMD_PACK"),
			"sub": tr("HUD_PACKING") % ceili(MineSys.ticks_left(sim, e) / 20.0) if pk else "",
			"act": func(): ctl.issue({"t": "pack", "target": e.id}), "tip": tr("CMD_PACK_TIP"), "accent": Color("#7dff8a")})
	if bd2.tags.has("trap"):
		out.append({"text": tr("HUD_DETONATE"), "act": func(): ctl.issue({"t": "detonate", "ids": [e.id]}), "accent": Color("#ff6a4a"), "tip": tr("HUD_DETONATE_TIP")})
	for uid in bd2.produces:
		var udf: UnitDef = Content.unit(uid)
		var why2 := sim.prereqs_met(pid, udf.prereqs)
		var n := e.queue.count(StringName(uid))
		var prog := -1.0
		if not e.queue.is_empty() and e.queue[0] == StringName(uid):
			prog = float(e.q_progress) / float(maxi(1, FX.ms_to_ticks(udf.build_time_ms) * 2))
		if udf.tags.has("upgrade"):   # M3.2: research (one-off)
			var done: bool = sim.players[pid].upgrades.has(String(uid))
			var queued := CommandSys.upgrade_queued(sim, pid, StringName(uid))
			out.append({"text": tr(udf.name_key), "sub": tr("HUD_RESEARCHED") if done else "$%d" % udf.cost, "badge": "",
				"act": ctl.queue_unit.bind(e, StringName(uid), 1), "alt": func(): ctl.dequeue(e, e.queue.rfind(StringName(uid))),
				"disabled": done or queued or why2 != "" or e.queue.size() >= ProdSys.MAX_QUEUE, "progress": prog,
				"tip": tr(udf.name_key + "_DESC"), "accent": Color("#6fe3ff"), "info": ["unit", String(uid)]})
			continue
		out.append({"text": tr(udf.name_key), "sub": "$%d" % udf.cost, "badge": str(n) if n > 0 else "",
			"act": ctl.queue_unit.bind(e, StringName(uid), 1), "alt": func(): ctl.dequeue(e, e.queue.rfind(StringName(uid))),
			"disabled": why2 != "" or e.queue.size() >= ProdSys.MAX_QUEUE or udf.tags.has("stub"), "progress": prog, "stub": not udf.stubs.is_empty(),
			"tip": tr(udf.name_key) + ("  [" + tr("HUD_LONGPRESS_CANCEL") + "]"), "accent": UiTheme.GOLD, "info": ["unit", String(uid)]})
	if not bd2.produces.is_empty():
		while out.size() < 5:
			out.append({"text": "", "disabled": true})
		out.append({"text": tr("CMD_RALLY"), "pin": true, "act": ctl.begin_target.bind("rally"), "accent": Color("#ffd166"),
			"alt": func(): ctl.issue({"t": "rally", "ids": [e.id], "clear": true})})
		out.append({"text": tr("CMD_LOOP_ON") if e.repeat else tr("CMD_LOOP"), "pin": true, "act": func(): ctl.issue({"t": "repeat", "target": e.id, "flag": not e.repeat}), "tip": tr("CMD_REPEAT_TIP")})
		out.append({"text": tr("CMD_CANCEL_LAST"), "pin": true, "act": func(): ctl.dequeue(e, -1), "disabled": e.queue.is_empty()})
	if CommandSys.can_sell(sim, pid, e) and ctl.selection.size() == 1:
		out.append(_sell_entry(e))
	return out

## M3.3: Sell for 70% - the first tap arms it ("Confirm?"), a second tap within 3 s sells.
var _sell_arm_id := -1
var _sell_arm_ms := 0
const SELL_CONFIRM_MS := 3000

func _sell_entry(e: SimEntity) -> Dictionary:
	var armed := _sell_arm_id == e.id and Time.get_ticks_msec() - _sell_arm_ms < SELL_CONFIRM_MS
	return {"text": tr("CMD_SELL_CONFIRM") if armed else tr("CMD_SELL"), "sub": "+" + _money_str(CommandSys.sell_value(sim, e)), "pin": true,
		"accent": Color("#ff6a4a"), "tip": tr("CMD_SELL_TIP"), "act": func(): sell_tap(e)}

func sell_tap(e: SimEntity) -> void:
	if _sell_arm_id == e.id and Time.get_ticks_msec() - _sell_arm_ms < SELL_CONFIRM_MS:
		_sell_arm_id = -1
		ctl.issue({"t": "sell", "target": e.id})
	else:
		_sell_arm_id = e.id
		_sell_arm_ms = Time.get_ticks_msec()
	_refresh_card()

const TYPE_MAX := 3
const QUEUE_MAX := 4
const QUEUE_CHIP := Vector2(59, 44)

## M3.2: "$2,000,000" with thousands separators; the font steps down for 7-digit amounts.
func _money(v: int) -> String:
	var t := _money_str(v)
	money_lbl.add_theme_font_size_override("font_size", 17 if t.length() <= 8 else 14)
	return t

func _money_str(v: int) -> String:
	var d := str(absi(v))
	var out := ""
	while d.length() > 3:
		out = "," + d.substr(d.length() - 3) + out
		d = d.substr(0, d.length() - 3)
	return ("-$" if v < 0 else "$") + d + out

func _hud_btn(caption: String, sz: Vector2) -> HudButton:
	var b := HudButton.new()
	b.custom_minimum_size = sz
	b.size = sz
	b.label_text = caption
	b.add_theme_font_size_override("font_size", 11)
	return b

func toggle_groups() -> void:
	groups_open = not groups_open
	for gb in group_btns:
		gb.visible = groups_open
	groups_btn.label_text = "‹" if groups_open else "›"
	_refresh_t = 0.0

func _resume_reserve() -> float:
	return 81.0 if resume_btn != null and resume_btn.visible else 0.0

## An unfinished own structure nobody is working on, nearest to the selected builders
## (Zero Hour: an interrupted build stays as a scaffold until a builder resumes it).
func resume_site_for(units: Array) -> SimEntity:
	var bl := ctl._filter(units, "builder")
	if bl.is_empty():
		return null
	var from: Vector2i = sim.ents[bl[0]].pos
	var busy := {}
	for id in sim.ids:
		var u: SimEntity = sim.ents[id]
		if u.alive and u.owner == pid and u.kind == SimEntity.Kind.UNIT and not u.orders.is_empty() and u.orders[0].get("o", "") == "build":
			busy[int(u.orders[0]["target"])] = true
	var best: SimEntity = null
	for id in sim.ids:
		var b: SimEntity = sim.ents[id]
		if b.alive and b.owner == pid and b.kind == SimEntity.Kind.BUILDING and not b.built and not busy.has(b.id):
			if best == null or FX.dist2(b.pos, from) < FX.dist2(best.pos, from):
				best = b
	return best

func resume_selected_builders() -> void:
	var units := ctl.own_units_selected()
	var site := resume_site_for(units)
	if site != null:
		ctl.issue({"t": "resume_build", "ids": ctl._filter(units, "builder"), "target": site.id})
		world.marker(site.pos, Color("#7dff8a"))

## Selected unfinished structure: send the nearest idle builder (else the nearest builder).
func resume_site(site: SimEntity) -> void:
	var best: SimEntity = null
	var best_idle := false
	for id in sim.ids:
		var u: SimEntity = sim.ents[id]
		if not u.alive or u.owner != pid or u.kind != SimEntity.Kind.UNIT or not Content.unit(u.def_id).tags.has("builder") or u.res_id < 0:
			continue
		var idle := u.is_idle() or (Content.unit(u.def_id).harvest_capacity > 0 and u.phase >= 0)
		if best == null or (idle and not best_idle) or (idle == best_idle and FX.dist2(u.pos, site.pos) < FX.dist2(best.pos, site.pos)):
			best = u
			best_idle = idle
	if best == null:
		toast(tr("REASON_NO_BUILDER"))
		return
	ctl.issue({"t": "resume_build", "ids": [best.id], "target": site.id})
	world.marker(site.pos, Color("#7dff8a"))

func _prereq_names(p: PackedStringArray) -> String:
	var n: Array = []
	for x in p:
		var b: BuildingDef = Content.building(x)
		if b != null:
			n.append(tr(b.name_key))
		else:
			var u: UnitDef = Content.unit(x)
			n.append(tr(u.name_key) if u != null else String(x))
	return ", ".join(n)

# ------------------------------------------------------------------ modes
func _on_mode() -> void:
	place_bar.visible = ctl.mode == PlayerController.Mode.PLACE
	place_confirm.visible = ctl.mode == PlayerController.Mode.PLACE
	if place_confirm.visible:
		place_confirm.set_valid(ctl.place_reason == "")
		_place_confirm_follow()
	target_bar.visible = ctl.mode == PlayerController.Mode.TARGET
	if ctl.mode == PlayerController.Mode.PLACE:
		place_reason.text = tr(ctl.place_reason) if ctl.place_reason != "" else ""
	if ctl.mode == PlayerController.Mode.TARGET:
		var k := ctl.target_kind
		target_lbl.text = tr("TARGET_" + (k.to_upper() if not k.begins_with("power:") else "POWER"))

func open_build() -> void:
	if pid < 0:
		return
	var b := ctl._filter(ctl.own_units_selected(), "builder")
	if b.is_empty():
		ctl.select_idle_builder()
		if ctl._filter(ctl.own_units_selected(), "builder").is_empty():
			toast(tr("REASON_NO_BUILDER"))

func toggle_tray() -> void:
	if not Content.GENERALS_ENABLED:
		tray.visible = false
		return
	tray.visible = not tray.visible
	if tray.visible:
		_fill_tray()

func _fill_tray() -> void:
	for c in tray_list.get_children():
		c.queue_free()
	_tray_info.clear()
	var p: SimPlayer = sim.players[pid]
	var nx: int = SimPlayer.RANK_XP[p.rank + 1] if p.rank + 1 < SimPlayer.RANK_XP.size() else -1
	tray_list.add_child(UiTheme.label(tr("TRAY_TITLE") % [p.rank, p.points, ("%d/%d" % [p.xp, nx]) if nx > 0 else str(p.xp)], 12, UiTheme.GOLD))
	for id in Content.powers_for(sim.faction_of(pid)):
		var d: PowerDef = Content.powers[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := UiTheme.label(tr(d.name_key) + ("  [STUB]" if d.stub else ""), 12)
		l.custom_minimum_size = Vector2(150, 0)
		l.tooltip_text = tr(d.desc_key)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var b := UiTheme.button("", Vector2(110, 48))
		b.add_theme_font_size_override("font_size", 11)
		_tray_info.append([l, String(id)])
		_tray_info.append([b, String(id)])
		var owned := p.powers.has(String(id))
		if d.stub:
			b.text = tr("TRAY_COMING")
			b.disabled = true
		elif not owned:
			var why := PowersSys.can_buy(sim, pid, id)
			b.text = tr("TRAY_BUY") % [d.rank_required, d.point_cost]
			b.disabled = why != ""
			b.pressed.connect(func():
				if info_just_closed():
					return
				ctl.issue({"t": "buy_power", "def": String(id)})
				_refresh_t = 0.0)
		else:
			var r := PowersSys.ready_in(sim, pid, id)
			if r > 0:
				b.text = tr("TRAY_COOLDOWN") % ceili(r / 20.0)
				b.disabled = true
			else:
				b.text = tr("TRAY_FIRE")
				b.pressed.connect(func():
					if info_just_closed():
						return
					tray.visible = false
					if d.radius > 0:
						ctl.begin_target("power:" + String(id))
					else:
						ctl.issue({"t": "power", "def": String(id), "pos": Vector2i.ZERO}))
		row.add_child(b)
		tray_list.add_child(row)

func toggle_pause() -> void:
	m.set_paused(not m.paused)

func show_pause_menu() -> void:
	if not pause_menu.visible:
		toggle_pause_menu()
	else:
		m.set_paused(true, true)

func toggle_pause_menu() -> void:
	pause_menu.visible = not pause_menu.visible
	if pause_menu.visible:
		_update_pause_menu()
		show_save_slots(false)
		m.set_paused(true, true)
	else:
		m.set_paused(false, true)

func jump_last_alert() -> void:
	if last_alert_pos.x >= 0:
		cam.jump_to(FX.to_world(last_alert_pos))
		back_btn.visible = true

# ------------------------------------------------------------------ alerts / toasts
func toast(text: String) -> void:
	toast_lbl.text = text
	_toast_t = 2.5

func alert(key: String, text: String, pos: Vector2i, throttle_s: float = 8.0) -> void:
	var now := Time.get_ticks_msec()
	var tk := key + str(FX.to_tile(pos) / 16)
	if now - int(_throttle.get(tk, -100000)) < throttle_s * 1000.0:
		return
	_throttle[tk] = now
	last_alert_pos = pos
	# one live alert per kind: a newer one replaces the older (no stacked duplicates)
	for a: Dictionary in alerts.duplicate():
		if a.get("key", "") == key:
			alerts.erase(a)
			blockers.erase(a["node"])
			a["node"].queue_free()
	var b := UiTheme.button(text, Vector2(144, 40))   # width -10%; height stays 40 (was already below the floor; alerts are a secondary tap)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	# M3.3 (Malachi: "Base notifications - no backing, just text"): no box, outlined text (still tappable)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(fc, Color("#ffe08a"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	b.set_meta("text_only", true)
	b.pressed.connect(func():
		cam.jump_to(FX.to_world(pos))
		back_btn.visible = true)
	alerts_box.add_child(b)
	blockers.append(b)
	alerts.append({"node": b, "t": 6.0, "key": key})
	if alerts.size() > 3:
		var old: Dictionary = alerts.pop_front()
		blockers.erase(old["node"])
		old["node"].queue_free()
	if pos.x >= 0:
		minimap.ping(Vector2(FX.to_world(pos).x, FX.to_world(pos).z))
	EventBus.alert_raised.emit(key, text, pos)

func on_events(events: Array) -> void:
	if pid < 0:
		return
	var my_team := sim.player_team(pid)
	for ev in events:
		match ev["t"]:
			"attacked":
				if int(ev["owner"]) == pid:
					var e := sim.get_ent(int(ev["id"]))
					if e != null:
						var is_b := e.kind != SimEntity.Kind.UNIT
						alert("attacked_b" if is_b else "attacked_u", tr("ALERT_BASE_ATTACK") if is_b else tr("ALERT_UNITS_ATTACK"), e.pos, 10.0 if is_b else 15.0)
						if is_b:
							AudioDirector.announce("base_under_attack")
						elif not AudioDirector.unit_voice(String(Content.unit(e.def_id).faction), String(e.def_id), "under_fire"):
							AudioDirector.announce("units_under_attack")
			"built":
				if int(ev["owner"]) == pid:
					var b := sim.get_ent(int(ev["id"]))
					if b != null:
						alert("built" + str(b.id), tr("ALERT_BUILT") % ent_name(b), b.pos, 1.0)
						AudioDirector.ui("build_ready")
						AudioDirector.announce("construction_complete")
			"spawn":
				var u := sim.get_ent(int(ev["id"]))
				if u != null and u.owner == pid and u.kind == SimEntity.Kind.UNIT and sim.tick > 5:
					toast(tr("ALERT_UNIT_READY") % ent_name(u))
					if not AudioDirector.unit_voice(String(Content.unit(u.def_id).faction), String(u.def_id), "created"):
						AudioDirector.announce("unit_ready")
			"low_power":
				if int(ev["owner"]) == pid and ev["on"]:
					alert("lowpower", tr("ALERT_LOW_POWER"), Vector2i(-1, -1), 20.0)
					AudioDirector.announce("low_power")
			"rank":
				if int(ev["owner"]) == pid and Content.GENERALS_ENABLED:
					alert("rank", tr("ALERT_RANK") % int(ev["rank"]), Vector2i(-1, -1), 0.5)
					AudioDirector.announce("general_promoted")
			"eliminated":
				var o := int(ev["owner"])
				alert("elim%d" % o, tr("ALERT_ELIMINATED") % (o + 1) if sim.player_team(o) != my_team or o != pid else tr("ALERT_YOU_ELIMINATED"), Vector2i(-1, -1), 0.5)
				AudioDirector.announce("you_eliminated" if o == pid else "player_eliminated")
			"reject":
				if int(ev["owner"]) == pid:
					toast(tr(String(ev["reason"])))
					AudioDirector.ui("error")
					var rs := String(ev["reason"])
					if rs == "REASON_FUNDS":
						AudioDirector.announce("insufficient_funds")
					elif rs in ["REASON_TERRAIN", "REASON_BLOCKED", "REASON_SHROUD", "REASON_UNREACHABLE", "REASON_ENEMY", "REASON_RESOURCE"]:
						AudioDirector.announce("cannot_build")
			"jtac_call":
				if int(ev["owner"]) == pid:
					alert("jtac", tr("ALERT_AIR_SUPPORT"), ev["pos"], 8.0)
					AudioDirector.announce("air_support")
			"captured":
				if int(ev["owner"]) == pid:
					var c := sim.get_ent(int(ev["id"]))
					if c != null:
						alert("cap", tr("ALERT_CAPTURED"), c.pos, 2.0)
						AudioDirector.announce("building_captured")
			"promoted":
				var pu := sim.get_ent(int(ev["id"]))
				if pu != null and pu.owner == pid:
					toast(tr("ALERT_PROMOTED") % [ent_name(pu), tr("VET_%d" % int(ev["vet"]))])
					if pu.kind != SimEntity.Kind.UNIT or not AudioDirector.unit_voice(String(Content.unit(pu.def_id).faction), String(pu.def_id), "veteran"):
						AudioDirector.announce("unit_promoted")
			"salvage":
				var su := sim.get_ent(int(ev["id"]))
				if su != null and su.owner == pid:
					toast(tr("ALERT_SALVAGE") % [ent_name(su), int(ev["tier"])])
					AudioDirector.announce("salvage_upgrade")
			"mine_moved":   # M3.3 Phase 3: the mine became a vehicle (or a structure again) - keep it selected
				if int(ev["owner"]) == pid and ctl.selection.has(int(ev["from"])):
					var ns: Array = ctl.selection.duplicate()
					ns[ns.find(int(ev["from"]))] = int(ev["to"])
					ctl.set_selection(ns)
					_refresh_t = 0.0
			"mine_unpack":
				if ev.has("why") and sim.get_ent(int(ev["id"])) != null and sim.get_ent(int(ev["id"])).owner == pid:
					toast(tr(String(ev["why"])))
			"hole_rebuild":
				if int(ev["owner"]) == pid:
					AudioDirector.announce("hole_rebuild")
			"explode":
				if int(ev.get("owner", -1)) == pid and ev.get("trap", false):
					AudioDirector.announce("trap_detonated")
			"death":
				if int(ev.get("owner", -1)) == pid and ev["kind"] == SimEntity.Kind.BUILDING and Content.btag(StringName(ev.get("def", "")), "tunnel") and not ev.get("silent", false):
					AudioDirector.announce("tunnel_lost")
			"power_fired":
				if int(ev["owner"]) != pid and Content.GENERALS_ENABLED and sim.enemies(sim.player_team(int(ev["owner"])), my_team) and float(ev["r"]) > 0:
					alert("enemy_power", tr("ALERT_ENEMY_POWER"), ev["pos"], 10.0)
					AudioDirector.announce("enemy_power_detected")
