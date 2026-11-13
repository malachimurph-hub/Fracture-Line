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
	# 2x side crops. Same camera, half the vertical span.
	cam.size = 0.925
	var cab_eye := Vector3(0, 0.72, 1.15)
	cam.global_position = Vector3(12, cab_eye.y, cab_eye.z)
	cam.look_at(cab_eye, Vector3.UP)
	await frames(3)
	await shot("side_cab")
	var bed_eye := Vector3(0, 0.48, -0.55)
	cam.global_position = Vector3(12, bed_eye.y, bed_eye.z)
	cam.look_at(bed_eye, Vector3.UP)
	await frames(3)
	await shot("side_bed")
	cam.size = 1.85
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := Vector3(0, 0.7, 0.2)
	cam.global_position = focus + Vector3(4.6, 2.3, 4.2)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-40, 30, 0)
	await frames(3)
	await shot("three_quarter")
	var cab := Vector3(0.15, 0.85, 1.35)
	cam.global_position = cab + Vector3(2.15, 0.75, 1.35)
	cam.look_at(cab, Vector3.UP)
	sun.rotation_degrees = Vector3(-36, 40, 0)
	await frames(3)
	await shot("cab")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.35
	var front := Vector3(0, 0.72, 1.55)
	cam.global_position = Vector3(0, front.y, 8.0)
	cam.look_at(front, Vector3.UP)
	sun.rotation_degrees = Vector3(-25, 180, 0)
	await frames(3)
	await shot("front")
	print("CAM front basis_x ", cam.global_basis.x)
	cam.size = 4.4
	cam.global_position = Vector3(0, 14, 0.01)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	sun.rotation_degrees = Vector3(-70, 20, 0)
	await frames(3)
	await shot("top")
	await _radar(cam, sun, truck)
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

## Base truck with the unwired radar module parented on ModuleMount.
func _radar(cam: Camera3D, sun: DirectionalLight3D, base: Node3D) -> void:
	base.visible = false
	var rig := (load("res://view/units/ecc/mzkt_base.tscn") as PackedScene).instantiate() as Node3D
	var mod := (load("res://view/units/ecc/mzkt_radar_module.tscn") as PackedScene).instantiate() as Node3D
	var mount := rig.find_child("ModuleMount", true, false) as Node3D
	mount.add_child(mod)
	add_child(rig)
	_paint(rig)
	var whole := _aabb(rig)
	var alone := _aabb(mod)
	var sc := 0.311
	print("RADAR whole u ", whole.size, " m ", whole.size / sc)
	print("RADAR module u ", alone.size, " min ", alone.position, " m ", alone.size / sc, " min m ", alone.position / sc)
	print("RADAR tris ", _tris(mod))
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	var center := whole.get_center()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var side_size := maxf(whole.size.y * 1.12, whole.size.z * 1.08 / aspect)
	cam.size = side_size
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(14, center.y, center.z)
	cam.look_at(center, Vector3.UP)
	await frames(4)
	await shot("radar_side")
	print("CAM radar side size ", cam.size, " center ", center)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := center + Vector3(0, 0.15, 0.2)
	cam.global_position = focus + Vector3(5.4, 2.6, 4.6)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-38, 28, 0)
	await frames(3)
	await shot("radar_three_quarter")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var front_size := maxf(whole.size.y * 1.15, whole.size.x * 1.4 / aspect)
	cam.size = front_size
	var front_at := Vector3(center.x, center.y, whole.position.z + whole.size.z * 0.55)
	cam.global_position = Vector3(front_at.x, front_at.y, whole.position.z + whole.size.z + 6.0)
	cam.look_at(front_at, Vector3.UP)
	sun.rotation_degrees = Vector3(-22, 180, 0)
	await frames(3)
	await shot("radar_front")
	cam.size = maxf(whole.size.z * 1.15 / aspect, whole.size.x * 1.4)
	cam.global_position = Vector3(center.x, center.y + 12.0, center.z + 0.01)
	cam.look_at(Vector3(center.x, 0, center.z), Vector3(0, 0, -1))
	sun.rotation_degrees = Vector3(-70, 20, 0)
	await frames(3)
	await shot("radar_top")
	# 2x the radar side shot, framed on the cabin floor where it meets the deck.
	cam.size = side_size * 0.5
	var join := mount.global_position + Vector3(0.35, 0.02, -0.35)
	sun.rotation_degrees = Vector3(-30, 75, 0)
	cam.global_position = Vector3(12, join.y, join.z)
	cam.look_at(join, Vector3.UP)
	await frames(3)
	await shot("radar_join")
	print("CAM radar join size ", cam.size, " at ", join)
	rig.queue_free()
	base.visible = true

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
