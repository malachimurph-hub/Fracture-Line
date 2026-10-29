extends SceneTree
## Rasterises the Fracture Line: Modern Conflict icon SVGs (written by tools/gen_icon_lc.py) with Godot's
## SVG renderer into the PNGs that export_presets.cfg uses for the Android launcher icons.
## The monochrome layer is drawn white-on-black and converted to white + alpha here.
## Optional user arg: a folder for extra 512/192/96/48 previews.
func _init() -> void:
	var jobs := [["res://icon.svg", "res://assets/icons/lc_launcher_192.png", 192],
		["res://assets/icons/lc_adaptive_fg.svg", "res://assets/icons/lc_adaptive_fg_432.png", 432],
		["res://assets/icons/lc_adaptive_bg.svg", "res://assets/icons/lc_adaptive_bg_432.png", 432],
		["res://assets/icons/lc_adaptive_mono.svg", "res://assets/icons/lc_adaptive_mono_432.png", 432]]
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		for s in [512, 192, 96, 48]:
			jobs.append(["res://icon.svg", args[0].path_join("icon_%d.png" % s), s])
	for j in jobs:
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(j[0]), float(j[2]) / 128.0)
		if err != OK:
			push_error("svg %s: %d" % [j[0], err])
			continue
		if String(j[0]).contains("mono"):
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(1, 1, 1, c.a * c.get_luminance()))
		var out: String = j[1]
		img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
		print("ICON ", out, " ", img.get_size())
	quit()
