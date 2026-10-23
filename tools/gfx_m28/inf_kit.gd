extends RefCounted
## M2.8 infantry detail kit (tool-time only, original procedural parts): specific weapon models
## built in metres (+Z = muzzle, +Y = up, origin = pistol grip) and faction gear (helmets, plate
## carriers, pouches, packs, radio, ghillie, head wraps). Parts are low-poly boxes / cylinders /
## cones with flat part colours; tools/bake_infantry.gd skins them rigidly to the hand / torso /
## head bones and bakes them into the soldier's VAT. Colour alpha 1 = team colour.
var P := PackedVector3Array()
var N := PackedVector3Array()
var C := PackedColorArray()
var I := PackedInt32Array()
var xf := Transform3D.IDENTITY
var col := Color.BLACK

func color(c: Variant, team := false) -> void:
	col = Color(c) if c is String else c
	col.a = 1.0 if team else 0.0

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (xf.basis * (b - a).cross(c - a)).normalized()
	var base := P.size()
	for v in [a, b, c, d]:
		P.append(xf * v)
		N.append(n)
		C.append(col)
	I.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

func box(c: Vector3, s: Vector3) -> void:
	var h := s * 0.5
	var v := []
	for k in 8:
		v.append(c + Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
	_quad(v[0], v[2], v[3], v[1]); _quad(v[4], v[5], v[7], v[6])   # -z, +z
	_quad(v[0], v[1], v[5], v[4]); _quad(v[2], v[6], v[7], v[3])   # -y, +y
	_quad(v[0], v[4], v[6], v[2]); _quad(v[1], v[3], v[7], v[5])   # -x, +x

## Cylinder / cone frustum between p0 and p1.
func cyl(p0: Vector3, p1: Vector3, r0: float, r1: float = -1.0, seg := 8, caps := true) -> void:
	if r1 < 0.0:
		r1 = r0
	var ax := (p1 - p0).normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := ax.cross(u)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := u * cos(a0) + w * sin(a0)
		var d1 := u * cos(a1) + w * sin(a1)
		_quad(p0 + d0 * r0, p0 + d1 * r0, p1 + d1 * r1, p1 + d0 * r1)
		if caps:
			var base := P.size()
			for v in [p1, p1 + d0 * r1, p1 + d1 * r1, p0, p0 + d1 * r0, p0 + d0 * r0]:
				P.append(xf * v)
				C.append(col)
			N.append_array([xf.basis * ax, xf.basis * ax, xf.basis * ax, xf.basis * -ax, xf.basis * -ax, xf.basis * -ax])
			I.append_array([base, base + 1, base + 2, base + 3, base + 4, base + 5])

func tris() -> int:
	return I.size() / 3

# ================================================================== weapons (metres)
const BLK := "#1e1f21"
const STEEL := "#3a3d40"
const WOOD := "#7a4a26"
const OD := "#4f5634"
const TAN := "#9b8560"

func _scope(z0: float, z1: float, y: float, r: float) -> void:
	color("#141516")
	cyl(Vector3(0, y, z0), Vector3(0, y, z1), r, r, 8)
	cyl(Vector3(0, y, z1), Vector3(0, y, z1 + 0.05), r * 1.35, r * 1.35, 8)
	cyl(Vector3(0, y, z0 - 0.05), Vector3(0, y, z0), r * 1.2, r * 1.2, 8)
	box(Vector3(0, y - r - 0.01, (z0 + z1) * 0.5), Vector3(0.025, 0.03, 0.06))

## M16A4-style: long 20" barrel, carry rail, triangular-ish handguard, fixed stock, 30-rd mag.
func m16() -> void:
	color(BLK)
	box(Vector3(0, 0.05, 0.05), Vector3(0.05, 0.08, 0.28))                    # receiver
	box(Vector3(0, 0.1, 0.05), Vector3(0.03, 0.03, 0.26))                     # flat-top rail
	box(Vector3(0, 0.055, 0.34), Vector3(0.06, 0.065, 0.3))                   # handguard
	color(STEEL)
	cyl(Vector3(0, 0.06, 0.48), Vector3(0, 0.06, 0.72), 0.009)                 # barrel
	box(Vector3(0, 0.1, 0.5), Vector3(0.012, 0.07, 0.02))                     # front sight post
	cyl(Vector3(0, 0.06, 0.72), Vector3(0, 0.06, 0.77), 0.013)                 # flash hider
	color(BLK)
	box(Vector3(0, 0.03, -0.24), Vector3(0.045, 0.08, 0.32))                  # fixed stock
	box(Vector3(0, -0.06, 0.08), Vector3(0.03, 0.15, 0.07))                   # STANAG mag
	box(Vector3(0, -0.04, -0.03), Vector3(0.03, 0.09, 0.04))                  # pistol grip
	box(Vector3(0, 0.125, 0.06), Vector3(0.035, 0.035, 0.08))                 # optic

## M4A1-style carbine: short barrel, collapsible stock, RIS, red-dot + PEQ box.
func m4() -> void:
	color(BLK)
	box(Vector3(0, 0.05, 0.05), Vector3(0.05, 0.08, 0.26))
	box(Vector3(0, 0.1, 0.12), Vector3(0.03, 0.03, 0.38))
	box(Vector3(0, 0.055, 0.29), Vector3(0.06, 0.07, 0.2))
	color(STEEL)
	cyl(Vector3(0, 0.06, 0.39), Vector3(0, 0.06, 0.55), 0.009)
	cyl(Vector3(0, 0.06, 0.55), Vector3(0, 0.06, 0.6), 0.013)
	color(BLK)
	box(Vector3(0, 0.05, -0.12), Vector3(0.03, 0.03, 0.14))                   # buffer tube
	box(Vector3(0, 0.03, -0.22), Vector3(0.045, 0.08, 0.1))                   # collapsible stock
	box(Vector3(0, -0.06, 0.08), Vector3(0.03, 0.15, 0.07))
	box(Vector3(0, -0.04, -0.03), Vector3(0.03, 0.09, 0.04))
	color(TAN)
	box(Vector3(0.04, 0.07, 0.3), Vector3(0.025, 0.035, 0.08))                # PEQ laser box
	color("#141516")
	box(Vector3(0, 0.13, 0.05), Vector3(0.035, 0.04, 0.07))                   # red dot
	cyl(Vector3(0, 0.0, 0.25), Vector3(0, -0.1, 0.25), 0.015)                 # vertical grip

## Javelin-style CLU + launch tube: fat 1.2 m tube with end caps, sight unit on the left.
func javelin() -> void:
	color(OD)
	cyl(Vector3(0.0, 0.11, -0.55), Vector3(0.0, 0.11, 0.65), 0.075, 0.075, 10)
	color("#3e4329")
	cyl(Vector3(0.0, 0.11, -0.6), Vector3(0.0, 0.11, -0.55), 0.09, 0.09, 10)
	cyl(Vector3(0.0, 0.11, 0.65), Vector3(0.0, 0.11, 0.7), 0.09, 0.09, 10)
	box(Vector3(0.0, 0.11, 0.05), Vector3(0.19, 0.04, 0.05))                  # strap band
	color("#2c2f24")
	box(Vector3(-0.15, 0.13, 0.05), Vector3(0.12, 0.14, 0.24))                # command launch unit
	cyl(Vector3(-0.15, 0.15, 0.17), Vector3(-0.15, 0.15, 0.24), 0.04)         # CLU optic
	box(Vector3(-0.15, 0.02, 0.0), Vector3(0.03, 0.1, 0.04))                  # CLU grip
	color("#141516")
	box(Vector3(-0.15, 0.2, -0.05), Vector3(0.08, 0.04, 0.06))                # eyepiece

## Bolt-action scoped sniper rifle (M40-style): heavy barrel, OD/tan stock, big scope, bipod.
func sniper() -> void:
	color(TAN)
	box(Vector3(0, 0.03, 0.08), Vector3(0.055, 0.07, 0.62))                   # stock + fore-end
	box(Vector3(0, 0.0, -0.3), Vector3(0.05, 0.12, 0.24))                     # butt
	box(Vector3(0, -0.05, -0.02), Vector3(0.035, 0.08, 0.05))                 # grip
	color(STEEL)
	cyl(Vector3(0, 0.07, 0.0), Vector3(0, 0.07, 0.2), 0.02)                   # action
	cyl(Vector3(0, 0.07, 0.2), Vector3(0, 0.07, 0.82), 0.012)                 # heavy barrel
	cyl(Vector3(0, 0.07, 0.82), Vector3(0, 0.07, 0.88), 0.017)                # suppressor stub
	box(Vector3(0.04, 0.07, 0.02), Vector3(0.04, 0.012, 0.012))               # bolt handle
	_scope(-0.04, 0.24, 0.13, 0.024)
	color(BLK)
	for s in [-1.0, 1.0]:
		cyl(Vector3(0, 0.02, 0.4), Vector3(s * 0.05, -0.16, 0.48), 0.006, 0.006, 5)   # bipod legs

## AK-pattern rifle: wood furniture, curved steel mag, gas tube, slant brake.
func ak() -> void:
	color(STEEL)
	box(Vector3(0, 0.05, 0.05), Vector3(0.05, 0.075, 0.3))
	cyl(Vector3(0, 0.06, 0.4), Vector3(0, 0.06, 0.62), 0.009)
	cyl(Vector3(0, 0.1, 0.2), Vector3(0, 0.1, 0.42), 0.011)                   # gas tube
	box(Vector3(0, 0.1, 0.52), Vector3(0.012, 0.05, 0.02))
	cyl(Vector3(0, 0.06, 0.62), Vector3(0, 0.06, 0.67), 0.013)
	color(WOOD)
	box(Vector3(0, 0.05, 0.3), Vector3(0.058, 0.06, 0.18))                    # handguard
	box(Vector3(0, 0.02, -0.25), Vector3(0.045, 0.09, 0.3))                   # stock
	box(Vector3(0, -0.04, -0.03), Vector3(0.03, 0.09, 0.04))
	color("#5c3a22")
	for k in 5:                                                               # curved magazine
		var a := k * 0.09
		box(Vector3(0, -0.02 - k * 0.035, 0.09 + a * 0.35 + k * 0.012), Vector3(0.03, 0.04, 0.065))

## RPG-7-style: tube with flared venturi, grips, optic, warhead with fins.
func rpg() -> void:
	color("#4d5236")
	cyl(Vector3(0, 0.1, -0.5), Vector3(0, 0.1, 0.4), 0.032, 0.032, 8)
	cyl(Vector3(0, 0.1, -0.62), Vector3(0, 0.1, -0.5), 0.065, 0.034, 8)       # venturi
	color(WOOD)
	cyl(Vector3(0, 0.1, -0.15), Vector3(0, 0.1, 0.12), 0.042, 0.042, 8)       # wood heat guard
	color(BLK)
	box(Vector3(0, 0.0, -0.02), Vector3(0.03, 0.12, 0.04))
	box(Vector3(0, 0.0, 0.2), Vector3(0.03, 0.1, 0.04))
	box(Vector3(-0.05, 0.15, 0.05), Vector3(0.03, 0.05, 0.1))                 # PGO-7 sight
	color("#5d6340")
	cyl(Vector3(0, 0.1, 0.4), Vector3(0, 0.1, 0.5), 0.03, 0.05, 8)
	cyl(Vector3(0, 0.1, 0.5), Vector3(0, 0.1, 0.62), 0.05, 0.05, 8)           # warhead
	cyl(Vector3(0, 0.1, 0.62), Vector3(0, 0.1, 0.74), 0.05, 0.008, 8)

## SVD-pattern marksman rifle (kept in the kit for a future TPLA marksman; no unit uses it yet).
func svd() -> void:
	color(STEEL)
	box(Vector3(0, 0.05, 0.08), Vector3(0.05, 0.075, 0.32))
	cyl(Vector3(0, 0.06, 0.45), Vector3(0, 0.06, 0.95), 0.01)
	color(WOOD)
	box(Vector3(0, 0.05, 0.35), Vector3(0.058, 0.065, 0.22))
	box(Vector3(0, 0.0, -0.22), Vector3(0.04, 0.06, 0.3))                     # skeleton stock
	box(Vector3(0, 0.08, -0.25), Vector3(0.04, 0.03, 0.22))
	box(Vector3(0, -0.06, 0.08), Vector3(0.03, 0.12, 0.06))
	_scope(0.0, 0.22, 0.13, 0.02)

## EU assault rifle (G36-style): polymer body, carry handle optic, underslung 40 mm launcher.
func eu_rifle_gl() -> void:
	color("#3f443b")
	box(Vector3(0, 0.05, 0.08), Vector3(0.055, 0.09, 0.42))
	box(Vector3(0, 0.03, -0.22), Vector3(0.04, 0.09, 0.22))                   # folding stock
	box(Vector3(0, 0.14, 0.05), Vector3(0.03, 0.05, 0.22))                    # carry handle
	box(Vector3(0, -0.07, 0.1), Vector3(0.03, 0.14, 0.06))                    # translucent mag
	box(Vector3(0, -0.04, -0.03), Vector3(0.03, 0.09, 0.04))
	color(STEEL)
	cyl(Vector3(0, 0.06, 0.29), Vector3(0, 0.06, 0.6), 0.009)
	color("#2e322b")
	cyl(Vector3(0, -0.015, 0.22), Vector3(0, -0.015, 0.45), 0.024, 0.024, 8)  # AG36-style launcher

## EU light anti-tank launcher (NLAW-style): short fat tube, sight block, tan end caps.
func eu_launcher() -> void:
	color("#555b47")
	cyl(Vector3(0, 0.1, -0.45), Vector3(0, 0.1, 0.55), 0.06, 0.06, 10)
	color(TAN)
	cyl(Vector3(0, 0.1, -0.52), Vector3(0, 0.1, -0.45), 0.075, 0.075, 10)
	cyl(Vector3(0, 0.1, 0.55), Vector3(0, 0.1, 0.62), 0.075, 0.075, 10)
	color(BLK)
	box(Vector3(-0.07, 0.15, 0.05), Vector3(0.06, 0.07, 0.14))
	box(Vector3(0, 0.0, 0.0), Vector3(0.03, 0.1, 0.04))
	box(Vector3(0, 0.0, 0.22), Vector3(0.03, 0.09, 0.04))

# ================================================================== gear (model space)
## b: body box in model space (position = feet-centre-ish AABB), front = +z.
func gear(kind: String, b: AABB, colr: String, accent: String) -> void:
	var c := b.get_center()
	var h := b.size.y
	var w := b.size.x
	var chest := Vector3(c.x, b.position.y + h * 0.66, c.z)
	var d := minf(b.size.z, w) * 0.5
	match kind:
		"plate_carrier":
			color(colr)
			box(chest + Vector3(0, 0, d * 0.42), Vector3(w * 0.36, h * 0.17, d * 0.25))      # front plate
			box(chest + Vector3(0, 0, -d * 0.42), Vector3(w * 0.36, h * 0.17, d * 0.25))     # back plate
			color(accent)
			for k in 3:
				box(chest + Vector3((k - 1) * w * 0.11, -h * 0.055, d * 0.6), Vector3(w * 0.09, h * 0.07, d * 0.18))   # mag pouches
		"chest_rig":
			color(colr)
			box(chest + Vector3(0, -h * 0.04, d * 0.46), Vector3(w * 0.38, h * 0.1, d * 0.28))
			color(accent)
			for k in 3:
				box(chest + Vector3((k - 1) * w * 0.12, -h * 0.04, d * 0.64), Vector3(w * 0.1, h * 0.09, d * 0.16))
		"pack":
			color(colr)
			box(chest + Vector3(0, -h * 0.02, -d * 0.78), Vector3(w * 0.34, h * 0.2, d * 0.45))
			color(accent)
			box(chest + Vector3(0, h * 0.09, -d * 0.82), Vector3(w * 0.3, h * 0.035, d * 0.4))
		"radio":
			color(colr)
			box(chest + Vector3(0, -h * 0.01, -d * 0.82), Vector3(w * 0.3, h * 0.22, d * 0.5))
			color("#141516")
			cyl(chest + Vector3(w * 0.1, h * 0.1, -d * 0.9), chest + Vector3(w * 0.14, h * 0.62, -d * 1.0), 0.004 * h / 0.5 * 2.5, 0.002 * h / 0.5 * 2.5, 4, false)
			color(accent, true)
			box(chest + Vector3(0, h * 0.05, -d * 0.55), Vector3(w * 0.2, h * 0.03, d * 0.1))  # team panel
		"ghillie":
			color("#4a5133")
			for k in 9:
				var a := TAU * k / 9.0
				var p := chest + Vector3(cos(a) * w * 0.22, h * 0.12, sin(a) * d * 0.7)
				cyl(p, p + Vector3(cos(a) * w * 0.08, -h * 0.2, sin(a) * d * 0.25), w * 0.06, w * 0.01, 4, false)
			color("#5f6640")
			box(chest + Vector3(0, h * 0.18, -d * 0.4), Vector3(w * 0.4, h * 0.06, d * 0.9))     # hood / veil
		"rocket_pack":
			color(colr)
			box(chest + Vector3(0, -h * 0.02, -d * 0.75), Vector3(w * 0.3, h * 0.2, d * 0.4))
			color("#5d6340")
			for s in [-1.0, 1.0]:
				var p0 := chest + Vector3(s * w * 0.09, -h * 0.12, -d * 0.95)
				cyl(p0, p0 + Vector3(0, h * 0.34, 0), w * 0.05, w * 0.05, 6)
				cyl(p0 + Vector3(0, h * 0.34, 0), p0 + Vector3(0, h * 0.42, 0), w * 0.05, w * 0.01, 6)
		"spare_tube":
			color(colr)
			cyl(chest + Vector3(-w * 0.15, -h * 0.18, -d * 0.85), chest + Vector3(w * 0.18, h * 0.22, -d * 0.85), w * 0.07, w * 0.07, 8)
		"canteen":
			color(colr)
			cyl(Vector3(c.x + w * 0.2, b.position.y + h * 0.5, c.z - d * 0.3), Vector3(c.x + w * 0.2, b.position.y + h * 0.56, c.z - d * 0.3), w * 0.06, w * 0.06, 6)

## Head gear around the head box (model space).
func headgear(kind: String, hb: AABB, colr: String, accent: String) -> void:
	var c := hb.get_center()
	var s := hb.size
	match kind:
		"helmet_cover":   # helmet cover band + NVG mount + goggles strap
			color(colr)
			box(c + Vector3(0, s.y * 0.12, 0), Vector3(s.x * 1.03, s.y * 0.07, s.z * 1.03))   # helmet band
			color("#141516")
			box(c + Vector3(0, s.y * 0.2, s.z * 0.5), Vector3(s.x * 0.16, s.y * 0.1, s.z * 0.08))   # NVG mount
		"headset":
			color("#1c1d1e")
			for sx in [-1.0, 1.0]:
				box(c + Vector3(sx * s.x * 0.52, 0, 0), Vector3(s.x * 0.12, s.y * 0.3, s.z * 0.3))
			cyl(c + Vector3(s.x * 0.5, -s.y * 0.05, s.z * 0.1), c + Vector3(s.x * 0.2, -s.y * 0.25, s.z * 0.55), s.x * 0.03, s.x * 0.03, 4, false)
		"wrap":            # shemagh head wrap with a tail
			color(colr)
			box(c + Vector3(0, -s.y * 0.15, s.z * 0.1), Vector3(s.x * 1.1, s.y * 0.35, s.z * 1.0))
			color(accent)
			box(c + Vector3(s.x * 0.15, -s.y * 0.45, -s.z * 0.5), Vector3(s.x * 0.35, s.y * 0.4, s.z * 0.12))
		"beret":
			color(colr, true)
			box(c + Vector3(-s.x * 0.08, s.y * 0.45, 0), Vector3(s.x * 1.0, s.y * 0.12, s.z * 1.0))
