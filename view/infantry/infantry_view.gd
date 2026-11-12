class_name InfantryView
extends EntityView
## Squad view (M2.2): N soldiers drawn as MultiMesh with baked vertex animation (VatModel).
## Idle / run / fire are picked from the view's own motion and fire events; soldiers drop
## (Death clip) as the squad's HP falls, and the whole squad plays it on death.
## M3.5 Combat Squads: `squad_id` names a Content.SQUAD_MEMBERS entry; each formation slot then
## gets its own model (one MultiMesh per distinct model) and weapons, so only the soldiers who
## carry the weapon that fired take the shooting pose. Machine gunners whose bake has the
## prone clips drop prone to fire (and get up again after a pause or to move); anti-tank
## gunners kneel (bake fire_kneel = 2). Members fall from the end of the list first, as the sim's
## pool drains.
@export var vat: VatModel
@export var formation: PackedVector3Array = PackedVector3Array([Vector3(-0.2, 0, -0.16), Vector3(0.2, 0, -0.14), Vector3(-0.16, 0, 0.2), Vector3(0.2, 0, 0.2)])
@export var squad_id: StringName = &""
const SHADER := preload("res://view/infantry/vat_soldier.gdshader")
const FIRE_HOLD := 0.7          ## seconds a soldier keeps the shooting pose after a shot
const PRONE_HOLD := 2.5         ## M3.5: a machine gunner stays down this long after his last burst
const CORPSE_S := 3.0           ## fallen soldiers fade over this long, then vanish
## states: 0 idle 1 run 2 fire 3 dead 4 lean 5 walk 6 going prone 7 prone fire 8 getting up
const ST_CLIPS := ["idle", "run", "fire", "die", "lean", "walk", "prone_down", "fire_prone", "prone_up"]
static var _mats: Dictionary = {}

var mmi: MultiMeshInstance3D
var mmis: Array = []              ## M3.5: one MultiMeshInstance3D per distinct member model
var _n := 0
var _vats: Array = []             ## per soldier: VatModel
var _slot: PackedInt32Array       ## per soldier: index in its MultiMesh
var _mm_of: PackedInt32Array      ## per soldier: index into mmis
var _weapons: Array = []          ## per soldier: Array of weapon ids ([] = fires with everything)
var _t: PackedFloat32Array        ## per-soldier clip time
var _state: PackedInt32Array
var _dead_t: PackedFloat32Array
var _phase: PackedFloat32Array
var _fire_left: PackedFloat32Array   ## per soldier: shooting-pose time left (goes negative after)
var _last_pos := Vector3.INF
var _speed := 0.0
var _alive := 0
var dying := false
var braced := false               ## M3.3 item 10: manning a barricade (line up, lean over it)
var variant := 0                  ## M3.4: look variant (head gear / packs) of this soldier
var _scale := 1.0                 ## M3.4: slight per-soldier size variation
const SKIN_TONES := [1.0, 0.72, 0.88, 1.08]
## M3.7 (Malachi: wider squad spacing, members scatter): a Combat Squad's formation is spread
## SQUAD_SPREAD times wider and every soldier stands off his slot by up to SCATTER (re-rolled
## each time the squad stops, eased in), never closer than MIN_GAP to a mate. View only.
const SQUAD_SPREAD := 1.6
const SCATTER := 0.14
const MIN_GAP := 0.26
var _base_form := PackedVector3Array()
var _goal_form := PackedVector3Array()
var _was_moving := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	_n = formation.size()
	_alive = _n
	mmi = get_node("Model/Squad")
	var members: Array = Content.squad_members(squad_id) if squad_id != &"" else []
	var by_vat := {}
	_slot.resize(_n)
	_mm_of.resize(_n)
	for i in _n:
		var v: VatModel = vat
		var ws: Array = []
		if i < members.size():
			v = load("res://assets/models/infantry/%s.res" % members[i][0])
			ws = members[i][1]
		_vats.append(v)
		_weapons.append(ws)
		if not by_vat.has(v):
			var inst := mmi if mmis.is_empty() else MultiMeshInstance3D.new()
			if inst != mmi:
				inst.name = "Squad%d" % mmis.size()
				get_node("Model").add_child(inst)
			by_vat[v] = mmis.size()
			mmis.append(inst)
			inst.set_meta("count", 0)
		var k: int = by_vat[v]
		_mm_of[i] = k
		_slot[i] = int(mmis[k].get_meta("count"))
		mmis[k].set_meta("count", _slot[i] + 1)
	for k in mmis.size():
		var inst: MultiMeshInstance3D = mmis[k]
		var v0: VatModel = null
		for i in _n:
			if _mm_of[i] == k:
				v0 = _vats[i]
				break
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = v0.mesh
		mm.instance_count = int(inst.get_meta("count"))
		inst.multimesh = mm
		inst.material_override = _material(v0)
		inst.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, v0.height + 0.4, 1.6))
	_t.resize(_n)
	_state.resize(_n)
	_dead_t.resize(_n)
	_phase.resize(_n)
	_fire_left.resize(_n)
	for i in _n:
		_phase[i] = fposmod(i * 0.37, 1.0)
		_t[i] = _phase[i]
		_fire_left[i] = -99.0
	if squad_id != &"" and _n > 1:
		_base_form = formation.duplicate()
		for i in _n:
			_base_form[i] = Vector3(_base_form[i].x, 0.0, _base_form[i].z) * SQUAD_SPREAD
		_rng.seed = hash(get_instance_id())
		_goal_form = _scattered()
		formation = _goal_form.duplicate()
		for inst in mmis:
			(inst as MultiMeshInstance3D).custom_aabb = AABB(Vector3(-1.3, -0.1, -1.3), Vector3(2.6, (inst as MultiMeshInstance3D).custom_aabb.size.y, 2.6))
	_place_all()
	_apply()

## M3.7: a fresh loose spread around the widened formation (rejection-sampled for MIN_GAP).
func _scattered() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_n)
	for i in _n:
		var best := _base_form[i]
		for attempt in 8:
			var c := _base_form[i] + Vector3(_rng.randf_range(-SCATTER, SCATTER), 0.0, _rng.randf_range(-SCATTER, SCATTER))
			var ok := true
			for j in i:
				if Vector2(c.x - out[j].x, c.z - out[j].z).length() < MIN_GAP:
					ok = false
					break
			if ok:
				best = c
				break
		out[i] = best
	return out

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
	m.set_shader_parameter("vat_min", v.pos_min)
	m.set_shader_parameter("vat_max", v.pos_max)
	_mats[v] = m
	return m

func _mm(i: int) -> MultiMesh:
	return (mmis[_mm_of[i]] as MultiMeshInstance3D).multimesh

## Stand every soldier at his formation slot (or in a line behind a barricade).
func _place_all() -> void:
	if mmis.is_empty():
		return
	var sink := 0.0
	for i in _n:
		if _state.size() > i and _state[i] == 3 and _dead_t[i] > CORPSE_S:
			continue
		var yaw := sin(i * 12.9898) * 0.25
		var xf: Transform3D
		if braced:
			xf = Transform3D(Basis(Vector3.UP, yaw * 0.3).scaled(Vector3.ONE * _scale), Vector3((i - (_n - 1) * 0.5) * 0.17, 0, sin(i * 4.1) * 0.03))
		else:
			xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _scale), formation[i] + Vector3(0, sink, 0))
		_mm(i).set_instance_transform(_slot[i], xf)

func set_team_material(mat: Material) -> void:
	var c := Color(0.18, 0.5, 0.88)
	if mat is ShaderMaterial:
		c = (mat as ShaderMaterial).get_shader_parameter("albedo")
	elif mat is BaseMaterial3D:
		c = (mat as BaseMaterial3D).albedo_color
	for inst in _instances():
		(inst as MultiMeshInstance3D).set_instance_shader_parameter(&"team_color", c)

func _instances() -> Array:
	if not mmis.is_empty():
		return mmis
	if mmi == null:
		mmi = get_node("Model/Squad")
	return [mmi]

## M3.4 WorldView: pick this soldier's look from a stable per-unit seed (the entity id): head
## gear / pack variant, skin tone, a slight uniform tint, height +-4 %, and clip timing.
## M3.5: each member model of a squad gets its own look from the same seed.
func set_variant(seed: int) -> void:
	var h := absi(hash(seed * 7919 + 17))
	variant = h % maxi(1, vat.variants if vat != null else 1)
	_scale = 0.96 + float((h / 7) % 9) * 0.01
	var k := 0
	for inst in _instances():
		var hk := absi(hash(h + k * 131))
		var vv := variant if k == 0 else hk % maxi(1, vat.variants if vat != null else 1)
		(inst as MultiMeshInstance3D).set_instance_shader_parameter(&"variant", float(vv))
		(inst as MultiMeshInstance3D).set_instance_shader_parameter(&"skin_tone", SKIN_TONES[((h if k == 0 else hk) / 5) % SKIN_TONES.size()])
		var tint0 := 0.94 + float(((h if k == 0 else hk) / 11) % 7) * 0.02
		var dirt0 := 0.55
		if squad_id == &"ecc_squad":
			# The mismatch is the baked cloth (Flora, EMR, woodland, olive), so the tint stays near 1.
			tint0 = 0.96 + float(((h if k == 0 else hk) / 11) % 4) * 0.02
			dirt0 = 0.22 + float(((h if k == 0 else hk) / 3) % 4) * 0.06
		elif String(squad_id).begins_with("ecc_"):
			tint0 = 0.76 + float(((h if k == 0 else hk) / 11) % 9) * 0.055
			dirt0 = 0.32 + float(((h if k == 0 else hk) / 3) % 6) * 0.09
		if squad_id in [&"ecc_alfa", &"ecc_spetsnaz", &"ecc_vdv"]:
			tint0 *= 0.78
		(inst as MultiMeshInstance3D).set_instance_shader_parameter(&"tint", tint0)
		(inst as MultiMeshInstance3D).set_instance_shader_parameter(&"dirt_amt", dirt0)
		k += 1
	for i in _phase.size():
		_phase[i] = fposmod(_phase[i] + float(h % 97) / 97.0, 1.0)
	_place_all()

## M3.4: which clip a state plays for this soldier (walk when slow, kneeling fire for some, two
## death falls); older bakes without the clip fall back.
func _clip_name(st: int, i: int) -> String:
	var v: VatModel = _vats[i] if i < _vats.size() else vat
	var cn: String = ST_CLIPS[st]
	if st == 2 and v.fire_kneel > 0 and (v.fire_kneel == 2 or (variant + i) % 2 == 1):
		cn = "fire_kneel"
	elif st == 3 and (variant + i) % 2 == 1:
		cn = "die2"
	if not v.anims.has(cn):
		cn = {"fire_kneel": "fire", "die2": "die", "walk": "run", "lean": "fire"}.get(cn, "fire")
	if not v.anims.has(cn):
		cn = "fire"
	return cn

func can_prone(i: int) -> bool:
	return i < _vats.size() and (_vats[i] as VatModel).anims.has("fire_prone")

func _clip_len(i: int, cn: String) -> float:
	var c: Array = (_vats[i] as VatModel).anims[cn]
	return float(c[1]) / float(c[2])

## WorldView: the squad mans a barricade - soldiers stand in a tight line behind the wall and
## lean over it with their rifles ("lean" clip; older bakes fall back to the shooting pose).
func set_braced(on := true) -> void:
	if braced == on or mmis.is_empty():
		return
	braced = on
	_place_all()

## WorldView: a shot was fired by this squad. M3.5: with a weapon id only its carriers shoot.
func on_fire(wid: StringName = &"") -> void:
	for i in _n:
		if _state[i] == 3:
			continue
		if wid == &"" or (_weapons[i] as Array).is_empty() or (_weapons[i] as Array).has(wid):
			_fire_left[i] = FIRE_HOLD

## Living soldiers who fire this weapon (all living ones for single-weapon views).
func shooters(wid: StringName = &"") -> Array:
	var out: Array = []
	for i in _n:
		if _state[i] != 3 and (wid == &"" or (_weapons[i] as Array).is_empty() or (_weapons[i] as Array).has(wid)):
			out.append(i)
	return out

## Muzzle point of soldier i (view space -> world), lower when he lies prone.
func muzzle(i: int, dir: Vector3) -> Vector3:
	var h: float = (vat.height if vat != null else 0.4)
	var up := h * (0.12 if _state[i] in [6, 7] else 0.6)
	var fwd := 0.14 + (0.22 if _state[i] in [6, 7] else 0.0)
	return global_transform * (formation[i] + Vector3(0, up, 0)) + dir * fwd

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
	if mmis.is_empty() or not is_visible_in_tree():
		return
	var p := global_position
	if _last_pos != Vector3.INF and delta > 0.0:
		_speed = lerpf(_speed, p.distance_to(_last_pos) / delta, minf(1.0, delta * 10.0))
	_last_pos = p
	var moving := _speed > 0.25 and not dying
	var slow := _speed < 0.7
	if not _goal_form.is_empty():
		if moving != _was_moving:
			_goal_form = _base_form.duplicate() if moving else _scattered()
			_was_moving = moving
		var k := minf(1.0, delta * 1.5)
		var changed := false
		for i in _n:
			if formation[i].distance_squared_to(_goal_form[i]) > 0.00001:
				formation[i] = formation[i].lerp(_goal_form[i], k)
				changed = true
		if changed:
			_place_all()
	for i in _n:
		_fire_left[i] = maxf(-99.0, _fire_left[i] - delta)
		if _state[i] == 3:
			_dead_t[i] += delta
		else:
			var s := (5 if slow else 1) if moving else (2 if _fire_left[i] > 0.0 else 0)
			if braced and not moving:
				s = 4
			if can_prone(i) and not braced:
				s = _prone_state(i, s, moving)
			if s != _state[i]:
				_state[i] = s
				_t[i] = (_phase[i] if s != 2 else _phase[i] * 0.3) if s < 6 else 0.0
		_t[i] += delta
	_apply()

## M3.5: machine gunners go prone to fire: down (prone_down), firing (fire_prone, also between
## bursts) until PRONE_HOLD after the last shot or an order to move, then up (prone_up).
func _prone_state(i: int, want: int, moving: bool) -> int:
	var st := _state[i]
	if st == 6:
		if _t[i] >= _clip_len(i, "prone_down"):
			return 7
		return 6
	if st == 7:
		if moving or _fire_left[i] < -PRONE_HOLD:
			return 8
		return 7
	if st == 8:
		if _t[i] >= _clip_len(i, "prone_up"):
			return want if want != 2 else 6
		return 8
	if want == 2:
		return 6
	return want

func _apply() -> void:
	for i in _n:
		var clip: Array = (_vats[i] as VatModel).anims[_clip_name(_state[i], i)]
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
		var mm := _mm(i)
		if _state[i] == 3:
			fade = clampf((_dead_t[i] - 1.2) / (CORPSE_S - 1.2), 0.0, 1.0)
			if _dead_t[i] > CORPSE_S:
				# gone: collapse the instance (no draw cost beyond the vertex shader)
				mm.set_instance_transform(_slot[i], Transform3D(Basis().scaled(Vector3.ONE * 0.001), formation[i]))
		mm.set_instance_custom_data(_slot[i], Color(first + fa, first + fb, bl, fade))
