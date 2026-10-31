class_name RosterSys
## M2.4 roster mechanics (ZH 1:1 widening), deterministic sim code:
## - transports: infantry board a friendly vehicle with transport_capacity (Wolfhound 4,
##   Sentinel 2, Rust Bus 8). Passengers are stored like garrisons (res_id = -transport id),
##   ride along, and get out on Unload or when the transport is destroyed.
## - jammer: enemy vehicles within JAM_RADIUS of a Spectre Jammer cannot fire.
## - heal aura: a powered Field Relay Mast heals own units in aux_radius by 1 % / s.
## - detectors (UnitDef.detector) reveal hidden structures (mines, traps, camo) in their sight;
##   see TplaSys._stealth.

const JAM_RADIUS := FX.ONE * 6
const HEAL_PCT := 1

static func run(w: SimWorld) -> void:
	_carry(w)
	if w.tick % 20 == 11:
		_heal_auras(w)
	if w.tick % 10 == 3:
		_field_repair(w)

## M3.2 German Field Engineer: while not moving, repairs the most damaged own vehicle within
## FIELD_REPAIR_R (2 % max hp per 0.5 s, free). Structures use the builder "repair" order.
const FIELD_REPAIR_R := FX.ONE * 2
static func _field_repair(w: SimWorld) -> void:
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.kind != SimEntity.Kind.UNIT or e.res_id < 0 or e.moving or not w.udef(e).tags.has("field_engineer"):
			continue
		var best: SimEntity = null
		var worst := 101
		for u: SimEntity in w.units_in_radius(e.pos, FIELD_REPAIR_R + 400):
			if u.owner != e.owner or u.res_id < 0 or not w.is_vehicle(u) or w.flying(u) or u.hp >= u.max_hp:
				continue
			var pct := u.hp * 100 / maxi(1, u.max_hp)
			if pct < worst:
				worst = pct
				best = u
		if best != null:
			best.hp = mini(best.max_hp, best.hp + maxi(1, best.max_hp * 2 / 100))
			w.events.append({"t": "repair_fx", "id": best.id, "by": e.id})

# ------------------------------------------------------------------ transports
static func capacity(w: SimWorld, t: SimEntity) -> int:
	if t == null or not t.alive or t.kind != SimEntity.Kind.UNIT:
		return 0
	return w.udef(t).transport_capacity

static func passengers(w: SimWorld, t: SimEntity) -> Array:
	var out: Array = []
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and u.res_id == -t.id:
			out.append(u)
	return out

## M3.5: a Combat Squad (six soldiers) takes SQUAD_SEATS of a transport's capacity.
const SQUAD_SEATS := 3
static func seats(w: SimWorld, u: SimEntity) -> int:
	return SQUAD_SEATS if Content.is_squad(u.def_id) else 1

static func load_of(w: SimWorld, t: SimEntity) -> int:
	var n := 0
	for u: SimEntity in passengers(w, t):
		n += seats(w, u)
	return n

static func can_board(w: SimWorld, u: SimEntity) -> bool:
	return w.udef(u).tags.has("infantry") and not w.udef(u).tags.has("builder")

## Passengers ride with their transport (positions only; they are skipped by move/combat/fog).
static func _carry(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id >= 0:
			continue
		var t: SimEntity = w.ents.get(-u.res_id)
		if t != null and t.kind == SimEntity.Kind.UNIT:
			u.pos = t.pos

## Board order step: walk to the transport, get in when adjacent and there is room.
static func board(w: SimWorld, u: SimEntity, t: SimEntity) -> int:
	## returns 1 = boarded, 0 = keep walking, -1 = give up
	if capacity(w, t) <= 0 or t.owner != u.owner or t.res_id < 0:
		return -1
	if FX.dist(u.pos, t.pos) <= u.radius + t.radius + FX.ONE:
		if load_of(w, t) + seats(w, u) > capacity(w, t):
			w.events.append({"t": "reject", "owner": u.owner, "reason": "REASON_TRANSPORT_FULL"})
			return -1
		u.res_id = -t.id
		u.goal = Vector2i(-1, -1)
		u.path = []
		u.orders.clear()
		u.target = 0
		u.pos = t.pos
		w.events.append({"t": "garrison", "id": u.id, "b": t.id})
		return 1
	return 0

## Everyone out, around the transport. stun_ticks > 0 when bailing out of a wreck.
static func unload(w: SimWorld, t: SimEntity, stun_ticks: int = 0) -> void:
	var k := 0
	for u: SimEntity in passengers(w, t):
		var off := Vector2i([-1, 1, 0, 0, -1, 1, -1, 1][k % 8], [0, 0, -1, 1, -1, 1, 1, -1][k % 8])
		var tile := w.map.nearest_passable(FX.to_tile(t.pos) + off, false)
		u.res_id = 0
		u.pos = FX.tile_center(tile)
		u.orders.clear()
		u.goal = Vector2i(-1, -1)
		if stun_ticks > 0:
			u.phase_t = w.tick + stun_ticks
		w.events.append({"t": "unload", "id": u.id, "b": t.id})
		k += 1

# ------------------------------------------------------------------ jammer
## Enemy Spectre Jammers in the match (cheap pre-pass for CombatSys).
static func jammers(w: SimWorld) -> Array:
	var out: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and e.res_id >= 0 and e.owner >= 0 and w.udef(e).tags.has("jammer"):
			out.append(e)
	return out

static func is_jammed(w: SimWorld, u: SimEntity, js: Array) -> bool:
	if js.is_empty() or not w.is_vehicle(u):
		return false
	for j: SimEntity in js:
		if w.enemies(j.team, u.team) and FX.dist2(j.pos, u.pos) <= JAM_RADIUS * JAM_RADIUS:
			return true
	return false

# ------------------------------------------------------------------ heal aura
static func _heal_auras(w: SimWorld) -> void:
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if not b.alive or b.kind != SimEntity.Kind.BUILDING or not b.built or not b.powered:
			continue
		var bd: BuildingDef = w.bdef(b)
		if not bd.tags.has("heal_aura"):
			continue
		for u: SimEntity in w.units_in_radius(b.pos, bd.aux_radius * FX.ONE):
			if u.owner == b.owner and u.hp < u.max_hp:
				u.hp = mini(u.max_hp, u.hp + maxi(1, u.max_hp * HEAL_PCT / 100))
