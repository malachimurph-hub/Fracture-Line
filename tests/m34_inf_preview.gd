extends Node3D
## M3.4 infantry preview (dev tool): one baked soldier model in several clips / variants on a
## plain ground, lit by a sun, shot from the front, side and three-quarter.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
##     --rendering-method mobile res://tests/m34_inf_preview.tscn -- <out.png> <model> [view]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/prev.png"
	var key: String = args[1] if args.size() > 1 else "us_rifleman"
	var view: String = args[2] if args.size() > 2 else "front"
	var grp: int = int(args[3]) if args.size() > 3 else 0   # 0 = first four clips, 1 = last four
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var gp := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	gp.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.55, 0.42)
	gp.material_override = gm
	add_child(gp)
	var vat: VatModel = load("res://assets/models/infantry/%s.res" % key)
	var clips := [["idle", 0.3, 0], ["fire", 0.05, 1], ["fire_kneel", 0.05, 2], ["run", 0.2, 3], ["walk", 0.3, 0], ["lean", 0.1, 1], ["die", 1.4, 2], ["die2", 1.4, 3]]
	for k in clips.size():
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = vat.mesh
		mm.instance_count = 1
		mmi.multimesh = mm
		mmi.material_override = InfantryView._material(vat)
		mmi.custom_aabb = AABB(Vector3(-1, -0.1, -1), Vector3(2, 1, 2))
		add_child(mmi)
		var cn: String = clips[k][0]
		var clip: Array = vat.anims.get(cn, vat.anims["idle"])
		var fr := int(float(clips[k][1]) * float(clip[2]))
		fr = mini(fr, int(clip[1]) - 1)
		mm.set_instance_transform(0, Transform3D(Basis(), Vector3((k - 1.5 - grp * 4) * 0.42, 0, 0)))
		mm.set_instance_custom_data(0, Color(clip[0] + fr, clip[0] + fr, 0, 0))
		mmi.set_instance_shader_parameter(&"variant", float(clips[k][2]))
		mmi.set_instance_shader_parameter(&"team_color", Color(0.2, 0.45, 0.9))
		mmi.set_instance_shader_parameter(&"skin_tone", [1.0, 0.72, 0.88, 1.08][k % 4])
	var cam := Camera3D.new()
	add_child(cam)
	match view:
		"side":
			cam.position = Vector3(-2.2, 0.45, 0.9)
		"back":
			cam.position = Vector3(0.0, 0.55, -1.7)
		"top":
			cam.position = Vector3(0.0, 1.7, 1.3)
		"q":
			cam.position = Vector3(1.2, 0.6, 1.4)
		_:
			cam.position = Vector3(0.0, 0.4, 1.7)
	cam.fov = 45
	cam.look_at(Vector3(0, 0.22, 0))
	cam.current = true
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("PREVIEW ", out)
	get_tree().quit(0)
