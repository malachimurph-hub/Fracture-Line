class_name VehicleView
extends EntityView
## Articulated vehicle view (M2.2): turret yaw (TurretPivot, driven by WorldView), barrel
## recoil on fire, wheels / road wheels spinning and track links scrolling with the distance
## the view actually moved (vertex shader, so a whole hull stays one draw call), front-wheel
## steering from the turn rate, soot / scorch as it takes damage and a burnt-out wreck on death.
## Meshes use view/materials/model_m3.gdshader (team colour + damage as instance uniforms).
@export var recoil: float = 0.12        ## barrel travel (world units) per shot
@export var steer_max: float = 0.0      ## radians; 0 = no steering wheels
@export var wreck_s: float = 7.0        ## how long the burnt wreck stays
@export var elevate: float = 0.0        ## M3.1: radians the barrel lifts while firing (M109A7); 0 = fixed

var _barrel_rx := 0.0
var _elev := 0.0
var _elev_hold := 0.0

var barrel: Node3D
var _barrel_z := 0.0
var _geos: Array = []
var _movers: Array = []                 ## meshes with wheels / tracks (get wheel_dist)
var _dist := 0.0
var _last_pos := Vector3.INF
var _last_yaw := 0.0
var _steer := 0.0
var _recoil := 0.0
var _dmg := 0.0
var _dead := false
var _dead_t := 0.0

func _ready() -> void:
	super._ready()
	barrel = find_child("Barrel", true, false)
	if barrel != null:
		_barrel_z = barrel.position.z
		_barrel_rx = barrel.rotation.x
	_gather(self)

func _gather(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			_geos.append(c)
			if c.has_meta("moves"):
				_movers.append(c)
		_gather(c)

func _each(param: StringName, v: Variant) -> void:
	for g in _geos:
		(g as GeometryInstance3D).set_instance_shader_parameter(param, v)

func set_team_material(mat: Material) -> void:
	var c := Color(0.6, 0.6, 0.6)
	if mat is ShaderMaterial:
		c = (mat as ShaderMaterial).get_shader_parameter("albedo")
	elif mat is StandardMaterial3D:
		c = (mat as StandardMaterial3D).albedo_color
	_each(&"team_color", c)

func on_fire() -> void:
	_recoil = 1.0
	_elev_hold = 4.0
	if elevate > 0.0 and _elev < 0.5:
		_elev = 0.5   # snap most of the way up so the shot leaves an elevated tube

## k = hp / max_hp: soot builds up below ~80 % health.
func set_health(k: float) -> void:
	if _dead:
		return
	var d := clampf((0.85 - k) / 0.85, 0.0, 1.0) * 0.7
	if absf(d - _dmg) > 0.02:
		_dmg = d
		_each(&"damage_amt", d)

func play_death() -> float:
	_dead = true
	_each(&"damage_amt", 1.0)
	if turret != null:   # blown turret sits askew
		turret.rotation += Vector3(0.12, randf_range(-0.6, 0.6), 0.08)
	if barrel != null:
		barrel.rotation.x = 0.18
	return wreck_s

func _process(delta: float) -> void:
	if _dead:
		_dead_t += delta
		if _dead_t > wreck_s - 1.5:   # sink into the ground before it vanishes
			position.y -= delta * 0.25
		return
	var p := global_position
	if _last_pos != Vector3.INF:
		var mv := p - _last_pos
		var fwd := global_basis.z
		var d := mv.dot(fwd)
		if absf(d) > 0.00001:
			_dist += d
			for g in _movers:
				(g as GeometryInstance3D).set_instance_shader_parameter(&"wheel_dist", _dist)
		if steer_max > 0.0:
			var yaw := global_rotation.y
			var rate := angle_difference(_last_yaw, yaw) / maxf(delta, 0.001)
			_steer = lerpf(_steer, clampf(rate * 0.35, -steer_max, steer_max), minf(1.0, delta * 8.0))
			_last_yaw = yaw
			for g in _movers:
				(g as GeometryInstance3D).set_instance_shader_parameter(&"steer", _steer)
	else:
		_last_yaw = global_rotation.y
	_last_pos = p
	if barrel != null and elevate > 0.0 and (_elev > 0.0 or _elev_hold > 0.0):
		_elev_hold = maxf(0.0, _elev_hold - delta)
		_elev = move_toward(_elev, 1.0 if _elev_hold > 0.0 else 0.0, delta * (2.5 if _elev_hold > 0.0 else 0.6))
		barrel.rotation.x = _barrel_rx - elevate * (_elev * _elev * (3.0 - 2.0 * _elev))
	if barrel != null and (_recoil > 0.0 or barrel.position.z != _barrel_z):
		_recoil = maxf(0.0, _recoil - delta * 3.5)
		# fast kick back, slower return
		var k := _recoil * _recoil * (3.0 - 2.0 * _recoil) if _recoil < 0.85 else (1.0 - _recoil) / 0.15
		barrel.position.z = _barrel_z - recoil * k
