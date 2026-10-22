extends Node
## M2.7 graphics pass: before/after renders + a "big fight" render benchmark.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
##     --rendering-method mobile res://tests/gfx_m27_compare.tscn -- <out_dir> <prefix> [shots]
## shots: comma list of reactor,us_bld,us_veh,eu,tpla,bench (default all).
## BENCH line: avg / p95 frame ms over 240 frames, primitives and draw calls (software GL on
## the box: compare before vs after on the same machine, not absolute phone numbers).
const US_B := ["reactor", "command", "barracks", "garage", "airfield", "supply_center", "strategy", "patriot", "firebase", "drop_zone"]
const US_V := ["dozer", "supply_truck", "lynx", "halberd", "picket", "longreach", "harrier", "wraith", "thunderlance"]
const EU_V := ["leopold", "wolfhound", "flakwerk", "salamander", "hearth", "brennus", "harvester", "crawler"]
const EU_B := ["hq", "barracks", "heavy_factory", "reactor", "motor_pool", "hub"]
const TP_V := ["rattler", "scrapback", "hailstorm", "junkhammer", "jackal", "sprayer", "mule", "bus"]
const TP_B := ["den", "camp", "workshop", "stash", "chop_shop", "tunnel"]
var out_dir := "/tmp/gfx27"
var prefix := "after"
var w3: Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: prefix = args[1]
	var shots := (args[2] if args.size() > 2 else "reactor,us_bld,us_veh,eu,tpla,bench").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	var gs := get_node_or_null("/root/GameSession")
	if gs != null and gs.get("_overlay") != null:
		(gs.get("_overlay") as Node).queue_free()
		gs.set("_overlay", null)
	for s in shots:
		match s:
			"reactor": await reactor()
			"us_bld": await bld_grid("us", US_B, "us_buildings")
			"us_veh": await veh_row("us", US_V, "us_vehicles")
			"eu": await bld_grid("eu", EU_B, "eu_buildings"); await veh_row("eu", EU_V, "eu_vehicles")
			"tpla": await bld_grid("tpla", TP_B, "tpla_buildings"); await veh_row("tpla", TP_V, "tpla_vehicles")
			"bench": await bench()
	get_tree().quit(0)

func _world() -> void:
	if w3 != null:
		w3.queue_free()
		await get_tree().process_frame
	w3 = Node3D.new()
	add_child(w3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#b9a988")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b7a98c")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	w3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	w3.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	var tp := "res://assets/textures/terrain/ground097_color.png"
	gm.albedo_color = Color("#8c7a58")
	if ResourceLoader.exists(tp):
		gm.albedo_texture = load(tp)
		gm.uv1_scale = Vector3(24, 24, 1)
		gm.albedo_color = Color("#d8c8a8")
	gm.roughness = 0.95
	ground.material_override = gm
	w3.add_child(ground)

func _team(f: String) -> Color:
	return {"eu": Color("#3a6fd8"), "tpla": Color("#d83a3a"), "us": Color("#3fae54")}[f]

func _place(path: String, pos: Vector3, yaw: float, team: Color) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("missing " + path)
		return null
	var v: Node3D = (load(path) as PackedScene).instantiate()
	v.position = pos
	v.rotation.y = deg_to_rad(yaw)
	w3.add_child(v)
	_team_inst(v, team)
	return v

func _team_inst(n: Node, team: Color) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter("team_color", team)
	for c in n.get_children():
		_team_inst(c, team)

func _cam(pos: Vector3, at: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.position = pos
	w3.add_child(cam)
	await get_tree().process_frame
	cam.look_at(at)
	cam.current = true

func reactor() -> void:
	await _world()
	_place("res://view/buildings/us/reactor.tscn", Vector3.ZERO, -25.0, _team("us"))
	await _cam(Vector3(2.2, 4.2, 5.2), Vector3(0, 0.7, 0), 34)
	await _shot("%s_reactor_close" % prefix)
	await _cam(Vector3(0, 11, 9), Vector3(0, 0.5, 0), 34)
	await _shot("%s_reactor_rts" % prefix)

func bld_grid(f: String, list: Array, name: String) -> void:
	await _world()
	var cols := 5
	for i in list.size():
		var p := Vector3((i % cols - (cols - 1) * 0.5) * 5.6, 0, (i / cols) * 6.0 - 3.0)
		_place("res://view/buildings/%s/%s.tscn" % [f, list[i]], p, -20.0, _team(f))
	await _cam(Vector3(0, 17, 17), Vector3(0, 0, 0.6), 40)
	await _shot("%s_%s" % [prefix, name])

func veh_row(f: String, list: Array, name: String) -> void:
	await _world()
	var cols := 5
	for i in list.size():
		var p := Vector3((i % cols - (cols - 1) * 0.5) * 2.6, 0, (i / cols) * 2.6 - 1.3)
		_place("res://view/units/%s/%s.tscn" % [f, list[i]], p, -35.0, _team(f))
	await _cam(Vector3(0, 7.5, 8.5), Vector3(0, 0.2, 0.2), 40)
	await _shot("%s_%s" % [prefix, name])

## Big-fight render benchmark: 3 x 40 vehicles + 30 structures under a mid-zoom RTS camera.
func bench() -> void:
	await _world()
	var fl := {"us": US_V.slice(0, 6), "eu": EU_V.slice(0, 6), "tpla": TP_V.slice(0, 6)}
	var k := 0
	var fi := 0
	for f in fl:
		for i in 40:
			var p := Vector3((i % 10) * 1.9 - 9.0 + fi * 0.6, 0, (i / 10) * 2.0 - 6.0 + fi * 8.0 - 8.0)
			_place("res://view/units/%s/%s.tscn" % [f, fl[f][i % fl[f].size()]], p, float(k * 37 % 360), _team(f))
			k += 1
		fi += 1
	var bl := {"us": US_B, "eu": EU_B, "tpla": TP_B}
	fi = 0
	for f in bl:
		for i in 10:
			var b: String = bl[f][i % bl[f].size()]
			_place("res://view/buildings/%s/%s.tscn" % [f, b], Vector3(i * 4.6 - 21.0, 0, -18.0 - fi * 5.0), 0.0, _team(f))
		fi += 1
	await _cam(Vector3(0, 26, 16), Vector3(0, 0, -6), 45)
	for i in 30:
		await get_tree().process_frame
	var times: Array = []
	var t0 := Time.get_ticks_usec()
	for i in 240:
		await RenderingServer.frame_post_draw
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
		t0 = t1
	times.sort()
	var s := 0.0
	for t in times:
		s += t
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("BENCH %s avg_ms=%.2f p95_ms=%.2f prims=%d draws=%d" % [prefix, s / times.size(), times[int(times.size() * 0.95)], prims, dc])
	await _shot("%s_bench" % prefix)

func _shot(name: String) -> void:
	for k in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("PERF %s prims=%d draws=%d" % [name, prims, dc])
