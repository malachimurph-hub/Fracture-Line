class_name PropMeshes
## Procedural, vertex-coloured, original low-poly meshes for environment props and the
## shared part helpers used by the unit/building generator (tools/gen_views.gd).
## Palette: Zero Hour-like warm, slightly saturated, sun-baked.
static var _cache: Dictionary = {}

## M2.9 urban props: footprint in tiles of props that block the ground (tall buildings stand on
## impassable tiles in the map; the map builder stamps these as Cliff). Others are 1 x 1 decor.
const FOOTPRINT := {"tower_glass": Vector2i(4, 4), "tower_apart": Vector2i(4, 4), "tower_office": Vector2i(4, 4),
	"tower_slim": Vector2i(3, 3), "shops": Vector2i(4, 3)}
const URBAN := ["tower_glass", "tower_apart", "tower_office", "tower_slim", "shops", "car_red", "car_white", "car_blue",
	"car_silver", "car_taxi", "car_van", "car_suv", "streetlight_double", "streetlight"]
const CAR_COL := {"car_red": "#a3302a", "car_white": "#e2e0d8", "car_blue": "#2f5a8a", "car_silver": "#a7abae",
	"car_taxi": "#e0b22e", "car_van": "#d8d6ce", "car_suv": "#2a2c2e"}

## Floor bands of a w x d tower from y0 to y1: alternating wall and window strips on all 4 sides.
static func _tower_bands(st: SurfaceTool, w: float, d: float, y0: float, y1: float, floors: int, wall: Color, glass: Color) -> void:
	box(st, Vector3(0, (y0 + y1) * 0.5, 0), Vector3(w, y1 - y0, d), wall)
	var fh := (y1 - y0) / floors
	for i in floors:
		var y := y0 + fh * (i + 0.55)
		box(st, Vector3(0, y, 0), Vector3(w + 0.03, fh * 0.48, d * 0.86), glass)
		box(st, Vector3(0, y, 0), Vector3(w * 0.86, fh * 0.48, d + 0.03), glass)

static func _car(st: SurfaceTool, body: Color, kind: String) -> void:
	var van := kind == "car_van"
	var suv := kind == "car_suv"
	var l := 1.05 if van else 0.92
	var hgt := 0.5 if van else (0.4 if suv else 0.3)
	box(st, Vector3(0, 0.2, 0), Vector3(0.44, 0.2, l), body)                                     # lower body
	box(st, Vector3(0, 0.12, 0), Vector3(0.46, 0.06, l + 0.02), Color("#2a2a2a"))                # bumpers / sills
	var cab_l := l * (0.9 if van else (0.62 if suv else 0.5))
	var cab_z := -0.04 if van else (-0.08 if suv else -0.04)
	box(st, Vector3(0, 0.3 + hgt * 0.5, cab_z), Vector3(0.4, hgt, cab_l), body)               # cabin
	box(st, Vector3(0, 0.3 + hgt * 0.5, cab_z), Vector3(0.41, hgt * 0.6, cab_l * 0.86), Color("#25303a"))   # side glass
	box(st, Vector3(0, 0.3 + hgt * 0.55, cab_z + cab_l * 0.5), Vector3(0.36, hgt * 0.6, 0.02), Color("#2e3b46"), Vector3(-25, 0, 0))
	for wx in [-0.21, 0.21]:
		for wz in [-l * 0.32, l * 0.32]:
			cyl(st, Vector3(wx, 0.1, wz), 0.1, 0.1, 0.08, Color("#1d1c1b"), 7, Vector3(0, 0, 90))
	box(st, Vector3(0, 0.24, l * 0.5 + 0.005), Vector3(0.36, 0.05, 0.02), Color("#e8e2c8"))      # headlights
	box(st, Vector3(0, 0.24, -l * 0.5 - 0.005), Vector3(0.36, 0.05, 0.02), Color("#a8281e"))     # tail lights
	if kind == "car_taxi":
		box(st, Vector3(0, 0.3 + hgt + 0.03, cab_z), Vector3(0.14, 0.05, 0.08), Color("#f2efe4"))

static func add_prim(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arr := prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	if idx.is_empty():
		for i in v.size():
			st.set_color(col)
			st.set_normal((nb * nm[i]).normalized())
			if not uv.is_empty():
				st.set_uv(uv[i])
			st.add_vertex(xf * v[i])
		return
	for i in idx:
		st.set_color(col)
		st.set_normal((nb * nm[i]).normalized())
		if not uv.is_empty():
			st.set_uv(uv[i])
		st.add_vertex(xf * v[i])

static func box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = s
	add_prim(st, b, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), c), col)

static func cyl(st: SurfaceTool, c: Vector3, r_top: float, r_bot: float, h: float, col: Color, sides: int = 8, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	add_prim(st, m, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), c), col)

static func sph(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, seg: int = 7) -> void:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = seg
	m.rings = maxi(3, seg / 2)
	add_prim(st, m, Transform3D(Basis().scaled(r), c), col)

static func wedge(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var p := PrismMesh.new()
	p.size = s
	p.left_to_right = 0.5
	add_prim(st, p, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), c), col)

static func make(kind: String) -> Mesh:
	if _cache.has(kind):
		return _cache[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"palm":
			var trunk := Color("#8a6f4d")
			for i in 5:
				var t := float(i) / 5.0
				cyl(st, Vector3(sin(t * 1.6) * 0.18, 0.3 + i * 0.5, 0), 0.07 - t * 0.02, 0.09 - t * 0.02, 0.52, trunk.darkened(i * 0.04), 6, Vector3(0, 0, -8 - i * 3))
			var top := Vector3(sin(1.6) * 0.2, 2.65, 0)
			for k in 7:
				var a := k * TAU / 7.0
				var dir := Vector3(cos(a), 0, sin(a))
				var leaf := Color("#5d7a2e") if k % 2 == 0 else Color("#6f8a35")
				box(st, top + dir * 0.55 + Vector3(0, -0.12, 0), Vector3(1.1, 0.04, 0.24), leaf, Vector3(0, -rad_to_deg(a), -22))
			sph(st, top, Vector3(0.14, 0.12, 0.14), Color("#6b5530"), 5)
		"scrub_tree":
			cyl(st, Vector3(0, 0.35, 0), 0.05, 0.08, 0.7, Color("#6e5a40"), 5)
			sph(st, Vector3(0, 0.95, 0), Vector3(0.55, 0.4, 0.5), Color("#7a7d3c"), 7)
			sph(st, Vector3(0.25, 0.78, 0.15), Vector3(0.38, 0.3, 0.35), Color("#6c7034"), 6)
			sph(st, Vector3(-0.22, 0.8, -0.18), Vector3(0.36, 0.28, 0.34), Color("#858a45"), 6)
		"pine", "pine_snow":
			# M2.5 conifer (temperate / winter maps); the snow variant carries white caps on each tier
			var snow := kind == "pine_snow"
			cyl(st, Vector3(0, 0.35, 0), 0.07, 0.1, 0.7, Color("#5a4632"), 6)
			for k in 4:
				var y := 0.55 + k * 0.52
				var r := 0.95 - k * 0.2
				var g := Color("#2f4a2c").lightened(k * 0.03)
				cyl(st, Vector3(0, y + 0.3, 0), 0.03, r, 0.78, g, 8)
				if snow:
					cyl(st, Vector3(0, y + 0.42, 0), 0.02, r * 0.78, 0.42, Color("#e8eef5"), 8)
		"oak":
			cyl(st, Vector3(0, 0.55, 0), 0.08, 0.13, 1.1, Color("#5c4a36"), 6)
			cyl(st, Vector3(0.18, 1.05, 0.05), 0.04, 0.06, 0.5, Color("#5c4a36"), 5, Vector3(0, 0, -35))
			sph(st, Vector3(0, 1.55, 0), Vector3(0.95, 0.7, 0.9), Color("#4c6b2f"), 8)
			sph(st, Vector3(0.45, 1.35, 0.3), Vector3(0.6, 0.48, 0.55), Color("#577a34"), 7)
			sph(st, Vector3(-0.4, 1.4, -0.3), Vector3(0.62, 0.5, 0.58), Color("#45622b"), 7)
		"bush":
			sph(st, Vector3(0, 0.22, 0), Vector3(0.5, 0.3, 0.45), Color("#53702f"), 6)
			sph(st, Vector3(0.3, 0.16, 0.18), Vector3(0.32, 0.22, 0.3), Color("#4a6229"), 5)
		"fence":
			for fx in [-0.9, -0.3, 0.3, 0.9]:
				box(st, Vector3(fx, 0.3, 0), Vector3(0.08, 0.6, 0.08), Color("#6e5a42"))
			for fy in [0.22, 0.45]:
				box(st, Vector3(0, fy, 0), Vector3(1.9, 0.06, 0.04), Color("#7a6449"))
		"hay_bale":
			cyl(st, Vector3(0, 0.32, 0), 0.32, 0.32, 0.55, Color("#b89b55"), 9, Vector3(0, 0, 90))
		"streetlight":
			cyl(st, Vector3(0, 1.4, 0), 0.035, 0.05, 2.8, Color("#4b4f52"), 6)
			box(st, Vector3(0.28, 2.78, 0), Vector3(0.6, 0.05, 0.08), Color("#4b4f52"))
			box(st, Vector3(0.55, 2.72, 0), Vector3(0.22, 0.07, 0.14), Color("#d8d0b0"))
		"rock":
			sph(st, Vector3(0, 0.25, 0), Vector3(0.7, 0.55, 0.6), Color("#9c8a72"), 6)
			sph(st, Vector3(0.45, 0.15, 0.25), Vector3(0.4, 0.35, 0.35), Color("#8b7a64"), 5)
		"debris_chunk":
			box(st, Vector3.ZERO, Vector3(1, 0.6, 0.8), Color.WHITE)
		"rock_small":
			sph(st, Vector3(0, 0.08, 0), Vector3(0.28, 0.18, 0.24), Color("#a28f75"), 5)
		"power_pole":
			cyl(st, Vector3(0, 1.3, 0), 0.04, 0.06, 2.6, Color("#6a5236"), 5)
			box(st, Vector3(0, 2.45, 0), Vector3(0.9, 0.06, 0.07), Color("#5e4a31"))
			for xx in [-0.38, 0.0, 0.38]:
				cyl(st, Vector3(xx, 2.53, 0), 0.025, 0.03, 0.1, Color("#c9c2b0"), 5)
		"wreck_car":
			var burnt := Color("#3b3430")
			var rust := Color("#6b4a32")
			box(st, Vector3(0, 0.25, 0), Vector3(0.8, 0.28, 1.55), rust)
			box(st, Vector3(0, 0.5, -0.1), Vector3(0.72, 0.24, 0.78), burnt, Vector3(4, 0, 2))
			for wx in [-0.4, 0.4]:
				for wz in [-0.5, 0.5]:
					cyl(st, Vector3(wx, 0.12, wz), 0.14, 0.14, 0.12, Color("#1f1d1c"), 7, Vector3(0, 0, 90))
			box(st, Vector3(0.1, 0.43, 0.62), Vector3(0.5, 0.05, 0.3), Color("#55463a"), Vector3(-25, 0, 0))
		"shack":
			var wall := Color("#b0a083")
			box(st, Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 1.7), wall)
			box(st, Vector3(0, 1.05, 0), Vector3(2.0, 0.1, 1.9), Color("#7f7b72"), Vector3(4, 0, 0))   # corrugated roof
			box(st, Vector3(0.4, 0.35, 0.86), Vector3(0.45, 0.7, 0.04), Color("#5a4632"))
			box(st, Vector3(-0.45, 0.6, 0.86), Vector3(0.4, 0.3, 0.04), Color("#2e3338"))
			box(st, Vector3(-0.9, 0.3, -0.6), Vector3(0.35, 0.6, 0.35), Color("#8a6a3a"))
		"gas_station":
			var conc := Color("#c8bfae")
			box(st, Vector3(-0.6, 0.6, 0), Vector3(1.6, 1.2, 1.8), conc)                           # shop
			box(st, Vector3(-0.6, 1.22, 0), Vector3(1.7, 0.08, 1.9), Color("#8d877c"))
			box(st, Vector3(0.18, 0.5, 0), Vector3(0.04, 0.6, 1.2), Color("#2d3640"))               # window
			box(st, Vector3(0.9, 1.35, 0), Vector3(1.4, 0.14, 1.9), Color("#c33f2a"))               # canopy (red band)
			box(st, Vector3(0.9, 1.44, 0), Vector3(1.4, 0.05, 1.9), Color("#e8e2d5"))
			for zz in [-0.6, 0.6]:
				cyl(st, Vector3(0.9, 0.65, zz), 0.06, 0.06, 1.3, Color("#d9d3c7"), 6)
				box(st, Vector3(0.9, 0.3, zz * 0.5), Vector3(0.25, 0.6, 0.18), Color("#a83524"))     # pumps
			box(st, Vector3(1.55, 1.6, 0.8), Vector3(0.08, 1.2, 0.08), Color("#5a5650"))
			box(st, Vector3(1.55, 2.25, 0.8), Vector3(0.5, 0.35, 0.06), Color("#e7b23a"))           # sign
		# ---------------------------------------------------------- M2.9 urban props
		"tower_glass":   # 4 x 4 glass office tower with a podium, crown and rooftop plant
			box(st, Vector3(0, 0.6, 0), Vector3(3.9, 1.2, 3.9), Color("#9c968a"))
			box(st, Vector3(0, 0.55, 0), Vector3(3.95, 0.7, 3.2), Color("#2b3640"))
			_tower_bands(st, 3.2, 3.2, 1.2, 8.6, 12, Color("#7d8a93"), Color("#3a5468"))
			for c in [Vector2(-1.6, -1.6), Vector2(1.6, -1.6), Vector2(1.6, 1.6), Vector2(-1.6, 1.6)]:
				box(st, Vector3(c.x, 4.9, c.y), Vector3(0.14, 7.4, 0.14), Color("#c9cdd0"))
			box(st, Vector3(0, 8.75, 0), Vector3(3.3, 0.3, 3.3), Color("#c9cdd0"))
			box(st, Vector3(0.6, 9.1, 0.4), Vector3(1.2, 0.5, 1.0), Color("#8d9296"))
			cyl(st, Vector3(-0.8, 9.6, -0.8), 0.02, 0.05, 1.6, Color("#4b4f52"), 5)
		"tower_apart":   # 4 x 4 concrete apartment block: window bands, balconies, water tanks
			_tower_bands(st, 3.8, 3.8, 0.0, 5.6, 8, Color("#c8bba0"), Color("#3d4650"))
			for i in 7:
				var y := 0.7 * (i + 1) + 0.05
				box(st, Vector3(0, y, 1.98), Vector3(2.8, 0.06, 0.32), Color("#b0a488"))
				box(st, Vector3(0, y + 0.16, 2.12), Vector3(2.8, 0.26, 0.03), Color("#9a8f78"))
				box(st, Vector3(0, y, -1.98), Vector3(2.8, 0.06, 0.32), Color("#b0a488"))
			box(st, Vector3(0, 5.7, 0), Vector3(3.9, 0.15, 3.9), Color("#8f8574"))
			for x in [-1.0, 0.9]:
				cyl(st, Vector3(x, 6.05, 0.8), 0.28, 0.28, 0.55, Color("#d9d4c8"), 8)
			box(st, Vector3(1.1, 0.4, 1.95), Vector3(0.8, 0.8, 0.06), Color("#5a4632"))
		"tower_office":   # stepped 4 x 4 office: three setbacks and an antenna mast
			_tower_bands(st, 3.9, 3.9, 0.0, 3.0, 4, Color("#b7aa94"), Color("#33444f"))
			_tower_bands(st, 3.0, 3.0, 3.0, 6.4, 5, Color("#a99c86"), Color("#34505f"))
			_tower_bands(st, 2.0, 2.0, 6.4, 9.2, 4, Color("#9d907b"), Color("#355566"))
			box(st, Vector3(0, 9.3, 0), Vector3(2.1, 0.2, 2.1), Color("#7d7468"))
			cyl(st, Vector3(0, 10.6, 0), 0.03, 0.08, 2.6, Color("#4b4f52"), 6)
			box(st, Vector3(0, 0.45, 1.96), Vector3(1.4, 0.9, 0.06), Color("#24303a"))
		"tower_slim":   # 3 x 3 residential tower with a red crown
			_tower_bands(st, 2.7, 2.7, 0.0, 7.0, 10, Color("#d6cdb8"), Color("#3a4652"))
			box(st, Vector3(0, 7.2, 0), Vector3(2.8, 0.4, 2.8), Color("#a3402e"))
			box(st, Vector3(0, 7.6, 0), Vector3(1.2, 0.5, 1.2), Color("#8a8278"))
		"shops":   # 4 x 3 two-storey shop row with coloured awnings and signs
			box(st, Vector3(0, 1.0, 0), Vector3(3.9, 2.0, 2.9), Color("#d2c3a2"))
			box(st, Vector3(0, 2.05, 0), Vector3(4.0, 0.12, 3.0), Color("#8f8574"))
			var cols := [Color("#b8402e"), Color("#2f6a8a"), Color("#3f7a3a"), Color("#c99a2e")]
			for i in 4:
				var x := -1.46 + i * 0.97
				box(st, Vector3(x, 0.45, 1.46), Vector3(0.8, 0.8, 0.04), Color("#28333c"))
				box(st, Vector3(x, 0.95, 1.62), Vector3(0.9, 0.06, 0.4), cols[i], Vector3(-18, 0, 0))
				box(st, Vector3(x, 1.4, 1.46), Vector3(0.6, 0.35, 0.04), Color("#3a4652"))
				box(st, Vector3(x, 1.85, 1.47), Vector3(0.7, 0.18, 0.04), cols[(i + 2) % 4])
			box(st, Vector3(1.2, 2.3, -0.6), Vector3(0.7, 0.4, 0.6), Color("#9a9a96"))
		"car_red", "car_white", "car_blue", "car_silver", "car_taxi", "car_van", "car_suv":
			_car(st, Color(CAR_COL[kind]), kind)
		"streetlight_double":
			cyl(st, Vector3(0, 1.6, 0), 0.04, 0.06, 3.2, Color("#4b4f52"), 6)
			box(st, Vector3(0, 0.1, 0), Vector3(0.22, 0.2, 0.22), Color("#5a5e60"))
			for sx in [-1.0, 1.0]:
				box(st, Vector3(sx * 0.32, 3.18, 0), Vector3(0.64, 0.05, 0.08), Color("#4b4f52"), Vector3(0, 0, sx * -6.0))
				box(st, Vector3(sx * 0.6, 3.12, 0), Vector3(0.24, 0.07, 0.14), Color("#4b4f52"))
				box(st, Vector3(sx * 0.6, 3.08, 0), Vector3(0.2, 0.02, 0.11), Color("#fff2c0"))
		_:
			return null
	st.index()
	var mesh := st.commit()
	_cache[kind] = mesh
	return mesh
