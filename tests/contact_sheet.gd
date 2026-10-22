extends Node
## Roster contact sheet:  xvfb-run godot --path . --resolution 2340x1080 res://tests/contact_sheet.tscn -- <out.png> <scene,scene,...>
## Lays the given view scenes out on a sand ground in a grid under a warm sun, RTS camera angle.
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/contact.png"
	var scenes: PackedStringArray = (args[1] if args.size() > 1 else "").split(",", false)
	var labels: PackedStringArray = (args[2] if args.size() > 2 else "").split(",", false)
	var cols := int(args[3]) if args.size() > 3 else 7
	var spacing := float(args[4]) if args.size() > 4 else 3.2
	var unit_scale := float(args[5]) if args.size() > 5 else 1.0
	await get_tree().process_frame
	var gs := get_node_or_null("/root/GameSession")
	if gs != null and gs.get("_overlay") != null:
		(gs.get("_overlay") as Node).queue_free()
		gs.set("_overlay", null)
	var w3 := Node3D.new()
	add_child(w3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#c9b892")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b7a98c")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	w3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	w3.add_child(sun)
	var rows := int(ceil(float(scenes.size()) / float(cols)))
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(cols * spacing + 4, rows * spacing + 4)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#8c7a58")
	ground.material_override = gm
	w3.add_child(ground)
	var teams := [Color("#3a6fd8"), Color("#d83a3a")]
	for i in scenes.size():
		var ps: PackedScene = load(scenes[i])
		if ps == null:
			push_error("missing " + scenes[i])
			continue
		var v: Node3D = ps.instantiate()
		var cx := (i % cols - (cols - 1) * 0.5) * spacing
		var cz := (i / cols - (rows - 1) * 0.5) * spacing
		v.position = Vector3(cx, 0, cz)
		v.rotation.y = deg_to_rad(-35)
		if scenes[i].contains("/units/"):
			v.scale = Vector3.ONE * unit_scale   # vehicles enlarged for legibility (label says so)
		w3.add_child(v)
		if v.has_method("set_team_material"):
			var tm := StandardMaterial3D.new()
			tm.albedo_color = teams[0] if scenes[i].contains("/eu/") else teams[1]
			v.call("set_team_material", tm)
		if i < labels.size():
			var l := Label3D.new()
			l.text = labels[i]
			l.font_size = 64
			l.pixel_size = 0.0012 * spacing
			l.outline_size = 12
			l.modulate = Color.WHITE
			l.rotation_degrees = Vector3(-55, 0, 0)
			l.position = Vector3(cx, 0.05, cz + spacing * 0.45)
			w3.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 32
	var span := maxf(cols * spacing, rows * spacing * 2.1)
	cam.position = Vector3(0, span * 0.78, span * 0.62)
	w3.add_child(cam)
	await get_tree().process_frame
	cam.look_at(Vector3(0, 0, 0.3))
	cam.current = true
	for k in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("contact sheet -> ", out, " ", img.get_size())
	get_tree().quit(0)
