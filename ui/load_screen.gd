extends ScreenBase
## M3.3: load a manual save slot (8 slots, newest time stamp first is not forced - slots keep
## their numbers). A slot that fails its check says so instead of loading.

func build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := UiTheme.button("‹ " + tr("BACK"), Vector2(80, 44))
	back.pressed.connect(go_back)
	head.add_child(back)
	head.add_child(UiTheme.label("  " + tr("LOAD_TITLE"), 22, UiTheme.GOLD))
	var g := GridContainer.new()
	g.name = "Slots"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for e: Dictionary in SaveSystem.list_slots():
		var i := int(e["slot"])
		var head_t := tr("SAVE_SLOT") % (i + 1)
		var b := UiTheme.button(head_t + "  -  " + tr("SAVE_EMPTY") if e["empty"] else head_t + "  " + SaveSystem.stamp(float(e["saved_at"])) + "\n" + String(e["label"]), Vector2(300, 52))
		b.name = "Slot%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		b.disabled = e["empty"]
		b.pressed.connect(func(): _load(i, b))
		g.add_child(b)

func _load(i: int, b: Button) -> void:
	var d := SaveSystem.load_slot(i)
	if d.is_empty():
		b.text = tr("SAVE_SLOT") % (i + 1) + "  -  " + tr("LOAD_BAD")
		b.disabled = true
		return
	GameSession.resume_save = d
	GameSession.goto_with_loading("res://match/match.tscn", tr("LOADING_BATTLE"))

func go_back() -> void:
	GameSession.goto("res://ui/main_menu.tscn")
