extends RefCounted
## M2.2 vehicles (tool-time): EU Leopold main battle tank and TPLA Rattler technical, built
## from original procedural geometry (tools/gfx_m3/geo.gd) in Zero Hour-like chunky RTS
## proportions. Node layout per vehicle (VehicleView):
##   Model/Hull (wheels + tracks animate in the shader, meta "moves")
##   Model/TurretPivot/Turret, Model/TurretPivot/Barrel/BarrelMesh (recoil), tier bolt-ons.
const Geo := preload("res://tools/gfx_m3/geo.gd")
const MAT_PATH := "res://view/materials/m3.tres"
const MAT_REVEAL_PATH := "res://view/materials/m3_reveal.tres"
const TEX := "res://assets/textures/materials/"

static func material(reveal := false) -> ShaderMaterial:
	var path := MAT_REVEAL_PATH if reveal else MAT_PATH
	var m := ShaderMaterial.new()
	m.shader = load("res://view/materials/model_m3_reveal.gdshader" if reveal else "res://view/materials/model_m3.gdshader")
	m.set_shader_parameter("weather_tex", load(TEX + "weather.png"))
	m.set_shader_parameter("rust_tex", load(TEX + "rust.png"))
	m.set_shader_parameter("stencil_tex", load(TEX + "stencils.png"))
	m.set_shader_parameter("stencil_amount", 0.6)
	ResourceSaver.save(m, path)
	return load(path)

static func build_all() -> void:
	var mat := material(false)
	material(true)
	_leopold(mat)
	_rattler(mat)

static func _mi(parent: Node, root: Node, name: String, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	mi.owner = root
	return mi

static func _n3(parent: Node, root: Node, name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	n.owner = root
	return n

static func _root(props: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/vehicles/vehicle_view.gd"))
	for k in props:
		root.set(k, props[k])
	return root

static func _save(root: Node3D, path: String, bar: float) -> void:
	var anchor := Marker3D.new()
	anchor.name = "HealthBarAnchor"
	anchor.position = Vector3(0, bar, 0)
	root.add_child(anchor)
	anchor.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, path)
	root.free()

static func _report(name: String, gs: Array) -> void:
	var t := 0
	for g in gs:
		t += g.tris
	print("  %s: %d tris in %d meshes" % [name, t, gs.size()])

## Track loop (outer band) around road wheels: x0..x1, as a closed path in (z, y).
static func _track(g, x0: float, x1: float, rear: Vector2, rr: float, front: Vector2, fr: float, top_y: float) -> void:
	var path: Array = []
	path.append(Vector2(front.x - 0.1, 0.02))
	path.append(Vector2(rear.x, 0.02))
	for i in range(1, 8):   # rear arc: bottom -> rear -> top
		var a := deg_to_rad(270.0 - 180.0 * float(i) / 8.0)
		path.append(rear + Vector2(cos(a), sin(a)) * rr)
	path.append(Vector2(rear.x, top_y))
	path.append(Vector2((rear.x + front.x) * 0.5, top_y - 0.012))
	path.append(Vector2(front.x, top_y))
	for i in range(1, 7):   # front arc: top -> front -> lower front
		var a := deg_to_rad(90.0 - 160.0 * float(i) / 6.0)
		path.append(front + Vector2(cos(a), sin(a)) * fr)
	var ctr := Vector3((x0 + x1) * 0.5, (top_y + 0.02) * 0.5, (rear.x + front.x) * 0.5)
	var s := 0.0
	var n := path.size()
	g.color("#3a3936", Geo.TRACK)
	for i in n:
		var a: Vector2 = path[i]
		var b: Vector2 = path[(i + 1) % n]
		var l := a.distance_to(b)
		var pa0 := Vector3(x0, a.y, a.x)
		var pa1 := Vector3(x1, a.y, a.x)
		var pb0 := Vector3(x0, b.y, b.x)
		var pb1 := Vector3(x1, b.y, b.x)
		# outer face (normal away from loop centre); uv.x = distance along the loop
		g.uv = Vector2(s, 0.0)
		var q := [pa0, pa1, pb1, pb0]
		var uvs := [Vector2(s, 0), Vector2(s, 1), Vector2(s + l, 1), Vector2(s + l, 0)]
		var nrm := (Vector3(0, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5) - Vector3(0, ctr.y, ctr.z)).normalized()
		_quad_uv(g, q, uvs, nrm)
		# guide horns / link edges: a narrow raised rim on both sides
		s += l

static func _quad_uv(g, q: Array, uvs: Array, out: Vector3) -> void:
	var n: Vector3 = (q[1] - q[0]).cross(q[2] - q[0]).normalized()
	var order := [0, 1, 2, 0, 2, 3]
	if n.dot(out) < 0.0:
		n = -n
		order = [0, 2, 1, 0, 3, 2]
	# Godot front faces are clockwise: emit reversed
	var tri := [order[0], order[2], order[1], order[3], order[5], order[4]]
	for k in tri:
		g.uv = uvs[k]
		g._v(g.xf * (q[k] as Vector3), n)
	g.tris += 2
	g.uv = Vector2.ZERO

# ------------------------------------------------------------------ EU Leopold MBT
static func _leopold(mat: Material) -> void:
	var paint := "#7d8669"
	var paint_d := "#5c6551"
	var steel := "#3c3f40"
	var root := _root({"selection_radius": 0.8, "bar_height": 1.43, "recoil": 0.16, "wreck_s": 8.0})
	var model := _n3(root, root, "Model")
	var h = Geo.new()
	# running gear
	for sx in [-0.44, 0.44]:
		_track(h, sx - 0.12, sx + 0.12, Vector2(-0.62, 0.17), 0.15, Vector2(0.64, 0.19), 0.13, 0.32)
		for i in 6:
			var z := lerpf(-0.46, 0.46, float(i) / 5.0)
			h.wheel(Vector3(sx, 0.12, z), 0.1, 0.2, false, paint_d, 12)
		h.wheel(Vector3(sx, 0.17, -0.62), 0.12, 0.2, false, steel, 12, 11)    # drive sprocket
		h.wheel(Vector3(sx, 0.19, 0.64), 0.1, 0.18, false, paint_d, 12)       # idler
		for z in [-0.3, 0.05, 0.38]:
			h.wheel(Vector3(sx, 0.285, z), 0.032, 0.08, false, steel, 6)      # return rollers
	# lower hull + upper deck (fenders over the tracks)
	h.color(paint_d, Geo.PAINT)
	h.prism_x([Vector2(-0.7, 0.12), Vector2(0.5, 0.12), Vector2(0.74, 0.3), Vector2(0.74, 0.36), Vector2(-0.72, 0.36)], -0.32, 0.32)
	h.color(paint, Geo.PAINT)
	h.prism_x([Vector2(-0.76, 0.34), Vector2(0.68, 0.34), Vector2(0.84, 0.38), Vector2(0.62, 0.45), Vector2(-0.66, 0.45), Vector2(-0.78, 0.4)], -0.58, 0.58)
	# side skirts: four panels per side, team band along the top edge
	for sx in [-0.585, 0.585]:
		for i in 4:
			var z0 := -0.7 + i * 0.34
			h.color(paint if i % 2 == 0 else "#626b57", Geo.PAINT)
			h.box(Vector3(sx, 0.3, z0 + 0.165), Vector3(0.03, 0.13, 0.33))
			h.color(steel, Geo.STEEL)
			for bz in [z0 + 0.05, z0 + 0.28]:   # bolts
				h.box(Vector3(sx + signf(sx) * 0.017, 0.335, bz), Vector3(0.01, 0.015, 0.015))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(sx + signf(sx) * 0.004, 0.352, -0.04), Vector3(0.028, 0.03, 1.34))
		h.color(paint_d, Geo.PAINT)   # mud flaps
		h.rbox(Vector3(sx, 0.31, 0.76), Vector3(0.03, 0.12, 0.08), Vector3(-20, 0.0, 0))
	# glacis details: driver hatch + periscopes, spare track links, lights, tow hooks
	h.color(paint_d, Geo.PAINT)
	h.rbox(Vector3(-0.18, 0.44, 0.64), Vector3(0.16, 0.025, 0.14), Vector3(-24, 0.0, 0))
	h.color("#2a3a46", Geo.GLASS)
	for x in [-0.24, -0.18, -0.12]:
		h.box(Vector3(x, 0.465, 0.57), Vector3(0.04, 0.025, 0.03))
	h.color(steel, Geo.STEEL)
	for i in 4:
		h.rbox(Vector3(0.12 + i * 0.085, 0.405, 0.735), Vector3(0.075, 0.018, 0.1), Vector3(-24, 0.0, 0))
	for sx in [-0.44, 0.44]:
		h.color("#ffe2a0", Geo.LAMP)
		h.box(Vector3(sx, 0.395, 0.79), Vector3(0.07, 0.05, 0.02))
		h.color(steel, Geo.STEEL)
		h.tube(Vector3(sx - 0.05, 0.42, 0.78), Vector3(sx - 0.05, 0.43, 0.8), 0.008, 4)
		h.tube(Vector3(sx + 0.05, 0.42, 0.78), Vector3(sx + 0.05, 0.43, 0.8), 0.008, 4)
		h.tube(Vector3(sx - 0.05, 0.43, 0.8), Vector3(sx + 0.05, 0.43, 0.8), 0.008, 4)
		h.box(Vector3(sx * 0.55, 0.27, 0.75), Vector3(0.05, 0.05, 0.06))
	# engine deck: grille slats, exhausts, tool box, jerry cans, tow cable, rear plate
	h.color("#2e322b", Geo.DARK)
	h.box(Vector3(0, 0.447, -0.48), Vector3(0.52, 0.01, 0.3))
	h.color(paint_d, Geo.PAINT)
	for i in 7:
		h.box(Vector3(0, 0.457, -0.6 + i * 0.04), Vector3(0.5, 0.012, 0.02))
	h.color("#2b2b2a", Geo.STEEL)
	for sx in [-0.36, 0.36]:
		h.tube(Vector3(sx, 0.42, -0.77), Vector3(sx, 0.42, -0.84), 0.032, 8)
	h.color(paint_d, Geo.PAINT)
	h.bbox(Vector3(0.47, 0.485, -0.15), Vector3(0.14, 0.07, 0.44), 0.012)
	h.color("#596245", Geo.PAINT)
	for z in [-0.52, -0.43]:
		h.bbox(Vector3(-0.48, 0.51, z), Vector3(0.12, 0.12, 0.06), 0.01)
	h.color("#55524c", Geo.STEEL)
	h.tube(Vector3(-0.5, 0.462, -0.3), Vector3(-0.5, 0.462, 0.36), 0.012, 4)
	h.tube(Vector3(-0.42, 0.462, -0.3), Vector3(-0.42, 0.462, 0.36), 0.012, 4)
	h.color(paint_d, Geo.PAINT)
	h.box(Vector3(0, 0.36, -0.75), Vector3(0.6, 0.12, 0.04))
	h.color("#b33a2a", Geo.LAMP)
	for sx in [-0.5, 0.5]:
		h.box(Vector3(sx, 0.42, -0.785), Vector3(0.04, 0.03, 0.01))
	var hull := _mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	# ---- turret (TurretPivot space)
	var piv := _n3(model, root, "TurretPivot", Vector3(0, 0.45, -0.06))
	piv.scale = Vector3.ONE * 1.12
	var t = Geo.new()
	var plan := [Vector2(-0.33, -0.36), Vector2(0.33, -0.36), Vector2(0.36, 0.06), Vector2(0.2, 0.4), Vector2(-0.2, 0.4), Vector2(-0.36, 0.06)]
	t.color("#35392f", Geo.STEEL)
	t.cyl(0.31, 0.31, 0.03, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(paint, Geo.PAINT)
	t.plan_loft(plan, 0.0, 0.2, Vector2(0.86, 0.86), Vector2(0, -0.03))
	# team band around the turret faces (slightly proud of the armour)
	var sc := func(y: float) -> float: return 1.0 - 0.14 * (y / 0.2)
	t.color("#ffffff", Geo.TEAM)
	var band: Array = []
	for p in plan:
		band.append(Vector2(p.x * (sc.call(0.115) + 0.03), p.y * (sc.call(0.115) + 0.03) - 0.03 * 0.115 / 0.2))
	t.plan_loft(band, 0.095, 0.14, Vector2(sc.call(0.14) / sc.call(0.095), sc.call(0.14) / sc.call(0.095)))
	t.color(paint_d, Geo.PAINT)
	t.bbox(Vector3(0, 0.09, -0.43), Vector3(0.54, 0.14, 0.16), 0.02)            # bustle
	t.bbox(Vector3(0, 0.11, 0.43), Vector3(0.28, 0.15, 0.1), 0.018)             # mantlet
	# bustle rack + stowage
	t.color("#3d4238", Geo.STEEL)
	for sx in [-0.3, 0.3]:
		t.tube(Vector3(sx, 0.16, -0.36), Vector3(sx, 0.16, -0.58), 0.009, 4)
		t.tube(Vector3(sx, 0.02, -0.58), Vector3(sx, 0.16, -0.58), 0.009, 4)
	t.tube(Vector3(-0.3, 0.16, -0.58), Vector3(0.3, 0.16, -0.58), 0.009, 4)
	t.color("#7f7556", Geo.CANVAS)
	t.tube(Vector3(-0.26, 0.2, -0.47), Vector3(0.08, 0.2, -0.47), 0.05, 8)
	t.color("#7a5c3a", Geo.WOOD)
	t.bbox(Vector3(0.18, 0.2, -0.48), Vector3(0.14, 0.09, 0.12), 0.01)
	# cupola, hatches, sight, MG, smoke dischargers, antennas
	t.color(paint_d, Geo.PAINT)
	t.cyl(0.085, 0.08, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(-0.15, 0.2, -0.12)))
	t.cyl(0.078, 0.078, 0.014, 10, Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(-0.15, 0.27, -0.2)))
	t.color("#2a3a46", Geo.GLASS)
	for i in 6:
		var a := TAU * float(i) / 6.0
		t.box(Vector3(-0.15 + cos(a) * 0.083, 0.235, -0.12 + sin(a) * 0.083), Vector3(0.025, 0.018, 0.025))
	t.color(paint_d, Geo.PAINT)
	t.cyl(0.07, 0.07, 0.012, 10, Transform3D(Basis.IDENTITY, Vector3(0.14, 0.2, -0.05)))
	t.bbox(Vector3(0.21, 0.235, 0.17), Vector3(0.08, 0.07, 0.11), 0.01)
	t.color("#2a3a46", Geo.GLASS)
	t.box(Vector3(0.21, 0.24, 0.227), Vector3(0.06, 0.04, 0.006))
	t.color("#2b2b2a", Geo.STEEL)
	t.tube(Vector3(-0.15, 0.3, -0.12), Vector3(-0.15, 0.31, 0.12), 0.01, 5)
	t.box(Vector3(-0.15, 0.3, -0.1), Vector3(0.035, 0.04, 0.08))
	for sx in [-1.0, 1.0]:
		for i in 3:
			var o := Vector3(sx * 0.3, 0.12 + i * 0.03, 0.2)
			t.tube(o, o + Vector3(sx * 0.03, 0.015, 0.07), 0.013, 6)
		t.tube(Vector3(sx * 0.26, 0.2, -0.3), Vector3(sx * 0.26, 0.75, -0.32), 0.005, 3)
		t.box(Vector3(sx * 0.26, 0.2, -0.3), Vector3(0.03, 0.03, 0.03))
	_mi(piv, root, "Turret", t.commit(mat))
	# ---- barrel (recoils along -z)
	var bn := _n3(piv, root, "Barrel", Vector3(0, 0.11, 0.47))
	var b = Geo.new()
	b.color(paint_d, Geo.PAINT)
	b.tube(Vector3(0, 0, -0.04), Vector3(0, 0, 0.07), 0.062, 10)
	b.color(paint, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 0.98), 0.04, 10, 0.034)
	b.tube(Vector3(0, 0, 0.12), Vector3(0, 0, 0.34), 0.046, 10)
	b.tube(Vector3(0, 0, 0.62), Vector3(0, 0, 0.82), 0.042, 10)
	b.color(paint_d, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.42), Vector3(0, 0, 0.56), 0.06, 10, 0.054)          # fume extractor
	b.color("#2b2b2a", Geo.STEEL)
	b.tube(Vector3(0, 0, 0.95), Vector3(0, 0, 1.01), 0.044, 10)
	b.box(Vector3(0, 0.05, 0.97), Vector3(0.025, 0.02, 0.04))
	_mi(bn, root, "BarrelMesh", b.commit(mat))
	_report("leopold", [h, t, b])
	_save(root, "res://view/units/eu/leopold.tscn", 1.43)

# ------------------------------------------------------------------ TPLA Rattler technical
static func _rattler(mat: Material) -> void:
	var tan := "#b89c70"
	var tan_d := "#9a8058"
	var steel := "#34322f"
	var root := _root({"selection_radius": 0.8, "bar_height": 1.23, "recoil": 0.035, "steer_max": 0.5, "wreck_s": 7.0})
	var model := _n3(root, root, "Model")
	var h = load("res://tools/gfx_m7/kit8.gd").new()
	for z in [0.4, -0.36]:
		for sx in [-0.29, 0.29]:
			h.tyre(Vector3(sx, 0.13, z), 0.13, 0.11, z > 0.0, "#5d5a52", 12)   # M2.7b treaded tyre
	h.color(steel, Geo.STEEL)
	h.box(Vector3(0, 0.2, 0.02), Vector3(0.44, 0.08, 1.22))                      # chassis
	h.tube(Vector3(-0.25, 0.13, -0.36), Vector3(0.25, 0.13, -0.36), 0.025, 6)    # rear axle
	h.box(Vector3(0, 0.15, -0.36), Vector3(0.14, 0.1, 0.12))                    # diff
	# hood, cab, bed
	h.color(tan, Geo.PAINT)
	h.prism_x([Vector2(0.22, 0.26), Vector2(0.66, 0.26), Vector2(0.69, 0.36), Vector2(0.63, 0.45), Vector2(0.22, 0.47)], -0.3, 0.3)
	h.prism_x([Vector2(-0.13, 0.26), Vector2(0.24, 0.26), Vector2(0.24, 0.47), Vector2(0.11, 0.67), Vector2(-0.1, 0.69), Vector2(-0.13, 0.66)], -0.29, 0.29)
	h.color("#26323b", Geo.GLASS)
	h.prism_x([Vector2(0.246, 0.48), Vector2(0.122, 0.665), Vector2(0.13, 0.67), Vector2(0.254, 0.483)], -0.25, 0.25)
	for sx in [-0.293, 0.293]:
		h.box(Vector3(sx, 0.56, 0.03), Vector3(0.008, 0.11, 0.17))
	h.box(Vector3(0, 0.58, -0.133), Vector3(0.4, 0.09, 0.008))
	h.color(tan_d, Geo.PAINT)
	h.box(Vector3(0, 0.3, -0.42), Vector3(0.6, 0.06, 0.58))                     # bed floor
	for sx in [-0.285, 0.285]:
		h.box(Vector3(sx, 0.4, -0.42), Vector3(0.03, 0.15, 0.58))
	h.box(Vector3(0, 0.4, -0.7), Vector3(0.6, 0.15, 0.03))
	# mismatched scrap door / welded plates (salvaged look)
	h.color("#5d6f7a", Geo.SCRAP)
	h.rbox(Vector3(0.298, 0.37, 0.05), Vector3(0.012, 0.17, 0.3), Vector3(0, 0, 2))
	h.color("#8a4a34", Geo.SCRAP)
	h.rbox(Vector3(-0.302, 0.4, -0.45), Vector3(0.012, 0.13, 0.26), Vector3(4, 0, 0))
	h.color("#6f6a52", Geo.SCRAP)
	h.rbox(Vector3(0.302, 0.41, -0.5), Vector3(0.012, 0.12, 0.2), Vector3(-6, 0, 0))
	# bumper, bull bar, grille, lights
	h.color(steel, Geo.STEEL)
	h.box(Vector3(0, 0.27, 0.71), Vector3(0.66, 0.06, 0.06))
	for sx in [-0.22, 0.22]:
		h.tube(Vector3(sx, 0.27, 0.74), Vector3(sx, 0.47, 0.72), 0.014, 5)
	h.tube(Vector3(-0.24, 0.47, 0.72), Vector3(0.24, 0.47, 0.72), 0.014, 5)
	h.tube(Vector3(-0.24, 0.38, 0.745), Vector3(0.24, 0.38, 0.745), 0.012, 5)
	h.color("#1f1f1e", Geo.DARK)
	h.box(Vector3(0, 0.35, 0.684), Vector3(0.26, 0.11, 0.01))
	h.color(steel, Geo.STEEL)
	for i in 4:
		h.box(Vector3(0, 0.31 + i * 0.027, 0.69), Vector3(0.26, 0.008, 0.008))
	h.color("#ffe2a0", Geo.LAMP)
	for sx in [-0.21, 0.21]:
		h.box(Vector3(sx, 0.38, 0.69), Vector3(0.09, 0.06, 0.01))
	h.color("#ffd890", Geo.LAMP)
	for sx in [-0.15, -0.05, 0.05, 0.15]:
		h.box(Vector3(sx, 0.71, 0.04), Vector3(0.05, 0.035, 0.03))
	h.color(steel, Geo.STEEL)
	h.box(Vector3(0, 0.7, 0.025), Vector3(0.38, 0.02, 0.04))
	h.color("#b3392a", Geo.LAMP)
	for sx in [-0.27, 0.27]:
		h.box(Vector3(sx, 0.4, -0.717), Vector3(0.04, 0.05, 0.006))
	# team colours: roof cloth, hood stripe, flag on a pole
	h.color("#ffffff", Geo.TEAM)
	h.rbox(Vector3(-0.02, 0.695, -0.0), Vector3(0.36, 0.012, 0.18), Vector3(0, 6, 0))
	h.box(Vector3(0, 0.458, 0.44), Vector3(0.12, 0.012, 0.42))
	h.color(steel, Geo.STEEL)
	h.tube(Vector3(-0.27, 0.46, -0.68), Vector3(-0.27, 1.05, -0.7), 0.008, 4)
	h.color("#ffffff", Geo.TEAM)
	h.rbox(Vector3(-0.27, 0.97, -0.8), Vector3(0.008, 0.12, 0.2), Vector3(0, 0, 0))
	# bed cargo: spare tyre, jerry cans, crate
	h.color("#1e1d1c", Geo.RUBBER)
	h.cyl(0.11, 0.11, 0.07, 10, Transform3D(Basis.IDENTITY, Vector3(0.14, 0.33, -0.57)))
	h.color("#5f6b4a", Geo.PAINT)
	for i in 2:
		h.bbox(Vector3(-0.2, 0.39, -0.62 + i * 0.07), Vector3(0.1, 0.13, 0.055), 0.008)
	h.color("#8b6d3f", Geo.WOOD)
	h.bbox(Vector3(0.17, 0.39, -0.24), Vector3(0.16, 0.12, 0.13), 0.008)
	h.color(steel, Geo.STEEL)   # exhaust
	h.tube(Vector3(0.18, 0.18, -0.2), Vector3(0.18, 0.18, -0.72), 0.016, 5)
	var hull := _mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	# ---- tier bolt-ons (TPLA salvage upgrades)
	var t1 = load("res://tools/gfx_m7/kit8.gd").new()
	t1.color("#6e5a46", Geo.SCRAP)
	t1.rbox(Vector3(0, 0.37, 0.70), Vector3(0.5, 0.13, 0.015), Vector3(-8, 0, 0))
	for sx in [-0.31, 0.31]:
		t1.rbox(Vector3(sx, 0.38, 0.06), Vector3(0.015, 0.2, 0.32), Vector3(0, 0, -signf(sx) * 6))
	t1.color("#7a7048", Geo.SANDBAG)
	for i in 3:
		t1.sandbag(Vector3(-0.15 + i * 0.15, 0.5, -0.69), 0.15, 0)
	var m1 := _mi(model, root, "Tier1", t1.commit(mat))
	m1.visible = false
	m1.set_meta("tier", 1)
	var t3 = load("res://tools/gfx_m7/kit8.gd").new()
	t3.color("#4a4640", Geo.STEEL)
	for i in 6:   # slat cage around the cab
		var z := -0.12 + i * 0.07
		for sx in [-0.34, 0.34]:
			t3.tube(Vector3(sx, 0.3, z), Vector3(sx, 0.62, z), 0.008, 4)
	for y in [0.36, 0.5, 0.62]:
		for sx in [-0.34, 0.34]:
			t3.tube(Vector3(sx, y, -0.14), Vector3(sx, y, 0.25), 0.008, 4)
	var m3 := _mi(model, root, "Tier3", t3.commit(mat))
	m3.visible = false
	m3.set_meta("tier", 3)
	# ---- gun mount (TurretPivot over the bed)
	var piv := _n3(model, root, "TurretPivot", Vector3(0, 0.33, -0.4))
	var t = load("res://tools/gfx_m7/kit8.gd").new()
	t.color(steel, Geo.STEEL)
	t.tube(Vector3(0, 0, 0), Vector3(0, 0.26, 0), 0.03, 6)
	t.cyl(0.06, 0.05, 0.03, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)))
	t.box(Vector3(0, 0.3, 0.0), Vector3(0.06, 0.05, 0.1))
	t.color("#5f6b4a", Geo.SCRAP)
	t.rbox(Vector3(0, 0.37, 0.12), Vector3(0.3, 0.17, 0.018), Vector3(-10, 0, 0))
	t.color("#1f1f1e", Geo.DARK)
	t.box(Vector3(0.07, 0.42, 0.13), Vector3(0.07, 0.015, 0.02))
	t.color("#5b6442", Geo.PAINT)
	t.bbox(Vector3(-0.08, 0.31, 0.03), Vector3(0.06, 0.07, 0.11), 0.006)
	t.color(steel, Geo.STEEL)
	for sx in [-0.03, 0.03]:
		t.tube(Vector3(sx, 0.31, -0.06), Vector3(sx, 0.29, -0.13), 0.008, 4)
	_mi(piv, root, "Turret", t.commit(mat))
	var t2 = load("res://tools/gfx_m7/kit8.gd").new()
	t2.color("#6f6a52", Geo.SCRAP)
	for sx in [-1.0, 1.0]:
		t2.rbox(Vector3(sx * 0.21, 0.36, 0.09), Vector3(0.14, 0.15, 0.016), Vector3(-10, -sx * 28, 0))
	t2.color("#5b6442", Geo.PAINT)
	t2.bbox(Vector3(0.08, 0.31, 0.03), Vector3(0.06, 0.07, 0.11), 0.006)
	var m2 := _mi(piv, root, "TurretTier2", t2.commit(mat))
	m2.visible = false
	m2.set_meta("tier", 2)
	var bn := _n3(piv, root, "Barrel", Vector3(0, 0.33, 0.02))
	var b = load("res://tools/gfx_m7/kit8.gd").new()
	b.color("#2b2a28", Geo.STEEL)
	b.bbox(Vector3(0, 0, 0.0), Vector3(0.06, 0.06, 0.2), 0.008)
	b.tube(Vector3(0, 0, 0.1), Vector3(0, 0, 0.6), 0.013, 6)
	b.color("#3a3936", Geo.STEEL)
	b.tube(Vector3(0, 0, 0.1), Vector3(0, 0, 0.32), 0.026, 8)
	for i in 4:
		b.tube(Vector3(0, 0, 0.13 + i * 0.05), Vector3(0, 0, 0.145 + i * 0.05), 0.03, 8)
	b.tube(Vector3(0, 0, 0.57), Vector3(0, 0, 0.63), 0.022, 8)
	b.box(Vector3(0, 0.04, 0.05), Vector3(0.012, 0.03, 0.012))
	_mi(bn, root, "BarrelMesh", b.commit(mat))
	_report("rattler", [h, t, b, t1, t2, t3])
	_save(root, "res://view/units/tpla/rattler.tscn", 1.23)
