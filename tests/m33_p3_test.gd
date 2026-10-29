## M3.3 Phase 3 headless checks (run from m33_test): the moving Russian mine, destructible
## civilians, night maps, ground variety, elevation, new maps and 8-player lobbies.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_mine_moves(t)

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
