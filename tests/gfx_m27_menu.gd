extends Node
## M2.7 graphics pass: captures each cinematic shot of the main-menu background battle.
##   godot --path . --resolution 2340x1080 res://tests/gfx_m27_menu.tscn -- <out_dir> [prefix]

var out_dir := "/tmp"
var prefix := "menu"

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	if a.size() > 1:
		prefix = a[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var mm: Node = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(mm)
	var bg: Node = null
	while bg == null:
		await get_tree().process_frame
		bg = mm.find_child("MenuBattle", true, false)
	# let the armies meet (~20 s of game time; software rendering is slow, so count ticks)
	var t0: int = bg.runner.sim.tick
	var waited := 0
	while bg.runner.sim.tick < t0 + 400 and waited < 4000:
		await get_tree().process_frame
		waited += 1
	for s in 4:
		bg._shot = s
		bg._shot_t = bg.SHOT_SECONDS * 0.5
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := out_dir.path_join("%s_shot%d.png" % [prefix, s])
		img.save_png(p)
		var us: Array = []
		for pid in 2:
			for id in bg._alive(pid):
				us.append(FX.to_world(bg.runner.sim.get_ent(id).pos))
		var bl := 0
		for id in bg.runner.sim.ids:
			if bg.runner.sim.ents[id].kind == SimEntity.Kind.BUILDING and bg.runner.sim.ents[id].owner >= 0:
				bl += 1
				if s == 0:
					print("  BLD ", bg.runner.sim.ents[id].def_id, " ", bg.runner.sim.ents[id].tile, " owner ", bg.runner.sim.ents[id].owner)
		var kinds: Array = []
		for pid in 2:
			for id in bg._alive(pid):
				var vv = bg.world.views.get(id)
				kinds.append("%s:%s" % [bg.runner.sim.get_ent(id).def_id, (vv.scene_file_path.get_file() if vv != null else "none")])
		print("UNITS ", kinds, " subject ", bg._subject, " nviews ", bg.world.views.size(), " keys ", bg.world.views.keys().slice(0, 6), " alive ", bg._alive(0).slice(0, 4))
		print("SHOT ", p, " map ", bg.runner.sim.map_id, " look ", bg._look, " eye ", bg.cam.cam.global_position, " bases ", bg._bases, " units ", us.size(), " ", us.slice(0, 4), " owned bld ", bl)
	get_tree().quit(0)
