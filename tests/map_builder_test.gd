## M2.8 headless map-builder test (test_runner "map_builder"): opens the Map Builder screen,
## creates a 256x256 map, paints terrain (incl. touch strokes, pinch roll-back, undo/redo),
## places assets, runs validation (unreachable starts, missing supplies, blocked items), saves,
## reloads, starts an AI skirmish on it for several hundred ticks (with pre-placed units /
## buildings) and suspends/resumes it, also after the map file was deleted (embedded copy).

static func _touch(c: Control, idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	c._gui_input(e)

static func _drag(c: Control, idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	c._gui_input(e)

static func run(t: Node) -> void:
	var scr: Node = load("res://ui/map_builder.tscn").instantiate()
	t.add_child(scr)
	for i in 3:
		await t.get_tree().process_frame
	var cv: MapBuilderCanvas = scr.canvas
	scr.new_map("Builder Test", Vector2i(256, 256), &"temperate")
	await t.get_tree().process_frame
	t._check(cv.w == 256 and cv.h == 256 and cv.env == &"temperate", "new map dialog result: 256x256 temperate (%dx%d %s)" % [cv.w, cv.h, cv.env])
	t._check(MapStore.SIZES[MapStore.DEFAULT_SIZE] == Vector2i(256, 256), "256x256 is the default size preset")
	# asset list covers every placeable asset
	var n := 0
	for c in scr.asset_categories():
		n += c[1].size()
	var want := 4 + 2 + MapBuilderCanvas.PROP_LABELS.size()
	for id in Content.buildings:
		if Content.faction_of_id(id) == &"neutral":
			want += 1
	for f in Content.FACTIONS:
		want += Content.faction(f)["units"].size() + Content.faction(f)["buildings"].size()
	t._check(n == want and n > 80, "asset list has every placeable asset (%d)" % n)
	# terrain: a river across the map
	cv.tool = "paint"
	cv.paint_t = SimMap.T.WATER
	cv.brush = 5
	var path: Array = []
	for x in range(0, 256, 8):
		path.append(Vector2i(x, 128))
	path.append(Vector2i(255, 128))
	cv.paint(path)
	t._check(cv.tiles[128 * 256 + 100] == SimMap.T.WATER and cv.tiles[126 * 256 + 100] == SimMap.T.WATER, "paint stroke with brush 5")
	# forest patch by fill on a cliff-ringed area: paint a small square outline and fill inside
	cv.paint_t = SimMap.T.FOREST
	cv.brush = 9
	cv.paint([Vector2i(60, 60)])
	cv.paint_t = SimMap.T.ROUGH
	cv.tool = "fill"
	cv.fill(Vector2i(60, 60))
	t._check(cv.tiles[60 * 256 + 60] == SimMap.T.ROUGH and cv.tiles[62 * 256 + 62] == SimMap.T.ROUGH, "fill replaces a connected region")
	cv.undo()
	t._check(cv.tiles[60 * 256 + 60] == SimMap.T.FOREST, "undo")
	cv.redo()
	t._check(cv.tiles[60 * 256 + 60] == SimMap.T.ROUGH, "redo")
	# touch: one finger paints, a second finger turns it into pan/zoom and rolls the stroke back
	cv.tool = "paint"
	cv.paint_t = SimMap.T.ROAD
	cv.brush = 1
	cv.zoom = 4.0
	cv.offset = Vector2.ZERO
	var u0 := cv._undo.size()
	_touch(cv, 0, Vector2(40, 40), true)
	_drag(cv, 0, Vector2(80, 40))
	_touch(cv, 0, Vector2(80, 40), false)
	t._check(cv.tiles[10 * 256 + 15] == SimMap.T.ROAD and cv._undo.size() == u0 + 1, "one-finger touch stroke paints (one undo step)")
	_touch(cv, 0, Vector2(40, 200), true)
	_drag(cv, 0, Vector2(44, 200))
	_touch(cv, 1, Vector2(140, 200), true)
	_drag(cv, 1, Vector2(240, 200))
	_touch(cv, 1, Vector2(240, 200), false)
	_touch(cv, 0, Vector2(44, 200), false)
	t._check(cv.tiles[50 * 256 + 10] != SimMap.T.ROAD and cv.zoom > 4.5, "two fingers pinch-zoom (%.1f) and roll back the started stroke" % cv.zoom)
	cv.undo()   # remove the road
	# items
	cv.place_at(Vector2i(22, 22), {"t": "spawn", "slot": 0})
	cv.place_at(Vector2i(232, 232), {"t": "spawn", "slot": 1})
	var msgs := MapStore.validate(cv.to_doc())
	t._check(_has(msgs, "cannot reach Start 1") or _has(msgs, "cannot reach Start 2"), "check: river with no crossing -> starts cannot reach each other")
	t._check(_has(msgs, "no reachable supply"), "check: missing supplies reported")
	cv.tool = "paint"
	cv.paint_t = SimMap.T.BRIDGE
	cv.brush = 3
	cv.paint([Vector2i(100, 122), Vector2i(100, 134)])
	cv.paint_t = SimMap.T.FORD
	cv.paint([Vector2i(180, 122), Vector2i(180, 134)])
	msgs = MapStore.validate(cv.to_doc())
	t._check(not _has(msgs, "cannot reach"), "check: a bridge connects the starts")
	cv.place_at(Vector2i(36, 22), {"t": "res", "kind": "seam"})
	cv.place_at(Vector2i(22, 36), {"t": "res", "kind": "cache"})
	cv.place_at(Vector2i(218, 232), {"t": "res", "kind": "seam"})
	cv.place_at(Vector2i(232, 218), {"t": "res", "kind": "cache"})
	cv.set_selected_amount(9000)
	t._check(int(cv.items[cv.selected]["amount"]) == 9000, "supply amount editable")
	var bad := cv.place_at(Vector2i(140, 128), {"t": "neutral", "kind": "neutral_pump"})
	msgs = MapStore.validate(cv.to_doc())
	t._check(_has(msgs, "blocked ground"), "check: item on water is reported")
	scr.check_map()
	t._check(scr.overlay != null and scr.last_messages.size() > 0, "validation message dialog shown")
	scr.close_overlay()
	cv.selected = bad
	cv.delete_selected()
	cv.place_at(Vector2i(128, 100), {"t": "neutral", "kind": "neutral_pump"})
	cv.place_at(Vector2i(128, 160), {"t": "neutral", "kind": "neutral_civ_block"})
	# pre-placed units / buildings for other factions
	cv.place_at(Vector2i(40, 40), {"t": "pre", "kind": "us_lynx", "slot": 0})
	cv.place_at(Vector2i(46, 34), {"t": "pre", "kind": "eu_gun_bunker", "slot": 0})
	cv.place_at(Vector2i(210, 210), {"t": "pre", "kind": "tpla_rattler", "slot": 1})
	cv.place_at(Vector2i(200, 214), {"t": "pre", "kind": "us_firebase", "slot": 1})
	# M2.9 city props: a tower saves as blocking Cliff + decor, a car as decor only
	cv.place_at(Vector2i(60, 120), {"t": "prop", "kind": "tower_glass"})
	cv.place_at(Vector2i(66, 120), {"t": "prop", "kind": "car_taxi"})
	var pd := cv.to_doc()
	t._check(pd["decor"].size() == 2 and String(pd["tiles"][120])[60] == "^" and String(pd["tiles"][120])[66] != "^", "city props saved (tower blocks its footprint, car is decor)")
	# select + move by touch
	cv.tool = "select"
	cv.size = Vector2(560, 320)   # phone-sized canvas (headless layout is tiny)
	cv.fit()
	var it_i := cv.hit(Vector2i(128, 100))
	var p0: Vector2 = cv.offset + (Vector2(cv.items[it_i]["tile"]) + Vector2(1, 1)) * cv.zoom
	_touch(cv, 0, p0, true)
	_drag(cv, 0, p0 + Vector2(cv.zoom * 10, 0))
	_touch(cv, 0, p0 + Vector2(cv.zoom * 10, 0), false)
	t._check(cv.selected == it_i and int(cv.items[it_i]["tile"].x) >= 133, "touch select + drag moves an item (%s)" % str(cv.items[it_i]["tile"]))
	msgs = MapStore.validate(cv.to_doc())
	t._check(msgs.is_empty(), "check passes on the finished map %s" % str(msgs))
	# save / list / reload
	var ok: bool = scr.save_map()
	var id := cv.map_id
	t._check(ok and FileAccess.file_exists(MapStore.path_of(id)) and Content.maps.has(StringName(id)), "saved to %s and registered" % MapStore.path_of(id))
	t._check(SkirmishConfig.map_ids().has(StringName(id)) and (Content.maps[StringName(id)] as MapDef).custom, "custom map listed in skirmish (marked custom)")
	var saved := cv.to_doc()
	scr.open_map(id)
	t._check(MapStore.hash_of(cv.to_doc()) == MapStore.hash_of(saved) and cv.items.size() == saved["spawns"].size() + saved["resources"].size() + saved["neutrals"].size() + saved["prebuilt"].size() + saved["decor"].size(), "reload gives the same map")
	Content.load_all()
	t._check(Content.maps.has(StringName(id)), "custom map re-registered by Content.load_all()")
	scr.queue_free()
	# skirmish via the lobby model, AI vs AI
	var cfg := SkirmishConfig.default_setup()
	cfg["map"] = id
	cfg["slots"][0]["kind"] = "ai"
	cfg["slots"][0]["faction"] = "us"
	cfg["slots"][0]["difficulty"] = "medium"
	cfg["slots"][1]["faction"] = "tpla"
	t._check(SkirmishConfig.validate(cfg) == "", "lobby accepts the custom map")
	var rc := SkirmishConfig.resolve(cfg)
	rc["seed"] = 4242
	rc["slots"][0]["spawn"] = 0
	rc["slots"][1]["spawn"] = 1
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(rc)
	var pre := {}
	for eid in r.sim.ids:
		var e: SimEntity = r.sim.ents[eid]
		if e.def_id in [&"us_lynx", &"eu_gun_bunker", &"tpla_rattler", &"us_firebase"]:
			pre[String(e.def_id)] = e.owner
	t._check(pre.get("us_lynx", -1) == 0 and pre.get("eu_gun_bunker", -1) == 0 and pre.get("tpla_rattler", -1) == 1 and pre.get("us_firebase", -1) == 1, "pre-placed units/buildings owned by their start's player %s" % str(pre))
	var ents0 := r.sim.ids.size()
	for i in 500:
		r.advance()
	t._check(r.sim.ids.size() > ents0 and r.sim.map.w == 256, "AI plays on the custom map (%d -> %d entities after 500 ticks)" % [ents0, r.sim.ids.size()])
	# suspend / resume (through the same byte serialisation SaveSystem uses)
	var blob := var_to_bytes(r.serialize())
	t._check(not (bytes_to_var(blob)["sim"]["map_data"] as Dictionary).is_empty(), "save embeds the custom map")
	var r2 := MatchRunner.new()
	r2.record_replay = false
	r2.deserialize(bytes_to_var(blob))
	for i in 300:
		r.advance()
		r2.advance()
	t._check(r.sim.state_hash() == r2.sim.state_hash(), "resumed match on the custom map stays in sync")
	MapStore.delete(id)
	t._check(not Content.maps.has(StringName(id)) and not FileAccess.file_exists(MapStore.path_of(id)), "custom map deleted")
	var r3 := MatchRunner.new()
	r3.record_replay = false
	var d3: Dictionary = bytes_to_var(blob)
	var w3 := SimWorld.new()
	w3.deserialize(d3["sim"])
	t._check(w3.state_hash() == int(d3["sim"]["hash"]), "save verifies (hash) after its map was deleted")
	r3.deserialize(d3)
	for i in 300:
		r3.advance()
	t._check(r3.sim.state_hash() == r.sim.state_hash() and not SkirmishConfig.map_ids().has(r3.sim.map_id), "resume after deleting the map uses the embedded copy (%s, hidden from lobby)" % r3.sim.map_id)
	Content.maps.erase(r3.sim.map_id)

static func _has(msgs: PackedStringArray, s: String) -> bool:
	for m in msgs:
		if m.contains(s):
			return true
	return false
