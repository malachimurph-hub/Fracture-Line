extends SceneTree
## M2.5 United States batch generator:  godot --headless --path . -s res://tools/gen_gfx_m5.gd
func _initialize() -> void:
	load("res://tools/gfx_m5/us_m5.gd").build_all()
	print("gfx m5 (US) views generated")
	quit(0)
