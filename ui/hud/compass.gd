class_name HudCompass
extends HudButton
## M3.1: small compass on the top bar. The needle points to map north as the camera turns;
## tap to ease back to north-up.
var cam: CameraRig

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.32
	var a := cam.yaw if cam != null else 0.0
	var up := Vector2(0, -1).rotated(-a)
	var side := Vector2(up.y, -up.x)
	draw_colored_polygon(PackedVector2Array([c + up * r, c + side * r * 0.42, c - side * r * 0.42]), Color("#e04a3a"))
	draw_colored_polygon(PackedVector2Array([c - up * r, c + side * r * 0.42, c - side * r * 0.42]), Color(0.85, 0.85, 0.82, 0.8))
	var f := get_theme_default_font()
	draw_string(f, c + up * (r + 6.0) - Vector2(4, -4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.9))
