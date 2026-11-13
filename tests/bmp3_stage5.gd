extends "res://tests/m30_shots.gd"
## Live match check for the wired BMP-3: scale, drive, turret, the three weapons, embark.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1280x720 \
##     res://tests/bmp3_stage5.tscn -- /tmp/bmp3v2

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/bmp3v2"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _start("varno_crossing", ["ecc", "us"], false)
	var spot := Vector2i(48, 48)
	var bmp := _unit(&"ecc_bmp3", spot, 0)
	var t90 := _unit(&"ecc_t90", spot + Vector2i(5, 0), 0)
	var squad := _unit(&"ecc_squad", spot + Vector2i(-3, 1), 0)
	var grunt := _unit(&"us_grunt", spot + Vector2i(0, 8), FX.ANG / 2, 1)
	bmp.dir = FX.dir_of(0)
	bmp.face = 0
	bmp.tface = 0
	m.ctl.set_selection([bmp.id])
	_frame(bmp, 11.0)
	await frames(12)
	var view: VehicleView = m.world.views[bmp.id]
	var anchor := view.find_child("HealthBarAnchor", true, false) as Node3D
	print("BAR height ", view.bar_height, " anchor y ", anchor.position.y if anchor != null else -1)
	print("SCALE bmp ", view.global_position, " t90 ", (m.world.views[t90.id] as Node3D).global_position, " squad ", (m.world.views[squad.id] as Node3D).global_position)
	await shot("match_scale")
	# Drive a few metres so the tracks scroll.
	var origin := bmp.pos
	for step in 6:
		m.world.prev[bmp.id] = m.world.cur[bmp.id]
		bmp.pos = origin + Vector2i(0, FX.ONE * (step + 1) / 2)
		bmp.moving = true
		m.world.cur[bmp.id] = m.world._world_pos(bmp)
		await frames(3)
	_frame(bmp, 9.0)
	await frames(4)
	await shot("match_drive")
	bmp.moving = false
	m.set_paused(true)
	bmp.tface = bmp.face + FX.ANG / 4
	var yaw0: float = (m.world.views[bmp.id] as VehicleView).turret.rotation.y
	await frames(20)
	var yaw1: float = (m.world.views[bmp.id] as VehicleView).turret.rotation.y
	print("TURRET face ", bmp.face, " tface ", bmp.tface, " yaw ", yaw0, " -> ", yaw1)
	_frame(bmp, 8.0)
	await shot("match_turret")
	m.set_paused(false)
	bmp.tface = bmp.face
	await frames(24)
	await _fire(bmp, grunt, &"ecc_bmp_100", "match_fire_100")
	await _fire(bmp, grunt, &"ecc_bmp_30", "match_fire_30")
	await _fire(bmp, grunt, &"ecc_bmp_atgm", "match_fire_atgm")
	m.world.local_team = 0
	squad.pos = bmp.pos + Vector2i(FX.ONE, 0)
	var boarded := RosterSys.board(sim, squad, bmp)
	_flush()
	await frames(6)
	print("EMBARK ", boarded, " aboard ", squad.res_id == -bmp.id, " squad visible ", m.world.views[squad.id].visible)
	_frame(bmp, 8.0)
	await shot("match_embark")
	RosterSys.unload(sim, bmp)
	_flush()
	await frames(8)
	print("DISEMBARK res ", squad.res_id, " visible ", m.world.views[squad.id].visible)
	_frame(bmp, 9.0)
	await shot("match_disembark")
	print("=== BMP3 STAGE 5")
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

func _fire(bmp: SimEntity, tgt: SimEntity, wid: StringName, name: String) -> void:
	m.world.local_team = -1
	CombatSys.fire(sim, bmp, tgt, Content.weapon(wid), 100)
	_flush()
	var mk_name := "GunMuzzle30" if wid == &"ecc_bmp_30" else "GunMuzzle100"
	var view: Node3D = m.world.views[bmp.id]
	var mk := view.find_child(mk_name, true, false) as Node3D
	var origin := Vector3.ZERO
	var got := false
	if m.world.wfx != null and not m.world.wfx.shots.is_empty():
		origin = m.world.wfx.shots[m.world.wfx.shots.size() - 1]["p0"]
		got = true
	var gap := origin.distance_to(mk.global_position) if got and mk != null else -1.0
	print("FIRE ", wid, " marker ", mk.global_position if mk != null else "none", " shot ", origin if got else "none", " gap ", gap, " rounds ", m.world.wfx.shots.size() if m.world.wfx != null else 0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34.0
	cam.current = true
	var at: Vector3 = view.global_position + Vector3(0, 0.7, 0)
	cam.global_position = at + Vector3(7.0, 3.4, -6.0)
	cam.look_at(at, Vector3.UP)
	await frames(1)
	await shot(name)
	cam.queue_free()
	m.cam.cam.current = true
