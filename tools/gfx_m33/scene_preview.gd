extends Node3D
## M3.3: compose a few view scenes in one shot (placement per entry), mobile renderer:
##   godot --path . --rendering-method mobile --resolution 1200x700 res://tools/gfx_m33/scene_preview.tscn -- \
##     <out.png> <cam_yaw_deg> <dist> <scene|x|z|yaw_deg[|method[=v]...]> ...
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	var cyaw := deg_to_rad(float(a[1]))
	var dist := float(a[2])
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
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.56, 0.52, 0.4)
	gm.roughness = 1.0
	g.material_override = gm
	add_child(g)
	var i := 0
	for ent in a.slice(3):
		var f: PackedStringArray = ent.split("|")
		var v: Node3D = load(f[0]).instantiate()
		add_child(v)
		v.position = Vector3(float(f[1]), 0, float(f[2]))
		v.rotation.y = deg_to_rad(float(f[3]))
		if v.has_method("set_team_material"):
			v.set_team_material(Palette.team_material(0))
		Weathering.apply(v, &"tpla" if f[0].contains("/tpla/") else &"eu")
		for m in f.slice(4):
			var p := m.split("=")
			if v.has_method(p[0]):
				if p.size() > 1:
					v.call(p[0], float(p[1]))
				else:
					v.call(p[0])
		i += 1
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.position = Vector3(sin(cyaw) * dist, dist * 0.75, cos(cyaw) * dist)
	cam.look_at(Vector3(0, 0.3, 0))
	for k in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SP ", out)
	get_tree().quit(0)
