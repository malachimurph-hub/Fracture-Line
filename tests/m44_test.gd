## M4.4 headless checks: US tech tree (Sub Station through DARPA / SOCOM / ZEUS).
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_tree(t)
	_power(t)
	_meshes(t)
	_units(t)
	_zeus(t)
	_reaper(t)
	_seal(t)
	_retired(t)
	_others(t)

static func _tree(t: Node) -> void:
	var order: Array = Content.faction(&"us")["buildings"]
	t._check(order[0] == &"us_command" and order[1] == &"us_substation", "US build list opens Headquarters, Sub Station")
	var sub := Content.building(&"us_substation")
	var bar := Content.building(&"us_barracks")
	var dep := Content.building(&"us_supply_center")
	var gar := Content.building(&"us_garage")
	var pen := Content.building(&"us_strategy")
	var air := Content.building(&"us_airfield")
	var dc := Content.building(&"us_drop_zone")
	var darpa := Content.building(&"us_darpa")
	var socom := Content.building(&"us_socom")
	t._check(sub.prereqs.has("us_command") and sub.power == 12 and sub.cost == 1000, "Sub Station: needs HQ, +12 power, $1000")
	t._check(bar.prereqs.has("us_substation") and bar.produces.has("us_squad") and bar.produces.has("us_mk23") and not bar.produces.has("us_jtac") and not bar.produces.has("us_breacher"),
		"Barracks needs a Sub Station and trains the squad and the MK 23 team")
	t._check(dep.prereqs.has("us_barracks") and dep.produces.has("us_supply_truck"), "Supply Depot needs the Barracks and builds supply trucks")
	t._check(Content.building(&"us_firebase").prereqs.has("us_barracks"), "M777A2 needs the Barracks")
	t._check(gar.prereqs.has("us_barracks") and gar.produces.has("us_lynx") and gar.produces.has("us_bradley") and gar.produces.has("us_picket") and not gar.produces.has("us_dozer"),
		"Motor Pool builds the JLTV, Bradley and MAAS")
	t._check(pen.prereqs.has("us_garage") and TranslationServer.translate(pen.name_key) == "Pentagon" and pen.produces.is_empty(), "Strategic Center is now the Pentagon")
	t._check(air.prereqs.has("us_strategy") and air.produces.has("us_littlebird") and air.produces.has("us_f16") and air.produces.has("us_blackhawk"),
		"Airfield needs the Pentagon and builds the AH-6, F-16 and Black Hawk")
	t._check(Content.building(&"us_patriot").prereqs.has("us_strategy") and Content.unit(&"us_halberd").prereqs.has("us_strategy") and Content.unit(&"us_longreach").prereqs.has("us_strategy"),
		"Pentagon unlocks the LPWS, M1A3 and M109A7")
	t._check(dc.prereqs.has("us_strategy") and darpa.cost == 5000 and darpa.prereqs.has("us_drop_zone") and socom.cost == 4500 and socom.prereqs.has("us_drop_zone"),
		"Data Center unlocks DARPA ($5000) and SOCOM ($4500)")
	t._check(darpa.produces.has("us_up_aero") and darpa.produces.has("us_up_robotics") and darpa.produces.has("us_up_nuclear") and darpa.produces.has("us_up_zeus"),
		"DARPA's menu is the four research projects")
	t._check(socom.produces.has("us_sniper") and socom.produces.has("us_green_beret") and socom.produces.has("us_seal") and socom.produces.has("us_jtac"),
		"SOCOM trains the sniper, Green Beret, SEAL and JTAC")
	var bot := Content.building(&"us_robotics")
	t._check(bot.cost == 3800 and bot.prereqs.has("us_up_robotics") and bot.produces.has("us_ripsaw"), "Robotics research unlocks the $3800 plant, which builds the Ripsaw")
	t._check(Content.unit(&"us_reaper").prereqs.has("us_robotics") and air.produces.has("us_reaper") and Content.unit(&"us_drone_operator").prereqs.has("us_robotics") and bar.produces.has("us_drone_operator"),
		"the plant unlocks the Reaper at the Airfield and the Drone Operator at the Barracks")
	var nuc := Content.building(&"us_reactor")
	var pad := Content.building(&"us_zeus_launcher")
	var pyl := Content.building(&"us_zeus_pylon")
	t._check(nuc.prereqs.has("us_up_nuclear") and nuc.footprint == Vector2i(4, 4) and nuc.power >= 60 and nuc.cost >= 5000, "Nuclear plant is large, pricey and strong")
	t._check(pad.cost == 8500 and pad.prereqs.has("us_up_zeus") and pyl.cost == 2000 and pyl.prereqs.has("us_up_zeus") and pyl.aux_radius >= 12, "ZEUS launcher $8500 and pylon $2000")
	# power draw grows with cost
	t._check(absi(darpa.power) > absi(socom.power) and absi(socom.power) > absi(bot.power) and absi(pad.power) > absi(darpa.power) and absi(pyl.power) > 0,
		"new buildings draw power in step with their cost")
	var ai: AIPersonalityDef = Content.ai_personalities[&"us_vanguard"]
	t._check(String(ai.opening[0]) == "us_substation" and ai.unit_weights.has("us_f16") and not ai.unit_weights.has("us_harrier") and not ai.unit_weights.has("us_wraith"),
		"US AI opens on the Sub Station and trains the new aircraft")
	for id in [&"us_littlebird", &"us_f16", &"us_yf22", &"us_f35", &"us_b1", &"us_ah64", &"us_reaper", &"us_ripsaw", &"us_mk23", &"us_green_beret", &"us_seal",
			&"us_substation", &"us_darpa", &"us_socom", &"us_robotics", &"us_zeus_launcher", &"us_zeus_pylon"]:
		var d = Content.unit(id) if Content.unit(id) != null else Content.building(id)
		var key: String = d.name_key
		t._check(d != null and ResourceLoader.exists(d.view_scene) and TranslationServer.translate(key) != key and TranslationServer.translate(d.desc_key) != d.desc_key,
			"%s has a model and a name" % id)

static func _power(t: Node) -> void:
	var r := M33._runner(["us", "eu"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	var sub := w._place_building(Content.building(&"us_substation"), 0, hq.tile + Vector2i(8, 0), 0, true)
	PowerSys.recompute_grid(w)
	t._check(w.players[0].power_prod == 17, "HQ + Sub Station make 17 power (%d)" % w.players[0].power_prod)
	w.players[0].upgrades["us_up_nuclear"] = true
	PowerSys.recompute_grid(w)
	t._check(w.players[0].power_prod == 17 and sub.alive, "Nuclear Research leaves the Sub Station producing power (%d)" % w.players[0].power_prod)
	t._check(w.can_place(0, &"us_substation", hq.tile + Vector2i(-10, 0), false) == "", "a new Sub Station can still be started")
	var plant := w._place_building(Content.building(&"us_reactor"), 0, hq.tile + Vector2i(0, 10), 0, true)
	PowerSys.recompute_grid(w)
	var both := 17 + Content.building(&"us_reactor").power
	t._check(plant.alive and w.players[0].power_prod == both, "the Nuclear plant adds power on top of the Sub Station (%d, want %d)" % [w.players[0].power_prod, both])

static func _tris(path: String) -> int:
	var n: Node = load(path).instantiate()
	var tris := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null and m.get_surface_count() > 0:
			tris += m.surface_get_array_index_len(0) / 3
	var scr: bool = n.get_script() != null
	n.free()
	return tris if scr else -tris

static func _meshes(t: Node) -> void:
	var floors := {
		"res://view/units/us/littlebird.tscn": 500, "res://view/units/us/ah64.tscn": 1400,
		"res://view/units/us/reaper.tscn": 800, "res://view/units/us/f16.tscn": 900,
		"res://view/units/us/yf22.tscn": 800, "res://view/units/us/f35.tscn": 800,
		"res://view/units/us/b1.tscn": 1200, "res://view/units/us/ripsaw.tscn": 1400,
		"res://view/buildings/us/substation.tscn": 2500, "res://view/buildings/us/reactor.tscn": 4000,
		"res://view/buildings/us/darpa.tscn": 1400, "res://view/buildings/us/socom.tscn": 1000,
		"res://view/buildings/us/robotics.tscn": 1200, "res://view/buildings/us/zeus_launcher.tscn": 1400,
		"res://view/buildings/us/zeus_pylon.tscn": 1000,
	}
	for path in floors:
		var n := _tris(path)
		t._check(n >= int(floors[path]), "%s is a fitted model (%d tris)" % [path.get_file(), n])
	var gb := FileAccess.get_file_as_string("res://view/units/us/green_beret.tscn")
	var seal := FileAccess.get_file_as_string("res://view/units/us/seal.tscn")
	var mk := FileAccess.get_file_as_string("res://view/units/us/mk23.tscn")
	t._check(gb.contains("us_green_beret.res") and seal.contains("us_seal.res") and mk.contains("us_mk23_gunner.res"), "Green Beret, SEAL and MK 23 use their own soldier bakes")
	t._check(Content.squad_members(&"us_mk23")[0][0] == "us_mk23_gunner" and Content.squad_members(&"us_mk23")[1][0] == "us_mk23_asst", "the MK 23 team is a gunner and an assistant")

static func _units(t: Node) -> void:
	var lb := Content.unit(&"us_littlebird")
	var ah := Content.unit(&"us_ah64")
	var f16 := Content.unit(&"us_f16")
	var yf := Content.unit(&"us_yf22")
	var f35 := Content.unit(&"us_f35")
	var b1 := Content.unit(&"us_b1")
	var rp := Content.unit(&"us_reaper")
	var saw := Content.unit(&"us_ripsaw")
	var m1 := Content.unit(&"us_halberd")
	t._check(lb.speed_mtps > ah.speed_mtps and lb.max_hp < ah.max_hp and lb.tags.has("low_sig") and lb.air_slots == 0, "AH-6 is faster and frailer than the AH-64, and harder to spot")
	t._check(f16.cost < yf.cost and Content.weapon(&"us_f16_aam").damage < Content.weapon(&"us_yf22_aam").damage and yf.tags.has("stealth_air") and yf.prereqs.has("us_up_aero"),
		"F-16 is cheaper and weaker than the stealth YF-22")
	t._check(f35.tags.has("bomber") and f35.air_slots == 2 and b1.air_slots == 4 and b1.prereqs.has("us_up_aero") and Content.weapon(&"us_b1_bay").damage > Content.weapon(&"us_f35_bomb").damage,
		"F-35 is the light bomber; the B-1 is the heavy bomber")
	t._check(Content.weapon(&"us_reaper_strike").damage == Content.weapon(&"us_f35_bomb").damage and rp.tags.has("stealth_defense") and rp.tags.has("reaper") and not rp.tags.has("jet"),
		"Reaper hits as hard as the F-35 and is not a runway jet")
	t._check(saw.tags.has("robot") and saw.radius_mt < m1.radius_mt and saw.speed_mtps > m1.speed_mtps and Content.weapon(&"us_ripsaw_gun").damage * 100 / Content.weapon(&"us_tank_gun").damage == 85,
		"Ripsaw is a smaller, quicker unmanned tank whose gun is 85% of the M1A3")
	t._check(Content.unit(&"us_mk23").tags.has("setup") and Content.squad_members(&"us_mk23").size() == 2, "MK 23 team is two soldiers and must set up")
	var gb := Content.unit(&"us_green_beret")
	t._check(gb.tags.has("capturer") and gb.tags.has("stealth_always") and Content.weapon(&"us_gb_carbine").damage > Content.weapon(&"us_m4").damage, "Green Beret captures, hides, and outshoots a carbine")
	t._check(Content.unit(&"us_seal").tags.has("demo") and Content.unit(&"us_seal").tags.has("stealth_always") and Content.unit(&"us_seal").max_hp > gb.max_hp, "SEAL is tougher stealth infantry that plants charges")
	for id in [&"us_f35", &"us_b1", &"us_ah64", &"us_yf22"]:
		t._check(Content.unit(id).prereqs.has("us_up_aero") and Content.building(&"us_airfield").produces.has(id), "%s is an Advanced Aero aircraft at the Airfield" % id)
	var banned := ["Textron", "Lockheed", "Boeing", "Sikorsky", "General Dynamics", "Northrop"]
	for id in [&"us_ripsaw", &"us_f16", &"us_f35", &"us_yf22", &"us_b1", &"us_ah64", &"us_littlebird", &"us_darpa", &"us_socom"]:
		var d2 = Content.unit(id) if Content.unit(id) != null else Content.building(id)
		var text := TranslationServer.translate(d2.name_key) + " " + TranslationServer.translate(d2.desc_key)
		for word in banned:
			t._check(not text.contains(word), "%s text has no company name (%s)" % [id, word])

static func _zeus(t: Node) -> void:
	var r := M33._runner(["us", "eu"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	w._place_building(Content.building(&"us_reactor"), 0, hq.tile + Vector2i(0, 10), 0, true)
	var pyl := w._place_building(Content.building(&"us_zeus_pylon"), 0, hq.tile + Vector2i(12, 0), 0, true)
	var pad := w._place_building(Content.building(&"us_zeus_launcher"), 0, hq.tile + Vector2i(12, 6), 0, true)
	var foes: Array = []
	for i in 3:
		foes.append(w.spawn_unit(&"eu_squad", 1, null, pyl.pos + Vector2i(FX.ONE * (i - 1) * 3, FX.ONE * 2)))
	PowerSys.recompute_grid(w)
	M33._ticks(r, 90)
	var hurt := 0
	for e in foes:
		if e.hp < e.max_hp:
			hurt += 1
	t._check(hurt >= 2, "one ZEUS salvo spreads across more than one target in the pylon (%d hurt)" % hurt)
	t._check(pad.air_t > w.tick + 400 and pad.phase == 0, "the launcher is recharging after the salvo")

static func _reaper(t: Node) -> void:
	var r := M33._runner(["us", "eu"])
	var w := r.sim
	w.fog.disabled = true
	var hq := M33._hq(w, 0)
	var rp := w.spawn_unit(&"us_reaper", 0, null, hq.pos + Vector2i(FX.ONE * 8, 0))
	var tank := w.spawn_unit(&"eu_leopold", 1, null, rp.pos + Vector2i(FX.ONE * 2, 0))
	var sam := w._place_building(Content.building(&"us_patriot"), 1, FX.to_tile(rp.pos) + Vector2i(2, 2), 0, true)
	# the patriot above is owned by player 1 so it is an enemy defence
	UsSys.run(w)
	t._check(rp.stealthy and (rp.stealth_mask & (1 << tank.team)) != 0, "a base defence detects the Reaper")
	t._check(not OrderSys.valid_target(w, tank, rp), "a tank cannot engage the Reaper")
	t._check(OrderSys.valid_target(w, sam, rp), "the enemy air defence can engage the Reaper")
	# move the defence out of sight and drop the mask source: a fresh reaper with only infantry nearby
	var rp2 := w.spawn_unit(&"us_reaper", 0, null, hq.pos + Vector2i(-FX.ONE * 20, -FX.ONE * 20))
	w.spawn_unit(&"eu_squad", 1, null, rp2.pos + Vector2i(FX.ONE, 0))
	UsSys.run(w)
	t._check(rp2.stealthy and (rp2.stealth_mask & (1 << 1)) == 0, "infantry alone cannot detect the Reaper")

static func _seal(t: Node) -> void:
	var r := M33._runner(["us", "eu"])
	var w := r.sim
	w.fog.disabled = true
	var hq := M33._hq(w, 0)
	var tank := w.spawn_unit(&"eu_leopold", 1, null, hq.pos + Vector2i(FX.ONE * 3, 0))
	var seal := w.spawn_unit(&"us_seal", 0, null, tank.pos + Vector2i(80, 0))
	var before := tank.hp
	r.issue({"p": 0, "t": "attack", "ids": [seal.id], "target": tank.id})
	M33._ticks(r, 90)
	t._check(tank.hp < before - 100, "a SEAL planted a demolition charge on the tank (%d -> %d)" % [before, tank.hp])

static func _retired(t: Node) -> void:
	for id in [&"us_harrier", &"us_wraith", &"us_thunderlance", &"us_breacher"]:
		t._check(Content.RETIRED_UNITS.has(id) and not (Content.faction(&"us")["units"] as Array).has(id), "%s is retired from the US roster" % id)
		t._check(Content.unit(id) != null, "%s def remains for old saves" % id)
	t._check(not Content.building(&"us_airfield").produces.has("us_harrier") and not Content.building(&"us_barracks").produces.has("us_breacher"),
		"Harrier and Breacher are not in a build menu")

static func _others(t: Node) -> void:
	t._check(Content.building(&"eu_motor_pool").produces.has("eu_leopold") and Content.building(&"tpla_chop_shop").produces.has("tpla_scrapback") and Content.building(&"ecc_airfield").produces.has("ecc_su57"),
		"Germany, Iran and Russia production is unchanged")
	t._check(Content.errors.is_empty(), "content validates (%s)" % str(Content.errors))
