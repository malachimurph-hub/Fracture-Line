class_name OrderSys
## Per-unit order state machine: executes the head order, acquires targets.
const NONE := Vector2i(-1, -1)
const TILE := FX.ONE
const LEASH := FX.ONE * 7

static func run(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
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
			r = maxi(r, FX.mt_to_fx(wd.range_mt))
	return r

static func can_attack(w: SimWorld, u: SimEntity) -> bool:
	return w.udef(u).weapons.size() > 0

static func valid_target(w: SimWorld, u: SimEntity, t: SimEntity) -> bool:
	if t == null or not t.alive or t.kind == SimEntity.Kind.RESOURCE:
		return false
	if t.kind == SimEntity.Kind.CRATE or not w.enemies(u.team, t.team):
		return false
	if t.kind == SimEntity.Kind.UNIT and t.res_id < 0:
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
		var s := FX.dist2(u.pos, e.pos) >> 10
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
			if t == null or not t.alive or (not w.fog.is_visible_ent(w, u.team, t)) or not w.enemies(u.team, t.team):
				_pop(u)
				return
			if not can_attack(w, u):
				_pop(u)
				return
			_engage(w, u, t)
		"guard":
			_guard(w, u, o)
		"build":
			var s := w.get_ent(int(o["target"]))
			if s == null or s.built or s.owner != u.owner:
				_pop(u)
				return
			if w.dist_to_building(u.pos, s) <= u.radius + TILE:
				u.goal = NONE
			else:
				var bp := FX.tile_center(w.map.nearest_passable(FX.to_tile(u.pos).clamp(s.tile - Vector2i.ONE, s.tile + s.fp), true))
				if _reached(u, bp):
					_pop(u)   # unreachable
				else:
					_goto(u, bp)
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
			if w.dist_to_building(u.pos, c) <= u.radius + TILE:
				u.goal = NONE
				o["prog"] = int(o.get("prog", 0)) + 1
				if o["prog"] >= 100:   # 5 s
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
