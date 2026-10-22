extends SceneTree
## M2.4 roster batch generator:  godot --headless --path . -s res://tools/gen_gfx_m4.gd
## Writes the view scenes for the new ZH-1:1 roster vehicles and structures.
func _initialize() -> void:
	var vk = load("res://tools/gfx_m4/vehicles_m4.gd")
	if vk != null:
		vk.build_all()
	if FileAccess.file_exists("res://tools/gfx_m4/buildings_m4.gd"):
		load("res://tools/gfx_m4/buildings_m4.gd").build_all()
	print("gfx m4 views generated")
	quit(0)
