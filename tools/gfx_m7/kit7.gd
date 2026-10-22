extends "res://tools/gfx_m3/geo.gd"
## M2.7 detail kit (tool-time only): real chamfered solids, stacked lofts (domes, cooling
## towers), ribs, railings, ladders, pipe runs, grilles, hazard stripes, and vertex-animated parts
## (class 18 spinners, class 19 pulsing lamps; see model_m3.gdshaderinc). Still one surface /
## one draw call per mesh; spinners and pulse lamps live inside the hull mesh.

const SPIN := 18
const PULSE := 19

## Box with true 45-degree chamfers on all 12 edges (26 faces, 44 tris): edges catch the light.
func cbox(c: Vector3, s: Vector3, ch: float, t: Transform3D = Transform3D.IDENTITY) -> void:
	var h := s * 0.5
	ch = minf(ch, minf(h.x, minf(h.y, h.z)) * 0.95)
	var pts: Array = []
	var fs: Array = []
	# 24 points: each corner split into 3 (one per axis inset pair)
	var P := func(sx: float, sy: float, sz: float, ax: int) -> Vector3:
		var v := Vector3(sx * h.x, sy * h.y, sz * h.z)
		if ax != 0: v.x -= sx * ch
		if ax != 1: v.y -= sy * ch
		if ax != 2: v.z -= sz * ch
		return v
	# faces: +-x, +-y, +-z
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var q: Array = []
			for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var v := Vector3.ZERO
				if ax == 0: v = P.call(sg, k[0], k[1], 0)
				elif ax == 1: v = P.call(k[0], sg, k[1], 1)
				else: v = P.call(k[0], k[1], sg, 2)
				q.append(v)
			fs.append(q)
	# 12 edge bevels
	for sa in [-1.0, 1.0]:
		for sb in [-1.0, 1.0]:
			# edges along x (between y and z faces)
			fs.append([P.call(-1, sa, sb, 1), P.call(1, sa, sb, 1), P.call(1, sa, sb, 2), P.call(-1, sa, sb, 2)])
			# along y (between x and z faces)
			fs.append([P.call(sa, -1, sb, 0), P.call(sa, 1, sb, 0), P.call(sa, 1, sb, 2), P.call(sa, -1, sb, 2)])
			# along z (between x and y faces)
			fs.append([P.call(sa, sb, -1, 0), P.call(sa, sb, 1, 0), P.call(sa, sb, 1, 1), P.call(sa, sb, -1, 1)])
	# 8 corner triangles
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				fs.append([P.call(sx, sy, sz, 0), P.call(sx, sy, sz, 1), P.call(sx, sy, sz, 2)])
	faces(fs, t * Transform3D(Basis.IDENTITY, c))

## Rotated chamfered box (Euler degrees).
func rcbox(c: Vector3, s: Vector3, ch: float, deg: Vector3) -> void:
	cbox(Vector3.ZERO, s, ch, Transform3D(Basis.from_euler(deg * PI / 180.0), c))

## Ring stack along +Y: profile = [[y, r], ...] bottom to top (each pair a convex frustum).
func lathe(profile: Array, seg: int, t: Transform3D, cap_bottom := true, cap_top := true) -> void:
	for i in profile.size() - 1:
		var a: Array = []
		var b: Array = []
		var y0: float = profile[i][0]
		var r0: float = profile[i][1]
		var y1: float = profile[i + 1][0]
		var r1: float = profile[i + 1][1]
		for k in seg:
			var ang := TAU * float(k) / float(seg)
			a.append(Vector3(cos(ang) * r0, y0, sin(ang) * r0))
			b.append(Vector3(cos(ang) * r1, y1, sin(ang) * r1))
		if r1 < 0.0005:
			var fs: Array = []
			for k in seg:
				fs.append([a[k], a[(k + 1) % seg], Vector3(0, y1, 0)])
			faces(fs, t)
		else:
			loft(a, b, t, cap_bottom and i == 0, cap_top and i == profile.size() - 2)

## Cylinder with a chamfered top rim.
func ccyl(r: float, h: float, ch: float, seg: int, t: Transform3D) -> void:
	lathe([[0.0, r], [h - ch, r], [h, r - ch]], seg, t)

## Dome: hemisphere-ish cap of radius r and height hgt starting at y=0.
func dome(r: float, hgt: float, rings: int, seg: int, t: Transform3D) -> void:
	var prof: Array = []
	for i in rings + 1:
		var a := PI * 0.5 * float(i) / float(rings)
		prof.append([sin(a) * hgt, cos(a) * r if i < rings else 0.0])
	lathe(prof, seg, t, false, false)

## n vertical ribs around a cylinder of radius r from y0 to y1.
func ribs(r: float, y0: float, y1: float, n: int, depth: float, w: float, t: Transform3D, phase := 0.0) -> void:
	for i in n:
		var a := TAU * float(i) / float(n) + phase
		var bas := Basis(Vector3.UP, -a)
		box(Vector3.ZERO, Vector3(depth, y1 - y0, w), t * Transform3D(bas, Vector3(cos(a) * (r + depth * 0.4), (y0 + y1) * 0.5, sin(a) * (r + depth * 0.4))))

## Thin band around a cylinder.
func band(r: float, y: float, hgt: float, out: float, seg: int, t: Transform3D) -> void:
	lathe([[y, r + out], [y + hgt, r + out]], seg, t)

## Railing along a polyline (posts + top and mid rails).
func rail(pts: Array, hgt := 0.12, post := 0.22, r := 0.006) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / post))
		for k in n + (1 if i == pts.size() - 2 else 0):
			var p := a.lerp(b, float(k) / float(n))
			tube(p, p + Vector3(0, hgt, 0), r, 3)
		tube(a + Vector3(0, hgt, 0), b + Vector3(0, hgt, 0), r, 3)
		tube(a + Vector3(0, hgt * 0.5, 0), b + Vector3(0, hgt * 0.5, 0), r * 0.8, 3)

## Railing ring around a cylinder.
func rail_ring(r: float, y: float, n: int, hgt := 0.12, t := Transform3D.IDENTITY) -> void:
	var pts: Array = []
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(t * Vector3(cos(a) * r, y, sin(a) * r))
	rail(pts, hgt, 10.0)
	for i in n:
		var a2 := TAU * float(i) / float(n)
		var p: Vector3 = t * Vector3(cos(a2) * r, y, sin(a2) * r)
		tube(p, p + Vector3(0, hgt, 0), 0.006, 3)

## Vertical ladder from p (bottom) up hgt, facing direction n (rungs along the side axis).
func ladder(p: Vector3, hgt: float, side: Vector3, w := 0.07) -> void:
	var s := side.normalized() * w * 0.5
	tube(p - s, p - s + Vector3(0, hgt, 0), 0.006, 3)
	tube(p + s, p + s + Vector3(0, hgt, 0), 0.006, 3)
	var y := 0.05
	while y < hgt:
		tube(p - s + Vector3(0, y, 0), p + s + Vector3(0, y, 0), 0.004, 3)
		y += 0.06

## Pipe run through points with flange collars at the joints.
func pipe(pts: Array, r: float, seg := 8) -> void:
	for i in pts.size() - 1:
		tube(pts[i], pts[i + 1], r, seg)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var d: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		tube(p - d * r * 0.6, p + d * r * 0.6, r * 1.35, seg)

## Flat bar grille (top surface) centred at c, w x d, n bars along x.
func grille(c: Vector3, w: float, d: float, n: int) -> void:
	box(c, Vector3(w, 0.01, d))
	for i in n:
		var x := -w * 0.5 + w * (float(i) + 0.5) / float(n)
		box(c + Vector3(x, 0.012, 0), Vector3(w / float(n) * 0.4, 0.014, d * 0.94))

## Diagonal hazard stripes on a vertical face (normal +z of t), w x h.
func hazard(c: Vector3, w: float, h: float, n: int, t := Transform3D.IDENTITY) -> void:
	var keep := _col
	color("#1d1c1a", PAINT)
	box(c, Vector3(w, h, 0.006), t)
	color("#d8a531", PAINT)
	for i in n:
		var x := -w * 0.5 + w * (float(i) + 0.5) / float(n)
		box(Vector3.ZERO, Vector3(w / float(n) * 0.45, h * 1.2, 0.008), t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(35)), c + Vector3(x, 0, 0.001)))
	_col = keep

## Spinning fan in a round housing (axis +Y) at c, radius r.
func fan(c: Vector3, r: float, blades: int, speed: float, housing: Variant = "#3a3d3a") -> void:
	var keep := _col
	color(housing, STEEL)
	lathe([[0.0, r + 0.03], [0.05, r + 0.03]], 12, Transform3D(Basis.IDENTITY, c), false, false)
	tube(c + Vector3(-r, 0.03, 0), c + Vector3(r, 0.03, 0), 0.006, 3)
	var pv: Vector3 = xf * c
	uv = Vector2(pv.x, pv.z)
	uv2 = Vector2(speed, 0.0)
	color("#2e302f", SPIN)
	cyl(r * 0.18, r * 0.16, 0.04, 8, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.005, 0)))
	for i in blades:
		var a := TAU * float(i) / float(blades)
		box(Vector3.ZERO, Vector3(r * 0.82, 0.008, r * 0.28), Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.35), c + Vector3(cos(a) * r * 0.5, 0.025, sin(a) * r * 0.5)))
	uv = Vector2.ZERO
	uv2 = Vector2.ZERO
	_col = keep

## Rotating radar / comms dish on a post: pivot c (top of post), dish radius r, tilt degrees.
func dish(c: Vector3, r: float, tilt: float, speed: float, painted := "#d9d9d4") -> void:
	var keep := _col
	var pv: Vector3 = xf * c
	uv = Vector2(pv.x, pv.z)
	uv2 = Vector2(speed, 1.0)
	color(painted, SPIN)
	var b := Basis(Vector3.RIGHT, deg_to_rad(-90 + tilt))
	var dt := Transform3D(b, c + b * Vector3(0, -0.04, 0))
	lathe([[0.0, r * 0.12], [r * 0.12, r * 0.55], [r * 0.3, r]], 14, dt, true, true)
	color("#3a3d3a", SPIN)
	tube(c, c + b * Vector3(0, r * 0.75, 0), 0.008, 3)   # feed horn arm
	box(c + b * Vector3(0, r * 0.78, 0), Vector3(0.03, 0.03, 0.03))
	box(c + Vector3(0, -0.02, 0), Vector3(0.06, 0.08, 0.06))   # yoke
	uv = Vector2.ZERO
	uv2 = Vector2.ZERO
	_col = keep

## Glowing (pulsing) band / window, phase offsets the breathing.
func pulse_color(c: Variant, phase := 0.0) -> void:
	color(c, PULSE)
	uv2 = Vector2(phase, 0.0)

func end_pulse() -> void:
	uv2 = Vector2.ZERO

## Lattice mast (square, tapering) from p up hgt, base half-width w.
func lattice(p: Vector3, hgt: float, w: float, levels := 5) -> void:
	var cs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for k in 4:
		var a: Vector2 = cs[k] * w
		var b2: Vector2 = cs[k] * w * 0.3
		tube(p + Vector3(a.x, 0, a.y), p + Vector3(b2.x, hgt, b2.y), 0.008, 3)
	for l in levels:
		var f0 := float(l) / float(levels)
		var f1 := float(l + 1) / float(levels)
		var w0 := lerpf(w, w * 0.3, f0)
		var w1 := lerpf(w, w * 0.3, f1)
		for k in 4:
			var a0: Vector2 = cs[k] * w0
			var a1: Vector2 = cs[(k + 1) % 4] * w0
			var b1: Vector2 = cs[(k + 1) % 4] * w1
			tube(p + Vector3(a0.x, hgt * f0, a0.y), p + Vector3(a1.x, hgt * f0, a1.y), 0.005, 3)
			tube(p + Vector3(a0.x, hgt * f0, a0.y), p + Vector3(b1.x, hgt * f1, b1.y), 0.004, 3)

## Window strip: dark frame + glass panes on a vertical face (normal +z of t).
func windows(c: Vector3, w: float, h: float, n: int, t := Transform3D.IDENTITY) -> void:
	var keep := _col
	color("#2b2d2c", DARK)
	box(c, Vector3(w, h, 0.012), t)
	color("#2a3a46", GLASS)
	for i in n:
		var x := -w * 0.5 + w * (float(i) + 0.5) / float(n)
		box(c + Vector3(x, 0, 0.007), Vector3(w / float(n) * 0.82, h * 0.78, 0.006), t)
	_col = keep

## Roll-up door with slats and a frame on a vertical face (normal +z).
func rollup(c: Vector3, w: float, h: float, t := Transform3D.IDENTITY) -> void:
	var keep := _col
	color("#55585a", STEEL)
	box(c + Vector3(0, 0, -0.004), Vector3(w + 0.06, h + 0.04, 0.02), t)
	color("#6a6d68", CORR)
	box(c + Vector3(0, 0, 0.006), Vector3(w, h, 0.01), t)
	color("#4a4d4a", STEEL)
	var n := int(h / 0.05)
	for i in n:
		box(c + Vector3(0, -h * 0.5 + (float(i) + 0.5) * h / float(n), 0.012), Vector3(w, 0.008, 0.004), t)
	_col = keep

## Insulator stack (transformer bushings).
func insulator(p: Vector3, hgt: float) -> void:
	var keep := _col
	color("#7b4a2a", PAINT)
	var y := 0.0
	while y < hgt:
		cyl(0.022, 0.022, 0.012, 6, Transform3D(Basis.IDENTITY, p + Vector3(0, y, 0)))
		tube(p + Vector3(0, y, 0), p + Vector3(0, y + 0.03, 0), 0.01, 5)
		y += 0.03
	_col = keep
