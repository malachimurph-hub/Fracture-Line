extends "res://tests/m30_shots.gd"
## Front 3/4, rear 3/4, side, and the match beside the T-90.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tools/m47/bmp3_draw_shot.tscn -- /tmp/bmp3draw

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/bmp3draw"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _studio()
	await _match()
	print("=== BMP3 DRAW SHOTS")
	get_tree().quit(0)

func _studio() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.91, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.73, 0.68)
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-80, 180, 0)
	fill.light_energy = 0.45
	add_child(fill)
	var model := (load("res://view/units/ecc/bmp3.tscn") as PackedScene).instantiate() as Node3D
	add_child(model)
	var olive := Color("#8d9876")
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter(&"paint_color", olive)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.current = true
	cam.size = 1.95
	# Light the side the camera sees, so the lowered edge is not lost in shadow.
	sun.rotation_degrees = Vector3(-35, -70, 0)
	fill.light_energy = 0.7
	cam.global_position = Vector3(-8, 0.55, 0.05)
	cam.look_at(Vector3(0, 0.55, 0.05), Vector3.UP)
	await frames(4)
	await shot("bmp3_side")
	sun.rotation_degrees = Vector3(-55, 30, 0)
	fill.light_energy = 0.45
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	cam.global_position = Vector3(3.4, 1.7, 3.6)
	cam.look_at(Vector3(0, 0.55, 0.15), Vector3.UP)
	await frames(3)
	await shot("bmp3_front")
	cam.global_position = Vector3(-3.2, 1.55, -3.3)
	cam.look_at(Vector3(0, 0.5, -0.2), Vector3.UP)
	await frames(3)
	await shot("bmp3_rear")
	model.queue_free()
	cam.queue_free()
	sun.queue_free()
	fill.queue_free()
	env.queue_free()

func _match() -> void:
	await _start("varno_crossing", ["ecc", "eu"], false)
	for layer in m.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var spot := Vector2i(48, 48)
	var u := _unit(&"ecc_bmp3", spot, 0)
	var t90 := _unit(&"ecc_t90", spot + Vector2i(0, 5), 0)
	await frames(4)
	var v: Node3D = m.world.views[u.id]
	var fwd: Vector3 = v.global_transform.basis.z
	var side: Vector3 = v.global_transform.basis.x
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 28.0
	cam.current = true
	var focus: Vector3 = v.global_position.lerp(m.world.views[t90.id].global_position, 0.42) + Vector3(0, 0.7, 0)
	cam.global_position = focus + side * 7.2 + fwd * 5.2 + Vector3(0, 3.1, 0)
	cam.look_at(focus, Vector3.UP)
	await frames(5)
	await shot("bmp3_match")
	cam.queue_free()
