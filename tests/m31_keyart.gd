extends Node
## M3.1 main-menu key art, rendered offline from the real in-game models, terrain, VFX and sky:
##   xvfb-run -a -s "-screen 0 4700x2200x24" godot --path . --resolution 1170x540 \
##     --rendering-method gl_compatibility res://tests/m31_keyart.tscn -- <out.png> [W H]
## A US / Germany / Iran three-way clash: tanks, the M109A7, IFVs, infantry, a gunship, artillery
## blasts and smoke. Simulates at a small window, then grows the window to W x H for the capture.
var m: Node
var sim: SimWorld
var out := "/workspace/m31_keyart.png"
var big := Vector2i(4680, 2160)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].ends_with(".png"):
		out = args[0]
	if args.size() > 2:
		big = Vector2i(int(args[1]), int(args[2]))
	Settings.data["graphics_preset"] = "ultra"
	Settings.data["texture_quality"] = "high"
	Settings.apply()
	await get_tree().process_frame
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 31
	cfg["map"] = "harrow_junction"
	for i in 4:
		cfg["slots"][i]["kind"] = "closed"
	var facs := ["us", "eu", "tpla"]
	for i in 3:
		cfg["slots"][i]["kind"] = "human" if i == 0 else "ai"
		cfg["slots"][i]["faction"] = facs[i]
		cfg["slots"][i]["team"] = i
		cfg["slots"][i]["spawn"] = i
	cfg["options"]["fog"] = false
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	sim = m.runner.sim
	m.runner.ais.clear()
	var c := _open_spot(Vector2i(46, 30), Vector2i(64, 64))
	var ctr := c + Vector2i(23, 15)
	# backdrop structures: US HQ behind the US line, a German factory across the field
	var hq := sim._place_building(Content.building(&"us_command"), 0, ctr + Vector2i(-21, 9), 0, true)
	_ensure(hq)
	_ensure(sim._place_building(Content.building(&"eu_heavy_factory"), 1, ctr + Vector2i(20, -4), 0, true))
	var us := [[&"us_halberd", -6, 4], [&"us_halberd", -2, 6], [&"us_longreach", -5, 6], [&"us_bradley", -4, 1], [&"us_lynx", -10, 3],
		[&"us_grunt", -3, 3], [&"us_grunt", -2, 2], [&"us_grunt", -1, 4], [&"us_javelin", -4, 5], [&"us_grunt", 0, 3]]
	var eu := [[&"eu_leopold", 6, 3], [&"eu_leopold", 8, 6], [&"eu_boxer", 4, 0], [&"eu_salamander", 9, 1], [&"eu_crawler", 9, 9],
		[&"eu_grenadier", 3, 2], [&"eu_grenadier", 4, 4], [&"eu_lancer", 5, 5], [&"eu_grenadier", 2, 1]]
	var tp := [[&"tpla_scrapback", 0, -6], [&"tpla_rattler", 3, -8], [&"tpla_pickup", -3, -7], [&"tpla_hailstorm", 1, -10],
		[&"tpla_militia", -1, -4], [&"tpla_militia", 1, -4], [&"tpla_rocket_cell", 2, -5], [&"tpla_militia", -2, -5]]
	var groups := [[0, us], [1, eu], [2, tp]]
	var ids := [[], [], []]
	for g in groups:
		for row in g[1]:
			var def: StringName = row[0]
			if Content.unit(def) == null:
				continue
			var t: Vector2i = ctr + Vector2i(int(row[1]) * 3 / 2, int(row[2]) * 3 / 2)
			var u := sim.spawn_unit(def, int(g[0]), null, FX.tile_center(t))
			u.pos = FX.tile_center(t)
			u.home = u.pos
			var to := Vector2(ctr - t)
			u.face = FX.iatan2(int(to.x * 100), int(to.y * 100))
			u.tface = u.face
			u.dir = FX.dir_of(u.face)
			_ensure(u)
			ids[int(g[0])].append(u.id)
	var heli := sim.spawn_unit(&"us_harrier", 0, null, FX.tile_center(ctr + Vector2i(-6, -2)))
	heli.air_state = AirSys.FLYING
	_ensure(heli)
	ids[0].append(heli.id)
	# everyone attack-moves into the middle
	for p in 3:
		m.runner.issue({"p": p, "t": "amove", "ids": ids[p], "pos": FX.tile_center(ctr)})
	for n in m.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n in m.find_children("*", "Control", true, false):
		(n as Control).visible = false
	# sky for the key art (in-game the camera looks down and never sees the horizon)
	for we in m.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (we as WorldEnvironment).environment
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color("#5d7fa6")
		sm.sky_horizon_color = Color("#c9c2b0")
		sm.ground_horizon_color = Color("#a89e88")
		sm.ground_bottom_color = Color("#4a463d")
		sm.sun_angle_max = 30.0
		var sky := Sky.new()
		sky.sky_material = sm
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.fog_light_color = Color("#c9c2b0")
		env.fog_density = 0.0065
		env.fog_sky_affect = 1.0
		env.adjustment_saturation *= 0.86
	m.cam.focus = FX.to_world(FX.tile_center(ctr))
	m.cam.dist = 26.0
	m.cam.target_dist = 26.0
	await frames(55)
	for n in m.find_children("*", "Control", true, false):
		(n as Control).visible = false
	var fx: Vfx = m.world.vfx
	var cw: Vector3 = FX.to_world(FX.tile_center(ctr))
	m.cam.set_process(false)
	m.input.set_process(false)
	var cam: Camera3D = m.cam.cam
	cam.fov = 38.0
	cam.look_at_from_position(cw + Vector3(-11.5, 4.4, 15.5), cw + Vector3(1.5, 0.5, -1.5))
	# set-piece artillery blasts, burning smoke and dust on top of the live fight, staggered so
	# they are caught at different ages (fireball, rolling smoke) rather than all at the flash
	seed(31)
	for wave in 3:
		for k in 3:
			var p := cw + Vector3(randf_range(-8, 8), 0, randf_range(-8, 4))
			fx.explosion(p, randf_range(1.3, 2.3) if wave > 0 else 1.0)
			if wave == 0:
				fx.smoke_puff(p + Vector3(0, 0.6, 0), 0.8, true)
			fx.dust(p, 1.2)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < (300 if wave == 0 else 90):
			await get_tree().process_frame
	Engine.time_scale = 0.02   # freeze the action while the big frames render (slow software GL)
	get_window().size = big
	await frames(2)
	# two fresh fireballs caught near their peak
	fx.explosion(cw + Vector3(-1.5, 0, -3.0), 0.9)
	fx.explosion(cw + Vector3(4.5, 0, 1.0), 0.75)
	Engine.time_scale = 1.0
	await frames(1)
	Engine.time_scale = 0.02
	await frames(1)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("KEYART ", out, " ", img.get_size())
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ensure(e: SimEntity) -> void:
	m.world._ensure_view(e)
	if e.kind == SimEntity.Kind.UNIT:
		m.world.cur[e.id] = m.world._world_pos(e)
		m.world.prev[e.id] = m.world.cur[e.id]

func _open_spot(fp: Vector2i, near: Vector2i) -> Vector2i:
	for r in 80:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := near + Vector2i(dx, dy)
				var ok := true
				for yy in fp.y + 2:
					for xx in fp.x + 2:
						var cc := t + Vector2i(xx - 1, yy - 1)
						ok = ok and sim.map.in_bounds(cc) and sim.map.passable(cc, false) and sim.map.occ[cc.y * sim.map.w + cc.x] == 0
				if ok:
					return t
	return near
