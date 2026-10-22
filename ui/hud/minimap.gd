class_name Minimap
extends Control
## Bottom-left minimap: terrain, shroud/fog, visible units and structures, camera frame.
## Tap = jump, drag = scrub, long-press = order the selection to move there (GDD 6.3).

var world: WorldView
var cam: CameraRig
var ctl: PlayerController
var base_tex: ImageTexture
var fog_img: Image
var fog_tex: ImageTexture
var fog_ver: int = -1
var _down: bool = false
var _down_ms: int = 0
var _down_pos := Vector2.ZERO
var _long_done: bool = false
var _redraw_t: float = 0.0
var pings: Array = []   ## [{p: Vector2 tile, t}]
## M2.5 (ZH-style): every supply seam / pile is marked on the minimap from the start (map
## knowledge, like Zero Hour's radar) with its own icon drawn above the shroud. Its fill level is
## what this player last saw: it dims as the pile empties and disappears once seen depleted.
var res_known: Dictionary = {}   ## resource id -> last seen fraction (1.0 = full, never seen)

func setup(w: WorldView, c: CameraRig, p: PlayerController) -> void:
	world = w
	cam = c
	ctl = p
	var m := w.sim.map
	var img := Image.create_empty(m.w, m.h, false, Image.FORMAT_RGB8)
	for y in m.h:
		for x in m.w:
			img.set_pixel(x, y, TerrainView.minimap_color(m.ttype(Vector2i(x, y))))
	base_tex = ImageTexture.create_from_image(img)
	fog_img = Image.create_empty(m.w, m.h, false, Image.FORMAT_RGBA8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	mouse_filter = Control.MOUSE_FILTER_STOP

func ping(tile: Vector2) -> void:
	pings.append({"p": tile, "t": 0.0})

func _process(delta: float) -> void:
	if world == null:
		return
	var sim := world.sim
	if sim.fog.version != fog_ver:
		fog_ver = sim.fog.version
		_update_fog()
	if _down and not _long_done and Time.get_ticks_msec() - _down_ms > 500 and _down_pos.distance_to(get_local_mouse_position()) < 10:
		_long_done = true
		if not ctl.own_units_selected().is_empty():
			var t := _to_tile(_down_pos)
			ctl.issue({"t": "move", "ids": ctl.own_units_selected(), "pos": FX.from_world(Vector3(t.x, 0, t.y))})
			ping(t)
			if Settings.g("haptics"):
				Input.vibrate_handheld(15)
	for p in pings:
		p["t"] += delta
	pings = pings.filter(func(p): return p["t"] < 2.0)
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.1
		queue_redraw()

func _update_fog() -> void:
	var sim := world.sim
	var team := world.local_team
	if team < 0 or sim.fog.disabled:
		fog_img.fill(Color(0, 0, 0, 0))
	else:
		var vis: PackedInt32Array = sim.fog.count[team]
		var exp: PackedByteArray = sim.fog.explored[team]
		var w := sim.map.w
		for y in sim.map.h:
			for x in w:
				var i := y * w + x
				if vis[i] > 0:
					fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
				elif exp[i] > 0:
					fog_img.set_pixel(x, y, Color(0, 0, 0, 0.5))
				else:
					fog_img.set_pixel(x, y, Color(0, 0, 0, 1))
	fog_tex.update(fog_img)

func _scale() -> Vector2:
	return size / Vector2(world.sim.map.w, world.sim.map.h)

func _to_tile(local: Vector2) -> Vector2:
	return (local / _scale()).clamp(Vector2.ZERO, Vector2(world.sim.map.w - 1, world.sim.map.h - 1))

func _draw() -> void:
	if world == null:
		return
	var sim := world.sim
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(base_tex, r, false)
	var k := _scale()
	var mem: Dictionary = sim.fog.memory.get(world.local_team, {})
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.kind == SimEntity.Kind.UNIT and e.res_id < 0:
			continue
		if e.kind == SimEntity.Kind.RESOURCE:
			continue   # drawn as supply icons above the fog
		var vis := world._is_visible(e, mem) or mem.has(id)
		if not vis:
			continue
		var col: Color
		if e.kind == SimEntity.Kind.RESOURCE:
			col = Color("#57e0c8")
		elif e.owner < 0:
			col = Color("#c8c2b4")
		else:
			col = Palette.color(sim.players[e.owner].color)
		if e.kind == SimEntity.Kind.UNIT:
			var p := FX.to_world(e.pos)
			draw_rect(Rect2(Vector2(p.x, p.z) * k - Vector2(1.5, 1.5), Vector2(3, 3)), col)
		else:
			draw_rect(Rect2(Vector2(e.tile) * k, Vector2(e.fp) * k).grow(0.5), col)
	draw_texture_rect(fog_tex, r, false)
	_draw_supply(k)
	# camera frame
	var cs := cam.view_corners()
	var pts := PackedVector2Array()
	for c in cs:
		pts.append((Vector2(c.x, c.z) * k).clamp(Vector2.ZERO, size))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.9), 1.2)
	for p in pings:
		var a: float = 1.0 - p["t"] / 2.0
		draw_arc(p["p"] * k, 4.0 + p["t"] * 10.0, 0, TAU, 20, Color(1, 0.3, 0.2, a), 2.0)
	draw_rect(r, Color("#c9a24a"), false, 1.0)

## Last-seen fill level of a resource for the local player (1.0 until scouted).
func supply_fraction(e: SimEntity) -> float:
	return known_fraction(world.sim, world.local_team, e, res_known)

## Shroud-respecting fill level (static so tests can check it without a view): a pile's level
## updates only while the team can see it; until then the icon shows the start value.
static func known_fraction(sim: SimWorld, team: int, e: SimEntity, known: Dictionary) -> float:
	var seen := team < 0 or sim.fog.disabled or sim.fog.visible_tile(team, e.tile) \
		or sim.fog.visible_tile(team, FX.to_tile(e.pos))
	if seen:
		known[e.id] = float(e.amount) / float(maxi(1, e.max_amount))
	return known.get(e.id, 1.0)

func _draw_supply(k: Vector2) -> void:
	var sim := world.sim
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.kind != SimEntity.Kind.RESOURCE:
			continue
		var f := supply_fraction(e)
		if f <= 0.0:
			continue
		var big := e.def_id == &"seam"   # supply dock-sized seam vs. small pile
		var c := (Vector2(e.tile) + Vector2(0.5, 0.5)) * k
		var rr := (4.2 if big else 3.2) * clampf(k.x / 1.2, 0.8, 1.6)
		var a := 0.45 + 0.55 * f
		var dia := PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
		var out := PackedVector2Array([c + Vector2(0, -rr - 1.2), c + Vector2(rr + 1.2, 0), c + Vector2(0, rr + 1.2), c + Vector2(-rr - 1.2, 0)])
		draw_colored_polygon(out, Color(0.05, 0.05, 0.04, 0.85 * a))
		draw_colored_polygon(dia, Color(0.98, 0.78, 0.22, a) if big else Color(0.45, 0.9, 0.78, a))
		# fill gauge: inner pip shrinks as the pile empties
		var ir := rr * 0.45 * clampf(f, 0.25, 1.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -ir), c + Vector2(ir, 0), c + Vector2(0, ir), c + Vector2(-ir, 0)]), Color(1, 1, 1, 0.8 * a))

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
			_down_ms = Time.get_ticks_msec()
			_down_pos = ev.position
			_long_done = false
			_jump(ev.position)
		else:
			_down = false
		accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		if not ctl.own_units_selected().is_empty():
			var t := _to_tile(ev.position)
			ctl.issue({"t": "move", "ids": ctl.own_units_selected(), "pos": FX.from_world(Vector3(t.x, 0, t.y))})
			ping(t)
		accept_event()
	elif ev is InputEventMouseMotion and _down:
		if ev.position.distance_to(_down_pos) > 10 or _long_done:
			_jump(ev.position)
		accept_event()

func _jump(local: Vector2) -> void:
	var t := _to_tile(local)
	cam.jump_to(Vector3(t.x, 0, t.y), false)
