extends Node3D
## M3.2 preview: Russia. Run: godot --path . res://tests/m32_preview.tscn -- buildings|air out.png
func _ready() -> void:
	var out := "/workspace/m32_preview.png"
	var mode := "buildings"
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			out = a
		elif a == "air" or a == "buildings":
			mode = a
	get_window().size = Vector2i(1920, 1080)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#9fb3c4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#8f9a6a")
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 32
	add_child(cam)
	var blds: Array = []
	if mode == "buildings":
		for d in [["hq", Vector3(-6.0, 0, -2.6)], ["ministry", Vector3(-1.6, 0, -2.6)], ["factory", Vector3(2.8, 0, -2.6)], ["power", Vector3(7.0, 0, -3.0)],
				["depot", Vector3(-6.6, 0, 2.0)], ["barracks", Vector3(-3.2, 0, 2.0)], ["black_market", Vector3(0.2, 0, 2.0)], ["bunker", Vector3(3.2, 0, 2.2)], ["aa_site", Vector3(5.6, 0, 2.2)]]:
			var n: Node3D = load("res://view/buildings/ecc/%s.tscn" % d[0]).instantiate()
			n.position = d[1]
			add_child(n)
			blds.append(n)
		for u in [["engineer", Vector3(-5.5, 0, 0.3), 0.0], ["cargo_truck", Vector3(-6.6, 0, 4.2), 2.6]]:
			var v: Node3D = load("res://view/units/ecc/%s.tscn" % u[0]).instantiate()
			v.position = u[1]
			v.rotation.y = u[2]
			add_child(v)
		cam.look_at_from_position(Vector3(0.0, 12.5, 15.5), Vector3(0.0, 0.3, -0.2))
	else:
		var af: Node3D = load("res://view/buildings/ecc/airfield.tscn").instantiate()
		add_child(af)
		blds.append(af)
		var bw := 8.0 / 3.0
		for u in [["tu160", Vector3(-4.0 + bw, 0, 0.0), 0.0, 0.0], ["su57", Vector3(-4.0 + bw * 2.5, 0, 0.0), 0.0, 0.0],
				["ka52", Vector3(4.6, 1.3, 3.6), -2.4, 0.0], ["su57", Vector3(-2.2, 2.2, 5.4), 1.7, 0.0]]:
			var v: Node3D = load("res://view/units/ecc/%s.tscn" % u[0]).instantiate()
			v.position = u[1]
			v.rotation.y = u[2]
			add_child(v)
		cam.look_at_from_position(Vector3(1.2, 8.5, 12.5), Vector3(0.6, 0.4, 0.8))
	for n in blds:   # complete state only
		for c in n.find_children("*", "Node3D", true, false):
			var nm := String(c.name).to_lower()
			if nm.contains("scaffold") or nm.contains("rubble") or nm.contains("damage") or nm.contains("ghost"):
				(c as Node3D).visible = false
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("shot ", out)
	get_tree().quit()
