extends SceneTree
## T-14 from the owner's dimensioned drawings. One scale: the live T-90's width
## (1.53 units) divided by the real T-90 width (3.78 m). Every T-14 millimetre uses
## that same scale, so the slopes stay in the drawing's proportions and the tank
## is wider, longer and taller than the in-game T-90.
##   godot --headless --path . -s res://tools/m47/t14_draw.gd
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const S := 1.53 / 3.78
const OLIVE := "#6a7450"
const OLIVE_D := "#555c42"
const OLIVE_L := "#7d8660"
const STEEL := "#3a3d38"
const RUBBER := "#1d1c1b"
const PAINT := 0
const TEAM := 1
const TRACK := 4
const LAMP := 5
const STEEL_C := 6
const WHEEL := 7
const WHEEL_S := 8
const DARK := 16

var st: SurfaceTool
var tris := 0

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 2.35, "bar_height": 1.6, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var hull := _mesh()
	_hull(hull)
	var hmi := VK._mi(model, root, "Hull", _commit(hull, mat))
	hmi.set_meta("moves", true)
	var piv := VK._n3(model, root, "TurretPivot", _v(0.0, 2.132, 0.55))
	var tur := _mesh()
	_turret(tur)
	VK._mi(piv, root, "Turret", _commit(tur, mat))
	var bn := VK._n3(piv, root, "Barrel", _v(0.0, 0.28, 0.85))
	var bar := _mesh()
	_barrel(bar)
	VK._mi(bn, root, "BarrelMesh", _commit(bar, mat))
	print("T14 DRAW tris hull %d turret %d barrel %d scale %.4f" % [hull_tris, tur_tris, bar_tris, S])
	VK._save(root, "res://view/units/ecc/t14.tscn", 1.6)
	quit(0)

var hull_tris := 0
var tur_tris := 0
var bar_tris := 0

func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * S

func _mesh() -> SurfaceTool:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	return s

func _col(hex: String, cls: int) -> Color:
	var c := Color(hex)
	c.a = float(cls) / 20.0
	return c

func _tri(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, uv := Vector2.ZERO, uv2 := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	for p in [a, b, c]:
		s.set_normal(n)
		s.set_color(col)
		s.set_uv(uv)
		s.set_uv2(uv2)
		s.add_vertex(p)
	tris += 1

func _quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(s, a, b, c, col)
	_tri(s, a, c, d, col)

func _commit(s: SurfaceTool, mat: Material) -> ArrayMesh:
	var n := tris
	if s == null:
		return ArrayMesh.new()
	s.index()
	var arrays := s.commit_to_arrays()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var ld := {}
	for l in im.get_surface_lod_count(0):
		ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], ld)
	m.surface_set_material(0, mat)
	tris = 0
	if hull_tris == 0:
		hull_tris = n
	elif tur_tris == 0:
		tur_tris = n
	else:
		bar_tris = n
	return m

func _ring(stn: Dictionary) -> Array:
	var belly: float = stn["belly"]
	var roof: float = stn["roof"]
	var hw_low: float = stn["low"]
	var hw_spon: float = stn["spon"]
	var hw_roof: float = stn["roofw"]
	var y_spon: float = lerpf(belly, roof, 0.42)
	var right := [
		Vector2(hw_low * 0.2, belly),
		Vector2(hw_low, belly),
		Vector2(hw_spon, y_spon),
		Vector2(hw_spon, lerpf(y_spon, roof, 0.55)),
		Vector2(hw_roof + 0.08, roof - 0.10),
		Vector2(hw_roof, roof),
	]
	var pts: Array = []
	for p in right:
		pts.append(p)
	for i in range(right.size() - 1, -1, -1):
		pts.append(Vector2(-(right[i] as Vector2).x, (right[i] as Vector2).y))
	return pts

func _hull(s: SurfaceTool) -> void:
	# z is metres from the hull centre, +forward. Roof 2.132 m, skirts added apart.
	var stations := [
		{"z": -4.44, "belly": 0.62, "roof": 1.72, "low": 1.20, "spon": 1.42, "roofw": 1.05},
		{"z": -4.05, "belly": 0.50, "roof": 2.05, "low": 1.38, "spon": 1.58, "roofw": 1.154},
		{"z": 2.20, "belly": 0.50, "roof": 2.132, "low": 1.38, "spon": 1.58, "roofw": 1.154},
		{"z": 3.55, "belly": 0.52, "roof": 1.48, "low": 1.15, "spon": 1.28, "roofw": 0.90},
		{"z": 4.12, "belly": 0.82, "roof": 1.05, "low": 0.72, "spon": 0.82, "roofw": 0.55},
		{"z": 4.44, "belly": 0.92, "roof": 0.92, "low": 0.38, "spon": 0.42, "roofw": 0.32},
	]
	var rings: Array = []
	for stn in stations:
		var ring: Array = []
		for p in _ring(stn):
			ring.append(_v((p as Vector2).x, (p as Vector2).y, stn["z"]))
		rings.append(ring)
	var paint := _col(OLIVE, PAINT)
	var paint_d := _col(OLIVE_D, PAINT)
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var col := paint if i % 2 == 0 else paint_d
		for k in a.size():
			var k2 := (k + 1) % a.size()
			_quad(s, a[k], a[k2], b[k2], b[k], col)
	_cap(s, rings[0], paint_d, true)
	_cap(s, rings[rings.size() - 1], paint, false)
	_skirts(s)
	_stern_cage(s)
	_fittings(s)
	_wheels(s)

func _cap(s: SurfaceTool, ring: Array, col: Color, rear: bool) -> void:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	c /= float(ring.size())
	for k in ring.size():
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % ring.size()]
		if rear:
			_tri(s, c, b, a, col)
		else:
			_tri(s, c, a, b, col)

func _skirts(s: SurfaceTool) -> void:
	var col := _col(OLIVE, PAINT)
	var col_d := _col(OLIVE_D, PAINT)
	var n := 14
	var z0 := -3.35
	var z1 := 3.25
	for side in [-1.0, 1.0]:
		var x: float = side * 1.96
		for i in n:
			var za := lerpf(z0, z1, float(i) / float(n))
			var zb := lerpf(z0, z1, float(i + 1) / float(n))
			var yb: float = 0.72 if i % 2 == 0 else 0.98
			var c := col if i % 2 == 0 else col_d
			var a := _v(x, yb, za)
			var b2 := _v(x, 1.62, za)
			var d := _v(x, yb, zb)
			var e := _v(x, 1.62, zb)
			if side > 0.0:
				_quad(s, a, d, e, b2, c)
			else:
				_quad(s, a, b2, e, d, c)
			_quad(s, _v(x - side * 0.04, yb, za), _v(x, yb, za), _v(x, yb, zb), _v(x - side * 0.04, yb, zb), col_d)

func _stern_cage(s: SurfaceTool) -> void:
	var col := _col(STEEL, STEEL_C)
	for i in 9:
		var x := lerpf(-1.15, 1.15, float(i) / 8.0)
		_box(s, _v(x, 1.22, -4.58), Vector3(0.02, 0.55, 0.04) * S, col)
	_box(s, _v(0.0, 1.70, -4.58), Vector3(1.20, 0.02, 0.04) * S, col)
	_box(s, _v(0.0, 0.78, -4.58), Vector3(1.20, 0.02, 0.04) * S, col)

func _fittings(s: SurfaceTool) -> void:
	var paint := _col(OLIVE_D, PAINT)
	var dark := _col("#1c1e1c", DARK)
	var lamp := _col("#ffe2a0", LAMP)
	# Rear side fuel tanks and exhaust slots. No markings.
	for side in [-1.0, 1.0]:
		_box(s, _v(side * 1.48, 1.15, -3.15), Vector3(0.28, 0.22, 0.55) * S, paint)
		_box(s, _v(side * 1.55, 1.35, -3.85), Vector3(0.06, 0.18, 0.22) * S, dark)
		_box(s, _v(side * 0.55, 0.78, 4.46), Vector3(0.08, 0.05, 0.02) * S, lamp)
	_box(s, _v(1.62, 1.25, 0.2), Vector3(0.012, 0.04, 0.45) * S, _col("#ffffff", TEAM))

func _wheels(s: SurfaceTool) -> void:
	var spacing := 5.491 / 6.0
	var front := 2.50
	for i in 7:
		var z := front - spacing * float(i)
		for side in [-1.0, 1.0]:
			_wheel(s, _v(side * 1.58, 0.42, z), 0.35 * S, 0.42 * S, false)
	for side in [-1.0, 1.0]:
		_wheel(s, _v(side * 1.58, 0.50, 3.40), 0.28 * S, 0.36 * S, false)
		_wheel(s, _v(side * 1.58, 0.48, -3.62), 0.32 * S, 0.38 * S, false)
		for k in 3:
			var z := lerpf(-2.2, 2.2, float(k) / 2.0)
			_wheel(s, _v(side * 1.58, 0.92, z), 0.09 * S, 0.16 * S, false)
	_track_run(s, 1.58)
	_track_run(s, -1.58)

func _wheel(s: SurfaceTool, c: Vector3, r: float, w: float, _steer: bool) -> void:
	var seg := 12
	var uv := Vector2(c.y, c.z)
	var uv2 := Vector2(c.x, r)
	var rub := _col(RUBBER, WHEEL)
	var hub := _col(STEEL, WHEEL_S)
	var side := 1.0 if c.x >= 0.0 else -1.0
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p0 := Vector3(0, sin(a0), cos(a0)) * r
		var p1 := Vector3(0, sin(a1), cos(a1)) * r
		var x0 := c + Vector3(-w * 0.5, 0, 0)
		var x1 := c + Vector3(w * 0.5, 0, 0)
		_tri_uv(s, x0 + p0, x0 + p1, x1 + p1, rub, uv, uv2)
		_tri_uv(s, x0 + p0, x1 + p1, x1 + p0, rub, uv, uv2)
	var o := c + Vector3(side * w * 0.5, 0, 0)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p0 := Vector3(0, sin(a0), cos(a0)) * r * 0.55
		var p1 := Vector3(0, sin(a1), cos(a1)) * r * 0.55
		_tri_uv(s, o, o + p1, o + p0, hub, uv, uv2)

func _tri_uv(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, uv: Vector2, uv2: Vector2) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	for p in [a, b, c]:
		s.set_normal(n)
		s.set_color(col)
		s.set_uv(uv)
		s.set_uv2(uv2)
		s.add_vertex(p)
	tris += 1

func _track_run(s: SurfaceTool, x_m: float) -> void:
	var pts: Array = []
	# Ground, rear sprocket arc, return, front idler arc. (z, y) metres.
	pts.append(Vector2(3.15, 0.10))
	pts.append(Vector2(-3.35, 0.10))
	for i in 6:
		var a := deg_to_rad(200.0 + 140.0 * float(i) / 5.0)
		pts.append(Vector2(-3.62, 0.48) + Vector2(cos(a), sin(a)) * 0.36)
	pts.append(Vector2(-3.3, 0.95))
	pts.append(Vector2(3.15, 0.98))
	for i in 6:
		var a := deg_to_rad(-20.0 - 140.0 * float(i) / 5.0)
		pts.append(Vector2(3.40, 0.50) + Vector2(cos(a), sin(a)) * 0.32)
	var col := _col("#2a2c2a", TRACK)
	var half := 0.20
	var along := 0.0
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var step := a.distance_to(b)
		var a0 := _v(x_m - half, a.y, a.x)
		var a1 := _v(x_m + half, a.y, a.x)
		var b0 := _v(x_m - half, b.y, b.x)
		var b1 := _v(x_m + half, b.y, b.x)
		_tri_uv(s, a0, b0, b1, col, Vector2(along, 0.0), Vector2.ZERO)
		_tri_uv(s, a0, b1, a1, col, Vector2(along, 1.0), Vector2.ZERO)
		along += step

func _turret(s: SurfaceTool) -> void:
	# Local metres, pivot on the hull roof. +z forward. Wedge: low narrow nose, taller rear.
	var stations := [
		{"z": 0.90, "hw": 0.28, "h": 0.22},
		{"z": 0.35, "hw": 0.72, "h": 0.42},
		{"z": -0.45, "hw": 0.95, "h": 0.55},
		{"z": -1.20, "hw": 0.82, "h": 0.48},
	]
	var rings: Array = []
	for stn in stations:
		var hw: float = stn["hw"]
		var h: float = stn["h"]
		var right := [
			Vector2(hw, 0.0),
			Vector2(hw * 0.92, h * 0.38),
			Vector2(hw * 0.62, h * 0.78),
			Vector2(hw * 0.40, h),
		]
		var pts: Array = []
		for p2 in right:
			pts.append(_v((p2 as Vector2).x, (p2 as Vector2).y, stn["z"]))
		for i in range(right.size() - 1, -1, -1):
			pts.append(_v(-(right[i] as Vector2).x, (right[i] as Vector2).y, stn["z"]))
		rings.append(pts)
	var paint := _col(OLIVE, PAINT)
	var paint_d := _col(OLIVE_D, PAINT)
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in a.size():
			var k2 := (k + 1) % a.size()
			_quad(s, a[k], b[k], b[k2], a[k2], paint if i != 1 else paint_d)
	_cap(s, rings[0], paint, false)
	_cap(s, rings[rings.size() - 1], paint_d, true)
	# Sensor panels on the front cheeks, fixed launcher tubes along the sides,
	# two trainable pods at the rear corners, roof station on the right.
	var glass := _col("#243038", 2)
	_box(s, _v(-0.42, 0.16, 0.55), Vector3(0.10, 0.10, 0.16) * S, paint_d)
	_box(s, _v(0.42, 0.16, 0.55), Vector3(0.10, 0.10, 0.16) * S, paint_d)
	_box(s, _v(-0.42, 0.18, 0.64), Vector3(0.08, 0.06, 0.012) * S, glass)
	_box(s, _v(0.42, 0.18, 0.64), Vector3(0.08, 0.06, 0.012) * S, glass)
	var steel := _col(STEEL, STEEL_C)
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := 0.35 - float(i) * 0.22
			_tube(s, _v(side * 0.78, 0.08, z), _v(side * 1.02, 0.16, z + 0.05), 0.035 * S, steel)
		_box(s, _v(side * 0.72, 0.22, -0.95), Vector3(0.16, 0.14, 0.22) * S, paint_d)
	# Roof station. Its top is the 3.32 m overall height.
	_box(s, _v(0.32, 0.72, -0.15), Vector3(0.22, 0.28, 0.32) * S, paint)
	_tube(s, _v(0.32, 0.78, 0.02), _v(0.32, 0.80, 0.38), 0.018 * S, steel)
	_tube(s, _v(-0.15, 0.58, -0.7), _v(-0.15, 1.15, -0.72), 0.012 * S, steel)

func _barrel(s: SurfaceTool) -> void:
	# Smooth tube, no fume bulge. Muzzle reaches the 10.889 m overall length.
	var steel := _col(STEEL, STEEL_C)
	var length := 6.4495 - (0.55 + 0.85)
	_tube_taper(s, Vector3.ZERO, _v(0.0, 0.0, length), 0.075 * S, 0.052 * S, steel)
	_tube_taper(s, _v(0.045, 0.02, length - 0.18), _v(0.045, 0.02, length), 0.012 * S, 0.012 * S, steel)

func _box(s: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z),
		c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	_quad(s, p[0], p[1], p[2], p[3], col)
	_quad(s, p[5], p[4], p[7], p[6], col)
	_quad(s, p[4], p[0], p[3], p[7], col)
	_quad(s, p[1], p[5], p[6], p[2], col)
	_quad(s, p[3], p[2], p[6], p[7], col)
	_quad(s, p[4], p[5], p[1], p[0], col)

func _tube(s: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	_tube_taper(s, a, b, r, r, col)

func _tube_taper(s: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color) -> void:
	var axis := b - a
	var len := axis.length()
	if len < 1e-5:
		return
	axis /= len
	var tmp := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(tmp).normalized()
	var v := axis.cross(u).normalized()
	var seg := 10
	for i in seg:
		var t0 := TAU * float(i) / float(seg)
		var t1 := TAU * float(i + 1) / float(seg)
		var d0 := u * cos(t0) + v * sin(t0)
		var d1 := u * cos(t1) + v * sin(t1)
		_quad(s, a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1, col)
