class_name WorldOverlay
extends Control
## 2D overlay over the 3D world: health/shield bars, veterancy chevrons, unpowered icons,
## construction progress, far-zoom role icons, the box-select rectangle, hold ring and
## floating income text. Drawn in logical units.

var ctl: PlayerController
var world: WorldView
var cam: CameraRig
var box := Rect2()
var box_on: bool = false
var hold_pos := Vector2.ZERO
var hold_k: float = 0.0
var floaters: Array = []   ## {pos3, text, t, col}
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = get_theme_default_font()

func on_box(r: Rect2, active: bool) -> void:
	box = r.abs()
	box_on = active
	queue_redraw()

func on_hold(p: Vector2, k: float) -> void:
	hold_pos = p
	hold_k = k

func floater(world_pos: Vector3, text: String, col: Color) -> void:
	floaters.append({"p": world_pos, "s": text, "t": 0.0, "c": col})

func _process(delta: float) -> void:
	var keep: Array = []
	for f in floaters:
		f["t"] += delta
		if f["t"] < 1.6:
			keep.append(f)
	floaters = keep
	queue_redraw()

func _draw() -> void:
	if world == null or cam == null:
		return
	var sim := world.sim
	var sel: Dictionary = {}
	for id in ctl.selection:
		sel[id] = true
	var always: bool = Settings.g("always_health_bars")
	var vs := get_viewport_rect().size
	var far := world.icon_mode
	for id in world.views:
		var e: SimEntity = sim.ents.get(id)
		var v: EntityView = world.views[id]
		if e == null or not v.visible and not (far and e.kind == SimEntity.Kind.UNIT and world._is_visible(e, {})):
			continue
		if e.kind == SimEntity.Kind.RESOURCE:
			continue
		var top := v.position + Vector3(0, v.bar_height * (v.scale.y), 0)
		if not cam.cam.is_position_in_frustum(top):
			continue
		var sp := cam.cam.unproject_position(top)
		if far and e.kind == SimEntity.Kind.UNIT:
			_role_icon(e, cam.cam.unproject_position(v.position), sel.has(id))
		var damaged := e.hp < e.max_hp
		var show_bar := sel.has(id) or always or (damaged and e.kind == SimEntity.Kind.UNIT and e.team >= 0) or (e.kind == SimEntity.Kind.BUILDING and (damaged or not e.built))
		if e.kind == SimEntity.Kind.NEUTRAL and e.owner < 0 and not sel.has(id):
			show_bar = false
		if show_bar:
			var w := 26.0 if e.kind == SimEntity.Kind.UNIT else 44.0
			_bar(sp, w, e)
		if e.vet > 0 and e.kind == SimEntity.Kind.UNIT:
			_chevrons(sp + Vector2(-16, -12), e.vet)
		if e.kind == SimEntity.Kind.BUILDING and e.built and not e.powered and e.team == world.local_team:
			_bolt(sp + Vector2(0, -16))
		if e.kind == SimEntity.Kind.NEUTRAL and e.owner >= 0 and Content.building(e.def_id).garrison_capacity > 0:
			var n := 0
			for uid in sim.ids:
				if sim.ents[uid].res_id == -e.id:
					n += 1
			draw_string(font, sp + Vector2(-14, -8), "%d/%d" % [n, Content.building(e.def_id).garrison_capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	if box_on:
		draw_rect(box, Color(0.5, 1.0, 0.6, 0.12), true)
		draw_rect(box, Color(0.5, 1.0, 0.6, 0.9), false, 1.5)
		var c := 6.0
		for corner in [box.position, box.end]:
			draw_circle(corner, c, Color(0.5, 1.0, 0.6, 0.9))
	if hold_k > 0.0:
		draw_arc(hold_pos + Vector2(0, -UiScale.mm(float(Settings.g("ghost_offset_mm")))), 22.0, -PI * 0.5, -PI * 0.5 + TAU * hold_k, 32, Color(1, 0.65, 0.2, 0.9), 3.0)
	for f in floaters:
		var p3: Vector3 = f["p"] + Vector3(0, 1.0 + f["t"] * 1.2, 0)
		if cam.cam.is_position_in_frustum(p3):
			var a: float = 1.0 - f["t"] / 1.6
			var col: Color = f["c"]
			col.a = a
			draw_string(font, cam.cam.unproject_position(p3) - Vector2(16, 0), f["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	if vs.x <= 0:
		return

func _bar(sp: Vector2, w: float, e: SimEntity) -> void:
	var h := 4.0
	var r := Rect2(sp - Vector2(w * 0.5, 0), Vector2(w, h))
	draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	var k := float(e.hp) / float(maxi(1, e.max_hp))
	var col := Color("#43d16b") if k > 0.6 else (Color("#f0c23c") if k > 0.3 else Color("#e8432f"))
	draw_rect(Rect2(r.position, Vector2(w * k, h)), col)
	if e.max_shield > 0 and e.shield > 0:
		var ks := float(e.shield) / float(maxi(1, e.max_shield))
		draw_rect(Rect2(r.position - Vector2(0, 3), Vector2(w * ks, 2)), Color("#6fe3ff"))
	if e.kind == SimEntity.Kind.BUILDING and not e.built:
		var kp := float(e.progress) / float(maxi(1, e.build_ticks))
		draw_rect(Rect2(r.position + Vector2(0, h + 2), Vector2(w * kp, 3)), Color("#ffd166"))

func _chevrons(p: Vector2, n: int) -> void:
	var col := Color("#ffd166") if n < 3 else Color("#ff5a3c")
	for i in mini(n, 3):
		var y := p.y - i * 4.0
		draw_polyline(PackedVector2Array([Vector2(p.x - 4, y - 2), Vector2(p.x, y + 1), Vector2(p.x + 4, y - 2)]), col, 2.0)

func _bolt(p: Vector2) -> void:
	draw_circle(p, 8, Color(0, 0, 0, 0.6))
	draw_colored_polygon(PackedVector2Array([p + Vector2(1, -6), p + Vector2(-4, 1), p + Vector2(0, 1), p + Vector2(-1, 6), p + Vector2(4, -1), p + Vector2(0, -1)]), Color("#ffd23c"))

func _role_icon(e: SimEntity, p: Vector2, selected: bool) -> void:
	var col := Palette.color(world.sim.players[e.owner].color if e.owner >= 0 else -1)
	var role := String(Content.unit(e.def_id).role)
	var s := 6.0
	if selected:
		draw_circle(p, s + 3, Color(1, 1, 1, 0.8))
	match role:
		"infantry", "anti_tank":
			draw_circle(p, s, col)
		"builder", "harvester":
			draw_rect(Rect2(p - Vector2(s, s * 0.6), Vector2(s * 2, s * 1.2)), col)
		"shield", "anti_air":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), col)
		_:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, s), p + Vector2(-s, s)]), col)
