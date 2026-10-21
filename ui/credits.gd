extends ScreenBase
## Credits / About, including the Godot Engine MIT license notice.

func build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := UiTheme.button("‹ " + tr("BACK"), Vector2(80, 44))
	back.pressed.connect(go_back)
	head.add_child(back)
	head.add_child(UiTheme.label("  " + tr("MENU_CREDITS"), 22, UiTheme.GOLD))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var t := Label.new()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(UiScale.logical_size().x - 60, 0)
	t.add_theme_font_size_override("font_size", 12)
	var info := Engine.get_version_info()
	t.text = tr("CREDITS_BODY") + "\n\n" + tr("CREDITS_ENGINE") % info["string"] + "\n\n" + Engine.get_license_text()
	sc.add_child(t)

func go_back() -> void:
	GameSession.goto("res://ui/main_menu.tscn")
