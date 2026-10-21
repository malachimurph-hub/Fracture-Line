extends Node
## Holds the skirmish setup between the lobby, the match and the results screen.
var setup: Dictionary = {}       ## see ui/skirmish_setup.gd default_setup()
var last_result: Dictionary = {}
var resume_save: Dictionary = {} ## set when continuing a suspended match

func _ready() -> void:
	# Verification builds (export preset "LinuxVerify", same stripped engine profile as the
	# Android template) boot straight into the headless test runner.
	if OS.has_feature("fl_verify"):
		get_tree().change_scene_to_file.call_deferred("res://tests/test_runner.tscn")
