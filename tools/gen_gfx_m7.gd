extends SceneTree
## M2.7 detail pass:  godot --headless --path . -s res://tools/gen_gfx_m7.gd -- [names...]
## then bake AO:      godot --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- <scenes>
## (tools/gfx_m7/build_m7.sh runs both.) Names: us_reactor, us_command, ... or "all".
func _initialize() -> void:
	var only := Array(OS.get_cmdline_user_args())
	load("res://tools/gfx_m7/us_m7.gd").build(only)
	print("gfx m7 views generated")
	quit(0)
