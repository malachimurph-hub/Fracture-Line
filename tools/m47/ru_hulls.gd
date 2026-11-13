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

## Track belt for one side. path is a closed loop of Vector2(z, y). x0 is the inner edge, x1 the outer.
static func _run_belt(h, x0: float, x1: float, path: Array, th: float = 0.08) -> void:
	h.color("#2c2b28", Geo.TRACK)
	var ctr := Vector3.ZERO
	for p in path:
		ctr += Vector3((x0 + x1) * 0.5, p.y, p.x)
	ctr /= float(path.size())
	var s := 0.0
	var n := path.size()
	for i in n:
		var a: Vector2 = path[i]
		var b: Vector2 = path[(i + 1) % n]
		var ln := a.distance_to(b)
		if ln < 0.001:
			continue
		var dir := Vector3(0, b.y - a.y, b.x - a.x) / ln
		var inward := Vector3(1, 0, 0).cross(dir)
		var mid := Vector3((x0 + x1) * 0.5, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5)
		if inward.dot(mid - ctr) < 0.0:
			inward = -inward
		var out := -inward
		var pa0 := Vector3(x0, a.y, a.x)
		var pa1 := Vector3(x1, a.y, a.x)
		var pb0 := Vector3(x0, b.y, b.x)
		var pb1 := Vector3(x1, b.y, b.x)
		var qa0 := pa0 + out * th
		var qa1 := pa1 + out * th
		var qb0 := pb0 + out * th
		var qb1 := pb1 + out * th
		var side := 1.0 if x1 > x0 else -1.0
		h.uv = Vector2(s, 0.0)
		VK._quad_uv(h, [qa0, qa1, qb1, qb0], [Vector2(s, 0), Vector2(s, 1), Vector2(s + ln, 1), Vector2(s + ln, 0)], out)
		VK._quad_uv(h, [pa1, qa1, qb1, pb1], [Vector2(s, 0), Vector2(s, 0.4), Vector2(s + ln, 0.4), Vector2(s + ln, 0)], Vector3(side, 0, 0))
		VK._quad_uv(h, [qa0, pa0, pb0, qb0], [Vector2(s, 0), Vector2(s, 0.4), Vector2(s + ln, 0.4), Vector2(s + ln, 0)], Vector3(-side, 0, 0))
		s += ln

static func bmp3(mat: Material) -> void:
	# Hull 7.14 x 3.23 m at the live T-90 width scale. The glacis is one flat plate
	# from a low nose up to the roof. The hull side starts at the top of the track.
	# Bow is +Z. The previous kit is bmp3_kit_prev.tscn.
	var Sc := 0.405
	var root := VK._root({"selection_radius": 1.5, "bar_height": 0.98, "recoil": 0.1, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# Roof, turret and bow plate stay at the earlier height. Wheels stay at that run's size and height.
	# The side walls are extended down to the wheel-centre line afterwards.
	var y_bot := 0.84
	var y_roof := 1.58
	var z_nose := 3.48
	var z_break := 1.72
	var wx := 1.22 * Sc
	var tw := 0.48 * Sc
	var wr := 0.38 * Sc
	var wy := 0.44 * Sc
	for side_i in [-1.0, 1.0]:
		var sx: float = side_i * wx
		var rear := Vector2(-2.15 * Sc, 0.48 * Sc)
		var front := Vector2(1.88 * Sc, 0.46 * Sc)
		VK._track(h, sx - tw * 0.5, sx + tw * 0.5, rear, 0.38 * Sc, front, 0.30 * Sc, 0.90 * Sc)
		for i in 6:
			var zm: float = lerpf(-1.55, 1.28, float(i) / 5.0)
			h.wheel(Vector3(sx, wy, zm * Sc), wr, tw * 0.78, false, "#6e736c", 12)
		h.sprocket(Vector3(sx, 0.48 * Sc, -2.15 * Sc), 0.32 * Sc, tw * 0.70, 10, RU_S)
		h.sprocket(Vector3(sx, 0.46 * Sc, 1.88 * Sc), 0.26 * Sc, tw * 0.62, 0, RU_S)
		h.wheel(Vector3(sx, 0.72 * Sc, 2.85 * Sc), 0.11 * Sc, tw * 0.55, false, "#6e736c", 10)
	# Flat bottom at the track top, flat roof. No undercut.
	h.color(RU, Geo.PAINT)
	var body := K.sect(y_bot * Sc, 1.18 * Sc, y_roof * Sc, 1.15 * Sc, 1.42 * Sc, 1.08 * Sc, 0.05 * Sc)
	h.xloft([
		[z_break * Sc, body],
		[-2.70 * Sc, body],
		[-3.15 * Sc, K.sect(y_bot * Sc, 1.14 * Sc, 1.48 * Sc, 1.08 * Sc, 1.30 * Sc, 1.00 * Sc, 0.04 * Sc)],
		[-3.48 * Sc, K.sect(y_bot * Sc, 1.10 * Sc, 1.40 * Sc, 0.96 * Sc, 1.15 * Sc, 0.90 * Sc, 0.035 * Sc)],
	])
	# One straight glacis: low nose, rising in a single plane to the roof. Trim vane on the nose.
	h.color(RU, Geo.PAINT)
	h.prism_x([Vector2(z_nose * Sc, y_bot * Sc), Vector2(z_break * Sc, y_roof * Sc), Vector2(z_break * Sc, y_bot * Sc)], -1.22 * Sc, 1.22 * Sc)
	var dz := z_nose - z_break
	var dy := y_roof - y_bot
	var glen := sqrt(dz * dz + dy * dy)
	var gang := rad_to_deg(atan2(dz, dy))
	var gmid := Vector3(0, (y_bot + y_roof) * 0.5 * Sc, (z_nose + z_break) * 0.5 * Sc)
	var gn := Vector3(0, dz / glen, dy / glen)
	h.color(RU_L, Geo.PAINT)
	var vane := gmid + (Vector3(0, y_bot * Sc, z_nose * Sc) - gmid) * 0.55 + gn * (0.03 * Sc)
	h.plate(vane, Vector3(2.15 * Sc, glen * Sc * 0.42, 0.035 * Sc), Vector3(-gang, 0, 0))
	h.color(RU_S, Geo.STEEL)
	h.box(vane + gn * (0.02 * Sc), Vector3(2.05 * Sc, 0.025 * Sc, 0.03 * Sc))
	h.rivets(Vector3(-0.9 * Sc, y_bot * Sc + 0.18 * Sc, z_nose * Sc - 0.35 * Sc), Vector3(0.9 * Sc, y_bot * Sc + 0.22 * Sc, z_nose * Sc - 0.55 * Sc), 6, gn, 0.012 * Sc)
	# Headlights in housings, sitting on the plate.
	for s2 in [-1.0, 1.0]:
		var side2: float = s2
		var lamp := vane + Vector3(side2 * 0.62 * Sc, 0.04 * Sc, -0.06 * Sc)
		h.color(RU_S, Geo.STEEL)
		h.plate(lamp, Vector3(0.28 * Sc, 0.16 * Sc, 0.05 * Sc), Vector3(-gang, 0, 0))
		h.color("#ffe6b0", Geo.LAMP)
		h.plate(lamp + gn * (0.02 * Sc), Vector3(0.16 * Sc, 0.09 * Sc, 0.02 * Sc), Vector3(-gang, 0, 0))
	# Side walls and rear plate extended down to the wheel-centre line. The bow's lower edge rises to the nose tip.
	var y_low := wy
	var y_high := y_bot * Sc + 0.03
	var z_rise := 1.35 * Sc
	var side_x := 0.58
	h.color(RU, Geo.PAINT)
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		h.box(Vector3(side3 * side_x, (y_low + y_high) * 0.5, (-3.48 * Sc + z_rise) * 0.5), Vector3(0.025, y_high - y_low, z_rise + 3.48 * Sc))
		h.prism_x([Vector2(z_rise, y_bot * Sc), Vector2(z_nose * Sc, y_bot * Sc), Vector2(z_rise, y_low)], side3 * (side_x - 0.02), side3 * (side_x + 0.02))
	h.color(RU, Geo.PAINT)
	h.box(Vector3(0, (y_low + y_high) * 0.5, -3.52 * Sc), Vector3(1.15 * Sc, y_high - y_low, 0.04 * Sc))
	# Hatches on the flat roof, periscopes in front of them.
	h.color(RU, Geo.PAINT)
	h.hatch(Vector3(0, 1.60 * Sc, 1.48 * Sc), 0.22 * Sc)
	h.hatch(Vector3(-0.46 * Sc, 1.60 * Sc, 1.22 * Sc), 0.18 * Sc)
	h.hatch(Vector3(0.46 * Sc, 1.60 * Sc, 1.22 * Sc), 0.18 * Sc)
	h.hatch(Vector3(-0.40 * Sc, 1.60 * Sc, -1.15 * Sc), 0.20 * Sc)
	h.hatch(Vector3(0.38 * Sc, 1.60 * Sc, -1.42 * Sc), 0.18 * Sc)
	h.color(GLASS_C, Geo.GLASS)
	for i3 in 3:
		h.box(Vector3(-0.16 * Sc + float(i3) * 0.16 * Sc, 1.66 * Sc, 1.62 * Sc), Vector3(0.06 * Sc, 0.04 * Sc, 0.045 * Sc))
	h.box(Vector3(-0.46 * Sc, 1.66 * Sc, 1.38 * Sc), Vector3(0.055 * Sc, 0.035 * Sc, 0.04 * Sc))
	h.box(Vector3(0.46 * Sc, 1.66 * Sc, 1.38 * Sc), Vector3(0.055 * Sc, 0.035 * Sc, 0.04 * Sc))
	# Engine grille on the rear deck. Two troop doors on the stern.
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 1.62 * Sc, -2.15 * Sc), 0.90 * Sc, 0.55 * Sc, 7)
	h.color(RU_D, Geo.PAINT)
	h.plate(Vector3(-0.32 * Sc, 1.12 * Sc, -3.52 * Sc), Vector3(0.55 * Sc, 0.42 * Sc, 0.04 * Sc), Vector3(0, 3, 0))
	h.plate(Vector3(0.32 * Sc, 1.12 * Sc, -3.52 * Sc), Vector3(0.55 * Sc, 0.42 * Sc, 0.04 * Sc), Vector3(0, -3, 0))
	h.color(RU_S, Geo.STEEL)
	h.box(Vector3(0, 1.12 * Sc, -3.56 * Sc), Vector3(0.02 * Sc, 0.38 * Sc, 0.018 * Sc))
	h.tube(Vector3(-0.32 * Sc, 1.12 * Sc, -3.58 * Sc), Vector3(-0.16 * Sc, 1.12 * Sc, -3.58 * Sc), 0.012 * Sc, 4)
	h.tube(Vector3(0.32 * Sc, 1.12 * Sc, -3.58 * Sc), Vector3(0.16 * Sc, 1.12 * Sc, -3.58 * Sc), 0.012 * Sc, 4)
	h.color("#c4483a", Geo.LAMP)
	h.box(Vector3(-0.52 * Sc, 1.22 * Sc, -3.54 * Sc), Vector3(0.08 * Sc, 0.045 * Sc, 0.018 * Sc))
	h.box(Vector3(0.52 * Sc, 1.22 * Sc, -3.54 * Sc), Vector3(0.08 * Sc, 0.045 * Sc, 0.018 * Sc))
	# Roof, sides and stern covered so the flat plates do not read as open planes.
	var ry := 1.60 * Sc
	h.color(RU_D, Geo.PAINT)
	h.box(Vector3(0, ry, 0.85 * Sc), Vector3(1.80 * Sc, 0.012 * Sc, 0.016 * Sc))
	h.box(Vector3(0, ry, -0.55 * Sc), Vector3(1.90 * Sc, 0.012 * Sc, 0.016 * Sc))
	h.box(Vector3(0, ry, -1.70 * Sc), Vector3(1.60 * Sc, 0.012 * Sc, 0.016 * Sc))
	h.box(Vector3(-0.48 * Sc, ry, -0.2 * Sc), Vector3(0.014 * Sc, 0.012 * Sc, 2.2 * Sc))
	h.box(Vector3(0.48 * Sc, ry, -0.2 * Sc), Vector3(0.014 * Sc, 0.012 * Sc, 2.2 * Sc))
	h.cbox(Vector3(-0.62 * Sc, 1.68 * Sc, 0.55 * Sc), Vector3(0.32 * Sc, 0.14 * Sc, 0.38 * Sc), 0.012 * Sc)
	h.cbox(Vector3(0.58 * Sc, 1.70 * Sc, -0.35 * Sc), Vector3(0.28 * Sc, 0.16 * Sc, 0.42 * Sc), 0.012 * Sc)
	h.cbox(Vector3(0.55 * Sc, 1.68 * Sc, -1.85 * Sc), Vector3(0.36 * Sc, 0.14 * Sc, 0.32 * Sc), 0.01 * Sc)
	h.cbox(Vector3(-0.58 * Sc, 1.67 * Sc, -1.95 * Sc), Vector3(0.30 * Sc, 0.12 * Sc, 0.40 * Sc), 0.01 * Sc)
	h.cbox(Vector3(0.15 * Sc, 1.69 * Sc, -2.45 * Sc), Vector3(0.42 * Sc, 0.12 * Sc, 0.28 * Sc), 0.01 * Sc)
	h.color("#7a735c", Geo.CANVAS)
	h.tube(Vector3(-0.15 * Sc, 1.68 * Sc, -0.85 * Sc), Vector3(0.40 * Sc, 1.68 * Sc, -0.85 * Sc), 0.06 * Sc, 6)
	h.tube(Vector3(-0.35 * Sc, 1.67 * Sc, -1.45 * Sc), Vector3(0.20 * Sc, 1.67 * Sc, -1.45 * Sc), 0.05 * Sc, 6)
	h.color(RU_S, Geo.STEEL)
	for i4 in 5:
		h.box(Vector3(-0.55 * Sc + float(i4) * 0.10 * Sc, 1.64 * Sc, -0.15 * Sc), Vector3(0.07 * Sc, 0.025 * Sc, 0.16 * Sc))
	h.tube(Vector3(-0.85 * Sc, 1.64 * Sc, 0.4 * Sc), Vector3(0.1 * Sc, 1.64 * Sc, 0.9 * Sc), 0.014 * Sc, 4)
	h.tube(Vector3(0.1 * Sc, 1.64 * Sc, 0.9 * Sc), Vector3(0.45 * Sc, 1.30 * Sc, 2.4 * Sc), 0.014 * Sc, 4)
	h.color("#6b5438", Geo.WOOD)
	h.box(Vector3(-1.18 * Sc, 1.25 * Sc, 0.7 * Sc), Vector3(0.03 * Sc, 0.04 * Sc, 0.55 * Sc))
	h.color(RU_S, Geo.STEEL)
	h.box(Vector3(-1.22 * Sc, 1.22 * Sc, 0.42 * Sc), Vector3(0.06 * Sc, 0.10 * Sc, 0.14 * Sc))
	h.color(RU_D, Geo.PAINT)
	h.jerrycan(Vector3(-0.85 * Sc, 1.68 * Sc, -2.15 * Sc), 20.0)
	h.jerrycan(Vector3(-0.72 * Sc, 1.68 * Sc, -2.20 * Sc), -15.0)
	h.jerrycan(Vector3(0.78 * Sc, 1.68 * Sc, -1.15 * Sc), 70.0)
	for s4 in [-1.0, 1.0]:
		var side4: float = s4
		var sx4 := side4 * 1.46 * Sc
		h.color(RU_D, Geo.PAINT)
		h.box(Vector3(sx4, 1.22 * Sc, -1.4 * Sc), Vector3(0.012 * Sc, 0.012 * Sc, 1.6 * Sc))
		h.box(Vector3(sx4, 1.05 * Sc, -0.2 * Sc), Vector3(0.012 * Sc, 0.012 * Sc, 2.4 * Sc))
		h.box(Vector3(sx4, 1.28 * Sc, 0.15 * Sc), Vector3(0.012 * Sc, 0.42 * Sc, 0.012 * Sc))
		h.box(Vector3(sx4, 1.28 * Sc, -1.15 * Sc), Vector3(0.012 * Sc, 0.42 * Sc, 0.012 * Sc))
		h.cbox(Vector3(side4 * 1.52 * Sc, 1.22 * Sc, 0.35 * Sc), Vector3(0.16 * Sc, 0.18 * Sc, 0.42 * Sc), 0.012 * Sc)
		h.cbox(Vector3(side4 * 1.50 * Sc, 1.18 * Sc, -0.85 * Sc), Vector3(0.14 * Sc, 0.16 * Sc, 0.36 * Sc), 0.01 * Sc)
		h.cbox(Vector3(side4 * 1.50 * Sc, 1.16 * Sc, -1.85 * Sc), Vector3(0.14 * Sc, 0.14 * Sc, 0.30 * Sc), 0.01 * Sc)
		h.color(RU_S, Geo.STEEL)
		h.tube(Vector3(side4 * 1.54 * Sc, 1.32 * Sc, 0.9 * Sc), Vector3(side4 * 1.52 * Sc, 1.10 * Sc, -1.5 * Sc), 0.014 * Sc, 4)
		for i5 in 4:
			h.box(Vector3(side4 * 1.52 * Sc, 1.38 * Sc, -0.2 * Sc + float(i5) * 0.16 * Sc), Vector3(0.04 * Sc, 0.10 * Sc, 0.12 * Sc))
		h.rivets(Vector3(sx4, 1.40 * Sc, -1.8 * Sc), Vector3(sx4, 1.40 * Sc, 1.2 * Sc), 6, Vector3(side4, 0, 0), 0.01 * Sc)
		h.box(Vector3(side4 * 0.28 * Sc, 0.98 * Sc, -3.56 * Sc), Vector3(0.07 * Sc, 0.07 * Sc, 0.035 * Sc))
	h.color("#6b5438", Geo.WOOD)
	h.box(Vector3(0.12 * Sc, 1.18 * Sc, -3.58 * Sc), Vector3(0.022 * Sc, 0.32 * Sc, 0.016 * Sc))
	h.color(RU_S, Geo.STEEL)
	h.box(Vector3(0.12 * Sc, 1.02 * Sc, -3.60 * Sc), Vector3(0.09 * Sc, 0.045 * Sc, 0.016 * Sc))
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(1.48 * Sc, 1.20 * Sc, -2.15 * Sc), Vector3(0.06 * Sc, 0.08 * Sc, 0.22 * Sc))
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(1.50 * Sc, 1.24 * Sc, -2.05 * Sc), Vector3(1.46 * Sc, 1.05 * Sc, -2.45 * Sc), 0.032 * Sc, 5)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(1.40 * Sc, 1.15 * Sc, -0.1 * Sc), Vector3(0.012 * Sc, 0.04 * Sc, 0.42 * Sc))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, y_roof * Sc, 0.28 * Sc))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	# Same height and station, wider so the twin guns have a real turret under them.
	t.plan_loft([
		Vector2(-0.22 * Sc, 0.78 * Sc), Vector2(0.22 * Sc, 0.78 * Sc),
		Vector2(1.02 * Sc, 0.34 * Sc), Vector2(1.06 * Sc, -0.30 * Sc),
		Vector2(0.72 * Sc, -0.72 * Sc), Vector2(-0.72 * Sc, -0.72 * Sc),
		Vector2(-1.06 * Sc, -0.30 * Sc), Vector2(-1.02 * Sc, 0.34 * Sc)],
		0.0, 0.50 * Sc, Vector2(0.84, 0.86))
	t.color(RU_D, Geo.PAINT)
	t.hatch(Vector3(-0.18 * Sc, 0.52 * Sc, -0.08 * Sc), 0.14 * Sc)
	t.hatch(Vector3(0.20 * Sc, 0.52 * Sc, 0.06 * Sc), 0.12 * Sc)
	t.color(GLASS_C, Geo.GLASS)
	for k2 in 3:
		var ang := deg_to_rad(-30.0 + float(k2) * 30.0)
		t.box(Vector3(-0.18 * Sc + cos(ang) * 0.15 * Sc, 0.56 * Sc, -0.08 * Sc + sin(ang) * 0.10 * Sc), Vector3(0.04 * Sc, 0.025 * Sc, 0.025 * Sc))
	t.box(Vector3(0.20 * Sc, 0.56 * Sc, 0.18 * Sc), Vector3(0.04 * Sc, 0.025 * Sc, 0.025 * Sc))
	t.color(RU_D, Geo.PAINT)
	t.cbox(Vector3(0.26 * Sc, 0.56 * Sc, 0.16 * Sc), Vector3(0.14 * Sc, 0.06 * Sc, 0.14 * Sc), 0.006 * Sc)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.26 * Sc, 0.58 * Sc, 0.24 * Sc), Vector3(0.08 * Sc, 0.035 * Sc, 0.012 * Sc))
	t.color(RU, Geo.PAINT)
	t.box(Vector3(0, 0.52 * Sc, 0.10 * Sc), Vector3(1.15 * Sc, 0.01 * Sc, 0.012 * Sc))
	t.box(Vector3(0, 0.52 * Sc, -0.32 * Sc), Vector3(0.85 * Sc, 0.01 * Sc, 0.012 * Sc))
	t.cbox(Vector3(0.42 * Sc, 0.58 * Sc, -0.28 * Sc), Vector3(0.22 * Sc, 0.08 * Sc, 0.18 * Sc), 0.008 * Sc)
	t.cbox(Vector3(-0.48 * Sc, 0.57 * Sc, 0.12 * Sc), Vector3(0.18 * Sc, 0.07 * Sc, 0.16 * Sc), 0.006 * Sc)
	t.color("#7a735c", Geo.CANVAS)
	t.tube(Vector3(-0.22 * Sc, 0.56 * Sc, -0.42 * Sc), Vector3(0.08 * Sc, 0.56 * Sc, -0.42 * Sc), 0.04 * Sc, 5)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(-0.28 * Sc, 0.52 * Sc, -0.55 * Sc), Vector3(-0.28 * Sc, 0.95 * Sc, -0.58 * Sc), 0.01 * Sc, 4)
	t.rivets(Vector3(-0.42 * Sc, 0.20 * Sc, 0.20 * Sc), Vector3(0.42 * Sc, 0.20 * Sc, 0.20 * Sc), 5, Vector3(0, 0, 1), 0.007 * Sc)
	var pitch := deg_to_rad(34.0)
	var fwd := Vector3(0, sin(pitch), cos(pitch))
	for s5 in [-1.0, 1.0]:
		var side5: float = s5
		for i5 in 3:
			var p := Vector3(side5 * 0.92 * Sc, 0.16 * Sc, 0.08 * Sc - float(i5) * 0.09 * Sc)
			t.color(RU_S, Geo.STEEL)
			t.tube(p, p + fwd * 0.20 * Sc, 0.02 * Sc, 5)
			t.color(RU_D, Geo.PAINT)
			t.tube(p + fwd * 0.16 * Sc, p + fwd * 0.24 * Sc, 0.026 * Sc, 5)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.18 * Sc, 0.52 * Sc))
	var b = K.new()
	b.color(RU_D, Geo.PAINT)
	b.cbox(Vector3(0.04 * Sc, 0, 0.04 * Sc), Vector3(0.42 * Sc, 0.22 * Sc, 0.16 * Sc), 0.012 * Sc)
	b.color(RU_S, Geo.STEEL)
	var g100 := 2.78 * Sc
	b.tube(Vector3(-0.06 * Sc, 0, 0.08 * Sc), Vector3(-0.06 * Sc, 0, g100), 0.036, 8, 0.030)
	b.tube(Vector3(-0.06 * Sc, 0, g100 * 0.55), Vector3(-0.06 * Sc, 0, g100 * 0.68), 0.046, 8)
	b.tube(Vector3(0.16 * Sc, 0.02 * Sc, 0.08 * Sc), Vector3(0.16 * Sc, 0.02 * Sc, g100 * 0.86), 0.018, 6, 0.015)
	b.tube(Vector3(0.16 * Sc, 0.02 * Sc, g100 * 0.80), Vector3(0.16 * Sc, 0.02 * Sc, g100 * 0.90), 0.026, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_save(root, model, h, mat, "res://view/units/ecc/bmp3.tscn", 1.12, [t, b])

## Stage 3. Same approved proportions as the Stage 2 blockout, plus the fittings the
## four-view shows. One m3 material; paint, steel, track and glass are vertex classes.
## Does not replace bmp3() or ecc_bmp3.
static func bmp3_v2(mat: Material) -> void:
	# 0.311 u/m is about 77% of the old 0.405, so the hull matches the live T-90's length.
	var Sc := 0.311
	var root := VK._root({"selection_radius": 1.15, "bar_height": 0.86, "recoil": 0.1, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.plain = true
	h.camo(RU, 2)
	var rear := -3.525 * Sc
	var brk := 2.08 * Sc
	var half := 1.625 * Sc
	# Hull wall is inboard of the tracks. Front view: roof about 2.04 m, the side
	# about 2.32 m at the fender step, tracks about 3.25 m. The side tapers in toward the roof.
	var y_wall := 1.18 * Sc
	var y_rear := 1.85 * Sc
	var y_deck := 2.00 * Sc
	var rise := (-3.525 + 2.30) * Sc
	var w_bot := 1.16 * Sc
	var w_mid := 1.08 * Sc
	var w_top := 1.02 * Sc
	var chm := 0.09 * Sc
	var hull_w := 1.00 * Sc
	h.xloft([
		[rear, K.sect(y_wall, (y_wall + y_rear) * 0.5, y_rear, w_bot * 0.90, w_mid * 0.92, w_top * 0.88, chm * 0.75)],
		[rear + 0.10 * Sc, K.sect(y_wall, (y_wall + y_rear) * 0.5, y_rear, w_bot, w_mid, w_top, chm)],
		[rise, K.sect(y_wall, (y_wall + y_deck) * 0.5, y_deck, w_bot, w_mid, w_top, chm)],
		[brk - 0.06 * Sc, K.sect(y_wall, (y_wall + y_deck) * 0.5, y_deck, w_bot, w_mid, w_top, chm)],
		[brk, K.sect(y_wall, (y_wall + y_deck) * 0.5, y_deck, w_bot * 0.96, w_mid * 0.96, w_top * 0.94, chm)],
	])
	h.prism_x([Vector2(rear, 0.42 * Sc), Vector2(brk, 0.42 * Sc), Vector2(brk, y_wall), Vector2(rear, y_wall)], -0.92 * Sc, 0.92 * Sc)
	# Bow stays on the traced profile. Width closes toward the nose so the corners are cut.
	var bow_z := [2.07, 2.625, 3.525]
	var bow_yt := [2.00, 1.849, 1.60]
	var bow_yb := [1.18, 0.50, 1.54]
	var bow_w := [1.12, 1.02, 0.84]
	var bow_secs: Array = []
	for bi in bow_z.size():
		var y0b: float = float(bow_yb[bi]) * Sc
		var y1b: float = float(bow_yt[bi]) * Sc
		var wbb: float = float(bow_w[bi]) * Sc
		var wtb: float = wbb * 0.90
		var chb: float = minf(0.06 * Sc, (y1b - y0b) * 0.25)
		bow_secs.append([float(bow_z[bi]) * Sc, K.sect(y0b, (y0b + y1b) * 0.5, y1b, wbb, (wbb + wtb) * 0.5, wtb, chb)])
	h.xloft(bow_secs)
	var n0 := Vector2(3.525, 1.60)
	var n1 := Vector2(2.72, 0.58)
	var vane_d := (n1 - n0).normalized()
	var vane_n := Vector2(vane_d.y, -vane_d.x)
	if vane_n.y > 0.0:
		vane_n = -vane_n
	var vane: Array = []
	for k in [0.06, 0.72]:
		var p: Vector2 = n0 + (n1 - n0) * k
		vane.append((p + vane_n * 0.01) * Sc)
		vane.append((p + vane_n * 0.045) * Sc)
	h.camo(RU_D, 2)
	h.prism_x([vane[0], vane[2], vane[3], vane[1]], -hull_w, hull_w)
	h.camo(RU, 2)
	# Fender over each track: crowned top, chamfered lip, thin skirt. The front angles down over the idler.
	var fen_prof := [
		Vector2(1.14, 1.08),
		Vector2(1.14, 1.18),
		Vector2(1.38, 1.24),
		Vector2(1.52, 1.16),
		Vector2(1.62, 1.02),
		Vector2(1.50, 0.98),
	]
	var fen_z := [-3.48, -3.28, 1.65, 2.15, 2.50, 2.90]
	var fen_dy := [0.12, 0.0, 0.0, 0.06, 0.26, 0.48]
	for s in [-1.0, 1.0]:
		var sd: float = s
		var secs: Array = []
		for fi in fen_z.size():
			var poly: Array = []
			for p in fen_prof:
				poly.append(Vector2(sd * p.x * Sc, (p.y - float(fen_dy[fi])) * Sc))
			secs.append([float(fen_z[fi]) * Sc, poly])
		h.camo(RU, 2)
		h.xloft(secs)
		h.camo(RU_D, 2)
		var x_a := sd * 1.50 * Sc
		var x_b := sd * 1.64 * Sc
		h.prism_x([
			Vector2(-3.30 * Sc, 0.55 * Sc),
			Vector2(2.10 * Sc, 0.55 * Sc),
			Vector2(2.10 * Sc, 1.02 * Sc),
			Vector2(-3.30 * Sc, 1.02 * Sc),
		], minf(x_a, x_b), maxf(x_a, x_b))
		# Headlight cluster and guard on the fender's front corner.
		var hx := sd * 1.36 * Sc
		var hz := 1.95 * Sc
		h.camo(RU_D, 2)
		h.cbox(Vector3(hx, 1.22 * Sc, hz), Vector3(0.36 * Sc, 0.22 * Sc, 0.22 * Sc), 0.016 * Sc)
		h.color("#e4dcc8", Geo.LAMP)
		h.box(Vector3(hx + sd * 0.06 * Sc, 1.22 * Sc, hz + 0.08 * Sc), Vector3(0.07 * Sc, 0.06 * Sc, 0.03 * Sc))
		h.box(Vector3(hx - sd * 0.06 * Sc, 1.22 * Sc, hz + 0.08 * Sc), Vector3(0.07 * Sc, 0.06 * Sc, 0.03 * Sc))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(hx, 1.30 * Sc, hz + 0.09 * Sc), Vector3(0.26 * Sc, 0.014 * Sc, 0.014 * Sc))
		h.box(Vector3(hx, 1.12 * Sc, hz + 0.09 * Sc), Vector3(0.26 * Sc, 0.014 * Sc, 0.014 * Sc))
		h.box(Vector3(hx + sd * 0.12 * Sc, 1.21 * Sc, hz + 0.09 * Sc), Vector3(0.014 * Sc, 0.18 * Sc, 0.014 * Sc))
		h.box(Vector3(hx - sd * 0.12 * Sc, 1.21 * Sc, hz + 0.09 * Sc), Vector3(0.014 * Sc, 0.18 * Sc, 0.014 * Sc))
	# Olive plate on the existing bow underside, facing down and forward.
	h.camo(RU, 2)
	var nudge := Vector3(0, -0.025 * Sc, 0.02 * Sc)
	var lip_a := Vector3(-hull_w, 1.52 * Sc, 3.42 * Sc) + nudge
	var lip_b := Vector3(hull_w, 1.52 * Sc, 3.42 * Sc) + nudge
	var lip_c := Vector3(hull_w, 0.54 * Sc, 2.68 * Sc) + nudge
	var lip_d := Vector3(-hull_w, 0.54 * Sc, 2.68 * Sc) + nudge
	h.pane([lip_a, lip_b, lip_c, lip_d], Vector3(0, -0.4, 1))
	h.box(Vector3(0, 0.56 * Sc, 2.25 * Sc), Vector3(hull_w * 2.0, 0.08 * Sc, 0.70 * Sc))
	# Running gear. The fender covers the upper run; the belt outer face is about 3.25 m.
	# The belt helper adds a tread slab past the outer edge and below the path, so the
	# path sits inside the 3.23 m width and the slab's underside lands on the ground.
	var x_out := half - 0.008
	var x_in := x_out - 0.40 * Sc
	var belt: Array = []
	# Flat bottom ends behind the idler, then a clean arc around it.
	var z_link := 2.20
	while z_link > -3.05:
		belt.append(Vector2(z_link, 0.08) * Sc)
		z_link -= 0.32
	belt.append(Vector2(-3.05, 0.08) * Sc)
	for i in 9:
		var a := deg_to_rad(270.0 - 180.0 * float(i) / 8.0)
		belt.append(Vector2(-3.125 + cos(a) * 0.32, 0.50 + sin(a) * 0.32) * Sc)
	var z_top := -2.30
	while z_top < 1.60:
		belt.append(Vector2(z_top, 1.05) * Sc)
		z_top += 0.32
	belt.append(Vector2(1.60, 1.05) * Sc)
	belt.append(Vector2(2.15, 0.96) * Sc)
	for i in 9:
		var a2 := deg_to_rad(75.0 - 185.0 * float(i) / 8.0)
		belt.append(Vector2(2.575 + cos(a2) * 0.30, 0.52 + sin(a2) * 0.30) * Sc)
	h.color("#4a4a4e", Geo.TRACK)
	_run_belt(h, x_in, x_out, belt, 0.08 * Sc / 0.405)
	_run_belt(h, -x_out, -x_in, belt, 0.08 * Sc / 0.405)
	var stations: Array = [1.00, 1.72, 2.48, 3.22, 4.40, 5.18]
	for stn in stations:
		var zc: float = (-3.525 + float(stn)) * Sc
		for s2 in [-1.0, 1.0]:
			var side2: float = s2
			var wc := Vector3(side2 * (x_out - 0.20 * Sc), 0.36 * Sc, zc)
			var wr := 0.355 * Sc
			h.uv = Vector2(wc.y, wc.z)
			h.uv2 = Vector2(wc.x, wr)
			h.color("#2a2c28", Geo.WHEEL_RUBBER)
			h.tube(wc - Vector3(0.15 * Sc, 0, 0), wc + Vector3(0.15 * Sc, 0, 0), wr, 8)
			h.color("#5c5e58", Geo.WHEEL_STEEL)
			h.tube(wc - Vector3(0.05 * Sc, 0, 0), wc + Vector3(0.05 * Sc, 0, 0), wr * 0.42, 6)
			var cap := wc + Vector3(side2 * 0.15 * Sc, 0, 0)
			h.tube(cap, cap + Vector3(side2 * 0.02 * Sc, 0, 0), wr * 0.34, 6)
	# Rear sprocket, smaller front idler, three return rollers under the top run.
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		var xc: float = side3 * (x_out - 0.20 * Sc)
		var sp := Vector3(xc, 0.50 * Sc, -3.125 * Sc)
		var idl := Vector3(xc, 0.52 * Sc, 2.575 * Sc)
		h.uv = Vector2(sp.y, sp.z)
		h.uv2 = Vector2(sp.x, 0.28 * Sc)
		h.color("#5a5a5e", Geo.WHEEL_STEEL)
		h.tube(sp - Vector3(0.12 * Sc, 0, 0), sp + Vector3(0.12 * Sc, 0, 0), 0.22 * Sc, 8)
		for tooth in 9:
			var ta := TAU * float(tooth) / 9.0
			h.box(Vector3.ZERO, Vector3(0.12 * Sc, 0.07 * Sc, 0.055 * Sc), Transform3D(Basis(Vector3.RIGHT, ta), sp + Vector3(0, sin(ta), cos(ta)) * 0.28 * Sc))
		h.uv = Vector2(idl.y, idl.z)
		h.uv2 = Vector2(idl.x, 0.22 * Sc)
		h.tube(idl - Vector3(0.11 * Sc, 0, 0), idl + Vector3(0.11 * Sc, 0, 0), 0.18 * Sc, 8)
		h.tube(idl - Vector3(0.04 * Sc, 0, 0), idl + Vector3(0.04 * Sc, 0, 0), 0.22 * Sc, 8)
		for rz in [-1.525, -0.125, 1.275]:
			var rc := Vector3(xc, 0.95 * Sc, float(rz) * Sc)
			h.uv = Vector2(rc.y, rc.z)
			h.uv2 = Vector2(rc.x, 0.10 * Sc)
			h.color("#4a4c48", Geo.WHEEL_RUBBER)
			h.tube(rc - Vector3(0.08 * Sc, 0, 0), rc + Vector3(0.08 * Sc, 0, 0), 0.10 * Sc, 6)
			h.color("#5a5a5e", Geo.WHEEL_STEEL)
			h.tube(rc - Vector3(0.03 * Sc, 0, 0), rc + Vector3(0.03 * Sc, 0, 0), 0.045 * Sc, 5)
	h.uv = Vector2.ZERO
	h.uv2 = Vector2.ZERO
	# Turret body centre 3.85 m from the rear plate. The 2 m box then shares the drawn rear face.
	var piv_z := -3.525 + 3.85 - 0.11
	var piv_y := 2.00
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, piv_y * Sc, piv_z * Sc))
	var t = K.new()
	t.plain = true
	t.camo(RU, 2)
	# Circular turret, roof still 2.42 m. A mantlet carries the guns forward of the ring.
	var tur_h := 2.42 - piv_y
	var yh := tur_h * Sc
	var ring: Array = []
	var rad := 0.88 * Sc
	var cz := 0.11 * Sc
	for i in 14:
		var ang := TAU * float(i) / 14.0
		ring.append(Vector2(cos(ang) * rad, sin(ang) * rad + cz))
	t.plan_loft(ring, 0.0, yh, Vector2(0.94, 0.94))
	# Commander panoramic sight on a mount, gunner's block, cheek armor and a rear box.
	# Sizes are in the same range as the T-90's sight housings.
	t.camo(RU_D, 2)
	t.cbox(Vector3(0.30 * Sc, (tur_h + 0.05) * Sc, -0.16 * Sc), Vector3(0.18 * Sc, 0.08 * Sc, 0.20 * Sc), 0.012 * Sc)
	t.camo(RU, 2)
	t.cbox(Vector3(0.30 * Sc, (tur_h + 0.18) * Sc, -0.16 * Sc), Vector3(0.26 * Sc, 0.18 * Sc, 0.24 * Sc), 0.016 * Sc)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.30 * Sc, (tur_h + 0.20) * Sc, -0.02 * Sc), Vector3(0.14 * Sc, 0.08 * Sc, 0.02 * Sc))
	t.camo(RU_D, 2)
	t.cbox(Vector3(-0.26 * Sc, (tur_h + 0.04) * Sc, 0.12 * Sc), Vector3(0.16 * Sc, 0.06 * Sc, 0.18 * Sc), 0.01 * Sc)
	t.camo(RU, 2)
	t.cbox(Vector3(-0.26 * Sc, (tur_h + 0.14) * Sc, 0.12 * Sc), Vector3(0.24 * Sc, 0.16 * Sc, 0.24 * Sc), 0.014 * Sc)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.26 * Sc, (tur_h + 0.16) * Sc, 0.25 * Sc), Vector3(0.14 * Sc, 0.07 * Sc, 0.02 * Sc))
	t.camo(RU_D, 2)
	for s_ck in [-1.0, 1.0]:
		t.cbox(Vector3(float(s_ck) * 0.46 * Sc, 0.12 * Sc, -0.28 * Sc), Vector3(0.24 * Sc, 0.16 * Sc, 0.26 * Sc), 0.012 * Sc)
	t.cbox(Vector3(0, 0.14 * Sc, -0.58 * Sc), Vector3(0.50 * Sc, 0.16 * Sc, 0.18 * Sc), 0.012 * Sc)
	for s_sm in [-1.0, 1.0]:
		var sms: float = s_sm
		t.camo(RU, 2)
		t.cbox(Vector3(sms * 0.56 * Sc, 0.16 * Sc, 0.10 * Sc), Vector3(0.12 * Sc, 0.20 * Sc, 0.42 * Sc), 0.012 * Sc)
		t.color(RU_S, Geo.STEEL)
		for si in 6:
			var row := float(si % 2)
			var col := float(si / 2)
			var p0 := Vector3(sms * 0.64 * Sc, (0.10 + row * 0.10) * Sc, (0.24 - col * 0.14) * Sc)
			var p1 := p0 + Vector3(sms * 0.14 * Sc, 0.05 * Sc, 0.08 * Sc)
			t.tube(p0, p1, 0.05 * Sc, 6)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0.18 * Sc, yh, -0.36 * Sc), Vector3(0.18 * Sc, yh + 0.045 * Sc, -0.36 * Sc), 0.18 * Sc, 8)
	t.camo(RU, 2)
	t.cbox(Vector3(0.18 * Sc, yh + 0.07 * Sc, -0.36 * Sc), Vector3(0.28 * Sc, 0.05 * Sc, 0.28 * Sc), 0.01 * Sc)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(-0.16 * Sc, yh, 0.04 * Sc), Vector3(-0.16 * Sc, yh + 0.04 * Sc, 0.04 * Sc), 0.16 * Sc, 8)
	t.camo(RU, 2)
	t.cbox(Vector3(-0.16 * Sc, yh + 0.065 * Sc, 0.04 * Sc), Vector3(0.24 * Sc, 0.045 * Sc, 0.24 * Sc), 0.008 * Sc)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0.08 * Sc, yh, -0.50 * Sc), Vector3(0.08 * Sc, yh + 0.32 * Sc, -0.50 * Sc), 0.015 * Sc, 4)
	VK._mi(piv, root, "Turret", t.commit(mat))
	# Barrel axis at 2.15 m. 100 mm reaches the drawing's visible muzzle, 7.15 m from the rear plate.
	var gun_y := 2.15 - piv_y
	var muzzle_z := (-3.525 + 7.15) - (piv_z + 1.11)
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, gun_y * Sc, 1.11 * Sc))
	var b = K.new()
	b.plain = true
	b.color(RU_S, Geo.STEEL)
	# Mantlet across both barrels. Tube lengths still end at the approved muzzles.
	b.cbox(Vector3(0.03 * Sc, 0.0, 0.02 * Sc), Vector3(0.52 * Sc, 0.26 * Sc, 0.20 * Sc), 0.016 * Sc)
	b.cbox(Vector3(-0.22 * Sc, 0.0, 0.0), Vector3(0.10 * Sc, 0.16 * Sc, 0.12 * Sc), 0.01 * Sc)
	b.cbox(Vector3(0.26 * Sc, 0.0, 0.0), Vector3(0.10 * Sc, 0.14 * Sc, 0.12 * Sc), 0.01 * Sc)
	b.tube(Vector3(-0.12 * Sc, 0, 0.06 * Sc), Vector3(-0.12 * Sc, 0, muzzle_z * Sc), 0.055 * Sc, 8)
	var zf := muzzle_z * 0.38
	b.camo(RU_D, 2)
	b.tube(Vector3(-0.12 * Sc, 0, (zf - 0.08) * Sc), Vector3(-0.12 * Sc, 0, (zf + 0.08) * Sc), 0.080 * Sc, 8)
	b.color(RU_S, Geo.STEEL)
	b.tube(Vector3(-0.12 * Sc, 0, muzzle_z * Sc - 0.06 * Sc), Vector3(-0.12 * Sc, 0, muzzle_z * Sc), 0.070 * Sc, 8)
	b.tube(Vector3(0.18 * Sc, 0, 0.06 * Sc), Vector3(0.18 * Sc, 0, (muzzle_z - 0.22) * Sc), 0.030 * Sc, 6)
	b.tube(Vector3(0.18 * Sc, 0, (muzzle_z - 0.22) * Sc - 0.04 * Sc), Vector3(0.18 * Sc, 0, (muzzle_z - 0.22) * Sc), 0.040 * Sc, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	var m100 := Marker3D.new()
	m100.name = "GunMuzzle100"
	m100.position = Vector3(-0.12 * Sc, 0, muzzle_z * Sc)
	bn.add_child(m100)
	m100.owner = root
	var m30 := Marker3D.new()
	m30.name = "GunMuzzle30"
	m30.position = Vector3(0.18 * Sc, 0, (muzzle_z - 0.22) * Sc)
	bn.add_child(m30)
	m30.owner = root
	_bmp3_v2_fittings(h, Sc)
	print("  bmp3_v2 m: roof %.3f-2.00 edge 0.36 pivot z %.3f y %.3f gun y 2.15 muzzle from rear 7.15" % [1.85, piv_z, piv_y])
	_save(root, model, h, mat, "res://view/units/ecc/bmp3_v2.tscn", 0.86, [t, b])

## Hatches, rear plate, lights and the stowage drawn on the hull. Sits on the approved surfaces.
static func _bmp3_v2_fittings(h, Sc: float) -> void:
	h.uv = Vector2.ZERO
	h.uv2 = Vector2.ZERO
	# Driver hatch and the two troop hatches, proud of the glacis, with periscope blocks.
	h.color(RU_S, Geo.STEEL)
	h.cbox(Vector3(0, 2.04 * Sc, 1.72 * Sc), Vector3(0.62 * Sc, 0.05 * Sc, 0.50 * Sc), 0.012 * Sc)
	h.camo(RU, 2)
	h.cbox(Vector3(0, 2.09 * Sc, 1.72 * Sc), Vector3(0.48 * Sc, 0.08 * Sc, 0.38 * Sc), 0.014 * Sc)
	for hs in [-1.0, 1.0]:
		var hx: float = hs
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(hx * 0.46 * Sc, 2.035 * Sc, 1.48 * Sc), Vector3(0.42 * Sc, 0.05 * Sc, 0.38 * Sc), 0.01 * Sc)
		h.camo(RU, 2)
		h.cbox(Vector3(hx * 0.46 * Sc, 2.08 * Sc, 1.48 * Sc), Vector3(0.32 * Sc, 0.07 * Sc, 0.28 * Sc), 0.012 * Sc)
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(hx * 0.46 * Sc, 2.14 * Sc, 1.60 * Sc), Vector3(0.10 * Sc, 0.08 * Sc, 0.12 * Sc), 0.008 * Sc)
		h.color(GLASS_C, Geo.GLASS)
		h.box(Vector3(hx * 0.46 * Sc, 2.15 * Sc, 1.67 * Sc), Vector3(0.06 * Sc, 0.04 * Sc, 0.015 * Sc))
	h.color(RU_S, Geo.STEEL)
	for pi in [-0.32, 0.0, 0.32]:
		var px: float = pi
		h.cbox(Vector3(px * Sc, 2.08 * Sc, 2.05 * Sc), Vector3(0.12 * Sc, 0.10 * Sc, 0.16 * Sc), 0.01 * Sc)
		h.color(GLASS_C, Geo.GLASS)
		h.box(Vector3(px * Sc, 2.10 * Sc, 2.13 * Sc), Vector3(0.07 * Sc, 0.045 * Sc, 0.02 * Sc))
		h.color(RU_S, Geo.STEEL)
	# Hinge bar across the trim vane, and two lifting eyes on the glacis.
	h.box(Vector3(0, 1.58 * Sc, 3.28 * Sc), Vector3(1.70 * Sc, 0.04 * Sc, 0.05 * Sc))
	for lx in [-0.70, 0.70]:
		h.cbox(Vector3(float(lx) * Sc, 1.86 * Sc, 2.35 * Sc), Vector3(0.10 * Sc, 0.08 * Sc, 0.10 * Sc), 0.01 * Sc)
	# Rear deck panels on the rising roof.
	h.box(Vector3(-0.35 * Sc, 1.92 * Sc, -2.55 * Sc), Vector3(0.70 * Sc, 0.04 * Sc, 0.55 * Sc))
	h.box(Vector3(0.40 * Sc, 1.90 * Sc, -2.70 * Sc), Vector3(0.55 * Sc, 0.035 * Sc, 0.40 * Sc))
	h.color(RU_S, Geo.STEEL)
	for tie in 6:
		h.box(Vector3(-0.85 * Sc, 1.93 * Sc, (-3.15 + float(tie) * 0.28) * Sc), Vector3(0.06 * Sc, 0.04 * Sc, 0.08 * Sc))
		h.box(Vector3(0.85 * Sc, 1.93 * Sc, (-3.15 + float(tie) * 0.28) * Sc), Vector3(0.06 * Sc, 0.04 * Sc, 0.08 * Sc))
	h.camo(RU_D, 2)
	# Grille is a row of slats on the port rear face, not a dark slab.
	h.color(RU_S, Geo.STEEL)
	for gi in 6:
		h.box(Vector3(-0.48 * Sc, (1.22 + float(gi) * 0.07) * Sc, -3.545 * Sc), Vector3(0.46 * Sc, 0.018 * Sc, 0.025 * Sc))
	# Two rear doors: a proud frame and a recessed panel.
	for ds in [-0.28, 0.32]:
		var dx: float = ds
		h.camo(RU, 2)
		h.box(Vector3(dx * Sc, 0.78 * Sc, -3.55 * Sc), Vector3(0.34 * Sc, 0.46 * Sc, 0.03 * Sc))
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(dx * Sc, 1.02 * Sc, -3.56 * Sc), Vector3(0.42 * Sc, 0.04 * Sc, 0.025 * Sc))
		h.box(Vector3(dx * Sc, 0.54 * Sc, -3.56 * Sc), Vector3(0.42 * Sc, 0.04 * Sc, 0.025 * Sc))
		h.box(Vector3((dx - 0.18) * Sc, 0.78 * Sc, -3.56 * Sc), Vector3(0.04 * Sc, 0.48 * Sc, 0.025 * Sc))
		h.box(Vector3((dx + 0.18) * Sc, 0.78 * Sc, -3.56 * Sc), Vector3(0.04 * Sc, 0.48 * Sc, 0.025 * Sc))
		h.box(Vector3((dx + 0.12) * Sc, 0.84 * Sc, -3.575 * Sc), Vector3(0.03 * Sc, 0.08 * Sc, 0.02 * Sc))
	# Hydrojet outlets, low on the rear.
	h.color(RU_S, Geo.STEEL)
	for js in [-0.95, 0.95]:
		var jx: float = js
		h.tube(Vector3(jx * Sc, 0.50 * Sc, -3.50 * Sc), Vector3(jx * Sc, 0.50 * Sc, -3.57 * Sc), 0.07 * Sc, 6)
	# Tow hooks on the lower bow, with a short lip so they read as hooks.
	h.color(RU_S, Geo.STEEL)
	for hk in [-0.55, 0.55]:
		var kx: float = hk
		h.cbox(Vector3(kx * Sc, 0.70 * Sc, 2.95 * Sc), Vector3(0.12 * Sc, 0.07 * Sc, 0.16 * Sc), 0.01 * Sc)
		h.box(Vector3(kx * Sc, 0.64 * Sc, 3.04 * Sc), Vector3(0.08 * Sc, 0.06 * Sc, 0.05 * Sc))
	for gx in [-0.42, 0.42]:
		var gxx: float = gx
		h.cbox(Vector3(gxx * Sc, 1.96 * Sc, 2.48 * Sc), Vector3(0.22 * Sc, 0.045 * Sc, 0.045 * Sc), 0.008 * Sc)
		h.box(Vector3(gxx * Sc, 1.90 * Sc, 2.48 * Sc), Vector3(0.04 * Sc, 0.10 * Sc, 0.04 * Sc))
	# Side rail, tow cable, vision blocks, fender steps and tool boxes.
	for s in [-1.0, 1.0]:
		var sd: float = s
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(sd * 1.20 * Sc, 1.48 * Sc, -0.40 * Sc), Vector3(0.06 * Sc, 0.06 * Sc, 3.4 * Sc), 0.012 * Sc)
		h.color("#2a2c28", Geo.DARK)
		h.tube(Vector3(sd * 1.18 * Sc, 1.34 * Sc, -2.20 * Sc), Vector3(sd * 1.18 * Sc, 1.34 * Sc, 1.20 * Sc), 0.032 * Sc, 6)
		h.color(RU_S, Geo.STEEL)
		for cz in [-1.9, -0.6, 0.7]:
			h.cbox(Vector3(sd * 1.16 * Sc, 1.34 * Sc, float(cz) * Sc), Vector3(0.08 * Sc, 0.08 * Sc, 0.10 * Sc), 0.01 * Sc)
		for fz in [-2.4, -1.5, -0.5, 0.6]:
			h.cbox(Vector3(sd * 1.42 * Sc, 1.30 * Sc, float(fz) * Sc), Vector3(0.16 * Sc, 0.045 * Sc, 0.32 * Sc), 0.008 * Sc)
		h.camo(RU_D, 2)
		h.cbox(Vector3(sd * 1.36 * Sc, 1.32 * Sc, -2.15 * Sc), Vector3(0.28 * Sc, 0.14 * Sc, 0.42 * Sc), 0.014 * Sc)
		h.cbox(Vector3(sd * 1.34 * Sc, 1.30 * Sc, -1.55 * Sc), Vector3(0.24 * Sc, 0.12 * Sc, 0.32 * Sc), 0.012 * Sc)
		h.color(RU_S, Geo.STEEL)
		for vz in [-0.9, 0.1, 1.0]:
			h.cbox(Vector3(sd * 1.16 * Sc, 1.62 * Sc, float(vz) * Sc), Vector3(0.05 * Sc, 0.08 * Sc, 0.14 * Sc), 0.006 * Sc)
			h.color(GLASS_C, Geo.GLASS)
			h.box(Vector3(sd * 1.19 * Sc, 1.62 * Sc, float(vz) * Sc), Vector3(0.015 * Sc, 0.045 * Sc, 0.08 * Sc))
			h.color(RU_S, Geo.STEEL)
	# Unditching log on the starboard upper side, in three heavy brackets.
	h.color("#7a4e2a", Geo.WOOD)
	h.tube(Vector3(1.24 * Sc, 1.60 * Sc, -0.45 * Sc), Vector3(1.24 * Sc, 1.60 * Sc, 1.45 * Sc), 0.11 * Sc, 8)
	h.color(RU_S, Geo.STEEL)
	for bz in [-0.25, 0.50, 1.25]:
		var zz: float = bz
		h.cbox(Vector3(1.14 * Sc, 1.52 * Sc, zz * Sc), Vector3(0.10 * Sc, 0.14 * Sc, 0.12 * Sc), 0.012 * Sc)
		h.cbox(Vector3(1.30 * Sc, 1.72 * Sc, zz * Sc), Vector3(0.08 * Sc, 0.05 * Sc, 0.14 * Sc), 0.008 * Sc)
	# Raised rear-deck hatches, a grille block, antenna bases and a rail.
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(0.40 * Sc, 1.94 * Sc, -2.35 * Sc), Vector3(0.40 * Sc, 2.00 * Sc, -2.35 * Sc), 0.22 * Sc, 8)
	h.camo(RU, 2)
	h.cbox(Vector3(0.40 * Sc, 2.03 * Sc, -2.35 * Sc), Vector3(0.32 * Sc, 0.06 * Sc, 0.32 * Sc), 0.01 * Sc)
	h.color(RU_S, Geo.STEEL)
	h.tube(Vector3(-0.36 * Sc, 1.90 * Sc, -2.90 * Sc), Vector3(-0.36 * Sc, 1.96 * Sc, -2.90 * Sc), 0.18 * Sc, 8)
	h.camo(RU, 2)
	h.cbox(Vector3(-0.36 * Sc, 1.99 * Sc, -2.90 * Sc), Vector3(0.26 * Sc, 0.05 * Sc, 0.26 * Sc), 0.008 * Sc)
	h.color("#2a2c28", Geo.DARK)
	h.cbox(Vector3(-0.28 * Sc, 1.94 * Sc, -3.05 * Sc), Vector3(0.55 * Sc, 0.06 * Sc, 0.48 * Sc), 0.01 * Sc)
	h.color(RU_S, Geo.STEEL)
	for gi in 6:
		h.box(Vector3(-0.28 * Sc, 1.98 * Sc, (-3.24 + float(gi) * 0.08) * Sc), Vector3(0.48 * Sc, 0.025 * Sc, 0.03 * Sc))
	h.cbox(Vector3(0.62 * Sc, 1.98 * Sc, -2.55 * Sc), Vector3(0.12 * Sc, 0.08 * Sc, 0.12 * Sc), 0.01 * Sc)
	h.tube(Vector3(0.62 * Sc, 2.02 * Sc, -2.55 * Sc), Vector3(0.62 * Sc, 3.65 * Sc, -2.55 * Sc), 0.016 * Sc, 4)
	h.cbox(Vector3(-0.55 * Sc, 2.04 * Sc, -1.70 * Sc), Vector3(0.12 * Sc, 0.08 * Sc, 0.12 * Sc), 0.01 * Sc)
	h.tube(Vector3(-0.55 * Sc, 2.08 * Sc, -1.70 * Sc), Vector3(-0.55 * Sc, 3.40 * Sc, -1.70 * Sc), 0.016 * Sc, 4)
	h.tube(Vector3(0.78 * Sc, 2.12 * Sc, -2.70 * Sc), Vector3(0.78 * Sc, 2.12 * Sc, -1.55 * Sc), 0.022 * Sc, 5)
	h.tube(Vector3(0.78 * Sc, 1.98 * Sc, -2.70 * Sc), Vector3(0.78 * Sc, 2.12 * Sc, -2.70 * Sc), 0.02 * Sc, 5)
	h.tube(Vector3(0.78 * Sc, 2.02 * Sc, -1.55 * Sc), Vector3(0.78 * Sc, 2.12 * Sc, -1.55 * Sc), 0.02 * Sc, 5)
	# Door hinges and a rear light on each upper corner.
	for ds in [-0.28, 0.32]:
		var dx: float = ds
		var edge: float = dx - 0.20 if dx < 0.0 else dx + 0.20
		h.cbox(Vector3(edge * Sc, 0.98 * Sc, -3.59 * Sc), Vector3(0.05 * Sc, 0.08 * Sc, 0.04 * Sc), 0.006 * Sc)
		h.cbox(Vector3(edge * Sc, 0.60 * Sc, -3.59 * Sc), Vector3(0.05 * Sc, 0.08 * Sc, 0.04 * Sc), 0.006 * Sc)
		h.box(Vector3((dx + 0.08) * Sc, 0.82 * Sc, -3.60 * Sc), Vector3(0.03 * Sc, 0.12 * Sc, 0.03 * Sc))
	for lx in [-0.78, 0.78]:
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(float(lx) * Sc, 1.42 * Sc, -3.58 * Sc), Vector3(0.12 * Sc, 0.08 * Sc, 0.05 * Sc), 0.008 * Sc)
		h.color("#c4b8a4", Geo.LAMP)
		h.box(Vector3(float(lx) * Sc, 1.42 * Sc, -3.61 * Sc), Vector3(0.07 * Sc, 0.045 * Sc, 0.02 * Sc))
	for tx in [-0.85, 0.85]:
		h.color(RU_S, Geo.STEEL)
		h.cbox(Vector3(float(tx) * Sc, 0.48 * Sc, -3.58 * Sc), Vector3(0.12 * Sc, 0.08 * Sc, 0.08 * Sc), 0.01 * Sc)
	h.uv = Vector2.ZERO
	h.uv2 = Vector2.ZERO

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
	# Original super-heavy for the T-14 slot. Turret is narrower than the hull.
	# Cheek pods fire the secondary missile. The twin cannons stay on the barrel.
	var root := VK._root({"selection_radius": 1.3, "bar_height": 1.32, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	for side_i in [-1.0, 1.0]:
		var sx: float = side_i * 0.78
		VK._track(h, sx - 0.15, sx + 0.15, Vector2(-1.12, 0.16), 0.14, Vector2(0.84, 0.16), 0.09, 0.33)
		for i in 7:
			var zw: float = lerpf(-0.82, 0.66, float(i) / 6.0)
			h.wheel(Vector3(sx, 0.132, zw), 0.110, 0.26, false, "#6e736c", 10)
		h.sprocket(Vector3(sx, 0.16, -1.12), 0.12, 0.20, 8, RU_S)
		h.wheel(Vector3(sx, 0.16, 0.84), 0.068, 0.16, false, RU_S, 10)
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
		h.box(Vector3(side2 * 0.22, 0.32, 1.34), Vector3(0.04, 0.035, 0.04))
		h.box(Vector3(side2 * 0.34, 0.30, -1.39), Vector3(0.035, 0.04, 0.035))
		h.color("#1a1c1a", Geo.DARK)
		h.box(Vector3(side2 * 0.86, 0.40, -1.18), Vector3(0.03, 0.05, 0.14))
		h.color(RU_D, Geo.PAINT)
		h.box(Vector3(side2 * 0.78, 0.24, 1.02), Vector3(0.26, 0.08, 0.012))
		h.box(Vector3(side2 * 0.78, 0.22, -1.22), Vector3(0.26, 0.10, 0.012))
		h.cbox(Vector3(side2 * 0.91, 0.48, 0.10), Vector3(0.018, 0.09, 0.20), 0.004)
		h.color(RU_S, Geo.STEEL)
		h.tube(Vector3(side2 * 0.72, 0.50, 0.55), Vector3(side2 * 0.70, 0.46, -0.35), 0.012, 4)
		h.tube(Vector3(side2 * 0.70, 0.46, -0.35), Vector3(side2 * 0.68, 0.50, -1.15), 0.012, 4)
	h.color(RU_D, Geo.PAINT)
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		h.cyl(0.065, 0.065, 0.16, 8, Transform3D(Basis.IDENTITY, Vector3(side3 * 0.62, 0.50, -1.12)))
		h.jerrycan(Vector3(side3 * 0.78, 0.52, -0.95), 90.0 if side3 > 0.0 else -90.0)
	h.color("#2a2c2a", Geo.DARK)
	h.box(Vector3(0.22, 0.50, 1.12), Vector3(0.10, 0.03, 0.16))
	h.box(Vector3(0.22, 0.535, 1.10), Vector3(0.10, 0.03, 0.16))
	for s4 in [-1.0, 1.0]:
		var side4: float = s4
		h.color(RU_S, Geo.STEEL)
		h.plate(Vector3(side4 * 0.30, 0.50, 1.18), Vector3(0.14, 0.08, 0.02), Vector3(-22, 0, 0))
		h.color("#ffe6b0", Geo.LAMP)
		h.plate(Vector3(side4 * 0.30, 0.508, 1.195), Vector3(0.07, 0.042, 0.01), Vector3(-22, 0, 0))
		h.color("#c4483a", Geo.LAMP)
		h.box(Vector3(side4 * 0.46, 0.34, -1.385), Vector3(0.06, 0.03, 0.012))
	# Break the big flat plates: seams, bolts, stowage, tools. Kept large enough to read at match range.
	h.color(RU_D, Geo.PAINT)
	h.box(Vector3(0, 0.605, 0.55), Vector3(1.15, 0.008, 0.012))
	h.box(Vector3(0, 0.605, -0.45), Vector3(1.20, 0.008, 0.012))
	h.box(Vector3(-0.42, 0.605, 0.15), Vector3(0.012, 0.008, 0.70))
	h.box(Vector3(0.42, 0.605, 0.15), Vector3(0.012, 0.008, 0.70))
	h.cbox(Vector3(-0.48, 0.64, 0.42), Vector3(0.16, 0.08, 0.20), 0.005)
	h.cbox(Vector3(0.50, 0.64, 0.55), Vector3(0.14, 0.09, 0.12), 0.005)
	h.cbox(Vector3(0.55, 0.63, -0.55), Vector3(0.16, 0.07, 0.12), 0.005)
	h.color("#7a735c", Geo.CANVAS)
	h.tube(Vector3(-0.42, 0.65, 0.62), Vector3(0.05, 0.65, 0.62), 0.04, 6)
	h.tube(Vector3(-0.15, 0.65, -0.62), Vector3(0.28, 0.65, -0.62), 0.038, 6)
	h.sandbag(Vector3(-0.55, 0.64, -0.25), 0.26, 20.0, "#5e644c")
	h.sandbag(Vector3(0.15, 0.64, 0.28), 0.22, -15.0, "#5a5344")
	h.color(GLASS_C, Geo.GLASS)
	for i4 in 4:
		h.box(Vector3(-0.22 + float(i4) * 0.14, 0.62, 0.98), Vector3(0.045, 0.022, 0.03))
	h.color("#6b5438", Geo.WOOD)
	h.box(Vector3(-0.16, 0.40, -1.405), Vector3(0.018, 0.20, 0.012))
	h.tube(Vector3(0.08, 0.34, -1.40), Vector3(0.08, 0.50, -1.40), 0.008, 4)
	h.color(RU_S, Geo.STEEL)
	h.box(Vector3(-0.16, 0.28, -1.41), Vector3(0.07, 0.045, 0.012))
	h.box(Vector3(0.08, 0.48, -1.41), Vector3(0.04, 0.02, 0.012))
	h.tube(Vector3(0.20, 0.32, -1.40), Vector3(0.20, 0.46, -1.395), 0.007, 4)
	h.cyl(0.09, 0.09, 0.04, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.72, 0.56, -0.42)))
	h.cyl(0.035, 0.035, 0.05, 6, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.72, 0.56, -0.42)))
	h.color("#2a2c2a", Geo.DARK)
	h.box(Vector3(-0.28, 0.50, 1.08), Vector3(0.10, 0.028, 0.16))
	h.box(Vector3(-0.28, 0.532, 1.06), Vector3(0.10, 0.028, 0.16))
	h.color(RU_S, Geo.STEEL)
	h.rivets(Vector3(-0.35, 0.46, 1.22), Vector3(0.35, 0.46, 1.22), 6, Vector3(0, 0.4, 1), 0.007)
	h.tube(Vector3(-0.55, 0.61, -0.35), Vector3(-0.55, 0.84, -0.37), 0.005, 3)
	for s5h in [-1.0, 1.0]:
		var sh: float = s5h
		h.box(Vector3(sh * 0.995, 0.36, -0.05), Vector3(0.008, 0.012, 1.85))
		h.rivets(Vector3(sh * 0.99, 0.44, -0.85), Vector3(sh * 0.99, 0.44, 0.75), 5, Vector3(sh, 0, 0), 0.006)
		h.color(RU_D, Geo.PAINT)
		h.cbox(Vector3(sh * 1.03, 0.40, 0.40), Vector3(0.07, 0.11, 0.24), 0.006)
		h.cbox(Vector3(sh * 1.025, 0.38, -0.35), Vector3(0.06, 0.09, 0.18), 0.005)
		h.color(RU_S, Geo.STEEL)
		h.box(Vector3(sh * 1.06, 0.40, 0.40), Vector3(0.012, 0.012, 0.20))
	h.color("#6b5438", Geo.WOOD)
	h.box(Vector3(-0.42, 0.54, 1.16), Vector3(0.025, 0.03, 0.28))
	h.color(RU_S, Geo.STEEL)
	h.box(Vector3(-0.42, 0.52, 1.02), Vector3(0.08, 0.02, 0.07))
	h.tube(Vector3(0.48, 0.54, 1.22), Vector3(0.48, 0.56, 1.02), 0.01, 4)
	h.color("#7a735c", Geo.CANVAS)
	h.tube(Vector3(-0.25, 0.66, 0.70), Vector3(0.32, 0.66, 0.70), 0.05, 6)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0.98, 0.40, -0.15), Vector3(0.012, 0.035, 0.42))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.58, -0.06))
	var t = K.new()
	t.color(RU, Geo.PAINT)
	t.plan_loft([
		Vector2(-0.14, 0.58), Vector2(0.14, 0.58),
		Vector2(0.54, 0.24), Vector2(0.56, -0.36),
		Vector2(0.40, -0.64), Vector2(-0.40, -0.64),
		Vector2(-0.56, -0.36), Vector2(-0.54, 0.24)],
		0.0, 0.30, Vector2(0.90, 0.88))
	t.color(RU_D, Geo.PAINT)
	t.cyl(0.07, 0.07, 0.05, 8, Transform3D(Basis.IDENTITY, Vector3(-0.16, 0.30, -0.08)))
	t.hatch(Vector3(-0.16, 0.36, -0.08), 0.08)
	t.hatch(Vector3(0.14, 0.315, 0.06), 0.08)
	for k in 3:
		var ang := deg_to_rad(-40.0 + float(k) * 40.0)
		t.box(Vector3(-0.16 + cos(ang) * 0.09, 0.34, -0.08 + sin(ang) * 0.07), Vector3(0.025, 0.02, 0.018))
	t.cbox(Vector3(0.0, 0.12, -0.56), Vector3(0.58, 0.14, 0.16), 0.008)
	t.box(Vector3(0.16, 0.22, -0.48), Vector3(0.12, 0.06, 0.10))
	t.cbox(Vector3(0.18, 0.16, 0.40), Vector3(0.10, 0.08, 0.14), 0.006)
	t.box(Vector3(-0.22, 0.20, 0.42), Vector3(0.06, 0.05, 0.05))
	t.box(Vector3(0.22, 0.22, 0.36), Vector3(0.05, 0.04, 0.05))
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.18, 0.16, 0.475), Vector3(0.06, 0.04, 0.01))
	t.box(Vector3(-0.22, 0.20, 0.45), Vector3(0.035, 0.025, 0.008))
	t.color(RU, Geo.PAINT)
	t.cbox(Vector3(0.20, 0.38, -0.18), Vector3(0.10, 0.06, 0.12), 0.006)
	t.color(RU_S, Geo.STEEL)
	t.tube(Vector3(0.20, 0.40, -0.10), Vector3(0.20, 0.41, 0.12), 0.012, 5)
	t.tube(Vector3(-0.16, 0.32, -0.28), Vector3(-0.16, 0.46, -0.28), 0.012, 5)
	t.dish(Vector3(-0.16, 0.46, -0.28), 0.07, 28.0, 0.35, "#8d9876")
	t.box(Vector3(0.26, 0.31, -0.34), Vector3(0.025, 0.018, 0.025))
	t.tube(Vector3(0.26, 0.32, -0.34), Vector3(0.26, 0.56, -0.35), 0.006, 3)
	t.tube(Vector3(0.26, 0.40, -0.34), Vector3(0.12, 0.32, -0.22), 0.005, 3)
	t.color(RU_D, Geo.PAINT)
	t.box(Vector3(0, 0.312, 0.10), Vector3(0.62, 0.008, 0.01))
	t.box(Vector3(0, 0.312, -0.22), Vector3(0.55, 0.008, 0.01))
	t.cbox(Vector3(0.02, 0.35, 0.18), Vector3(0.12, 0.05, 0.09), 0.004)
	t.color("#7a735c", Geo.CANVAS)
	t.tube(Vector3(-0.22, 0.34, 0.16), Vector3(0.02, 0.34, 0.16), 0.032, 5)
	t.sandbag(Vector3(-0.08, 0.35, -0.38), 0.20, 70.0, "#5c6248")
	t.color(RU_S, Geo.STEEL)
	t.rivets(Vector3(-0.40, 0.16, 0.05), Vector3(0.40, 0.16, 0.05), 5, Vector3(0, 0, 1), 0.006)
	for s5 in [-1.0, 1.0]:
		var side5: float = s5
		t.color(RU_S, Geo.STEEL)
		t.tube(Vector3(side5 * 0.32, 0.32, 0.05), Vector3(side5 * 0.32, 0.32, -0.28), 0.006, 3)
		t.tube(Vector3(side5 * 0.48, 0.16, -0.05), Vector3(side5 * 0.48, 0.28, -0.05), 0.008, 3)
		t.tube(Vector3(side5 * 0.48, 0.16, -0.22), Vector3(side5 * 0.48, 0.28, -0.22), 0.008, 3)
		for i3 in 4:
			var zs: float = 0.28 - float(i3) * 0.04
			t.tube(Vector3(side5 * 0.46, 0.12, zs), Vector3(side5 * 0.56, 0.20, zs + 0.08), 0.012, 4)
	var pitch := deg_to_rad(38.0)
	var fwd := Vector3(0, sin(pitch), cos(pitch))
	for s6 in [-1.0, 1.0]:
		var side6: float = s6
		var origin := Vector3(side6 * 0.68, 0.14, 0.02)
		var mk := Marker3D.new()
		mk.name = "PodMuzzleL" if side6 < 0.0 else "PodMuzzleR"
		mk.position = origin + fwd * 0.42
		piv.add_child(mk)
		mk.owner = root
		t.color(RU_S, Geo.STEEL)
		t.box(Vector3(side6 * 0.58, 0.16, 0.0), Vector3(0.16, 0.04, 0.06))
		t.color(RU_S, Geo.STEEL)
		t.plate(origin, Vector3(0.26, 0.20, 0.52), Vector3(-38, 0, 0))
		t.color(RU, Geo.PAINT)
		t.plate(origin + fwd * 0.012, Vector3(0.20, 0.15, 0.46), Vector3(-38, 0, 0))
		t.color("#141615", Geo.DARK)
		t.plate(origin + fwd * 0.02, Vector3(0.16, 0.11, 0.40), Vector3(-38, 0, 0))
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
	b.cbox(Vector3(0, 0, 0.06), Vector3(0.48, 0.16, 0.16), 0.012)
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

## Stage 2 blockout of the armed Mi-8T. Unwired. The live mi8.tscn is not touched.
## 0.311 u/m, same as the BMP-3 v2 and the T-90 hull. +Z is the nose. The tail rotor is
## on the starboard side (+X): published Mi-8T, and the side the audit read as right.
static func mi8_v2(mat: Material) -> void:
	# 0.218 is about 70% of the approved 0.311, so the helicopter fits the camera.
	# Tw scales the few thicknesses that were tuned in world units at 0.311.
	var Sc := 0.218
	var Tw := Sc / 0.311
	var root := VK._root({"selection_radius": 2.7 * Tw, "bar_height": 1.82 * Tw, "recoil": 0.0, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.plain = true
	h.camo("#96A468", 2)
	# Fuselage 18.22 m, origin on the ground under the midpoint. The cabin is a rounded
	# box held at full width until the clamshells. 2.50 m is the published Mi-8T
	# fuselage width; the drawing's front and top views show that wide constant cabin
	# and have no scale bar of their own.
	var cabin_w := 2.50
	var belly := 0.48
	var roof := 3.38
	var cabin_h := roof - belly
	var bow := 0.72 * Sc
	# Cabin stays the approved box. The solid nose stops at the cockpit bulkhead;
	# the greenhouse in front of it is a rounded glass bulb, not a flat cap.
	h.xloft([
		[7.55 * Sc, _mi8_ring(1.15 * Sc, 0.72 * Sc, 3.18 * Sc, 0.50 * Sc)],
		[6.40 * Sc, _mi8_ring(cabin_w * 0.5 * Sc, belly * Sc, roof * Sc, bow)],
		[-1.15 * Sc, _mi8_ring(cabin_w * 0.5 * Sc, belly * Sc, roof * Sc, bow)],
		[-1.85 * Sc, _mi8_ring(0.72 * Sc, 1.15 * Sc, 2.55 * Sc, 0.36 * Sc)],
		[-2.35 * Sc, _mi8_ring(0.42 * Sc, 1.45 * Sc, 2.15 * Sc, 0.24 * Sc)],
	])
	# Rounded greenhouse: a glass bulb, with dark mullions sitting on the outside.
	h.color("#24323a", Geo.GLASS)
	h.xloft([
		[9.02 * Sc, _mi8_ring(0.12 * Sc, 1.95 * Sc, 2.22 * Sc, 0.10 * Sc)],
		[8.72 * Sc, _mi8_ring(0.42 * Sc, 1.55 * Sc, 2.55 * Sc, 0.28 * Sc)],
		[8.35 * Sc, _mi8_ring(0.78 * Sc, 1.15 * Sc, 2.88 * Sc, 0.40 * Sc)],
		[7.95 * Sc, _mi8_ring(1.02 * Sc, 0.88 * Sc, 3.08 * Sc, 0.46 * Sc)],
		[7.55 * Sc, _mi8_ring(1.15 * Sc, 0.72 * Sc, 3.18 * Sc, 0.50 * Sc)],
	])
	var fr := 0.016
	h.color("#161a1e", Geo.DARK)
	h.tube(Vector3(0, 1.35 * Sc, 8.82 * Sc), Vector3(0, 2.08 * Sc, 9.08 * Sc), fr, 4)
	h.tube(Vector3(0, 2.08 * Sc, 9.08 * Sc), Vector3(0, 2.78 * Sc, 8.48 * Sc), fr, 4)
	h.tube(Vector3(-0.52 * Sc, 1.62 * Sc, 8.58 * Sc), Vector3(0, 1.78 * Sc, 9.05 * Sc), fr, 4)
	h.tube(Vector3(0, 1.78 * Sc, 9.05 * Sc), Vector3(0.52 * Sc, 1.62 * Sc, 8.58 * Sc), fr, 4)
	h.tube(Vector3(-0.42 * Sc, 2.48 * Sc, 8.55 * Sc), Vector3(0, 2.55 * Sc, 8.95 * Sc), fr, 4)
	h.tube(Vector3(0, 2.55 * Sc, 8.95 * Sc), Vector3(0.42 * Sc, 2.48 * Sc, 8.55 * Sc), fr, 4)
	h.tube(Vector3(-0.36 * Sc, 1.18 * Sc, 8.55 * Sc), Vector3(0.36 * Sc, 1.18 * Sc, 8.55 * Sc), fr, 4)
	h.tube(Vector3(-0.42 * Sc, 1.25 * Sc, 8.62 * Sc), Vector3(-0.42 * Sc, 2.45 * Sc, 8.68 * Sc), fr, 4)
	h.tube(Vector3(0.42 * Sc, 1.25 * Sc, 8.62 * Sc), Vector3(0.42 * Sc, 2.45 * Sc, 8.68 * Sc), fr, 4)
	for sw in [-1.0, 1.0]:
		var ss: float = sw
		_mi8_win(h, _mi8_quad(Sc, Vector3(ss * 1.18, 2.15, 8.35), Vector3(ss * 1.18, 2.15, 7.90), Vector3(ss * 1.18, 2.78, 7.90)), Vector3(ss, 0.15, 0.35))
		_mi8_win(h, _mi8_quad(Sc, Vector3(ss * 1.16, 1.25, 8.38), Vector3(ss * 1.16, 1.25, 7.92), Vector3(ss * 1.16, 2.05, 7.92)), Vector3(ss, -0.1, 0.3))
		_mi8_blister(h, ss, Sc)
	# Round cabin windows. The port row stops for the sliding door.
	for pz in [4.70, 3.75, 1.30, 0.25]:
		_mi8_port(h, Vector3(-1.30 * Sc, 1.85 * Sc, float(pz) * Sc), -1.0)
	for i2 in 5:
		_mi8_port(h, Vector3(1.30 * Sc, 1.85 * Sc, (4.65 - float(i2) * 1.05) * Sc), 1.0)
	# Engine and gearbox fairing, about half the cabin length, intakes forward.
	h.camo("#96A468", 2)
	var fair_a := 5.35
	var fair_b := 1.05
	h.xloft([
		[fair_a * Sc, _mi8_ring(0.88 * Sc, 3.48 * Sc, 4.02 * Sc, 0.20 * Sc)],
		[5.00 * Sc, _mi8_ring(1.12 * Sc, 3.36 * Sc, 4.22 * Sc, 0.28 * Sc)],
		[3.15 * Sc, _mi8_ring(1.14 * Sc, 3.36 * Sc, 4.36 * Sc, 0.30 * Sc)],
		[1.85 * Sc, _mi8_ring(1.06 * Sc, 3.36 * Sc, 4.28 * Sc, 0.26 * Sc)],
		[fair_b * Sc, _mi8_ring(0.50 * Sc, 3.48 * Sc, 3.92 * Sc, 0.16 * Sc)],
	])
	h.xloft([
		[2.15 * Sc, _mi8_ring(0.32 * Sc, 4.20 * Sc, 4.36 * Sc, 0.10 * Sc)],
		[1.60 * Sc, _mi8_ring(0.44 * Sc, 4.16 * Sc, 4.52 * Sc, 0.14 * Sc)],
		[1.20 * Sc, _mi8_ring(0.26 * Sc, 4.18 * Sc, 4.34 * Sc, 0.08 * Sc)],
	])
	for s2 in [-1.0, 1.0]:
		var es: float = s2
		var mouth := Vector3(es * 0.42 * Sc, 3.66 * Sc, fair_a * Sc)
		h.color("#6a6c68", Geo.STEEL)
		h.tube(mouth, mouth + Vector3(0, 0, 0.22 * Sc), 0.30 * Sc, 10)
		h.color("#14181c", Geo.DARK)
		h.tube(mouth + Vector3(0, 0, 0.04 * Sc), mouth + Vector3(0, 0, 0.20 * Sc), 0.19 * Sc, 8)
		h.color("#5c5e5a", Geo.STEEL)
		var exh0 := Vector3(es * 0.90 * Sc, 3.72 * Sc, 1.35 * Sc)
		var exh1 := Vector3(es * 1.58 * Sc, 3.18 * Sc, 0.48 * Sc)
		h.tube(exh0, exh1, 0.22 * Sc, 8, 0.28 * Sc)
		h.color("#2a2420", Geo.DARK)
		h.tube(exh0 + (exh1 - exh0) * 0.35, exh1, 0.30 * Sc, 8, 0.34 * Sc)
		h.color("#14181c", Geo.DARK)
		h.tube(exh1 - (exh1 - exh0).normalized() * 0.10 * Sc, exh1, 0.16 * Sc, 8)
		h.color("#1a1c1e", Geo.DARK)
		var lip := mouth + Vector3(0, 0, 0.18 * Sc)
		for gi in 4:
			var gy: float = (3.50 + float(gi) * 0.10) * Sc
			h.box(Vector3(es * 0.42 * Sc, gy, lip.z), Vector3(0.34 * Sc, 0.012 * Tw, 0.02 * Tw))
	# Mast and hub housing. Hub stays at 4.75 m over the gearbox.
	h.color("#6e706c", Geo.STEEL)
	var hub := Vector3(0, 4.75 * Sc, 1.60 * Sc)
	h.tube(Vector3(0, 4.46 * Sc, hub.z), Vector3(0, 4.62 * Sc, hub.z), 0.16 * Sc, 8)
	h.tube(Vector3(0, 4.56 * Sc, hub.z), Vector3(0, 4.70 * Sc, hub.z), 0.28 * Sc, 10)
	# Boom into the fin. The fuselage loft itself is unchanged.
	h.camo("#96A468", 2)
	h.tube(Vector3(0, 1.80 * Sc, -2.35 * Sc), Vector3(0, 1.90 * Sc, -8.90 * Sc), 0.40 * Sc, 8, 0.16 * Sc)
	print("  mi8 cabin %.2f m wide, belly-to-roof %.2f m, ratio to 18.22 m length %.3f" % [cabin_w, cabin_h, cabin_h / 18.22])
	print("  mi8 fairing %.2f m to %.2f m (%.2f m, cabin %.2f m)" % [fair_a, fair_b, fair_a - fair_b, 6.40 - (-1.15)])
	# Swept fin. The tail rotor sits on its starboard face. Stab on the boom ahead of it.
	var fin: Array = []
	for fp in [Vector2(-7.40, 1.80), Vector2(-9.25, 1.55), Vector2(-9.35, 3.80), Vector2(-8.15, 4.00)]:
		fin.append(Vector2(fp.x * Sc, fp.y * Sc))
	h.prism_x(fin, -0.04 * Sc, 0.12 * Sc)
	h.camo("#8a9460", 2)
	h.box(Vector3(0, 1.98 * Sc, -6.55 * Sc), Vector3(3.60 * Sc, 0.18 * Sc, 1.05 * Sc))
	h.camo("#96A468", 2)
	h.color("#5a5c58", Geo.STEEL)
	var tail_at := Vector3(0.24 * Sc, 2.80 * Sc, -8.60 * Sc)
	h.tube(Vector3(0.10 * Sc, tail_at.y, tail_at.z), tail_at, 0.11 * Sc, 8)
	# Fixed tricycle gear. Track 4.50 m. Main tyre 865x280, nose 595x185 twin.
	# Wheelbase 4.28 m, the published Mi-8 figure; the drawing has no scale bar.
	var nose_z := 7.05
	var main_z := nose_z - 4.28
	var main_r := 0.432
	var nose_r := 0.298
	h.color("#4e524e", Geo.STEEL)
	h.tube(Vector3(0, 0.62 * Sc, (nose_z + 0.15) * Sc), Vector3(0, nose_r * Sc, nose_z * Sc), 0.042 * Tw, 8)
	h.tube(Vector3(0, 0.55 * Sc, (nose_z - 0.85) * Sc), Vector3(0, nose_r * Sc, nose_z * Sc), 0.028 * Tw, 6)
	h.tube(Vector3(-0.22 * Sc, nose_r * Sc, nose_z * Sc), Vector3(0.22 * Sc, nose_r * Sc, nose_z * Sc), 0.028 * Tw, 6)
	_mi8_tyre(h, Vector3(-0.20 * Sc, nose_r * Sc, nose_z * Sc), nose_r * Sc, 0.16 * Sc)
	_mi8_tyre(h, Vector3(0.20 * Sc, nose_r * Sc, nose_z * Sc), nose_r * Sc, 0.16 * Sc)
	for sg in [-1.0, 1.0]:
		var gs: float = sg
		var axle := Vector3(gs * 2.25 * Sc, main_r * Sc, main_z * Sc)
		h.color("#4a4e4a", Geo.STEEL)
		h.tube(Vector3(gs * 1.15 * Sc, 1.05 * Sc, (main_z + 0.45) * Sc), axle + Vector3(gs * -0.08 * Sc, 0.06 * Sc, 0.08 * Sc), 0.052 * Tw, 8)
		h.tube(axle + Vector3(gs * -0.15 * Sc, 0.04 * Sc, 0), Vector3(gs * 1.05 * Sc, 0.62 * Sc, (main_z + 1.35) * Sc), 0.032 * Tw, 6)
		h.tube(axle + Vector3(gs * -0.15 * Sc, 0.04 * Sc, 0), Vector3(gs * 1.05 * Sc, 0.62 * Sc, (main_z - 1.15) * Sc), 0.032 * Tw, 6)
		h.tube(axle + Vector3(gs * -0.18 * Sc, 0, 0), axle + Vector3(gs * 0.16 * Sc, 0, 0), 0.034 * Tw, 6)
		_mi8_tyre(h, axle, main_r * Sc, 0.26 * Sc)
	print("  mi8 gear track 4.50 m, wheelbase %.2f m, main dia %.3f m, nose dia %.3f m" % [nose_z - main_z, main_r * 2.0, nose_r * 2.0])
	# Stub weapon beam each side, three struts, three rocket pods. The drawing shows the
	# row and not a count; six is the published Mi-8T load.
	var pods: Array = []
	for side in [-1.0, 1.0]:
		var sd: float = side
		h.camo("#7d8a58", 2)
		h.cbox(Vector3(sd * 1.72 * Sc, 1.38 * Sc, 2.70 * Sc), Vector3(1.05 * Sc, 0.36 * Sc, 4.60 * Sc), 0.05 * Sc)
		h.color("#3e423c", Geo.STEEL)
		h.tube(Vector3(sd * 1.22 * Sc, 2.35 * Sc, 4.15 * Sc), Vector3(sd * 2.05 * Sc, 1.52 * Sc, 3.85 * Sc), 0.038 * Tw, 6)
		h.tube(Vector3(sd * 1.22 * Sc, 2.35 * Sc, 2.55 * Sc), Vector3(sd * 2.10 * Sc, 1.52 * Sc, 2.55 * Sc), 0.038 * Tw, 6)
		h.tube(Vector3(sd * 1.22 * Sc, 2.25 * Sc, 1.05 * Sc), Vector3(sd * 2.05 * Sc, 1.52 * Sc, 1.35 * Sc), 0.038 * Tw, 6)
		var tag := "R" if sd > 0.0 else "L"
		for i in 3:
			var pz: float = (4.45 - float(i) * 1.70) * Sc
			var px: float = sd * 1.78 * Sc
			var py: float = 0.78 * Sc
			h.color("#3a3c38", Geo.STEEL)
			h.tube(Vector3(px, 1.20 * Sc, pz), Vector3(px, py + 0.28 * Sc, pz), 0.028 * Tw, 6)
			h.color("#5c6258", Geo.DARK)
			h.tube(Vector3(px, py, pz - 0.88 * Sc), Vector3(px, py, pz + 0.55 * Sc), 0.30 * Sc, 10)
			h.color("#3a3e3a", Geo.STEEL)
			h.tube(Vector3(px, py, pz + 0.55 * Sc), Vector3(px, py, pz + 1.05 * Sc), 0.30 * Sc, 10, 0.04 * Sc)
			h.color("#2a2c2a", Geo.DARK)
			h.tube(Vector3(px, py, pz - 0.88 * Sc), Vector3(px, py, pz - 1.02 * Sc), 0.22 * Sc, 8)
			var mk := Marker3D.new()
			mk.name = "PodMuzzle%s%d" % [tag, i + 1]
			mk.position = Vector3(px, py, pz + 1.02 * Sc)
			model.add_child(mk)
			mk.owner = root
			pods.append(mk.name)
	# Door rails, cabin breaks, and the two door guns. The MG fires from these, not the pods.
	h.color("#2c3034", Geo.DARK)
	h.tube(Vector3(-1.32 * Sc, 2.72 * Sc, 1.85 * Sc), Vector3(-1.32 * Sc, 2.72 * Sc, 3.40 * Sc), 0.022 * Tw, 5)
	h.tube(Vector3(-1.32 * Sc, 0.95 * Sc, 1.90 * Sc), Vector3(-1.32 * Sc, 0.95 * Sc, 3.30 * Sc), 0.016 * Tw, 4)
	h.box(Vector3(-1.36 * Sc, 1.55 * Sc, 2.15 * Sc), Vector3(0.04 * Tw, 0.08 * Tw, 0.16 * Sc))
	_mi8_detail(h, Sc)
	for ms in [-1.0, 1.0]:
		var mside: float = ms
		var gun := Marker3D.new()
		gun.name = "MuzzleL" if mside < 0.0 else "MuzzleR"
		gun.position = Vector3(mside * 1.55 * Sc, 1.65 * Sc, 2.35 * Sc)
		model.add_child(gun)
		gun.owner = root
	var parts: Array = []
	parts.append(_mi8_door(model, root, mat, Vector3(-1.34 * Sc, 1.82 * Sc, 2.60 * Sc), Vector3(0.05 * Sc, 1.70 * Sc, 1.15 * Sc)))
	parts.append(_mi8_clamshell(model, root, mat, "ClamshellL", Vector3(-0.62 * Sc, 1.93 * Sc, -1.18 * Sc), Vector3(1.12 * Sc, 2.50 * Sc, 0.07 * Sc), -1.0))
	parts.append(_mi8_clamshell(model, root, mat, "ClamshellR", Vector3(0.62 * Sc, 1.93 * Sc, -1.18 * Sc), Vector3(1.12 * Sc, 2.50 * Sc, 0.07 * Sc), 1.0))
	# Five main blades. Hub is the Rotor pivot.
	var rotor := VK._n3(model, root, "Rotor", hub)
	rotor.set_meta("rotor_axis", "y")
	parts.append(_mi8_rotor(rotor, root, mat, 10.645 * Sc, 5, false, 0.10 * Tw, 0.03 * Tw, 0.03))
	# Three tail blades. Starboard of the fin (+X).
	var tail := VK._n3(model, root, "TailRotor", tail_at)
	tail.set_meta("rotor_axis", "x")
	parts.append(_mi8_rotor(tail, root, mat, 1.955 * Sc, 3, true, 0.08 * Tw, 0.025 * Tw, 0.0))
	print("  mi8_v2 pods ", pods, " hub m ", hub / Sc)
	_save(root, model, h, mat, "res://view/units/ecc/mi8_v2.tscn", 1.82 * Tw, parts)

## Rounded-rectangle cross-section. Sixteen points: four corners, four steps each.
static func _mi8_ring(hw: float, y0: float, y1: float, rad: float) -> Array:
	var ry: float = minf(rad, (y1 - y0) * 0.46)
	var rx: float = minf(rad, hw * 0.46)
	var n := 4
	var corners: Array = [
		[hw - rx, y0 + ry, -PI * 0.5, 0.0],
		[hw - rx, y1 - ry, 0.0, PI * 0.5],
		[-hw + rx, y1 - ry, PI * 0.5, PI],
		[-hw + rx, y0 + ry, PI, PI * 1.5],
	]
	var pts: Array = []
	for c in corners:
		for k in n:
			var t: float = float(k) / float(n)
			var ang: float = float(c[2]) + (float(c[3]) - float(c[2])) * t
			pts.append(Vector2(float(c[0]) + cos(ang) * rx, float(c[1]) + sin(ang) * ry))
	return pts

## Three corners of a parallelogram, in metres, returned in model units.
static func _mi8_quad(sc: float, a: Vector3, b: Vector3, c: Vector3) -> Array:
	return [a * sc, b * sc, c * sc, (a + c - b) * sc]

## Glass pane plus a dark frame. mask bit i draws the edge from i to i+1.
static func _mi8_win(h, q: Array, out: Vector3, mask: int = 15) -> void:
	h.color("#24323a", Geo.GLASS)
	h.pane(q, out, 0.006, 0.004)
	var n: Vector3 = ((q[1] - q[0]) as Vector3).cross((q[3] - q[0]) as Vector3)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot(out) < 0.0:
		n = -n
	h.color("#161a1e", Geo.DARK)
	for i in 4:
		if (mask & (1 << i)) == 0:
			continue
		var a: Vector3 = (q[i] as Vector3) + n * 0.005
		var b: Vector3 = (q[(i + 1) % 4] as Vector3) + n * 0.005
		h.tube(a, b, 0.014, 4)

## Bulged sliding cockpit window. s is +1 starboard, -1 port.
static func _mi8_blister(h, s: float, sc: float) -> void:
	var cy := 2.20
	var cz := 7.40
	var n := 10
	var rings: Array = []
	var depths: Array = [0.0, 0.12, 0.22]
	var rys: Array = [0.38, 0.32, 0.12]
	var rzs: Array = [0.34, 0.28, 0.10]
	for d in 3:
		var ring: Array = []
		var di: int = d
		for i in n:
			var ang := TAU * float(i) / float(n)
			ring.append(Vector3(s * (1.22 + float(depths[di])) * sc, (cy + sin(ang) * float(rys[di])) * sc, (cz + cos(ang) * float(rzs[di])) * sc))
		rings.append(ring)
	h.color("#24323a", Geo.GLASS)
	h.loft(rings[0], rings[1], Transform3D.IDENTITY, false, false)
	h.loft(rings[1], rings[2], Transform3D.IDENTITY, false, true)
	h.color("#161a1e", Geo.DARK)
	var base: Array = rings[0]
	for i2 in n:
		h.tube(base[i2], base[(i2 + 1) % n], 0.018, 4)

## Round tyre and a plain hub. No tread lugs, so the wheel does not read as a gear.
static func _mi8_tyre(h, c: Vector3, r: float, w: float) -> void:
	var keep = h._col
	h.uv = Vector2(c.y, c.z)
	h.uv2 = Vector2(c.x, r)
	h.color("#1c1e1c", Geo.WHEEL_RUBBER)
	h.tube(c - Vector3(w * 0.46, 0, 0), c - Vector3(w * 0.28, 0, 0), r * 0.94, 14)
	h.tube(c - Vector3(w * 0.30, 0, 0), c + Vector3(w * 0.30, 0, 0), r, 14, -1.0, false)
	h.tube(c + Vector3(w * 0.28, 0, 0), c + Vector3(w * 0.46, 0, 0), r * 0.94, 14)
	h.color("#3a3e42", Geo.WHEEL_STEEL)
	var side := 1.0 if c.x >= 0.0 else -1.0
	var hub := c + Vector3(side * w * 0.40, 0, 0)
	h.tube(hub - Vector3(side * 0.008, 0, 0), hub + Vector3(side * 0.01, 0, 0), r * 0.46, 12)
	h.tube(hub, hub + Vector3(side * 0.016, 0, 0), r * 0.16, 8)
	h.uv = Vector2.ZERO
	h.uv2 = Vector2.ZERO
	h._col = keep

## Breaks on the flat cabin and boom: seams, a roof rivet line, two access panels.
static func _mi8_detail(h, sc: float) -> void:
	var u := sc / 0.311
	h.color("#2c3028", Geo.DARK)
	for s in [-1.0, 1.0]:
		var sd: float = s
		h.box(Vector3(sd * 1.28 * sc, 2.55 * sc, 2.6 * sc), Vector3(0.012 * u, 0.015 * u, 6.4 * sc))
		h.box(Vector3(sd * 1.28 * sc, 1.15 * sc, 2.6 * sc), Vector3(0.012 * u, 0.015 * u, 6.4 * sc))
		for k in 8:
			h.box(Vector3(sd * 1.27 * sc, 3.05 * sc, (5.4 - float(k) * 0.8) * sc), Vector3(0.02 * u, 0.012 * u, 0.02 * u))
	h.camo("#7d8a58", 2)
	h.box(Vector3(1.22 * sc, 2.15 * sc, 0.4 * sc), Vector3(0.02 * u, 0.55 * sc, 0.7 * sc))
	h.box(Vector3(-1.22 * sc, 2.35 * sc, 4.3 * sc), Vector3(0.02 * u, 0.42 * sc, 0.55 * sc))
	h.color("#2c3028", Geo.DARK)
	h.box(Vector3(0, 2.05 * sc, -5.2 * sc), Vector3(0.015 * u, 0.012 * u, 2.4 * sc))

static func _mi8_port(h, c: Vector3, s: float) -> void:
	var u := 0.218 / 0.311
	h.color("#161a1e", Geo.DARK)
	h.tube(c, c + Vector3(s * 0.016 * u, 0, 0), 0.078 * u, 10)
	h.color("#24323a", Geo.GLASS)
	var r := 0.050 * u
	h.pane([
		c + Vector3(s * 0.018 * u, -r, -r), c + Vector3(s * 0.018 * u, -r, r),
		c + Vector3(s * 0.018 * u, r, r), c + Vector3(s * 0.018 * u, r, -r)], Vector3(s, 0, 0), 0.006 * u, 0.004 * u)

static func _mi8_door(model: Node, root: Node, mat: Material, c: Vector3, s: Vector3):
	var g = K.new()
	g.plain = true
	g.camo("#a3b07a", 2)
	g.box(c, s)
	var u := 0.218 / 0.311
	_mi8_port(g, c + Vector3(-0.03 * u, 0.12 * u, 0), -1.0)
	g.color("#2c3034", Geo.DARK)
	var hy := s.y * 0.5
	var hz := s.z * 0.5
	g.tube(c + Vector3(-0.03 * u, hy, -hz), c + Vector3(-0.03 * u, hy, hz), 0.016 * u, 4)
	g.tube(c + Vector3(-0.03 * u, -hy, -hz), c + Vector3(-0.03 * u, -hy, hz), 0.016 * u, 4)
	g.tube(c + Vector3(-0.03 * u, -hy, -hz), c + Vector3(-0.03 * u, hy, -hz), 0.016 * u, 4)
	g.tube(c + Vector3(-0.03 * u, -hy, hz), c + Vector3(-0.03 * u, hy, hz), 0.016 * u, 4)
	VK._mi(model, root, "DoorPort", g.commit(mat))
	return g

static func _mi8_clamshell(model: Node, root: Node, mat: Material, name: String, c: Vector3, s: Vector3, side: float):
	var g = K.new()
	g.plain = true
	g.camo("#a3b07a", 2)
	g.box(c, s)
	g.color("#2c3034", Geo.DARK)
	var u := 0.218 / 0.311
	g.box(Vector3(c.x - side * s.x * 0.48, c.y, c.z), Vector3(0.02 * u, s.y * 0.94, s.z * 1.3))
	var edge_x: float = c.x + side * s.x * 0.5
	g.tube(Vector3(edge_x, c.y - s.y * 0.42, c.z), Vector3(edge_x, c.y + s.y * 0.42, c.z), 0.016 * u, 5)
	VK._mi(model, root, name, g.commit(mat))
	return g

static func _mi8_plate(model: Node, root: Node, mat: Material, name: String, c: Vector3, s: Vector3):
	var g = K.new()
	g.plain = true
	g.color("#9a9c96", Geo.PAINT)
	g.box(c, s)
	VK._mi(model, root, name, g.commit(mat))
	return g

## Straight blades, evenly spaced. droop is the tip drop as a fraction of radius.
static func _mi8_rotor(pivot: Node, root: Node, mat: Material, radius: float, n: int, on_x: bool, chord: float, thick: float, droop: float):
	var g = K.new()
	g.plain = true
	g.color("#2a2c28", Geo.STEEL)
	if on_x:
		g.tube(Vector3(-0.03, 0, 0), Vector3(0.045, 0, 0), 0.055, 6)
		for i in n:
			_mi8_blade(g, TAU * float(i) / float(n), radius, chord, thick, 0.0, true)
	else:
		g.tube(Vector3(0, -0.015, 0), Vector3(0, 0.05, 0), 0.07, 8)
		for i in n:
			_mi8_blade(g, TAU * float(i) / float(n), radius, chord, thick, droop, false)
	VK._mi(pivot, root, "RotorMesh", g.commit(mat))
	return g

static func _mi8_blade(g, ang: float, radius: float, chord: float, thick: float, droop: float, on_x: bool) -> void:
	var dir: Vector3
	var side: Vector3
	if on_x:
		dir = Vector3(0, cos(ang), sin(ang))
		side = Vector3(0, -sin(ang), cos(ang))
	else:
		dir = Vector3(cos(ang), -absf(droop), sin(ang)).normalized()
		side = Vector3(-sin(ang), 0, cos(ang))
	var up := side.cross(dir).normalized()
	var root_p := dir * 0.05
	var tip_p := dir * radius
	var c0 := chord * 0.5
	var c1 := chord * 0.32
	var t0 := thick * 0.5
	var t1 := thick * 0.4
	var a: Array = [root_p + side * c0 + up * t0, root_p + side * c0 - up * t0, root_p - side * c0 - up * t0, root_p - side * c0 + up * t0]
	var b: Array = [tip_p + side * c1 + up * t1, tip_p + side * c1 - up * t1, tip_p - side * c1 - up * t1, tip_p - side * c1 + up * t1]
	g.loft(a, b, Transform3D.IDENTITY, true, true)

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

## Box ladder. The kit ladder is a tube per rung and blows the triangle budget.
static func _mzkt_ladder(h, x: float, y0: float, z: float, hgt: float) -> void:
	h.color("#3a3d38", Geo.STEEL)
	var w := hgt * 0.16
	h.box(Vector3(x, y0 + hgt * 0.5, z - w), Vector3(0.018, hgt, 0.018))
	h.box(Vector3(x, y0 + hgt * 0.5, z + w), Vector3(0.018, hgt, 0.018))
	for i in 6:
		var y := y0 + hgt * (float(i) + 0.5) / 6.0
		h.box(Vector3(x, y, z), Vector3(0.016, 0.014, w * 2.0))

## Round truck tyre. The kit tread lugs read as spikes at a 1.50 m diameter.
static func _mzkt_tyre(h, c: Vector3, r: float, w: float, steers: bool) -> void:
	var keep_uv: Vector2 = h.uv
	var keep_uv2: Vector2 = h.uv2
	# Same wheel pivot the chassis shader uses, so a moved truck spins tyres in place.
	h.uv = Vector2(c.y, c.z)
	h.uv2 = Vector2(c.x, r + (10.0 if steers else 0.0))
	h.color("#1a1a18", Geo.WHEEL_RUBBER)
	h.tube(c - Vector3(w * 0.46, 0, 0), c - Vector3(w * 0.28, 0, 0), r * 0.94, 16)
	h.tube(c - Vector3(w * 0.30, 0, 0), c + Vector3(w * 0.30, 0, 0), r, 16, -1.0, false)
	h.tube(c + Vector3(w * 0.28, 0, 0), c + Vector3(w * 0.46, 0, 0), r * 0.94, 16)
	h.color("#121210", Geo.WHEEL_RUBBER)
	for k in 3:
		var x := lerpf(-w * 0.18, w * 0.18, float(k) / 2.0)
		h.tube(c + Vector3(x - w * 0.035, 0, 0), c + Vector3(x + w * 0.035, 0, 0), r * 1.015, 16, -1.0, false)
	h.color("#3a3d38", Geo.WHEEL_STEEL)
	var side := 1.0 if c.x >= 0.0 else -1.0
	var o := c + Vector3(side * w * 0.42, 0, 0)
	h.tube(o - Vector3(side * 0.008, 0, 0), o + Vector3(side * 0.01, 0, 0), r * 0.52, 12)
	h.tube(o, o + Vector3(side * 0.018, 0, 0), r * 0.20, 8)
	h.uv = keep_uv
	h.uv2 = keep_uv2

## Bare MZKT-7930 chassis. 0.311 u/m, the tank scale. No module. +Z is the nose.
## Spec MZKT-RU.7930-415.S.28.01. The axle chain sums to 12,445 mm against a
## 12,670 mm length; the extra 225 mm is the front bumper, and the rear overhang stays 1,000 mm.
## The 4,290 mm body top is the module, so the mounting deck stays at the chassis bed.
static func mzkt_base(mat: Material) -> void:
	var Sc := 0.311
	var root := VK._root({"selection_radius": 2.1, "bar_height": 1.22, "recoil": 0.0, "wreck_s": 8.0, "steer_max": 0.32})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.plain = true
	# Plain class, same as the cab. Camo and paint pick up the shared stencil sheet.
	h.color("#96A468", Geo.CONCRETE)
	# Stations in metres from the truck centre. Nose is +Z.
	var nose := 6.335
	var z1 := nose - 3.220
	var z2 := nose - 5.570
	var z3 := nose - 9.470
	var z4 := nose - 11.670
	var sx := 1.1875 * Sc
	var wr := 0.75 * Sc
	var tw := 0.695 * Sc
	for i in 4:
		var zz: float = [z1, z2, z3, z4][i] * Sc
		for side in [-sx, sx]:
			_mzkt_tyre(h, Vector3(side, wr, zz), wr, tw, i < 2)
	# Rails sit inside the tyres. The belly stays low so the wheels are not buried in a slab.
	var zf0 := 5.55
	var zf1 := -6.05
	h.color("#738252", Geo.CONCRETE)
	h.cbox(Vector3(0, 0.70 * Sc, (zf0 + zf1) * 0.5 * Sc), Vector3(0.52 * Sc, 0.36 * Sc, (zf0 - zf1) * Sc), 0.015 * Sc)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.42 * Sc, 1.00 * Sc, (zf0 + zf1) * 0.5 * Sc), Vector3(0.16 * Sc, 0.88 * Sc, (zf0 - zf1) * Sc), 0.012 * Sc)
		# Lower extension from the rail end into the bumper, under the cab chin.
		h.cbox(Vector3(s * 0.42 * Sc, 0.84 * Sc, 5.86 * Sc), Vector3(0.16 * Sc, 0.56 * Sc, 0.66 * Sc), 0.01 * Sc)
	h.cbox(Vector3(0, 0.96 * Sc, 6.12 * Sc), Vector3(1.10 * Sc, 0.28 * Sc, 0.14 * Sc), 0.008 * Sc)
	# Empty bed, 3.150 m wide. Top at 1.62 m. It starts where the engine bay ends.
	var d0 := 1.48
	var d1 := -6.08
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0, 1.54 * Sc, (d0 + d1) * 0.5 * Sc), Vector3(3.15 * Sc, 0.16 * Sc, (d0 - d1) * Sc), 0.018 * Sc)
	# Side rail overlaps the deck bottom and the frame top, so the bed seam stays closed.
	h.color("#738252", Geo.CONCRETE)
	for sr in [-1.0, 1.0]:
		h.box(Vector3(sr * 1.585 * Sc, 1.42 * Sc, (d0 + d1) * 0.5 * Sc), Vector3(0.07 * Sc, 0.28 * Sc, (d0 - d1 + 0.20) * Sc))
	for pair in [[z1, z2], [z3, z4]]:
		var zc: float = (pair[0] + pair[1]) * 0.5
		var span: float = absf(pair[0] - pair[1]) + 1.25
		for s2 in [-1.0, 1.0]:
			h.color("#738252", Geo.CONCRETE)
			h.cbox(Vector3(s2 * sx, 1.56 * Sc, zc * Sc), Vector3(tw * 1.02, 0.08 * Sc, span * Sc), 0.01 * Sc)
			h.box(Vector3(s2 * sx, 1.50 * Sc, zc * Sc), Vector3(tw * 0.55, 0.06 * Sc, span * 0.92 * Sc))
			h.color("#2a2c28", Geo.DARK)
			h.box(Vector3(s2 * sx, 0.70 * Sc, (zc - span * 0.48) * Sc), Vector3(tw * 0.5, 0.28 * Sc, 0.03 * Sc))
	# Skirts only in the open span, so they do not cut the tyres.
	h.color("#738252", Geo.CONCRETE)
	for ssk in [-1.0, 1.0]:
		h.box(Vector3(ssk * 1.50 * Sc, 1.22 * Sc, -1.15 * Sc), Vector3(0.04 * Sc, 0.42 * Sc, 1.7 * Sc))
	# Rear cap keeps the 1,000 mm overhang. The front beam is only the last 0.22 m of the 12,670 mm length.
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0, 0.95 * Sc, -6.18 * Sc), Vector3(2.15 * Sc, 0.70 * Sc, 0.28 * Sc), 0.014 * Sc)
	# Slim cab-coloured bumper, bolted to the front cross-member. Front face stays at 6.335 m.
	h.cbox(Vector3(0, 0.96 * Sc, 6.225 * Sc), Vector3(2.20 * Sc, 0.32 * Sc, 0.22 * Sc), 0.01 * Sc)
	h.cbox(Vector3(0, 1.20 * Sc, 6.02 * Sc), Vector3(2.00 * Sc, 0.08 * Sc, 0.26 * Sc), 0.008 * Sc)
	# Valance overlaps the rake underside and the frame, so the nose seam stays closed.
	h.prism_x([
		Vector2(5.28 * Sc, 1.70 * Sc), Vector2(6.28 * Sc, 1.42 * Sc),
		Vector2(6.28 * Sc, 0.84 * Sc), Vector2(5.28 * Sc, 1.18 * Sc),
	], -1.38 * Sc, 1.38 * Sc)
	h.color("#1c1e1c", Geo.DARK)
	for gi in 6:
		h.box(Vector3((-0.40 + float(gi) * 0.16) * Sc, 0.98 * Sc, 6.34 * Sc), Vector3(0.04 * Sc, 0.14 * Sc, 0.016 * Sc))
	for lp in [-0.86, 0.86]:
		h.box(Vector3(lp * Sc, 0.98 * Sc, 6.30 * Sc), Vector3(0.24 * Sc, 0.13 * Sc, 0.05 * Sc))
	h.color("#96A468", Geo.CONCRETE)
	for lp2 in [-0.86, 0.86]:
		h.box(Vector3(lp2 * Sc, 1.06 * Sc, 6.345 * Sc), Vector3(0.28 * Sc, 0.018 * Sc, 0.012 * Sc))
		h.box(Vector3(lp2 * Sc, 0.90 * Sc, 6.345 * Sc), Vector3(0.28 * Sc, 0.018 * Sc, 0.012 * Sc))
		h.box(Vector3((lp2 - 0.12) * Sc, 0.98 * Sc, 6.345 * Sc), Vector3(0.018 * Sc, 0.16 * Sc, 0.012 * Sc))
		h.box(Vector3((lp2 + 0.12) * Sc, 0.98 * Sc, 6.345 * Sc), Vector3(0.018 * Sc, 0.16 * Sc, 0.012 * Sc))
	V4._lamps(h, 0.86 * Sc, 0.98 * Sc, 6.31 * Sc)
	h.color("#3a3d38", Geo.STEEL)
	for hk in [-0.42, 0.42]:
		h.tube(Vector3(hk * Sc, 0.78 * Sc, 6.16 * Sc), Vector3(hk * Sc, 0.62 * Sc, 6.16 * Sc), 0.016 * Sc, 5)
		h.tube(Vector3((hk - 0.05) * Sc, 0.64 * Sc, 6.16 * Sc), Vector3((hk + 0.05) * Sc, 0.64 * Sc, 6.16 * Sc), 0.014 * Sc, 5)
	h.color("#96A468", Geo.CONCRETE)
	h.box(Vector3(0, 1.16 * Sc, 6.16 * Sc), Vector3(0.46 * Sc, 0.035 * Sc, 0.14 * Sc))
	h.color("#3a3d38", Geo.STEEL)
	for st in 3:
		h.box(Vector3(0, 1.185 * Sc, (6.11 + float(st) * 0.035) * Sc), Vector3(0.40 * Sc, 0.01 * Sc, 0.012 * Sc))
	# The rake ends at full cab height on the door face, then sinks into the box so the join has no notch.
	# Cab paint uses the plain class. Camo and paint classes pick up the shared stencil sheet (numbers, chevrons).
	h.color("#96A468", Geo.CONCRETE)
	h.xloft([
		[5.98 * Sc, K.sect(1.32 * Sc, 1.72 * Sc, 2.10 * Sc, 1.16 * Sc, 1.28 * Sc, 1.08 * Sc, 0.04 * Sc)],
		[5.40 * Sc, K.sect(1.575 * Sc, 2.25 * Sc, 3.025 * Sc, 1.32 * Sc, 1.36 * Sc, 1.30 * Sc, 0.04 * Sc)],
	])
	h.cbox(Vector3(0, 2.30 * Sc, 4.72 * Sc), Vector3(2.72 * Sc, 1.45 * Sc, 1.45 * Sc), 0.03 * Sc)
	h.color("#738252", Geo.CONCRETE)
	h.cbox(Vector3(0, 3.16 * Sc, 4.70 * Sc), Vector3(2.45 * Sc, 0.26 * Sc, 1.55 * Sc), 0.02 * Sc)
	h.box(Vector3(0, 3.04 * Sc, 5.50 * Sc), Vector3(2.15 * Sc, 0.05 * Sc, 0.18 * Sc))
	# Doors, a framed side window, grab handles, and a few panel breaks.
	for sd in [-1.0, 1.0]:
		h.color("#738252", Geo.CONCRETE)
		h.box(Vector3(sd * 1.38 * Sc, 2.25 * Sc, 4.70 * Sc), Vector3(0.03 * Sc, 1.05 * Sc, 0.72 * Sc))
		h.color("#b7c6cc", Geo.STEEL)
		h.box(Vector3(sd * 1.40 * Sc, 2.45 * Sc, 4.78 * Sc), Vector3(0.018 * Sc, 0.40 * Sc, 0.50 * Sc))
		h.color("#8eb6c6", Geo.GLASS)
		h.box(Vector3(sd * 1.415 * Sc, 2.45 * Sc, 4.78 * Sc), Vector3(0.012 * Sc, 0.30 * Sc, 0.40 * Sc))
		h.color("#3a3d38", Geo.STEEL)
		h.box(Vector3(sd * 1.42 * Sc, 2.15 * Sc, 4.28 * Sc), Vector3(0.02 * Sc, 0.22 * Sc, 0.04 * Sc))
		h.box(Vector3(sd * 1.42 * Sc, 2.05 * Sc, 4.28 * Sc), Vector3(0.06 * Sc, 0.03 * Sc, 0.04 * Sc))
		h.color("#4a5240", Geo.CONCRETE)
		h.box(Vector3(sd * 1.395 * Sc, 2.85 * Sc, 4.70 * Sc), Vector3(0.012 * Sc, 0.016 * Sc, 1.15 * Sc))
		h.box(Vector3(sd * 1.395 * Sc, 1.75 * Sc, 4.70 * Sc), Vector3(0.012 * Sc, 0.016 * Sc, 1.15 * Sc))
		h.color("#96A468", Geo.CONCRETE)
		h.box(Vector3(sd * 1.42 * Sc, 1.42 * Sc, 4.55 * Sc), Vector3(0.16 * Sc, 0.06 * Sc, 0.32 * Sc))
	# Two wide panes, mirrored about the cab centre. Together they cover most of the rake.
	var pane_x := 0.50
	h.color("#9aa6aa", Geo.STEEL)
	h.plate(Vector3(-pane_x * Sc, 2.28 * Sc, 5.90 * Sc), Vector3(1.02 * Sc, 0.94 * Sc, 0.014 * Sc), Vector3(-32, 0, 0))
	h.plate(Vector3(pane_x * Sc, 2.28 * Sc, 5.90 * Sc), Vector3(1.02 * Sc, 0.94 * Sc, 0.014 * Sc), Vector3(-32, 0, 0))
	h.color("#8eb6c6", Geo.GLASS)
	h.plate(Vector3(-pane_x * Sc, 2.28 * Sc, 5.94 * Sc), Vector3(0.92 * Sc, 0.82 * Sc, 0.012 * Sc), Vector3(-32, 0, 0))
	h.plate(Vector3(pane_x * Sc, 2.28 * Sc, 5.94 * Sc), Vector3(0.92 * Sc, 0.82 * Sc, 0.012 * Sc), Vector3(-32, 0, 0))
	h.color("#d5dee2", Geo.STEEL)
	h.plate(Vector3(0, 2.28 * Sc, 5.95 * Sc), Vector3(0.05 * Sc, 0.82 * Sc, 0.012 * Sc), Vector3(-32, 0, 0))
	# Mirrors reach the 4,076 mm width and no further.
	for sm in [-1.0, 1.0]:
		h.tube(Vector3(sm * 1.36 * Sc, 2.55 * Sc, 5.35 * Sc), Vector3(sm * 1.92 * Sc, 2.62 * Sc, 5.48 * Sc), 0.022 * Sc, 5)
		h.color("#738252", Geo.CONCRETE)
		h.box(Vector3(sm * 1.998 * Sc, 2.58 * Sc, 5.42 * Sc), Vector3(0.07 * Sc, 0.20 * Sc, 0.14 * Sc))
		h.color("#24323a", Geo.GLASS)
		h.box(Vector3(sm * 2.03 * Sc, 2.58 * Sc, 5.42 * Sc), Vector3(0.012 * Sc, 0.14 * Sc, 0.09 * Sc))
	# Engine bay, split from the cab. Louvres on the sides and the roof, an intake, an exhaust.
	h.color("#738252", Geo.CONCRETE)
	h.cbox(Vector3(0, 2.02 * Sc, 2.72 * Sc), Vector3(2.55 * Sc, 0.88 * Sc, 2.35 * Sc), 0.02 * Sc)
	# Rear cab bulkhead overlaps the cab wall, the roof and the engine front.
	h.color("#96A468", Geo.CONCRETE)
	h.box(Vector3(0, 2.28 * Sc, 3.945 * Sc), Vector3(2.80 * Sc, 1.90 * Sc, 0.42 * Sc))
	# Sill under the cab and engine bay, overlapping the floor, the valance and the frame.
	h.box(Vector3(0, 1.48 * Sc, 3.45 * Sc), Vector3(2.80 * Sc, 0.32 * Sc, 4.20 * Sc))
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(0, 2.48 * Sc, 2.55 * Sc), Vector3(1.15 * Sc, 0.025 * Sc, 1.35 * Sc))
	for lv in 7:
		h.color("#3a3d38", Geo.STEEL)
		h.box(Vector3(0, 2.50 * Sc, (3.10 - float(lv) * 0.16) * Sc), Vector3(1.05 * Sc, 0.02 * Sc, 0.04 * Sc))
	for se in [-1.0, 1.0]:
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(se * 1.29 * Sc, 2.05 * Sc, 2.45 * Sc), Vector3(0.02 * Sc, 0.48 * Sc, 0.85 * Sc))
		for lb in 5:
			h.color("#3a3d38", Geo.STEEL)
			h.box(Vector3(se * 1.305 * Sc, (2.24 - float(lb) * 0.09) * Sc, 2.45 * Sc), Vector3(0.012 * Sc, 0.025 * Sc, 0.78 * Sc))
		_mzkt_ladder(h, se * 1.42 * Sc, 1.05 * Sc, 1.70 * Sc, 1.05 * Sc)
		h.color("#5e6848", Geo.CONCRETE)
		h.cbox(Vector3(se * 1.22 * Sc, 1.15 * Sc, 2.05 * Sc), Vector3(0.32 * Sc, 0.28 * Sc, 0.42 * Sc), 0.01 * Sc)
	h.color("#738252", Geo.CONCRETE)
	h.cbox(Vector3(-0.35 * Sc, 2.54 * Sc, 3.35 * Sc), Vector3(0.55 * Sc, 0.22 * Sc, 0.48 * Sc), 0.012 * Sc)
	h.color("#2a2c28", Geo.DARK)
	h.tube(Vector3(0.95 * Sc, 2.15 * Sc, 1.70 * Sc), Vector3(1.15 * Sc, 2.55 * Sc, 1.45 * Sc), 0.04 * Sc, 6)
	h.tube(Vector3(1.15 * Sc, 2.55 * Sc, 1.45 * Sc), Vector3(1.15 * Sc, 2.55 * Sc, 1.15 * Sc), 0.035 * Sc, 6)
	# Fuel tank one side, battery box the other, in the span between axle 2 and axle 3.
	h.color("#5e6848", Geo.CONCRETE)
	h.cbox(Vector3(-1.22 * Sc, 1.08 * Sc, -1.15 * Sc), Vector3(0.38 * Sc, 0.42 * Sc, 1.15 * Sc), 0.012 * Sc)
	h.cbox(Vector3(1.18 * Sc, 1.02 * Sc, -1.55 * Sc), Vector3(0.32 * Sc, 0.32 * Sc, 0.55 * Sc), 0.01 * Sc)
	h.color("#3a3d38", Geo.STEEL)
	h.tube(Vector3(0.55 * Sc, 1.15 * Sc, 1.2 * Sc), Vector3(0.55 * Sc, 1.15 * Sc, -0.4 * Sc), 0.018 * Sc, 4)
	h.tube(Vector3(0.55 * Sc, 1.15 * Sc, -0.4 * Sc), Vector3(0.85 * Sc, 1.05 * Sc, -0.9 * Sc), 0.016 * Sc, 4)
	# Four pads mark the bed corners. The jack markers sit on them. The bed itself stays empty.
	for spec in [[1.0, 0.35], [-1.0, 0.35], [1.0, -5.55], [-1.0, -5.55]]:
		h.box(Vector3(spec[0] * 1.42 * Sc, 1.62 * Sc, spec[1] * Sc), Vector3(0.18 * Sc, 0.04 * Sc, 0.22 * Sc))
	var mount := VK._n3(model, root, "ModuleMount", Vector3(0, 1.62 * Sc, -2.05 * Sc))
	mount.set_meta("deck_top_m", 1.62)
	var jacks := VK._n3(model, root, "JackPoints")
	for spec2 in [["JackFR", 1.0, 0.35], ["JackFL", -1.0, 0.35], ["JackRR", 1.0, -5.55], ["JackRL", -1.0, -5.55]]:
		var mk := Marker3D.new()
		mk.name = String(spec2[0])
		mk.position = Vector3(float(spec2[1]) * 1.42 * Sc, 1.62 * Sc, float(spec2[2]) * Sc)
		jacks.add_child(mk)
		mk.owner = root
	_save(root, model, h, mat, "res://view/units/ecc/mzkt_base.tscn", 1.22, [])

## Module B, the radar. Unwired. Origin is ModuleRoot, which sits on the chassis
## ModuleMount (deck centre, 1.62 m). +Z points at the cab. The bed in this frame
## runs from z = -4.03 m to z = 3.53 m and x = ±1.575 m. Nothing crosses x = ±1.575.
static func mzkt_radar(mat: Material) -> void:
	var Sc := 0.311
	var root := Node3D.new()
	root.name = "ModuleRoot"
	var h = K.new()
	h.plain = true
	# Cabin on the rear half of the bed. The floor overlaps the deck by 30 mm.
	var zc := -1.725
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0, 1.05 * Sc, zc * Sc), Vector3(2.96 * Sc, 2.16 * Sc, 3.95 * Sc), 0.04 * Sc)
	h.color("#738252", Geo.CONCRETE)
	h.box(Vector3(1.485 * Sc, 1.15 * Sc, zc * Sc), Vector3(0.012 * Sc, 0.018 * Sc, 3.55 * Sc))
	h.box(Vector3(1.485 * Sc, 0.42 * Sc, zc * Sc), Vector3(0.012 * Sc, 0.018 * Sc, 3.55 * Sc))
	h.box(Vector3(-1.485 * Sc, 1.15 * Sc, zc * Sc), Vector3(0.012 * Sc, 0.018 * Sc, 3.55 * Sc))
	# Door, near side, with a recess, hinge straps and a latch.
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(1.492 * Sc, 1.08 * Sc, -1.05 * Sc), Vector3(0.028 * Sc, 1.32 * Sc, 0.72 * Sc))
	h.color("#96A468", Geo.CONCRETE)
	h.box(Vector3(1.508 * Sc, 1.08 * Sc, -1.05 * Sc), Vector3(0.016 * Sc, 1.18 * Sc, 0.60 * Sc))
	h.color("#2c302c", Geo.STEEL)
	h.box(Vector3(1.518 * Sc, 1.72 * Sc, -1.05 * Sc), Vector3(0.02 * Sc, 0.06 * Sc, 0.84 * Sc))
	h.box(Vector3(1.518 * Sc, 0.44 * Sc, -1.05 * Sc), Vector3(0.02 * Sc, 0.06 * Sc, 0.84 * Sc))
	h.box(Vector3(1.518 * Sc, 1.08 * Sc, -1.45 * Sc), Vector3(0.02 * Sc, 1.22 * Sc, 0.06 * Sc))
	h.box(Vector3(1.518 * Sc, 1.08 * Sc, -0.65 * Sc), Vector3(0.02 * Sc, 1.22 * Sc, 0.06 * Sc))
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(1.532 * Sc, 1.55 * Sc, -1.40 * Sc), Vector3(0.02 * Sc, 0.14 * Sc, 0.06 * Sc))
	h.box(Vector3(1.532 * Sc, 0.64 * Sc, -1.40 * Sc), Vector3(0.02 * Sc, 0.14 * Sc, 0.06 * Sc))
	h.box(Vector3(1.534 * Sc, 1.08 * Sc, -0.72 * Sc), Vector3(0.03 * Sc, 0.08 * Sc, 0.10 * Sc))
	h.box(Vector3(1.548 * Sc, 1.08 * Sc, -0.66 * Sc), Vector3(0.02 * Sc, 0.16 * Sc, 0.03 * Sc))
	# Vent grille behind the door.
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(1.488 * Sc, 1.55 * Sc, -2.45 * Sc), Vector3(0.04 * Sc, 0.46 * Sc, 0.72 * Sc))
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(1.520 * Sc, 1.80 * Sc, -2.45 * Sc), Vector3(0.03 * Sc, 0.05 * Sc, 0.78 * Sc))
	for i in 5:
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(1.516 * Sc, (1.72 - float(i) * 0.08) * Sc, -2.45 * Sc), Vector3(0.02 * Sc, 0.028 * Sc, 0.60 * Sc))
	# Rear access panel.
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(0.35 * Sc, 1.12 * Sc, -3.715 * Sc), Vector3(0.52 * Sc, 0.92 * Sc, 0.02 * Sc))
	h.color("#96A468", Geo.CONCRETE)
	h.box(Vector3(0.35 * Sc, 1.12 * Sc, -3.732 * Sc), Vector3(0.42 * Sc, 0.78 * Sc, 0.014 * Sc))
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(0.56 * Sc, 1.12 * Sc, -3.742 * Sc), Vector3(0.03 * Sc, 0.14 * Sc, 0.012 * Sc))
	# Two roof conditioners.
	for s in [-0.62, 0.55]:
		h.color("#96A468", Geo.CONCRETE)
		h.box(Vector3(s * Sc, 2.32 * Sc, -2.35 * Sc), Vector3(0.58 * Sc, 0.38 * Sc, 0.70 * Sc))
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(s * Sc, 2.52 * Sc, -2.35 * Sc), Vector3(0.40 * Sc, 0.03 * Sc, 0.48 * Sc))
		for k in 4:
			h.color("#1c1e1c", Geo.DARK)
			h.box(Vector3(s * Sc, 2.545 * Sc, (-2.52 + float(k) * 0.12) * Sc), Vector3(0.36 * Sc, 0.02 * Sc, 0.035 * Sc))
	h.color("#4e5840", Geo.CONCRETE)
	h.box(Vector3(0.05 * Sc, 2.16 * Sc, -1.15 * Sc), Vector3(0.62 * Sc, 0.04 * Sc, 0.52 * Sc))
	h.color("#96A468", Geo.CONCRETE)
	h.box(Vector3(0.08 * Sc, 2.16 * Sc, 0.18 * Sc), Vector3(0.55 * Sc, 0.06 * Sc, 0.28 * Sc))
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0.05 * Sc, 2.24 * Sc, -1.15 * Sc), Vector3(0.50 * Sc, 0.10 * Sc, 0.40 * Sc), 0.01 * Sc)
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(0.22 * Sc, 2.30 * Sc, -1.15 * Sc), Vector3(0.08 * Sc, 0.03 * Sc, 0.06 * Sc))
	# Stowage along the far side.
	h.color("#5e6848", Geo.CONCRETE)
	h.cbox(Vector3(-1.38 * Sc, 0.28 * Sc, -2.15 * Sc), Vector3(0.22 * Sc, 0.32 * Sc, 0.55 * Sc), 0.008 * Sc)
	h.cbox(Vector3(-1.36 * Sc, 0.24 * Sc, -0.35 * Sc), Vector3(0.18 * Sc, 0.26 * Sc, 0.38 * Sc), 0.008 * Sc)
	# Roof rail. Posts sit inside the rail so nothing hangs past either end.
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(1.40 * Sc, 2.30 * Sc, -1.65 * Sc), Vector3(0.022 * Sc, 0.022 * Sc, 3.30 * Sc))
	for i in 5:
		h.box(Vector3(1.40 * Sc, 2.20 * Sc, (-0.25 - float(i) * 0.70) * Sc), Vector3(0.018 * Sc, 0.18 * Sc, 0.018 * Sc))
	_mzkt_ladder(h, 1.18 * Sc, 0.02 * Sc, -3.48 * Sc, 2.02 * Sc)
	h.color("#3a3d38", Geo.STEEL)
	for ly in [0.40, 1.10, 1.75]:
		h.box(Vector3(1.33 * Sc, ly * Sc, -3.48 * Sc), Vector3(0.28 * Sc, 0.04 * Sc, 0.04 * Sc))
	# Cable run along the skirt, then up toward the pedestal.
	h.color("#141614", Geo.RUBBER)
	h.tube(Vector3(1.38 * Sc, 0.48 * Sc, 0.05 * Sc), Vector3(1.38 * Sc, 0.48 * Sc, -3.45 * Sc), 0.016 * Sc, 5)
	h.tube(Vector3(1.38 * Sc, 0.48 * Sc, -0.15 * Sc), Vector3(0.70 * Sc, 0.82 * Sc, 0.55 * Sc), 0.014 * Sc, 5)
	# Pedestal and turntable. The hinge beam is as wide as the panel and meets the barrel.
	h.color("#3a3d38", Geo.STEEL)
	h.tube(Vector3(0, 0.02 * Sc, 0.90 * Sc), Vector3(0, 0.09 * Sc, 0.90 * Sc), 0.70 * Sc, 10)
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0, 0.50 * Sc, 0.88 * Sc), Vector3(1.10 * Sc, 1.06 * Sc, 1.50 * Sc), 0.014 * Sc)
	h.color("#2c302c", Geo.STEEL)
	h.cbox(Vector3(0, 0.90 * Sc, 1.22 * Sc), Vector3(2.55 * Sc, 0.18 * Sc, 0.34 * Sc), 0.012 * Sc)
	for hx in [-1.10, -0.55, 0.0, 0.55, 1.10]:
		h.cbox(Vector3(hx * Sc, 0.98 * Sc, 1.22 * Sc), Vector3(0.08 * Sc, 0.26 * Sc, 0.32 * Sc), 0.01 * Sc)
		h.color("#1a1c1a", Geo.STEEL)
		h.box(Vector3(hx * Sc, 1.08 * Sc, 1.36 * Sc), Vector3(0.035 * Sc, 0.035 * Sc, 0.02 * Sc))
		h.color("#2c302c", Geo.STEEL)
	# Ram bodies stay on the pedestal. The rods are on the panel, so each end
	# stays with its pin when ArrayPivot turns.
	h.color("#3a3d38", Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.55 * Sc, 0.82 * Sc, 0.38 * Sc), Vector3(0.14 * Sc, 0.14 * Sc, 0.10 * Sc))
		h.tube(Vector3(s * 0.48 * Sc, 0.82 * Sc, 0.38 * Sc), Vector3(s * 0.62 * Sc, 0.82 * Sc, 0.38 * Sc), 0.035 * Sc, 6)
		h.tube(Vector3(s * 0.55 * Sc, 0.82 * Sc, 0.38 * Sc), Vector3(s * 0.66 * Sc, 2.04 * Sc, 0.50 * Sc), 0.048 * Sc, 6)
	# Both cabin sides: grilles, a wall unit, boxes, conduits, handles.
	for s in [-1.0, 1.0]:
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(s * 1.492 * Sc, 1.58 * Sc, -0.15 * Sc), Vector3(0.02 * Sc, 0.36 * Sc, 0.48 * Sc))
		for i in 4:
			h.color("#1c1e1c", Geo.DARK)
			h.box(Vector3(s * 1.508 * Sc, (1.72 - float(i) * 0.08) * Sc, -0.15 * Sc), Vector3(0.012 * Sc, 0.016 * Sc, 0.40 * Sc))
		h.color("#5e6848", Geo.CONCRETE)
		h.box(Vector3(s * 1.505 * Sc, 0.55 * Sc, -2.85 * Sc), Vector3(0.08 * Sc, 0.22 * Sc, 0.32 * Sc))
		h.color("#738252", Geo.CONCRETE)
		h.box(Vector3(s * 1.505 * Sc, 1.35 * Sc, -3.15 * Sc), Vector3(0.07 * Sc, 0.16 * Sc, 0.22 * Sc))
		h.color("#141614", Geo.RUBBER)
		h.tube(Vector3(s * 1.50 * Sc, 0.72 * Sc, 0.10 * Sc), Vector3(s * 1.50 * Sc, 0.72 * Sc, -3.35 * Sc), 0.012 * Sc, 4)
		h.tube(Vector3(s * 1.50 * Sc, 0.72 * Sc, -1.70 * Sc), Vector3(s * 1.46 * Sc, 1.55 * Sc, -1.70 * Sc), 0.010 * Sc, 4)
		h.color("#5e6848", Geo.CONCRETE)
		h.box(Vector3(s * 1.50 * Sc, 0.95 * Sc, -2.15 * Sc), Vector3(0.10 * Sc, 0.28 * Sc, 0.36 * Sc))
		h.color("#3a3d38", Geo.STEEL)
		h.box(Vector3(s * 1.530 * Sc, 1.15 * Sc, -0.55 * Sc), Vector3(0.03 * Sc, 0.04 * Sc, 0.18 * Sc))
		h.box(Vector3(s * 1.530 * Sc, 0.85 * Sc, -1.85 * Sc), Vector3(0.03 * Sc, 0.04 * Sc, 0.18 * Sc))
		for cz in [-0.4, -1.5, -2.6]:
			h.box(Vector3(s * 1.52 * Sc, 0.72 * Sc, cz * Sc), Vector3(0.045 * Sc, 0.045 * Sc, 0.03 * Sc))
	# Wall conditioner on the far side, extinguisher and reel on the near side.
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(-1.50 * Sc, 1.52 * Sc, -0.85 * Sc), Vector3(0.12 * Sc, 0.42 * Sc, 0.50 * Sc), 0.01 * Sc)
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(-1.555 * Sc, 1.52 * Sc, -0.85 * Sc), Vector3(0.016 * Sc, 0.26 * Sc, 0.36 * Sc))
	for k in 3:
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(-1.566 * Sc, 1.52 * Sc, (-0.96 + float(k) * 0.10) * Sc), Vector3(0.012 * Sc, 0.20 * Sc, 0.022 * Sc))
	h.color("#c4382e", Geo.CONCRETE)
	h.tube(Vector3(1.52 * Sc, 0.42 * Sc, -1.85 * Sc), Vector3(1.52 * Sc, 0.78 * Sc, -1.85 * Sc), 0.045 * Sc, 5)
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(1.52 * Sc, 0.84 * Sc, -1.85 * Sc), Vector3(0.07 * Sc, 0.04 * Sc, 0.07 * Sc))
	h.tube(Vector3(-1.46 * Sc, 0.48 * Sc, -2.55 * Sc), Vector3(-1.54 * Sc, 0.48 * Sc, -2.55 * Sc), 0.13 * Sc, 8)
	h.box(Vector3(-1.54 * Sc, 0.48 * Sc, -2.55 * Sc), Vector3(0.02 * Sc, 0.22 * Sc, 0.03 * Sc))
	# Deck fittings around the mast and the pedestal. All sit on the deck.
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(1.05 * Sc, 0.40 * Sc, 0.72 * Sc), Vector3(0.62 * Sc, 0.84 * Sc, 0.78 * Sc), 0.012 * Sc)
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(1.345 * Sc, 0.40 * Sc, 0.72 * Sc), Vector3(0.012 * Sc, 0.32 * Sc, 0.48 * Sc))
	for k in 4:
		h.color("#1c1e1c", Geo.DARK)
		h.box(Vector3(1.354 * Sc, (0.52 - float(k) * 0.07) * Sc, 0.72 * Sc), Vector3(0.008 * Sc, 0.016 * Sc, 0.40 * Sc))
	h.color("#6b4e32", Geo.WOOD)
	h.box(Vector3(-0.15 * Sc, 0.24 * Sc, 2.30 * Sc), Vector3(0.50 * Sc, 0.52 * Sc, 0.44 * Sc))
	h.box(Vector3(-1.32 * Sc, 0.20 * Sc, 1.55 * Sc), Vector3(0.40 * Sc, 0.42 * Sc, 0.36 * Sc))
	h.color("#4a4e46", Geo.STEEL)
	h.box(Vector3(0.95 * Sc, 0.14 * Sc, 2.28 * Sc), Vector3(0.36 * Sc, 0.28 * Sc, 0.24 * Sc))
	h.color("#6a7348", Geo.CANVAS)
	h.box(Vector3(0.55 * Sc, 0.18 * Sc, 2.62 * Sc), Vector3(0.22 * Sc, 0.36 * Sc, 0.30 * Sc))
	h.color("#7a5a3a", Geo.WOOD)
	h.box(Vector3(1.40 * Sc, 0.14 * Sc, 0.02 * Sc), Vector3(0.28 * Sc, 0.28 * Sc, 0.24 * Sc))
	h.color("#5c6844", Geo.CANVAS)
	h.box(Vector3(-0.55 * Sc, 0.12 * Sc, 2.72 * Sc), Vector3(0.40 * Sc, 0.24 * Sc, 0.28 * Sc))
	h.color("#6a6e66", Geo.STEEL)
	h.tube(Vector3(1.20 * Sc, 0.18 * Sc, 1.55 * Sc), Vector3(1.20 * Sc, 0.18 * Sc, 1.92 * Sc), 0.18 * Sc, 8)
	h.box(Vector3(1.20 * Sc, 0.15 * Sc, 1.55 * Sc), Vector3(0.04 * Sc, 0.22 * Sc, 0.04 * Sc))
	h.color("#3a3d38", Geo.STEEL)
	for td in [[1.42, 2.55], [-1.42, 2.55], [1.42, 0.18], [-0.85, 2.70]]:
		h.box(Vector3(td[0] * Sc, 0.015 * Sc, td[1] * Sc), Vector3(0.14 * Sc, 0.03 * Sc, 0.08 * Sc))
	# Mast plinth on the open deck ahead of the array, near side of the bed.
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(-1.12 * Sc, 0.20 * Sc, 2.05 * Sc), Vector3(0.42 * Sc, 0.46 * Sc, 0.42 * Sc), 0.01 * Sc)
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(-0.72 * Sc, 0.05 * Sc, 2.35 * Sc), Vector3(0.10 * Sc, 0.10 * Sc, 0.08 * Sc))
	h.box(Vector3(-1.48 * Sc, 0.05 * Sc, 2.45 * Sc), Vector3(0.08 * Sc, 0.10 * Sc, 0.10 * Sc))
	h.box(Vector3(-1.45 * Sc, 0.05 * Sc, 1.25 * Sc), Vector3(0.10 * Sc, 0.10 * Sc, 0.08 * Sc))
	VK._mi(root, root, "Hull", h.commit(mat))
	# Hinge. The -25 degree pitch is the raised pose; a later animation drives this node.
	var pivot := VK._n3(root, root, "ArrayPivot", Vector3(0, 0.92 * Sc, 1.28 * Sc))
	pivot.rotation_degrees = Vector3(-25, 0, 0)
	var p = K.new()
	p.plain = true
	p.color("#3a4538", Geo.WOOD)
	p.box(Vector3(0, 2.16 * Sc, 0.08 * Sc), Vector3(2.52 * Sc, 4.36 * Sc, 0.14 * Sc))
	p.color("#2a2e2c", Geo.STEEL)
	p.box(Vector3(0, 4.32 * Sc, 0.20 * Sc), Vector3(2.74 * Sc, 0.12 * Sc, 0.07 * Sc))
	p.box(Vector3(0, 0.04 * Sc, 0.10 * Sc), Vector3(2.74 * Sc, 0.14 * Sc, 0.12 * Sc))
	p.box(Vector3(-1.32 * Sc, 2.18 * Sc, 0.20 * Sc), Vector3(0.12 * Sc, 4.28 * Sc, 0.07 * Sc))
	p.box(Vector3(1.32 * Sc, 2.18 * Sc, 0.20 * Sc), Vector3(0.12 * Sc, 4.28 * Sc, 0.07 * Sc))
	# Shallow tiles. 8 by 10, inset from the frame.
	p.color("#465242", Geo.WOOD)
	var cols := 8
	var rows := 10
	var gx0 := -1.16
	var gx1 := 1.16
	var gy0 := 0.24
	var gy1 := 4.16
	var cw := (gx1 - gx0) / float(cols)
	var rh := (gy1 - gy0) / float(rows)
	for r in rows:
		for c in cols:
			var cx := gx0 + cw * (float(c) + 0.5)
			var cy := gy0 + rh * (float(r) + 0.5)
			p.box(Vector3(cx * Sc, cy * Sc, 0.180 * Sc), Vector3(cw * 0.82 * Sc, rh * 0.78 * Sc, 0.030 * Sc))
	# Back box frame, ribs and edge braces.
	p.color("#2a2e2c", Geo.STEEL)
	p.box(Vector3(0, 4.15 * Sc, -0.04 * Sc), Vector3(2.40 * Sc, 0.08 * Sc, 0.06 * Sc))
	p.box(Vector3(0, 0.35 * Sc, -0.04 * Sc), Vector3(2.40 * Sc, 0.08 * Sc, 0.06 * Sc))
	p.box(Vector3(-1.16 * Sc, 2.25 * Sc, -0.04 * Sc), Vector3(0.08 * Sc, 3.80 * Sc, 0.06 * Sc))
	p.box(Vector3(1.16 * Sc, 2.25 * Sc, -0.04 * Sc), Vector3(0.08 * Sc, 3.80 * Sc, 0.06 * Sc))
	for bx in [-0.70, 0.0, 0.70]:
		p.box(Vector3(bx * Sc, 2.25 * Sc, -0.02 * Sc), Vector3(0.08 * Sc, 3.40 * Sc, 0.05 * Sc))
	p.box(Vector3(0, 1.20 * Sc, -0.03 * Sc), Vector3(2.20 * Sc, 0.06 * Sc, 0.04 * Sc))
	p.box(Vector3(0, 3.20 * Sc, -0.03 * Sc), Vector3(2.20 * Sc, 0.06 * Sc, 0.04 * Sc))
	p.color("#32362f", Geo.STEEL)
	p.box(Vector3(-1.22 * Sc, 3.6 * Sc, 0.02 * Sc), Vector3(0.08 * Sc, 0.9 * Sc, 0.08 * Sc))
	p.box(Vector3(1.22 * Sc, 3.6 * Sc, 0.02 * Sc), Vector3(0.08 * Sc, 0.9 * Sc, 0.08 * Sc))
	p.color("#3a3d38", Geo.STEEL)
	p.tube(Vector3(-1.22 * Sc, 0, 0), Vector3(1.22 * Sc, 0, 0), 0.055 * Sc, 8)
	for s in [-1.0, 1.0]:
		p.color("#2a2e2c", Geo.STEEL)
		p.box(Vector3(s * 0.70 * Sc, 1.70 * Sc, -0.05 * Sc), Vector3(0.14 * Sc, 0.14 * Sc, 0.08 * Sc))
		p.tube(Vector3(s * 0.62 * Sc, 1.70 * Sc, -0.05 * Sc), Vector3(s * 0.78 * Sc, 1.70 * Sc, -0.05 * Sc), 0.032 * Sc, 6)
		p.color("#f2f4f6", Geo.STEEL)
		p.tube(Vector3(s * 0.70 * Sc, 1.70 * Sc, -0.02 * Sc), Vector3(s * 0.61 * Sc, 0.85 * Sc, -0.52 * Sc), 0.026 * Sc, 5)
	# Two bundles. At the 25 degree pose their lower ends sit on the cabin roof pad.
	p.color("#141614", Geo.RUBBER)
	p.tube(Vector3(0.20 * Sc, 2.40 * Sc, -0.06 * Sc), Vector3(0.20 * Sc, 1.58 * Sc, -0.51 * Sc), 0.016 * Sc, 4)
	p.tube(Vector3(-0.25 * Sc, 2.20 * Sc, -0.06 * Sc), Vector3(-0.05 * Sc, 1.55 * Sc, -0.50 * Sc), 0.014 * Sc, 4)
	p.color("#2a2e2c", Geo.STEEL)
	p.box(Vector3(0.72 * Sc, 1.25 * Sc, -0.02 * Sc), Vector3(0.26 * Sc, 0.20 * Sc, 0.10 * Sc))
	p.color("#141614", Geo.RUBBER)
	p.tube(Vector3(0.72 * Sc, 1.12 * Sc, -0.02 * Sc), Vector3(0.20 * Sc, 0.08 * Sc, 0.0), 0.012 * Sc, 4)
	VK._mi(pivot, root, "Panel", p.commit(mat))
	var mast := VK._n3(root, root, "MastPivot", Vector3(-1.12 * Sc, 0.42 * Sc, 2.05 * Sc))
	var g = K.new()
	g.plain = true
	g.color("#2a2e2c", Geo.STEEL)
	g.box(Vector3(0, 0.015 * Sc, 0), Vector3(0.28 * Sc, 0.05 * Sc, 0.28 * Sc))
	g.color("#2c302c", Geo.STEEL)
	g.tube(Vector3.ZERO, Vector3(0, 1.50 * Sc, 0), 0.050 * Sc, 6)
	g.tube(Vector3(0, 1.32 * Sc, 0), Vector3(0, 2.70 * Sc, 0), 0.036 * Sc, 6)
	g.tube(Vector3(0, 2.52 * Sc, 0), Vector3(0, 3.80 * Sc, 0), 0.024 * Sc, 6)
	g.color("#3a3d38", Geo.STEEL)
	g.box(Vector3(0, 0.08 * Sc, 0), Vector3(0.18 * Sc, 0.08 * Sc, 0.18 * Sc))
	g.color("#8a8e86", Geo.STEEL)
	g.tube(Vector3(0, 1.32 * Sc, 0), Vector3(0, 1.52 * Sc, 0), 0.070 * Sc, 6)
	g.tube(Vector3(0, 2.50 * Sc, 0), Vector3(0, 2.70 * Sc, 0), 0.052 * Sc, 6)
	g.color("#3a3d38", Geo.STEEL)
	var guys := [Vector2(0.40, 0.30), Vector2(-0.36, 0.40), Vector2(-0.33, -0.80)]
	for i in guys.size():
		var lug: Vector2 = guys[i]
		g.box(Vector3(lug.x * 0.15 * Sc, 0.36 * Sc, lug.y * 0.15 * Sc), Vector3(0.04 * Sc, 0.04 * Sc, 0.04 * Sc))
		g.tube(Vector3(lug.x * 0.12 * Sc, 0.36 * Sc, lug.y * 0.12 * Sc), Vector3(lug.x * Sc, -0.36 * Sc, lug.y * Sc), 0.008 * Sc, 4)
	# Sensor head: a short boom, six elements, a box and a whip.
	g.tube(Vector3(0, 3.88 * Sc, -0.22 * Sc), Vector3(0, 3.88 * Sc, 0.36 * Sc), 0.010 * Sc, 4)
	for i in 6:
		var ez := -0.16 + float(i) * 0.09
		var span := 0.10 + float(i) * 0.018
		g.tube(Vector3(-span * Sc, 3.88 * Sc, ez * Sc), Vector3(span * Sc, 3.88 * Sc, ez * Sc), 0.005 * Sc, 4)
	g.color("#5c6058", Geo.STEEL)
	g.box(Vector3(0, 4.00 * Sc, 0.02 * Sc), Vector3(0.14 * Sc, 0.10 * Sc, 0.16 * Sc))
	g.color("#3a3d38", Geo.STEEL)
	g.tube(Vector3(0, 3.85 * Sc, 0), Vector3(0, 4.30 * Sc, 0), 0.007 * Sc, 4)
	VK._mi(mast, root, "Mast", g.commit(mat))
	var tris: int = h.tris + p.tris + g.tris
	print("  mzkt_radar_module.tscn: %d tris" % tris)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://view/units/ecc/mzkt_radar_module.tscn")
	root.free()

## Module C, cruise-missile launcher. Unwired. ModuleRoot sits on ModuleMount.
## +Z points at the cab. The bed runs z = -4.03 to 3.53 m and x = ±1.575 m.
## LauncherPivot is the raised pose, 38 degrees, hinge toward the cab.
static func mzkt_missile(mat: Material) -> void:
	var Sc := 0.311
	var root := Node3D.new()
	root.name = "ModuleRoot"
	var h = K.new()
	h.plain = true
	# Pedestal under the hinge, biting the deck.
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0, 0.32 * Sc, 0.85 * Sc), Vector3(1.35 * Sc, 0.68 * Sc, 1.15 * Sc), 0.014 * Sc)
	h.color("#3a3d38", Geo.STEEL)
	h.tube(Vector3(0, 0.02 * Sc, 0.85 * Sc), Vector3(0, 0.08 * Sc, 0.85 * Sc), 0.55 * Sc, 8)
	# Hinge beam and clevis plates. The barrel lives on the cradle.
	h.color("#2c302c", Geo.STEEL)
	h.cbox(Vector3(0, 0.50 * Sc, 1.05 * Sc), Vector3(2.15 * Sc, 0.16 * Sc, 0.32 * Sc), 0.01 * Sc)
	for hx in [-0.90, -0.32, 0.32, 0.90]:
		h.cbox(Vector3(hx * Sc, 0.60 * Sc, 1.05 * Sc), Vector3(0.07 * Sc, 0.24 * Sc, 0.28 * Sc), 0.008 * Sc)
		h.color("#1a1c1a", Geo.STEEL)
		h.box(Vector3(hx * Sc, 0.70 * Sc, 1.18 * Sc), Vector3(0.03 * Sc, 0.03 * Sc, 0.016 * Sc))
		h.color("#2c302c", Geo.STEEL)
	# Equipment box toward the cab, on the deck.
	h.color("#96A468", Geo.CONCRETE)
	h.cbox(Vector3(0, 0.58 * Sc, 2.35 * Sc), Vector3(1.55 * Sc, 1.20 * Sc, 1.35 * Sc), 0.016 * Sc)
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(0.79 * Sc, 0.62 * Sc, 2.35 * Sc), Vector3(0.03 * Sc, 0.72 * Sc, 0.48 * Sc))
	h.color("#738252", Geo.CONCRETE)
	h.box(Vector3(0.805 * Sc, 0.62 * Sc, 2.35 * Sc), Vector3(0.016 * Sc, 0.60 * Sc, 0.38 * Sc))
	h.color("#3a3d38", Geo.STEEL)
	h.box(Vector3(0.82 * Sc, 0.88 * Sc, 2.55 * Sc), Vector3(0.016 * Sc, 0.08 * Sc, 0.04 * Sc))
	h.box(Vector3(0.82 * Sc, 0.62 * Sc, 2.12 * Sc), Vector3(0.02 * Sc, 0.06 * Sc, 0.08 * Sc))
	h.color("#1c1e1c", Geo.DARK)
	h.box(Vector3(0.79 * Sc, 0.95 * Sc, 2.85 * Sc), Vector3(0.02 * Sc, 0.22 * Sc, 0.28 * Sc))
	for i in 3:
		h.box(Vector3(0.805 * Sc, (1.02 - float(i) * 0.06) * Sc, 2.85 * Sc), Vector3(0.012 * Sc, 0.016 * Sc, 0.22 * Sc))
	h.color("#141614", Geo.RUBBER)
	h.tube(Vector3(0.7 * Sc, 0.35 * Sc, 1.55 * Sc), Vector3(0.55 * Sc, 0.48 * Sc, 0.7 * Sc), 0.014 * Sc, 4)
	h.tube(Vector3(-0.55 * Sc, 0.30 * Sc, 1.70 * Sc), Vector3(-0.4 * Sc, 0.42 * Sc, 0.85 * Sc), 0.012 * Sc, 4)
	# Ram plinths on the rear of the pedestal. The pins are the aft face, so the rams leave clear of the block.
	for sx in [-0.55, 0.55]:
		h.color("#96A468", Geo.CONCRETE)
		h.box(Vector3(sx * Sc, 0.66 * Sc, 0.42 * Sc), Vector3(0.24 * Sc, 0.12 * Sc, 0.20 * Sc))
		h.color("#2c302c", Geo.STEEL)
		h.box(Vector3((sx - 0.07) * Sc, 0.78 * Sc, 0.30 * Sc), Vector3(0.035 * Sc, 0.14 * Sc, 0.14 * Sc))
		h.box(Vector3((sx + 0.07) * Sc, 0.78 * Sc, 0.30 * Sc), Vector3(0.035 * Sc, 0.14 * Sc, 0.14 * Sc))
		h.color("#1a1c1a", Geo.STEEL)
		h.box(Vector3(sx * Sc, 0.72 * Sc, 0.30 * Sc), Vector3(0.16 * Sc, 0.03 * Sc, 0.03 * Sc))
	# Deck stowage, inboard of the outrigger lane (|x| stays under 1.30 m).
	h.color("#6b4e32", Geo.WOOD)
	h.box(Vector3(-0.90 * Sc, 0.18 * Sc, 2.85 * Sc), Vector3(0.42 * Sc, 0.36 * Sc, 0.38 * Sc))
	h.color("#5c6844", Geo.CANVAS)
	h.box(Vector3(0.90 * Sc, 0.12 * Sc, 0.55 * Sc), Vector3(0.36 * Sc, 0.24 * Sc, 0.28 * Sc))
	h.color("#6a6e66", Geo.STEEL)
	h.tube(Vector3(-0.85 * Sc, 0.16 * Sc, 0.05 * Sc), Vector3(-0.85 * Sc, 0.16 * Sc, 0.45 * Sc), 0.16 * Sc, 8)
	h.color("#4a4e46", Geo.STEEL)
	h.box(Vector3(0.88 * Sc, 0.10 * Sc, 3.15 * Sc), Vector3(0.32 * Sc, 0.20 * Sc, 0.24 * Sc))
	VK._mi(root, root, "Hull", h.commit(mat))
	var piv := VK._n3(root, root, "LauncherPivot", Vector3(0, 0.58 * Sc, 1.05 * Sc))
	var c = K.new()
	c.plain = true
	# Four long canisters, two wide and two high, running back from the hinge.
	c.color("#738252", Geo.CONCRETE)
	for sx in [-0.46, 0.46]:
		for sy in [0.46, 1.18]:
			c.box(Vector3(sx * Sc, sy * Sc, -2.55 * Sc), Vector3(0.78 * Sc, 0.58 * Sc, 4.50 * Sc))
			c.color("#4e5840", Geo.CONCRETE)
			c.box(Vector3(sx * Sc, sy * Sc, -2.55 * Sc), Vector3(0.80 * Sc, 0.03 * Sc, 4.30 * Sc))
			c.color("#738252", Geo.CONCRETE)
	# Cradle rails and end lattice.
	c.color("#2c302c", Geo.STEEL)
	c.box(Vector3(-1.00 * Sc, 0.10 * Sc, -2.45 * Sc), Vector3(0.08 * Sc, 0.14 * Sc, 4.70 * Sc))
	c.box(Vector3(1.00 * Sc, 0.10 * Sc, -2.45 * Sc), Vector3(0.08 * Sc, 0.14 * Sc, 4.70 * Sc))
	c.box(Vector3(0, 1.52 * Sc, -2.45 * Sc), Vector3(2.08 * Sc, 0.06 * Sc, 0.06 * Sc))
	for ez in [-0.40, -2.50, -4.70]:
		c.box(Vector3(0, 0.10 * Sc, ez * Sc), Vector3(2.00 * Sc, 0.08 * Sc, 0.06 * Sc))
	for side in [-1.0, 1.0]:
		c.box(Vector3(side * 0.96 * Sc, 0.80 * Sc, -4.72 * Sc), Vector3(0.05 * Sc, 1.40 * Sc, 0.05 * Sc))
		c.box(Vector3(side * 0.96 * Sc, 0.80 * Sc, -0.38 * Sc), Vector3(0.05 * Sc, 1.40 * Sc, 0.05 * Sc))
	c.box(Vector3(0, 1.48 * Sc, -4.72 * Sc), Vector3(1.90 * Sc, 0.05 * Sc, 0.05 * Sc))
	c.box(Vector3(0, 0.78 * Sc, -4.72 * Sc), Vector3(1.90 * Sc, 0.05 * Sc, 0.05 * Sc))
	# Hinge barrel. Upper ram eyes stay on the cradle. The rams are sibling nodes of the pivot.
	c.tube(Vector3(-1.05 * Sc, 0, 0), Vector3(1.05 * Sc, 0, 0), 0.05 * Sc, 8)
	for s in [-1.0, 1.0]:
		c.color("#2a2e2c", Geo.STEEL)
		c.box(Vector3(s * 0.55 * Sc, 0.22 * Sc, -1.40 * Sc), Vector3(0.08 * Sc, 0.10 * Sc, 0.12 * Sc))
		c.tube(Vector3(s * 0.46 * Sc, 0.22 * Sc, -1.40 * Sc), Vector3(s * 0.64 * Sc, 0.22 * Sc, -1.40 * Sc), 0.026 * Sc, 6)
	for s2 in [-1.0, 1.0]:
		var eye := Marker3D.new()
		eye.name = "EyeR" if s2 > 0.0 else "EyeL"
		eye.position = Vector3(s2 * 0.55 * Sc, 0.22 * Sc, -1.40 * Sc)
		piv.add_child(eye)
		eye.owner = root
	VK._mi(piv, root, "Cradle", c.commit(mat))
	var tris: int = h.tris + c.tris
	tris += _missile_rams(root, mat, Sc)
	tris += _missile_outriggers(root, mat, Sc)
	_missile_anims(root)
	print("  mzkt_missile_module.tscn: %d tris" % tris)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://view/units/ecc/mzkt_missile_module.tscn")
	root.free()

## Upper eye, module metres. Positive X rotation lifts the rear of the cradle.
static func _missile_eye_m(alpha: float, side: float) -> Vector3:
	return Vector3(0, 0.58, 1.05) + Basis(Vector3.RIGHT, alpha) * Vector3(side * 0.55, 0.22, -1.40)

static func _missile_clevis_m(side: float) -> Vector3:
	return Vector3(side * 0.55, 0.72, 0.30)

## Local +Z points along dir. Local +X stays level.
static func _aim_z(dir: Vector3) -> Basis:
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 1e-4:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x).normalized(), z)

## Two cradle rams. Cylinder and rod share a pivot, and the rod slides along it,
## so the pair stays one piece from the stowed pin to the raised pin.
static func _missile_rams(root: Node3D, mat: Material, Sc: float) -> int:
	var tris := 0
	var raise := deg_to_rad(38.0)
	for side in [-1.0, 1.0]:
		var s: float = side
		var clevis := _missile_clevis_m(s)
		var d0 := _missile_eye_m(0.0, s).distance_to(clevis)
		var d1 := _missile_eye_m(raise, s).distance_to(clevis)
		var rod_len := d0 - 0.05
		var cyl_end := d0 - 0.12
		var deploy_pos := d1 - rod_len
		var overlap := cyl_end - deploy_pos
		print("  ram side %.0f  stow %.3f m  deploy %.3f m  overlap %.3f m" % [s, d0, d1, overlap])
		var ram := VK._n3(root, root, "RamR" if s > 0.0 else "RamL", clevis * Sc)
		ram.basis = _aim_z(_missile_eye_m(0.0, s) - clevis)
		ram.set_meta("rod_len_m", rod_len)
		var g = K.new()
		g.plain = true
		g.color("#2a2e2c", Geo.STEEL)
		g.tube(Vector3(-0.045 * Sc, 0, 0), Vector3(0.045 * Sc, 0, 0), 0.032 * Sc, 8)
		g.box(Vector3(0, 0, 0.045 * Sc), Vector3(0.08 * Sc, 0.07 * Sc, 0.06 * Sc))
		g.color("#3a3d38", Geo.STEEL)
		g.tube(Vector3(0, 0, 0.09 * Sc), Vector3(0, 0, cyl_end * Sc), 0.052 * Sc, 10)
		g.tube(Vector3(0, 0, (cyl_end - 0.04) * Sc), Vector3(0, 0, (cyl_end + 0.012) * Sc), 0.064 * Sc, 10)
		VK._mi(ram, root, "Cylinder", g.commit(mat))
		tris += g.tris
		var rod := VK._n3(ram, root, "Rod", Vector3(0, 0, 0.05 * Sc))
		rod.set_meta("stow_z", 0.05 * Sc)
		rod.set_meta("deploy_z", deploy_pos * Sc)
		var r = K.new()
		r.plain = true
		r.color("#d8dcd8", Geo.STEEL)
		r.tube(Vector3(0, 0, 0), Vector3(0, 0, (rod_len - 0.07) * Sc), 0.028 * Sc, 8)
		r.color("#f2f4f6", Geo.STEEL)
		r.tube(Vector3(0, 0, (rod_len - 0.16) * Sc), Vector3(0, 0, (rod_len - 0.07) * Sc), 0.034 * Sc, 8)
		r.color("#2a2e2c", Geo.STEEL)
		r.box(Vector3(-0.062 * Sc, 0, (rod_len - 0.045) * Sc), Vector3(0.022 * Sc, 0.09 * Sc, 0.06 * Sc))
		r.box(Vector3(0.062 * Sc, 0, (rod_len - 0.045) * Sc), Vector3(0.022 * Sc, 0.09 * Sc, 0.06 * Sc))
		VK._mi(rod, root, "RodMesh", r.commit(mat))
		tris += r.tris
		var tip := Marker3D.new()
		tip.name = "Tip"
		tip.position = Vector3(0, 0, rod_len * Sc)
		rod.add_child(tip)
		tip.owner = root
	return tris

## Four swing-out jacks on the chassis JackFL/FR/RL/RR points (module frame).
## Stowed, the arm lies along the bed and the leg folds back along it, inside 3.15 m.
## Deployed, the arm is straight out and the pad sole is on the ground (module y = -1.62).
static func _missile_outriggers(root: Node3D, mat: Material, Sc: float) -> int:
	var tris := 0
	var arm_len := 1.28
	var arm_y := 0.40
	var hinge_drop := 0.22
	var rod_len := 1.05
	var cyl_end := 0.90
	var hinge_y := arm_y - hinge_drop
	var deploy_tip := (hinge_y - (-1.62)) - 0.025
	var deploy_pos := deploy_tip - rod_len
	var stow_pos := 0.08
	print("  jack rod overlap %.3f m, deploy tip %.3f m, stow outer x %.3f m" % [cyl_end - deploy_pos, deploy_tip, 1.42 + 0.12])
	# Not named Outriggers: VehicleView claims that node and lifts it for the anti-air plant.
	var group := VK._n3(root, root, "Jacks")
	for spec in [["OutriggerFR", 1.0, 1.0], ["OutriggerFL", -1.0, 1.0], ["OutriggerRR", 1.0, -1.0], ["OutriggerRL", -1.0, -1.0]]:
		var s: float = float(spec[1])
		var front: float = float(spec[2])
		var z: float = 2.40 if front > 0.0 else -3.50
		var mount := VK._n3(group, root, String(spec[0]), Vector3(s * 1.42 * Sc, 0, z * Sc))
		var housing = K.new()
		housing.plain = true
		housing.color("#5e6848", Geo.CONCRETE)
		housing.cbox(Vector3(0, 0.18 * Sc, 0), Vector3(0.22 * Sc, 0.36 * Sc, 0.26 * Sc), 0.012 * Sc)
		housing.color("#2c302c", Geo.STEEL)
		housing.tube(Vector3(0, 0.36 * Sc, 0), Vector3(0, arm_y * Sc, 0), 0.07 * Sc, 8)
		VK._mi(mount, root, "Housing", housing.commit(mat))
		tris += housing.tris
		var stow_yaw := s * (90.0 if front > 0.0 else -90.0)
		var swing := VK._n3(mount, root, "Swing", Vector3(0, arm_y * Sc, 0))
		swing.rotation_degrees = Vector3(0, stow_yaw, 0)
		swing.set_meta("stow_yaw", stow_yaw)
		var arm = K.new()
		arm.plain = true
		arm.color("#2c302c", Geo.STEEL)
		arm.box(Vector3(s * arm_len * 0.5 * Sc, 0, 0), Vector3(arm_len * Sc, 0.08 * Sc, 0.14 * Sc))
		arm.color("#3a3d38", Geo.STEEL)
		arm.box(Vector3(s * 0.10 * Sc, 0.02 * Sc, 0), Vector3(0.16 * Sc, 0.10 * Sc, 0.16 * Sc))
		arm.tube(Vector3(s * (arm_len - 0.02) * Sc, 0, 0), Vector3(s * arm_len * Sc, -hinge_drop * Sc, 0), 0.04 * Sc, 6)
		VK._mi(swing, root, "Arm", arm.commit(mat))
		tris += arm.tris
		var hinge := VK._n3(swing, root, "LegHinge", Vector3(s * arm_len * Sc, -hinge_drop * Sc, 0))
		hinge.rotation_degrees = Vector3(0, 0, -90.0 * s)
		hinge.set_meta("stow_roll", -90.0 * s)
		var leg = K.new()
		leg.plain = true
		leg.color("#2a2e2c", Geo.STEEL)
		leg.box(Vector3(0, -0.03 * Sc, 0), Vector3(0.10 * Sc, 0.08 * Sc, 0.10 * Sc))
		leg.tube(Vector3(0, -0.05 * Sc, 0), Vector3(0, -cyl_end * Sc, 0), 0.048 * Sc, 10)
		leg.tube(Vector3(0, -(cyl_end - 0.035) * Sc, 0), Vector3(0, -(cyl_end + 0.012) * Sc, 0), 0.060 * Sc, 10)
		VK._mi(hinge, root, "Leg", leg.commit(mat))
		tris += leg.tris
		var rod := VK._n3(hinge, root, "Rod", Vector3(0, -stow_pos * Sc, 0))
		rod.set_meta("stow_y", -stow_pos * Sc)
		rod.set_meta("deploy_y", -deploy_pos * Sc)
		var rm = K.new()
		rm.plain = true
		rm.color("#d8dcd8", Geo.STEEL)
		rm.tube(Vector3(0, 0, 0), Vector3(0, -(rod_len - 0.04) * Sc, 0), 0.026 * Sc, 8)
		rm.color("#f2f4f6", Geo.STEEL)
		rm.tube(Vector3(0, -(rod_len - 0.12) * Sc, 0), Vector3(0, -rod_len * Sc, 0), 0.032 * Sc, 8)
		rm.color("#3a3d38", Geo.STEEL)
		rm.box(Vector3(0, -rod_len * Sc, 0), Vector3(0.32 * Sc, 0.05 * Sc, 0.24 * Sc))
		rm.color("#2c302c", Geo.STEEL)
		rm.box(Vector3(0, -(rod_len - 0.02) * Sc, 0), Vector3(0.18 * Sc, 0.03 * Sc, 0.10 * Sc))
		for bx in [-0.10, 0.10]:
			for bz in [-0.07, 0.07]:
				rm.color("#1a1c1a", Geo.STEEL)
				rm.tube(Vector3(bx * Sc, -(rod_len - 0.04) * Sc, bz * Sc), Vector3(bx * Sc, -(rod_len - 0.012) * Sc, bz * Sc), 0.012 * Sc, 6)
		VK._mi(rod, root, "RodMesh", rm.commit(mat))
		tris += rm.tris
		var sole := Marker3D.new()
		sole.name = "Sole"
		sole.position = Vector3(0, -(rod_len + 0.025) * Sc, 0)
		rod.add_child(sole)
		sole.owner = root
	return tris

## Authored only. deploy: arms, then legs, then pads, then the cradle. pack is the reverse.
## 8 s, the same duration as the anti-air plant.
static func _missile_anims(root: Node3D) -> void:
	var deploy := Animation.new()
	deploy.length = 8.0
	deploy.loop_mode = Animation.LOOP_NONE
	var pack := Animation.new()
	pack.length = 8.0
	pack.loop_mode = Animation.LOOP_NONE
	for name in ["OutriggerFR", "OutriggerFL", "OutriggerRR", "OutriggerRL"]:
		var mount := root.find_child(String(name), true, false) as Node3D
		var swing := mount.get_node("Swing") as Node3D
		var hinge := swing.get_node("LegHinge") as Node3D
		var rod := hinge.get_node("Rod") as Node3D
		var yaw: float = swing.get_meta("stow_yaw")
		var roll: float = hinge.get_meta("stow_roll")
		_missile_rot(deploy, pack, root, swing, 0.0, yaw)
		_missile_rot(deploy, pack, root, swing, 2.4, 0.0)
		_missile_rot(deploy, pack, root, hinge, 0.0, roll, false)
		_missile_rot(deploy, pack, root, hinge, 2.4, roll, false)
		_missile_rot(deploy, pack, root, hinge, 4.0, 0.0, false)
		var stow_y: float = rod.get_meta("stow_y")
		var deploy_y: float = rod.get_meta("deploy_y")
		_missile_pos(deploy, pack, root, rod, 0.0, Vector3(0, stow_y, 0))
		_missile_pos(deploy, pack, root, rod, 4.0, Vector3(0, stow_y, 0))
		_missile_pos(deploy, pack, root, rod, 4.8, Vector3(0, deploy_y, 0))
	var piv := root.get_node("LauncherPivot") as Node3D
	var sc: float = (root.get_node("RamR") as Node3D).position.x / 0.55
	var raise := deg_to_rad(38.0)
	_missile_quat(deploy, pack, root, piv, 0.0, Quaternion.IDENTITY)
	for i in 21:
		var t := 4.8 + 3.2 * float(i) / 20.0
		var alpha := raise * float(i) / 20.0
		_missile_quat(deploy, pack, root, piv, t, Quaternion(Basis(Vector3.RIGHT, alpha)))
		for side in [-1.0, 1.0]:
			var s: float = side
			var ram := root.get_node("RamR" if s > 0.0 else "RamL") as Node3D
			var rod2 := ram.get_node("Rod") as Node3D
			var clevis := _missile_clevis_m(s)
			var dist := _missile_eye_m(alpha, s).distance_to(clevis)
			var rod_len: float = ram.get_meta("rod_len_m")
			var basis := _aim_z(_missile_eye_m(alpha, s) - clevis)
			_missile_quat(deploy, pack, root, ram, t, Quaternion(basis))
			_missile_pos(deploy, pack, root, rod2, t, Vector3(0, 0, (dist - rod_len) * sc))
	for side2 in [-1.0, 1.0]:
		var s2: float = side2
		var ram0 := root.get_node("RamR" if s2 > 0.0 else "RamL") as Node3D
		var rod0 := ram0.get_node("Rod") as Node3D
		var clevis0 := _missile_clevis_m(s2)
		var basis0 := _aim_z(_missile_eye_m(0.0, s2) - clevis0)
		_missile_quat(deploy, pack, root, ram0, 0.0, Quaternion(basis0))
		_missile_pos(deploy, pack, root, rod0, 0.0, Vector3(0, 0, 0.05 * sc))
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	player.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	lib.add_animation(&"deploy", deploy)
	lib.add_animation(&"pack", pack)
	player.add_animation_library(&"", lib)

static func _missile_rot(deploy: Animation, pack: Animation, root: Node, node: Node, t: float, deg: float, yaw: bool = true) -> void:
	var euler := Vector3(0, deg_to_rad(deg), 0) if yaw else Vector3(0, 0, deg_to_rad(deg))
	_missile_quat(deploy, pack, root, node, t, Quaternion(Basis.from_euler(euler)))

static func _missile_quat(deploy: Animation, pack: Animation, root: Node, node: Node, t: float, q: Quaternion) -> void:
	var path := root.get_path_to(node)
	var a := _missile_track(deploy, path, Animation.TYPE_ROTATION_3D)
	var b := _missile_track(pack, path, Animation.TYPE_ROTATION_3D)
	deploy.rotation_track_insert_key(a, t, q)
	pack.rotation_track_insert_key(b, 8.0 - t, q)

static func _missile_pos(deploy: Animation, pack: Animation, root: Node, node: Node, t: float, p: Vector3) -> void:
	var path := root.get_path_to(node)
	var a := _missile_track(deploy, path, Animation.TYPE_POSITION_3D)
	var b := _missile_track(pack, path, Animation.TYPE_POSITION_3D)
	deploy.position_track_insert_key(a, t, p)
	pack.position_track_insert_key(b, 8.0 - t, p)

static func _missile_track(anim: Animation, path: NodePath, kind: Animation.TrackType) -> int:
	for i in anim.get_track_count():
		if anim.track_get_path(i) == path and anim.track_get_type(i) == kind:
			return i
	var idx := anim.add_track(kind)
	anim.track_set_path(idx, path)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	return idx

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
