class_name WorldInput
extends Node
## Gesture recognizer (GDD 6.1) + mouse/keyboard scheme (GDD 6.6). Works in logical (dp)
## coordinates - the root viewport's stretch transform already maps events into them.
##
## Touch: drag = pan (with inertia) | tap = select / smart order | hold 350 ms + drag = box
## select (haptic tick) | hold + release = attack-move | double-tap = select all of type on
## screen | two-finger tap = cancel / deselect | pinch = zoom (3 soft levels).
## Mouse emulated from touch (device == -1) is ignored here; touch is handled directly.

signal box_changed(rect: Rect2, active: bool)
signal hold_progress(pos: Vector2, k: float)

enum G { IDLE, PENDING, PAN, HOLD, BOX, GHOST, MULTI }

var ctl: PlayerController
var cam: CameraRig
var hud  ## must provide blocks(pos: Vector2) -> bool
var touches: Dictionary = {}       ## index -> {start, pos, t0}
var state: int = G.IDLE
var start_pos := Vector2.ZERO
var last_pos := Vector2.ZERO
var t_down: int = 0
var drag_vel := Vector2.ZERO
var last_move_ms: int = 0
var last_tap_ms: int = -10000
var last_tap_pos := Vector2(-999, -999)
var pinch_d0: float = 0.0
var pinch_mid := Vector2.ZERO
var multi_t0: int = 0
var multi_moved: bool = false
var multi_max: int = 0
var haptic_done: bool = false
## mouse
var m_down: bool = false
var m_start := Vector2.ZERO
var m_box: bool = false
var m_pan: bool = false
var key_pan := Vector2.ZERO
var enabled: bool = true

func _deadzone() -> float:
	return float(Settings.g("drag_deadzone_dp"))

func _hold_ms() -> int:
	return int(Settings.g("hold_ms"))

func _offset() -> Vector2:
	return Vector2(0, -UiScale.mm(float(Settings.g("ghost_offset_mm"))))

## Test harness only: when >= 0 the gesture clock reads this instead of wall time, so the
## touch test is independent of the (software-rendered, ~3 fps) frame rate on CI.
static var test_clock_ms: int = -1

func _now() -> int:
	return test_clock_ms if test_clock_ms >= 0 else Time.get_ticks_msec()

func _unhandled_input(ev: InputEvent) -> void:
	if not enabled:
		return
	if ev is InputEventScreenTouch:
		_touch(ev)
	elif ev is InputEventScreenDrag:
		_drag(ev)
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_button(ev)
	elif ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_motion(ev)
	elif ev is InputEventMagnifyGesture:
		cam.pinch(ev.factor)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev)

# ------------------------------------------------------------------ touch
func _touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if touches.is_empty() and hud != null and hud.blocks(ev.position):
			return
		touches[ev.index] = {"start": ev.position, "pos": ev.position, "t0": _now()}
		if touches.size() == 1:
			state = G.PENDING
			start_pos = ev.position
			last_pos = ev.position
			t_down = _now()
			drag_vel = Vector2.ZERO
			haptic_done = false
			cam.velocity = Vector3.ZERO
			if ctl.mode == PlayerController.Mode.PLACE and _near_ghost(ev.position):
				state = G.GHOST
				ctl.move_ghost_screen(ev.position + _offset())
		elif touches.size() >= 2:
			if state == G.BOX:
				box_changed.emit(Rect2(), false)
			if state != G.MULTI:
				multi_t0 = _now()
				multi_moved = false
			state = G.MULTI
			multi_max = maxi(multi_max, touches.size())
			_pinch_reset()
		get_viewport().set_input_as_handled()
		return
	# release
	if not touches.has(ev.index):
		return
	touches.erase(ev.index)
	get_viewport().set_input_as_handled()
	if state == G.MULTI:
		if touches.is_empty():
			if not multi_moved and _now() - multi_t0 < 350 and multi_max >= 2:
				_two_finger_tap()
			cam.snap_zoom()
			state = G.IDLE
			multi_max = 0
		else:
			_pinch_reset()
		return
	if not touches.is_empty():
		return
	var p := ev.position
	match state:
		G.PENDING:
			_tap(p)
		G.PAN:
			if Settings.g("camera_inertia") and _now() - last_move_ms < 80:
				cam.fling(drag_vel)
		G.HOLD:
			_hold_release(p)
		G.BOX:
			ctl.box_select(Rect2(start_pos + _offset(), p - start_pos))
			box_changed.emit(Rect2(), false)
		G.GHOST:
			pass   # releasing a finger never places a building (GDD 6.5)
	state = G.IDLE
	hold_progress.emit(p, 0.0)

func _drag(ev: InputEventScreenDrag) -> void:
	if not touches.has(ev.index):
		return
	touches[ev.index]["pos"] = ev.position
	get_viewport().set_input_as_handled()
	if state == G.MULTI:
		_pinch_update()
		return
	var p := ev.position
	match state:
		G.PENDING:
			if p.distance_to(start_pos) > _deadzone():
				state = G.PAN
				cam.pan_screen(p - last_pos)
		G.PAN:
			cam.pan_screen(p - last_pos)
			var dt := maxf(1.0, float(_now() - last_move_ms))
			drag_vel = drag_vel.lerp((p - last_pos) / dt * 1000.0, 0.5)
		G.HOLD:
			if p.distance_to(start_pos) > _deadzone():
				state = G.BOX
		G.GHOST:
			ctl.move_ghost_screen(p + _offset())
	if state == G.BOX:
		# box corner is drawn offset above the finger so it stays visible
		box_changed.emit(Rect2(start_pos + _offset(), p - start_pos), true)
	last_pos = p
	last_move_ms = _now()

func _process(delta: float) -> void:
	if state == G.PENDING:
		var held := _now() - t_down
		if held >= 120:
			hold_progress.emit(start_pos, clampf(float(held) / float(_hold_ms()), 0.0, 1.0))
		if held >= _hold_ms():
			state = G.HOLD
			hold_progress.emit(start_pos, 0.0)
			if Settings.g("haptics") and not haptic_done:
				Input.vibrate_handheld(15)
				haptic_done = true
	# keyboard pan
	var kp := Vector2.ZERO
	if not _typing():
		if Input.is_physical_key_pressed(KEY_LEFT): kp.x -= 1
		if Input.is_physical_key_pressed(KEY_RIGHT): kp.x += 1
		if Input.is_physical_key_pressed(KEY_UP): kp.y -= 1
		if Input.is_physical_key_pressed(KEY_DOWN): kp.y += 1
		if not Input.is_key_pressed(KEY_CTRL):
			if Input.is_physical_key_pressed(KEY_W): kp.y -= 1
			if Input.is_physical_key_pressed(KEY_S) and kp.y == 0 and _s_is_pan(): kp.y += 1
			if Input.is_physical_key_pressed(KEY_D): kp.x += 1
			if Input.is_physical_key_pressed(KEY_A) and ctl.own_units_selected().is_empty(): kp.x -= 1
	if kp != Vector2.ZERO:
		cam.focus += Vector3(kp.x, 0, kp.y) * cam.dist * 0.9 * delta
	if Settings.g("edge_pan") and not UiScale.is_mobile() and DisplayServer.window_is_focused():
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		var e := Vector2.ZERO
		if mp.x < 4: e.x = -1
		elif mp.x > vs.x - 4: e.x = 1
		if mp.y < 4: e.y = -1
		elif mp.y > vs.y - 4: e.y = 1
		cam.focus += Vector3(e.x, 0, e.y) * cam.dist * 0.8 * delta

## WASD panning collides with A (attack-move) and S (stop) per GDD 6.6: A/S pan only when no
## units are selected; with a selection they are commands.
func _s_is_pan() -> bool:
	return ctl.own_units_selected().is_empty()

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _pinch_reset() -> void:
	var pts := _two()
	if pts.size() < 2:
		return
	pinch_d0 = maxf(1.0, pts[0].distance_to(pts[1]))
	pinch_mid = (pts[0] + pts[1]) * 0.5

func _pinch_update() -> void:
	var pts := _two()
	if pts.size() < 2:
		return
	var d := maxf(1.0, pts[0].distance_to(pts[1]))
	var mid: Vector2 = (pts[0] + pts[1]) * 0.5
	if absf(d - pinch_d0) > 6.0 or mid.distance_to(pinch_mid) > 6.0:
		multi_moved = true
	cam.pinch(d / pinch_d0)
	cam.pan_screen(mid - pinch_mid)
	pinch_d0 = d
	pinch_mid = mid

func _two() -> Array:
	var out: Array = []
	for k in touches:
		out.append(touches[k]["pos"])
		if out.size() == 2:
			break
	return out

func _near_ghost(p: Vector2) -> bool:
	var d := Content.building(ctl.place_def)
	var c := Vector3(ctl.place_tile.x + d.footprint.x * 0.5, 0, ctl.place_tile.y + d.footprint.y * 0.5)
	var sp := cam.cam.unproject_position(c)
	return sp.distance_to(p + _offset()) < 90.0 or sp.distance_to(p) < 90.0

func _tap(p: Vector2) -> void:
	var now := _now()
	var is_double := now - last_tap_ms < int(Settings.g("double_tap_ms")) and p.distance_to(last_tap_pos) < 30.0
	last_tap_ms = now
	last_tap_pos = p
	if ctl.mode == PlayerController.Mode.PLACE:
		ctl.move_ghost_screen(p)
		return
	if ctl.mode == PlayerController.Mode.TARGET:
		ctl.complete_target(p)
		return
	if is_double:
		ctl.select_same_type(p)
		last_tap_ms = -10000
		return
	tap_select_or_order(p)

## Tap rules: own entity -> select it. Otherwise, with own units selected -> smart order.
## Otherwise select whatever is there (enemy/neutral info) or deselect on empty ground.
func tap_select_or_order(p: Vector2) -> void:
	var id := ctl.pick(p, true)
	var e := ctl.sim.get_ent(id)
	if e != null and ctl.is_own(e):
		ctl.set_selection([id])
		return
	if not ctl.own_units_selected().is_empty() or not ctl.selected_buildings().is_empty():
		ctl.smart_command(p)
		return
	if e != null:
		ctl.set_selection([id])
	else:
		ctl.set_selection([])

func _hold_release(p: Vector2) -> void:
	if ctl.own_units_selected().is_empty():
		return
	if Settings.g("hold_action") == "move":
		ctl.smart_command(p)
	else:
		ctl.attack_move(p)

func _two_finger_tap() -> void:
	if ctl.mode != PlayerController.Mode.NONE:
		ctl.cancel_mode()
	else:
		ctl.set_selection([])

# ------------------------------------------------------------------ mouse
func _mouse_button(ev: InputEventMouseButton) -> void:
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
		cam.set_level(cam.level - 1)
		return
	if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
		cam.set_level(cam.level + 1)
		return
	if ev.button_index == MOUSE_BUTTON_MIDDLE:
		m_pan = ev.pressed
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		if ctl.mode != PlayerController.Mode.NONE:
			ctl.cancel_mode()
		else:
			ctl.smart_command(ev.position)
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if ev.pressed:
		if hud != null and hud.blocks(ev.position):
			return
		m_down = true
		m_box = false
		m_start = ev.position
		return
	if not m_down:
		return
	m_down = false
	if m_box:
		ctl.box_select(Rect2(m_start, ev.position - m_start), ev.shift_pressed)
		box_changed.emit(Rect2(), false)
		m_box = false
		return
	if ctl.mode == PlayerController.Mode.PLACE:
		ctl.move_ghost_screen(ev.position)
		ctl.confirm_place()
		return
	if ctl.mode == PlayerController.Mode.TARGET:
		ctl.complete_target(ev.position)
		return
	if ev.double_click:
		ctl.select_same_type(ev.position)
		return
	if not ctl.select_at(ev.position, ev.shift_pressed) and not ev.shift_pressed:
		ctl.set_selection([])

func _mouse_motion(ev: InputEventMouseMotion) -> void:
	if m_pan:
		cam.pan_screen(ev.relative)
		return
	if ctl.mode == PlayerController.Mode.PLACE and not m_down:
		ctl.move_ghost_screen(ev.position)
	if m_down and not m_box and ev.position.distance_to(m_start) > 6.0 and ctl.mode == PlayerController.Mode.NONE:
		m_box = true
	if m_box:
		box_changed.emit(Rect2(m_start, ev.position - m_start), true)

# ------------------------------------------------------------------ keys
func _key(ev: InputEventKey) -> void:
	if _typing():
		return
	var k := ev.keycode
	if k >= KEY_1 and k <= KEY_5:
		var i := int(k - KEY_1)
		if ev.ctrl_pressed:
			ctl.group_assign(i)
		else:
			ctl.group_select(i)
		get_viewport().set_input_as_handled()
		return
	var has_units := not ctl.own_units_selected().is_empty()
	match k:
		KEY_A:
			if has_units:
				ctl.begin_target("amove")
		KEY_S:
			if has_units:
				ctl.simple("stop")
		KEY_G:
			if has_units:
				ctl.begin_target("guard")
		KEY_R:
			if ctl.mode == PlayerController.Mode.PLACE:
				ctl.rotate_ghost()
		KEY_ESCAPE:
			if ctl.mode != PlayerController.Mode.NONE:
				ctl.cancel_mode()
			elif not ctl.selection.is_empty():
				ctl.set_selection([])
			elif hud != null:
				hud.toggle_pause_menu()
		KEY_B:
			if hud != null:
				hud.open_build()
		KEY_P:
			if hud != null:
				hud.toggle_pause()
		KEY_SPACE:
			if hud != null:
				hud.jump_last_alert()
		KEY_ENTER, KEY_KP_ENTER:
			if ctl.mode == PlayerController.Mode.PLACE:
				ctl.confirm_place()
		KEY_EQUAL, KEY_KP_ADD:
			cam.set_level(cam.level - 1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			cam.set_level(cam.level + 1)
