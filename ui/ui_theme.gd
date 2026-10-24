class_name UiTheme
## Code-built theme (Germany, id eu: gunmetal + gold + cyan). Sizes are in dp (logical units).

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

# ---------------------------------------------------------------- M2.6 faction HUD themes
## Zero Hour gives each faction its own command-bar look. Ours (Malachi, M2.6):
##  Germany (eu) - gunmetal + gold + cyan, rounded bevelled frames (the base theme)
##  Iran (tpla)  - rust / umber / sand, square riveted frames, slanted buttons, heavy stencil-ish font
##  US           - navy + steel blue + white, chamfer-like tight corners, wide-spaced font
##  Russia (ecc) - dark olive + signal red + pale gold, plain square frames (M3.0 F)
const PALETTES := {
	&"eu": {"bg": Color(0.09, 0.10, 0.12, 0.96), "btn": Color("#343a44"), "btn_hover": Color("#3f4652"), "btn_pressed": Color("#1a1d22"),
		"edge": Color("#4b5260"), "frame": Color("#c9a24a"), "accent": Color("#6fe3ff"), "title": Color("#c9a24a"),
		"money": Color("#ffd166"), "text": Color("#e8e6e0"), "radius": 6, "btn_radius": 4, "frame_w": 1, "skew": 0.0,
		"embolden": 0.0, "spacing": 0, "slant": 0.0},
	&"tpla": {"bg": Color(0.13, 0.09, 0.06, 0.96), "btn": Color("#4a3322"), "btn_hover": Color("#5c3f29"), "btn_pressed": Color("#24170e"),
		"edge": Color("#7a4a2a"), "frame": Color("#b5562a"), "accent": Color("#f0b860"), "title": Color("#e08a3c"),
		"money": Color("#f6c86a"), "text": Color("#efe2cc"), "radius": 0, "btn_radius": 0, "frame_w": 2, "skew": 0.12,
		"embolden": 0.3, "spacing": 0, "slant": 0.08},
	&"us": {"bg": Color(0.06, 0.09, 0.14, 0.96), "btn": Color("#22344c"), "btn_hover": Color("#2c4462"), "btn_pressed": Color("#0f1a28"),
		"edge": Color("#41648c"), "frame": Color("#7fb0e6"), "accent": Color("#ffffff"), "title": Color("#cfe4ff"),
		"money": Color("#9fe0a0"), "text": Color("#e6eef8"), "radius": 2, "btn_radius": 2, "frame_w": 1, "skew": 0.0,
		"embolden": 0.0, "spacing": 0, "slant": 0.0},
	# M3.0 F Russia: dark olive + signal red + pale gold, plain square frames
	&"ecc": {"bg": Color(0.08, 0.10, 0.07, 0.96), "btn": Color("#323b2c"), "btn_hover": Color("#3d4835"), "btn_pressed": Color("#181d15"),
		"edge": Color("#56614a"), "frame": Color("#b8352b"), "accent": Color("#e8d27a"), "title": Color("#e0574a"),
		"money": Color("#e8d27a"), "text": Color("#e9e8dc"), "radius": 1, "btn_radius": 1, "frame_w": 1, "skew": 0.0,
		"embolden": 0.15, "spacing": 0, "slant": 0.0},
}
static var _fthemes: Dictionary = {}

static func pal(fac: StringName) -> Dictionary:
	return PALETTES.get(fac, PALETTES[&"eu"])

static func fbox(fac: StringName, bg: Color, border: Color, bw: int = -1, radius: int = -1, margin: float = 6.0) -> StyleBoxFlat:
	var p := pal(fac)
	var s := box(bg, border, int(p["frame_w"]) if bw < 0 else bw, int(p["btn_radius"]) if radius < 0 else radius, margin)
	s.skew = Vector2(float(p["skew"]), 0)
	if fac == &"us":
		# US: steel double-edge look (inner border + soft outer glow)
		s.shadow_color = Color(p["frame"], 0.25)
		s.shadow_size = 2
	elif fac == &"tpla":
		s.border_width_bottom = s.border_width_top + 1   # heavier "welded" lower edge
	return s

## Faction font accent: a FontVariation of the default font (embolden, slant, letter spacing).
static func faction_font(fac: StringName) -> Font:
	var p := pal(fac)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = float(p["embolden"])
	if float(p["slant"]) != 0.0:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(float(p["slant"]), 1), Vector2.ZERO)
	fv.spacing_glyph = int(p["spacing"])
	return fv

static func faction_theme(fac: StringName) -> Theme:
	if fac == &"" or not PALETTES.has(fac):
		fac = &"eu"
	if _fthemes.has(fac):
		return _fthemes[fac]
	var p := pal(fac)
	var t := get_theme().duplicate(true) as Theme
	t.default_font = faction_font(fac)
	t.set_stylebox("normal", "Button", fbox(fac, p["btn"], p["edge"]))
	t.set_stylebox("hover", "Button", fbox(fac, p["btn_hover"], p["frame"]))
	t.set_stylebox("pressed", "Button", fbox(fac, p["btn_pressed"], p["accent"], 2))
	t.set_stylebox("disabled", "Button", fbox(fac, Color(p["btn"]).darkened(0.4), Color(p["edge"]).darkened(0.4)))
	t.set_color("font_color", "Button", p["text"])
	t.set_color("font_pressed_color", "Button", p["accent"])
	t.set_color("font_color", "Label", p["text"])
	t.set_stylebox("panel", "Panel", fbox(fac, p["bg"], p["frame"], -1, int(p["radius"])))
	t.set_stylebox("panel", "PanelContainer", fbox(fac, p["bg"], p["frame"], -1, int(p["radius"]), 8))
	t.set_stylebox("panel", "TooltipPanel", fbox(fac, Color(0.05, 0.05, 0.06, 0.95), p["frame"]))
	_fthemes[fac] = t
	return t

static func button(text: String, min_size := Vector2(48, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): AudioDirector.ui("click"))
	return b

static func label(text: String, size: int = 13, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
