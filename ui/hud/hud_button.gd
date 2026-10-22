class_name HudButton
extends Button
## Command-bar button: tap = primary, long-press (500 ms) or right click = secondary.
## Minimum size is enforced by the HUD (>= 48 dp tap target, GDD 6.2).
## M2: draws its own caption (label_text) with the FULL unit/building name: word-wrapped to
## at most two lines and auto-shrunk from the theme font size down to MIN_FONT (9 dp ~ 9 sp on
## the S24 Ultra). The price / count (`sub`) keeps its own line at the bottom.
## fit_ok / fit_size report the result so the UI test can assert nothing is clipped.
signal primary
signal secondary

const MIN_FONT := 9
const MAX_LINES := 2
const PAD_X := 2.0
const SUB_H := 13.0

var _down_ms: int = -1
var _fired: bool = false
var badge: String = ""
var sub: String = ""
var stub: bool = false
var progress: float = -1.0
var accent := Color(0, 0, 0, 0)
var label_text: String = "":
	set(v):
		if v != label_text:
			label_text = v
			_fit_key = ""
			queue_redraw()
var fit_ok := true
var fit_size := 0
var _fit_key := ""
var _para: TextParagraph
## M2.6: invisible tap padding (dp) around the drawn button: the top strip draws ~15% smaller
## buttons but keeps a >= 44 dp touch target.
var hit_pad := 0.0

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(hit_pad).has_point(point)

## Touch-target rect in global (HUD) coordinates, including the invisible padding.
func hit_rect() -> Rect2:
	return get_global_rect().grow(hit_pad)

func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	if text != "" and label_text == "":
		label_text = text
	text = ""
	button_down.connect(func(): _down_ms = _now(); _fired = false)
	button_up.connect(func(): _down_ms = -1)
	pressed.connect(_on_pressed)
	resized.connect(func(): _fit_key = ""; queue_redraw())

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
		if ev.pressed and not disabled:
			secondary.emit()
		accept_event()

func _on_pressed() -> void:
	if _fired:
		_fired = false
		return
	AudioDirector.ui("error" if stub or disabled else "click")
	primary.emit()

## Same gesture clock as WorldInput: real time on device; under the touch test the virtual
## clock, so a slow CI frame cannot turn a tap into a long-press (secondary) action.
static func _now() -> int:
	return WorldInput.test_clock_ms if WorldInput.test_clock_ms >= 0 else Time.get_ticks_msec()

func _process(_d: float) -> void:
	if _down_ms >= 0 and not _fired and is_pressed() and _now() - _down_ms > 500:
		_fired = true
		AudioDirector.ui("select")
		if Settings.g("haptics"):
			Input.vibrate_handheld(15)
		secondary.emit()

## Caption box (inside the button): below the accent strip / [STUB] tag, above the sub line.
func caption_rect() -> Rect2:
	var top := 3.0 + (11.0 if stub and not _stub_on_sub() else 0.0)
	var bottom := size.y - (SUB_H if sub != "" else 3.0)
	return Rect2(Vector2(PAD_X, top), Vector2(maxf(1.0, size.x - PAD_X * 2.0), maxf(1.0, bottom - top)))

## Largest font size (theme size down to MIN_FONT) at which the caption fits in <= 2 lines
## without any line wider than the box. Sets fit_ok / fit_size.
func _fit() -> void:
	var r := caption_rect()
	var key := "%s|%s|%s|%d" % [label_text, r.size, stub, get_theme_font_size("font_size")]
	if key == _fit_key and _para != null:
		return
	_fit_key = key
	var f := get_theme_default_font() if not has_theme_font("font") else get_theme_font("font")
	var start := maxi(MIN_FONT, get_theme_font_size("font_size"))
	fit_ok = false
	for fs in range(start, MIN_FONT - 1, -1):
		var p := _make_para(f, fs, r.size.x)
		if _para_fits(p, r.size):
			_para = p
			fit_size = fs
			fit_ok = true
			return
	_para = _make_para(f, MIN_FONT, r.size.x)
	fit_size = MIN_FONT
	fit_ok = label_text == ""

## Shared by the HUD portrait: [TextParagraph, fits, font_size] for `text` in `box`.
static func fit_paragraph(t: String, f: Font, box: Vector2, start: int) -> Array:
	for fs in range(maxi(MIN_FONT, start), MIN_FONT - 1, -1):
		var p := _para_of(t, f, fs, box.x)
		if _fits_box(p, box):
			return [p, true, fs]
	return [_para_of(t, f, MIN_FONT, box.x), t == "", MIN_FONT]

static func _para_of(t: String, f: Font, fs: int, w: float) -> TextParagraph:
	var p := TextParagraph.new()
	p.width = w
	p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_TRIM_START_EDGE_SPACES | TextServer.BREAK_TRIM_END_EDGE_SPACES
	p.alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_string(t, f, fs)
	return p

static func _fits_box(p: TextParagraph, box: Vector2) -> bool:
	var n := p.get_line_count()
	if n > MAX_LINES:
		return false
	var h := 0.0
	for i in n:
		var ls := p.get_line_size(i)
		if ls.x > box.x + 0.5:
			return false
		h += ls.y
	return h <= box.y + 0.5

func _make_para(f: Font, fs: int, w: float) -> TextParagraph:
	var p := TextParagraph.new()
	p.width = w
	p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_TRIM_START_EDGE_SPACES | TextServer.BREAK_TRIM_END_EDGE_SPACES
	p.alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_string(label_text, f, fs)
	return p

func _para_fits(p: TextParagraph, box: Vector2) -> bool:
	var n := p.get_line_count()
	if n > MAX_LINES:
		return false
	var h := 0.0
	for i in n:
		var ls := p.get_line_size(i)
		if ls.x > box.x + 0.5:
			return false
		h += ls.y
	return h <= box.y + 0.5

## With a price line and no queue badge, the [STUB] tag shares the price line (right-aligned)
## so it does not steal a caption line.
func _stub_on_sub() -> bool:
	return sub != ""

## Price line shares the row with the [STUB] tag: 9 dp (the minimum) and tighter margins.
func _sub_font() -> int:
	return 9 if stub and _stub_on_sub() else 10

func _sub_margin() -> float:
	return 3.0 if stub and _stub_on_sub() else 4.0

## M2.1 (smaller buttons): a queued [STUB] item has no room for price + badge + tag on one
## line, so while it is queued the price yields to the tag (it is still in the tooltip).
## M2.4: the same happens on a narrow card when the price and the tag together are wider than
## the button (four-digit prices on the Airstrip's two stubbed aircraft).
func _hide_sub_text() -> bool:
	if not stub or sub == "":
		return false
	if badge != "":
		return true
	var f := get_theme_default_font()
	var need := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _sub_font()).x + f.get_string_size("[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 3.0
	return need > size.x - _sub_margin() * 2 + 0.5

func _draw() -> void:
	var f := get_theme_default_font()
	if accent.a > 0:
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 3)), accent)
	if label_text != "":
		_fit()
		var r := caption_rect()
		var h := 0.0
		for i in _para.get_line_count():
			h += _para.get_line_size(i).y
		var col := get_theme_color("font_disabled_color") if disabled else get_theme_color("font_color")
		_para.draw(get_canvas_item(), Vector2(r.position.x, r.position.y + maxf(0.0, (r.size.y - h) * 0.5)), col)
	var bw := 8.0 + 7.0 * badge.length() if badge != "" else 0.0
	if sub != "" and not _hide_sub_text():
		# price / count on its own line; a queue badge sits at the right end of that line
		var al := HORIZONTAL_ALIGNMENT_LEFT if badge != "" or stub else HORIZONTAL_ALIGNMENT_CENTER
		var sm := _sub_margin()
		draw_string(f, Vector2(sm, size.y - 4), sub, al, size.x - sm * 2 - bw, _sub_font(), Color(1, 0.85, 0.45, 0.95 if not disabled else 0.5))
	if badge != "":
		var by := size.y - 15.0 if sub != "" else 2.0
		draw_rect(Rect2(Vector2(size.x - bw - 2, by), Vector2(bw, 13)), Color("#e2b23c"))
		draw_string(f, Vector2(size.x - bw + 2, by + 11), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
	if stub and _stub_on_sub():
		var sx := (size.x - 4 - bw - 2 - f.get_string_size("[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x) if _hide_sub_text() else (size.x - _sub_margin() - f.get_string_size("[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
		draw_string(f, Vector2(sx, size.y - 4), "[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ff8a7a"))
	elif stub:
		draw_string(f, Vector2(4, 13), "[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ff8a7a"))
	if progress >= 0.0:
		draw_rect(Rect2(Vector2(0, size.y - 3), Vector2(size.x * progress, 3)), Color("#6fe3ff"))

## For tests: the caption fits and the sub line fits.
func text_fits() -> bool:
	_fit()
	var f := get_theme_default_font()
	var bw := 8.0 + 7.0 * badge.length() if badge != "" else 0.0
	var stub_w := f.get_string_size("[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 3.0 if stub and _stub_on_sub() else 0.0
	if _hide_sub_text():
		return fit_ok and stub_w + bw + 6 <= size.x + 0.5
	var sub_ok := sub == "" or f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _sub_font()).x <= size.x - _sub_margin() * 2 - bw - stub_w + 0.5
	return fit_ok and sub_ok
