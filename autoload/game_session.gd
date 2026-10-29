extends Node
## Holds the skirmish setup between the lobby, the match and the results screen, and owns
## safe scene changes: a scene that fails to load or whose scripts fail to compile shows an
## on-screen error panel (with a "Copy error log" button) instead of a blank screen.
var setup: Dictionary = {}       ## see ui/skirmish_setup.gd default_setup()
var last_result: Dictionary = {}
var resume_save: Dictionary = {} ## set when continuing a suspended match

const MAIN_MENU := "res://ui/main_menu.tscn"
const ERROR_LOG_PATH := "user://last_error.txt"

## M3.0.1: heavy scene changes (a match) show a "Loading battle" screen first and wait a few
## frames so it is on screen before the main thread is busy; repeated taps are ignored meanwhile.
var _loading: CanvasLayer = null
var busy := false

func goto_with_loading(path: String, text: String) -> void:
	if busy:
		return
	busy = true
	_loading = CanvasLayer.new()
	_loading.layer = 90
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.045, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading.add_child(bg)
	var l := UiTheme.label(text, 22, UiTheme.GOLD)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.add_child(l)
	add_child(_loading)
	for i in 3:   # a frame is drawn between process frames
		await get_tree().process_frame
	goto(path)
	# keep it up until the new scene has drawn its first frames
	await get_tree().process_frame
	await get_tree().process_frame
	if _loading != null:
		_loading.queue_free()
		_loading = null
	busy = false

var logger := FLLogger.new()
var _overlay: CanvasLayer = null
var last_error_text := ""

func _init() -> void:
	OS.add_logger(logger)

func _ready() -> void:
	# Verification builds (export preset "LinuxVerify", same stripped engine profile as the
	# Android template) boot straight into the headless test runner, unless the UI flow
	# test was requested (--fl-ui-test).
	if OS.has_feature("fl_verify"):
		var ui_test := "--fl-ui-test" in OS.get_cmdline_user_args() or "--fl-ui-test" in OS.get_cmdline_args()
		if not ui_test:
			get_tree().change_scene_to_file.call_deferred("res://tests/test_runner.tscn")
		else:
			var t: Node = load("res://tests/ui_flow_test.gd").new()
			t.name = "UiFlowTest"
			add_child.call_deferred(t)
	_check_startup.call_deferred()

## The boot scene is loaded by the engine; if its script failed, show the panel too.
func _check_startup() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		fail("The start screen did not load.")
	elif cs.get_script() != null and not (cs.get_script() as Script).can_instantiate():
		fail("The start screen's script failed to compile.")

## Safe replacement for SceneTree.change_scene_to_file(). Returns true on success.
func goto(path: String) -> bool:
	if not ResourceLoader.exists(path):
		fail("Scene not found in this build: %s" % path)
		return false
	var res: Resource = ResourceLoader.load(path)
	if res == null or not (res is PackedScene):
		fail("Could not load scene: %s" % path)
		return false
	var bad := broken_scripts(res as PackedScene)
	for b in broken_dependencies(path):
		if not b in bad:
			bad.append(b)
	if not bad.is_empty():
		fail("Scene %s has scripts that failed to compile:\n  %s" % [path, "\n  ".join(bad)])
		return false
	var err := get_tree().change_scene_to_packed(res as PackedScene)
	if err != OK:
		fail("Could not open scene %s (error %d: %s)" % [path, err, error_string(err)])
		return false
	_hide_overlay()
	return true

## Scripts attached anywhere in a packed scene that cannot be instantiated (parse/compile
## failure, missing engine API...). Empty when the scene is fine.
static func broken_scripts(ps: PackedScene) -> PackedStringArray:
	var out := PackedStringArray()
	var st := ps.get_state()
	for n in st.get_node_count():
		for p in st.get_node_property_count(n):
			if st.get_node_property_name(n, p) == &"script":
				var s: Variant = st.get_node_property_value(n, p)
				if s is Script and not (s as Script).can_instantiate() and not (s as Script).resource_path in out:
					out.append((s as Script).resource_path)
		var inst: PackedScene = st.get_node_instance(n)
		if inst != null:
			out.append_array(broken_scripts(inst))
	return out

## Script dependencies of a scene file (recursing into sub-scenes) that fail to load or
## compile. A script with a parse error makes its ext_resource load as null, so the scene
## itself still "loads" - as an empty node, i.e. a blank screen - unless checked here.
static func broken_dependencies(path: String, seen: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	if seen.has(path):
		return out
	seen[path] = true
	for dep in ResourceLoader.get_dependencies(path):
		var p: String = dep.get_slice("::", 2) if dep.contains("::") else dep
		if p.is_empty():
			p = dep.get_slice("::", 0)
		if p.begins_with("uid://"):
			var id := ResourceUID.text_to_id(p)
			p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else p
		if p.ends_with(".gd"):
			var sc: Script = load(p) as Script
			if sc == null or not sc.can_instantiate():
				out.append(p)
		elif p.ends_with(".tscn") or p.ends_with(".scn"):
			out.append_array(broken_dependencies(p, seen))
	return out

func error_log_text() -> String:
	return "FRACTURE LINE: MODERN CONFLICT %s (%s, %s)\n%s\n\nRecent errors:\n%s" % [
		ProjectSettings.get_setting("application/config/version", "?"), OS.get_name(),
		RenderingServer.get_current_rendering_method(), last_error_text, logger.text(60)]

func fail(message: String) -> void:
	last_error_text = message
	push_error("FRACTURE LINE: " + message)
	var f := FileAccess.open(ERROR_LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(error_log_text())
		f.close()
	_show_overlay(message)

func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

func _show_overlay(message: String) -> void:
	_hide_overlay()
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	_overlay.name = "ErrorOverlay"
	add_child(_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	bg.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var title := Label.new()
	title.text = "Something went wrong"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	v.add_child(title)
	var details := TextEdit.new()
	details.text = message + "\n\n" + logger.text(25)
	details.editable = false
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("font_size", 13)
	v.add_child(details)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var copy := Button.new()
	copy.text = "Copy error log"
	copy.custom_minimum_size = Vector2(200, 52)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(error_log_text())
		copy.text = "Copied to clipboard")
	row.add_child(copy)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.custom_minimum_size = Vector2(200, 52)
	menu.pressed.connect(func():
		_hide_overlay()
		if not message.contains(MAIN_MENU) and goto(MAIN_MENU):
			return
		get_tree().quit())
	row.add_child(menu)
	var note := Label.new()
	note.text = "Saved to " + ProjectSettings.globalize_path(ERROR_LOG_PATH)
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row.add_child(note)
