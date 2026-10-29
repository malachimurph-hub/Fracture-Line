extends Node
## M3.3 Phase 5 screenshots: the World Builder on a sculpted map (heights, objects, ground).
##   xvfb-run -a -s "-screen 0 1600x740x24" godot --path . --resolution 1600x740 \
##     --rendering-method mobile res://tests/wb_shots.tscn -- <out_dir>

func _shot(path: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	get_tree().current_scene = null
	GameSession.goto("res://ui/map_builder.tscn")
	for i in 6:
		await get_tree().process_frame
	var scr: Node = get_tree().current_scene
	scr.new_map("Ridge Crossing", Vector2i(80, 80), &"temperate")
	for i in 3:
		await get_tree().process_frame
	var cv: MapBuilderCanvas = scr.canvas
	var wb: WorldBuilderView = scr.wb
	# ground: a river with a bridge, a road over it, woods, rough ground and a rock outcrop
	for spec in [[SimMap.T.WATER, 5, [Vector2i(0, 44), Vector2i(20, 47), Vector2i(40, 43), Vector2i(60, 48), Vector2i(79, 45)]],
			[SimMap.T.FOREST, 7, [Vector2i(8, 14), Vector2i(18, 22), Vector2i(12, 30)]],
			[SimMap.T.FOREST, 5, [Vector2i(60, 60), Vector2i(70, 68)]],
			[SimMap.T.ROUGH, 7, [Vector2i(52, 18), Vector2i(64, 26)]],
			[SimMap.T.ROAD, 3, [Vector2i(34, 8), Vector2i(36, 40), Vector2i(36, 52), Vector2i(44, 76)]],
			[SimMap.T.CLIFF, 3, [Vector2i(66, 8), Vector2i(72, 14)]]]:
		cv.paint_t = spec[0]
		cv.brush = spec[1]
		cv.paint(spec[2])
	cv.paint_t = SimMap.T.BRIDGE
	cv.brush = 3
	cv.paint([Vector2i(36, 40), Vector2i(36, 51)])
	# heights: a ridge north of the river, a hill with a flattened top, a hollow
	cv.height_strength = 300
	for c in [Vector2(14, 20), Vector2(20, 24), Vector2(26, 26), Vector2(56, 22), Vector2(58, 24)]:
		cv.begin_height(c)
		for k in 9:
			cv.height_dab(c, 7.0, "raise")
		cv.end_height()
	cv.begin_height(Vector2(57, 23))
	for k in 4:
		cv.height_dab(Vector2(57, 23), 4.0, "flatten")
	cv.end_height()
	cv.begin_height(Vector2(20, 64))
	cv.height_dab(Vector2(20, 64), 6.0, "lower")
	cv.end_height()
	cv.begin_height(Vector2(20, 22))
	for k in 2:
		cv.height_dab(Vector2(20, 22), 9.0, "smooth")
	cv.end_height()
	# objects
	for p in [[Vector2i(6, 6), {"t": "spawn", "slot": 0}], [Vector2i(68, 70), {"t": "spawn", "slot": 1}],
			[Vector2i(28, 14), {"t": "res", "kind": "seam"}], [Vector2i(50, 62), {"t": "res", "kind": "cache"}],
			[Vector2i(44, 30), {"t": "neutral", "kind": "neutral_pump"}],
			[Vector2i(40, 16), {"t": "pre", "kind": "us_reactor", "slot": 0}],
			[Vector2i(44, 22), {"t": "pre", "kind": "us_barracks", "slot": 0}],
			[Vector2i(31, 31), {"t": "pre", "kind": "us_lynx", "slot": 0}], [Vector2i(33, 33), {"t": "pre", "kind": "us_lynx", "slot": 0}],
			[Vector2i(30, 35), {"t": "pre", "kind": "us_bradley", "slot": 0}],
			[Vector2i(40, 57), {"t": "pre", "kind": "ecc_t90", "slot": 1}], [Vector2i(43, 59), {"t": "pre", "kind": "ecc_t90", "slot": 1}],
			[Vector2i(48, 66), {"t": "pre", "kind": "ecc_factory", "slot": 1}],
			[Vector2i(24, 36), {"t": "prop", "kind": "oak"}], [Vector2i(27, 38), {"t": "prop", "kind": "oak"}]]:
		cv.place_at(p[0], p[1])
	for i in 4:
		await get_tree().process_frame
	# 1) Height tab, Raise brush over the ridge
	scr.show_tab("height")
	for b in scr._strength_group.get_buttons():
		if (b as Button).text == "Strong":
			(b as Button).button_pressed = true
			(b as Button).pressed.emit()
	cv.tool = "raise"
	cv.selected = -1
	cv.selection_changed.emit()
	wb.yaw = 200.0
	wb.set_pitch(34.0)
	wb.focus(Vector2(32, 30), 50.0)
	for i in 3:
		await get_tree().process_frame
	wb._hover_at(wb.screen_of(Vector3(22, wb.ground_y(22, 26), 26)))
	await _shot(out + "/wb_height_brush.png")
	# 2) Objects tab: units and structures standing on the sculpted ground, one selected
	scr.show_tab("assets")
	cv.tool = "select"
	cv.selected = cv.hit(Vector2i(40, 16), 1)
	cv.selection_changed.emit()
	wb.yaw = -30.0
	wb.set_pitch(38.0)
	wb.focus(Vector2(38, 26), 24.0)
	await _shot(out + "/wb_objects_select.png")
	# 3) Ground tab, grid on, painting road across the plateau
	scr.show_tab("terrain")
	cv.tool = "paint"
	for b in scr._tile_group.get_buttons():
		if (b as Button).text == "Road":
			(b as Button).button_pressed = true
			(b as Button).pressed.emit()
	cv.brush = 3
	cv.selected = -1
	cv.selection_changed.emit()
	wb.set_grid(true)
	wb.yaw = 150.0
	wb.set_pitch(50.0)
	wb.focus(Vector2(52, 30), 30.0)
	for i in 3:
		await get_tree().process_frame
	cv.begin_paint(Vector2i(40, 30))
	for x in range(41, 58):
		cv.paint_to(Vector2i(x, 30 - (x - 40) / 3))
		await get_tree().process_frame
	cv.end_paint()
	wb._hover_at(wb.screen_of(Vector3(57.5, wb.ground_y(57.5, 25.5), 25.5)))
	await _shot(out + "/wb_ground_paint.png")
	print("WB updates ", wb.tile_updates, " last ", wb.last_update_ms, " ms, builds ", wb.terrain_builds)
	get_tree().quit()
