class_name CmdIcons
extends RefCounted
## Small original glyphs for command-grid orders (move, stop, unload, ...).
## The grid shows these instead of a text caption. Names stay on the tooltip and the info card.

const N := 48
static var _cache := {}

static func of(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.94, 0.95, 0.93, 1.0)
	_paint(img, key, ink)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _paint(img: Image, key: String, col: Color) -> void:
	match key:
		"move":
			_arrow(img, 12, 34, 34, 12, col)
		"amove":
			_arrow(img, 11, 33, 30, 14, col)
			_ring(img, 33, 15, 7.5, col)
		"stop":
			img.fill_rect(Rect2i(13, 13, 22, 22), col)
		"guard":
			_shield(img, col)
		"scatter":
			_arrow(img, 24, 24, 24, 8, col)
			_arrow(img, 24, 24, 24, 40, col)
			_arrow(img, 24, 24, 8, 24, col)
			_arrow(img, 24, 24, 40, 24, col)
		"harvest":
			_arrow(img, 24, 8, 24, 28, col)
			_line(img, 12, 32, 36, 32, col, 2.4)
			_line(img, 14, 32, 16, 40, col, 2.2)
			_line(img, 34, 32, 32, 40, col, 2.2)
			_line(img, 16, 40, 32, 40, col, 2.2)
		"unload":
			img.fill_rect(Rect2i(12, 10, 24, 6), col)
			_arrow(img, 24, 18, 24, 40, col)
		"unload_all":
			_arrow(img, 16, 14, 16, 38, col)
			_arrow(img, 32, 14, 32, 38, col)
		"evacuate":
			_line(img, 14, 10, 14, 38, col, 2.6)
			_arrow(img, 16, 24, 38, 24, col)
		"rally":
			_line(img, 16, 8, 16, 42, col, 2.4)
			img.fill_rect(Rect2i(16, 8, 18, 12), col)
		"sell":
			_ring(img, 24, 22, 12, col)
			_arrow(img, 24, 18, 24, 40, col)
		"sell_ok":
			_line(img, 10, 26, 20, 38, col, 3.2)
			_line(img, 20, 38, 40, 12, col, 3.2)
		"more":
			_chevron(img, 14, 24, col)
			_chevron(img, 26, 24, col)
		"loop":
			_arc(img, 24, 24, 13, col, false)
		"loop_on":
			_arc(img, 24, 24, 13, col, true)
		"cancel":
			_line(img, 12, 12, 36, 36, col, 3.2)
			_line(img, 36, 12, 12, 36, col, 3.2)
		"resume":
			_tri(img, Vector2(16, 10), Vector2(16, 38), Vector2(38, 24), col)
		"unpack":
			img.fill_rect(Rect2i(12, 28, 24, 8), col)
			_arrow(img, 24, 26, 24, 8, col)
		"pack":
			img.fill_rect(Rect2i(12, 30, 24, 8), col)
			_arrow(img, 24, 8, 24, 28, col)
		"detonate":
			for i in 8:
				var a := float(i) * TAU / 8.0
				_line(img, 24 + cos(a) * 6.0, 24 + sin(a) * 6.0, 24 + cos(a) * 18.0, 24 + sin(a) * 18.0, col, 2.6)
		"exit":
			_line(img, 12, 10, 12, 38, col, 2.8)
			_arrow(img, 14, 24, 38, 24, col)
		_:
			_disc(img, 24, 24, 6, col)

static func _disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var r2 := r * r
	var x0 := maxi(0, int(floor(cx - r)))
	var x1 := mini(N - 1, int(ceil(cx + r)))
	var y0 := maxi(0, int(floor(cy - r)))
	var y1 := mini(N - 1, int(ceil(cy + r)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)

static func _ring(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var outer := r * r
	var inner := (r - 2.4) * (r - 2.4)
	var x0 := maxi(0, int(floor(cx - r - 1.0)))
	var x1 := mini(N - 1, int(ceil(cx + r + 1.0)))
	var y0 := maxi(0, int(floor(cy - r - 1.0)))
	var y1 := mini(N - 1, int(ceil(cy + r + 1.0)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d2 := (float(x) + 0.5 - cx) * (float(x) + 0.5 - cx) + (float(y) + 0.5 - cy) * (float(y) + 0.5 - cy)
			if d2 <= outer and d2 >= inner:
				img.set_pixel(x, y, col)

static func _line(img: Image, x0: float, y0: float, x1: float, y1: float, col: Color, thick: float = 2.4) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
	for i in steps + 1:
		var k := float(i) / float(maxi(1, steps))
		_disc(img, lerpf(x0, x1, k), lerpf(y0, y1, k), thick * 0.5, col)

static func _arrow(img: Image, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	_line(img, x0, y0, x1, y1, col, 2.6)
	var ang := atan2(y1 - y0, x1 - x0)
	_line(img, x1, y1, x1 + cos(ang + 2.5) * 9.0, y1 + sin(ang + 2.5) * 9.0, col, 2.6)
	_line(img, x1, y1, x1 + cos(ang - 2.5) * 9.0, y1 + sin(ang - 2.5) * 9.0, col, 2.6)

static func _chevron(img: Image, cx: float, cy: float, col: Color) -> void:
	_line(img, cx - 6, cy - 10, cx + 4, cy, col, 2.6)
	_line(img, cx + 4, cy, cx - 6, cy + 10, col, 2.6)

static func _shield(img: Image, col: Color) -> void:
	_line(img, 14, 10, 34, 10, col, 2.6)
	_line(img, 14, 10, 14, 26, col, 2.6)
	_line(img, 34, 10, 34, 26, col, 2.6)
	_line(img, 14, 26, 24, 40, col, 2.6)
	_line(img, 34, 26, 24, 40, col, 2.6)
	_line(img, 24, 16, 24, 30, col, 2.2)

static func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var minx := int(floor(minf(a.x, minf(b.x, c.x))))
	var maxx := int(ceil(maxf(a.x, maxf(b.x, c.x))))
	var miny := int(floor(minf(a.y, minf(b.y, c.y))))
	var maxy := int(ceil(maxf(a.y, maxf(b.y, c.y))))
	var area := _edge(a, b, c)
	if absf(area) < 0.001:
		return
	for y in range(maxi(0, miny), mini(N - 1, maxy) + 1):
		for x in range(maxi(0, minx), mini(N - 1, maxx) + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var w0 := _edge(b, c, p) / area
			var w1 := _edge(c, a, p) / area
			var w2 := _edge(a, b, p) / area
			if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
				img.set_pixel(x, y, col)

static func _edge(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x)

static func _arc(img: Image, cx: float, cy: float, r: float, col: Color, dot: bool) -> void:
	var pts := 28
	var prev := Vector2(cx + r, cy)
	for i in range(1, pts):
		var a := float(i) / float(pts) * TAU * 0.82 - 0.4
		var p := Vector2(cx + cos(a) * r, cy + sin(a) * r)
		_line(img, prev.x, prev.y, p.x, p.y, col, 2.4)
		prev = p
	var end_a := TAU * 0.82 - 0.4
	var tip := Vector2(cx + cos(end_a) * r, cy + sin(end_a) * r)
	_arrow(img, tip.x - cos(end_a + 1.2) * 8.0, tip.y - sin(end_a + 1.2) * 8.0, tip.x, tip.y, col)
	if dot:
		_disc(img, cx, cy, 3.2, col)
