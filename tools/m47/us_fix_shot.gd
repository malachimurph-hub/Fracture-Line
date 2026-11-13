extends SceneTree
## Side and three-quarter of the Reaper, and the MK 23 tripod carried and planted.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     -s res://tools/m47/us_fix_shot.gd -- /tmp/us_fix

func _initialize() -> void:
	var out := "/tmp/us_fix"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.58, 0.52)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.60, 0.55)
	e.ambient_light_energy = 1.1
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 48, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	root.add_child(cam)
	await process_frame
	var overlay := root.find_child("ErrorOverlay", true, false)
	if overlay != null:
		overlay.visible = false
	var reaper := (load("res://view/units/us/reaper.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(reaper)
	await process_frame
	cam.size = 4.2
	cam.look_at_from_position(Vector3(8.0, 1.6, 0.2), Vector3(0.0, 0.35, -0.15), Vector3.UP)
	await _grab(cam, out.path_join("reaper_side.png"))
	cam.size = 4.4
	cam.look_at_from_position(Vector3(6.2, 2.4, 5.4), Vector3(0.0, 0.3, -0.1), Vector3.UP)
	await _grab(cam, out.path_join("reaper_quarter.png"))
	reaper.visible = false
	var mk := (load("res://view/units/us/mk23.tscn") as PackedScene).instantiate()
	root.add_child(mk)
	mk.set_setup(0.0)
	mk._k = 0.0
	await process_frame
	cam.size = 1.35
	cam.look_at_from_position(Vector3(2.4, 1.15, 1.6), Vector3(0.0, 0.35, 0.05), Vector3.UP)
	await _grab(cam, out.path_join("mk23_carried.png"))
	mk.set_setup(1.0)
	mk._k = 1.0
	await process_frame
	await _grab(cam, out.path_join("mk23_planted.png"))
	print("SHOTS ", out)
	quit(0)

func _grab(cam: Camera3D, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())
