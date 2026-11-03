extends RefCounted
## M2.9 TPLA remodel (tool-time only; run tools/gfx_m29/build_m29.sh), M3.0 E: faction is Iran.
## Backhoe, white civilian Pickup, Karrar-based Striker, BMP-family (Boragh) transport, Samavat
## (tracked 35 mm SPAAG), Fajr-5 rocket truck, MiG-29-style interceptor, the redone defences, and
## the M3.0 E swaps: Safir-style jeep Technical, Raad-2-style SPG, F-4E-style strike jet and a
## Kowsar / F-5-style fighter. Original procedural geometry only. Node layout matches
## VehicleView / BuildingView.
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const V8 := preload("res://tools/gfx_m7/us_v8.gd")
const TP := "#a8915f"
const TP_D := "#8a774d"
const TP_L := "#bba674"
const TP_S := "#4a4640"
const GLASS_C := "#2a3a46"
const WHITE := "#e6e4dc"
const WHITE_D := "#c9c6bc"
const YEL := "#c99a2e"
const AIR := "#9a9c92"
const AIR_D := "#7b7d74"
const Y0 := 0.08

static var wrote: Array = []

static func jobs() -> Dictionary:
	return {
		"backhoe": func() -> void: _backhoe(),
		"pickup": func() -> void: _pickup(),
		"rattler": func() -> void: _technical(),
		"scrapback": func() -> void: _striker(),
		"bus": func() -> void: _bmp2(),
		"hailstorm": func() -> void: _bhx35(),
		"blight": func() -> void: _koksan(),
		"shrike": func() -> void: _fajr(),
		"f16": func() -> void: _f16(),
		"mirage": func() -> void: _mirage(),
		"mig29": func() -> void: _mig29(),
		"tunnel": func() -> void: _make_b("tunnel", Vector2(2, 2), 0.9, _tunnel, _tunnel_turret, Vector3(0.0, 0.6, 0.0)),
		"wasp_nest": func() -> void: _make_b("wasp_nest", Vector2(2, 2), 1.0, _wasp, _wasp_turret, Vector3(0, 0.36, 0)),
		"demo_trap": func() -> void: _make_b("demo_trap", Vector2(1, 1), 0.35, _demo_trap),
		"camo_net": func() -> void: _make_b("camo_net", Vector2(1, 1), 0.9, _camo_net),
		"decoy": func() -> void: _make_b("decoy", Vector2(3, 3), 1.4, _decoy),
		"airfield": func() -> void: _airfield(),
	}

static func build(only: Array) -> void:
	var all := only.is_empty() or "all" in only
	var j := jobs()
	for k in j:
		if all or k in only:
			j[k].call()
	var f := FileAccess.open("/tmp/gfx_m29_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line("WROTE " + p)

# ------------------------------------------------------------------ helpers
static func _finish(root: Node3D, model: Node3D, h, mat: Material, name: String, extra: Array, bar: float) -> void:
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	var t := 0
	for g in [h] + extra:
		t += g.tris
	print("  tpla_%s: %d tris (LOD0) in %d meshes" % [name, t, 1 + extra.size()])
	var path := "res://view/units/tpla/%s.tscn" % name
	VK._save(root, path, bar)
	wrote.append(path)

static func _barrel(piv: Node3D, root: Node3D, mat: Material, at: Vector3, parts: Callable):
	var bn := VK._n3(piv, root, "Barrel", at)
	var b = K.new()
	parts.call(b)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	return b

static func _turret(piv: Node3D, root: Node3D, mat: Material, parts: Callable):
	var t = K.new()
	parts.call(t)
	VK._mi(piv, root, "Turret", t.commit(mat))
	return t

static func _smoke(t, p: Vector3, yaw: float, n := 3) -> void:
	t.color(TP_S, Geo.STEEL)
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	for i in n:
		var o := p + b * Vector3(0, 0, -0.035 * i)
		t.tube(o, o + b * Vector3(0.05, 0.03, 0.0), 0.013, 6)

static func _era(h, c: Vector3, nx: int, nz: int, cell: Vector2, deg: Vector3, col := TP_D) -> void:
	## grid of explosive reactive armour bricks on a plate rotated by deg
	var b := Basis.from_euler(deg * PI / 180.0)
	h.color(col, Geo.PAINT)
	for i in nx:
		for k in nz:
			var o := Vector3((i - (nx - 1) * 0.5) * cell.x, 0, (k - (nz - 1) * 0.5) * cell.y)
			h.box(Vector3.ZERO, Vector3(cell.x * 0.88, 0.035, cell.y * 0.86), Transform3D(b, c + b * o))

static func _team_band(h, hw: float, y: float, z0: float, z1: float) -> void:
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * (hw + 0.004), y, (z0 + z1) * 0.5), Vector3(0.008, 0.035, absf(z1 - z0)))

# ------------------------------------------------------------------ Toyota-style pickup body (shared)
## Hilux-style double-cab pickup in white civilian paint (kept out of the camo pass), nose +z.
static func _toyota(h, bed_load: bool) -> void:
	V8._tyres(h, 0.33, [0.48, -0.42], 0.12, 0.1, 1, "#9a9a96")
	h.plain = true
	h.color("#2e2d2a", Geo.DARK)
	h.cbox(Vector3(0, 0.2, 0.0), Vector3(0.42, 0.06, 1.38), 0.01)   # ladder frame
	h.color(WHITE, Geo.PAINT)
	# hood + front clip
	h.xloft([[0.78, K.sect(0.2, 0.27, 0.36, 0.34, 0.36, 0.32, 0.04)], [0.68, K.sect(0.17, 0.28, 0.41, 0.36, 0.37, 0.34, 0.035)], [0.3, K.sect(0.17, 0.28, 0.44, 0.37, 0.38, 0.35, 0.03)]])
	# cab: raked windscreen, roof, rear window
	var c0 := K.sect(0.4, 0.42, 0.45, 0.37, 0.37, 0.35, 0.01)
	var c1 := K.sect(0.4, 0.45, 0.66, 0.37, 0.37, 0.31, 0.035)
	var c2 := K.sect(0.4, 0.45, 0.66, 0.37, 0.37, 0.31, 0.035)
	var c3 := K.sect(0.4, 0.45, 0.62, 0.37, 0.37, 0.32, 0.03)
	h.xloft([[0.32, c0], [0.12, c1], [-0.2, c2], [-0.25, c3]])
	h.xloft([[0.32, K.sect(0.17, 0.3, 0.42, 0.37, 0.38, 0.37, 0.01)], [-0.25, K.sect(0.17, 0.3, 0.42, 0.37, 0.38, 0.37, 0.01)]])   # cab lower
	V8._glass(h, c0, 0.32, c1, 0.12, 4, 5, Vector2(0.06, 0.94), Vector2(0.08, 0.9), Vector3(0, 1, 1))
	for s in [-1.0, 1.0]:
		V8._glass(h, c1, 0.12, c2, -0.2, 2 if s > 0 else 7, 3 if s > 0 else 6, Vector2(0.15, 0.85), Vector2(0.05, 0.47), Vector3(s, 0, 0))
		V8._glass(h, c1, 0.12, c2, -0.2, 2 if s > 0 else 7, 3 if s > 0 else 6, Vector2(0.15, 0.85), Vector2(0.53, 0.95), Vector3(s, 0, 0))
	h.color(GLASS_C, Geo.GLASS)
	h.box(Vector3(0, 0.55, -0.252), Vector3(0.44, 0.09, 0.006))
	# grille, bumper, lamps, mirrors
	h.color("#3a3a38", Geo.STEEL)
	h.box(Vector3(0, 0.31, 0.785), Vector3(0.44, 0.08, 0.012))
	h.color("#2b2b2a", Geo.DARK)
	for y in [0.29, 0.32]:
		h.box(Vector3(0, y, 0.792), Vector3(0.4, 0.012, 0.006))
	h.color("#8d8d88", Geo.STEEL)
	h.cbox(Vector3(0, 0.2, 0.8), Vector3(0.74, 0.07, 0.06), 0.015)
	V4._lamps(h, 0.27, 0.34, 0.785)
	h.color("#2b2b2a", Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.4, 0.5, 0.26), Vector3(0.03, 0.05, 0.06), 0.008)
		h.color("#3a3a38", Geo.DARK)   # wheel-arch flares
		for z in [0.48, -0.42]:
			h.plate(Vector3(s * 0.375, 0.27, z), Vector3(0.03, 0.03, 0.3), Vector3(0, 0, 0))
		h.color("#2b2b2a", Geo.STEEL)
		h.box(Vector3(s * 0.376, 0.4, -0.02), Vector3(0.006, 0.012, 0.04))   # door handles
	# bed
	h.color(WHITE_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, -0.62), Vector3(0.72, 0.05, 0.72), 0.01)
	h.color(WHITE, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.cbox(Vector3(s * 0.35, 0.39, -0.62), Vector3(0.03, 0.16, 0.74), 0.01)
	h.cbox(Vector3(0, 0.39, -0.985), Vector3(0.72, 0.16, 0.03), 0.01)
	h.cbox(Vector3(0, 0.39, -0.26), Vector3(0.72, 0.16, 0.02), 0.008)
	h.color("#b33a2a", Geo.LAMP)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.33, 0.42, -1.002), Vector3(0.04, 0.08, 0.006))
	h.plain = false
	# team colour: door stripe + tailgate band
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.378, 0.33, 0.04), Vector3(0.006, 0.03, 0.55))
	h.box(Vector3(0, 0.36, -1.003), Vector3(0.5, 0.03, 0.006))
	if bed_load:
		var cols := ["#7c6a45", "#6b5a3a", "#8a7650", "#5d6650"]
		for i in 4:
			h.color(cols[i], Geo.WOOD)
			h.cbox(Vector3(-0.15 + (i % 2) * 0.3, 0.42, -0.45 - (i / 2) * 0.32), Vector3(0.26, 0.2, 0.28), 0.02)
		h.color("#b5a27a", Geo.CANVAS)   # supply sacks + strapped tarp
		for k in 3:
			h.cbox(Vector3(-0.18 + k * 0.18, 0.56, -0.62), Vector3(0.16, 0.08, 0.3), 0.03)
		h.color("#4d5741", Geo.PAINT)
		for z in [-0.86, -0.78]:
			h.jerrycan(Vector3(0.24, 0.33, z), 0)
		h.color("#2b2b2a", Geo.STEEL)
		h.box(Vector3(0, 0.58, -0.5), Vector3(0.7, 0.012, 0.02))

static func _pickup() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.62, "bar_height": 0.95, "recoil": 0.0, "wreck_s": 6.0, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_toyota(h, true)
	V4._antenna(h, Vector3(0.3, 0.66, 0.1), 0.35)
	_finish(root, model, h, mat, "pickup", [], 0.95)

# ------------------------------------------------------------------ Backhoe (builder)
static func _backhoe() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0, "steer_max": 0.35})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	for s in [-1.0, 1.0]:
		h.tyre(Vector3(s * 0.36, 0.14, 0.42), 0.14, 0.12, true, "#3a3a36", 12)
		h.tyre(Vector3(s * 0.38, 0.24, -0.3), 0.24, 0.18, false, "#3a3a36", 14)
	h.plain = true
	h.color(YEL, Geo.PAINT)
	h.xloft([[0.62, K.sect(0.2, 0.26, 0.42, 0.2, 0.22, 0.18, 0.04)], [0.1, K.sect(0.2, 0.27, 0.48, 0.22, 0.24, 0.2, 0.05)]])   # engine hood
	h.cbox(Vector3(0, 0.3, -0.2), Vector3(0.46, 0.2, 0.7), 0.03)   # chassis / tub
	for s in [-1.0, 1.0]:   # rear fenders
		h.plate(Vector3(s * 0.38, 0.5, -0.3), Vector3(0.22, 0.02, 0.5), Vector3(0, 0, 0))
		h.plate(Vector3(s * 0.38, 0.43, -0.03), Vector3(0.22, 0.02, 0.14), Vector3(-40, 0, 0))
	# cab with corner posts and glass
	h.color("#2b2b2a", Geo.STEEL)
	for p in [Vector3(-0.22, 0, 0.08), Vector3(0.22, 0, 0.08), Vector3(-0.22, 0, -0.42), Vector3(0.22, 0, -0.42)]:
		h.cbox(p + Vector3(0, 0.66, 0), Vector3(0.035, 0.36, 0.035), 0.008)
	h.color(YEL, Geo.PAINT)
	h.cbox(Vector3(0, 0.86, -0.17), Vector3(0.5, 0.05, 0.6), 0.015)
	h.plain = false
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.66, 0.08), Vector3(0.42, 0.34, 0.008), Vector3(-4, 0, 0))
	h.box(Vector3(0, 0.66, -0.42), Vector3(0.42, 0.34, 0.008))
	for s in [-0.22, 0.22]:
		h.box(Vector3(s, 0.66, -0.17), Vector3(0.008, 0.34, 0.46))
	h.color("#2e2f2b", Geo.DARK)
	h.cbox(Vector3(0, 0.52, -0.2), Vector3(0.18, 0.1, 0.16), 0.02)
	h.color("#2b2b2a", Geo.STEEL)
	h.tube(Vector3(0.14, 0.45, 0.4), Vector3(0.14, 0.82, 0.4), 0.022, 6)   # exhaust
	h.color("#ff9a2a", Geo.LAMP)
	h.cbox(Vector3(-0.18, 0.9, -0.3), Vector3(0.05, 0.04, 0.05), 0.01)
	h.color("#2b2b2a", Geo.DARK)
	h.grille(Vector3(0, 0.483, 0.36), 0.3, 0.3, 6)
	# front loader: lift arms, rams and a wide bucket
	h.color("#2b2b2a", Geo.STEEL)
	for s in [-0.3, 0.3]:
		h.tube(Vector3(s, 0.5, 0.05), Vector3(s, 0.22, 0.78), 0.03, 6)
		h.tube(Vector3(s * 0.8, 0.32, 0.25), Vector3(s * 0.9, 0.3, 0.62), 0.02, 6)
		h.color("#c9ccce", Geo.STEEL)
		h.tube(Vector3(s * 0.85, 0.31, 0.45), Vector3(s * 0.9, 0.3, 0.62), 0.011, 6)
		h.color("#2b2b2a", Geo.STEEL)
	h.plain = true
	h.color(YEL, Geo.PAINT)
	h.prism_x([Vector2(0.72, 0.05), Vector2(0.93, 0.05), Vector2(0.95, 0.1), Vector2(0.8, 0.34), Vector2(0.72, 0.32)], -0.42, 0.42)
	h.plain = false
	h.color(TP_S, Geo.STEEL)
	h.plate(Vector3(0, 0.05, 0.95), Vector3(0.84, 0.025, 0.05), Vector3(10, 0, 0))
	for x in [-0.3, -0.1, 0.1, 0.3]:
		h.cbox(Vector3(x, 0.05, 0.99), Vector3(0.035, 0.025, 0.06), 0.006)   # teeth
	# rear backhoe: swing frame, boom folded up, dipper, small bucket, stabiliser legs
	h.color(TP_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.36, -0.62), Vector3(0.24, 0.16, 0.12), 0.02)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.3, 0.3, -0.62), Vector3(0.2, 0.06, 0.1), Vector3(0, 0, s * -20.0))
		h.tube(Vector3(s * 0.38, 0.28, -0.62), Vector3(s * 0.44, 0.06, -0.64), 0.025, 6)
		h.cbox(Vector3(s * 0.44, 0.03, -0.64), Vector3(0.12, 0.03, 0.12), 0.008)
	# M3.3: boom, dipper, ram and bucket are one node "Arm" (pivot on the swing frame) so the
	# backhoe digs, swings and dumps while it builds; "Dirt" is the bucket load
	var w = K.new()
	var piv := Vector3(0, 0.42, -0.66)
	w.xf = Transform3D(Basis.IDENTITY, -piv)
	w.plain = true
	w.color(YEL, Geo.PAINT)
	_beam(w, piv, Vector3(0, 0.8, -0.78), 0.08, 0.1)   # boom (kinked)
	_beam(w, Vector3(0, 0.8, -0.78), Vector3(0, 0.92, -0.98), 0.08, 0.09)
	_beam(w, Vector3(0, 0.95, -0.97), Vector3(0, 0.5, -1.12), 0.065, 0.08)   # dipper
	w.plain = false
	w.color("#c9ccce", Geo.STEEL)
	w.tube(Vector3(0, 0.5, -0.7), Vector3(0, 0.82, -0.86), 0.018, 6)   # boom ram
	w.tube(Vector3(0, 0.97, -0.92), Vector3(0, 0.62, -1.06), 0.014, 6)   # bucket ram
	w.color(TP_S, Geo.STEEL)
	w.tube(Vector3(-0.06, 0.92, -0.98), Vector3(0.06, 0.92, -0.98), 0.03, 8)   # elbow pin
	w.prism_x([Vector2(-1.08, 0.52), Vector2(-1.2, 0.5), Vector2(-1.25, 0.36), Vector2(-1.17, 0.29), Vector2(-1.1, 0.38)], -0.1, 0.1)   # bucket
	for x in [-0.07, 0.0, 0.07]:
		w.cbox(Vector3(x, 0.28, -1.18), Vector3(0.025, 0.03, 0.04), 0.005)   # teeth
	var arm := VK._mi(model, root, "Arm", w.commit(mat), piv)
	arm.set_meta("work", "arm")
	var d = K.new()
	d.color("#6e5a3e", Geo.SANDBAG)
	d.cbox(Vector3(0, 0.03, 0), Vector3(0.17, 0.06, 0.12), 0.02)   # bucket load
	d.cbox(Vector3(0.01, 0.07, 0), Vector3(0.1, 0.04, 0.08), 0.015)
	var dn := VK._mi(arm, root, "Dirt", d.commit(mat), Vector3(0, 0.47, -1.16) - piv)
	dn.set_meta("dirt", true)
	dn.visible = false
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.235, 0.36, -0.2), Vector3(0.006, 0.05, 0.5))
	V4._lamps(h, 0.16, 0.43, 0.63)
	_finish(root, model, h, mat, "backhoe", [], 1.2)

static func _beam(g, a: Vector3, b: Vector3, w: float, h: float, ch := 0.01) -> void:
	var d := b - a
	var bs := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	g.cbox(Vector3.ZERO, Vector3(w, h, d.length()), ch, Transform3D(bs, (a + b) * 0.5))

# ------------------------------------------------------------------ tracked hull (shared)
## Low T-72-family style hull: track runs, lower hull, upper hull with a sloped glacis.
static func _tracked_hull(h, hw: float, l: float, wheels: int, top: float, col: String, col_d: String) -> void:
	var hl := l * 0.5
	h.track_run(hw - 0.1, l, wheels, 0.08, 0.22, TP_S)
	h.color(col_d, Geo.PAINT)
	h.prism_x([Vector2(-hl + 0.04, 0.12), Vector2(hl - 0.2, 0.12), Vector2(hl, 0.26), Vector2(hl, 0.3), Vector2(-hl, 0.32), Vector2(-hl, 0.18)], -hw + 0.22, hw - 0.22)
	h.color(col, Geo.PAINT)
	h.xloft([[hl + 0.02, K.sect(0.28, 0.29, 0.31, hw - 0.02, hw - 0.01, hw - 0.04, 0.01)], [hl - 0.32, K.sect(0.28, 0.31, top, hw, hw, hw - 0.04, 0.02)],
		[-hl + 0.06, K.sect(0.28, 0.31, top, hw, hw, hw - 0.04, 0.02)], [-hl - 0.02, K.sect(0.28, 0.3, top - 0.03, hw, hw, hw - 0.05, 0.02)]])
	# side fenders / rubber skirts
	for s in [-1.0, 1.0]:
		h.color(col_d, Geo.PAINT)
		h.plate(Vector3(s * (hw + 0.01), 0.27, -0.02), Vector3(0.025, 0.1, l - 0.1), Vector3(0, 0, -s * 6.0))
		h.color(TP_S, Geo.STEEL)
		h.rivets(Vector3(s * (hw + 0.03), 0.3, -hl + 0.1), Vector3(s * (hw + 0.03), 0.3, hl - 0.15), 8, Vector3(s, 0, 0), 0.008)

# ------------------------------------------------------------------ Striker MBT (Karrar-inspired)
static func _striker() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.35, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked_hull(h, 0.56, 1.6, 6, 0.44, TP, TP_D)
	# glacis ERA in two rows + V-shaped splash board, driver hatch, lamps, fuel drums at the rear
	_era(h, Vector3(0, 0.39, 0.63), 6, 2, Vector2(0.16, 0.12), Vector3(-62, 0, 0))
	h.color(TP_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.22, 0.45, 0.47), Vector3(0.32, 0.03, 0.03), Vector3(0, s * 12.0, 0))
	h.hatch(Vector3(0, 0.45, 0.42), 0.12)
	V4._lamps(h, 0.42, 0.36, 0.8)
	h.color("#5d5a4a", Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.3, 0.56, -0.8), Vector3(s * 0.3 * 0.2 + s * 0.1, 0.56, -0.8), 0.08, 10)
	h.color("#2e322b", Geo.DARK)
	h.grille(Vector3(0, 0.447, -0.5), 0.6, 0.36, 9)
	# side ERA skirt blocks
	for s in [-1.0, 1.0]:
		for i in 5:
			h.color(TP if i % 2 == 0 else TP_L, Geo.PAINT)
			h.plate(Vector3(s * 0.6, 0.3, 0.6 - i * 0.16), Vector3(0.05, 0.12, 0.14), Vector3(0, 0, -s * 4.0))
	_team_band(h, 0.6, 0.38, -0.7, -0.2)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.45, -0.02))
	piv.scale = Vector3.ONE * 1.1
	var t = _turret(piv, root, mat, func(t) -> void:
		t.color(TP_S, Geo.STEEL)
		t.cyl(0.3, 0.3, 0.03, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
		# angular welded turret: wedge-front plan, sloped sides
		t.color(TP, Geo.PAINT)
		t.plan_loft([Vector2(-0.12, 0.44), Vector2(0.12, 0.44), Vector2(0.36, 0.18), Vector2(0.36, -0.22), Vector2(0.26, -0.4), Vector2(-0.26, -0.4), Vector2(-0.36, -0.22), Vector2(-0.36, 0.18)], 0.0, 0.18, Vector2(0.9, 0.88), Vector2(0, -0.02))
		# wedge ERA cheeks (the Karrar's sharp turret front)
		for s in [-1.0, 1.0]:
			t.color(TP_D, Geo.PAINT)
			t.plan_loft([Vector2(s * 0.1, 0.44), Vector2(s * 0.36, 0.18), Vector2(s * 0.39, 0.22), Vector2(s * 0.13, 0.5)], 0.02, 0.17, Vector2(0.95, 0.95))
			t.color(TP_S, Geo.STEEL)
			t.rivets(Vector3(s * 0.15, 0.175, 0.44), Vector3(s * 0.34, 0.175, 0.24), 4, Vector3(0, 1, 0), 0.007)
		_era(t, Vector3(0, 0.18, 0.05), 4, 3, Vector2(0.12, 0.1), Vector3(0, 0, 0))
		# bustle rack, stowage, panoramic sight, commander RWS, smoke launchers, antennas
		t.color(TP_S, Geo.STEEL)
		t.rail([Vector3(-0.28, 0.16, -0.4), Vector3(-0.28, 0.16, -0.52), Vector3(0.28, 0.16, -0.52), Vector3(0.28, 0.16, -0.4)], 0.07, 0.1, 0.006)
		t.color("#7f7556", Geo.CANVAS)
		t.tube(Vector3(-0.24, 0.21, -0.47), Vector3(0.1, 0.21, -0.47), 0.045, 8)
		t.color(TP_D, Geo.PAINT)
		t.cbox(Vector3(0.2, 0.26, 0.0), Vector3(0.1, 0.1, 0.12), 0.015)
		t.color(GLASS_C, Geo.GLASS)
		t.box(Vector3(0.2, 0.27, 0.062), Vector3(0.07, 0.05, 0.006))
		t.color(TP_D, Geo.PAINT)
		t.hatch(Vector3(-0.15, 0.19, -0.12), 0.13)
		t.color("#2b2b2a", Geo.STEEL)
		t.cbox(Vector3(-0.15, 0.28, -0.08), Vector3(0.08, 0.07, 0.1), 0.01)
		t.tube(Vector3(-0.15, 0.29, -0.04), Vector3(-0.15, 0.29, 0.16), 0.01, 5)
		_smoke(t, Vector3(0.3, 0.16, 0.05), 40.0, 4)
		_smoke(t, Vector3(-0.3, 0.16, 0.05), 140.0, 4)
		for s in [-1.0, 1.0]:
			t.tube(Vector3(s * 0.24, 0.18, -0.36), Vector3(s * 0.24, 0.72, -0.38), 0.005, 3)
		t.color("#ffffff", Geo.TEAM)
		for s in [-1.0, 1.0]:
			t.plate(Vector3(s * 0.352, 0.1, -0.05), Vector3(0.008, 0.04, 0.34), Vector3(0, 0, s * 4.0)))
	var b = _barrel(piv, root, mat, Vector3(0, 0.1, 0.44), func(b) -> void:
		b.color(TP_D, Geo.PAINT)
		b.tube(Vector3(0, 0, -0.04), Vector3(0, 0, 0.06), 0.065, 10, 0.055)
		b.color(TP, Geo.PAINT)
		b.gun(0.0, 1.06, 0.042, 0.033, 0.38, false, 10)
		b.color(TP_D, Geo.PAINT)
		for z in [0.18, 0.62, 0.86]:
			b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.03), 0.046, 10)
		b.color("#2b2b2a", Geo.STEEL)
		b.tube(Vector3(0, 0, 1.04), Vector3(0, 0, 1.08), 0.038, 10))
	_finish(root, model, h, mat, "scrapback", [t, b], 1.35)

# ------------------------------------------------------------------ BMP-2 transport
static func _bmp2() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.78, "bar_height": 1.2, "recoil": 0.04, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.44, 1.6, 6, 0.075, 0.2, TP_S)
	h.color(TP_D, Geo.PAINT)
	h.prism_x([Vector2(-0.76, 0.12), Vector2(0.5, 0.12), Vector2(0.86, 0.3), Vector2(-0.8, 0.3)], -0.34, 0.34)
	# sharp ribbed nose (trim vane), flat roof, sloped sides, rear doors
	h.color(TP, Geo.PAINT)
	h.xloft([[0.92, K.sect(0.28, 0.29, 0.3, 0.5, 0.5, 0.48, 0.0)], [0.4, K.sect(0.28, 0.32, 0.46, 0.56, 0.56, 0.44, 0.02)],
		[-0.74, K.sect(0.28, 0.32, 0.46, 0.56, 0.56, 0.44, 0.02)], [-0.82, K.sect(0.28, 0.31, 0.43, 0.55, 0.55, 0.42, 0.02)]])
	h.color(TP_D, Geo.PAINT)
	for i in 4:   # glacis ribs
		h.plate(Vector3(0, 0.33 + i * 0.03, 0.82 - i * 0.12), Vector3(0.9 - i * 0.04, 0.012, 0.02), Vector3(-15, 0, 0))
	h.plate(Vector3(0, 0.36, 0.88), Vector3(0.8, 0.12, 0.02), Vector3(-60, 0, 0))   # trim vane
	h.hatch(Vector3(-0.2, 0.465, 0.38), 0.12)
	h.hatch(Vector3(0.2, 0.465, 0.38), 0.12)
	for s in [-1.0, 1.0]:   # troop roof hatches + firing ports
		for z in [-0.3, -0.6]:
			h.hatch(Vector3(s * 0.2, 0.465, z), 0.13)
		h.color(TP_S, Geo.STEEL)
		for z in [-0.1, -0.3, -0.5]:
			h.tube(Vector3(s * 0.5, 0.38, z), Vector3(s * 0.53, 0.38, z), 0.015, 6)
		h.color(TP_D, Geo.PAINT)
		h.plate(Vector3(s * 0.15, 0.37, -0.83), Vector3(0.22, 0.14, 0.03), Vector3.ZERO)   # rear doors (fuel tanks)
		h.color(TP_S, Geo.STEEL)
		h.box(Vector3(s * 0.15, 0.37, -0.85), Vector3(0.04, 0.02, 0.01))
	V4._lamps(h, 0.36, 0.38, 0.72)
	_team_band(h, 0.56, 0.36, -0.7, 0.2)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.06, 0.46, 0.08))
	var t = _turret(piv, root, mat, func(t) -> void:
		t.color(TP_S, Geo.STEEL)
		t.cyl(0.2, 0.2, 0.02, 12, Transform3D.IDENTITY)
		t.color(TP, Geo.PAINT)
		t.plan_loft([Vector2(-0.18, 0.2), Vector2(0.18, 0.2), Vector2(0.24, 0.0), Vector2(0.2, -0.2), Vector2(-0.2, -0.2), Vector2(-0.24, 0.0)], 0.0, 0.14, Vector2(0.78, 0.78))
		t.color(TP_D, Geo.PAINT)
		t.hatch(Vector3(-0.08, 0.14, -0.04), 0.1)
		t.hatch(Vector3(0.1, 0.14, -0.06), 0.1)
		t.color(GLASS_C, Geo.GLASS)
		t.box(Vector3(-0.1, 0.16, 0.1), Vector3(0.06, 0.03, 0.03))
		# Konkurs-style ATGM tube on a roof bracket
		t.color(TP_S, Geo.STEEL)
		t.box(Vector3(0.0, 0.18, 0.0), Vector3(0.04, 0.06, 0.04))
		t.color("#5d6340", Geo.PAINT)
		t.tube(Vector3(0.0, 0.23, -0.18), Vector3(0.0, 0.23, 0.26), 0.035, 8)
		_smoke(t, Vector3(0.2, 0.08, -0.05), 20.0, 3)
		_smoke(t, Vector3(-0.2, 0.08, -0.05), 160.0, 3)
		t.color("#ffffff", Geo.TEAM)
		t.box(Vector3(0, 0.07, -0.205), Vector3(0.3, 0.035, 0.008)))
	var b = _barrel(piv, root, mat, Vector3(0.0, 0.08, 0.18), func(b) -> void:
		b.color(TP_S, Geo.STEEL)
		b.tube(Vector3(0, 0, -0.02), Vector3(0, 0, 0.08), 0.035, 8)
		b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 0.72), 0.014, 8)   # 30 mm 2A42-style
		b.tube(Vector3(0, 0, 0.62), Vector3(0, 0, 0.74), 0.02, 8)
		b.tube(Vector3(0.04, -0.01, 0.0), Vector3(0.04, -0.01, 0.12), 0.01, 5))
	_finish(root, model, h, mat, "bus", [t, b], 1.2)

# ------------------------------------------------------------------ BHX-35 (DAMITA-style 35 mm SPAAG, tracked)
## Real reference: the Calidus DAMITA SPAAG carries a Skyranger-35-style turret (single 35 mm
## revolver cannon, roof search radar, EO sensor) on an 8x8; Malachi's BHX-35 puts it on a
## tank-like tracked chassis, plus a small counter-drone laser head on the turret.
static func _bhx35() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.45, "recoil": 0.06, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked_hull(h, 0.55, 1.62, 6, 0.46, TP, TP_D)
	h.color(TP_D, Geo.PAINT)
	h.plate(Vector3(0, 0.42, 0.66), Vector3(0.9, 0.03, 0.22), Vector3(-55, 0, 0))   # applique glacis
	h.hatch(Vector3(-0.22, 0.47, 0.5), 0.12)
	V4._lamps(h, 0.42, 0.37, 0.8)
	h.color("#2e322b", Geo.DARK)
	h.grille(Vector3(0, 0.467, -0.55), 0.58, 0.3, 8)
	h.color("#596245", Geo.PAINT)
	for z in [-0.42, -0.33]:
		h.jerrycan(Vector3(-0.45, 0.47, z), 90)
	h.color("#7a5c3a", Geo.WOOD)
	h.cbox(Vector3(0.43, 0.5, -0.4), Vector3(0.14, 0.08, 0.3), 0.012)
	_team_band(h, 0.6, 0.38, -0.7, -0.1)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.47, -0.08))
	var t = _turret(piv, root, mat, func(t) -> void:
		t.color(TP_S, Geo.STEEL)
		t.cyl(0.3, 0.3, 0.03, 16, Transform3D.IDENTITY)
		# faceted Skyranger-style turret: wide low front, steep faceted sides, tall rear
		t.color(TP, Geo.PAINT)
		t.plan_loft([Vector2(-0.22, 0.34), Vector2(0.22, 0.34), Vector2(0.36, 0.12), Vector2(0.36, -0.3), Vector2(-0.36, -0.3), Vector2(-0.36, 0.12)], 0.02, 0.3, Vector2(0.86, 0.8), Vector2(0, -0.04))
		t.color(TP_D, Geo.PAINT)
		for s in [-1.0, 1.0]:   # angled side armour facets
			t.plate(Vector3(s * 0.37, 0.15, -0.05), Vector3(0.03, 0.22, 0.42), Vector3(0, 0, -s * 14.0))
		# central gun mantlet + feed housing
		t.cbox(Vector3(0, 0.15, 0.36), Vector3(0.16, 0.18, 0.12), 0.02)
		# roof search radar: four AESA panels around a mast (reads as the boxy radar head)
		t.color(TP_S, Geo.STEEL)
		t.tube(Vector3(0, 0.3, -0.12), Vector3(0, 0.42, -0.12), 0.04, 8)
		t.color("#6b6a58", Geo.PAINT)
		t.cbox(Vector3(0, 0.48, -0.12), Vector3(0.26, 0.14, 0.26), 0.02)
		t.color("#3a3d38", Geo.DARK)
		for k in 4:
			var a := TAU * float(k) / 4.0 + PI * 0.25
			t.plate(Vector3(0, 0.48, -0.12) + Vector3(sin(a), 0, cos(a)) * 0.135 * 1.0, Vector3(0.18, 0.11, 0.008), Vector3(0, rad_to_deg(a), 0))
		# EO fire-control sensor (left) and counter-drone laser head (right)
		t.color(TP_D, Geo.PAINT)
		t.cbox(Vector3(-0.24, 0.36, 0.12), Vector3(0.12, 0.12, 0.14), 0.015)
		t.color(GLASS_C, Geo.GLASS)
		t.box(Vector3(-0.24, 0.37, 0.192), Vector3(0.08, 0.07, 0.006))
		t.color(TP_S, Geo.STEEL)
		t.tube(Vector3(0.24, 0.3, 0.0), Vector3(0.24, 0.36, 0.0), 0.03, 8)
		t.color("#6b6a58", Geo.PAINT)
		t.tube(Vector3(0.24, 0.4, -0.1), Vector3(0.24, 0.4, 0.14), 0.05, 10)
		t.color("#7fd8ff", Geo.LAMP)
		t.tube(Vector3(0.24, 0.4, 0.14), Vector3(0.24, 0.4, 0.146), 0.036, 10)
		_smoke(t, Vector3(0.3, 0.26, 0.2), 30.0, 3)
		_smoke(t, Vector3(-0.3, 0.26, 0.2), 150.0, 3)
		t.color(TP_S, Geo.STEEL)
		for s in [-1.0, 1.0]:
			t.tube(Vector3(s * 0.28, 0.3, -0.28), Vector3(s * 0.28, 0.7, -0.3), 0.005, 3)
		t.color("#ffffff", Geo.TEAM)
		for s in [-1.0, 1.0]:
			t.plate(Vector3(s * 0.395, 0.18, -0.05), Vector3(0.008, 0.04, 0.34), Vector3(0, 0, -s * 14.0)))
	var b = _barrel(piv, root, mat, Vector3(0, 0.16, 0.42), func(b) -> void:
		b.color(TP_S, Geo.STEEL)
		b.tube(Vector3(0, 0, -0.02), Vector3(0, 0, 0.14), 0.05, 10)   # revolver housing
		b.color("#3a3a36", Geo.STEEL)
		b.tube(Vector3(0, 0, 0.14), Vector3(0, 0, 0.98), 0.022, 10, 0.02)   # single long 35 mm barrel
		b.tube(Vector3(0, 0, 0.9), Vector3(0, 0, 1.02), 0.036, 10)   # muzzle velocity sensor ring
		b.tube(Vector3(0, 0, 1.02), Vector3(0, 0, 1.04), 0.024, 10))
	_finish(root, model, h, mat, "hailstorm", [t, b], 1.45)

# ------------------------------------------------------------------ Fajr-5 rocket truck
static func _fajr() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.25, "recoil": 0.02, "wreck_s": 7.0, "steer_max": 0.35})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8._tyres(h, 0.4, [0.6, -0.2, -0.58], 0.15, 0.13, 1, TP_S)
	h.color("#2e2d2a", Geo.DARK)
	h.cbox(Vector3(0, 0.3, -0.05), Vector3(0.5, 0.08, 1.7), 0.015)
	# bonneted cab
	h.color(TP, Geo.PAINT)
	h.xloft([[0.98, K.sect(0.3, 0.38, 0.5, 0.3, 0.32, 0.27, 0.04)], [0.7, K.sect(0.3, 0.4, 0.54, 0.33, 0.34, 0.3, 0.04)]])
	var c0 := K.sect(0.34, 0.45, 0.56, 0.38, 0.38, 0.37, 0.02)
	var c1 := K.sect(0.34, 0.46, 0.84, 0.38, 0.38, 0.34, 0.04)
	var c2 := K.sect(0.34, 0.46, 0.84, 0.38, 0.38, 0.34, 0.04)
	h.xloft([[0.7, c0], [0.6, c1], [0.3, c2]])
	V8._glass(h, c0, 0.7, c1, 0.6, 4, 5, Vector2(0.06, 0.94), Vector2(0.1, 0.88), Vector3(0, 1, 1))
	for s in [-1.0, 1.0]:
		V8._glass(h, c1, 0.6, c2, 0.3, 2 if s > 0 else 7, 3 if s > 0 else 6, Vector2(0.18, 0.88), Vector2(0.1, 0.55), Vector3(s, 0, 0))
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.42, 0.985), 0.4, 0.1, 5)
	V4._lamps(h, 0.25, 0.42, 0.985)
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(0.3, 0.6, 0.28), Vector3(0.3, 0.95, 0.28), 0.022, 6)
	# launcher deck + stabiliser jacks
	h.color(TP_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -0.45), Vector3(0.76, 0.08, 1.0), 0.015)
	for s in [-1.0, 1.0]:
		h.color(TP_S, Geo.STEEL)
		h.tube(Vector3(s * 0.38, 0.4, -0.85), Vector3(s * 0.42, 0.08, -0.85), 0.025, 6)
		h.cbox(Vector3(s * 0.42, 0.04, -0.85), Vector3(0.1, 0.03, 0.1), 0.008)
	_team_band(h, 0.38, 0.42, 0.35, 0.7)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.5, -0.5))
	var t = _turret(piv, root, mat, func(t) -> void:
		t.color(TP_S, Geo.STEEL)
		t.cyl(0.16, 0.16, 0.05, 12, Transform3D.IDENTITY)
		t.cbox(Vector3(0, 0.1, 0), Vector3(0.24, 0.12, 0.3), 0.02))
	var b = _barrel(piv, root, mat, Vector3(0, 0.22, 0.0), func(b) -> void:
		var tilt := Basis(Vector3.RIGHT, -0.25)
		b.color(TP, Geo.PAINT)
		b.cbox(Vector3.ZERO, Vector3(0.62, 0.3, 0.9), 0.02, Transform3D(tilt, Vector3(0, 0.05, 0.05)))   # 4 x 4 tube box
		b.color("#1d1d1b", Geo.DARK)
		for r in 4:
			for c in 4:
				var p := Vector3(-0.21 + c * 0.14, -0.09 + r * 0.065, 0.452)
				b.tube(Vector3(0, 0.05, 0.05) + tilt * p, Vector3(0, 0.05, 0.05) + tilt * (p + Vector3(0, 0, 0.01)), 0.026, 8)
		b.color("#ffffff", Geo.TEAM)
		b.box(Vector3.ZERO, Vector3(0.008, 0.06, 0.6), Transform3D(tilt, Vector3(0.315, 0.05, 0.05))))
	_finish(root, model, h, mat, "shrike", [t, b], 1.25)

# ------------------------------------------------------------------ jets (M3.0 E: F-4E and Kowsar further down)
static func _jet_root():
	return VK._root({"selection_radius": 0.85, "bar_height": 1.0, "recoil": 0.0, "wreck_s": 6.0})

static func _canopy(h, z0: float, z1: float, y: float) -> void:
	h.color("#5a6a78", Geo.GLASS)
	h.xloft([[z0, K.sect(y, y + 0.005, y + 0.015, 0.025, 0.03, 0.025, 0.004)], [lerpf(z0, z1, 0.35), K.sect(y - 0.01, y + 0.01, y + 0.08, 0.045, 0.052, 0.035, 0.016)],
		[lerpf(z0, z1, 0.7), K.sect(y - 0.01, y + 0.01, y + 0.075, 0.045, 0.05, 0.034, 0.016)], [z1, K.sect(y, y + 0.005, y + 0.015, 0.02, 0.025, 0.02, 0.004)]])

static func _nozzle(h, x: float, y: float, z: float, r: float) -> void:
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(x, y, z), Vector3(x, y, z - 0.14), r, 10, r * 0.85)
	h.color("#ff7a2a", Geo.LAMP)
	h.tube(Vector3(x, y, z - 0.14), Vector3(x, y, z - 0.145), r * 0.7, 10)

## MiG-29-style interceptor: wide lifting body with LERX, under-slung twin intakes, twin fins.
static func _mig29() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root = _jet_root()
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.24, 0.25, 0.26, 0.003, 0.008, 0.003, 0.0)], [0.66, K.sect(0.2, 0.25, 0.32, 0.03, 0.06, 0.04, 0.015)],
		[0.3, K.sect(0.2, 0.25, 0.33, 0.05, 0.08, 0.05, 0.02)], [-0.1, K.sect(0.17, 0.23, 0.3, 0.2, 0.24, 0.16, 0.03)], [-0.7, K.sect(0.17, 0.22, 0.28, 0.2, 0.22, 0.15, 0.03)], [-0.86, K.sect(0.18, 0.22, 0.26, 0.16, 0.18, 0.12, 0.02)]])
	_canopy(h, 0.7, 0.38, 0.32)
	for s in [-1.0, 1.0]:
		h.color(AIR_D, Geo.PAINT)   # LERX + under-slung intake ramps
		V8._surf(h, [Vector3(s * 0.04, 0.25, 0.55), Vector3(s * 0.22, 0.24, 0.0), Vector3(s * 0.22, 0.24, -0.1), Vector3(s * 0.04, 0.25, -0.1)], Vector3(0, 1, 0), 0.02, 0.01)
		h.xloft([[0.3, K.sect(0.08, 0.11, 0.17, 0.05, 0.055, 0.05, 0.01)], [-0.2, K.sect(0.1, 0.13, 0.19, 0.06, 0.065, 0.06, 0.015)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.12, 0, 0)))
		h.color("#1d1f1e", Geo.DARK)
		h.plate(Vector3(s * 0.12, 0.125, 0.303), Vector3(0.09, 0.08, 0.008), Vector3(-20, 0, 0))
		h.color(AIR_D, Geo.PAINT)
		V8._surf(h, [Vector3(s * 0.2, 0.22, 0.05), Vector3(s * 0.74, 0.21, -0.4), Vector3(s * 0.74, 0.21, -0.5), Vector3(s * 0.2, 0.22, -0.55)], Vector3(0, 1, 0), 0.04, 0.01)
		V8._surf(h, [Vector3(s * 0.18, 0.22, -0.66), Vector3(s * 0.48, 0.21, -0.86), Vector3(s * 0.48, 0.21, -0.94), Vector3(s * 0.18, 0.22, -0.92)], Vector3(0, 1, 0), 0.02, 0.008)
		var fb := Basis(Vector3.FORWARD, s * deg_to_rad(8.0))
		V8._surf(h, [Vector3(0, 0, -0.48), Vector3(0, 0.36, -0.74), Vector3(0, 0.36, -0.84), Vector3(0, 0, -0.86)], Vector3(1, 0, 0), 0.02, 0.008, Transform3D(fb, Vector3(s * 0.15, 0.26, 0)))
		h.color("#5d6250", Geo.PAINT)   # R-73-style AAMs
		for x in [0.45, 0.62]:
			h.tube(Vector3(s * x, 0.15, -0.1), Vector3(s * x, 0.15, -0.38), 0.016, 6)
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.5, 0.222, -0.35), Vector3(0.14, 0.01, 0.07))
		_nozzle(h, s * 0.09, 0.21, -0.86, 0.055)
	V8._gear(h, [Vector3(0, 0.0, 0.48), Vector3(-0.16, 0.0, -0.25), Vector3(0.16, 0.0, -0.25)], 0.04)
	_finish(root, model, h, mat, "mig29", [], 1.0)

## M3.0 E (Iran): Safir-style military 4x4 jeep with a 12.7 mm DShK on a pedestal (was the
## white Technical pickup). Open body, fold-down windscreen frame, roll bar, jerrycans, spare.
static func _technical() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.6, "bar_height": 1.1, "recoil": 0.05, "wreck_s": 6.0, "steer_max": 0.4})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	V8._tyres(h, 0.32, [0.42, -0.4], 0.13, 0.1, 1, TP_S)
	h.color("#2e2d2a", Geo.DARK)
	h.cbox(Vector3(0, 0.2, 0.0), Vector3(0.4, 0.06, 1.22), 0.01)   # ladder frame
	h.color(TP, Geo.PAINT)
	# flat bonnet with a slatted grille, slab body tub, flat fenders over the wheels
	h.xloft([[0.7, K.sect(0.22, 0.3, 0.38, 0.3, 0.31, 0.29, 0.02)], [0.28, K.sect(0.22, 0.32, 0.44, 0.32, 0.33, 0.31, 0.02)]])
	h.xloft([[0.28, K.sect(0.22, 0.3, 0.46, 0.35, 0.35, 0.34, 0.015)], [-0.66, K.sect(0.22, 0.3, 0.46, 0.35, 0.35, 0.34, 0.015)]])
	h.color(TP_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [0.42, -0.4]:
			h.cbox(Vector3(s * 0.33, 0.37, z), Vector3(0.12, 0.025, 0.36), 0.008)   # flat fenders
		h.cbox(Vector3(s * 0.352, 0.37, -0.1), Vector3(0.012, 0.1, 0.18), 0.004)   # open door cut-out edge
	h.color("#2b2b2a", Geo.DARK)
	for x in [-0.18, -0.09, 0.0, 0.09, 0.18]:
		h.box(Vector3(x, 0.31, 0.705), Vector3(0.03, 0.1, 0.008))   # grille slots
	V4._lamps(h, 0.24, 0.34, 0.705)
	h.color(TP_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.22, 0.73), Vector3(0.66, 0.05, 0.05), 0.01)   # bumper
	# windscreen frame (glass down), seats, roll bar
	h.color(TP_D, Geo.PAINT)
	h.pipe([Vector3(-0.3, 0.44, 0.27), Vector3(-0.3, 0.66, 0.24), Vector3(0.3, 0.66, 0.24), Vector3(0.3, 0.44, 0.27)], 0.012)
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.55, 0.255), Vector3(0.56, 0.2, 0.006), Vector3(-10, 0, 0))
	h.color("#4b4436", Geo.CANVAS)
	for x in [-0.15, 0.15]:
		h.cbox(Vector3(x, 0.38, 0.05), Vector3(0.18, 0.06, 0.18), 0.02)
		h.cbox(Vector3(x, 0.47, -0.04), Vector3(0.18, 0.18, 0.04), 0.015)
	h.color(TP_S, Geo.STEEL)
	h.pipe([Vector3(-0.33, 0.46, -0.2), Vector3(-0.33, 0.78, -0.22), Vector3(0.33, 0.78, -0.22), Vector3(0.33, 0.46, -0.2)], 0.015)
	h.tube(Vector3(0, 0.3, -0.45), Vector3(0, 0.62, -0.45), 0.03, 8)   # gun pedestal
	h.color("#4d5741", Geo.PAINT)
	for x in [-0.26, -0.16]:
		h.jerrycan(Vector3(x, 0.3, -0.69), 0)
	h.tyre(Vector3(0.18, 0.4, -0.7), 0.12, 0.06, false, TP_S, 10)   # spare on the tail
	h.color("#5a4b30", Geo.WOOD)
	h.cbox(Vector3(0.2, 0.34, -0.45), Vector3(0.12, 0.08, 0.16), 0.01)   # ammo box
	h.color("#b33a2a", Geo.LAMP)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.3, 0.36, -0.665), Vector3(0.04, 0.03, 0.006))
	_team_band(h, 0.352, 0.28, -0.6, 0.25)
	V4._antenna(h, Vector3(-0.3, 0.46, -0.6), 0.45)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.66, -0.45))
	var t = _turret(piv, root, mat, func(t) -> void:
		t.color("#2b2b2a", Geo.STEEL)
		t.cyl(0.05, 0.04, 0.06, 8, Transform3D.IDENTITY)
		t.cbox(Vector3(0, 0.06, -0.04), Vector3(0.1, 0.1, 0.22), 0.012)   # receiver
		t.tube(Vector3(-0.07, 0.03, -0.18), Vector3(-0.07, 0.09, -0.22), 0.012, 5)   # spade grips
		t.tube(Vector3(0.07, 0.03, -0.18), Vector3(0.07, 0.09, -0.22), 0.012, 5)
		t.color(TP_D, Geo.PAINT)
		t.plate(Vector3(0, 0.1, 0.12), Vector3(0.3, 0.18, 0.015), Vector3(-8, 0, 0))   # small gun shield
		t.color("#4a4a3a", Geo.PAINT)
		t.cbox(Vector3(0.09, 0.04, 0.0), Vector3(0.07, 0.07, 0.12), 0.008)   # ammo can
		t.color("#ffffff", Geo.TEAM)
		t.box(Vector3(0, 0.16, 0.131), Vector3(0.2, 0.03, 0.006)))
	var b = _barrel(piv, root, mat, Vector3(0, 0.07, 0.06), func(b) -> void:
		b.color("#2b2b2a", Geo.STEEL)
		b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 0.52), 0.016, 8)   # DShK barrel
		for z in [0.06, 0.12, 0.18]:
			b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.025), 0.026, 8)   # cooling fins
		b.tube(Vector3(0, 0, 0.48), Vector3(0, 0, 0.55), 0.024, 8))   # muzzle brake
	_finish(root, model, h, mat, "rattler", [t, b], 1.1)

## M3.0 E (Iran): Raad-2-style 155 mm self-propelled howitzer (was the Koksan): tracked hull,
## large boxy rear turret with side doors, long 155 mm barrel with a muzzle brake, travel lock.
static func _koksan() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.9, "bar_height": 1.3, "recoil": 0.22, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tracked_hull(h, 0.52, 1.7, 6, 0.44, TP, TP_D)
	h.color("#2e322b", Geo.DARK)
	h.grille(Vector3(0.18, 0.446, 0.55), 0.3, 0.26, 6)
	h.color(TP_D, Geo.PAINT)
	h.hatch(Vector3(-0.24, 0.45, 0.62), 0.12)
	V4._lamps(h, 0.4, 0.36, 0.86)
	h.tube(Vector3(0, 0.45, 0.72), Vector3(0, 0.66, 0.72), 0.025, 6)   # travel lock
	h.cbox(Vector3(0, 0.67, 0.72), Vector3(0.14, 0.04, 0.05), 0.01)
	h.color(TP_S, Geo.STEEL)
	for x in [-0.3, 0.3]:
		h.plate(Vector3(x, 0.24, -0.88), Vector3(0.16, 0.18, 0.03), Vector3(25, 0, 0))   # rear spades
	h.color(TP_D, Geo.PAINT)
	h.plate(Vector3(0, 0.36, -0.86), Vector3(0.4, 0.14, 0.02), Vector3(0, 0, 0))   # rear door
	_team_band(h, 0.56, 0.38, -0.3, 0.6)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.44, -0.28))
	var t = _turret(piv, root, mat, func(t) -> void:
		t.color(TP_S, Geo.STEEL)
		t.cyl(0.36, 0.36, 0.03, 14, Transform3D.IDENTITY)
		t.color(TP, Geo.PAINT)
		t.plan_loft([Vector2(-0.44, -0.52), Vector2(0.44, -0.52), Vector2(0.46, 0.3), Vector2(0.3, 0.46), Vector2(-0.3, 0.46), Vector2(-0.46, 0.3)], 0.02, 0.36, Vector2(0.94, 0.94))
		t.color(TP_D, Geo.PAINT)
		for s in [-1.0, 1.0]:
			t.plate(Vector3(s * 0.455, 0.18, -0.1), Vector3(0.012, 0.24, 0.3), Vector3(0, 0, 0))   # side doors
		t.cbox(Vector3(0.24, 0.4, -0.1), Vector3(0.18, 0.06, 0.18), 0.012)   # commander's cupola
		t.hatch(Vector3(-0.22, 0.37, -0.2), 0.13)
		t.color(TP_S, Geo.STEEL)
		t.tube(Vector3(0.24, 0.43, -0.1), Vector3(0.24, 0.48, 0.05), 0.012, 4)   # roof MG
		t.tube(Vector3(0.24, 0.48, 0.05), Vector3(0.24, 0.48, 0.25), 0.01, 4)
		t.color("#6b5a3a", Geo.CANVAS)
		t.cbox(Vector3(0, 0.2, -0.56), Vector3(0.7, 0.14, 0.08), 0.02)   # rear stowage
		t.color("#ffffff", Geo.TEAM)
		for s in [-1.0, 1.0]:
			t.box(Vector3(s * 0.462, 0.3, 0.15), Vector3(0.006, 0.04, 0.24)))
	var b = _barrel(piv, root, mat, Vector3(0, 0.2, 0.46), func(b) -> void:
		b.color(TP_D, Geo.PAINT)
		b.cbox(Vector3(0, 0, -0.02), Vector3(0.2, 0.18, 0.1), 0.015)   # mantlet
		b.color(TP, Geo.PAINT)
		b.gun(0.03, 1.45, 0.045, 0.034, 0.6, true, 10))   # 155 mm, fume extractor, muzzle brake
	_finish(root, model, h, mat, "blight", [t, b], 1.3)

## M3.0 E (Iran): F-4E-style strike jet (was the F-16): long drooped nose, tandem canopy, big
## side intakes with splitter plates, upturned outer wing panels, anhedral tailplanes, twin
## engines; bombs under the wings.
static func _f16() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root = _jet_root()
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[1.06, K.sect(0.2, 0.21, 0.22, 0.004, 0.01, 0.004, 0.0)], [0.74, K.sect(0.15, 0.2, 0.28, 0.05, 0.07, 0.05, 0.02)],
		[0.3, K.sect(0.14, 0.21, 0.32, 0.08, 0.1, 0.08, 0.03)], [-0.5, K.sect(0.13, 0.2, 0.3, 0.14, 0.16, 0.1, 0.03)], [-0.86, K.sect(0.15, 0.2, 0.27, 0.12, 0.13, 0.09, 0.02)]])
	_canopy(h, 0.72, 0.22, 0.29)
	for s in [-1.0, 1.0]:
		h.color(AIR_D, Geo.PAINT)   # rectangular side intakes + splitter plates
		h.xloft([[0.36, K.sect(0.12, 0.17, 0.27, 0.04, 0.05, 0.04, 0.01)], [-0.2, K.sect(0.12, 0.17, 0.27, 0.05, 0.06, 0.05, 0.015)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.13, 0, 0)))
		h.color("#1d1f1e", Geo.DARK)
		h.box(Vector3(s * 0.14, 0.19, 0.362), Vector3(0.08, 0.12, 0.008))
		h.color(TP_S, Geo.STEEL)
		h.plate(Vector3(s * 0.085, 0.19, 0.36), Vector3(0.006, 0.13, 0.1), Vector3(0, 0, 0))
		h.color(AIR_D, Geo.PAINT)
		V8._surf(h, [Vector3(s * 0.16, 0.16, 0.12), Vector3(s * 0.58, 0.16, -0.28), Vector3(s * 0.58, 0.16, -0.42), Vector3(s * 0.16, 0.16, -0.5)], Vector3(0, 1, 0), 0.04, 0.012)   # inner wing
		V8._surf(h, [Vector3(s * 0.58, 0.16, -0.28), Vector3(s * 0.8, 0.24, -0.44), Vector3(s * 0.8, 0.24, -0.52), Vector3(s * 0.58, 0.16, -0.42)], Vector3(0, 1, 0), 0.02, 0.008)   # upturned outer panel
		V8._surf(h, [Vector3(s * 0.1, 0.24, -0.66), Vector3(s * 0.42, 0.14, -0.84), Vector3(s * 0.42, 0.14, -0.92), Vector3(s * 0.1, 0.24, -0.9)], Vector3(0, 1, 0), 0.02, 0.008)   # anhedral tailplane
		h.color("#5d6250", Geo.PAINT)   # bombs
		for x in [0.32, 0.46]:
			h.tube(Vector3(s * x, 0.08, 0.0), Vector3(s * x, 0.08, -0.3), 0.035, 8)
			h.cyl(0.035, 0.0, 0.08, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * x, 0.08, 0.0)))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.42, 0.172, -0.36), Vector3(0.14, 0.01, 0.07))
		_nozzle(h, s * 0.07, 0.2, -0.86, 0.06)
	h.color("#5d6250", Geo.PAINT)
	h.tube(Vector3(0, 0.1, 0.0), Vector3(0, 0.1, -0.4), 0.05, 8)   # centreline fuel tank
	h.color(AIR_D, Geo.PAINT)
	V8._surf(h, [Vector3(0, 0.3, -0.4), Vector3(0, 0.62, -0.72), Vector3(0, 0.62, -0.82), Vector3(0, 0.3, -0.84)], Vector3(1, 0, 0), 0.025, 0.01)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.55, -0.76), Vector3(0.03, 0.06, 0.1))
	V8._gear(h, [Vector3(0, 0.0, 0.5), Vector3(-0.2, 0.0, -0.22), Vector3(0.2, 0.0, -0.22)], 0.04)
	_finish(root, model, h, mat, "f16", [], 1.0)

## M3.0 E (Iran): Kowsar / F-5-style light fighter (was the Delta Fighter): slim shark nose,
## small trapezoid wings with wingtip missiles, LERX, twin engines side by side, single fin.
static func _mirage() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root = _jet_root()
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(AIR, Geo.PAINT)
	h.xloft([[1.04, K.sect(0.225, 0.23, 0.235, 0.003, 0.006, 0.003, 0.0)], [0.66, K.sect(0.18, 0.22, 0.28, 0.035, 0.06, 0.04, 0.015)],
		[0.2, K.sect(0.16, 0.21, 0.29, 0.06, 0.08, 0.06, 0.02)], [-0.6, K.sect(0.16, 0.21, 0.28, 0.09, 0.1, 0.07, 0.02)], [-0.84, K.sect(0.17, 0.21, 0.26, 0.08, 0.09, 0.06, 0.02)]])
	_canopy(h, 0.64, 0.36, 0.27)
	for s in [-1.0, 1.0]:
		h.color(AIR_D, Geo.PAINT)
		h.xloft([[0.3, K.sect(0.16, 0.2, 0.25, 0.025, 0.035, 0.025, 0.01)], [-0.2, K.sect(0.15, 0.2, 0.26, 0.035, 0.045, 0.035, 0.012)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.09, 0, 0)))   # side intakes
		h.color("#1d1f1e", Geo.DARK)
		h.box(Vector3(s * 0.095, 0.205, 0.302), Vector3(0.05, 0.08, 0.006))
		h.color(AIR_D, Geo.PAINT)
		V8._surf(h, [Vector3(s * 0.04, 0.22, 0.5), Vector3(s * 0.14, 0.21, 0.1), Vector3(s * 0.14, 0.21, 0.0), Vector3(s * 0.04, 0.22, 0.0)], Vector3(0, 1, 0), 0.015, 0.008)   # LERX
		V8._surf(h, [Vector3(s * 0.12, 0.2, 0.06), Vector3(s * 0.56, 0.2, -0.26), Vector3(s * 0.56, 0.2, -0.36), Vector3(s * 0.12, 0.2, -0.4)], Vector3(0, 1, 0), 0.03, 0.008)   # trapezoid wing
		V8._surf(h, [Vector3(s * 0.08, 0.21, -0.6), Vector3(s * 0.32, 0.21, -0.76), Vector3(s * 0.32, 0.21, -0.84), Vector3(s * 0.08, 0.21, -0.82)], Vector3(0, 1, 0), 0.015, 0.006)
		h.color("#5d6250", Geo.PAINT)
		h.tube(Vector3(s * 0.57, 0.2, -0.12), Vector3(s * 0.57, 0.2, -0.42), 0.016, 6)   # wingtip AAM
		h.tube(Vector3(s * 0.3, 0.12, 0.0), Vector3(s * 0.3, 0.12, -0.26), 0.035, 8)   # rocket pod
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.38, 0.212, -0.25), Vector3(0.12, 0.01, 0.07))
		_nozzle(h, s * 0.045, 0.21, -0.84, 0.042)
	h.color(AIR_D, Geo.PAINT)
	V8._surf(h, [Vector3(0, 0.27, -0.36), Vector3(0, 0.6, -0.68), Vector3(0, 0.6, -0.78), Vector3(0, 0.27, -0.8)], Vector3(1, 0, 0), 0.022, 0.01)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.52, -0.72), Vector3(0.03, 0.06, 0.1))
	V8._gear(h, [Vector3(0, 0.0, 0.45), Vector3(-0.12, 0.0, -0.22), Vector3(0.12, 0.0, -0.22)], 0.035)
	_finish(root, model, h, mat, "mirage", [], 1.0)

# ------------------------------------------------------------------ TPLA defences (BuildingView)
static func _make_b(short: String, fp: Vector2, top: float, hull_fn: Callable, turret_fn: Callable = Callable(), tpos := Vector3.ZERO) -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/buildings/building_view.gd"))
	root.set("selection_radius", maxf(fp.x, fp.y) * 0.5)
	root.set("bar_height", top + 0.15)
	root.set("footprint", fp)
	root.set("is_structure", true)
	root.set("top_y", top + 0.05)
	root.set("scaffold_top", top * 0.8)
	var model := VK._n3(root, root, "Model")
	var f = B4._foundation(fp, true)
	VK._mi(model, root, "Foundation", f.commit(mat))
	var h = K.new()
	hull_fn.call(h)
	VK._mi(model, root, "Hull", h.commit(mat))
	var parts: Array = [h, f]
	if turret_fn.is_valid():
		var pv := VK._n3(model, root, "TurretPivot", tpos)
		var t = K.new()
		turret_fn.call(t)
		VK._mi(pv, root, "Turret", t.commit(mat))
		parts.append(t)
	VK._mi(model, root, "Scaffold", B4._scaffold(fp, top * 0.8).commit(mat)).visible = false
	VK._mi(model, root, "DamageLight", B4._damage_light(fp, true).commit(mat)).visible = false
	VK._mi(model, root, "DamageHeavy", B4._damage_heavy(fp, top, true).commit(mat)).visible = false
	VK._mi(model, root, "Rubble", B4._rubble(fp, true).commit(mat)).visible = false
	var i := 0
	for p in [Vector3(-fp.x * 0.3, top * 0.6, fp.y * 0.15), Vector3(fp.x * 0.3, top * 0.5, -fp.y * 0.3), Vector3(0, top * 0.3, fp.y * 0.3)]:
		var mk := Marker3D.new()
		mk.name = "Fire%d" % i
		mk.position = p
		model.add_child(mk)
		mk.owner = root
		i += 1
	var tr := 0
	for g in parts:
		tr += g.tris
	print("  tpla_%s: %d tris" % [short, tr])
	var path := "res://view/buildings/tpla/%s.tscn" % short
	VK._save(root, path, top + 0.15)
	wrote.append(path)

static func _sandbag_ring(g, c: Vector3, r: float, rows: int, n: int, gap_a := -1.0, gap_w := 0.0) -> void:
	for row in rows:
		for i in n:
			var a := TAU * (float(i) + row * 0.5) / float(n)
			if gap_a >= 0.0 and absf(wrapf(a - gap_a, -PI, PI)) < gap_w:
				continue
			g.sandbag(c + Vector3(cos(a) * r, 0.035 + row * 0.07, sin(a) * r), TAU * r / n * 1.05, -rad_to_deg(a) + 90.0, "#a08a5c" if (i + row) % 3 else "#8f7b52")

static func _crate(g, c: Vector3, s: Vector3, yaw: float) -> void:
	g.color("#6b5236", Geo.WOOD)
	g.cbox(Vector3.ZERO, s, 0.01, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c))
	g.color("#3a3128", Geo.DARK)
	g.box(Vector3.ZERO, Vector3(s.x * 1.02, 0.012, s.z * 1.02), Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c + Vector3(0, s.y * 0.25, 0)))

## Tunnel Network: an earth-covered concrete bunker entrance with a timber-framed mouth, ramp,
## sandbag walls, a scrap lean-to, oil drums, and a gun pit on top with a DShK-style HMG.
static func _tunnel(g) -> void:
	g.color("#8a7656", Geo.CONCRETE)   # earth mound
	g.plan_loft([Vector2(-0.9, -0.8), Vector2(0.9, -0.8), Vector2(0.95, 0.3), Vector2(0.6, 0.75), Vector2(-0.6, 0.75), Vector2(-0.95, 0.3)], Y0, Y0 + 0.36, Vector2(0.62, 0.55), Vector2(0, -0.08))
	g.color("#7d6a4c", Geo.CONCRETE)
	g.plan_loft([Vector2(-0.55, -0.5), Vector2(0.55, -0.5), Vector2(0.55, 0.2), Vector2(-0.55, 0.2)], Y0 + 0.36, Y0 + 0.44, Vector2(0.9, 0.85))
	# concrete portal (faces +z) with a dark mouth and timber frame
	g.color("#9a9384", Geo.CONCRETE)
	g.cbox(Vector3(0, Y0 + 0.2, 0.55), Vector3(0.72, 0.4, 0.16), 0.02)
	g.color("#0d0c0b", Geo.DARK)
	g.box(Vector3(0, Y0 + 0.16, 0.635), Vector3(0.42, 0.3, 0.01))
	g.color("#6b5236", Geo.WOOD)
	for x in [-0.23, 0.23]:
		g.cbox(Vector3(x, Y0 + 0.17, 0.645), Vector3(0.05, 0.34, 0.05), 0.008)
	g.cbox(Vector3(0, Y0 + 0.34, 0.645), Vector3(0.56, 0.05, 0.06), 0.008)
	g.color("#7d7362", Geo.CONCRETE)   # ramp down into the mouth
	g.plate(Vector3(0, Y0 + 0.02, 0.82), Vector3(0.42, 0.03, 0.32), Vector3(8, 0, 0))
	# sandbag wing walls
	for s in [-1.0, 1.0]:
		for row in 3:
			for k in 3:
				g.sandbag(Vector3(s * 0.42, Y0 + 0.035 + row * 0.07, 0.68 + k * 0.11), 0.2, 90.0)
	# scrap lean-to on the side, oil drums, camo patches on the mound
	g.color("#7b4a2a", Geo.SCRAP)
	g.plate(Vector3(-0.62, Y0 + 0.25, -0.3), Vector3(0.36, 0.02, 0.5), Vector3(0, 0, 30))
	g.color("#6b5236", Geo.WOOD)
	g.tube(Vector3(-0.78, Y0, -0.08), Vector3(-0.78, Y0 + 0.17, -0.08), 0.015, 4)
	g.tube(Vector3(-0.78, Y0, -0.52), Vector3(-0.78, Y0 + 0.17, -0.52), 0.015, 4)
	for k in 3:
		g.color(["#4a5a3a", "#7b3a2a", "#3a4a5a"][k], Geo.SCRAP)
		g.cyl(0.06, 0.06, 0.17, 10, Transform3D(Basis.IDENTITY, Vector3(0.66 + (k % 2) * 0.12, Y0, 0.42 + k * 0.08)))
	g.color("#5d6644", Geo.CANVAS)
	g.rbox(Vector3(0.3, Y0 + 0.38, -0.35), Vector3(0.5, 0.02, 0.4), Vector3(3, 20, -4))
	_crate(g, Vector3(-0.6, Y0 + 0.07, 0.35), Vector3(0.2, 0.14, 0.14), 20.0)
	# gun pit sandbags on top
	_sandbag_ring(g, Vector3(0, Y0 + 0.42, 0.35 - 0.35), 0.24, 2, 10, PI * 0.5, 0.5)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.36, 0.635), Vector3(0.6, 0.04, 0.006))

static func _tunnel_turret(t) -> void:
	t.xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.5), Vector3.ZERO)
	t.color("#2b2b2a", Geo.STEEL)
	t.tube(Vector3(0, -0.1, 0), Vector3(0, 0.12, 0), 0.025, 6)
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:   # tripod
		t.tube(Vector3(0, 0.02, 0), Vector3(sin(a) * 0.12, -0.08, cos(a) * 0.12), 0.012, 4)
	t.cbox(Vector3(0, 0.15, -0.02), Vector3(0.08, 0.08, 0.22), 0.01)
	t.tube(Vector3(0, 0.15, 0.08), Vector3(0, 0.15, 0.42), 0.014, 6)
	t.tube(Vector3(0, 0.15, 0.08), Vector3(0, 0.15, 0.2), 0.024, 8)   # finned barrel
	t.tube(Vector3(0, 0.15, 0.4), Vector3(0, 0.15, 0.45), 0.022, 6)
	t.color("#5a5444", Geo.PAINT)
	t.plate(Vector3(0, 0.18, 0.12), Vector3(0.26, 0.14, 0.012), Vector3(-6, 0, 0))
	t.color("#4a4a3a", Geo.PAINT)
	t.cbox(Vector3(0.07, 0.13, 0.0), Vector3(0.06, 0.06, 0.1), 0.008)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.23, 0.128), Vector3(0.18, 0.025, 0.006))

## Wasp Nest: a dug-in rocket pit: concrete revetment ring, layered sandbags, camo-net canopy
## on poles, rocket crates and spare tubes, a radio mast; the launcher has 8 tubes and a radar box.
static func _wasp(g) -> void:
	g.color("#8a7d68", Geo.CONCRETE)
	g.ccyl(0.62, 0.16, 0.02, 14, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
	g.color("#9a9384", Geo.CONCRETE)
	for k in 8:   # broken jersey-barrier segments around the pit
		var a := TAU * float(k) / 8.0 + 0.2
		if k == 2:
			continue
		g.rbox(Vector3(cos(a) * 0.82, Y0 + 0.1, sin(a) * 0.82), Vector3(0.36, 0.2, 0.1), Vector3(0, -rad_to_deg(a) + 90.0, 0))
	_sandbag_ring(g, Vector3(0, Y0, 0), 0.68, 3, 14, TAU * 2.0 / 8.0 + 0.2, 0.3)
	# camo-net lean-to over the ammo store at the back (keeps the launcher in view)
	g.color("#6b5236", Geo.WOOD)
	for x in [-0.8, 0.0, 0.8]:
		g.tube(Vector3(x, Y0, -0.85), Vector3(x, Y0 + 0.62, -0.85), 0.018, 5)
	g.color("#5d6644", Geo.CANVAS)
	g.rbox(Vector3(0, Y0 + 0.5, -0.72), Vector3(1.75, 0.012, 0.4), Vector3(-28, 0, 0))
	g.color("#7a7a4a", Geo.CANVAS)
	for k in 5:
		g.rbox(Vector3(-0.65 + k * 0.32, Y0 + 0.52, -0.74), Vector3(0.18, 0.012, 0.14), Vector3(-28, k * 37.0, 0))
	for c in [Vector3(-0.5, Y0 + 0.07, -0.8), Vector3(-0.2, Y0 + 0.07, -0.8), Vector3(0.3, Y0 + 0.07, -0.78)]:
		_crate(g, c, Vector3(0.24, 0.14, 0.12), 5.0)
	for c in [Vector3(-0.62, Y0 + 0.07, 0.58), Vector3(-0.48, Y0 + 0.07, 0.68), Vector3(-0.55, Y0 + 0.21, 0.63)]:
		_crate(g, c, Vector3(0.24, 0.14, 0.12), 30.0)
	g.color("#4d5236", Geo.PAINT)
	for k in 3:
		g.tube(Vector3(0.45 + k * 0.05, Y0 + 0.03, 0.55), Vector3(0.6 + k * 0.05, Y0 + 0.03, 0.2), 0.03, 6)
	g.color("#2b2b2a", Geo.STEEL)   # radio mast with guy wires
	g.tube(Vector3(0.72, Y0, -0.62), Vector3(0.72, Y0 + 1.25, -0.62), 0.012, 4)
	g.tube(Vector3(0.72, Y0 + 1.1, -0.62), Vector3(0.5, Y0, -0.62), 0.003, 3)
	g.tube(Vector3(0.72, Y0 + 1.1, -0.62), Vector3(0.72, Y0, -0.4), 0.003, 3)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.17, 0.625), Vector3(0.4, 0.04, 0.006))

static func _wasp_turret(t) -> void:
	t.color("#3a3734", Geo.STEEL)
	t.cyl(0.14, 0.12, 0.12, 10, Transform3D.IDENTITY)
	t.cbox(Vector3(0, 0.16, -0.05), Vector3(0.2, 0.1, 0.2), 0.015)
	var tilt := Basis(Vector3.RIGHT, -0.35)
	var o := Vector3(0, 0.32, 0)
	t.color(TP, Geo.PAINT)
	t.cbox(Vector3.ZERO, Vector3(0.52, 0.28, 0.56), 0.02, Transform3D(tilt, o))
	t.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		t.box(Vector3.ZERO, Vector3(0.01, 0.08, 0.44), Transform3D(tilt, o + tilt * Vector3(s * 0.262, 0.0, 0)))
	t.color("#1d1d1b", Geo.DARK)
	for r in 2:
		for c in 4:
			var p := Vector3(-0.18 + c * 0.12, -0.06 + r * 0.12, 0.282)
			t.tube(o + tilt * p, o + tilt * (p + Vector3(0, 0, 0.01)), 0.04, 8)
	t.color("#b23a2a", Geo.PAINT)
	for c in 4:
		var p2 := Vector3(-0.18 + c * 0.12, 0.06, 0.29)
		t.cyl(0.028, 0.0, 0.05, 6, Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), o + tilt * p2))
	t.color("#6b6a58", Geo.PAINT)   # tracking radar box on the side
	t.cbox(Vector3(0.36, 0.32, -0.02), Vector3(0.12, 0.16, 0.14), 0.015)
	t.color("#3a3d38", Geo.DARK)
	t.box(Vector3(0.36, 0.32, 0.052), Vector3(0.1, 0.13, 0.006))

## Demo Trap: a buried IED cache: half-buried artillery shells and a drum under a scrap plate,
## loose dirt, a car battery and wires to a pressure plate.
static func _demo_trap(g) -> void:
	g.color("#7d6a4c", Geo.CONCRETE)
	g.plan_loft([Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(0.35, 0.1), Vector2(0.1, 0.34), Vector2(-0.32, 0.2)], Y0, Y0 + 0.06, Vector2(0.7, 0.7))
	g.color("#4d5236", Geo.PAINT)
	for k in 4:   # shells poking out of the dirt
		var a := float(k) * 1.4
		var p := Vector3(cos(a) * 0.14, Y0 + 0.02, sin(a) * 0.14)
		g.tube(p, p + Vector3(0.02, 0.16, 0.03), 0.035, 8)
		g.color("#8a6a2a", Geo.STEEL)
		g.cyl(0.035, 0.0, 0.06, 8, Transform3D(Basis.IDENTITY, p + Vector3(0.02, 0.16, 0.03)))
		g.color("#4d5236", Geo.PAINT)
	g.color("#7b3a2a", Geo.SCRAP)
	g.cyl(0.08, 0.08, 0.14, 10, Transform3D(Basis.IDENTITY, Vector3(-0.15, Y0, -0.12)))
	g.rbox(Vector3(0.1, Y0 + 0.07, -0.1), Vector3(0.28, 0.015, 0.22), Vector3(6, 25, -8))
	g.color("#2b2b2a", Geo.DARK)
	g.cbox(Vector3(0.22, Y0 + 0.04, 0.18), Vector3(0.1, 0.07, 0.07), 0.008)
	g.color("#b33a2a", Geo.RUBBER)
	g.pipe([Vector3(0.22, Y0 + 0.08, 0.18), Vector3(0.05, Y0 + 0.07, 0.1), Vector3(-0.12, Y0 + 0.12, -0.08)], 0.004, 4)
	g.color("#2a6aa0", Geo.RUBBER)
	g.pipe([Vector3(0.24, Y0 + 0.08, 0.18), Vector3(0.3, Y0 + 0.02, 0.32)], 0.004, 4)
	g.color("#ff3a2a", Geo.TEAM_LAMP)
	g.box(Vector3(0.22, Y0 + 0.085, 0.16), Vector3(0.02, 0.012, 0.02))

## Camo Net: a big draped net on poles with leaf patches and hanging fringes.
static func _camo_net(g) -> void:
	g.color("#6b5236", Geo.WOOD)
	for p in [Vector2(-0.42, -0.42), Vector2(0.42, -0.42), Vector2(0.42, 0.42), Vector2(-0.42, 0.42), Vector2(0, 0)]:
		g.tube(Vector3(p.x, Y0, p.y), Vector3(p.x, Y0 + (0.88 if p == Vector2.ZERO else 0.62), p.y), 0.016, 5)
	g.color("#5d6644", Geo.CANVAS)
	for k in 4:   # four sloped panels to the centre pole
		var a := TAU * float(k) / 4.0
		var d := Vector3(sin(a), 0, cos(a))
		g.rbox(Vector3(0, Y0 + 0.75, 0) + d * 0.24, Vector3(0.86, 0.012, 0.5), Vector3(rad_to_deg(0.48), rad_to_deg(a), 0) * Vector3(1, 1, 0) + Vector3(0, 0, 0))
	g.color("#7a7a4a", Geo.CANVAS)
	for k in 10:
		var a2 := float(k) * 2.1
		var r := 0.15 + 0.03 * (k % 5)
		g.rbox(Vector3(cos(a2) * r * 2.0, Y0 + 0.8 - r * 0.6, sin(a2) * r * 2.0), Vector3(0.14, 0.012, 0.1), Vector3(0, rad_to_deg(a2), 0))
	g.color("#4d5536", Geo.CANVAS)
	for k in 12:   # hanging fringes along the edges
		var a3 := TAU * float(k) / 12.0
		var p3 := Vector3(cos(a3) * 0.5, Y0 + 0.5, sin(a3) * 0.5)
		g.box(p3, Vector3(0.06, 0.22, 0.01))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(0, Y0 + 0.86, 0), Vector3(0.08, 0.04, 0.08))

## Decoy Yard: a convincing fake compound: painted facades with false doors and windows, a
## plywood "tank" with a pipe gun under a tarp, inflatable-looking truck, poles bracing it all.
static func _decoy(g) -> void:
	g.color("#b5a27a", Geo.CANVAS)
	g.cbox(Vector3(-0.45, Y0 + 0.5, 0.75), Vector3(1.6, 1.0, 0.04), 0.008)
	g.color("#9c8a62", Geo.CANVAS)
	g.cbox(Vector3(-1.2, Y0 + 0.4, 0.2), Vector3(0.04, 0.8, 1.1), 0.008)
	g.color("#7b4a2a", Geo.SCRAP)
	g.prism_x([Vector2(0.8, Y0 + 1.0), Vector2(0.5, Y0 + 1.25), Vector2(0.2, Y0 + 1.0)], -1.25, 0.35)
	g.color("#2a2622", Geo.DARK)   # painted door, windows and shadows
	g.box(Vector3(-0.45, Y0 + 0.3, 0.772), Vector3(0.36, 0.55, 0.005))
	for x in [-1.0, 0.1]:
		g.box(Vector3(x, Y0 + 0.62, 0.772), Vector3(0.28, 0.22, 0.005))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.45, Y0 + 0.88, 0.772), Vector3(1.0, 0.08, 0.005))
	g.color("#7a5d3c", Geo.WOOD)
	for x in [-1.1, -0.45, 0.2]:
		g.tube(Vector3(x, Y0, 0.2), Vector3(x, Y0 + 0.95, 0.72), 0.02, 4)
	# plywood tank under a tarp
	g.color("#8a7550", Geo.WOOD)
	g.cbox(Vector3(0.65, Y0 + 0.16, -0.5), Vector3(0.62, 0.24, 1.0), 0.03)
	g.color("#6b5a40", Geo.CANVAS)
	g.plan_loft([Vector2(-0.22, -0.26), Vector2(0.22, -0.26), Vector2(0.26, 0.1), Vector2(-0.26, 0.1)], Y0 + 0.28, Y0 + 0.42, Vector2(0.8, 0.8), Vector2.ZERO, Transform3D(Basis.IDENTITY, Vector3(0.65, 0, -0.5)))
	g.color("#3a3734", Geo.STEEL)
	g.tube(Vector3(0.65, Y0 + 0.36, -0.4), Vector3(0.65, Y0 + 0.38, 0.35), 0.03, 6)
	g.color("#2b2d2f", Geo.RUBBER)
	for z in [-0.85, -0.5, -0.15]:
		for x in [0.33, 0.97]:
			g.cyl(0.09, 0.09, 0.06, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, Y0 + 0.09, z)))
	# fake truck silhouette
	g.color("#9c8a62", Geo.CANVAS)
	g.cbox(Vector3(-0.6, Y0 + 0.25, -0.65), Vector3(0.5, 0.36, 0.8), 0.05)
	g.cbox(Vector3(-0.6, Y0 + 0.2, -0.1), Vector3(0.46, 0.28, 0.3), 0.05)
	g.color("#2b2d2f", Geo.RUBBER)
	for z in [-0.95, -0.4, -0.05]:
		for x in [-0.84, -0.36]:
			g.cyl(0.08, 0.08, 0.05, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, Y0 + 0.08, z)))
	_crate(g, Vector3(1.1, Y0 + 0.07, 0.7), Vector3(0.24, 0.14, 0.18), 10.0)

# ------------------------------------------------------------------ Airfield (M2.8 8x8 base, TPLA colours)
static func _airfield() -> void:
	var U = load("res://tools/gfx_m7/us_m7.gd")
	U._make("airfield", Vector2(10, 8), 2.2, U._airbase8.bind("tpla"), Callable(), Vector3.ZERO, "tpla")
	wrote.append("res://view/buildings/tpla/airfield.tscn")
