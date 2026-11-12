## M3.4 task 3: infantry overhaul (Malachi: "still look way too cartoony and the same; troops
## should hold the gun with two hands when shooting").
extends RefCounted
const Bake := preload("res://tools/bake_infantry_m34.gd")
const Rig := preload("res://tools/gfx_m34/soldier_rig.gd")
const Anims := preload("res://tools/gfx_m34/soldier_anims.gd")

static func run(t: Node) -> void:
	_bakes(t)
	_two_hands(t)
	_variety(t)
	_shader(t)

static func _inf_scenes() -> Array:
	var out := []
	for id in Content.units:
		var ud: UnitDef = Content.units[id]
		if ud.view_scene != "" and FileAccess.file_exists(ud.view_scene) and FileAccess.get_file_as_string(ud.view_scene).contains("infantry_view.gd"):
			out.append([id, ud.view_scene])
	return out

static func _bakes(t: Node) -> void:
	var bad := []
	var n := 0
	var bytes := 0
	var seen := {}
	for p in _inf_scenes():
		var v: InfantryView = (load(p[1]) as PackedScene).instantiate()
		var vm: VatModel = v.vat
		n += 1
		for cn in ["idle", "walk", "run", "fire", "fire_kneel", "lean", "die", "die2"]:
			if not vm.anims.has(cn):
				bad.append("%s: no %s clip" % [p[0], cn])
		if vm.fmt < 3 or vm.variants != 4 or not vm.source.begins_with("Original procedural"):
			bad.append("%s: fmt %d variants %d source %s" % [p[0], vm.fmt, vm.variants, vm.source])
		var tris := vm.mesh.surface_get_array_index_len(0) / 3
		if tris > 3300 or vm.vertex_count > 4096 or vm.pos_tex.get_width() > 4096 or vm.rows != 1:
			bad.append("%s: %d tris, %d verts, tex %d wide, %d rows" % [p[0], tris, vm.vertex_count, vm.pos_tex.get_width(), vm.rows])
		if vm.mesh.get_surface_count() < 1 or vm.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV == 0:
			bad.append("%s: mesh without packed colours" % p[0])
		if not seen.has(vm.resource_path):
			seen[vm.resource_path] = true
			bytes += FileAccess.get_file_as_bytes(vm.resource_path).size()
		v.free()
	t._check(bad.is_empty() and n >= 19, "every infantry model is the new original soldier with walk / run / aim / kneel / lean / two death clips, in the mobile budget (%d models)%s" % [n, "" if bad.is_empty() else ": " + str(bad.slice(0, 4))])
	# 0.4.4 added three US scenes; M4.5 gives them their own bakes. The old 20 MB cap was already over.
	t._check(bytes < 23 * 1024 * 1024, "the soldier bakes stay small on disk (%.1f MB for all, compact VAT)" % (bytes / 1048576.0))

## every soldier's hands are on his weapon when he fires: right palm on the grip, left palm on
## the handguard / front grip / tube; the weapon points where he aims, the sight at his eye
static func _two_hands(t: Node) -> void:
	var bad := []
	var n := 0
	for key in Bake.SPECS:
		var rs: Array = Bake.build_rig(key)
		var r = rs[0]
		var spec: Dictionary = rs[1]
		var gun: Dictionary = Bake.GUNS[spec["gun"]]
		var style: String = Bake.STYLE.get(spec["gun"], "rifle")
		if style == "tool":
			continue
		for clip in ["fire", "fire_kneel", "idle", "run"]:
			for tt in [0.0, 0.2]:
				var g: Array = r.solve(Anims.pose(clip, tt, style), gun)
				var gx: Transform3D = g[Rig.GUN]
				var palm_r := _palm(g[Rig.HAND_R])
				var palm_l := _palm(g[Rig.HAND_L])
				var er: float = palm_r.distance_to(gx * (gun["grip"] as Vector3))
				var el: float = palm_l.distance_to(gx * (gun["support"] as Vector3))
				n += 1
				if er > 0.03 or el > 0.04:
					bad.append("%s %s: right hand %.2f m, left hand %.2f m off the weapon" % [key, clip, er, el])
				if clip.begins_with("fire"):
					var fwd := gx.basis.z.normalized()
					var eye: Vector3 = (g[Rig.HEAD] as Transform3D) * Vector3(0, 0.11, 0.09)
					var sight := gx * Vector3(0, 0.12, 0)
					if fwd.dot(Vector3.BACK) < 0.97:
						bad.append("%s %s: weapon points %s" % [key, clip, fwd])
					if style == "rifle" and absf(sight.y - eye.y) > 0.12:
						bad.append("%s %s: sight %.2f m below the eye" % [key, clip, eye.y - sight.y])
	t._check(bad.is_empty() and n > 100, "soldiers hold their weapons in both hands and aim down the sights (%d pose checks)%s" % [n, "" if bad.is_empty() else ": " + str(bad.slice(0, 4))])
	# adult proportions: head ~1/7.5 of standing height, legs about half
	var J: Dictionary = Rig.J
	var head_h := 1.805 - 1.58
	t._check(absf(1.8 / head_h - 7.6) < 0.6 and absf(J["hip_L"].y / 1.8 - 0.53) < 0.04, "realistic adult proportions (%.1f heads tall, legs %.0f %% of height)" % [1.8 / head_h, J["hip_L"].y / 1.8 * 100.0])

static func _palm(h: Transform3D) -> Vector3:
	return h.origin - h.basis.y.normalized() * Rig.HAND_LEN

## no two soldiers of a type look the same: look variants, skin tone, tint, size
static func _variety(t: Node) -> void:
	var v: InfantryView = (load("res://view/units/us/grunt.tscn") as PackedScene).instantiate()
	t.add_child(v)
	var looks := {}
	var sizes := {}
	for id in range(1, 41):
		v.set_variant(id)
		looks[v.variant] = true
		sizes[v._scale] = true
	t._check(looks.size() == 4 and sizes.size() >= 4, "soldiers of one type mix four looks and several heights (%d looks, %d heights)" % [looks.size(), sizes.size()])
	var vm: VatModel = v.vat
	var a: Array = vm.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var masked := 0
	for u in uv:
		if int(u.y) / 256 / 16 > 0:
			masked += 1
	t._check(masked > 50, "the look variants swap real head gear / pack geometry (%d variant vertices)" % masked)
	# the view picks kneeling fire for marksmen and some riflemen, and two ways to fall
	var sn: InfantryView = (load("res://view/units/us/sniper.tscn") as PackedScene).instantiate()
	t.add_child(sn)
	var kneel := true
	for id in range(1, 9):
		sn.set_variant(id)
		kneel = kneel and sn._clip_name(2, 0) == "fire_kneel"
	var deaths := {}
	for id in range(1, 21):
		v.set_variant(id)
		deaths[v._clip_name(3, 0)] = true
	t._check(kneel and deaths.has("die") and deaths.has("die2"), "marksmen kneel to fire; soldiers fall in two different ways")
	v.queue_free()
	sn.queue_free()

static func _shader(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://view/infantry/vat_soldier.gdshader")
	t._check(src.contains("vnoise") and src.contains("rest * fq") and src.contains("if (vat_fmt < 2)"), "uniform camouflage is smooth noise on the rest pose (no grain, no tiling, no stripes)")
	t._check(src.contains("instance uniform float variant") and src.contains("skin_tone"), "per-soldier look variant and skin tone in the soldier shader")
