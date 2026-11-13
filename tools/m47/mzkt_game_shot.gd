extends SceneTree
## One side view of a module mounted through the gameplay rig, fully deployed.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     -s res://tools/m47/mzkt_game_shot.gd -- /tmp/mzkt_deployed.png aa

func _initialize() -> void:
	var path := "/tmp/mzkt_deployed.png"
	var kind := "aa"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		path = args[0]
	if args.size() > 1:
		kind = args[1]
	var ids := {"aa": &"ecc_mzkt_aa", "radar": &"ecc_mzkt_radar", "missile": &"ecc_mzkt_missile"}
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.58, 0.52)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.60, 0.55)
	e.ambient_light_energy = 1.05
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 40, 0)
	sun.light_energy = 1.15
	root.add_child(sun)
	var rig := (load("res://view/units/ecc/mzkt_base.tscn") as PackedScene).instantiate()
	root.add_child(rig)
	rig.sync_mzkt(ids[kind], 1.0, 0.0, false, Vector3.ZERO, false)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.7
	cam.current = true
	root.add_child(cam)
	await process_frame
	cam.look_at_from_position(Vector3(14.0, 1.2, 0.0), Vector3(0.0, 1.15, -0.15), Vector3.UP)
	for _i in 3:
		await process_frame
	var overlay := root.find_child("ErrorOverlay", true, false)
	if overlay != null:
		overlay.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size(), " ", kind)
	quit(0)
