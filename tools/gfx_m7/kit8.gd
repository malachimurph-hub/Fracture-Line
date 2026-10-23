extends "res://tools/gfx_m7/kit7.gd"
## M2.7b vehicle kit: lofted chamfered hull sections, angled armour plates, treaded tyres,
## toothed sprockets, tapered barrels with muzzle brakes, and faction camo paint (class 20).

const VK7 := preload("res://tools/gfx_m3/vehicle_kit.gd")
const CAMO := 20

## Camo-painted surface: pattern 0 US, 1 EU, 2 TPLA (see model_m3.gdshaderinc).
func camo(c: Variant, pattern: int) -> void:
	color(c, CAMO)
	uv2 = Vector2(float(pattern), 0.0)

## Plain paint (also clears the camo pattern channel).
func paint(c: Variant, cls := PAINT) -> void:
	color(c, cls)
	uv2 = Vector2.ZERO

## Cross-section polygon (x, y) of a chamfered hull: bottom half-width wb at y0, waist half-width
## wm at ym, top half-width wt at y1 with chamfer ch on the top corners.
static func sect(y0: float, ym: float, y1: float, wb: float, wm: float, wt: float, ch: float) -> Array:
	return [Vector2(-wb, y0), Vector2(wb, y0), Vector2(wm, ym), Vector2(wt, y1 - ch), Vector2(wt - ch, y1),
		Vector2(-wt + ch, y1), Vector2(-wt, y1 - ch), Vector2(-wm, ym)]

## Loft through cross-sections along z: secs = [[z, polygon], ...] front-to-back or back-to-front,
## all polygons with the same vertex count. Each span is one convex piece.
func xloft(secs: Array, t := Transform3D.IDENTITY) -> void:
	for i in secs.size() - 1:
		var za: float = secs[i][0]
		var zb: float = secs[i + 1][0]
		var a: Array = []
		var b: Array = []
		for p: Vector2 in secs[i][1]:
			a.append(Vector3(p.x, p.y, za))
		for p: Vector2 in secs[i + 1][1]:
			b.append(Vector3(p.x, p.y, zb))
		loft(a, b, t, i == 0, i == secs.size() - 2)

## Angled armour plate: thin slab of size s centred at c, rotated by deg (x, y, z) degrees.
func plate(c: Vector3, s: Vector3, deg: Vector3) -> void:
	box(Vector3.ZERO, s, Transform3D(Basis.from_euler(deg * PI / 180.0), c))

## Tyre with a rounded shoulder profile and tread blocks (spins with the wheel classes).
func tyre(c: Vector3, r: float, w: float, steers := false, hub: Variant = "#3a3d40", seg := 14) -> void:
	var keep := _col
	uv = Vector2(c.y, c.z)
	uv2 = Vector2(c.x, r + (10.0 if steers else 0.0))
	var side := 1.0 if c.x >= 0.0 else -1.0
	color("#1d1c1b", WHEEL_RUBBER)
	# rounded shoulders: three coaxial bands
	tube(c - Vector3(w * 0.5, 0, 0), c - Vector3(w * 0.3, 0, 0), r * 0.93, seg)
	tube(c - Vector3(w * 0.32, 0, 0), c + Vector3(w * 0.32, 0, 0), r, seg)
	tube(c + Vector3(w * 0.3, 0, 0), c + Vector3(w * 0.5, 0, 0), r * 0.93, seg)
	color("#252423", WHEEL_RUBBER)
	for i in seg:   # chevron tread lugs
		var a := TAU * (float(i) + 0.5) / float(seg)
		var p := c + Vector3(0, sin(a), cos(a)) * (r + 0.005)
		for k in [-1.0, 1.0]:
			box(Vector3.ZERO, Vector3(w * 0.3, 0.014, r * 0.2), Transform3D(Basis(Vector3.RIGHT, a) * Basis(Vector3.UP, k * 0.35), p + Vector3(k * w * 0.17, 0, 0)))
	color(hub, WHEEL_STEEL)
	var o := c + Vector3(side * w * 0.5, 0, 0)
	tube(o - Vector3(side * 0.01, 0, 0), o + Vector3(side * 0.006, 0, 0), r * 0.6, seg)
	tube(o, o + Vector3(side * 0.028, 0, 0), r * 0.24, 8)
	for i in 6:
		var a2 := TAU * float(i) / 6.0
		box(o + Vector3(side * 0.012, sin(a2) * r * 0.42, cos(a2) * r * 0.42), Vector3(0.012, r * 0.1, r * 0.1))
	uv = Vector2.ZERO
	uv2 = Vector2.ZERO
	_col = keep

## Toothed drive sprocket / idler (spins with the road wheels).
func sprocket(c: Vector3, r: float, w: float, teeth: int, col: Variant) -> void:
	var keep := _col
	uv = Vector2(c.y, c.z)
	uv2 = Vector2(c.x, r)
	color(col, WHEEL_STEEL)
	tube(c - Vector3(w * 0.5, 0, 0), c + Vector3(w * 0.5, 0, 0), r * 0.86, 12)
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		box(Vector3.ZERO, Vector3(w * 0.7, r * 0.22, r * 0.18), Transform3D(Basis(Vector3.RIGHT, a), c + Vector3(0, sin(a), cos(a)) * r * 0.9))
	var side := 1.0 if c.x >= 0.0 else -1.0
	tube(c + Vector3(side * w * 0.5, 0, 0), c + Vector3(side * (w * 0.5 + 0.02), 0, 0), r * 0.35, 8)
	uv = Vector2.ZERO
	uv2 = Vector2.ZERO
	_col = keep

## Full track run along z at x = sx (both sides when both=true): track belt, road wheels with
## rubber rims, a toothed rear sprocket, front idler and return rollers.
func track_run(sx: float, l: float, n: int, rw: float, tw: float, steel: String, rubber := "#1d1c1b", both := true) -> void:
	var hl := l * 0.5
	for s in ([-sx, sx] if both else [sx]):
		VK7._track(self, s - tw * 0.5, s + tw * 0.5, Vector2(-hl + rw * 1.15, rw * 1.55), rw * 1.4, Vector2(hl - rw * 1.05, rw * 1.75), rw * 1.25, rw * 3.05)
		for i in n:
			var z := lerpf(-hl + rw * 2.55, hl - rw * 2.55, float(i) / float(maxi(1, n - 1)))
			var c := Vector3(s, rw * 1.12, z)
			uv = Vector2(c.y, c.z)
			uv2 = Vector2(c.x, rw)
			color(rubber, WHEEL_RUBBER)
			tube(c - Vector3(tw * 0.46, 0, 0), c + Vector3(tw * 0.46, 0, 0), rw, 12)
			color(steel, WHEEL_STEEL)
			var o := c + Vector3(signf(s) * tw * 0.46, 0, 0)
			tube(o - Vector3(signf(s) * 0.004, 0, 0), o + Vector3(signf(s) * 0.008, 0, 0), rw * 0.62, 10)
			tube(o, o + Vector3(signf(s) * 0.016, 0, 0), rw * 0.22, 6)
		sprocket(Vector3(s, rw * 1.55, -hl + rw * 1.15), rw * 1.15, tw * 0.8, 10, steel)
		sprocket(Vector3(s, rw * 1.75, hl - rw * 1.05), rw * 0.95, tw * 0.75, 0, steel)
		color(steel, STEEL)
		for k in 2:   # return rollers
			var zr := lerpf(-hl * 0.45, hl * 0.45, float(k))
			tube(Vector3(s - tw * 0.3, rw * 2.85, zr), Vector3(s + tw * 0.3, rw * 2.85, zr), rw * 0.32, 6)
	uv = Vector2.ZERO
	uv2 = Vector2.ZERO

## Tapered gun barrel along +z from z0 (radius r0) to z1 (radius r1) with an optional fume
## extractor bulge, clamps and a slotted muzzle brake.
func gun(z0: float, z1: float, r0: float, r1: float, fume_at := -1.0, brake := true, seg := 10) -> void:
	tube(Vector3(0, 0, z0), Vector3(0, 0, z1), r0, seg, r1)
	if fume_at > 0.0:
		var zf := lerpf(z0, z1, fume_at)
		var rf := lerpf(r0, r1, fume_at)
		tube(Vector3(0, 0, zf - 0.07), Vector3(0, 0, zf + 0.07), rf * 1.35, seg)
	if brake:
		box(Vector3(0, 0, z1 + 0.035), Vector3(r1 * 3.2, r1 * 2.2, 0.07))
		var keep := _col
		color("#1c1d1c", DARK)
		for k in [-1.0, 1.0]:
			box(Vector3(k * r1 * 1.61, 0, z1 + 0.035), Vector3(0.004, r1 * 1.4, 0.045))
		_col = keep
