class_name PlayerController
extends Node
## Selection, control groups, smart commands and targeting modes for the local player.
## Turns intent from gestures/mouse/HUD into simulation Commands (MatchRunner.issue) - the
## same path the AI and replays use.

signal selection_changed
signal mode_changed
signal feedback(text: String)

enum Mode { NONE, PLACE, TARGET }

var runner: MatchRunner
var sim: SimWorld
var world: WorldView
var cam: CameraRig
var pid: int = 0
var selection: Array = []
var groups: Array = [[], [], [], [], []]
var mode: int = Mode.NONE
var target_kind: String = ""     ## amove | guard | rally | power:<id> | move | attack
## placement
var place_def: StringName = &""
var place_tile := Vector2i(-1, -1)
var place_rot: int = 0
var place_reason: String = ""
var place_builders: Array = []
var last_cycle: Dictionary = {}  ## pick cycling: {pos, ids, i}

func setup(r: MatchRunner, w: WorldView, c: CameraRig, p: int) -> void:
	runner = r
	sim = r.sim
	world = w
	cam = c
	pid = p

func is_observer() -> bool:
	return pid < 0

# ---------------------------------------------------------------- picking
func screen_of(e: SimEntity) -> Vector2:
	var v: EntityView = world.views.get(e.id)
	var p: Vector3 = v.position if v != null else FX.to_world(e.pos)
	return cam.cam.unproject_position(p + Vector3(0, 0.3, 0))

func screen_radius(e: SimEntity) -> float:
	var v: EntityView = world.views.get(e.id)
	var r := v.selection_radius if v != null else 0.6
	if e.kind != SimEntity.Kind.UNIT:
		r = maxf(float(e.fp.x), float(e.fp.y)) * 0.5
	var p := FX.to_world(e.pos)
	var a := cam.cam.unproject_position(p)
	var b := cam.cam.unproject_position(p + cam.cam.global_transform.basis.x * r)
	return a.distance_to(b)

func _view_visible(e: SimEntity) -> bool:
	var v: EntityView = world.views.get(e.id)
	return v != null and v.visible

## Returns entities under a screen point, nearest first. Tap targets are at least 48 dp
## (24 dp radius) per GDD 6.2 - the screen point is in viewport pixels.
func pick_all(screen: Vector2) -> Array:
	var px_per_dp := float(get_viewport().get_visible_rect().size.y) / maxf(1.0, UiScale.logical_size().y)
	var min_r := 24.0 * px_per_dp
	var out: Array = []
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if not _view_visible(e):
			continue
		var sp := screen_of(e)
		var r := maxf(min_r, screen_radius(e))
		if e.kind != SimEntity.Kind.UNIT:
			# structures: use the projected footprint rather than a circle
			if _in_footprint(e, screen):
				out.append([0.0 + 1.0, e.id])
			continue
		var d := sp.distance_to(screen)
		if d <= r:
			out.append([d / r, e.id])
	out.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var ids: Array = []
	for o in out:
		ids.append(o[1])
	return ids

func _in_footprint(e: SimEntity, screen: Vector2) -> bool:
	var g := cam.ground_point(screen)
	var t0 := Vector2(e.tile)
	return g.x >= t0.x - 0.25 and g.z >= t0.y - 0.25 and g.x <= t0.x + e.fp.x + 0.25 and g.z <= t0.y + e.fp.y + 0.25

## Single best pick, preferring units over structures under the same finger and cycling
## through overlapping candidates on repeated taps at the same spot (GDD 6.4).
func pick(screen: Vector2, cycle: bool = false) -> int:
	var ids := pick_all(screen)
	if ids.is_empty():
		return 0
	ids.sort_custom(func(a, b):
		var ea: SimEntity = sim.ents[a]
		var eb: SimEntity = sim.ents[b]
		var ua := 0 if ea.kind == SimEntity.Kind.UNIT else 1
		var ub := 0 if eb.kind == SimEntity.Kind.UNIT else 1
		if ua != ub:
			return ua < ub
		return ids.find(a) < ids.find(b))
	if cycle and last_cycle.get("pos", Vector2(-999, -999)).distance_to(screen) < 20.0 and last_cycle.get("ids", []) == ids:
		last_cycle["i"] = (int(last_cycle["i"]) + 1) % ids.size()
	else:
		last_cycle = {"pos": screen, "ids": ids, "i": 0}
	return ids[int(last_cycle["i"])]

func overlap_count() -> int:
	return (last_cycle.get("ids", []) as Array).size()

# ---------------------------------------------------------------- selection
func set_selection(ids: Array) -> void:
	var clean: Array = []
	for id in ids:
		var e := sim.get_ent(id)
		if e != null and e.alive and not (id in clean):
			clean.append(id)
	selection = clean
	world.set_selection(selection)
	selection_changed.emit()

func prune() -> void:
	var before := selection.size()
	var keep: Array = []
	for id in selection:
		var e := sim.get_ent(id)
		if e != null and e.alive and e.res_id >= 0 and (e.owner == pid or not is_own(e) and _view_visible(e)):
			keep.append(id)
	if keep.size() != before:
		set_selection(keep)
	for g in groups:
		var gi := 0
		while gi < g.size():
			var ge := sim.get_ent(g[gi])
			if ge == null or not ge.alive:
				g.remove_at(gi)
			else:
				gi += 1

func is_own(e: SimEntity) -> bool:
	return e != null and e.owner == pid and pid >= 0

func own_units_selected() -> Array:
	var out: Array = []
	for id in selection:
		var e := sim.get_ent(id)
		if is_own(e) and e.kind == SimEntity.Kind.UNIT:
			out.append(id)
	return out

func selected_buildings() -> Array:
	var out: Array = []
	for id in selection:
		var e := sim.get_ent(id)
		if is_own(e) and e.kind != SimEntity.Kind.UNIT:
			out.append(id)
	return out

func primary() -> SimEntity:
	return sim.get_ent(selection[0]) if not selection.is_empty() else null

func select_at(screen: Vector2, add: bool = false) -> bool:
	var id := pick(screen, true)
	if id == 0:
		return false
	var e := sim.get_ent(id)
	if add and is_own(e) and e.kind == SimEntity.Kind.UNIT:
		var s := selection.duplicate()
		if id in s:
			s.erase(id)
		else:
			s.append(id)
		set_selection(s)
	else:
		set_selection([id])
	return true

func select_same_type(screen: Vector2) -> void:
	var id := pick(screen)
	var e := sim.get_ent(id)
	if e == null or not is_own(e):
		return
	var vp := get_viewport().get_visible_rect()
	var out: Array = []
	for oid in sim.ids:
		var o: SimEntity = sim.ents[oid]
		if o.owner == pid and o.def_id == e.def_id and o.res_id >= 0 and vp.has_point(screen_of(o)):
			out.append(oid)
	set_selection(out)

## Box select own units (structures only if no units). Builders/harvesters are dropped
## when combat units are also in the box (keeps army boxes clean, like ZH).
func box_select(r: Rect2, add: bool = false) -> void:
	r = r.abs()
	var units: Array = []
	var combat: Array = []
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner != pid or e.kind != SimEntity.Kind.UNIT or e.res_id < 0:
			continue
		if r.has_point(screen_of(e)):
			units.append(id)
			var tags := Content.unit(e.def_id).tags
			if not tags.has("builder") and not tags.has("harvester"):
				combat.append(id)
	var pickd: Array = combat if not combat.is_empty() else units
	if add:
		pickd = selection + pickd
	set_selection(pickd)

func select_all_army() -> void:
	var out: Array = []
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == pid and e.kind == SimEntity.Kind.UNIT and e.res_id >= 0:
			var tags := Content.unit(e.def_id).tags
			if not tags.has("builder") and not tags.has("harvester"):
				out.append(id)
	set_selection(out)

func select_idle_builder() -> void:
	var best := 0
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner == pid and e.kind == SimEntity.Kind.UNIT and Content.unit(e.def_id).tags.has("builder"):
			if best == 0 or e.orders.is_empty():
				best = id
				if e.orders.is_empty():
					break
	if best != 0:
		set_selection([best])
		cam.jump_to(FX.to_world(sim.ents[best].pos))

func group_assign(i: int) -> void:
	groups[i] = own_units_selected()
	feedback.emit(tr("HUD_GROUP_SET") % (i + 1))

func group_select(i: int) -> bool:
	var g: Array = groups[i]
	if g.is_empty():
		return false
	if selection == g:
		# second press jumps the camera to the group
		var e := sim.get_ent(g[0])
		if e != null:
			cam.jump_to(FX.to_world(e.pos))
	set_selection(g.duplicate())
	return true

# ---------------------------------------------------------------- commands
func issue(c: Dictionary) -> void:
	if is_observer():
		return
	c["p"] = pid
	runner.issue(c)

func _queue_flag() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

## Context-sensitive order at a screen point (tap with a selection, right click).
func smart_command(screen: Vector2) -> void:
	var units := own_units_selected()
	var g := cam.ground_point(screen)
	var pos := FX.from_world(g)
	if units.is_empty():
		var blds := selected_buildings()
		if not blds.is_empty():
			_set_rally(blds, pos)
		return
	var tid := pick(screen)
	var t := sim.get_ent(tid)
	var q := _queue_flag()
	if t != null and t.owner != pid:
		if t.kind == SimEntity.Kind.RESOURCE:
			var hv := _filter(units, "harvester")
			if not hv.is_empty():
				issue({"t": "harvest", "ids": hv, "target": t.id})
				world.marker(t.pos, Color("#7dff8a"))
				units = _minus(units, hv)
		elif t.kind == SimEntity.Kind.NEUTRAL and t.team >= 0 and sim.enemies(t.team, sim.player_team(pid)):
			issue({"t": "attack", "ids": units, "target": t.id, "q": q})
			world.marker(t.pos, Color("#ff4a3d"))
			return
		elif t.kind == SimEntity.Kind.NEUTRAL:
			var bd := Content.building(t.def_id)
			if bd.garrison_capacity > 0:
				var gi := _filter(units, "garrison")
				if not gi.is_empty():
					issue({"t": "garrison", "ids": gi, "target": t.id, "q": q})
					world.marker(t.pos, Color("#7dff8a"))
					units = _minus(units, gi)
			elif bd.capturable and t.owner != pid:
				var cap: Array = []
				for id in units:
					var tg := Content.unit(sim.ents[id].def_id).tags
					if tg.has("builder") or tg.has("infantry"):
						cap.append(id)
				if not cap.is_empty():
					issue({"t": "capture", "ids": cap, "target": t.id, "q": q})
					world.marker(t.pos, Color("#7dff8a"))
					units = _minus(units, cap)
		elif t.team >= 0 and sim.enemies(t.team, sim.player_team(pid)):
			issue({"t": "attack", "ids": units, "target": t.id, "q": q})
			world.marker(t.pos, Color("#ff4a3d"))
			return
	elif t != null and t.kind == SimEntity.Kind.BUILDING and not t.built:
		var b := _filter(units, "builder")
		if not b.is_empty():
			issue({"t": "resume_build", "ids": b, "target": t.id, "q": q})
			world.marker(t.pos, Color("#7dff8a"))
			units = _minus(units, b)
	elif t != null and t.kind == SimEntity.Kind.BUILDING and Content.building(t.def_id).is_refinery:
		var hv2 := _filter(units, "harvester")
		if not hv2.is_empty():
			issue({"t": "harvest", "ids": hv2, "target": _nearest_resource(t.pos)})
			units = _minus(units, hv2)
	if units.is_empty():
		return
	issue({"t": "move", "ids": units, "pos": pos, "q": q})
	world.marker(pos, Color("#7dff8a"))

func _nearest_resource(p: Vector2i) -> int:
	var best := 0
	var bd := 1 << 62
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.kind == SimEntity.Kind.RESOURCE and e.amount > 0:
			var d := FX.dist2(e.pos, p)
			if d < bd:
				bd = d
				best = id
	return best

func _filter(ids: Array, tag: String) -> Array:
	var out: Array = []
	for id in ids:
		if Content.unit(sim.ents[id].def_id).tags.has(tag):
			out.append(id)
	return out

func _minus(a: Array, b: Array) -> Array:
	var out: Array = []
	for x in a:
		if not (x in b):
			out.append(x)
	return out

func attack_move(screen: Vector2) -> void:
	var units := own_units_selected()
	if units.is_empty():
		return
	var pos := FX.from_world(cam.ground_point(screen))
	issue({"t": "amove", "ids": units, "pos": pos, "q": _queue_flag()})
	world.marker(pos, Color("#ff9a2a"))

func simple(kind: String) -> void:
	var units := own_units_selected()
	if units.is_empty():
		return
	issue({"t": kind, "ids": units})

func _set_rally(blds: Array, pos: Vector2i, attack: bool = false) -> void:
	issue({"t": "rally", "ids": blds, "pos": pos, "flag": attack})
	world.marker(pos, Color("#ffd166"))

## Enter a targeting mode: the next tap/click supplies the location.
func begin_target(kind: String) -> void:
	cancel_mode()
	mode = Mode.TARGET
	target_kind = kind
	mode_changed.emit()

func complete_target(screen: Vector2) -> void:
	var g := cam.ground_point(screen)
	var pos := FX.from_world(g)
	var k := target_kind
	if k == "amove":
		attack_move(screen)
	elif k == "guard":
		issue({"t": "guard", "ids": own_units_selected(), "pos": pos})
		world.marker(pos, Color("#6fe3ff"))
	elif k == "move":
		issue({"t": "move", "ids": own_units_selected(), "pos": pos, "q": _queue_flag()})
		world.marker(pos, Color("#7dff8a"))
	elif k == "rally":
		_set_rally(selected_buildings(), pos)
	elif k.begins_with("power:"):
		issue({"t": "power", "def": k.substr(6), "pos": pos})
	if not (_queue_flag() and k in ["amove", "move"]):
		cancel_mode()

func cancel_mode() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	target_kind = ""
	place_def = &""
	world.hide_ghost()
	mode_changed.emit()

# ---------------------------------------------------------------- placement
func begin_place(def_id: StringName) -> void:
	var builders := _filter(own_units_selected(), "builder")
	if builders.is_empty():
		feedback.emit(tr("REASON_NO_BUILDER"))
		return
	cancel_mode()
	mode = Mode.PLACE
	place_def = def_id
	place_builders = builders
	# start the ghost near the builder, nudged toward the screen center
	var b: SimEntity = sim.ents[builders[0]]
	var c := cam.ground_point(get_viewport().get_visible_rect().size * Vector2(0.5, 0.42))
	var bt := FX.to_tile(b.pos)
	var ct := Vector2i(int(c.x), int(c.z))
	var start := ct if Vector2(ct).distance_to(Vector2(bt)) < 14 else bt + Vector2i(3, 0)
	move_ghost_tile(start)
	mode_changed.emit()

func move_ghost_screen(screen: Vector2) -> void:
	var g := cam.ground_point(screen)
	var d := Content.building(place_def)
	var fpv := d.footprint if place_rot % 2 == 0 else Vector2i(d.footprint.y, d.footprint.x)
	move_ghost_tile(Vector2i(roundi(g.x - fpv.x * 0.5), roundi(g.z - fpv.y * 0.5)))

func move_ghost_tile(t: Vector2i) -> void:
	place_tile = t
	_revalidate()

func _revalidate() -> void:
	place_reason = sim.can_place(pid, place_def, place_tile)
	world.show_ghost(place_def, place_tile, place_rot, place_reason == "", pid)
	mode_changed.emit()

func rotate_ghost() -> void:
	place_rot = (place_rot + 1) % 4
	_revalidate()

func confirm_place() -> bool:
	_revalidate()
	if place_reason != "":
		feedback.emit(tr(place_reason))
		return false
	issue({"t": "place", "ids": place_builders, "def": place_def, "tile": place_tile, "rot": place_rot, "q": _queue_flag()})
	world.marker(FX.tile_center(place_tile + Content.building(place_def).footprint / 2), Color("#7dff8a"))
	if Settings.g("haptics"):
		Input.vibrate_handheld(20)
	cancel_mode()
	return true

# ---------------------------------------------------------------- production
func queue_unit(b: SimEntity, uid: StringName, n: int = 1) -> void:
	issue({"t": "queue", "target": b.id, "def": uid, "n": n})

func dequeue(b: SimEntity, i: int = -1) -> void:
	issue({"t": "dequeue", "target": b.id, "n": i})
