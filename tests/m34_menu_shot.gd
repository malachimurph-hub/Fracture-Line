extends Node
## M3.4 main-menu shots: the live battle behind the menu, a day and a night clip, with the
## Campaign "Coming soon" entry. Also prints menu battle stats (units, shots fired, fps).
##   xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --resolution 2340x1080 \
##     --rendering-method mobile res://tests/m34_menu_shot.tscn -- <out_dir>
var out_dir := "/tmp/m34menu"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else out_dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	MainMenuScript().force_live = true
	for pass_i in 2:
		MenuBattle.force_map = &"ochre_wells" if pass_i == 0 else &"varno_crossing_night"
		MenuBattle.force_clip = 0 if pass_i == 0 else 1
		var menu: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
		add_child(menu)
		var t0 := Time.get_ticks_msec()
		while (menu.battle == null or menu.battle.building or menu.live.modulate.a < 0.99) and Time.get_ticks_msec() - t0 < 120000:
			await get_tree().process_frame
		if menu.battle == null:
			print("NO LIVE BATTLE (allowed=%s)" % MainMenuScript().live_allowed())
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var name := "menu_day" if pass_i == 0 else "menu_night"
		img.save_png(out_dir.path_join(name + ".png"))
		var b: MenuBattle = menu.battle
		print("SHOT %s night=%s units=%d shots=%d fps=%d map=%s camp=%s" % [name, b.night if b else false, b.unit_count() if b else 0, b.shots_seen if b else 0, Engine.get_frames_per_second(), b.runner.sim.map_id if b else &"", menu.find_child("CampaignSoon", true, false) != null])
		if b:
			var ps := []
			for pid in 2:
				for id in b._alive(pid):
					var wp := FX.to_world(b.runner.sim.get_ent(id).pos); ps.append("%d,%d" % [wp.x, wp.z])
			print("  clash=%s cam=%s units=%s" % [b._clash, b.cam.position, " ".join(ps)])
		menu.queue_free()
		for i in 5:
			await get_tree().process_frame
	print("=== M34 MENU SHOTS DONE")
	get_tree().quit(0)

func MainMenuScript():
	return load("res://ui/main_menu.gd")
