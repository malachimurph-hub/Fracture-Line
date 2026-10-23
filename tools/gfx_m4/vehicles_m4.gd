extends RefCounted
## M2.4 roster vehicles (tool-time): original procedural models in the M2.2 style (articulated
## TurretPivot / Barrel, spinning wheels and scrolling tracks via the m3 shader, team bands,
## weathering). Roles follow ROSTER_ZH_1TO1.md; shapes are our own designs.
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const K8 := preload("res://tools/gfx_m7/kit8.gd")   # M2.7b: lofts, track runs, tyres

# EU palette (matches the M2.2 Leopold) and TPLA palette (matches the Rattler)
const EU := "#7d8669"
const EU_D := "#5c6551"
const EU_S := "#3c3f40"
const TP := "#b89c70"
const TP_D := "#9a8058"
const TP_S := "#34322f"

static func build_all() -> void:
	var mat: Material = load(VK.MAT_PATH)
	_brennus(mat)
	_salamander(mat)
	_thunderhead(mat)
	_hearth(mat)
	_spectre(mat)
	_sentinel(mat)
	_kestrel(mat)
	_corvid(mat)
	_junkhammer(mat)
	_sprayer(mat)
	_earwig(mat)
	_jackal(mat)
	_bus(mat)

# ------------------------------------------------------------------ shared parts
## Tracked running gear on both sides: half width sx, length l (z from -l/2..l/2).
static func _tracks(h, sx: float, l: float, n: int, rw: float, col_d: String, steel: String, tw := 0.22) -> void:
	if h.has_method("track_run"):   # M2.7b: road wheels with rims, toothed sprocket, idler, return rollers
		h.track_run(sx, l, n, rw, tw, steel)
		return
	var hl := l * 0.5
	for s in [-sx, sx]:
		VK._track(h, s - tw * 0.5, s + tw * 0.5, Vector2(-hl + rw * 1.2, rw * 1.6), rw * 1.45, Vector2(hl - rw * 1.1, rw * 1.8), rw * 1.3, rw * 3.1)
		for i in n:
			var z := lerpf(-hl + rw * 2.6, hl - rw * 2.6, float(i) / float(maxi(1, n - 1)))
			h.wheel(Vector3(s, rw * 1.15, z), rw, tw * 0.9, false, col_d, 12)
		h.wheel(Vector3(s, rw * 1.6, -hl + rw * 1.2), rw * 1.2, tw * 0.9, false, steel, 12, 11)
		h.wheel(Vector3(s, rw * 1.8, hl - rw * 1.1), rw, tw * 0.85, false, col_d, 12)

static func _wheelset(h, sx: float, zs: Array, r: float, w: float, steer_n: int, hub: String) -> void:
	for i in zs.size():
		for s in [-sx, sx]:
			if h.has_method("tyre"):   # M2.7b: shouldered treaded tyre
				h.tyre(Vector3(s, r, zs[i]), r, w, i < steer_n, hub, 12)
			else:
				h.wheel(Vector3(s, r, zs[i]), r, w, i < steer_n, hub, 12, 12)

## Sloped armoured hull: side profile in (z, y) extruded over +-hw, with fenders and team band.
static func _armour_hull(h, hw: float, l: float, y0: float, y1: float, col: String, col_d: String, nose := 0.18, tail := 0.08) -> void:
	var hl := l * 0.5
	h.color(col_d, Geo.PAINT)
	h.prism_x([Vector2(-hl, y0), Vector2(hl - nose, y0), Vector2(hl, y0 + (y1 - y0) * 0.55), Vector2(hl - nose * 0.6, y1), Vector2(-hl + tail, y1), Vector2(-hl, y1 - tail)], -hw * 0.62, hw * 0.62)
	h.color(col, Geo.PAINT)
	if h.has_method("xloft"):
		# M2.7b: chamfered upper deck (raked glacis, bevelled edges) + sponson plates angled
		# down over the tracks, so the hull reads as armour rather than a flat slab
		var w := hw * 0.84
		var zf := hl - nose * 0.3
		var zg := hl - nose * 0.75
		h.xloft([[zf, K8.sect(y1 - 0.02, y1 - 0.01, y1 + 0.015, w * 0.92, w * 0.94, w * 0.9, 0.008)],
			[zg, K8.sect(y1 - 0.02, y1 + 0.0, y1 + 0.075, w, w, w * 0.95, 0.03)],
			[-hl + 0.06, K8.sect(y1 - 0.02, y1 + 0.0, y1 + 0.075, w, w, w * 0.95, 0.03)],
			[-hl - 0.02, K8.sect(y1 - 0.02, y1 + 0.0, y1 + 0.05, w * 0.97, w * 0.97, w * 0.92, 0.02)]])
		for s in [-1.0, 1.0]:
			var sw := hw - w + 0.02
			h.plate(Vector3(s * (w + sw * 0.5 - 0.01), y1 + 0.03, (zg - hl + 0.02) * 0.5), Vector3(sw, 0.03, zg + hl - 0.06), Vector3(0, 0, -s * 24.0))
			h.plate(Vector3(s * (w + sw * 0.5 - 0.01), y1 + 0.005, (zf + zg) * 0.5 + 0.01), Vector3(sw, 0.03, zf - zg + 0.04), Vector3(-18, 0, -s * 24.0))
		h.color("#ffffff", Geo.TEAM)
		for s in [-1.0, 1.0]:
			h.plate(Vector3(s * (hw - 0.012), y1 + 0.012, 0), Vector3(0.02, 0.03, l * 0.75), Vector3(0, 0, -s * 24.0))
		return
	h.prism_x([Vector2(-hl - 0.02, y1 - 0.02), Vector2(hl - nose * 0.3, y1 - 0.02), Vector2(hl - nose * 0.6, y1 + 0.06), Vector2(-hl + 0.05, y1 + 0.06)], -hw, hw)
	h.color("#ffffff", Geo.TEAM)
	for s in [-hw - 0.004, hw + 0.004]:
		h.box(Vector3(s, y1 + 0.02, 0), Vector3(0.02, 0.03, l * 0.8))

static func _lamps(h, sx: float, y: float, z: float) -> void:
	h.color("#ffe2a0", Geo.LAMP)
	for s in [-sx, sx]:
		h.box(Vector3(s, y, z), Vector3(0.06, 0.045, 0.02))
	h.color("#b33a2a", Geo.LAMP)

static func _antenna(g, p: Vector3, hgt: float) -> void:
	g.color("#2b2b2a", Geo.STEEL)
	g.tube(p, p + Vector3(0, hgt, -0.02), 0.005, 3)
	g.box(p, Vector3(0.03, 0.03, 0.03))

static func _finish(root: Node3D, model: Node3D, h, mat: Material, name: String, extra: Array, path: String, bar: float) -> void:
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	VK._report(name, [h] + extra)
	VK._save(root, path, bar)

## Barrel node + mesh: tube(s) along +z from the pivot's mantlet.
static func _barrel(piv: Node3D, root: Node3D, mat: Material, at: Vector3, parts: Callable) -> void:
	var bn := VK._n3(piv, root, "Barrel", at)
	var b = K8.new()
	parts.call(b)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))

# ------------------------------------------------------------------ EU Brennus siege tank (super-heavy, twin cannon)
static func _brennus(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.7, "recoil": 0.18, "wreck_s": 9.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_tracks(h, 0.56, 1.9, 7, 0.1, EU_D, EU_S, 0.26)
	_armour_hull(h, 0.72, 1.9, 0.12, 0.42, EU, EU_D, 0.24)
	# heavy side skirts with hex shield emitters (EU identity)
	for s in [-0.73, 0.73]:
		for i in 5:
			h.color(EU if i % 2 == 0 else "#69725d", Geo.PAINT)
			h.plate(Vector3(s, 0.33, -0.76 + i * 0.38), Vector3(0.035, 0.15, 0.37), Vector3(0, 0, -signf(s) * 6.0))
			h.plate(Vector3(s * 0.99, 0.235, -0.76 + i * 0.38), Vector3(0.03, 0.05, 0.37), Vector3(0, 0, signf(s) * 28.0))
		h.color("#6fe3ff", Geo.TEAM_LAMP)
		h.box(Vector3(s * 1.03, 0.36, 0.0), Vector3(0.01, 0.05, 0.12))
	h.color(EU_S, Geo.STEEL)
	for s in [-0.42, 0.42]:
		h.tube(Vector3(s, 0.47, -0.92), Vector3(s, 0.47, -1.02), 0.04, 8)
	h.color("#2e322b", Geo.DARK)
	h.box(Vector3(0, 0.49, -0.66), Vector3(0.8, 0.012, 0.42))
	_lamps(h, 0.5, 0.42, 0.97)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.5, -0.1))
	var t = K8.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.4, 0.4, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(EU, Geo.PAINT)
	t.color(EU_D, Geo.PAINT)
	t.plan_loft([Vector2(-0.4, -0.45), Vector2(0.4, -0.45), Vector2(0.45, 0.09), Vector2(0.27, 0.45), Vector2(-0.27, 0.45), Vector2(-0.45, 0.09)], -0.02, 0.06, Vector2(1.1, 1.1))
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.44, -0.5), Vector2(0.44, -0.5), Vector2(0.5, 0.1), Vector2(0.3, 0.5), Vector2(-0.3, 0.5), Vector2(-0.5, 0.1)], 0.06, 0.22, Vector2(0.9, 0.9), Vector2(0, -0.02))
	t.plan_loft([Vector2(-0.4, -0.47), Vector2(0.4, -0.47), Vector2(0.45, 0.07), Vector2(0.27, 0.43), Vector2(-0.27, 0.43), Vector2(-0.45, 0.07)], 0.22, 0.26, Vector2(0.9, 0.9), Vector2(0, -0.02))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.15, -0.5), Vector3(0.7, 0.05, 0.02))
	t.color(EU_D, Geo.PAINT)
	t.xloft([[0.6, K8.sect(0.05, 0.08, 0.2, 0.22, 0.25, 0.22, 0.04)], [0.44, K8.sect(0.03, 0.06, 0.22, 0.25, 0.27, 0.25, 0.04)]])
	t.xloft([[-0.48, K8.sect(0.04, 0.07, 0.2, 0.34, 0.35, 0.33, 0.03)], [-0.64, K8.sect(0.05, 0.08, 0.19, 0.32, 0.33, 0.31, 0.03)]])
	t.cyl(0.09, 0.085, 0.07, 10, Transform3D(Basis.IDENTITY, Vector3(-0.2, 0.26, -0.15)))
	t.cyl(0.07, 0.07, 0.05, 10, Transform3D(Basis.IDENTITY, Vector3(0.22, 0.26, -0.1)))
	_antenna(t, Vector3(-0.34, 0.26, -0.4), 0.6)
	_antenna(t, Vector3(0.34, 0.26, -0.4), 0.45)
	VK._mi(piv, root, "Turret", t.commit(mat))
	_barrel(piv, root, mat, Vector3(0, 0.13, 0.56), func(b) -> void:
		for x in [-0.12, 0.12]:
			b.xf = Transform3D(Basis.IDENTITY, Vector3(x, 0, 0))
			b.color(EU, Geo.PAINT)
			b.gun(0.0, 1.02, 0.046, 0.037, 0.5, true, 10)
			b.xf = Transform3D.IDENTITY)
	_finish(root, model, h, mat, "brennus", [t], "res://view/units/eu/brennus.tscn", 1.7)

# ------------------------------------------------------------------ EU Salamander flame tank
static func _salamander(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.3, "recoil": 0.02, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_tracks(h, 0.44, 1.5, 5, 0.09, EU_D, EU_S)
	_armour_hull(h, 0.56, 1.5, 0.11, 0.38, "#7a7f62", EU_D, 0.3)
	# twin fuel tanks on the rear deck (hazard striped)
	for x in [-0.22, 0.22]:
		h.color("#8b7a3a", Geo.PAINT)
		h.tube(Vector3(x, 0.55, -0.62), Vector3(x, 0.55, -0.05), 0.15, 12)
		h.color("#d8a531", Geo.PAINT)
		h.tube(Vector3(x, 0.55, -0.3), Vector3(x, 0.55, -0.22), 0.153, 12)
		h.color(EU_S, Geo.STEEL)
		h.tube(Vector3(x, 0.55, -0.05), Vector3(x * 0.4, 0.5, 0.15), 0.025, 6)
	_lamps(h, 0.4, 0.38, 0.76)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.42, 0.3))
	var t = K8.new()
	t.color(EU_D, Geo.PAINT)
	t.cyl(0.2, 0.17, 0.16, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	t.color("#ffffff", Geo.TEAM)
	t.cyl(0.185, 0.18, 0.03, 12, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)))
	t.color("#2a3a46", Geo.GLASS)
	t.box(Vector3(0, 0.12, 0.17), Vector3(0.12, 0.04, 0.02))
	VK._mi(piv, root, "Turret", t.commit(mat))
	_barrel(piv, root, mat, Vector3(0, 0.08, 0.16), func(b) -> void:
		b.color(EU_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 0.55), 0.035, 8)
		b.color("#4a3a2a", Geo.DARK)
		b.tube(Vector3(0, 0, 0.5), Vector3(0, 0, 0.62), 0.05, 8, 0.03)
		b.color("#ff8a30", Geo.LAMP)
		b.box(Vector3(0, 0.05, 0.56), Vector3(0.02, 0.02, 0.02)))
	_finish(root, model, h, mat, "salamander", [t], "res://view/units/eu/salamander.tscn", 1.3)

# ------------------------------------------------------------------ EU Thunderhead howitzer (long barrel, spades)
static func _thunderhead(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.5, "recoil": 0.3, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_tracks(h, 0.48, 1.8, 6, 0.09, EU_D, EU_S)
	_armour_hull(h, 0.6, 1.8, 0.11, 0.36, EU, EU_D, 0.2, 0.02)
	# rear recoil spades
	h.color(EU_S, Geo.STEEL)
	for x in [-0.35, 0.35]:
		h.rbox(Vector3(x, 0.2, -1.0), Vector3(0.22, 0.03, 0.26), Vector3(55, 0, 0))
	h.color(EU_D, Geo.PAINT)
	h.bbox(Vector3(0, 0.5, 0.58), Vector3(0.6, 0.16, 0.42), 0.02)        # crew cab front
	h.color("#2a3a46", Geo.GLASS)
	h.box(Vector3(0, 0.54, 0.795), Vector3(0.44, 0.06, 0.01))
	_lamps(h, 0.44, 0.36, 0.91)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.44, -0.25))
	var t = K8.new()
	t.color(EU, Geo.PAINT)
	t.plan_loft([Vector2(-0.3, -0.4), Vector2(0.3, -0.4), Vector2(0.32, 0.25), Vector2(-0.32, 0.25)], 0.0, 0.34, Vector2(0.9, 0.9))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.22, -0.4), Vector3(0.55, 0.05, 0.02))
	t.color(EU_S, Geo.STEEL)
	for x in [-0.13, 0.13]:   # cradle cheeks
		t.box(Vector3(x, 0.24, 0.3), Vector3(0.05, 0.22, 0.16))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.26, 0.3))
	bn.rotation.x = -0.45   # elevated barrel
	var b = K8.new()
	b.color(EU_D, Geo.PAINT)
	b.tube(Vector3(0, 0, -0.1), Vector3(0, 0, 0.2), 0.08, 10)
	b.color(EU, Geo.PAINT)
	b.tube(Vector3(0, 0, 0.0), Vector3(0, 0, 1.45), 0.05, 10, 0.042)
	b.color(EU_S, Geo.STEEL)
	b.tube(Vector3(0, 0, 1.38), Vector3(0, 0, 1.52), 0.07, 10)
	for z in [0.4, 0.9]:
		b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.06), 0.058, 10)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "thunderhead", [t, b], "res://view/units/eu/thunderhead.tscn", 1.5)

# ------------------------------------------------------------------ EU Hearth mortar carrier (open box, vertical tube)
static func _hearth(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.25, "recoil": 0.1, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_tracks(h, 0.42, 1.5, 5, 0.085, EU_D, EU_S)
	_armour_hull(h, 0.54, 1.5, 0.1, 0.4, EU, EU_D, 0.26)
	# open-topped rear compartment walls
	h.color(EU, Geo.PAINT)
	for x in [-0.46, 0.46]:   # M2.7b: inward-raked open-top walls with a lip, rear ramp
		h.plate(Vector3(x, 0.55, -0.22), Vector3(0.04, 0.22, 0.9), Vector3(0, 0, signf(x) * 10.0))
		h.color(EU_D, Geo.PAINT)
		h.plate(Vector3(x * 0.96, 0.665, -0.22), Vector3(0.07, 0.02, 0.9), Vector3(0, 0, signf(x) * 10.0))
		h.color(EU, Geo.PAINT)
	h.plate(Vector3(0, 0.53, -0.66), Vector3(0.92, 0.22, 0.04), Vector3(-8, 0, 0))
	h.plate(Vector3(0, 0.53, 0.22), Vector3(0.92, 0.2, 0.04), Vector3(12, 0, 0))   # front bulkhead
	h.color(EU_S, Geo.STEEL)
	h.rail([Vector3(-0.44, 0.67, 0.22), Vector3(0.44, 0.67, 0.22)], 0.05, 0.2, 0.005)
	h.color("#7f7556", Geo.CANVAS)
	h.tube(Vector3(-0.38, 0.69, -0.6), Vector3(-0.38, 0.69, 0.1), 0.04, 6)   # rolled tarp
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(0.2, 0.47, 0.5), 0.14)
	h.color("#7a5c3a", Geo.WOOD)
	for i in 3:
		h.bbox(Vector3(-0.32, 0.5, -0.5 + i * 0.13), Vector3(0.16, 0.1, 0.11), 0.01)   # ammo crates
	_lamps(h, 0.4, 0.4, 0.76)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0.08, 0.46, -0.2))
	var t = K8.new()
	t.color(EU_S, Geo.STEEL)
	t.cyl(0.18, 0.18, 0.05, 12, Transform3D.IDENTITY)
	t.box(Vector3(0, 0.12, 0), Vector3(0.12, 0.18, 0.12))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.06, -0.17), Vector3(0.2, 0.04, 0.02))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.2, 0.0))
	bn.rotation.x = -1.0
	var b = K8.new()
	b.color(EU_D, Geo.PAINT)
	b.gun(-0.1, 0.62, 0.068, 0.062, -1.0, false, 10)
	b.color(EU_S, Geo.STEEL)
	b.tube(Vector3(0, 0, 0.58), Vector3(0, 0, 0.66), 0.078, 10, 0.072)
	b.tube(Vector3(0, 0, -0.14), Vector3(0, 0, -0.08), 0.08, 10)   # breech
	b.tube(Vector3(0, -0.07, 0.25), Vector3(0, -0.2, 0.05), 0.012, 4)   # bipod
	b.tube(Vector3(0, 0.07, 0.25), Vector3(0, 0.16, 0.08), 0.01, 4)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "hearth", [t, b], "res://view/units/eu/hearth.tscn", 1.25)

# ------------------------------------------------------------------ EU Spectre jammer (6x6 truck, dish array)
static func _spectre(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.6, "recoil": 0.0, "steer_max": 0.45, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_wheelset(h, 0.38, [0.5, -0.15, -0.5], 0.13, 0.12, 1, EU_D)
	h.color(EU_S, Geo.STEEL)
	h.box(Vector3(0, 0.22, 0), Vector3(0.5, 0.08, 1.45))
	h.color(EU, Geo.PAINT)
	h.prism_x([Vector2(0.38, 0.26), Vector2(0.74, 0.26), Vector2(0.76, 0.42), Vector2(0.62, 0.62), Vector2(0.38, 0.64)], -0.34, 0.34)   # cab
	h.color("#2a3a46", Geo.GLASS)
	h.prism_x([Vector2(0.75, 0.44), Vector2(0.63, 0.61), Vector2(0.64, 0.615), Vector2(0.765, 0.445)], -0.3, 0.3)
	h.color(EU_D, Geo.PAINT)
	h.xloft([[0.3, K8.sect(0.25, 0.3, 0.75, 0.32, 0.33, 0.3, 0.05)], [-0.7, K8.sect(0.25, 0.3, 0.75, 0.32, 0.33, 0.3, 0.05)]])   # electronics shelter
	h.color(EU_S, Geo.STEEL)
	for z in [0.15, -0.2, -0.55]:
		h.box(Vector3(0, 0.76, z), Vector3(0.56, 0.012, 0.03))   # roof ribs
	h.rail([Vector3(-0.28, 0.76, 0.25), Vector3(-0.28, 0.76, -0.65)], 0.06, 0.15, 0.005)
	h.color("#4d5741", Geo.PAINT)
	for z in [-0.1, -0.02]:
		h.jerrycan(Vector3(-0.36, 0.38, z), 90)
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.335, 0.335]:
		h.box(Vector3(s, 0.6, -0.2), Vector3(0.01, 0.05, 0.9))
	h.color("#2e322b", Geo.DARK)
	for i in 4:
		h.box(Vector3(0.335, 0.45, -0.55 + i * 0.2), Vector3(0.012, 0.18, 0.12))   # cooling louvres
	_lamps(h, 0.25, 0.36, 0.765)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.76, -0.25))
	var t = K8.new()
	t.color(EU_S, Geo.STEEL)
	t.tube(Vector3(0, 0, 0), Vector3(0, 0.55, 0), 0.03, 6)
	t.color(EU, Geo.PAINT)
	t.lathe([Vector2(0.0, 0.04), Vector2(0.03, 0.14), Vector2(0.07, 0.24), Vector2(0.11, 0.3)], 14, Transform3D(Basis(Vector3.RIGHT, -1.2), Vector3(0, 0.55, 0.02)), true, false)   # parabolic dish
	t.color(EU_S, Geo.STEEL)
	t.tube(Vector3(0, 0.55, 0.02), Vector3(0, 0.6, 0.18), 0.01, 4)
	t.color("#6fe3ff", Geo.TEAM_LAMP)
	t.box(Vector3(0, 0.6, 0.18), Vector3(0.03, 0.03, 0.03))
	t.color(EU_S, Geo.STEEL)
	for a in 4:   # jammer whip antennas around the mast
		var ang := TAU * float(a) / 4.0 + 0.4
		t.tube(Vector3(cos(ang) * 0.25, 0, sin(ang) * 0.25), Vector3(cos(ang) * 0.28, 0.5, sin(ang) * 0.28), 0.006, 3)
	VK._mi(piv, root, "Turret", t.commit(mat))
	_finish(root, model, h, mat, "spectre", [t], "res://view/units/eu/spectre.tscn", 1.6)

# ------------------------------------------------------------------ EU Sentinel outpost (tracked box, sensor mast)
static func _sentinel(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.7, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_tracks(h, 0.42, 1.4, 5, 0.08, EU_D, EU_S, 0.2)
	# M2.7b: armoured sensor carrier: raked nose, tumblehome superstructure, sponsons
	h.color(EU_D, Geo.PAINT)
	h.xloft([[0.74, K8.sect(0.2, 0.26, 0.36, 0.3, 0.36, 0.38, 0.0)], [0.56, K8.sect(0.14, 0.22, 0.4, 0.33, 0.38, 0.4, 0.0)], [-0.66, K8.sect(0.14, 0.22, 0.4, 0.33, 0.38, 0.4, 0.0)], [-0.72, K8.sect(0.18, 0.24, 0.4, 0.32, 0.37, 0.39, 0.0)]])
	h.color(EU, Geo.PAINT)
	var s0 := K8.sect(0.36, 0.42, 0.5, 0.5, 0.52, 0.42, 0.04)
	var s1 := K8.sect(0.36, 0.44, 0.66, 0.52, 0.53, 0.42, 0.06)
	h.xloft([[0.76, s0], [0.42, s1], [-0.68, K8.sect(0.36, 0.44, 0.66, 0.52, 0.53, 0.43, 0.06)], [-0.72, K8.sect(0.36, 0.44, 0.63, 0.5, 0.51, 0.42, 0.05)]])
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.493, 0.55, -0.1), Vector3(0.012, 0.04, 0.9), Vector3(0, 0, s * 33.0))
	h.color(EU_D, Geo.PAINT)
	h.box(Vector3(0, 0.5, -0.725), Vector3(0.4, 0.24, 0.02))         # rear troop door
	h.color(EU_S, Geo.STEEL)
	h.box(Vector3(0.12, 0.5, -0.74), Vector3(0.05, 0.015, 0.015))
	h.color("#2a3a46", Geo.GLASS)
	for x in [-0.18, 0.18]:   # driver's vision blocks on the raked nose
		h.plate(Vector3(x, 0.56, 0.62), Vector3(0.16, 0.05, 0.01), Vector3(-50, 0, 0))
	for s in [-1.0, 1.0]:
		for z in [-0.4, 0.0]:
			h.plate(Vector3(s * 0.485, 0.6, z), Vector3(0.008, 0.035, 0.08), Vector3(0, 0, s * 33.0))   # firing-port blocks
	h.color(EU_D, Geo.PAINT)
	h.hatch(Vector3(0.22, 0.66, 0.2), 0.14)
	h.hatch(Vector3(-0.2, 0.66, -0.5), 0.16)
	h.color("#7f7556", Geo.CANVAS)
	h.cbox(Vector3(0.3, 0.7, -0.45), Vector3(0.18, 0.08, 0.3), 0.03)
	h.color(EU_S, Geo.STEEL)
	h.rail([Vector3(0.2, 0.66, -0.25), Vector3(0.4, 0.66, -0.25), Vector3(0.4, 0.66, -0.65), Vector3(0.2, 0.66, -0.65)], 0.06, 0.12, 0.005)
	for i in 3:   # smoke launchers
		h.tube(Vector3(0.38, 0.6, 0.3 + i * 0.04), Vector3(0.44, 0.65, 0.34 + i * 0.04), 0.012, 6)
		h.tube(Vector3(-0.38, 0.6, 0.3 + i * 0.04), Vector3(-0.44, 0.65, 0.34 + i * 0.04), 0.012, 6)
	# sensor mast (fixed) with rotating head on the pivot
	h.color(EU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.66, -0.2), Vector3(0, 1.2, -0.2), 0.035, 6)
	_lamps(h, 0.3, 0.42, 0.73)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 1.2, -0.2))
	var t = K8.new()
	t.color(EU_D, Geo.PAINT)
	t.xloft([[0.06, K8.sect(0.0, 0.03, 0.1, 0.25, 0.26, 0.24, 0.02)], [-0.06, K8.sect(0.0, 0.03, 0.1, 0.25, 0.26, 0.24, 0.02)]])
	t.color("#2a3a46", Geo.GLASS)
	t.box(Vector3(0, 0.05, 0.065), Vector3(0.42, 0.06, 0.01))
	t.color(EU_S, Geo.STEEL)
	for s in [-1.0, 1.0]:
		t.cbox(Vector3(s * 0.31, 0.05, 0.0), Vector3(0.1, 0.09, 0.1), 0.015)   # EO / laser heads
		t.color("#2a3a46", Geo.GLASS)
		t.box(Vector3(s * 0.31, 0.05, 0.052), Vector3(0.06, 0.05, 0.006))
		t.color(EU_S, Geo.STEEL)
	t.color("#6fe3ff", Geo.TEAM_LAMP)
	t.box(Vector3(0, 0.12, 0), Vector3(0.05, 0.03, 0.05))
	VK._mi(piv, root, "Turret", t.commit(mat))
	_finish(root, model, h, mat, "sentinel", [t], "res://view/units/eu/sentinel.tscn", 1.7)

# ------------------------------------------------------------------ EU Kestrel lift helo [STUB: no air layer]
static func _kestrel(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.5, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	h.color(EU_S, Geo.STEEL)
	for x in [-0.32, 0.32]:   # skids
		h.tube(Vector3(x, 0.04, -0.5), Vector3(x, 0.04, 0.55), 0.02, 5)
		for z in [-0.3, 0.3]:
			h.tube(Vector3(x, 0.04, z), Vector3(x * 0.7, 0.22, z), 0.015, 4)
	h.color(EU, Geo.PAINT)
	h.plan_loft([Vector2(-0.3, -0.55), Vector2(0.3, -0.55), Vector2(0.32, 0.4), Vector2(0.14, 0.7), Vector2(-0.14, 0.7), Vector2(-0.32, 0.4)], 0.2, 0.72, Vector2(0.85, 0.85))
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.55, 0.62), Vector3(0.3, 0.22, 0.05), Vector3(-35, 0, 0))
	h.color(EU, Geo.PAINT)
	h.tube(Vector3(0, 0.55, -0.55), Vector3(0, 0.62, -1.45), 0.09, 8, 0.04)     # tail boom
	h.box(Vector3(0, 0.78, -1.42), Vector3(0.03, 0.3, 0.16))                   # fin
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.62, -1.0), Vector3(0.14, 0.03, 0.3))
	for s in [-0.3, 0.3]:
		h.box(Vector3(s, 0.48, 0.0), Vector3(0.02, 0.05, 0.6))
	h.color(EU_S, Geo.STEEL)
	h.cyl(0.07, 0.05, 0.12, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0.0)))
	for i in 4:   # main rotor (static blades on the ground)
		var a := TAU * float(i) / 4.0 + 0.3
		h.rbox(Vector3(cos(a) * 0.62, 0.86, sin(a) * 0.62), Vector3(1.2, 0.012, 0.07), Vector3(0, -rad_to_deg(a), 0))
	h.rbox(Vector3(0.05, 0.8, -1.45), Vector3(0.01, 0.3, 0.04), Vector3(0, 0, 0))
	_finish(root, model, h, mat, "kestrel", [], "res://view/units/eu/kestrel.tscn", 1.5)

# ------------------------------------------------------------------ EU Corvid strike jet [STUB: no air layer]
static func _corvid(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	h.color(EU_S, Geo.STEEL)
	for p in [Vector3(0, 0.08, 0.7), Vector3(-0.3, 0.08, -0.2), Vector3(0.3, 0.08, -0.2)]:   # gear
		h.tube(p, p + Vector3(0, 0.2, 0), 0.015, 4)
		h.wheel(p, 0.06, 0.04, false, EU_S, 8)
	h.color("#6d747a", Geo.PAINT)
	h.tube(Vector3(0, 0.34, -0.9), Vector3(0, 0.34, 0.9), 0.15, 10, 0.06)   # fuselage
	h.cyl(0.06, 0.0, 0.3, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.34, 0.9)))
	h.color("#2a3a46", Geo.GLASS)
	h.rbox(Vector3(0, 0.46, 0.45), Vector3(0.12, 0.08, 0.36), Vector3(-6, 0, 0))
	h.color("#5d6268", Geo.PAINT)
	h.faces([[Vector3(-0.08, 0.32, 0.25), Vector3(-0.95, 0.3, -0.45), Vector3(-0.95, 0.3, -0.62), Vector3(-0.08, 0.32, -0.6)], [Vector3(-0.08, 0.34, 0.25), Vector3(-0.95, 0.32, -0.45), Vector3(-0.95, 0.32, -0.62), Vector3(-0.08, 0.34, -0.6)]])
	h.faces([[Vector3(0.08, 0.32, 0.25), Vector3(0.95, 0.3, -0.45), Vector3(0.95, 0.3, -0.62), Vector3(0.08, 0.32, -0.6)], [Vector3(0.08, 0.34, 0.25), Vector3(0.95, 0.32, -0.45), Vector3(0.95, 0.32, -0.62), Vector3(0.08, 0.34, -0.6)]])
	for s in [-1.0, 1.0]:   # twin canted fins
		h.rbox(Vector3(s * 0.12, 0.56, -0.75), Vector3(0.02, 0.36, 0.26), Vector3(0, 0, s * 18))
	h.color("#ffffff", Geo.TEAM)
	for s in [-0.7, 0.7]:
		h.box(Vector3(s, 0.335, -0.5), Vector3(0.2, 0.012, 0.1))
	h.color(EU_S, Geo.STEEL)
	h.tube(Vector3(0, 0.34, -0.92), Vector3(0, 0.34, -1.0), 0.1, 10)
	_finish(root, model, h, mat, "corvid", [], "res://view/units/eu/corvid.tscn", 1.2)

# ------------------------------------------------------------------ TPLA Junkhammer heavy tank (welded scrap)
static func _junkhammer(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.9, "bar_height": 1.45, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_tracks(h, 0.48, 1.7, 6, 0.095, "#5d5a52", TP_S, 0.24)
	_armour_hull(h, 0.62, 1.7, 0.12, 0.4, TP, TP_D, 0.22)
	for b in [[0.63, 0.32, -0.3, "#5d6f7a"], [-0.63, 0.3, 0.2, "#8a4a34"], [0.63, 0.34, 0.45, "#6f6a52"]]:   # welded plates
		h.color(b[3], Geo.SCRAP)
		h.rbox(Vector3(b[0], b[1], b[2]), Vector3(0.02, 0.2, 0.42), Vector3(2.0, 0, 3))
	h.color("#4a4640", Geo.STEEL)
	for i in 5:   # slat armour on the front
		h.box(Vector3(-0.4 + i * 0.2, 0.36, 0.9), Vector3(0.03, 0.22, 0.02))
	h.box(Vector3(0, 0.46, 0.9), Vector3(0.9, 0.025, 0.02))
	h.color("#1e1d1c", Geo.RUBBER)
	h.cyl(0.13, 0.13, 0.08, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.3, 0.6, -0.86)))   # spare tyre
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.48, -0.05))
	var t = K8.new()
	t.color(TP_D, Geo.PAINT)
	t.lathe([Vector2(0.0, 0.37), Vector2(0.07, 0.38), Vector2(0.15, 0.33), Vector2(0.21, 0.24), Vector2(0.25, 0.1), Vector2(0.26, 0.0)], 12, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 1.12)), Vector3(0, 0, 0.02)))   # M2.7b cast dome turret
	t.color(TP_S, Geo.STEEL)
	t.cyl(0.4, 0.4, 0.03, 14, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	t.color(TP_D, Geo.PAINT)
	t.ccyl(0.07, 0.05, 0.012, 8, Transform3D(Basis.IDENTITY, Vector3(-0.12, 0.22, -0.1)))
	t.hatch(Vector3(0.13, 0.23, -0.08), 0.12)
	t.color(TP_S, Geo.STEEL)
	t.tube(Vector3(0.13, 0.33, -0.08), Vector3(0.13, 0.34, 0.14), 0.01, 5)   # DShK
	t.box(Vector3(0.13, 0.32, -0.06), Vector3(0.04, 0.05, 0.08))
	t.color("#ffe2a0", Geo.LAMP)
	t.box(Vector3(-0.2, 0.2, 0.36), Vector3(0.05, 0.05, 0.02))   # IR searchlight
	t.color("#6f6a52", Geo.SCRAP)
	t.rbox(Vector3(0.3, 0.12, 0.1), Vector3(0.02, 0.2, 0.36), Vector3(0, 0, -10))
	t.color("#ffffff", Geo.TEAM)
	t.rbox(Vector3(-0.1, 0.25, -0.1), Vector3(0.36, 0.01, 0.2), Vector3(0, 8, 0))   # team tarp
	t.color("#7a7048", Geo.SANDBAG)
	for i in 3:
		t.sandbag(Vector3(-0.2 + i * 0.2, 0.28, -0.32), 0.18, 0)
	VK._mi(piv, root, "Turret", t.commit(mat))
	_barrel(piv, root, mat, Vector3(0, 0.12, 0.42), func(b) -> void:
		b.color(TP_D, Geo.PAINT)
		b.tube(Vector3(0, 0, -0.04), Vector3(0, 0, 0.08), 0.075, 10, 0.06)   # mantlet
		b.color(TP_S, Geo.STEEL)
		b.gun(0.0, 0.95, 0.048, 0.038, 0.8, true, 10)
		b.color("#5d6f7a", Geo.SCRAP)
		b.tube(Vector3(0, 0, 0.3), Vector3(0, 0, 0.5), 0.062, 10))
	_finish(root, model, h, mat, "junkhammer", [t], "res://view/units/tpla/junkhammer.tscn", 1.45)

# ------------------------------------------------------------------ TPLA Rot Sprayer (farm tractor + tank + boom)
static func _sprayer(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.8, "bar_height": 1.3, "recoil": 0.0, "steer_max": 0.5, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	for s in [-0.33, 0.33]:
		h.wheel(Vector3(s, 0.24, -0.3), 0.24, 0.16, false, "#8a4a34", 14, 14)   # big rear tractor wheels
		h.wheel(Vector3(s * 0.85, 0.13, 0.45), 0.13, 0.1, true, "#8a4a34", 12, 10)
	h.color(TP_S, Geo.STEEL)
	h.box(Vector3(0, 0.25, 0.05), Vector3(0.3, 0.1, 1.1))
	h.color("#9a4a2c", Geo.PAINT)
	h.bbox(Vector3(0, 0.38, 0.38), Vector3(0.3, 0.2, 0.42), 0.02)         # engine bonnet
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(0.1, 0.48, 0.45), Vector3(0.1, 0.8, 0.45), 0.02, 6)    # exhaust stack
	h.color(TP, Geo.PAINT)
	h.box(Vector3(0, 0.62, -0.2), Vector3(0.44, 0.03, 0.4))               # canopy
	for x in [-0.2, 0.2]:
		h.tube(Vector3(x, 0.3, -0.38), Vector3(x, 0.62, -0.38), 0.012, 4)
		h.tube(Vector3(x, 0.3, -0.02), Vector3(x, 0.62, -0.02), 0.012, 4)
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.64, -0.2), Vector3(0.42, 0.012, 0.36))
	# toxic tank trailer-on-frame at the back
	h.color("#7c8a3a", Geo.PAINT)
	h.tube(Vector3(0, 0.55, -0.55), Vector3(0, 0.55, -0.95), 0.2, 12)
	h.color("#c8d84a", Geo.LAMP)
	h.box(Vector3(0, 0.76, -0.75), Vector3(0.08, 0.02, 0.08))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.45, 0.62))
	var t = K8.new()
	t.color(TP_S, Geo.STEEL)
	t.box(Vector3(0, 0, 0), Vector3(0.1, 0.08, 0.08))
	t.tube(Vector3(-0.45, 0.02, 0.06), Vector3(0.45, 0.02, 0.06), 0.015, 5)      # spray boom
	t.color("#c8d84a", Geo.LAMP)
	for i in 5:
		t.box(Vector3(-0.4 + i * 0.2, -0.02, 0.07), Vector3(0.025, 0.025, 0.025))
	VK._mi(piv, root, "Turret", t.commit(mat))
	_finish(root, model, h, mat, "sprayer", [t], "res://view/units/tpla/sprayer.tscn", 1.3)

# ------------------------------------------------------------------ TPLA Earwig van (radar dish on a delivery van)
static func _earwig(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.45, "recoil": 0.0, "steer_max": 0.5, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_wheelset(h, 0.3, [0.42, -0.4], 0.12, 0.1, 1, "#5d5a52")
	h.color(TP_S, Geo.STEEL)
	h.box(Vector3(0, 0.2, 0), Vector3(0.44, 0.07, 1.2))
	h.color("#c9c0a8", Geo.PAINT)
	h.prism_x([Vector2(-0.62, 0.24), Vector2(0.62, 0.24), Vector2(0.66, 0.4), Vector2(0.48, 0.7), Vector2(-0.62, 0.72)], -0.3, 0.3)
	h.color("#26323b", Geo.GLASS)
	h.prism_x([Vector2(0.65, 0.42), Vector2(0.49, 0.68), Vector2(0.5, 0.685), Vector2(0.665, 0.425)], -0.26, 0.26)
	h.color("#6f6a52", Geo.SCRAP)
	h.box(Vector3(0.302, 0.45, -0.2), Vector3(0.012, 0.22, 0.5))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(-0.302, 0.5, -0.1), Vector3(0.01, 0.12, 0.7))
	h.color(TP_S, Geo.STEEL)
	h.box(Vector3(0, 0.74, -0.2), Vector3(0.44, 0.03, 0.7))      # roof rack
	h.tube(Vector3(0, 0.74, -0.25), Vector3(0, 0.95, -0.25), 0.025, 6)
	h.color("#ffe2a0", Geo.LAMP)
	for s in [-0.2, 0.2]:
		h.box(Vector3(s, 0.36, 0.665), Vector3(0.08, 0.05, 0.01))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.95, -0.25))
	var t = K8.new()
	t.color("#d8d2c0", Geo.PAINT)
	t.cyl(0.26, 0.04, 0.1, 14, Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(0, 0.12, 0)))
	t.color(TP_S, Geo.STEEL)
	t.tube(Vector3(0, 0.12, 0), Vector3(0, 0.12, 0.22), 0.01, 4)
	VK._mi(piv, root, "Turret", t.commit(mat))
	_finish(root, model, h, mat, "earwig", [t], "res://view/units/tpla/earwig.tscn", 1.45)

# ------------------------------------------------------------------ TPLA Jackal bike (motorbike + gunner)
static func _jackal(mat: Material) -> void:
	var root := VK._root({"selection_radius": 0.55, "bar_height": 1.05, "recoil": 0.02, "steer_max": 0.6, "wreck_s": 5.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	h.wheel(Vector3(0.0, 0.15, 0.42), 0.15, 0.08, true, TP_S, 12, 12)
	h.wheel(Vector3(0.0, 0.15, -0.38), 0.15, 0.1, false, TP_S, 12, 12)
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(0, 0.15, 0.42), Vector3(0, 0.5, 0.3), 0.018, 5)      # fork
	h.tube(Vector3(-0.15, 0.52, 0.3), Vector3(0.15, 0.52, 0.3), 0.012, 4)   # handlebar
	h.color(TP, Geo.PAINT)
	h.prism_x([Vector2(-0.35, 0.28), Vector2(0.25, 0.28), Vector2(0.3, 0.42), Vector2(0.1, 0.48), Vector2(-0.3, 0.42)], -0.1, 0.1)
	h.color("#2a2622", Geo.RUBBER)
	h.box(Vector3(0, 0.46, -0.12), Vector3(0.16, 0.04, 0.32))    # seat
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.44, 0.15), Vector3(0.18, 0.04, 0.16))     # tank stripe
	h.color(TP_S, Geo.STEEL)
	h.tube(Vector3(0.08, 0.25, -0.1), Vector3(0.1, 0.3, -0.45), 0.02, 5)
	# rider (simple figure) + pillion gunner
	for rp in [[0.0, -0.02, "#6a5a40"], [0.0, -0.26, "#5d6648"]]:
		h.color(rp[2], Geo.CANVAS)
		h.bbox(Vector3(0, 0.65, rp[1]), Vector3(0.18, 0.28, 0.14), 0.02)
		h.color("#c9a27a", Geo.PAINT)
		h.box(Vector3(0, 0.84, rp[1]), Vector3(0.1, 0.1, 0.1))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(0, 0.89, rp[1]), Vector3(0.11, 0.04, 0.11))   # team scarf / cap
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.66, -0.26))
	var t = K8.new()
	t.color(TP_S, Geo.STEEL)
	t.box(Vector3(0.1, 0.0, 0.05), Vector3(0.04, 0.04, 0.1))
	VK._mi(piv, root, "Turret", t.commit(mat))
	_barrel(piv, root, mat, Vector3(0.1, 0.0, 0.1), func(b) -> void:
		b.color("#2b2a28", Geo.STEEL)
		b.tube(Vector3(0, 0, 0), Vector3(0, 0, 0.35), 0.012, 5))
	_finish(root, model, h, mat, "jackal", [t], "res://view/units/tpla/jackal.tscn", 1.05)

# ------------------------------------------------------------------ TPLA Rust Bus (armoured school bus)
static func _bus(mat: Material) -> void:
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.55, "recoil": 0.0, "steer_max": 0.4, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K8.new()
	_wheelset(h, 0.36, [0.6, -0.45, -0.75], 0.15, 0.12, 1, "#5d5a52")
	h.color(TP_S, Geo.STEEL)
	h.box(Vector3(0, 0.24, -0.05), Vector3(0.6, 0.08, 1.9))
	h.color("#c9a23a", Geo.PAINT)    # faded yellow body
	h.prism_x([Vector2(-1.0, 0.28), Vector2(0.95, 0.28), Vector2(1.0, 0.45), Vector2(0.92, 0.95), Vector2(-1.0, 0.98)], -0.4, 0.4)
	h.color("#26323b", Geo.GLASS)
	for i in 6:
		for s in [-0.402, 0.402]:
			h.box(Vector3(s, 0.78, -0.8 + i * 0.28), Vector3(0.01, 0.14, 0.2))
	h.prism_x([Vector2(0.99, 0.5), Vector2(0.93, 0.9), Vector2(0.94, 0.905), Vector2(1.0, 0.505)], -0.36, 0.36)
	# welded armour plates over the windows, roof sandbags and a team banner
	for i in 4:
		h.color(["#5d6f7a", "#8a4a34", "#6f6a52", "#4a4640"][i], Geo.SCRAP)
		h.rbox(Vector3(0.41 if i % 2 == 0 else -0.41, 0.6, -0.7 + i * 0.4), Vector3(0.015, 0.22, 0.34), Vector3(0, 0, 3 - i * 2))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.99, 0.0), Vector3(0.7, 0.012, 0.5))
	for i in 5:
		h.sandbag(Vector3(-0.25 + (i % 2) * 0.5, 1.03, -0.7 + i * 0.3), 0.2, 90)
	h.color(TP_S, Geo.STEEL)
	h.box(Vector3(0, 0.33, 1.02), Vector3(0.78, 0.07, 0.06))
	h.color("#ffe2a0", Geo.LAMP)
	for s in [-0.28, 0.28]:
		h.box(Vector3(s, 0.42, 1.0), Vector3(0.09, 0.06, 0.01))
	_finish(root, model, h, mat, "rust_bus", [], "res://view/units/tpla/bus.tscn", 1.55)
