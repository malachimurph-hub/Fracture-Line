extends ScreenBase
## Main menu: Skirmish, Continue (suspended match), Settings, Credits/About, Quit.

var _old_fps := 0

func build() -> void:
	get_tree().set_auto_accept_quit(true)
	_add_battle_backdrop()
	var h := HBoxContainer.new()
	body.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	left.add_child(_shadowed(UiTheme.label(tr("APP_TITLE"), 40, UiTheme.GOLD), 6))
	left.add_child(_shadowed(UiTheme.label(tr("MENU_SUBTITLE"), 14, UiTheme.CYAN), 4))
	left.add_child(_shadowed(UiTheme.label(tr("MENU_BUILD") % ProjectSettings.get_setting("application/config/version", "M1"), 11, Color(0.72, 0.72, 0.72)), 3))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	var b := UiTheme.button(tr("MENU_SKIRMISH"), Vector2(260, 56))
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func(): GameSession.goto("res://ui/skirmish_setup.tscn"))
	right.add_child(b)
	if SaveSystem.has_suspend():
		var c := UiTheme.button(tr("MENU_CONTINUE"), Vector2(260, 52))
		c.pressed.connect(_continue)
		right.add_child(c)
	var s := UiTheme.button(tr("MENU_SETTINGS"), Vector2(260, 52))
	s.pressed.connect(func(): GameSession.goto("res://ui/settings_screen.tscn"))
	right.add_child(s)
	var cr := UiTheme.button(tr("MENU_CREDITS"), Vector2(260, 52))
	cr.pressed.connect(func(): GameSession.goto("res://ui/credits.tscn"))
	right.add_child(cr)
	if not OS.has_feature("web"):
		var q := UiTheme.button(tr("MENU_QUIT"), Vector2(260, 52))
		q.pressed.connect(func(): get_tree().quit())
		right.add_child(q)

## M2.7b: title text stays readable over bright (snow) battle maps: dark outline + soft drop
## shadow on the label itself (the backdrop also gets a gradient behind the title column).
func _shadowed(l: Label, outline: int) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", outline + 4)
	return l

## M2.6: live battle behind the menu (reduced-resolution 3D, 30 FPS cap while shown).
## M2.7: 3D at 67% scale instead of a half-size viewport (sharper models), lighter veil.
func _add_battle_backdrop() -> void:
	if not Settings.g("menu_battle"):
		return
	var svc := SubViewportContainer.new()
	svc.name = "BattleBackdrop"
	svc.stretch = true
	svc.stretch_shrink = 1
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	move_child(svc, 1)               # above the flat background, below the menu
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.audio_listener_enable_3d = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.67
	svc.add_child(vp)
	var mb := MenuBattle.new()
	mb.name = "MenuBattle"
	vp.add_child(mb)
	# readability: dark gradient on the menu side, light veil elsewhere
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.035, 0.045, 0.16)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	move_child(veil, 2)
	var side := ColorRect.new()
	side.color = Color(0.03, 0.035, 0.045, 0.4)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.set_anchors_preset(Control.PRESET_FULL_RECT)
	side.anchor_left = 0.6
	add_child(side)
	move_child(side, 3)
	# M2.7b: soft dark backing behind the title column (fades out toward the middle and
	# toward the top and bottom), so the title reads over snow without boxing it in
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.025, 0.035, 0.62))
	grad.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	grad.add_point(0.55, Color(0.02, 0.025, 0.035, 0.42))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(0.5, 0.5)
	gt.width = 256
	gt.height = 128
	var back := TextureRect.new()
	back.name = "TitleBacking"
	back.texture = gt
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.anchor_top = 0.12
	back.anchor_bottom = 0.88
	add_child(back)
	move_child(back, 4)
	_old_fps = Engine.max_fps
	Engine.max_fps = 30

func _exit_tree() -> void:
	if _old_fps >= 0 and has_node("BattleBackdrop"):
		Engine.max_fps = _old_fps

func _continue() -> void:
	var d := SaveSystem.load_suspend()
	if d.is_empty():
		SaveSystem.clear_suspend()
		get_tree().reload_current_scene()
		return
	GameSession.resume_save = d
	GameSession.goto("res://match/match.tscn")

func go_back() -> void:
	get_tree().quit()
