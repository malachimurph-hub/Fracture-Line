## M3.3 headless checks (test_runner "m33"): Malachi's M3.3 Phase 1 quick wins.
extends RefCounted

static func _runner(facs: Array) -> MatchRunner:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(load("res://tests/test_runner.gd").make_cfg("1v1", 7, [], facs))
	r.ais.clear()
	return r

static func _hq(w: SimWorld, pid: int) -> SimEntity:
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.owner == pid and e.kind == SimEntity.Kind.BUILDING and Content.building(e.def_id).is_hq:
			return e
	return null

## First free spot for def near `near` (spiral), or (-1, -1).
static func spot(w: SimWorld, pid: int, def_id: StringName, near: Vector2i, skip: int = 0) -> Vector2i:
	var found := 0
	for r in range(3, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var t := near + Vector2i(dx, dy)
				if free_rect(w, t, Content.building(def_id).footprint + Vector2i(2, 2), Vector2i(-1, -1)):
					if found == skip:
						return t
					found += 1
	return Vector2i(-1, -1)

## Footprint (with a 1-tile margin when off = (-1, -1)) is buildable ground with nothing on it.
static func free_rect(w: SimWorld, t: Vector2i, fp: Vector2i, off: Vector2i = Vector2i.ZERO) -> bool:
	for yy in fp.y:
		for xx in fp.x:
			var c := t + off + Vector2i(xx, yy)
			if not w.map.in_bounds(c) or c.x < 1 or c.y < 1 or c.x >= w.map.w - 1 or c.y >= w.map.h - 1:
				return false
			var i := w.map.idx(c)
			if not SimMap.BUILD_OK[w.map.tiles[i]] or w.map.occ[i] != 0 or w.map.nobuild[i] != 0:
				return false
	return true

static func place(w: SimWorld, pid: int, def_id: StringName, near: Vector2i, skip: int = 0) -> SimEntity:
	var t := spot(w, pid, def_id, near, skip)
	return null if t.x < 0 else w._place_building(Content.building(def_id), pid, t, 0, true)

static func run(t: Node) -> void:
	_balance(t)
	_economy(t)
	_germany(t)

# ------------------------------------------------------------------ combat balance
static func _balance(t: Node) -> void:
	var spg := [&"us_longreach", &"ecc_msta", &"eu_thunderhead", &"tpla_blight"]
	for id in spg:
		var d: UnitDef = Content.unit(id)
		t._check(d.turret_dps == 0 and d.tags.has("spg"), "%s: fixed-turret self-propelled howitzer (hull aims)" % id)
	t._check(CombatSys.splash_mult(Content.weapon(&"tpla_rpg"), &"infantry") >= 125, "blast damage on infantry is heavy even from anti-tank rockets")
	for wid in [&"us_tank_gun", &"eu_tank_cannon", &"ecc_125mm", &"tpla_scrap_cannon"]:
		var wd: WeaponDef = Content.weapon(wid)
		t._check(wd.splash_mt >= 900 and Content.combat.mult(wd.damage_type, &"infantry") >= 100, "%s: tank round splashes and hits infantry hard" % wid)
	for wid in [&"us_gbu", &"eu_gbu", &"ecc_kab"]:
		var g: WeaponDef = Content.weapon(wid)
		t._check(g.damage * Content.combat.mult(g.damage_type, &"heavy") / 100 >= 150 and g.damage * Content.combat.mult(g.damage_type, &"structure") / 100 >= 200,
			"%s: light-aircraft bomb hits vehicles and structures harder" % wid)
	# a tank shell landing on a soldier hurts the soldier next to him
	var r := _runner(["us", "eu"])
	var w := r.sim
	var hq := _hq(w, 1)
	var c := FX.tile_center(hq.tile + Vector2i(8, 8))
	var tank := w.spawn_unit(&"us_halberd", 0, null, c - Vector2i(FX.ONE * 5, 0))
	var a := w.spawn_unit(&"eu_grenadier", 1, null, c)
	var b := w.spawn_unit(&"eu_grenadier", 1, null, c + Vector2i(FX.ONE * 2 / 3, 0))
	var hp_b := b.hp
	w.rebuild_spatial()
	var wd2: WeaponDef = Content.weapon(&"us_tank_gun")
	var sc := wd2.scatter_mt
	wd2.scatter_mt = 0
	wd2.scatter_inf_mt = 0
	CombatSys.fire(w, tank, a, wd2, 100)
	wd2.scatter_inf_mt = 300
	wd2.scatter_mt = sc
	t._check(not a.alive or a.hp <= a.max_hp - 100, "a direct tank hit on a soldier does heavy damage (%d of %d left)" % [a.hp, a.max_hp])
	t._check(b.hp < hp_b - 40, "the soldier next to him takes splash damage (%d -> %d)" % [hp_b, b.hp])

# ------------------------------------------------------------------ economy
static func _economy(t: Node) -> void:
	t._check(SimWorld.SUPPLY_CAP == 9999999, "funds cap is $9,999,999")
	t._check(SkirmishConfig.MONEY.max() == 50000 and SkirmishConfig.clamp_money(2000000) == 50000 and SkirmishConfig.clamp_money(10000) == 10000,
		"starting cash choices stop at $50k (an older $2M lobby becomes $50k)")
	var cfg := SkirmishConfig.default_setup()
	cfg["options"]["start_money"] = 1000000
	t._check(int(SkirmishConfig.resolve(cfg)["options"]["start_money"]) == 50000, "a resolved lobby never starts above $50k")
	var exp := {&"us_drop_zone": [500, 60, 3800], &"tpla_bazaar": [185, 60, 2000], &"eu_exchange": [465, 60, 3000], &"ecc_black_market": [400, 30, 6500]}
	for id in exp:
		var d: BuildingDef = Content.building(id)
		t._check(d.income_amount == exp[id][0] and d.income_period_s == exp[id][1] and d.cost == exp[id][2] and d.passive_income == 0,
			"%s (%s): $%d every %d s, costs $%d" % [id, TranslationServer.translate(d.name_key), d.income_amount, d.income_period_s, d.cost])
		var sum := 0
		for s in d.income_period_s * 3:
			sum += EconSys.period_pay(d, 1, s)
		t._check(sum == d.income_amount * 3, "%s pays exactly $%d over 3 periods (%d)" % [id, d.income_amount * 3, sum])
	var dz := Content.building(&"us_drop_zone")
	t._check(dz.power <= -5 and Content.building(&"eu_exchange").power <= -6 and Content.building(&"ecc_black_market").power == 0,
		"Data Center and Automotive Plant use more power; Minerals Mining needs none")
	t._check(EconSys.period_pay(Content.building(&"ecc_black_market"), 1, 29) == 400 and EconSys.period_pay(Content.building(&"ecc_black_market"), 1, 28) == 0,
		"Minerals Mining pays $400 in one lump every 30 s")
	var nuc := Content.building(&"us_reactor")
	t._check(nuc.power == 13 and nuc.cost == 1040 and TranslationServer.translate(nuc.name_key) == "Nuclear Power Plant", "US Nuclear Power Plant: +30% power (13) and +30% price ($1040)")
	t._check(TranslationServer.translate("BLD_TPLA_BAZAAR") == "Oil Derrick" and TranslationServer.translate("BLD_EU_EXCHANGE") == "Automotive Plant" and TranslationServer.translate("BLD_ECC_BLACK_MARKET") == "Minerals Mining",
		"income structures renamed (Oil Derrick, Automotive Plant, Minerals Mining)")
	# in a match: a powered Data Center earns $500 a minute, Minerals Mining $800 even in low power
	var r := _runner(["us", "ecc"])
	var w := r.sim
	var h0 := _hq(w, 0)
	place(w, 0, &"us_reactor", h0.tile)
	place(w, 0, &"us_drop_zone", h0.tile)
	var h1 := _hq(w, 1)
	place(w, 1, &"ecc_black_market", h1.tile)
	place(w, 1, &"ecc_barracks", h1.tile)
	place(w, 1, &"ecc_barracks", h1.tile, 1)
	place(w, 1, &"ecc_factory", h1.tile)
	PowerSys.recompute_grid(w)
	var nb := 0
	for id in w.ids:
		if w.ents[id].kind == SimEntity.Kind.BUILDING and Content.building(w.ents[id].def_id).income_amount > 0:
			nb += 1
	t._check(nb == 2, "test setup: two income structures placed (%d)" % nb)
	_ticks(r, 20 - w.tick % 20)
	var m0: int = w.players[0].supply
	var m1: int = w.players[1].supply
	_ticks(r, 1200)
	t._check(not w.players[0].low_power and w.players[0].supply - m0 == 500, "a powered Data Center earned $%d in a minute (want 500)" % (w.players[0].supply - m0))
	t._check(w.players[1].low_power and w.players[1].supply - m1 == 800, "Minerals Mining earned $%d in a minute in low power (want 800)" % (w.players[1].supply - m1))
	# saves keep it
	var w2 := SimWorld.new()
	w2.deserialize(w.serialize())
	t._check(w2.state_hash() == w.state_hash(), "a save with the new income structures loads identically")

static func _ticks(r: MatchRunner, n: int) -> void:
	for i in n:
		r.advance()

# ------------------------------------------------------------------ Germany
static func _germany(t: Node) -> void:
	t._check(TranslationServer.translate("UNIT_EU_GRENADIER") == "Infanterie" and TranslationServer.translate("UNIT_EU_LANCER") == "Panzerfaust",
		"German infantry: Infanterie and Panzerfaust")
	var made := false
	for bid in Content.buildings:
		made = made or Content.building(bid).produces.has("eu_brennus")
	var used := false
	for pid in Content.ai_personalities:
		used = used or (Content.ai_personalities[pid] as AIPersonalityDef).unit_weights.has("eu_brennus")
	t._check(not made and not Content.faction(&"eu")["units"].has(&"eu_brennus") and not used, "the heavy tank is in no build list, roster or AI")
	var r := _runner(["eu", "us"])
	var w := r.sim
	var hq := _hq(w, 0)
	var hf := w._place_building(Content.building(&"eu_heavy_factory"), 0, spot(w, 0, &"eu_heavy_factory", hq.tile), 0, true)
	place(w, 0, &"eu_signals", hq.tile)
	w.players[0].supply = 50000
	r.issue({"p": 0, "t": "queue", "target": hf.id, "def": "eu_brennus", "n": 1})
	_ticks(r, 2)
	t._check(hf.queue.has(&"eu_brennus"), "an old replay's heavy-tank order still plays back")
	var old := w.spawn_unit(&"eu_brennus", 0, null, FX.tile_center(hq.tile + Vector2i(6, 6)))
	var w2 := SimWorld.new()
	w2.deserialize(w.serialize())
	t._check(w2.get_ent(old.id) != null and w2.state_hash() == w.state_hash(), "a save with a heavy tank loads identically")
