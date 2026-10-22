extends RefCounted
## M2.2 procedural modelling kit (tool-time only, excluded from export). Builds flat-shaded,
## vertex-coloured meshes for view/materials/model_m3.gdshader: the part class goes in vertex
## alpha (see the shader header), so each mesh is ONE surface / one draw call.
## All primitives are convex; triangles are oriented outward from each primitive's centroid.

enum { PAINT, TEAM, GLASS, RUBBER, TRACK, LAMP, STEEL, WHEEL_RUBBER, WHEEL_STEEL, CANVAS,
	CONCRETE, CORR, WOOD, SANDBAG, CHAR, TEAM_LAMP, DARK, SCRAP }

var st := SurfaceTool.new()
var tris := 0
var xf := Transform3D.IDENTITY     ## applied to every point (node-local placement)
var uv := Vector2.ZERO
var uv2 := Vector2.ZERO
var _col := Color.WHITE

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func color(c: Variant, cls: int) -> void:
	var cc: Color = Color(c) if c is String else c
	cc.a = float(cls) / 20.0
	_col = cc

func _v(p: Vector3, n: Vector3) -> void:
	st.set_color(_col)
	st.set_normal(n)
	st.set_uv(uv)
	st.set_uv2(uv2)
	st.add_vertex(p)

## One triangle in final (already transformed) space, flipped to face away from `ctr`.
func tri_w(a: Vector3, b: Vector3, c: Vector3, ctr: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - ctr) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	# SurfaceTool / Godot front faces are clockwise: emit a, c, b
	_v(a, n)
	_v(c, n)
	_v(b, n)
	tris += 1

## Convex hull given as a list of faces (each a list of local points); local -> xf * t.
func faces(fs: Array, t: Transform3D = Transform3D.IDENTITY) -> void:
	var m := xf * t
	var ctr := Vector3.ZERO
	var cnt := 0
	for f in fs:
		for p in f:
			ctr += m * (p as Vector3)
			cnt += 1
	ctr /= maxf(1, cnt)
	for f in fs:
		var pts: Array = []
		for p in f:
			pts.append(m * (p as Vector3))
		for i in range(1, pts.size() - 1):
			tri_w(pts[0], pts[i], pts[i + 1], ctr)

## Loft between two rings of equal size (each ring a convex loop), capped.
func loft(r0: Array, r1: Array, t: Transform3D = Transform3D.IDENTITY, cap0 := true, cap1 := true) -> void:
	var fs: Array = []
	var n := r0.size()
	for i in n:
		var j := (i + 1) % n
		fs.append([r0[i], r0[j], r1[j], r1[i]])
	if cap0:
		fs.append(r0)
	if cap1:
		fs.append(r1)
	faces(fs, t)

func box(c: Vector3, s: Vector3, t: Transform3D = Transform3D.IDENTITY) -> void:
	var h := s * 0.5
	var r0 := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]
	var r1 := [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	loft(r0, r1, t * Transform3D(Basis.IDENTITY, c))

## Box with chamfered edges (the classic RTS "bevel" silhouette): 3 crossed boxes.
func bbox(c: Vector3, s: Vector3, bev: float, t: Transform3D = Transform3D.IDENTITY) -> void:
	box(c, Vector3(s.x, s.y - bev * 2.0, s.z - bev * 2.0), t)
	box(c, Vector3(s.x - bev * 2.0, s.y, s.z - bev * 2.0), t)
	box(c, Vector3(s.x - bev * 2.0, s.y - bev * 2.0, s.z), t)

## Box rotated by Euler degrees around its centre.
func rbox(c: Vector3, s: Vector3, deg: Vector3) -> void:
	box(Vector3.ZERO, s, Transform3D(Basis.from_euler(deg * PI / 180.0), c))

## Side profile (z, y) extruded along x from x0 to x1 (profile must be convex).
func prism_x(profile: Array, x0: float, x1: float, t: Transform3D = Transform3D.IDENTITY) -> void:
	var r0: Array = []
	var r1: Array = []
	for p in profile:
		r0.append(Vector3(x0, p.y, p.x))
		r1.append(Vector3(x1, p.y, p.x))
	loft(r0, r1, t)

## Plan polygon (x, z) at y0 lofted to a (scaled / offset) copy at y1: turrets, roofs.
func plan_loft(plan: Array, y0: float, y1: float, top_scale := Vector2.ONE, top_off := Vector2.ZERO, t: Transform3D = Transform3D.IDENTITY) -> void:
	var r0: Array = []
	var r1: Array = []
	for p in plan:
		r0.append(Vector3(p.x, y0, p.y))
		r1.append(Vector3(p.x * top_scale.x + top_off.x, y1, p.y * top_scale.y + top_off.y))
	loft(r0, r1, t)

## Cylinder / cone along local +Y (length h from y=0), radius r0 at bottom, r1 at top.
func cyl(r0: float, r1: float, h: float, seg: int, t: Transform3D, caps := true) -> void:
	var a: Array = []
	var b: Array = []
	for i in seg:
		var ang := TAU * float(i) / float(seg)
		a.append(Vector3(cos(ang) * r0, 0.0, sin(ang) * r0))
		b.append(Vector3(cos(ang) * r1, h, sin(ang) * r1))
	if r1 <= 0.0001:
		var fs: Array = []
		for i in seg:
			fs.append([a[i], a[(i + 1) % seg], Vector3(0, h, 0)])
		if caps:
			fs.append(a)
		faces(fs, t)
		return
	loft(a, b, t, caps, caps)

## Cylinder between two local points.
func tube(p0: Vector3, p1: Vector3, r: float, seg: int = 6, r_end: float = -1.0, caps := true) -> void:
	var d := p1 - p0
	var l := d.length()
	if l < 1e-5:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	cyl(r, r if r_end < 0.0 else r_end, l, seg, Transform3D(Basis(x, y, z), p0), caps)

## Wheel on an axle along x, centred at c: tyre (spinning rubber) + rim/hub (spinning steel).
func wheel(c: Vector3, r: float, w: float, steers := false, hub_col: Variant = "#3a3d40", seg := 12, lugs := 0) -> void:
	var keep := _col
	uv = Vector2(c.y, c.z)
	uv2 = Vector2(c.x, r + (10.0 if steers else 0.0))
	color("#1d1c1b", WHEEL_RUBBER)
	var side := 1.0 if c.x >= 0.0 else -1.0
	tube(c - Vector3(w * 0.5, 0, 0), c + Vector3(w * 0.5, 0, 0), r, seg)
	if lugs > 0:   # tread blocks
		for i in lugs:
			var a := TAU * float(i) / float(lugs)
			var p := c + Vector3(0, sin(a), cos(a)) * (r + 0.006)
			box(Vector3.ZERO, Vector3(w * 0.9, 0.02, r * 0.28), Transform3D(Basis(Vector3.RIGHT, a), p))
	color(hub_col, WHEEL_STEEL)
	var o := c + Vector3(side * w * 0.5, 0, 0)
	tube(o - Vector3(side * 0.004, 0, 0), o + Vector3(side * 0.012, 0, 0), r * 0.62, seg)
	tube(o, o + Vector3(side * 0.03, 0, 0), r * 0.22, 6)
	for i in 5:   # wheel nuts / spokes: make the spin visible
		var a2 := TAU * float(i) / 5.0
		box(o + Vector3(side * 0.016, sin(a2) * r * 0.4, cos(a2) * r * 0.4), Vector3(0.012, r * 0.14, r * 0.14))
	uv = Vector2.ZERO
	uv2 = Vector2.ZERO
	_col = keep

## Sandbag (squashed bevelled pillow) centred at c, long axis rotated by yaw degrees.
func sandbag(c: Vector3, l: float, yaw: float, col: Variant = "#9c8a62") -> void:
	color(col, SANDBAG)
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c)
	box(Vector3.ZERO, Vector3(l, 0.06, 0.12), t)
	box(Vector3.ZERO, Vector3(l - 0.05, 0.09, 0.09), t)

## M2.6: LODs. The engine simplifier (meshoptimizer via ImporterMesh) builds the LOD index
## chains; the mesh keeps every attribute (wheel UV / UV2, part class in colour alpha).
var lods := true

func commit(mat: Material) -> ArrayMesh:
	st.index()
	if not lods or tris < 120:
		var m0 := st.commit()
		if m0.get_surface_count() > 0:
			m0.surface_set_material(0, mat)
		return m0
	var arrays := st.commit_to_arrays()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var ld := {}
	for l in im.get_surface_lod_count(0):
		ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], ld)
	m.surface_set_material(0, mat)
	return m

## M2.6 detail helpers -------------------------------------------------------------------
## Row of rivet / bolt heads from a to b on a face with outward normal n.
func rivets(a: Vector3, b: Vector3, count: int, n: Vector3, r := 0.008) -> void:
	for i in count:
		var p := a.lerp(b, (float(i) + 0.5) / float(count))
		box(p + n * r * 0.5, Vector3(r, r, r) * 1.4)

## Louvred vent panel centred at c on a face (normal along +z of transform t), w x h.
func vent(c: Vector3, w: float, h: float, slats: int, yaw := 0.0) -> void:
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c)
	box(Vector3(0, 0, 0), Vector3(w, h, 0.012), t)
	for i in slats:
		var y := -h * 0.5 + h * (float(i) + 0.5) / float(slats)
		box(Vector3(0, 0, 0.0), Vector3(w * 0.9, h / float(slats) * 0.35, 0.03), t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-30)), Vector3(0, y, 0.012)))

## Square hatch with hinge and handle on a horizontal surface at c.
func hatch(c: Vector3, s: float) -> void:
	bbox(c + Vector3(0, 0.008, 0), Vector3(s, 0.016, s), 0.004)
	box(c + Vector3(0, 0.02, -s * 0.42), Vector3(s * 0.6, 0.014, 0.014))
	tube(c + Vector3(-s * 0.2, 0.02, s * 0.3), c + Vector3(s * 0.2, 0.02, s * 0.3), 0.005, 4)

## Jerrycan / stowage box helpers
func jerrycan(c: Vector3, yaw := 0.0) -> void:
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c)
	bbox(Vector3(0, 0.05, 0), Vector3(0.035, 0.1, 0.07), 0.006, t)
	box(Vector3(0, 0.105, 0.02), Vector3(0.02, 0.012, 0.02), t)
