extends SceneTree
## M3.3 (Malachi: "Iran: Technical back to white"): repaint the Technical (tpla_rattler) white in
## place. Only the vertex colours of its sand paint (class 0 plain / 20 camo, tan hue) change:
## they become plain white paint (class 0, so no sprayed camo bands) keeping each vertex's baked
## shading ratio. Geometry, LODs and the tex14 surface bake are untouched.
## Run: godot --headless --path . -s res://tools/gfx_m33/technical_white.gd
const SCENE := "res://view/units/tpla/rattler.tscn"
const WHITE := Color("#e6e4dc")
const REF := Color("#a8915f")   # TP (tools/gfx_m29/tpla_m29.gd)

func _lum(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

func _initialize() -> void:
	var ps: PackedScene = load(SCENE)
	var root := ps.instantiate()
	var changed := 0
	var done := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh as ArrayMesh
		if m == null or done.has(m):
			continue
		done[m] = true
		var surfs: Array = m.get("_surfaces")
		for si in surfs.size():
			var sd: Dictionary = surfs[si]
			var nv: int = sd["vertex_count"]
			var ad: PackedByteArray = sd["attribute_data"]
			var stride := ad.size() / nv
			var cols: PackedColorArray = m.surface_get_arrays(si)[Mesh.ARRAY_COLOR]
			# colour is the first attribute (RGBA8); check against the decoded array
			assert(absi(ad[0] - roundi(cols[0].r * 255.0)) <= 1 and absi(ad[3] - roundi(cols[0].a * 255.0)) <= 1)
			for i in nv:
				var c := cols[i]
				var cl := int(c.a * 20.0 + 0.5)
				if cl != 0 and cl != 20:
					continue
				var hsv_h := c.h * 360.0
				if c.s < 0.18 or c.s > 0.6 or hsv_h < 25.0 or hsv_h > 55.0:
					continue   # not the sand paint (olive jerrycans, dark trim stay)
				var k := clampf(_lum(c) / _lum(REF), 0.55, 1.08)
				var o := i * stride
				ad[o] = clampi(roundi(WHITE.r * k * 255.0), 0, 255)
				ad[o + 1] = clampi(roundi(WHITE.g * k * 255.0), 0, 255)
				ad[o + 2] = clampi(roundi(WHITE.b * k * 255.0), 0, 255)
				ad[o + 3] = 0   # class 0: plain painted metal
				changed += 1
			sd["attribute_data"] = ad
			surfs[si] = sd
		m.set("_surfaces", surfs)
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, SCENE)
	print("technical_white: %d paint vertices repainted, save err %d" % [changed, err])
	quit()
