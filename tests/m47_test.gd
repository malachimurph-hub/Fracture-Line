## Russia tech tree: conscripts, FSB GRU, armour, artillery, towers, reactive armour, Red Dawn, hacks.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_tree(t)
	_squad(t)
	_special(t)
	_vehicles(t)
	_research(t)
	_sim(t)
	_meshes(t)
	_voices(t)
	_text(t)

static func _tree(t: Node) -> void:
	t._check(Content.errors.is_empty(), "content loaded (%s)" % str(Content.errors))
	var units: Array = Content.faction(&"ecc")["units"]
	var blds: Array = Content.faction(&"ecc")["buildings"]
	t._check(not units.has(&"ecc_infiltrator") and not units.has(&"ecc_saboteur"), "Infiltrator and Saboteur are off the roster")
	t._check(units.has(&"ecc_drone_operator") and Content.building(&"ecc_barracks").produces.has("ecc_drone_operator"), "the Drone Operator stays at the Barracks")
	t._check(Content.RETIRED_UNITS.has(&"ecc_infiltrator") and Content.RETIRED_UNITS.has(&"ecc_saboteur"), "both retired defs still load for old saves")
	t._check(blds.has(&"ecc_fsb") and Content.building(&"ecc_fsb").prereqs.has("ecc_ministry") and Content.building(&"ecc_fsb").cost == 4200, "FSB GRU is tier 3 and needs the Ministry")
	var bar: BuildingDef = Content.building(&"ecc_barracks")
	t._check(bar.produces.has("ecc_squad") and not bar.produces.has("ecc_infiltrator") and not bar.produces.has("ecc_saboteur"), "Barracks trains conscripts only, plus the operator")
	var fac: BuildingDef = Content.building(&"ecc_factory")
	for id in ["ecc_bmp3", "ecc_bmpt", "ecc_tos", "ecc_iskander", "ecc_t14", "ecc_reaper", "ecc_zeus", "ecc_up_tower_bal", "ecc_up_era"]:
		t._check(fac.produces.has(id), "factory menu includes %s" % id)
	var air: BuildingDef = Content.building(&"ecc_airfield")
	t._check(air.produces.has("ecc_mi8") and air.produces.has("ecc_ka52"), "Airfield builds the Mi-8 and keeps the Ka-52")
	var fsb: BuildingDef = Content.building(&"ecc_fsb")
	t._check(fsb.produces.has("ecc_alfa") and fsb.produces.has("ecc_spetsnaz") and fsb.produces.has("ecc_vdv"), "FSB GRU trains Alfa, Spetsnaz and VDV")
	var minis: BuildingDef = Content.building(&"ecc_ministry")
	t._check(minis.produces.has("ecc_up_red_dawn") and minis.produces.has("ecc_up_reaper") and minis.produces.has("ecc_up_tower_at") and minis.produces.has("ecc_up_tower_aa"), "Ministry researches towers, Red Dawn and the Grim Reaper")
	var hub: BuildingDef = Content.building(&"ecc_black_market")
	t._check(hub.cost == 6500 and hub.prereqs.has("ecc_ministry") and hub.power < 0 and hub.income_amount == 0 and not hub.tags.has("mobile"), "Black Market stays $6500, draws power, and is not a mine")
	for id in ["ecc_up_hack_power", "ecc_up_hack_radar", "ecc_up_hack_funds", "ecc_up_hack_hijack"]:
		t._check(hub.produces.has(id), "Black Market researches %s" % id)
	var ai: AIPersonalityDef = Content.ai_personalities[&"ecc_steppe"]
	t._check(ai.opening.has("ecc_ministry") and ai.unit_weights.has("ecc_t14") and ai.unit_weights.has("ecc_up_era") and not ai.unit_weights.has("ecc_infiltrator"), "Russian AI opens through the Ministry and trains the new kit")
	t._check(TranslationServer.translate("UNIT_ECC_ZEUS") == "Shilka", "the ZSU-23-4 is named Shilka")

static func _squad(t: Node) -> void:
	var ms := Content.squad_members(&"ecc_squad")
	var rifles := 0
	var rpg := 0
	var mg := 0
	for m in ms:
		var w: String = m[1][0]
		if w == "ecc_ak47":
			rifles += 1
		elif w == "ecc_rpg7":
			rpg += 1
		elif w == "ecc_pkm":
			mg += 1
	t._check(ms.size() == 6 and rifles == 3 and rpg == 2 and mg == 1, "conscripts are 3 AK-47, 2 RPG-7, 1 PKM")
	var ud := Content.unit(&"ecc_squad")
	t._check(ud.weapons.has("ecc_ak47") and not ud.weapons.has("ecc_gp25") and ud.max_hp == 500 and ud.cost == 1000, "the squad stats dropped the grenadier")

static func _special(t: Node) -> void:
	var alfa := Content.unit(&"ecc_alfa")
	var sp := Content.unit(&"ecc_spetsnaz")
	var vdv := Content.unit(&"ecc_vdv")
	t._check(alfa.tags.has("capturer") and alfa.tags.has("stealth_combat") and not Content.is_squad(alfa.id), "FSB Alfa is one hidden soldier who can capture")
	t._check(Content.weapon(&"ecc_asval").damage > Content.weapon(&"ecc_ak47").damage, "the AS Val hits harder than the AK-47")
	t._check(Content.is_squad(sp.id) and Content.squad_members(sp.id).size() == 3 and sp.speed_mtps > Content.unit(&"ecc_squad").speed_mtps and sp.tags.has("stealth_combat"), "Spetsnaz is a faster hidden trio")
	var vss := Content.weapon(&"ecc_vss")
	t._check(vss.clip_size == 10 and vss.aim_deg <= 6 and Content.weapon(&"ecc_ak74u").range_mt < vss.range_mt, "the VSS is a scoped single-fire rifle; the AK-74U is shorter")
	t._check(Content.squad_members(vdv.id).size() == 2 and vdv.tags.has("parachute") and vdv.tags.has("stealth_combat") and vdv.weapons.has("ecc_gp25"), "VDV is a hidden pair with grenade launchers, marked to parachute later")

static func _vehicles(t: Node) -> void:
	var bmp := Content.unit(&"ecc_bmp3")
	var brad := Content.unit(&"us_bradley")
	t._check(bmp.transport_capacity == 6 and bmp.speed_mtps < brad.speed_mtps and bmp.max_hp > brad.max_hp, "BMP-3 carries a squad, slower and tougher than the Bradley")
	var bmpt := Content.unit(&"ecc_bmpt")
	t._check(bmpt.weapons.has("ecc_bmpt_30") and bmpt.weapons.has("ecc_bmpt_atgm") and Content.weapon(&"ecc_bmpt_30").damage_type == &"autocannon", "BMPT has autocannons and missiles")
	var t14 := Content.unit(&"ecc_t14")
	var t90 := Content.unit(&"ecc_t90")
	t._check(t14.prereqs.has("ecc_ministry") and t14.max_hp > t90.max_hp and Content.weapon(&"ecc_t14_gun").damage > Content.weapon(&"ecc_125mm").damage, "T-14 needs the Ministry and outclasses the T-90M")
	var tos := Content.weapon(&"ecc_tos")
	t._check(tos.range_mt < 5500 and tos.splash_mt >= 1400 and tos.damage_type == &"demolition" and tos.clip_size >= 8, "TOS-1A is a short-range thermobaric salvo")
	var isk := Content.unit(&"ecc_iskander")
	var reap := Content.unit(&"ecc_reaper")
	t._check(isk.cost < reap.cost and isk.tags.has("setup") and not isk.prereqs.has("ecc_up_reaper"), "Iskander is the mid-tier missile truck")
	t._check(reap.prereqs.has("ecc_up_reaper") and reap.tags.has("deploy") and reap.cost >= 5000 and Content.weapon(&"ecc_reaper_mirv").splash_mt > 0, "Grim Reaper is researched, expensive, and must deploy")
	var mi := Content.unit(&"ecc_mi8")
	var hawk := Content.unit(&"us_blackhawk")
	t._check(mi.tags.has("helicopter") and mi.tags.has("transport") and mi.transport_capacity >= 6 and mi.speed_mtps < hawk.speed_mtps and mi.air_slots == 0, "Mi-8 is a slower transport helicopter")

static func _research(t: Node) -> void:
	t._check(Content.unit(&"ecc_up_tower_bal").tags.has("upgrade") and Content.unit(&"ecc_up_tower_at").cost > Content.unit(&"ecc_up_tower_bal").cost, "balanced tower is the cheaper, earlier research")
	t._check(EccSys.TOWER_COST["bal"] < EccSys.TOWER_COST["at"] and EccSys.RED_DAWN_MS == 450000 and EccSys.ERA_KEEP == 60, "fit costs, Red Dawn cooldown and reactive armour percent")
	t._check(int(EccSys.HACKS["power"]["dur"]) < int(EccSys.HACKS["funds"]["dur"]), "the power hack is the short one")

static func _sim(t: Node) -> void:
	var r := M33._runner(["ecc", "us"])
	var w: SimWorld = r.sim
	var hq := M33._hq(w, 0)
	# stealth until engaged
	var alfa := w.spawn_unit(&"ecc_alfa", 0, null, hq.pos + Vector2i(FX.ONE * 6, 0))
	UsSys.run(w)
	t._check(alfa.stealthy, "FSB Alfa is hidden before the fight")
	alfa.firing_tick = w.tick
	UsSys.run(w)
	t._check(not alfa.stealthy, "shooting reveals him")
	alfa.firing_tick = w.tick - UsSys.FIRE_REVEAL_TICKS - 1
	alfa.last_hit_tick = w.tick - UsSys.FIRE_REVEAL_TICKS - 1
	UsSys.run(w)
	t._check(alfa.stealthy, "he hides again once the fight is over")
	# reactive armour
	var tank := w.spawn_unit(&"ecc_t90", 0, null, hq.pos + Vector2i(FX.ONE * 8, 2))
	var foe := w.spawn_unit(&"us_halberd", 1, null, tank.pos + Vector2i(0, FX.ONE * 4))
	var gun: WeaponDef = Content.weapon(&"us_tank_gun")
	var keep_s := gun.scatter_mt
	var keep_i := gun.scatter_inf_mt
	gun.scatter_mt = 0
	gun.scatter_inf_mt = 0
	var hp0 := tank.hp
	CombatSys.fire(w, foe, tank, gun, 100)
	CombatSys.land_all(w)
	var raw := hp0 - tank.hp
	tank.hp = tank.max_hp
	w.players[0].upgrades["ecc_up_era"] = true
	CombatSys.fire(w, foe, tank, gun, 100)
	CombatSys.land_all(w)
	var cut := tank.max_hp - tank.hp
	gun.scatter_mt = keep_s
	gun.scatter_inf_mt = keep_i
	t._check(raw > 10 and cut == maxi(1, raw * EccSys.ERA_KEEP / 100), "reactive armour keeps 60%% of a cannon hit (%d -> %d)" % [raw, cut])
	# tower
	w._place_building(Content.building(&"ecc_power"), 0, hq.tile + Vector2i(6, 0), 0, true)
	var bar := w._place_building(Content.building(&"ecc_barracks"), 0, hq.tile + Vector2i(-6, 0), 0, true)
	PowerSys.recompute_grid(w)
	w.players[0].upgrades["ecc_up_tower_bal"] = true
	w.players[0].supply = 5000
	r.issue({"p": 0, "t": "tower", "target": bar.id, "def": "bal"})
	var grunt := w.spawn_unit(&"us_squad", 1, null, bar.pos + Vector2i(FX.ONE * 3, 0))
	var g0 := grunt.hp
	M33._ticks(r, 40)
	t._check(EccSys.tower_of(bar) == "bal" and grunt.hp < g0, "a fitted balanced tower shoots (%d -> %d)" % [g0, grunt.hp])
	# Red Dawn
	var ministry := w._place_building(Content.building(&"ecc_ministry"), 0, hq.tile + Vector2i(0, 8), 0, true)
	PowerSys.recompute_grid(w)
	w.players[0].upgrades["ecc_up_red_dawn"] = true
	var before := 0
	for id in w.ids:
		if w.ents[id].def_id == &"ecc_squad" and w.ents[id].alive:
			before += 1
	r.issue({"p": 0, "t": "red_dawn", "ids": [ministry.id], "pos": hq.pos + Vector2i(FX.ONE * 10, FX.ONE * 4)})
	r.advance()
	var after := 0
	for id in w.ids:
		if w.ents[id].def_id == &"ecc_squad" and w.ents[id].alive and w.ents[id].owner == 0:
			after += 1
	t._check(after >= before + EccSys.RED_DAWN_SQUADS and EccSys.ready_in(w, 0, "ecc_red_dawn") > 4000, "Red Dawn drops conscripts and then waits")
	# hacks
	var hub := w._place_building(Content.building(&"ecc_black_market"), 0, hq.tile + Vector2i(8, 8), 0, true)
	var foe_hq := M33._hq(w, 1)
	w._place_building(Content.building(&"us_substation"), 1, foe_hq.tile + Vector2i(6, 0), 0, true)
	w._place_building(Content.building(&"us_barracks"), 1, foe_hq.tile + Vector2i(-6, 0), 0, true)
	PowerSys.recompute_grid(w)
	var prod: int = w.players[1].power_prod
	w.players[0].upgrades["ecc_up_hack_power"] = true
	w.players[0].upgrades["ecc_up_hack_funds"] = true
	w.players[0].upgrades["ecc_up_hack_radar"] = true
	w.players[0].upgrades["ecc_up_hack_hijack"] = true
	w.players[1].supply = 800
	var mine: int = w.players[0].supply
	r.issue({"p": 0, "t": "hack", "ids": [hub.id], "target": foe_hq.id, "def": "power"})
	r.advance()
	t._check(prod > 0 and w.players[1].power_prod == 0 and w.players[1].low_power, "grid shutdown takes the enemy power offline")
	w.players[1].power_down_until = w.tick
	PowerSys.recompute_grid(w)
	t._check(w.players[1].power_prod == prod, "power comes back when the hack ends")
	r.issue({"p": 0, "t": "hack", "ids": [hub.id], "target": foe_hq.id, "def": "funds"})
	var spins := 0
	while w.players[1].supply == 800 and spins < 25:
		r.advance()
		spins += 1
	t._check(w.players[1].supply == 770 and w.players[0].supply >= mine + 30, "funds siphon moves $30 a second")
	r.issue({"p": 0, "t": "hack", "ids": [hub.id], "target": foe_hq.id, "def": "radar"})
	r.advance()
	t._check(w.players[1].radar_until > w.tick, "radar blackout is timed on the enemy")
	var truck := w.spawn_unit(&"us_lynx", 1, null, foe_hq.pos + Vector2i(FX.ONE * 3, 0))
	r.issue({"p": 0, "t": "hack", "ids": [hub.id], "target": truck.id, "def": "hijack"})
	r.advance()
	t._check(truck.owner == 0 and truck.team == w.player_team(0), "hijack takes one enemy vehicle")
	var soldier := w.spawn_unit(&"us_squad", 1, null, foe_hq.pos + Vector2i(-FX.ONE * 3, 0))
	var owner := soldier.owner
	r.issue({"p": 0, "t": "hack", "ids": [hub.id], "target": soldier.id, "def": "hijack"})
	t._check(soldier.owner == owner, "hijack does not take infantry")
	# Grim Reaper deploy and split
	var tel := w.spawn_unit(&"ecc_reaper", 0, null, hq.pos + Vector2i(-FX.ONE * 4, -FX.ONE * 4))
	var victim := w.spawn_unit(&"us_squad", 1, null, tel.pos + Vector2i(0, FX.ONE * 10))
	tel.tface = FX.iatan2(victim.pos.x - tel.pos.x, victim.pos.y - tel.pos.y)
	CombatSys._ensure(tel, Content.unit(tel.def_id))
	w.flight.clear()
	tel.still = 0
	CombatSys._fire_unit(w, tel, victim)
	t._check(w.flight.is_empty(), "the Grim Reaper cannot fire until the outriggers plant")
	tel.still = EccSys.DEPLOY_TICKS
	CombatSys._fire_unit(w, tel, victim)
	t._check(w.flight.size() == 1 and int(w.flight[0].get("mirv", 0)) == 1, "once planted it launches one splitting missile")
	CombatSys.land_all(w)
	t._check(w.flight.size() == EccSys.MIRV, "the missile breaks into six warheads")
	w.rebuild_spatial()
	var vh := victim.hp
	CombatSys.land_all(w)
	t._check(not victim.alive or victim.hp < vh, "the warheads hit the squad underneath")

static func _tris(path: String) -> int:
	var n: Node = load(path).instantiate()
	var tris := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null and m.get_surface_count() > 0:
			tris += m.surface_get_array_index_len(0) / 3
	n.free()
	return tris

static func _meshes(t: Node) -> void:
	var floors := {
		"res://view/units/ecc/bmp3.tscn": 1400, "res://view/units/ecc/bmpt.tscn": 1400,
		"res://view/units/ecc/t14.tscn": 1600, "res://view/units/ecc/tos.tscn": 1400,
		"res://view/units/ecc/iskander.tscn": 1600, "res://view/units/ecc/reaper.tscn": 1800,
		"res://view/units/ecc/mi8.tscn": 900,
		"res://view/buildings/ecc/fsb.tscn": 800, "res://view/buildings/ecc/black_market.tscn": 1000,
		"res://view/buildings/ecc/tower_bal.tscn": 80,
	}
	for path in floors:
		var n := _tris(path)
		t._check(n >= int(floors[path]), "%s is a fitted model (%d tris)" % [path.get_file(), n])
	var reaper: Node = load("res://view/units/ecc/reaper.tscn").instantiate()
	var mi8: Node = load("res://view/units/ecc/mi8.tscn").instantiate()
	t._check(reaper.find_child("Outriggers", true, false) != null and mi8.find_child("Rotor", true, false) != null, "Grim Reaper has outriggers and the Mi-8 has a rotor")
	reaper.free()
	mi8.free()
	var t90: Node = load("res://view/units/ecc/t90.tscn").instantiate()
	var hidden := true
	var blocks := 0
	for n in t90.find_children("ActiveArmor", "MeshInstance3D", true, false):
		blocks += 1
		hidden = hidden and not (n as Node3D).visible
	t._check(blocks == 2 and hidden, "T-90M reactive blocks stay hidden until the research shows them")
	t90.free()
	var fsb: Node = load("res://view/buildings/ecc/fsb.tscn").instantiate()
	t._check(fsb.find_child("TowerMount", true, false) != null, "FSB GRU has a tower mount")
	fsb.free()

static func _voices(t: Node) -> void:
	var units: Dictionary = AudioDirector.manifest["factions"]["ecc"]["units"]
	for pair in [["ecc_alfa", "infiltrator"], ["ecc_spetsnaz", "infiltrator"], ["ecc_vdv", "rifleman"], ["ecc_bmp3", "btr"], ["ecc_t14", "t90"], ["ecc_mi8", "ka52"], ["ecc_reaper", "msta"], ["ecc_zeus", "zeus"]]:
		var folder := String(units[pair[0]]["folder"])
		var v: Array = AudioDirector.variants("ecc", folder, "select")
		t._check(folder == pair[1] and not v[0].is_empty() and str(v[0][0]).contains("/ecc/" + folder + "/"), "%s speaks with the male %s bank" % [pair[0], pair[1]])

static func _text(t: Node) -> void:
	var banned := ["Lockheed", "Boeing", "Kalashnikov", "Uralvagonzavod", "Rostec", "EA ", "Zero Hour"]
	for id in [&"ecc_bmp3", &"ecc_bmpt", &"ecc_t14", &"ecc_tos", &"ecc_iskander", &"ecc_reaper", &"ecc_mi8", &"ecc_alfa", &"ecc_fsb", &"ecc_black_market", &"ecc_zeus"]:
		var d = Content.unit(id) if Content.unit(id) != null else Content.building(id)
		var text := TranslationServer.translate(d.name_key) + " " + TranslationServer.translate(d.desc_key)
		t._check(TranslationServer.translate(d.name_key) != d.name_key, "%s has a name" % id)
		for word in banned:
			t._check(not text.contains(word), "%s text has no %s" % [id, word])
