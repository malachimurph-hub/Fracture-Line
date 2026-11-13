class_name AirSys
## M2.5 air layer (US aircraft; ZH Airfield behaviour studied, reimplemented in our own code).
##  - aircraft (move_layer air) fly straight lines over any terrain; no pathing, no separation
##  - only weapons with targets_air can hit them while airborne; a parked aircraft is a ground target
##  - jets (tag "jet") belong to an Airfield: each uses air_slots of its 6 parking slots; production
##    holds while the slots are full; a jet spends its sortie ammo (no reload in the air), then flies
##    home, lands and rearms (reload_ms per empty clip) before it can take off again; jets cannot
##    hover: they keep flying and circle their target or loiter point; idle jets return to base
##  - helicopters (no "jet" tag) hover, reload in the air like ground units and use no slots
##  - JTAC Observer: calls the nearest idle armed friendly aircraft onto the JTAC's current target
##    (one call every JTAC_CALL_TICKS), and boosts artillery / air damage near him (boost_pct)
const NONE := Vector2i(-1, -1)
const FLYING := 0
const PARKED := 1
const RETURNING := 2
const TAXI_OUT := 3   ## M3.1: on the ground: bay -> hold-short (phase 0), runway threshold (1), take-off roll (2)
const LANDING := 4    ## M3.1: final approach (phase 0), touchdown roll-out (1), runway exit (2), lead-in (3), bay (4)
## M3.1 runway (model space of the 8 x 8 airfield, tiles from the centre; tools/gfx_m7/us_m7.gd
## _airbase8): strip along +z at RWY_Z, threshold at the -x end, jets take off and land towards +x.
const RWY_Z := FX.ONE * 315 / 100
const HOLD_Z := FX.ONE * 23 / 10
## M4.2: the runway scales with the airfield width (10 x 8 with 4 hangars; was 8 x 8 with 3)
static func rwy_x0(home: SimEntity) -> int:   ## threshold / touchdown
	return -home.fp.x * FX.ONE / 2 + FX.ONE * 4 / 10
static func lift_x(home: SimEntity) -> int:   ## lift-off point
	return home.fp.x * FX.ONE / 2 - FX.ONE * 14 / 10
static func app_x(home: SimEntity) -> int:    ## approach fix, ~8 tiles out from the threshold
	return rwy_x0(home) - FX.ONE * 84 / 10
const IDLE_RETURN_TICKS := 40          ## idle airborne jets head home after 2 s
const JTAC_RADIUS := FX.ONE * 8        ## boost aura around the JTAC
const JTAC_BONUS := 25                 ## +% damage for artillery / aircraft hitting near a JTAC
const JTAC_CALL_TICKS := 200           ## 10 s between air-support calls per JTAC
const JTAC_CALL_RANGE := FX.ONE * 70

static func run(w: SimWorld) -> void:
	var jtacs: Array = []
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
			continue
		var d: UnitDef = w.udef(u)
		if d.move_layer == &"air":
			if d.tags.has("jet"):
				_jet(w, u, d)
			elif d.transport_capacity > 0:
				_heli_transport(w, u, d)
		elif d.tags.has("jtac"):
			jtacs.append(u)
	if w.tick % 20 == 5:
		for j: SimEntity in jtacs:
			_jtac_call(w, j)

# ------------------------------------------------------------------ transport helicopters
## Transport helicopters land before troops board, and they land before troops step out.
## An unload order while airborne is "drop": descend (LANDING phase 0, HELI_LAND_TICKS), sit
## PARKED, then RosterSys unloads. There is no mid-air exit. A move order lifts off again.
## Boarding: an idle helicopter with infantry walking up to it sets down the same way.
const HELI_LAND_TICKS := 30
const HELI_CALL_R := FX.ONE * 14

static func _heli_transport(w: SimWorld, u: SimEntity, d: UnitDef) -> void:
	if _drop_pending(u):
		_heli_drop(w, u)
		return
	if u.air_state == FLYING:
		if u.goal == NONE and u.orders.is_empty() and u.spd == 0 and w.tick % 4 == u.id % 4 and _boarders_near(w, u):
			if w.map.passable(FX.to_tile(u.pos), false):
				u.air_state = LANDING
				u.phase = 0
				u.phase_t = w.tick + HELI_LAND_TICKS
				u.target = 0
		return
	if not u.orders.is_empty():
		u.air_state = FLYING   # lift off for the new order
		u.phase = 0
		w.events.append({"t": "takeoff", "id": u.id})
		return
	if u.air_state == LANDING and w.tick >= u.phase_t:
		u.air_state = PARKED
		u.air_t = 0
		w.events.append({"t": "landed", "id": u.id})

static func _drop_pending(u: SimEntity) -> bool:
	return not u.orders.is_empty() and String(u.orders[0].get("o", "")) == "drop"

static func _clear_drop(u: SimEntity) -> void:
	if _drop_pending(u):
		u.orders.pop_front()
	u.goal = NONE
	u.target = 0

## Unload order while airborne: stop, descend, then the passengers step out. Never a mid-air drop.
static func _heli_drop(w: SimWorld, u: SimEntity) -> void:
	if RosterSys.passengers(w, u).is_empty():
		_clear_drop(u)
		return
	u.target = 0
	if u.air_state == PARKED:
		RosterSys.unload(w, u)
		_clear_drop(u)
		return
	if u.air_state != FLYING and u.air_state != LANDING:
		u.air_state = FLYING
		u.phase = 0
	if u.air_state == LANDING:
		if w.tick >= u.phase_t:
			u.air_state = PARKED
			u.air_t = 0
			u.spd = 0
			u.goal = NONE
			w.events.append({"t": "landed", "id": u.id})
			RosterSys.unload(w, u)
			_clear_drop(u)
		return
	var tile := FX.to_tile(u.pos)
	if u.spd > 0 and u.goal == NONE:
		return
	if not w.map.passable(tile, false):
		if u.goal == NONE:
			u.goal = FX.tile_center(w.map.nearest_passable(tile, false))
		return
	if u.goal != NONE or u.spd > 0:
		return
	u.air_state = LANDING
	u.phase = 0
	u.phase_t = w.tick + HELI_LAND_TICKS

static func _boarders_near(w: SimWorld, t: SimEntity) -> bool:
	for o: SimEntity in w.units_in_radius(t.pos, HELI_CALL_R):
		if o.owner != t.owner or o.res_id < 0 or o.orders.is_empty():
			continue
		var od: Dictionary = o.orders[0]
		if od.get("o", "") == "garrison" and int(od.get("target", 0)) == t.id:
			return true
	return false

## Can infantry step aboard right now? Ground transports always; helicopters only once landed.
static func boardable(w: SimWorld, t: SimEntity) -> bool:
	return not w.is_air(t) or t.air_state == PARKED

# ------------------------------------------------------------------ airfield slots
static func is_airfield(w: SimWorld, b: SimEntity) -> bool:
	return b != null and b.alive and b.kind == SimEntity.Kind.BUILDING and w.bdef(b).air_slots > 0

static func slots_used(w: SimWorld, b: SimEntity) -> int:
	var n := 0
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and u.air_home == b.id:
			n += w.udef(u).air_slots
	return n

static func slots_free(w: SimWorld, b: SimEntity) -> int:
	return w.bdef(b).air_slots - slots_used(w, b)

static func _find_home(w: SimWorld, u: SimEntity, d: UnitDef) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 60
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if not is_airfield(w, b) or b.owner != u.owner or not b.built:
			continue
		if slots_free(w, b) < d.air_slots:
			continue
		var dd := FX.dist2(b.pos, u.pos)
		if dd < bd:
			bd = dd
			best = b
	return best

## M2.8 parking: the airfield's slots form bays of 2 across the hangar row (US: 6 slots = 3 bays).
## A fighter (2 slots) takes one bay, a bomber (4 slots) two adjacent bays; bombers are given the
## first bays so a fighter never splits the row. Positions match the hangars in the 8 x 8 model
## (tools/gfx_m7/us_m7.gd _airbase8), mirrored for airfields facing north (rot 2).
const PARK_DZ := 0            ## parking line, tiles from the footprint centre (model BAY_Z)
static func bay_of(w: SimWorld, home: SimEntity, u: SimEntity) -> Array:
	var nb := maxi(1, w.bdef(home).air_slots / 2)
	var used: Array = []
	used.resize(nb)
	used.fill(false)
	var mine := [0, 1]
	for pass_i in 2:   # pass 0: bombers (multi-bay), pass 1: everything else, each in id order
		for id in w.ids:
			var o: SimEntity = w.ents[id]
			if not o.alive or o.kind != SimEntity.Kind.UNIT or o.air_home != home.id:
				continue
			var need := maxi(1, w.udef(o).air_slots / 2)
			if (need > 1) != (pass_i == 0):
				continue
			var at := 0
			for b in range(0, nb - need + 1):
				var ok := true
				for k in need:
					ok = ok and not used[b + k]
				if ok:
					at = b
					break
			for k in need:
				if at + k < nb:
					used[at + k] = true
			if o.id == u.id:
				mine = [at, need]
	return mine

static func parking_pos(w: SimWorld, home: SimEntity, u: SimEntity) -> Vector2i:
	return local_pos(home, _bay_x(w, home, u), PARK_DZ * FX.ONE)

## Bay centre along the hangar row (model x, FX units from the footprint centre).
static func _bay_x(w: SimWorld, home: SimEntity, u: SimEntity) -> int:
	var nb := maxi(1, w.bdef(home).air_slots / 2)
	var bay := bay_of(w, home, u)
	var fpx := home.fp.x * FX.ONE
	return fpx * (2 * int(bay[0]) + int(bay[1])) / (2 * nb) - fpx / 2

## Airfield model space (FX units from the footprint centre) -> world, for the building's rotation.
static func local_pos(home: SimEntity, cx: int, cz: int) -> Vector2i:
	var fpx := home.fp.x * FX.ONE
	var fpy := home.fp.y * FX.ONE
	match home.rot:
		1:
			var t := cx
			cx = cz
			cz = -t
		2:
			cx = -cx
			cz = -cz
		3:
			var t2 := cx
			cx = -cz
			cz = t2
	return Vector2i(home.tile.x * FX.ONE + fpx / 2 + cx, home.tile.y * FX.ONE + fpy / 2 + cz)

## A freshly built jet appears parked on its airfield, armed.
static func park_new(w: SimWorld, b: SimEntity, u: SimEntity) -> void:
	u.air_home = b.id
	u.air_state = PARKED
	u.air_t = 0
	u.pos = parking_pos(w, b, u)
	u.home = u.pos
	u.face = b.rot * FX.ANG / 4
	u.tface = u.face
	u.orders = []
	CombatSys._ensure(u, w.udef(u))
	# a bomber can shift parked fighters to the free bay: tow them over
	for id in w.ids:
		var o: SimEntity = w.ents[id]
		if o != u and o.alive and o.kind == SimEntity.Kind.UNIT and o.air_home == b.id and o.air_state == PARKED:
			o.pos = parking_pos(w, b, o)
			o.home = o.pos

## Heading of the runway's take-off / landing direction (model +x) for the building's rotation.
static func runway_face(home: SimEntity) -> int:
	var a := local_pos(home, FX.ONE, 0)
	var b := local_pos(home, 0, 0)
	return FX.iatan2(a.x - b.x, a.y - b.y)

## One aircraft on the runway at a time: lined up / rolling, or on final / rolling out.
static func runway_busy(w: SimWorld, home: SimEntity, me: SimEntity) -> bool:
	for id in w.ids:
		var o: SimEntity = w.ents[id]
		if o == me or not o.alive or o.kind != SimEntity.Kind.UNIT or o.air_home != home.id:
			continue
		if (o.air_state == TAXI_OUT and o.phase >= 1) or (o.air_state == LANDING and o.phase <= 2):
			return true
	return false

## Ground movement towards p at speed spd (taxiing / rolling); true once there.
static func _taxi_to(u: SimEntity, p: Vector2i, spd: int, turn_rate: int) -> bool:
	var dist := FX.dist(u.pos, p)
	if dist <= maxi(spd, 8):
		MoveSys._set_pos(u, p)
		return true
	var want := FX.iatan2(p.x - u.pos.x, p.y - u.pos.y)
	u.face = Loco.turn(u.face, want, turn_rate)
	var hv := FX.dir_of(want)
	MoveSys._set_pos(u, u.pos + Vector2i(hv.x * spd / FX.ONE, hv.y * spd / FX.ONE))
	u.dir = FX.dir_of(u.face)
	return false

static func has_ammo(u: SimEntity, d: UnitDef) -> bool:
	CombatSys._ensure(u, d)
	for i in d.weapons.size():
		var wd: WeaponDef = Content.weapon(d.weapons[i])
		if wd.clip_size <= 0 or int(u.ammo[i]) > 0:
			return true
	return false

static func _rearm_ticks(u: SimEntity, d: UnitDef) -> int:
	var t := 0
	for i in d.weapons.size():
		var wd: WeaponDef = Content.weapon(d.weapons[i])
		if wd.clip_size > 0 and int(u.ammo[i]) < wd.clip_size:
			t = maxi(t, FX.ms_to_ticks(wd.reload_ms * (wd.clip_size - int(u.ammo[i])) / wd.clip_size))
	return t

static func _rearm(u: SimEntity, d: UnitDef) -> void:
	for i in d.weapons.size():
		u.ammo[i] = Content.weapon(d.weapons[i]).clip_size
		u.cds[i] = 0

static func _jet(w: SimWorld, u: SimEntity, d: UnitDef) -> void:
	CombatSys._ensure(u, d)
	var home := w.get_ent(u.air_home)
	if home == null or not home.alive or home.owner != u.owner or not home.built:
		home = null
		if u.air_home != 0:
			u.air_home = 0
		if (w.tick + u.id) % 20 == 0:
			home = _find_home(w, u, d)
			if home != null:
				u.air_home = home.id
	match u.air_state:
		PARKED:
			if home == null:
				u.air_state = FLYING   # airfield lost: take off and loiter until a new one has room
				u.home = u.pos
				return
			u.pos = parking_pos(w, home, u)
			u.spd = 0
			u.goal = NONE
			if u.air_t > 0:
				u.air_t -= 1
				if u.air_t == 0:
					_rearm(u, d)
					w.events.append({"t": "rearmed", "id": u.id, "owner": u.owner})
			elif not u.orders.is_empty():
				u.air_state = TAXI_OUT   # M3.1: taxi to the runway first
				u.phase = 0
				u.phase_t = 0
				w.events.append({"t": "taxi", "id": u.id})
		TAXI_OUT:
			if home == null:
				u.air_state = FLYING
				u.home = u.pos
				return
			_taxi_out(w, u, d, home)
		LANDING:
			if home == null:
				u.air_state = FLYING
				u.home = u.pos
				return
			u.orders = []
			u.target = 0
			_landing(w, u, d, home)
		RETURNING:
			if home == null:
				u.air_state = FLYING
				u.home = u.pos
				return
			if has_ammo(u, d) and not u.orders.is_empty():
				u.air_state = FLYING   # re-tasked on the way home
				return
			u.orders = []
			u.target = 0
			# M3.1: fly to the approach fix, then a straight final onto the runway; while the
			# runway is in use the jet holds (circles) over the fix
			var fix := local_pos(home, app_x(home), RWY_Z)
			fix.x = clampi(fix.x, FX.ONE * 2, w.map.w * FX.ONE - FX.ONE * 2)
			fix.y = clampi(fix.y, FX.ONE * 2, w.map.h * FX.ONE - FX.ONE * 2)
			if FX.dist(u.pos, fix) <= FX.ONE * 2:
				if not runway_busy(w, home, u):
					u.air_state = LANDING
					u.phase = 0
					u.goal = NONE
					u.done_goal = NONE
					u.path = []
					return
				u.goal = NONE
				u.home = fix
			elif u.goal == NONE and u.home == fix:
				pass    # holding over the fix
			else:
				u.goal = fix
		_:
			if not has_ammo(u, d):
				u.orders = []
				u.target = 0
				if home != null:
					u.air_state = RETURNING
				return
			if u.orders.is_empty() and u.target == 0:
				u.phase_t += 1
				if u.phase_t > IDLE_RETURN_TICKS and home != null:
					u.air_state = RETURNING
					u.phase_t = 0
			else:
				u.phase_t = 0

static func _taxi_speed(d: UnitDef) -> int:
	return maxi(FX.ONE / 40, FX.speed_per_tick(d.speed_mtps) / 4)

static func _taxi_out(w: SimWorld, u: SimEntity, d: UnitDef, home: SimEntity) -> void:
	var lp := Loco.params(d)
	var bx := _bay_x(w, home, u)
	var tx := _taxi_speed(d)
	var turn := int(lp["turn"]) * 2
	match u.phase:
		0:   # bay -> hold-short line in front of the bay
			if _taxi_to(u, local_pos(home, bx, HOLD_Z), tx, turn) and not runway_busy(w, home, u):
				u.phase = 1
		1:   # onto the runway, back-taxi to the threshold
			var thr := local_pos(home, rwy_x0(home), RWY_Z)
			var lane := local_pos(home, bx, RWY_Z)
			if u.phase_t == 0:
				if _taxi_to(u, lane, tx, turn):
					u.phase_t = 1
			elif _taxi_to(u, thr, tx, turn):
				u.phase = 2
				u.phase_t = 0
				u.spd = 0
				u.face = runway_face(home)
				w.events.append({"t": "lineup", "id": u.id})
		2:   # take-off roll: full power down the strip, rotate at the lift-off point
			var maxs := FX.speed_per_tick(d.speed_mtps)
			u.spd = mini(maxs, u.spd + maxi(1, maxs * 50 / maxi(1, int(lp["accel_ms"]))))
			u.face = runway_face(home)
			var lift := local_pos(home, lift_x(home), RWY_Z)
			if _taxi_to(u, lift, u.spd, turn):
				u.air_state = FLYING
				u.phase = 0
				u.phase_t = 0
				u.spd = maxi(u.spd, maxs * 55 / 100)
				w.events.append({"t": "takeoff", "id": u.id})
	u.goal = NONE

static func _landing(w: SimWorld, u: SimEntity, d: UnitDef, home: SimEntity) -> void:
	var lp := Loco.params(d)
	var maxs := FX.speed_per_tick(d.speed_mtps)
	var bx := _bay_x(w, home, u)
	var tx := _taxi_speed(d)
	var turn := int(lp["turn"]) * 2
	u.goal = NONE
	match u.phase:
		0:   # final approach: straight line to the touchdown point, aligning with the runway
			var td := local_pos(home, rwy_x0(home), RWY_Z)
			u.spd = maxi(maxs * 55 / 100, u.spd - maxi(1, maxs / 40))
			if _taxi_to(u, td, u.spd, int(lp["turn"]) * 3):
				u.phase = 1
				u.face = runway_face(home)
				w.events.append({"t": "touchdown", "id": u.id})
		1:   # roll-out: brake along the strip
			u.face = runway_face(home)
			u.spd = maxi(tx, u.spd - maxi(1, maxs / 25))
			var end := local_pos(home, lift_x(home), RWY_Z)
			var exit := local_pos(home, bx, RWY_Z)
			var past := FX.dist(u.pos, local_pos(home, rwy_x0(home), RWY_Z)) >= FX.dist(exit, local_pos(home, rwy_x0(home), RWY_Z))
			if (u.spd <= tx and past) or _taxi_to(u, end, u.spd, turn):
				u.phase = 2
				u.spd = tx
		2:   # taxi along the strip to the bay's exit
			if _taxi_to(u, local_pos(home, bx, RWY_Z), tx, turn):
				u.phase = 3
		3:   # off the runway onto the hold-short line (runway free for the next one)
			if _taxi_to(u, local_pos(home, bx, HOLD_Z), tx, turn):
				u.phase = 4
		_:   # lead-in line into the bay; park, rearm
			var pp := parking_pos(w, home, u)
			if _taxi_to(u, pp, tx, turn):
				u.air_state = PARKED
				u.phase = 0
				u.pos = pp
				u.goal = NONE
				u.done_goal = NONE
				u.spd = 0
				u.face = home.rot * FX.ANG / 4
				u.air_t = _rearm_ticks(u, d)
				if u.air_t == 0:
					_rearm(u, d)
				w.events.append({"t": "landed", "id": u.id})

# ------------------------------------------------------------------ flight
## Called by MoveSys for every aircraft instead of ground path following.
static func fly(w: SimWorld, u: SimEntity, d: UnitDef) -> void:
	u.moving = false
	if u.air_state == PARKED:
		u.spd = 0
		return
	if u.air_state == TAXI_OUT or u.air_state == LANDING:
		return    # ground roll / taxi / final: AirSys._jet moves it
	var lp := Loco.params(d)
	var maxs := FX.speed_per_tick(d.speed_mtps)
	if u.vet >= 2:
		maxs = maxs * 110 / 100
	var jet := d.tags.has("jet")
	var brake_pt := maxi(1, maxs * 50 / maxi(1, int(lp["brake_ms"])))
	var accel_pt := maxi(1, maxs * 50 / maxi(1, int(lp["accel_ms"])))
	var dest := u.goal
	var loiter := false
	if d.tags.has("reaper"):
		_reaper_orbit(w, u, maxs, accel_pt, brake_pt, lp)
		return
	if dest == NONE and jet:
		var t := w.get_ent(u.target)
		if t != null and t.alive:
			dest = t.pos
		else:
			dest = u.home
			loiter = true
	if dest == NONE:
		u.spd = maxi(0, u.spd - brake_pt)   # helicopter hovers
		if u.spd > 0:
			_step(w, u, u.spd)
		return
	var dist := FX.dist(u.pos, dest)
	var want := FX.iatan2(dest.x - u.pos.x, dest.y - u.pos.y)
	if dist > 8:
		u.face = Loco.turn(u.face, want, lp["turn"])
	var rel := absi(FX.adiff(u.face, want))
	var gs := maxs
	if jet:
		var mins := maxs * 55 / 100
		if loiter or u.air_state == RETURNING and dist < FX.ONE * 3:
			gs = maxs * 60 / 100
		u.spd = mini(gs, u.spd + accel_pt) if u.spd < gs else maxi(gs, u.spd - brake_pt)
		u.spd = maxi(u.spd, mins)
		if u.goal != NONE and dist <= maxi(u.spd, FX.ONE / 2):
			u.done_goal = u.goal
			u.goal = NONE
			u.path = []
	else:
		if rel > FX.ANG / 10:
			gs = maxs / 3
		gs = mini(gs, maxi(16, FX.isqrt(2 * brake_pt * dist)))
		u.spd = mini(gs, u.spd + accel_pt) if u.spd < gs else maxi(gs, u.spd - brake_pt)
		if dist <= maxi(u.spd, 24):
			MoveSys._set_pos(u, dest)
			MoveSys._arrive(u)
			u.dir = FX.dir_of(u.face)
			return
		if dist <= FX.ONE * 6 / 10 and u.spd <= maxs / 2 and spreads(w, u):
			MoveSys._arrive(u)   # M3.2.2: close enough (separation nudged it off the exact slot)
			u.dir = FX.dir_of(u.face)
			return
	u.dir = FX.dir_of(u.face)
	_step(w, u, u.spd)

## The Reaper never hovers. Idle, a move order and an attack are all the same circle:
## the centre is the target, else the ordered point, else the spot it was left at.
## still holds the orbit bearing. Radius eases in, so a long move is a descending spiral
## that becomes the circle instead of a straight run that stops.
static func _reaper_orbit(w: SimWorld, u: SimEntity, maxs: int, accel_pt: int, brake_pt: int, lp: Dictionary) -> void:
	var center := u.pos
	var rad := FX.ONE * 3
	var tg := w.get_ent(u.target)
	if tg != null and tg.alive:
		center = tg.pos
		rad = FX.ONE * 5
	elif u.goal != MoveSys.NONE:
		center = u.goal
	else:
		if u.done_goal == MoveSys.NONE:
			u.done_goal = u.pos
		center = u.done_goal
	var bearing := FX.iatan2(u.pos.x - center.x, u.pos.y - center.y)
	var cur_r := FX.dist(u.pos, center)
	var far := cur_r > rad + FX.ONE
	# Far away, aim at the near side of the ring so the path curves in. On the ring, walk ahead.
	bearing = (bearing + (2 if far else 8)) % FX.ANG
	if bearing == 0:
		bearing = 8
	u.still = bearing
	var use_r := rad if far else maxi(FX.ONE / 2, cur_r + clampi(rad - cur_r, -FX.ONE / 3, FX.ONE / 5))
	var dv := FX.dir_of(bearing)
	var dest := center + Vector2i(dv.x * use_r / FX.ONE, dv.y * use_r / FX.ONE)
	dest.x = clampi(dest.x, FX.HALF, w.map.w * FX.ONE - FX.HALF)
	dest.y = clampi(dest.y, FX.HALF, w.map.h * FX.ONE - FX.HALF)
	var dist := FX.dist(u.pos, dest)
	if dist > 4:
		u.face = Loco.turn(u.face, FX.iatan2(dest.x - u.pos.x, dest.y - u.pos.y), lp["turn"])
	var gs := maxs * 90 / 100 if cur_r > rad + FX.ONE * 2 else maxs * 62 / 100
	u.spd = mini(gs, u.spd + accel_pt) if u.spd < gs else maxi(gs, u.spd - brake_pt)
	u.spd = maxi(u.spd, gs * 75 / 100)
	u.dir = FX.dir_of(u.face)
	_step(w, u, u.spd)

static func _step(w: SimWorld, u: SimEntity, spd: int) -> void:
	var hv := FX.dir_of(u.face)
	var np := u.pos + Vector2i(hv.x * spd / FX.ONE, hv.y * spd / FX.ONE)
	np.x = clampi(np.x, FX.HALF, w.map.w * FX.ONE - FX.HALF)
	np.y = clampi(np.y, FX.HALF, w.map.h * FX.ONE - FX.HALF)
	MoveSys._set_pos(u, np)

# ------------------------------------------------------------------ M3.2.2 air spreading
## A big group of helicopters given one order used to stack into one ball over the same point.
## Now: (1) group moves give every aircraft its own slot of a loose sunflower formation
## (air_slots, ~AIR_SLOT apart, no terrain limits); (2) on attack each hovering aircraft heads
## for its own point around the target inside weapon range (attack_slot, angle from its id),
## so the group fans out along the range ring; (3) a gentle separation push keeps hovering
## aircraft from overlapping (separate: spatial-grid neighbours only, integer maths, ids order,
## so it stays deterministic and cheap). Jets (runway / taxi / landing / rearm, circling) and
## suicide drones are left out of (2) and (3); jets only get their own move slot.
const AIR_SLOT := FX.ONE * 20 / 10     ## formation spacing (heli radius 0.65 tile -> ~0.5 tile gap)
const AIR_GAP := FX.ONE * 3 / 10       ## separation: keep radius + radius + this apart
const AIR_PUSH := 40                   ## max separation step per tick (fx; ~0.8 tile/s)
const GOLDEN := 391                    ## golden angle in FX.ANG units (1024 * 0.381966)

static func air_slots(w: SimWorld, center: Vector2i, n: int) -> Array:
	var out: Array = []
	for i in n:
		var p := center
		if i > 0:
			# Vogel spiral: r = c * sqrt(i), angle = i * golden angle -> even spacing ~AIR_SLOT
			var r := AIR_SLOT * 56 / 100 * FX.isqrt(i * FX.ONE * FX.ONE) / FX.ONE
			var dv := FX.dir_of((i * GOLDEN) % FX.ANG)
			p = center + Vector2i(dv.x * r / FX.ONE, dv.y * r / FX.ONE)
		p.x = clampi(p.x, FX.HALF, w.map.w * FX.ONE - FX.HALF)
		p.y = clampi(p.y, FX.HALF, w.map.h * FX.ONE - FX.HALF)
		out.append(p)
	return out

## hovering aircraft that take part in attack spreading / separation
static var _spread_def := {}   ## def id -> bool (static content data, safe to cache)
static func spreads(w: SimWorld, u: SimEntity) -> bool:
	if u.air_state != FLYING or u.kind != SimEntity.Kind.UNIT:
		return false
	var v = _spread_def.get(u.def_id)
	if v == null:
		var d: UnitDef = Content.unit(u.def_id)
		v = d.move_layer == &"air" and not d.tags.has("jet") and not d.tags.has("suicide") and not d.tags.has("reaper")
		_spread_def[u.def_id] = v
	return v

## a fixed spot for this unit around the target, at ~60-85 % of weapon range (angle and depth from
## its id, so a group spreads all round and in depth, and the spot does not wobble while it flies)
static func attack_slot(w: SimWorld, u: SimEntity, t: SimEntity, rng: int) -> Vector2i:
	var dv := FX.dir_of((u.id * GOLDEN) % FX.ANG)
	var r := rng * (60 + (u.id * 7) % 26) / 100
	var p := t.pos + Vector2i(dv.x * r / FX.ONE, dv.y * r / FX.ONE)
	p.x = clampi(p.x, FX.HALF, w.map.w * FX.ONE - FX.HALF)
	p.y = clampi(p.y, FX.HALF, w.map.h * FX.ONE - FX.HALF)
	return p

static func separate(w: SimWorld) -> void:
	# own 2-tile bucket grid of just the hovering aircraft (built in ids order -> deterministic)
	const CELL := FX.ONE * 2
	var list: Array = []
	var grid := {}
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.res_id < 0 or not spreads(w, u):
			continue
		list.append(u)
		var k: int = (u.pos.y / CELL) * 4096 + u.pos.x / CELL
		if grid.has(k):
			grid[k].append(u)
		else:
			grid[k] = [u]
	if list.size() < 2:
		return
	for u: SimEntity in list:
		var push := Vector2i.ZERO
		var cx: int = u.pos.x / CELL
		var cy: int = u.pos.y / CELL
		for yy in range(cy - 1, cy + 2):
			for xx in range(cx - 1, cx + 2):
				var arr = grid.get(yy * 4096 + xx)
				if arr == null:
					continue
				for n: SimEntity in arr:
					if n == u:
						continue
					var minr := u.radius + n.radius + AIR_GAP
					var dx := u.pos.x - n.pos.x
					var dy := u.pos.y - n.pos.y
					if absi(dx) >= minr or absi(dy) >= minr:
						continue
					var d2 := dx * dx + dy * dy
					if d2 >= minr * minr:
						continue
					var dd := FX.isqrt(d2)
					if dd == 0:   # exactly stacked: split along a direction from the id pair
						var sv := FX.dir_of(((u.id * 131 + n.id * 17) % FX.ANG) if u.id > n.id else ((n.id * 131 + u.id * 17) % FX.ANG + FX.ANG / 2) % FX.ANG)
						dx = sv.x
						dy = sv.y
						dd = FX.ONE
					var ov := minr - dd
					push += Vector2i(dx * ov / dd, dy * ov / dd) / 2
		if push != Vector2i.ZERO:
			push.x = clampi(push.x, -AIR_PUSH, AIR_PUSH)
			push.y = clampi(push.y, -AIR_PUSH, AIR_PUSH)
			var np := u.pos + push
			np.x = clampi(np.x, FX.HALF, w.map.w * FX.ONE - FX.HALF)
			np.y = clampi(np.y, FX.HALF, w.map.h * FX.ONE - FX.HALF)
			MoveSys._set_pos(u, np)   # (grid buckets keep the start-of-pass cell: fine for a nudge)

# ------------------------------------------------------------------ JTAC
static func _jtac_call(w: SimWorld, j: SimEntity) -> void:
	if w.tick < j.air_t:
		return
	var t := w.get_ent(j.target)
	if t == null or not OrderSys.valid_target(w, j, t) or w.flying(t):
		return
	var best: SimEntity = null
	var bd := JTAC_CALL_RANGE * JTAC_CALL_RANGE
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.owner != j.owner or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
			continue
		var d: UnitDef = w.udef(u)
		if d.move_layer != &"air" or not CombatSys.can_hit(w, u, false):
			continue
		if not u.orders.is_empty() or u.target != 0:
			continue
		if d.tags.has("jet"):
			if u.air_state == RETURNING or (u.air_state == PARKED and u.air_t > 0) or not has_ammo(u, d):
				continue
		var dd := FX.dist2(u.pos, t.pos)
		if dd < bd:
			bd = dd
			best = u
	if best == null:
		return
	best.orders = [{"o": "attack", "target": t.id}]
	best.target = 0
	j.air_t = w.tick + JTAC_CALL_TICKS
	w.events.append({"t": "jtac_call", "id": j.id, "to": best.id, "owner": j.owner, "pos": t.pos})

## Damage % for a shot / blast landing at `pos`: artillery and aircraft get +JTAC_BONUS% when one of
## the shooter's JTACs is within JTAC_RADIUS of the impact.
static func boost_pct(w: SimWorld, src: SimEntity, pos: Vector2i) -> int:
	if src == null or src.kind != SimEntity.Kind.UNIT or src.owner < 0:
		return 100
	var d: UnitDef = w.udef(src)
	if d.move_layer != &"air" and not d.tags.has("artillery"):
		return 100
	return 100 + JTAC_BONUS if jtac_near(w, src.owner, pos) else 100

static func jtac_near(w: SimWorld, owner: int, pos: Vector2i) -> bool:
	for o: SimEntity in w.units_in_radius(pos, JTAC_RADIUS):
		if o.owner == owner and o.res_id >= 0 and w.udef(o).tags.has("jtac"):
			return true
	return false
