class_name TutorialDirector
extends Node
## M4.2 (item 2): narrated first battle. A guided easy 1v1 (US vs Iran, Varno Crossing): each step shows
## a text card on the HUD and plays the matching announcer line (announcer_us/tut_<step>_1.ogg).
## Steps advance on simple game-state checks; the flag Settings "tutorial_done" is set at the end or on skip.
const STEPS := ["welcome", "select", "power", "barracks", "train", "move", "attack"]
var match_node: Node
var step := -1
var _t := 0.0
var _wait := 0.0
var _pos0 := {}
var card: PanelContainer
var lbl: Label
var finished := false

static func setup_cfg() -> Dictionary:
	var cfg := SkirmishConfig.default_setup()
	cfg["map"] = "varno_crossing"
	cfg["tutorial"] = true
	cfg["options"]["start_money"] = 10000
	cfg["slots"][0].merge({"faction": "us", "spawn": 0, "team": 0}, true)
	cfg["slots"][1].merge({"faction": "tpla", "spawn": 2, "team": 1, "difficulty": "easy"}, true)
	return cfg

func _ready() -> void:
	var hud: Node = match_node.hud
	card = PanelContainer.new()
	card.name = "TutorialCard"
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GUNMETAL, UiTheme.GOLD, 2))
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.offset_top = 64
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	card.add_child(v)
	lbl = UiTheme.label("", 18, Color.WHITE)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(420, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
	var skip := UiTheme.button(tr("TUT_SKIP"), Vector2(160, 40))
	skip.name = "TutorialSkip"
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func(): _finish(false))
	v.add_child(skip)
	hud.root.add_child(card)
	_go(0)

func _go(i: int) -> void:
	step = i
	_t = 0.0
	var key: String = STEPS[i]
	lbl.text = tr("TUT_" + key.to_upper())
	AudioDirector.announce("tut_" + key)
	if key == "move":
		_pos0.clear()
		for u in _army():
			_pos0[u.id] = u.pos

func _sim():
	return match_node.runner.sim

func _mine(kind: int, def_id: String) -> bool:
	var s = _sim()
	for id in s.ids:
		var e: SimEntity = s.ents[id]
		if e.alive and e.owner == match_node.local_pid and e.kind == kind and String(e.def_id) == def_id:
			return true
	return false

func _army() -> Array:
	var s = _sim()
	var out := []
	for id in s.ids:
		var e: SimEntity = s.ents[id]
		if e.alive and e.owner == match_node.local_pid and e.kind == SimEntity.Kind.UNIT and not String(e.def_id) in ["us_dozer", "us_supply_truck"]:
			out.append(e)
	return out

## true when the current step's goal is met
func check() -> bool:
	match STEPS[step]:
		"welcome":
			return _t > 6.0
		"select":
			for id in match_node.ctl.selection:
				var e = _sim().ents.get(id)
				if e != null and String(e.def_id) == "us_dozer":
					return true
			return false
		"power":
			return _mine(SimEntity.Kind.BUILDING, "us_substation")
		"barracks":
			return _mine(SimEntity.Kind.BUILDING, "us_barracks")
		"train":
			return _army().size() >= 2
		"move":
			for u in _army():
				if _pos0.has(u.id) and (u.pos - _pos0[u.id]).length() > FX.ONE * 4:
					return true
			return false
	return false

func _process(delta: float) -> void:
	if finished or step < 0:
		return
	_t += delta
	var s = _sim()
	if s.game_over:
		if s.winner_team == s.player_team(match_node.local_pid):
			lbl.text = tr("TUT_DONE")
			AudioDirector.announce("tut_done")
		_finish(true)
		return
	_wait -= delta
	if step < STEPS.size() - 1 and _wait <= 0.0 and check():
		_wait = 1.5
		_go(step + 1)

func _finish(keep_card: bool) -> void:
	finished = true
	Settings.s("tutorial_done", true)
	if not keep_card and card != null:
		card.queue_free()
