extends RefCounted
## M3.4 infantry overhaul (tool-time only, all original procedural work): a realistic soldier
## built from smooth lofted body parts on our own 18-bone rig, posed by our own keyframe /
## two-bone-IK animation code (two-handed weapon holds, aim, kneel, walk, run, deaths), then
## baked into VAT textures by tools/bake_infantry_m34.gd. Metres, +Y up, the soldier faces +Z,
## his right side is -X. Weapons come from the M2.8 procedural kit (tools/gfx_m28/inf_kit.gd),
## mirrored into this right-handed frame.
enum { PELVIS, SPINE, CHEST, NECK, HEAD, UARM_L, FARM_L, HAND_L, UARM_R, FARM_R, HAND_R,
	THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R, GUN, NB }
const PARENT := [-1, PELVIS, SPINE, CHEST, NECK, CHEST, UARM_L, FARM_L, CHEST, UARM_R, FARM_R,
	PELVIS, THIGH_L, SHIN_L, PELVIS, THIGH_R, SHIN_R, -1]
## rest joints (metres): a 1.80 m adult, ~7.6 heads tall
const J := {
	"pelvis": Vector3(0, 1.0, 0), "spine": Vector3(0, 1.1, 0), "chest": Vector3(0, 1.3, 0),
	"neck": Vector3(0, 1.5, 0), "head": Vector3(0, 1.58, 0.0),
	"sh_L": Vector3(0.19, 1.45, -0.01), "el_L": Vector3(0.22, 1.14, -0.02), "wr_L": Vector3(0.24, 0.87, 0.0),
	"sh_R": Vector3(-0.19, 1.45, -0.01), "el_R": Vector3(-0.22, 1.14, -0.02), "wr_R": Vector3(-0.24, 0.87, 0.0),
	"hip_L": Vector3(0.1, 0.95, 0), "kn_L": Vector3(0.11, 0.52, 0.01), "an_L": Vector3(0.11, 0.09, -0.01),
	"hip_R": Vector3(-0.1, 0.95, 0), "kn_R": Vector3(-0.11, 0.52, 0.01), "an_R": Vector3(-0.11, 0.09, -0.01)}
const HAND_LEN := 0.085   ## wrist to palm centre

# ------------------------------------------------------------------ mesh buffers
var P := PackedVector3Array()
var N := PackedVector3Array()
var C := PackedColorArray()
var F := PackedInt32Array()      ## flags: 1 team, 2 skin, 4 camo, 8 fine camo
var VM := PackedInt32Array()     ## variant mask (bit v = shown on variant v; 0 = always)
var B0 := PackedInt32Array()
var B1 := PackedInt32Array()
var W1 := PackedFloat32Array()   ## weight of B1
var I := PackedInt32Array()
var col := Color.WHITE
var flags := 0
var vmask := 0
var bone := CHEST
var rest: Array = []             ## rest global Transform3D per bone

func _init() -> void:
	rest.resize(NB)
	rest[PELVIS] = Transform3D(Basis(), J["pelvis"])
	rest[SPINE] = Transform3D(Basis(), J["spine"])
	rest[CHEST] = Transform3D(Basis(), J["chest"])
	rest[NECK] = Transform3D(Basis(), J["neck"])
	rest[HEAD] = Transform3D(Basis(), J["head"])
	for s in ["L", "R"]:
		var o := 0 if s == "L" else 3
		var sx := 1.0 if s == "L" else -1.0
		var arm_pole := Vector3(sx * 0.3, 0, -1)
		rest[UARM_L + o] = Transform3D(limb_basis(J["el_" + s] - J["sh_" + s], arm_pole), J["sh_" + s])
		rest[FARM_L + o] = Transform3D(limb_basis(J["wr_" + s] - J["el_" + s], arm_pole), J["el_" + s])
		rest[HAND_L + o] = Transform3D(rest[FARM_L + o].basis, J["wr_" + s])
		var leg_pole := Vector3(0, 0, 1)
		rest[THIGH_L + o] = Transform3D(limb_basis(J["kn_" + s] - J["hip_" + s], leg_pole), J["hip_" + s])
		rest[SHIN_L + o] = Transform3D(limb_basis(J["an_" + s] - J["kn_" + s], leg_pole), J["kn_" + s])
		rest[FOOT_L + o] = Transform3D(Basis(), J["an_" + s])
	rest[GUN] = Transform3D()

## basis whose -Y runs along `dir` and whose +Z leans toward `pole`
static func limb_basis(dir: Vector3, pole: Vector3) -> Basis:
	var y := -dir.normalized()
	var z := (pole - y * pole.dot(y))
	if z.length_squared() < 1e-8:
		z = Vector3.FORWARD
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)

func set_c(c: Variant, fl := 0, vm := 0) -> void:
	col = Color(c) if c is String else c
	flags = fl
	vmask = vm

func _v(p: Vector3, n: Vector3, b0: int, b1 := -1, w := 0.0) -> int:
	P.append(p)
	N.append(n.normalized())
	C.append(col)
	F.append(flags)
	VM.append(vmask)
	B0.append(b0)
	B1.append(b1 if b1 >= 0 else b0)
	W1.append(w if b1 >= 0 else 0.0)
	return P.size() - 1

func tris() -> int:
	return I.size() / 3

## Smooth lofted tube along an arbitrary axis. rings: [[t (0..1 along a->b), rx, rz], ...]
## with rx across `side` and rz across the third axis; ends closed. blend: [parent bone, child
## bone] - vertices near the ends lean into the neighbouring bone so joints bend smoothly.
func loft(a: Vector3, b: Vector3, rings: Array, side: Vector3, seg := 10, blend := [-1, -1], ofs := Vector3.ZERO) -> void:
	var ax := (b - a)
	var L := ax.length()
	var z := ax / L
	var x := (side - z * side.dot(z)).normalized()
	var y := z.cross(x)
	var base := P.size()
	var nr := rings.size()
	for r in nr:
		var rg: Array = rings[r]
		var t: float = rg[0]
		var c: Vector3 = a + ax * t + ofs * (float(rg[3]) if rg.size() > 3 else 0.0)
		var b1 := -1
		var w := 0.0
		if blend[0] >= 0 and t < 0.25:
			b1 = blend[0]
			w = 0.5 * (1.0 - smoothstep(-0.05, 0.25, t))
		elif blend[1] >= 0 and t > 0.75:
			b1 = blend[1]
			w = 0.5 * smoothstep(0.75, 1.05, t)
		# normal tilt from the radius slope
		var r0: Array = rings[maxi(0, r - 1)]
		var r1: Array = rings[mini(nr - 1, r + 1)]
		var dt := maxf(1e-4, (float(r1[0]) - float(r0[0])) * L)
		var slx := (float(r1[1]) - float(r0[1])) / dt
		var slz := (float(r1[2]) - float(r0[2])) / dt
		for s in seg:
			var an := TAU * s / seg
			var ca := cos(an)
			var sa := sin(an)
			var p := c + x * (ca * float(rg[1])) + y * (sa * float(rg[2]))
			var rx := maxf(1e-4, float(rg[1]))
			var rz := maxf(1e-4, float(rg[2]))
			var n := x * (ca / rx) + y * (sa / rz)
			n = n.normalized() - z * (ca * ca * slx + sa * sa * slz)
			_v(p, n, bone, b1, w)
	for r in nr - 1:
		for s in seg:
			var i0 := base + r * seg + s
			var i1 := base + r * seg + (s + 1) % seg
			var i2 := i0 + seg
			var i3 := i1 + seg
			I.append_array([i0, i1, i2, i1, i3, i2])
	# caps
	var ca0 := _v(a + ax * float(rings[0][0]), -z, bone, blend[0] if blend[0] >= 0 else -1, 0.5 if blend[0] >= 0 else 0.0)
	var ca1 := _v(a + ax * float(rings[nr - 1][0]), z, bone, blend[1] if blend[1] >= 0 else -1, 0.5 if blend[1] >= 0 else 0.0)
	for s in seg:
		var j0 := base + s
		var j1 := base + (s + 1) % seg
		I.append_array([ca0, j1, j0])
		var k0 := base + (nr - 1) * seg + s
		var k1 := base + (nr - 1) * seg + (s + 1) % seg
		I.append_array([ca1, k0, k1])

## capsule-ish limb: rounded at both ends
func limb(a: Vector3, b: Vector3, r0: float, r1: float, side: Vector3, seg := 8, blend := [-1, -1], flat := 1.0) -> void:
	var L := a.distance_to(b)
	var e0 := minf(0.45, r0 / L)
	var e1 := minf(0.45, r1 / L)
	var rings := [[-e0 * 0.8, r0 * 0.35, r0 * 0.35 * flat], [-e0 * 0.45, r0 * 0.8, r0 * 0.8 * flat], [0.0, r0, r0 * flat],
		[0.5, (r0 + r1) * 0.5 * 1.02, (r0 + r1) * 0.5 * flat], [1.0, r1, r1 * flat], [1.0 + e1 * 0.45, r1 * 0.8, r1 * 0.8 * flat], [1.0 + e1 * 0.8, r1 * 0.35, r1 * 0.35 * flat]]
	loft(a, b, rings, side, seg, blend)

func ellipsoid(c: Vector3, r: Vector3, basis := Basis(), rings := 6, seg := 10, b1 := -1, w := 0.0) -> void:
	var base := P.size()
	for i in rings + 1:
		var th := PI * i / rings
		for s in seg:
			var ph := TAU * s / seg
			var u := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			_v(c + basis * (u * r), basis * Vector3(u.x / r.x, u.y / r.y, u.z / r.z), bone, b1, w)
	for i in rings:
		for s in seg:
			var i0 := base + i * seg + s
			var i1 := base + i * seg + (s + 1) % seg
			I.append_array([i0, i1, i0 + seg, i1, i1 + seg, i0 + seg])

## box with softly bevelled (corner-leaning) normals; `basis` orients it
func box(c: Vector3, s: Vector3, basis := Basis(), soft := 0.3) -> void:
	var h := s * 0.5
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = sg
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(ax + 2) % 3] = 1.0
			var base := P.size()
			for k in 4:
				var su := -1.0 if (k == 0 or k == 3) else 1.0
				var sv := -1.0 if k < 2 else 1.0
				var lc := n + u * su + v * sv
				var lp := Vector3(lc.x * h.x, lc.y * h.y, lc.z * h.z)
				_v(c + basis * lp, basis * (n + (u * su + v * sv) * soft), bone)
			var a0: Vector3 = P[base]
			var a1: Vector3 = P[base + 1]
			var a2: Vector3 = P[base + 2]
			if (a1 - a0).cross(a2 - a0).dot(basis * n) > 0.0:
				I.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			else:
				I.append_array([base, base + 2, base + 1, base, base + 3, base + 2])

## upper part of an ellipsoid (helmets, caps): polar angle 0..th_max
func dome(c: Vector3, r: Vector3, th_max := 1.75, rings := 5, seg := 12, basis := Basis()) -> void:
	var base := P.size()
	for i in rings + 1:
		var th := th_max * i / rings
		for s in seg:
			var ph := TAU * s / seg
			var u := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			_v(c + basis * (u * r), basis * Vector3(u.x / r.x, u.y / r.y, u.z / r.z), bone)
	for i in rings:
		for s in seg:
			var i0 := base + i * seg + s
			var i1 := base + i * seg + (s + 1) % seg
			I.append_array([i0, i1, i0 + seg, i1, i1 + seg, i0 + seg])

func cyl(p0: Vector3, p1: Vector3, r0: float, r1 := -1.0, seg := 8) -> void:
	if r1 < 0.0:
		r1 = r0
	var ax := p1 - p0
	var side := ax.cross(Vector3.UP if absf(ax.normalized().y) < 0.9 else Vector3.RIGHT)
	loft(p0, p1, [[0.0, r0, r0], [1.0, r1, r1]], side, seg)

## add a kit part (weapon) in gun space on the GUN bone, mirrored to the right-handed frame
func add_kit(kit) -> void:
	var base := P.size()
	for i in kit.P.size():
		var p: Vector3 = kit.P[i]
		var n: Vector3 = kit.N[i]
		var c: Color = kit.C[i]
		col = Color(c.r, c.g, c.b, 1.0)
		flags = 1 if c.a > 0.5 else 0
		vmask = 0
		_v(Vector3(-p.x, p.y, p.z), Vector3(-n.x, n.y, n.z), GUN)
	for t in range(0, kit.I.size(), 3):
		I.append_array([base + kit.I[t], base + kit.I[t + 2], base + kit.I[t + 1]])

# ------------------------------------------------------------------ posing
## Two-bone IK. Returns [elbow, end] positions.
static func ik(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := target - a
	var dl := clampf(d.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir := d.normalized() if d.length() > 1e-5 else Vector3.DOWN
	var ca := clampf((l1 * l1 + dl * dl - l2 * l2) / (2.0 * l1 * dl), -1.0, 1.0)
	var sa := sqrt(1.0 - ca * ca)
	var pp := pole - dir * pole.dot(dir)
	if pp.length_squared() < 1e-8:
		pp = Vector3.FORWARD
	pp = pp.normalized()
	var el := a + dir * (l1 * ca) + pp * (l1 * sa)
	var end := el + (a + dir * dl - el).normalized() * l2
	return [el, end]

static func eul(v: Vector3) -> Basis:
	return Basis.from_euler(v * PI / 180.0, EULER_ORDER_YXZ)

## Pose globals from a pose dict (see SoldierAnims). Returns Array[Transform3D] per bone.
func solve(p: Dictionary, gun: Dictionary) -> Array:
	var g := []
	g.resize(NB)
	g[PELVIS] = Transform3D(eul(p.get("pelvis_r", Vector3.ZERO)), p.get("pelvis", J["pelvis"]))
	g[SPINE] = g[PELVIS] * Transform3D(eul(p.get("spine_r", Vector3.ZERO)), J["spine"] - J["pelvis"])
	g[CHEST] = g[SPINE] * Transform3D(eul(p.get("chest_r", Vector3.ZERO)), J["chest"] - J["spine"])
	g[NECK] = g[CHEST] * Transform3D(eul(p.get("neck_r", Vector3.ZERO)), J["neck"] - J["chest"])
	g[HEAD] = g[NECK] * Transform3D(eul(p.get("head_r", Vector3.ZERO)), J["head"] - J["neck"])
	# legs
	for s in ["L", "R"]:
		var o := 0 if s == "L" else 3
		var hip: Vector3 = (g[PELVIS] as Transform3D) * (J["hip_" + s] - J["pelvis"])
		var ft: Array = p["foot_" + s]   # [ankle pos, yaw, pitch]
		var l1: float = (J["kn_" + s] - J["hip_" + s]).length()
		var l2: float = (J["an_" + s] - J["kn_" + s]).length()
		var pole: Vector3 = p.get("knee_" + s, Vector3(0, 0, 1))
		var r := ik(hip, ft[0], l1, l2, pole)
		g[THIGH_L + o] = Transform3D(limb_basis(r[0] - hip, pole), hip)
		g[SHIN_L + o] = Transform3D(limb_basis(r[1] - r[0], pole), r[0])
		g[FOOT_L + o] = Transform3D(eul(Vector3(ft[2], ft[1], 0)), r[1])
	# weapon: "chest" = held relative to the chest; "aim" = pointing along a model-space basis
	# with one of its points (butt / shoulder rest) at a chest-local spot; "world" = dropped;
	# "hand" = carried in the right hand (free arm targets)
	var mode: String = p.get("gun_rel", "chest")
	var gx := Transform3D()
	if mode == "chest":
		gx = (g[CHEST] as Transform3D) * (p.get("gun", Transform3D()) as Transform3D)
	elif mode == "aim":
		var B: Basis = p["gun_basis"]
		var anchor: Vector3 = (g[CHEST] as Transform3D) * (p["pocket"] as Vector3)
		gx = Transform3D(B, anchor - B * (gun[p.get("anchor", "butt")] as Vector3))
	elif mode == "world":
		gx = p["gun"]
	g[GUN] = gx
	# arms: hands on the weapon unless the pose gives free hand targets
	for s in ["L", "R"]:
		var o := 0 if s == "L" else 3
		var sh: Vector3 = (g[CHEST] as Transform3D) * (J["sh_" + s] - J["chest"])
		var tgt: Vector3
		if p.has("hand_" + s):
			tgt = p["hand_" + s]
			if p.get("hand_rel", "") == "chest":
				tgt = (g[CHEST] as Transform3D) * tgt
		else:
			tgt = gx * (gun["grip"] if s == "R" else gun["support"])
		var pole: Vector3 = p.get("elbow_" + s, Vector3(0.5 if s == "L" else -0.5, -0.6, -0.4))
		var l1: float = (J["el_" + s] - J["sh_" + s]).length()
		var l2: float = (J["wr_" + s] - J["el_" + s]).length()
		var wr := tgt - (tgt - sh).normalized() * HAND_LEN
		var r := ik(sh, wr, l1, l2, pole)
		wr = r[1]
		g[UARM_L + o] = Transform3D(limb_basis(r[0] - sh, pole), sh)
		var fb := limb_basis(r[1] - r[0], pole)
		g[FARM_L + o] = Transform3D(fb, r[0])
		# the hand closes round the grip: its fingers point from the wrist to the palm target
		var hb := limb_basis(tgt - wr, fb.z)
		g[HAND_L + o] = Transform3D(hb, wr)
	if mode == "hand":
		g[GUN] = (g[HAND_R] as Transform3D) * (p.get("gun", Transform3D()) as Transform3D)
	if p.has("root"):
		var rt: Transform3D = p["root"]
		for i in NB:
			if i == GUN and mode == "world":
				continue
			g[i] = rt * (g[i] as Transform3D)
	return g

## Skin all vertices with a pose. Returns [positions, normals].
func skin(g: Array) -> Array:
	var m := []
	for i in NB:
		m.append((g[i] as Transform3D) * (rest[i] as Transform3D).affine_inverse())
	var op := PackedVector3Array()
	var on := PackedVector3Array()
	op.resize(P.size())
	on.resize(P.size())
	for i in P.size():
		var ma: Transform3D = m[B0[i]]
		var w := W1[i]
		if w > 0.0:
			var mb: Transform3D = m[B1[i]]
			op[i] = (ma * P[i]).lerp(mb * P[i], w)
			on[i] = (ma.basis * N[i]).lerp(mb.basis * N[i], w).normalized()
		else:
			op[i] = ma * P[i]
			on[i] = (ma.basis * N[i]).normalized()
	return [op, on]
