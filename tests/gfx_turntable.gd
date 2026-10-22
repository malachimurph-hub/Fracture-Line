extends Node3D
## Quick model viewer for the M2.2 art (not part of the suite):
##   xvfb-run godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://tests/gfx_turntable.tscn -- <out.png> <yaw_deg> <dist> <scene> [scene...]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	var yaw := float(a[1])
	var dist := float(a[2])
	var scenes := a.slice(3)
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
	pm.size = Vector2(40, 40)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.55, 0.42)
	gm.roughness = 1.0
	g.material_override = gm
	add_child(g)
	var sp := 3.4 if scenes[0].contains("/buildings/") else 2.2
	var x := -(scenes.size() - 1) * sp * 0.5
	var ctr := Vector3.ZERO
	var i := 0
	for s in scenes:
		var parts: PackedStringArray = s.split("@")
		var v: Node3D = load(parts[0]).instantiate()
		add_child(v)
		v.position = Vector3(x, 0, 0)
		v.rotation.y = deg_to_rad(yaw)
		if v.has_method("set_team_material"):
			v.set_team_material(Palette.team_material(i))
		Weathering.apply(v, &"tpla" if parts[0].contains("/tpla/") else &"eu")
		if parts.size() > 1:
			for kv in parts[1].split(","):
				var p := kv.split("=")
				if v.has_method(p[0]):
					if p.size() > 1:
						v.call(p[0], float(p[1]))
					else:
						v.call(p[0])
		x += sp
		i += 1
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.position = ctr + Vector3(0, dist * 0.75, dist)
	cam.look_at(ctr + Vector3(0, 0.3, 0))
	for k in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("TT ", out)
	get_tree().quit(0)
