extends "res://tests/m33_shots.gd"
## M3.4 screenshots (no release build):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
##     --rendering-method mobile res://tests/m34_shots.tscn -- <out_dir> <part>
## part: night | headlights | inf:<fac> (infantry close-ups: idle, firing, running)
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
	elif p.begins_with("inf:"):
		await run_inf_close(p.substr(4))
	print("=== M34 SHOTS DONE")
	get_tree().quit(0)

func run_inf_close(fac: String) -> void:
	await _start("varno_crossing", [fac, "us" if fac != "us" else "eu"], false)
	var defs: Array = []
	for id in Content.units:
		var ud: UnitDef = Content.units[id]
		if ud.faction == StringName(fac) and ud.tags.has("infantry") and ud.view_scene != "" and ResourceLoader.exists(ud.view_scene):
			var sc: PackedScene = load(ud.view_scene)
			if sc.get_state().get_node_count() > 0 and FileAccess.get_file_as_string(ud.view_scene).contains("infantry_view.gd"):
				defs.append(id)
	defs.sort()
	var c := Vector2i(40, 40)
	var hq := FX.to_tile(sim.ents[sim.ids[0]].pos)
	c = hq + Vector2i(8, 8)
	defs = defs.slice(0, 6)
	var units: Array = []
	# row 1: every role idle; row 2: the same roles firing; row 3: three riflemen running
	for k in defs.size():
		units.append(_unit(defs[k], c + Vector2i(k, 0), FX.ANG / 2))
	var firing: Array = []
	for k in defs.size():
		firing.append(_unit(defs[k], c + Vector2i(k, 1), FX.ANG / 2))
	for k in 3:
		var r := _unit(defs[0], c + Vector2i(k * 2, -2), FX.ANG / 4)
		r.orders = [{"o": "move", "pos": FX.tile_center(c + Vector2i(k * 2 + 30, -2))}]
	var cam := Camera3D.new()
	add_child(cam)
	await frames(2)
	var fv: Node3D = m.world.views[units[0].id]
	var fwd := fv.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var side := Vector3.UP.cross(fwd).normalized()
	var mid := (fv.global_position + (m.world.views[firing[firing.size() - 1].id] as Node3D).global_position) * 0.5
	cam.fov = 38
	cam.current = true
	for i in 40:
		_fire_all(firing)
		cam.global_position = mid + fwd * 4.6 + Vector3.UP * 1.9 + side * 0.4
		cam.look_at(mid + Vector3(0, 0.2, 0))
		await get_tree().process_frame
	await shot("inf_%s_wide" % fac)
	# close-up: the first two roles, idle and firing
	var c0: Vector3 = ((m.world.views[units[0].id] as Node3D).global_position + (m.world.views[firing[1 if firing.size() > 1 else 0].id] as Node3D).global_position) * 0.5
	cam.fov = 30
	for i in 8:
		_fire_all(firing)
		cam.global_position = c0 + fwd * 2.3 + Vector3.UP * 0.75 + side * 0.5
		cam.look_at(c0 + Vector3(0, 0.25, 0))
		await get_tree().process_frame
	await shot("inf_%s_close" % fac)
	# side view of a firing soldier (two-handed aim)
	var f0: Vector3 = (m.world.views[firing[0].id] as Node3D).global_position
	for i in 8:
		_fire_all(firing)
		cam.global_position = f0 + side * 1.3 + fwd * 0.5 + Vector3.UP * 0.45
		cam.look_at(f0 + Vector3(0, 0.27, 0))
		await get_tree().process_frame
	await shot("inf_%s_aim" % fac)

func _fire_all(firing: Array) -> void:
	for f in firing:
		var v: Node = m.world.views.get(f.id)
		if v != null and v.has_method("on_fire"):
			v.on_fire()
