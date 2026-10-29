## M3.3: find floating parts in a building scene. Splits each Hull / Parts mesh into connected
## pieces (by shared vertex position), and flags a piece whose bottom is above the ground
## with nothing under it (no other piece's triangle within 4 cm below its bottom points) and
## that is not carried by a lower piece it overlaps (see _carried).
## Run: godot --headless --path . -s res://tools/gfx_m33/float_check.gd -- <scene.tscn ...>
extends SceneTree

const MIN_SIZE := 0.12   # ignore trim smaller than this (bands, bolts)

func _init() -> void:
	var total := 0
	for p in OS.get_cmdline_user_args():
		var sc: PackedScene = load(p)
		var root := sc.instantiate()
		var bad := check(root)
		total += bad.size()
		print("%s: %d floating" % [p, bad.size()])
		for b in bad:
			print("   FLOAT ", b)
		root.free()
	print("FLOAT_TOTAL %d" % total)
	quit()

static func check(root: Node) -> Array:
	var pieces: Array = []   # {tris: PackedVector3Array, box: AABB, name}
	for mi in _meshes(root):
		if not mi.visible or mi.name in ["Scaffold", "DamageLight", "DamageHeavy", "Rubble"] or mi.name.begins_with("LOD"):
			continue
		var xf: Transform3D = _xf(mi, root)
		var m: Mesh = mi.mesh
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			pieces.append_array(_split(v, idx, xf, String(mi.name)))
	var out: Array = []
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var bx: AABB = pc.box
		if bx.position.y < 0.12 or bx.get_longest_axis_size() < MIN_SIZE:
			continue
		var embedded := false
		for j in pieces.size():
			if j != i and _carried(bx, pieces[j].box):
				embedded = true
				break
		if embedded:
			continue
		# bottom sample points: the lowest vertices + their centre
		var y0 := bx.position.y
		var pts: Array = []
		var tri: PackedVector3Array = pc.tris
		var c := Vector3.ZERO
		for q in tri:
			if q.y < y0 + 0.005:
				pts.append(q)
				c += q
		if pts.is_empty():
			continue
		pts.append(c / pts.size())
		var sup := 0
		for q in pts:
			if _under(q, pieces, i):
				sup += 1
		if float(sup) / pts.size() < 0.5:
			out.append("%s piece at %s size %s (supported %d/%d)" % [pc.name, (bx.position + bx.size * 0.5).snapped(Vector3.ONE * 0.01), bx.size.snapped(Vector3.ONE * 0.01), sup, pts.size()])
	return out

## b carries a: b reaches at least as low, and the boxes overlap (or touch within 3 mm) over at
## least 30% of a's extent on two axes - a wall strip, a ring on a stack, a ladder.
static func _carried(a: AABB, b: AABB) -> bool:
	if b.position.y > a.position.y + 0.005:
		return false
	var lo := a.position.max(b.position)
	var hi := a.end.min(b.end)
	var n := 0
	for ax in 3:
		var ov := hi[ax] - lo[ax]
		if ov < -0.003:
			return false
		if ov >= 0.3 * maxf(a.size[ax], 0.004) or (a.size[ax] < 0.02 and ov > -0.003):
			n += 1
	return n >= 2

static func _pen(a: AABB, b: AABB) -> float:
	var lo := a.position.max(b.position)
	var hi := (a.position + a.size).min(b.position + b.size)
	var d := hi - lo
	return minf(d.x, minf(d.y, d.z))

static func _under(q: Vector3, pieces: Array, skip: int) -> bool:
	var p2 := Vector2(q.x, q.z)
	for j in pieces.size():
		if j == skip:
			continue
		var bx: AABB = pieces[j].box
		if bx.position.y > q.y + 0.01 or bx.position.y + bx.size.y < q.y - 0.04:
			continue
		if q.x < bx.position.x - 0.005 or q.x > bx.end.x + 0.005 or q.z < bx.position.z - 0.005 or q.z > bx.end.z + 0.005:
			continue
		var t: PackedVector3Array = pieces[j].tris
		for k in range(0, t.size(), 3):
			var a: Vector3 = t[k]
			var b: Vector3 = t[k + 1]
			var c: Vector3 = t[k + 2]
			var my := maxf(a.y, maxf(b.y, c.y))
			if my < q.y - 0.04 or minf(a.y, minf(b.y, c.y)) > q.y + 0.01:
				continue
			if Geometry2D.point_is_inside_triangle(p2, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)) or \
					(Geometry2D.get_closest_point_to_segment(p2, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(p2) < 0.006):
				return true
	return false

static func _split(v: PackedVector3Array, idx: PackedInt32Array, xf: Transform3D, nm: String) -> Array:
	# union-find over quantised positions
	var key := {}
	var par := PackedInt32Array()
	var vid := PackedInt32Array()
	vid.resize(v.size())
	for i in v.size():
		var k := Vector3i((v[i] * 2000.0).round())
		if not key.has(k):
			key[k] = par.size()
			par.append(par.size())
		vid[i] = key[k]
	var find := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x
	for k in range(0, idx.size(), 3):
		var a: int = find.call(vid[idx[k]])
		for e in [1, 2]:
			var b: int = find.call(vid[idx[k + e]])
			if a != b:
				par[b] = a
	var groups := {}
	for k in range(0, idx.size(), 3):
		var r: int = find.call(vid[idx[k]])
		if not groups.has(r):
			groups[r] = PackedVector3Array()
		for e in 3:
			groups[r].append(xf * v[idx[k + e]])
	var out: Array = []
	for r in groups:
		var t: PackedVector3Array = groups[r]
		var bx := AABB(t[0], Vector3.ZERO)
		for q in t:
			bx = bx.expand(q)
		out.append({"tris": t, "box": bx, "name": nm})
	return out

static func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

static func _xf(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
