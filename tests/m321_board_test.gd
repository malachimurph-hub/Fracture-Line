extends Node
## M3.2.1 regression (Malachi's bug: "entering vehicles / structures does not seem to work, at
## least as Russian"). For each of the 4 factions, through the REAL tap path (InputEventScreenTouch
## -> WorldInput -> PlayerController), with infantry selected:
##  A  5 infantry a few tiles away tap the transport body: they keep their selection (it must not
##     switch to the transport), get the board order and end up inside; the transport card shows
##     "Unload n / cap"; Unload puts them back on the ground
##  A2 1 infantry right next to the transport: same
##  B  tapping an own non-transport unit with infantry selected still selects that unit
##  C  own barricade: infantry man it, then step out
##  D  neutral civilian block and the new garrisonable house, tapped high on the walls (40 deg
##     camera): infantry garrison it, the building turns ours; Evacuate empties it
##   godot --headless --path . res://tests/m321_board_test.tscn
var m: Node
var sim: SimWorld
var fails := 0
var checks := 0

func _ready() -> void:
	Input.use_accumulated_input = false
	WorldInput.test_clock_ms = 100000
	var facs := ["us", "eu", "tpla", "ecc"]
	if OS.has_environment("M321_FACS"):
		facs = OS.get_environment("M321_FACS").split(",")
	for fac in facs:
		await _run_faction(fac)
	print("=== M321 BOARD RESULT: %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	get_tree().quit(0 if fails == 0 else 1)

func check(name: String, ok: bool, info = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", name, str(info)])

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _start(fac: String) -> void:
	if m != null:
		m.queue_free()
		await frames(2)
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = 321
	cfg["map"] = "harrow_junction"
	for i in 4:
		cfg["slots"][i]["kind"] = "closed"
	for i in 2:
		cfg["slots"][i]["kind"] = "human" if i == 0 else "ai"
		cfg["slots"][i]["faction"] = fac if i == 0 else ("us" if fac != "us" else "eu")
		cfg["slots"][i]["team"] = i
		cfg["slots"][i]["spawn"] = i
	cfg["options"]["fog"] = false
	GameSession.setup = cfg
	GameSession.resume_save = {}
	m = (load("res://match/match.tscn") as PackedScene).instantiate()
	add_child(m)
	await frames(3)
	sim = m.runner.sim
	m.runner.ais.clear()

func _ensure(e: SimEntity) -> void:
	m.world._ensure_view(e)
	if e.kind == SimEntity.Kind.UNIT:
		m.world.cur[e.id] = m.world._world_pos(e)
		m.world.prev[e.id] = m.world.cur[e.id]

func _adv(n: int) -> void:
	for i in n:
		m.runner.advance()
		var evs: Array = sim.events.duplicate()
		m.world.on_tick(evs)
		m.hud.on_events(evs)
	m.world.frame(1.0, 0.05)
	await frames(1)

func _unit(def: StringName, t: Vector2i) -> SimEntity:
	var tt := sim.map.nearest_passable(t, false)
	var u := sim.spawn_unit(def, 0, null, FX.tile_center(tt))
	u.pos = FX.tile_center(tt)
	u.home = u.pos
	_ensure(u)
	return u

## real finger tap at a world point (window pixels); far apart in time so it is never a double tap
func _tap_world(p: Vector3) -> void:
	WorldInput.test_clock_ms += 2000
	var sp: Vector2 = m.cam.cam.unproject_position(p) * float(UiScale.dp)
	if OS.has_environment("M321_DEBUG"):
		print("TAP ", p, " -> ", sp, " win ", get_window().size, " vp ", get_viewport().get_visible_rect().size, " dp ", UiScale.dp)
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = sp
		ev.pressed = pressed
		Input.parse_input_event(ev)
		WorldInput.test_clock_ms += 60
		await frames(2)

func _look(p: Vector3) -> void:
	m.cam.jump_to(p, false)
	m.cam.set_level(1)
	await frames(4)

func _inside(ids: Array, host: SimEntity) -> int:
	var n := 0
	for id in ids:
		var u: SimEntity = sim.ents.get(id)
		if u != null and u.alive and u.res_id == -host.id:
			n += 1
	return n

func _wait_inside(ids: Array, host: SimEntity, want: int, max_ticks := 600) -> int:
	var t := 0
	while t < max_ticks and _inside(ids, host) < want:
		await _adv(20)
		t += 20
	return _inside(ids, host)

func _card_has(text: String) -> String:
	for it in m.hud._make_card():
		if String(it.get("text", "")) == text:
			return String(it.get("sub", "-"))
	return ""

func _defs(fac: String) -> Dictionary:
	var inf: StringName = &""
	var tr_: StringName = &""
	var other: StringName = &""
	for id in Content.units.keys():
		var ud: UnitDef = Content.unit(id)
		if ud.faction != StringName(fac) or ud.stubs.size() > 0 and ud.stubs.has("all"):
			continue
		if ud.tags.has("infantry") and ud.tags.has("garrison") and not ud.tags.has("builder") and not ud.tags.has("squad"):
			if inf == &"" or String(id).contains("rpg"):
				inf = id
		elif ud.transport_capacity > 0 and ud.move_layer == &"vehicle" and (tr_ == &"" or String(id).contains("btr")):
			tr_ = id
		elif ud.move_layer == &"vehicle" and ud.transport_capacity == 0 and not ud.tags.has("builder") and other == &"":
			other = id
	var bar: StringName = &""
	for id in Content.buildings.keys():
		var bd: BuildingDef = Content.building(id)
		if bd.faction == StringName(fac) and bd.tags.has("barricade") and bd.garrison_capacity > 0:
			bar = id
	return {"inf": inf, "tr": tr_, "other": other, "bar": bar}

func _run_faction(fac: String) -> void:
	await _start(fac)
	var d := _defs(fac)
	print("--- ", fac, " ", d)
	var hq: SimEntity = null
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == 0 and e.kind == SimEntity.Kind.BUILDING:
			hq = e
	var c := hq.tile + Vector2i(10, 8)
	# ---- A: 5 infantry, tap the transport body
	var trn := _unit(d["tr"], c)
	var squad: Array = []
	for k in 5:
		squad.append(_unit(d["inf"], c + Vector2i(-4 + k % 3, 3 + k / 3)).id)
	await _adv(2)
	await _look(FX.to_world(trn.pos))
	m.ctl.set_selection(squad)
	var tv: EntityView = m.world.views[trn.id]
	await _tap_world(tv.position + Vector3(0, 0.35, 0))
	check("%s A: tap on %s keeps the infantry selected" % [fac, d["tr"]], m.ctl.selection == squad, m.ctl.selection)
	var ordered := 0
	for id in squad:
		if not sim.ents[id].orders.is_empty() and sim.ents[id].orders[0].get("o", "") == "garrison":
			ordered += 1
	check("%s A: board order given to all 5" % fac, ordered == 5, ordered)
	var n_in := await _wait_inside(squad, trn, 5)
	check("%s A: 5 %s inside the %s" % [fac, d["inf"], d["tr"]], n_in == 5, n_in)
	m.ctl.set_selection([trn.id])
	var sub := _card_has(tr("CMD_UNLOAD"))
	check("%s A: transport card shows Unload %s" % [fac, "5 / cap"], tr("CMD_UNLOAD") == "Unload" and sub.begins_with("5 / "), [tr("CMD_UNLOAD"), sub])
	m.ctl.issue({"t": "unload", "ids": [trn.id]})
	await _adv(4)
	check("%s A: Unload puts them back out" % fac, _inside(squad, trn) == 0, _inside(squad, trn))
	# ---- A2: one infantry right next to the transport
	await _adv(30)
	var solo := _unit(d["inf"], FX.to_tile(trn.pos) + Vector2i(1, 1))
	await _adv(2)
	m.ctl.set_selection([solo.id])
	tv = m.world.views[trn.id]
	await _tap_world(tv.position + Vector3(0, 0.35, 0))
	# (it may already be inside: boarded units drop out of the selection, as in ZH)
	check("%s A2: adjacent single infantry is not deselected for the transport" % fac, m.ctl.selection == [solo.id] or (m.ctl.selection.is_empty() and solo.res_id == -trn.id), [m.ctl.selection, solo.res_id])
	check("%s A2: adjacent single infantry boards" % fac, await _wait_inside([solo.id], trn, 1, 200) == 1)
	m.ctl.issue({"t": "unload", "ids": [trn.id]})
	await _adv(4)
	# ---- B: tapping an own non-transport unit still selects it
	if d["other"] != &"":
		var oth := _unit(d["other"], c + Vector2i(8, 0))
		await _adv(2)
		await _look(FX.to_world(oth.pos))
		m.ctl.set_selection(squad)
		await _tap_world(m.world.views[oth.id].position + Vector3(0, 0.3, 0))
		check("%s B: tap on own %s with infantry selected selects it" % [fac, d["other"]], m.ctl.selection == [oth.id], m.ctl.selection)
	# ---- C: own barricade
	var bt := c + Vector2i(0, 9)
	for r in 12:
		if sim.can_place(0, d["bar"], bt) == "":
			break
		bt += Vector2i(1, 0)
	var bar := sim._place_building(Content.building(d["bar"]), 0, bt, 0, true)
	_ensure(bar)
	# M3.5: one Combat Squad per barricade - two squads tapped onto it, one gets in
	var three: Array = [_unit(StringName(fac + "_squad"), c + Vector2i(-2, 7)).id, _unit(StringName(fac + "_squad"), c + Vector2i(2, 7)).id]
	await _adv(2)
	await _look(FX.to_world(bar.pos))
	m.ctl.set_selection(three)
	await _tap_world(m.world.views[bar.id].position + Vector3(0, 0.25, 0))
	var n_bar := await _wait_inside(three, bar, 1)
	await _adv(120)
	check("%s C: %s manned by one squad" % [fac, d["bar"]], n_bar == 1 and _inside(three, bar) == 1, _inside(three, bar))
	m.ctl.issue({"t": "unload", "ids": [bar.id]})
	await _adv(4)
	check("%s C: troops step out of the barricade" % fac, _inside(three, bar) == 0)
	# ---- D: neutral civilian block + garrisonable house (tap high on the walls)
	for kind in ["neutral_civ_block", "neutral_house"]:
		var nb: SimEntity = null
		for id in sim.ids:
			var e2: SimEntity = sim.ents[id]
			if e2.kind == SimEntity.Kind.NEUTRAL and String(e2.def_id).begins_with(kind) and e2.owner < 0 and (nb == null or FX.dist2(e2.pos, hq.pos) < FX.dist2(nb.pos, hq.pos)):
				nb = e2
		if nb == null:
			check("%s D: map has a %s" % [fac, kind], false)
			continue
		var grp: Array = []
		for k in 3:
			grp.append(_unit(d["inf"], nb.tile + Vector2i(k, nb.fp.y + 2)).id)
		await _adv(2)
		await _look(FX.to_world(nb.pos))
		m.ctl.set_selection(grp)
		var nv: EntityView = m.world.views[nb.id]
		var hgt: float = m.ctl._pick_height(nv)
		await _tap_world(nv.position + Vector3(0, hgt * 0.8, 0))   # on the upper wall / roof
		check("%s D: tap high on %s keeps the infantry selected" % [fac, nb.def_id], m.ctl.selection == grp, m.ctl.selection)
		var gin := await _wait_inside(grp, nb, 3)
		check("%s D: 3 infantry garrison %s, it turns ours" % [fac, nb.def_id], gin == 3 and nb.owner == 0, [gin, nb.owner])
		m.ctl.set_selection([nb.id])
		check("%s D: %s card shows Evacuate 3 / cap" % [fac, nb.def_id], _card_has(tr("HUD_EVACUATE")).begins_with("3 / "))
		m.ctl.issue({"t": "unload", "ids": [nb.id]})
		await _adv(4)
		check("%s D: Evacuate empties %s" % [fac, nb.def_id], _inside(grp, nb) == 0 and nb.owner < 0, [_inside(grp, nb), nb.owner])
