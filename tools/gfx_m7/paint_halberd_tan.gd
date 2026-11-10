extends SceneTree
## Solid CARC tan on the approved M1A3. Class 0 and 20 keep their baked AO (relative
## luminance) but lose the olive hue. Team stripe, glass, tracks, wheels, steel and
## canvas are left alone. LODs are rebuilt from the same vertices.
##   godot --headless --path . -s res://tools/gfx_m7/paint_halberd_tan.gd
const TAN := Color("#E0C080")
const SRC := "res://view/units/us/halberd_v3detail.tscn"
const LIVE := "res://view/units/us/halberd.tscn"
const PAINT := [0, 20]

func _initialize() -> void:
	var root: Node = (load(SRC) as PackedScene).instantiate()
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		n += _recolor(mi as MeshInstance3D)
	var out := PackedScene.new()
	out.pack(root)
	for path in [SRC, LIVE]:
		var err := ResourceSaver.save(out, path)
		print("saved %s %s" % [path, "OK" if err == OK else str(err)])
	print("repainted %d paint verts to %s" % [n, TAN.to_html(false)])
	root.free()
	quit(0)

func _recolor(mi: MeshInstance3D) -> int:
	var src := mi.mesh as ArrayMesh
	if src == null or src.get_surface_count() != 1:
		return 0
	var arr := src.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var tan_l := TAN.get_luminance()
	var changed := 0
	for i in cols.size():
		var c := cols[i]
		var cls := int(c.a * 20.0 + 0.5)
		if cls != 0 and cls != 20:
			continue
		var l := c.get_luminance()
		var k := clampf(l / maxf(tan_l, 0.001), 0.42, 1.15)
		cols[i] = Color(TAN.r * k, TAN.g * k, TAN.b * k, c.a)
		changed += 1
	arr[Mesh.ARRAY_COLOR] = cols
	mi.mesh = _with_lods(arr, src.surface_get_material(0), src)
	return changed

func _with_lods(arr: Array, mat: Material, src: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mat)
	im.generate_lods(25.0, 60.0, [])
	var ld := {}
	for l in im.get_surface_lod_count(0):
		ld[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], ld)
	m.surface_set_material(0, mat)
	for k in src.get_meta_list():
		m.set_meta(k, src.get_meta(k))
	m.set_meta("ao_baked", true)
	m.set_meta("camo", true)
	m.set_meta("carc_tan", true)
	return m
