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
	left.add_child(_title_block())
	var right := VBoxContainer.new()
	_right = right
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	_fit_title.call_deferred()
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

## M2.7b: ZH-style title treatment that reads on every map (snow, desert, night): a dark
## band behind the title block that fades out to the right, a heavy stencil face with a
## thick dark outline and drop shadow, and a gold rule. The band hugs its content, and the
## title shrinks to fit the column, so any APP_TITLE length works.
const TITLE_FONT := "res://ui/fonts/BlackOpsOne-Regular.ttf"
const TITLE_SIZE := 46
const TITLE_MIN := 22

var _title: Label
var _subs: Array = []
var _right: Control
const LOGO := "res://ui/logo/roe_badge.png"
var _logo: TextureRect

func _title_block() -> Control:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.015, 0.02, 0.028, 0.86))
	grad.set_color(1, Color(0.015, 0.02, 0.028, 0.0))
	grad.add_point(0.62, Color(0.015, 0.02, 0.028, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 128
	gt.height = 4
	var band := StyleBoxTexture.new()
	band.texture = gt
	band.content_margin_left = 22
	band.content_margin_right = 64
	band.content_margin_top = 14
	band.content_margin_bottom = 14
	var panel := PanelContainer.new()
	panel.name = "TitleBand"
	panel.add_theme_stylebox_override("panel", band)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	_title = _shadowed(UiTheme.label(tr("APP_TITLE"), TITLE_SIZE, UiTheme.GOLD.lightened(0.08)), 10)
	_title.name = "Title"
	var f := load(TITLE_FONT) as Font
	if f != null:
		_title.add_theme_font_override("font", f)
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	# M2.7: Malachi's RULES OF ENGAGEMENT badge replaces the text title (the label stays as
	# the fallback if the texture is missing, and keeps the fit/test logic working).
	var tex := load(LOGO) as Texture2D
	if tex != null:
		_logo = TextureRect.new()
		_logo.name = "Logo"
		_logo.texture = tex
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_logo)
		_title.visible = false
	col.add_child(_title)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.85)
	rule.custom_minimum_size = Vector2(0, 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.visible = _logo == null
	col.add_child(rule)
	_subs = [_shadowed(UiTheme.label(tr("MENU_SUBTITLE"), 15, UiTheme.CYAN), 5),
		_shadowed(UiTheme.label(tr("MENU_BUILD") % ProjectSettings.get_setting("application/config/version", "M1"), 11, Color(0.78, 0.78, 0.78)), 4)]
	for l in _subs:
		col.add_child(l)
	panel.resized.connect(_fit_title.bind(panel))
	UiScale.changed.connect(func(): _fit_title(panel))
	return panel

## Shrink the title until it fits the left column (long or localised titles); past the
## minimum size it wraps onto more lines instead of pushing the buttons off screen.
## The column width comes from the safe rect minus the button column, never from the row
## (the row has already been stretched by an over-wide title).
func title_column_width() -> float:
	var sr := UiScale.safe_rect
	var w := sr.size.x if sr.size.x > 0.0 else UiScale.logical_size().x
	w -= 24.0   # body margins (ScreenBase._fit)
	var row := _right.get_parent() as Control if _right != null else null
	if _right != null:
		w -= _right.get_combined_minimum_size().x
	if row != null:
		w -= float(row.get_theme_constant("separation"))
	return maxf(w, 120.0)

func _fit_line(l: Label, avail: float, f: Font, sz: int) -> void:
	var wrap := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 4.0 > avail
	var mode := TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	var min_w := maxf(avail, 60.0) if wrap else 0.0
	if l.autowrap_mode != mode or not is_equal_approx(l.custom_minimum_size.x, min_w):
		l.autowrap_mode = mode
		l.custom_minimum_size.x = min_w

func _fit_title(_panel: Control = null) -> void:
	if _title == null:
		return
	var avail := title_column_width() - 22.0 - 64.0 - 8.0
	var f := _title.get_theme_font("font")
	var sz := TITLE_SIZE
	while sz > TITLE_MIN and f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 20.0 > avail:
		sz -= 2
	if _title.get_theme_font_size("font_size") != sz:
		_title.add_theme_font_size_override("font_size", sz)
	_fit_line(_title, avail, f, sz)
	if _logo != null:
		# as large as the column allows, leaving room for the subtitle lines and band margins
		var sr := UiScale.safe_rect
		var screen_h := sr.size.y if sr.size.y > 0.0 else UiScale.logical_size().y
		var ts := _logo.texture.get_size()
		var h := minf(screen_h - 16.0 - 28.0 - 60.0, (avail + 64.0) * ts.y / ts.x)
		h = maxf(h, 60.0)
		var want := Vector2(roundf(h * ts.x / ts.y), roundf(h))
		if not _logo.custom_minimum_size.is_equal_approx(want):
			_logo.custom_minimum_size = want
	for l in _subs:
		_fit_line(l, avail, l.get_theme_font("font"), l.get_theme_font_size("font_size"))

## M2.7b: title text stays readable over bright (snow) battle maps: dark outline + soft drop
## shadow on the label itself (the backdrop also gets a gradient behind the title column).
func _shadowed(l: Label, outline: int) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.016, 0.95))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
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
