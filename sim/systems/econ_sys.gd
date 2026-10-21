class_name EconSys
## Harvesting (Harvester Rig <-> seam/cache <-> Logistics Hub), Hub passive income, captured Pumps.

const GATHER_PER_TICK := 4      ## 400 load in ~5 s
const UNLOAD_TICKS := 40        ## 2 s at the dock
const NEAR := FX.ONE * 3 / 2

static func run(w: SimWorld) -> void:
	if w.tick % 20 != 0:
		return
	var hubs := {}
	var pumps := {}
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.owner < 0:
			continue
		if e.kind == SimEntity.Kind.BUILDING and e.built and e.powered:
			var d: BuildingDef = w.bdef(e)
			if d.passive_income > 0:
				hubs[e.owner] = hubs.get(e.owner, 0) + 1
		elif e.kind == SimEntity.Kind.NEUTRAL and w.bdef(e).capture_income > 0:
			pumps[e.owner] = pumps.get(e.owner, 0) + w.bdef(e).capture_income
	for p in w.players:
		if p.eliminated:
			continue
		var h: int = mini(4, hubs.get(p.id, 0))
		var inc := 3 * h
		if p.low_power:
			inc /= 2
		if p.logistics_until > w.tick:
			inc *= 2
		inc += int(pumps.get(p.id, 0))
		add_supply(w, p, inc)

static func add_supply(w: SimWorld, p: SimPlayer, amount: int) -> void:
	p.supply = mini(SimWorld.SUPPLY_CAP, p.supply + amount)
	p.stats["harvested"] += amount

static func nearest_hub(w: SimWorld, u: SimEntity) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 50
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.owner == u.owner and e.kind == SimEntity.Kind.BUILDING and e.built and w.bdef(e).is_refinery:
			var d := FX.dist2(e.pos, u.pos)
			if d < bd:
				bd = d
				best = e
	return best

static func nearest_resource(w: SimWorld, p: Vector2i, max_tiles: int = 60) -> SimEntity:
	var best: SimEntity = null
	var bd := (max_tiles * FX.ONE) * (max_tiles * FX.ONE)
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.RESOURCE and e.amount > 0:
			var d := FX.dist2(e.pos, p)
			if d < bd:
				bd = d
				best = e
	return best

static func auto_harvest(w: SimWorld, u: SimEntity) -> bool:
	if u.phase < 0:
		return false
	var hub := nearest_hub(w, u)
	if hub == null:
		return false
	var r := nearest_resource(w, hub.pos)
	if r == null:
		return false
	u.res_id = r.id
	u.phase = 0 if u.carry < w.udef(u).harvest_capacity else 2
	u.orders = [{"o": "harvest"}]
	return true

static func harvest_think(w: SimWorld, u: SimEntity) -> void:
	var cap := w.udef(u).harvest_capacity
	match u.phase:
		0, -1:
			u.phase = 0
			var r := w.get_ent(u.res_id)
			if r == null or r.amount <= 0:
				var from := u.pos
				var hub0 := nearest_hub(w, u)
				if hub0 != null:
					from = hub0.pos
				r = nearest_resource(w, from)
				if r == null:
					if u.carry > 0:
						u.phase = 2
					else:
						u.orders.clear()
						u.goal = Vector2i(-1, -1)
					return
				u.res_id = r.id
			if FX.dist(u.pos, r.pos) <= NEAR:
				u.goal = Vector2i(-1, -1)
				u.phase = 1
			else:
				if OrderSys._reached(u, r.pos):
					u.phase = 1 if FX.dist(u.pos, r.pos) <= NEAR * 2 else 0
					if u.phase == 0:
						u.done_goal = Vector2i(-1, -1)
				else:
					OrderSys._goto(u, r.pos)
		1:
			var r1 := w.get_ent(u.res_id)
			if r1 == null or r1.amount <= 0:
				u.phase = 2 if u.carry > 0 else 0
				return
			var take := mini(GATHER_PER_TICK, mini(r1.amount, cap - u.carry))
			r1.amount -= take
			u.carry += take
			if u.carry >= cap or r1.amount <= 0:
				u.phase = 2
				if r1.amount <= 0:
					w.events.append({"t": "depleted", "id": r1.id})
		2:
			var hub := nearest_hub(w, u)
			if hub == null:
				u.goal = Vector2i(-1, -1)
				return
			var dock := w.dock_point(hub)
			if FX.dist(u.pos, dock) <= NEAR or w.dist_to_building(u.pos, hub) <= u.radius + FX.ONE / 2:
				u.goal = Vector2i(-1, -1)
				u.phase = 3
				u.phase_t = 0
			elif OrderSys._reached(u, dock):
				u.phase = 3
				u.phase_t = 0
			else:
				OrderSys._goto(u, dock)
		3:
			u.phase_t += 1
			if u.phase_t >= UNLOAD_TICKS:
				add_supply(w, w.players[u.owner], u.carry)
				w.events.append({"t": "unload", "id": u.id, "amount": u.carry})
				u.carry = 0
				u.phase = 0
