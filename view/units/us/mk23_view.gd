extends InfantryView
## MK 23 team. The launcher is carried, then the crew plants a tripod and mounts it.
## WorldView drives set_setup from the sim setup timer. Combat stays locked until that timer ends.
## A move order drops the target to 0 and the rig folds back up while they walk.

var _want := 0.0
var _k := 0.0
var _rig: Node3D
var _legs: Array = []
var _gun: Node3D

func _ready() -> void:
	super._ready()
	_build_rig()

## k is 0 carried, 1 planted. Hidden views snap so scrolling back does not replay the plant.
func set_setup(k: float) -> void:
	_want = clampf(k, 0.0, 1.0)
	if not is_visible_in_tree():
		_k = _want

func _process(delta: float) -> void:
	super._process(delta)
	if _rig == null:
		return
	var rate := 1.6 if _want < _k else 0.22
	_k = move_toward(_k, _want, delta * rate)
	# Carried: a small folded launcher between the crew. Planted: full tripod on the ground.
	_rig.position = Vector3(-0.12, lerpf(0.22, 0.0, _k), lerpf(0.02, 0.24, _k))
	var sc := lerpf(0.38, 1.0, _k)
	_rig.scale = Vector3(sc, sc, sc)
	for leg in _legs:
		(leg as Node3D).rotation.x = lerpf(0.25, 0.82, _k)
	if _gun != null:
		_gun.rotation.x = lerpf(1.15, 0.04, _k)
	if _k > 0.25 and _speed < 0.25 and not dying:
		for i in _n:
			if i == 0 and _state[i] != 3:
				_fire_left[i] = maxf(_fire_left[i], 0.25)

func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.name = "Tripod"
	get_node("Model").add_child(_rig)
	var steel := _mat(Color("#3c3e3a"))
	var dark := _mat(Color("#2a2c28"))
	_rig.add_child(_box(Vector3(0, 0.36, 0), Vector3(0.07, 0.045, 0.07), steel))
	for ang in [0.15, 2.25, -1.95]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.34, 0)
		pivot.rotation.y = ang
		_rig.add_child(pivot)
		pivot.add_child(_box(Vector3(0, -0.16, 0.015), Vector3(0.016, 0.32, 0.016), dark))
		var foot := _box(Vector3(0, -0.32, 0.03), Vector3(0.04, 0.012, 0.05), steel)
		pivot.add_child(foot)
		_legs.append(pivot)
	_gun = Node3D.new()
	_gun.position = Vector3(0, 0.39, 0)
	_rig.add_child(_gun)
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.022
	cyl.height = 0.42
	tube.mesh = cyl
	tube.rotation.x = PI * 0.5
	tube.position = Vector3(0, 0.02, 0.12)
	tube.material_override = dark
	_gun.add_child(tube)
	_gun.add_child(_box(Vector3(0, 0.02, -0.06), Vector3(0.05, 0.05, 0.08), steel))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.72
	return m

func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	return mi
