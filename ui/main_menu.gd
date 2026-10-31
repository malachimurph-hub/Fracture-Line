extends ScreenBase
## Main menu: Skirmish, Continue (suspended match), Campaign (coming soon), Map Builder,
## Settings, Credits/About, Quit.
## M3.5 (Malachi: "Forget the motion background ... change menu up to match the feel of the
## provided photo. Shrink game logo and move to top right, change menu buttons to left side"):
## his dusk battlefield photo is the backdrop (cover-fit, no live battle, nothing per frame), the
## buttons are a left column of translucent dark plates with a thin amber edge in the bundled
## stencil face, and the emblem sits small in the top-right corner.

const PHOTO := "res://assets/ui/menu_photo.jpg"
const LOGO := "res://ui/logo/fl_badge.png"
const TITLE_FONT := "res://ui/fonts/BlackOpsOne-Regular.ttf"
const TITLE_SIZE := 34
const TITLE_MIN := 18
## warm sunset accents taken from the photo
const AMBER := Color("#e0a04a")
const AMBER_DIM := Color(0.88, 0.63, 0.29, 0.38)
const BTN_TEXT := Color("#f1e7d4")
const BTN_HOVER := Color("#ffd28c")
const PLATE := Color(0.045, 0.04, 0.036, 0.66)
const COL_W := 236.0          ## button column width (dp)
const BTN_H := 46.0
const BTN_H_MIN := 38.0
const LOGO_K := 0.3           ## logo height as a share of the screen height
const LOGO_MIN := 64.0
const LOGO_MAX := 150.0

var _title: Label
var _logo: TextureRect
var _col: VBoxContainer
var _corner: VBoxContainer
var _buttons: Array = []
var _font: Font

func build() -> void:
	get_tree().set_auto_accept_quit(true)
	_font = load(TITLE_FONT) as Font
	_add_backdrop()
	var h := HBoxContainer.new()
	h.name = "MenuRow"
	body.add_child(h)
	_col = VBoxContainer.new()
	_col.name = "ButtonColumn"
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_theme_constant_override("separation", 8)
	_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(_col)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(gap)
	_corner = _logo_block()
	h.add_child(_corner)
	var b := _button(tr("MENU_SKIRMISH"), COL_W, "Skirmish", true)
	b.pressed.connect(func(): GameSession.goto("res://ui/skirmish_setup.tscn"))
	_col.add_child(b)
	# M3.3: Continue (autosave) and Load (manual slots) share a row so the menu still fits a phone
	var half := (COL_W - 6.0) * 0.5
	if SaveSystem.has_suspend() or SaveSystem.has_any_slot():
		var row := _row()
		var both := SaveSystem.has_suspend() and SaveSystem.has_any_slot()
		if SaveSystem.has_suspend():
			var c := _button(tr("MENU_CONTINUE_SHORT") if both else tr("MENU_CONTINUE"), half if both else COL_W, "Continue")
			c.pressed.connect(_continue)
			row.add_child(c)
		if SaveSystem.has_any_slot():
			var lb := _button(tr("MENU_LOAD"), half if both else COL_W, "Load")
			lb.pressed.connect(func(): GameSession.goto("res://ui/load_screen.tscn"))
			row.add_child(lb)
	# M3.4: Campaign beside Map Builder, with a small "Coming soon" line inside it; a tap says so
	var row2 := _row()
	row2.name = "CampaignRow"
	var cb := _button(tr("MENU_CAMPAIGN"), half, "Campaign")
	cb.modulate = Color(1, 1, 1, 0.78)
	_lift_campaign_text(cb)
	cb.pressed.connect(_campaign_soon)
	row2.add_child(cb)
	var soon := _shadowed(UiTheme.label(tr("MENU_COMING_SOON"), 10, AMBER), 3)
	soon.name = "CampaignSoon"
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soon.set_anchors_preset(Control.PRESET_FULL_RECT)
	soon.offset_bottom = -4
	cb.add_child(soon)
	var mb := _button(tr("MENU_MAP_BUILDER"), half, "MapBuilder")   # M2.8
	mb.pressed.connect(func(): GameSession.goto("res://ui/map_builder.tscn"))
	row2.add_child(mb)
	var s := _button(tr("MENU_SETTINGS"), COL_W, "Settings")
	s.pressed.connect(func(): GameSession.goto("res://ui/settings_screen.tscn"))
	_col.add_child(s)
	var cr := _button(tr("MENU_CREDITS"), COL_W, "Credits")
	cr.pressed.connect(func(): GameSession.goto("res://ui/credits.tscn"))
	_col.add_child(cr)
	if not OS.has_feature("web"):
		var q := _button(tr("MENU_QUIT"), COL_W, "Quit")
		q.pressed.connect(func(): get_tree().quit())
		_col.add_child(q)
	UiScale.changed.connect(_fit_title)
	resized.connect(_fit_title)
	_fit_title.call_deferred()

func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	_col.add_child(r)
	return r

## Translucent dark plate, thin amber rule on the left edge and a faint amber outline; the
## stencil face (Black Ops One, OFL, already bundled) in warm off-white.
func _button(text: String, w: float, node_name: String, lead := false) -> Button:
	var b := UiTheme.button(text, Vector2(w, BTN_H + (6.0 if lead else 0.0)))
	b.name = node_name
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if w >= COL_W - 1.0 else HORIZONTAL_ALIGNMENT_CENTER
	if _font != null:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 19 if lead else 15)
	b.add_theme_color_override("font_color", BTN_TEXT)
	b.add_theme_color_override("font_hover_color", BTN_HOVER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", BTN_TEXT)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 2)
	b.add_theme_stylebox_override("normal", _plate(PLATE, AMBER_DIM))
	b.add_theme_stylebox_override("hover", _plate(Color(0.09, 0.07, 0.05, 0.78), Color(AMBER, 0.8)))
	b.add_theme_stylebox_override("pressed", _plate(Color(0.32, 0.19, 0.07, 0.82), BTN_HOVER))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _plate(Color(0.04, 0.04, 0.04, 0.5), Color(0.5, 0.5, 0.5, 0.3)))
	_buttons.append(b)
	return b

static func _plate(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.border_width_left = 3      # the thicker amber rule on the left edge
	s.set_corner_radius_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	return s

## Top-right corner: the emblem, small, with the build line under it (right aligned).
func _logo_block() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "LogoCorner"
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	_title = _shadowed(UiTheme.label(tr("APP_TITLE"), TITLE_SIZE, AMBER.lightened(0.1)), 8)
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _font != null:
		_title.add_theme_font_override("font", _font)
	var tex := load(LOGO) as Texture2D
	if tex != null:
		_logo = TextureRect.new()
		_logo.name = "Logo"
		_logo.texture = tex
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.size_flags_horizontal = Control.SIZE_SHRINK_END
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(_logo)
		_title.visible = false   # the text title is the fallback when the emblem is missing
	v.add_child(_title)
	var ver := _shadowed(UiTheme.label(tr("MENU_BUILD") % ProjectSettings.get_setting("application/config/version", "M1"), 10, Color(0.86, 0.8, 0.7, 0.85)), 3)
	ver.name = "Build"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(ver)
	return v

func _screen() -> Vector2:
	var sr := UiScale.safe_rect
	return sr.size if sr.size.x > 0.0 else UiScale.logical_size()

## Width left for the corner block: the screen minus the button column and the body margins.
func title_column_width() -> float:
	return maxf(_screen().x - 24.0 - COL_W - 24.0, 120.0)

## Fits the small screens: the logo is ~30% of the screen height (64-150 dp) and never reaches
## the button column; the text title (fallback) shrinks the same way; the button column trims
## its button height and spacing when a phone is very short.
func _fit_title() -> void:
	if _title == null:
		return
	var scr := _screen()
	var avail := title_column_width()
	if _logo != null:
		var ts := _logo.texture.get_size()
		var hh := clampf(scr.y * LOGO_K, LOGO_MIN, LOGO_MAX)
		hh = minf(hh, avail * 0.85 * ts.y / ts.x)
		var want := Vector2(roundf(hh * ts.x / ts.y), roundf(hh))
		if not _logo.custom_minimum_size.is_equal_approx(want):
			_logo.custom_minimum_size = want
	var f := _title.get_theme_font("font")
	var sz := TITLE_SIZE
	while sz > TITLE_MIN and f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 12.0 > avail:
		sz -= 2
	if _title.get_theme_font_size("font_size") != sz:
		_title.add_theme_font_size_override("font_size", sz)
	var wrap := f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 12.0 > avail
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	_title.custom_minimum_size.x = avail if wrap else 0.0
	# button column height: shrink rows on very short screens
	var rows := _col.get_child_count()
	var room := scr.y - 16.0
	var bh := BTN_H
	var sep := 8
	while bh > BTN_H_MIN and rows * bh + 6.0 + (rows - 1) * sep > room:
		bh -= 2.0
		sep = maxi(4, sep - 1)
	_col.add_theme_constant_override("separation", sep)
	for b: Button in _buttons:
		b.custom_minimum_size.y = bh + (6.0 if b.name == "Skirmish" else 0.0)

func _shadowed(l: Label, outline: int) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.012, 0.95))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", outline + 4)
	return l

## Malachi's photo, cover-fit (crops to the screen's aspect, never stretched), plus a dark wash on
## the left (button side, already the dark half of the photo) and a faint warm vignette.
func _add_backdrop() -> void:
	var art := TextureRect.new()
	art.name = "KeyArt"
	art.texture = load(PHOTO)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	move_child(art, body.get_index())
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.018, 0.016, 0.7))
	g.set_color(1, Color(0.02, 0.018, 0.016, 0.0))
	g.add_point(0.4, Color(0.02, 0.018, 0.016, 0.42))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.62, 0)
	gt.width = 256
	gt.height = 4
	var wash := TextureRect.new()
	wash.name = "LeftWash"
	wash.texture = gt
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	move_child(wash, body.get_index())
	var vg := Gradient.new()
	vg.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	vg.set_color(1, Color(0.05, 0.02, 0.0, 0.42))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.45)
	vt.fill_to = Vector2(1.1, 0.45)
	vt.width = 128
	vt.height = 64
	var vig := TextureRect.new()
	vig.name = "Vignette"
	vig.texture = vt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vig)
	move_child(vig, body.get_index())

func _lift_campaign_text(cb: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := cb.get_theme_stylebox(st)
		if sb != null:
			sb = sb.duplicate()
			sb.content_margin_bottom = maxf(sb.content_margin_bottom, 0.0) + 12.0
			cb.add_theme_stylebox_override(st, sb)

## M3.4: "Coming soon" toast for the Campaign entry.
var _toast: Label
func _campaign_soon() -> void:
	if _toast == null:
		_toast = _shadowed(UiTheme.label(tr("MENU_CAMPAIGN_SOON_TOAST"), 16, BTN_HOVER), 6)
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
