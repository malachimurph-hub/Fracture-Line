class_name UiTheme
## Code-built theme (EU Alliance: gunmetal + gold + cyan). Sizes are in dp (logical units).

const GUNMETAL := Color("#23272e")
const GUNMETAL_LIGHT := Color("#343a44")
const GOLD := Color("#c9a24a")
const CYAN := Color("#6fe3ff")
const TEXT := Color("#e8e6e0")

static var _theme: Theme

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 4, margin: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.5
	s.content_margin_bottom = margin * 0.5
	return s

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 14
	t.set_stylebox("normal", "Button", box(GUNMETAL_LIGHT, Color("#4b5260"), 1))
	t.set_stylebox("hover", "Button", box(Color("#3f4652"), GOLD, 1))
	t.set_stylebox("pressed", "Button", box(Color("#1a1d22"), CYAN, 2))
	t.set_stylebox("disabled", "Button", box(Color("#202328"), Color("#30343b"), 1))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.55))
	t.set_color("font_pressed_color", "Button", CYAN)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 13)
	t.set_stylebox("panel", "Panel", box(Color(0.10, 0.11, 0.13, 0.94), GOLD, 1, 4))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.10, 0.11, 0.13, 0.94), GOLD, 1, 4, 8))
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 13)
	for cls in ["OptionButton"]:
		t.set_stylebox("normal", cls, box(GUNMETAL_LIGHT, Color("#4b5260"), 1))
		t.set_stylebox("hover", cls, box(Color("#3f4652"), GOLD, 1))
		t.set_stylebox("pressed", cls, box(Color("#1a1d22"), CYAN, 1))
		t.set_stylebox("disabled", cls, box(Color("#202328"), Color("#30343b"), 1))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_font_size("font_size", cls, 13)
	t.set_font_size("font_size", "PopupMenu", 16)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.10, 0.11, 0.13, 0.98), GOLD, 1, 4, 10))
	t.set_font_size("font_size", "CheckButton", 13)
	t.set_font_size("font_size", "CheckBox", 13)
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.05, 0.06, 0.95), GOLD, 1))
	_theme = t
	return t

static func button(text: String, min_size := Vector2(48, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b

static func label(text: String, size: int = 13, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
