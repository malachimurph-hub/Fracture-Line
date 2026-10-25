extends SceneTree
## M3.2 item 14 (tool-time): quick close-up of view scenes in a row under a sun, RTS camera.
##   xvfb-run godot --path . --resolution 1600x700 -s res://tools/gfx_m32/tex14/preview.gd -- out.png scene...
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out: String = args.pop_front()
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.53, 0.38)
	ground.material_override = gm
	root.add_child(ground)
	var x := 0.0
	var spans: Array = []
	for p in args:
		var ps: PackedScene = load(p)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		var w := 5.0 if String(p).contains("/buildings/") else 2.6
		n.position = Vector3(x + w * 0.5, 0, 0)
		root.add_child(n)
		for d in n.find_children("*", "Node3D", true, false):
			if String(d.name) in ["Scaffold", "DamageLight", "DamageHeavy", "Rubble"]:
				(d as Node3D).visible = false
		x += w
	var cam := Camera3D.new()
	cam.fov = 24
	root.add_child(cam)
	cam.position = Vector3(x * 0.5, x * 0.9, x * 0.62 + 1.0)
	cam.look_at(Vector3(x * 0.5, 0.3, 0))
	for i in 12:
		await process_frame
		var gs := get_root().get_node_or_null("GameSession")
		if gs != null and gs.has_method("_hide_overlay"):
			gs._hide_overlay()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("PREVIEW ", out)
	quit(0)
