class_name MapBuilderCanvas
extends Control
## M2.8 map builder: the editable 2D map (tile grid + placed items), touch input and undo/redo.
## One finger paints / places / selects+moves; two fingers pan and pinch-zoom (a stroke that
## turns into a two-finger gesture is rolled back). Desktop: left mouse = finger, wheel zooms,
## right / middle drag pans. Emulated mouse events from touch are ignored (touch is handled).
## Items: {t:"spawn", slot, tile} | {t:"res", kind, tile, amount} | {t:"neutral", kind, tile}
##        | {t:"pre", kind, slot, tile}   (pre-placed unit / building owned by start slot)
signal doc_changed
signal selection_changed

const TILE_NAMES := ["Grass", "Road", "Rough", "Water", "Ford", "Bridge", "Cliff", "Forest"]
const BRUSHES := [1, 3, 5, 9, 15]
const UNDO_MAX := 40
const TAP_PX := 14.0
const FAC_COL := {&"eu": Color("#6fe3ff"), &"us": Color("#cfe4ff"), &"tpla": Color("#f0b860"), &"neutral": Color("#c8c2b4")}

var w := 64
var h := 64
var tiles := PackedByteArray()
var items: Array = []
var map_name := ""
var map_id := ""
var env: StringName = &"desert"
var dirty := false

var tool := "paint"            ## paint | fill | erase | place | select
var paint_t := 0
var brush := 3
var place := {}                ## {t, kind, slot}
var amounts := {"seam": 30000, "cache": 6000}
var owner_slot := 0
var selected := -1

var zoom := 4.0
var offset := Vector2.ZERO
var _img: Image
var _tex: ImageTexture
var _img_dirty := false
var _undo: Array = []
var _redo: Array = []
var _touches := {}
var _down := false
var _gesture := false
var _g_dist := 0.0
var _g_mid := Vector2.ZERO
var _snap = null
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _last_tile := Vector2i(-9999, -9999)
var _moved := false
var _pan_one := false
var _drag_item := -1
var _drag_off := Vector2i.ZERO
var _mouse_pan := false
var _hover := Vector2i(-1, -1)

func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(func(): if _tex != null and zoom <= 0.0: fit())

# ------------------------------------------------------------------ document
func load_doc(d: Dictionary) -> void:
	var sz := MapStore._v(d.get("size", [64, 64]))
	w = sz.x
	h = sz.y
	map_name = String(d.get("name", "New map"))
	map_id = String(d.get("id", ""))
	env = StringName(d.get("env", "desert"))
	tiles = PackedByteArray()
	tiles.resize(w * h)
	var rows: Array = d.get("tiles", [])
	for y in mini(h, rows.size()):
		var ln: String = rows[y]
		for x in mini(w, ln.length()):
			tiles[y * w + x] = SimMap.CHAR_TO_T.get(ln[x], SimMap.T.GRASS)
	items.clear()
	var sp: Array = d.get("spawns", [])
	for i in sp.size():
		items.append({"t": "spawn", "slot": i, "tile": MapStore._v(sp[i])})
	for r in d.get("resources", []):
		items.append({"t": "res", "kind": String(r["kind"]), "tile": MapStore._v(r["tile"]), "amount": int(r["amount"])})
	for n in d.get("neutrals", []):
		items.append({"t": "neutral", "kind": String(n["kind"]), "tile": MapStore._v(n["tile"])})
	for p in d.get("prebuilt", []):
		items.append({"t": "pre", "kind": String(p["kind"]), "slot": int(p["spawn"]), "tile": MapStore._v(p["tile"])})
	_undo.clear()
	_redo.clear()
	selected = -1
	dirty = false
	_rebuild_image()
	fit()
	doc_changed.emit()
	selection_changed.emit()

func to_doc() -> Dictionary:
	var rows: Array = []
	for y in h:
		var row := ""
		for x in w:
			row += MapStore.T_TO_CHAR[tiles[y * w + x]]
		rows.append(row)
	var spawn_items: Array = []
	for it in items:
		if it["t"] == "spawn":
			spawn_items.append(it)
	spawn_items.sort_custom(func(a, b): return int(a["slot"]) < int(b["slot"]))
	var slot_to_i := {}
	var sp: Array = []
	for it in spawn_items:
		slot_to_i[int(it["slot"])] = sp.size()
		sp.append(MapStore._a(it["tile"]))
	var rs: Array = []
	var ns: Array = []
	var pb: Array = []
	for it in items:
		match it["t"]:
			"res": rs.append({"kind": it["kind"], "tile": MapStore._a(it["tile"]), "amount": int(it["amount"])})
			"neutral": ns.append({"kind": it["kind"], "tile": MapStore._a(it["tile"])})
			"pre": pb.append({"kind": it["kind"], "spawn": int(slot_to_i.get(int(it["slot"]), -1)), "tile": MapStore._a(it["tile"])})
	return {"format": MapStore.FORMAT, "id": map_id, "name": map_name, "size": [w, h], "env": String(env), "tiles": rows,
		"spawns": sp, "resources": rs, "neutrals": ns, "prebuilt": pb}

func _snapshot() -> Dictionary:
	return {"tiles": tiles.duplicate(), "items": items.duplicate(true)}

func _restore(s: Dictionary) -> void:
	tiles = s["tiles"].duplicate()
	items = s["items"].duplicate(true)
	selected = -1
	_rebuild_image()
	selection_changed.emit()

func _push_undo(s: Dictionary) -> void:
	_undo.append(s)
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()
	dirty = true
	doc_changed.emit()

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	dirty = true
	doc_changed.emit()

func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	dirty = true
	doc_changed.emit()

# ------------------------------------------------------------------ editing API (also used by tests)
func tile_ok(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < w and t.y < h

func _set_tile(t: Vector2i, v: int) -> void:
	if tile_ok(t) and tiles[t.y * w + t.x] != v:
		tiles[t.y * w + t.x] = v
		_img.set_pixel(t.x, t.y, tile_color(v))
		_img_dirty = true

func _brush_at(t: Vector2i) -> void:
	var v := SimMap.T.GRASS if tool == "erase" else paint_t
	var r := brush / 2
	for yy in range(-r, r + 1):
		for xx in range(-r, r + 1):
			if brush >= 5 and xx * xx + yy * yy > r * r + r:
				continue   # round brush for the big sizes
			_set_tile(t + Vector2i(xx, yy), v)

func _brush_line(a: Vector2i, b: Vector2i) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, n + 1):
		_brush_at(Vector2i(roundi(lerpf(a.x, b.x, float(i) / n)), roundi(lerpf(a.y, b.y, float(i) / n))))

## One undoable brush dab (or stroke through `path`).
func paint(path: Array) -> void:
	var s := _snapshot()
	for i in path.size():
		if i == 0:
			_brush_at(path[0])
		else:
			_brush_line(path[i - 1], path[i])
	_push_undo(s)

func fill(t: Vector2i) -> void:
	if not tile_ok(t):
		return
	var from := tiles[t.y * w + t.x]
	var to := SimMap.T.GRASS if tool == "erase" else paint_t
	if from == to:
		return
	var s := _snapshot()
	var stack := PackedInt32Array([t.y * w + t.x])
	tiles[t.y * w + t.x] = to
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % w
		var y := i / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h and tiles[ny * w + nx] == from:
				tiles[ny * w + nx] = to
				stack.append(ny * w + nx)
	_rebuild_image()
	_push_undo(s)

static func item_fp(it: Dictionary) -> Vector2i:
	match it["t"]:
		"spawn": return MapStore.HQ_FP
		"neutral": return MapStore.footprint_of(it["kind"])
		"pre":
			if Content.is_building(it["kind"]):
				return MapStore.footprint_of(it["kind"])
	return Vector2i.ONE

## Places the current `place` asset centred on tile t. Returns the new item index.
func place_at(t: Vector2i, what: Dictionary = {}) -> int:
	var p := what if not what.is_empty() else place
	if p.is_empty() or not tile_ok(t):
		return -1
	var s := _snapshot()
	var it := {"t": p["t"]}
	match p["t"]:
		"spawn":
			it["slot"] = int(p["slot"])
			for i in items.size():
				if items[i]["t"] == "spawn" and int(items[i]["slot"]) == int(p["slot"]):
					items.remove_at(i)   # each start position exists once: placing it again moves it
					break
		"res":
			it["kind"] = p["kind"]
			it["amount"] = int(p.get("amount", amounts.get(p["kind"], 10000)))
		"neutral":
			it["kind"] = p["kind"]
		"pre":
			it["kind"] = p["kind"]
			it["slot"] = int(p.get("slot", owner_slot))
	var fp := item_fp(it)
	it["tile"] = Vector2i(clampi(t.x - fp.x / 2, 0, w - fp.x), clampi(t.y - fp.y / 2, 0, h - fp.y))
	items.append(it)
	selected = items.size() - 1
	_push_undo(s)
	selection_changed.emit()
	queue_redraw()
	return selected

func hit(t: Vector2i, slack: int = 0) -> int:
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		var r := Rect2i(it["tile"], item_fp(it)).grow(slack)
		if r.has_point(t):
			return i
	return -1

func select_at(t: Vector2i) -> int:
	selected = hit(t, maxi(1, ceili(18.0 / zoom)))
	selection_changed.emit()
	queue_redraw()
	return selected

func move_selected(to_tile: Vector2i) -> void:
	if selected < 0:
		return
	var s := _snapshot()
	var fp := item_fp(items[selected])
	items[selected]["tile"] = Vector2i(clampi(to_tile.x, 0, w - fp.x), clampi(to_tile.y, 0, h - fp.y))
	_push_undo(s)
	queue_redraw()

func delete_selected() -> void:
	if selected < 0:
		return
	var s := _snapshot()
	items.remove_at(selected)
	selected = -1
	_push_undo(s)
	selection_changed.emit()
	queue_redraw()

func set_selected_amount(a: int) -> void:
	if selected < 0 or items[selected]["t"] != "res":
		return
	var s := _snapshot()
	items[selected]["amount"] = clampi(a, 1000, 200000)
	amounts[items[selected]["kind"]] = items[selected]["amount"]
	_push_undo(s)
	selection_changed.emit()
	queue_redraw()

func set_selected_slot(slot: int) -> void:
	if selected < 0 or items[selected]["t"] != "pre":
		return
	var s := _snapshot()
	items[selected]["slot"] = slot
	_push_undo(s)
	selection_changed.emit()
	queue_redraw()

func set_env(e: StringName) -> void:
	env = e
	_rebuild_image()
	dirty = true
	doc_changed.emit()

# ------------------------------------------------------------------ view
func tile_at(p: Vector2) -> Vector2i:
	var v := (p - offset) / zoom
	return Vector2i(floori(v.x), floori(v.y))

func fit() -> void:
	if size.x <= 0 or w <= 0:
		return
	zoom = minf(size.x / w, size.y / h) * 0.96
	offset = (size - Vector2(w, h) * zoom) * 0.5
	queue_redraw()

func min_zoom() -> float:
	return minf(size.x / maxf(1, w), size.y / maxf(1, h)) * 0.5

func zoom_at(p: Vector2, f: float) -> void:
	var nz := clampf(zoom * f, min_zoom(), 48.0)
	offset = p - (p - offset) * (nz / zoom)
	zoom = nz
	_clamp_view()
	queue_redraw()

func _clamp_view() -> void:
	var ms := Vector2(w, h) * zoom
	offset.x = clampf(offset.x, size.x * 0.5 - ms.x, size.x * 0.5)
	offset.y = clampf(offset.y, size.y * 0.5 - ms.y, size.y * 0.5)

const GRASS_COL := {&"desert": Color("#c9a878"), &"winter": Color("#e4eaf0"), &"arid": Color("#cfa56a"), &"temperate": Color("#7f9a52")}
const FOREST_COL := {&"desert": Color("#6f7a45"), &"winter": Color("#5d7466"), &"arid": Color("#7c7448"), &"temperate": Color("#3f6030")}

func tile_color(t: int) -> Color:
	var g: Color = GRASS_COL.get(env, GRASS_COL[&"desert"])
	match t:
		SimMap.T.ROAD: return Color("#55524c")
		SimMap.T.ROUGH: return g.darkened(0.22)
		SimMap.T.WATER: return Color("#3f6f8f")
		SimMap.T.FORD: return Color("#79a7bd")
		SimMap.T.BRIDGE: return Color("#8a6a48")
		SimMap.T.CLIFF: return Color("#6e625a")
		SimMap.T.FOREST: return FOREST_COL.get(env, FOREST_COL[&"desert"])
	return g

func _rebuild_image() -> void:
	_img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cols: Array = []
	for t in 8:
		cols.append(tile_color(t))
	for y in h:
		for x in w:
			_img.set_pixel(x, y, cols[tiles[y * w + x]])
	_tex = ImageTexture.create_from_image(_img)
	_img_dirty = false
	queue_redraw()

func _process(_dt: float) -> void:
	if _img_dirty and _tex != null:
		_tex.update(_img)
		_img_dirty = false
		queue_redraw()

## Map-builder maps have no biome layer: lobby preview letters from the tile grid.
static func biome_rows(tiles_text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cmap := {":": "a", ",": "d", "~": "w", "=": "w", "#": "c", "^": "r", "T": "G"}
	for ln in tiles_text.split("\n", false):
		var row := ""
		for c in ln:
			row += cmap.get(c, "s")
		out.append(row)
	return out

func item_label(it: Dictionary) -> String:
	match it["t"]:
		"spawn": return "Start %d" % (int(it["slot"]) + 1)
		"res": return ("Supply seam" if it["kind"] == "seam" else "Supply cache") + " %d" % int(it["amount"])
	return MapStore._name(it["kind"])

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0d0f12"))
	if _tex == null:
		return
	var mrect := Rect2(offset, Vector2(w, h) * zoom)
	draw_texture_rect(_tex, mrect, false)
	var f := get_theme_default_font()
	# grid when zoomed in (visible range only: 256x256 maps stay cheap)
	if zoom >= 10.0:
		var x0 := maxi(0, floori(-offset.x / zoom))
		var x1 := mini(w, ceili((size.x - offset.x) / zoom))
		var y0 := maxi(0, floori(-offset.y / zoom))
		var y1 := mini(h, ceili((size.y - offset.y) / zoom))
		var gc := Color(0, 0, 0, 0.12)
		for x in range(x0, x1 + 1):
			draw_line(offset + Vector2(x, y0) * zoom, offset + Vector2(x, y1) * zoom, gc)
		for y in range(y0, y1 + 1):
			draw_line(offset + Vector2(x0, y) * zoom, offset + Vector2(x1, y) * zoom, gc)
	draw_rect(mrect, UiTheme.GOLD, false, 1.0)
	for i in items.size():
		var it: Dictionary = items[i]
		var fp := item_fp(it)
		var r := Rect2(offset + Vector2(it["tile"]) * zoom, Vector2(fp) * zoom)
		var c := Vector2(r.get_center())
		match it["t"]:
			"spawn":
				var col: Color = Palette.color(int(it["slot"]))
				var rr := r.grow(maxf(0.0, 10.0 - r.size.x) * 0.5)
				draw_rect(rr, Color(col, 0.85))
				draw_rect(rr, Color.WHITE, false, 2.0)
				draw_string(f, c + Vector2(-5, 6), str(int(it["slot"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
			"res":
				var col2 := Color("#ffd166") if it["kind"] == "seam" else Color("#f39c4a")
				var rad := maxf(5.0, zoom * (1.2 if it["kind"] == "seam" else 0.9))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0)]), col2)
				draw_polyline(PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0), c + Vector2(0, -rad)]), Color(0, 0, 0, 0.7), 1.0)
				if zoom >= 6.0:
					draw_string(f, c + Vector2(rad + 2, 4), "%dk" % (int(it["amount"]) / 1000), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			"neutral":
				var rn := r.grow(maxf(0.0, 6.0 - r.size.x) * 0.5)
				draw_rect(rn, Color(0.62, 0.62, 0.6, 0.9))
				draw_rect(rn, Color(0.15, 0.15, 0.15), false, 1.0)
			"pre":
				var fac := Content.faction_of_id(it["kind"])
				var pc: Color = Palette.color(int(it["slot"]))
				var fc: Color = FAC_COL.get(fac, Color.WHITE)
				if Content.is_building(it["kind"]):
					var rb := r.grow(maxf(0.0, 6.0 - r.size.x) * 0.5)
					draw_rect(rb, Color(pc, 0.8))
					draw_rect(rb, fc, false, 2.0)
				else:
					var ur := maxf(3.5, zoom * 0.5)
					draw_circle(c, ur, Color(pc, 0.95))
					draw_arc(c, ur, 0, TAU, 16, fc, 1.5)
		if zoom >= 14.0 and it["t"] in ["neutral", "pre"]:
			draw_string(f, r.position + Vector2(2, -2), item_label(it), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		if i == selected:
			draw_rect(r.grow(3.0), UiTheme.CYAN, false, 2.0)
	# brush outline
	if _hover.x >= 0 and tool in ["paint", "erase"]:
		var b2 := brush / 2
		draw_rect(Rect2(offset + Vector2(_hover - Vector2i(b2, b2)) * zoom, Vector2(brush, brush) * zoom), Color(1, 1, 1, 0.8), false, 1.0)
	# overview minimap (big maps): whole map + the visible window
	if mrect.size.x > size.x * 1.1 or mrect.size.y > size.y * 1.1:
		var ms := 96.0
		var mm := Rect2(Vector2(size.x - ms - 6, size.y - ms - 6), Vector2(ms, ms))
		draw_rect(mm.grow(2), Color(0, 0, 0, 0.7))
		draw_texture_rect(_tex, mm, false)
		var vr := Rect2(-offset / zoom, size / zoom)
		vr = Rect2(mm.position + vr.position / Vector2(w, h) * ms, vr.size / Vector2(w, h) * ms).intersection(mm)
		draw_rect(vr, UiTheme.CYAN, false, 1.0)

# ------------------------------------------------------------------ input
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_press(st.position)
			elif _touches.size() == 2:
				_begin_gesture()
		else:
			var n := _touches.size()
			_touches.erase(st.index)
			if n == 1 and not _gesture:
				_release(st.position)
			if _touches.is_empty():
				_gesture = false
				_down = false
		accept_event()
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _gesture and _touches.size() >= 2:
			_update_gesture()
		elif not _gesture:
			_drag(sd.position)
		accept_event()
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, 1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			elif _down:
				_release(mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_mouse_pan = mb.pressed
		accept_event()
	elif ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION:
		var mm := ev as InputEventMouseMotion
		_hover = tile_at(mm.position)
		if _mouse_pan:
			offset += mm.relative
			_clamp_view()
		elif _down:
			_drag(mm.position)
		queue_redraw()

func _press(p: Vector2) -> void:
	_down = true
	_moved = false
	_pan_one = false
	_drag_item = -1
	_press_pos = p
	_last_pos = p
	var t := tile_at(p)
	_hover = t
	_last_tile = t
	_snap = null
	match tool:
		"paint", "erase":
			_snap = _snapshot()
			_brush_at(t)
		"select":
			select_at(t)
			if selected >= 0:
				_snap = _snapshot()
				_drag_item = selected
				_drag_off = Vector2i(items[selected]["tile"]) - t
			else:
				_pan_one = true
	queue_redraw()

func _drag(p: Vector2) -> void:
	if not _down:
		return
	if p.distance_to(_press_pos) > TAP_PX:
		_moved = true
	var t := tile_at(p)
	_hover = t
	match tool:
		"paint", "erase":
			if t != _last_tile:
				_brush_line(_last_tile, t)
		"select":
			if _drag_item >= 0 and t != _last_tile:
				var fp := item_fp(items[_drag_item])
				var nt := t + _drag_off
				items[_drag_item]["tile"] = Vector2i(clampi(nt.x, 0, w - fp.x), clampi(nt.y, 0, h - fp.y))
		_:
			_pan_one = _pan_one or _moved
	if _pan_one:
		offset += p - _last_pos
		_clamp_view()
	_last_tile = t
	_last_pos = p
	queue_redraw()

func _release(p: Vector2) -> void:
	if not _down:
		return
	_down = false
	var t := tile_at(p)
	match tool:
		"paint", "erase":
			if _snap != null and _snap["tiles"] != tiles:
				_push_undo(_snap)
		"fill":
			if not _moved:
				fill(t)
		"place":
			if not _moved:
				place_at(t)
		"select":
			if _drag_item >= 0 and _moved and _snap != null:
				_push_undo(_snap)
	_snap = null
	_drag_item = -1
	_pan_one = false
	queue_redraw()

func _two() -> Array:
	var ps: Array = _touches.values()
	return [ps[0], ps[1]]

func _begin_gesture() -> void:
	# a stroke / move that turns into a two-finger gesture is rolled back
	if _snap != null and _down:
		_restore(_snap)
	_snap = null
	_down = false
	_drag_item = -1
	_gesture = true
	var pp := _two()
	_g_dist = maxf(1.0, (pp[0] as Vector2).distance_to(pp[1]))
	_g_mid = ((pp[0] as Vector2) + (pp[1] as Vector2)) * 0.5

func _update_gesture() -> void:
	var pp := _two()
	var d := maxf(1.0, (pp[0] as Vector2).distance_to(pp[1]))
	var mid: Vector2 = ((pp[0] as Vector2) + (pp[1] as Vector2)) * 0.5
	offset += mid - _g_mid
	zoom_at(mid, d / _g_dist)
	_g_dist = d
	_g_mid = mid
