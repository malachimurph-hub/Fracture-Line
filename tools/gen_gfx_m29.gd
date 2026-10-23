extends SceneTree
## M2.9 TPLA models: godot --headless --path . -s res://tools/gen_gfx_m29.gd -- [names... | all]
## (tools/gfx_m29/build_m29.sh also bakes AO and the camo pass.)
func _initialize() -> void:
	load("res://tools/gfx_m29/tpla_m29.gd").build(Array(OS.get_cmdline_user_args()))
	print("gfx m29 views generated")
	quit(0)
