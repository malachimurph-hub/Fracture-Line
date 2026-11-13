extends SceneTree
## One frame of the module card: three flat icons and their English labels.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 720x280 \
##     -s res://tools/m47/mzkt_ui_shot.gd -- /tmp/mzkt_card.png

func _initialize() -> void:
	var path := "/tmp/mzkt_card.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		path = args[0]
	var root_win := root as Window
	root_win.size = Vector2i(720, 280)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(36, 48)
	row.add_theme_constant_override("separation", 28)
	root.add_child(row)
	for spec in [["mzkt_aa", "CMD_MZKT_AA", "$800"], ["mzkt_radar", "CMD_MZKT_RADAR", "$1600"], ["mzkt_missile", "CMD_MZKT_MISSILE", "$1100"]]:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(180, 180)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.texture = CmdIcons.of(spec[0])
		icon.custom_minimum_size = Vector2(96, 96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(icon)
		var name_l := Label.new()
		name_l.text = TranslationServer.translate(spec[1])
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_l)
		var cost := Label.new()
		cost.text = spec[2]
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cost)
		row.add_child(col)
	for _i in 4:
		await process_frame
	# A -s script has no boot scene, so the startup guard paints an error panel
	# over the card. The card itself is what this shot is for.
	var overlay := root.find_child("ErrorOverlay", true, false)
	if overlay != null:
		overlay.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())
	quit(0)
