class_name PowerSegBar
extends Control
## M3.3 (Malachi: "Power in a bar with multiple squares like 40, green shows where your power is
## at and yellow follows behind to show demand. Tap and hold to see actual numbers"): 40 square
## segments. Green fills to the power produced, yellow (drawn over it) to the power used; when
## demand is over supply the missing part shows red. The scale is the larger of the two (min 10).
## Press and hold shows the numbers (the HUD connects `hold_info`).
signal hold_info(on: bool)

const SEGS := 40
const GREEN := Color("#3ee05a")
const YELLOW := Color("#ffd23a")
const RED := Color("#ff4a3a")
const OFF := Color(1, 1, 1, 0.10)

var prod := 0
var used := 0
var _down := false
var _t0 := 0

func set_power(p: int, u: int) -> void:
	if p == prod and u == used:
		return
	prod = p
	used = u
	queue_redraw()

func scale_max() -> int:
	return maxi(10, maxi(prod, used))

## Segments lit [green, yellow, red] - tests read this.
func lit() -> Array:
	var mx := float(scale_max())
	var g := roundi(SEGS * prod / mx)
	var y := roundi(SEGS * mini(used, prod) / mx)
	var r := roundi(SEGS * used / mx) - g if used > prod else 0
	return [g, y, maxi(0, r)]

func _draw() -> void:
	var gap := 1.0
	var w := (size.x - gap * (SEGS - 1)) / SEGS
	var l := lit()
	draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0, 0, 0, 0.55))
	for i in SEGS:
		var c := OFF
		if i < l[1]:
			c = YELLOW
		elif i < l[0]:
			c = GREEN
		elif i < l[0] + l[2]:
			c = RED
		draw_rect(Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y)), c)

func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch:
		if ev.pressed:
			_down = true
			_t0 = Time.get_ticks_msec()
			hold_info.emit(true)   # numbers show at once and stay while held
		elif _down:
			_down = false
			hold_info.emit(false)
		accept_event()
