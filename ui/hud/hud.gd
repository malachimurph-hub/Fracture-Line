class_name Hud
extends CanvasLayer
## Zero Hour-style command bar adapted for touch (GDD 7 + ZH steering): bottom bar with
## minimap (left), selection portrait/info, 2x5 command grid, money/power/pop/rank panel;
## top strip with filters, 5 control groups, clock, pause and menu; alerts with jump/Back;
## placement Confirm/Rotate/Cancel; General powers tray; pause menu. All sizes in dp.

const BAR_H := 112.0
const BTN := Vector2(54, 50)

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
var power_bar: ProgressBar
var pop_lbl: Label
var rank_lbl: Label
var general_btn: Button
var build_btn: Button
var top: HBoxContainer
var group_btns: Array = []
var clock_lbl: Label
var pause_btn: Button
var alerts_box: VBoxContainer
var back_btn: Button
var place_bar: HBoxContainer
var place_reason: Label
var target_bar: HBoxContainer
var target_lbl: Label
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
	root.theme = UiTheme.get_theme()
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
	bar = Panel.new()
	bar.add_theme_stylebox_override("panel", UiTheme.box(Color(0.09, 0.10, 0.12, 0.96), UiTheme.GOLD, 1, 6))
	root.add_child(bar)
	blockers.append(bar)
	minimap = Minimap.new()
	minimap.setup(world, cam, ctl)
	bar.add_child(minimap)
	# selection panel
	sel_panel = Control.new()
	bar.add_child(sel_panel)
	sel_portrait = Control.new()
	sel_portrait.custom_minimum_size = Vector2(44, 44)
	sel_portrait.draw.connect(_draw_portrait)
	sel_panel.add_child(sel_portrait)
	sel_name = UiTheme.label("", 14, UiTheme.GOLD)
	sel_panel.add_child(sel_name)
	sel_info = UiTheme.label("", 11)
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
		b.add_theme_font_size_override("font_size", 11)
		b.primary.connect(_on_grid.bind(i, false))
		b.secondary.connect(_on_grid.bind(i, true))
		grid.add_child(b)
		grid_buttons.append(b)
	# resources panel
	var rp := VBoxContainer.new()
	rp.name = "Res"
	rp.add_theme_constant_override("separation", 2)
	bar.add_child(rp)
	money_lbl = UiTheme.label("$0", 17, Color("#ffd166"))
	rp.add_child(money_lbl)
	power_bar = ProgressBar.new()
	power_bar.show_percentage = false
	power_bar.custom_minimum_size = Vector2(110, 8)
	rp.add_child(power_bar)
	power_lbl = UiTheme.label("", 11)
	rp.add_child(power_lbl)
	pop_lbl = power_lbl
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	rp.add_child(row)
	general_btn = UiTheme.button(tr("HUD_GENERAL"), Vector2(86, 48))
	general_btn.add_theme_font_size_override("font_size", 11)
	general_btn.pressed.connect(toggle_tray)
	row.add_child(general_btn)
	build_btn = UiTheme.button(tr("HUD_BUILD"), Vector2(56, 48))
	build_btn.add_theme_font_size_override("font_size", 11)
	build_btn.pressed.connect(open_build)
	row.add_child(build_btn)
	rank_lbl = UiTheme.label("", 11, UiTheme.CYAN)
	# top strip
	top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)
	var army := UiTheme.button(tr("HUD_ARMY"), Vector2(56, 44))
	army.add_theme_font_size_override("font_size", 11)
	army.pressed.connect(ctl.select_all_army)
	top.add_child(army)
	var idle := UiTheme.button(tr("HUD_IDLE_CRAWLER"), Vector2(64, 44))
	idle.add_theme_font_size_override("font_size", 11)
	idle.pressed.connect(ctl.select_idle_builder)
	top.add_child(idle)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(8, 1)
	top.add_child(sp)
	for i in 5:
		var gb := HudButton.new()
		gb.custom_minimum_size = Vector2(48, 44)
		gb.text = str(i + 1)
		gb.primary.connect(func(): if not ctl.group_select(i): toast(tr("HUD_GROUP_HINT")))
		gb.secondary.connect(func(): ctl.group_assign(i))
		top.add_child(gb)
		group_btns.append(gb)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fill)
	clock_lbl = UiTheme.label("00:00", 14)
	top.add_child(clock_lbl)
	pause_btn = UiTheme.button("II", Vector2(48, 44))
	pause_btn.pressed.connect(toggle_pause)
	top.add_child(pause_btn)
	var menu_btn := UiTheme.button("Menu", Vector2(64, 44))
	menu_btn.pressed.connect(toggle_pause_menu)
	top.add_child(menu_btn)
	for c in [army, idle, pause_btn, menu_btn] + group_btns:
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
	var cancel := UiTheme.button(tr("HUD_CANCEL"), Vector2(64, 56))
	cancel.pressed.connect(ctl.cancel_mode)
	place_bar.add_child(cancel)
	var ok := UiTheme.button(tr("HUD_CONFIRM"), Vector2(84, 56))
	ok.add_theme_color_override("font_color", Color("#9dff9a"))
	ok.pressed.connect(func(): ctl.confirm_place())
	place_bar.add_child(ok)
	root.add_child(place_bar)
	blockers.append(place_bar)
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
	paused_lbl = UiTheme.label(tr("HUD_PAUSED"), 22, Color("#ffd166"))
	paused_lbl.visible = false
	paused_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paused_lbl)
	perf_lbl = UiTheme.label("", 11, Color(0.7, 1, 0.7))
	perf_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(perf_lbl)
	_build_pause_menu()

func _build_pause_menu() -> void:
	pause_menu = ColorRect.new()
	(pause_menu as ColorRect).color = Color(0, 0, 0, 0.55)
	pause_menu.visible = false
	root.add_child(pause_menu)
	var pc := PanelContainer.new()
	pc.name = "P"
	pause_menu.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(UiTheme.label(tr("PAUSE_TITLE"), 20, UiTheme.GOLD))
	var items := [["PAUSE_RESUME", func(): toggle_pause_menu()],
		["PAUSE_SPEED", func(): m.cycle_speed(); _update_pause_menu()],
		["PAUSE_HEALTHBARS", func(): Settings.s("always_health_bars", not Settings.g("always_health_bars")); _update_pause_menu()],
		["PAUSE_PERF", func(): Settings.s("perf_overlay", not Settings.g("perf_overlay")); _update_pause_menu()],
		["PAUSE_RESTART", func(): m.restart()],
		["PAUSE_SURRENDER", func(): m.surrender()],
		["PAUSE_QUIT", func(): m.quit_to_menu()]]
	for it in items:
		var b := UiTheme.button(tr(it[0]), Vector2(240, 48))
		b.name = it[0]
		b.pressed.connect(it[1])
		v.add_child(b)

func _update_pause_menu() -> void:
	var v := pause_menu.get_node("P").get_child(0)
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
	bar.position = Vector2(sr.position.x, sr.end.y - bh)
	bar.size = Vector2(sr.size.x, bh)
	var pad := 4.0
	minimap.position = Vector2(pad, pad)
	minimap.size = Vector2(bh - pad * 2, bh - pad * 2)
	var res_w := 150.0
	var grid_w := BTN.x * 5 + 12
	var res: Control = bar.get_node("Res")
	res.position = Vector2(bar.size.x - res_w - pad, pad)
	res.size = Vector2(res_w, bh - pad * 2)
	grid.position = Vector2(res.position.x - grid_w - pad, pad + 2)
	var sx := minimap.position.x + minimap.size.x + 8
	var sw := grid.position.x - sx - 8
	sel_panel.position = Vector2(sx, pad)
	sel_panel.size = Vector2(sw, bh - pad * 2)
	sel_portrait.position = Vector2(0, 2)
	sel_name.position = Vector2(50, 0)
	sel_name.size = Vector2(sw - 50, 20)
	sel_info.position = Vector2(50, 20)
	sel_info.size = Vector2(sw - 50, 44)
	sel_types.position = Vector2(0, 54)
	queue_box.position = Vector2(0, 62)
	top.position = sr.position + Vector2(4, 4)
	top.size = Vector2(sr.size.x - 8, 44)
	alerts_box.position = sr.position + Vector2(6, 54)
	alerts_box.size = Vector2(minf(320, sr.size.x * 0.4), 10)
	back_btn.position = sr.position + Vector2(6, sr.size.y - bh - 56)
	toast_lbl.position = Vector2(sr.position.x, sr.end.y - bh - 34)
	toast_lbl.size = Vector2(sr.size.x, 24)
	place_bar.position = Vector2(sr.end.x - 360, sr.end.y - bh - 64)
	place_bar.size = Vector2(352, 56)
	place_bar.alignment = BoxContainer.ALIGNMENT_END
	target_bar.position = Vector2(sr.position.x + sr.size.x * 0.5 - 140, sr.position.y + 54)
	tray.position = Vector2(sr.end.x - 300, sr.end.y - bh - 8 - 220)
	tray.size = Vector2(292, 220)
	paused_lbl.position = Vector2(sr.position.x + sr.size.x * 0.5 - 50, sr.position.y + 100)
	perf_lbl.position = sr.position + Vector2(sr.size.x - 210, 52)
	pause_menu.position = Vector2.ZERO
	pause_menu.size = root.size
	var pc: Control = pause_menu.get_node("P")
	pc.position = root.size * 0.5 - Vector2(130, 210)

## True when a screen point (logical units) is over HUD chrome - world input ignores it.
func blocks(p: Vector2) -> bool:
	if pause_menu.visible:
		return true
	for b in blockers:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(p):
			return true
	return false

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if sim == null:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_lbl.text = ""
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
			a["node"].queue_free()
	alerts = keep

func _refresh() -> void:
	ctl.prune()
	var secs := sim.tick / 20
	clock_lbl.text = "%02d:%02d" % [secs / 60, secs % 60]
	paused_lbl.visible = m.paused
	pause_btn.text = ">" if m.paused else "II"
	for i in 5:
		var gb: HudButton = group_btns[i]
		gb.badge = str(ctl.groups[i].size()) if not ctl.groups[i].is_empty() else ""
		gb.queue_redraw()
	if pid < 0:
		money_lbl.text = tr("HUD_OBSERVER")
		power_lbl.text = ""
		pop_lbl.text = ""
		rank_lbl.text = ""
		general_btn.disabled = true
		build_btn.disabled = true
	else:
		var p: SimPlayer = sim.players[pid]
		money_lbl.text = "$%d" % p.supply
		power_bar.max_value = maxi(1, maxi(p.power_prod, p.power_used))
		power_bar.value = p.power_used
		power_bar.modulate = Color("#ff5a4a") if p.low_power else Color("#6fe3ff")
		power_lbl.text = tr("HUD_POWER") % [p.power_used, p.power_prod] + (" " + tr("HUD_LOW_POWER") if p.low_power else "") + "  " + tr("HUD_POP") % [p.pop, p.pop_cap]
		power_lbl.add_theme_color_override("font_color", Color("#ff7a6a") if p.low_power else UiTheme.TEXT)
		var next: int = SimPlayer.RANK_XP[p.rank + 1] if p.rank + 1 < SimPlayer.RANK_XP.size() else -1
		rank_lbl.text = tr("HUD_RANK") % p.rank + ("  XP %d/%d" % [p.xp, next] if next > 0 else "  XP %d" % p.xp)
		general_btn.text = tr("HUD_GENERAL_RANK") % p.rank + (" +%d" % p.points if p.points > 0 else "")
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
	sel_portrait.draw_circle(s * 0.5, s.x * 0.36, col.darkened(0.3))
	sel_portrait.draw_string(f, Vector2(2, s.y * 0.5 + 6), short_name(e.def_id), HORIZONTAL_ALIGNMENT_CENTER, s.x - 4, 15, Color.WHITE)

func short_name(def_id: StringName) -> String:
	var k := "SHORT_" + String(def_id).to_upper()
	var t := tr(k)
	return t if t != k else String(def_id).substr(3, 3).to_upper()

func ent_name(e: SimEntity) -> String:
	match e.kind:
		SimEntity.Kind.UNIT:
			return tr(Content.unit(e.def_id).name_key)
		SimEntity.Kind.RESOURCE:
			return tr("RES_" + String(e.def_id).to_upper())
	return tr(Content.building(e.def_id).name_key)

func _refresh_selection_info() -> void:
	sel_portrait.queue_redraw()
	var e := ctl.primary()
	for c in queue_box.get_children():
		c.queue_free()
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
	if e.kind == SimEntity.Kind.RESOURCE:
		lines.append(tr("HUD_SUPPLY_LEFT") % e.amount)
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
		if ud.harvest_capacity > 0:
			lines.append(tr("HUD_CARRY") % [e.carry, ud.harvest_capacity])
		if not ud.stubs.is_empty():
			lines.append("[STUB] " + ", ".join(Array(ud.stubs)))
		if e.owner == pid:
			lines.append(_unit_state(e))
	elif e.kind == SimEntity.Kind.BUILDING:
		var bd := Content.building(e.def_id)
		if not e.built:
			lines.append(tr("HUD_CONSTRUCTING") % int(100.0 * e.progress / maxi(1, e.build_ticks)))
		elif e.owner == pid:
			if not e.powered:
				lines.append(tr("HUD_UNPOWERED"))
			if bd.power != 0:
				lines.append(tr("HUD_BLD_POWER") % bd.power)
			if e.hold_reason != "":
				lines.append(tr(e.hold_reason))
			_fill_queue(e)
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

func _fill_types(units: Array) -> void:
	for c in sel_types.get_children():
		c.queue_free()
	if units.is_empty():
		return
	var counts := {}
	for id in units:
		var d: StringName = sim.ents[id].def_id
		counts[d] = counts.get(d, 0) + 1
	for d in counts:
		var b := UiTheme.button("%s×%d" % [short_name(d), counts[d]], Vector2(48, 48))
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func():
			var only: Array = []
			for id in ctl.own_units_selected():
				if sim.ents[id].def_id == d:
					only.append(id)
			ctl.set_selection(only))
		sel_types.add_child(b)
		if sel_types.get_child_count() >= 4:
			break

func _fill_queue(b: SimEntity) -> void:
	if b.queue.is_empty():
		return
	for i in mini(b.queue.size(), 5):
		var q := HudButton.new()
		q.custom_minimum_size = Vector2(40, 40)
		q.text = short_name(b.queue[i])
		q.add_theme_font_size_override("font_size", 10)
		if i == 0:
			var need := FX.ms_to_ticks(Content.unit(b.queue[0]).build_time_ms) * 2
			q.progress = float(b.q_progress) / float(maxi(1, need))
		var idx := i
		q.primary.connect(func(): ctl.dequeue(b, idx))
		q.tooltip_text = tr("HUD_TAP_CANCEL")
		queue_box.add_child(q)
	if b.queue.size() > 5:
		queue_box.add_child(UiTheme.label("+%d" % (b.queue.size() - 5), 11))

# ------------------------------------------------------------------ command card
## Each card entry: {id, text, sub, act, alt, disabled, badge, stub, accent, tip}
var card: Array = []

func _refresh_card() -> void:
	card = _make_card()
	for i in 10:
		var b: HudButton = grid_buttons[i]
		if i < card.size():
			var c: Dictionary = card[i]
			b.visible = true
			b.text = c.get("text", "")
			b.sub = c.get("sub", "")
			b.disabled = c.get("disabled", false)
			b.badge = c.get("badge", "")
			b.stub = c.get("stub", false)
			b.progress = c.get("progress", -1.0)
			b.accent = c.get("accent", Color(0, 0, 0, 0))
			b.tooltip_text = c.get("tip", "")
			b.modulate = Color(1, 1, 1, 1) if not b.disabled else Color(1, 1, 1, 0.75)
		else:
			b.visible = true
			b.text = ""
			b.sub = ""
			b.badge = ""
			b.stub = false
			b.progress = -1.0
			b.accent = Color(0, 0, 0, 0)
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.25)
		b.queue_redraw()

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
		var builders := ctl._filter(units, "builder")
		if not builders.is_empty() and builders.size() == units.size():
			for bid in Content.BUILDING_ORDER:
				var bd: BuildingDef = Content.building(bid)
				if not bd.buildable or bd.is_hq:
					continue
				var why := sim.prereqs_met(pid, bd.prereqs)
				var funds: bool = sim.players[pid].supply >= bd.cost
				out.append({"text": short_name(bid), "sub": "$%d" % bd.cost,
					"act": ctl.begin_place.bind(bid), "disabled": why != "" or not funds,
					"tip": tr(bd.name_key) + (" — " + tr("HUD_NEEDS") % _prereq_names(bd.prereqs) if why != "" else (" — " + tr("REASON_FUNDS") if not funds else "")),
					"accent": UiTheme.GOLD})
			while out.size() < 9:
				out.append({"text": "", "disabled": true})
			out.append({"text": tr("CMD_STOP"), "act": ctl.simple.bind("stop")})
			return out
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
		var ud := Content.unit(e.def_id)
		if ud.stubs.has("transport"):
			out.append({"text": tr("CMD_LOAD"), "stub": true, "disabled": true, "tip": tr("STUB_TRANSPORT")})
		return out
	if e.kind == SimEntity.Kind.NEUTRAL and e.owner == pid:
		out.append({"text": tr("CMD_UNLOAD"), "act": func(): ctl.issue({"t": "unload", "ids": [e.id]})})
		return out
	if e.kind != SimEntity.Kind.BUILDING:
		return out
	var bd2: BuildingDef = Content.building(e.def_id)
	if not e.built:
		out.append({"text": tr("CMD_CANCEL_BUILD"), "act": func(): ctl.issue({"t": "cancel_build", "target": e.id}), "tip": tr("CMD_CANCEL_BUILD_TIP")})
		return out
	for uid in bd2.produces:
		var udf: UnitDef = Content.unit(uid)
		var why2 := sim.prereqs_met(pid, udf.prereqs)
		var n := e.queue.count(StringName(uid))
		var prog := -1.0
		if not e.queue.is_empty() and e.queue[0] == StringName(uid):
			prog = float(e.q_progress) / float(maxi(1, FX.ms_to_ticks(udf.build_time_ms) * 2))
		out.append({"text": short_name(uid), "sub": "$%d" % udf.cost, "badge": str(n) if n > 0 else "",
			"act": ctl.queue_unit.bind(e, StringName(uid), 1), "alt": func(): ctl.dequeue(e, e.queue.rfind(StringName(uid))),
			"disabled": why2 != "" or e.queue.size() >= 9, "progress": prog, "stub": not udf.stubs.is_empty(),
			"tip": tr(udf.name_key) + ("  [" + tr("HUD_LONGPRESS_CANCEL") + "]"), "accent": UiTheme.GOLD})
	if not bd2.produces.is_empty():
		while out.size() < 5:
			out.append({"text": "", "disabled": true})
		out.append({"text": tr("CMD_RALLY"), "act": ctl.begin_target.bind("rally"), "accent": Color("#ffd166"),
			"alt": func(): ctl.issue({"t": "rally", "ids": [e.id], "clear": true})})
		out.append({"text": "Loop" + (" ON" if e.repeat else ""), "act": func(): ctl.issue({"t": "repeat", "target": e.id, "flag": not e.repeat}), "tip": tr("CMD_REPEAT_TIP")})
		out.append({"text": tr("CMD_CANCEL_LAST"), "act": func(): ctl.dequeue(e, -1), "disabled": e.queue.is_empty()})
	return out

func _prereq_names(p: PackedStringArray) -> String:
	var n: Array = []
	for x in p:
		n.append(tr(Content.building(x).name_key))
	return ", ".join(n)

# ------------------------------------------------------------------ modes
func _on_mode() -> void:
	place_bar.visible = ctl.mode == PlayerController.Mode.PLACE
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
	tray.visible = not tray.visible
	if tray.visible:
		_fill_tray()

func _fill_tray() -> void:
	for c in tray_list.get_children():
		c.queue_free()
	var p: SimPlayer = sim.players[pid]
	var nx: int = SimPlayer.RANK_XP[p.rank + 1] if p.rank + 1 < SimPlayer.RANK_XP.size() else -1
	tray_list.add_child(UiTheme.label(tr("TRAY_TITLE") % [p.rank, p.points, ("%d/%d" % [p.xp, nx]) if nx > 0 else str(p.xp)], 12, UiTheme.GOLD))
	for id in Content.power_order:
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
		var owned := p.powers.has(String(id))
		if d.stub:
			b.text = tr("TRAY_COMING")
			b.disabled = true
		elif not owned:
			var why := PowersSys.can_buy(sim, pid, id)
			b.text = tr("TRAY_BUY") % [d.rank_required, d.point_cost]
			b.disabled = why != ""
			b.pressed.connect(func(): ctl.issue({"t": "buy_power", "def": String(id)}); _refresh_t = 0.0)
		else:
			var r := PowersSys.ready_in(sim, pid, id)
			if r > 0:
				b.text = tr("TRAY_COOLDOWN") % ceili(r / 20.0)
				b.disabled = true
			else:
				b.text = tr("TRAY_FIRE")
				b.pressed.connect(func():
					tray.visible = false
					if d.radius > 0:
						ctl.begin_target("power:" + String(id))
					else:
						ctl.issue({"t": "power", "def": String(id), "pos": Vector2i.ZERO}))
		row.add_child(b)
		tray_list.add_child(row)

func toggle_pause() -> void:
	m.set_paused(not m.paused)

func toggle_pause_menu() -> void:
	pause_menu.visible = not pause_menu.visible
	if pause_menu.visible:
		_update_pause_menu()
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
	var b := UiTheme.button(text, Vector2(160, 40))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func():
		cam.jump_to(FX.to_world(pos))
		back_btn.visible = true)
	alerts_box.add_child(b)
	blockers.append(b)
	alerts.append({"node": b, "t": 6.0})
	if alerts.size() > 3:
		var old: Dictionary = alerts.pop_front()
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
			"built":
				if int(ev["owner"]) == pid:
					var b := sim.get_ent(int(ev["id"]))
					if b != null:
						alert("built" + str(b.id), tr("ALERT_BUILT") % ent_name(b), b.pos, 1.0)
			"spawn":
				var u := sim.get_ent(int(ev["id"]))
				if u != null and u.owner == pid and u.kind == SimEntity.Kind.UNIT and sim.tick > 5:
					toast(tr("ALERT_UNIT_READY") % ent_name(u))
			"low_power":
				if int(ev["owner"]) == pid and ev["on"]:
					alert("lowpower", tr("ALERT_LOW_POWER"), Vector2i(-1, -1), 20.0)
			"rank":
				if int(ev["owner"]) == pid:
					alert("rank", tr("ALERT_RANK") % int(ev["rank"]), Vector2i(-1, -1), 0.5)
			"eliminated":
				var o := int(ev["owner"])
				alert("elim%d" % o, tr("ALERT_ELIMINATED") % (o + 1) if sim.player_team(o) != my_team or o != pid else tr("ALERT_YOU_ELIMINATED"), Vector2i(-1, -1), 0.5)
			"reject":
				if int(ev["owner"]) == pid:
					toast(tr(String(ev["reason"])))
			"captured":
				if int(ev["owner"]) == pid:
					var c := sim.get_ent(int(ev["id"]))
					if c != null:
						alert("cap", tr("ALERT_CAPTURED"), c.pos, 2.0)
			"promoted":
				var pu := sim.get_ent(int(ev["id"]))
				if pu != null and pu.owner == pid:
					toast(tr("ALERT_PROMOTED") % [ent_name(pu), tr("VET_%d" % int(ev["vet"]))])
			"power_fired":
				if int(ev["owner"]) != pid and sim.enemies(sim.player_team(int(ev["owner"])), my_team) and float(ev["r"]) > 0:
					alert("enemy_power", tr("ALERT_ENEMY_POWER"), ev["pos"], 10.0)
