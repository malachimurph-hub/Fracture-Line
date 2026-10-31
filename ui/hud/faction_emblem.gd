class_name FactionEmblem
extends Control
## Faction insignia drawn in code for the HUD / menus (no texture assets). M3.0: factions are
## single nations, so each badge is a simple roundel in national flag colours (original designs,
## not official emblems):
##  Germany (id eu)  - black / red / gold horizontal bands
##  Iran (id tpla)   - green / white / red horizontal bands with a small red centre dot
##  Russia (id ecc)  - white / blue / red horizontal bands
##  US               - white five-point star in a steel-blue roundel (unchanged)
var fac: StringName = &"eu"
## M3.3: draw the national flag filling the rect (taskbar background) instead of the roundel
var flag_mode := false

const BANDS := {
	&"eu": [Color("#1a1a1a"), Color("#d0151c"), Color("#f2c200")],
	&"tpla": [Color("#239f40"), Color("#f4f4f4"), Color("#da1f26")],
	&"ecc": [Color("#f4f4f4"), Color("#1c3f9e"), Color("#d52b1e")],
}

func _draw() -> void:
	if flag_mode:
		draw_flag(self, fac, Rect2(Vector2.ZERO, size))
		return
	var s := minf(size.x, size.y)
	draw_roundel(self, fac, size * 0.5, s * 0.5 - 1.0)

static func circle_poly(c: Vector2, r: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

static func draw_roundel(ci: CanvasItem, f: StringName, c: Vector2, r: float) -> void:
	if f == &"us":
		var p := UiTheme.pal(f)
		ci.draw_circle(c, r, p["edge"])
		ci.draw_arc(c, r, 0, TAU, 32, p["frame"], 1.5, true)
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r * 0.78 if i % 2 == 0 else r * 0.32))
		ci.draw_colored_polygon(pts, Color.WHITE)
		return
	var bands: Array = BANDS.get(f, BANDS[&"eu"])
	var circ := circle_poly(c, r)
	for i in 3:
		var y0 := c.y - r + i * (2.0 * r / 3.0)
		var rect := PackedVector2Array([Vector2(c.x - r - 1, y0), Vector2(c.x + r + 1, y0), Vector2(c.x + r + 1, y0 + 2.0 * r / 3.0 + 0.5), Vector2(c.x - r - 1, y0 + 2.0 * r / 3.0 + 0.5)])
		for poly in Geometry2D.intersect_polygons(circ, rect):
			ci.draw_colored_polygon(poly, bands[i])
	if f == &"tpla":
		ci.draw_circle(c, r * 0.16, bands[2])
	ci.draw_arc(c, r, 0, TAU, 32, Color(0.85, 0.85, 0.85), maxf(1.0, r * 0.08), true)

## M3.3: a simple national flag in the rect (original drawing in flag colours, no assets).
static func draw_flag(ci: CanvasItem, f: StringName, r: Rect2) -> void:
	if f == &"us":
		for i in 13:
			var h := r.size.y / 13.0
			ci.draw_rect(Rect2(r.position + Vector2(0, i * h), Vector2(r.size.x, h + 0.5)), Color("#b22234") if i % 2 == 0 else Color.WHITE)
		var cn := Rect2(r.position, Vector2(r.size.x * 0.4, r.size.y * 7.0 / 13.0))
		ci.draw_rect(cn, Color("#3c3b6e"))
		var rows := 5
		var cols := 6
		var sr := cn.size.y / (rows * 3.2)
		for yy in rows:
			for xx in cols:
				var c := cn.position + Vector2((xx + 0.5 + (0.5 if yy % 2 == 1 else 0.0)) * cn.size.x / (cols + 0.5), (yy + 0.5) * cn.size.y / rows)
				ci.draw_circle(c, sr, Color.WHITE)
		return
	var bands: Array = BANDS.get(f, BANDS[&"eu"])
	var bh := r.size.y / 3.0
	for i in 3:
		ci.draw_rect(Rect2(r.position + Vector2(0, i * bh), Vector2(r.size.x, bh + 0.5)), bands[i])
	if f == &"tpla":
		ci.draw_circle(r.get_center(), bh * 0.3, bands[2])

## Small flag icon (texture) for option lists such as the skirmish lobby faction picker.
static func flag_texture(f: StringName, w: int = 24, h: int = 16, dark := false) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	if f == &"us":
		for y in h:
			var col := Color("#b22234") if (y * 7 / h) % 2 == 0 else Color.WHITE
			for x in w:
				img.set_pixel(x, y, col)
		img.fill_rect(Rect2i(0, 0, w * 2 / 5, h * 4 / 7), Color("#3c3b6e"))
	elif f in [&"jp", &"pl", &"cn", &"uk"]:
		_coming_soon_flag(img, f, w, h)   # M3.5: locked "Coming soon" factions
	else:
		var bands: Array = BANDS.get(f, BANDS[&"eu"])
		for y in h:
			for x in w:
				img.set_pixel(x, y, bands[mini(2, y * 3 / h)])
		if f == &"tpla":
			img.fill_rect(Rect2i(w / 2 - 1, h / 2 - 1, 2, 2), bands[2])
	if dark:   # M3.5: locked factions show a darkened, desaturated flag
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var l := c.get_luminance()
				img.set_pixel(x, y, Color(lerpf(c.r, l, 0.6) * 0.42, lerpf(c.g, l, 0.6) * 0.42, lerpf(c.b, l, 0.6) * 0.42, c.a))
	return ImageTexture.create_from_image(img)

## M3.5: simple flags for the factions shown as "Coming soon" (Japan, Poland, China, UK).
static func _coming_soon_flag(img: Image, f: StringName, w: int, h: int) -> void:
	match f:
		&"jp":
			img.fill(Color.WHITE)
			var c := Vector2(w * 0.5, h * 0.5)
			var r := h * 0.3
			for y in h:
				for x in w:
					if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
						img.set_pixel(x, y, Color("#bc002d"))
		&"pl":
			img.fill_rect(Rect2i(0, 0, w, h / 2), Color.WHITE)
			img.fill_rect(Rect2i(0, h / 2, w, h - h / 2), Color("#dc143c"))
		&"cn":
			img.fill(Color("#de2910"))
			img.fill_rect(Rect2i(w / 6, h / 5, maxi(2, w / 6), maxi(2, h / 4)), Color("#ffde00"))
			for k in 4:
				img.fill_rect(Rect2i(w / 3 + 1 + (k % 2) * 2, h / 10 + k * h / 8, 1, 1), Color("#ffde00"))
		&"uk":
			img.fill(Color("#012169"))
			for y in h:
				for x in w:
					var u := float(x) / w
					var v := float(y) / h
					if absf(u - v) < 0.09 or absf(u - (1.0 - v)) < 0.09:
						img.set_pixel(x, y, Color.WHITE)
					if absf(u - v) < 0.035 or absf(u - (1.0 - v)) < 0.035:
						img.set_pixel(x, y, Color("#c8102e"))
			img.fill_rect(Rect2i(0, h / 2 - h / 5, w, h * 2 / 5), Color.WHITE)
			img.fill_rect(Rect2i(w / 2 - h / 5, 0, h * 2 / 5, h), Color.WHITE)
			img.fill_rect(Rect2i(0, h / 2 - h / 9, w, maxi(1, h * 2 / 9)), Color("#c8102e"))
			img.fill_rect(Rect2i(w / 2 - h / 9, 0, maxi(1, h * 2 / 9), h), Color("#c8102e"))

