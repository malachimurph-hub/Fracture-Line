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
		elif d.tags.has("jtac"):
			jtacs.append(u)
	if w.tick % 20 == 5:
		for j: SimEntity in jtacs:
			_jtac_call(w, j)

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

## Parking spot: the airfield pad has 6 slots (3 x 2); a jet parks at the centre of its slots.
static func parking_pos(w: SimWorld, home: SimEntity, u: SimEntity) -> Vector2i:
	var start := 0
	for id in w.ids:
		var o: SimEntity = w.ents[id]
		if not o.alive or o.kind != SimEntity.Kind.UNIT or o.air_home != home.id:
			continue
		if o.id == u.id:
			break
		start += w.udef(o).air_slots
	var n := maxi(1, w.udef(u).air_slots)
	var acc := Vector2i.ZERO
	for k in range(start, start + n):
		var kk := k % 6
		acc += Vector2i(FX.ONE * 2 / 3 + (kk % 3) * FX.ONE * 4 / 3, FX.ONE + (kk / 3) * FX.ONE * 2)
	return Vector2i(home.tile.x * FX.ONE, home.tile.y * FX.ONE) + acc / n

## A freshly built jet appears parked on its airfield, armed.
static func park_new(w: SimWorld, b: SimEntity, u: SimEntity) -> void:
	u.air_home = b.id
	u.air_state = PARKED
	u.air_t = 0
	u.pos = parking_pos(w, b, u)
	u.home = u.pos
	u.face = FX.ANG / 2 if b.rot == 2 else 0
	u.tface = u.face
	u.orders = []
	CombatSys._ensure(u, w.udef(u))

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
				u.air_state = FLYING
				u.phase_t = 0
				w.events.append({"t": "takeoff", "id": u.id})
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
			var pp := parking_pos(w, home, u)
			u.goal = pp
			if FX.dist(u.pos, pp) <= FX.ONE * 3 / 4:
				u.air_state = PARKED
				u.pos = pp
				u.goal = NONE
				u.done_goal = NONE
				u.spd = 0
				u.face = FX.ANG / 2 if home.rot == 2 else 0
				u.air_t = _rearm_ticks(u, d)
				if u.air_t == 0:
					_rearm(u, d)
				w.events.append({"t": "landed", "id": u.id})
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

# ------------------------------------------------------------------ flight
## Called by MoveSys for every aircraft instead of ground path following.
static func fly(w: SimWorld, u: SimEntity, d: UnitDef) -> void:
	u.moving = false
	if u.air_state == PARKED:
		u.spd = 0
		return
	var lp := Loco.params(d)
	var maxs := FX.speed_per_tick(d.speed_mtps)
	if u.vet >= 2:
		maxs = maxs * 110 / 100
	var jet := d.tags.has("jet")
	var brake_pt := maxi(1, maxs * 50 / maxi(1, int(lp["brake_ms"])))
	var accel_pt := maxi(1, maxs * 50 / maxi(1, int(lp["accel_ms"])))
	var dest := u.goal
	var loiter := false
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
	u.dir = FX.dir_of(u.face)
	_step(w, u, u.spd)

static func _step(w: SimWorld, u: SimEntity, spd: int) -> void:
	var hv := FX.dir_of(u.face)
	var np := u.pos + Vector2i(hv.x * spd / FX.ONE, hv.y * spd / FX.ONE)
	np.x = clampi(np.x, FX.HALF, w.map.w * FX.ONE - FX.HALF)
	np.y = clampi(np.y, FX.HALF, w.map.h * FX.ONE - FX.HALF)
	MoveSys._set_pos(u, np)

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
