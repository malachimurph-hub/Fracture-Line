extends ScreenBase
## Post-match results: outcome, duration and per-player stats; back to the skirmish setup.

func build() -> void:
	var r: Dictionary = GameSession.last_result
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	var title := tr("RESULT_VICTORY") if r.get("won", false) else (tr("RESULT_DEFEAT") if int(r.get("local_pid", -1)) >= 0 else tr("RESULT_TEAM_WINS") % (int(r.get("winner_team", 0)) + 1))
	v.add_child(UiTheme.label(title, 34, UiTheme.GOLD))
	var secs := int(r.get("ticks", 0)) / 20
	v.add_child(UiTheme.label(tr("RESULT_DURATION") % [secs / 60, secs % 60], 14, UiTheme.CYAN))
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for k in ["RES_COL_PLAYER", "RES_COL_TEAM", "RES_COL_RANK", "RES_COL_BUILT", "RES_COL_LOST", "RES_COL_KILLS", "RES_COL_STRUCT", "RES_COL_HARVEST"]:
		g.add_child(UiTheme.label(tr(k), 12, Color(0.7, 0.7, 0.7)))
	for p in r.get("players", []):
		var st: Dictionary = p["stats"]
		var name := tr("LOBBY_YOU") if int(p["id"]) == int(r.get("local_pid", -1)) else tr("RES_AI") % [int(p["id"]) + 1, tr("DIFF_" + String(p.get("difficulty", "medium")).to_upper())]
		var lbl := UiTheme.label(name, 13, Palette.COLORS[int(p["color"])])
		g.add_child(lbl)
		g.add_child(UiTheme.label(str(int(p["team"]) + 1) + ("  ✓" if int(p["team"]) == int(r.get("winner_team", -9)) else ""), 13))
		g.add_child(UiTheme.label(str(p["rank"]), 13))
		g.add_child(UiTheme.label(str(st.get("built", 0)), 13))
		g.add_child(UiTheme.label(str(st.get("lost", 0)), 13))
		g.add_child(UiTheme.label(str(st.get("kills", 0)), 13))
		g.add_child(UiTheme.label(str(st.get("structures_killed", 0)), 13))
		g.add_child(UiTheme.label("$" + str(st.get("harvested", 0)), 13))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var again := UiTheme.button(tr("RESULT_BACK_SETUP"), Vector2(220, 54))
	again.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/skirmish_setup.tscn"))
	h.add_child(again)
	var menu := UiTheme.button(tr("RESULT_MENU"), Vector2(160, 54))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	h.add_child(menu)

func go_back() -> void:
	get_tree().change_scene_to_file("res://ui/skirmish_setup.tscn")
