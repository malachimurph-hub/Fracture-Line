extends "res://tests/m30_shots.gd"
## Live match check for the finished Mi-8: hover, flight, the door gun, embark, land, unload.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tests/mi8_stage5.tscn -- /tmp/mi8v2

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/mi8v2"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["ecc", "us"], false)
	var spot := Vector2i(48, 48)
	var heli := _unit(&"ecc_mi8", spot, 0)
	var squad := _unit(&"ecc_squad", spot + Vector2i(-4, 1), 0)
	var grunt := _unit(&"us_grunt", spot + Vector2i(0, 6), FX.ANG / 2, 1)
	heli.air_state = AirSys.FLYING
	heli.orders.clear()
	heli.goal = MoveSys.NONE
	heli.spd = 0
	m.ctl.set_selection([heli.id])
	_frame(heli, 18.0)
	await frames(16)
	var view: VehicleView = m.world.views[heli.id]
	var rotor := view.find_child("Rotor", true, false) as Node3D
	var tail := view.find_child("TailRotor", true, false) as Node3D
	var anchor := view.find_child("HealthBarAnchor", true, false) as Node3D
	var y0 := rotor.rotation.y
	var x0 := tail.rotation.x
	await frames(8)
	print("HOVER y ", view.global_position.y, " bar ", view.bar_height, " anchor ", anchor.position.y if anchor != null else -1, " sel ", view.selection_radius)
	print("SPIN main ", y0, " -> ", rotor.rotation.y, " tail ", x0, " -> ", tail.rotation.x, " axes ", rotor.get_meta("rotor_axis"), tail.get_meta("rotor_axis"))
	await shot("match_hover")
	var origin := heli.pos
	for step in 5:
		m.world.prev[heli.id] = m.world.cur[heli.id]
		heli.pos = origin + Vector2i(0, FX.ONE * (step + 1))
		heli.moving = true
		m.world.cur[heli.id] = m.world._world_pos(heli)
		await frames(3)
	_frame(heli, 16.0)
	await frames(4)
	await shot("match_fly")
	heli.moving = false
	await _fire(heli, grunt)
	# Land, take the squad aboard, lift off, then the drop order brings it down to unload.
	heli.air_state = AirSys.PARKED
	heli.orders.clear()
	await frames(18)
	squad.pos = heli.pos + Vector2i(FX.ONE, 0)
	var boarded := RosterSys.board(sim, squad, heli)
	_flush()
	await frames(6)
	print("EMBARK ", boarded, " aboard ", squad.res_id == -heli.id, " cap ", Content.unit(&"ecc_mi8").transport_capacity, " visible ", m.world.views[squad.id].visible)
	_frame(heli, 14.0)
	await shot("match_embark")
	heli.air_state = AirSys.FLYING
	await frames(12)
	RosterSys.unload(sim, heli)
	var landed := false
	for _i in 50:
		m.runner.advance()
		if heli.air_state == AirSys.PARKED and squad.res_id >= 0:
			landed = true
			break
	_flush()
	await frames(16)
	print("DISEMBARK state ", heli.air_state, " res ", squad.res_id, " visible ", m.world.views[squad.id].visible, " landed ", landed)
	_frame(heli, 16.0)
	await shot("match_disembark")
	print("=== MI8 STAGE 5")
	get_tree().quit(0)

func _frame(u: SimEntity, dist: float) -> void:
	var p := FX.to_world(u.pos)
	m.cam.jump_to(p, false)
	m.cam.dist = dist
	m.cam.target_dist = dist

func _flush() -> void:
	var evs: Array = sim.events.duplicate()
	sim.events.clear()
	m.world.on_tick(evs)

func _fire(heli: SimEntity, tgt: SimEntity) -> void:
	m.world.local_team = -1
	CombatSys.fire(sim, heli, tgt, Content.weapon(&"ecc_mi8_mg"), 100)
	_flush()
	var view: Node3D = m.world.views[heli.id]
	var mouths: Array = []
	for n in view.find_children("Muzzle*", "Marker3D", true, false):
		mouths.append(n)
	var origin := Vector3.ZERO
	var got := false
	if m.world.wfx != null and not m.world.wfx.shots.is_empty():
		origin = m.world.wfx.shots[m.world.wfx.shots.size() - 1]["p0"]
		got = true
	var best := 999.0
	var which := ""
	for mk in mouths:
		var gap := origin.distance_to((mk as Node3D).global_position) if got else -1.0
		if gap >= 0.0 and gap < best:
			best = gap
			which = (mk as Node3D).name
	print("FIRE ecc_mi8_mg from ", which, " gap ", best, " rounds ", m.world.wfx.shots.size() if m.world.wfx != null else 0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34.0
	cam.current = true
	var at: Vector3 = view.global_position + Vector3(0, 1.2, 0)
	cam.global_position = at + Vector3(9.0, 4.2, -8.0)
	cam.look_at(at, Vector3.UP)
	await frames(2)
	await shot("match_fire")
	cam.queue_free()
	m.cam.cam.current = true
