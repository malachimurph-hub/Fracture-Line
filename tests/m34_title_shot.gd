## M3.4: screenshot of the title / main menu (the emblem logo over the key art).
##   godot --path . --resolution 2340x1080 --rendering-method mobile -s res://tests/m34_title_shot.gd -- <out.png>
extends SceneTree

func _initialize() -> void:
	var out := "/tmp/title.png"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	# instanced and made current right away (GameSession checks for a current scene at boot)
	var menu: Node = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 90:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("title shot -> ", out, " ", img.get_size())
	quit()
