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
static func _run_belt(h, x0: float, x1: float, path: Array) -> void:
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
		var pa0 := Vector3(x0, a.y, a.x)
		var pa1 := Vector3(x1, a.y, a.x)
		var pb0 := Vector3(x0, b.y, b.x)
		var pb1 := Vector3(x1, b.y, b.x)
		h.uv = Vector2(s, 0.0)
		var nrm: Vector3 = (Vector3(0, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5) - ctr).normalized()
		VK._quad_uv(h, [pa0, pa1, pb1, pb0], [Vector2(s, 0), Vector2(s, 1), Vector2(s + ln, 1), Vector2(s + ln, 0)], nrm)
		var dir := Vector3(0, b.y - a.y, b.x - a.x) / ln
		var up := Vector3(1, 0, 0).cross(dir).normalized()
		var mid := Vector3(x1, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5)
		h.box(Vector3.ZERO, Vector3(0.016, 0.055, ln), Transform3D(Basis(Vector3(1, 0, 0), up, dir), mid))
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

## Stage 2 blockout. Plain grey, no stowage. Does not replace bmp3() or ecc_bmp3.
## Approved metres, drawn at 0.405 u/m. +Z bow, +X starboard, root on the ground under the hull centre.
static func bmp3_v2(_mat: Material) -> void:
	var Sc := 0.405
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.62, 0.63, 0.65)
	grey.roughness = 0.92
	grey.vertex_color_use_as_albedo = false
	var root := VK._root({"selection_radius": 1.5, "bar_height": 1.12, "recoil": 0.1, "wreck_s": 7.5})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.plain = true
	h.color("#9a9a9e", Geo.PAINT)
	var rear := -3.525 * Sc
	var bow := 3.525 * Sc
	var brk := 2.15 * Sc
	var half := 1.615 * Sc
	var sill := 0.14 * Sc
	var y0 := 0.36 * Sc
	var ytub := 0.42 * Sc
	# Re-measured on the four-view, track bottom on the ground, hull length held at 7.05 m.
	# Rear deck 1.85 m, up to 2.00 m by 2.30 m from the rear plate, then flat to the glacis.
	var y_rear := 1.85 * Sc
	var y_deck := 2.00 * Sc
	var ynose := 0.72 * Sc
	var rise := (-3.525 + 2.30) * Sc
	var deck := [Vector2(rear, ytub), Vector2(rise, ytub), Vector2(rise, y_deck), Vector2(rear, y_rear)]
	var flat := [Vector2(rise, ytub), Vector2(brk, ytub), Vector2(brk, y_deck), Vector2(rise, y_deck)]
	var sill_deck := [Vector2(rear, y0), Vector2(rise, y0), Vector2(rise, y_deck), Vector2(rear, y_rear)]
	var sill_flat := [Vector2(rise, y0), Vector2(brk, y0), Vector2(brk, y_deck), Vector2(rise, y_deck)]
	h.prism_x(deck, -(half - sill), half - sill)
	h.prism_x(flat, -(half - sill), half - sill)
	for s in [-1.0, 1.0]:
		var side: float = s
		var x_a: float = minf(side * (half - sill), side * half)
		var x_b: float = maxf(side * (half - sill), side * half)
		h.prism_x(sill_deck, x_a, x_b)
		h.prism_x(sill_flat, x_a, x_b)
	# One flat glacis from the same nose point up to the new roof height.
	h.prism_x([Vector2(brk, y0), Vector2(bow, ynose), Vector2(brk, y_deck)], -half, half)
	var along := Vector2(2.15 - 3.525, 2.00 - 0.72).normalized()
	var out_n := Vector2(along.y, -along.x)
	var nose := Vector2(3.525, 0.72)
	var vane: Array = []
	for k in [0.04, 0.58]:
		var p: Vector2 = nose + along * k
		vane.append((p + out_n * 0.012) * Sc)
		vane.append((p + out_n * 0.034) * Sc)
	# Quad order around the thin plate: inner near, outer near, outer far, inner far.
	h.prism_x([vane[0], vane[2], vane[3], vane[1]], -1.30 * Sc, 1.30 * Sc)
	# Running gear. Upper halves sit behind the side wall; the belt is flush with it.
	# The belt helper adds a tread slab past the outer edge and below the path, so the
	# path sits inside the 3.23 m width and the slab's underside lands on the ground.
	var x_out := half - 0.008
	var x_in := x_out - 0.40 * Sc
	var belt: Array = []
	belt.append(Vector2(2.50, 0.07) * Sc)
	belt.append(Vector2(-3.05, 0.07) * Sc)
	for i in 9:
		var a := deg_to_rad(270.0 - 180.0 * float(i) / 8.0)
		belt.append(Vector2(-3.125 + cos(a) * 0.32, 0.50 + sin(a) * 0.32) * Sc)
	belt.append(Vector2(-2.30, 1.05) * Sc)
	belt.append(Vector2(1.70, 1.05) * Sc)
	for i in 9:
		var a2 := deg_to_rad(90.0 - 180.0 * float(i) / 8.0)
		belt.append(Vector2(2.575 + cos(a2) * 0.26, 0.52 + sin(a2) * 0.26) * Sc)
	h.color("#4a4a4e", Geo.TRACK)
	_run_belt(h, x_in, x_out, belt)
	_run_belt(h, -x_out, -x_in, belt)
	var stations: Array = [1.00, 1.72, 2.48, 3.22, 4.40, 5.18]
	for stn in stations:
		var zc: float = (-3.525 + float(stn)) * Sc
		for s2 in [-1.0, 1.0]:
			var side2: float = s2
			var wc := Vector3(side2 * (x_out - 0.20 * Sc), 0.36 * Sc, zc)
			h.uv = Vector2(wc.y, wc.z)
			h.uv2 = Vector2(wc.x, 0.355 * Sc)
			h.color("#3e3e42", Geo.WHEEL_RUBBER)
			h.tube(wc - Vector3(0.15 * Sc, 0, 0), wc + Vector3(0.15 * Sc, 0, 0), 0.355 * Sc, 14)
	# Rear sprocket, smaller front idler, three return rollers under the top run.
	for s3 in [-1.0, 1.0]:
		var side3: float = s3
		var xc: float = side3 * (x_out - 0.20 * Sc)
		var sp := Vector3(xc, 0.50 * Sc, -3.125 * Sc)
		var idl := Vector3(xc, 0.52 * Sc, 2.575 * Sc)
		h.uv = Vector2(sp.y, sp.z)
		h.uv2 = Vector2(sp.x, 0.28 * Sc)
		h.color("#5a5a5e", Geo.WHEEL_STEEL)
		h.tube(sp - Vector3(0.14 * Sc, 0, 0), sp + Vector3(0.14 * Sc, 0, 0), 0.28 * Sc, 12)
		h.uv = Vector2(idl.y, idl.z)
		h.uv2 = Vector2(idl.x, 0.22 * Sc)
		h.tube(idl - Vector3(0.12 * Sc, 0, 0), idl + Vector3(0.12 * Sc, 0, 0), 0.22 * Sc, 12)
		for rz in [-1.525, -0.125, 1.275]:
			var rc := Vector3(xc, 0.95 * Sc, float(rz) * Sc)
			h.uv = Vector2(rc.y, rc.z)
			h.uv2 = Vector2(rc.x, 0.10 * Sc)
			h.tube(rc - Vector3(0.10 * Sc, 0, 0), rc + Vector3(0.10 * Sc, 0, 0), 0.10 * Sc, 8)
	h.uv = Vector2.ZERO
	h.uv2 = Vector2.ZERO
	# Turret body centre 3.85 m from the rear plate. The 2 m box then shares the drawn rear face.
	var piv_z := -3.525 + 3.85 - 0.11
	var piv_y := 2.00
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, piv_y * Sc, piv_z * Sc))
	var t = K.new()
	t.plain = true
	t.color("#8e8e92", Geo.PAINT)
	# Roof of the turret box at 2.42 m. Sight block tops out at 2.55 m.
	var tur_h := 2.42 - piv_y
	t.box(Vector3(0, tur_h * 0.5 * Sc, 0.11 * Sc), Vector3(1.75 * Sc, tur_h * Sc, 2.00 * Sc))
	var sight_top := 2.55 - piv_y
	t.box(Vector3(0.28 * Sc, (sight_top - 0.065) * Sc, -0.20 * Sc), Vector3(0.30 * Sc, 0.13 * Sc, 0.34 * Sc))
	VK._mi(piv, root, "Turret", t.commit(grey))
	# Barrel axis at 2.15 m. 100 mm reaches the drawing's visible muzzle, 7.15 m from the rear plate.
	var gun_y := 2.15 - piv_y
	var muzzle_z := (-3.525 + 7.15) - (piv_z + 1.11)
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, gun_y * Sc, 1.11 * Sc))
	var b = K.new()
	b.plain = true
	b.color("#6e6e72", Geo.STEEL)
	b.box(Vector3(0.03 * Sc, 0, -0.02 * Sc), Vector3(0.52 * Sc, 0.26 * Sc, 0.16 * Sc))
	b.tube(Vector3(-0.12 * Sc, 0, 0), Vector3(-0.12 * Sc, 0, muzzle_z * Sc), 0.070 * Sc, 8)
	b.tube(Vector3(0.18 * Sc, 0, 0), Vector3(0.18 * Sc, 0, (muzzle_z - 0.22) * Sc), 0.032 * Sc, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(grey))
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
	print("  bmp3_v2 m: roof %.3f-2.00 edge 0.36 pivot z %.3f y %.3f gun y 2.15 muzzle from rear 7.15" % [1.85, piv_z, piv_y])
	_save(root, model, h, grey, "res://view/units/ecc/bmp3_v2.tscn", 1.12, [t, b])

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
