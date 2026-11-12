class_name BuildingView
extends EntityView
## Staged structure view (M2.2): construction in stages (foundation + scaffold going up, the
## structure rising inside it with a glowing build edge, scaffold struck on completion), damage
## states (light: soot, debris, a smoke wisp; heavy: scorched breaches, fallen sheeting, fires
## at the Fire* anchors) and a destroyed state (smouldering rubble that lingers, then sinks).
## Meshes use view/materials/model_m3.gdshader; the reveal variant is swapped in only while
## building (discard is costly on tile GPUs).
const MAT := preload("res://view/materials/m3.tres")
const MAT_REVEAL := preload("res://view/materials/m3_reveal.tres")
const KEEP := [&"team_color", &"rust_amt", &"wear_amt", &"dirt_amt", &"damage_amt"]
@export var top_y: float = 1.6          ## structure height (object space) for the reveal
@export var scaffold_top: float = 1.35
@export var rubble_s: float = 14.0      ## destroyed rubble lingers this long

var hull: GeometryInstance3D
var scaffold: GeometryInstance3D
var dmg_light: Node3D
var dmg_heavy: Node3D
var rubble: Node3D
var anchors: Array = []
var _geos: Array = []
var _prog := -1.0
var _building := false
var _state := 0          ## 0 ok, 1 light, 2 heavy, 3 destroyed
var _smoke_t := 0.0
var _dead_t := 0.0
var external_scaffold := false   ## M2.4: a ConstructionRig draws the faction's scaffold instead
var under_construction := false
var anim_parts: Array = []      ## M3.3: [node, kind, base rotation] - "spin" / "nod" / "door"
var _anim_t := 0.0
var _door_t := 0.0              ## seconds the silo hatch stays open after a launch
var loaded_round: GeometryInstance3D   ## standing missile hidden while the hatches are open
var _reveal_parts: Array = []   ## hatches and the loaded round, clipped with the hull while building
var pack_rig: PackRig           ## M3.4: Minerals Mining excavator pack-up parts (null elsewhere)
var pack_target := 0.0          ## WorldView: MineSys pack-up progress 0..1
var pack_k := -1.0              ## shown pose (eases after the target; -1 = not posed yet)
var _spin := 0.0
var _tower: Node3D
var _tower_kind := ""

## A researched Russian tower, mounted on TowerMount or on the roof line.
func set_tower(kind: String) -> void:
	if kind == _tower_kind:
		return
	_tower_kind = kind
	if _tower != null:
		_tower.queue_free()
		_tower = null
	if kind == "":
		return
	var path := "res://view/buildings/ecc/tower_%s.tscn" % kind
	if not ResourceLoader.exists(path):
		return
	_tower = (load(path) as PackedScene).instantiate()
	var mount := find_child("TowerMount", true, false) as Node3D
	_tower.position = mount.position if mount != null else Vector3(0, top_y * 0.82, 0)
	var model := get_node_or_null("Model")
	if model != null:
		model.add_child(_tower)

func _ready() -> void:
	super._ready()
	hull = get_node_or_null("Model/Hull")
	scaffold = get_node_or_null("Model/Scaffold")
	dmg_light = get_node_or_null("Model/DamageLight")
	dmg_heavy = get_node_or_null("Model/DamageHeavy")
	rubble = get_node_or_null("Model/Rubble")
	for c in get_node("Model").get_children():
		if c is Marker3D and String(c.name).begins_with("Fire"):
			anchors.append(c)
	_gather(self)
	for c in get_node("Model").get_children():
		if c is Node3D and c.has_meta("anim"):
			anim_parts.append([c, String(c.get_meta("anim")), (c as Node3D).rotation])
	pack_rig = PackRig.from(get_node("Model"))
	if pack_rig != null:
		pack_rig.pose(0.0)
	loaded_round = get_node_or_null("Model/LoadedRound")
	for c in get_node("Model").get_children():
		if c is GeometryInstance3D and (c == loaded_round or String(c.get_meta("anim", "")) == "door"):
			_reveal_parts.append(c)

## M3.4: pack-up progress from the sim (0 = set up, 1 = about to drive off). The pose follows
## it smoothly (a cancelled pack-up eases back out); the first call snaps (a loaded save).
func set_pack(k: float) -> void:
	pack_target = clampf(k, 0.0, 1.0)
	if pack_k < 0.0:
		pack_k = pack_target
		if pack_rig != null:
			pack_rig.pose(pack_k, _spin)

func _pack_step(delta: float) -> void:
	if pack_k < 0.0:
		pack_k = pack_target
	pack_k = move_toward(pack_k, pack_target, delta * 0.6)
	pack_rig.pose(pack_k, _spin)

func _gather(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			_geos.append(c)
		_gather(c)

func _each(param: StringName, v: Variant) -> void:
	for g in _geos:
		(g as GeometryInstance3D).set_instance_shader_parameter(param, v)

func set_team_material(mat: Material) -> void:
	var c := Color(0.6, 0.6, 0.6)
	if mat is ShaderMaterial:
		c = (mat as ShaderMaterial).get_shader_parameter("albedo")
	_each(&"team_color", c)

## Swaps a mesh between the normal and the clipping material, keeping its instance values.
func _swap(g: GeometryInstance3D, mat: Material) -> void:
	if g == null or g.material_override == mat:
		return
	var keep := {}
	for p in KEEP:
		keep[p] = g.get_instance_shader_parameter(p)
	g.material_override = mat
	for p in keep:
		if keep[p] != null:
			g.set_instance_shader_parameter(p, keep[p])

## k = construction progress 0..1 (1 = complete).
func set_build_progress(k: float) -> void:
	if is_equal_approx(k, _prog):
		return
	_prog = k
	var done := k >= 1.0
	var reveal_y := top_y * clampf((k - 0.12) / 0.83, 0.0, 1.0) + 0.02
	if done:
		if _building or scaffold == null or scaffold.visible:
			_building = false
			_swap(hull, null)
			for p in _reveal_parts:
				_swap(p, null)
			if scaffold:
				scaffold.visible = false
		return
	if not _building:
		_building = true
		_swap(hull, MAT_REVEAL)
		if scaffold:
			scaffold.visible = not external_scaffold
			_swap(scaffold, MAT_REVEAL)
	if scaffold and external_scaffold and scaffold.visible:
		scaffold.visible = false
	# stage 1 (0..25 %): scaffold climbs; stage 2 (12..95 %): the structure rises inside it
	if scaffold and scaffold.visible:
		scaffold.set_instance_shader_parameter(&"reveal_y", scaffold_top * 1.05 * clampf(k / 0.25, 0.0, 1.0) - 0.02)
	hull.set_instance_shader_parameter(&"reveal_y", reveal_y)
	for p in _reveal_parts:
		_swap(p, MAT_REVEAL)
		(p as GeometryInstance3D).set_instance_shader_parameter(&"reveal_y", reveal_y)

## k = hp / max_hp, or while under construction hp / the HP the scaffold has reached so far
## (WorldView), so a healthy site always looks clean. A site that took fire shows at most the
## light state (soot, a wisp of smoke): no fires or breaches on an unfinished frame.
func set_damage(k: float, constructing: bool = false) -> void:
	if _state == 3:
		return
	under_construction = constructing
	var s := 0 if k > 0.75 else (1 if k > 0.4 else 2)
	if constructing:
		s = mini(s, 1)
	if s == _state and _prog >= 0.0:
		return
	_state = s
	if dmg_light:
		dmg_light.visible = s >= 1
	if dmg_heavy:
		dmg_heavy.visible = s >= 2
	_each(&"damage_amt", [0.0, 0.22, 0.5][s])

func play_death() -> float:
	_state = 3
	for n in [hull, scaffold, dmg_light, dmg_heavy, loaded_round]:
		if n:
			n.visible = false
	for a in anim_parts:
		(a[0] as Node3D).visible = false
	if rubble:
		rubble.visible = true
	_each(&"damage_amt", 0.85)
	return rubble_s

## M3.3: a launch from this structure (WorldView): silo hatches swing open for a moment.
func on_fire() -> void:
	_door_t = 2.4

## Moving parts (bucket wheel, pumpjack beam, silo hatches): only when built, not destroyed and
## on screen. A node rotation each, no extra draw calls.
func _animate(delta: float) -> void:
	_anim_t += delta
	_door_t = maxf(0.0, _door_t - delta)
	var live := _prog >= 1.0 or _prog < 0.0
	for a in anim_parts:
		var n: Node3D = a[0]
		var base: Vector3 = a[2]
		match a[1]:
			"spin":
				if live and pack_rig != null and n.has_meta("pack_pivot"):   # M3.4: the rig places the wheel
					_spin = wrapf(_spin + delta * float(n.get_meta("speed", 1.0)) * PackRig.spin_factor(maxf(pack_k, 0.0)), -PI, PI)
				elif live:
					if n.get_meta("axis", "x") == "y":   # M3.3: fan rotors (combined-cycle condenser)
						n.rotation.y = wrapf(n.rotation.y + delta * float(n.get_meta("speed", 1.0)), -PI, PI)
					else:
						n.rotation.x = wrapf(n.rotation.x + delta * float(n.get_meta("speed", 1.0)), -PI, PI)
			"nod":
				if live:
					n.rotation.x = base.x + sin(_anim_t * float(n.get_meta("speed", 1.5))) * float(n.get_meta("amp", 0.2))
			"door":
				var want := deg_to_rad(float(n.get_meta("open_deg", 90.0))) if _door_t > 0.0 else 0.0
				n.rotation.z = move_toward(n.rotation.z, base.z + want, delta * (5.0 if _door_t > 0.0 else 1.6))
	if loaded_round != null and _state < 3:
		loaded_round.visible = _door_t <= 0.0
	if pack_rig != null:
		_pack_step(delta)

func _process(delta: float) -> void:
	if not anim_parts.is_empty() and _state < 3 and is_visible_in_tree():
		_animate(delta)
	if _state == 0 or not is_visible_in_tree():
		return
	var wv = get_parent()
	if wv == null or not ("vfx" in wv) or wv.vfx == null:
		return
	if _state == 3:
		_dead_t += delta
		if _dead_t > rubble_s - 2.5:
			position.y -= delta * 0.12
	_smoke_t += delta
	var every := 0.9 if _state == 1 else 0.28
	if _state == 3 and _dead_t > 9.0:
		every = 0.8
	if _smoke_t < every or anchors.is_empty():
		return
	_smoke_t = 0.0
	if _state == 1:   # one thin, dark wisp
		wv.vfx.smoke_puff((anchors[0] as Node3D).global_position, 0.22, false)
		return
	for a in anchors:
		if randf() < 0.6:
			wv.vfx.smoke_puff((a as Node3D).global_position, 0.45, _state >= 2 and (_state == 2 or _dead_t < 9.0))
