extends Node
## Stage 2 blockout renders, all at one orthographic scale, plus the gameplay camera.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tools/m47/bmp3_v2_shot.tscn -- /tmp/bmp3v2

var out_dir := "/tmp/bmp3v2"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/bmp3v2"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _views()
	print("=== BMP3 V2 SHOTS")
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
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -55, 0)
	sun.light_energy = 1.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-70, 140, 0)
	fill.light_energy = 0.28
	add_child(fill)
	var model := (load("res://view/units/ecc/bmp3_v2.tscn") as PackedScene).instantiate() as Node3D
	add_child(model)
	var olive := Color("#8d9876")
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter(&"paint_color", olive)
	_measure(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.4
	add_child(cam)
	cam.current = true
	# Same ortho size on every view, so a metre is the same number of pixels.
	var eye := Vector3(0, 0.45, 0)
	# Camera on the port side so the bow (+Z) sits on the right, matching the four-view.
	cam.global_position = Vector3(-8, eye.y, 0)
	cam.look_at(eye, Vector3.UP)
	await frames(4)
	await shot("side")
	cam.global_position = Vector3(0, eye.y, 8)
	cam.look_at(eye, Vector3.UP)
	await frames(3)
	await shot("front")
	cam.global_position = Vector3(0, 8, 0)
	cam.look_at(Vector3.ZERO, Vector3(1, 0, 0))
	await frames(3)
	await shot("top")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	cam.global_position = Vector3(3.3, 1.55, 3.5)
	cam.look_at(Vector3(0, 0.7, 0.15), Vector3.UP)
	await frames(3)
	await shot("front34")
	cam.global_position = Vector3(-3.1, 1.45, -3.4)
	cam.look_at(Vector3(0, 0.65, -0.15), Vector3.UP)
	await frames(3)
	await shot("rear34")
	# Gameplay camera: 40 deg pitch, 32 deg FOV, default distance 32.4. T-90 on the right for scale.
	var t90 := (load("res://view/units/ecc/t90.tscn") as PackedScene).instantiate() as Node3D
	t90.position = Vector3(2.4, 0, 0)
	add_child(t90)
	model.position = Vector3(-2.0, 0, 0)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 32.0
	var focus := Vector3(0.2, 0.4, 0)
	var pitch := deg_to_rad(40.0)
	var dist := 32.4
	cam.global_position = focus + Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.look_at(focus, Vector3.UP)
	await frames(4)
	await shot("gameplay")

func _measure(model: Node3D) -> void:
	var sc := 0.405
	var hull := model.find_child("Hull", true, false) as MeshInstance3D
	var ab: AABB = hull.mesh.get_aabb()
	print("HULL_AABB u ", ab.position, " size ", ab.size)
	print("HULL_AABB m pos ", ab.position / sc, " size ", ab.size / sc)
	var piv := model.find_child("TurretPivot", true, false) as Node3D
	var barrel := model.find_child("Barrel", true, false) as Node3D
	var m100 := model.find_child("GunMuzzle100", true, false) as Marker3D
	var m30 := model.find_child("GunMuzzle30", true, false) as Marker3D
	var bar := model.find_child("HealthBarAnchor", true, false) as Marker3D
	print("PIVOT m ", piv.position / sc)
	print("BARREL local m ", barrel.position / sc, " world m ", barrel.global_position / sc)
	print("MUZZLE100 m ", m100.global_position / sc, " MUZZLE30 m ", m30.global_position / sc)
	print("BAR y u ", bar.position.y, " bar_height ", model.get("bar_height"))
	var names: Array = []
	for c in model.find_children("*", "", true, false):
		names.append(c.name)
	print("NODES ", " ".join(names))
