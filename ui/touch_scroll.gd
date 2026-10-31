class_name TouchScroll
extends ScrollContainer
## M3.5 (Malachi: "Scrolling in the menu seems sticky, especially on the map selection"): a
## ScrollContainer that scrolls by dragging anywhere in it, buttons included, with a phone feel:
##  - a small deadzone (DEADZONE dp) so a tap stays a tap and a drag starts promptly;
##  - buttons and other controls inside pass their pointer events up (mouse_filter PASS) so they
##    no longer swallow the drag; once a drag starts the pressed button is cancelled
##    (NOTIFICATION_SCROLL_BEGIN), so a scroll never fires a button;
##  - a kinetic fling on release that decays smoothly (FRICTION), stopped by the next touch;
##  - follow_focus off (a tapped row never jumps the list).
## Works with mouse events, which Android emulates from touch (pointing/emulate_mouse_from_touch).

const DEADZONE := 10.0       ## dp moved before a press becomes a drag
const FRICTION := 4.2        ## fling decay per second (exponential)
const MIN_FLING := 60.0      ## dp/s below which a release does not fling
const MAX_FLING := 4200.0

var dragging := false
var fling := Vector2.ZERO
var _press := false
var _from := Vector2.ZERO
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _last_t := 0
var _vel := Vector2.ZERO
var _fpos := Vector2.ZERO          ## fling position (sub-pixel)

func _init() -> void:
	follow_focus = false
	scroll_deadzone = int(DEADZONE)
	child_entered_tree.connect(_on_child)

func _ready() -> void:
	_pass_mouse(self)
	set_process(false)

func _on_child(n: Node) -> void:
	_pass_mouse(n)
	if not n.child_entered_tree.is_connected(_on_child):
		n.child_entered_tree.connect(_on_child)

## Everything inside lets pointer events through to the scroller (buttons still get their taps).
func _pass_mouse(n: Node) -> void:
	if n != self and n is Control and n.mouse_filter == Control.MOUSE_FILTER_STOP and not n is ScrollBar:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for c in n.get_children():
		_pass_mouse(c)

func _scroll_pos() -> Vector2:
	return Vector2(scroll_horizontal, scroll_vertical)

func _axes() -> Vector2:
	return Vector2(0.0 if horizontal_scroll_mode == SCROLL_MODE_DISABLED else 1.0, 0.0 if vertical_scroll_mode == SCROLL_MODE_DISABLED else 1.0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			fling = Vector2.ZERO
			set_process(false)
			_press = true
			dragging = false
			_from = mb.global_position
			_last = mb.global_position
			_last_t = Time.get_ticks_usec()
			_start = _scroll_pos()
			_vel = Vector2.ZERO
		else:
			if dragging:
				var v := _vel
				if Time.get_ticks_usec() - _last_t > 120000:
					v = Vector2.ZERO   # finger held still before lifting: no fling
				if v.length() > MIN_FLING:
					fling = v.limit_length(MAX_FLING)
					_fpos = _scroll_pos()
					set_process(true)
			_press = false
			dragging = false
	elif ev is InputEventMouseMotion and _press:
		var mm := ev as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_press = false
			dragging = false
			return
		var d := (mm.global_position - _from) * _axes()
		if not dragging:
			if d.length() < DEADZONE:
				return
			dragging = true
			_from = mm.global_position
			_start = _scroll_pos()
			d = Vector2.ZERO
			propagate_notification(NOTIFICATION_SCROLL_BEGIN)   # cancels the button being pressed
			scroll_started.emit()
		var now := Time.get_ticks_usec()
		var dt := maxf(0.001, float(now - _last_t) / 1000000.0)
		var inst := -(mm.global_position - _last) * _axes() / dt
		_vel = _vel.lerp(inst, 0.6) if _vel != Vector2.ZERO else inst
		_last = mm.global_position
		_last_t = now
		var p := _start - d
		scroll_horizontal = int(round(p.x))
		scroll_vertical = int(round(p.y))
		accept_event()

func _process(delta: float) -> void:
	if fling.length() < 12.0:
		fling = Vector2.ZERO
		set_process(false)
		scroll_ended.emit()
		return
	_fpos += fling * delta
	scroll_horizontal = int(round(_fpos.x))
	scroll_vertical = int(round(_fpos.y))
	if _scroll_pos().distance_to(_fpos.round()) > 1.5:
		fling = Vector2.ZERO   # hit the end of the list
	fling *= exp(-FRICTION * delta)

## The list is moving (drag or fling): callers can ignore taps meanwhile.
func is_scrolling() -> bool:
	return dragging or fling != Vector2.ZERO
