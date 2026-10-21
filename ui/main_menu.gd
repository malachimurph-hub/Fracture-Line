extends ScreenBase
## Main menu: Skirmish, Continue (suspended match), Settings, Credits/About, Quit.

func build() -> void:
	get_tree().set_auto_accept_quit(true)
	var h := HBoxContainer.new()
	body.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	left.add_child(UiTheme.label(tr("APP_TITLE"), 40, UiTheme.GOLD))
	left.add_child(UiTheme.label(tr("MENU_SUBTITLE"), 14, UiTheme.CYAN))
	left.add_child(UiTheme.label(tr("MENU_BUILD") % ProjectSettings.get_setting("application/config/version", "M1"), 11, Color(0.6, 0.6, 0.6)))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	var b := UiTheme.button(tr("MENU_SKIRMISH"), Vector2(260, 56))
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/skirmish_setup.tscn"))
	right.add_child(b)
	if SaveSystem.has_suspend():
		var c := UiTheme.button(tr("MENU_CONTINUE"), Vector2(260, 52))
		c.pressed.connect(_continue)
		right.add_child(c)
	var s := UiTheme.button(tr("MENU_SETTINGS"), Vector2(260, 52))
	s.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/settings_screen.tscn"))
	right.add_child(s)
	var cr := UiTheme.button(tr("MENU_CREDITS"), Vector2(260, 52))
	cr.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/credits.tscn"))
	right.add_child(cr)
	if not OS.has_feature("web"):
		var q := UiTheme.button(tr("MENU_QUIT"), Vector2(260, 52))
		q.pressed.connect(func(): get_tree().quit())
		right.add_child(q)

func _continue() -> void:
	var d := SaveSystem.load_suspend()
	if d.is_empty():
		SaveSystem.clear_suspend()
		get_tree().reload_current_scene()
		return
	GameSession.resume_save = d
	get_tree().change_scene_to_file("res://match/match.tscn")

func go_back() -> void:
	get_tree().quit()
