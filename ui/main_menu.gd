extends ScreenBase
## Main menu: Skirmish, Continue (suspended match), Campaign (coming soon), Settings,
## Credits/About, Quit. M3.4: a live battle plays behind it (ui/menu_battle.gd) over the key art.

func build() -> void:
	get_tree().set_auto_accept_quit(true)
	_add_backdrop()
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
	# M3.3: Continue (autosave) and Load (manual slots) share a row so the menu still fits a phone
	if SaveSystem.has_suspend() or SaveSystem.has_any_slot():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		right.add_child(row)
		var both := SaveSystem.has_suspend() and SaveSystem.has_any_slot()
		if SaveSystem.has_suspend():
			var c := UiTheme.button(tr("MENU_CONTINUE_SHORT") if both else tr("MENU_CONTINUE"), Vector2(128 if both else 260, 52))
			c.name = "Continue"
			c.pressed.connect(_continue)
			row.add_child(c)
		if SaveSystem.has_any_slot():
			var lb := UiTheme.button(tr("MENU_LOAD"), Vector2(128 if both else 260, 52))
			lb.name = "Load"
			lb.pressed.connect(func(): GameSession.goto("res://ui/load_screen.tscn"))
			row.add_child(lb)
	# M3.4: Campaign beside Map Builder (so the column still fits a phone in landscape), styled like
	# the others, with a small "Coming soon" line inside it; a tap says so
	var row2 := HBoxContainer.new()
	row2.name = "CampaignRow"
	row2.add_theme_constant_override("separation", 4)
	right.add_child(row2)
	var cb := UiTheme.button(tr("MENU_CAMPAIGN"), Vector2(128, 52))
	cb.name = "Campaign"
	cb.modulate = Color(1, 1, 1, 0.78)
	cb.ready.connect(_lift_campaign_text.bind(cb))   # the menu theme's styles, text lifted for the label
	cb.pressed.connect(_campaign_soon)
	row2.add_child(cb)
	var soon := _shadowed(UiTheme.label(tr("MENU_COMING_SOON"), 11, UiTheme.GOLD), 3)
	soon.name = "CampaignSoon"
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soon.set_anchors_preset(Control.PRESET_FULL_RECT)
	soon.offset_bottom = -5
	cb.add_child(soon)
	var mb := UiTheme.button(tr("MENU_MAP_BUILDER"), Vector2(128, 52))   # M2.8
	mb.name = "MapBuilder"
	mb.pressed.connect(func(): GameSession.goto("res://ui/map_builder.tscn"))
	row2.add_child(mb)
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
const LOGO := "res://ui/logo/fl_badge.png"
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
	# M2.7: Malachi's title badge (M3.2.2: FRACTURE LINE / MODERN CONFLICT) replaces the text title (the label stays as
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
	# M3.5: the stale MENU_SUBTITLE line is gone (the emblem already reads MODERN CONFLICT); only the build line stays.
	_subs = [_shadowed(UiTheme.label(tr("MENU_BUILD") % ProjectSettings.get_setting("application/config/version", "M1"), 11, Color(0.78, 0.78, 0.78)), 4)]
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

## M3.1 (Malachi: "forgo the animated menu screen"): a static key-art battle scene behind the
## menu, rendered offline at high resolution from the real in-game models (tools/render_keyart_m31.gd)
## and shipped as one compressed image. The menu opens instantly and costs nothing per frame.
const KEYART := "res://assets/ui/menu_keyart.jpg"

func _add_backdrop() -> void:
	var art := TextureRect.new()
	art.name = "KeyArt"
	art.texture = load(KEYART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	move_child(art, 1)               # above the flat background, below the menu
	_add_live_battle()               # M3.4: the live battle fades in over the key art
	# readability: light veil, darker on the button side, soft backing behind the title column
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.035, 0.045, 0.12)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	move_child(veil, 2)
	var side := ColorRect.new()
	side.color = Color(0.03, 0.035, 0.045, 0.36)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.set_anchors_preset(Control.PRESET_FULL_RECT)
	side.anchor_left = 0.6
	add_child(side)
	move_child(side, 3)
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
	# M3.4: subtle dark vignette behind the buttons (right side) so they read over the battle
	var vg := Gradient.new()
	vg.set_color(0, Color(0.02, 0.025, 0.035, 0.0))
	vg.set_color(1, Color(0.02, 0.025, 0.035, 0.5))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill_from = Vector2(0.45, 0.5)
	vt.fill_to = Vector2(1.0, 0.5)
	vt.width = 256
	vt.height = 4
	var vig := TextureRect.new()
	vig.name = "ButtonVignette"
	vig.texture = vt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vig)
	move_child(vig, 5)

## M3.4 live battle behind the menu. Off on the compatibility renderer, the Low preset, headless
## runs, and for the rest of the session once the frame rate has dropped (then the key art stays).
static var live_off := false
static var force_live := false   ## tests/screenshots on the box (no Vulkan -> compatibility renderer)
const LOW_FPS := 22
const LOW_FPS_SECONDS := 4.0
var live: SubViewportContainer
var battle: MenuBattle
var _old_fps := -1
var _low_t := 0.0
var _shown_t := 0.0

static func live_allowed() -> bool:
	if live_off or DisplayServer.get_name() == "headless":
		return false
	if force_live:
		return true
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return false
	return String(Settings.g("graphics_preset")) != "low"

func _add_live_battle() -> void:
	if not live_allowed():
		return
	live = SubViewportContainer.new()
	live.name = "BattleBackdrop"
	live.stretch = true
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live.set_anchors_preset(Control.PRESET_FULL_RECT)
	live.modulate.a = 0.0
	add_child(live)
	move_child(live, 2)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.audio_listener_enable_3d = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.67
	vp.positional_shadow_atlas_size = 0
	live.add_child(vp)
	battle = MenuBattle.new()
	battle.name = "MenuBattle"
	battle.battle_ready.connect(_live_in)
	battle.wants_rebuild.connect(_live_next)
	vp.add_child(battle)
	_old_fps = Engine.max_fps
	Engine.max_fps = 30

func _live_in() -> void:
	if live == null:
		return
	_shown_t = 0.0
	_low_t = 0.0
	create_tween().tween_property(live, "modulate:a", 1.0, 0.8)

func _live_next() -> void:
	if live == null:
		return
	var tw := create_tween()
	tw.tween_property(live, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): if battle != null and is_instance_valid(battle): battle.next_map())

## Frame-rate watchdog: below LOW_FPS for LOW_FPS_SECONDS while the battle is shown -> key art.
func _process(delta: float) -> void:
	if live == null or battle == null or battle.building or live.modulate.a < 0.99 or force_live:
		return
	_shown_t += delta
	if _shown_t < 3.0:
		return
	if Engine.get_frames_per_second() < LOW_FPS:
		_low_t += delta
		if _low_t > LOW_FPS_SECONDS:
			drop_live_battle()
	else:
		_low_t = maxf(0.0, _low_t - delta)

func drop_live_battle() -> void:
	live_off = true
	if live == null:
		return
	var l := live
	live = null
	battle = null
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	if _old_fps >= 0:
		Engine.max_fps = _old_fps
		_old_fps = -1

func _exit_tree() -> void:
	if _old_fps >= 0:
		Engine.max_fps = _old_fps
		_old_fps = -1

func _lift_campaign_text(cb: Button) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := cb.get_theme_stylebox(st)
		if sb != null:
			sb = sb.duplicate()
			sb.content_margin_bottom = maxf(sb.content_margin_bottom, 0.0) + 14.0
			cb.add_theme_stylebox_override(st, sb)

## M3.4: "Coming soon" toast for the Campaign entry.
var _toast: Label
func _campaign_soon() -> void:
	if _toast == null:
		_toast = _shadowed(UiTheme.label(tr("MENU_CAMPAIGN_SOON_TOAST"), 16, UiTheme.GOLD.lightened(0.1)), 6)
		_toast.name = "Toast"
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_toast.anchor_left = 0.0
		_toast.anchor_right = 1.0
		_toast.offset_top = -72
		_toast.offset_bottom = -40
		add_child(_toast)
	_toast.modulate.a = 1.0
	_toast.visible = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)

func _continue() -> void:
	var d := SaveSystem.load_suspend()
	if d.is_empty():
		SaveSystem.clear_suspend()
		get_tree().reload_current_scene()
		return
	GameSession.resume_save = d
	GameSession.goto_with_loading("res://match/match.tscn", tr("LOADING_BATTLE"))

func go_back() -> void:
	get_tree().quit()
