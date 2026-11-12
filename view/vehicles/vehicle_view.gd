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
## M3.5: every artillery piece (WorldView sets `elevate` for those without one and `aiming` while
## the unit holds a fire mission): the gun / launcher rises before the shot, holds through the
## salvo and lowers after. Pods and tubes pivot at the rear-bottom of their mesh. View only.
var aiming := false
var _pivot := Vector3.ZERO
var _barrel_p0 := Vector3.ZERO

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
## M3.3 builders at work (WorldView sets `working` while the unit stands at its site):
## parts with meta "work" = "blade" (dozer: push, lift, dump), "arm" (backhoe: dig, swing,
## dump) or "boom" (crane: luff up and telescope out). Children with meta "dirt" are the load
## (grows while digging, gone at the dump); meta "tele" slide out along +Z. View only.
var working := false
var work_parts: Array = []   ## [node, kind, rest rotation, [dirt nodes], [tele nodes, rest z]]
var _work_t := 0.0
var _work_k := 0.0           ## 0 = stowed .. 1 = fully working (eases in / out)
var _dumped := false
## M3.4: the packed Minerals Mining excavator (PackRig parts): rests packed (k = 1); while it
## sets up WorldView feeds 1 - MineSys progress so it unfolds in step with the sim's timer.
var pack_rig: PackRig
var pack_target := 1.0
var pack_k := -1.0
var plant := 0.0                 ## 0 travelling, 1 outriggers down (Grim Reaper)
var _plant_k := 0.0
var _outriggers: Node3D
var _rotor: Node3D
var _radar: Node3D
var _radar_rx := 0.0

func _ready() -> void:
	super._ready()
	var m := get_node_or_null("Model")
	if m != null:
		for c in m.get_children():
			if c is Node3D and c.has_meta("work"):
				var dirt: Array = []
				var tele: Array = []
				for d in (c as Node3D).find_children("*", "Node3D", true, false):
					if d.has_meta("dirt"):
						dirt.append(d)
					if d.has_meta("tele"):
						tele.append([d, (d as Node3D).position.z])
				work_parts.append([c, String(c.get_meta("work")), (c as Node3D).rotation, dirt, tele])
	pack_rig = PackRig.from(m)
	if pack_rig != null:
		pack_rig.pose(1.0)
	_outriggers = find_child("Outriggers", true, false) as Node3D
	_rotor = find_child("Rotor", true, false) as Node3D
	_radar = find_child("Radar", true, false) as Node3D
	if _outriggers != null:
		_outriggers.position.y = 0.42
	if _radar != null:
		_radar_rx = _radar.rotation.x
	barrel = find_child("Barrel", true, false)
	if barrel != null:
		_barrel_z = barrel.position.z
		_barrel_rx = barrel.rotation.x
		_barrel_p0 = barrel.position
		for c in barrel.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var bb: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).mesh.get_aabb()
				_pivot = Vector3(0, bb.position.y, minf(0.0, bb.position.z))
				break
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

func set_pack(k: float) -> void:
	pack_target = clampf(k, 0.0, 1.0)
	if pack_k < 0.0:
		pack_k = pack_target
		if pack_rig != null:
			pack_rig.pose(pack_k)

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

func _work(delta: float) -> void:
	_work_k = move_toward(_work_k, 1.0 if working else 0.0, delta * 1.2)
	if _work_k <= 0.0 and not working:
		return
	_work_t += delta * _work_k
	for wp in work_parts:
		var n: Node3D = wp[0]
		var rest: Vector3 = wp[2]
		var dirt: Array = wp[3]
		var ld := 0.0
		var dump := false
		match wp[1]:
			"blade":   # 3.2 s: lower and push (load builds), lift, tip the load out ahead
				var ph := fmod(_work_t / 3.2, 1.0)
				var lift := 0.0
				if ph < 0.5:
					lift = lerpf(0.0, 0.1, ph / 0.5)   # blade digs in (nose down)
					ld = ph / 0.5
				elif ph < 0.75:
					lift = lerpf(0.1, -0.32, (ph - 0.5) / 0.25)
					ld = 1.0
				else:
					lift = lerpf(-0.32, 0.0, (ph - 0.75) / 0.25)
					ld = maxf(0.0, 1.0 - (ph - 0.75) / 0.08)
					dump = ph < 0.8
				n.rotation.x = rest.x + lift * _work_k
			"arm":   # 4 s: dig (arm down), curl up, swing to the side, dump, swing back
				var ph := fmod(_work_t / 4.0, 1.0)
				var dig := 0.0
				var swing := 0.0
				if ph < 0.35:
					dig = sin(ph / 0.35 * PI) * 0.7
					ld = ph / 0.35
				elif ph < 0.55:
					dig = lerpf(0.0, -0.25, (ph - 0.35) / 0.2)
					swing = lerpf(0.0, 0.9, (ph - 0.35) / 0.2)
					ld = 1.0
				elif ph < 0.7:
					dig = -0.25
					swing = 0.9
					ld = maxf(0.0, 1.0 - (ph - 0.55) / 0.06)
					dump = ph < 0.62
				else:
					dig = lerpf(-0.25, 0.0, (ph - 0.7) / 0.3)
					swing = lerpf(0.9, 0.0, (ph - 0.7) / 0.3)
				n.rotation.x = rest.x - dig * _work_k   # -X lowers the rear arm
				n.rotation.y = rest.y + swing * _work_k
			"boom":   # luff up, telescope out, then slow slewing sway while the site rises
				n.rotation.x = rest.x - 0.8 * _ease(_work_k)
				n.rotation.y = rest.y + sin(_work_t * 0.4) * 0.25 * _work_k
				for t in wp[4]:
					(t[0] as Node3D).position.z = float(t[1]) + 0.55 * _ease(clampf(_work_k * 1.6 - 0.6, 0.0, 1.0))
					for hk in (t[0] as Node3D).get_children():
						if hk is Node3D and hk.has_meta("hang"):
							(hk as Node3D).rotation.x = -n.rotation.x   # the hook hangs plumb
		for d in dirt:
			(d as Node3D).visible = ld > 0.02 and _work_k > 0.5
			(d as Node3D).scale = Vector3.ONE * maxf(0.05, ld)
		if dump and not _dumped and dirt.size() > 0:
			var wv = get_parent()
			if wv != null and "vfx" in wv and wv.vfx != null:
				wv.vfx.dust((dirt[0] as Node3D).global_position, 0.45, 0.35)
		_dumped = dump

## Snap to a point in the work cycle (previews / tests).
func work_pose(t: float) -> void:
	working = true
	_work_k = 1.0
	_work_t = t
	_work(0.0)

static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

func set_reactive(on: bool) -> void:
	for n in find_children("ActiveArmor", "MeshInstance3D", true, false):
		(n as Node3D).visible = on

func set_plant(k: float) -> void:
	plant = clampf(k, 0.0, 1.0)

func _process(delta: float) -> void:
	if _rotor != null and not _dead:
		_rotor.rotate_y(delta * 18.0)
	if (_outriggers != null or _radar != null) and not _dead:
		_plant_k = move_toward(_plant_k, plant, delta * 0.5)
		if _outriggers != null:
			_outriggers.position.y = lerpf(0.42, 0.0, _plant_k)
		if _radar != null:
			_radar.rotation.x = _radar_rx + lerpf(-1.15, 0.0, _plant_k)
	if not work_parts.is_empty() and not _dead:
		_work(delta)
	if _dead:
		_dead_t += delta
		if _dead_t > wreck_s - 1.5:   # sink into the ground before it vanishes
			position.y -= delta * 0.25
		return
	if pack_rig != null and pack_k != pack_target:
		pack_k = move_toward(maxf(pack_k, 0.0) if pack_k >= 0.0 else pack_target, pack_target, delta * 0.6)
		pack_rig.pose(pack_k)
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
	var elev_moved := false
	if barrel != null and elevate > 0.0 and (_elev > 0.0 or _elev_hold > 0.0 or aiming):
		_elev_hold = maxf(0.0, _elev_hold - delta)
		var up := _elev_hold > 0.0 or aiming
		_elev = move_toward(_elev, 1.0 if up else 0.0, delta * (1.6 if up else 0.6))
		elev_moved = true
	if barrel != null and (elev_moved or _recoil > 0.0 or barrel.position.z != _barrel_z):
		_recoil = maxf(0.0, _recoil - delta * 3.5)
		# fast kick back, slower return
		var k := _recoil * _recoil * (3.0 - 2.0 * _recoil) if _recoil < 0.85 else (1.0 - _recoil) / 0.15
		var a := elevate * (_elev * _elev * (3.0 - 2.0 * _elev))
		var b := Basis(Vector3.RIGHT, _barrel_rx - a)
		var rb := Basis(Vector3.RIGHT, _barrel_rx)
		barrel.basis = b
		# pivot about the rear of the tube / pod, then recoil along the bore
		barrel.position = _barrel_p0 + rb * _pivot - b * _pivot + b * Vector3(0, 0, -recoil * k)
