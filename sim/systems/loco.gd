class_name Loco
## M2.3 locomotor model, studied from Zero Hour's Locomotor (treads / wheels / legs behaviour) and
## reimplemented here in our own fixed-point code. All numbers are FRACTURE LINE tuning, not ZH data.
##  legs   - nimble: turn almost on the spot, reach full speed almost instantly.
##  treads - pivot in place: forward speed scales down with the heading error, 0 at >= 45 degrees.
##  wheels - cannot pivot: while turning more than 9 degrees speed is clamped to a turning speed.
## Every locomotor accelerates and brakes over time, and brakes into its final destination.

const LEGS := &"legs"
const TREADS := &"treads"
const WHEELS := &"wheels"
# kind -> [turn deg/s, accel ms (0 -> full), brake ms (full -> 0)]
const DEFAULTS := {
	&"legs": [540, 200, 150],
	&"treads": [110, 1200, 600],
	&"wheels": [170, 800, 500],
}
const DAMAGED_PCT := 35        ## vehicles below this HP% are "damaged"...
const DAMAGED_SPEED := 80      ## ...and move at this % of their speed
const WHEEL_TURN_DEG := 9      ## wheels slow to turning speed above this heading error
const WHEEL_TURN_SPEED := 40   ## % of max speed while turning hard

static var _cache := {}

## {kind, turn (ANG per tick), accel_ms, brake_ms, turret (ANG per tick, 0 = none)}
static func params(d: UnitDef) -> Dictionary:
	if _cache.has(d.id):
		return _cache[d.id]
	var kind: StringName = d.loco
	if kind == &"":
		if d.tags.has("infantry") or d.move_layer == &"foot":
			kind = LEGS
		elif d.tags.has("tank") or d.tags.has("builder") or d.tags.has("shield"):
			kind = TREADS
		else:
			kind = WHEELS
	var def: Array = DEFAULTS.get(kind, DEFAULTS[LEGS])
	var p := {
		"kind": kind,
		"turn": FX.dps_to_apt(d.turn_dps if d.turn_dps > 0 else int(def[0])),
		"accel_ms": d.accel_ms if d.accel_ms > 0 else int(def[1]),
		"brake_ms": int(def[2]),
		"turret": FX.dps_to_apt(d.turret_dps) if d.turret_dps > 0 else 0,
	}
	_cache[d.id] = p
	return p

## Top speed in fx/tick for this unit right now (terrain, veterancy, damage, group cap).
static func max_step(w: SimWorld, u: SimEntity, d: UnitDef) -> int:
	var veh := d.move_layer == &"vehicle"
	var step := FX.speed_per_tick(d.speed_mtps) * w.map.speed_pct(FX.to_tile(u.pos), veh) / 100
	if u.vet >= 2:
		step = step * 110 / 100
	if veh and u.hp * 100 < u.max_hp * DAMAGED_PCT:
		step = step * DAMAGED_SPEED / 100
	if not u.orders.is_empty():
		var cap := int(u.orders[0].get("spd", 0))
		if cap > 0:
			step = mini(step, cap)
	return maxi(step, 8)

## Speed the locomotor wants given heading error `rel` (ANG units) toward the waypoint.
static func goal_speed(kind: StringName, maxs: int, rel: int) -> int:
	var a := absi(rel)
	match kind:
		WHEELS:
			if a > WHEEL_TURN_DEG * FX.ANG / 360:
				return maxs * WHEEL_TURN_SPEED / 100
			return maxs
		_:
			# treads and legs: (1 - |rel|/45deg) of desired speed
			var q := FX.ANG / 8
			return maxs * maxi(0, q - a) / q

## Rotate heading `cur` toward `want` by at most `rate`.
static func turn(cur: int, want: int, rate: int) -> int:
	var r := FX.adiff(cur, want)
	return posmod(cur + clampi(r, -rate, rate), FX.ANG)
