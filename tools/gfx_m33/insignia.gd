extends SceneTree
## M3.3 item 37 (tool-time): the Bundeswehr cross (black cross with straight, flared arms and a
## white border - a national military marking, drawn from plain geometry) on Germany's
## vehicles and structures. Adds one small MeshInstance3D "Insignia" next to the Hull
## (same node, so it moves / recoils with it): vehicles get one on each hull side, structures
## one on the front wall and one on the roof. Placement follows the actual hull surface:
## the outermost vertices in a window at the chosen height. Idempotent (replaces "Insignia").
##   godot --headless --path . -s res://tools/gfx_m33/insignia.gd -- scene.tscn ...
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")

## Cross in the local XY plane (normal +Z), arm half-length a; white border then black.
static func cross(g, a: float, t: Transform3D) -> void:
	for layer in 2:
		var s := 1.0 if layer == 0 else 0.72
		var z := 0.0 if layer == 0 else 0.0025
		g.color("#f2f2ee" if layer == 0 else "#151515", Geo.PAINT)
		var w0 := a * 0.24 * s   # half width at the centre
		var w1 := a * 0.42 * s   # half width at the tip (flared)
		var l := a * s
		for k in 4:
			var r := Basis(Vector3.BACK, PI * 0.5 * k)
			var p0 := r * Vector3(-w0 * 0.5, w0 * 0.5, z)
			var p1 := r * Vector3(-w1, l, z)
			var p2 := r * Vector3(w1, l, z)
			var p3 := r * Vector3(w0 * 0.5, w0 * 0.5, z)
			var q := [p0, p1, p2, p3]
			var th := Vector3(0, 0, 0.003)
			var back := t * Vector3(0, 0, -0.2)   # faces point away from the hull (+Z)
			g.tri_w(t * (q[0] + th), t * (q[1] + th), t * (q[2] + th), back)
			g.tri_w(t * (q[0] + th), t * (q[2] + th), t * (q[3] + th), back)
		var bk := t * Vector3(0, 0, -0.2)
		var zc := z + 0.003
		g.tri_w(t * Vector3(-w0 * 0.5, -w0 * 0.5, zc), t * Vector3(-w0 * 0.5, w0 * 0.5, zc), t * Vector3(w0 * 0.5, w0 * 0.5, zc), bk)
		g.tri_w(t * Vector3(-w0 * 0.5, -w0 * 0.5, zc), t * Vector3(w0 * 0.5, w0 * 0.5, zc), t * Vector3(w0 * 0.5, -w0 * 0.5, zc), bk)

static func _verts(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var m := mi.mesh
	for si in m.get_surface_count():
		out.append_array(m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	return out

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	for path in OS.get_cmdline_user_args():
		var ps: PackedScene = load(path)
		var root: Node3D = ps.instantiate()
		var hull := root.get_node_or_null("Model/Hull") as MeshInstance3D
		if hull == null:
			print("INSIGNIA skip (no Model/Hull) ", path)
			root.free()
			continue
		var old := hull.get_parent().get_node_or_null("Insignia")
		if old != null:
			old.free()
		var vs := _verts(hull)
		var bb: AABB = hull.mesh.get_aabb()
		var g = K.new()
		var structure := path.contains("/buildings/")
		if structure:
			# front wall: the frontmost vertices around 45 % height, left of centre
			var y := bb.position.y + bb.size.y * 0.24
			var x := bb.position.x + bb.size.x * 0.3
			var zf := -INF
			for v in vs:
				if absf(v.y - y) < bb.size.y * 0.05 and absf(v.x - x) < bb.size.x * 0.12:
					zf = maxf(zf, v.z)
			var a := clampf(bb.size.y * 0.16, 0.1, 0.16)
			cross(g, a, Transform3D(Basis.IDENTITY, Vector3(x, y, zf + 0.003)))
			# roof: the highest broad surface near the centre
			var top := -INF
			for v in vs:
				if absf(v.x) < bb.size.x * 0.12 and absf(v.z - bb.get_center().z) < bb.size.z * 0.12:
					top = maxf(top, v.y)
			cross(g, a * 1.8, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, top + 0.004, bb.get_center().z)))
		else:
			# both hull sides, behind centre, at ~55 % of the hull height
			var y := bb.position.y + bb.size.y * 0.55
			var z := bb.get_center().z - bb.size.z * 0.12
			var a := clampf(bb.size.y * 0.13, 0.035, 0.07)
			for s in [-1.0, 1.0]:
				var xm := 0.0
				for wk in [1.0, 2.0, 4.0]:   # widen the window for hulls with sparse side vertices
					for v in vs:
						if absf(v.y - y) < a * wk and absf(v.z - z) < a * 1.2 * wk and v.x * s > xm:
							xm = v.x * s
					if xm > 0.05:
						break
				if xm <= 0.05:
					continue
				cross(g, a, Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(s * (xm + 0.003), y, z)))
		if g.tris == 0:
			print("INSIGNIA none placed ", path)
			root.free()
			continue
		var mi := VK._mi(hull.get_parent(), root, "Insignia", g.commit(mat), hull.position)
		mi.transform = hull.transform
		var out := PackedScene.new()
		out.pack(root)
		ResourceSaver.save(out, path)
		print("INSIGNIA ", path, " tris ", g.tris)
		root.free()
	quit(0)
