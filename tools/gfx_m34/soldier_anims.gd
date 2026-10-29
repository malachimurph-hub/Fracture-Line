extends RefCounted
## M3.4 soldier animation (original keyframe + IK code). pose(clip, t, style) returns the pose
## dict SoldierRig.solve() reads. Styles: rifle | launcher | pistol | tool. The soldier faces
## +Z; his right is -X. Weapons are held in both hands (right on the grip, left on the
## handguard / front grip / tube) in every clip but the deaths.
const Rig := preload("res://tools/gfx_m34/soldier_rig.gd")
## clip: [length s, loop]
const CLIPS := {"idle": [2.4, true], "walk": [1.0, true], "run": [0.66, true], "fire": [0.4, true],
	"fire_kneel": [0.4, true], "lean": [0.4, true], "die": [1.4, false], "die2": [1.4, false]}

static func _e(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

static func _ph(t: float, len: float) -> float:
	return TAU * t / len

static func _basis_dir(fwd: Vector3, up := Vector3.UP) -> Basis:
	var z := fwd.normalized()
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x), z)

## aim direction: yaw (deg, + = toward his left) and pitch (deg, + = muzzle up)
static func _aim(yaw: float, pitch: float, roll := 0.0) -> Basis:
	var b := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	return b * Basis(Vector3.BACK, deg_to_rad(roll))

static func _feet(p: Dictionary, l: Vector3, ly: float, r: Vector3, ry: float, lp := 0.0, rp := 0.0) -> void:
	p["foot_L"] = [l, ly, lp]
	p["foot_R"] = [r, ry, rp]

static func pose(clip: String, t: float, style: String, recoil_k := 1.0) -> Dictionary:
	var p := {}
	match clip:
		"idle":
			_idle(p, t, style)
		"walk":
			_gait(p, t, style, 1.0, 0.3, 0.09, 0.012, 4.0)
		"run":
			_gait(p, t, style, 0.66, 0.5, 0.2, 0.03, 13.0)
		"fire":
			_fire(p, t, style, false, recoil_k)
		"fire_kneel":
			_fire(p, t, style, true, recoil_k)
		"lean":
			_fire(p, t, style, false, recoil_k * 0.6)
			p["pelvis"] = p["pelvis"] + Vector3(0, -0.04, -0.1)
			p["spine_r"] = p["spine_r"] + Vector3(20, 0, 0)
			p["chest_r"] = p["chest_r"] + Vector3(8, 0, 0)
			p["neck_r"] = p["neck_r"] + Vector3(-12, 0, 0)
			p["head_r"] = p["head_r"] + Vector3(-10, 0, 0)
			p["gun_basis"] = _aim(0, -8)
		"die":
			_die(p, t, style, false)
		"die2":
			_die(p, t, style, true)
	return p

# ------------------------------------------------------------------ carry positions
## gun held relative to the chest (idle / moving)
static func _carry(p: Dictionary, style: String, k: String, bob := 0.0) -> void:
	match style:
		"rifle":
			if k == "low":     # low ready: stock in the shoulder, muzzle down at 35 degrees
				p["gun_rel"] = "aim"
				p["gun_basis"] = _aim(14, -34 + bob * 2.0)
				p["pocket"] = Vector3(-0.13, 0.15, 0.1)
				p["anchor"] = "butt"
			else:              # port arms across the chest while running
				p["gun_rel"] = "chest"
				p["gun"] = Transform3D(_basis_dir(Vector3(0.55, 0.42, 0.72), Vector3(0, 1, -0.3)), Vector3(-0.06, 0.02 + bob * 0.01, 0.2))
		"launcher":
			p["gun_rel"] = "aim"
			p["gun_basis"] = _aim(4, 16 if k == "port" else 6)
			p["pocket"] = Vector3(-0.17, 0.235, 0.0)
			p["anchor"] = "shoulder"
		"pistol":
			p["gun_rel"] = "chest"
			p["gun"] = Transform3D(_aim(10, -40), Vector3(-0.05, 0.02, 0.3))
		"tool":
			p["gun_rel"] = "chest"
			if k == "low":
				p["gun"] = Transform3D(_basis_dir(Vector3(-0.2, -1.0, 0.25), Vector3(0, 0, 1)), Vector3(-0.2, -0.1, 0.18))
			else:
				p["gun"] = Transform3D(_basis_dir(Vector3(0.5, -0.6, 0.62), Vector3(0, 1, 0)), Vector3(-0.15, 0.05, 0.22))

static func _idle(p: Dictionary, t: float, style: String) -> void:
	var ph := _ph(t, 2.4)
	var br := sin(ph)
	p["pelvis"] = Vector3(0.0, 0.985 + br * 0.003, 0.0)
	p["pelvis_r"] = Vector3(0, -14, 0)
	p["spine_r"] = Vector3(2.0 + br * 1.0, 0, 0)
	p["chest_r"] = Vector3(1.5 + br * 0.8, -6, 0)
	p["neck_r"] = Vector3(4, 8, 0)
	p["head_r"] = Vector3(2 - br * 1.0, 10 + 10.0 * sin(ph * 0.5 + 0.7), 0)
	_feet(p, Vector3(0.14, 0.09, 0.07), 6, Vector3(-0.15, 0.09, -0.08), -24)
	p["knee_L"] = Vector3(0.2, 0, 1)
	p["knee_R"] = Vector3(-0.3, 0, 1)
	_carry(p, style, "low", br)
	p["elbow_L"] = Vector3(0.4, -1, -0.1)
	p["elbow_R"] = Vector3(-0.8, -0.5, -0.4)
	if style == "tool":
		p["hand_L"] = Vector3(0.24, -0.38, 0.06)
		p["hand_rel"] = "chest"
	if style == "pistol":
		p["elbow_R"] = Vector3(-0.6, -1, -0.2)

## walk / run cycle in place (the view moves the soldier); feet plant and push back
static func _gait(p: Dictionary, t: float, style: String, len: float, stride: float, lift: float, bob: float, lean: float) -> void:
	var ph := _ph(t, len)
	var lz := stride * cos(ph)
	var rz := -lz
	var ly := 0.09 + lift * maxf(0.0, -sin(ph))
	var ry := 0.09 + lift * maxf(0.0, sin(ph))
	var running := len < 0.8
	var h := (0.95 if running else 0.975) - bob * absf(cos(ph))
	p["pelvis"] = Vector3(0.0, h, 0.03 if running else 0.0)
	p["pelvis_r"] = Vector3(lean * 0.4, 7.0 * cos(ph) * (0.6 if running else 1.0), 2.0 * sin(ph))
	p["spine_r"] = Vector3(lean * 0.4, -4.0 * cos(ph), 0)
	p["chest_r"] = Vector3(lean * 0.25, -3.0 * cos(ph), 0)
	p["neck_r"] = Vector3(-lean * 0.4, 0, 0)
	p["head_r"] = Vector3(-lean * 0.3, 0, 0)
	_feet(p, Vector3(0.11, ly, lz), 2, Vector3(-0.11, ry, rz), -2, -25.0 * maxf(0.0, -sin(ph)) if running else 0.0, -25.0 * maxf(0.0, sin(ph)) if running else 0.0)
	p["knee_L"] = Vector3(0.1, 0, 1)
	p["knee_R"] = Vector3(-0.1, 0, 1)
	_carry(p, style, "port" if running else "low", sin(ph * 2.0))
	p["elbow_L"] = Vector3(0.5, -1, -0.2)
	p["elbow_R"] = Vector3(-0.9, -0.6, -0.4)
	if style == "tool":
		p["hand_L"] = Vector3(0.22, -0.36, 0.05 + 0.08 * cos(ph))
		p["hand_rel"] = "chest"

## aimed fire: bladed stance, cheek on the stock, both hands on the weapon, recoil each loop
static func _fire(p: Dictionary, t: float, style: String, kneel: bool, rk: float) -> void:
	var k := exp(-t * 18.0) * rk     # recoil impulse at the start of each loop (~2.5 rounds / s)
	if style == "launcher":
		k *= 0.6
	if kneel:
		p["pelvis"] = Vector3(0.0, 0.64, -0.06)
		p["pelvis_r"] = Vector3(4, -22, 0)
		_feet(p, Vector3(0.16, 0.09, 0.36), -12, Vector3(-0.13, 0.12, -0.46), -30, 0.0, 55.0)
		p["knee_L"] = Vector3(0.1, 0.4, 1)
		p["knee_R"] = Vector3(-0.1, -1.0, 0.25)
	else:
		p["pelvis"] = Vector3(0.0, 0.955, -0.01)
		p["pelvis_r"] = Vector3(5, -24, 0)
		_feet(p, Vector3(0.15, 0.09, 0.22), -8, Vector3(-0.12, 0.09, -0.15), -48)
		p["knee_L"] = Vector3(0.2, 0, 1)
		p["knee_R"] = Vector3(-0.4, 0, 1)
	p["spine_r"] = Vector3(6.0 - k * 2.0, -2, 0)
	p["chest_r"] = Vector3(3.0 - k * 1.5, -6, 0)
	p["neck_r"] = Vector3(14, 14, -6)
	p["head_r"] = Vector3(10, 14, -8)
	match style:
		"rifle":
			p["gun_rel"] = "aim"
			p["gun_basis"] = _aim(0, k * 4.0)
			p["pocket"] = Vector3(-0.135, 0.185 - k * 0.006, 0.085 - k * 0.035)
			p["anchor"] = "butt"
			p["elbow_L"] = Vector3(0.3, -1, -0.2)
			p["elbow_R"] = Vector3(-1, -0.25, -0.35)
		"launcher":
			p["gun_rel"] = "aim"
			p["gun_basis"] = _aim(0, 2 + k * 6.0)
			p["pocket"] = Vector3(-0.17, 0.235, 0.0 - k * 0.04)
			p["anchor"] = "shoulder"
			p["neck_r"] = Vector3(10, 14, -2)
			p["head_r"] = Vector3(6, 12, -4)
			p["elbow_L"] = Vector3(0.3, -1, -0.1)
			p["elbow_R"] = Vector3(-0.8, -0.8, -0.2)
		"pistol":     # two-handed isosceles: arms out, pistol at eye level
			p["gun_rel"] = "aim"
			p["gun_basis"] = _aim(0, k * 8.0)
			p["pocket"] = Vector3(-0.03, 0.27, 0.5 - k * 0.03)
			p["anchor"] = "grip"
			p["pelvis_r"] = Vector3(4, -6, 0)
			p["chest_r"] = Vector3(3 - k, 2, 0)
			p["neck_r"] = Vector3(6, 2, 0)
			p["head_r"] = Vector3(6, 2, 0)
			p["elbow_L"] = Vector3(0.6, -1, 0)
			p["elbow_R"] = Vector3(-0.6, -1, 0)
		"tool":       # no weapon: digging / working motion
			var ph := _ph(t, 0.4)
			p["gun_rel"] = "chest"
			p["gun"] = Transform3D(_basis_dir(Vector3(0.1, -0.85, 0.5), Vector3(0, 0, 1)), Vector3(-0.1, -0.05 - 0.08 * sin(ph), 0.3))
			p["spine_r"] = Vector3(22, 0, 0)
			p["hand_L"] = Vector3(0.05, -0.32, 0.32)
			p["hand_rel"] = "chest"

## deaths: hit, knees give, falls on his back (die) or crumples forward on his face (die2);
## the weapon drops beside him
static func _die(p: Dictionary, t: float, style: String, fwd: bool) -> void:
	_fire(p, 0.3, style, false, 0.0)
	var u1 := _e(clampf(t / 0.35, 0.0, 1.0))          # hit reaction / knees buckle
	var u2 := _e(clampf((t - 0.3) / 0.65, 0.0, 1.0))  # the fall
	var sgn := 1.0 if fwd else -1.0
	var drop := 0.22 if fwd else 0.12
	p["pelvis"] = (p["pelvis"] as Vector3).lerp(Vector3(0, 0.98 - drop, 0), u1).lerp(Vector3(0, 1.0, 0), u2)
	p["pelvis_r"] = (p["pelvis_r"] as Vector3).lerp(Vector3(sgn * 10, -10, 4), u1).lerp(Vector3(0, -6, 6), u2)
	p["spine_r"] = Vector3(sgn * 18 * u1 * (1.0 - u2) + sgn * 4 * u2, 0, 0)
	p["chest_r"] = Vector3(sgn * 10 * u1 * (1.0 - u2), 4, 0)
	p["neck_r"] = Vector3(-sgn * 10 * u2, 10 * u2, 0)
	p["head_r"] = Vector3(-sgn * 8 * u1, 20 * u2, 0)
	var kn := 0.3 if fwd else 0.15
	_feet(p, (p["foot_L"][0] as Vector3).lerp(Vector3(0.12, 0.09, kn * -0.5), u1).lerp(Vector3(0.18, 0.09, 0.02), u2), 10,
		(p["foot_R"][0] as Vector3).lerp(Vector3(-0.13, 0.09, -kn), u1).lerp(Vector3(-0.15, 0.09, -0.04), u2), -20)
	p["knee_L"] = Vector3(0.3, 0, 1)
	p["knee_R"] = Vector3(-0.3, 0, 1)
	# arms let go and fling out
	p["hand_rel"] = "chest"
	if fwd:
		p["hand_L"] = Vector3(0.3, -0.1, 0.35).lerp(Vector3(0.42, 0.3, 0.28), u2)
		p["hand_R"] = Vector3(-0.25, -0.05, 0.35).lerp(Vector3(-0.38, 0.05, 0.3), u2)
	else:
		p["hand_L"] = Vector3(0.3, 0.0, 0.25).lerp(Vector3(0.55, 0.25, -0.05), u2)
		p["hand_R"] = Vector3(-0.3, 0.05, 0.2).lerp(Vector3(-0.5, 0.35, -0.02), u2)
	p["elbow_L"] = Vector3(1, -0.3, -0.5)
	p["elbow_R"] = Vector3(-1, -0.3, -0.5)
	# the body topples about the feet; it ends lying on the ground (half its depth up)
	var ang := sgn * 88.0 * u2
	var lift := 0.15 * u2
	var rot := Basis(Vector3.RIGHT, deg_to_rad(ang))
	p["root"] = Transform3D(rot, Vector3(0, lift, 0.0))
	# weapon: falls out of the hands to the ground at his side
	var held: Transform3D = Transform3D(_aim(0, -20), Vector3(-0.2, 1.1, 0.35))
	var lie := Transform3D(Basis(Vector3.UP, deg_to_rad(70 if fwd else -60)) * Basis(Vector3.BACK, deg_to_rad(90)), Vector3(-0.45, 0.04, 0.5 if fwd else -0.4))
	var gu := _e(clampf((t - 0.15) / 0.6, 0.0, 1.0))
	var gx := held.interpolate_with(lie, gu)
	gx.origin.y += sin(gu * PI) * 0.15
	p["gun_rel"] = "world"
	p["gun"] = gx
