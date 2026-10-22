class_name FactionEmblem
extends Control
## M2.6 faction insignia drawn in code for the HUD / menus (no texture assets):
##  EU   - gold ring of twelve stars-as-dots around a cyan core
##  TPLA - rust chevron-and-spanner badge on a sand triangle
##  US   - white five-point star in a steel-blue roundel
var fac: StringName = &"eu"

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5 - 1.0
	var p := UiTheme.pal(fac)
	match fac:
		&"tpla":
			var tri := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.8), c + Vector2(-r * 0.95, r * 0.8)])
			draw_colored_polygon(tri, Color(p["accent"]).darkened(0.15))
			draw_polyline(tri + PackedVector2Array([tri[0]]), p["frame"], 2.0, true)
			var k := r * 0.45
			draw_polyline(PackedVector2Array([c + Vector2(-k, k * 0.2), c + Vector2(0, -k * 0.6), c + Vector2(k, k * 0.2)]), p["frame"].darkened(0.3), 3.0, true)
			draw_line(c + Vector2(-k * 0.8, k * 0.75), c + Vector2(k * 0.8, k * 0.75), p["frame"].darkened(0.3), 3.0, true)
		&"us":
			draw_circle(c, r, p["edge"])
			draw_arc(c, r, 0, TAU, 32, p["frame"], 1.5, true)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 0.78 if i % 2 == 0 else r * 0.32))
			draw_colored_polygon(pts, Color.WHITE)
		_:
			draw_circle(c, r, Color(0.08, 0.12, 0.2))
			draw_circle(c, r * 0.32, Color(p["accent"], 0.85))
			for i in 12:
				var a := i * TAU / 12.0
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.72, maxf(1.2, r * 0.11), p["frame"])
