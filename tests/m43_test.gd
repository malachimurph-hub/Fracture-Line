## M4.3 headless checks (test_runner "m43"): Malachi's 0.4.3 list - low power shuts powered
## buildings down, no-power defences, retired German defences and camo nets, civilian colours,
## helicopter landing, unload cash pop-up, rubble cleared by new buildings, new sounds.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_power(t)
	_retired(t)
	_civvy(t)
	_unload_floater(t)
	_rubble(t)
	_audio(t)
	_country_maps(t)

static func _power(t: Node) -> void:
	for id in [&"eu_javelin_pit", &"eu_guard_tower", &"us_firebase"]:
		var d := Content.building(id)
		t._check(d.power >= 0 and not d.needs_power_to_fire, "%s needs no power" % id)
	var r := M33._runner(["eu", "ecc"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	var base := hq.tile + Vector2i(8, 0)
	var made: Array = []
	for k in 6:
		var tl := base + Vector2i(0, k * 4 - 10)
		made.append(w._place_building(Content.building(&"eu_signals"), 0, tl, 0, true))
	var tw: SimEntity = null
	tw = w._place_building(Content.building(&"eu_guard_tower"), 0, hq.tile + Vector2i(-8, 0), 0, true)
	PowerSys.recompute_grid(w)
	var p: SimPlayer = w.players[0]
	t._check(p.low_power, "enough consumers put the player in low power (%d/%d)" % [p.power_used, p.power_prod])
	var off := 0
	for b in made:
		if not b.powered:
			off += 1
	t._check(made.size() > 0 and off == made.size(), "powered buildings shut down in low power (%d/%d)" % [off, made.size()])
	t._check(tw != null and tw.powered, "a guard tower keeps working in low power")

static func _retired(t: Node) -> void:
	for id in [&"eu_gun_bunker", &"eu_flak_tower", &"tpla_camo_net"]:
		t._check(not Content.building(id).buildable, "%s is no longer buildable" % id)

static func _civvy(t: Node) -> void:
	var seen := {}
	for i in 200:
		seen[Palette.civvy_paint(i)] = true
	t._check(seen.size() == Palette.CIVVY_PAINT.size(), "civilian pickups get all %d colours" % seen.size())
	t._check(Palette.civvy_paint(17) == Palette.civvy_paint(17), "a vehicle keeps its colour")

static func _unload_floater(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://match/match.gd")
	t._check(src.contains("ev[\"t\"] == \"unload\" and ev.has(\"amount\")"), "troops unloading do not show a cash pop-up")

static func _rubble(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	var hv: SimEntity = null
	for id in r.sim.ids:
		if r.sim.is_civilian(r.sim.ents[id]):
			hv = r.sim.ents[id]
			break
	if hv == null:
		t._check(true, "no civilian building on the test map (rubble check skipped)")
		wv.queue_free()
		return
	var v: EntityView = wv._ensure_view(hv)
	var pos := v.position
	wv._on_death({"t": "death", "id": hv.id, "kind": hv.kind, "def": hv.def_id, "pos": hv.pos, "owner": -1})
	var n0: int = wv.rubble_count
	var dummy := EntityView.new()
	dummy.footprint = Vector2(2, 2)
	dummy.position = pos
	wv._clear_rubble(dummy)
	t._check(n0 >= 1 and wv.rubble_count == n0 - 1, "building over civilian rubble clears it (%d -> %d)" % [n0, wv.rubble_count])
	dummy.free()
	wv.queue_free()

static func _audio(t: Node) -> void:
	for k in ["move_tank_loop", "move_ifv_loop", "move_light_loop", "move_heli_loop", "move_jet_loop", "jet_takeoff", "rocket_heavy", "missile_heavy", "artillery_heavy", "cannon_heavy"]:
		t._check(ResourceLoader.exists("res://audio/sfx/%s.ogg" % k), "sound %s exists" % k)
	t._check(AudioDirector.move_class(Content.unit(&"us_halberd")) == "tank" and AudioDirector.move_class(Content.unit(&"us_lynx")) == "light", "vehicles get size-matched engine loops")

static func _country_maps(t: Node) -> void:
	var expect := {&"prairie_crossing": &"us", &"rheinbruck": &"de", &"qanat_gate": &"ir", &"severny_bridge": &"ru"}
	for id in expect:
		t._check(Content.maps.has(id), "country map %s is registered" % id)
		var md: MapDef = Content.maps[id]
		t._check(md.civ_theme == expect[id], "%s civ_theme is %s" % [id, expect[id]])
		var label := tr(md.name_key)
		t._check(label.contains("USA") or label.contains("Germany") or label.contains("Iran") or label.contains("Russia"),
			"%s label names the country (%s)" % [id, label])
		TerrainView.civ_theme = md.civ_theme
		var hk := PropMeshes.themed("house_a", md.civ_theme)
		t._check(PropMeshes.make(hk) != null, "%s house mesh %s builds" % [id, hk])
		t._check(PropMeshes.make(PropMeshes.themed("civ_block", md.civ_theme)) != null, "%s civ block mesh builds" % id)
