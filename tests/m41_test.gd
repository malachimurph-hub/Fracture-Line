## M4.1 headless checks (test_runner "m41"): Malachi's 0.4.1 list - transport helicopters
## (UH-60 Black Hawk, Mi-24 Hind, H145M), Germany's Guard Tower / Javelin Foxhole / MANTIS
## turret, bigger Crude Oil Reserve, calmer power-plant vapour, floodlights on their mounts,
## no helicopter trails, heavier MG / minigun / explosion sounds, aircraft +35 % speed.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")
const HELIS := [&"us_blackhawk", &"ecc_hind", &"eu_h145m"]
const DEFS := [&"eu_guard_tower", &"eu_javelin_pit", &"eu_mantis"]
## pre-0.4.1 speeds (mt/s) of every non-drone aircraft
const AIR_OLD := {&"eu_kestrel": 3200, &"eu_corvid": 5600, &"tpla_f16": 5200, &"tpla_mirage": 5400, &"tpla_mig29": 5800,
	&"us_thunderlance": 4800, &"us_wraith": 5600, &"us_harrier": 3200, &"ecc_su57": 5800, &"ecc_ka52": 3200, &"ecc_tu160": 4300}

static func run(t: Node) -> void:
	_content(t)
	_air_speed(t)
	_transport(t)
	await _defences(t)
	_ai(t)
	_views(t)
	_sounds(t)
	_vfx_src(t)

static func _ticks(r: MatchRunner, n: int) -> void:
	for i in n:
		r.advance()

# ------------------------------------------------------------------ data, menus, strings, icons
static func _content(t: Node) -> void:
	var fac_of := {&"us_blackhawk": &"us", &"ecc_hind": &"ecc", &"eu_h145m": &"eu"}
	var field := {&"us_blackhawk": &"us_airfield", &"ecc_hind": &"ecc_airfield", &"eu_h145m": &"eu_airstrip"}
	for id in HELIS:
		var d := Content.unit(id)
		var fac: StringName = fac_of[id]
		t._check(d != null and d.move_layer == &"air" and d.tags.has("helicopter") and d.transport_capacity >= 6 and d.loco == &"heli",
			"%s: flying transport helicopter, %d seats (two squads)" % [id, d.transport_capacity if d else 0])
		t._check(Content.building(field[id]).produces.has(id) and (Content.faction(fac)["units"] as Array).has(id), "%s: built at %s and in the build menu" % [id, field[id]])
		t._check(TranslationServer.translate(d.name_key) != d.name_key and TranslationServer.translate(d.desc_key) != d.desc_key and ResourceLoader.exists("res://ui/icons/%s.png" % id) and ResourceLoader.exists(d.view_scene), "%s: name, description, icon and model" % id)
	t._check(TranslationServer.translate("UNIT_EU_H145M") == "H145M" and not TranslationServer.translate("UNIT_EU_H145M_DESC").contains("Airbus") and TranslationServer.translate("UNIT_US_BLACKHAWK").contains("UH-60"), "military designations, no company names")
	# weapons: two door miniguns (very high rate), lighter H145M door guns, Hind 20 mm nose gun
	var mg := Content.weapon(&"us_door_minigun")
	var h1 := Content.weapon(&"eu_h145_mg")
	var hd := Content.weapon(&"ecc_hind_20mm")
	t._check(mg.cooldown_ms <= 80 and mg.vfx == &"tracer_minigun", "Black Hawk miniguns fire very fast (%d ms)" % mg.cooldown_ms)
	t._check(_dps(h1, &"infantry") < _dps(mg, &"infantry") and _dps(h1, &"light") < _dps(mg, &"light"), "H145M door guns are lighter than the Black Hawk's")
	t._check(hd.damage_type == &"autocannon" and Content.unit(&"ecc_hind").weapons.size() == 1, "Hind: one 20 mm nose cannon")
	# roughly comparable: cost x hp x dps within a band
	var vals := []
	for id in HELIS:
		var d := Content.unit(id)
		var w := Content.weapon(StringName(d.weapons[0]))
		vals.append(float(d.max_hp) * (_dps(w, &"infantry") + _dps(w, &"light")) / float(d.cost))
	t._check(vals.max() / vals.min() < 2.2, "the three transports are roughly comparable (value spread %.2f)" % (vals.max() / vals.min()))
	for id in DEFS:
		var b := Content.building(id)
		t._check(b != null and b.category == &"defense" and b.buildable and (Content.faction(&"eu")["buildings"] as Array).has(id) and ResourceLoader.exists("res://ui/icons/%s.png" % id) and TranslationServer.translate(b.name_key) != b.name_key,
			"%s: German defence in the build menu with icon and text" % id)
	var tw := Content.weapon(&"eu_tower_50cal")
	t._check(tw.damage_type == &"hmg" and not tw.targets_air, "Guard Tower: .50 cal heavy MG (good vs infantry and light vehicles)")
	var jv := Content.weapon(&"eu_pit_javelin")
	t._check(jv.damage_type == &"anti_tank" and jv.range_mt >= 8500 and jv.range_mt > Content.weapon(&"us_javelin").range_mt and not jv.targets_air, "Javelin Foxhole: long-range anti-tank (%d mt)" % jv.range_mt)
	var ma := Content.weapon(&"eu_mantis_35")
	var mg2 := Content.weapon(&"eu_mantis_gnd")
	t._check(ma.targets_air and ma.cooldown_ms <= 120 and mg2.damage_type == &"aa_ground" and mg2.targets_ground, "MANTIS: rapid single-barrel AA, aa_ground mode vs vehicles")
	t._check(TranslationServer.translate("BLD_EU_MANTIS").contains("MANTIS") and not TranslationServer.translate("BLD_EU_MANTIS_DESC").contains("Rheinmetall") and not TranslationServer.translate("BLD_EU_MANTIS").contains("Skyshield"), "MANTIS name without company names")

static func _dps(w: WeaponDef, arm: StringName) -> float:
	return float(w.damage) * Content.combat.mult(w.damage_type, arm) / 100.0 * 1000.0 / float(w.cooldown_ms)

static func _air_speed(t: Node) -> void:
	var ok := true
	var info := []
	for id in AIR_OLD:
		var k := float(Content.unit(id).speed_mtps) / float(AIR_OLD[id])
		ok = ok and absf(k - 1.35) < 0.01
		info.append("%s %d" % [id, Content.unit(id).speed_mtps])
	t._check(ok, "every aircraft (helicopters and jets) flies 35 %% faster: %s" % ", ".join(info))

# ------------------------------------------------------------------ boarding, flying, shot down
static func _transport(t: Node) -> void:
	for id in HELIS:
		var fac := String(id).split("_")[0]
		var r := M33._runner([fac, "tpla" if fac != "tpla" else "us"])
		var w := r.sim
		var c := Vector2i(w.map.w / 2, w.map.h / 2)
		var heli := w.spawn_unit(id, 0, null, FX.tile_center(c))
		var sq_id := StringName(fac + "_squad")
		var s1 := w.spawn_unit(sq_id, 0, null, FX.tile_center(c))
		var s2 := w.spawn_unit(sq_id, 0, null, FX.tile_center(c))
		var s3 := w.spawn_unit(sq_id, 0, null, FX.tile_center(c))
		var b1 := RosterSys.board(w, s1, heli)
		var b2 := RosterSys.board(w, s2, heli)
		var b3 := RosterSys.board(w, s3, heli)
		t._check(b1 == 1 and b2 == 1 and b3 == -1 and RosterSys.load_of(w, heli) == 6, "%s: two squads board, a third does not fit" % id)
		heli.pos += Vector2i(FX.ONE * 6, 0)
		RosterSys.run(w)
		t._check(s1.pos == heli.pos, "%s: passengers ride along" % id)
		RosterSys.unload(w, heli)
		t._check(s1.res_id == 0 and s2.res_id == 0 and FX.dist(s1.pos, heli.pos) < FX.ONE * 3, "%s: Unload sets them down under the helicopter" % id)
		RosterSys.board(w, s1, heli)
		w.damage(heli, 999999, null)
		t._check(not heli.alive and not s1.alive, "%s: shot down with everyone aboard" % id)
		t._check(s2.alive, "%s: soldiers already on the ground are unhurt" % id)

# ------------------------------------------------------------------ the German defences fire
static func _defences(t: Node) -> void:
	var r := M33._runner(["eu", "ecc"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	var res := {}
	for k in 2:
		M33.place(w, 0, &"eu_reactor", hq.tile + Vector2i(0, -8), k)
	for id in DEFS:
		var b := M33.place(w, 0, id, hq.tile + Vector2i(0, 8), DEFS.find(id) * 3)
		t._check(b != null, "%s placed" % id)
		if b == null:
			continue
		var tgt_id := &"ecc_squad" if id == &"eu_guard_tower" else (&"ecc_ka52" if id == &"eu_mantis" else &"ecc_t90")
		var e := w.spawn_unit(tgt_id, 1, null, b.pos + Vector2i(FX.ONE * 5, 0))
		res[id] = [b, e, e.hp]
	w.rebuild_spatial()
	w.players[0].supply = 99999
	_ticks(r, 200)
	for id in res:
		var e: SimEntity = res[id][1]
		t._check(not e.alive or e.hp < int(res[id][2]), "%s fires at %s (%d -> %d)" % [id, e.def_id, res[id][2], e.hp if e.alive else 0])
	# javelin range: a tank well beyond normal AT range still gets hit
	var r2 := M33._runner(["eu", "ecc"])
	var w2 := r2.sim
	M33.place(w2, 0, &"eu_reactor", M33._hq(w2, 0).tile + Vector2i(0, -8))
	var pit := M33.place(w2, 0, &"eu_javelin_pit", M33._hq(w2, 0).tile + Vector2i(0, 8))
	var far := w2.spawn_unit(&"ecc_t90", 1, null, pit.pos + Vector2i(FX.mt_to_fx(8500), 0))
	far.orders.clear()
	var h0 := far.hp
	w2.rebuild_spatial()
	_ticks(r2, 160)
	t._check(far.hp < h0, "Javelin Foxhole hits a tank at 8.5 tiles (%d -> %d)" % [h0, far.hp])
	await t.get_tree().process_frame

# ------------------------------------------------------------------ AI
static func _ai(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://ai/ai_player.gd")
	var ok := true
	for id in DEFS:
		ok = ok and src.contains('&"%s"' % id)
	t._check(ok, "the German AI builds the Guard Tower, Javelin Foxhole and MANTIS turret")
	t._check(src.contains('ud.tags.has("transport") and ud.move_layer == &"air"'), "AIs build a capped number of transport helicopters from their airfields")

# ------------------------------------------------------------------ views
static func _views(t: Node) -> void:
	for id in HELIS:
		var v: Node3D = (load(Content.unit(id).view_scene) as PackedScene).instantiate()
		t._check(v.get_node_or_null("Model/Rotor") != null and v.get_node_or_null("Model/TailRotor") != null, "%s: main and tail rotor nodes spin" % id)
		var mz := v.find_children("Muzzle*", "Marker3D", true, false).size()
		if id != &"ecc_hind":
			t._check(mz == 2, "%s: one gun in each door (%d muzzles)" % [id, mz])
		else:
			t._check(v.get_node_or_null("Model/TurretPivot/Barrel") != null, "Hind: nose gun turret")
		v.free()
	var gt: Node3D = (load(Content.building(&"eu_guard_tower").view_scene) as PackedScene).instantiate()
	t._check(gt.find_children("Spot*", "Marker3D", true, false).size() == 1 and gt.get_node_or_null("Model/TurretPivot") != null, "Guard Tower: searchlight mounted with the .50 cal on its turning mount")
	gt.free()
	var jp: Node3D = (load(Content.building(&"eu_javelin_pit").view_scene) as PackedScene).instantiate()
	t._check(jp.find_children("Muzzle*", "Marker3D", true, false).size() == 2, "Javelin Foxhole: two teams, two launch points")
	var aabb := AABB()
	var first := true
	for mi in jp.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in ["Turret"]:
			aabb = (mi as MeshInstance3D).get_aabb()
			first = false
	t._check(not first and aabb.end.y < 0.5, "the Javelin teams kneel (figures %.2f high)" % aabb.end.y)
	jp.free()
	# bigger oil reserve
	var oc: Node3D = (load("res://view/neutral/cache.tscn") as PackedScene).instantiate()
	var bb: AABB = (oc.get_node("Model/Body") as MeshInstance3D).get_aabb()
	t._check(bb.size.x >= 2.0 and bb.size.z >= 1.8, "Crude Oil Reserve about twice the size (%.2f x %.2f)" % [bb.size.x, bb.size.z])
	oc.free()
	var r := M33._runner(["us", "ecc"])
	var res: SimEntity = null
	for id in r.sim.ids:
		if r.sim.ents[id].kind == SimEntity.Kind.RESOURCE:
			res = r.sim.ents[id]
			break
	t._check(res != null and res.radius >= 1300, "its footprint in the sim grew too (radius %d)" % (res.radius if res else 0))

static func _sounds(t: Node) -> void:
	for p in ["res://audio/sfx/hmg_heavy.ogg", "res://audio/sfx/minigun.ogg"]:
		t._check(ResourceLoader.exists(p), "%s exists" % p.get_file())
	var big := load("res://audio/sfx/explosion_large.ogg") as AudioStream
	t._check(big != null and big.get_length() > 2.0, "explosions ring out with a reverb tail (%.2f s)" % (big.get_length() if big else 0.0))
	var src := FileAccess.get_file_as_string("res://view/world_view.gd")
	t._check(src.contains('snd = "minigun"') and src.contains('snd = "hmg_heavy"'), "miniguns and heavy MGs get their own sounds")

static func _vfx_src(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://view/world_view.gd")
	t._check(src.contains('not ud.tags.has("helicopter")'), "helicopters leave no trail (jets keep theirs)")
	t._check(WorldView.POWER_PUFF_S > 0.32 and WorldView.POWER_PUFF_K < 1.0, "power plants vent less vapour (every %.2f s, %.0f %% size)" % [WorldView.POWER_PUFF_S, WorldView.POWER_PUFF_K * 100])
	t._check(src.contains("_flood_layout") and src.contains("Spot*"), "floodlights mount on the model's walls (and the tower's searchlight)")
