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
var prop_tower_material: ShaderMaterial   ## M2.9 tall buildings: see-through where they hide units
var has_towers := false
var m: SimMap
var biome: PackedStringArray = PackedStringArray()
var prop_tint := Color(1, 1, 1)
var heights: PackedFloat32Array
var ground_decal_count := 0

var decor_override: Array = []   ## M2.9: props placed in the map builder (MapDef.decor)
var _tree_kind := "scrub_tree"   ## M2.8: forest prop for maps without a decor layer (map builder)

func build(map: SimMap, tiles_path: String = "", env: Dictionary = {}) -> void:
	m = map
	if env.is_empty():
		env = MapEnv.of(&"desert")
	fog_image = Image.create_empty(m.w, m.h, false, Image.FORMAT_L8)
	fog_image.fill(Color(0, 0, 0))
	fog_texture = ImageTexture.create_from_image(fog_image)
	_tree_kind = "pine_snow" if String(env.get("albedo", "")).contains("winter") else ("oak" if String(env.get("albedo", "")).contains("temperate") else "scrub_tree")
	_load_biome(tiles_path)
	material = ShaderMaterial.new()
	material.shader = load("res://view/terrain/terrain.gdshader")
	material.set_shader_parameter("fog_tex", fog_texture)
	material.set_shader_parameter("map_size", Vector2(m.w, m.h))
	material.set_shader_parameter("t_albedo", load(env["albedo"]))
	material.set_shader_parameter("t_nrao", load(env["nrao"]))
	material.set_shader_parameter("dry_scrub", env["dry"])
	material.set_shader_parameter("desert_tint", env["tint"])
	material.set_shader_parameter("worn_amt", env.get("worn", 0.7))
	material.set_shader_parameter("cloud_amt", env.get("clouds", 0.2))
	material.set_shader_parameter("t_detail", load(TEX + "terrain/terrain_detail.png"))
	material.set_shader_parameter("t_macro", load(TEX + "terrain/terrain_macro.png"))
	_build_splats()
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://view/terrain/water.gdshader")
	water_material.set_shader_parameter("fog_tex", fog_texture)
	water_material.set_shader_parameter("map_size", Vector2(m.w, m.h))
	water_material.set_shader_parameter("deep_col", env["water_deep"])
	water_material.set_shader_parameter("shallow_col", env["water_shallow"])
	water_material.set_shader_parameter("sky_col", (env["fog_col"] as Color).lerp(env["ambient"], 0.5))
	prop_tint = env["prop_tint"]
	prop_material = _prop_mat(0.0, 0.0, null)
	prop_sway_material = _prop_mat(1.0, 0.0, null)
	prop_sway_material.set_shader_parameter("leaf_tex", load(TEX + "props/leaf_atlas.png"))
	prop_material.set_shader_parameter("leaf_tex", load(TEX + "props/leaf_atlas.png"))
	prop_detail_material = _prop_mat(0.0, 0.55, load(TEX + "materials/concrete.png"))
	prop_tower_material = _prop_mat(0.0, 0.55, load(TEX + "materials/concrete.png"))
	_house_cover(tiles_path)
	heights = _corner_heights()
	for cy in range(0, m.h, CHUNK):
		for cx in range(0, m.w, CHUNK):
			_build_chunk(cx, cy)
	_build_water()
	_build_bridges()
	_build_lane_markings()
	_build_ground_decals()
	_build_scatter(float(env.get("dry", 0.0)) > 0.5)
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
	# M2.9: two 3x3 passes (smoother blends between ground types, no blocky tile edges)
	var src := ia
	for pass_i in 2:
		var dst := src.duplicate() as Image
		for y in m.h:
			for x in m.w:
				var acc := Color(0, 0, 0, 0)
				var n := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var xx := clampi(x + dx, 0, m.w - 1)
						var yy := clampi(y + dy, 0, m.h - 1)
						var wgt := 2.0 if dx == 0 and dy == 0 else 1.0
						acc += src.get_pixel(xx, yy) * wgt
						n += wgt
				dst.set_pixel(x, y, acc / n)
		src = dst
	for y in m.h:
		for x in m.w:
			sa.set_pixel(x, y, src.get_pixel(x, y).lerp(soft.get_pixel(x, y), 0.35))
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

## Smooth value noise over tile space (bilinear over the per-tile hash), 0..1.
func _vn(fx: float, fy: float) -> float:
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	return lerpf(lerpf(_h(ix, iy), _h(ix + 1, iy), tx), lerpf(_h(ix, iy + 1), _h(ix + 1, iy + 1), tx), ty)

## Chebyshev distance (tiles) from each cliff tile to the nearest non-cliff tile; 0 off-cliff.
func _cliff_distance() -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(m.w * m.h)
	var q: Array[Vector2i] = []
	for y in m.h:
		for x in m.w:
			if m.ttype(Vector2i(x, y)) == SimMap.T.CLIFF:
				dist[y * m.w + x] = 1 << 20
			else:
				dist[y * m.w + x] = 0
				q.append(Vector2i(x, y))
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var dc := dist[c.y * m.w + c.x]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if m.in_bounds(n) and dist[n.y * m.w + n.x] > dc + 1:
					dist[n.y * m.w + n.x] = dc + 1
					q.append(n)
	return dist

## M3.2 item 14: tiles under village houses / container stacks are Cliff in the map (they block
## like the towers) but the ground stays flat there instead of rising into a massif.
var house_tiles := {}
func _house_cover(tiles_path: String) -> void:
	house_tiles.clear()
	var items: Array = []
	if not decor_override.is_empty():
		items = decor_override
	else:
		var dp := tiles_path.replace(".txt", ".decor.txt")
		if tiles_path == "" or not FileAccess.file_exists(dp):
			return
		for line in FileAccess.get_file_as_string(dp).split("\n", false):
			var parts := line.split(" ", false)
			if parts.size() >= 4 and String(parts[0]) in PropMeshes.HOUSES:
				items.append([parts[0], float(parts[1]), float(parts[2]), int(parts[3])])
	for d in items:
		if not String(d[0]) in PropMeshes.HOUSES:
			continue
		var fp: Vector2i = PropMeshes.FOOTPRINT[String(d[0])]
		if int(d[3]) % 2 == 1:
			fp = Vector2i(fp.y, fp.x)
		var o := Vector2i(roundi(float(d[1]) - fp.x * 0.5), roundi(float(d[2]) - fp.y * 0.5))
		for yy in fp.y:
			for xx in fp.x:
				house_tiles[o + Vector2i(xx, yy)] = true

func _corner_heights() -> PackedFloat32Array:
	var cdist := _cliff_distance()
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
				if tt == SimMap.T.CLIFF and not house_tiles.has(t):
					n_cliff += 1
				elif tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE or tt == SimMap.T.FORD:
					n_wet += 1
					lo = minf(lo, height_at_tile(t))
			var v := 0.0
			if n_cliff == cnt:
				# M3.0 mountains: rise with distance into the massif + smooth multi-octave relief
				# (value noise, not per-corner hash spikes), small crags on top
				var dd := 99
				for d2: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
					var t2 := Vector2i(x, y) + d2
					dd = mini(dd, cdist[t2.y * m.w + t2.x] if m.in_bounds(t2) else 99)
				var rise := minf(float(dd), 4.0)
				v = 0.85 + rise * 0.4 * (0.75 + _vn(x * 0.21, y * 0.21) * 0.5) + _vn(x * 0.37 + 11.0, y * 0.37) * 0.55 + _h(x, y) * 0.18
			elif n_cliff == cnt - 1 and n_wet == 0:
				v = 0.4 + _vn(x * 0.37, y * 0.37) * 0.25                 # M3.0: chamfer the inside corners of massifs (no stair steps)
			elif n_wet == cnt:
				v = lo
			elif n_wet > 0:
				v = lo * 0.35                                          # sloping bank
			hts[y * (m.w + 1) + x] = v
	# M2.8: relax bank corners (wet/dry mix) toward their neighbours so shores slope instead of stepping
	var sm := hts.duplicate()
	for y in range(1, m.h):
		for x in range(1, m.w):
			var k := y * (m.w + 1) + x
			var v0 := hts[k]
			if v0 >= 0.0 or v0 <= -0.5:
				continue
			var acc := 0.0
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var hv := hts[k + dy * (m.w + 1) + dx]
					if hv < 0.85:
						acc += hv
						n += 1
			sm[k] = acc / maxf(1.0, n)
	return sm

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

## M2.8 water: one flat surface per 32-tile chunk that has water, shaped by a smooth shoreline
## field (wet mask at 4 px per tile, blurred) instead of per-tile quads, so banks curve instead of
## stepping. R = wet (water / ford / bridge), G = deep water; the shader cuts the surface at the
## R = 0.5 contour and uses the field for depth colour and shore foam.
const SHORE_PX := 4
var shore_texture: ImageTexture

## M3.0.1: the field is the same as before, but (1) only the box around the water (plus a margin
## wider than the blur reach) is blurred - everything outside stays 0 - and (2) the result is
## cached per map layout in memory and on disk (user://cache/shore_<hash>.png), so the menu
## battle and the match on the same map do not rebuild it. It was ~1.6 s of the map load.
static var _shore_mem := {}

func _build_shore_field() -> void:
	var W := m.w * SHORE_PX
	var H := m.h * SHORE_PX
	var key := _shore_key()
	if _shore_mem.has(key):
		shore_texture = _shore_mem[key]
		return
	var cache_path := "user://cache/shore_%s.png" % key
	if FileAccess.file_exists(cache_path):
		var cimg := Image.load_from_file(cache_path)
		if cimg != null and cimg.get_width() == W and cimg.get_height() == H:
			if cimg.get_format() != Image.FORMAT_RG8:
				cimg.convert(Image.FORMAT_RG8)
			shore_texture = ImageTexture.create_from_image(cimg)
			_shore_mem[key] = shore_texture
			return
	# wet-tile box, grown by a margin past the blur reach (3 passes x 3 px)
	var tx0 := m.w
	var ty0 := m.h
	var tx1 := -1
	var ty1 := -1
	for y in m.h:
		for x in m.w:
			var tt := m.ttype(Vector2i(x, y))
			if tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE or tt == SimMap.T.FORD:
				tx0 = mini(tx0, x); ty0 = mini(ty0, y); tx1 = maxi(tx1, x); ty1 = maxi(ty1, y)
	var data := PackedByteArray()
	data.resize(W * H * 2)
	if tx1 >= 0:
		const MARGIN := 4   # tiles (16 px > 9 px blur reach)
		tx0 = maxi(0, tx0 - MARGIN); ty0 = maxi(0, ty0 - MARGIN)
		tx1 = mini(m.w - 1, tx1 + MARGIN); ty1 = mini(m.h - 1, ty1 + MARGIN)
		var ox := tx0 * SHORE_PX
		var oy := ty0 * SHORE_PX
		var sw := (tx1 - tx0 + 1) * SHORE_PX
		var sh := (ty1 - ty0 + 1) * SHORE_PX
		var a := PackedFloat32Array()
		var b := PackedFloat32Array()
		a.resize(sw * sh)
		b.resize(sw * sh)
		for y in range(ty0, ty1 + 1):
			for x in range(tx0, tx1 + 1):
				var tt := m.ttype(Vector2i(x, y))
				var wet := 1.0 if (tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE or tt == SimMap.T.FORD) else 0.0
				var deep := 1.0 if (tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE) else 0.0
				if wet == 0.0:
					continue
				for py in SHORE_PX:
					var k0 := ((y - ty0) * SHORE_PX + py) * sw + (x - tx0) * SHORE_PX
					for px in SHORE_PX:
						a[k0 + px] = wet
						b[k0 + px] = deep
		# separable box blur, 3 passes of radius 3 px (~ a gaussian ~1.3 tiles wide)
		for pass_i in 3:
			a = _blur(a, sw, sh, 3)
			b = _blur(b, sw, sh, 3)
		for y in sh:
			var row := ((oy + y) * W + ox) * 2
			var srow := y * sw
			for x in sw:
				data[row + x * 2] = int(clampf(a[srow + x] * 255.0, 0.0, 255.0))
				data[row + x * 2 + 1] = int(clampf(b[srow + x] * 255.0, 0.0, 255.0))
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RG8, data)
	shore_texture = ImageTexture.create_from_image(img)
	_shore_mem[key] = shore_texture
	DirAccess.make_dir_recursive_absolute("user://cache")
	img.save_png(cache_path)

## Hash of the water layout (wet / deep per tile) and size; any map edit gives a new key.
func _shore_key() -> String:
	var bytes := PackedByteArray()
	bytes.resize(m.w * m.h)
	for y in m.h:
		for x in m.w:
			var tt := m.ttype(Vector2i(x, y))
			bytes[y * m.w + x] = 2 if (tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE) else (1 if tt == SimMap.T.FORD else 0)
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_MD5)
	hc.update(bytes)
	return "%dx%d_%d_%s" % [m.w, m.h, SHORE_PX, hc.finish().hex_encode().substr(0, 16)]

static func _blur(src: PackedFloat32Array, W: int, H: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(W * H)
	var inv := 1.0 / float(2 * r + 1)
	for y in H:
		var acc := 0.0
		var row := y * W
		for x in range(-r, r + 1):
			acc += src[row + clampi(x, 0, W - 1)]
		for x in W:
			tmp[row + x] = acc * inv
			acc += src[row + mini(x + r + 1, W - 1)] - src[row + maxi(x - r, 0)]
	var out := PackedFloat32Array()
	out.resize(W * H)
	for x in W:
		var acc2 := 0.0
		for y in range(-r, r + 1):
			acc2 += tmp[clampi(y, 0, H - 1) * W + x]
		for y in H:
			out[y * W + x] = acc2 * inv
			acc2 += tmp[mini(y + r + 1, H - 1) * W + x] - tmp[maxi(y - r, 0) * W + x]
	return out

func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for cy in range(0, m.h, CHUNK):
		for cx in range(0, m.w, CHUNK):
			var x0 := m.w
			var y0 := m.h
			var x1 := -1
			var y1 := -1
			for y in range(cy, mini(cy + CHUNK, m.h)):
				for x in range(cx, mini(cx + CHUNK, m.w)):
					var tt := m.ttype(Vector2i(x, y))
					if tt == SimMap.T.WATER or tt == SimMap.T.BRIDGE or tt == SimMap.T.FORD:
						x0 = mini(x0, x); y0 = mini(y0, y); x1 = maxi(x1, x); y1 = maxi(y1, y)
			if x1 < 0:
				continue
			any = true
			var r := Rect2(x0 - 2, y0 - 2, x1 - x0 + 5, y1 - y0 + 5)
			var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(cs[k].x, -0.14, cs[k].y))
	if not any:
		return
	_build_shore_field()
	water_material.set_shader_parameter("shore_tex", shore_texture)
	material.set_shader_parameter("shore_tex", shore_texture)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = water_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## M3.2 real bridge design (Malachi: "they look like nothing"): per bridge tile, in a span
## frame (u along the crossing, v across): asphalt deck on a concrete slab with lane lines,
## raised curbs + steel railings on the water sides, a riveted steel through-truss (top chord,
## verticals, X diagonals) along both outer edges, three steel girders under the deck, concrete
## piers with caps and cut-waters every 3 tiles, abutments + wing walls + approach ramps where the
## span meets land, and lamp posts. One static mesh (no per-frame cost).
func _build_bridges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var asphalt := Color("#4a4b4d")
	var slab := Color("#9a958c")
	var curb := Color("#b9b4a8")
	var steel := Color("#5c6b64")
	var steel_d := Color("#46524c")
	var rust := Color("#7a5a40")
	var conc := Color("#8f8a80")
	var conc_d := Color("#6f6b63")
	var line := Color("#e9d9a2")
	var is_b := func(t: Vector2i) -> bool: return m.in_bounds(t) and m.ttype(t) == SimMap.T.BRIDGE
	var is_w := func(t: Vector2i) -> bool: return not m.in_bounds(t) or m.ttype(t) == SimMap.T.WATER
	for y in m.h:
		for x in m.w:
			var t := Vector2i(x, y)
			if not is_b.call(t):
				continue
			# span axis: water on the north / south sides -> the bridge runs along x
			var along_x: bool = is_w.call(t + Vector2i(0, -1)) or is_w.call(t + Vector2i(0, 1)) or not (is_w.call(t + Vector2i(-1, 0)) or is_w.call(t + Vector2i(1, 0)))
			var du := Vector2i(1, 0) if along_x else Vector2i(0, 1)
			var dv := Vector2i(0, 1) if along_x else Vector2i(1, 0)
			var k := x if along_x else y   # index along the span (piers / lamps rhythm)
			var cen := Vector3(x + 0.5, 0.0, y + 0.5)
			# local box: c = (u, y, v) offset, s = (su, sy, sv), tilt = rotation about the v axis
			var bx := func(c: Vector3, sz: Vector3, col: Color, tilt := 0.0) -> void:
				var wc := cen + (Vector3(c.x, c.y, c.z) if along_x else Vector3(c.z, c.y, c.x))
				var ws := sz if along_x else Vector3(sz.z, sz.y, sz.x)
				var rot := Vector3(0, 0, tilt) if along_x else Vector3(-tilt, 0, 0)
				PropMeshes.box(st, wc, ws, col, rot)
			# deck: slab + asphalt (top at y 0.08 where units drive)
			bx.call(Vector3(0, -0.02, 0), Vector3(1.0, 0.12, 1.0), slab)
			bx.call(Vector3(0, 0.06, 0), Vector3(1.0, 0.04, 1.0), asphalt.darkened(0.03 * (k % 2)))
			bx.call(Vector3(0, 0.081, 0), Vector3(1.0, 0.002, 0.02), asphalt.lightened(0.08))   # expansion joint
			# girders under the deck
			for gv in [-0.32, 0.0, 0.32]:
				bx.call(Vector3(0, -0.14, gv), Vector3(1.0, 0.12, 0.06), steel_d)
				bx.call(Vector3(0, -0.2, gv), Vector3(1.0, 0.02, 0.14), steel_d)
			# cross beam
			bx.call(Vector3(-0.45, -0.12, 0), Vector3(0.05, 0.08, 0.9), steel_d)
			for side in [-1, 1]:
				var nb: Vector2i = t + dv * side
				var vv: float = 0.5 * side
				if is_w.call(nb):
					# curb / footway, railing, through-truss
					bx.call(Vector3(0, 0.1, vv - side * 0.08), Vector3(1.0, 0.04, 0.16), curb)
					bx.call(Vector3(0, 0.087, vv - side * 0.17), Vector3(1.0, 0.004, 0.03), line.lightened(0.3))   # edge line
					for pi in 4:
						bx.call(Vector3(-0.375 + pi * 0.25, 0.19, vv - side * 0.02), Vector3(0.025, 0.16, 0.025), steel)
					bx.call(Vector3(0, 0.27, vv - side * 0.02), Vector3(1.0, 0.025, 0.035), steel)
					bx.call(Vector3(0, 0.19, vv - side * 0.02), Vector3(1.0, 0.015, 0.02), steel)
					var tv: float = vv + side * 0.02
					bx.call(Vector3(0, 0.66, tv), Vector3(1.0, 0.07, 0.07), steel)   # top chord
					bx.call(Vector3(0, 0.1, tv), Vector3(1.0, 0.08, 0.08), steel)    # bottom chord
					bx.call(Vector3(-0.5, 0.38, tv), Vector3(0.06, 0.6, 0.06), steel)  # vertical
					for dg in [-1.0, 1.0]:   # X diagonals
						bx.call(Vector3(0, 0.38, tv), Vector3(1.12, 0.045, 0.045), steel_d, dg * 29.0)
					bx.call(Vector3(0, 0.38, tv), Vector3(0.1, 0.1, 0.075), rust)   # gusset plate
					bx.call(Vector3(0, 0.7, tv - side * 0.12), Vector3(0.05, 0.04, 0.24), steel_d)   # top lateral strut
					if k % 3 == 1:
						bx.call(Vector3(0, 0.5, vv - side * 0.08), Vector3(0.03, 0.8, 0.03), steel_d)   # lamp post
						bx.call(Vector3(0, 0.9, vv - side * 0.16), Vector3(0.16, 0.03, 0.05), Color("#ffe9a8"))
			# piers every 3 tiles along the span
			if k % 3 == 0:
				bx.call(Vector3(0, -0.24, 0), Vector3(0.3, 0.06, 1.05), conc)   # pier cap
				for pv in [-0.3, 0.3]:
					bx.call(Vector3(0, -0.42, pv), Vector3(0.22, 0.34, 0.22), conc_d)
				bx.call(Vector3(0, -0.5, 0), Vector3(0.24, 0.14, 0.9), conc_d)   # web wall at the waterline
				for cw in [-1.0, 1.0]:   # cut-waters
					bx.call(Vector3(0, -0.47, cw * 0.48), Vector3(0.17, 0.2, 0.17), conc, 0.0)
			# span ends meeting land: abutment, wing walls, approach ramp
			for end in [-1, 1]:
				var nl: Vector2i = t + du * end
				if not is_b.call(nl) and not is_w.call(nl):
					var ue: float = 0.5 * end
					bx.call(Vector3(ue - end * 0.06, -0.25, 0), Vector3(0.14, 0.62, 1.0), conc)   # abutment wall
					bx.call(Vector3(ue + end * 0.25, 0.035, 0), Vector3(0.5, 0.05, 1.0), asphalt, -end * 8.0)   # ramp onto the road
					bx.call(Vector3(ue, 0.13, 0), Vector3(0.06, 0.06, 1.0), curb)   # end curb (expansion)
					for side2 in [-1, 1]:
						if is_w.call(t + dv * side2):
							bx.call(Vector3(ue + end * 0.2, 0.0, 0.52 * side2), Vector3(0.5, 0.3, 0.08), conc_d)   # wing wall
							bx.call(Vector3(ue - end * 0.05, 0.38, 0.52 * side2), Vector3(0.12, 0.62, 0.12), conc)   # portal pylon
			# centre line (dashed)
			if k % 2 == 0:
				var na := 0
				var nbn := 0
				while na < 8 and is_b.call(t - dv * (na + 1)):
					na += 1
				while nbn < 8 and is_b.call(t + dv * (nbn + 1)):
					nbn += 1
				if na == nbn:
					bx.call(Vector3(0, 0.083, 0), Vector3(0.45, 0.003, 0.05), line)
				elif na == nbn + 1:
					bx.call(Vector3(0, 0.083, -0.5), Vector3(0.45, 0.003, 0.05), line)
				elif na % 2 == 0 and na > 0 and nbn > 0:   # white lane dashes
					bx.call(Vector3(0, 0.083, -0.5), Vector3(0.4, 0.003, 0.04), Color("#d9d6cc"))
			if (k % 2 == 1) and is_b.call(t - dv) and is_b.call(t + dv):
				var na2 := 0
				var nb2 := 0
				while na2 < 8 and is_b.call(t - dv * (na2 + 1)):
					na2 += 1
				while nb2 < 8 and is_b.call(t + dv * (nb2 + 1)):
					nb2 += 1
				if na2 == nb2 + 1 or na2 == nb2:
					bx.call(Vector3(0, 0.083, -0.5 if na2 == nb2 + 1 else 0.0), Vector3(1.0, 0.003, 0.025), line.darkened(0.1))   # solid centre
			if k % 3 == 0:   # expansion joint (steel finger plate) across the deck
				bx.call(Vector3(-0.5, 0.082, 0), Vector3(0.05, 0.004, 1.0), Color("#3a3c3e"))
			var hsh := (x * 73856093) ^ (y * 19349663)
			if hsh % 7 == 0:   # asphalt patch / wear
				bx.call(Vector3(((hsh >> 3) % 50) / 100.0 - 0.25, 0.0815, ((hsh >> 9) % 50) / 100.0 - 0.25), Vector3(0.3, 0.002, 0.22), asphalt.lightened(0.07))
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

## M3.0 city detail: raised concrete sidewalks with kerbs along every road edge that meets a
## non-road tile, solid white edge lines just inside the kerb, and zebra crossings where a
## two-lane road meets a junction. One mesh per 32 x 32 chunk (frustum-culled), no shadows.
func _build_sidewalks() -> void:
	var road := func(x: int, y: int) -> bool: return m.in_bounds(Vector2i(x, y)) and (m.ttype(Vector2i(x, y)) == SimMap.T.ROAD or m.ttype(Vector2i(x, y)) == SimMap.T.BRIDGE)
	var walk := Color("#9d9a92")
	var kerb := Color("#c4c0b6")
	var line := Color("#e8e6dc")
	var sts := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in m.h:
		for x in m.w:
			if not road.call(x, y):
				continue
			for d: Vector2i in dirs:
				var nx := x + d.x
				var ny := y + d.y
				if not m.in_bounds(Vector2i(nx, ny)) or road.call(nx, ny):
					continue
				var nt := m.ttype(Vector2i(nx, ny))
				if nt == SimMap.T.WATER or nt == SimMap.T.FORD:
					continue
				var ck := Vector2i(x >> 5, y >> 5)
				if not sts.has(ck):
					var st0 := SurfaceTool.new()
					st0.begin(Mesh.PRIMITIVE_TRIANGLES)
					sts[ck] = st0
				var st: SurfaceTool = sts[ck]
				var c := Vector3(x + 0.5 + d.x * 0.5, 0.0, y + 0.5 + d.y * 0.5)
				var along := Vector3(1, 0, 0) if d.x == 0 else Vector3(0, 0, 1)
				var out := Vector3(d.x, 0, d.y)
				var sz := along * 1.0 + out.abs() * 0.34
				PropMeshes.box(st, c + out * 0.17 + Vector3(0, 0.03, 0), sz + Vector3(0, 0.06, 0), walk)   # pavement slab
				_flat(st, c + out * 0.02 + Vector3(0, 0.062, 0), along * 1.0 + out.abs() * 0.04, kerb)   # kerb stone
				_flat(st, c - out * 0.09 + Vector3(0, 0.012, 0), along * 0.98 + out.abs() * 0.035, line)   # edge line
				if (x + y) % 3 == 0:   # pavement joints
					_flat(st, c + out * 0.19 + Vector3(0, 0.062, 0), out.abs() * 0.3 + along * 0.015, walk.darkened(0.15))
	# zebra crossings: road tile with road on both sides along one axis and a junction ahead
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not road.call(x, y):
				continue
			var ck2 := Vector2i(x >> 5, y >> 5)
			if not sts.has(ck2):
				continue
			var st2: SurfaceTool = sts[ck2]
			# vertical road (kerbs left/right), junction below: stripes across x
			if not road.call(x - 1, y) and road.call(x + 1, y) and not road.call(x + 2, y) and road.call(x, y + 1) and road.call(x - 1, y + 1) and road.call(x + 2, y + 1) and road.call(x, y - 1):
				for k in 6:
					_flat(st2, Vector3(x + 0.18 + k * 0.33, 0.013, y + 0.8), Vector3(0.16, 0, 0.36), line)
			if not road.call(x, y - 1) and road.call(x, y + 1) and not road.call(x, y + 2) and road.call(x + 1, y) and road.call(x + 1, y - 1) and road.call(x + 1, y + 2) and road.call(x - 1, y):
				for k in 6:
					_flat(st2, Vector3(x + 0.8, 0.013, y + 0.18 + k * 0.33), Vector3(0.36, 0, 0.16), line)
	for ck in sts:
		var st3: SurfaceTool = sts[ck]
		st3.index()
		var mi := MeshInstance3D.new()
		mi.name = "Sidewalks_%d_%d" % [ck.x, ck.y]
		mi.mesh = st3.commit()
		mi.material_override = prop_detail_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## Upward-facing quad (2 tris) of size s.x x s.z centred at c: road paint, kerb tops, joints.
func _flat(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var hx := s.x * 0.5
	var hz := s.z * 0.5
	for p: Vector3 in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(c.x + p.x, c.z + p.z))
		st.add_vertex(c + p)

func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	PropMeshes.box(st, c, s, col)

# ---------------------------------------------------------------- props
func _build_props(tiles_path: String) -> void:
	var by_kind := {}
	var dp := tiles_path.replace(".txt", ".decor.txt")
	if not decor_override.is_empty():
		# M2.9: map-builder maps carry their placed props in MapDef.decor ([kind, x, y, rot])
		for d in decor_override:
			if not by_kind.has(String(d[0])):
				by_kind[String(d[0])] = []
			by_kind[String(d[0])].append([float(d[1]), float(d[2]), int(d[3])])
		var covered := {}
		for d in decor_override:
			var fp: Vector2i = PropMeshes.FOOTPRINT.get(String(d[0]), Vector2i.ZERO)
			if int(d[3]) % 2 == 1:
				fp = Vector2i(fp.y, fp.x)
			if fp != Vector2i.ZERO:
				var o := Vector2i(roundi(float(d[1]) - fp.x * 0.5), roundi(float(d[2]) - fp.y * 0.5))
				for yy in fp.y:
					for xx in fp.x:
						covered[o + Vector2i(xx, yy)] = true
		for k in [_tree_kind, "rock"]:
			if not by_kind.has(k):
				by_kind[k] = []
		for y in m.h:
			for x in m.w:
				var tt := m.ttype(Vector2i(x, y))
				if tt == SimMap.T.FOREST and _h(x, y) < 0.6:
					by_kind[_tree_kind].append([x + 0.5, y + 0.5, 0])
				elif tt == SimMap.T.CLIFF and _h(x, y) < 0.2 and not covered.has(Vector2i(x, y)):
					by_kind["rock"].append([x + 0.5, y + 0.5, 0])
	elif tiles_path != "" and FileAccess.file_exists(dp):
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
		by_kind = {_tree_kind: [], "rock": []}
		for y in m.h:
			for x in m.w:
				var tt := m.ttype(Vector2i(x, y))
				if tt == SimMap.T.FOREST and _h(x, y) < 0.6:
					by_kind[_tree_kind].append([x + 0.5, y + 0.5, 0])
				elif tt == SimMap.T.CLIFF and _h(x, y) < 0.2:
					by_kind["rock"].append([x + 0.5, y + 0.5, 0])
	var urban := false
	for kind in by_kind:
		urban = urban or (PropMeshes.FOOTPRINT.has(kind) and not kind in PropMeshes.HOUSES and by_kind[kind].size() >= 8)
	material.set_shader_parameter("asphalt_dark", 1.0 if urban else 0.0)
	if urban:
		_build_sidewalks()
	for kind in by_kind:
		var mesh: Mesh = PropMeshes.make(kind)
		if mesh == null:
			continue
		var mat := prop_material
		if kind in ["palm", "scrub_tree", "pine", "pine_snow", "oak", "bush"]:
			mat = prop_sway_material
		elif kind in PropMeshes.HOUSES:
			mat = prop_detail_material
		elif PropMeshes.FOOTPRINT.has(kind):
			mat = prop_tower_material
			has_towers = true
		elif kind in ["gas_station", "shack", "power_pole", "streetlight", "streetlight_double"]:
			mat = prop_detail_material
		# M2.9: one MultiMesh per kind per 32x32-tile chunk so off-screen props are frustum-culled
		# (dense urban maps carry thousands of cars / lights / towers)
		# M3.0: trees are split over TREE_VARIANTS shapes by a position hash (more variety)
		var nv: int = PropMeshes.TREE_VARIANTS if kind in PropMeshes.TREES or kind.begins_with("rock") else 1
		var chunks := {}
		for it in by_kind[kind]:
			var v := int(_h(int(it[0] * 3.0), int(it[1] * 5.0)) * nv) % nv
			if kind == "oak":   # M3.2: autumn colours come in clusters (low-frequency choice)
				v = int(_vn(it[0] / 7.0, it[1] / 7.0) * nv * 0.999) % nv
			var ck := Vector3i(int(it[0]) >> 5, int(it[1]) >> 5, v)
			if not chunks.has(ck):
				chunks[ck] = []
			chunks[ck].append(it)
		for ck in chunks:
			var vm: Mesh = mesh if ck.z == 0 else PropMeshes.make("%s:%d" % [kind, ck.z])
			_multimesh(chunks[ck], vm, mat, kind, "_%d_%d_%d" % [ck.x, ck.y, ck.z])

func _multimesh(items: Array, mesh: Mesh, mat: Material, kind: String, suffix: String = "") -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	var jitter := kind in ["palm", "scrub_tree", "rock", "rock_small", "pine", "pine_snow", "oak", "bush", "hay_bale"]
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
		mm.set_instance_color(i, (prop_tint.darkened(n * 0.15) if jitter else prop_tint))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Props_" + kind + suffix
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind.begins_with("car_") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)

## M2.9: up to 24 unit positions (world space, nearest the camera focus) that tall towers fade around.
func set_occluded_units(pts: PackedVector4Array) -> void:
	if prop_tower_material == null:
		return
	prop_tower_material.set_shader_parameter("occl_n", pts.size())
	if pts.size() > 0:
		var full := pts.duplicate()
		full.resize(24)
		prop_tower_material.set_shader_parameter("occl_pts", full)

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

## M3.2 dense ground scatter (Zero Hour look): grass / dry-scrub tufts and pebbles on open
## ground, deterministic per tile, one MultiMesh per 32 x 32 chunk (culled), no shadows. Density
## follows the graphics preset ("scatter": Ultra 1.0 .. Low off).
var scatter_count := 0
func _build_scatter(dry: bool) -> void:
	var dens := float(Settings.preset().get("scatter", 1.0))
	if dens <= 0.0:
		return
	var tuft := _tuft_mesh(dry)
	var peb := _pebble_mesh()
	var bush := _bush_mesh(dry)
	var mat := prop_material   # vertex colour + fog of war (alpha 1 = plain, no emission)
	for cy in range(0, m.h, CHUNK):
		for cx in range(0, m.w, CHUNK):
			var tx: Array = []
			var px: Array = []
			var bx: Array = []
			for y in range(cy, mini(cy + CHUNK, m.h)):
				for x in range(cx, mini(cx + CHUNK, m.w)):
					var tt := m.ttype(Vector2i(x, y))
					if tt != SimMap.T.GRASS and tt != SimMap.T.ROUGH and tt != SimMap.T.FOREST:
						continue
					if absf(heights[y * (m.w + 1) + x]) > 0.01 or absf(heights[(y + 1) * (m.w + 1) + x + 1]) > 0.01:
						continue
					var h := _h(x * 3 + 1, y * 7 + 2)
					var n_t := int((1.6 if tt != SimMap.T.ROUGH else 0.8) * dens * (0.5 + h))
					for k in n_t:
						var r1 := _h(x * 11 + k, y * 13 + k * 5)
						var r2 := _h(x * 17 + k * 3, y * 19 + k)
						var sc := 0.7 + r1 * 0.7
						tx.append(Transform3D(Basis(Vector3.UP, r2 * TAU).scaled(Vector3(sc, sc * (0.8 + r2 * 0.5), sc)), Vector3(x + r1, 0.0, y + r2)))
					# M3.2 item 14: dense dark scrub / bush clusters (clumped by low-frequency noise)
					var cn := _vn(x / 6.0 + 40.0, y / 6.0) * 0.8 + _h(x, y + 999) * 0.2
					if cn > 0.62 and not house_tiles.has(Vector2i(x, y)):
						for k in int((1.0 + (cn - 0.62) * 8.0) * dens):
							var b1 := _h(x * 41 + k * 3, y * 43 + k)
							var b2 := _h(x * 47 + k, y * 53 + k * 7)
							var bs := 0.75 + b1 * 0.7
							bx.append(Transform3D(Basis(Vector3.UP, b2 * TAU).scaled(Vector3(bs, bs * (0.8 + b2 * 0.4), bs)), Vector3(x + b1, 0.0, y + b2)))
					if tt == SimMap.T.ROUGH or h > 0.55:
						for k in int((2.0 if tt == SimMap.T.ROUGH else 1.0) * dens):
							var q1 := _h(x * 23 + k, y * 29 + k * 7)
							var q2 := _h(x * 31 + k * 5, y * 37 + k)
							var ps := 0.6 + q2 * 0.9
							px.append(Transform3D(Basis(Vector3.UP, q1 * TAU).scaled(Vector3(ps, ps * 0.7, ps)), Vector3(x + q2, 0.0, y + q1)))
			for pair in [[tx, tuft], [px, peb], [bx, bush]]:
				var arr: Array = pair[0]
				if arr.is_empty():
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = pair[1]
				mm.instance_count = arr.size()
				for i in arr.size():
					mm.set_instance_transform(i, arr[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = mat
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 60.0
				add_child(mmi)
				scatter_count += arr.size()

## Tuft: 5 tapered blades leaning outward, darker at the root (vertex colour = fake AO).
func _tuft_mesh(dry: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Color("#c9b46a") if dry else Color("#8fb34e")
	var root := Color("#6e5c34") if dry else Color("#3f5a26")
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		var sd := Vector3(-d.z, 0, d.x) * 0.012
		var h := 0.07 + 0.03 * float(i % 3)
		var top := d * 0.045 + Vector3(0, h, 0)
		for vv in [[-sd, sd, top], [sd, -sd, top]]:   # both faces
			st.set_color(root)
			st.add_vertex(vv[0])
			st.set_color(root)
			st.add_vertex(vv[1])
			st.set_color(tip)
			st.add_vertex(vv[2])
	st.generate_normals()
	return st.commit()

## M3.2 item 14: low dark scrub bush (a few overlapping blobs, darker underside = fake AO).
func _bush_mesh(dry: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c0 := Color("#3a3a22") if dry else Color("#2f4220")
	var c1 := Color("#4a4628") if dry else Color("#3c5426")
	PropMeshes.sph(st, Vector3(0, 0.05, 0), Vector3(0.11, 0.07, 0.1), c0, 5)
	PropMeshes.sph(st, Vector3(0.07, 0.04, 0.05), Vector3(0.07, 0.05, 0.07), c1, 4)
	PropMeshes.sph(st, Vector3(-0.06, 0.035, -0.04), Vector3(0.065, 0.045, 0.06), c1.darkened(0.1), 4)
	st.generate_normals()
	return st.commit()

func _pebble_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	PropMeshes.sph(st, Vector3(0, 0.008, 0), Vector3(0.03, 0.02, 0.025), Color("#8a8070"), 5)
	PropMeshes.sph(st, Vector3(0.04, 0.006, 0.02), Vector3(0.018, 0.012, 0.016), Color("#6f675c"), 4)
	return st.commit()

## M2: static ground decals scattered deterministically from the map: tire tracks along roads
## and around resource fields, cracks on asphalt / concrete, oil stains on roads and where
## harvesters work, sand drifting onto roads, rubble at cliff feet; M3.2: scorch marks and
## vehicle tracks across open ground. Flat tiles only.
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
			elif r1 > 0.985 and bc != "w":
				kind = 10; size = 1.8 + r2 * 1.2                # M3.2: old shell scorch marks in the open
			elif r1 > 0.965 and r1 <= 0.985:
				kind = int(r2 * 4.0) % 4; size = 1.6; stretch = 1.8   # M3.2: vehicle tracks across open ground
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
