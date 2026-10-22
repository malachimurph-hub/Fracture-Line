class_name PlaceConfirm
extends Control
## M2.6 (Malachi): building placement is confirmed with a ✓ / ✗ pair floating just above the
## ghost silhouette. ✓ is disabled while the spot is invalid (the ghost turns red), ✗ cancels.
## The pair follows the ghost every frame (projected from the 3D footprint top) and is clamped
## inside the safe area so it can never end up off-screen or under the command bar.
## Glyphs are drawn (no font dependency).

const SIZE := 52.0     ## dp, each button (>= 48 dp tap target)
const GAP := 14.0

var ok_btn: GlyphButton
var cancel_btn: GlyphButton

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_btn = GlyphButton.new()
	ok_btn.glyph = "ok"
	ok_btn.name = "PlaceOK"
	add_child(ok_btn)
	cancel_btn = GlyphButton.new()
	cancel_btn.glyph = "cancel"
	cancel_btn.name = "PlaceCancel"
	add_child(cancel_btn)
	size = Vector2(SIZE * 2 + GAP, SIZE)
	ok_btn.position = Vector2(0, 0)
	cancel_btn.position = Vector2(SIZE + GAP, 0)

## anchor: screen point (HUD logical units) of the top centre of the ghost.
func place_at(anchor: Vector2, bounds: Rect2) -> void:
	var p := anchor - Vector2(size.x * 0.5, size.y + 10.0)
	p.x = clampf(p.x, bounds.position.x + 4, bounds.end.x - size.x - 4)
	p.y = clampf(p.y, bounds.position.y + 4, bounds.end.y - size.y - 4)
	position = p

func set_valid(v: bool) -> void:
	if ok_btn.disabled == v:
		ok_btn.disabled = not v
		ok_btn.queue_redraw()


class GlyphButton extends Button:
	var glyph := "ok"

	func _init() -> void:
		custom_minimum_size = Vector2(PlaceConfirm.SIZE, PlaceConfirm.SIZE)
		size = custom_minimum_size
		focus_mode = Control.FOCUS_NONE
		flat = true
		pressed.connect(func(): AudioDirector.ui("click"))
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 2.0
		var ok := glyph == "ok"
		var base := Color("#2fbf5a") if ok else Color("#c2402f")
		if disabled:
			base = Color(0.32, 0.32, 0.34)
		if is_pressed():
			base = base.darkened(0.3)
		draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, base)
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.85 if not disabled else 0.35), 2.5, true)
		var ink := Color.WHITE if not disabled else Color(0.6, 0.6, 0.6)
		var k := r * 0.5
		if ok:
			draw_polyline(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(-k * 0.25, k * 0.75), c + Vector2(k, -k * 0.7)]), ink, 5.0, true)
		else:
			draw_line(c + Vector2(-k, -k) * 0.8, c + Vector2(k, k) * 0.8, ink, 5.0, true)
			draw_line(c + Vector2(k, -k) * 0.8, c + Vector2(-k, k) * 0.8, ink, 5.0, true)
