## M3.7 headless checks (test_runner "m37"): Malachi's balance update - squad spread, one Iran
## power plant, light-tan US paint, no foxholes, stronger base defences, artillery splash on
## infantry, lighter squads.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	await _squad_spread(t)
	_iran_power(t)
	_paint(t)
	_no_foxhole(t)
	_defences(t)
	_artillery_splash(t)
	_squad_hp(t)

static func _frames(t: Node, n: int) -> void:
	for i in n:
		await t.get_tree().process_frame

static func _min_gap(f: PackedVector3Array) -> float:
	var g := 99.0
	for i in f.size():
		for j in i:
			g = minf(g, Vector2(f[i].x - f[j].x, f[i].z - f[j].z).length())
	return g

static func _extent(f: PackedVector3Array) -> float:
	var e := 0.0
	for p in f:
		e = maxf(e, Vector2(p.x, p.z).length())
	return e

# ------------------------------------------------------------------ 1 squad spread
static func _squad_spread(t: Node) -> void:
	for sid in [&"us_squad", &"eu_squad", &"tpla_squad", &"ecc_squad"]:
		var ps := load(Content.unit(sid).view_scene) as PackedScene
		var raw: InfantryView = ps.instantiate()
		var old_f: PackedVector3Array = raw.formation.duplicate()
		raw.free()
		var v: InfantryView = ps.instantiate()
		t.add_child(v)
		await _frames(t, 1)
		var f1: PackedVector3Array = v.formation.duplicate()
		t._check(_extent(f1) > _extent(old_f) * 1.4 and _min_gap(f1) >= InfantryView.MIN_GAP - 0.001,
			"%s: wider spread (%.2f -> %.2f), no two soldiers closer than %.2f (%.2f)" % [sid, _extent(old_f), _extent(f1), InfantryView.MIN_GAP, _min_gap(f1)])
		# walk, then stop: the soldiers scatter to a new loose spread
		v._goal_form = v._base_form.duplicate()
		v._was_moving = true
		v._speed = 0.0
		v._last_pos = v.global_position
		for k in 40:
			v._process(0.05)
		var f2: PackedVector3Array = v.formation.duplicate()
		var moved := 0
		for i in f2.size():
			if f2[i].distance_to(v._base_form[i]) > 0.01:
				moved += 1
		t._check(moved >= 3 and _min_gap(f2) >= InfantryView.MIN_GAP - 0.03, "%s: stopping scatters the soldiers off their slots (%d moved, gap %.2f)" % [sid, moved, _min_gap(f2)])
		v.queue_free()
	await _frames(t, 1)

# ------------------------------------------------------------------ 2 one Iran power plant
static func _iran_power(t: Node) -> void:
	var order: Array = Content.faction(&"tpla")["buildings"]
	var cc := Content.building(&"tpla_cc_plant")
	t._check(order.has(&"tpla_cc_plant") and not order.has(&"tpla_gas_plant") and Content.RETIRED_BUILDINGS.has(&"tpla_gas_plant"), "Iran builds one power plant (Gas Processing Plant); the Gas Turbine Plant is retired")
	t._check(cc.cost == 800 and cc.power == 10 and cc.prereqs.is_empty(), "Gas Processing Plant: $800, +10 power, no prerequisite")
	t._check(Content.building(&"tpla_gas_plant") != null, "the old Gas Turbine Plant def still loads (old saves)")
	var r := M33._runner(["tpla", "ecc"])
	var ai := AITpla.new()
	ai.init(r, 0, "normal", &"tpla_scrapjack")
	r.sim.players[0].supply = 5000
	var nb: StringName = ai._next_building()
	t._check(nb != &"tpla_gas_plant", "the Iran AI never picks the Gas Turbine Plant (%s)" % nb)
	var src := FileAccess.get_file_as_string("res://ai/ai_tpla.gd")
	t._check(not src.contains("tpla_gas_plant"), "the Iran AI build planner only knows the Gas Processing Plant")

# ------------------------------------------------------------------ 3 US light tan
static func _paint(t: Node) -> void:
	var c: Color = Palette.FACTION_PAINT[&"us"]
	t._check(c.get_luminance() > Color("#a08a68").get_luminance() + 0.1 and c.r > c.b, "US vehicles: light tan (%s, lighter than the FDE #a08a68)" % c.to_html(false))

# ------------------------------------------------------------------ 4 no foxholes
static func _no_foxhole(t: Node) -> void:
	var hud := FileAccess.get_file_as_string("res://ui/hud/hud.gd")
	var cmd := FileAccess.get_file_as_string("res://sim/systems/command_sys.gd")
	t._check(not hud.contains("CMD_DIG") and not cmd.contains("\"dig\""), "no Dig foxhole button or command")
	t._check(TranslationServer.translate("CMD_DIG") == "CMD_DIG" and not TranslationServer.translate("UNIT_US_SQUAD_DESC").contains("foxhole"), "no foxhole strings")
	t._check(SimWorld.SQUAD_DMG_PCT == 67, "squads keep their +50 % damage resistance")

# ------------------------------------------------------------------ 5 base defences
const DEF_OLD := {&"eu_bunker_cannon": 40, &"tpla_tunnel_mg": 15, &"eu_gatling": 14, &"eu_gatling_gnd": 7,
	&"tpla_wasp_missile": 30, &"tpla_wasp_gnd": 14, &"us_sam": 15, &"us_patriot_gnd": 9, &"us_firebase_gun": 90,
	&"ecc_silo_missile": 240, &"ecc_zak30": 14, &"ecc_zak30_gnd": 7}
const AA_GND := {&"eu_gatling_gnd": &"quad", &"tpla_wasp_gnd": &"anti_tank", &"us_patriot_gnd": &"hmg", &"ecc_zak30_gnd": &"quad"}
static func _defences(t: Node) -> void:
	var ok := true
	var info := []
	for wid in DEF_OLD:
		var wd := Content.weapon(wid)
		var k: float = float(wd.damage) / float(DEF_OLD[wid])
		ok = ok and k >= 1.5 and k <= 1.75
		info.append("%s %d->%d" % [wid, DEF_OLD[wid], wd.damage])
	t._check(ok, "every base defence weapon hits ~60 %% harder: %s" % ", ".join(info))
	var ok2 := true
	for wid in AA_GND:
		var wd := Content.weapon(wid)
		var old_t: StringName = AA_GND[wid]
		for arm in [&"light", &"heavy"]:
			var before: float = DEF_OLD[wid] * Content.combat.mult(old_t, arm)
			var after: float = wd.damage * Content.combat.mult(wd.damage_type, arm)
			ok2 = ok2 and after >= before * 2.0
	t._check(ok2 and Content.combat.mult(&"aa_ground", &"air") == 0, "anti-air sites' ground guns do far more to vehicles (aa_ground: light %d %%, heavy %d %%)" % [Content.combat.mult(&"aa_ground", &"light"), Content.combat.mult(&"aa_ground", &"heavy")])

# ------------------------------------------------------------------ 6 artillery splash on infantry
static func _artillery_splash(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := Vector2i(w.map.w / 2, w.map.h / 2)
	var gun := w.spawn_unit(&"us_longreach", 0, null, FX.tile_center(c + Vector2i(-10, 0)))
	var tgt := w.spawn_unit(&"ecc_squad", 1, null, FX.tile_center(c))
	tgt.pos = FX.tile_center(c)
	var near := w.spawn_unit(&"ecc_squad", 1, null, FX.tile_center(c))
	var wd := Content.weapon(&"us_howitzer")
	var r_fx := FX.mt_to_fx(wd.splash_mt)
	# a squad whose centre is just outside the blast but whose body is inside
	near.pos = tgt.pos + Vector2i(r_fx + near.radius / 2, 0)
	var single := w.spawn_unit(&"ecc_rifleman", 1, null, FX.tile_center(c))
	single.pos = tgt.pos + Vector2i(0, r_fx * 9 / 10)
	w.rebuild_spatial()   # the spatial grid picks the units up
	var h_near := near.hp
	var h_single := single.hp
	var sc := wd.scatter_mt
	wd.scatter_mt = 0
	CombatSys.fire(w, gun, tgt, wd, 100)
	wd.scatter_mt = sc
	var exp_single := wd.damage * CombatSys.splash_mult(wd, &"infantry") / 100 * (100 - CombatSys.ARTY_INF_FALLOFF * 9 / 10) / 100
	t._check(near.hp < h_near, "artillery splash catches a squad standing at the edge of the blast (%d -> %d)" % [h_near, near.hp])
	t._check(h_single - single.hp >= mini(exp_single - 2, h_single), "a rifleman near the rim takes most of the blast (%d, expect ~%d)" % [h_single - single.hp, exp_single])

# ------------------------------------------------------------------ 7 squad HP
static func _squad_hp(t: Node) -> void:
	var old := {&"us_squad": 660, &"eu_squad": 640, &"tpla_squad": 560, &"ecc_squad": 660}
	var ok := true
	var info := []
	for sid in old:
		var hp := Content.unit(sid).max_hp
		var cut: float = 1.0 - float(hp) / float(old[sid])
		ok = ok and cut >= 0.3 and cut <= 0.35
		info.append("%s %d->%d" % [sid, old[sid], hp])
	t._check(ok, "squads have about a third less health: %s" % ", ".join(info))
