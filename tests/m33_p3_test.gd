## M3.3 Phase 3 headless checks (run from m33_test): the moving Russian mine, destructible
## civilians, night maps, ground variety, elevation, new maps and 8-player lobbies.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_mine_moves(t)
	_civilians(t)
	_night(t)
	_headlights(t)
	_elevation(t)
	_ground_variety(t)
	_new_maps(t)

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

# ------------------------------------------------------------------ 17: elevation
static func _elevation(t: Node) -> void:
	var flat := M33._runner(["us", "eu"])
	var fm := flat.sim.map
	var any_slope := 0
	for v in fm.slope:
		any_slope = maxi(any_slope, v)
	t._check(not fm.has_elev and any_slope == 0, "existing maps stay flat (old saves and replays play the same)")
	var r := _runner_on("harvest_valley", ["us", "tpla"])
	var m := r.sim.map
	var steep := Vector2i(-1, -1)
	for y in m.h:
		for x in m.w:
			if m.slope[y * m.w + x] >= 10 and m.ttype(Vector2i(x, y)) == SimMap.T.GRASS:
				steep = Vector2i(x, y)
	t._check(m.has_elev and steep.x >= 0, "the new maps have real hills (steep tile %s)" % str(steep))
	if steep.x >= 0:
		var base: int = SimMap.SPEED_PCT[SimMap.T.GRASS][1]
		var sp := m.speed_pct(steep, true)
		t._check(sp < base and sp >= base * 80 / 100 and m.speed_pct(steep, false) == SimMap.SPEED_PCT[SimMap.T.GRASS][0],
			"vehicles slow a little on slopes (%d%% of %d%%), infantry do not" % [sp, base])
	var md: MapDef = Content.maps[&"harvest_valley"]
	var hl: Array = md.hills[0]
	var top := m.height_at(float(hl[0]), float(hl[1]))
	t._check(top > 1.5 and absf(m.height_at(float(md.spawns[0].x + 2), float(md.spawns[0].y + 2))) < 0.05, "hilltops stand %.1f m high; the bases stay level" % top)
	var d := MapStore.to_dict(md)
	var back := MapStore.from_dict(d)
	t._check(back != null and back.hills.size() == md.hills.size(), "hills are kept when a map is saved / embedded in a save")
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	t._check(FX.ground == m and FX.to_world(FX.tile_center(Vector2i(int(hl[0]), int(hl[1])))).y > 1.5, "units and buildings stand on the hill (view height follows the ground)")
	var w := r.sim
	var on := Vector2i(int(hl[0]) - 5, int(hl[1]) - 2)
	var bd := Content.building(&"us_barracks")
	var b := w._place_building(bd, 0, on, 0, true)
	wv._ensure_view(b)
	var bv: Node3D = wv.views.get(b.id)
	t._check(bv != null and bv.get_node_or_null("Plinth") != null, "a structure on a slope stands level on a concrete plinth")
	var tank := w.spawn_unit(&"us_halberd", 0, null, FX.tile_center(steep if steep.x >= 0 else on))
	tank.face = FX.ANG / 4
	wv._ensure_view(tank)
	wv.cur[tank.id] = wv._world_pos(tank)
	wv.prev[tank.id] = wv.cur[tank.id]
	for k in 6:
		wv.frame(0.05, 0.5)
	var tv: Node3D = wv.views.get(tank.id)
	t._check(tv != null and (absf(tv.rotation.x) > 0.02 or absf(tv.rotation.z) > 0.02), "vehicles tilt with the slope (pitch %.2f, roll %.2f)" % [tv.rotation.x if tv else 0.0, tv.rotation.z if tv else 0.0])
	t.remove_child(wv)
	t._check(FX.ground == null, "the next screen starts on flat ground")
	wv.free()

# ------------------------------------------------------------------ 22: ground variety
static func _ground_variety(t: Node) -> void:
	for mid in ["twin_ridges", "harvest_valley", "sunfall_basin", "highland_crown"]:
		var md: MapDef = Content.maps[StringName(mid)]
		var bio := FileAccess.get_file_as_string(md.tiles_path.replace(".txt", ".biome.txt"))
		var kinds := []
		for c in ["e", "v", "p", "l", "g", "G", "d", "s"]:
			if bio.contains(c):
				kinds.append(c)
		t._check(bio.contains("v") and bio.contains("p") and kinds.size() >= 5, "%s: %d ground types incl. gravel and pavers (%s)" % [mid, kinds.size(), "".join(kinds)])
	var src := FileAccess.get_file_as_string("res://view/terrain/terrain.gdshader")
	t._check(src.contains("splat_c") and src.contains("pavers"), "the terrain shader blends earth, gravel, pavers and lush grass")

# ------------------------------------------------------------------ 21: 2 / 4 / 6 / 8 player maps
static func _new_maps(t: Node) -> void:
	var want := {"twin_ridges": [2, 128], "harvest_valley": [4, 192], "sunfall_basin": [6, 224], "highland_crown": [8, 256]}
	for mid in want:
		var md: MapDef = Content.maps.get(StringName(mid))
		t._check(md != null and md.spawns.size() == want[mid][0] and md.size.x == want[mid][1] and not md.hills.is_empty() and md.resources.size() >= md.spawns.size() * 2,
			"%s: %d players on %d x %d with hills, %d supply piles" % [mid, md.spawns.size() if md else 0, md.size.x if md else 0, md.size.y if md else 0, md.resources.size() if md else 0])
		t._check(SkirmishConfig.map_ids().has(StringName(mid)), "%s is in the lobby map list" % mid)
	t._check(Palette.COLORS.size() >= 8 and Palette.COLOR_KEYS.size() == Palette.COLORS.size(), "8 player colours")
	var ds := SkirmishConfig.default_setup()
	t._check(ds["slots"].size() == 8 and SkirmishConfig.active(ds).size() == 2, "the lobby has 8 slots (5-8 start closed)")
	var old := ds.duplicate(true)
	old["slots"] = old["slots"].slice(0, 4)
	var nrm := SkirmishConfig.normalize(old)
	var cols := {}
	for s in nrm["slots"]:
		cols[int(s["color"])] = true
	t._check(nrm["slots"].size() == 8 and cols.size() == 8, "a remembered 4-slot lobby opens with 8 slots")
	var cfg := SkirmishConfig.default_setup()
	cfg["map"] = "highland_crown"
	for i in 8:
		cfg["slots"][i]["kind"] = "human" if i == 0 else "ai"
		cfg["slots"][i]["team"] = i
		cfg["slots"][i]["faction"] = ["us", "eu", "tpla", "ecc"][i % 4]
	t._check(SkirmishConfig.validate(cfg) == "", "an 8-player free-for-all on Highland Crown is valid")
	var c6 := cfg.duplicate(true)
	c6["map"] = "sunfall_basin"
	t._check(SkirmishConfig.validate(c6) == "LOBBY_ERR_PLAYERS", "8 players do not fit a 6-player map")
	var c4 := SkirmishConfig.default_setup()
	c4["slots"][1]["spawn"] = 6
	t._check(SkirmishConfig.validate(c4) == "LOBBY_ERR_SPAWN_MAP", "a start position the map does not have is refused")
	var res := SkirmishConfig.resolve(cfg)
	for s in res["slots"]:
		s["kind"] = "ai"
		s["difficulty"] = "medium"
	var sp := {}
	for s in res["slots"]:
		sp[int(s["spawn"])] = true
	t._check(sp.size() == 8, "8 players get 8 different start positions")
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(res)
	var t0 := Time.get_ticks_msec()
	_adv(r, 600)
	var ms := float(Time.get_ticks_msec() - t0) / 600.0
	var hqs := 0
	for pl in r.sim.players.size():
		if r.sim.count_owned(pl, Content.faction(r.sim.players[pl].faction)["hq"]) > 0:
			hqs += 1
	t._check(hqs == 8 and r.ais.size() == 8 and not r.sim.game_over, "8 AIs play Highland Crown for 30 s (%d HQs, %.1f ms per sim tick headless)" % [hqs, ms])
	var blds := 0
	for id in r.sim.ids:
		var e: SimEntity = r.sim.ents[id]
		if e.kind == SimEntity.Kind.BUILDING and e.owner >= 0:
			blds += 1
	t._check(blds > 8, "they start building their bases (%d structures after 30 s)" % blds)
	var vmd := MapStore.to_dict(Content.maps[&"highland_crown"])
	var verr := MapStore.validate(vmd)
	var too_many := false
	for e in verr:
		too_many = too_many or e.begins_with("At most")
	t._check(not too_many, "the Map Builder accepts 8 start positions (opening Highland Crown as a base)")
	for mid in ["twin_ridges", "sunfall_basin"]:
		var r2 := _runner_on(mid, ["tpla", "ecc"])
		_adv(r2, 300)
		t._check(not r2.sim.game_over and r2.sim.players.size() == 2, "%s: a 1v1 runs" % mid)

# ------------------------------------------------------------------ headlights point forward
## Malachi: beams pointed to the rear. Every ground vehicle of every faction, facing four ways,
## must have its beam starting at its front and running along its forward vector; also tilted on a hill.
static func _beam_check(wv: WorldView, w: SimWorld, def: StringName, at: Vector2i, face: int) -> String:
	var u := w.spawn_unit(def, 0, null, FX.tile_center(at))
	u.face = face
	u.dir = FX.dir_of(face)
	wv._ensure_view(u)
	wv.cur[u.id] = wv._world_pos(u)
	wv.prev[u.id] = wv.cur[u.id]
	wv.yaw.erase(u.id)
	for k in 8:
		wv.frame(0.05, 1.0)
	wv._update_night()
	var v: Node3D = wv.views[u.id]
	var fwd := Vector3(float(u.dir.x), 0, float(u.dir.y)).normalized()
	var ends: Array = wv.night.beam_ends
	var best := -1
	var bd := 1e9
	for k in ends.size():
		var d := Vector2(ends[k][0].x - v.position.x, ends[k][0].z - v.position.z).length()
		if d < bd:
			bd = d
			best = k
	var err := ""
	if best < 0 or bd > 4.0:
		err = "%s face %d: no beam at the vehicle" % [def, face]
	else:
		var near_end: Vector3 = ends[best][0]
		var far_end: Vector3 = ends[best][1]
		var run := Vector3(far_end.x - near_end.x, 0, far_end.z - near_end.z).normalized()
		var off := Vector3(near_end.x - v.position.x, 0, near_end.z - v.position.z)
		var hull := Vector3(v.global_transform.basis.z.x, 0, v.global_transform.basis.z.z).normalized()
		if run.dot(fwd) < 0.95 or off.dot(fwd) <= 0.2 or hull.dot(fwd) < 0.95:
			err = "%s face %d: beam run %s, start offset %s, hull %s, forward %s" % [def, face, run, off, hull, fwd]
	w.ents.erase(u.id)
	w.ids.erase(u.id)
	wv.views[u.id].queue_free()
	wv.views.erase(u.id)
	return err

static func _headlights(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://view/env/light_pool.gdshader")
	t._check(src.contains("along_v") and not src.contains("float along = UV.y"), "the beam fades from the lamps outwards (mesh-space, not UV)")
	var r := _runner_on("riverside_metro_night", ["us", "eu"])
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	var w := r.sim
	var bad: Array = []
	var n := 0
	var at := FX.to_tile(M33._hq(w, 0).pos) + Vector2i(10, 0)
	for id in Content.units:
		var ud: UnitDef = Content.units[id]
		if ud.move_layer != &"vehicle" or ud.view_scene == "" or not ResourceLoader.exists(ud.view_scene):
			continue
		for face in [0, FX.ANG / 4, FX.ANG / 2, FX.ANG * 3 / 4]:
			var e := _beam_check(wv, w, id, at, face)
			n += 1
			if e != "":
				bad.append(e)
	t._check(bad.is_empty() and n > 40, "headlights shine forward from the front of every vehicle (%d vehicle / facing checks)%s" % [n, "" if bad.is_empty() else ": " + str(bad.slice(0, 3))])
	t.remove_child(wv)
	wv.free()
	# tilted on a hill (no night map has hills: the lights are set up on a hilly map just for this)
	var r2 := _runner_on("harvest_valley", ["us", "eu"])
	var wv2 := WorldView.new()
	t.add_child(wv2)
	wv2.setup(r2, 0)
	if wv2.night == null:
		wv2.night = NightLights.new()
		wv2.add_child(wv2.night)
		wv2.night.setup(wv2.terrain.fog_texture, Vector2(r2.sim.map.w, r2.sim.map.h))
	var m := r2.sim.map
	var steep := Vector2i(-1, -1)
	for y in m.h:
		for x in m.w:
			if steep.x < 0 and m.slope[y * m.w + x] >= 12 and m.ttype(Vector2i(x, y)) == SimMap.T.GRASS:
				steep = Vector2i(x, y)
	var eh := ""
	for face in [0, FX.ANG / 4, FX.ANG / 2, FX.ANG * 3 / 4]:
		var e2 := _beam_check(wv2, r2.sim, &"us_halberd", steep, face)
		if e2 != "":
			eh = e2
	t._check(eh == "", "on a hillside the beams still point forward from the tilted vehicle %s" % eh)
	t.remove_child(wv2)
	wv2.free()
