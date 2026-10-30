class_name PackRig
extends RefCounted
## M3.4 (Malachi: "Pack up animation for Russian minerals mining"): poses the Minerals Mining
## excavator's moving parts for a pack fraction k (0 = set up and digging, 1 = packed for the
## road). View only: the sim's 10 s pack-up / set-up timers (MineSys) drive k, so the motion
## always finishes exactly when the structure becomes the vehicle (and the reverse).
## Parts are Model children with meta pack_pivot / pack_axis / pack_deg / pack_move / pack_t
## (tools/gfx_m33/new_m33.gd _excavator_parts); "pack_hide" hides a part from that k on and
## "pack_spin" adds the bucket wheel's own turn about X on top of the pose.
## A node transform each, no extra draw calls.
var parts: Array = []   ## [node, rest Transform3D, pivot, axis, rad, move, t0, t1, hide, spin]
var k := 0.0

static func from(model: Node) -> PackRig:
	if model == null:
		return null
	var r := PackRig.new()
	for c in model.get_children():
		if c is Node3D and c.has_meta("pack_pivot"):
			var t: Vector2 = c.get_meta("pack_t", Vector2(0, 1))
			r.parts.append([c, (c as Node3D).transform, c.get_meta("pack_pivot"), (c.get_meta("pack_axis") as Vector3).normalized(),
				deg_to_rad(float(c.get_meta("pack_deg", 0.0))), c.get_meta("pack_move", Vector3.ZERO), t.x, t.y,
				float(c.get_meta("pack_hide", 2.0)), c.get_meta("pack_spin", false)])
	return r if not r.parts.is_empty() else null

## Eased 0..1 progress of a phase [t0, t1] at pack fraction k.
static func phase(k: float, t0: float, t1: float) -> float:
	return smoothstep(t0, t1, k) if t1 > t0 else (1.0 if k >= t1 else 0.0)

## How fast the bucket wheel turns at k (full speed set up, stopped once packing is under way).
static func spin_factor(k: float) -> float:
	return 1.0 - smoothstep(0.0, 0.08, k)

func pose(pk: float, spin := 0.0) -> void:
	k = clampf(pk, 0.0, 1.0)
	for p in parts:
		var n: Node3D = p[0]
		var rest: Transform3D = p[1]
		var e := phase(k, p[6], p[7])
		var bs := Basis(p[3], p[4] * e) if absf(p[4]) > 0.0 else Basis.IDENTITY
		var pv: Vector3 = p[2]
		var t := Transform3D(bs, pv - bs * pv + (p[5] as Vector3) * e) * rest
		if p[9]:
			t.basis = t.basis * Basis(Vector3.RIGHT, spin)
		n.transform = t
		n.visible = k < float(p[8])
