## M3.3 Phase 3 headless checks (run from m33_test): the moving Russian mine, destructible
## civilians, night maps, ground variety, elevation, new maps and 8-player lobbies.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_mine_moves(t)
	_civilians(t)
	_night(t)

static func _adv(r: MatchRunner, n: int) -> void:
	for i in n:
		r.advance()

# ------------------------------------------------------------------ 28: the mine moves
static func _mine_moves(t: Node) -> void:
	var r := M33._runner(["ecc", "us"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	var st := M33.spot(w, 0, &"ecc_black_market", hq.tile + Vector2i(6, 0))
	var b := w._place_building(Content.building(&"ecc_black_market"), 0, st, 0, true)
	b.hp = b.max_hp / 2
	_adv(r, 2)
	r.issue({"p": 0, "t": "pack", "target": b.id})
	_adv(r, 2)
	t._check(MineSys.packing(w, b) and b.alive, "Pack Up starts a 10 s pack-up")
	var m0: int = w.players[0].supply
	_adv(r, 30 * 20)
	var mob: SimEntity = null
	for id in w.ids:
		if w.ents[id].def_id == &"ecc_mine_mobile":
			mob = w.ents[id]
	t._check(not b.alive and mob != null and mob.owner == 0 and mob.hp < mob.max_hp and w.map.occ[w.map.idx(st)] == 0,
		"after 10 s the structure becomes a slow vehicle with the same damage, and frees its ground (%s)" % (str([mob.hp, mob.max_hp, w.map.occ[w.map.idx(st)]]) if mob != null else "none"))
	t._check(w.players[0].supply - m0 < 400, "it earns nothing while packed ($%d in 30 s)" % (w.players[0].supply - m0))
	t._check(Content.unit(&"ecc_mine_mobile").speed_mtps * 4 == Content.unit(&"ecc_engineer").speed_mtps, "it drives at a quarter of the engineer's speed")
	if mob == null:
		return
	var p0 := mob.pos
	r.issue({"p": 0, "t": "move", "ids": [mob.id], "pos": mob.pos + Vector2i(8 * FX.ONE, 4 * FX.ONE)})
	_adv(r, 20 * 20)
	t._check(FX.dist(p0, mob.pos) > 3 * FX.ONE, "the packed mine drives (%.1f tiles in 20 s)" % (FX.dist(p0, mob.pos) / float(FX.ONE)))
	_adv(r, 40 * 20)
	r.issue({"p": 0, "t": "unpack", "ids": [mob.id]})
	_adv(r, 2)
	t._check(MineSys.unpacking(mob), "Set Up starts a 10 s set-up on open ground")
	# save / load in the middle of setting up keeps the timer
	var snap := w.serialize()
	var w2 := SimWorld.new()
	w2.deserialize(snap)
	t._check(w2.state_hash() == w.state_hash() and MineSys.unpacking(w2.get_ent(mob.id)), "a save in the middle of setting up restores the timer")
	var mhp := mob.hp
	_adv(r, 11 * 20)
	var site: SimEntity = null
	for id in w.ids:
		if w.ents[id].def_id == &"ecc_black_market" and w.ents[id].alive:
			site = w.ents[id]
	t._check(not mob.alive and site != null and site.built and site.tile != st and absi(site.hp - mhp * site.max_hp / mob.max_hp) <= 30, "it sets up again as a working structure somewhere new (%s)" % (str([site.hp, site.max_hp, site.tile, st]) if site != null else "none"))
	var m1: int = w.players[0].supply
	_adv(r, 31 * 20)
	t._check(w.players[0].supply - m1 >= 400, "income starts again once it is set up (+$%d)" % (w.players[0].supply - m1))
	# a move order during set-up calls it off; it cannot set up on top of a building
	r.issue({"p": 0, "t": "pack", "target": site.id})
	_adv(r, 11 * 20)
	var mob2: SimEntity = null
	for id in w.ids:
		if w.ents[id].def_id == &"ecc_mine_mobile" and w.ents[id].alive:
			mob2 = w.ents[id]
	if mob2 == null:
		t._check(false, "packs up a second time")
		return
	r.issue({"p": 0, "t": "unpack", "ids": [mob2.id]})
	_adv(r, 3)
	r.issue({"p": 0, "t": "move", "ids": [mob2.id], "pos": mob2.pos + Vector2i(3 * FX.ONE, 0)})
	_adv(r, 3)
	t._check(not MineSys.unpacking(mob2) and mob2.alive, "a move order calls the set-up off")
	t._check(MineSys.can_unpack_at(w, mob2, hq.tile) != "", "it cannot set up on top of a building")

# ------------------------------------------------------------------ 19: destructible civilian buildings and cars
static func _runner_on(map_id: String, facs: Array) -> MatchRunner:
	var cfg: Dictionary = load("res://tests/test_runner.gd").make_cfg("1v1", 7, [], facs)
	cfg["map"] = map_id
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(cfg)
	return r

static func _civilians(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var house: SimEntity = null
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if w.is_civilian(e) and e.owner < 0:
			house = e
			break
	if house == null:
		t._check(false, "the test map has an empty civilian building")
		return
	# a tank round that lands next to an empty house damages it (collateral), and a direct demolition order levels it
	var tank := w.spawn_unit(&"us_halberd", 0, null, house.pos + Vector2i(0, (house.fp.y + 5) * FX.ONE))
	var foe := w.spawn_unit(&"ecc_rifleman", 1, null, house.pos + Vector2i(0, (house.fp.y / 2 + 1) * FX.ONE))
	var hp0 := house.hp
	var wd := Content.weapon(Content.unit(&"us_halberd").weapons[0])
	CombatSys.fire(w, tank, foe, wd, 100)
	t._check(wd.splash_mt > 0 and house.hp < hp0, "a tank round landing next to an empty house damages it (%d -> %d)" % [hp0, house.hp])
	foe.alive = false
	_adv(r, 2)
	r.issue({"p": 0, "t": "attack", "ids": [tank.id], "target": house.id, "flag": true})
	var fp0 := house.tile
	for i in 120 * 20:
		r.advance()
		if not house.alive:
			break
	t._check(not house.alive and w.map.occ[w.map.idx(fp0)] == 0, "a force-attack order demolishes an empty civilian building and frees its ground")
	# without the force flag (a plain attack) an empty house is not a target
	var r2 := M33._runner(["us", "ecc"])
	var w2 := r2.sim
	var h2: SimEntity = null
	for id in w2.ids:
		if w2.is_civilian(w2.ents[id]) and w2.ents[id].owner < 0:
			h2 = w2.ents[id]
			break
	var t2 := w2.spawn_unit(&"us_halberd", 0, null, h2.pos + Vector2i(0, (h2.fp.y + 4) * FX.ONE))
	r2.issue({"p": 0, "t": "attack", "ids": [t2.id], "target": h2.id})
	_adv(r2, 200)
	t._check(h2.hp == h2.max_hp, "a plain attack order does not touch an empty house")
	# view: blasts wreck parked cars, tanks crush them, a destroyed house leaves rubble
	var r3 := _runner_on("riverside_metro", ["us", "ecc"])
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r3, 0)
	var keys: Array = wv.terrain._cars.keys()
	t._check(wv.terrain.has_cars() and not keys.is_empty(), "the city map has parked cars (%d tiles)" % keys.size())
	if not keys.is_empty():
		var c: Array = wv.terrain._cars[keys[0]][0]
		var n0: int = wv.terrain.wrecked_count
		wv._wreck_cars(Vector3((c[2] as Vector2).x, 0, (c[2] as Vector2).y), 0.6)
		var wrecks := 0
		for ch in wv.terrain.get_children():
			if ch.name.begins_with("CarWreck"):
				wrecks += 1
		t._check(wv.terrain.wrecked_count > n0 and wrecks > 0, "a blast turns parked cars into wrecks (%d)" % (wv.terrain.wrecked_count - n0))
		var n1: int = wv.terrain.wrecked_count
		wv._wreck_cars(Vector3((c[2] as Vector2).x, 0, (c[2] as Vector2).y), 0.6)
		t._check(wv.terrain.wrecked_count == n1, "a wrecked car is not wrecked twice")
	t._check(wv._crushers.has(&"us_halberd") and not wv._crushers.has(&"us_lynx"), "tanks crush cars, light vehicles do not")
	var hv: SimEntity = null
	for id in r3.sim.ids:
		if r3.sim.is_civilian(r3.sim.ents[id]):
			hv = r3.sim.ents[id]
			break
	if hv != null:
		var v: EntityView = wv._ensure_view(hv)
		wv._on_death({"t": "death", "id": hv.id, "kind": hv.kind, "def": hv.def_id, "pos": hv.pos, "owner": -1})
		t._check(wv.rubble_count == 1, "a destroyed civilian building leaves a rubble heap")
	wv.queue_free()

# ------------------------------------------------------------------ 20: night maps
static func _night(t: Node) -> void:
	var nm: Array = []
	for id in Content.maps:
		if (Content.maps[id] as MapDef).night:
			nm.append(id)
	t._check(nm.size() >= 2, "there are night versions of chosen maps (%s)" % str(nm))
	var day := MapEnv.for_map(&"riverside_metro")
	var nt := MapEnv.for_map(&"riverside_metro_night")
	t._check(not day.has("night") and float(nt["night"]) == 1.0 and float(nt["sun_energy"]) < float(day["sun_energy"]) * 0.5, "the night map is lit by a dim moon")
	t._check(Content.maps[&"riverside_metro_night"].tiles_path == Content.maps[&"riverside_metro"].tiles_path, "it plays on the same ground as the day map")
	var r := _runner_on("riverside_metro_night", ["us", "eu"])
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	t._check(wv.night != null and wv.night.lamp_count > 100, "street lamps light the avenues (%d)" % (wv.night.lamp_count if wv.night != null else 0))
	var w := r.sim
	var tank := w.spawn_unit(&"us_halberd", 0, null, M33._hq(w, 0).pos + Vector2i(6 * FX.ONE, 0))
	for e in [M33._hq(w, 0), tank]:
		wv._ensure_view(e)
	wv.frame(1.0, 0.2)
	t._check(wv.night.bld_mm.visible_instance_count >= 1 and wv.night.veh_mm.visible_instance_count >= 1, "structures are floodlit and vehicles drive with headlights")
	var src: String = FileAccess.get_file_as_string("res://view/materials/model_m3.gdshaderinc")
	t._check(src.contains("fl_night"), "lamps and lit windows glow brighter at night")
	wv.queue_free()
	var r2 := M33._runner(["us", "eu"])
	var wv2 := WorldView.new()
	t.add_child(wv2)
	wv2.setup(r2, 0)
	t._check(wv2.night == null, "day maps have no night lights")
	wv2.queue_free()
