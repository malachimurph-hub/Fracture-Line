class_name OrderSys
## Per-unit order state machine: executes the head order, acquires targets.
const NONE := Vector2i(-1, -1)
const TILE := FX.ONE
const LEASH := FX.ONE * 7

static func run(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT:
			continue
		if u.dig != 0:
			u.dig = 0   # M3.7: foxholes removed; an old save's dug-in squad just stands up
		if u.res_id < 0:
			continue
		if u.air_state != AirSys.FLYING and w.is_air(u):
			continue   # parked / returning aircraft: AirSys owns them
		_think(w, u)

## Longest weapon reach. With a target, only weapons that can hit its layer count: a unit with
## a long-range anti-air missile and a short ground gun (US Picket) used to park at missile range
## from a ground target and never fire (M2.8 "turret stuck" fix).
static func max_range(w: SimWorld, u: SimEntity, t: SimEntity = null) -> int:
	var r := 0
	var air := t != null and w.flying(t)
	for wid in w.udef(u).weapons:
		var wd: WeaponDef = Content.weapon(wid)
		if wd.min_tier <= u.tier and (t == null or (wd.targets_air if air else wd.targets_ground)):
			r = maxi(r, FX.mt_to_fx(EccSys.range_mt(w, u, wd.range_mt)))
	return r

static func can_attack(w: SimWorld, u: SimEntity) -> bool:
	return w.udef(u).weapons.size() > 0

## M3.3 P3 (19): the unit's current order is to knock down this empty civilian building.
static func demolishing(w: SimWorld, u: SimEntity, t: SimEntity) -> bool:
	if t.team >= 0 or u.orders.is_empty() or not w.is_civilian(t):
		return false
	var o: Dictionary = u.orders[0]
	return o.get("o", "") == "attack" and int(o.get("target", 0)) == t.id and bool(o.get("force", false))

static func valid_target(w: SimWorld, u: SimEntity, t: SimEntity) -> bool:
	if t == null or not t.alive or t.kind == SimEntity.Kind.RESOURCE:
		return false
	if t.kind == SimEntity.Kind.CRATE or not (w.enemies(u.team, t.team) or demolishing(w, u, t)):
		return false
	if t.kind == SimEntity.Kind.UNIT and t.res_id < 0:
		return false
	# M4.4: the Reaper is only engageable by base defences, never by units.
	# A deployed Pantsir is the one unit that joins that net.
	if t.kind == SimEntity.Kind.UNIT and w.udef(t).tags.has("stealth_defense"):
		var net := u.kind == SimEntity.Kind.BUILDING and w.bdef(u).category == &"defense"
		if not net and u.kind == SimEntity.Kind.UNIT and w.udef(u).tags.has("deploy_aa"):
			net = u.still >= EccSys.DEPLOY_TICKS and not u.moving and u.goal == MoveSys.NONE
		if not net:
			return false
	if not CombatSys.can_hit(w, u, t.kind == SimEntity.Kind.UNIT and w.flying(t)):
		return false
	return w.fog.is_visible_ent(w, u.team, t)

## Best enemy within radius r of point p: armed units first, then unarmed units, then structures.
static func find_target(w: SimWorld, u: SimEntity, p: Vector2i, r: int) -> SimEntity:
	var best: SimEntity = null
	var best_score := 1 << 40
	for e: SimEntity in w.units_in_radius(p, r):
		if not valid_target(w, u, e):
			continue
		# M4.2 smart targeting: distance weighted by how well our weapons hurt this target
		var s := (FX.dist2(u.pos, e.pos) >> 10) * 100 / CombatSys.eff_pct(w, u, e)
		if w.udef(e).weapons.is_empty():
			s += 1 << 24
		if s < best_score:
			best_score = s
			best = e
	if best != null:
		return best
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if b.kind == SimEntity.Kind.UNIT or b.kind == SimEntity.Kind.RESOURCE or b.kind == SimEntity.Kind.CRATE or not b.alive:
			continue
		if not valid_target(w, u, b):
			continue
		var d := w.dist_to_building(p, b)
		if d > r:
			continue
		var bd: BuildingDef = w.bdef(b)
		var s2 := (1 << 26) + d + (0 if bd.weapons.size() > 0 or bd.garrison_capacity > 0 else (1 << 20))
		if s2 < best_score:
			best_score = s2
			best = b
	return best

## M3.3 dozer fix (Malachi: "dozer pathing gets stuck"): the builder used to aim at the one
## ring tile nearest itself and drop the order as unreachable whenever it stopped short (blocked
## by a cliff, a tree line, another structure or a crowd). Now it tries up to BUILD_TRIES free
## ring tiles around the site, nearest first, and once it has stopped close by (within 2 tiles)
## it may work from there.
const BUILD_TRIES := 4
const STALL_TICKS := 60   # 3 s on the same tile

static func build_reach(u: SimEntity, o: Dictionary) -> int:
	return u.radius + (TILE * 2 if o.get("near", false) else TILE)

static func _build_approach(w: SimWorld, u: SimEntity, o: Dictionary, s: SimEntity) -> void:
	var tried: Array = o.get("tried", [])
	var bi := int(o.get("bp", -1))
	if bi >= 0:
		var bp := FX.tile_center(Vector2i(bi % w.map.w, bi / w.map.w))
		# no progress for STALL_TICKS (wedged against a wall or a crowd) counts as stopped too
		var lp := int(o.get("lp", -1))
		var here := w.map.idx(FX.to_tile(u.pos))
		if here == lp:
			o["st"] = int(o.get("st", 0)) + 1
		else:
			o["lp"] = here
			o["st"] = 0
		if not _reached(u, bp) and int(o["st"]) < STALL_TICKS:
			_goto(u, bp)
			return
		o["st"] = 0
		# stopped (arrived or stuck) but still not in reach
		if w.dist_to_building(u.pos, s) <= u.radius + TILE * 2:
			o["near"] = true   # close enough: work from here
			u.goal = NONE
			return
		tried.append(bi)
		o["tried"] = tried
		o.erase("bp")
		if tried.size() >= BUILD_TRIES:
			_pop(u)   # unreachable from every side
			return
	var nt := _ring_tile(w, u, s, tried)
	if nt.x < 0:
		_pop(u)
		return
	o["bp"] = w.map.idx(nt)
	_goto(u, FX.tile_center(nt))

## Nearest passable tile on the ring just outside the footprint, not tried yet; falls back to
## the old nearest-passable search (wider) when the whole ring is blocked.
static func _ring_tile(w: SimWorld, u: SimEntity, s: SimEntity, tried: Array) -> Vector2i:
	var me := FX.to_tile(u.pos)
	var my_reg: int = w.map.region[w.map.idx(me)] if w.map.in_bounds(me) else 0
	var best := NONE
	var bestd := 1 << 30
	for yy in range(-1, s.fp.y + 1):
		for xx in range(-1, s.fp.x + 1):
			if xx >= 0 and xx < s.fp.x and yy >= 0 and yy < s.fp.y:
				continue
			var c := s.tile + Vector2i(xx, yy)
			if not w.map.in_bounds(c) or not w.map.passable(c, true) or _near_tried(w, c, tried):
				continue
			var rc: int = w.map.region[w.map.idx(c)]
			if my_reg != 0 and rc != 0 and rc != my_reg:
				continue   # cut off by terrain (cliff, water) from where the builder is
			var d := (c - me).length_squared()
			if d < bestd:
				bestd = d
				best = c
	if best.x < 0:
		var f := w.map.nearest_passable(me.clamp(s.tile - Vector2i.ONE, s.tile + s.fp), true)
		if w.map.passable(f, true) and not _near_tried(w, f, tried):
			best = f
	return best

## A failed approach tile rules out its neighbours too (they sit in the same blocked pocket).
static func _near_tried(w: SimWorld, c: Vector2i, tried: Array) -> bool:
	for ti in tried:
		var t := Vector2i(int(ti) % w.map.w, int(ti) / w.map.w)
		if absi(t.x - c.x) <= 1 and absi(t.y - c.y) <= 1:
			return true
	return false

static func _goto(u: SimEntity, p: Vector2i) -> void:
	if u.goal != p:
		u.goal = p
		u.done_goal = NONE

static func _reached(u: SimEntity, p: Vector2i) -> bool:
	return u.done_goal == p and u.goal == NONE

static func _pop(u: SimEntity) -> void:
	if not u.orders.is_empty():
		u.orders.pop_front()
	u.target = 0
	u.goal = NONE
	u.home = u.pos

## Engage a target: move into range, CombatSys fires when in range.
static func _engage(w: SimWorld, u: SimEntity, t: SimEntity) -> void:
	u.target = t.id
	var rng := max_range(w, u, t)
	if w.edge_dist(u, t) <= rng:
		u.goal = NONE
		u.path = []
		u.path_goal = NONE
	else:
		var dest := t.pos
		if t.kind != SimEntity.Kind.UNIT and not w.is_air(u):
			dest = FX.tile_center(w.map.nearest_passable(FX.to_tile(t.pos), w.is_vehicle(u)))
		elif AirSys.spreads(w, u):
			dest = AirSys.attack_slot(w, u, t, rng)   # M3.2.2: each helicopter its own spot in range
		if u.goal == NONE or FX.dist2(u.goal, dest) > (TILE * 2) * (TILE * 2):
			_goto(u, dest)

static func _acq_tick(w: SimWorld, u: SimEntity) -> bool:
	return (w.tick + u.id) % 5 == 0

static func _think(w: SimWorld, u: SimEntity) -> void:
	var o: Dictionary = u.head()
	var typ: String = o.get("o", "")
	match typ:
		"":
			_idle(w, u)
		"drop":
			u.target = 0   # AirSys lands the helicopter, then RosterSys unloads
			return
		"move":
			u.target = 0
			if _reached(u, o["pos"]):
				_pop(u)
			else:
				_goto(u, o["pos"])
		"amove":
			_amove(w, u, o)
		"attack":
			var t := w.get_ent(int(o["target"]))
			var demolish: bool = t != null and bool(o.get("force", false)) and t.team < 0 and w.is_civilian(t)   # M3.3 P3: knock an empty house down
			if t == null or not t.alive or (not w.fog.is_visible_ent(w, u.team, t)) or not (w.enemies(u.team, t.team) or demolish):
				_pop(u)
				return
			if not can_attack(w, u):
				_pop(u)
				return
			if w.udef(u).tags.has("demo") and _demo_target(w, t) and w.tick >= u.aux_t:
				var gap := w.edge_dist(u, t) if t.kind == SimEntity.Kind.UNIT else maxi(0, w.dist_to_building(u.pos, t) - u.radius)
				if gap <= TILE:
					u.goal = NONE
					u.moving = false
					u.target = t.id
					o["plant"] = int(o.get("plant", 0)) + 1
					if int(o["plant"]) >= PLANT_TICKS:
						CombatSys.fire(w, u, t, Content.weapon(&"us_seal_charge"), 100)
						u.aux_t = w.tick + PLANT_COOL
						o["plant"] = 0
					return
				o["plant"] = 0
				u.target = t.id
				var dp := t.pos
				if t.kind != SimEntity.Kind.UNIT:
					dp = FX.tile_center(w.map.nearest_passable(FX.to_tile(u.pos).clamp(t.tile - Vector2i.ONE, t.tile + t.fp), false))
				_goto(u, dp)
				return
			_engage(w, u, t)
		"guard":
			_guard(w, u, o)
		"build":
			var s := w.get_ent(int(o["target"]))
			if s == null or s.built or s.owner != u.owner:
				_pop(u)
				return
			if w.dist_to_building(u.pos, s) <= build_reach(u, o):
				u.goal = NONE
			else:
				_build_approach(w, u, o, s)
		"repair":
			_repair(w, u, o)
		"harvest":
			EconSys.harvest_think(w, u)
		"garrison":
			var b := w.get_ent(int(o["target"]))
			if b != null and b.kind == SimEntity.Kind.UNIT:
				var r := RosterSys.board(w, u, b)
				if r < 0:
					_pop(u)
				elif r == 0 and (u.goal == NONE or FX.dist2(u.goal, b.pos) > TILE * TILE):
					_goto(u, b.pos)
				return
			if b == null or (b.owner >= 0 and b.owner != u.owner and w.enemies(b.team, u.team)):
				_pop(u)
				return
			if TplaSys.is_tunnel(w, b):
				_enter_tunnel(w, u, b)
				return
			if w.dist_to_building(u.pos, b) <= u.radius + TILE:
				if garrison_count(w, b) < w.bdef(b).garrison_capacity:
					u.res_id = -b.id
					b.owner = u.owner
					b.team = u.team
					u.goal = NONE
					u.orders.clear()
					w.events.append({"t": "garrison", "id": u.id, "b": b.id})
				else:
					_pop(u)
			else:
				var gp := FX.tile_center(w.map.nearest_passable(FX.to_tile(u.pos).clamp(b.tile - Vector2i.ONE, b.tile + b.fp), false))
				if _reached(u, gp):
					_pop(u)
				else:
					_goto(u, gp)
		"capture":
			var c := w.get_ent(int(o["target"]))
			if c == null or c.owner == u.owner:
				_pop(u)
				return
			if c.kind == SimEntity.Kind.BUILDING and not CommandSys.can_capture_building(w, u.owner, c):
				_pop(u)
				return
			if w.dist_to_building(u.pos, c) <= u.radius + TILE:
				u.goal = NONE
				u.moving = false
				o["prog"] = int(o.get("prog", 0)) + 1
				var need := CAPTURE_TICKS if c.kind == SimEntity.Kind.BUILDING else 100   # 6 s structures, 5 s neutral
				if o["prog"] >= need:
					if c.kind == SimEntity.Kind.BUILDING:
						w._eject_garrison(c)   # defenders / tunnel occupants spill out; captured queue is dropped
						c.queue.clear()
						c.q_progress = 0
						c.q_paid.clear()
						c.repeat = false
					c.owner = u.owner
					c.team = u.team
					w.events.append({"t": "captured", "id": c.id, "owner": u.owner})
					_pop(u)
			else:
				o["prog"] = 0
				var cp := FX.tile_center(w.map.nearest_passable(FX.to_tile(u.pos).clamp(c.tile - Vector2i.ONE, c.tile + c.fp), w.is_vehicle(u)))
				if _reached(u, cp):
					_pop(u)
				else:
					_goto(u, cp)

const CAPTURE_TICKS := 120
const PLANT_TICKS := 60       ## M4.4 SEAL: 3 s to set a charge
const PLANT_COOL := 400       ## 20 s before the next charge

static func _demo_target(w: SimWorld, t: SimEntity) -> bool:
	if t.kind == SimEntity.Kind.BUILDING or t.kind == SimEntity.Kind.NEUTRAL:
		return true
	return t.kind == SimEntity.Kind.UNIT and w.is_vehicle(t)

## M3.1 building repair (Zero Hour dozer style): next to the structure, each builder restores
## REPAIR_TICKS-th of its max HP per tick (a full repair takes ~30 s for one builder) and pays as
## it goes: a 0-to-full repair costs REPAIR_COST_PCT % of the building's price. With no supply the
## builder waits. It stays until the building is at full HP, then the order ends.
const REPAIR_TICKS := 600
const REPAIR_COST_PCT := 25

static func _repair(w: SimWorld, u: SimEntity, o: Dictionary) -> void:
	var b := w.get_ent(int(o["target"]))
	if b == null or not b.alive or b.owner != u.owner or not b.built or b.hp >= b.max_hp:
		if b != null and b.alive and b.hp >= b.max_hp and o.has("busy"):
			w.events.append({"t": "repaired", "id": b.id, "owner": u.owner})
		_pop(u)
		return
	if w.dist_to_building(u.pos, b) <= u.radius + TILE:
		u.goal = NONE
		o["busy"] = true
		var rate := maxi(1, b.max_hp / REPAIR_TICKS)
		var add := mini(rate, b.max_hp - b.hp)
		# cost in thousandths of a supply unit, carried between ticks (deterministic integers)
		var acc: int = int(o.get("acc", 0)) + w.bdef(b).cost * REPAIR_COST_PCT * 10 * add / b.max_hp
		var p: SimPlayer = w.players[u.owner]
		var due := acc / 1000
		if due > p.supply:
			return   # out of money: wait
		p.supply -= due
		o["acc"] = acc - due * 1000
		b.hp += add
		if (w.tick + u.id) % 10 == 0:
			w.events.append({"t": "repair", "id": b.id, "by": u.id})
	else:
		var rp := FX.tile_center(w.map.nearest_passable(FX.to_tile(u.pos).clamp(b.tile - Vector2i.ONE, b.tile + b.fp), true))
		if _reached(u, rp):
			_pop(u)   # unreachable
		else:
			_goto(u, rp)

static func _enter_tunnel(w: SimWorld, u: SimEntity, b: SimEntity) -> void:
	if b.owner != u.owner or not b.built:
		_pop(u)
		return
	var veh := w.is_vehicle(u)
	if w.dist_to_building(u.pos, b) <= u.radius + TILE * (2 if veh else 1):
		if TplaSys.network_units(w, u.owner).size() < TplaSys.network_capacity():
			u.res_id = -b.id
			u.goal = NONE
			u.path = []
			u.orders.clear()
			u.target = 0
			w.events.append({"t": "garrison", "id": u.id, "b": b.id})
		else:
			w.events.append({"t": "reject", "owner": u.owner, "reason": "REASON_TUNNEL_FULL"})
			_pop(u)
	else:
		var gp := FX.tile_center(w.exit_tile(b, veh))
		if _reached(u, gp):
			_pop(u)
		else:
			_goto(u, gp)

static func garrison_count(w: SimWorld, b: SimEntity) -> int:
	var n := 0
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.res_id == -b.id:
			n += 1
	return n

static func _idle(w: SimWorld, u: SimEntity) -> void:
	var d: UnitDef = w.udef(u)
	if d.harvest_capacity > 0 and w.tick % 20 == u.id % 20:
		if EconSys.auto_harvest(w, u):
			return
	if not can_attack(w, u):
		if u.goal == NONE and FX.dist2(u.pos, u.home) > TILE * TILE * 4:
			u.home = u.pos
		return
	var t := w.get_ent(u.target)
	if t != null and valid_target(w, u, t) and FX.dist(u.home, u.pos) < LEASH:
		_engage(w, u, t)
		return
	u.target = 0
	if _acq_tick(w, u):
		var r := max_range(w, u) + TILE
		if w.tick - u.last_hit_tick < 40:
			r = maxi(r, u.sight * TILE)
		var nt := find_target(w, u, u.pos, r)
		if nt != null:
			_engage(w, u, nt)
			return
	# return to home after a chase
	if u.goal == NONE and FX.dist2(u.pos, u.home) > TILE * TILE * 4:
		if u.done_goal == u.home:
			u.home = u.pos
		else:
			_goto(u, u.home)

## Dug-in squad: keep a target only while it is in weapon range; no move orders.
static func _hold(w: SimWorld, u: SimEntity) -> void:
	var t := w.get_ent(u.target)
	if t != null and valid_target(w, u, t) and w.edge_dist(u, t) <= max_range(w, u, t):
		return
	u.target = 0
	if _acq_tick(w, u):
		var nt := find_target(w, u, u.pos, max_range(w, u))
		if nt != null and w.edge_dist(u, nt) <= max_range(w, u, nt):
			u.target = nt.id

static func _amove(w: SimWorld, u: SimEntity, o: Dictionary) -> void:
	var dest: Vector2i = o["pos"]
	if can_attack(w, u):
		var t := w.get_ent(u.target)
		if t != null and valid_target(w, u, t) and FX.dist(u.pos, t.pos) < u.sight * TILE + TILE * 2:
			_engage(w, u, t)
			return
		u.target = 0
		if _acq_tick(w, u) or u.goal == NONE:
			var nt := find_target(w, u, u.pos, maxi(max_range(w, u) + TILE * 2, u.sight * TILE))
			if nt != null:
				_engage(w, u, nt)
				return
	if _reached(u, dest):
		_pop(u)
	else:
		_goto(u, dest)

static func _guard(w: SimWorld, u: SimEntity, o: Dictionary) -> void:
	var gp: Vector2i = o["pos"]
	if can_attack(w, u):
		var t := w.get_ent(u.target)
		if t != null and valid_target(w, u, t) and FX.dist(gp, t.pos) < max_range(w, u) + TILE * 4:
			_engage(w, u, t)
			return
		u.target = 0
		if _acq_tick(w, u):
			var nt := find_target(w, u, gp, max_range(w, u) + TILE * 3)
			if nt != null:
				_engage(w, u, nt)
				return
	if FX.dist2(u.pos, gp) > TILE * TILE and not _reached(u, gp):
		_goto(u, gp)
