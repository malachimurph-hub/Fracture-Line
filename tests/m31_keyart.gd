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
	var c := _open_spot(Vector2i(26, 18), Vector2i(64, 64))
	var ctr := c + Vector2i(13, 9)
	var us := [[&"us_halberd", -6, 4], [&"us_halberd", -2, 6], [&"us_longreach", -9, 8], [&"us_bradley", -4, 1], [&"us_lynx", -10, 3],
		[&"us_grunt", -3, 3], [&"us_grunt", -2, 2], [&"us_grunt", -1, 4], [&"us_javelin", -4, 5], [&"us_grunt", 0, 3]]
	var eu := [[&"eu_leopold", 6, 3], [&"eu_leopold", 8, 6], [&"eu_boxer", 4, 0], [&"eu_salamander", 9, 1], [&"eu_crawler", 12, 7],
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
			var t: Vector2i = ctr + Vector2i(int(row[1]), int(row[2]))
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
	m.hud.visible = false
	for n in m.hud.get_children():
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	m.cam.focus = FX.to_world(FX.tile_center(ctr))
	m.cam.dist = 26.0
	m.cam.target_dist = 26.0
	await frames(150)
	# set-piece artillery blasts + smoke on top of the live fight
	var fx: Vfx = m.world.vfx
	var cw: Vector3 = FX.to_world(FX.tile_center(ctr))
	for k in 6:
		var p := cw + Vector3(randf_range(-6, 6), 0, randf_range(-6, 4))
		fx.explosion(p, randf_range(1.2, 2.2))
		fx.smoke_puff(p + Vector3(0, 0.5, 0), 1.0, true)
	await frames(6)
	m.cam.set_process(false)
	m.input.set_process(false)
	var cam: Camera3D = m.cam.cam
	cam.fov = 38.0
	cam.look_at_from_position(cw + Vector3(-11.0, 7.5, 15.0), cw + Vector3(1.0, 0.3, -1.0))
	get_window().size = big
	await frames(8)
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
