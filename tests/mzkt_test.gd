## Bare MZKT-7930, one permanent module, deploy gate, radar sight and the artillery aura.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_data(t)
	_fit(t)
	_deploy(t)
	_radar(t)

static func _data(t: Node) -> void:
	var fac: BuildingDef = Content.building(&"ecc_factory")
	t._check(fac.produces.has("ecc_mzkt"), "the factory builds the bare MZKT")
	t._check(not fac.produces.has("ecc_mzkt_aa") and not fac.produces.has("ecc_mzkt_radar") and not fac.produces.has("ecc_mzkt_missile"), "the three modules are not factory units")
	var hull := Content.unit(&"ecc_mzkt")
	t._check(hull.weapons.is_empty() and hull.sight == 9 and hull.cost == 1500 and hull.view_scene.ends_with("mzkt_base.tscn"), "the bare truck has no weapon and sight 9")
	var aa := Content.unit(&"ecc_mzkt_aa")
	var gun: WeaponDef = Content.weapon(&"ecc_mzkt_gun")
	var sam: WeaponDef = Content.weapon(&"ecc_mzkt_sam")
	t._check(aa.tags.has("deploy") and aa.tags.has("deploy_aa") and aa.tags.has("pack_move") and gun.targets_air and not gun.targets_ground and sam.targets_air and not sam.targets_ground and sam.range_mt == 16000, "anti-air is deploy-gated and air only, out to 16 tiles")
	var radar := Content.unit(&"ecc_mzkt_radar")
	t._check(radar.detector and radar.sight == 20 and radar.range_aura_radius == 12 and radar.range_aura_pct == 25 and radar.weapons.is_empty(), "the radar sees 20, detects stealth, and buffs artillery 25 percent inside 12")
	var cm := Content.unit(&"ecc_mzkt_missile")
	var wpn: WeaponDef = Content.weapon(&"ecc_mzkt_cm")
	t._check(cm.tags.has("artillery") and cm.tags.has("deploy") and cm.tags.has("pack_move") and wpn.targets_ground and not wpn.targets_air and wpn.range_mt == 18000 and wpn.min_range_mt == 6000, "the cruise missile is an 18-tile ground shot with a 6-tile minimum")
	for key in ["UNIT_ECC_MZKT", "UNIT_ECC_MZKT_AA", "UNIT_ECC_MZKT_RADAR", "UNIT_ECC_MZKT_MISSILE", "CMD_MZKT_AA", "CMD_MZKT_RADAR", "CMD_MZKT_MISSILE"]:
		t._check(TranslationServer.translate(key) != key, "string %s is in the English table" % key)
	for glyph in ["mzkt_aa", "mzkt_radar", "mzkt_missile"]:
		var tex := CmdIcons.of(glyph)
		t._check(tex != null and tex.get_width() == 48, "command icon %s is drawn" % glyph)

static func _fit(t: Node) -> void:
	var r := M33._runner(["ecc", "us"])
	var w: SimWorld = r.sim
	var hq := M33._hq(w, 0)
	w.players[0].supply = 5000
	var truck := w.spawn_unit(&"ecc_mzkt", 0, null, hq.pos + Vector2i(FX.ONE * 4, 0))
	t._check(EccSys.mzkt_reason(w, 0, truck, "aa") == "ecc_ministry", "anti-air stays locked until the Ministry exists")
	t._check(EccSys.mzkt_reason(w, 0, truck, "radar") == "", "radar can be fitted with no Ministry")
	w.players[0].upgrades["ecc_ministry"] = true
	t._check(EccSys.mzkt_reason(w, 0, truck, "aa") == "", "anti-air unlocks once the Ministry is up")
	w.players[0].supply = 100
	t._check(EccSys.mzkt_reason(w, 0, truck, "aa") == "REASON_FUNDS", "a module refuses when the cash is short")
	w.players[0].supply = 5000
	var hp_frac := 0.5
	truck.hp = int(truck.max_hp * hp_frac)
	EccSys.begin_mzkt(w, 0, truck, "aa")
	t._check(truck.aux_def == &"ecc_mzkt_aa" and truck.phase == EccSys.INSTALL_TICKS and w.players[0].supply == 4200, "fitting starts, costs 800, and holds the truck")
	t._check(EccSys.mzkt_reason(w, 0, truck, "radar") != "", "a second module cannot be chosen while the first is fitting")
	var held: Vector2i = truck.pos
	truck.goal = truck.pos + Vector2i(FX.ONE * 6, 0)
	MoveSys.run(w)
	t._check(truck.pos == held, "the truck does not drive during the fit")
	for _i in EccSys.INSTALL_TICKS:
		EccSys.installs(w)
	t._check(truck.def_id == &"ecc_mzkt_aa" and truck.aux_def == &"" and truck.hp == int(round(hp_frac * 760.0)), "the fit is permanent and keeps the hit-point fraction")
	t._check(EccSys.mzkt_reason(w, 0, truck, "missile") == "REASON_OWNED", "a fitted truck cannot take another module")

static func _deploy(t: Node) -> void:
	var r := M33._runner(["ecc", "us"])
	var w: SimWorld = r.sim
	var hq := M33._hq(w, 0)
	var aa := w.spawn_unit(&"ecc_mzkt_aa", 0, null, hq.pos + Vector2i(FX.ONE * 6, 0))
	var jet := w.spawn_unit(&"us_blackhawk", 1, null, aa.pos + Vector2i(0, FX.ONE * 4))
	aa.face = 0
	aa.tface = 0
	aa.still = 10
	aa.firing_tick = -100
	CombatSys._fire_unit(w, aa, jet)
	t._check(aa.firing_tick == -100, "anti-air does not fire before the outriggers finish")
	aa.still = EccSys.DEPLOY_TICKS
	aa.goal = MoveSys.NONE
	aa.moving = false
	CombatSys._fire_unit(w, aa, jet)
	t._check(aa.firing_tick == w.tick, "anti-air fires once it has stood for 8 seconds")
	aa.still = EccSys.DEPLOY_TICKS
	aa.goal = aa.pos + Vector2i(FX.ONE * 8, 0)
	var at: Vector2i = aa.pos
	MoveSys.run(w)
	UsSys.run(w)
	t._check(aa.pos == at and aa.still == EccSys.DEPLOY_TICKS - 1, "a move order packs the jacks before the truck rolls")
	for _i in EccSys.DEPLOY_TICKS - 1:
		MoveSys.run(w)
	t._check(aa.still == 0, "pack takes the same 8 seconds as deploy")

static func _radar(t: Node) -> void:
	var r := M33._runner(["ecc", "us"])
	var w: SimWorld = r.sim
	var hq := M33._hq(w, 0)
	var radar := w.spawn_unit(&"ecc_mzkt_radar", 0, null, hq.pos + Vector2i(FX.ONE * 3, 0))
	radar.still = EccSys.AURA_HALT
	radar.goal = MoveSys.NONE
	radar.moving = false
	var ghost := w.spawn_unit(&"ecc_alfa", 1, null, radar.pos + Vector2i(FX.ONE * 15, 0))
	ghost.firing_tick = -10000
	ghost.last_hit_tick = -10000
	UsSys.run(w)
	var seen := (ghost.stealth_mask & (1 << w.player_team(0))) != 0
	t._check(ghost.stealthy and seen, "the radar reveals a hidden soldier at 15 tiles")
	var far := w.spawn_unit(&"ecc_alfa", 1, null, radar.pos + Vector2i(FX.ONE * 22, 0))
	far.firing_tick = -10000
	far.last_hit_tick = -10000
	UsSys.run(w)
	var far_seen := (far.stealth_mask & (1 << w.player_team(0))) != 0
	t._check(far.stealthy and not far_seen, "a hidden soldier past 20 tiles stays hidden")
	var gun := w.spawn_unit(&"ecc_msta", 0, null, radar.pos + Vector2i(FX.ONE * 8, FX.ONE * 2))
	var base: int = Content.weapon(&"ecc_152mm").range_mt
	t._check(EccSys.range_mt(w, gun, base) == base * 5 / 4, "halted radar gives artillery +25 percent range")
	var other := w.spawn_unit(&"ecc_mzkt_radar", 0, null, gun.pos + Vector2i(FX.ONE, 0))
	other.still = EccSys.AURA_HALT
	other.goal = MoveSys.NONE
	t._check(EccSys.range_mt(w, gun, base) == base * 5 / 4, "a second radar does not stack the bonus")
	radar.moving = true
	other.moving = true
	t._check(EccSys.range_mt(w, gun, base) == base, "the aura drops as soon as the radar moves")
	var aa := w.spawn_unit(&"ecc_mzkt_aa", 0, null, radar.pos)
	t._check(EccSys.range_mt(w, aa, 16000) == 16000, "anti-air is not artillery, so the aura does not extend it")
