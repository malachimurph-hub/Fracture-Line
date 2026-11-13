extends Node
## Plain blockout shots of the unwired Mi-8T, plus one hover shot beside the T-90 and BMP-3.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tools/m47/mi8_v2_shot.tscn -- /tmp/mi8v2

var out_dir := "/tmp/mi8v2"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/mi8v2"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _views()
	print("=== MI8 V2 SHOTS")
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
	var model := (load("res://view/units/ecc/mi8_v2.tscn") as PackedScene).instantiate() as Node3D
	add_child(model)
	_paint(model)
	_measure(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.2
	add_child(cam)
	cam.current = true
	var eye := Vector3(0, 1.3, 0)
	# Starboard side, so the tail rotor (+X) faces the camera. Nose (+Z) to the right.
	sun.rotation_degrees = Vector3(-18, 90, 0)
	cam.global_position = Vector3(14, eye.y, 0)
	cam.look_at(eye, Vector3.UP)
	await frames(4)
	await shot("side")
	sun.rotation_degrees = Vector3(-25, 180, 0)
	cam.global_position = Vector3(0, eye.y, 14)
	cam.look_at(eye, Vector3.UP)
	await frames(3)
	await shot("front")
	cam.global_position = Vector3(0, 16, 0.01)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	await frames(3)
	await shot("top")
	# Gameplay camera on the Mi-8 alone, then with the tanks at the live hover height.
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 32.0
	var pitch := deg_to_rad(40.0)
	var dist := 32.4
	var focus := Vector3(0, 1.2, 0)
	cam.global_position = focus + Vector3(sin(0.4) * cos(pitch), sin(pitch), cos(0.4) * cos(pitch)) * dist
	cam.look_at(focus, Vector3.UP)
	await frames(3)
	await shot("gameplay")
	# Close 3/4, the same kind of photo angle used for the T-90.
	cam.fov = 32.0
	cam.global_position = Vector3(6.4, 2.6, 5.2)
	cam.look_at(Vector3(0.2, 1.15, 0.6), Vector3.UP)
	await frames(3)
	await shot("photo34")
	model.position = Vector3(0, 4.0, 0)
	var t90 := (load("res://view/units/ecc/t90.tscn") as PackedScene).instantiate() as Node3D
	t90.position = Vector3(6.5, 0, 1.5)
	add_child(t90)
	_paint(t90)
	var bmp := (load("res://view/units/ecc/bmp3_v2.tscn") as PackedScene).instantiate() as Node3D
	bmp.position = Vector3(6.5, 0, -2.2)
	add_child(bmp)
	_paint(bmp)
	focus = Vector3(2.2, 1.6, 0)
	cam.global_position = focus + Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.look_at(focus, Vector3.UP)
	await frames(4)
	await shot("hover_with_tanks")

func _paint(n: Node) -> void:
	var olive := Color("#96A468")
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.set_instance_shader_parameter(&"paint_color", olive)
		gi.set_instance_shader_parameter(&"rust_amt", 0.2)
		gi.set_instance_shader_parameter(&"wear_amt", 0.55)
		gi.set_instance_shader_parameter(&"dirt_amt", 0.7)

func _measure(model: Node3D) -> void:
	var sc := 0.311
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
		mn = mn.min(ab.position)
		mx = mx.max(ab.position + ab.size)
	print("AABB u ", mn, " size ", mx - mn)
	print("AABB m size ", (mx - mn) / sc)
	var rotor := model.find_child("Rotor", true, false) as Node3D
	var tail := model.find_child("TailRotor", true, false) as Node3D
	var bar := model.find_child("HealthBarAnchor", true, false) as Node3D
	print("ROTOR ", rotor.position, " m ", rotor.position / sc, " axis ", rotor.get_meta("rotor_axis"))
	print("TAIL ", tail.position, " m ", tail.position / sc, " axis ", tail.get_meta("rotor_axis"))
	print("BAR y ", bar.position.y, " sel ", model.get("selection_radius"))
	var names: Array = []
	for c in model.find_children("PodMuzzle*", "Marker3D", true, false):
		names.append(c.name)
	print("PODS ", names)
	print("NODES DoorPort ", model.find_child("DoorPort", true, false) != null, " clamshells ", model.find_child("ClamshellL", true, false) != null)
