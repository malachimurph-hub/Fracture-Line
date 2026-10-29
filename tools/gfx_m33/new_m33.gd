extends RefCounted
## M3.3 Phase 2 models (tool-time only, original procedural art; no brand names anywhere):
##   us_drop_zone     - Data Center, 4 x 4: two server halls, roof chillers, generator row, substation
##   us_reactor       - Nuclear Power Plant: containment dome, turbine hall, two cooling towers (steam)
##   tpla_gas_plant   - Iran Gas Turbine Plant (new): turbine hall, twin exhaust stacks, gas train
##   tpla_cc_plant    - Iran Combined-Cycle Gas Plant, 4 x 4: two turbine halls, heat-recovery boilers
##                      with tall stacks, steam-turbine hall, air-cooled condenser, pipework
##   tpla_bazaar      - Iran Oil Derrick, 2 x 2: nodding pumpjack, drilling mast, tanks, manifold
##   eu_exchange      - Germany Automotive Plant: sawtooth assembly hall, paint shop, finished-car lot
##   ecc_black_market - Russia Minerals Mining: giant bucket-wheel excavator (wheel turns)
##   ecc_bunker       - Russia Missile Silo: in-ground launcher, hatch doors open when it fires
## Animated parts are separate nodes with meta "anim" (BuildingView animates them):
##   "spin"  rotate about local X at meta "speed" rad/s     "nod"  rock about local X
##   "door"  hinge open about local Z by meta "open_deg" while firing (on_fire)
## Smoke / steam come from Marker3D "Stack*" (WorldView stack puffs).
##   tools/gfx_m33/build_m33.sh [names...]
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const UM := preload("res://tools/gfx_m30/us_m30.gd")
const Y0 := 0.08
const GLASS_C := "#2a3a46"
const LIT := "#ffd98a"
const STEEL := "#4a4e4c"
const STEEL_L := "#8d9290"

static func U():
	return load("res://tools/gfx_m7/us_m7.gd")

static func jobs() -> Dictionary:
	return {
		"us_drop_zone": func() -> void: _make("drop_zone", Vector2(4, 4), 1.0, "us", _data_center4),
		"us_reactor": func() -> void: _make("reactor", Vector2(3, 3), 2.4, "us", _nuclear, Callable(), [Vector3(0.78, 2.42, -0.62), Vector3(-0.42, 2.42, -0.82)]),
		"tpla_gas_plant": func() -> void: _make("gas_plant", Vector2(3, 3), 1.9, "tpla", _gas_plant, Callable(), [Vector3(0.95, 1.92, -0.85), Vector3(0.45, 1.92, -0.85)]),
		"tpla_cc_plant": func() -> void: _make("cc_plant", Vector2(4, 4), 2.6, "tpla", _cc_plant, _cc_fans, [Vector3(-0.95, 2.62, -1.2), Vector3(0.15, 2.62, -1.2)]),
		"tpla_bazaar": func() -> void: _make("bazaar", Vector2(2, 2), 1.5, "tpla", _derrick, _pumpjack),
		"eu_exchange": func() -> void: _make("exchange", Vector2(3, 3), 1.0, "eu", _auto_plant, Callable(), [Vector3(1.05, 1.15, -0.95)]),
		"ecc_black_market": func() -> void: _make("black_market", Vector2(3, 3), 2.0, "ecc", _excavator, _bucket_wheel),
		"ecc_bunker": func() -> void: _make("bunker", Vector2(2, 2), 0.45, "ecc", _silo, _silo_doors),
	}

# ------------------------------------------------------------------ assembly
## us_m7._make plus: an optional parts_fn(model, root, mat) for animated nodes, and Stack markers.
static func _make(short: String, fp: Vector2, top: float, fac: String, hull_fn: Callable, parts_fn: Callable = Callable(), stacks: Array = []) -> void:
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
	var f = K.new()
	U()._foundation(f, fp)
	VK._mi(model, root, "Foundation", f.commit(mat))
	var h = K.new()
	hull_fn.call(h)
	VK._mi(model, root, "Hull", h.commit(mat))
	var extra := 0
	if parts_fn.is_valid():
		extra = parts_fn.call(model, root, mat)
	var tp := fac == "tpla"
	var s = B4._scaffold(fp, top * 0.8)
	VK._mi(model, root, "Scaffold", s.commit(mat)).visible = false
	var l = B4._damage_light(fp, tp)
	VK._mi(model, root, "DamageLight", l.commit(mat)).visible = false
	var hv = B4._damage_heavy(fp, top, tp)
	VK._mi(model, root, "DamageHeavy", hv.commit(mat)).visible = false
	var rb = B4._rubble(fp, tp)
	VK._mi(model, root, "Rubble", rb.commit(mat)).visible = false
	var hx := fp.x * 0.3
	var hz := fp.y * 0.3
	var i := 0
	for p in [Vector3(-hx, top * 0.6, hz * 0.5), Vector3(hx, top * 0.5, -hz), Vector3(0, top * 0.3, hz)]:
		var mk := Marker3D.new()
		mk.name = "Fire%d" % i
		mk.position = p
		model.add_child(mk)
		mk.owner = root
		i += 1
	i = 0
	for p in stacks:
		var sk := Marker3D.new()
		sk.name = ("StackSteam%d" if short == "reactor" else "Stack%d") % i
		sk.position = p
		model.add_child(sk)
		sk.owner = root
		i += 1
	print("  %s_%s: hull %d + foundation %d + parts %d tris (LOD0)" % [fac, short, h.tris, f.tris, extra])
	var path := "res://view/buildings/%s/%s.tscn" % [fac, short]
	VK._save(root, path, top + 0.15)
	U().wrote.append(path)

static func _part(model: Node3D, root: Node3D, mat: Material, name: String, g, pos: Vector3, anim: String, meta := {}) -> MeshInstance3D:
	var mi := VK._mi(model, root, name, g.commit(mat), pos)
	mi.set_meta("anim", anim)
	for k in meta:
		mi.set_meta(k, meta[k])
	return mi

static func _fence(g, hx: float, hz: float, gap_z := 99.0) -> void:
	g.color(STEEL_L, Geo.STEEL)
	var pts := [Vector3(-hx, Y0, -hz), Vector3(hx, Y0, -hz), Vector3(hx, Y0, hz), Vector3(-hx, Y0, hz), Vector3(-hx, Y0, -hz)]
	for i in 4:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 0.32))
		for k in n:
			var p := a.lerp(b, float(k) / float(n))
			if absf(p.z - hz) < 0.01 and absf(p.x) < gap_z:
				continue
			g.tube(p, p + Vector3(0, 0.2, 0), 0.006, 3)
		if absf(a.z - hz) < 0.01 and absf(b.z - hz) < 0.01 and gap_z < 90.0:
			for sx in [-1.0, 1.0]:
				var e0 := Vector3(sx * hx, 0, hz)
				var e1 := Vector3(sx * gap_z, 0, hz)
				for y in [0.1, 0.19]:
					g.box((e0 + e1) * 0.5 + Vector3(0, Y0 + y, 0), Vector3(absf(e1.x - e0.x), 0.006, 0.006))
			continue
		for y in [0.1, 0.19]:
			g.tube(a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.004, 3)

# ================================================================== USA Data Center (4 x 4)
## Malachi: more cash, more power, bigger footprint. Hyperscale-style campus: two long white
## server halls with louvred walls and rows of roof chillers (spinning fans), a backup
## generator row with stacks and a fuel tank, a fenced substation with transformers, a
## gatehouse, team bands and the rooftop aviation lights.
const DC_W := "#d9dbd9"
const DC_W2 := "#c3c6c4"
const DC_B := "#2f5d8c"
static func _data_center4(g) -> void:
	# apron + internal road
	g.color("#8f8b80", Geo.CONCRETE)
	g.box(Vector3(0, Y0 + 0.004, 1.55), Vector3(3.7, 0.006, 0.5))
	g.color("#e8d34a", Geo.PAINT)
	g.box(Vector3(0, Y0 + 0.009, 1.55), Vector3(3.5, 0.003, 0.02))
	for hall in [[Vector3(-0.35, 0, -0.9), Vector2(3.0, 1.15), 0.62, 0], [Vector3(-0.6, 0, 0.62), Vector2(2.5, 0.95), 0.52, 1]]:
		var c: Vector3 = hall[0]
		var sz: Vector2 = hall[1]
		var hh: float = hall[2]
		g.color(DC_W, Geo.CONCRETE)
		g.cbox(Vector3(c.x, Y0 + hh * 0.5, c.z), Vector3(sz.x, hh, sz.y), 0.02)
		g.color(DC_W2, Geo.CONCRETE)
		g.cbox(Vector3(c.x, Y0 + hh + 0.02, c.z), Vector3(sz.x - 0.04, 0.04, sz.y - 0.04), 0.01)   # roof
		g.color(DC_B, Geo.PAINT)
		g.box(Vector3(c.x, Y0 + hh - 0.06, c.z + sz.y * 0.5 + 0.003), Vector3(sz.x, 0.05, 0.006))   # accent band
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(c.x - sz.x * 0.32, Y0 + hh - 0.15, c.z + sz.y * 0.5 + 0.004), Vector3(0.5, 0.06, 0.006))
		g.color("#5d6163", Geo.STEEL)
		var nv := int(sz.x / 0.36)
		for i in nv:   # louvre panels along the long face
			g.vent(Vector3(c.x - sz.x * 0.5 + 0.2 + i * 0.36, Y0 + hh * 0.42, c.z + sz.y * 0.5 + 0.004), 0.26, hh * 0.45, 6)
		g.vent(Vector3(c.x + sz.x * 0.5 + 0.004, Y0 + hh * 0.45, c.z), sz.y * 0.7, hh * 0.45, 6, 90)
		# roof chiller rows (two fans each)
		var nc := int((sz.x - 0.2) / 0.5)
		for i in nc:
			var p := Vector3(c.x - sz.x * 0.5 + 0.35 + i * 0.5, Y0 + hh + 0.04, c.z)
			g.color("#a3a7a1", Geo.STEEL)
			g.cbox(p + Vector3(0, 0.05, 0), Vector3(0.4, 0.1, sz.y * 0.62), 0.01)
			g.fan(p + Vector3(0, 0.1, -sz.y * 0.15), 0.1, 5, 6.0 + i * 0.7)
			g.fan(p + Vector3(0, 0.1, sz.y * 0.15), 0.1, 5, 8.0 - i * 0.5)
		# entrance with lit canopy
		g.color(GLASS_C, Geo.GLASS)
		g.box(Vector3(c.x + sz.x * 0.36, Y0 + 0.13, c.z + sz.y * 0.5 + 0.005), Vector3(0.28, 0.22, 0.006))
		g.color(LIT, Geo.LAMP)
		g.box(Vector3(c.x + sz.x * 0.36, Y0 + 0.27, c.z + sz.y * 0.5 + 0.03), Vector3(0.34, 0.015, 0.05))
	# cable tray bridge between the halls
	g.color(STEEL, Geo.STEEL)
	g.box(Vector3(-0.9, Y0 + 0.42, -0.1), Vector3(0.08, 0.03, 0.44))
	g.box(Vector3(0.2, Y0 + 0.42, -0.1), Vector3(0.08, 0.03, 0.44))
	# backup generators along the east side + fuel tank
	for i in 4:
		var p := Vector3(1.55, Y0, -1.45 + i * 0.42)
		g.color("#cbc6b8", Geo.PAINT)
		g.cbox(p + Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.34), 0.012)
		g.color("#2b2d2c", Geo.DARK)
		g.vent(p + Vector3(-0.151, 0.1, 0), 0.26, 0.1, 4, 90)
		g.color(STEEL, Geo.STEEL)
		g.tube(p + Vector3(0.06, 0.2, 0.08), p + Vector3(0.06, 0.42, 0.08), 0.018, 6)
	g.color("#e4e2da", Geo.STEEL)
	g.tube(Vector3(1.05, Y0 + 0.11, 0.55), Vector3(1.05, Y0 + 0.11, 1.15), 0.11, 12)
	g.color(STEEL, Geo.STEEL)
	for z in [0.62, 1.08]:
		g.box(Vector3(1.05, Y0 + 0.02, z), Vector3(0.18, 0.04, 0.04))
	# substation: fenced transformers + insulator gantry
	for i in 3:
		var p := Vector3(0.95 + i * 0.32, Y0, 1.55 - 0.32)
		g.color("#7a7f7a", Geo.STEEL)
		g.cbox(p + Vector3(0, 0.09, 0), Vector3(0.22, 0.18, 0.18), 0.01)
		g.color("#5d6163", Geo.STEEL)
		for k in 3:
			g.box(p + Vector3(-0.08 + k * 0.08, 0.09, 0.095), Vector3(0.012, 0.15, 0.012))
		g.insulator(p + Vector3(0, 0.18, 0), 0.08)
	g.color(STEEL_L, Geo.STEEL)
	g.tube(Vector3(0.82, Y0, 1.05), Vector3(0.82, Y0 + 0.45, 1.05), 0.01, 4)
	g.tube(Vector3(1.75, Y0, 1.05), Vector3(1.75, Y0 + 0.45, 1.05), 0.01, 4)
	g.tube(Vector3(0.82, Y0 + 0.45, 1.05), Vector3(1.75, Y0 + 0.45, 1.05), 0.01, 4)
	# gatehouse + barrier
	g.color(DC_W, Geo.CONCRETE)
	g.cbox(Vector3(-1.55, Y0 + 0.09, 1.55), Vector3(0.3, 0.18, 0.26), 0.01)
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(-1.55, Y0 + 0.12, 1.682), Vector3(0.22, 0.07, 0.005))
	g.color("#d84a3a", Geo.PAINT)
	g.box(Vector3(-1.15, Y0 + 0.12, 1.55), Vector3(0.5, 0.018, 0.018))
	# roof comms
	g.color(STEEL, Geo.STEEL)
	g.tube(Vector3(-1.6, Y0 + 0.62, -1.2), Vector3(-1.6, Y0 + 1.0, -1.2), 0.01, 4)
	g.dish(Vector3(-1.3, Y0 + 0.75, -0.6), 0.12, 30, 0.0)
	_fence_campus(g)
	UM._roof_lights(g, UM._corners(-0.35, -0.9, 1.45, 0.52, Y0 + 0.66), Vector3(-0.35, Y0 + 0.82, -0.9))

static func _fence_campus(g) -> void:
	_fence(g, 1.88, 1.88, 0.9)

# ================================================================== USA Nuclear Power Plant
## +30 % output and price (M3.3): bigger, with the containment dome, a turbine hall and two
## hyperbolic cooling towers whose steam plumes come from the Stack markers.
const NP_W := "#e2e2dc"
const NP_W2 := "#c9cac4"
const NP_C := "#bdb8aa"
static func _tw_r(r: float, t: float) -> float:
	# hyperboloid: narrow waist at ~70 % height, flared base and lip
	var w := t - 0.7
	return r * (0.62 + 0.38 * (w * w) / (0.49 if w < 0.0 else 0.09))

static func _ring(g, r: float, y: float, hgt: float, at: Vector3, seg := 18) -> void:
	g.lathe([[y, r], [y + hgt, r]], seg, Transform3D(Basis.IDENTITY, Vector3(at.x, 0, at.z)), false, false)

static func _tower(g, c: Vector3, r: float, hgt: float) -> void:
	var prof := []
	for k in 13:
		var t := float(k) / 12.0
		prof.append([c.y + hgt * t, _tw_r(r, t)])
	g.color(NP_C, Geo.CONCRETE)
	g.lathe(prof, 20, Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.z)), false, false)
	g.color("#2e302f", Geo.DARK)   # dark throat seen over the lip
	g.cyl(_tw_r(r, 0.9) * 0.98, _tw_r(r, 0.9) * 0.98, 0.01, 20, Transform3D(Basis.IDENTITY, Vector3(c.x, c.y + hgt * 0.9, c.z)))
	g.color("#9e998c", Geo.CONCRETE)   # stained band at the base
	_ring(g, _tw_r(r, 0.0) + 0.004, c.y, 0.08, c, 20)
	g.color("#d8503c", Geo.PAINT)   # red aviation band just under the lip
	_ring(g, _tw_r(r, 0.9) + 0.004, c.y + hgt * 0.885, hgt * 0.03, c, 20)

static func _nuclear(g) -> void:
	_tower(g, Vector3(0.78, Y0, -0.62), 0.6, 2.32)
	_tower(g, Vector3(-0.42, Y0, -0.82), 0.52, 2.32)
	# containment: cylinder + dome
	var dc := Vector3(-0.72, Y0, 0.6)
	g.color(NP_W, Geo.CONCRETE)
	g.cyl(0.5, 0.5, 0.55, 20, Transform3D(Basis.IDENTITY, dc + Vector3(0, 0.275, 0)))
	g.dome(0.5, 0.34, 4, 20, Transform3D(Basis.IDENTITY, dc + Vector3(0, 0.55, 0)))
	g.color(NP_W2, Geo.CONCRETE)
	g.band(0.505, Y0 + 0.5, 0.03, 0.004, 20, Transform3D(Basis.IDENTITY, Vector3(dc.x, 0, dc.z)))
	g.color("#ffffff", Geo.TEAM)
	g.band(0.506, Y0 + 0.36, 0.06, 0.004, 20, Transform3D(Basis.IDENTITY, Vector3(dc.x, 0, dc.z)))
	g.color(STEEL, Geo.STEEL)
	g.ladder(dc + Vector3(0.0, 0.0, 0.51), 0.55, Vector3.RIGHT)
	# turbine hall + switchyard
	g.color(NP_W, Geo.CONCRETE)
	g.cbox(Vector3(0.55, Y0 + 0.27, 0.62), Vector3(1.1, 0.54, 0.62), 0.02)
	g.color(NP_W2, Geo.CONCRETE)
	g.prism_x([Vector2(0.3, Y0 + 0.54), Vector2(0.94, Y0 + 0.54), Vector2(0.62, Y0 + 0.66)], 0.0, 1.1)
	g.color("#3a5f8a", Geo.PAINT)
	g.box(Vector3(0.55, Y0 + 0.47, 0.933), Vector3(1.1, 0.05, 0.006))
	g.color(GLASS_C, Geo.GLASS)
	UM._win_grid(g, Vector3(0.55, Y0 + 0.28, 0.934), 0.9, 0.18, 8, 1, UM._face_t(0, Vector3.ZERO), 33, 0.35)
	g.color(STEEL, Geo.STEEL)   # reactor-to-hall steam pipes
	g.pipe([Vector3(-0.25, Y0 + 0.35, 0.62), Vector3(0.0, Y0 + 0.35, 0.62)], 0.04)
	g.pipe([Vector3(0.55, Y0 + 0.2, 0.3), Vector3(0.55, Y0 + 0.2, 0.0), Vector3(0.62, Y0 + 0.2, -0.05)], 0.035)
	for i in 3:
		var p := Vector3(1.25, Y0, 0.15 + i * 0.36)
		g.color("#7a7f7a", Geo.STEEL)
		g.cbox(p + Vector3(0, 0.09, 0), Vector3(0.2, 0.18, 0.22), 0.01)
		g.insulator(p + Vector3(0, 0.18, 0), 0.07)
	g.color("#e8d34a", Geo.PAINT)
	g.hazard(Vector3(-0.72, Y0 + 0.01, 1.15), 0.7, 0.05, 6)
	UM._roof_lights(g, [Vector3(0.78, Y0 + 2.33, -0.02), Vector3(-0.42, Y0 + 2.33, -0.3), Vector3(-0.72, Y0 + 0.9, 0.6)])

# ================================================================== Iran Gas Turbine Plant
## Malachi: Iran gets a power system, natural gas, cheaper and weaker than nuclear; Iran is "a
## little more advanced" than the GLA look. Clean sand-stone turbine hall with a turquoise tile
## band, two tall exhaust stacks over the heat-recovery boilers, inlet filter houses, a yellow
## gas pipeline with valves and a pig launcher, transformers. Exhaust haze from the Stacks.
const IR_S := "#d9c9a6"
const IR_S2 := "#c4b28c"
const IR_T := "#2f8f8a"
const IR_T2 := "#5ab7b0"
const IR_G := "#d8b23a"
static func _ir_band(g, c: Vector3, w: float, yaw: float) -> void:
	# turquoise tile band with a darker pattern of diamonds (Persian tilework, plain geometry)
	var t := UM._face_t(yaw, c)
	g.color(IR_T, Geo.PAINT)
	g.box(Vector3.ZERO, Vector3(w, 0.06, 0.006), t)
	g.color(IR_T2, Geo.PAINT)
	var n := int(w / 0.09)
	for i in n:
		g.rbox(t * Vector3(-w * 0.5 + 0.045 + i * 0.09, 0, 0.004), Vector3(0.026, 0.026, 0.004), Vector3(0, yaw, 45))

static func _gas_plant(g) -> void:
	# turbine hall
	g.color(IR_S, Geo.CONCRETE)
	g.cbox(Vector3(-0.45, Y0 + 0.3, 0.35), Vector3(1.7, 0.6, 0.95), 0.02)
	g.color(IR_S2, Geo.CONCRETE)
	g.cbox(Vector3(-0.45, Y0 + 0.62, 0.35), Vector3(1.74, 0.05, 0.99), 0.01)
	_ir_band(g, Vector3(-0.45, Y0 + 0.5, 0.826), 1.7, 0)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-1.0, Y0 + 0.36, 0.827), Vector3(0.4, 0.05, 0.006))
	g.color(GLASS_C, Geo.GLASS)
	UM._win_grid(g, Vector3(-0.3, Y0 + 0.3, 0.828), 1.1, 0.14, 7, 1, UM._face_t(0, Vector3.ZERO), 71, 0.45)
	g.color("#6a6e6c", Geo.STEEL)
	g.rollup(Vector3(-1.05, Y0 + 0.16, 0.828), 0.32, 0.3)
	# arched entrance (Iranian iwan motif) on the hall's end wall
	g.color(IR_S2, Geo.CONCRETE)
	g.cbox(Vector3(0.43, Y0 + 0.28, 0.6), Vector3(0.06, 0.56, 0.36), 0.01)
	g.color(IR_T, Geo.PAINT)
	g.box(Vector3(0.465, Y0 + 0.3, 0.6), Vector3(0.006, 0.36, 0.2))
	# roof: intake filter houses + vents
	for i in 3:
		var p := Vector3(-1.0 + i * 0.5, Y0 + 0.645, 0.25)
		g.color("#b9bcb8", Geo.STEEL)
		g.cbox(p + Vector3(0, 0.09, 0), Vector3(0.34, 0.18, 0.4), 0.01)
		g.color("#5d6163", Geo.STEEL)
		g.vent(p + Vector3(0, 0.09, 0.201), 0.28, 0.12, 5)
	# heat recovery boilers + two exhaust stacks (behind the hall)
	for k in 2:
		var x := 0.95 - k * 0.5
		g.color("#a7aba7", Geo.STEEL)
		g.cbox(Vector3(x, Y0 + 0.4, -0.45), Vector3(0.36, 0.8, 0.6), 0.015)
		g.color("#7f8481", Geo.STEEL)
		for y in [0.25, 0.55]:
			g.box(Vector3(x, Y0 + y, -0.144), Vector3(0.37, 0.02, 0.01))
		g.color("#c9ccc8", Geo.STEEL)
		g.cyl(0.11, 0.09, 1.1, 12, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.8 + 0.55, -0.85 + 0.0)))
		g.color("#d8503c", Geo.PAINT)
		g.band(0.092, Y0 + 1.75, 0.05, 0.004, 12, Transform3D(Basis.IDENTITY, Vector3(x, 0, -0.85)))
		g.color(STEEL, Geo.STEEL)
		g.box(Vector3(x, Y0 + 0.7, -0.78), Vector3(0.18, 0.18, 0.16))   # breeching duct
		g.rail_ring(0.13, Y0 + 1.3, 10, 0.06, Transform3D(Basis.IDENTITY, Vector3(x, 0, -0.85)))
		g.ladder(Vector3(x + 0.11, Y0 + 0.8, -0.85), 0.9, Vector3.BACK)
	# gas pipeline (yellow) from the property edge, valves, pig launcher
	g.color(IR_G, Geo.PAINT)
	g.pipe([Vector3(-1.45, Y0 + 0.08, -0.85), Vector3(-0.2, Y0 + 0.08, -0.85), Vector3(-0.2, Y0 + 0.08, -0.25), Vector3(0.25, Y0 + 0.08, -0.25)], 0.04)
	g.tube(Vector3(-1.2, Y0 + 0.08, -1.05), Vector3(-1.2, Y0 + 0.08, -0.85), 0.03, 8)
	g.color("#c0392b", Geo.PAINT)
	for x in [-1.0, -0.6]:
		g.cyl(0.035, 0.035, 0.04, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.15, -0.85)))
		g.tube(Vector3(x, Y0 + 0.12, -0.85), Vector3(x, Y0 + 0.2, -0.85), 0.008, 4)
	g.color(IR_G, Geo.PAINT)
	g.tube(Vector3(-1.35, Y0 + 0.12, -0.55), Vector3(-0.85, Y0 + 0.12, -0.55), 0.07, 10)
	g.color(STEEL, Geo.STEEL)
	for x in [-1.25, -0.95]:
		g.box(Vector3(x, Y0 + 0.03, -0.55), Vector3(0.05, 0.06, 0.12))
	# transformers
	for i in 2:
		var p := Vector3(0.95, Y0, 0.45 + i * 0.4)
		g.color("#7a7f7a", Geo.STEEL)
		g.cbox(p + Vector3(0, 0.1, 0), Vector3(0.24, 0.2, 0.26), 0.01)
		g.color("#5d6163", Geo.STEEL)
		for k in 3:
			g.box(p + Vector3(0.125, 0.1, -0.08 + k * 0.08), Vector3(0.012, 0.16, 0.012))
		g.insulator(p + Vector3(0, 0.2, 0), 0.08)
	_fence(g, 1.4, 1.4, 0.35)
	UM._roof_lights(g, [Vector3(0.95, Y0 + 1.9, -0.85), Vector3(0.45, Y0 + 1.9, -0.85)])

# ================================================================== Iran Combined-Cycle Gas Plant (4 x 4)
## Malachi 2026-10-29: Iran's advanced natural-gas power. Two gas-turbine halls (front), each
## feeding a tall heat-recovery steam generator with its own exhaust stack (back), a steam
## turbine hall between them, an air-cooled condenser bank on steel legs (fans spin) on the
## east side, steam and gas pipework, a switchyard and a fence - same clean Iran finish.
const CC_X := [-0.95, 0.15]
static func _cc_plant(g) -> void:
	for k in 2:
		var x: float = CC_X[k]
		# gas turbine hall
		g.color(IR_S, Geo.CONCRETE)
		g.cbox(Vector3(x, Y0 + 0.28, 0.85), Vector3(0.92, 0.56, 0.8), 0.02)
		g.color(IR_S2, Geo.CONCRETE)
		g.cbox(Vector3(x, Y0 + 0.58, 0.85), Vector3(0.96, 0.05, 0.84), 0.01)
		_ir_band(g, Vector3(x, Y0 + 0.47, 1.256), 0.92, 0)
		g.color(GLASS_C, Geo.GLASS)
		UM._win_grid(g, Vector3(x + 0.12, Y0 + 0.27, 1.258), 0.6, 0.13, 5, 1, UM._face_t(0, Vector3.ZERO), 37 + k * 11, 0.45)
		g.color("#6a6e6c", Geo.STEEL)
		g.rollup(Vector3(x - 0.33, Y0 + 0.15, 1.258), 0.22, 0.28)
		# intake filter house on the roof
		g.color("#b9bcb8", Geo.STEEL)
		g.cbox(Vector3(x, Y0 + 0.72, 0.95), Vector3(0.5, 0.24, 0.42), 0.01)
		g.color("#5d6163", Geo.STEEL)
		g.vent(Vector3(x, Y0 + 0.72, 1.161), 0.42, 0.16, 6)
		# transition duct into the boiler
		g.color("#8f9490", Geo.STEEL)
		g.cbox(Vector3(x, Y0 + 0.42, 0.28), Vector3(0.5, 0.44, 0.36), 0.015)
		# heat-recovery steam generator: tall casing with stiffener bands and platforms
		g.color("#a7aba7", Geo.STEEL)
		g.cbox(Vector3(x, Y0 + 0.65, -0.38), Vector3(0.62, 1.3, 0.95), 0.02)
		g.color("#7f8481", Geo.STEEL)
		for y in [0.3, 0.62, 0.94, 1.22]:
			g.box(Vector3(x, Y0 + y, -0.38), Vector3(0.635, 0.025, 0.965))
		g.color(IR_S2, Geo.PAINT)
		g.cbox(Vector3(x, Y0 + 1.33, -0.38), Vector3(0.66, 0.05, 0.99), 0.01)
		g.color(STEEL, Geo.STEEL)
		g.ladder(Vector3(x + 0.32, Y0, 0.0), 1.3, Vector3.RIGHT)
		# steam drum on top
		g.color("#c9ccc8", Geo.STEEL)
		g.tube(Vector3(x - 0.22, Y0 + 1.45, -0.38), Vector3(x + 0.22, Y0 + 1.45, -0.38), 0.07, 10)
		# exhaust stack (tall, banded, with a platform ring)
		var sp := Vector3(x, 0, -1.2)
		g.color("#8f9490", Geo.STEEL)
		g.cbox(Vector3(x, Y0 + 0.9, -0.95), Vector3(0.3, 0.3, 0.3), 0.01)
		g.color("#c9ccc8", Geo.STEEL)
		g.cyl(0.15, 0.12, 2.5, 14, Transform3D(Basis.IDENTITY, sp + Vector3(0, Y0 + 1.25, 0)))
		g.color("#d8503c", Geo.PAINT)
		for y in [2.2, 2.42]:
			g.band(0.125, Y0 + y, 0.07, 0.004, 14, Transform3D(Basis.IDENTITY, sp))
		g.color(STEEL, Geo.STEEL)
		g.rail_ring(0.18, Y0 + 1.9, 12, 0.06, Transform3D(Basis.IDENTITY, sp))
		g.ladder(sp + Vector3(0.14, Y0 + 0.3, 0), 1.6, Vector3.RIGHT)
	# steam turbine hall (between and behind the gas halls)
	g.color(IR_S, Geo.CONCRETE)
	g.cbox(Vector3(-0.4, Y0 + 0.36, -1.45), Vector3(1.7, 0.72, 0.5), 0.02)
	g.color(IR_S2, Geo.CONCRETE)
	g.cbox(Vector3(-0.4, Y0 + 0.74, -1.45), Vector3(1.74, 0.05, 0.54), 0.01)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.4, Y0 + 0.62, -1.705), Vector3(0.6, 0.06, 0.006))
	# air-cooled condenser: raised fan deck on legs, A-frame coil roof, fan rings (fans are parts)
	g.color(STEEL, Geo.STEEL)
	for ix in 3:
		for iz in 4:
			var lp := Vector3(1.05 + ix * 0.32, Y0, -1.35 + iz * 0.6)
			g.tube(lp, lp + Vector3(0, 0.78, 0), 0.02, 5)
	g.color("#9a9f9b", Geo.STEEL)
	g.cbox(Vector3(1.37, Y0 + 0.82, -0.45), Vector3(0.78, 0.08, 2.0), 0.01)
	for iz in 4:
		var c := Vector3(1.37, Y0 + 0.87, -1.2 + iz * 0.5)
		g.color("#6f7471", Geo.STEEL)
		g.cyl(0.17, 0.17, 0.05, 16, Transform3D(Basis.IDENTITY, c + Vector3(-0.18, 0.025, 0)))
		g.cyl(0.17, 0.17, 0.05, 16, Transform3D(Basis.IDENTITY, c + Vector3(0.18, 0.025, 0)))
	g.color("#b4b8b4", Geo.STEEL)
	g.rbox(Vector3(1.2, Y0 + 1.05, -0.45), Vector3(0.38, 0.01, 2.0), Vector3(0, 0, 35))
	g.rbox(Vector3(1.54, Y0 + 1.05, -0.45), Vector3(0.38, 0.01, 2.0), Vector3(0, 0, -35))
	g.color(STEEL, Geo.STEEL)
	g.box(Vector3(1.37, Y0 + 1.16, -0.45), Vector3(0.1, 0.06, 2.0))
	# steam pipework: boilers -> turbine hall -> condenser header
	g.color("#d4d6d2", Geo.STEEL)
	for k in 2:
		var x: float = CC_X[k]
		g.pipe([Vector3(x + 0.2, Y0 + 1.45, -0.38), Vector3(x + 0.2, Y0 + 1.6, -0.38), Vector3(x + 0.2, Y0 + 1.6, -1.45), Vector3(x + 0.2, Y0 + 0.8, -1.45)], 0.03)
	g.pipe([Vector3(0.45, Y0 + 0.55, -1.45), Vector3(0.95, Y0 + 0.55, -1.45), Vector3(0.95, Y0 + 0.95, -1.45), Vector3(0.95, Y0 + 0.95, 0.55)], 0.05)
	# gas pipeline (yellow) along the front into both turbine halls, valves
	g.color(IR_G, Geo.PAINT)
	g.pipe([Vector3(-1.85, Y0 + 0.07, 0.15), Vector3(-1.5, Y0 + 0.07, 0.15), Vector3(-1.5, Y0 + 0.07, 0.4), Vector3(0.7, Y0 + 0.07, 0.4)], 0.04)
	for k in 2:
		g.tube(Vector3(CC_X[k], Y0 + 0.07, 0.4), Vector3(CC_X[k], Y0 + 0.07, 0.45), 0.035, 8)
	g.color("#c0392b", Geo.PAINT)
	for x in [-1.3, -0.4, 0.5]:
		g.cyl(0.035, 0.035, 0.04, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.14, 0.4)))
		g.tube(Vector3(x, Y0 + 0.11, 0.4), Vector3(x, Y0 + 0.2, 0.4), 0.008, 4)
	# switchyard (front right) with transformers and a gantry
	for i in 2:
		var p := Vector3(0.95 + i * 0.42, Y0, 1.25)
		g.color("#7a7f7a", Geo.STEEL)
		g.cbox(p + Vector3(0, 0.11, 0), Vector3(0.28, 0.22, 0.3), 0.01)
		g.color("#5d6163", Geo.STEEL)
		for kk in 3:
			g.box(p + Vector3(0.145, 0.11, -0.09 + kk * 0.09), Vector3(0.012, 0.17, 0.012))
		g.insulator(p + Vector3(0, 0.22, 0), 0.08)
	g.color(STEEL_L, Geo.STEEL)
	for x in [0.85, 1.57]:
		g.tube(Vector3(x, Y0, 1.6), Vector3(x, Y0 + 0.55, 1.6), 0.012, 4)
	g.tube(Vector3(0.85, Y0 + 0.55, 1.6), Vector3(1.57, Y0 + 0.55, 1.6), 0.01, 4)
	_fence(g, 1.9, 1.9, 0.4)
	UM._roof_lights(g, [Vector3(CC_X[0], Y0 + 2.52, -1.2), Vector3(CC_X[1], Y0 + 2.52, -1.2)])

## Condenser fans: 8 spinning rotors on the fan deck.
static func _cc_fans(model: Node3D, root: Node3D, mat: Material) -> int:
	var tris := 0
	var i := 0
	for iz in 4:
		for sx in [-0.18, 0.18]:
			var f = K.new()
			f.color("#3a3d3c", Geo.STEEL)
			for b in 3:
				f.rbox(Vector3.ZERO, Vector3(0.3, 0.008, 0.05), Vector3(0, b * 60.0, 0))
			f.cyl(0.03, 0.03, 0.03, 8, Transform3D.IDENTITY)
			tris += f.tris
			_part(model, root, mat, "Fan%d" % i, f, Vector3(1.37 + sx, Y0 + 0.9, -1.2 + iz * 0.5), "spin", {"speed": 5.0, "axis": "y"})
			i += 1
	return tris

# ================================================================== Iran Oil Derrick (2 x 2)
## Replaces the Trade Exchange; smaller footprint, new design. A drilling mast over the well
## head, a working pumpjack (walking beam nods via BuildingView), two storage tanks, a
## manifold and a small control cabin - clean, painted, tidy.
static func _derrick(g) -> void:
	g.color("#7f7566", Geo.CONCRETE)
	g.cbox(Vector3(0.15, Y0 + 0.01, 0.2), Vector3(0.9, 0.02, 0.5), 0.005)   # pumpjack plinth
	# pumpjack frame (samson post), gearbox and motor - the beam is the animated part
	g.color("#3f5f78", Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.tube(Vector3(0.15 + s * 0.06, Y0 + 0.02, 0.32), Vector3(0.15, Y0 + 0.5, 0.2), 0.016, 6)
		g.tube(Vector3(0.15 + s * 0.06, Y0 + 0.02, 0.05), Vector3(0.15, Y0 + 0.5, 0.2), 0.016, 6)
	g.color("#2e3d4c", Geo.PAINT)
	g.cbox(Vector3(0.15, Y0 + 0.1, -0.08), Vector3(0.16, 0.16, 0.16), 0.01)   # gearbox
	g.color(STEEL, Geo.STEEL)
	g.cyl(0.05, 0.05, 0.12, 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.15, Y0 + 0.07, -0.25)))
	g.tube(Vector3(0.15, Y0 + 0.02, 0.6), Vector3(0.15, Y0 + 0.22, 0.6), 0.03, 8)   # well head
	g.color("#c0392b", Geo.PAINT)
	g.cyl(0.04, 0.04, 0.03, 8, Transform3D(Basis.IDENTITY, Vector3(0.15, Y0 + 0.2, 0.6)))
	# drilling mast (lattice) over the second well, with the crown block lamp
	g.color("#d8b23a", Geo.PAINT)
	g.lattice(Vector3(-0.5, Y0, -0.45), 1.35, 0.3, 7)
	g.color("#8a8f8c", Geo.STEEL)
	g.cbox(Vector3(-0.5, Y0 + 0.05, -0.45), Vector3(0.5, 0.1, 0.5), 0.01)   # drill floor
	g.color("#ff3020", Geo.LAMP)
	g.cbox(Vector3(-0.5, Y0 + 1.4, -0.45), Vector3(0.05, 0.04, 0.05), 0.01)
	# storage tanks
	for p in [Vector3(0.55, Y0, -0.55), Vector3(0.55, Y0, -0.1)]:
		g.color("#e6e1d4", Geo.PAINT)
		g.cyl(0.17, 0.17, 0.34, 14, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.17, 0)))
		g.dome(0.17, 0.05, 2, 14, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.34, 0)))
		g.color(IR_T, Geo.PAINT)
		g.band(0.172, p.y + 0.24, 0.04, 0.003, 14, Transform3D(Basis.IDENTITY, Vector3(p.x, 0, p.z)))
		g.color(STEEL, Geo.STEEL)
		g.ladder(p + Vector3(-0.17, 0, 0), 0.34, Vector3.BACK)
	g.color("#ffffff", Geo.TEAM)
	g.band(0.173, Y0 + 0.12, 0.04, 0.003, 14, Transform3D(Basis.IDENTITY, Vector3(0.55, 0, -0.1)))
	# manifold pipes
	g.color(IR_G, Geo.PAINT)
	g.pipe([Vector3(0.15, Y0 + 0.12, 0.6), Vector3(0.38, Y0 + 0.12, 0.6), Vector3(0.38, Y0 + 0.12, -0.55)], 0.022)
	g.pipe([Vector3(-0.5, Y0 + 0.08, -0.2), Vector3(-0.5, Y0 + 0.08, 0.1), Vector3(0.38, Y0 + 0.08, 0.1)], 0.02)
	# control cabin with the tile band
	g.color(IR_S, Geo.CONCRETE)
	g.cbox(Vector3(-0.55, Y0 + 0.12, 0.5), Vector3(0.5, 0.24, 0.36), 0.01)
	g.color(IR_S2, Geo.CONCRETE)
	g.cbox(Vector3(-0.55, Y0 + 0.25, 0.5), Vector3(0.54, 0.03, 0.4), 0.006)
	_ir_band(g, Vector3(-0.55, Y0 + 0.2, 0.682), 0.5, 0)
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(-0.42, Y0 + 0.11, 0.683), Vector3(0.14, 0.08, 0.005))
	g.color("#5d6163", Geo.STEEL)
	g.box(Vector3(-0.66, Y0 + 0.1, 0.683), Vector3(0.09, 0.16, 0.005))
	_fence(g, 0.92, 0.92, 0.25)

static func _pumpjack(model: Node3D, root: Node3D, mat: Material) -> int:
	var b = K.new()
	b.color("#3f5f78", Geo.PAINT)
	b.cbox(Vector3(0, 0.0, 0.0), Vector3(0.05, 0.05, 0.66), 0.008)   # walking beam
	b.color("#2e3d4c", Geo.PAINT)
	b.prism_x([Vector2(0.33, -0.1), Vector2(0.4, -0.06), Vector2(0.4, 0.06), Vector2(0.33, 0.1), Vector2(0.3, 0.0)], -0.03, 0.03)   # horse head
	b.color("#d8b23a", Geo.PAINT)
	b.cbox(Vector3(0, -0.02, -0.33), Vector3(0.12, 0.12, 0.08), 0.01)   # counterweight
	b.color(STEEL, Geo.STEEL)
	b.tube(Vector3(0, -0.1, 0.4), Vector3(0, -0.3, 0.4), 0.005, 3)   # bridle
	var mi := _part(model, root, mat, "Beam", b, Vector3(0.15, Y0 + 0.5, 0.2), "nod", {"speed": 1.6, "amp": 0.22})
	return b.tris

# ================================================================== Germany Automotive Plant
## Replaces the Logistics Centre: a long sawtooth-roof assembly hall with glazed north lights,
## a paint shop with exhaust stack, a covered loading dock and a lot of finished cars in
## neat rows (generic shapes, no makes), plus the team band. Faction-neutral grey-white.
const AP_W := "#cfd0cb"
const AP_W2 := "#b4b6b1"
const AP_R := "#9a9e9b"
static func _car(g, c: Vector3, yaw: float, col: String) -> void:
	var t := UM._face_t(yaw, c)
	g.color(col, Geo.PAINT)
	g.cbox(Vector3(0, 0.035, 0), Vector3(0.11, 0.04, 0.24), 0.012, t)
	g.cbox(Vector3(0, 0.07, -0.01), Vector3(0.095, 0.035, 0.12), 0.012, t)
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(0, 0.07, 0.051), Vector3(0.085, 0.025, 0.004), t)
	g.color("#1d1c1b", Geo.RUBBER)
	for s in [-1.0, 1.0]:
		for z in [-0.075, 0.075]:
			g.box(Vector3(s * 0.054, 0.016, z), Vector3(0.006, 0.03, 0.04), t)

static func _auto_plant(g) -> void:
	# assembly hall with sawtooth roof
	var x0 := -1.35
	var x1 := 0.75
	var z0 := -1.25
	var z1 := 0.25
	g.color(AP_W, Geo.CONCRETE)
	g.cbox(Vector3((x0 + x1) * 0.5, Y0 + 0.26, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.52, z1 - z0), 0.02)
	var n := 6
	var dz := (z1 - z0) / float(n)
	for i in n:
		var za := z0 + i * dz
		g.color(AP_R, Geo.CORR)
		g.prism_x([Vector2(za, Y0 + 0.52), Vector2(za + dz, Y0 + 0.52), Vector2(za + dz, Y0 + 0.7)], x0 + 0.02, x1 - 0.02)
		g.color(GLASS_C, Geo.GLASS)
		g.box(Vector3((x0 + x1) * 0.5, Y0 + 0.62, za + dz - 0.004), Vector3(x1 - x0 - 0.08, 0.1, 0.006))
	g.color("#3a5f8a", Geo.PAINT)
	g.box(Vector3((x0 + x1) * 0.5, Y0 + 0.46, z1 + 0.003), Vector3(x1 - x0, 0.05, 0.006))
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(x0 + 0.4, Y0 + 0.36, z1 + 0.004), Vector3(0.5, 0.06, 0.006))
	g.color(GLASS_C, Geo.GLASS)
	UM._win_grid(g, Vector3((x0 + x1) * 0.5 + 0.2, Y0 + 0.3, z1 + 0.005), 1.2, 0.12, 9, 1, UM._face_t(0, Vector3.ZERO), 52, 0.5)
	g.color("#5d6163", Geo.STEEL)
	for k in 3:   # delivery doors on the long side
		g.rollup(Vector3(x0 - 0.004, Y0 + 0.17, z0 + 0.3 + k * 0.45), 0.3, 0.3, UM._face_t(-90, Vector3.ZERO))
	# paint shop + stack
	g.color(AP_W2, Geo.CONCRETE)
	g.cbox(Vector3(1.1, Y0 + 0.3, -0.75), Vector3(0.62, 0.6, 1.0), 0.02)
	g.color("#a3a7a1", Geo.STEEL)
	for i in 2:
		g.cbox(Vector3(1.1, Y0 + 0.66, -1.0 + i * 0.5), Vector3(0.4, 0.12, 0.3), 0.01)
		g.fan(Vector3(1.1, Y0 + 0.72, -1.0 + i * 0.5), 0.1, 5, 6.0 + i)
	g.color("#c9ccc8", Geo.STEEL)
	g.cyl(0.07, 0.06, 0.55, 10, Transform3D(Basis.IDENTITY, Vector3(1.05, Y0 + 0.6 + 0.27, -0.95)))
	g.color("#d8503c", Geo.PAINT)
	g.band(0.062, Y0 + 1.07, 0.04, 0.003, 10, Transform3D(Basis.IDENTITY, Vector3(1.05, 0, -0.95)))
	g.color(STEEL, Geo.STEEL)   # conveyor bridge hall -> paint shop
	g.box(Vector3(0.78, Y0 + 0.42, -0.6), Vector3(0.12, 0.12, 0.2))
	# covered loading dock
	g.color(STEEL, Geo.STEEL)
	for x in [0.95, 1.35]:
		for z in [0.0, 0.4]:
			g.tube(Vector3(x, Y0, z), Vector3(x, Y0 + 0.3, z), 0.01, 4)
	g.color(AP_R, Geo.CORR)
	g.cbox(Vector3(1.15, Y0 + 0.31, 0.2), Vector3(0.52, 0.02, 0.52), 0.005)
	# finished-car lot (rows, no makes)
	g.color("#55585a", Geo.CONCRETE)
	g.box(Vector3(-0.35, Y0 + 0.004, 0.95), Vector3(2.0, 0.006, 0.8))
	g.color("#e8e8e0", Geo.PAINT)
	var cols := ["#c8ccd0", "#2b3542", "#8c1f1f", "#e8e8e4", "#3d5f7f", "#4a4d4f"]
	for r in 2:
		for k in 9:
			g.color("#e8e8e0", Geo.PAINT)
			g.box(Vector3(-1.22 + k * 0.2 - 0.1, Y0 + 0.008, 0.78 + r * 0.36), Vector3(0.01, 0.002, 0.26))
			if (k * 7 + r * 3) % 5 != 0:
				_car(g, Vector3(-1.22 + k * 0.2, Y0 + 0.007, 0.78 + r * 0.36), 0.0 if r == 0 else 180.0, cols[(k + r * 2) % cols.size()])
	_fence(g, 1.42, 1.42, 0.5)
	UM._roof_lights(g, UM._corners((x0 + x1) * 0.5, (z0 + z1) * 0.5, (x1 - x0) * 0.46, (z1 - z0) * 0.45, Y0 + 0.7))

# ================================================================== Russia Minerals Mining
## A giant bucket-wheel excavator (the biggest machine in the base, building-sized): crawler
## chassis on three track pairs, a turntable house, the bucket-wheel boom angled up to the
## front with the wheel (separate node, turns via BuildingView), the counterweight boom and
## its A-frame mast with stay cables, and a discharge conveyor boom to the side. Industrial
## yellow-orange with grey steel. Not a copy of any one machine.
const BW_Y := "#d9a42c"
const BW_O := "#c8742a"
const BW_G := "#6d716f"
## Box girder from a to b (w wide, h deep), the long axis along a->b.
static func _beam(g, a: Vector3, b: Vector3, w: float, h: float, ch := 0.01) -> void:
	var d := b - a
	var bs := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	g.cbox(Vector3.ZERO, Vector3(w, h, d.length()), ch, Transform3D(bs, (a + b) * 0.5))

static func _excavator(g) -> void:
	# crawler pads (3 pairs) + undercarriage
	for p in [Vector2(-0.75, 0.55), Vector2(0.75, 0.55), Vector2(0.0, -0.7)]:
		for s in [-1.0, 1.0]:
			g.color("#2e2f2d", Geo.TRACK)
			g.cbox(Vector3(p.x + s * 0.22, Y0 + 0.1, p.y), Vector3(0.18, 0.2, 0.7), 0.04)
			g.color(BW_G, Geo.STEEL)
			for k in 4:
				g.box(Vector3(p.x + s * 0.22, Y0 + 0.21, p.y - 0.27 + k * 0.18), Vector3(0.19, 0.012, 0.03))
		g.color(BW_G, Geo.STEEL)
		g.cbox(Vector3(p.x, Y0 + 0.24, p.y), Vector3(0.3, 0.1, 0.5), 0.02)
	g.color(BW_G, Geo.STEEL)
	g.cyl(0.95, 0.95, 0.1, 20, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.34, 0)))   # ring girder
	g.color(BW_Y, Geo.PAINT)
	g.cyl(0.7, 0.75, 0.12, 20, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.45, 0)))   # turntable
	# superstructure house
	g.color(BW_Y, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 0.75, -0.1), Vector3(0.9, 0.5, 1.0), 0.02)
	g.color(BW_O, Geo.PAINT)
	g.cbox(Vector3(0, Y0 + 1.02, -0.1), Vector3(0.94, 0.05, 1.04), 0.01)
	g.color(BW_Y, Geo.PAINT)
	g.cbox(Vector3(0.05, Y0 + 1.17, -0.3), Vector3(0.55, 0.26, 0.5), 0.015)   # machinery house
	g.color(GLASS_C, Geo.GLASS)
	g.box(Vector3(0.05, Y0 + 1.2, -0.046), Vector3(0.45, 0.08, 0.006))
	g.color(BW_O, Geo.PAINT)   # operator cab hung off the front, looking at the wheel
	g.cbox(Vector3(-0.35, Y0 + 0.95, 0.55), Vector3(0.22, 0.2, 0.22), 0.015)
	g.color(GLASS_C, Geo.GLASS)
	g.plate(Vector3(-0.35, Y0 + 0.97, 0.663), Vector3(0.18, 0.12, 0.006), Vector3(-12, 0, 0))
	g.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 0.452, Y0 + 0.88, -0.1), Vector3(0.006, 0.07, 0.8))
	g.color(GLASS_C, Geo.GLASS)
	for s in [-1.0, 1.0]:
		g.box(Vector3(s * 0.453, Y0 + 0.72, -0.1), Vector3(0.006, 0.08, 0.7))
	g.color("#5d6163", Geo.STEEL)
	g.vent(Vector3(0, Y0 + 0.75, -0.605), 0.6, 0.25, 6)
	# main boom: two heavy box girders from the house up to the wheel hub, cross-braced
	var hub := Vector3(0, Y0 + 1.3, 1.62)
	var foot := Vector3(0, Y0 + 0.95, 0.35)
	var hb := hub + Vector3(0, 0, -0.32)
	g.color(BW_Y, Geo.PAINT)
	for s in [-1.0, 1.0]:
		_beam(g, foot + Vector3(s * 0.17, 0.08, 0), hb + Vector3(s * 0.17, 0.04, 0), 0.06, 0.16)
	for k in 5:
		var t := (float(k) + 0.5) / 5.0
		var c := foot.lerp(hb, t) + Vector3(0, 0.08, 0)
		g.color(BW_O, Geo.PAINT)
		g.box(c, Vector3(0.36, 0.03, 0.03))
		g.tube(c + Vector3(-0.17, -0.06, 0), c + Vector3(0.17, 0.06, 0.08), 0.01, 4)
	g.color(BW_G, Geo.STEEL)   # boom conveyor belt down the middle
	g.box((foot + hub) * 0.5 + Vector3(0, 0.06, -0.15), Vector3(0.14, 0.02, foot.distance_to(hub) - 0.2))
	g.cbox(hub + Vector3(0, 0, -0.22), Vector3(0.36, 0.2, 0.2), 0.02)   # wheel drive housing
	# counterweight boom + ballast box
	var cw := Vector3(0, Y0 + 1.15, -1.45)
	g.color(BW_Y, Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.tube(Vector3(s * 0.2, Y0 + 1.0, -0.5), cw + Vector3(s * 0.2, 0, 0.1), 0.03, 6)
		g.tube(Vector3(s * 0.2, Y0 + 0.8, -0.55), cw + Vector3(s * 0.2, -0.15, 0.1), 0.02, 6)
	g.color("#7d7a6f", Geo.CONCRETE)
	g.cbox(cw + Vector3(0, -0.08, 0), Vector3(0.5, 0.3, 0.32), 0.02)
	# A-frame mast with stay cables to both booms
	var top := Vector3(0, Y0 + 2.05, -0.25)
	g.color(BW_O, Geo.PAINT)
	for s in [-1.0, 1.0]:
		g.tube(Vector3(s * 0.32, Y0 + 1.02, 0.1), top + Vector3(s * 0.05, 0, 0), 0.028, 6)
		g.tube(Vector3(s * 0.32, Y0 + 1.02, -0.5), top + Vector3(s * 0.05, 0, 0), 0.028, 6)
	g.color("#2b2d2c", Geo.STEEL)
	for s in [-1.0, 1.0]:
		g.tube(top + Vector3(s * 0.05, 0, 0), hub + Vector3(s * 0.15, 0.25, -0.35), 0.006, 3)
		g.tube(top + Vector3(s * 0.05, 0, 0), foot.lerp(hub, 0.5) + Vector3(s * 0.16, 0.25, 0), 0.006, 3)
		g.tube(top + Vector3(s * 0.05, 0, 0), cw + Vector3(s * 0.2, 0.1, 0), 0.006, 3)
	g.color("#ff3020", Geo.LAMP)
	g.cbox(top + Vector3(0, 0.04, 0), Vector3(0.05, 0.04, 0.05), 0.01)
	# discharge conveyor boom to the right, ending over a spoil heap
	var d0 := Vector3(0.45, Y0 + 0.9, -0.3)
	var d1 := Vector3(1.55, Y0 + 0.6, -0.95)
	g.color(BW_Y, Geo.PAINT)
	for s in [-0.06, 0.06]:
		g.tube(d0 + Vector3(0, 0, s), d1 + Vector3(0, 0, s), 0.02, 5)
	g.color(BW_G, Geo.STEEL)
	g.box((d0 + d1) * 0.5 + Vector3(0, 0.04, 0), Vector3(0.1, 0.015, 0.1))
	g.tube(d0 + Vector3(0, 0.04, 0), d1 + Vector3(0, 0.04, 0), 0.04, 6)
	g.color("#3b3428", Geo.SANDBAG)
	g.lathe([[Y0, 0.42], [Y0 + 0.22, 0.18], [Y0 + 0.3, 0.0]], 10, Transform3D(Basis.IDENTITY, Vector3(1.5, 0, -1.0)))
	g.color("#2c271f", Geo.SANDBAG)
	g.lathe([[Y0, 0.3], [Y0 + 0.14, 0.12], [Y0 + 0.2, 0.0]], 9, Transform3D(Basis.IDENTITY, Vector3(-1.2, 0, 1.25)))
	# walkways + handrails on the house roof
	g.color("#e8d34a", Geo.PAINT)
	g.rail([Vector3(-0.44, Y0 + 1.05, -0.58), Vector3(0.44, Y0 + 1.05, -0.58), Vector3(0.44, Y0 + 1.05, 0.38), Vector3(-0.44, Y0 + 1.05, 0.38), Vector3(-0.44, Y0 + 1.05, -0.58)], 0.08)
	g.color("#ff9a2a", Geo.LAMP)
	g.cbox(Vector3(0.4, Y0 + 1.1, 0.35), Vector3(0.04, 0.04, 0.04), 0.01)

static func _bucket_wheel(model: Node3D, root: Node3D, mat: Material) -> int:
	var w = K.new()
	var R := 0.56
	var rim := Basis(Vector3.FORWARD, PI * 0.5)
	w.color("#5b5e5c", Geo.STEEL)
	w.cyl(R * 0.82, R * 0.82, 0.05, 24, Transform3D(rim, Vector3.ZERO))   # wheel body
	w.color(BW_Y, Geo.PAINT)
	w.cyl(R * 0.9, R * 0.9, 0.12, 24, Transform3D(rim, Vector3.ZERO), false)   # rim ring
	w.cyl(R * 0.25, R * 0.25, 0.18, 12, Transform3D(rim, Vector3.ZERO))   # hub
	for k in 8:   # spokes on both faces
		var a := TAU * float(k) / 8.0
		for sx in [-0.035, 0.035]:
			w.tube(Vector3(sx, sin(a) * R * 0.25, cos(a) * R * 0.25), Vector3(sx, sin(a) * R * 0.85, cos(a) * R * 0.85), 0.02, 4)
	for k in 14:   # buckets with teeth
		var a := TAU * float(k) / 14.0
		var c := Vector3(0, sin(a) * R * 0.98, cos(a) * R * 0.98)
		var bs := Basis(Vector3.RIGHT, -a)
		w.color("#6a6d6a", Geo.STEEL)
		w.cbox(Vector3.ZERO, Vector3(0.17, 0.12, 0.15), 0.025, Transform3D(bs, c))
		w.color("#2f302e", Geo.STEEL)
		for tx in [-0.05, 0.0, 0.05]:
			w.box(Vector3(tx, 0.02, 0.09), Vector3(0.02, 0.03, 0.04), Transform3D(bs, c))
	_part(model, root, mat, "BucketWheel", w, Vector3(0, Y0 + 1.3, 1.62), "spin", {"speed": -0.9})
	return w.tris

# ================================================================== Russia Missile Silo
## Replaces the Kornet Nest (Malachi: a fixed in-ground launcher whose door opens to fire,
## heavy damage, slow rate). A flush concrete silo collar with two armoured hatch leaves
## (separate nodes: BuildingView swings them open on each launch), a dark shaft with the
## missile nose, a low control bunker, vents, warning stripes and perimeter posts.
static func _silo(g) -> void:
	g.color("#8d887d", Geo.CONCRETE)
	g.cyl(0.62, 0.66, 0.08, 20, Transform3D(Basis.IDENTITY, Vector3(0.0, Y0 + 0.04, 0.1)))   # collar
	g.color("#a19c90", Geo.CONCRETE)
	g.cyl(0.5, 0.52, 0.02, 20, Transform3D(Basis.IDENTITY, Vector3(0.0, Y0 + 0.09, 0.1)))
	g.color("#1c1d1c", Geo.DARK)
	g.cyl(0.36, 0.36, 0.012, 16, Transform3D(Basis.IDENTITY, Vector3(0.0, Y0 + 0.095, 0.1)))   # shaft mouth
	g.color("#5f6a56", Geo.PAINT)   # missile nose deep in the shaft
	g.lathe([[Y0 + 0.02, 0.16], [Y0 + 0.07, 0.12], [Y0 + 0.095, 0.0]], 12, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)))
	g.color("#e8d34a", Geo.PAINT)
	g.band(0.64, Y0 + 0.07, 0.02, 0.004, 20, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)))
	g.color("#2b2d2c", Geo.DARK)
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.2
		g.rbox(Vector3(cos(a) * 0.645, Y0 + 0.07, 0.1 + sin(a) * 0.645), Vector3(0.06, 0.021, 0.02), Vector3(0, -rad_to_deg(a) + 90.0, 0))
	# hinge blocks on both sides of the hatch
	g.color("#6b6f6c", Geo.STEEL)
	for s in [-1.0, 1.0]:
		g.cbox(Vector3(s * 0.43, Y0 + 0.11, 0.1), Vector3(0.08, 0.06, 0.5), 0.01)
	# control bunker (low, half buried) + vents + antenna
	g.color("#7d7a6f", Geo.CONCRETE)
	g.plan_loft([Vector2(-0.85, -0.95), Vector2(-0.15, -0.95), Vector2(-0.15, -0.55), Vector2(-0.85, -0.55)], Y0, Y0 + 0.16, Vector2(0.88, 0.75))
	g.color("#2b2d2c", Geo.DARK)
	g.box(Vector3(-0.5, Y0 + 0.07, -0.548), Vector3(0.16, 0.1, 0.006))
	g.color("#5d6163", Geo.STEEL)
	for x in [0.35, 0.6]:
		g.cyl(0.05, 0.05, 0.1, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.05, -0.75)))
		g.cyl(0.07, 0.07, 0.015, 8, Transform3D(Basis.IDENTITY, Vector3(x, Y0 + 0.12, -0.75)))
	g.tube(Vector3(-0.75, Y0 + 0.16, -0.75), Vector3(-0.75, Y0 + 0.6, -0.75), 0.006, 3)
	g.color("#ffffff", Geo.TEAM)
	g.box(Vector3(-0.5, Y0 + 0.13, -0.547), Vector3(0.5, 0.025, 0.006))
	g.color("#ff3020", Geo.LAMP)
	for p in [Vector3(-0.85, Y0 + 0.05, 0.85), Vector3(0.85, Y0 + 0.05, 0.85), Vector3(0.85, Y0 + 0.05, -0.4)]:
		g.color(STEEL_L, Geo.STEEL)
		g.tube(p - Vector3(0, 0.05, 0), p + Vector3(0, 0.1, 0), 0.008, 4)
		g.color("#ff3020", Geo.LAMP)
		g.cbox(p + Vector3(0, 0.12, 0), Vector3(0.03, 0.03, 0.03), 0.006)

static func _silo_doors(model: Node3D, root: Node3D, mat: Material) -> int:
	var n := 0
	for s in [-1.0, 1.0]:
		var d = K.new()
		# a half-disc armoured leaf, hinged at its outer edge (node origin on the hinge)
		d.color("#6a705f", Geo.PAINT)
		d.cbox(Vector3(-s * 0.21, 0.02, 0.0), Vector3(0.42, 0.04, 0.72), 0.012)
		d.color("#525849", Geo.PAINT)
		for z in [-0.22, 0.0, 0.22]:
			d.box(Vector3(-s * 0.21, 0.043, z), Vector3(0.38, 0.006, 0.03))
		d.color("#ffffff", Geo.TEAM)
		d.box(Vector3(-s * 0.3, 0.044, 0.0), Vector3(0.05, 0.004, 0.4))
		var mi := _part(model, root, mat, "Door" + ("L" if s < 0 else "R"), d, Vector3(s * 0.42, Y0 + 0.1, 0.1), "door", {"open_deg": 105.0 * -s})
		n += d.tris
	return n
