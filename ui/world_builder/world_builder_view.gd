class_name WorldBuilderView
extends SubViewportContainer
## M3.3 Phase 5 (47): the World Builder's 3D map view. The map is shown with the game's own
## terrain renderer, lighting and unit / structure / prop models, and edited directly on it,
## in the spirit of Zero Hour's World Builder: paint ground types, sculpt the height (raise,
## lower, smooth, flatten, level), place, pick, drag, turn and delete objects, all on the 3D map.
## The document (tiles, corner heights, items, undo) stays in MapBuilderCanvas; this view
## draws it and turns touches into canvas edits.
##
## Touch: one finger = current tool; two fingers pan, pinch to zoom, twist to turn the view
## (a stroke that becomes a two-finger gesture is cancelled). Mouse: left = finger, wheel zoom,
## right drag turns / tilts, middle drag pans.

signal hover_changed(tile: Vector2i)
signal view_status(text: String)

var canvas: MapBuilderCanvas
var vp: SubViewport
var world_root: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env_node: WorldEnvironment
var terrain: TerrainView
var map: SimMap
var item_root: Node3D
var item_nodes: Array = []       ## parallel to canvas.items
var cursor: MeshInstance3D       ## brush ring / placement footprint
var sel_mark: MeshInstance3D     ## outline of the selected object
var grid: MeshInstance3D
var grid_on := false
var _cursor_mat: StandardMaterial3D
var _sel_mat: StandardMaterial3D
var _grid_mat: StandardMaterial3D

## camera: orbit around `target` (tile space), yaw / pitch in degrees, distance in metres
var target := Vector2(32, 32)
var yaw := 0.0
var pitch := 56.0
var dist := 34.0
const DIST_MIN := 7.0
const DIST_MAX := 160.0

var terrain_builds := 0
var last_build_ms := 0
var _rebuild_due := -1.0
var _tiles_pending := false
var _tiles_wait := 0.0
var tile_updates := 0          ## partial terrain updates after paints / moves (tests, status)
var last_update_ms := 0
const LIVE_PAINT_EVERY := 0.1  ## seconds between ground updates while a finger paints
const FULL_REBUILD_SHARE := 0.6
var _elev_before := PackedInt32Array()
var _scenes := {}

# input state
var _touches := {}
var _gesture := false
var _g_mid := Vector2.ZERO
var _g_dist := 0.0
var _g_ang := 0.0
var _down := false
var _press_pos := Vector2.ZERO
var _moved := false
var _path: Array = []
var _drag_item := -1
var _drag_off := Vector2.ZERO
var _drag_tile := Vector2i(-1, -1)
var _mouse_btn := 0
var _last_mouse := Vector2.ZERO
var _last_dab := Vector2(-99, -99)
var hover := Vector2i(-1, -1)
var _hover_world := Vector3.ZERO

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X if not OS.has_feature("mobile") else Viewport.MSAA_DISABLED
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	world_root = Node3D.new()
	vp.add_child(world_root)
	env_node = WorldEnvironment.new()
	world_root.add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	world_root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.3
	cam.far = 600.0
	world_root.add_child(cam)
	cam.current = true
	item_root = Node3D.new()
	item_root.name = "Items"
	world_root.add_child(item_root)
	_cursor_mat = _line_mat(Color(1.0, 0.86, 0.3, 0.95))
	_sel_mat = _line_mat(Color(0.35, 1.0, 0.55, 1.0))
	_grid_mat = _line_mat(Color(1, 1, 1, 0.22))
	cursor = _imm_node("Cursor", _cursor_mat)
	sel_mark = _imm_node("Selection", _sel_mat)
	grid = _imm_node("Grid", _grid_mat)
	grid.visible = false

func _line_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 10
	m.vertex_color_use_as_albedo = false
	return m

func _imm_node(n: String, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = ImmediateMesh.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(mi)
	return mi

func bind(c: MapBuilderCanvas) -> void:
	canvas = c
	canvas.edited.connect(_on_edited)
	canvas.selection_changed.connect(_draw_selection)

# ------------------------------------------------------------------ building the scene
func _on_edited(kind: String, rect: Rect2i) -> void:
	if not is_inside_tree() or canvas == null:
		return
	match kind:
		"all":
			rebuild_all()
		"tiles":
			_tiles_pending = true
		"height":
			_apply_height(rect)
		"height_done":
			_height_done(rect)
		"items":
			rebuild_items()
			_tiles_pending = true   # props stamp their footprint into the ground

## Light sim map for the renderer (no pathfinding): tiles with props stamped, sculpted heights.
func _make_map() -> SimMap:
	var m := SimMap.new()
	m.w = canvas.w
	m.h = canvas.h
	m.tiles = _stamped_tiles()
	m.nobuild = PackedByteArray()
	m.nobuild.resize(m.w * m.h)
	m.elev = PackedInt32Array()
	m.elev.resize((m.w + 1) * (m.h + 1))
	m.slope = PackedByteArray()
	m.slope.resize(m.w * m.h)
	m.has_elev = true
	map = m
	_copy_elev(Rect2i(0, 0, m.w + 1, m.h + 1))
	return m

func _stamped_tiles() -> PackedByteArray:
	var out := canvas.tiles.duplicate()
	for it in canvas.items:
		if it["t"] == "prop" and PropMeshes.FOOTPRINT.has(it["kind"]):
			var fp := MapBuilderCanvas.item_fp(it)
			for yy in fp.y:
				for xx in fp.x:
					var tx: int = it["tile"].x + xx
					var ty: int = it["tile"].y + yy
					if tx < canvas.w and ty < canvas.h:
						out[ty * canvas.w + tx] = SimMap.T.CLIFF
	return out

## canvas heights -> render map, with the sim's rule: corners at water / ford / bridge stay 0.
func _copy_elev(r: Rect2i) -> void:
	var W := canvas.w
	var H := canvas.h
	if canvas.elev.size() != (W + 1) * (H + 1):
		return
	for y in range(maxi(0, r.position.y), mini(H, r.end.y) + 1):
		for x in range(maxi(0, r.position.x), mini(W, r.end.x) + 1):
			var v := clampi(canvas.elev[y * (W + 1) + x], -SimMap.ELEV_CAP, SimMap.ELEV_CAP)
			for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var tx := x + d.x
				var ty := y + d.y
				if tx >= 0 and ty >= 0 and tx < W and ty < H:
					var tt := map.tiles[ty * W + tx]
					if tt == SimMap.T.WATER or tt == SimMap.T.FORD or tt == SimMap.T.BRIDGE:
						v = 0
			map.elev[y * (W + 1) + x] = v

func _sync_tiles() -> void:
	if map != null and map.w == canvas.w:
		map.tiles = _stamped_tiles()

func rebuild_all() -> void:
	_make_map()
	var e := MapEnv.of(canvas.env)
	_apply_env(e)
	_rebuild_terrain()
	rebuild_items()
	if terrain_builds == 1 or target.x > canvas.w or target.y > canvas.h:
		frame_all()
	_update_camera()

func _apply_env(menv: Dictionary) -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b0c0e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = menv["ambient"]
	e.ambient_light_energy = menv["ambient_energy"]
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = menv["exposure"]
	e.fog_enabled = true
	e.fog_light_color = menv["fog_col"]
	e.fog_density = float(menv["fog_density"]) * 0.6
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_saturation = menv["saturation"]
	e.adjustment_contrast = menv["contrast"]
	e.tonemap_white = 6.0
	env_node.environment = e
	sun.rotation_degrees = menv["sun_rot"]
	sun.light_energy = menv["sun_energy"]
	sun.light_color = menv["sun_col"]

func _rebuild_terrain() -> void:
	var t0 := Time.get_ticks_msec()
	map.tiles = _stamped_tiles()
	_copy_elev(Rect2i(0, 0, map.w + 1, map.h + 1))
	var tv := TerrainView.new()
	tv.name = "Terrain"
	tv.decor_override = _decor_list()
	tv.skip_decor_meshes = true
	tv.cache_shore = false
	FX.ground = map
	tv.build(map, "", MapEnv.of(canvas.env))
	if terrain != null:
		terrain.queue_free()
	terrain = tv
	world_root.add_child(tv)
	world_root.move_child(tv, 0)
	terrain_builds += 1
	last_build_ms = Time.get_ticks_msec() - t0
	_rebuild_due = -1.0
	_tiles_pending = false

func _schedule_rebuild(delay: float) -> void:
	_rebuild_due = delay
	view_status.emit("Updating the map…")

func _process(dt: float) -> void:
	_tiles_wait -= dt
	if _tiles_pending and _tiles_wait <= 0.0 and _rebuild_due < 0.0:
		refresh_tiles()
		_tiles_wait = LIVE_PAINT_EVERY if _down else 0.0
	if _rebuild_due >= 0.0 and not _down:
		_rebuild_due -= dt
		if _rebuild_due < 0.0:
			_rebuild_terrain()
			_reseat_items()
			view_status.emit("")

## M3.3 Phase 5: the ground types changed (paint, fill, undo, a prop moved): update only the
## part of the terrain they touch. A change over most of the map rebuilds it all.
func refresh_tiles() -> void:
	_tiles_pending = false
	if map == null or terrain == null or map.w != canvas.w or map.h != canvas.h:
		return
	var nt := _stamped_tiles()
	var r := MapBuilderCanvas.diff_rect(map.tiles, nt, map.w)
	if r.size == Vector2i.ZERO:
		return
	var t0 := Time.get_ticks_msec()
	var kinds := {}
	var wet := [SimMap.T.WATER, SimMap.T.FORD, SimMap.T.BRIDGE]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var a: int = map.tiles[y * map.w + x]
			var b: int = nt[y * map.w + x]
			if a == b:
				continue
			if a in wet or b in wet:
				kinds["wet"] = true
			if a == SimMap.T.BRIDGE or b == SimMap.T.BRIDGE:
				kinds["bridge"] = true
			if a == SimMap.T.ROAD or b == SimMap.T.ROAD:
				kinds["road"] = true
			if a == SimMap.T.FOREST or b == SimMap.T.FOREST or a == SimMap.T.CLIFF or b == SimMap.T.CLIFF:
				kinds["props"] = true
	if r.size.x * r.size.y > FULL_REBUILD_SHARE * map.w * map.h:
		_rebuild_terrain()
		_reseat_items()
		return
	map.tiles = nt
	_copy_elev(Rect2i(r.position - Vector2i.ONE, r.size + Vector2i(3, 3)))   # water corners go level
	terrain.decor_override = _decor_list()
	var cr := terrain.update_tiles(r, kinds)   # rebuilds everything standing in the area
	_reseat_items(cr)
	_draw_selection()
	tile_updates += 1
	last_update_ms = Time.get_ticks_msec() - t0

func _decor_list() -> Array:
	var dc: Array = []
	for it in canvas.items:
		if it["t"] == "prop":
			var fp := MapBuilderCanvas.item_fp(it)
			dc.append([it["kind"], it["tile"].x + fp.x * 0.5, it["tile"].y + fp.y * 0.5, int(it.get("rot", 0))])
	return dc if not dc.is_empty() else [["_none", -10.0, -10.0, 0]]

## live sculpting: copy the new heights, rebuild the touched ground chunks, move the objects
func _apply_height(r: Rect2i) -> void:
	if map == null or terrain == null:
		return
	if _tiles_pending:
		refresh_tiles()
	if _elev_before.is_empty():
		_elev_before = map.elev.duplicate()
	_copy_elev(r)
	terrain.rebuild_ground(r)
	_reseat_items(r)
	_draw_selection()

func _height_done(r: Rect2i) -> void:
	if terrain != null and not _elev_before.is_empty() and r.size != Vector2i.ZERO:
		terrain.reseat_props(r, _elev_before)
	_elev_before = PackedInt32Array()

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]

func rebuild_items() -> void:
	for n in item_nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	item_nodes.clear()
	for i in canvas.items.size():
		item_nodes.append(_make_item(canvas.items[i]))
	_reseat_items()
	_draw_selection()

func _make_item(it: Dictionary) -> Node3D:
	var n: Node3D = null
	var kind := String(it.get("kind", ""))
	match it["t"]:
		"spawn":
			n = _start_marker(int(it["slot"]))
		"res":
			var ps := _scene("res://view/neutral/%s.tscn" % kind)
			n = ps.instantiate() if ps != null else Node3D.new()
		"neutral":
			var bd: BuildingDef = Content.building(StringName(kind))
			var ps2 := _scene(bd.view_scene) if bd != null else null
			n = ps2.instantiate() if ps2 != null else Node3D.new()
		"pre":
			var path := ""
			if Content.is_building(StringName(kind)):
				path = Content.building(StringName(kind)).view_scene
			elif Content.unit(StringName(kind)) != null:
				path = Content.unit(StringName(kind)).view_scene
			var ps3 := _scene(path) if path != "" else null
			n = ps3.instantiate() if ps3 != null else Node3D.new()
			if n.has_method("set_team_material"):
				n.call("set_team_material", Palette.team_material(int(it["slot"])))
			var ud: UnitDef = Content.unit(StringName(kind)) if not Content.is_building(StringName(kind)) else null
			if ud != null and ud.tags.has("infantry"):
				n.scale = Vector3.ONE * WorldView.INF_SCALE
		"prop":
			n = MeshInstance3D.new()
			(n as MeshInstance3D).mesh = PropMeshes.make(kind)
			if terrain != null:
				var mat: Material = terrain.prop_material
				if kind in ["palm", "scrub_tree", "pine", "pine_snow", "oak", "bush"]:
					mat = terrain.prop_sway_material
				elif kind in PropMeshes.HOUSES or kind in ["gas_station", "shack", "power_pole", "streetlight", "streetlight_double"]:
					mat = terrain.prop_detail_material
				elif PropMeshes.FOOTPRINT.has(kind):
					mat = terrain.prop_tower_material
				(n as MeshInstance3D).material_override = mat
			n.rotation.y = float(int(it.get("rot", 0))) * PI * 0.5
	if n == null:
		n = Node3D.new()
	n.set_meta("wb_kind", String(it["t"]))
	item_root.add_child(n)
	return n

func _start_marker(slot: int) -> Node3D:
	var n := Node3D.new()
	var col := Palette.color(slot)
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(MapStore.HQ_FP.x - 0.2, 0.06, MapStore.HQ_FP.y - 0.2)
	pad.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(col.r, col.g, col.b, 0.55)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = pm
	pad.position.y = 0.05
	n.add_child(pad)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 3.0
	pole.mesh = cm
	var pol := StandardMaterial3D.new()
	pol.albedo_color = Color(0.85, 0.85, 0.8)
	pole.material_override = pol
	pole.position = Vector3(-1.4, 1.5, -1.4)
	n.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.0, 0.6, 0.04)
	flag.mesh = fm
	var flm := StandardMaterial3D.new()
	flm.albedo_color = col
	flag.material_override = flm
	flag.position = Vector3(-0.9, 2.65, -1.4)
	n.add_child(flag)
	var lb := Label3D.new()
	lb.text = "Start %d" % (slot + 1)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.fixed_size = true
	lb.pixel_size = 0.0022
	lb.font_size = 26
	lb.outline_size = 8
	lb.modulate = col.lightened(0.3)
	lb.position = Vector3(0, 3.4, 0)
	n.add_child(lb)
	n.name = "Start%d" % (slot + 1)
	return n

## put every object (or those inside `r`, a corner rect) on the ground
func _reseat_items(r: Rect2i = Rect2i()) -> void:
	for i in mini(item_nodes.size(), canvas.items.size()):
		var it: Dictionary = canvas.items[i]
		var fp := MapBuilderCanvas.item_fp(it)
		var c := Vector2(it["tile"]) + Vector2(fp) * 0.5
		if r.size != Vector2i.ZERO and not Rect2(r.position, r.size).grow(float(maxi(fp.x, fp.y))).has_point(c):
			continue
		var n: Node3D = item_nodes[i]
		var y := ground_y(c.x, c.y)
		if it["t"] != "prop" and it["t"] != "spawn" and fp.x * fp.y > 1:
			# structures stand level on their highest corner (the game seats them on a plinth)
			y = maxf(maxf(ground_y(it["tile"].x, it["tile"].y), ground_y(it["tile"].x + fp.x, it["tile"].y)),
				maxf(ground_y(it["tile"].x, it["tile"].y + fp.y), ground_y(it["tile"].x + fp.x, it["tile"].y + fp.y)))
		n.position = Vector3(c.x, y, c.y)

func ground_y(x: float, z: float) -> float:
	if map == null:
		return 0.0
	var base := 0.0
	if terrain != null and terrain.heights.size() == (map.w + 1) * (map.h + 1):
		var ix := clampi(int(x), 0, map.w - 1)
		var iz := clampi(int(z), 0, map.h - 1)
		var fx := clampf(x - ix, 0.0, 1.0)
		var fz := clampf(z - iz, 0.0, 1.0)
		var k := iz * (map.w + 1) + ix
		var hh := terrain.heights
		base = lerpf(lerpf(hh[k], hh[k + 1], fx), lerpf(hh[k + map.w + 1], hh[k + map.w + 2], fx), fz)
	return base + map.height_at(x, z)

# ------------------------------------------------------------------ overlays
func _ring(mesh: ImmediateMesh, c: Vector2, r: float, seg: int = 40) -> void:
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in seg + 1:
		var a := TAU * float(i) / seg
		var p := c + Vector2(cos(a), sin(a)) * r
		mesh.surface_add_vertex(Vector3(p.x, ground_y(p.x, p.y) + 0.08, p.y))
	mesh.surface_end()

func _rect_outline(mesh: ImmediateMesh, r: Rect2) -> void:
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b)))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			mesh.surface_add_vertex(Vector3(p.x, ground_y(p.x, p.y) + 0.1, p.y))
	mesh.surface_add_vertex(Vector3(r.position.x, ground_y(r.position.x, r.position.y) + 0.1, r.position.y))
	mesh.surface_end()

func brush_radius() -> float:
	return float(canvas.brush) * 0.5 + 0.25

func _draw_cursor() -> void:
	var im: ImmediateMesh = cursor.mesh
	im.clear_surfaces()
	if canvas == null or hover.x < 0 or map == null:
		return
	var t := canvas.tool
	if t in ["paint", "erase"] or t in MapBuilderCanvas.HEIGHT_TOOLS:
		var c := Vector2(_hover_world.x, _hover_world.z) if t in MapBuilderCanvas.HEIGHT_TOOLS else Vector2(hover) + Vector2(0.5, 0.5)
		_ring(im, c, brush_radius())
		_ring(im, c, 0.25, 10)
	elif t == "place" and not canvas.place.is_empty():
		var it := canvas.place.duplicate()
		var fp := MapBuilderCanvas.item_fp(it)
		var o := Vector2i(clampi(hover.x - fp.x / 2, 0, canvas.w - fp.x), clampi(hover.y - fp.y / 2, 0, canvas.h - fp.y))
		_rect_outline(im, Rect2(Vector2(o), Vector2(fp)))
	elif t == "fill":
		_rect_outline(im, Rect2(Vector2(hover), Vector2.ONE))

func _draw_selection() -> void:
	if sel_mark == null:
		return
	var im: ImmediateMesh = sel_mark.mesh
	im.clear_surfaces()
	if canvas == null or canvas.selected < 0 or canvas.selected >= canvas.items.size() or map == null:
		return
	var it: Dictionary = canvas.items[canvas.selected]
	var tile: Vector2i = _drag_tile if _drag_item == canvas.selected and _drag_tile.x >= 0 else it["tile"]
	_rect_outline(im, Rect2(Vector2(tile), Vector2(MapBuilderCanvas.item_fp(it))).grow(0.15))

func set_grid(on: bool) -> void:
	grid_on = on
	grid.visible = on
	_draw_grid()

func _draw_grid() -> void:
	var im: ImmediateMesh = grid.mesh
	im.clear_surfaces()
	if not grid_on or map == null:
		return
	var span := int(clampf(dist * 1.2, 16, 64))
	var x0 := maxi(0, int(target.x) - span)
	var x1 := mini(map.w, int(target.x) + span)
	var y0 := maxi(0, int(target.y) - span)
	var y1 := mini(map.h, int(target.y) + span)
	for x in range(x0, x1 + 1):
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for y in range(y0, y1 + 1):
			im.surface_add_vertex(Vector3(x, ground_y(x, y) + 0.04, y))
		im.surface_end()
	for y in range(y0, y1 + 1):
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for x in range(x0, x1 + 1):
			im.surface_add_vertex(Vector3(x, ground_y(x, y) + 0.04, y))
		im.surface_end()

# ------------------------------------------------------------------ camera
func frame_all() -> void:
	target = Vector2(canvas.w, canvas.h) * 0.5
	dist = clampf(maxf(canvas.w, canvas.h) * 0.75, DIST_MIN, DIST_MAX)
	_update_camera()

func focus(tile: Vector2, d: float = 28.0) -> void:
	target = tile
	dist = clampf(d, DIST_MIN, DIST_MAX)
	_update_camera()

func turn(deg: float) -> void:
	yaw = fposmod(yaw + deg, 360.0)
	_update_camera()

func set_pitch(p: float) -> void:
	pitch = clampf(p, 25.0, 89.0)
	_update_camera()

func zoom_by(f: float) -> void:
	dist = clampf(dist * f, DIST_MIN, DIST_MAX)
	_update_camera()

func pan_pixels(d: Vector2) -> void:
	# drag the ground under the finger: metres per pixel at the target distance
	var mpp := 2.0 * dist * tan(deg_to_rad(cam.fov * 0.5)) / maxf(1.0, size.y)
	var r := Vector2(cos(deg_to_rad(yaw)), -sin(deg_to_rad(yaw)))
	var f := Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw)))
	target -= (r * d.x + f * d.y / maxf(0.35, sin(deg_to_rad(pitch)))) * mpp
	_update_camera()

func _update_camera() -> void:
	if cam == null:
		return
	if canvas != null:
		target = target.clamp(Vector2.ZERO, Vector2(canvas.w, canvas.h))
	var gy := ground_y(target.x, target.y)
	var p := deg_to_rad(pitch)
	var yr := deg_to_rad(yaw)
	var off := Vector3(sin(yr) * cos(p), sin(p), cos(yr) * cos(p)) * dist
	var t3 := Vector3(target.x, gy, target.y)
	cam.position = t3 + off
	cam.look_at(t3, Vector3.UP if pitch < 88.5 else Vector3(-sin(yr), 0, -cos(yr)))
	sun.directional_shadow_max_distance = clampf(dist * 2.4, 40.0, 200.0)
	if grid_on:
		_draw_grid()

# ------------------------------------------------------------------ picking
## Screen point (container pixels) -> the point on the 3D ground, or null.
func pick(p: Vector2) -> Variant:
	if cam == null or map == null:
		return null
	var sp := p * (Vector2(vp.size) / size) if size.x > 0 and size.y > 0 else p
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var step := 0.5
	var prev := o
	var t := 0.0
	while t < 900.0:
		t += step
		var q := o + d * t
		if q.y <= ground_y(q.x, q.z):
			var lo := prev
			var hi := q
			for i in 12:
				var mid := (lo + hi) * 0.5
				if mid.y <= ground_y(mid.x, mid.z):
					hi = mid
				else:
					lo = mid
			if hi.x < 0 or hi.z < 0 or hi.x >= map.w or hi.z >= map.h:
				return null
			return hi
		prev = q
		step = clampf(t * 0.02, 0.25, 2.0)
	return null

func tile_at(p: Vector2) -> Vector2i:
	var q: Variant = pick(p)
	if q == null:
		return Vector2i(-1, -1)
	return Vector2i(floori((q as Vector3).x), floori((q as Vector3).z))

## screen position of a map point (for tests and the UI)
func screen_of(world: Vector3) -> Vector2:
	var s := cam.unproject_position(world)
	return s * (size / Vector2(vp.size)) if vp.size.x > 0 else s

# ------------------------------------------------------------------ input
func _gui_input(ev: InputEvent) -> void:
	if canvas == null:
		return
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_press(st.position)
			elif _touches.size() == 2:
				_begin_gesture()
		else:
			_touches.erase(st.index)
			if _gesture:
				if _touches.is_empty():
					_gesture = false
			elif _touches.is_empty():
				_release(st.position)
		accept_event()
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _gesture and _touches.size() >= 2:
			_update_gesture()
		elif not _gesture:
			_drag(sd.position)
		accept_event()
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(0.88)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(1.0 / 0.88)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				_release(mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_mouse_btn = mb.button_index if mb.pressed else 0
			_last_mouse = mb.position
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _mouse_btn == MOUSE_BUTTON_RIGHT:
			var d := mm.position - _last_mouse
			turn(-d.x * 0.35)
			set_pitch(pitch + d.y * 0.25)
		elif _mouse_btn == MOUSE_BUTTON_MIDDLE:
			pan_pixels(mm.position - _last_mouse)
		elif _down:
			_drag(mm.position)
		else:
			_hover_at(mm.position)
		_last_mouse = mm.position

func _hover_at(p: Vector2) -> void:
	var q: Variant = pick(p)
	var t := Vector2i(-1, -1)
	if q != null:
		_hover_world = q
		t = Vector2i(floori(_hover_world.x), floori(_hover_world.z))
	if t != hover:
		hover = t
		hover_changed.emit(t)
	_draw_cursor()

func _press(p: Vector2) -> void:
	_down = true
	_moved = false
	_press_pos = p
	_path.clear()
	_hover_at(p)
	var tool := canvas.tool
	if hover.x < 0:
		return
	if tool in MapBuilderCanvas.HEIGHT_TOOLS:
		canvas.begin_height(Vector2(_hover_world.x, _hover_world.z))
		_dab()
	elif tool in ["paint", "erase"]:
		canvas.begin_paint(hover)
	elif tool == "select":
		var i := canvas.hit(hover, 1)
		canvas.selected = i
		canvas.selection_changed.emit()
		_drag_item = i
		_drag_tile = Vector2i(-1, -1)
		if i >= 0:
			_drag_off = Vector2(canvas.items[i]["tile"]) - Vector2(_hover_world.x, _hover_world.z)

func _dab() -> void:
	var c := Vector2(_hover_world.x, _hover_world.z)
	if c.distance_to(_last_dab) < brush_radius() * 0.3:
		return
	_last_dab = c
	canvas.height_dab(c, brush_radius(), canvas.tool)

func _drag(p: Vector2) -> void:
	if not _down:
		return
	if p.distance_to(_press_pos) > 8.0:
		_moved = true
	_hover_at(p)
	if hover.x < 0:
		return
	var tool := canvas.tool
	if tool in MapBuilderCanvas.HEIGHT_TOOLS:
		_dab()
	elif tool in ["paint", "erase"]:
		canvas.paint_to(hover)
	elif tool == "select" and _drag_item >= 0 and _moved:
		var it: Dictionary = canvas.items[_drag_item]
		var fp := MapBuilderCanvas.item_fp(it)
		var tl := Vector2(_hover_world.x, _hover_world.z) + _drag_off
		_drag_tile = Vector2i(clampi(roundi(tl.x), 0, canvas.w - fp.x), clampi(roundi(tl.y), 0, canvas.h - fp.y))
		var n: Node3D = item_nodes[_drag_item]
		var c := Vector2(_drag_tile) + Vector2(fp) * 0.5
		n.position = Vector3(c.x, ground_y(c.x, c.y), c.y)
		_draw_selection()

func _release(p: Vector2) -> void:
	if not _down:
		return
	_down = false
	var tool := canvas.tool
	if tool in MapBuilderCanvas.HEIGHT_TOOLS:
		canvas.end_height()
		_last_dab = Vector2(-99, -99)
	elif tool in ["paint", "erase"]:
		canvas.end_paint()
	elif tool == "fill":
		if hover.x >= 0 and not _moved:
			canvas.fill(hover)
	elif tool == "place":
		if hover.x >= 0 and not _moved:
			canvas.place_at(hover)
	elif tool == "select":
		if _drag_item >= 0 and _drag_tile.x >= 0 and _moved:
			canvas.selected = _drag_item
			canvas.move_selected(_drag_tile)
		_drag_item = -1
		_drag_tile = Vector2i(-1, -1)
		_draw_selection()
	_draw_cursor()

func _two() -> Array:
	var k: Array = _touches.keys()
	return [_touches[k[0]], _touches[k[1]]]

func _begin_gesture() -> void:
	# a started stroke is cancelled when a second finger lands
	if _down:
		if canvas.tool in MapBuilderCanvas.HEIGHT_TOOLS:
			canvas.cancel_height()
		elif canvas.tool in ["paint", "erase"]:
			canvas.cancel_paint()
		if _drag_item >= 0:
			_drag_item = -1
			_drag_tile = Vector2i(-1, -1)
			_reseat_items()
		_down = false
	_gesture = true
	var t := _two()
	_g_mid = (t[0] + t[1]) * 0.5
	_g_dist = maxf(1.0, (t[0] as Vector2).distance_to(t[1]))
	_g_ang = ((t[1] as Vector2) - (t[0] as Vector2)).angle()
	_draw_cursor()

func _update_gesture() -> void:
	var t := _two()
	var mid: Vector2 = (t[0] + t[1]) * 0.5
	var d := maxf(1.0, (t[0] as Vector2).distance_to(t[1]))
	var ang := ((t[1] as Vector2) - (t[0] as Vector2)).angle()
	pan_pixels(mid - _g_mid)
	zoom_by(_g_dist / d)
	var da := wrapf(ang - _g_ang, -PI, PI)
	if absf(da) > 0.002:
		turn(rad_to_deg(da))
	_g_mid = mid
	_g_dist = d
	_g_ang = ang
