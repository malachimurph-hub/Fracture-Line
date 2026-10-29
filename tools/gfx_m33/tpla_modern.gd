extends SceneTree
## M3.3 item 34: Iran's structures read as a modern, organised army rather than a scrap-yard
## militia. Post-pass over the built Iran building scenes: the scrap-metal, rough-plank,
## canvas and rusty corrugated parts are repainted as clean rendered panels (sand stone, pale
## off-white, light-grey cladding). Vertex brightness (baked AO / shading variation) is kept
## relative to each part's average, geometry and bake slots are untouched.
##   godot --headless --path . -s res://tools/gfx_m33/tpla_modern.gd -- res://view/buildings/tpla/den.tscn ...
const SCRAP := 17
const WOOD := 12
const CANVAS := 9
const CORR := 11
const PAINT := 0
## class -> [new class, target colour]
const WALL := 100      ## pseudo class: CONCRETE (mud / render) above the pad = building walls
const WALL_Y := 0.16
const MAP := {WALL: [10, Color("#d8cbab")], SCRAP: [PAINT, Color("#cbbd9c")], WOOD: [PAINT, Color("#ddd4c0")], CANVAS: [CANVAS, Color("#c4b48c")], CORR: [CORR, Color("#b0b3ae")]}

func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		_do(path)
	quit(0)

static func _cls(c: Color, p: Vector3) -> int:
	var k := int(c.a * 20.0 + 0.5)
	return WALL if k == 10 and p.y > WALL_Y else k

func _do(path: String) -> void:
	var ps: PackedScene = load(path)
	var root: Node3D = ps.instantiate()
	var n_changed := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh as ArrayMesh
		if m == null or m.get_surface_count() != 1 or m.has_meta("tpla_modern"):
			continue
		var arr := m.surface_get_arrays(0)
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if cols.is_empty():
			continue
		var sum := {}
		var cnt := {}
		for i in cols.size():
			var c := cols[i]
			var k := _cls(c, vs[i])
			if MAP.has(k):
				sum[k] = sum.get(k, 0.0) + maxf(c.r, maxf(c.g, c.b))
				cnt[k] = cnt.get(k, 0) + 1
		if cnt.is_empty():
			continue
		for i in cols.size():
			var c := cols[i]
			var k := _cls(c, vs[i])
			if not MAP.has(k):
				continue
			var mean: float = sum[k] / float(cnt[k])
			var f: float = clampf(maxf(c.r, maxf(c.g, c.b)) / maxf(0.05, mean), 0.6, 1.12)
			var t: Color = MAP[k][1]
			cols[i] = Color(t.r * f, t.g * f, t.b * f, float(MAP[k][0]) / 20.0)
			n_changed += 1
		arr[Mesh.ARRAY_COLOR] = cols
		var lods: bool = RenderingServer.mesh_get_surface(m.get_rid(), 0).get("lods", []).size() > 0
		var nm := ArrayMesh.new()
		if lods:
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
			im.generate_lods(25.0, 60.0, [])
			var ld := {}
			for l in im.get_surface_lod_count(0):
				ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
			nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
		else:
			nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nm.surface_set_material(0, m.surface_get_material(0))
		nm.custom_aabb = m.custom_aabb
		for k2 in m.get_meta_list():
			nm.set_meta(k2, m.get_meta(k2))
		nm.set_meta("tpla_modern", true)
		mi.mesh = nm
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, path)
	root.free()
	print("MODERN %s: %d vertices repainted %s" % [path.get_file(), n_changed, "" if err == OK else "SAVE ERROR %d" % err])
