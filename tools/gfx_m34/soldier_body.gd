extends RefCounted
## M3.4 soldier geometry (original, procedural): body, uniform, armour, pouches, packs, head
## gear, per-variant parts (vertex variant masks) on the M3.4 rig. Called by the bake script.
const Rig := preload("res://tools/gfx_m34/soldier_rig.gd")
const TEAM := 1
const SKIN := 2
const CAMO := 4
const FINE := 8

static func _cam(spec: Dictionary) -> int:
	return CAMO | (FINE if spec.get("camo", 1) == 2 else 0) if spec.get("camo", 1) > 0 else 0

static func build(r, spec: Dictionary) -> void:
	var jk: String = spec["jacket"]
	var tr: String = spec.get("trousers", jk)
	var cm := _cam(spec)
	var skin: String = spec.get("skin", "#c49a78")
	var boots: String = spec.get("boots", "#2a2622")
	var gloves: String = spec.get("gloves", "")
	var J: Dictionary = Rig.J
	# ---------------- pelvis / hips (trousers) + belt
	r.bone = Rig.PELVIS
	r.set_c(tr, cm)
	r.loft(Vector3(0, 0.84, 0), Vector3(0, 1.06, 0), [[0.0, 0.125, 0.095], [0.3, 0.165, 0.115], [0.7, 0.165, 0.112], [1.0, 0.152, 0.104]], Vector3.RIGHT, 12, [-1, Rig.SPINE])
	r.set_c(spec.get("belt", "#3a3528"))
	r.loft(Vector3(0, 1.0, 0), Vector3(0, 1.045, 0), [[0.0, 0.172, 0.12], [1.0, 0.17, 0.118]], Vector3.RIGHT, 12)
	if spec.get("armour", "") != "":
		r.set_c(spec["pouch"])
		r.box(Vector3(-0.12, 0.98, -0.1), Vector3(0.07, 0.09, 0.06))    # dump pouch
		r.box(Vector3(0.155, 0.99, -0.03), Vector3(0.045, 0.08, 0.07))   # IFAK
	# ---------------- abdomen (jacket)
	r.bone = Rig.SPINE
	r.set_c(jk, cm)
	r.loft(Vector3(0, 1.03, 0), Vector3(0, 1.27, 0), [[0.0, 0.158, 0.106], [0.5, 0.152, 0.102], [1.0, 0.168, 0.112]], Vector3.RIGHT, 12, [Rig.PELVIS, Rig.CHEST])
	# ---------------- chest
	r.bone = Rig.CHEST
	r.set_c(jk, cm)
	r.loft(Vector3(0, 1.24, 0), Vector3(0, 1.505, 0), [[0.0, 0.166, 0.11], [0.35, 0.183, 0.12], [0.68, 0.192, 0.118], [0.86, 0.178, 0.104], [1.0, 0.1, 0.07]], Vector3.RIGHT, 12, [Rig.SPINE, -1])
	r.set_c(jk, cm)
	r.loft(Vector3(0, 1.47, -0.005), Vector3(0, 1.53, -0.005), [[0.0, 0.07, 0.065], [1.0, 0.062, 0.058]], Vector3.RIGHT, 10)   # collar
	_armour(r, spec)
	_back(r, spec)
	# ---------------- neck / head
	r.bone = Rig.NECK
	r.set_c(skin, SKIN)
	r.loft(Vector3(0, 1.47, 0.0), Vector3(0, 1.62, 0.01), [[0.0, 0.056, 0.054], [1.0, 0.05, 0.05]], Vector3.RIGHT, 8, [Rig.CHEST, Rig.HEAD])
	r.bone = Rig.HEAD
	r.set_c(skin, SKIN)
	r.ellipsoid(Vector3(0, 1.695, 0.0), Vector3(0.08, 0.11, 0.096), Basis(), 7, 12)
	r.ellipsoid(Vector3(0, 1.635, 0.028), Vector3(0.066, 0.052, 0.07), Basis(), 5, 10)    # jaw
	r.box(Vector3(0, 1.672, 0.098), Vector3(0.022, 0.042, 0.03), Basis(Vector3.RIGHT, -0.2))   # nose
	for sx in [-1.0, 1.0]:
		r.ellipsoid(Vector3(sx * 0.08, 1.68, -0.004), Vector3(0.012, 0.03, 0.02), Basis(), 3, 6)   # ears
	r.set_c("#2a221c")
	for sx in [-1.0, 1.0]:
		r.box(Vector3(sx * 0.031, 1.692, 0.089), Vector3(0.024, 0.011, 0.008))   # eyes / brow shadow
	_heads(r, spec)
	# ---------------- arms
	for s in ["L", "R"]:
		var o: int = 0 if s == "L" else 3
		var sx := 1.0 if s == "L" else -1.0
		var sh: Vector3 = J["sh_" + s]
		var el: Vector3 = J["el_" + s]
		var wr: Vector3 = J["wr_" + s]
		r.bone = Rig.UARM_L + o
		r.set_c(jk, cm)
		r.ellipsoid(sh + Vector3(sx * 0.012, -0.015, 0), Vector3(0.062, 0.068, 0.064), Basis(), 5, 10, Rig.CHEST, 0.35)   # deltoid
		r.limb(sh, el, 0.056, 0.044, Vector3.FORWARD, 9, [Rig.CHEST, Rig.FARM_L + o])
		r.set_c("#cccccc", TEAM)
		var pp: Vector3 = sh.lerp(el, 0.3) + Vector3(sx * 0.054, 0, 0.0)
		r.box(pp, Vector3(0.01, 0.055, 0.058))     # shoulder patch (team colour)
		r.bone = Rig.FARM_L + o
		var rolled: bool = spec.get("rolled", false)
		r.set_c(jk if not rolled else skin, cm if not rolled else SKIN)
		r.limb(el, wr, 0.045, 0.034, Vector3.FORWARD, 9, [Rig.UARM_L + o, Rig.HAND_L + o])
		if rolled:
			r.set_c(jk, cm)
			r.loft(el + (wr - el) * -0.05, el + (wr - el) * 0.18, [[0.0, 0.05, 0.05], [1.0, 0.048, 0.048]], Vector3.FORWARD, 9)
		r.bone = Rig.HAND_L + o
		if gloves != "":
			r.set_c(gloves)
		else:
			r.set_c(skin, SKIN)
		var hb: Basis = (r.rest[Rig.HAND_L + o] as Transform3D).basis
		var d := -hb.y
		r.ellipsoid(wr + d * 0.05, Vector3(0.022, 0.052, 0.043), hb, 4, 8)
		r.ellipsoid(wr + d * 0.03 + hb.z * 0.035 + hb.x * sx * -0.01, Vector3(0.014, 0.03, 0.014), hb, 3, 6)   # thumb
		if gloves != "":
			r.loft(wr - d * 0.015, wr + d * 0.02, [[0.0, 0.036, 0.04], [1.0, 0.035, 0.044]], hb.z, 8)   # cuff
	# ---------------- legs
	for s in ["L", "R"]:
		var o: int = 0 if s == "L" else 3
		var sx := 1.0 if s == "L" else -1.0
		var hip: Vector3 = J["hip_" + s]
		var kn: Vector3 = J["kn_" + s]
		var an: Vector3 = J["an_" + s]
		r.bone = Rig.THIGH_L + o
		r.set_c(tr, cm)
		r.limb(hip + Vector3(0, 0.03, 0), kn, 0.088, 0.058, Vector3.RIGHT, 10, [Rig.PELVIS, Rig.SHIN_L + o])
		r.set_c(spec.get("pouch", tr), 0)
		if spec.get("thigh_pouch", false) and s == "R":
			r.box(hip.lerp(kn, 0.45) + Vector3(sx * 0.085, 0, 0.0), Vector3(0.03, 0.13, 0.09))   # holster / pocket
		elif spec.get("cargo", true):
			r.set_c(tr, cm)
			r.box(hip.lerp(kn, 0.5) + Vector3(sx * 0.077, 0, 0.005), Vector3(0.025, 0.11, 0.085))   # cargo pocket
		r.bone = Rig.SHIN_L + o
		r.set_c(tr, cm)
		r.limb(kn, an, 0.058, 0.042, Vector3.RIGHT, 10, [Rig.THIGH_L + o, Rig.FOOT_L + o])
		if spec.get("kneepads", false):
			r.set_c(spec.get("pouch", "#333333"))
			r.box(kn + Vector3(0, -0.03, 0.055), Vector3(0.085, 0.1, 0.035), Basis(Vector3.RIGHT, 0.1))
		r.set_c(boots)
		r.loft(an + Vector3(0, -0.02, 0), an + Vector3(0, 0.17, 0.0), [[0.0, 0.05, 0.056], [1.0, 0.048, 0.05]], Vector3.RIGHT, 10)   # boot shaft
		r.bone = Rig.FOOT_L + o
		r.set_c(boots)
		r.loft(an + Vector3(0, -0.035, -0.07), an + Vector3(0, -0.045, 0.18), [[0.0, 0.035, 0.04], [0.15, 0.045, 0.048], [0.6, 0.048, 0.04], [0.92, 0.042, 0.03], [1.0, 0.02, 0.018]], Vector3.RIGHT, 10)
		r.set_c("#1b1a18")
		r.box(an + Vector3(0, -0.082, 0.05), Vector3(0.094, 0.018, 0.27))   # sole

# ------------------------------------------------------------------ armour / chest kit
static func _armour(r, spec: Dictionary) -> void:
	var kind: String = spec.get("armour", "")
	var ac: String = spec.get("carrier", "#5a5440")
	var pc: String = spec.get("pouch", ac)
	var cm := _cam(spec) if spec.get("carrier_camo", false) else 0
	match kind:
		"plate":
			r.set_c(ac, cm)
			r.box(Vector3(0, 1.355, 0.128), Vector3(0.3, 0.3, 0.05), Basis(Vector3.RIGHT, -0.06))   # front plate bag
			r.box(Vector3(0, 1.365, -0.124), Vector3(0.3, 0.32, 0.05), Basis(Vector3.RIGHT, 0.05))  # back plate bag
			r.loft(Vector3(0, 1.21, 0), Vector3(0, 1.32, 0), [[0.0, 0.19, 0.135], [1.0, 0.195, 0.14]], Vector3.RIGHT, 12)   # cummerbund
			for sx in [-1.0, 1.0]:
				r.box(Vector3(sx * 0.1, 1.5, 0.0), Vector3(0.07, 0.025, 0.25))   # shoulder straps
			r.set_c(pc)
			for k in 3:
				r.box(Vector3((k - 1) * 0.085, 1.25, 0.168), Vector3(0.075, 0.12, 0.045))   # rifle mag pouches
			r.box(Vector3(0, 1.43, 0.163), Vector3(0.15, 0.065, 0.03))    # admin pouch
			r.box(Vector3(0.17, 1.28, 0.08), Vector3(0.04, 0.09, 0.06))    # radio pouch
			r.set_c("#4a4f3a")
			r.ellipsoid(Vector3(-0.16, 1.26, 0.11), Vector3(0.028, 0.034, 0.028), Basis(), 4, 6)   # grenade
		"chest_rig":
			r.set_c(ac, cm)
			r.box(Vector3(0, 1.27, 0.13), Vector3(0.3, 0.14, 0.06))
			for sx in [-1.0, 1.0]:
				r.box(Vector3(sx * 0.09, 1.42, 0.03), Vector3(0.05, 0.02, 0.24), Basis(Vector3.RIGHT, 0.25))   # harness straps
			r.box(Vector3(0, 1.32, -0.13), Vector3(0.22, 0.02, 0.04))
			r.set_c(pc)
			for k in 4:
				r.box(Vector3((k - 1.5) * 0.07, 1.27, 0.168), Vector3(0.06, 0.12, 0.035))
		"vest":     # light load-bearing vest (engineers, specialists)
			r.set_c(ac, cm)
			r.box(Vector3(0, 1.33, 0.125), Vector3(0.29, 0.26, 0.04))
			r.box(Vector3(0, 1.35, -0.12), Vector3(0.29, 0.28, 0.035))
			r.set_c(pc)
			for k in 2:
				r.box(Vector3((k - 0.5) * 0.12, 1.25, 0.155), Vector3(0.09, 0.09, 0.04))
	if spec.has("chest_extra"):
		for e in spec["chest_extra"]:
			match e:
				"controller":
					r.set_c("#2a2c2a")
					r.box(Vector3(0, 1.38, 0.2), Vector3(0.18, 0.11, 0.03), Basis(Vector3.RIGHT, -0.5))
					r.set_c("#7fd0ff")
					r.box(Vector3(0, 1.39, 0.214), Vector3(0.13, 0.07, 0.006), Basis(Vector3.RIGHT, -0.5))
				"binoculars":
					r.set_c("#24261f")
					for sx in [-1.0, 1.0]:
						r.cyl(Vector3(sx * 0.025, 1.45, 0.16), Vector3(sx * 0.025, 1.45, 0.22), 0.02)
				"ammo_belt":
					r.set_c("#8a7440")
					r.loft(Vector3(-0.16, 1.48, 0.04), Vector3(0.17, 1.12, 0.1), [[0.0, 0.03, 0.012], [1.0, 0.03, 0.012]], Vector3.FORWARD, 6)
				"satchel":
					r.set_c(spec.get("pouch", "#444"))
					r.box(Vector3(0.18, 1.08, 0.02), Vector3(0.06, 0.16, 0.2))
					r.loft(Vector3(0.17, 1.12, 0.0), Vector3(-0.15, 1.5, 0.0), [[0.0, 0.025, 0.01], [1.0, 0.025, 0.01]], Vector3.FORWARD, 5)

# ------------------------------------------------------------------ back (per variant)
static func _back(r, spec: Dictionary) -> void:
	var backs: Array = spec.get("backs", [""])
	var masks := _masks(backs)
	var pk: String = spec.get("pack", spec.get("carrier", "#5a5440"))
	for kind in masks:
		var vm: int = masks[kind]
		for part in String(kind).split("+", false):
			match part:
				"pack":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.3, -0.215), Vector3(0.27, 0.32, 0.13))
					r.box(Vector3(0, 1.47, -0.2), Vector3(0.25, 0.05, 0.12))
					r.box(Vector3(0, 1.24, -0.29), Vector3(0.2, 0.15, 0.04))
				"bigpack":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.27, -0.25), Vector3(0.32, 0.46, 0.2))
					r.box(Vector3(0, 1.52, -0.24), Vector3(0.3, 0.06, 0.18))
					r.set_c(spec.get("pouch", pk), 0, vm)
					for sx in [-1.0, 1.0]:
						r.box(Vector3(sx * 0.18, 1.22, -0.25), Vector3(0.05, 0.2, 0.12))
				"hydration":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.35, -0.17), Vector3(0.18, 0.28, 0.05))
				"radio":
					r.set_c("#3a3d34", 0, vm)
					r.box(Vector3(0, 1.3, -0.22), Vector3(0.22, 0.3, 0.13))
					r.set_c("#141516", 0, vm)
					r.cyl(Vector3(-0.08, 1.44, -0.24), Vector3(-0.12, 2.25, -0.32), 0.006, 0.003, 4)   # whip antenna
					r.cyl(Vector3(0.07, 1.44, -0.24), Vector3(0.08, 1.7, -0.25), 0.008, 0.006, 4)
				"rockets":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.28, -0.2), Vector3(0.26, 0.3, 0.12))
					r.set_c("#5d6340", 0, vm)
					for sx in [-1.0, 1.0]:
						var b0 := Vector3(sx * 0.07, 1.22, -0.28)
						r.cyl(b0, b0 + Vector3(0, 0.38, 0), 0.045, 0.045, 8)
						r.cyl(b0 + Vector3(0, 0.38, 0), b0 + Vector3(0, 0.5, 0), 0.045, 0.006, 8)
				"tube":
					r.set_c(spec.get("tube", "#555b47"), 0, vm)
					r.cyl(Vector3(-0.16, 1.05, -0.24), Vector3(0.2, 1.6, -0.24), 0.06, 0.06, 10)
				"tools":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.3, -0.22), Vector3(0.28, 0.34, 0.14))
					r.set_c("#c8742a", 0, vm)
					r.box(Vector3(0, 1.4, -0.296), Vector3(0.2, 0.03, 0.01))     # hi-vis strip
					r.set_c("#6b5236", 0, vm)
					r.cyl(Vector3(0.12, 1.08, -0.3), Vector3(-0.1, 1.62, -0.3), 0.014, 0.014, 6)   # e-tool handle
					r.set_c("#3a3d40", 0, vm)
					r.box(Vector3(0.14, 1.03, -0.3), Vector3(0.12, 0.13, 0.012), Basis(Vector3.FORWARD, 0.4))
				"ghillie":
					for k in 16:
						var a := TAU * k / 16.0
						var p0 := Vector3(cos(a) * 0.17, 1.46, sin(a) * 0.12 - 0.01)
						r.set_c("#4a5133" if k % 2 == 0 else "#6a6a44", 0, vm)
						var tip := p0 + Vector3(cos(a) * 0.05, -0.3 - 0.06 * sin(k * 2.1), sin(a) * 0.04)
						r.loft(p0, tip, [[0.0, 0.03, 0.006], [1.0, 0.008, 0.004]], Vector3(-sin(a), 0, cos(a)), 4)
					r.set_c("#5f6640", 0, vm)
					r.box(Vector3(0, 1.36, -0.17), Vector3(0.3, 0.3, 0.05))
				"mgbox":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.3, -0.215), Vector3(0.27, 0.32, 0.13))
					r.set_c("#4f5634", 0, vm)
					r.box(Vector3(0.0, 1.0, 0.0) + Vector3(0.2, 0.0, 0.05), Vector3(0.07, 0.1, 0.12))
				"satchel_back":
					r.set_c(pk, 0, vm)
					r.box(Vector3(0, 1.28, -0.19), Vector3(0.22, 0.24, 0.09))

## parts -> variant mask, for a list of 4 (or fewer) per-variant options
static func _masks(opts: Array) -> Dictionary:
	if opts.size() <= 1:
		var one := {}
		for p in (String(opts[0]) if not opts.is_empty() else "").split("+", false):
			one[p] = 0
		return one
	var out := {}
	for v in 4:
		var k: String = opts[v % opts.size()]
		out[k] = int(out.get(k, 0)) | (1 << v)
	# split shared parts so a part common to several variants is drawn once
	var parts := {}
	for k in out:
		for p in String(k).split("+", false):
			parts[p] = int(parts.get(p, 0)) | int(out[k])
	var res := {}
	for p in parts:
		res[p] = 0 if parts[p] == 15 else parts[p]
	return res

# ------------------------------------------------------------------ heads (per variant)
static func _heads(r, spec: Dictionary) -> void:
	var masks := _masks(spec.get("heads", ["helmet"]))
	var hc: String = spec.get("helmet", spec["jacket"])
	var cm := _cam(spec)
	var hair: String = spec.get("hair", "#2b231d")
	for part in masks:
		var vm: int = masks[part]
		match part:
			"helmet", "helmet_ru":
				r.set_c(hc, cm, vm)
				var hr := Vector3(0.112, 0.106, 0.128) if part == "helmet" else Vector3(0.116, 0.112, 0.13)
				r.dome(Vector3(0, 1.705, -0.006), hr, 1.72, 5, 14)
				r.set_c(hc, 0, vm)
				r.loft(Vector3(0, 1.69, -0.006), Vector3(0, 1.715, -0.006), [[0.0, hr.x * 1.02, hr.z * 1.02], [1.0, hr.x * 1.015, hr.z * 1.015]], Vector3.RIGHT, 14)   # rim
				r.set_c("#cccccc", TEAM, vm)
				r.loft(Vector3(0, 1.75, -0.006), Vector3(0, 1.768, -0.006), [[0.0, hr.x * 0.95, hr.z * 0.95], [1.0, hr.x * 0.93, hr.z * 0.93]], Vector3.RIGHT, 14)   # team band
				r.set_c("#2a2a26", 0, vm)
				r.box(Vector3(0, 1.66, -0.112), Vector3(0.06, 0.05, 0.02))   # counterweight / strap
				for sx in [-1.0, 1.0]:
					r.box(Vector3(sx * 0.075, 1.63, 0.03), Vector3(0.008, 0.08, 0.014), Basis(Vector3.RIGHT, 0.35))   # chin strap
				if part == "helmet":
					r.set_c("#1c1d1e", 0, vm)
					for sx in [-1.0, 1.0]:
						r.box(Vector3(sx * 0.1, 1.74, -0.01), Vector3(0.02, 0.025, 0.09))   # side rails
			"nvg":
				r.set_c("#141516", 0, vm)
				r.box(Vector3(0, 1.77, 0.118), Vector3(0.045, 0.04, 0.025))
			"goggles":
				r.set_c("#33332e", 0, vm)
				r.box(Vector3(0, 1.775, 0.105), Vector3(0.14, 0.035, 0.035), Basis(Vector3.RIGHT, 0.3))
				r.set_c("#3a5060", 0, vm)
				r.box(Vector3(0, 1.776, 0.124), Vector3(0.11, 0.024, 0.006), Basis(Vector3.RIGHT, 0.3))
			"headset":
				r.set_c("#1c1d1e", 0, vm)
				for sx in [-1.0, 1.0]:
					r.ellipsoid(Vector3(sx * 0.095, 1.68, 0.0), Vector3(0.022, 0.04, 0.036), Basis(), 3, 8)
				r.cyl(Vector3(-0.1, 1.66, 0.02), Vector3(-0.045, 1.62, 0.1), 0.004, 0.004, 4)   # boom mic
			"boonie":
				r.set_c(hc, cm, vm)
				r.dome(Vector3(0, 1.73, -0.004), Vector3(0.094, 0.075, 0.105), 1.6, 4, 12)
				r.loft(Vector3(0, 1.725, -0.004), Vector3(0, 1.735, -0.004), [[0.0, 0.17, 0.18], [1.0, 0.165, 0.175]], Vector3.RIGHT, 14)   # brim
			"cap":
				r.set_c(hc, cm, vm)
				r.dome(Vector3(0, 1.72, -0.004), Vector3(0.088, 0.075, 0.1), 1.6, 4, 12)
				r.box(Vector3(0, 1.738, 0.11), Vector3(0.12, 0.012, 0.07), Basis(Vector3.RIGHT, 0.12))   # visor
			"shemagh":
				r.set_c(spec.get("wrap", "#c9bfa5"), 0, vm)
				r.dome(Vector3(0, 1.71, -0.006), Vector3(0.096, 0.1, 0.108), 1.85, 5, 12)
				r.ellipsoid(Vector3(0, 1.63, 0.025), Vector3(0.074, 0.06, 0.079), Basis(), 4, 10)   # face cover
				r.set_c(spec.get("wrap2", "#8f3a2e"), 0, vm)
				r.box(Vector3(0.03, 1.57, -0.08), Vector3(0.1, 0.12, 0.02), Basis(Vector3.RIGHT, 0.4))   # tail
			"balaclava":
				r.set_c("#1c1d1c", 0, vm)
				r.dome(Vector3(0, 1.7, -0.002), Vector3(0.086, 0.115, 0.1), 2.3, 6, 12)
			"beanie":
				r.set_c(spec.get("wrap", "#3a3d34"), 0, vm)
				r.dome(Vector3(0, 1.715, -0.004), Vector3(0.088, 0.09, 0.1), 1.6, 4, 12)
			"hair":
				r.set_c(hair, 0, vm)
				r.dome(Vector3(0, 1.705, -0.01), Vector3(0.084, 0.108, 0.1), 1.45, 4, 12)
			"beard":
				r.set_c(hair, 0, vm)
				r.ellipsoid(Vector3(0, 1.625, 0.036), Vector3(0.07, 0.05, 0.068), Basis(), 4, 10)
			"wrap":   # turban-like head wrap
				r.set_c(spec.get("wrap", "#c9bfa5"), 0, vm)
				r.dome(Vector3(0, 1.72, -0.006), Vector3(0.1, 0.085, 0.11), 1.75, 4, 12)
				r.set_c(spec.get("wrap2", "#8f3a2e"), 0, vm)
				r.loft(Vector3(0, 1.72, -0.006), Vector3(0, 1.74, -0.006), [[0.0, 0.103, 0.113], [1.0, 0.1, 0.11]], Vector3.RIGHT, 12)
