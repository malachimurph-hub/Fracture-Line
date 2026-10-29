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
## M3.3 Phase 5: what changed, so the 3D World Builder view can update only that part.
## kind: "height" (rect = corner rect) | "tiles" (tile rect) | "items" | "all"
signal edited(kind: String, rect: Rect2i)

const TILE_NAMES := ["Grass", "Road", "Rough", "Water", "Ford", "Bridge", "Cliff", "Forest"]
const BRUSHES := [1, 3, 5, 9, 15]
const UNDO_MAX := 40
const TAP_PX := 14.0
## M2.9 props (view-only decor). Tall buildings block: their footprint is saved as Cliff.
const PROP_LABELS := {"tower_glass": "Glass tower", "tower_office": "Office tower", "tower_apart": "Apartment block",
	"tower_slim": "Slim tower", "shops": "Shop row", "car_red": "Car (red)", "car_white": "Car (white)", "car_blue": "Car (blue)",
	"car_silver": "Car (silver)", "car_taxi": "Taxi", "car_van": "Van", "car_suv": "SUV", "streetlight": "Street light",
	"streetlight_double": "Double street light", "wreck_car": "Burnt-out car", "palm": "Palm tree", "oak": "Oak tree",
	"pine": "Pine tree", "bush": "Bush", "rock": "Rock"}
const FAC_COL := {&"eu": Color("#6fe3ff"), &"us": Color("#cfe4ff"), &"tpla": Color("#f0b860"), &"ecc": Color("#e0574a"), &"neutral": Color("#c8c2b4")}

var w := 64
var h := 64
var tiles := PackedByteArray()
var items: Array = []
var map_name := ""
var map_id := ""
var env: StringName = &"desert"
var dirty := false
## M3.3 Phase 5 (47): sculpted ground height per tile corner (mm), (w + 1) * (h + 1). Hills from
## a copied map are baked into it; saved as MapDef.elev (MapStore.elev_encode).
var elev := PackedInt32Array()
const HEIGHT_TOOLS := ["raise", "lower", "smooth", "flatten", "level0"]
const HEIGHT_CAP := 3200       ## same as SimMap.ELEV_CAP
var height_strength := 120     ## mm per dab at the brush centre (raise / lower)
var _flat_target := 0

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
	elev = MapStore.elev_decode(d.get("elev", ""), (w + 1) * (h + 1))
	if elev.size() != (w + 1) * (h + 1):
		elev = PackedInt32Array()
		elev.resize((w + 1) * (h + 1))
	_bake_hills(d.get("hills", []))
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
	for e in d.get("decor", []):
		var pit := {"t": "prop", "kind": String(e[0]), "rot": int(e[3])}
		var pfp := item_fp(pit)
		pit["tile"] = Vector2i(roundi(float(e[1]) - pfp.x * 0.5), roundi(float(e[2]) - pfp.y * 0.5))
		items.append(pit)
		if PropMeshes.FOOTPRINT.has(pit["kind"]):   # un-stamp: the Cliff is re-applied on save
			for yy in pfp.y:
				for xx in pfp.x:
					var tx: int = pit["tile"].x + xx
					var ty: int = pit["tile"].y + yy
					if tx < w and ty < h and tiles[ty * w + tx] == SimMap.T.CLIFF:
						tiles[ty * w + tx] = SimMap.T.GRASS
	_undo.clear()
	_redo.clear()
	selected = -1
	dirty = false
	_rebuild_image()
	fit()
	doc_changed.emit()
	selection_changed.emit()
	edited.emit("all", Rect2i(0, 0, w + 1, h + 1))

## Hills ([cx, cy, r, mm], SimMap.build_elevation's bump) become sculpted height.
func _bake_hills(hills: Array) -> void:
	for hl in hills:
		var cx := int(hl[0])
		var cy := int(hl[1])
		var r := maxi(2, int(hl[2]))
		var hm := int(hl[3])
		var r2 := r * r
		for y in range(maxi(0, cy - r), mini(h, cy + r) + 1):
			for x in range(maxi(0, cx - r), mini(w, cx + r) + 1):
				var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
				if d2 < r2:
					var u := 1024 - d2 * 1024 / r2
					elev[y * (w + 1) + x] += hm * (u * u / 1024) / 1024
	for i in elev.size():
		elev[i] = clampi(elev[i], -HEIGHT_CAP, HEIGHT_CAP)

func to_doc() -> Dictionary:
	var rows: Array = []
	var out := tiles.duplicate()
	var dc: Array = []
	for it in items:
		if it["t"] == "prop":
			var fp := item_fp(it)
			dc.append([it["kind"], it["tile"].x + fp.x * 0.5, it["tile"].y + fp.y * 0.5, int(it.get("rot", 0))])
			if PropMeshes.FOOTPRINT.has(it["kind"]):
				for yy in fp.y:
					for xx in fp.x:
						out[(it["tile"].y + yy) * w + it["tile"].x + xx] = SimMap.T.CLIFF
	for y in h:
		var row := ""
		for x in w:
			row += MapStore.T_TO_CHAR[out[y * w + x]]
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
		"spawns": sp, "resources": rs, "neutrals": ns, "prebuilt": pb, "decor": dc, "elev": MapStore.elev_encode(elev)}

func _snapshot() -> Dictionary:
	return {"tiles": tiles.duplicate(), "items": items.duplicate(true), "elev": elev.duplicate()}

func _restore(s: Dictionary) -> void:
	# M3.3 Phase 5: tell the 3D view only what changed (a full rebuild of a big map is slow)
	var tr := diff_rect(tiles, s["tiles"], w)
	var er := Rect2i()
	if s.has("elev"):
		er = diff_rect_i(elev, s["elev"], w + 1)
	var items_changed: bool = items != s["items"]
	tiles = s["tiles"].duplicate()
	items = s["items"].duplicate(true)
	if s.has("elev"):
		elev = s["elev"].duplicate()
	selected = -1
	_rebuild_image()
	selection_changed.emit()
	if tr.size != Vector2i.ZERO:
		edited.emit("tiles", tr)
	if er.size != Vector2i.ZERO:
		edited.emit("height", er)
		edited.emit("height_done", er)
	if items_changed:
		edited.emit("items", Rect2i())

## bounding box of the cells that differ (row width `rw`)
static func diff_rect(a: PackedByteArray, b: PackedByteArray, rw: int) -> Rect2i:
	if a.size() != b.size():
		return Rect2i(0, 0, rw, b.size() / maxi(1, rw))
	if a == b:
		return Rect2i()
	var x0 := rw
	var y0 := 1 << 30
	var x1 := -1
	var y1 := -1
	for i in a.size():
		if a[i] != b[i]:
			var x := i % rw
			var y := i / rw
			x0 = mini(x0, x); x1 = maxi(x1, x); y0 = mini(y0, y); y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

static func diff_rect_i(a: PackedInt32Array, b: PackedInt32Array, rw: int) -> Rect2i:
	if a.size() != b.size():
		return Rect2i(0, 0, rw, maxi(a.size(), b.size()) / maxi(1, rw))
	if a == b:
		return Rect2i()
	var x0 := rw
	var y0 := 1 << 30
	var x1 := -1
	var y1 := -1
	for i in a.size():
		if a[i] != b[i]:
			var x := i % rw
			var y := i / rw
			x0 = mini(x0, x); x1 = maxi(x1, x); y0 = mini(y0, y); y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

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
		_img.set_pixel(t.x, t.y, _shaded(tile_color(v), t.x, t.y) if elev.size() == (w + 1) * (h + 1) else tile_color(v))
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
	edited.emit("tiles", _path_rect(path, brush / 2 + 1))

## M3.3 Phase 5: live brush strokes for the 3D view (the ground updates under the finger):
## begin_paint() at the first tile, paint_to() per new tile, end_paint() = one undo step.
var _pstroke = null
var _plast := Vector2i(-1, -1)
func begin_paint(t: Vector2i) -> void:
	_pstroke = _snapshot()
	_plast = t
	_brush_at(t)
	edited.emit("tiles", _path_rect([t], brush / 2 + 1))

func paint_to(t: Vector2i) -> void:
	if _pstroke == null or t == _plast:
		return
	_brush_line(_plast, t)
	edited.emit("tiles", _path_rect([_plast, t], brush / 2 + 1))
	_plast = t

func end_paint() -> void:
	if _pstroke != null and _pstroke["tiles"] != tiles:
		_push_undo(_pstroke)
	_pstroke = null

func cancel_paint() -> void:
	if _pstroke == null:
		return
	var r := diff_rect(_pstroke["tiles"], tiles, w)
	tiles = _pstroke["tiles"].duplicate()
	_pstroke = null
	_rebuild_image()
	if r.size != Vector2i.ZERO:
		edited.emit("tiles", r)

func _path_rect(path: Array, pad: int) -> Rect2i:
	if path.is_empty():
		return Rect2i()
	var r := Rect2i(path[0], Vector2i.ONE)
	for p in path:
		r = r.expand(p).expand(p + Vector2i.ONE)
	return r.grow(pad).intersection(Rect2i(0, 0, w, h))

# ------------------------------------------------------------------ M3.3 Phase 5: sculpting
## Height brush stroke: begin_height() once, height_dab() per brush position (tile-space centre,
## radius in tiles), end_height() commits one undo step. Modes: raise / lower (add or remove
## height_strength mm at the centre, smooth falloff), smooth (relax toward the neighbours),
## flatten (toward the height under the first dab), level0 (back to the ground plane).
var _hstroke = null
var _hrect := Rect2i()
func begin_height(at: Vector2 = Vector2(-1, -1)) -> void:
	_hstroke = _snapshot()
	_hrect = Rect2i()
	_flat_target = corner_mm(Vector2i(roundi(at.x), roundi(at.y))) if at.x >= 0 else 0

func corner_mm(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x > w or c.y > h or elev.is_empty():
		return 0
	return elev[c.y * (w + 1) + c.x]

func height_dab(at: Vector2, radius: float, mode: String) -> Rect2i:
	if _hstroke == null:
		begin_height(at)
	var r := maxf(0.75, radius)
	var x0 := maxi(0, floori(at.x - r))
	var x1 := mini(w, ceili(at.x + r))
	var y0 := maxi(0, floori(at.y - r))
	var y1 := mini(h, ceili(at.y + r))
	var src := elev.duplicate() if mode == "smooth" else elev
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x, y).distance_to(at) / r
			if d >= 1.0:
				continue
			var f := (1.0 - d * d) * (1.0 - d * d)   # same bump shape as the hills
			var k := y * (w + 1) + x
			var v := elev[k]
			match mode:
				"raise":
					v += roundi(height_strength * f)
				"lower":
					v -= roundi(height_strength * f)
				"flatten":
					v = roundi(lerpf(v, _flat_target, minf(1.0, f * 1.6)))
				"level0":
					v = roundi(lerpf(v, 0.0, minf(1.0, f * 1.6)))
				"smooth":
					var acc := 0
					var n := 0
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var xx := x + dx
							var yy := y + dy
							if xx >= 0 and yy >= 0 and xx <= w and yy <= h:
								acc += src[yy * (w + 1) + xx]
								n += 1
					v = roundi(lerpf(v, float(acc) / n, minf(1.0, f * 0.9)))
			elev[k] = clampi(v, -HEIGHT_CAP, HEIGHT_CAP)
	var rr := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	_hrect = rr if _hrect.size == Vector2i.ZERO else _hrect.merge(rr)
	_shade_rect(rr)
	edited.emit("height", rr)
	return rr

func end_height() -> void:
	if _hstroke == null:
		return
	if _hstroke["elev"] != elev:
		_push_undo(_hstroke)
	_hstroke = null
	edited.emit("height_done", _hrect)

func cancel_height() -> void:
	if _hstroke != null:
		elev = _hstroke["elev"].duplicate()
		_hstroke = null
		edited.emit("height", _hrect)

func has_height() -> bool:
	return elev.count(0) < elev.size()

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
	edited.emit("tiles", diff_rect(s["tiles"], tiles, w))

static func item_fp(it: Dictionary) -> Vector2i:
	match it["t"]:
		"spawn": return MapStore.HQ_FP
		"neutral": return MapStore.footprint_of(it["kind"])
		"prop":
			var pf: Vector2i = PropMeshes.FOOTPRINT.get(it["kind"], Vector2i.ONE)
			return Vector2i(pf.y, pf.x) if int(it.get("rot", 0)) % 2 == 1 else pf
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
		"prop":
			it["kind"] = p["kind"]
			it["rot"] = int(p.get("rot", 0))
	var fp := item_fp(it)
	it["tile"] = Vector2i(clampi(t.x - fp.x / 2, 0, w - fp.x), clampi(t.y - fp.y / 2, 0, h - fp.y))
	items.append(it)
	selected = items.size() - 1
	_push_undo(s)
	edited.emit("items", Rect2i())
	selection_changed.emit()
	queue_redraw()
	return selected

## Topmost item under t, else the nearest one within `slack` tiles (finger-sized targets).
func hit(t: Vector2i, slack: int = 0) -> int:
	var best := -1
	var best_d := slack + 1
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		var r := Rect2i(it["tile"], item_fp(it))
		var dx := maxi(0, maxi(r.position.x - t.x, t.x - (r.end.x - 1)))
		var dy := maxi(0, maxi(r.position.y - t.y, t.y - (r.end.y - 1)))
		var d := maxi(dx, dy)
		if d < best_d:
			best_d = d
			best = i
	return best

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
	edited.emit("items", Rect2i())
	queue_redraw()

func delete_selected() -> void:
	if selected < 0:
		return
	var s := _snapshot()
	items.remove_at(selected)
	selected = -1
	_push_undo(s)
	edited.emit("items", Rect2i())
	selection_changed.emit()
	queue_redraw()

func set_selected_amount(a: int) -> void:
	if selected < 0 or items[selected]["t"] != "res":
		return
	var s := _snapshot()
	items[selected]["amount"] = clampi(a, 1000, 200000)
	amounts[items[selected]["kind"]] = items[selected]["amount"]
	_push_undo(s)
	edited.emit("items", Rect2i())
	selection_changed.emit()
	queue_redraw()

## M2.9: turn the selected prop by 90° (non-square footprints swap and stay on the map).
func rotate_selected() -> void:
	if selected < 0 or items[selected]["t"] != "prop":
		return
	var s := _snapshot()
	var it: Dictionary = items[selected]
	it["rot"] = (int(it.get("rot", 0)) + 1) % 4
	var fp := item_fp(it)
	it["tile"] = Vector2i(clampi(it["tile"].x, 0, w - fp.x), clampi(it["tile"].y, 0, h - fp.y))
	_push_undo(s)
	edited.emit("items", Rect2i())
	selection_changed.emit()
	queue_redraw()

func set_selected_slot(slot: int) -> void:
	if selected < 0 or items[selected]["t"] != "pre":
		return
	var s := _snapshot()
	items[selected]["slot"] = slot
	_push_undo(s)
	edited.emit("items", Rect2i())
	selection_changed.emit()
	queue_redraw()

func set_env(e: StringName) -> void:
	env = e
	_rebuild_image()
	dirty = true
	doc_changed.emit()
	edited.emit("all", Rect2i(0, 0, w + 1, h + 1))

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
	var shade := elev.size() == (w + 1) * (h + 1) and has_height()
	for y in h:
		for x in w:
			var c: Color = cols[tiles[y * w + x]]
			if shade:
				c = _shaded(c, x, y)
			_img.set_pixel(x, y, c)
	_tex = ImageTexture.create_from_image(_img)
	_img_dirty = false
	queue_redraw()

## M3.3 P5: 2D hill shading (light from the north-west) + a little brightness with height
func _shaded(c: Color, x: int, y: int) -> Color:
	var k := y * (w + 1) + x
	var s := float(elev[k] - elev[k + w + 2]) * 0.0012 + float(elev[k]) * 0.00004
	return c.lightened(s) if s > 0.0 else c.darkened(-s)

func _shade_rect(r: Rect2i) -> void:
	if _img == null:
		return
	for y in range(maxi(0, r.position.y - 1), mini(h, r.end.y + 1)):
		for x in range(maxi(0, r.position.x - 1), mini(w, r.end.x + 1)):
			_img.set_pixel(x, y, _shaded(tile_color(tiles[y * w + x]), x, y))
	_img_dirty = true

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
		"prop": return PROP_LABELS.get(it["kind"], String(it["kind"]))
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
			"prop":
				var big := PropMeshes.FOOTPRINT.has(it["kind"])
				var rp := r.grow(maxf(0.0, (6.0 if big else 3.0) - r.size.x) * 0.5)
				draw_rect(rp, Color(0.45, 0.5, 0.58, 0.92) if big else Color(0.85, 0.8, 0.55, 0.9))
				draw_rect(rp, Color(0.1, 0.1, 0.12), false, 1.0)
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
		"raise", "lower", "smooth", "flatten", "level0":   # M3.3 P5: sculpting works in the 2D view too
			begin_height(Vector2(t) + Vector2(0.5, 0.5))
			height_dab(Vector2(t) + Vector2(0.5, 0.5), brush * 0.5 + 0.25, tool)
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
		"raise", "lower", "smooth", "flatten", "level0":
			if t != _last_tile:
				height_dab(Vector2(t) + Vector2(0.5, 0.5), brush * 0.5 + 0.25, tool)
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
				edited.emit("tiles", diff_rect(_snap["tiles"], tiles, w))
		"raise", "lower", "smooth", "flatten", "level0":
			end_height()
		"fill":
			if not _moved:
				fill(t)
		"place":
			if not _moved:
				place_at(t)
		"select":
			if _drag_item >= 0 and _moved and _snap != null:
				_push_undo(_snap)
				edited.emit("items", Rect2i())
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
