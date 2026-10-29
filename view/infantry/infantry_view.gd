class_name InfantryView
extends EntityView
## Squad view (M2.2): N soldiers drawn as one MultiMesh with baked vertex animation
## (VatModel). Idle / run / fire are picked from the view's own motion and fire events;
## soldiers drop (Death clip) as the squad's HP falls, and the whole squad plays it on death.
@export var vat: VatModel
@export var formation: PackedVector3Array = PackedVector3Array([Vector3(-0.2, 0, -0.16), Vector3(0.2, 0, -0.14), Vector3(-0.16, 0, 0.2), Vector3(0.2, 0, 0.2)])
const SHADER := preload("res://view/infantry/vat_soldier.gdshader")
const FIRE_HOLD := 0.7          ## seconds a soldier keeps the shooting pose after a shot
const CORPSE_S := 3.0           ## fallen soldiers fade over this long, then vanish
static var _mats: Dictionary = {}

var mmi: MultiMeshInstance3D
var _n := 0
var _t: PackedFloat32Array        ## per-soldier clip time
var _state: PackedInt32Array      ## 0 idle 1 run 2 fire 3 dead
var _dead_t: PackedFloat32Array
var _phase: PackedFloat32Array
var _fire_left := 0.0
var _last_pos := Vector3.INF
var _speed := 0.0
var _alive := 0
var dying := false
var braced := false               ## M3.3 item 10: manning a barricade (line up, lean over it)
var variant := 0                  ## M3.4: look variant (head gear / packs) of this soldier
var _scale := 1.0                 ## M3.4: slight per-soldier size variation
const SKIN_TONES := [1.0, 0.72, 0.88, 1.08]

func _ready() -> void:
	super._ready()
	_n = formation.size()
	_alive = _n
	mmi = get_node("Model/Squad")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = vat.mesh
	mm.instance_count = _n
	mmi.multimesh = mm
	mmi.material_override = _material(vat)
	mmi.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, vat.height + 0.4, 1.6))
	_t.resize(_n)
	_state.resize(_n)
	_dead_t.resize(_n)
	_phase.resize(_n)
	for i in _n:
		# small per-soldier facing / timing variety; stable per formation slot
		var yaw := sin(i * 12.9898) * 0.25
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _scale), formation[i]))
		_phase[i] = fposmod(i * 0.37, 1.0)
		_t[i] = _phase[i]
	_apply()

static func _material(v: VatModel) -> ShaderMaterial:
	if _mats.has(v):
		return _mats[v]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("vat_pos", v.pos_tex)
	m.set_shader_parameter("vat_nrm", v.nrm_tex)
	m.set_shader_parameter("vat_w", v.width)
	m.set_shader_parameter("vat_rows", v.rows)
	m.set_shader_parameter("vat_fmt", v.fmt)
	_mats[v] = m
	return m

func set_team_material(mat: Material) -> void:
	var c := Color(0.18, 0.5, 0.88)
	if mat is ShaderMaterial:
		c = (mat as ShaderMaterial).get_shader_parameter("albedo")
	elif mat is BaseMaterial3D:
		c = (mat as BaseMaterial3D).albedo_color
	if mmi == null:
		mmi = get_node("Model/Squad")
	mmi.set_instance_shader_parameter(&"team_color", c)

## M3.4 WorldView: pick this soldier's look from a stable per-unit seed (the entity id): head
## gear / pack variant, skin tone, a slight uniform tint, height +-4 %, and clip timing.
func set_variant(seed: int) -> void:
	var h := absi(hash(seed * 7919 + 17))
	variant = h % maxi(1, vat.variants if vat != null else 1)
	_scale = 0.96 + float((h / 7) % 9) * 0.01
	if mmi == null:
		mmi = get_node("Model/Squad")
	mmi.set_instance_shader_parameter(&"variant", float(variant))
	mmi.set_instance_shader_parameter(&"skin_tone", SKIN_TONES[(h / 5) % SKIN_TONES.size()])
	mmi.set_instance_shader_parameter(&"tint", 0.94 + float((h / 11) % 7) * 0.02)
	for i in _phase.size():
		_phase[i] = fposmod(_phase[i] + float(h % 97) / 97.0, 1.0)
	if mmi.multimesh != null:
		for i in _n:
			var yaw := sin(i * 12.9898) * 0.25
			mmi.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _scale), formation[i]))

## M3.4: which clip a state plays for this soldier (walk when slow, kneeling fire for some, two
## death falls); older bakes without the clip fall back.
func _clip_name(st: int, i: int) -> String:
	var cn: String = ["idle", "run", "fire", "die", "lean", "walk"][st]
	if st == 2 and vat.fire_kneel > 0 and (vat.fire_kneel == 2 or (variant + i) % 2 == 1):
		cn = "fire_kneel"
	elif st == 3 and (variant + i) % 2 == 1:
		cn = "die2"
	if not vat.anims.has(cn):
		cn = {"fire_kneel": "fire", "die2": "die", "walk": "run", "lean": "fire"}.get(cn, "fire")
	if not vat.anims.has(cn):
		cn = "fire"
	return cn

## WorldView: the squad mans a barricade - soldiers stand in a tight line behind the wall and
## lean over it with their rifles ("lean" clip; older bakes fall back to the shooting pose).
func set_braced(on := true) -> void:
	if braced == on or mmi == null:
		return
	braced = on
	var mm := mmi.multimesh
	for i in _n:
		var yaw := sin(i * 12.9898) * 0.25
		var xf := Transform3D(Basis(Vector3.UP, yaw), formation[i])
		if on:
			xf = Transform3D(Basis(Vector3.UP, yaw * 0.3).scaled(Vector3.ONE * _scale), Vector3((i - (_n - 1) * 0.5) * 0.17, 0, sin(i * 4.1) * 0.03))
		else:
			xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _scale), formation[i])
		mm.set_instance_transform(i, xf)

## WorldView: a shot was fired by this squad.
func on_fire() -> void:
	_fire_left = FIRE_HOLD

## WorldView: squad health 0..1; soldiers fall as it drops (at least one stands while alive).
func set_health(k: float) -> void:
	var want := clampi(int(ceil(k * _n - 0.001)), 1, _n)
	while _alive > want:
		_kill_one()

func _kill_one() -> void:
	for i in range(_n - 1, -1, -1):
		if _state[i] != 3:
			_state[i] = 3
			_t[i] = 0.0
			_dead_t[i] = 0.0
			_alive -= 1
			return

## WorldView: the squad died. Returns how long the view should linger before being freed.
func play_death() -> float:
	dying = true
	while _alive > 0:
		_kill_one()
	return CORPSE_S + 0.2

func _process(delta: float) -> void:
	if mmi == null or not is_visible_in_tree():
		return
	var p := global_position
	if _last_pos != Vector3.INF and delta > 0.0:
		_speed = lerpf(_speed, p.distance_to(_last_pos) / delta, minf(1.0, delta * 10.0))
	_last_pos = p
	_fire_left = maxf(0.0, _fire_left - delta)
	var moving := _speed > 0.25 and not dying
	var slow := _speed < 0.7
	for i in _n:
		if _state[i] == 3:
			_dead_t[i] += delta
		else:
			var s := (5 if slow else 1) if moving else (2 if _fire_left > 0.0 else 0)
			if braced and not moving:
				s = 4
			if s != _state[i]:
				_state[i] = s
				_t[i] = _phase[i] if s != 2 else _phase[i] * 0.3
		_t[i] += delta
	_apply()

func _apply() -> void:
	var mm := mmi.multimesh
	for i in _n:
		var clip: Array = vat.anims[_clip_name(_state[i], i)]
		var first: int = clip[0]
		var count: int = clip[1]
		var fps: float = clip[2]
		var loop: bool = clip[3] == 1
		var f := _t[i] * fps * (1.15 if _state[i] == 1 else 1.0)
		var fa: int
		var fb: int
		var bl: float
		if loop:
			var ff := fposmod(f, float(count))
			fa = int(ff)
			fb = (fa + 1) % count
			bl = ff - fa
		else:
			var ff2 := minf(f, float(count - 1))
			fa = int(ff2)
			fb = mini(fa + 1, count - 1)
			bl = ff2 - fa
		var fade := 0.0
		if _state[i] == 3:
			fade = clampf((_dead_t[i] - 1.2) / (CORPSE_S - 1.2), 0.0, 1.0)
			if _dead_t[i] > CORPSE_S:
				# gone: collapse the instance (no draw cost beyond the vertex shader)
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), formation[i]))
		mm.set_instance_custom_data(i, Color(first + fa, first + fb, bl, fade))
