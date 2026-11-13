extends VehicleView
## Bare MZKT-7930. The chosen module is parented on ModuleMount.
## A and C play their authored deploy clip from the sim's plant timer.
## Yaw follows the sim turret heading. Module scripts own which way "forward" points.

const SCENES := {
	&"ecc_mzkt_aa": "res://view/units/ecc/mzkt_aa_module.tscn",
	&"ecc_mzkt_radar": "res://view/units/ecc/mzkt_radar_module.tscn",
	&"ecc_mzkt_missile": "res://view/units/ecc/mzkt_missile_module.tscn",
}

var _kind: StringName = &""
var _mod: Node3D
var _anim: AnimationPlayer
var _array: Node3D
var _spin := false

func sync_mzkt(def_id: StringName, plant_k: float, yaw_deg: float, has_aim: bool, aim_pos: Vector3, spin: bool) -> void:
	_mount(def_id)
	_spin = spin and def_id == &"ecc_mzkt_radar"
	if _anim != null and _anim.has_animation(&"deploy"):
		_anim.play(&"deploy")
		_anim.seek(clampf(plant_k, 0.0, 1.0) * _anim.get_animation(&"deploy").length, true)
		_anim.pause()
	if _mod == null:
		return
	if has_aim and _mod.has_method("aim_at"):
		_mod.aim_at(aim_pos)
		return
	var rel := wrapf(yaw_deg, -180.0, 180.0)
	if def_id == &"ecc_mzkt_missile":
		rel = wrapf(rel - 180.0, -180.0, 180.0)
	if "target_yaw_deg" in _mod:
		_mod.target_yaw_deg = rel

func _mount(def_id: StringName) -> void:
	if def_id == _kind:
		return
	_kind = def_id
	if _mod != null:
		_mod.queue_free()
		_mod = null
		_anim = null
		_array = null
	if not SCENES.has(def_id):
		return
	var mount := find_child("ModuleMount", true, false) as Node3D
	if mount == null:
		return
	_mod = (load(SCENES[def_id]) as PackedScene).instantiate()
	mount.add_child(_mod)
	_anim = _mod.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_array = _mod.find_child("ArrayPivot", true, false) as Node3D

func _process(delta: float) -> void:
	super._process(delta)
	if _spin and _array != null and not _dead:
		_array.rotate_y(delta * 0.35)
