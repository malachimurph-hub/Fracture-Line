extends Node
## M2.8 screenshots: editor with the asset list open, skirmish lobby listing a custom map.
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/map_builder_shots.tscn -- <out_dir> --dpi=450

func _shot(path: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	get_tree().current_scene = null   # keep this driver alive across scene changes
	GameSession.goto("res://ui/map_builder.tscn")
	for i in 6:
		await get_tree().process_frame
	var scr: Node = get_tree().current_scene
	scr.new_map("Twin Rivers", Vector2i(256, 256), &"temperate")
	await get_tree().process_frame
	var cv: MapBuilderCanvas = scr.canvas
	cv.brush = 9
	for spec in [[SimMap.T.WATER, [Vector2i(0, 120), Vector2i(90, 132), Vector2i(170, 124), Vector2i(255, 136)]],
			[SimMap.T.FOREST, [Vector2i(40, 70), Vector2i(70, 90), Vector2i(60, 60)]],
			[SimMap.T.FOREST, [Vector2i(200, 180), Vector2i(220, 160)]],
			[SimMap.T.ROAD, [Vector2i(24, 24), Vector2i(128, 100), Vector2i(232, 232)]]]:
		cv.paint_t = spec[0]
		cv.brush = 9 if spec[0] != SimMap.T.ROAD else 3
		cv.paint(spec[1])
	cv.paint_t = SimMap.T.BRIDGE
	cv.brush = 5
	cv.paint([Vector2i(112, 118), Vector2i(112, 140)])
	cv.paint_t = SimMap.T.CLIFF
	cv.paint([Vector2i(150, 40), Vector2i(180, 70)])
	for p in [[Vector2i(22, 22), {"t": "spawn", "slot": 0}], [Vector2i(232, 232), {"t": "spawn", "slot": 1}],
			[Vector2i(36, 24), {"t": "res", "kind": "seam"}], [Vector2i(22, 38), {"t": "res", "kind": "cache"}],
			[Vector2i(218, 232), {"t": "res", "kind": "seam"}], [Vector2i(232, 216), {"t": "res", "kind": "cache"}],
			[Vector2i(128, 90), {"t": "neutral", "kind": "neutral_pump"}], [Vector2i(140, 160), {"t": "neutral", "kind": "neutral_civ_block"}],
			[Vector2i(44, 44), {"t": "pre", "kind": "us_lynx", "slot": 0}]]:
		cv.place_at(p[0], p[1])
	cv.zoom_at(cv.size * 0.3, 2.2)
	scr.show_tab("assets")
	await _shot(out + "/map_builder_editor_assets.png")
	scr.check_map()
	var ok: bool = scr.save_map()
	scr.close_overlay()
	print("saved ", ok, " ", cv.map_id)
	var mid := cv.map_id
	var cfg := SkirmishConfig.default_setup()
	cfg["map"] = mid
	GameSession.setup = cfg
	GameSession.goto("res://ui/skirmish_setup.tscn")
	for i in 6:
		await get_tree().process_frame
	var ls: Node = get_tree().current_scene
	ls.map_option.show_popup()
	await _shot(out + "/skirmish_list_custom_map.png")
	MapStore.delete(mid)
	get_tree().quit()
