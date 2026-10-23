extends Node
## M2.8 rendered screenshots (one per feedback item):
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m28_shots.tscn -- <out_dir> [all|water|map|airfield|infantry|crash] --dpi=450
var out_dir := "/tmp/m28"
var part := "all"
var m: Node
var sim: SimWorld

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	if args.size() > 1 and not args[1].begins_with("--"):
		part = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if part == "all" or "water" in part:
		await run_water()
	if part == "all" or "map" in part:
		await run_map()
	if part == "all" or "airfield" in part:
		await run_airfield()
	if part == "all" or "infantry" in part:
		await run_infantry()
	if part == "all" or "crash" in part:
		await run_crash()
	print("=== M28 SHOTS DONE")
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())

func _start(mid: String, facs: Array, fog: bool) -> void:
	if m != null:
		m.queue_free()
		await frames(2)
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 28
	cfg["map"] = mid
	for i in 4:
		cfg["slots"][i]["kind"] = "closed"
	for i in facs.size():
		cfg["slots"][i]["kind"] = "human" if i == 0 else "ai"
		cfg["slots"][i]["faction"] = facs[i]
		cfg["slots"][i]["team"] = i
		cfg["slots"][i]["spawn"] = i
	cfg["options"]["fog"] = fog
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	sim = m.runner.sim
	m.runner.ais.clear()

func _look(t: Vector2, lvl: int) -> void:
	m.cam.jump_to(Vector3(t.x, 0, t.y), false)
	m.cam.set_level(lvl)

func _find(ch: Array, from: Vector2i) -> Vector2i:
	## nearest tile of a type to `from`
	for r in 200:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := from + Vector2i(dx, dy)
				if sim.map.in_bounds(t) and ch.has(sim.map.ttype(t)):
					return t
	return from

func run_water() -> void:
	await _start("kessel_pass", ["us", "eu"], false)
	var t := _find([SimMap.T.WATER], Vector2i(40, 128))
	_look(Vector2(t.x + 2, t.y + 3), 0)
	await frames(40)
	await shot("water_kessel_winter")

func run_map() -> void:
	await _start("varno_crossing", ["us", "eu"], false)
	m.cam.jump_to(Vector3(128, 0, 128), false)
	m.cam.set_level(2)
	await frames(30)
	await shot("map_varno_256_overview")

func run_airfield() -> void:
	pass

func run_infantry() -> void:
	pass

func run_crash() -> void:
	pass
