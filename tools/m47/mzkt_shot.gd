extends Node
## Blockout shots of the unwired MZKT chassis.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://tools/m47/mzkt_shot.tscn -- /tmp/mzkt

var out_dir := "/tmp/mzkt"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/mzkt"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _views()
	print("=== MZKT SHOTS")
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())

func _views() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.91, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.60, 0.55)
	e.ambient_light_energy = 1.05
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -55, 0)
	sun.light_energy = 1.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-70, 140, 0)
	fill.light_energy = 0.42
	add_child(fill)
	var truck := (load("res://view/units/ecc/mzkt_base.tscn") as PackedScene).instantiate() as Node3D
	add_child(truck)
	_paint(truck)
	_measure(truck)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.current = true
	# Side. Camera on +X. size is the vertical world span. Nose is +Z.
	var eye := Vector3(0, 0.7, 0)
	cam.size = 1.85
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(12, eye.y, 0)
	cam.look_at(eye, Vector3.UP)
	await frames(4)
	await shot("side")
	print("CAM side size ", cam.size, " eye ", eye, " pos ", cam.global_position, " basis_x ", cam.global_basis.x)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := Vector3(0, 0.7, 0.2)
	cam.global_position = focus + Vector3(4.6, 2.3, 4.2)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-40, 30, 0)
	await frames(3)
	await shot("three_quarter")
	# Lineup on one ground line, noses toward +Z, gaps measured from each mesh.
	var lineup: Array[Node3D] = [truck]
	var paths := ["res://view/units/ecc/t90.tscn", "res://view/units/ecc/bmp3_v2.tscn", "res://view/units/ecc/mi8_v2.tscn"]
	for pth in paths:
		var n := (load(pth) as PackedScene).instantiate() as Node3D
		add_child(n)
		_paint(n)
		lineup.append(n)
	# Order: T-90, BMP-3, MZKT, Mi-8. truck is already in the tree at index 0 of lineup
	# but was created first. Reorder by moving along Z.
	# Camera right is -Z, so the last vehicle placed (highest Z) appears on the left.
	var order: Array[Node3D] = [lineup[3], lineup[0], lineup[2], lineup[1]]
	var labels := ["mi8", "mzkt", "bmp3", "t90"]
	var cursor := 0.0
	for i in order.size():
		var ab := _aabb(order[i])
		var sz: Vector3 = ab.size
		print("LINE ", labels[i], " size ", sz, " min ", ab.position)
		order[i].position = Vector3(0, 0, cursor - ab.position.z)
		cursor += sz.z + 0.55
	var span := cursor
	var mid := span * 0.5
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	cam.size = (span + 1.2) / aspect
	var look := Vector3(0, 1.1, mid)
	cam.global_position = Vector3(18, look.y, mid)
	cam.look_at(look, Vector3.UP)
	sun.rotation_degrees = Vector3(-30, 80, 0)
	await frames(4)
	await shot("lineup")
	print("CAM lineup size ", cam.size, " look ", look, " basis_x ", cam.global_basis.x, " span ", span)

func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == null:
			continue
		var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		if first:
			out = ab
			first = false
		else:
			out = out.merge(ab)
	return out

func _paint(n: Node) -> void:
	var olive := Color("#96A468")
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.set_instance_shader_parameter(&"paint_color", olive)
		gi.set_instance_shader_parameter(&"rust_amt", 0.15)
		gi.set_instance_shader_parameter(&"wear_amt", 0.35)
		gi.set_instance_shader_parameter(&"dirt_amt", 0.45)

func _tris(n: Node) -> int:
	var t := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		if m == null:
			continue
		for s in m.get_surface_count():
			t += m.surface_get_array_index_len(s) / 3
	return t

func _measure(model: Node3D) -> void:
	var sc := 0.311
	var ab := _aabb(model)
	var sz := ab.size
	print("AABB min ", ab.position, " size u ", sz)
	print("AABB m ", sz / sc, " ground y ", ab.position.y)
	print("TRIS ", _tris(model))
	print("BAR ", (model.find_child("HealthBarAnchor", true, false) as Node3D).position, " sel ", model.get("selection_radius"))
	var mount := model.find_child("ModuleMount", true, false) as Node3D
	print("MOUNT ", mount.position, " m ", mount.position / sc)
	for name in ["JackFL", "JackFR", "JackRL", "JackRR"]:
		var mk := model.find_child(name, true, false) as Node3D
		print("JACK ", name, " ", mk.position, " m ", mk.position / sc)
