extends ScreenBase
## Settings: touch thresholds, UI scale, ghost offset, render scale, fps cap, toggles.

func build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	body.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := UiTheme.button("‹ " + tr("BACK"), Vector2(80, 44))
	back.pressed.connect(go_back)
	head.add_child(back)
	head.add_child(UiTheme.label("  " + tr("MENU_SETTINGS"), 22, UiTheme.GOLD))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	sc.add_child(cols)
	var a := VBoxContainer.new()
	var b := VBoxContainer.new()
	cols.add_child(a)
	cols.add_child(b)
	_slider(a, "SET_UI_SCALE", "ui_scale", 0.8, 1.4, 0.05)
	_slider(a, "SET_HOLD_MS", "hold_ms", 250, 600, 25)
	_slider(a, "SET_DOUBLE_TAP", "double_tap_ms", 200, 450, 25)
	_slider(a, "SET_DEADZONE", "drag_deadzone_dp", 6, 20, 1)
	_slider(a, "SET_GHOST_OFFSET", "ghost_offset_mm", 0, 20, 1)
	_slider(b, "SET_RENDER_SCALE", "render_scale", 0.5, 1.0, 0.05)
	_choice(b, "SET_FPS", "fps_cap", [30, 60, 120])
	_choice(b, "SET_HOLD_ACTION", "hold_action", ["attack_move", "move"])
	_toggle(b, "SET_HAPTICS", "haptics")
	_toggle(b, "SET_INERTIA", "camera_inertia")
	_toggle(b, "PAUSE_HEALTHBARS", "always_health_bars")
	_toggle(b, "PAUSE_PERF", "perf_overlay")
	if not UiScale.is_mobile():
		_toggle(b, "SET_EDGE_PAN", "edge_pan")

func _slider(p: Control, key: String, sk: String, lo: float, hi: float, step: float) -> void:
	var l := UiTheme.label("", 12)
	p.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.g(sk))
	s.custom_minimum_size = Vector2(260, 36)
	var upd := func(val): l.text = "%s: %s" % [tr(key), str(snappedf(val, step))]
	upd.call(s.value)
	s.value_changed.connect(upd)
	s.drag_ended.connect(func(_c): Settings.s(sk, int(s.value) if step >= 1.0 else s.value))
	p.add_child(s)

func _choice(p: Control, key: String, sk: String, opts: Array) -> void:
	p.add_child(UiTheme.label(tr(key), 12))
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(200, 44)
	for x in opts:
		o.add_item(tr("OPT_" + str(x).to_upper()) if x is String else str(x))
	o.selected = maxi(0, opts.find(Settings.g(sk)))
	o.item_selected.connect(func(i): Settings.s(sk, opts[i]))
	p.add_child(o)

func _toggle(p: Control, key: String, sk: String) -> void:
	var c := CheckButton.new()
	c.text = tr(key)
	c.button_pressed = bool(Settings.g(sk))
	c.custom_minimum_size = Vector2(240, 44)
	c.toggled.connect(func(on): Settings.s(sk, on))
	p.add_child(c)

func go_back() -> void:
	GameSession.goto("res://ui/main_menu.tscn")
