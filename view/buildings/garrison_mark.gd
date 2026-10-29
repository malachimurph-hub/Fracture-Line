class_name GarrisonMark
extends Node3D
## M3.3 item 11: a garrisoned (or captured) civilian structure shows its occupier: a flag in
## the team colour on a pole on the roof and a team-colour outline on the ground round the
## footprint. View only; hidden again when the building is empty. Two tiny meshes, no lights.

var flag: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0

## Show (team colour index >= 0) or hide the mark on a neutral structure's view.
static func apply(v: Node3D, color_idx: int) -> void:
	var m: GarrisonMark = v.get_node_or_null("GarrisonMark")
	if color_idx < 0:
		if m != null:
			m.visible = false
		return
	if m == null:
		m = GarrisonMark.new()
		m.name = "GarrisonMark"
		v.add_child(m)
		m._build(v)
	m.visible = true
	m._mat.albedo_color = Palette.color(color_idx)

static func _bounds(v: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := v.global_transform.affine_inverse() if v.is_inside_tree() else Transform3D.IDENTITY
	for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.name == "GarrisonMark" or mi.get_parent() is GarrisonMark:
			continue
		var xf := (inv * mi.global_transform) if v.is_inside_tree() else _rel(v, mi)
		var bb: AABB = xf * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out if not first else AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.2, 1.6))

static func _rel(v: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != v:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _build(v: Node3D) -> void:
	var bb := _bounds(v)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pole_m := StandardMaterial3D.new()
	pole_m.albedo_color = Color(0.82, 0.82, 0.8)
	pole_m.roughness = 0.5
	pole_m.metallic = 0.6
	# a structure with its own team-colour flag (civilian block) only gets the outline
	var tm = v.get("team_meshes")
	if tm is Array and not (tm as Array).is_empty():
		_outline(bb)
		return
	# pole on the roof ridge (top of the bounds, centre); its foot runs down into the roof
	var top := Vector3(bb.get_center().x, bb.end.y - 0.04, bb.get_center().z)
	var ph := clampf(bb.size.y * 0.45, 0.45, 0.8)
	var foot := bb.size.y * 0.4
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.022
	cm.height = ph + foot
	cm.radial_segments = 6
	cm.rings = 1
	pole.mesh = cm
	pole.material_override = pole_m
	pole.position = top + Vector3(0, (ph - foot) * 0.5, 0)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pole)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 8
	sm.rings = 4
	knob.mesh = sm
	knob.material_override = pole_m
	knob.position = top + Vector3(0, ph + 0.02, 0)
	add_child(knob)
	# flag: a thin cloth hinged at the pole (sways in _process)
	flag = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.44, 0.27, 0.012)
	flag.mesh = fm
	flag.material_override = _mat
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = top + Vector3(0, ph - 0.15, 0)
	add_child(hinge)
	hinge.add_child(flag)
	flag.position = Vector3(0.23, 0, 0)
	_outline(bb)

## team-colour outline on the ground round the footprint
func _outline(bb: AABB) -> void:
	var g := MeshInstance3D.new()
	g.name = "Outline"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := bb.position.x - 0.12
	var x1 := bb.end.x + 0.12
	var z0 := bb.position.z - 0.12
	var z1 := bb.end.z + 0.12
	var w := 0.07
	for r in [[x0, z0, x1, z0 + w], [x0, z1 - w, x1, z1], [x0, z0, x0 + w, z1], [x1 - w, z0, x1, z1]]:
		var a := Vector3(r[0], 0.04, r[1])
		var b := Vector3(r[2], 0.04, r[1])
		var c := Vector3(r[2], 0.04, r[3])
		var d := Vector3(r[0], 0.04, r[3])
		for p in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	g.mesh = st.commit()
	g.material_override = _mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)

func _process(delta: float) -> void:
	if not visible or flag == null:
		return
	_t += delta
	var h: Node3D = flag.get_parent()
	h.rotation.y = sin(_t * 1.3) * 0.35 + 0.3
	flag.rotation.y = sin(_t * 3.1) * 0.12
