## M3.3 Phase 5 (47): World Builder - editing on the real 3D map. Run: test_runner -- wb
extends RefCounted

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

static func _frames(t: Node, n: int) -> void:
	for i in n:
		await t.get_tree().process_frame

static func run(t: Node) -> void:
	var scr: Node = load("res://ui/map_builder.tscn").instantiate()
	t.add_child(scr)
	await _frames(t, 3)
	var cv: MapBuilderCanvas = scr.canvas
	var wb: WorldBuilderView = scr.wb
	scr.new_map("WB Test", Vector2i(64, 64), &"temperate")
	wb.size = Vector2(800, 450)
	await _frames(t, 3)
	t._check(wb.visible and not cv.visible and wb.terrain != null and wb.terrain.is_inside_tree() and wb.map.w == 64,
		"the World Builder opens on the 3D map (terrain built in %d ms)" % wb.last_build_ms)
	t._check(wb.cam.current and wb.cam.position.y > 5.0, "a 3D camera looks at the map")
	# ---- sculpting through the API
	cv.tool = "raise"
	cv.height_strength = 300
	var u0: int = cv._undo.size()
	var rb0: int = wb.terrain.chunk_rebuilds
	cv.begin_height(Vector2(32, 32))
	for i in 4:
		cv.height_dab(Vector2(32, 32), 5.0, "raise")
	cv.end_height()
	var mm := cv.corner_mm(Vector2i(32, 32))
	t._check(mm >= 1100 and cv._undo.size() == u0 + 1, "Raise builds a hill (%d mm), one undo step" % mm)
	t._check(wb.map.elev[32 * 65 + 32] == mm and wb.terrain.chunk_rebuilds > rb0 and wb.ground_y(32, 32) > 1.0,
		"the 3D ground follows at once (%d chunk rebuilds, ground %.2f m)" % [wb.terrain.chunk_rebuilds - rb0, wb.ground_y(32, 32)])
	t._check(wb.terrain.chunk_rebuilds - rb0 <= 4 * 4, "only the touched ground chunks are rebuilt")
	cv.begin_height(Vector2(32, 32))
	for i in 6:
		cv.height_dab(Vector2(34, 32), 5.0, "smooth")
	cv.end_height()
	t._check(cv.corner_mm(Vector2i(32, 32)) < mm and cv.corner_mm(Vector2i(32, 32)) > 0, "Smooth softens it (%d mm)" % cv.corner_mm(Vector2i(32, 32)))
	cv.begin_height(Vector2(10, 50))
	cv.height_dab(Vector2(10, 50), 4.0, "lower")
	cv.end_height()
	t._check(cv.corner_mm(Vector2i(10, 50)) < 0, "Lower digs a hollow (%d mm)" % cv.corner_mm(Vector2i(10, 50)))
	cv.begin_height(Vector2(10, 50))
	for i in 4:
		cv.height_dab(Vector2(10, 50), 5.0, "level0")
	cv.end_height()
	t._check(absi(cv.corner_mm(Vector2i(10, 50))) < 30, "Level to ground flattens it again")
	cv.undo()
	t._check(cv.corner_mm(Vector2i(10, 50)) < 0 and wb.map.elev[50 * 65 + 10] < 0, "undo restores the hollow in the 3D view too")
	cv.redo()
	# water stays level: paint a pond then try to raise it
	cv.paint_t = SimMap.T.WATER
	cv.brush = 3
	cv.paint([Vector2i(50, 12)])
	cv.begin_height(Vector2(50.5, 12.5))
	cv.height_dab(Vector2(50.5, 12.5), 3.0, "raise")
	cv.end_height()
	t._check(cv.corner_mm(Vector2i(50, 12)) > 0 and wb.map.elev[12 * 65 + 50] == 0, "water and its banks stay level (the sim's rule, shown as it will play)")
	# ---- picking: a screen point lands on the right tile of the hilly ground
	wb.focus(Vector2(32, 32), 30.0)
	await _frames(t, 2)
	var ok_pick := true
	var info := []
	for p in [Vector2(32.5, 32.5), Vector2(28.5, 35.5), Vector2(40.5, 30.5)]:
		var wp := Vector3(p.x, wb.ground_y(p.x, p.y), p.y)
		var tl := wb.tile_at(wb.screen_of(wp))
		if tl != Vector2i(int(p.x), int(p.y)):
			ok_pick = false
			info.append([p, tl])
	t._check(ok_pick, "tapping the 3D map picks the tile under the finger, on hills too %s" % str(info))
	# ---- one finger on the 3D view sculpts, a second finger turns it into a view gesture
	cv.tool = "raise"
	cv.height_strength = 120
	cv.brush = 5
	var sp := wb.screen_of(Vector3(24.5, wb.ground_y(24.5, 40.5), 40.5))
	var m0 := cv.corner_mm(Vector2i(24, 40))
	u0 = cv._undo.size()
	_touch(wb, 0, sp, true)
	_drag(wb, 0, sp + Vector2(12, 0))
	_drag(wb, 0, sp + Vector2(24, 0))
	_touch(wb, 0, sp + Vector2(24, 0), false)
	t._check(cv.corner_mm(Vector2i(24, 40)) > m0 and cv._undo.size() == u0 + 1, "a one-finger drag on the 3D map raises the ground (one undo step)")
	var d0 := wb.dist
	var m1 := cv.corner_mm(Vector2i(24, 40))
	_touch(wb, 0, sp, true)
	_drag(wb, 0, sp + Vector2(4, 0))
	_touch(wb, 1, sp + Vector2(100, 0), true)
	_drag(wb, 1, sp + Vector2(220, 0))
	_touch(wb, 1, sp + Vector2(220, 0), false)
	_touch(wb, 0, sp + Vector2(4, 0), false)
	t._check(wb.dist < d0 * 0.8 and cv.corner_mm(Vector2i(24, 40)) == m1, "two fingers zoom the view (%.0f -> %.0f m) and cancel the started stroke" % [d0, wb.dist])
	var y0 := wb.yaw
	wb.turn(45.0)
	t._check(absf(wrapf(wb.yaw - y0, -180, 180) - 45.0) < 0.1, "the view turns")
	wb.turn(-45.0)
	wb.focus(Vector2(32, 32), 30.0)
	await _frames(t, 2)
	# ---- placing objects on the 3D map
	cv.place = {"t": "pre", "kind": "us_lynx", "slot": 0}
	cv.tool = "place"
	var n0 := cv.items.size()
	var tp := wb.screen_of(Vector3(30.5, wb.ground_y(30.5, 30.5), 30.5))
	_touch(wb, 0, tp, true)
	_touch(wb, 0, tp, false)
	t._check(cv.items.size() == n0 + 1 and cv.items[n0]["tile"] == Vector2i(30, 30) and wb.item_nodes.size() == cv.items.size(),
		"tapping places a unit on the 3D map (%s)" % (str(cv.items[n0]["tile"]) if cv.items.size() > n0 else "none"))
	var un: Node3D = wb.item_nodes[n0]
	t._check(un is EntityView and absf(un.position.y - wb.ground_y(30.5, 30.5)) < 0.05, "the real unit model stands on the hill (y %.2f)" % un.position.y)
	cv.place_at(Vector2i(14, 14), {"t": "spawn", "slot": 0})
	cv.place_at(Vector2i(50, 50), {"t": "spawn", "slot": 1})
	cv.place_at(Vector2i(20, 14), {"t": "res", "kind": "seam"})
	cv.place_at(Vector2i(44, 50), {"t": "res", "kind": "cache"})
	cv.place_at(Vector2i(40, 20), {"t": "neutral", "kind": "neutral_pump"})
	cv.place_at(Vector2i(22, 26), {"t": "prop", "kind": "oak"})
	cv.place_at(Vector2i(26, 46), {"t": "pre", "kind": "us_firebase", "slot": 1})
	var kinds := {}
	for n in wb.item_nodes:
		kinds[String(n.get_meta("wb_kind", ""))] = true
	t._check(wb.item_nodes.size() == cv.items.size() and kinds.size() == 5, "starts, supplies, neutral structures, props and units all show in 3D (%s)" % str(kinds.keys()))
	# ---- select + drag an object with one finger
	cv.tool = "select"
	var fi := cv.items.size() - 1
	var fp := MapBuilderCanvas.item_fp(cv.items[fi])
	var c0 := Vector2(cv.items[fi]["tile"]) + Vector2(fp) * 0.5
	var s0 := wb.screen_of(Vector3(c0.x, wb.ground_y(c0.x, c0.y), c0.y))
	var c1 := c0 + Vector2(6, 0)
	var s1 := wb.screen_of(Vector3(c1.x, wb.ground_y(c1.x, c1.y), c1.y))
	var tile0: Vector2i = cv.items[fi]["tile"]
	_touch(wb, 0, s0, true)
	_drag(wb, 0, s0.lerp(s1, 0.5))
	_drag(wb, 0, s1)
	_touch(wb, 0, s1, false)
	var moved: Vector2i = cv.items[fi]["tile"] - tile0
	t._check(cv.selected == fi and moved.x >= 5 and moved.x <= 7 and absi(moved.y) <= 1, "drag a structure across the 3D map (moved %s)" % str(moved))
	var fnode: Node3D = wb.item_nodes[fi]
	var want := Vector2(cv.items[fi]["tile"]) + Vector2(fp) * 0.5
	t._check(Vector2(fnode.position.x, fnode.position.z).distance_to(want) < 0.01, "its model follows")
	cv.delete_selected()
	t._check(wb.item_nodes.size() == cv.items.size(), "delete removes it from the 3D map")
	# ---- painting ground types on the 3D map: the ground is rebuilt after the stroke
	cv.tool = "paint"
	cv.paint_t = SimMap.T.ROAD
	cv.brush = 3
	var b0 := wb.terrain_builds
	var pu0 := wb.tile_updates
	var nu0 := cv._undo.size()
	var rp := wb.screen_of(Vector3(36.5, wb.ground_y(36.5, 44.5), 44.5))
	_touch(wb, 0, rp, true)
	for i in 3:
		await t.get_tree().process_frame
	t._check(cv.tiles[44 * 64 + 36] == SimMap.T.ROAD and wb.map.tiles[44 * 64 + 36] == SimMap.T.ROAD and wb.tile_updates > pu0,
		"painting shows on the 3D ground while the finger is still down")
	_drag(wb, 0, rp + Vector2(30, 0))
	_touch(wb, 0, rp + Vector2(30, 0), false)
	for i in 6:
		await t.get_tree().process_frame
	t._check(wb.terrain_builds == b0 and cv._undo.size() == nu0 + 1 and wb.terrain.splat_at(36, 44) == "a",
		"a paint stroke lays road as one undo step, redrawing only that part of the ground (%d ms)" % wb.last_update_ms)
	# undo / redo of a stroke update the same part only
	cv.undo()
	await _frames(t, 2)
	t._check(wb.map.tiles[44 * 64 + 36] != SimMap.T.ROAD and wb.terrain_builds == b0, "undo takes the road away again (no full rebuild)")
	cv.redo()
	await _frames(t, 2)
	# water painted on the 3D map: banks level, the water surface follows
	cv.paint_t = SimMap.T.WATER
	var wp0 := wb.screen_of(Vector3(20.5, wb.ground_y(20.5, 56.5), 56.5))
	_touch(wb, 0, wp0, true)
	_touch(wb, 0, wp0, false)
	await _frames(t, 2)
	t._check(wb.map.tiles[56 * 64 + 20] == SimMap.T.WATER and wb.terrain.heights[56 * 65 + 20] < -0.2 and wb.terrain.has_part("water"),
		"painted water digs a riverbed and gets a water surface (%d ms)" % wb.last_update_ms)
	# ---- the 2D overview edits the same map
	scr.set_3d(false)
	await _frames(t, 2)
	t._check(cv.visible and not wb.visible, "2D map view toggle")
	scr.set_3d(true)
	await _frames(t, 2)
	# ---- save / reload / play: the sculpted height is part of the map
	cv.place_at(Vector2i(12, 20), {"t": "res", "kind": "cache"})
	cv.place_at(Vector2i(52, 44), {"t": "res", "kind": "seam"})
	var msgs := MapStore.validate(cv.to_doc())
	var saved_ok: bool = scr.save_map()
	var id := cv.map_id
	t._check(saved_ok, "map with hills passes the check and saves %s" % str(msgs))
	var doc := cv.to_doc()
	t._check(String(doc["elev"]).begins_with("z1:") and String(doc["elev"]).length() < 40000, "heights saved compactly (%d chars)" % String(doc["elev"]).length())
	var e_before := cv.elev.duplicate()
	scr.open_map(id)
	await _frames(t, 2)
	t._check(cv.elev == e_before and MapStore.hash_of(cv.to_doc()) == MapStore.hash_of(doc), "reload gives the same heights")
	var md: MapDef = Content.maps[StringName(id)]
	var sm := SimMap.new()
	sm.load_from(md)
	var steep := 0
	for k in sm.slope:
		steep = maxi(steep, k)
	t._check(sm.has_elev and sm.elev[32 * 65 + 32] > 300 and steep > 0, "the game's map has the hill (%d mm, slope %d%%)" % [sm.elev[32 * 65 + 32], steep])
	var cfg := SkirmishConfig.default_setup()
	cfg["map"] = id
	cfg["slots"][0]["kind"] = "ai"
	cfg["slots"][0]["faction"] = "us"
	cfg["slots"][1]["faction"] = "eu"
	var rc := SkirmishConfig.resolve(cfg)
	rc["seed"] = 77
	rc["slots"][0]["spawn"] = 0
	rc["slots"][1]["spawn"] = 1
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(rc)
	for i in 300:
		r.advance()
	var blob := var_to_bytes(r.serialize())
	var r2 := MatchRunner.new()
	r2.record_replay = false
	r2.deserialize(bytes_to_var(blob))
	for i in 200:
		r.advance()
		r2.advance()
	t._check(r.sim.map.has_elev and r.sim.state_hash() == r2.sim.state_hash(), "a skirmish on the sculpted map plays, saves and resumes in sync")
	MapStore.delete(id)
	# ---- older maps are unchanged
	var d_old := MapStore.to_dict(Content.maps[&"harvest_valley"])
	var d_no := d_old.duplicate()
	d_no.erase("elev")
	t._check(String(d_old["elev"]) == "" and MapStore.hash_of(d_old) == MapStore.hash_of(d_no), "built-in maps carry no sculpted heights and keep their hash")
	# a copy of a hilly built-in map keeps its hills (baked into sculpted heights)
	scr.new_map("Copy", Vector2i(64, 64), &"temperate", &"harvest_valley")
	await _frames(t, 2)
	var orig := SimMap.new()
	orig.load_from(Content.maps[&"harvest_valley"])
	var cp := SimMap.new()
	cp.load_from(MapStore.from_dict(cv.to_doc()))
	t._check(cv.has_height() and cp.elev == orig.elev, "a copy of Harvest Valley keeps its hills exactly")
	print("WB timing: 64x64 build %d ms" % wb.last_build_ms)
	scr.new_map("Big", Vector2i(256, 256), &"desert", &"highland_crown")
	await _frames(t, 2)
	print("WB timing: Highland Crown copy (256x256) terrain build %d ms" % wb.last_build_ms)
	t._check(wb.map.w == 256 and wb.terrain_builds > 0, "a 256x256 map opens in the 3D builder (%d ms)" % wb.last_build_ms)
	# a brush stroke on the big map only redraws the part it touches
	var tb := wb.terrain_builds
	cv.paint_t = SimMap.T.ROUGH
	cv.brush = 5
	cv.begin_paint(Vector2i(120, 120))
	cv.paint_to(Vector2i(130, 124))
	var tt0 := Time.get_ticks_msec()
	wb.refresh_tiles()
	var live_ms := Time.get_ticks_msec() - tt0
	cv.end_paint()
	cv.paint_t = SimMap.T.WATER
	cv.begin_paint(Vector2i(140, 100))
	cv.paint_to(Vector2i(146, 100))
	tt0 = Time.get_ticks_msec()
	wb.refresh_tiles()
	var wet_ms := Time.get_ticks_msec() - tt0
	cv.end_paint()
	print("WB timing: 256x256 stroke update %d ms, with water %d ms" % [live_ms, wet_ms])
	t._check(wb.terrain_builds == tb and live_ms < 700 and wet_ms < 1500 and wb.map.tiles[124 * 256 + 130] == SimMap.T.ROUGH,
		"a brush stroke on a 256x256 map updates in %d ms (water %d ms), not a full %d ms rebuild" % [live_ms, wet_ms, wb.last_build_ms])
	scr.queue_free()
