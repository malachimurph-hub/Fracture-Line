class_name TerrainView
extends Node3D
## Builds chunked terrain meshes (32x32 tiles) from the SimMap tile grid, bridge decks,
## and MultiMesh trees/rocks. All share the fog-of-war shader.

const CHUNK := 32
const COLORS := {
	SimMap.T.GRASS: Color("#7f8c58"), SimMap.T.ROAD: Color("#a39274"), SimMap.T.ROUGH: Color("#8f8361"),
	SimMap.T.WATER: Color("#3d6d8c"), SimMap.T.FORD: Color("#5b8b99"), SimMap.T.BRIDGE: Color("#3d6d8c"),
	SimMap.T.CLIFF: Color("#77716a"), SimMap.T.FOREST: Color("#5f7542"),
}
var fog_image: Image
var fog_texture: ImageTexture
var material: ShaderMaterial
var prop_material: ShaderMaterial
var m: SimMap

func build(map: SimMap) -> void:
	m = map
	fog_image = Image.create(m.w, m.h, false, Image.FORMAT_L8)
	fog_image.fill(Color(0, 0, 0))
	fog_texture = ImageTexture.create_from_image(fog_image)
	var sh: Shader = load("res://view/terrain/fog_world.gdshader")
	material = ShaderMaterial.new()
	material.shader = sh
	material.set_shader_parameter("fog_tex", fog_texture)
	material.set_shader_parameter("map_size", Vector2(m.w, m.h))
	prop_material = material
	var heights := _corner_heights()
	for cy in range(0, m.h, CHUNK):
		for cx in range(0, m.w, CHUNK):
			_build_chunk(cx, cy, heights)
	_build_bridges()
	_build_props()
	# dark skirt under the map so edges don't show the clear color
	var skirt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(m.w + 80, m.h + 80)
	skirt.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.02, 0.02, 0.025)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skirt.material_override = sm
	skirt.position = Vector3(m.w * 0.5, -0.6, m.h * 0.5)
	add_child(skirt)

func height_at_tile(t: Vector2i) -> float:
	var tt := m.ttype(t)
	if tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE:
		return -0.4
	if tt == SimMap.T.FORD:
		return -0.18
	if tt == SimMap.T.CLIFF:
		return 0.7
	return 0.0

func _corner_heights() -> PackedFloat32Array:
	var hts := PackedFloat32Array()
	hts.resize((m.w + 1) * (m.h + 1))
	for y in m.h + 1:
		for x in m.w + 1:
			var best := -10.0
			var all_cliff := true
			for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var t := Vector2i(x, y) + d
				if not m.in_bounds(t):
					continue
				if m.ttype(t) == SimMap.T.CLIFF:
					continue
				all_cliff = false
				best = maxf(best, height_at_tile(t))
			var v := 0.7 if all_cliff else best
			hts[y * (m.w + 1) + x] = v
	return hts

func _tile_color(t: Vector2i) -> Color:
	var c: Color = COLORS[m.ttype(t)]
	var n := float(((t.x * 73856093) ^ (t.y * 19349663)) & 255) / 255.0
	return c.lightened(n * 0.06) if n > 0.5 else c.darkened((0.5 - n) * 0.08)

func _build_chunk(cx: int, cy: int, hts: PackedFloat32Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(cy, mini(cy + CHUNK, m.h)):
		for x in range(cx, mini(cx + CHUNK, m.w)):
			var t := Vector2i(x, y)
			var c := _tile_color(t)
			var h00 := hts[y * (m.w + 1) + x]
			var h10 := hts[y * (m.w + 1) + x + 1]
			var h01 := hts[(y + 1) * (m.w + 1) + x]
			var h11 := hts[(y + 1) * (m.w + 1) + x + 1]
			var p00 := Vector3(x, h00, y)
			var p10 := Vector3(x + 1, h10, y)
			var p01 := Vector3(x, h01, y + 1)
			var p11 := Vector3(x + 1, h11, y + 1)
			var n1 := (p01 - p00).cross(p10 - p00).normalized()
			var n2 := (p01 - p10).cross(p11 - p10).normalized()
			# faceted (flat) shading per triangle
			for v in [[p00, n1], [p10, n1], [p01, n1], [p10, n2], [p11, n2], [p01, n2]]:
				st.set_color(c)
				st.set_normal(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_bridges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := Color("#8b6f4e")
	var rail := Color("#5a616b")
	for y in m.h:
		for x in m.w:
			if m.ttype(Vector2i(x, y)) != SimMap.T.BRIDGE:
				continue
			_box(st, Vector3(x + 0.5, 0.02, y + 0.5), Vector3(1.0, 0.12, 1.0), deck.lightened(0.05 * (x % 2)))
			if m.ttype(Vector2i(x, y - 1)) != SimMap.T.BRIDGE:
				_box(st, Vector3(x + 0.5, 0.2, y + 0.08), Vector3(1.0, 0.22, 0.1), rail)
			if m.ttype(Vector2i(x, y + 1)) != SimMap.T.BRIDGE:
				_box(st, Vector3(x + 0.5, 0.2, y + 0.92), Vector3(1.0, 0.22, 0.1), rail)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	add_child(mi)

func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
	]
	for f in faces:
		var q: Array = f[1]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(f[0])
			st.add_vertex(c + q[i])

func _build_props() -> void:
	var trees: Array = []
	var rocks: Array = []
	for y in m.h:
		for x in m.w:
			var tt := m.ttype(Vector2i(x, y))
			var n := ((x * 73856093) ^ (y * 19349663)) & 1023
			if tt == SimMap.T.FOREST and n % 3 != 0:
				trees.append(Vector3(x + 0.3 + (n % 7) * 0.06, 0, y + 0.3 + (n % 5) * 0.08))
			elif tt == SimMap.T.CLIFF and n % 2 == 0 and x > 0 and y > 0 and x < m.w - 1 and y < m.h - 1:
				rocks.append(Vector3(x + 0.5, 0.6, y + 0.5))
	_multimesh(trees, _tree_mesh(), Color("#3f6b35"), 0.9, 1.35)
	_multimesh(rocks, _rock_mesh(), Color("#8a847a"), 0.8, 1.3)

func _tree_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.06; trunk.bottom_radius = 0.08; trunk.height = 0.5; trunk.radial_segments = 5
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.bottom_radius = 0.42; cone.height = 1.2; cone.radial_segments = 7
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 0.25, 0)))
	st.append_from(cone, 0, Transform3D(Basis(), Vector3(0, 1.0, 0)))
	var mesh := st.commit()
	return mesh

func _rock_mesh() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(0.9, 0.6, 0.8)
	return b

func _multimesh(points: Array, mesh: Mesh, col: Color, smin: float, smax: float) -> void:
	if points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var p: Vector3 = points[i]
		var n := float((int(p.x * 13) * 31 + int(p.z * 7)) % 100) / 100.0
		var s := lerpf(smin, smax, n)
		var b := Basis(Vector3.UP, n * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, col.lightened(n * 0.15))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = material.shader
	mat.set_shader_parameter("fog_tex", fog_texture)
	mat.set_shader_parameter("map_size", Vector2(m.w, m.h))
	mmi.material_override = mat
	add_child(mmi)

## Rebuild the fog texture for the local team (called at 5 Hz when fog changes).
func update_fog(fog: SimFog, team: int) -> void:
	var data := PackedByteArray()
	data.resize(m.w * m.h)
	if fog.disabled:
		data.fill(255)
	else:
		var c: PackedInt32Array = fog.count.get(team, PackedInt32Array())
		var ex: PackedByteArray = fog.explored.get(team, PackedByteArray())
		if team < 0 or c.is_empty():
			data.fill(255)
		else:
			for i in data.size():
				data[i] = 255 if c[i] > 0 else (120 if ex[i] != 0 else 0)
	fog_image.set_data(m.w, m.h, false, Image.FORMAT_L8, data)
	fog_texture.update(fog_image)

static func minimap_color(tt: int) -> Color:
	var c: Color = COLORS[tt]
	return c.lightened(0.08)
