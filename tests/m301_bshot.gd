extends Node3D
## M3.0.1 preview: US HQ (command compound) and Strategic Center (Pentagon-style), with a dozer
## on the HQ's exit tile in front of the bay. Run: godot --path . res://tests/m301_bshot.tscn -- out.png
func _ready() -> void:
	var out := "/tmp/us_hq_strategic.png"
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			out = a
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
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#c2ab7f")
	ground.material_override = gm
	add_child(ground)
	var hq: Node3D = load("res://view/buildings/us/command.tscn").instantiate()
	hq.position = Vector3(-2.6, 0, 0)
	add_child(hq)
	var st: Node3D = load("res://view/buildings/us/strategy.tscn").instantiate()
	st.position = Vector3(2.4, 0, -0.5)
	add_child(st)
	var dz: Node3D = load("res://view/units/us/dozer.tscn").instantiate()
	dz.position = hq.position + Vector3(0.5, 0, 2.5)   # sim exit tile for rot 0
	add_child(dz)
	for n in [hq, st]:   # complete state only
		for c in n.find_children("*", "Node3D", true, false):
			var nm := String(c.name).to_lower()
			if nm.contains("scaffold") or nm.contains("rubble") or nm.contains("damage") or nm.contains("ghost"):
				(c as Node3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 32
	add_child(cam)
	cam.look_at_from_position(Vector3(-0.3, 6.2, 9.0), Vector3(-0.1, 0.4, 0.3))
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("shot ", out)
	get_tree().quit()
