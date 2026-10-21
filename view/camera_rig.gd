class_name CameraRig
extends Node3D
## Tilted RTS camera (fixed ~55 deg pitch, north-up, Generals-like). Three soft zoom levels
## (close / default / far tactical), pan with inertia, clamped to the map.

signal zoom_level_changed(level: int)
const PITCH_DEG := 55.0
const FOV := 32.0
## camera distance per zoom level (close, default, far)
const LEVELS := [16.0, 27.0, 46.0]

var cam: Camera3D
var focus := Vector3(20, 0, 20)
var dist: float = LEVELS[1]
var target_dist: float = LEVELS[1]
var level: int = 1
var velocity := Vector3.ZERO
var map_size := Vector2(128, 128)
var history: Array = []   ## previous focus for "Back" after alert jumps

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	_apply()

func _process(delta: float) -> void:
	if velocity.length_squared() > 0.0001:
		focus += velocity * delta
		velocity = velocity.lerp(Vector3.ZERO, minf(1.0, delta * 5.0))
	dist = lerpf(dist, target_dist, minf(1.0, delta * 10.0))
	_apply()

func _apply() -> void:
	focus.x = clampf(focus.x, 4.0, map_size.x - 4.0)
	focus.z = clampf(focus.z, 4.0, map_size.y - 2.0)
	var pitch := deg_to_rad(PITCH_DEG)
	var off := Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.position = focus + off
	cam.look_at(focus, Vector3.UP)

func set_level(l: int) -> void:
	l = clampi(l, 0, LEVELS.size() - 1)
	if l != level:
		level = l
		zoom_level_changed.emit(l)
	target_dist = LEVELS[l]

## Continuous pinch zoom; snaps to the nearest level on release.
func pinch(factor: float) -> void:
	target_dist = clampf(target_dist / factor, LEVELS[0] * 0.85, LEVELS[2] * 1.1)
	dist = target_dist
	var l := nearest_level(target_dist)
	if l != level:
		level = l
		zoom_level_changed.emit(l)

func snap_zoom() -> void:
	set_level(nearest_level(target_dist))

func nearest_level(d: float) -> int:
	var best := 0
	for i in LEVELS.size():
		if absf(LEVELS[i] - d) < absf(LEVELS[best] - d):
			best = i
	return best

func ground_point(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return focus
	var t := -o.y / dir.y
	return o + dir * t

func pan_screen(delta_screen: Vector2) -> void:
	# move focus so the ground point under the finger stays under the finger
	var vp := get_viewport().get_visible_rect().size
	var c := vp * 0.5
	var a := ground_point(c)
	var b := ground_point(c - delta_screen)
	focus += Vector3(b.x - a.x, 0, b.z - a.z)
	_apply()

func fling(screen_velocity: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var c := vp * 0.5
	var a := ground_point(c)
	var b := ground_point(c - screen_velocity * 0.1)
	velocity = Vector3(b.x - a.x, 0, b.z - a.z) * 10.0

func jump_to(p: Vector3, remember: bool = true) -> void:
	if remember:
		history.append(focus)
		if history.size() > 5:
			history.pop_front()
	focus = Vector3(p.x, 0, p.z)
	velocity = Vector3.ZERO
	_apply()

func back() -> void:
	if not history.is_empty():
		jump_to(history.pop_back(), false)

## Visible ground rectangle corners (for the minimap frame).
func view_corners() -> Array:
	var vp := get_viewport().get_visible_rect().size
	return [ground_point(Vector2.ZERO), ground_point(Vector2(vp.x, 0)), ground_point(vp), ground_point(Vector2(0, vp.y))]
