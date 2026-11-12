extends RefCounted
## Godot-kit silhouettes for the Russian vehicles that are not the BMPT, the Grim Reaper
## or the T-90. Same kit as tools/gfx_m7/kit8.gd. No logos, no lettering.
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const UV8 := preload("res://tools/gfx_m7/us_v8.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const RU := "#5b6442"
const RU_D := "#474f34"
const RU_L := "#6a7350"
const RU_S := "#3a3d38"
const GLASS_C := "#2a3a46"
const S := 0.30

static func bmp3(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.95, "bar_height": 0.95, "recoil": 0.1, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 7.14 * S
	var sx := 0.40
	# Larger road wheels so the run shows under a thin skirt. Roof stays near y = 0.32.
	h.track_run(sx, L * 0.94, 6, 0.092, 0.16, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[L * 0.52, K.sect(0.06, 0.10, 0.14, 0.08, 0.14, 0.10, 0.012)],
		[L * 0.40, K.sect(0.08, 0.14, 0.22, 0.22, 0.32, 0.26, 0.015)],
		[L * 0.24, K.sect(0.08, 0.16, 0.32, 0.32, 0.40, 0.34, 0.012)],
		[-L * 0.40, K.sect(0.08, 0.16, 0.32, 0.34, 0.40, 0.34, 0.01)],
		[-L * 0.50, K.sect(0.10, 0.18, 0.28, 0.30, 0.36, 0.30, 0.01)]])
	# Sharp trim vane on the wedge, and short bow gun ports.
	h.color(RU_L, Geo.PAINT)
	h.plate(Vector3(0, 0.20, L * 0.40), Vector3(0.50, 0.18, 0.008), Vector3(-32, 0, 0))
	h.box(Vector3(0, 0.28, L * 0.46), Vector3(0.48, 0.012, 0.02))
	h.color(RU, Geo.PAINT)
	h.hatch(Vector3(0, 0.33, L * 0.12), 0.07)
	h.hatch(Vector3(-0.12, 0.33, -L * 0.18), 0.06)
	h.hatch(Vector3(0.12, 0.33, -L * 0.18), 0.06)
	h.color(RU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		var side: float = s
		h.tube(Vector3(side * 0.22, 0.18, L * 0.46), Vector3(side * 0.22, 0.17, L * 0.52), 0.008, 5)
	# Thin skirts. The lower edge sits at the wheel tops so the run stays visible.
	var nskirt := 5
	var z0 := -L * 0.36
	var z1 := L * 0.30
	var seg := (z1 - z0) / float(nskirt)
	for i in nskirt:
		h.color(RU if i % 2 == 0 else RU_D, Geo.PAINT)
		for s2 in [-1.0, 1.0]:
			var side2: float = s2
			h.box(Vector3(side2 * (sx + 0.05), 0.26, z0 + seg * (float(i) + 0.5)), Vector3(0.012, 0.08, seg - 0.02))
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		h.color(RU_D, Geo.PAINT)
		h.plate(Vector3(side3 * 0.12, 0.22, -L * 0.50), Vector3(0.22, 0.22, 0.012), Vector3(0, side3 * 6.0, 0))
	V4._lamps(h, 0.16, 0.16, L * 0.50)
	V4._antenna(h, Vector3(-0.12, 0.34, -0.15), 0.42)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.42, 0.24, 0.0), Vector3(0.008, 0.02, 0.28))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.34, -0.22))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.cbox(Vector3(0, 0.02, 0), Vector3(0.40, 0.04, 0.46), 0.008)
	t.dome(0.20, 0.11, 3, 12, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.15)), Vector3(0, 0.03, -0.02)))
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(-0.08, 0.15, -0.04), 0.05)
	t.hatch(Vector3(0.08, 0.15, -0.06), 0.045)
	t.color(RU_S, Geo.STEEL)
	for s4 in [-1.0, 1.0]:
		var side4: float = s4
		for i2 in 3:
			var zs: float = -0.04 + float(i2) * 0.04
			t.tube(Vector3(side4 * 0.18, 0.08, zs), Vector3(side4 * 0.24, 0.12, zs + 0.06), 0.008, 4)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.16))
	var b = K.new()
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0.012, 0, 0.02), Vector3(0.08, 0.06, 0.05), 0.005)
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0, 0, 0.02), Vector3(0, 0, 1.35), 0.020, 8, 0.014)
	b.tube(Vector3(0.036, 0.016, 0.04), Vector3(0.036, 0.016, 1.08), 0.012, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/bmp3.tscn", 0.95, [t, b])

static func t14(mat: Material) -> void:
	# Drawing millimetres at the live T-90 width scale (1.53 u / 3.78 m). Hull 8.879 m,
	# roof 2.132 m, top of the roof station 3.320 m, width 4.000 m, gun forward 10.889 m.
	var S := 1.53 / 3.78
	var root := VK._root({"selection_radius": 1.75, "bar_height": 1.72, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var wx: float = 1.56 * S
	var tw: float = 0.56 * S
	var wr: float = 0.35 * S
	var wy: float = 0.40 * S
	var spacing: float = 5.491 / 6.0
	for side_i in [-1.0, 1.0]:
		var sx: float = side_i * wx
		var front := Vector2(3.40 * S, 0.52 * S)
		var rear := Vector2(-3.62 * S, 0.50 * S)
		VK._track(h, sx - tw * 0.5, sx + tw * 0.5, rear, 0.40 * S, front, 0.34 * S, 0.98 * S)
		for i in 7:
			var zm: float = 2.50 - spacing * float(i)
			h.wheel(Vector3(sx, wy, zm * S), wr, tw * 0.92, false, "#6e736c", 14)
		h.sprocket(Vector3(sx, 0.50 * S, -3.62 * S), 0.32 * S, tw * 0.72, 9, RU_S)
		h.sprocket(Vector3(sx, 0.52 * S, 3.40 * S), 0.28 * S, tw * 0.66, 0, RU_S)
		h.color(RU_S, Geo.STEEL)
		for k in 3:
			var zr: float = lerpf(-1.6, 1.8, float(k) / 2.0)
			h.tube(Vector3(sx - tw * 0.28, 0.86 * S, zr * S), Vector3(sx + tw * 0.28, 0.86 * S, zr * S), 0.07 * S, 6)
	# Two-plane glacis: shallow upper plate from the nose back to the flat roof, steep lower plate down to the belly.
	h.color(RU, Geo.PAINT)
	h.xloft([
		[4.44 * S, K.sect(1.32 * S, 1.40 * S, 1.48 * S, 0.62 * S, 0.90 * S, 0.74 * S, 0.02 * S)],
		[4.02 * S, K.sect(0.50 * S, 1.15 * S, 1.62 * S, 1.02 * S, 1.52 * S, 0.98 * S, 0.03 * S)],
		[2.55 * S, K.sect(0.48 * S, 1.52 * S, 2.132 * S, 1.10 * S, 1.82 * S, 1.154 * S, 0.04 * S)],
		[-4.05 * S, K.sect(0.48 * S, 1.52 * S, 2.132 * S, 1.10 * S, 1.82 * S, 1.154 * S, 0.04 * S)],
		[-4.44 * S, K.sect(0.55 * S, 1.35 * S, 1.92 * S, 1.02 * S, 1.55 * S, 1.02 * S, 0.03 * S)],
	])
	for i in 3:
		h.color(RU_D, Geo.PAINT)
		h.hatch(Vector3((-0.50 + float(i) * 0.50) * S, 2.16 * S, 1.70 * S), 0.20 * S)
	# Skirts outside the track. The lower edge steps so the upper arc of each wheel stays the only part covered.
	var nskirt := 10
	var z0: float = -3.40 * S
	var z1: float = 3.20 * S
	var seg: float = (z1 - z0) / float(nskirt)
	var skirt_x: float = 1.975 * S
	for i2 in nskirt:
		var yb: float = 0.50 * S if i2 % 2 == 0 else 0.72 * S
		var yt: float = 1.55 * S
		h.color(RU if i2 % 2 == 0 else RU_D, Geo.PAINT)
		for s in [-1.0, 1.0]:
			var side: float = s
			h.box(Vector3(side * skirt_x, (yb + yt) * 0.5, z0 + seg * (float(i2) + 0.5)), Vector3(0.045 * S, yt - yb, seg * 1.02))
	# Rear bar cage proud of the stern, plus side fuel tanks and exhaust slots above the skirt.
	h.color(RU_S, Geo.STEEL)
	for i3 in 7:
		var xb: float = lerpf(-1.05, 1.05, float(i3) / 6.0)
		h.box(Vector3(xb * S, 1.25 * S, -4.62 * S), Vector3(0.04 * S, 0.85 * S, 0.04 * S))
	h.box(Vector3(0, 1.64 * S, -4.62 * S), Vector3(2.20 * S, 0.04 * S, 0.04 * S))
	h.box(Vector3(0, 0.86 * S, -4.62 * S), Vector3(2.20 * S, 0.04 * S, 0.04 * S))
	h.box(Vector3(0, 1.25 * S, -4.52 * S), Vector3(2.20 * S, 0.04 * S, 0.04 * S))
	for s2 in [-1.0, 1.0]:
		var side2: float = s2
		h.color(RU_D, Geo.PAINT)
		h.box(Vector3(side2 * 1.35 * S, 1.78 * S, -3.05 * S), Vector3(0.36 * S, 0.32 * S, 0.78 * S))
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(side2 * 1.20 * S, 1.72 * S, -3.70 * S), Vector3(0.22 * S, 0.10 * S, 0.36 * S))
	V4._lamps(h, 0.42 * S, 1.05 * S, 4.20 * S)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(skirt_x, 1.15 * S, -0.4 * S), Vector3(0.012 * S, 0.04 * S, 0.55 * S))
	var roof_y: float = 2.132 * S
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, roof_y, 0.15 * S))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	# Tall faceted block: narrow wedge nose, flat cheeks, roof shifted aft so the front face slopes.
	t.plan_loft([
		Vector2(-0.20 * S, 0.98 * S), Vector2(0.20 * S, 0.98 * S),
		Vector2(1.08 * S, 0.38 * S), Vector2(1.12 * S, -0.80 * S),
		Vector2(0.72 * S, -1.42 * S), Vector2(-0.72 * S, -1.42 * S),
		Vector2(-1.12 * S, -0.80 * S), Vector2(-1.08 * S, 0.38 * S)],
		0.0, 0.86 * S, Vector2(0.88, 0.82), Vector2(0.0, -0.48 * S))
	t.color(RU_D, Geo.PAINT)
	t.box(Vector3(-0.55 * S, 0.16 * S, 0.55 * S), Vector3(0.22 * S, 0.18 * S, 0.28 * S))
	t.box(Vector3(0.55 * S, 0.16 * S, 0.55 * S), Vector3(0.22 * S, 0.18 * S, 0.28 * S))
	t.box(Vector3(-0.85 * S, 0.28 * S, -1.15 * S), Vector3(0.22 * S, 0.20 * S, 0.28 * S))
	t.box(Vector3(0.85 * S, 0.28 * S, -1.15 * S), Vector3(0.22 * S, 0.20 * S, 0.28 * S))
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.55 * S, 0.18 * S, 0.70 * S), Vector3(0.16 * S, 0.10 * S, 0.015 * S))
	t.box(Vector3(0.55 * S, 0.18 * S, 0.70 * S), Vector3(0.16 * S, 0.10 * S, 0.015 * S))
	t.color(RU, Geo.PAINT)
	# Roof station. Its top is the 3.320 m overall height.
	t.cbox(Vector3(0.42 * S, 1.02 * S, -0.15 * S), Vector3(0.32 * S, 0.32 * S, 0.40 * S), 0.02 * S)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0.42 * S, 1.02 * S, 0.06 * S), Vector3(0.42 * S, 1.04 * S, 0.42 * S), 0.018 * S, 5)
	t.tube(Vector3(-0.25 * S, 0.88 * S, -1.05 * S), Vector3(-0.25 * S, 1.188 * S, -1.08 * S), 0.012 * S, 4)
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		for i4 in 5:
			var zt: float = 0.25 * S - float(i4) * 0.24 * S
			t.tube(Vector3(side3 * 0.95 * S, 0.08 * S, zt), Vector3(side3 * 1.28 * S, 0.18 * S, zt + 0.06 * S), 0.035 * S, 5)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.30 * S, 0.72 * S))
	var b = K.new()
	var blen: float = (6.4495 - 0.15 - 0.72) * S
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0, 0, 0), Vector3(0, 0, blen), 0.085 * S, 8, 0.062 * S)
	b.box(Vector3(0.055 * S, 0.02 * S, blen - 0.06 * S), Vector3(0.03 * S, 0.022 * S, 0.14 * S))
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/t14.tscn", 1.72, [t, b])

static func t14_super(mat: Material) -> void:
	# Original super-heavy for the T-14 slot. Same silhouette as the approved first pass.
	# The front idler sits inside the track loop. Cheek pods are visual only.
	var root := VK._root({"selection_radius": 1.3, "bar_height": 1.32, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	for side_i in [-1.0, 1.0]:
		var sx: float = side_i * 0.78
		VK._track(h, sx - 0.15, sx + 0.15, Vector2(-1.12, 0.16), 0.14, Vector2(1.02, 0.145), 0.105, 0.33)
		for i in 7:
			var zw: float = lerpf(-0.80, 0.74, float(i) / 6.0)
			h.wheel(Vector3(sx, 0.132, zw), 0.110, 0.26, false, "#6e736c", 10)
		h.sprocket(Vector3(sx, 0.16, -1.12), 0.12, 0.20, 8, RU_S)
		h.wheel(Vector3(sx, 0.145, 1.02), 0.086, 0.22, false, RU_S, 10)
		h.color(RU_S, Geo.STEEL)
		for k in 3:
			var zr: float = lerpf(-0.45, 0.50, float(k) / 2.0)
			h.tube(Vector3(sx - 0.08, 0.30, zr), Vector3(sx + 0.08, 0.30, zr), 0.028, 5)
	h.color(RU, Geo.PAINT)
	h.xloft([
		[1.38, K.sect(0.28, 0.36, 0.42, 0.40, 0.55, 0.46, 0.02)],
		[1.02, K.sect(0.16, 0.40, 0.58, 0.58, 0.92, 0.82, 0.03)],
		[-1.22, K.sect(0.16, 0.40, 0.58, 0.58, 0.92, 0.82, 0.03)],
		[-1.38, K.sect(0.20, 0.36, 0.50, 0.52, 0.84, 0.74, 0.03)],
	])
	h.color(RU, Geo.PAINT)
	h.hatch(Vector3(0.0, 0.60, 0.82), 0.11)
	h.color(RU_D, Geo.PAINT)
	h.vent(Vector3(-0.28, 0.605, -0.92), 0.42, 0.28, 5, 0.0)
	h.vent(Vector3(0.28, 0.605, -0.92), 0.42, 0.28, 5, 0.0)
	h.cbox(Vector3(0, 0.36, -1.39), Vector3(0.62, 0.20, 0.03), 0.008)
	h.rivets(Vector3(-0.22, 0.44, -1.40), Vector3(0.22, 0.44, -1.40), 4, Vector3(0, 0, -1), 0.008)
	var z0 := -1.02
	var z1 := 0.96
	var nskirt := 6
	var seg := (z1 - z0) / float(nskirt)
	for i2 in nskirt:
		h.color(RU if i2 % 2 == 0 else RU_D, Geo.PAINT)
		var zc: float = z0 + seg * (float(i2) + 0.5)
		for s in [-1.0, 1.0]:
			var side: float = s
			h.box(Vector3(side * 0.98, 0.38, zc), Vector3(0.04, 0.16, seg - 0.025))
			h.color(RU_S, Geo.STEEL)
			h.box(Vector3(side * 0.995, 0.44, zc - seg * 0.28), Vector3(0.012, 0.012, 0.012))
			h.box(Vector3(side * 0.995, 0.44, zc + seg * 0.28), Vector3(0.012, 0.012, 0.012))
			h.color(RU if i2 % 2 == 0 else RU_D, Geo.PAINT)
	h.color(RU_S, Geo.STEEL)
	for s2 in [-1.0, 1.0]:
		var side2: float = s2
		h.box(Vector3(side2 * 0.26, 0.22, 1.36), Vector3(0.045, 0.04, 0.05))
		h.tube(Vector3(side2 * 0.26, 0.20, 1.38), Vector3(side2 * 0.26, 0.15, 1.43), 0.012, 4)
		h.box(Vector3(side2 * 0.34, 0.28, -1.40), Vector3(0.04, 0.05, 0.045))
		h.tube(Vector3(side2 * 0.72, 0.50, 0.55), Vector3(side2 * 0.70, 0.46, -0.35), 0.012, 4)
		h.tube(Vector3(side2 * 0.70, 0.46, -0.35), Vector3(side2 * 0.68, 0.50, -1.15), 0.012, 4)
	h.color(RU_D, Geo.PAINT)
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		h.cyl(0.065, 0.065, 0.16, 8, Transform3D(Basis.IDENTITY, Vector3(side3 * 0.62, 0.50, -1.12)))
		h.jerrycan(Vector3(side3 * 0.78, 0.52, -0.95), 90.0 if side3 > 0.0 else -90.0)
	h.color("#2a2c2a", Geo.DARK)
	h.box(Vector3(0.52, 0.36, 0.92), Vector3(0.12, 0.035, 0.18))
	h.box(Vector3(0.52, 0.40, 0.92), Vector3(0.12, 0.035, 0.18))
	for s4 in [-1.0, 1.0]:
		var side4: float = s4
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(side4 * 0.34, 0.40, 1.30), Vector3(0.11, 0.08, 0.02))
		h.box(Vector3(side4 * 0.34, 0.445, 1.312), Vector3(0.10, 0.012, 0.012))
		h.box(Vector3(side4 * 0.34, 0.355, 1.312), Vector3(0.10, 0.012, 0.012))
		h.color("#ffe6b0", Geo.LAMP)
		h.box(Vector3(side4 * 0.34, 0.40, 1.316), Vector3(0.055, 0.038, 0.012))
		h.color("#c4483a", Geo.LAMP)
		h.box(Vector3(side4 * 0.48, 0.32, -1.395), Vector3(0.07, 0.035, 0.014))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.98, 0.40, -0.15), Vector3(0.012, 0.035, 0.42))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.58, -0.06))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.plan_loft([
		Vector2(-0.22, 0.58), Vector2(0.22, 0.58),
		Vector2(0.78, 0.22), Vector2(0.82, -0.38),
		Vector2(0.58, -0.64), Vector2(-0.58, -0.64),
		Vector2(-0.82, -0.38), Vector2(-0.78, 0.22)],
		0.0, 0.30, Vector2(0.90, 0.88))
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(-0.24, 0.315, -0.10), 0.12)
	t.hatch(Vector3(0.22, 0.315, 0.02), 0.10)
	t.cbox(Vector3(0.0, 0.14, -0.58), Vector3(0.78, 0.16, 0.20), 0.01)
	t.box(Vector3(0.30, 0.24, -0.52), Vector3(0.18, 0.08, 0.14))
	t.box(Vector3(-0.32, 0.18, 0.46), Vector3(0.12, 0.08, 0.10))
	t.box(Vector3(0.16, 0.22, 0.48), Vector3(0.08, 0.07, 0.08))
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.32, 0.18, 0.515), Vector3(0.08, 0.045, 0.012))
	t.box(Vector3(0.16, 0.22, 0.525), Vector3(0.045, 0.04, 0.012))
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(-0.30, 0.32, -0.22), Vector3(-0.30, 0.46, -0.22), 0.012, 5)
	t.dish(Vector3(-0.30, 0.46, -0.22), 0.075, 28.0, 0.35, "#8d9876")
	t.color(RU_S, Geo.STEEL)
	t.box(Vector3(0.42, 0.31, -0.36), Vector3(0.03, 0.02, 0.03))
	t.tube(Vector3(0.42, 0.32, -0.36), Vector3(0.42, 0.58, -0.37), 0.006, 3)
	t.tube(Vector3(0.42, 0.40, -0.36), Vector3(0.26, 0.32, -0.24), 0.005, 3)
	for s5 in [-1.0, 1.0]:
		var side5: float = s5
		t.color(RU_S, Geo.STEEL)
		for i3 in 4:
			var zs: float = 0.22 - float(i3) * 0.045
			t.tube(Vector3(side5 * 0.70, 0.10, zs), Vector3(side5 * 0.84, 0.18, zs + 0.10), 0.013, 4)
	var pitch := deg_to_rad(38.0)
	var fwd := Vector3(0, sin(pitch), cos(pitch))
	for s6 in [-1.0, 1.0]:
		var side6: float = s6
		var origin := Vector3(side6 * 0.98, 0.12, 0.0)
		t.color(RU_S, Geo.STEEL)
		t.box(Vector3(side6 * 0.86, 0.14, -0.02), Vector3(0.20, 0.045, 0.07))
		t.color(RU, Geo.PAINT)
		t.plate(origin, Vector3(0.30, 0.22, 0.58), Vector3(-38, 0, 0))
		t.color("#141615", Geo.DARK)
		t.plate(origin + fwd * 0.015, Vector3(0.20, 0.14, 0.48), Vector3(-38, 0, 0))
		for row in 2:
			for col in 2:
				var lx: float = (float(col) - 0.5) * 0.09
				var ly: float = (float(row) - 0.5) * 0.055
				var p := origin + Vector3(lx, ly * cos(pitch), ly * sin(pitch))
				t.color(RU_S, Geo.STEEL)
				t.tube(p + fwd * 0.02, p + fwd * 0.34, 0.020, 5)
				t.color(RU_D, Geo.PAINT)
				t.tube(p + fwd * 0.32, p + fwd * 0.40, 0.024, 5)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.12, 0.42))
	var b = K.new()
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0, 0.06), Vector3(0.58, 0.18, 0.18), 0.014)
	b.color(RU_S, Geo.STEEL)
	for s7 in [-1.0, 1.0]:
		var gx: float = s7 * 0.16
		b.tube(Vector3(gx, 0, 0.10), Vector3(gx, 0, 0.88), 0.040, 8, 0.034)
		b.tube(Vector3(gx, 0, 0.82), Vector3(gx, 0, 0.98), 0.052, 8)
		b.tube(Vector3(gx, 0, 0.94), Vector3(gx, 0, 1.56), 0.034, 8, 0.030)
		b.box(Vector3(gx, 0, 1.52), Vector3(0.10, 0.075, 0.09))
		b.color("#1c1d1c", Geo.DARK)
		b.box(Vector3(gx, 0.042, 1.52), Vector3(0.016, 0.030, 0.055))
		b.color(RU_S, Geo.STEEL)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/t14_super.tscn", 1.32, [t, b])

static func tos(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.05, "bar_height": 1.4, "recoil": 0.02, "wreck_s": 7.5, "elevate": 0.55})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 6.9 * S
	var sx := 0.48
	h.track_run(sx, L, 6, 0.088, 0.22, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[L * 0.50, K.sect(0.16, 0.24, 0.34, 0.22, 0.34, 0.26, 0.02)],
		[L * 0.28, K.sect(0.14, 0.26, 0.44, 0.40, 0.50, 0.44, 0.03)],
		[-L * 0.40, K.sect(0.14, 0.26, 0.44, 0.40, 0.50, 0.44, 0.03)],
		[-L * 0.50, K.sect(0.18, 0.28, 0.40, 0.36, 0.44, 0.36, 0.02)]])
	h.color(RU, Geo.PAINT)
	h.hatch(Vector3(-0.14, 0.48, L * 0.16), 0.07)
	h.hatch(Vector3(0.14, 0.48, L * 0.16), 0.07)
	_skirts(h, sx + 0.07, -L * 0.30, L * 0.26, 0.16, 0.38, false)
	V4._lamps(h, 0.22, 0.34, L * 0.48)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.52, 0.32, 0.0), Vector3(0.012, 0.03, 0.4))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.50, -0.02))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.03, -0.15), Vector3(0.42, 0.06, 0.28), 0.008)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.08, 0.05))
	var b = K.new()
	b.color(RU, Geo.PAINT)
	b.cbox(Vector3(0, 0.16, 0.15), Vector3(0.72, 0.40, 0.85), 0.016)
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0.38, 0.15), Vector3(0.76, 0.04, 0.90), 0.006)
	for row in 3:
		for col in 8:
			var x: float = -0.28 + float(col) * 0.08
			var y: float = 0.04 + float(row) * 0.11
			b.color(RU_S, Geo.STEEL)
			b.tube(Vector3(x, y, -0.22), Vector3(x, y, 0.62), 0.026, 6)
			b.color("#1a1c1a", Geo.DARK)
			b.tube(Vector3(x, y, 0.56), Vector3(x, y, 0.66), 0.014, 5)
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0.40, -0.02, -0.1), Vector3(0.40, 0.08, 0.35), 0.016, 5)
	b.tube(Vector3(-0.40, -0.02, -0.1), Vector3(-0.40, 0.08, 0.35), 0.016, 5)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/tos.tscn", 1.4, [t, b])

static func iskander(mat: Material) -> void:
	var sc := 0.24
	var root := VK._root({"selection_radius": 1.4, "bar_height": 1.55, "recoil": 0.0, "wreck_s": 8.0, "elevate": 0.85, "steer_max": 0.32})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 13.0 * sc
	UV8._tyres(h, 0.48, [L * 0.36, L * 0.24, -L * 0.10, -L * 0.28], 0.20, 0.15, 2, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.38, -0.05), Vector3(0.78, 0.14, L * 0.92), 0.015)
	h.color(RU, Geo.PAINT)
	var nose := L * 0.48
	h.xloft([[nose, K.sect(0.36, 0.44, 0.58, 0.18, 0.28, 0.22, 0.03)],
		[nose - 0.38, K.sect(0.34, 0.46, 0.82, 0.40, 0.46, 0.36, 0.03)],
		[nose - 0.72, K.sect(0.34, 0.46, 0.78, 0.40, 0.44, 0.34, 0.02)]])
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.72, nose - 0.10), Vector3(0.62, 0.20, 0.012), Vector3(-12, 0, 0))
	for s in [-1.0, 1.0]:
		var side: float = s
		h.box(Vector3(side * 0.38, 0.68, nose - 0.32), Vector3(0.012, 0.14, 0.22))
		h.color(RU_S, Geo.STEEL)
		h.tube(Vector3(side * 0.40, 0.78, nose - 0.16), Vector3(side * 0.56, 0.82, nose - 0.12), 0.01, 4)
		h.box(Vector3(side * 0.58, 0.82, nose - 0.10), Vector3(0.045, 0.07, 0.06))
		h.color(RU, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.50, nose - 0.02), 0.34, 0.10, 5)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.52, -0.15), Vector3(0.82, 0.10, L * 0.42), 0.01)
	V4._lamps(h, 0.24, 0.46, nose)
	V4._antenna(h, Vector3(-0.22, 0.95, nose - 0.5), 0.45)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.46, 0.48, 0.1), Vector3(0.01, 0.03, 0.5))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.55, -0.15))
	var t = K.new()
	t.color(RU_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.03, -0.4), Vector3(0.55, 0.07, 0.35), 0.008)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.06, 0.05))
	var b = K.new()
	for s2 in [-1.0, 1.0]:
		var side2: float = s2
		b.color(RU, Geo.PAINT)
		b.cbox(Vector3(side2 * 0.22, 0.14, 0.35), Vector3(0.20, 0.22, 1.45), 0.012)
		b.color(RU_D, Geo.PAINT)
		b.cbox(Vector3(side2 * 0.22, 0.14, 1.05), Vector3(0.18, 0.18, 0.16), 0.01)
		b.color(RU_L, Geo.PAINT)
		b.tube(Vector3(side2 * 0.22, 0.14, 1.12), Vector3(side2 * 0.22, 0.14, 1.22), 0.06, 8)
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(0.42, -0.04, 0.1), Vector3(0.42, 0.10, 0.7), 0.018, 5)
	b.tube(Vector3(-0.42, -0.04, 0.1), Vector3(-0.42, 0.10, 0.7), 0.018, 5)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/iskander.tscn", 1.55, [t, b])

static func pantsir(mat: Material) -> void:
	var sc := 0.24
	var root := VK._root({"selection_radius": 1.6, "bar_height": 2.45, "recoil": 0.05, "wreck_s": 8.0, "steer_max": 0.28})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 12.7 * sc
	# Two close pairs up front, a long gap, two close pairs at the back.
	UV8._tyres(h, 0.58, [1.15, 0.78, -0.55, -1.05], 0.26, 0.18, 2, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -0.05), Vector3(0.70, 0.16, L * 0.96), 0.012)
	# Separate forward cab, then a lower equipment box behind it.
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.72, 1.25), Vector3(0.70, 0.42, 0.62), 0.012)
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.52, 1.52), Vector3(0.68, 0.10, 0.12), 0.008)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.86, 1.52), Vector3(0.58, 0.24, 0.012), Vector3(-6, 0, 0))
	for s in [-1.0, 1.0]:
		var side: float = s
		h.box(Vector3(side * 0.37, 0.80, 1.18), Vector3(0.012, 0.18, 0.32))
		h.color(RU_S, Geo.STEEL)
		h.tube(Vector3(side * 0.38, 1.02, 1.28), Vector3(side * 0.58, 1.06, 1.32), 0.012, 4)
		h.box(Vector3(side * 0.62, 1.06, 1.34), Vector3(0.05, 0.08, 0.07))
		h.color(RU, Geo.PAINT)
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.52, 1.50), 0.42, 0.10, 5)
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.90, 0.18), Vector3(0.66, 0.58, 0.52), 0.01)
	for s2 in [-1.0, 1.0]:
		var side2: float = s2
		h.color(RU_D, Geo.PAINT)
		h.box(Vector3(side2 * 0.34, 0.86, 0.18), Vector3(0.02, 0.32, 0.24))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(side2 * 0.355, 0.84, 0.28), Vector3(0.012, 0.06, 0.03))
	h.ladder(Vector3(-0.46, 0.18, 0.02), 0.85, Vector3(0, 0, 1), 0.09)
	# Side rail and grille along the rear bed, under the turret.
	h.color(RU_S, Geo.STEEL)
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		h.box(Vector3(side3 * 0.48, 0.92, -0.45), Vector3(0.018, 0.018, 1.35))
		h.box(Vector3(side3 * 0.48, 0.62, -0.45), Vector3(0.014, 0.014, 1.35))
		for i in 8:
			h.box(Vector3(side3 * 0.48, 0.76, -1.05 + float(i) * 0.17), Vector3(0.012, 0.28, 0.012))
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.55, -1.38), Vector3(0.66, 0.22, 0.08), 0.008)
	# Pedestal the turret sits on, rear of the middle.
	h.color(RU, Geo.PAINT)
	h.cbox(Vector3(0, 0.78, -0.28), Vector3(0.42, 0.55, 0.48), 0.01)
	V4._lamps(h, 0.24, 0.55, 1.52)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.40, 0.70, 0.55), Vector3(0.01, 0.025, 0.28))
	var og := VK._n3(model, root, "Outriggers", Vector3.ZERO)
	var parts: Array = []
	for spec in [["LegFR", 1.0, 0.55], ["LegFL", -1.0, 0.55], ["LegRR", 1.0, -1.15], ["LegRL", -1.0, -1.15]]:
		var side4: float = spec[1]
		var leg := VK._n3(og, root, String(spec[0]), Vector3(side4 * 0.36, 0.48, float(spec[2])))
		var g = K.new()
		g.color(RU_S, Geo.STEEL)
		g.tube(Vector3.ZERO, Vector3(side4 * 0.10, -0.46, 0), 0.028, 6)
		g.cbox(Vector3(side4 * 0.14, -0.50, 0), Vector3(0.26, 0.05, 0.30), 0.006)
		VK._mi(leg, root, String(spec[0]) + "Mesh", g.commit(mat))
		parts.append(g)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 1.08, -0.28))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.cbox(Vector3(0, 0.10, 0.0), Vector3(0.38, 0.22, 0.36), 0.01)
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.16, 0.20), Vector3(0.16, 0.14, 0.06), 0.005)
	t.color(RU_S, Geo.STEEL)
	t.box(Vector3(0, 0.16, 0.24), Vector3(0.10, 0.08, 0.012))
	# Six tubes a side, beside and above the guns, noses up.
	for s5 in [-1.0, 1.0]:
		var side5: float = s5
		for row in 2:
			for col in 3:
				var x: float = side5 * (0.32 + float(col) * 0.07)
				var y0: float = 0.16 + float(row) * 0.09
				var y1: float = y0 + 0.22
				t.color(RU_L, Geo.PAINT)
				t.tube(Vector3(x, y0, -0.05), Vector3(x, y1, 0.62), 0.030, 6)
				t.color("#1a1c1a", Geo.DARK)
				t.tube(Vector3(x, y1 - 0.02, 0.56), Vector3(x, y1 + 0.02, 0.70), 0.016, 5)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var rad := VK._n3(piv, root, "Radar", Vector3(0, 0.24, -0.12))
	var rd = K.new()
	rd.color(RU_S, Geo.STEEL)
	rd.tube(Vector3(-0.08, 0, 0), Vector3(0.08, 0, 0), 0.024, 6)
	rd.tube(Vector3(0, 0, 0), Vector3(0, 0.22, 0), 0.022, 5)
	rd.tube(Vector3(0.12, -0.02, 0.02), Vector3(0.04, 0.55, 0), 0.014, 5)
	rd.color(RU, Geo.PAINT)
	rd.cbox(Vector3(0, 0.62, 0.02), Vector3(0.62, 0.58, 0.05), 0.008)
	rd.color(RU_D, Geo.PAINT)
	rd.box(Vector3(0, 0.62, 0.05), Vector3(0.46, 0.42, 0.012))
	VK._mi(rad, root, "RadarMesh", rd.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.02, 0.16))
	var b = K.new()
	b.color(RU_S, Geo.STEEL)
	for s6 in [-1.0, 1.0]:
		var side6: float = s6
		for k in 2:
			var y2: float = -0.02 + float(k) * 0.08
			b.tube(Vector3(side6 * 0.22, y2, 0.0), Vector3(side6 * 0.26, y2 + 0.06, 1.35), 0.030, 6)
			b.tube(Vector3(side6 * 0.25, y2 + 0.055, 1.22), Vector3(side6 * 0.26, y2 + 0.065, 1.42), 0.036, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	parts.append_array([t, b, rd])
	_save(root, model, h, mat, "res://view/units/ecc/pantsir.tscn", 2.45, parts)


static func mi8(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.35, "bar_height": 1.45, "recoil": 0.0, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(RU, Geo.PAINT)
	h.xloft([[1.20, K.sect(0.20, 0.30, 0.40, 0.10, 0.16, 0.12, 0.04)],
		[0.90, K.sect(0.16, 0.32, 0.58, 0.26, 0.34, 0.24, 0.05)],
		[0.25, K.sect(0.16, 0.32, 0.66, 0.34, 0.40, 0.28, 0.05)],
		[-0.55, K.sect(0.16, 0.32, 0.62, 0.32, 0.38, 0.26, 0.04)],
		[-0.85, K.sect(0.20, 0.32, 0.46, 0.16, 0.22, 0.14, 0.03)]])
	h.color(RU_L, Geo.PAINT)
	h.dome(0.32, 0.22, 4, 14, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.9, 1.15)), Vector3(0, 0.36, 1.05)))
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.62, 0.95), Vector3(0.28, 0.06, 0.22), 0.008)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.42, 1.22), Vector3(0.46, 0.20, 0.012), Vector3(-32, 0, 0))
	h.plate(Vector3(-0.22, 0.40, 1.12), Vector3(0.16, 0.14, 0.01), Vector3(-16, 38, 0))
	h.plate(Vector3(0.22, 0.40, 1.12), Vector3(0.16, 0.14, 0.01), Vector3(-16, -38, 0))
	h.plate(Vector3(0, 0.58, 1.08), Vector3(0.32, 0.08, 0.01), Vector3(-18, 0, 0))
	for s in [-1.0, 1.0]:
		var side: float = s
		for z in [0.45, 0.15, -0.15, -0.45]:
			var zz: float = z
			h.color(GLASS_C, Geo.GLASS)
			h.tube(Vector3(side * 0.34, 0.46, zz), Vector3(side * 0.40, 0.46, zz), 0.055, 8)
		h.color(RU_D, Geo.PAINT)
		h.tube(Vector3(side * 0.42, 0.30, 0.20), Vector3(side * 0.42, 0.30, -0.40), 0.055, 8)
		h.cbox(Vector3(side * 0.40, 0.16, 0.0), Vector3(0.08, 0.06, 0.32), 0.005)
		h.color(RU_S, Geo.STEEL)
		for i in 4:
			h.tube(Vector3(side * 0.40, 0.15, -0.08 + float(i) * 0.06), Vector3(side * 0.40, 0.15, 0.16), 0.010, 4)
	# Sliding door on the left, rail above it. Clamshell split at the cabin rear.
	h.color(RU_L, Geo.PAINT)
	h.box(Vector3(-0.40, 0.42, -0.15), Vector3(0.02, 0.32, 0.38))
	h.color(RU_S, Geo.STEEL)
	h.box(Vector3(-0.41, 0.60, -0.05), Vector3(0.015, 0.015, 0.7))
	h.color(RU, Geo.PAINT)
	h.plate(Vector3(-0.12, 0.40, -0.78), Vector3(0.22, 0.36, 0.016), Vector3(0, 8, 0))
	h.plate(Vector3(0.12, 0.40, -0.78), Vector3(0.22, 0.36, 0.016), Vector3(0, -8, 0))
	h.color("#1c1d1c", Geo.DARK)
	h.box(Vector3(0, 0.40, -0.80), Vector3(0.012, 0.32, 0.012))
	# Twin intakes and the cowl over the cabin.
	h.color(RU_D, Geo.PAINT)
	h.cbox(Vector3(-0.16, 0.74, 0.08), Vector3(0.16, 0.10, 0.38), 0.01)
	h.cbox(Vector3(0.16, 0.74, 0.08), Vector3(0.16, 0.10, 0.38), 0.01)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(-0.18, 0.78, 0.32), Vector3(-0.18, 0.78, 0.42), 0.07, 8)
	h.tube(Vector3(0.18, 0.78, 0.32), Vector3(0.18, 0.78, 0.42), 0.07, 8)
	h.color("#2a2c28", Geo.DARK)
	h.tube(Vector3(-0.18, 0.74, -0.22), Vector3(-0.32, 0.66, -0.32), 0.035, 6)
	h.tube(Vector3(0.18, 0.74, -0.22), Vector3(0.32, 0.66, -0.32), 0.035, 6)
	# Tail boom, fin, and the left-side tail rotor.
	h.color(RU, Geo.PAINT)
	h.tube(Vector3(0, 0.48, -0.9), Vector3(0, 0.58, -2.25), 0.055, 8, 0.03)
	h.color(RU_D, Geo.PAINT)
	h.plate(Vector3(0, 0.82, -2.15), Vector3(0.035, 0.42, 0.22), Vector3.ZERO)
	h.plate(Vector3(0.02, 0.62, -2.05), Vector3(0.28, 0.02, 0.10), Vector3.ZERO)
	h.color(RU_S, Geo.STEEL)
	# Fixed tricycle gear.
	h.tube(Vector3(0, 0.22, 1.00), Vector3(0, 0.08, 1.08), 0.014, 4)
	h.tyre(Vector3(0, 0.08, 1.12), 0.08, 0.045, true, RU_S, 8)
	for s2 in [-1.0, 1.0]:
		var side7: float = s2
		h.tube(Vector3(side7 * 0.16, 0.22, -0.05), Vector3(side7 * 0.32, 0.08, 0.02), 0.016, 4)
		h.tyre(Vector3(side7 * 0.36, 0.10, 0.04), 0.10, 0.05, false, RU_S, 8)
	V4._antenna(h, Vector3(0.15, 0.9, -0.4), 0.35)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.40, 0.40, 0.2), Vector3(0.012, 0.025, 0.3))
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 1.02, 0.05), 1.95, 5)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(-0.12, 0.82, -2.12), 0.38, 3, true)
	_save(root, model, h, mat, "res://view/units/ecc/mi8.tscn", 1.45, [])

static func shilka(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.45, "recoil": 0.04, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	var L := 6.5 * S
	var sx := 0.48
	h.track_run(sx, L, 6, 0.08, 0.20, RU_S)
	h.color(RU_D, Geo.PAINT)
	h.xloft([[L * 0.50, K.sect(0.16, 0.24, 0.34, 0.24, 0.36, 0.28, 0.02)],
		[L * 0.22, K.sect(0.14, 0.26, 0.42, 0.40, 0.50, 0.44, 0.025)],
		[-L * 0.42, K.sect(0.14, 0.26, 0.42, 0.40, 0.50, 0.44, 0.025)],
		[-L * 0.50, K.sect(0.16, 0.26, 0.36, 0.36, 0.42, 0.36, 0.02)]])
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.40, -L * 0.36), 0.55, 0.22, 6)
	h.color(RU, Geo.PAINT)
	h.hatch(Vector3(-0.18, 0.46, L * 0.22), 0.08)
	_skirts(h, sx + 0.06, -L * 0.28, L * 0.22, 0.16, 0.36, false)
	V4._lamps(h, 0.22, 0.32, L * 0.48)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.52, 0.30, 0.0), Vector3(0.012, 0.03, 0.4))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.46, 0.0))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.plan_loft([Vector2(-0.55, -0.42), Vector2(0.55, -0.42), Vector2(0.58, 0.22), Vector2(0.42, 0.40),
		Vector2(-0.42, 0.40), Vector2(-0.58, 0.22)], 0.0, 0.26, Vector2(0.92, 0.88))
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(-0.16, 0.28, -0.05), 0.08)
	# Dish on a short mast at the rear of the turret.
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.26, -0.32), Vector3(0, 0.48, -0.32), 0.028, 6)
	t.color(RU_L, Geo.PAINT)
	t.cyl(0.22, 0.16, 0.05, 12, Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 0.55, -0.36)))
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.55, -0.30), Vector3(0, 0.55, -0.16), 0.01, 4)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.12, 0.32))
	var b = K.new()
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0, 0, -0.02), Vector3(0.62, 0.16, 0.12), 0.01)
	b.color(RU_S, Geo.STEEL)
	for i in 4:
		var x: float = -0.22 + float(i) * 0.146
		var y: float = 0.03 if i % 2 == 0 else -0.03
		b.tube(Vector3(x, y, 0.02), Vector3(x, y, 0.72), 0.016, 6)
		b.tube(Vector3(x, y, 0.08), Vector3(x, y, 0.28), 0.024, 6)
		b.tube(Vector3(x, y, 0.66), Vector3(x, y, 0.76), 0.022, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/zeus.tscn", 1.45, [t, b])

static func _skirts(h, x: float, z0: float, z1: float, y0: float, y1: float, _notch: bool) -> void:
	var n := 4
	var seg := (z1 - z0) / float(n)
	for i in n:
		h.color(RU if i % 2 == 0 else RU_D, Geo.PAINT)
		for s in [-1.0, 1.0]:
			var side: float = s
			h.box(Vector3(side * x, (y0 + y1) * 0.5, z0 + seg * (float(i) + 0.5)), Vector3(0.025, y1 - y0, seg - 0.03))

static func _notched_skirts(h, x: float, z0: float, z1: float) -> void:
	var n := 6
	var seg := (z1 - z0) / float(n)
	for i in n:
		var notch: float = 0.06 if i % 2 == 0 else 0.0
		h.color(RU if i % 2 == 0 else RU_D, Geo.PAINT)
		for s in [-1.0, 1.0]:
			var side: float = s
			h.box(Vector3(side * x, 0.28 + notch * 0.5, z0 + seg * (float(i) + 0.5)), Vector3(0.028, 0.16 - notch, seg - 0.025))

static func _save(root, model, h, mat: Material, path: String, bar: float, parts: Array) -> void:
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	var tris: int = h.tris
	for g in parts:
		tris += g.tris
	print("  %s: %d tris" % [path.get_file(), tris])
	VK._save(root, path, bar)
