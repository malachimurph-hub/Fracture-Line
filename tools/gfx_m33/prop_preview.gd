extends Node3D
## M3.3: preview the procedural props (trees / rocks) with the in-game prop shader (no fog):
##   xvfb-run godot --path . --rendering-method mobile --resolution 1200x700 \
##     res://tools/gfx_m33/prop_preview.tscn -- <out.png> <dist> <kind> [kind...]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	var dist := float(a[1])
	var kinds := a.slice(2)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, float(OS.get_environment("SUN_YAW")) if OS.has_environment("SUN_YAW") else -35.0, 0)   # SUN_YAW=160: back-lit (light through leaves)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.5, 0.52, 0.36)
	g.material_override = gm
	add_child(g)
	var img := Image.create(4, 4, false, Image.FORMAT_R8)
	img.fill(Color.WHITE)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/terrain/prop.gdshader")
	mat.set_shader_parameter("fog_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("map_size", Vector2(60, 60))
	mat.set_shader_parameter("sway", 1.0)
	mat.set_shader_parameter("leaf_tex", load("res://assets/textures/props/leaf_atlas.png"))
	var sp := 2.2
	var x := -(kinds.size() - 1) * sp * 0.5
	for k in kinds:
		var mi := MeshInstance3D.new()
		mi.mesh = PropMeshes.make(k)
		mi.material_override = mat
		mi.position = Vector3(x, 0, 0)
		add_child(mi)
		x += sp
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.position = Vector3(0, dist * 0.6, dist)
	cam.look_at(Vector3(0, 0.8, 0))
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("PP ", out)
	get_tree().quit(0)
