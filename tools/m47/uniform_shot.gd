extends Node
## Close-up and match-zoom of one rifleman per faction, stitched side by side.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 640x720 \
##     res://tools/m47/uniform_shot.tscn -- /opt/cursor/artifacts

const UNITS := [
	["us", "res://view/units/us/grunt.tscn", &"us_grunt"],
	["de", "res://view/units/eu/grenadier.tscn", &"eu_grenadier"],
	["ru", "res://view/units/ecc/rifleman.tscn", &"ecc_rifleman"],
	["ir", "res://view/units/tpla/militia.tscn", &"tpla_militia"],
]

func _ready() -> void:
	var out := "/opt/cursor/artifacts"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.64, 0.58)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.68, 0.62)
	e.ambient_light_energy = 1.15
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, 40, 0)
	sun.light_energy = 1.25
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.52, 0.42)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	add_child(cam)
	await get_tree().process_frame
	var overlay := get_tree().root.find_child("ErrorOverlay", true, false)
	if overlay != null:
		overlay.visible = false
	for spec in UNITS:
		var man := (load(spec[1]) as PackedScene).instantiate()
		add_child(man)
		man.set_variant(3)
		man.set_pattern(spec[2])
		man.rotation.y = deg_to_rad(28.0)
		await get_tree().process_frame
		await get_tree().process_frame
		cam.size = 0.62
		cam.look_at_from_position(Vector3(1.15, 0.72, 1.35), Vector3(0.0, 0.34, 0.0), Vector3.UP)
		var close := await _grab()
		cam.size = 11.0
		cam.look_at_from_position(Vector3(8.0, 9.0, 8.0), Vector3(0.0, 0.0, 0.0), Vector3.UP)
		var far := await _grab()
		var side := Image.create(close.get_width() * 2, close.get_height(), false, close.get_format())
		side.blit_rect(close, Rect2i(0, 0, close.get_width(), close.get_height()), Vector2i(0, 0))
		side.blit_rect(far, Rect2i(0, 0, far.get_width(), far.get_height()), Vector2i(close.get_width(), 0))
		var path := out.path_join("uniform_%s.png" % spec[0])
		side.save_png(path)
		print("SHOT ", path, " ", side.get_size())
		man.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)

func _grab() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
