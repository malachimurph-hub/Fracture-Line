extends "res://tests/m33_shots.gd"
## M3.4 screenshots (no release build):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
##     --rendering-method mobile res://tests/m34_shots.tscn -- <out_dir> <part>
## part: night | headlights | shade (night base + city + the same base by day) | inf:<fac> (infantry close-ups: idle, firing, running)
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m34"
	var p: String = args[1] if args.size() > 1 else "inf:us"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if p == "night":
		await run_night()
	elif p == "headlights":
		await run_headlights()
	elif p == "shade":
		await run_night()
		await run_day_base()
	elif p.begins_with("inf:"):
		await run_inf_close(p.substr(4))
	print("=== M34 SHOTS DONE")
	get_tree().quit(0)

func run_inf_close(fac: String) -> void:
	await _start("riverside_metro", [fac, "us" if fac != "us" else "eu"], false)
	var defs: Array = []
	for id in Content.units:
		var ud: UnitDef = Content.units[id]
		if ud.faction == StringName(fac) and ud.view_scene != "" and FileAccess.file_exists(ud.view_scene) and FileAccess.get_file_as_string(ud.view_scene).contains("infantry_view.gd"):
			defs.append(id)
	defs.sort()
	defs = defs.slice(0, 5)
	var hq := FX.to_tile(sim.ents[sim.ids[0]].pos)
	var c := _open_spot(Vector2i(8, 6), hq + Vector2i(10, 6))
	var base := FX.tile_center(c)
	# front row idle, second row (half a tile behind) firing, three running past behind them
	var units: Array = []
	var firing: Array = []
	for k in defs.size():
		units.append(_place(defs[k], base + Vector2i(k * 520, 0), 0))
		firing.append(_place(defs[k], base + Vector2i(k * 520 + 260, -700), 0))
	for k in 3:
		var r := _place(defs[0], base + Vector2i(k * 700, -1900), FX.ANG / 4)
		r.orders = [{"o": "move", "pos": base + Vector2i(k * 700 + 30 * FX.ONE, -1900)}]
	var cam := Camera3D.new()
	add_child(cam)
	await frames(2)
	var w0 := (m.world.views[units[0].id] as Node3D).global_position
	var w1 := (m.world.views[units[units.size() - 1].id] as Node3D).global_position
	var mid := (w0 + w1) * 0.5 + Vector3(0, 0, -0.3)
	cam.fov = 40
	cam.current = true
	for i in 40:
		_fire_all(firing)
		cam.global_position = mid + Vector3(0.2, 1.1, 3.4)
		cam.look_at(mid + Vector3(0, 0.2, 0))
		await get_tree().process_frame
	await shot("inf_%s_wide" % fac)
	var c0 := w0 + Vector3(0.35, 0, -0.3)
	for i in 8:
		_fire_all(firing)
		cam.global_position = c0 + Vector3(0.25, 0.42, 1.45)
		cam.look_at(c0 + Vector3(0, 0.24, 0))
		await get_tree().process_frame
	await shot("inf_%s_close" % fac)
	var f0 := (m.world.views[firing[0].id] as Node3D).global_position
	for i in 8:
		_fire_all(firing)
		cam.global_position = f0 + Vector3(-1.2, 0.4, 0.55)
		cam.look_at(f0 + Vector3(0, 0.25, 0.1))
		await get_tree().process_frame
	await shot("inf_%s_aim" % fac)

func _place(def: StringName, pos: Vector2i, face: int) -> SimEntity:
	var u := _unit(def, FX.to_tile(pos), face)
	u.pos = pos
	u.home = pos
	m.world.cur[u.id] = m.world._world_pos(u)
	m.world.prev[u.id] = m.world.cur[u.id]
	return u

func _fire_all(firing: Array) -> void:
	for f in firing:
		var v: Node = m.world.views.get(f.id)
		if v != null and v.has_method("on_fire"):
			v.on_fire()
			v._last_pos = Vector3.INF   # shots only: hold the firing pose even if the crowd shuffles
			v._speed = 0.0


## M3.4 shading check: the night_base_f layout on the daytime Riverside Metro (shadowed sides)
func run_day_base() -> void:
	await _start("riverside_metro", ["us", "eu"], false)
	var hq := Vector2i(30, 30)
	_bld(&"us_barracks", hq + Vector2i(6, 0))
	_bld(&"us_reactor", hq + Vector2i(0, 6))
	_bld(&"us_garage", hq + Vector2i(6, 6))
	for k in 4:
		_unit([&"us_halberd", &"us_bradley", &"us_lynx", &"us_halberd"][k], hq + Vector2i(12, 2 + k * 3), FX.ANG / 4)
	_look(Vector2(hq.x + 8, hq.y + 7), 0)
	m.cam.dist = 24.0
	m.cam.target_dist = 24.0
	await frames(50)
	await shot("day_base")
