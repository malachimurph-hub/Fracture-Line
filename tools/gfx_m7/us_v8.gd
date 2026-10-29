extends RefCounted
## M2.7b US vehicle remodel (tool-time only): Zero Hour-style hard modelling read at RTS range.
## Lofted, chamfered hulls and cabs (no axis-aligned box bodies), sloped glazing laid on the
## faces, angled armour plates, full track runs (road wheels, toothed sprockets, idlers, return
## rollers), treaded tyres, tapered guns with muzzle brakes. Node layout and pivots are unchanged
## from M2.7 (tools/gfx_m7/us_m7.gd), so gameplay hooks (TurretPivot / Barrel / Hull) still match.
## Faction camo is applied afterwards by tools/gfx_m7/camo_pass.gd.
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const V4 := preload("res://tools/gfx_m4/vehicles_m4.gd")
const US := "#7e8a5c"
const US_D := "#66704a"
const US_S := "#464a46"
const GLASS_C := "#2a3a46"
const YEL := "#d8a531"
const AIR := "#8a9097"
const AIR_D := "#6c737a"
const BOMB := "#70767c"

static func jobs() -> Dictionary:
	return {
		"us_halberd": func() -> void: _halberd(),
		"us_lynx": func() -> void: _lynx(),
		"us_picket": func() -> void: _picket(),
		"us_longreach": func() -> void: _m109a7(),   # M3.1: M109A7 self-propelled howitzer
		"us_dozer": func() -> void: _dozer(),
		"us_supply_truck": func() -> void: _supply_truck(),
		"us_harrier": func() -> void: _harrier(),
		"us_wraith": func() -> void: _wraith(),
		"us_thunderlance": func() -> void: _thunderlance(),
	}

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func _barrel(piv: Node3D, root: Node3D, mat: Material, at: Vector3, parts: Callable):
	var bn := VK._n3(piv, root, "Barrel", at)
	var b = K.new()
	parts.call(b)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	return b

static func _tyres(h, sx: float, zs: Array, r: float, w: float, steer_n: int, hub := US_S) -> void:
	for i in zs.size():
		for s in [-sx, sx]:
			h.tyre(Vector3(s, r, zs[i]), r, w, i < steer_n, hub, 12)

## Point on the quad between two loft sections' matching edge (i0, i1 = vertex indices of a
## sect() polygon), u across the edge, v along z, both 0..1.
static func _on(sa: Array, za: float, sb: Array, zb: float, i0: int, i1: int, u: float, v: float) -> Vector3:
	var a: Vector2 = (sa[i0] as Vector2).lerp(sa[i1], u)
	var b: Vector2 = (sb[i0] as Vector2).lerp(sb[i1], u)
	var p := a.lerp(b, v)
	return Vector3(p.x, p.y, lerpf(za, zb, v))

## Glazed quad on the face between loft sections (inset by du / dv).
static func _glass(h, sa: Array, za: float, sb: Array, zb: float, i0: int, i1: int, du: Vector2, dv: Vector2, out: Vector3) -> void:
	h.color(GLASS_C, Geo.GLASS)
	h.pane([_on(sa, za, sb, zb, i0, i1, du.x, dv.x), _on(sa, za, sb, zb, i0, i1, du.y, dv.x),
		_on(sa, za, sb, zb, i0, i1, du.y, dv.y), _on(sa, za, sb, zb, i0, i1, du.x, dv.y)], out, 0.005)

# ------------------------------------------------------------------ Halberd MBT (Abrams-inspired)
static func _halberd() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.35, "recoil": 0.16, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.5, 1.8, 7, 0.085, 0.24, US_S)
	# lower hull: chamfered tub between the tracks with a raked lower glacis
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.92, K.sect(0.2, 0.28, 0.34, 0.3, 0.37, 0.38, 0.0)], [0.7, K.sect(0.13, 0.22, 0.34, 0.33, 0.38, 0.38, 0.0)],
		[-0.84, K.sect(0.13, 0.22, 0.35, 0.33, 0.38, 0.38, 0.0)], [-0.92, K.sect(0.18, 0.26, 0.36, 0.3, 0.37, 0.38, 0.0)]])
	# upper hull: long shallow glacis, flat engine deck, chamfered sponson edges over the tracks
	h.color(US, Geo.PAINT)
	var sf := K.sect(0.33, 0.34, 0.37, 0.56, 0.6, 0.58, 0.015)
	var sg := K.sect(0.33, 0.36, 0.445, 0.6, 0.63, 0.6, 0.03)
	h.xloft([[0.94, sf], [0.48, sg], [-0.84, K.sect(0.33, 0.36, 0.455, 0.6, 0.63, 0.6, 0.03)], [-0.93, K.sect(0.33, 0.35, 0.42, 0.58, 0.61, 0.58, 0.02)]])
	# side skirts: raked armour panels with a chamfered lower lip, heavier front panels
	for s in [-1.0, 1.0]:
		for i in 6:
			var zc := lerpf(-0.74, 0.78, (float(i) + 0.5) / 6.0)
			var seg := 1.52 / 6.0
			h.color(US if i > 1 else US_D, Geo.PAINT)
			h.plate(Vector3(s * 0.645, 0.3, zc), Vector3(0.03, 0.14, seg - 0.012), Vector3(0, 0, -s * 6.0))
			h.plate(Vector3(s * 0.635, 0.215, zc), Vector3(0.028, 0.045, seg - 0.012), Vector3(0, 0, s * 28.0))
			if i % 2 == 0:
				h.color(US_S, Geo.STEEL)
				h.rivets(Vector3(s * 0.664, 0.345, zc - seg * 0.3), Vector3(s * 0.664, 0.345, zc + seg * 0.3), 2, Vector3(s, 0, 0), 0.006)
		h.color(US, Geo.PAINT)   # angled nose plate closing the skirt
		h.plate(Vector3(s * 0.62, 0.27, 0.86), Vector3(0.03, 0.16, 0.12), Vector3(-30, s * 25.0, 0))
	# glacis: driver hatch + periscopes, headlight guards, tow hooks
	h.color(US_D, Geo.PAINT)
	h.hatch(Vector3(0, 0.43, 0.48), 0.16)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.07, 0.0, 0.07]:
		h.box(Vector3(x, 0.445, 0.6), Vector3(0.05, 0.02, 0.025))
	V4._lamps(h, 0.5, 0.375, 0.9)
	h.color(US_S, Geo.STEEL)
	for x in [-0.5, 0.5]:
		h.tube(Vector3(x - 0.05, 0.36, 0.92), Vector3(x + 0.05, 0.42, 0.92), 0.005, 3)
		h.tube(Vector3(x * 0.6, 0.2, 0.9), Vector3(x * 0.6, 0.2, 0.97), 0.02, 6)
	# engine deck: grilles, access panels, exhaust grille at the rear, stowage, tail lamps
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.457, -0.52), 0.7, 0.4, 9)
	h.vent(Vector3(0, 0.33, -0.935), 0.7, 0.12, 5, 180)
	h.color(US_D, Geo.PAINT)
	for x in [-0.45, 0.45]:
		h.cbox(Vector3(x, 0.5, -0.8), Vector3(0.24, 0.09, 0.16), 0.015)
	h.color("#4d5741", Geo.PAINT)
	h.jerrycan(Vector3(-0.56, 0.5, -0.55), 0)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.55, 0.55]:
		h.box(Vector3(x, 0.39, -0.93), Vector3(0.05, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.667, 0.33, 0.02), Vector3(0.006, 0.035, 1.2), Vector3(0, 0, -s * 6.0))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.43, -0.12))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.36, 0.36, 0.04, 16, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	# faceted wedge turret: undercut lower faces, sloped cheeks, chamfered roof step, long bustle
	var plan := [Vector2(-0.44, -0.5), Vector2(0.44, -0.5), Vector2(0.5, 0.12), Vector2(0.28, 0.52), Vector2(-0.28, 0.52), Vector2(-0.5, 0.12)]
	var low: Array = []
	for p: Vector2 in plan:
		low.append(p * 0.9)
	t.color(US_D, Geo.PAINT)
	t.plan_loft(low, -0.02, 0.05, Vector2(1.0 / 0.9, 1.0 / 0.9))
	t.color(US, Geo.PAINT)
	t.plan_loft(plan, 0.05, 0.18, Vector2(0.95, 0.96), Vector2(0, -0.01))
	var top: Array = []
	for p: Vector2 in plan:
		top.append(Vector2(p.x * 0.95, p.y * 0.96 - 0.01))
	t.plan_loft(top, 0.18, 0.215, Vector2(0.9, 0.92), Vector2(0, -0.02))
	t.color(US_D, Geo.PAINT)
	t.plan_loft([Vector2(-0.4, -0.78), Vector2(0.4, -0.78), Vector2(0.42, -0.48), Vector2(-0.42, -0.48)], 0.03, 0.19, Vector2(0.96, 0.96))
	# bolted cheek armour packs
	t.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.41, 0.11, 0.33), Vector3(0.03, 0.14, 0.4), Vector3(0, s * 30.0, s * -8.0))
	# bustle rack + stowed bags
	t.color(US_S, Geo.STEEL)
	t.rail([Vector3(-0.42, 0.19, -0.5), Vector3(-0.42, 0.19, -0.84), Vector3(0.42, 0.19, -0.84), Vector3(0.42, 0.19, -0.5)], 0.08, 0.12, 0.006)
	t.color("#6b5a3a", Geo.CANVAS)
	t.cbox(Vector3(-0.22, 0.24, -0.7), Vector3(0.3, 0.09, 0.2), 0.03)
	t.color("#56604a", Geo.CANVAS)
	t.cbox(Vector3(0.16, 0.235, -0.68), Vector3(0.36, 0.08, 0.22), 0.03)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.12, -0.785), Vector3(0.6, 0.05, 0.01))
	for s in [-1.0, 1.0]:
		t.plate(Vector3(s * 0.47, 0.12, -0.12), Vector3(0.008, 0.05, 0.4), Vector3(0, s * 3.0, 0))
	# roof: commander's cupola + HMG, loader's hatch + MG, CITV sight, blow-out panels, wind sensor
	t.color(US_D, Geo.PAINT)
	t.ccyl(0.1, 0.07, 0.015, 10, Transform3D(Basis.IDENTITY, Vector3(0.2, 0.2, -0.15)))
	t.color(GLASS_C, Geo.GLASS)
	for i in 6:
		var a := TAU * i / 6.0
		t.box(Vector3(0.2 + cos(a) * 0.09, 0.235, -0.15 + sin(a) * 0.09), Vector3(0.025, 0.015, 0.025))
	U()._mg(t, Vector3(0.2, 0.34, -0.1), 0.0, 0.26)
	t.color(US_D, Geo.PAINT)
	t.hatch(Vector3(-0.2, 0.205, -0.18), 0.14)
	U()._mg(t, Vector3(-0.3, 0.31, -0.12), -10.0, 0.18)
	t.color(US_S, Geo.STEEL)
	t.tube(Vector3(-0.05, 0.2, 0.0), Vector3(-0.05, 0.27, 0.0), 0.02, 6)
	t.cbox(Vector3(-0.05, 0.3, 0.0), Vector3(0.09, 0.07, 0.08), 0.01)
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.05, 0.3, 0.042), Vector3(0.06, 0.045, 0.006))
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.3, 0.225, 0.18), Vector3(0.12, 0.05, 0.12), 0.01)   # gunner's primary sight
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.3, 0.23, 0.242), Vector3(0.09, 0.03, 0.006))
	t.color("#3f4633", Geo.PAINT)
	for k in 2:
		t.box(Vector3(-0.15 + k * 0.3, 0.215, -0.62), Vector3(0.2, 0.006, 0.14))
	t.color(US_S, Geo.STEEL)
	t.tube(Vector3(0.0, 0.19, -0.6), Vector3(0.0, 0.34, -0.6), 0.006, 3)
	t.box(Vector3(0.0, 0.345, -0.6), Vector3(0.05, 0.02, 0.02))
	V4._antenna(t, Vector3(-0.36, 0.19, -0.6), 0.55)
	V4._antenna(t, Vector3(0.36, 0.19, -0.62), 0.45)
	U()._smoke(t, Vector3(0.44, 0.15, 0.25), 40.0)
	U()._smoke(t, Vector3(-0.44, 0.15, 0.25), -40.0)
	# mantlet: chamfered gun shield
	t.color(US_D, Geo.PAINT)
	t.xloft([[0.56, K.sect(0.03, 0.06, 0.17, 0.13, 0.15, 0.13, 0.03)], [0.46, K.sect(0.02, 0.05, 0.19, 0.15, 0.17, 0.15, 0.03)]])
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.11, 0.54), func(b) -> void:
		b.color("#5d6650", Geo.CANVAS)   # mantlet dust cover
		b.tube(Vector3(0, 0, -0.02), Vector3(0, 0, 0.1), 0.068, 10, 0.05)
		b.color(US, Geo.PAINT)
		b.gun(0.08, 1.14, 0.045, 0.034, 0.42, false, 10)
		b.color(US_D, Geo.PAINT)
		for z in [0.25, 0.8]:
			b.tube(Vector3(0, 0, z), Vector3(0, 0, z + 0.03), 0.047, 10)   # thermal sleeve clamps
		b.color(US_S, Geo.STEEL)
		b.tube(Vector3(0, 0, 1.1), Vector3(0, 0, 1.15), 0.04, 10)
		b.cbox(Vector3(0, 0.048, 1.09), Vector3(0.03, 0.025, 0.04), 0.005))
	U()._vfinish(root, model, h, mat, "halberd", [t, b], 1.35)

# ------------------------------------------------------------------ M3.1 M109A7 self-propelled howitzer
## Tracked SPH: low hull with the engine and driver up front, a big flat-sided turret set back
## with a long bustle, side crew doors and stowage, commander's cupola with an HMG, and a long
## 155 mm barrel (fume extractor, double-baffle muzzle brake) resting in a travel lock on the
## glacis. Barrel elevates when firing (VehicleView.elevate). Olive green (camo pattern 0).
static func _m109a7() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 1.0, "bar_height": 1.3, "recoil": 0.22, "wreck_s": 8.0, "elevate": 0.62})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.5, 1.94, 7, 0.085, 0.25, US_S)
	# lower hull tub
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.98, K.sect(0.2, 0.28, 0.33, 0.3, 0.37, 0.38, 0.0)], [0.78, K.sect(0.13, 0.22, 0.34, 0.34, 0.39, 0.39, 0.0)],
		[-0.9, K.sect(0.13, 0.22, 0.35, 0.34, 0.39, 0.39, 0.0)], [-0.98, K.sect(0.17, 0.25, 0.36, 0.32, 0.38, 0.38, 0.0)]])
	# upper hull: raked glacis over the front engine, flat deck, vertical sides over the tracks
	h.color(US, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.33, 0.34, 0.36, 0.6, 0.61, 0.58, 0.012)], [0.6, K.sect(0.33, 0.37, 0.47, 0.63, 0.64, 0.62, 0.02)],
		[-0.92, K.sect(0.33, 0.37, 0.48, 0.63, 0.64, 0.62, 0.02)], [-0.99, K.sect(0.33, 0.36, 0.45, 0.61, 0.62, 0.6, 0.015)]])
	# track guards / fenders with stowage bins
	for s in [-1.0, 1.0]:
		h.color(US_D, Geo.PAINT)
		h.cbox(Vector3(s * 0.63, 0.345, 0.0), Vector3(0.05, 0.03, 1.94), 0.008)
		for i in 4:
			h.color(US if i % 2 == 0 else US_D, Geo.PAINT)
			h.plate(Vector3(s * 0.655, 0.29, -0.7 + i * 0.47), Vector3(0.025, 0.1, 0.45), Vector3(0, 0, -s * 4.0))
			h.color(US_S, Geo.STEEL)
			h.rivets(Vector3(s * 0.672, 0.33, -0.86 + i * 0.47), Vector3(s * 0.672, 0.33, -0.54 + i * 0.47), 3, Vector3(s, 0, 0), 0.006)
	# engine: front-right grilles; driver: front-left hatch + periscopes
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0.24, 0.465, 0.42), 0.34, 0.34, 8)
	h.grille(Vector3(0.24, 0.47, 0.0), 0.3, 0.22, 6)
	h.color(US_D, Geo.PAINT)
	h.hatch(Vector3(-0.3, 0.475, 0.5), 0.16)
	h.color(GLASS_C, Geo.GLASS)
	for x in [-0.38, -0.3, -0.22]:
		h.box(Vector3(x, 0.49, 0.6), Vector3(0.05, 0.02, 0.025))
	V4._lamps(h, 0.5, 0.36, 0.99)
	h.color(US_S, Geo.STEEL)
	for x in [-0.36, 0.36]:
		h.tube(Vector3(x, 0.2, 0.96), Vector3(x, 0.2, 1.04), 0.022, 6)   # tow eyes
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0.48, 0.44, 0.58), 0.12, 0.05, 3)                       # exhaust
	# travel lock (barrel crutch) on the glacis
	h.color(US_S, Geo.STEEL)
	for x in [-0.07, 0.07]:
		h.tube(Vector3(x, 0.4, 0.84), Vector3(x * 0.7, 0.62, 0.8), 0.016, 6)
	h.cbox(Vector3(0, 0.63, 0.8), Vector3(0.2, 0.04, 0.06), 0.008)
	# rear: big crew/ammo door, steps, tail lamps
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.36, -0.995), Vector3(0.42, 0.22, 0.02), 0.006)
	h.color(US_S, Geo.STEEL)
	h.box(Vector3(0.14, 0.38, -1.01), Vector3(0.04, 0.02, 0.02))
	h.cbox(Vector3(0, 0.15, -1.02), Vector3(0.5, 0.025, 0.08), 0.006)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.55, 0.55]:
		h.box(Vector3(x, 0.42, -0.99), Vector3(0.05, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.67, 0.29, 0.0), Vector3(0.006, 0.03, 1.5), Vector3(0, 0, -s * 4.0))
	# turret: set back on the hull, flat slab sides, chamfered roof, long overhanging bustle
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.48, -0.28))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.42, 0.42, 0.03, 18, Transform3D(Basis.IDENTITY, Vector3(0, -0.005, 0)))
	var plan := [Vector2(-0.52, -0.78), Vector2(0.52, -0.78), Vector2(0.54, 0.3), Vector2(0.42, 0.56), Vector2(-0.42, 0.56), Vector2(-0.54, 0.3)]
	t.color(US, Geo.PAINT)
	t.plan_loft(plan, 0.02, 0.33, Vector2(0.97, 0.98))
	var top: Array = []
	for q: Vector2 in plan:
		top.append(Vector2(q.x * 0.97, q.y * 0.98))
	t.plan_loft(top, 0.33, 0.37, Vector2(0.94, 0.95))
	# panel seams / welds on the slab sides
	t.color(US_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [-0.42, -0.02, 0.28]:
			t.box(Vector3(s * 0.535, 0.18, z), Vector3(0.006, 0.28, 0.012))
		t.box(Vector3(s * 0.535, 0.31, -0.24), Vector3(0.006, 0.012, 1.04))
		# side crew door with handle + hinges
		t.cbox(Vector3(s * 0.54, 0.16, 0.06), Vector3(0.016, 0.22, 0.22), 0.004)
		t.color(US_S, Geo.STEEL)
		t.box(Vector3(s * 0.552, 0.18, 0.14), Vector3(0.01, 0.02, 0.04))
		t.rivets(Vector3(s * 0.55, 0.08, -0.04), Vector3(s * 0.55, 0.24, -0.04), 3, Vector3(s, 0, 0), 0.007)
		# stowage racks + bags along the sides
		t.rail([Vector3(s * 0.55, 0.3, -0.3), Vector3(s * 0.6, 0.3, -0.3), Vector3(s * 0.6, 0.3, -0.72), Vector3(s * 0.55, 0.3, -0.72)], 0.07, 0.12, 0.005)
		t.color("#6b5a3a" if s < 0 else "#56604a", Geo.CANVAS)
		t.cbox(Vector3(s * 0.585, 0.25, -0.5), Vector3(0.07, 0.09, 0.36), 0.025)
		t.color(US, Geo.PAINT)
	# bustle rack at the rear
	t.color(US_S, Geo.STEEL)
	t.rail([Vector3(-0.5, 0.37, -0.78), Vector3(-0.5, 0.37, -0.92), Vector3(0.5, 0.37, -0.92), Vector3(0.5, 0.37, -0.78)], 0.1, 0.16, 0.006)
	t.color("#5d5236", Geo.CANVAS)
	t.cbox(Vector3(-0.2, 0.42, -0.86), Vector3(0.4, 0.08, 0.1), 0.025)
	t.color("#4d5741", Geo.PAINT)
	t.jerrycan(Vector3(0.3, 0.4, -0.86), 90.0)
	# roof: commander's cupola + M2-type HMG, loader hatch, vents, sights, antennas
	t.color(US_D, Geo.PAINT)
	t.ccyl(0.11, 0.07, 0.015, 12, Transform3D(Basis.IDENTITY, Vector3(0.26, 0.37, -0.2)))
	t.color(GLASS_C, Geo.GLASS)
	for i in 6:
		var a := TAU * i / 6.0
		t.box(Vector3(0.26 + cos(a) * 0.1, 0.41, -0.2 + sin(a) * 0.1), Vector3(0.025, 0.015, 0.025))
	U()._mg(t, Vector3(0.26, 0.5, -0.14), 0.0, 0.3)
	t.color(US_D, Geo.PAINT)
	t.hatch(Vector3(-0.24, 0.372, -0.3), 0.16)
	t.color("#2b2d2c", Geo.DARK)
	t.vent(Vector3(0.0, 0.375, -0.6), 0.3, 0.06, 4)
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(-0.34, 0.41, 0.26), Vector3(0.1, 0.07, 0.1), 0.01)   # panoramic sight
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(-0.34, 0.415, 0.312), Vector3(0.07, 0.035, 0.006))
	V4._antenna(t, Vector3(-0.46, 0.37, -0.7), 0.6)
	V4._antenna(t, Vector3(0.46, 0.37, -0.72), 0.5)
	U()._smoke(t, Vector3(0.5, 0.28, 0.42), 35.0)
	U()._smoke(t, Vector3(-0.5, 0.28, 0.42), -35.0)
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.2, -0.785), Vector3(0.7, 0.05, 0.01))
	# mantlet: tall gun shield on the turret face
	t.color(US_D, Geo.PAINT)
	t.xloft([[0.62, K.sect(0.08, 0.12, 0.27, 0.15, 0.17, 0.15, 0.03)], [0.54, K.sect(0.06, 0.1, 0.29, 0.18, 0.2, 0.18, 0.03)]])
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.19, 0.6), func(b) -> void:
		b.color("#5d6650", Geo.CANVAS)   # mantlet boot
		b.tube(Vector3(0, 0, -0.02), Vector3(0, 0, 0.12), 0.075, 12, 0.055)
		b.color(US, Geo.PAINT)
		b.gun(0.1, 1.72, 0.05, 0.04, -1.0, false, 12)
		b.color(US_D, Geo.PAINT)
		b.tube(Vector3(0, 0, 0.72), Vector3(0, 0, 0.92), 0.058, 12)   # fume extractor
		for z in [0.71, 0.93]:
			b.tube(Vector3(0, 0, z - 0.01), Vector3(0, 0, z + 0.01), 0.061, 12)
		b.color(US_S, Geo.STEEL)
		for z in [1.71, 1.82]:   # double-baffle muzzle brake
			b.cbox(Vector3(0, 0, z + 0.03), Vector3(0.15, 0.1, 0.06), 0.014)
		b.tube(Vector3(0, 0, 1.7), Vector3(0, 0, 1.88), 0.034, 10)
		b.color("#1d1f1e", Geo.DARK)
		for x in [-0.076, 0.076]:
			b.box(Vector3(x, 0, 1.785), Vector3(0.006, 0.06, 0.1))
		b.color(US_S, Geo.STEEL)
		for x in [-0.075, 0.075]:
			b.tube(Vector3(x, 0.055, 0.0), Vector3(x, 0.055, 0.4), 0.022, 8))   # recoil cylinders
	U()._vfinish(root, model, h, mat, "longreach", [t, b], 1.3)

# ------------------------------------------------------------------ Lynx JLTV (JLTV-inspired)
static func _lynx() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.35, "recoil": 0.03, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tyres(h, 0.42, [0.52, -0.46], 0.175, 0.15, 1)
	h.color(US_S, Geo.STEEL)   # independent suspension arms + half shafts
	for z in [0.52, -0.46]:
		for s in [-1.0, 1.0]:
			h.tube(Vector3(s * 0.12, 0.2, z), Vector3(s * 0.34, 0.17, z), 0.015, 4)
			h.tube(Vector3(s * 0.14, 0.27, z + 0.06), Vector3(s * 0.3, 0.27, z + 0.04), 0.01, 4)
	# V-hull tub
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.86, K.sect(0.3, 0.4, 0.5, 0.1, 0.3, 0.32, 0.0)], [0.7, K.sect(0.22, 0.36, 0.5, 0.1, 0.34, 0.34, 0.0)],
		[-0.74, K.sect(0.22, 0.36, 0.5, 0.1, 0.34, 0.34, 0.0)], [-0.84, K.sect(0.27, 0.38, 0.5, 0.1, 0.32, 0.33, 0.0)]])
	# flared fenders: raked side profile, outward-canted top plates
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [0.52, -0.46]:
			h.prism_x([Vector2(z - 0.25, 0.42), Vector2(z + 0.25, 0.42), Vector2(z + 0.19, 0.51), Vector2(z - 0.19, 0.51)], s * 0.34, s * 0.48)
			h.plate(Vector3(s * 0.5, 0.47, z), Vector3(0.03, 0.08, 0.4), Vector3(0, 0, s * 18.0))
	# hood: chamfered, sloping to a low nose with the grille and a raised power bulge
	var hs0 := K.sect(0.48, 0.53, 0.6, 0.36, 0.39, 0.33, 0.05)
	var hs1 := K.sect(0.48, 0.54, 0.68, 0.39, 0.41, 0.36, 0.06)
	h.xloft([[0.9, hs0], [0.56, hs1], [0.24, K.sect(0.48, 0.54, 0.71, 0.39, 0.41, 0.37, 0.06)]])
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.78, K.sect(0.6, 0.62, 0.68, 0.14, 0.15, 0.12, 0.02)], [0.3, K.sect(0.66, 0.68, 0.74, 0.15, 0.16, 0.13, 0.02)]])
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.545, 0.905), 0.42, 0.08, 4)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.26, 0.67, 0.45), Vector3(0.12, 0.006, 0.2), Vector3(-7, 0, s * 9.0))   # hood louvres
	# armoured crew cab: raked windscreen, tumblehome sides, thick glazing laid on the faces
	h.color(US, Geo.PAINT)
	var c0 := K.sect(0.5, 0.6, 0.73, 0.4, 0.41, 0.4, 0.02)
	var c1 := K.sect(0.5, 0.62, 0.98, 0.4, 0.41, 0.33, 0.05)
	var c2 := K.sect(0.5, 0.62, 0.98, 0.4, 0.41, 0.34, 0.05)
	var c3 := K.sect(0.5, 0.62, 0.94, 0.39, 0.4, 0.33, 0.04)
	h.xloft([[0.27, c0], [0.07, c1], [-0.64, c2], [-0.72, c3]])
	_glass(h, c0, 0.27, c1, 0.07, 4, 5, Vector2(0.06, 0.94), Vector2(0.08, 0.86), Vector3(0, 1, 1))   # split windscreen
	h.color(US_D, Geo.PAINT)
	h.pane([_on(c0, 0.27, c1, 0.07, 4, 5, 0.49, 0.0), _on(c0, 0.27, c1, 0.07, 4, 5, 0.51, 0.0), _on(c0, 0.27, c1, 0.07, 4, 5, 0.51, 1.0), _on(c0, 0.27, c1, 0.07, 4, 5, 0.49, 1.0)], Vector3(0, 1, 1), 0.012)
	for s in [-1.0, 1.0]:
		var i0 := 2 if s > 0 else 7
		var i1 := 3 if s > 0 else 6
		for zz in [Vector2(0.05, 0.42), Vector2(0.52, 0.9)]:
			_glass(h, c1, 0.07, c2, -0.64, i0, i1, Vector2(0.12, 0.88), zz, Vector3(s, 0, 0))
		h.color(US_S, Geo.STEEL)
		for z2 in [-0.1, -0.44]:
			h.box(Vector3(s * 0.415, 0.6, z2), Vector3(0.015, 0.015, 0.05))   # door handles
		h.color(US_D, Geo.PAINT)
		for z in [0.12, -0.25, -0.6]:
			h.plate(Vector3(s * 0.405, 0.56, z), Vector3(0.008, 0.11, 0.008), Vector3.ZERO)   # door seams
	h.color(US_S, Geo.STEEL)
	h.cbox(Vector3(0, 0.49, 0.92), Vector3(0.66, 0.08, 0.05), 0.01)   # brush bar / winch
	for s in [-0.3, 0.3]:
		h.tube(Vector3(s, 0.45, 0.92), Vector3(s, 0.6, 0.94), 0.012, 4)
	# rear: stowage bin, spare tyre, jerrycans, tail lamps
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(-0.12, 0.62, -0.8), Vector3(0.3, 0.16, 0.12), 0.025)
	h.tyre(Vector3(0.22, 0.66, -0.82), 0.13, 0.07, false, US_S, 10)
	h.color("#4d5741", Geo.PAINT)
	h.jerrycan(Vector3(-0.3, 0.6, -0.82), 90)
	h.color("#b33a2a", Geo.LAMP)
	for x in [-0.33, 0.33]:
		h.box(Vector3(x, 0.47, -0.845), Vector3(0.04, 0.03, 0.01))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.409, 0.53, -0.2), Vector3(0.006, 0.04, 0.7))
	V4._lamps(h, 0.3, 0.56, 0.9)
	V4._antenna(h, Vector3(-0.3, 0.98, -0.55), 0.5)
	V4._antenna(h, Vector3(0.3, 0.98, -0.58), 0.4)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.97, -0.25))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.ccyl(0.17, 0.04, 0.01, 14, Transform3D.IDENTITY)
	t.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:   # gunner shield wings with view blocks
		t.plate(Vector3(s * 0.15, 0.12, 0.05), Vector3(0.025, 0.18, 0.2), Vector3(0, s * 25.0, s * 6.0))
	t.plate(Vector3(0, 0.12, 0.13), Vector3(0.2, 0.18, 0.025), Vector3(-8, 0, 0))
	t.color(GLASS_C, Geo.GLASS)
	t.plate(Vector3(0, 0.16, 0.146), Vector3(0.08, 0.05, 0.006), Vector3(-8, 0, 0))
	t.color(US_D, Geo.PAINT)
	t.cbox(Vector3(0, 0.08, -0.14), Vector3(0.22, 0.12, 0.08), 0.015)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.13, 0.12), func(b) -> void:
		b.color(US_S, Geo.STEEL)
		b.cbox(Vector3(0, 0, 0.05), Vector3(0.06, 0.07, 0.16), 0.01)
		b.gun(0.1, 0.42, 0.015, 0.013, -1.0, false, 8)
		b.tube(Vector3(0, 0, 0.36), Vector3(0, 0, 0.44), 0.02, 8)   # flash hider
		b.color("#4d5741", Geo.PAINT)
		b.cbox(Vector3(0.055, -0.01, 0.02), Vector3(0.05, 0.06, 0.08), 0.008))
	U()._vfinish(root, model, h, mat, "lynx", [t, b], 1.35)

# ------------------------------------------------------------------ Picket SHORAD (Avenger-inspired)
static func _picket() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.7, "bar_height": 1.5, "recoil": 0.02, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tyres(h, 0.42, [0.5, -0.45], 0.16, 0.14, 1)
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.86, K.sect(0.28, 0.36, 0.46, 0.2, 0.34, 0.35, 0.0)], [0.72, K.sect(0.2, 0.32, 0.46, 0.22, 0.36, 0.36, 0.0)],
		[-0.76, K.sect(0.2, 0.32, 0.46, 0.22, 0.36, 0.36, 0.0)], [-0.84, K.sect(0.24, 0.34, 0.46, 0.2, 0.34, 0.35, 0.0)]])
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [0.5, -0.45]:
			h.prism_x([Vector2(z - 0.23, 0.4), Vector2(z + 0.23, 0.4), Vector2(z + 0.18, 0.475), Vector2(z - 0.18, 0.475)], s * 0.36, s * 0.47)
	# HMMWV hood: wide, low, sloping, chamfered, with a raised centre and grille slots
	h.xloft([[0.88, K.sect(0.4, 0.44, 0.53, 0.4, 0.43, 0.38, 0.04)], [0.18, K.sect(0.4, 0.46, 0.61, 0.42, 0.44, 0.41, 0.04)]])
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.47, 0.885), 0.36, 0.08, 5)
	h.grille(Vector3(0, 0.583, 0.45), 0.3, 0.14, 6)
	# crew cab: raked windscreen, hard top, glazing laid on the faces
	h.color(US, Geo.PAINT)
	var c0 := K.sect(0.46, 0.55, 0.63, 0.41, 0.42, 0.41, 0.02)
	var c1 := K.sect(0.46, 0.56, 0.83, 0.41, 0.42, 0.37, 0.035)
	var c2 := K.sect(0.46, 0.56, 0.83, 0.41, 0.42, 0.37, 0.035)
	var c3 := K.sect(0.46, 0.56, 0.8, 0.4, 0.41, 0.36, 0.03)
	h.xloft([[0.24, c0], [0.12, c1], [-0.13, c2], [-0.17, c3]])
	_glass(h, c0, 0.24, c1, 0.12, 4, 5, Vector2(0.05, 0.95), Vector2(0.1, 0.85), Vector3(0, 1, 1))
	for s in [-1.0, 1.0]:
		_glass(h, c1, 0.12, c2, -0.13, 2 if s > 0 else 7, 3 if s > 0 else 6, Vector2(0.15, 0.85), Vector2(0.08, 0.9), Vector3(s, 0, 0))
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.5, -0.5), Vector3(0.82, 0.08, 0.62), 0.02)   # flat bed
	h.color(US_S, Geo.STEEL)
	h.rail([Vector3(-0.4, 0.54, -0.8), Vector3(-0.4, 0.54, -0.2)], 0.08, 0.15, 0.005)
	h.rail([Vector3(0.4, 0.54, -0.8), Vector3(0.4, 0.54, -0.2)], 0.08, 0.15, 0.005)
	h.cbox(Vector3(0, 0.48, 0.92), Vector3(0.6, 0.07, 0.04), 0.01)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(-0.28, 0.6, -0.72), Vector3(0.2, 0.12, 0.12), 0.02)   # generator / cooling
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(-0.28, 0.6, -0.781), 0.16, 0.08, 3, 180)
	h.color("#4d5741", Geo.PAINT)
	h.jerrycan(Vector3(0.3, 0.6, -0.74), 90)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.364, 0.42, 0.05), Vector3(0.006, 0.04, 0.4))
	V4._lamps(h, 0.3, 0.48, 0.885)
	V4._antenna(h, Vector3(0.34, 0.83, -0.1), 0.45)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.56, -0.48))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.ccyl(0.23, 0.05, 0.012, 14, Transform3D.IDENTITY)
	# gunner pod: faceted, sloped front glazing
	t.color(US, Geo.PAINT)
	var p0 := K.sect(0.04, 0.12, 0.24, 0.16, 0.17, 0.16, 0.02)
	var p1 := K.sect(0.04, 0.12, 0.4, 0.16, 0.17, 0.13, 0.04)
	t.xloft([[0.18, p0], [0.08, p1], [-0.16, K.sect(0.04, 0.12, 0.4, 0.16, 0.17, 0.13, 0.04)], [-0.18, K.sect(0.04, 0.12, 0.37, 0.15, 0.16, 0.12, 0.03)]])
	_glass(t, p0, 0.18, p1, 0.08, 4, 5, Vector2(0.08, 0.92), Vector2(0.12, 0.85), Vector3(0, 1, 1))
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0.0, 0.45, -0.04), Vector3(0.12, 0.08, 0.1), 0.015)   # FLIR / laser rangefinder head
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.0, 0.45, 0.012), Vector3(0.07, 0.05, 0.006))
	t.color(US_S, Geo.STEEL)
	for s in [-1.0, 1.0]:   # launcher arms
		t.plate(Vector3(s * 0.19, 0.24, 0.0), Vector3(0.05, 0.08, 0.16), Vector3(0, 0, s * -20.0))
	t.color("#ffffff", Geo.TEAM)
	t.box(Vector3(0, 0.3, -0.182), Vector3(0.22, 0.04, 0.01))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, 0.24, 0.0), func(b) -> void:
		for s in [-0.3, 0.3]:   # twin 4-round missile pods: chamfered boxes, bevelled nose
			b.color(US, Geo.PAINT)
			b.xloft([[0.34, K.sect(-0.1, -0.08, 0.1, 0.09, 0.1, 0.09, 0.025)], [-0.18, K.sect(-0.11, -0.09, 0.11, 0.1, 0.11, 0.1, 0.03)]], Transform3D(Basis.IDENTITY, Vector3(s, 0, 0)))
			b.color(US_D, Geo.PAINT)
			b.box(Vector3(s, 0.0, 0.08), Vector3(0.225, 0.02, 0.5))
			b.color("#1d1f1e", Geo.DARK)
			for k in 4:
				b.ccyl(0.035, 0.012, 0.006, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s - 0.05 + (k % 2) * 0.1, -0.05 + (k / 2) * 0.1, 0.342)))
			b.color(US_S, Geo.STEEL)
			b.box(Vector3(s * 0.62, 0.0, 0.05), Vector3(0.06, 0.06, 0.12))
		b.color(US_S, Geo.STEEL)
		b.gun(0.08, 0.5, 0.014, 0.012, -1.0, false, 6)
		b.tube(Vector3(0, 0, 0.44), Vector3(0, 0, 0.52), 0.018, 6)
		b.cbox(Vector3(0, 0, 0.06), Vector3(0.05, 0.06, 0.12), 0.008))
	U()._vfinish(root, model, h, mat, "picket", [t, b], 1.5)

# ------------------------------------------------------------------ Longreach howitzer (M777-inspired, with prime mover)
static func _longreach() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.95, "bar_height": 1.3, "recoil": 0.3, "wreck_s": 8.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# prime mover (front): forward-control 4x4 cab + canvas crew bay
	_tyres(h, 0.38, [0.85, 0.35], 0.145, 0.12, 1)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.27, 0.55), Vector3(0.52, 0.08, 0.9), 0.015)
	h.color(US, Geo.PAINT)
	var c0 := K.sect(0.31, 0.42, 0.55, 0.35, 0.36, 0.34, 0.03)
	var c1 := K.sect(0.31, 0.43, 0.72, 0.35, 0.36, 0.3, 0.045)
	var c2 := K.sect(0.31, 0.43, 0.72, 0.35, 0.36, 0.31, 0.045)
	h.xloft([[1.01, c0], [0.92, c1], [0.66, c2], [0.63, K.sect(0.31, 0.43, 0.69, 0.34, 0.35, 0.3, 0.04)]])
	_glass(h, c0, 1.01, c1, 0.92, 4, 5, Vector2(0.06, 0.94), Vector2(0.1, 0.88), Vector3(0, 1, 1))
	for s in [-1.0, 1.0]:
		_glass(h, c1, 0.92, c2, 0.66, 2 if s > 0 else 7, 3 if s > 0 else 6, Vector2(0.15, 0.85), Vector2(0.1, 0.6), Vector3(s, 0, 0))
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.38, 1.015), 0.4, 0.08, 4)
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		for z in [0.85, 0.35]:
			h.prism_x([Vector2(z - 0.19, 0.27), Vector2(z + 0.19, 0.27), Vector2(z + 0.15, 0.33), Vector2(z - 0.15, 0.33)], s * 0.26, s * 0.38)
	h.color("#5d5236", Geo.CANVAS)   # canvas crew bay on hoops: rounded tilt
	h.xloft([[0.6, K.sect(0.33, 0.6, 0.7, 0.32, 0.32, 0.26, 0.07)], [0.08, K.sect(0.33, 0.6, 0.7, 0.32, 0.32, 0.26, 0.07)]])
	h.color(US_S, Geo.STEEL)
	for z in [0.15, 0.34, 0.53]:
		h.box(Vector3(0, 0.705, z), Vector3(0.4, 0.012, 0.02))
	V4._lamps(h, 0.26, 0.4, 1.01)
	V4._antenna(h, Vector3(0.3, 0.72, 0.75), 0.4)
	# towed gun: carriage, split trails with spades, treaded wheels, shield
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.25, 0.12), Vector3(0, 0.25, -0.2), 0.03, 6)
	for s in [-1.0, 1.0]:
		h.color(US, Geo.PAINT)
		h.tube(Vector3(s * 0.08, 0.22, -0.2), Vector3(s * 0.32, 0.12, -0.95), 0.035, 6, 0.028)
		h.color(US_S, Geo.STEEL)
		h.rcbox(Vector3(s * 0.33, 0.08, -1.0), Vector3(0.14, 0.1, 0.03), 0.008, Vector3(-30, 0, 0))   # spade
		h.tyre(Vector3(s * 0.4, 0.17, -0.42), 0.17, 0.12, false, US_S, 12)
		h.color(US, Geo.PAINT)
		h.prism_x([Vector2(-0.6, 0.3), Vector2(-0.25, 0.3), Vector2(-0.3, 0.36), Vector2(-0.55, 0.36)], s * 0.32, s * 0.48)
	h.color(US, Geo.PAINT)
	h.xloft([[-0.25, K.sect(0.28, 0.3, 0.38, 0.22, 0.25, 0.22, 0.03)], [-0.59, K.sect(0.28, 0.3, 0.38, 0.22, 0.25, 0.22, 0.03)]])
	h.color(US_D, Geo.PAINT)
	h.plate(Vector3(0, 0.39, -0.2), Vector3(0.6, 0.03, 0.06), Vector3(-20, 0, 0))
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.362, 0.37, 0.8), Vector3(0.008, 0.05, 0.26))
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.4, -0.42))
	var t = K.new()
	t.color(US, Geo.PAINT)
	for x in [-0.14, 0.14]:   # cradle cheeks with trunnions (bevelled tops)
		t.xloft([[0.15, K.sect(0.0, 0.14, 0.23, 0.025, 0.025, 0.025, 0.012)], [-0.15, K.sect(0.0, 0.14, 0.2, 0.025, 0.025, 0.025, 0.012)]], Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
		t.color(US_S, Geo.STEEL)
		t.tube(Vector3(x * 1.4, 0.18, 0), Vector3(x * 0.9, 0.18, 0), 0.03, 8)
		t.color(US, Geo.PAINT)
	t.color(US_S, Geo.STEEL)
	t.cbox(Vector3(0, 0.03, 0.0), Vector3(0.36, 0.05, 0.36), 0.015)
	t.cbox(Vector3(0.2, 0.1, -0.08), Vector3(0.06, 0.1, 0.08), 0.01)   # sight box
	t.color(GLASS_C, Geo.GLASS)
	t.box(Vector3(0.2, 0.12, -0.035), Vector3(0.04, 0.03, 0.006))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, 0.18, 0.0))
	bn.rotation.x = -0.5
	var b = K.new()
	b.color(US_D, Geo.PAINT)
	b.xloft([[0.26, K.sect(-0.065, -0.04, 0.065, 0.06, 0.08, 0.06, 0.02)], [-0.3, K.sect(-0.065, -0.04, 0.065, 0.06, 0.08, 0.06, 0.02)]])   # cradle / recoil housing
	b.color(US, Geo.PAINT)
	b.gun(0.0, 1.5, 0.048, 0.036, -1.0, false, 10)
	b.color(US_S, Geo.STEEL)
	for z in [1.5, 1.6]:   # double-baffle muzzle brake
		b.cbox(Vector3(0, 0, z + 0.03), Vector3(0.14, 0.09, 0.05), 0.012)
	b.tube(Vector3(0, 0, 1.5), Vector3(0, 0, 1.64), 0.03, 8)
	b.color("#1d1f1e", Geo.DARK)
	for s in [-0.071, 0.071]:
		b.box(Vector3(s, 0, 1.565), Vector3(0.006, 0.05, 0.09))
	b.color(US_S, Geo.STEEL)
	for x in [-0.07, 0.07]:
		b.tube(Vector3(x, 0.06, -0.25), Vector3(x, 0.06, 0.3), 0.022, 8)   # recuperators
	b.tube(Vector3(0, -0.07, -0.25), Vector3(0, -0.07, 0.2), 0.02, 8)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	U()._vfinish(root, model, h, mat, "longreach", [t, b], 1.3)

# ------------------------------------------------------------------ Dozer (D9-inspired armoured bulldozer)
static func _dozer() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.track_run(0.4, 1.3, 4, 0.09, 0.22, US_S)
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.5, K.sect(0.14, 0.2, 0.3, 0.2, 0.26, 0.27, 0.0)], [-0.62, K.sect(0.14, 0.2, 0.3, 0.2, 0.26, 0.27, 0.0)]])   # belly / track frame
	# engine hood narrowing to the front, chamfered, with radiator + side louvres
	h.color(US, Geo.PAINT)
	var e0 := K.sect(0.28, 0.32, 0.43, 0.25, 0.27, 0.22, 0.05)
	var e1 := K.sect(0.28, 0.33, 0.47, 0.29, 0.3, 0.27, 0.05)
	h.xloft([[0.32, e0], [-0.5, e1], [-0.56, K.sect(0.28, 0.33, 0.45, 0.28, 0.29, 0.26, 0.04)]])
	h.color(US, Geo.PAINT)   # fender decks over the tracks
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.4, 0.3, -0.12), Vector3(0.24, 0.025, 1.1), Vector3.ZERO)
		h.plate(Vector3(s * 0.4, 0.28, 0.48), Vector3(0.24, 0.025, 0.12), Vector3(-25, 0, 0))
	h.color("#2b2d2c", Geo.DARK)
	h.grille(Vector3(0, 0.442, 0.0), 0.36, 0.3, 7)
	h.vent(Vector3(0, 0.35, 0.325), 0.4, 0.12, 5)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.285, 0.38, -0.1), Vector3(0.006, 0.06, 0.3), Vector3(0, 0, s * 15.0))
	# ROPS cab: armoured safety-yellow frame, glass, angled roof
	h.plain = true
	h.color(YEL, Geo.PAINT)
	for p in [Vector3(-0.23, 0, -0.04), Vector3(0.23, 0, -0.04), Vector3(-0.23, 0, -0.42), Vector3(0.23, 0, -0.42)]:
		h.cbox(p + Vector3(0, 0.66, 0), Vector3(0.04, 0.4, 0.04), 0.01)
	h.xloft([[0.0, K.sect(0.86, 0.87, 0.9, 0.27, 0.28, 0.25, 0.015)], [-0.46, K.sect(0.86, 0.87, 0.91, 0.27, 0.28, 0.25, 0.015)]])
	h.plain = false
	h.color(GLASS_C, Geo.GLASS)
	h.plate(Vector3(0, 0.66, -0.04), Vector3(0.42, 0.3, 0.008), Vector3(-6, 0, 0))
	for s in [-0.23, 0.23]:
		h.box(Vector3(s, 0.66, -0.23), Vector3(0.008, 0.3, 0.34))
	h.color("#2e2f2b", Geo.DARK)
	h.cbox(Vector3(0, 0.55, -0.25), Vector3(0.2, 0.08, 0.16), 0.02)   # seat
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.18, 0.44, 0.2), Vector3(0.18, 0.92, 0.2), 0.028, 8, 0.024)   # exhaust
	h.tube(Vector3(0.18, 0.9, 0.2), Vector3(0.18, 0.95, 0.24), 0.034, 8)
	h.color("#ff9a2a", Geo.LAMP)
	h.cbox(Vector3(-0.2, 0.93, -0.42), Vector3(0.05, 0.04, 0.05), 0.01)   # beacon
	# rear ripper
	h.color(US_S, Geo.STEEL)
	h.plate(Vector3(0, 0.28, -0.7), Vector3(0.36, 0.06, 0.1), Vector3.ZERO)
	h.plate(Vector3(0, 0.14, -0.78), Vector3(0.05, 0.26, 0.05), Vector3(-25, 0, 0))
	# M3.3: the blade (push arms, rams, blade, cutting edge) is its own node "Blade", pivoting
	# on the push-arm mounts, so the dozer can push, lift and dump while it builds (VehicleView)
	var w = K.new()
	var piv := Vector3(0, 0.2, 0.05)
	w.xf = Transform3D(Basis.IDENTITY, -piv)
	# blade on push arms with hydraulic rams
	for s in [-0.36, 0.36]:
		w.tube(Vector3(s, 0.2, 0.05), Vector3(s, 0.2, 0.72), 0.03, 6)
		w.tube(Vector3(s * 0.7, 0.5, 0.25), Vector3(s * 0.8, 0.32, 0.7), 0.022, 6)
		w.color("#c9ccce", Geo.STEEL)
		w.tube(Vector3(s * 0.75, 0.41, 0.48), Vector3(s * 0.8, 0.32, 0.7), 0.012, 6)
		w.color(US_S, Geo.STEEL)
	w.plain = true
	w.color(YEL, Geo.PAINT)
	w.prism_x([Vector2(0.72, 0.04), Vector2(0.8, 0.06), Vector2(0.87, 0.2), Vector2(0.87, 0.34), Vector2(0.8, 0.48), Vector2(0.73, 0.46)], -0.54, 0.54)
	w.color("#b88d25", Geo.PAINT)
	for x in [-0.36, -0.12, 0.12, 0.36]:   # blade ribs (back side)
		w.box(Vector3(x, 0.28, 0.72), Vector3(0.03, 0.36, 0.05))
	for s in [-1.0, 1.0]:   # angled end plates
		w.plate(Vector3(s * 0.54, 0.25, 0.8), Vector3(0.03, 0.42, 0.14), Vector3(0, s * -12.0, 0))
	w.plain = false
	w.color(US_S, Geo.STEEL)
	w.plate(Vector3(0, 0.05, 0.85), Vector3(1.06, 0.04, 0.06), Vector3(20, 0, 0))   # cutting edge
	var bn := VK._mi(model, root, "Blade", w.commit(mat), piv)
	bn.set_meta("work", "blade")
	var d = K.new()
	d.color("#6e5a3e", Geo.SANDBAG)
	d.cbox(Vector3(0, 0.05, 0.02), Vector3(0.62, 0.1, 0.34), 0.04)   # pushed spoil heap
	d.cbox(Vector3(0.02, 0.13, 0.0), Vector3(0.42, 0.09, 0.24), 0.035)
	d.cbox(Vector3(-0.03, 0.2, -0.02), Vector3(0.22, 0.07, 0.14), 0.03)
	d.color("#5c4a33", Geo.SANDBAG)
	d.cbox(Vector3(0.12, 0.05, 0.08), Vector3(0.12, 0.08, 0.1), 0.03)
	d.cbox(Vector3(-0.14, 0.04, -0.04), Vector3(0.1, 0.07, 0.09), 0.03)
	var dn := VK._mi(bn, root, "Dirt", d.commit(mat), Vector3(0, -0.19, 0.98))
	dn.set_meta("dirt", true)
	dn.visible = false
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.52, 0.32, -0.12), Vector3(0.006, 0.03, 0.8))
	V4._lamps(h, 0.18, 0.84, 0.0)
	U()._vfinish(root, model, h, mat, "dozer", [], 1.2)

# ------------------------------------------------------------------ Supply Truck (harvester; FMTV-inspired 6x6)
static func _supply_truck() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.75, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	_tyres(h, 0.4, [0.55, -0.25, -0.6], 0.15, 0.13, 1)
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.3, -0.05), Vector3(0.5, 0.08, 1.62), 0.015)   # frame
	# cab-over: short sloped nose, raked windscreen, chamfered roof
	h.color(US, Geo.PAINT)
	h.xloft([[0.93, K.sect(0.33, 0.4, 0.5, 0.32, 0.34, 0.3, 0.04)], [0.78, K.sect(0.32, 0.41, 0.56, 0.36, 0.37, 0.34, 0.03)]])
	var c0 := K.sect(0.34, 0.45, 0.6, 0.37, 0.375, 0.37, 0.02)
	var c1 := K.sect(0.34, 0.46, 0.8, 0.37, 0.375, 0.33, 0.04)
	var c2 := K.sect(0.34, 0.46, 0.8, 0.37, 0.375, 0.335, 0.04)
	h.xloft([[0.79, c0], [0.7, c1], [0.34, c2], [0.32, K.sect(0.34, 0.46, 0.77, 0.36, 0.37, 0.33, 0.03)]])
	_glass(h, c0, 0.79, c1, 0.7, 4, 5, Vector2(0.06, 0.94), Vector2(0.1, 0.88), Vector3(0, 1, 1))
	for s in [-1.0, 1.0]:
		_glass(h, c1, 0.7, c2, 0.34, 2 if s > 0 else 7, 3 if s > 0 else 6, Vector2(0.18, 0.88), Vector2(0.08, 0.5), Vector3(s, 0, 0))
	h.color("#2b2d2c", Geo.DARK)
	h.vent(Vector3(0, 0.42, 0.935), 0.4, 0.1, 5)
	h.color(US, Geo.PAINT)
	for s in [-1.0, 1.0]:
		h.prism_x([Vector2(0.36, 0.35), Vector2(0.76, 0.35), Vector2(0.71, 0.43), Vector2(0.41, 0.43)], s * 0.3, s * 0.43)   # front fenders
		h.color(US_S, Geo.STEEL)
		h.tube(Vector3(s * 0.37, 0.6, 0.72), Vector3(s * 0.45, 0.7, 0.72), 0.008, 3)   # mirror arms
		h.cbox(Vector3(s * 0.46, 0.72, 0.72), Vector3(0.02, 0.08, 0.04), 0.006)
		h.color(US, Geo.PAINT)
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0.3, 0.6, 0.29), Vector3(0.3, 0.98, 0.29), 0.022, 6, 0.019)   # exhaust stack
	h.tube(Vector3(0.3, 0.7, 0.29), Vector3(0.3, 0.86, 0.29), 0.03, 6)   # heat shield
	h.cbox(Vector3(-0.3, 0.42, 0.3), Vector3(0.1, 0.12, 0.12), 0.015)   # air tank
	# cargo bed with drop sides + crates under nets, fuel cans, spare tyre
	h.color(US_D, Geo.PAINT)
	h.cbox(Vector3(0, 0.42, -0.38), Vector3(0.76, 0.08, 0.92), 0.015)
	for x in [-0.37, 0.37]:
		h.cbox(Vector3(x, 0.55, -0.38), Vector3(0.03, 0.18, 0.92), 0.008)
		for z in [-0.7, -0.38, -0.06]:
			h.box(Vector3(x * 1.03, 0.55, z), Vector3(0.012, 0.18, 0.02))
	h.cbox(Vector3(0, 0.55, -0.83), Vector3(0.76, 0.18, 0.03), 0.008)
	var cols := ["#7c6a45", "#6b5a3a", "#8a7650", "#5d6650"]
	for i in 4:
		h.color(cols[i], Geo.WOOD)
		h.cbox(Vector3(-0.17 + (i % 2) * 0.34, 0.6, -0.17 - (i / 2) * 0.42), Vector3(0.3, 0.26, 0.36), 0.02)
	h.color("#66704f", Geo.CANVAS)
	h.cbox(Vector3(0, 0.74, -0.38), Vector3(0.7, 0.025, 0.86), 0.01)
	for z in [-0.6, -0.17]:
		h.box(Vector3(0, 0.7, z), Vector3(0.72, 0.1, 0.02))
	h.color("#4d5741", Geo.PAINT)
	for z in [0.15, 0.22]:
		h.jerrycan(Vector3(-0.4, 0.32, z), 90)
	h.tyre(Vector3(0.41, 0.36, 0.1), 0.12, 0.06, false, US_S, 10)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.376, 0.4, 0.55), Vector3(0.006, 0.05, 0.3))
	V4._lamps(h, 0.28, 0.42, 0.935)
	V4._antenna(h, Vector3(-0.3, 0.8, 0.4), 0.4)
	U()._vfinish(root, model, h, mat, "supply_truck", [], 1.2)

# ------------------------------------------------------------------ aircraft helpers
## Thin swept surface (wing / stabiliser / fin) from a planform quad in its own plane: pts are
## [root LE, tip LE, tip TE, root TE] (local), th0 / th1 root / tip thickness along `up`.
static func _surf(h, pts: Array, up: Vector3, th0: float, th1: float, t := Transform3D.IDENTITY) -> void:
	var lo: Array = []
	var hi: Array = []
	for i in 4:
		var th := th0 if i == 0 or i == 3 else th1
		lo.append(pts[i] - up * th * 0.35)
		hi.append(pts[i] + up * th * 0.65)
	h.faces([lo, hi, [lo[0], lo[1], hi[1], hi[0]], [lo[1], lo[2], hi[2], hi[1]], [lo[2], lo[3], hi[3], hi[2]], [lo[3], lo[0], hi[0], hi[3]]], t)

static func _rotor(model: Node3D, root: Node3D, mat: Material, name: String, at: Vector3, r: float, n: int, axis_x := false) -> void:
	var rn := VK._n3(model, root, name, at)
	rn.set_meta("rotor_axis", "x" if axis_x else "y")
	var g = K.new()
	g.color("#2b2d2f", Geo.STEEL)
	if axis_x:
		g.cyl(0.03, 0.03, 0.04, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
		for i in n:
			var a := TAU * float(i) / float(n)
			g.rbox(Vector3(0, sin(a) * r * 0.5, cos(a) * r * 0.5), Vector3(0.01, 0.045, r), Vector3(-rad_to_deg(a), 0, 0))
	else:
		g.cyl(0.06, 0.045, 0.07, 8, Transform3D.IDENTITY)
		for i in n:
			var a := TAU * float(i) / float(n)
			var d := Vector3(cos(a), 0, sin(a))
			var sd := Vector3(-d.z, 0, d.x)
			g.color("#2b2d2f", Geo.STEEL)
			g.faces([[d * 0.05 - sd * 0.035 + Vector3(0, 0.03, 0), d * r * 0.85 - sd * 0.03 + Vector3(0, 0.025, 0), d * r * 0.85 + sd * 0.03 + Vector3(0, 0.03, 0), d * 0.05 + sd * 0.035 + Vector3(0, 0.04, 0)],
				[d * 0.05 - sd * 0.035 + Vector3(0, 0.042, 0), d * r * 0.85 - sd * 0.03 + Vector3(0, 0.034, 0), d * r * 0.85 + sd * 0.03 + Vector3(0, 0.038, 0), d * 0.05 + sd * 0.035 + Vector3(0, 0.05, 0)]])
			g.plain = true
			g.color("#c9b23a", Geo.PAINT)   # painted blade tips make the disc read when spinning
			g.box(Vector3.ZERO, Vector3(0.06, 0.014, 0.065), Transform3D(Basis(Vector3.UP, -a), d * (r * 0.85 - 0.03) + Vector3(0, 0.034, 0)))
	VK._mi(rn, root, "RotorMesh", g.commit(mat))

static func _gear(h, pts: Array, r: float) -> void:
	h.color(US_S, Geo.STEEL)
	for p: Vector3 in pts:
		h.tube(p + Vector3(0, r, 0), p + Vector3(0, r + 0.12, 0), 0.013, 4)
		h.tyre(p + Vector3(0, r, 0), r, r * 0.8, false, US_S, 8)

# ------------------------------------------------------------------ Harrier gunship (Apache-inspired)
static func _harrier() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.2, "recoil": 0.02, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# slab-sided angular fuselage: narrow tandem nose, wide engine section, taper into the boom
	h.color(US_D, Geo.PAINT)
	h.xloft([[0.74, K.sect(0.2, 0.25, 0.32, 0.04, 0.06, 0.04, 0.015)], [0.56, K.sect(0.14, 0.23, 0.4, 0.08, 0.11, 0.08, 0.03)],
		[0.2, K.sect(0.12, 0.24, 0.47, 0.11, 0.14, 0.1, 0.04)], [-0.3, K.sect(0.13, 0.26, 0.5, 0.12, 0.16, 0.12, 0.05)],
		[-0.52, K.sect(0.24, 0.3, 0.46, 0.07, 0.09, 0.07, 0.03)]])
	# stepped tandem canopy: faceted glass, gunner low in front, pilot raised behind
	h.color(GLASS_C, Geo.GLASS)
	h.xloft([[0.6, K.sect(0.37, 0.38, 0.41, 0.07, 0.075, 0.06, 0.012)], [0.44, K.sect(0.37, 0.4, 0.5, 0.09, 0.095, 0.065, 0.025)], [0.3, K.sect(0.37, 0.4, 0.51, 0.09, 0.095, 0.065, 0.025)]])
	h.xloft([[0.32, K.sect(0.44, 0.46, 0.5, 0.09, 0.095, 0.07, 0.015)], [0.18, K.sect(0.44, 0.47, 0.6, 0.095, 0.1, 0.07, 0.03)], [0.0, K.sect(0.44, 0.47, 0.6, 0.095, 0.1, 0.07, 0.03)], [-0.04, K.sect(0.44, 0.46, 0.56, 0.09, 0.095, 0.065, 0.02)]])
	h.color(US_S, Geo.PAINT)   # canopy frames
	for z in [0.44, 0.18]:
		h.box(Vector3(0, (0.49 if z > 0.3 else 0.59), z), Vector3(0.15, 0.012, 0.015))
	# nose sensor turret (TADS/PNVS)
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.22, 0.72), Vector3(0, 0.22, 0.82), 0.06, 8)
	h.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.03, 0.22, 0.825), Vector3(0.035, 0.035, 0.01))
	# engine nacelles with intakes and down-turned exhaust shrouds, hump + mast fairing
	for s in [-1.0, 1.0]:
		h.color(US_D, Geo.PAINT)
		h.tube(Vector3(s * 0.21, 0.45, 0.06), Vector3(s * 0.21, 0.45, -0.36), 0.07, 8, 0.075)
		h.color("#1d1f1e", Geo.DARK)
		h.tube(Vector3(s * 0.21, 0.45, 0.065), Vector3(s * 0.21, 0.45, 0.075), 0.05, 8)
		h.color(US_S, Geo.STEEL)
		h.plate(Vector3(s * 0.26, 0.42, -0.4), Vector3(0.06, 0.1, 0.12), Vector3(-20, 0, s * 25.0))
		h.color(US, Geo.PAINT)
		h.plate(Vector3(s * 0.13, 0.47, -0.15), Vector3(0.06, 0.05, 0.4), Vector3(0, 0, s * -30.0))
	h.color(US, Geo.PAINT)
	h.xloft([[0.05, K.sect(0.48, 0.52, 0.6, 0.11, 0.12, 0.08, 0.03)], [-0.38, K.sect(0.48, 0.52, 0.6, 0.11, 0.12, 0.08, 0.03)], [-0.5, K.sect(0.46, 0.48, 0.5, 0.06, 0.07, 0.05, 0.01)]])
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.6, -0.08), Vector3(0, 0.72, -0.08), 0.03, 6)
	h.color("#5a5e55", Geo.PAINT)   # mast-mounted fire-control radar
	h.lathe([Vector2(0.0, 0.0), Vector2(0.02, 0.07), Vector2(0.05, 0.09), Vector2(0.08, 0.07), Vector2(0.1, 0.0)], 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.79, -0.08)))
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.72, -0.08), Vector3(0, 0.79, -0.08), 0.015, 4)
	# tapered tail boom, swept fin, T-stabiliser, tail wheel
	h.color(US_D, Geo.PAINT)
	h.tube(Vector3(0, 0.36, -0.48), Vector3(0, 0.43, -1.32), 0.085, 8, 0.04)
	_surf(h, [Vector3(0, 0.42, -1.18), Vector3(0, 0.78, -1.34), Vector3(0, 0.78, -1.44), Vector3(0, 0.42, -1.4)], Vector3(1, 0, 0), 0.035, 0.02)
	_surf(h, [Vector3(0.02, 0.42, -1.16), Vector3(0.26, 0.42, -1.2), Vector3(0.26, 0.42, -1.3), Vector3(0.02, 0.42, -1.3)], Vector3(0, 1, 0), 0.02, 0.012)
	_surf(h, [Vector3(-0.02, 0.42, -1.16), Vector3(-0.26, 0.42, -1.2), Vector3(-0.26, 0.42, -1.3), Vector3(-0.02, 0.42, -1.3)], Vector3(0, 1, 0), 0.02, 0.012)
	# stub wings with anhedral: inner rocket pods, outer Hellfire racks, wingtip launchers
	for s in [-1.0, 1.0]:
		h.color(US, Geo.PAINT)
		_surf(h, [Vector3(s * 0.12, 0.38, 0.06), Vector3(s * 0.56, 0.35, 0.03), Vector3(s * 0.56, 0.35, -0.1), Vector3(s * 0.12, 0.38, -0.16)], Vector3(0, 1, 0), 0.035, 0.022)
		h.color(US_S, Geo.STEEL)
		for x in [0.3, 0.47]:
			h.box(Vector3(s * x, 0.32, -0.04), Vector3(0.02, 0.05, 0.1))
		h.color("#5a5e55", Geo.PAINT)
		h.tube(Vector3(s * 0.3, 0.25, 0.14), Vector3(s * 0.3, 0.25, -0.2), 0.055, 8)   # 19-shot rocket pod
		h.color("#1d1f1e", Geo.DARK)
		h.tube(Vector3(s * 0.3, 0.25, 0.141), Vector3(s * 0.3, 0.25, 0.15), 0.045, 8)
		h.color(US_S, Geo.STEEL)
		h.box(Vector3(s * 0.47, 0.285, -0.04), Vector3(0.1, 0.012, 0.3))   # Hellfire rail
		h.color("#4a4e44", Geo.PAINT)
		for k in 4:
			var mx: float = s * (0.44 + 0.06 * float(k % 2))
			var my := 0.255 - 0.05 * float(k / 2)
			h.tube(Vector3(mx, my, 0.1), Vector3(mx, my, -0.18), 0.018, 6)
			h.color("#2b2d2c", Geo.DARK)
			h.tube(Vector3(mx, my, 0.1), Vector3(mx, my, 0.13), 0.018, 6, 0.004)
			h.color("#4a4e44", Geo.PAINT)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.285, 0.45, -0.15), Vector3(0.008, 0.05, 0.3))
		h.plate(Vector3(s * 0.2, 0.365, 0.0), Vector3(0.12, 0.006, 0.12), Vector3(0, 0, s * -4.0))
	h.box(Vector3(0, 0.6, -1.38), Vector3(0.045, 0.1, 0.06))
	_gear(h, [Vector3(-0.2, 0.0, 0.3), Vector3(0.2, 0.0, 0.3)], 0.05)
	h.color(US_S, Geo.STEEL)
	h.tube(Vector3(0, 0.36, -1.2), Vector3(0, 0.05, -1.24), 0.01, 4)
	h.tyre(Vector3(0, 0.04, -1.24), 0.035, 0.03, false, US_S, 8)
	_rotor(model, root, mat, "Rotor", Vector3(0, 0.72, -0.08), 1.5, 4)
	_rotor(model, root, mat, "TailRotor", Vector3(0.05, 0.62, -1.38), 0.36, 4, true)
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.12, 0.5))
	var t = K.new()
	t.color(US_S, Geo.STEEL)
	t.cyl(0.06, 0.05, 0.07, 8, Transform3D.IDENTITY)
	t.cbox(Vector3(0, -0.02, 0.03), Vector3(0.07, 0.05, 0.1), 0.012)
	VK._mi(piv, root, "Turret", t.commit(mat))
	var b = _barrel(piv, root, mat, Vector3(0, -0.02, 0.04), func(b) -> void:
		b.color(US_S, Geo.STEEL)
		b.gun(0.0, 0.3, 0.017, 0.013, -1.0, false, 6)
		b.tube(Vector3(0, 0, 0.26), Vector3(0, 0, 0.31), 0.02, 6))
	U()._vfinish(root, model, h, mat, "harrier", [t, b], 1.2)

# ------------------------------------------------------------------ Wraith fighter (F-22-inspired)
static func _wraith() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 0.85, "bar_height": 1.0, "recoil": 0.0, "wreck_s": 6.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# chined stealth fuselage: flat belly, sharp chine line, sloped sides
	h.color(AIR, Geo.PAINT)
	h.xloft([[0.98, K.sect(0.225, 0.235, 0.25, 0.004, 0.012, 0.004, 0.0)], [0.62, K.sect(0.17, 0.22, 0.3, 0.04, 0.11, 0.05, 0.015)],
		[0.22, K.sect(0.14, 0.21, 0.32, 0.12, 0.25, 0.11, 0.03)], [-0.5, K.sect(0.14, 0.2, 0.3, 0.16, 0.26, 0.14, 0.03)],
		[-0.84, K.sect(0.15, 0.2, 0.27, 0.14, 0.2, 0.12, 0.02)]])
	# bubble canopy (gold tint) with a frame line
	h.color("#a07a2a", Geo.GLASS)
	h.xloft([[0.66, K.sect(0.29, 0.295, 0.305, 0.025, 0.03, 0.025, 0.004)], [0.5, K.sect(0.28, 0.3, 0.37, 0.045, 0.052, 0.035, 0.016)],
		[0.32, K.sect(0.28, 0.3, 0.36, 0.045, 0.05, 0.034, 0.016)], [0.18, K.sect(0.29, 0.3, 0.31, 0.02, 0.025, 0.02, 0.004)]])
	# caret intakes on the chines
	for s in [-1.0, 1.0]:
		h.color(AIR_D, Geo.PAINT)
		h.xloft([[0.32, K.sect(0.14, 0.18, 0.25, 0.04, 0.05, 0.04, 0.012)], [0.0, K.sect(0.14, 0.18, 0.27, 0.05, 0.06, 0.05, 0.015)]], Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(s * 0.2, 0, 0)))
		h.color("#1d1f1e", Geo.DARK)
		h.plate(Vector3(s * 0.215, 0.2, 0.325), Vector3(0.07, 0.08, 0.008), Vector3(0, s * 20.0, s * 14.0))
	# diamond wings (swept LE, forward-swept TE), diamond tailplanes, canted twin fins
	h.color(AIR_D, Geo.PAINT)
	for s in [-1.0, 1.0]:
		_surf(h, [Vector3(s * 0.2, 0.19, 0.22), Vector3(s * 0.84, 0.18, -0.46), Vector3(s * 0.84, 0.18, -0.6), Vector3(s * 0.2, 0.19, -0.72)], Vector3(0, 1, 0), 0.05, 0.012)
		_surf(h, [Vector3(s * 0.15, 0.2, -0.62), Vector3(s * 0.5, 0.2, -0.88), Vector3(s * 0.5, 0.2, -1.0), Vector3(s * 0.15, 0.2, -0.98)], Vector3(0, 1, 0), 0.025, 0.008)
		var fb := Basis(Vector3.FORWARD, s * deg_to_rad(28.0))
		_surf(h, [Vector3(0, 0, -0.5), Vector3(0, 0.34, -0.78), Vector3(0, 0.34, -0.9), Vector3(0, 0, -0.86)], Vector3(1, 0, 0), 0.02, 0.008, Transform3D(fb, Vector3(s * 0.16, 0.27, 0)))
		h.color("#ffffff", Geo.TEAM)
		h.box(Vector3(s * 0.56, 0.205, -0.42), Vector3(0.16, 0.012, 0.08))
		h.color(AIR_D, Geo.PAINT)
	# 2D thrust-vectoring nozzles with afterburner glow
	for s in [-1.0, 1.0]:
		h.color(US_S, Geo.STEEL)
		h.xloft([[-0.82, K.sect(0.15, 0.18, 0.26, 0.06, 0.07, 0.06, 0.02)], [-0.98, K.sect(0.17, 0.19, 0.24, 0.06, 0.065, 0.06, 0.012)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.085, 0, 0)))
		h.color("#ff7a2a", Geo.LAMP)
		h.box(Vector3(s * 0.085, 0.205, -0.985), Vector3(0.1, 0.05, 0.01))
	h.color("#ffffff", Geo.TEAM)
	h.box(Vector3(0, 0.32, -0.2), Vector3(0.06, 0.008, 0.3))
	_gear(h, [Vector3(0, 0.0, 0.5), Vector3(-0.18, 0.0, -0.15), Vector3(0.18, 0.0, -0.15)], 0.04)
	U()._vfinish(root, model, h, mat, "wraith", [], 1.0)

# ------------------------------------------------------------------ Thunderlance bomber (B-1-inspired)
static func _thunderlance() -> void:
	var mat: Material = load(VK.MAT_PATH)
	var root := VK._root({"selection_radius": 1.2, "bar_height": 1.2, "recoil": 0.0, "wreck_s": 7.0})
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	# long blended fuselage with a drooped nose and a wide wing glove
	h.color(BOMB, Geo.PAINT)
	h.xloft([[1.44, K.sect(0.25, 0.27, 0.29, 0.01, 0.02, 0.01, 0.0)], [1.12, K.sect(0.17, 0.27, 0.4, 0.07, 0.12, 0.07, 0.04)],
		[0.7, K.sect(0.15, 0.28, 0.45, 0.1, 0.17, 0.1, 0.05)], [0.25, K.sect(0.14, 0.27, 0.44, 0.2, 0.36, 0.14, 0.06)],
		[-0.45, K.sect(0.14, 0.27, 0.42, 0.2, 0.33, 0.13, 0.06)], [-0.95, K.sect(0.2, 0.28, 0.38, 0.08, 0.13, 0.08, 0.04)],
		[-1.28, K.sect(0.26, 0.29, 0.34, 0.03, 0.05, 0.03, 0.015)]])
	# cockpit glazing on the nose shoulders + spine
	h.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		h.plate(Vector3(s * 0.065, 0.4, 1.08), Vector3(0.006, 0.05, 0.12), Vector3(-25, s * -8.0, s * -40.0))
	h.plate(Vector3(0, 0.425, 1.05), Vector3(0.1, 0.006, 0.08), Vector3(-25, 0, 0))
	h.color(AIR_D, Geo.PAINT)
	h.xloft([[0.95, K.sect(0.4, 0.42, 0.46, 0.04, 0.05, 0.035, 0.012)], [-0.9, K.sect(0.36, 0.38, 0.43, 0.04, 0.05, 0.035, 0.012)]])   # dorsal spine
	# variable-sweep wings (mid sweep) from the glove
	for s in [-1.0, 1.0]:
		h.color(BOMB, Geo.PAINT)
		_surf(h, [Vector3(s * 0.34, 0.28, 0.12), Vector3(s * 1.3, 0.26, -0.62), Vector3(s * 1.3, 0.26, -0.78), Vector3(s * 0.34, 0.28, -0.3)], Vector3(0, 1, 0), 0.05, 0.012)
		_surf(h, [Vector3(s * 0.04, 0.33, -0.98), Vector3(s * 0.62, 0.33, -1.16), Vector3(s * 0.62, 0.33, -1.28), Vector3(s * 0.04, 0.33, -1.24)], Vector3(0, 1, 0), 0.03, 0.01)
		# twin-engine nacelle under the glove: chamfered box, splitter intakes, nozzles
		h.color(AIR_D, Geo.PAINT)
		h.xloft([[0.05, K.sect(0.06, 0.1, 0.18, 0.13, 0.14, 0.12, 0.03)], [-0.55, K.sect(0.07, 0.11, 0.19, 0.13, 0.14, 0.12, 0.03)]], Transform3D(Basis.IDENTITY, Vector3(s * 0.32, 0, 0)))
		h.color("#1d1f1e", Geo.DARK)
		h.box(Vector3(s * 0.32, 0.12, 0.055), Vector3(0.22, 0.08, 0.01))
		for k in 2:
			var x: float = s * (0.255 + 0.13 * float(k))
			h.color(US_S, Geo.STEEL)
			h.tube(Vector3(x, 0.125, -0.55), Vector3(x, 0.125, -0.64), 0.05, 8, 0.042)
			h.color("#ff7a2a", Geo.LAMP)
			h.tube(Vector3(x, 0.125, -0.64), Vector3(x, 0.125, -0.645), 0.035, 8)
	# swept fin with a fairing
	h.color(BOMB, Geo.PAINT)
	_surf(h, [Vector3(0, 0.38, -0.7), Vector3(0, 0.86, -1.08), Vector3(0, 0.86, -1.22), Vector3(0, 0.38, -1.3)], Vector3(1, 0, 0), 0.04, 0.02)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.88, 0.285, -0.42), Vector3(0.22, 0.012, 0.1))
	h.plate(Vector3(0, 0.78, -1.1), Vector3(0.045, 0.08, 0.16), Vector3(0, 0, 0))
	_gear(h, [Vector3(0, 0.0, 0.85), Vector3(-0.22, 0.0, -0.3), Vector3(0.22, 0.0, -0.3)], 0.05)
	U()._vfinish(root, model, h, mat, "thunderlance", [], 1.2)
