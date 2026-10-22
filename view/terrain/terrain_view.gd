class_name TerrainView
extends Node3D
## Terrain v1 (M1.2, Zero Hour-style look): smooth-shaded chunk meshes with raised rocky
## outcrops/cliffs (only on impassable cliff tiles, so pathing is unchanged), a lowered
## riverbed with an animated water surface, CC0 ground textures blended by splat maps
## built from the map's biome layer, lane markings, concrete bridges and MultiMesh props
## (palms, scrub, rocks, power poles, wrecks, shacks, gas station) from the decor layer.

const CHUNK := 32
const COLORS := {
	SimMap.T.GRASS: Color("#a39a66"), SimMap.T.ROAD: Color("#5d5a57"), SimMap.T.ROUGH: Color("#9c8358"),
	SimMap.T.WATER: Color("#3f6e74"), SimMap.T.FORD: Color("#6a8c86"), SimMap.T.BRIDGE: Color("#8f8b84"),
	SimMap.T.CLIFF: Color("#7d6f5f"), SimMap.T.FOREST: Color("#6d7a42"),
}
const BIOME_A := {"s": Color(1, 0, 0, 0), "d": Color(0, 1, 0, 0), "g": Color(0, 0, 1, 0), "G": Color(0, 0, 0, 1)}
const BIOME_B := {"a": Color(1, 0, 0, 0), "r": Color(0, 1, 0, 0), "w": Color(0, 0, 1, 0), "c": Color(0, 0, 0, 1)}
const TEX := "res://assets/textures/"

var fog_image: Image
var fog_texture: ImageTexture
var material: ShaderMaterial
var water_material: ShaderMaterial
var prop_material: ShaderMaterial
var prop_sway_material: ShaderMaterial
var prop_detail_material: ShaderMaterial
var m: SimMap
var biome: PackedStringArray = PackedStringArray()
var heights: PackedFloat32Array
var ground_decal_count := 0

func build(map: SimMap, tiles_path: String = "") -> void:
	m = map
	fog_image = Image.create_empty(m.w, m.h, false, Image.FORMAT_L8)
	fog_image.fill(Color(0, 0, 0))
	fog_texture = ImageTexture.create_from_image(fog_image)
	_load_biome(tiles_path)
	material = ShaderMaterial.new()
	material.shader = load("res://view/terrain/terrain.gdshader")
	material.set_shader_parameter("fog_tex", fog_texture)
	material.set_shader_parameter("map_size", Vector2(m.w, m.h))
	material.set_shader_parameter("t_albedo", load(TEX + "terrain/terrain_albedo.png"))
	material.set_shader_parameter("t_nrao", load(TEX + "terrain/terrain_nrao.png"))
	material.set_shader_parameter("t_detail", load(TEX + "terrain/terrain_detail.png"))
	material.set_shader_parameter("t_macro", load(TEX + "terrain/terrain_macro.png"))
	_build_splats()
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://view/terrain/water.gdshader")
	water_material.set_shader_parameter("fog_tex", fog_texture)
	water_material.set_shader_parameter("map_size", Vector2(m.w, m.h))
	prop_material = _prop_mat(0.0, 0.0, null)
	prop_sway_material = _prop_mat(1.0, 0.0, null)
	prop_detail_material = _prop_mat(0.0, 0.55, load(TEX + "materials/concrete.png"))
	heights = _corner_heights()
	for cy in range(0, m.h, CHUNK):
		for cx in range(0, m.w, CHUNK):
			_build_chunk(cx, cy)
	_build_water()
	_build_bridges()
	_build_lane_markings()
	_build_ground_decals()
	_build_props(tiles_path)
	var skirt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(m.w + 120, m.h + 120)
	skirt.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.03, 0.03, 0.035)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skirt.material_override = sm
	skirt.position = Vector3(m.w * 0.5, -0.9, m.h * 0.5)
	add_child(skirt)

func _prop_mat(sway: float, detail_amount: float, tex: Texture2D) -> ShaderMaterial:
	var pm := ShaderMaterial.new()
	pm.shader = load("res://view/terrain/prop.gdshader")
	pm.set_shader_parameter("fog_tex", fog_texture)
	pm.set_shader_parameter("map_size", Vector2(m.w, m.h))
	pm.set_shader_parameter("sway", sway)
	pm.set_shader_parameter("detail_amount", detail_amount)
	if tex != null:
		pm.set_shader_parameter("detail", tex)
	return pm

func _load_biome(tiles_path: String) -> void:
	biome = PackedStringArray()
	var bp := tiles_path.replace(".txt", ".biome.txt")
	if tiles_path != "" and FileAccess.file_exists(bp):
		var f := FileAccess.open(bp, FileAccess.READ)
		while not f.eof_reached():
			var line := f.get_line()
			if line.length() >= m.w:
				biome.append(line)
	if biome.size() < m.h:   # fallback: derive from sim tiles
		biome.clear()
		for y in m.h:
			var row := ""
			for x in m.w:
				match m.ttype(Vector2i(x, y)):
					SimMap.T.ROAD: row += "a"
					SimMap.T.ROUGH: row += "d"
					SimMap.T.WATER, SimMap.T.FORD, SimMap.T.BRIDGE: row += "w"
					SimMap.T.CLIFF: row += "r"
					_: row += "g"
			biome.append(row)

func biome_at(x: int, y: int) -> String:
	if y < 0 or y >= biome.size() or x < 0 or x >= m.w:
		return "g"
	return biome[y][x]

func _build_splats() -> void:
	var ia := Image.create_empty(m.w, m.h, false, Image.FORMAT_RGBA8)
	var ib := Image.create_empty(m.w, m.h, false, Image.FORMAT_RGBA8)
	for y in m.h:
		for x in m.w:
			var b := biome_at(x, y)
			ia.set_pixel(x, y, BIOME_A.get(b, Color(0, 0, 0, 0)))
			ib.set_pixel(x, y, BIOME_B.get(b, Color(0, 0, 0, 0)))
	# soften natural-ground transitions (asphalt stays crisp)
	var sa := ia.duplicate() as Image
	var soft := ia.duplicate() as Image   # wide, organic falloff (≈3 tiles)
	soft.resize(maxi(4, m.w / 4), maxi(4, m.h / 4), Image.INTERPOLATE_BILINEAR)
	soft.resize(m.w, m.h, Image.INTERPOLATE_CUBIC)
	for y in m.h:
		for x in m.w:
			var acc := Color(0, 0, 0, 0)
			var n := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := clampi(x + dx, 0, m.w - 1)
					var yy := clampi(y + dy, 0, m.h - 1)
					var wgt := 2.0 if dx == 0 and dy == 0 else 1.0
					acc += ia.get_pixel(xx, yy) * wgt
					n += wgt
			sa.set_pixel(x, y, (acc / n).lerp(soft.get_pixel(x, y), 0.45))
	material.set_shader_parameter("splat_a", ImageTexture.create_from_image(sa))
	material.set_shader_parameter("splat_b", ImageTexture.create_from_image(ib))

func _h(x: int, y: int) -> float:
	var v := ((x * 73856093) ^ (y * 19349663) ^ 0x2545F491) & 0xffff
	return float(v) / 65535.0

func height_at_tile(t: Vector2i) -> float:
	match m.ttype(t):
		SimMap.T.WATER, SimMap.T.BRIDGE:
			return -0.55
		SimMap.T.FORD:
			return -0.22
		SimMap.T.CLIFF:
			return 1.0
	return 0.0

func _corner_heights() -> PackedFloat32Array:
	var hts := PackedFloat32Array()
	hts.resize((m.w + 1) * (m.h + 1))
	for y in m.h + 1:
		for x in m.w + 1:
			var n_cliff := 0
			var n_wet := 0
			var lo := 0.0
			var cnt := 0
			for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var t := Vector2i(x, y) + d
				if not m.in_bounds(t):
					n_cliff += 1
					cnt += 1
					continue
				cnt += 1
				var tt := m.ttype(t)
				if tt == SimMap.T.CLIFF:
					n_cliff += 1
				elif tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE or tt == SimMap.T.FORD:
					n_wet += 1
					lo = minf(lo, height_at_tile(t))
			var v := 0.0
			if n_cliff == cnt:
				v = 0.9 + _h(x, y) * 0.9 + _h(x / 3, y / 3) * 0.6     # rocky outcrop top
			elif n_wet == cnt:
				v = lo
			elif n_wet > 0:
				v = lo * 0.35                                          # sloping bank
			hts[y * (m.w + 1) + x] = v
	return hts

func _build_chunk(cx: int, cy: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x1 := mini(cx + CHUNK, m.w)
	var y1 := mini(cy + CHUNK, m.h)
	var vw := x1 - cx + 1
	for y in range(cy, y1 + 1):
		for x in range(cx, x1 + 1):
			var hv := heights[y * (m.w + 1) + x]
			st.set_uv(Vector2(x, y))
			st.add_vertex(Vector3(x, hv, y))
	for y in range(0, y1 - cy):
		for x in range(0, x1 - cx):
			var i0 := y * vw + x
			var i1 := i0 + 1
			var i2 := i0 + vw
			var i3 := i2 + 1
			for i in [i0, i1, i2, i1, i3, i2]:
				st.add_index(i)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # outcrops shade the ground
	add_child(mi)

func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for y in m.h:
		for x in m.w:
			var tt := m.ttype(Vector2i(x, y))
			if tt != SimMap.T.WATER and tt != SimMap.T.BRIDGE and tt != SimMap.T.FORD:
				continue
			any = true
			var corners := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var edge := []
			for c: Vector2 in corners:
				var dry := 0
				for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
					var t := Vector2i(int(c.x), int(c.y)) + d
					var t2 := m.ttype(t)
					if t2 != SimMap.T.WATER and t2 != SimMap.T.BRIDGE and t2 != SimMap.T.FORD:
						dry += 1
				edge.append(1.0 if dry > 0 else (0.45 if tt == SimMap.T.FORD else 0.0))
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(edge[i], 0, 0))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(corners[i].x, -0.14, corners[i].y))
	if not any:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = water_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_bridges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := Color("#9a958c")
	var rail := Color("#6c6a66")
	var pillar := Color("#837e75")
	for y in m.h:
		for x in m.w:
			if m.ttype(Vector2i(x, y)) != SimMap.T.BRIDGE:
				continue
			_box(st, Vector3(x + 0.5, 0.0, y + 0.5), Vector3(1.0, 0.16, 1.0), deck.darkened(0.04 * (x % 2)))
			if m.ttype(Vector2i(x, y - 1)) != SimMap.T.BRIDGE:
				_box(st, Vector3(x + 0.5, 0.2, y + 0.06), Vector3(1.0, 0.26, 0.12), rail)
				if x % 2 == 0:
					_box(st, Vector3(x + 0.5, -0.4, y + 0.3), Vector3(0.35, 0.7, 0.35), pillar)
			if m.ttype(Vector2i(x, y + 1)) != SimMap.T.BRIDGE:
				_box(st, Vector3(x + 0.5, 0.2, y + 0.94), Vector3(1.0, 0.26, 0.12), rail)
				if x % 2 == 0:
					_box(st, Vector3(x + 0.5, -0.4, y + 0.7), Vector3(0.35, 0.7, 0.35), pillar)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = prop_detail_material
	add_child(mi)

## Dashed centre lines on two-lane roads (between two road rows / columns).
func _build_lane_markings() -> void:
	var pts: Array = []
	var road := func(x: int, y: int) -> bool: return m.in_bounds(Vector2i(x, y)) and m.ttype(Vector2i(x, y)) == SimMap.T.ROAD
	for y in m.h:
		for x in m.w:
			if x % 2 == 0 and road.call(x, y) and road.call(x, y - 1) and not road.call(x, y + 1) and not road.call(x, y - 2) and road.call(x - 1, y) and road.call(x + 1, y):
				pts.append(Transform3D(Basis(), Vector3(x + 0.5, 0.025, y)))
			if y % 2 == 0 and road.call(x, y) and road.call(x - 1, y) and not road.call(x + 1, y) and not road.call(x - 2, y) and road.call(x, y - 1) and road.call(x, y + 1):
				pts.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.025, y + 0.5)))
	if pts.is_empty():
		return
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.09)
	q.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e9d9a2")
	mat.roughness = 0.8
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	PropMeshes.box(st, c, s, col)

# ---------------------------------------------------------------- props
func _build_props(tiles_path: String) -> void:
	var by_kind := {}
	var dp := tiles_path.replace(".txt", ".decor.txt")
	if tiles_path != "" and FileAccess.file_exists(dp):
		var f := FileAccess.open(dp, FileAccess.READ)
		while not f.eof_reached():
			var parts := f.get_line().split(" ", false)
			if parts.size() < 4:
				continue
			if not by_kind.has(parts[0]):
				by_kind[parts[0]] = []
			by_kind[parts[0]].append([float(parts[1]), float(parts[2]), int(parts[3])])
	else:
		# fallback: trees on forest tiles, rocks on cliffs
		by_kind = {"scrub_tree": [], "rock": []}
		for y in m.h:
			for x in m.w:
				var tt := m.ttype(Vector2i(x, y))
				if tt == SimMap.T.FOREST and _h(x, y) < 0.6:
					by_kind["scrub_tree"].append([x + 0.5, y + 0.5, 0])
				elif tt == SimMap.T.CLIFF and _h(x, y) < 0.2:
					by_kind["rock"].append([x + 0.5, y + 0.5, 0])
	for kind in by_kind:
		var mesh: Mesh = PropMeshes.make(kind)
		if mesh == null:
			continue
		var mat := prop_material
		if kind == "palm" or kind == "scrub_tree":
			mat = prop_sway_material
		elif kind in ["gas_station", "shack", "power_pole"]:
			mat = prop_detail_material
		_multimesh(by_kind[kind], mesh, mat, kind)

func _multimesh(items: Array, mesh: Mesh, mat: Material, kind: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	var jitter := kind in ["palm", "scrub_tree", "rock", "rock_small"]
	for i in items.size():
		var it: Array = items[i]
		var x: float = it[0]
		var z: float = it[1]
		var n := _h(int(x * 13.0), int(z * 7.0))
		var s := lerpf(0.8, 1.25, n) if jitter else 1.0
		var yaw: float = n * TAU if jitter else float(it[2]) * PI * 0.5
		var y := heights[clampi(int(z), 0, m.h) * (m.w + 1) + clampi(int(x), 0, m.w)] if kind.begins_with("rock") else 0.0
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * lerpf(0.9, 1.15, _h(int(x), int(z))), s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, y, z)))
		mm.set_instance_color(i, Color(1, 1, 1).darkened(n * 0.15) if jitter else Color(1, 1, 1))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Props_" + kind
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	return c.lightened(0.05)

## M2: static ground decals scattered deterministically from the map: tire tracks along roads
## and around resource fields, cracks on asphalt / concrete, oil stains on roads and where
## harvesters work, sand drifting onto roads, rubble at cliff feet. Flat tiles only.
func _build_ground_decals() -> void:
	var xf: Array = []
	var cust: Array = []
	var flat := func(x: int, y: int) -> bool:
		for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if absf(heights[(y + d.y) * (m.w + 1) + x + d.x]) > 0.01:
				return false
		return true
	var tt := func(x: int, y: int) -> int: return m.ttype(Vector2i(x, y)) if m.in_bounds(Vector2i(x, y)) else SimMap.T.CLIFF
	var near := func(x: int, y: int, kind: int, r: int) -> bool:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if tt.call(x + dx, y + dy) == kind:
					return true
		return false
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			var t: int = tt.call(x, y)
			if t == SimMap.T.WATER or t == SimMap.T.FORD or t == SimMap.T.BRIDGE or t == SimMap.T.CLIFF or not flat.call(x, y):
				continue
			var r1 := _h(x * 3 + 11, y * 7 + 5)
			var r2 := _h(x * 5 + 2, y * 3 + 17)
			var bc := biome[y][x] if y < biome.size() and x < biome[y].length() else "s"
			var res_near := m.nobuild[y * m.w + x] == 1
			var kind := -1
			var size := 1.6
			var rot := r2 * TAU
			var stretch := 1.0
			if t == SimMap.T.ROAD:
				var horiz: bool = tt.call(x - 1, y) == SimMap.T.ROAD and tt.call(x + 1, y) == SimMap.T.ROAD
				if r1 < 0.14:
					kind = int(r2 * 4.0) % 4                       # tire tracks along the road
					rot = (PI * 0.5 if horiz else 0.0) + (r2 - 0.5) * 0.3
					size = 1.5; stretch = 1.6
				elif r1 < 0.24:
					kind = 4 + int(r2 * 4.0) % 4                   # cracks
				elif r1 < 0.28:
					kind = 8 + int(r2 * 3.0) % 3; size = 1.3        # oil
				elif r1 < 0.36 and (near.call(x, y, SimMap.T.GRASS, 1) or near.call(x, y, SimMap.T.ROUGH, 1)):
					kind = 11; size = 2.0                           # sand drifting onto asphalt
			elif bc == "c" and r1 < 0.2:
				kind = 4 + int(r2 * 4.0) % 4
			elif res_near and r1 < 0.12:
				kind = int(r2 * 4.0) % 4 if r1 < 0.08 else 8 + int(r2 * 3.0) % 3
				size = 1.8; stretch = 1.3 if kind < 4 else 1.0
			elif near.call(x, y, SimMap.T.CLIFF, 1) and r1 < 0.22:
				kind = 12 + int(r2 * 4.0) % 4; size = 1.2 + r2 * 0.6
			if kind < 0:
				continue
			var b := Basis(Vector3.UP, rot).scaled(Vector3(size, 1.0, size * stretch))
			var jx := (_h(x + 91, y) - 0.5) * 0.5
			var jy := (_h(x, y + 37) - 0.5) * 0.5
			xf.append(Transform3D(b, Vector3(x + 0.5 + jx, 0.012 + 0.001 * float(kind % 4), y + 0.5 + jy)))
			cust.append(Color(float(kind), 0.65 + 0.35 * r1, 0, 0))
	if xf.is_empty():
		return
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = pm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_custom_data(i, cust[i])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/terrain/ground_decal.gdshader")
	mat.set_shader_parameter("atlas", load(TEX + "decals/ground_decals.png"))
	mat.set_shader_parameter("fog_tex", fog_texture)
	mat.set_shader_parameter("map_size", Vector2(m.w, m.h))
	mat.render_priority = -2
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GroundDecals"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	ground_decal_count = xf.size()
