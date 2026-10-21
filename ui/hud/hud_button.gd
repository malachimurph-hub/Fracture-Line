class_name HudButton
extends Button
## Command-bar button: tap = primary, long-press (500 ms) or right click = secondary.
## Minimum size is enforced by the HUD (>= 48 dp tap target, GDD 6.2).
signal primary
signal secondary

var _down_ms: int = -1
var _fired: bool = false
var badge: String = ""
var sub: String = ""
var stub: bool = false
var progress: float = -1.0
var accent := Color(0, 0, 0, 0)

func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	button_down.connect(func(): _down_ms = Time.get_ticks_msec(); _fired = false)
	button_up.connect(func(): _down_ms = -1)
	pressed.connect(_on_pressed)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
		if ev.pressed and not disabled:
			secondary.emit()
		accept_event()

func _on_pressed() -> void:
	if _fired:
		_fired = false
		return
	primary.emit()

func _process(_d: float) -> void:
	if _down_ms >= 0 and not _fired and is_pressed() and Time.get_ticks_msec() - _down_ms > 500:
		_fired = true
		if Settings.g("haptics"):
			Input.vibrate_handheld(15)
		secondary.emit()

func _draw() -> void:
	var f := get_theme_default_font()
	if accent.a > 0:
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 3)), accent)
	if sub != "":
		draw_string(f, Vector2(4, size.y - 5), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 10, Color(1, 0.85, 0.45, 0.95 if not disabled else 0.5))
	if badge != "":
		var bw := 8.0 + 7.0 * badge.length()
		draw_rect(Rect2(Vector2(size.x - bw - 2, 2), Vector2(bw, 15)), Color("#e2b23c"))
		draw_string(f, Vector2(size.x - bw + 2, 14), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
	if stub:
		draw_string(f, Vector2(4, 13), "[STUB]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ff8a7a"))
	if progress >= 0.0:
		draw_rect(Rect2(Vector2(0, size.y - 3), Vector2(size.x * progress, 3)), Color("#6fe3ff"))
