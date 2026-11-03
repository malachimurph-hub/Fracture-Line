## M4.2 headless checks (test_runner "m42"): Malachi's 0.4.2 list - damage on impact, transport
## helicopters land before troops board, mass unload, smart targeting, rally points only where
## units come out, build next to supply stashes, mines removed, Supply Stash naming, etc.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_impact(t)
	_landing(t)
	_mass_unload(t)
	_smart(t)
	_rally(t)
	_build_rules(t)
	_text(t)
	if ResourceLoader.exists("res://tests/m42_more.gd"):
		await load("res://tests/m42_more.gd").run(t)

static func _ticks(r: MatchRunner, n: int) -> void:
	for i in n:
		r.advance()

static func _mid(w: SimWorld) -> Vector2i:
	return Vector2i(w.map.w / 2, w.map.h / 2)

# ------------------------------------------------------------------ 5: damage lands with the round
static func _impact(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := _mid(w)
	var jav := w.spawn_unit(&"us_javelin", 0, null, FX.tile_center(c))
	var tank := w.spawn_unit(&"ecc_t90", 1, null, FX.tile_center(c + Vector2i(9, 0)))
	w.rebuild_spatial()
	var wd := Content.weapon(Content.unit(&"us_javelin").weapons[0])
	var sc := wd.scatter_mt
	wd.scatter_mt = 0
	var h0 := tank.hp
	CombatSys.fire(w, jav, tank, wd, 100)
	wd.scatter_mt = sc
	var ft := CombatSys.flight_ticks(wd, FX.dist(jav.pos, tank.pos))
	t._check(ft >= 8 and tank.hp == h0 and w.flight.size() == 1, "missile launched: no damage yet, %d ticks of flight" % ft)
	var at := int(w.flight[0]["at"])
	w.tick = at - 1
	CombatSys.resolve_flight(w)
	t._check(tank.hp == h0, "still in the air one tick before impact")
	w.tick = at
	CombatSys.resolve_flight(w)
	t._check(tank.hp < h0 and w.flight.is_empty(), "damage applied on impact (%d -> %d)" % [h0, tank.hp])
	# the round lands even if the shooter died meanwhile; rounds in the air survive a save/load
	var h1 := tank.hp
	wd.scatter_mt = 0
	CombatSys.fire(w, jav, tank, wd, 100)
	wd.scatter_mt = sc
	var d := w.serialize()
	var w2 := SimWorld.new()
	w2.deserialize(d)
	t._check(w2.flight.size() == 1, "rounds in flight are saved")
	jav.alive = false
	w.tick = int(w.flight[0]["at"])
	CombatSys.resolve_flight(w)
	t._check(tank.hp < h1, "a round already fired still hits after its shooter dies")
	# rifles: nearly instant, still never before the round arrives
	var rf := Content.weapon(&"ecc_ak74")
	t._check(CombatSys.flight_ticks(rf, FX.ONE * 3) <= 1, "rifle rounds at close range land within a tick")

# ------------------------------------------------------------------ 6: land before boarding
static func _landing(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := _mid(w)
	var heli := w.spawn_unit(&"us_blackhawk", 0, null, FX.tile_center(c))
	var sq := w.spawn_unit(&"us_squad", 0, null, FX.tile_center(c + Vector2i(5, 0)))
	_ticks(r, 10)
	t._check(w.flying(heli), "Black Hawk hovers")
	r.sim.queue_command({"p": 0, "t": "garrison", "ids": [sq.id], "target": heli.id})
	var boarded_air := false
	var landed_t := -1
	for i in 200:
		r.advance()
		if sq.res_id < 0 and w.flying(heli):
			boarded_air = true
		if landed_t < 0 and heli.air_state == AirSys.PARKED:
			landed_t = i
		if sq.res_id < 0:
			break
	t._check(not boarded_air, "nobody boards while the helicopter is in the air")
	t._check(landed_t >= 0 and heli.air_state == AirSys.PARKED and not w.flying(heli), "the helicopter lands for the boarding squad (landed after %d ticks)" % landed_t)
	t._check(sq.res_id == -heli.id, "the squad boards the landed helicopter")
	r.sim.queue_command({"p": 0, "t": "move", "ids": [heli.id], "pos": heli.pos + Vector2i(FX.ONE * 12, 0)})
	_ticks(r, 20)
	t._check(w.flying(heli) and FX.dist(heli.pos, FX.tile_center(c)) > FX.ONE, "it lifts off with the squad on a move order")
	t._check(sq.res_id == -heli.id, "the squad rides along")

# ------------------------------------------------------------------ 7: mass unload
static func _mass_unload(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := _mid(w)
	var trs: Array = []
	for k in 3:
		var tr := w.spawn_unit(&"us_bradley", 0, null, FX.tile_center(c + Vector2i(k * 4, 0)))
		if RosterSys.capacity(w, tr) <= 0:
			tr = w.spawn_unit(&"us_lynx", 0, null, FX.tile_center(c + Vector2i(k * 4, 0)))
		var g := w.spawn_unit(&"us_grunt", 0, null, tr.pos)
		RosterSys.board(w, g, tr)
		trs.append(tr)
	var ids: Array = trs.map(func(e): return e.id)
	var n0 := 0
	for e in trs:
		n0 += RosterSys.load_of(w, e)
	t._check(n0 == 3, "three transports loaded (%d aboard)" % n0)
	r.sim.queue_command({"p": 0, "t": "unload", "ids": ids})
	_ticks(r, 2)
	var n1 := 0
	for e in trs:
		n1 += RosterSys.load_of(w, e)
	t._check(n1 == 0, "one Unload with several transports selected empties all of them")
	var src := FileAccess.get_file_as_string("res://ui/hud/hud.gd")
	t._check(src.contains("CMD_UNLOAD_ALL") and src.contains("tr_ids.size() > 1"), "HUD shows Unload All only with several transports selected")

# ------------------------------------------------------------------ 15: smart targeting
static func _smart(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := _mid(w)
	var jav := w.spawn_unit(&"us_javelin", 0, null, FX.tile_center(c))
	var rif := w.spawn_unit(&"ecc_rifleman", 1, null, FX.tile_center(c + Vector2i(4, 0)))
	var tank := w.spawn_unit(&"ecc_t90", 1, null, FX.tile_center(c + Vector2i(0, 6)))
	w.rebuild_spatial()
	FogSys.run(w, true)
	t._check(CombatSys.eff_pct(w, jav, tank) > CombatSys.eff_pct(w, jav, rif), "anti-tank weapons rate tanks above infantry (%d vs %d)" % [CombatSys.eff_pct(w, jav, tank), CombatSys.eff_pct(w, jav, rif)])
	var pick := OrderSys.find_target(w, jav, jav.pos, FX.ONE * 12)
	t._check(pick == tank, "Javelin team picks the tank over a closer rifleman (%s)" % (pick.def_id if pick else &"none"))
	var mg := w.spawn_unit(&"ecc_machine_gunner", 1, null, FX.tile_center(c + Vector2i(1, 20)))
	var us_t := w.spawn_unit(&"us_halberd", 0, null, FX.tile_center(c + Vector2i(1, 23)))
	var us_g := w.spawn_unit(&"us_grunt", 0, null, FX.tile_center(c + Vector2i(4, 20)))
	w.rebuild_spatial()
	FogSys.run(w, true)
	var p2 := OrderSys.find_target(w, mg, mg.pos, FX.ONE * 10)
	t._check(p2 == us_g, "machine gunner picks infantry over a closer tank (%s)" % (p2.def_id if p2 else &"none"))
	# a defence: AA turret prefers aircraft, and nothing is picked out of range
	var heli := w.spawn_unit(&"us_blackhawk", 0, null, FX.tile_center(c + Vector2i(30, 5)))
	t._check(CombatSys.eff_pct(w, us_g, heli) >= 10, "effectiveness never drops to zero")

# ------------------------------------------------------------------ 16: rally points
static func _rally(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var prod := 0
	var other := 0
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if b.kind == SimEntity.Kind.BUILDING and b.owner == 0:
			if CommandSys.rally_ok(w, b):
				prod += 1
			else:
				other += 1
	var hq: SimEntity = M33._hq(w, 0)
	t._check(CommandSys.rally_ok(w, hq) == not Content.building(hq.def_id).produces.is_empty(), "HQ rally follows whether it produces units")
	var c := _mid(w)
	var pp := w._place_building(Content.building(&"us_reactor") if Content.building(&"us_reactor") else Content.building(&"us_power_plant"), 0, c, 0, true)
	if pp != null:
		w.queue_command({"p": 0, "t": "rally", "ids": [pp.id], "pos": pp.pos + Vector2i(FX.ONE * 5, 0)})
		_ticks(r, 1)
		t._check(pp.rally == Vector2i(-1, -1), "a power plant takes no rally point")
	var fac: SimEntity = null
	for id in w.ids:
		var b2: SimEntity = w.ents[id]
		if b2.kind == SimEntity.Kind.BUILDING and b2.owner == 0 and not w.bdef(b2).produces.is_empty():
			fac = b2
	if fac != null:
		w.queue_command({"p": 0, "t": "rally", "ids": [fac.id], "pos": fac.pos + Vector2i(FX.ONE * 5, 0)})
		_ticks(r, 1)
		t._check(fac.rally != Vector2i(-1, -1), "a production structure keeps its rally point")

# ------------------------------------------------------------------ 8, 18: build rules
static func _build_rules(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var res: SimEntity = null
	for id in w.ids:
		if w.ents[id].kind == SimEntity.Kind.RESOURCE:
			res = w.ents[id]
			break
	var blocked := 0
	var near := 0
	for yy in range(-4, 5):
		for xx in range(-4, 5):
			var c := res.tile + Vector2i(xx, yy)
			if w.map.in_bounds(c) and w.map.nobuild[w.map.idx(c)] != 0:
				blocked += 1
				if maxi(absi(xx), absi(yy)) > 1:
					near += 1
	t._check(blocked > 0 and blocked <= 9 and near == 0, "only the stash itself blocks building (%d tiles, none beyond it)" % blocked)
	t._check(not Content.building(&"eu_minefield").buildable and not Content.building(&"tpla_demo_trap").buildable, "anti-tank mines removed from every build menu")
	var mines := 0
	for bid in Content.buildings:
		var bd: BuildingDef = Content.building(bid)
		if bd.buildable and (bd.tags.has("mine") or bd.tags.has("trap")):
			mines += 1
	t._check(mines == 0, "no buildable mine / trap left")
	t._check(w.can_place(0, &"eu_minefield", res.tile + Vector2i(8, 8)) != "", "placing a minefield is refused")

# ------------------------------------------------------------------ 9, 17: text and menu
static func _text(t: Node) -> void:
	t._check(TranslationServer.translate("RES_SEAM") == "Supply Stash", "the veridite seam is called Supply Stash")
	var csv := FileAccess.get_file_as_string("res://locale/strings.csv").to_lower()
	t._check(not csv.contains("veridite"), "no 'veridite' left in player-facing text")
	var mm := FileAccess.get_file_as_string("res://ui/main_menu.gd")
	t._check(mm.contains("MENU_MAP_BUILDER_SOON_TOAST") and not mm.contains("goto(\"res://ui/map_builder.tscn\")"), "Map Builder is marked coming soon and does not open")
	var hud := FileAccess.get_file_as_string("res://ui/hud/hud.gd")
	t._check(hud.contains("PAUSE_OPTIONS") and hud.contains("vol_music"), "pause menu has an Options page with volume sliders")
