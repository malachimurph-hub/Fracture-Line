## M4.2 headless checks (test_runner "m42"): Malachi's 0.4.2 list - damage on impact, transport
## helicopters land before troops board, mass unload, smart targeting, rally points only where
## units come out, build next to supply stashes, mines removed, Supply Stash naming, etc.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_impact(t)
	_landing(t)
	_air_unload(t)
	_mass_unload(t)
	_smart(t)
	_rally(t)
	_build_rules(t)
	_text(t)
	_defs(t)
	_paint(t)
	_tutorial_voices(t)
	_drone_audio(t)
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

# ------------------------------------------------------------------ 6b: land before unloading (no rappel)
static func _air_unload(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var c := _mid(w)
	var heli := w.spawn_unit(&"us_blackhawk", 0, null, FX.tile_center(c))
	var sq := w.spawn_unit(&"us_squad", 0, null, heli.pos)
	heli.air_state = AirSys.PARKED
	t._check(RosterSys.board(w, sq, heli) == 1, "squad boards a landed Black Hawk")
	heli.air_state = AirSys.FLYING
	r.sim.queue_command({"p": 0, "t": "unload", "ids": [heli.id]})
	r.advance()
	t._check(sq.res_id == -heli.id and heli.air_state == AirSys.LANDING, "unload in the air starts a landing; the squad stays aboard")
	var left := -1
	for i in 50:
		r.advance()
		if sq.res_id >= 0:
			left = i
			break
	t._check(left >= 20 and heli.air_state == AirSys.PARKED and sq.res_id == 0 and not w.flying(heli),
		"the squad steps out only after the helicopter has landed (after %d more ticks)" % left)
	heli.air_state = AirSys.PARKED
	t._check(RosterSys.board(w, sq, heli) == 1, "the squad can board again once the helicopter is down")
	r.sim.queue_command({"p": 0, "t": "unload", "ids": [heli.id]})
	r.advance()
	t._check(sq.res_id == 0 and heli.air_state == AirSys.PARKED, "a helicopter already on the ground unloads immediately")
	var wv := FileAccess.get_file_as_string("res://view/world_view.gd")
	t._check(not wv.contains("rappel") and not wv.contains("RAPPEL") and not wv.contains("fast rope") and not wv.contains("fast-rope"),
		"the view has no fast-rope")

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

# ------------------------------------------------------------------ 1, 11, 20: structures
static func _defs(t: Node) -> void:
	# Javelin Foxhole: crews are the barracks infantry views at the Crew markers
	var pit: Node3D = (load("res://view/buildings/eu/javelin_pit.tscn") as PackedScene).instantiate()
	var marks := pit.find_children("Crew*", "Marker3D", true, false)
	t._check(marks.size() == 4 and (marks[0].get_parent().name == "TurretPivot"), "Javelin Foxhole has 4 crew posts on the turning mount")
	var wv := FileAccess.get_file_as_string("res://view/world_view.gd")
	t._check(wv.contains("&\"eu_javelin_pit\": [&\"eu_lancer\", &\"eu_grenadier\"]") and wv.contains("_crew_fire"), "the crews are animated eu_lancer / eu_grenadier infantry views that fire with the pit")
	var lv: Node3D = (load(Content.unit(&"eu_lancer").view_scene) as PackedScene).instantiate()
	t._check(lv is InfantryView and lv.scale == Vector3.ONE and (lv as InfantryView).vat != null, "crew view is the trained soldier model at full size")
	pit.free()
	lv.free()
	# airfields: M4.2 4-hangar change reverted (Malachi) - back to 8 x 8 with 6 parking slots
	for id in [&"us_airfield", &"eu_airstrip", &"ecc_airfield", &"tpla_airfield"]:
		var b: BuildingDef = Content.building(id)
		t._check(b.footprint == Vector2i(8, 8) and b.air_slots == 6, "%s: 8 x 8 with 6 slots" % id)
	# Sayad-3
	var sd: BuildingDef = Content.building(&"tpla_sayad3")
	t._check(sd != null and sd.buildable and sd.faction == &"tpla" and sd.prereqs.has("tpla_workshop") and ResourceLoader.exists(sd.view_scene), "Sayad-3 SAM site: Iran defence, needs a Workshop, has a model")
	var sw := Content.weapon(sd.weapons[0]) if sd != null else null
	var best := 0
	for wid in Content.weapons:
		var o: WeaponDef = Content.weapon(wid)
		if o.targets_air and o.id != sw.id and Content.buildings.values().any(func(bb): return bb.weapons.has(wid)):
			best = maxi(best, o.range_mt)
	t._check(sw != null and sw.targets_air and not sw.targets_ground and sw.range_mt > best, "Sayad-3 outranges every other air-defence structure (%d vs %d)" % [sw.range_mt if sw else 0, best])
	t._check((Content.faction(&"tpla")["buildings"] as Array).has(&"tpla_sayad3") and ResourceLoader.exists("res://ui/icons/tpla_sayad3.png"), "Sayad-3 in Iran's build menu with an icon")
	t._check(TranslationServer.translate("BLD_TPLA_SAYAD3").contains("Sayad-3"), "named by its military designation")
	t._check(FileAccess.get_file_as_string("res://ai/ai_tpla.gd").contains("tpla_sayad3"), "the Iran AI builds one")

# ------------------------------------------------------------------ 10, 12: paint
static func _paint(t: Node) -> void:
	t._check(Palette.paint_for(&"us_blackhawk").get_luminance() < 0.15, "Black Hawk is black")
	t._check(Palette.paint_for(&"us_dozer") == Palette.paint_for(&"us_wraith") or absf(Palette.paint_for(&"us_dozer").s) < 0.1, "US dozer is grey")
	for id in [&"us_wraith", &"us_thunderlance", &"us_harrier"]:
		var c := Palette.paint_for(id)
		t._check(c.s < 0.1 and c.v > 0.35, "%s is grey" % id)
	t._check(Palette.paint_for(&"us_bradley") == Palette.FACTION_PAINT[&"us"], "other US vehicles stay tan")

# ------------------------------------------------------------------ 2, 13: tutorial + new voices
static func _tutorial_voices(t: Node) -> void:
	var cfg := SkirmishConfig.resolve(TutorialDirector.setup_cfg())
	t._check(cfg.get("tutorial", false) and cfg["slots"][0]["kind"] == "human" and cfg["slots"][0]["faction"] == "us" and cfg["slots"][1]["difficulty"] == "easy", "first battle: US player vs easy Iran AI")
	var miss := []
	for st in TutorialDirector.STEPS + ["done"]:
		if TranslationServer.translate("TUT_" + st.to_upper()) == "TUT_" + st.to_upper():
			miss.append("text " + st)
		if not ResourceLoader.exists("res://audio/voice_ai/announcer_us/tut_%s_1.ogg" % st):
			miss.append("voice " + st)
	t._check(miss.is_empty(), "every tutorial step has text and an announcer line %s" % [miss])
	t._check(FileAccess.get_file_as_string("res://ui/settings_screen.gd").contains("TutorialDirector.setup_cfg()") and TranslationServer.translate("SET_REPLAY_TUTORIAL") != "SET_REPLAY_TUTORIAL", "Settings can replay the First Battle")
	var vm := []
	for f in ["us/blackhawk", "eu/h145m", "ecc/hind"]:
		for ev in ["select", "move", "attack", "under_fire", "created"]:
			if not ResourceLoader.exists("res://audio/voice_ai/%s/%s_1.ogg" % [f, ev]):
				vm.append(f + "/" + ev)
	t._check(vm.is_empty(), "transport helicopters have their own voice lines %s" % [vm])

# ------------------------------------------------------------------ drones hum, never talk
static func _drone_audio(t: Node) -> void:
	var ids := []
	for id in Content.units:
		if AudioDirector.is_drone(String(id)):
			ids.append(id)
	t._check(ids.size() >= 3 and not ids.has(&"us_drone_operator"), "scout / explosive drones of every faction are recognised %s" % [ids])
	t._check(ResourceLoader.exists(AudioDirector.DRONE_ACK) and ResourceLoader.exists(AudioDirector.DRONE_LOOP), "drone rev + hum loop exist")
	t._check(FileAccess.get_file_as_string("res://autoload/audio_director.gd").contains("if is_drone(unit_id):"), "drone acknowledgements are the motor rev, not a voice")
	t._check(FileAccess.get_file_as_string("res://view/world_view.gd").contains("DroneHum"), "flying drones play a looping hum")
