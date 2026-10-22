extends Node
## M2.6 asset before/after showcase (asset track). Renders each faction's core units in front of
## its main base buildings on a terrain-textured ground, RTS camera, plus a close-up of the tanks.
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/assets_m26_showcase.tscn -- <out_dir> <prefix>
## Prints per-shot perf counters (primitives, draw calls, objects) as PERF lines.
const SETS := {
	"eu": {"units": ["crawler", "grenadier", "lancer", "wolfhound", "leopold", "aegis", "flakwerk", "harvester"],
		"bld": ["hq", "barracks", "heavy_factory", "reactor"], "team": Color("#3a6fd8")},
	"tpla": {"units": ["laborer", "militia", "rocket_cell", "rattler", "scrapback", "hailstorm", "shrike", "mule"],
		"bld": ["camp", "den", "workshop", "stash"], "team": Color("#d83a3a")},
	"us": {"units": ["dozer", "grunt", "javelin", "jtac", "lynx", "halberd", "picket", "longreach"],
		"bld": ["command", "barracks", "garage", "reactor"], "team": Color("#3fae54")},
}
const CLOSE := {"eu": "leopold", "tpla": "scrapback", "us": "halberd"}
var out_dir := "/tmp/assets_m26"
var prefix := "after"
var w3: Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: prefix = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	var gs := get_node_or_null("/root/GameSession")
	if gs != null and gs.get("_overlay") != null:
		(gs.get("_overlay") as Node).queue_free()
		gs.set("_overlay", null)
	var only := args[2] if args.size() > 2 else ""
	for f in SETS:
		if only != "" and only != f:
			continue
		await lineup(f)
		await closeup(f)
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
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	var tex = load("res://assets/textures/terrain/ground097_color.png") if ResourceLoader.exists("res://assets/textures/terrain/ground097_color.png") else null
	gm.albedo_color = Color("#8c7a58")
	if tex != null:
		gm.albedo_texture = tex
		gm.uv1_scale = Vector3(16, 16, 1)
		gm.albedo_color = Color("#d8c8a8")
	gm.roughness = 0.95
	ground.material_override = gm
	w3.add_child(ground)

func _place(path: String, pos: Vector3, yaw: float, team: Color) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("missing " + path)
		return null
	var v: Node3D = (load(path) as PackedScene).instantiate()
	v.position = pos
	v.rotation.y = deg_to_rad(yaw)
	w3.add_child(v)
	if v.has_method("set_team_material"):
		var tm := StandardMaterial3D.new()
		tm.albedo_color = team
		v.call("set_team_material", tm)
	_team_inst(v, team)
	return v

func _team_inst(n: Node, team: Color) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter("team_color", team)
	for c in n.get_children():
		_team_inst(c, team)

func lineup(f: String) -> void:
	await _world()
	var s: Dictionary = SETS[f]
	var bx := -12.0
	for b in s["bld"]:
		_place("res://view/buildings/%s/%s.tscn" % [f, b], Vector3(bx, 0, -4.5), -20.0, s["team"])
		bx += 8.0
	var ux := -10.5
	for u in s["units"]:
		_place("res://view/units/%s/%s.tscn" % [f, u], Vector3(ux, 0, 3.2), -35.0, s["team"])
		ux += 3.0
	var cam := Camera3D.new()
	cam.fov = 38
	cam.position = Vector3(0, 17, 17)
	w3.add_child(cam)
	await get_tree().process_frame
	cam.look_at(Vector3(0, 0, 0.2))
	cam.current = true
	await _shot("%s_%s_lineup" % [prefix, f])

func closeup(f: String) -> void:
	await _world()
	var s: Dictionary = SETS[f]
	_place("res://view/units/%s/%s.tscn" % [f, CLOSE[f]], Vector3(0, 0, 0), -40.0, s["team"])
	var inf := "grunt" if f == "us" else ("militia" if f == "tpla" else "grenadier")
	_place("res://view/units/%s/%s.tscn" % [f, inf], Vector3(1.6, 0, 0.7), -60.0, s["team"])
	_place("res://view/units/%s/%s.tscn" % [f, s["units"][2]], Vector3(-1.7, 0, 0.6), -20.0, s["team"])
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0.4, 3.0, 4.6)
	w3.add_child(cam)
	await get_tree().process_frame
	cam.look_at(Vector3(0, 0.35, 0))
	cam.current = true
	await _shot("%s_%s_closeup" % [prefix, f])

func _shot(name: String) -> void:
	for k in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("PERF %s prims=%d draws=%d objects=%d size=%s" % [name, prims, dc, objs, img.get_size()])
