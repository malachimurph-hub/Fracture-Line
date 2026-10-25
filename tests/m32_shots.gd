extends "res://tests/m30_shots.gd"
## M3.2 screenshots (no release build):
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m32_shots.tscn -- <out_dir> <gfx|new> [name]
## gfx: the same RTS-zoom base + battle scene (graphics before/after)
## new: barricades (manned), Drone Operator + drones, Field Engineer + mines, a bridge
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m32"
	var p: String = args[1] if args.size() > 1 else "gfx"
	var nm: String = args[2] if args.size() > 2 else "m32_" + p
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	if p == "gfx":
		await run_gfx(nm)
	elif p == "new":
		await run_new(nm)
	elif p == "tex":
		await run_tex(nm)
	elif p == "text":
		await run_tex(nm, false)
	elif p == "texc":
		await run_combat(nm)
	get_tree().quit(0)

func run_gfx(nm: String) -> void:
	await _start("ochre_wells", ["us", "eu"], false)
	var c := Vector2i(40, 40)
	_bld(&"us_command", c)
	_bld(&"us_barracks", c + Vector2i(6, 0))
	_bld(&"us_reactor", c + Vector2i(11, 1))
	_bld(&"us_patriot", c + Vector2i(11, 5))
	_bld(&"us_garage", c + Vector2i(0, 6))
	var row := [&"us_halberd", &"us_halberd", &"us_bradley", &"us_lynx", &"us_dozer"]
	for k in row.size():
		_unit(row[k], c + Vector2i(6 + k * 2, 8), FX.ANG / 8)
	for k in 6:
		_unit(&"us_grunt", c + Vector2i(5 + k, 11), FX.ANG / 8)
	var foe := [&"eu_leopold", &"eu_leopold", &"eu_boxer", &"eu_wolfhound"]
	for k in foe.size():
		_unit(foe[k], c + Vector2i(8 + k * 2, 15), FX.ANG / 2 + FX.ANG / 8, 1)
	_look(Vector2(c.x + 8, c.y + 8), 1)
	await frames(60)
	await shot(nm)

func _bld_o(id: StringName, at: Vector2i, owner: int) -> SimEntity:
	var bd: BuildingDef = Content.building(id)
	var t := _open_spot(bd.footprint, at)
	var b := sim._place_building(bd, owner, t, 0, true)
	_ensure(b)
	return b

func run_new(nm: String) -> void:
	await _start("varno_crossing", ["us", "eu"], false)
	var bt := _find([SimMap.T.BRIDGE], Vector2i(128, 128))
	# walk to the bridge's land end along x or y
	var land := bt
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t: Vector2i = bt
		while sim.map.in_bounds(t) and sim.map.ttype(t) == SimMap.T.BRIDGE:
			t += d
		if sim.map.in_bounds(t) and sim.map.passable(t, true) and sim.map.ttype(t) != SimMap.T.WATER and (t - bt).length() < 30:
			land = t
			break
	print("bridge ", bt, " land end ", land)
	# US: manned concrete + sandbag barricades, Drone Operator with both drones in the air
	var bar := _bld_o(&"us_barricade", land + Vector2i(2, 1), 0)
	var sb := _bld_o(&"us_sandbags", land + Vector2i(-2, 2), 0)
	for k in 3:
		var g := _unit(&"us_grunt", land + Vector2i(k, 4), 0)
		g.res_id = -bar.id
	for k in 2:
		var g2 := _unit(&"us_grunt", land + Vector2i(-k, 5), 0)
		g2.res_id = -sb.id
	var op := _unit(&"us_drone_operator", land + Vector2i(1, 4), FX.ANG / 2)
	var bomb := _unit(&"us_bomb_drone", land + Vector2i(-1, 1), FX.ANG / 2)
	bomb.air_home = op.id
	var scout := _unit(&"us_scout_drone", land + Vector2i(3, 0), FX.ANG / 2)
	scout.air_home = op.id
	_unit(&"us_breacher", land + Vector2i(4, 3), FX.ANG / 2)
	# Germany: Field Engineer laying a minefield next to a sandbag wall, repairing a tank
	var eu_at := land + Vector2i(0, -6)
	_bld_o(&"eu_sandbags", eu_at, 1)
	_bld_o(&"eu_minefield", eu_at + Vector2i(3, 0), 1)
	_unit(&"eu_field_engineer", eu_at + Vector2i(1, -2), 0, 1)
	_unit(&"eu_field_engineer", eu_at + Vector2i(2, -2), 0, 1)
	_unit(&"eu_leopold", eu_at + Vector2i(-2, -2), 0, 1)
	_unit(&"eu_sturmtrupp", eu_at + Vector2i(4, -2), 0, 1)
	_look(Vector2(land.x + 0.5, land.y - 1.0), 1)
	await frames(90)
	await shot(nm)

## M3.2 item 14: texture/model rebuild before/after, closest RTS zoom: HQ + factory per faction,
## tanks, IFVs and infantry of all four factions on the arid map (terrain fills the gaps).
func run_tex(nm: String, combat := true) -> void:
	## M3.2 item 14 before/after: (1) temperate base beside the village at a high oblique camera
	## like the art-direction shots, (2) a desert tank battle (live sim: fire, wrecks, smoke, tracks)
	await _start("harrow_junction", ["us", "ecc"], false)
	var c := Vector2i(100, 148)
	_bld(&"us_command", c)
	_bld(&"us_garage", c + Vector2i(7, 0))
	_bld(&"us_barracks", c + Vector2i(0, 7))
	_bld(&"us_reactor", c + Vector2i(7, 7))
	for k in 4:
		_unit(&"us_halberd", c + Vector2i(13 + (k % 2) * 2, 2 + (k / 2) * 2), FX.ANG / 8)
	for k in 5:
		_unit(&"us_grunt", c + Vector2i(4 + k, 13), FX.ANG / 8)
	_bld_o(&"eu_heavy_factory", c + Vector2i(14, 12), 0)
	_look(Vector2(c.x + 16, c.y + 8), 2)   # real game camera (M3.2 polish: 40 deg default pitch)
	await frames(90)
	await shot(nm + "_town")
	if combat:
		await run_combat(nm)

func run_combat(nm: String) -> void:
	await _start("ochre_wells", ["us", "ecc"], false)
	var b := Vector2i(52, 44)
	var us := [&"us_halberd", &"us_bradley", &"us_halberd", &"us_halberd", &"us_bradley", &"us_halberd"]
	var ru := [&"ecc_t90", &"ecc_btr", &"ecc_t90", &"ecc_t90", &"ecc_t90", &"ecc_btr"]
	var all: Array = []
	for k in 6:
		var a := _unit(us[k], b + Vector2i(-5 - (k % 2) * 2, -5 + k * 2), FX.ANG / 4, 0)
		var e := _unit(ru[k], b + Vector2i(5 + (k % 2) * 2, -5 + k * 2), FX.ANG * 3 / 4, 1)
		for u in [a, e]:
			u.max_hp *= 40
			u.hp = u.max_hp
			all.append(u)
	for i in range(0, all.size(), 2):   # each pair trades fire; the weak front pair dies early (wrecks)
		all[i].orders = [{"o": "attack", "target": all[i + 1].id}]
		all[i + 1].orders = [{"o": "attack", "target": all[i].id}]
	for k in 2:   # gunships overhead (aircraft ground shadows)
		var heli := sim.spawn_unit(&"us_harrier", 0, null, FX.tile_center(b + Vector2i(-8 + k * 3, 3 + k * 3)))
		heli.air_state = AirSys.FLYING
		_ensure(heli)
	await frames(200)
	_look(Vector2(b.x, b.y + 5), 1)
	for i in 3:   # three tanks are knocked out shortly before the shot (wrecks, fireballs, smoke)
		var u: SimEntity = all[i * 4 + 1]
		if u.alive:
			u.hp = 1
		await frames(12)
	await frames(30)
	await shot(nm + "_combat")
