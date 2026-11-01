class_name EconSys
## Harvesting (Harvester Rig <-> seam/cache <-> Logistics Hub), Hub passive income, captured Pumps.

const GATHER_PER_TICK := 4      ## 400 load in ~5 s
const UNLOAD_TICKS := 40        ## 2 s at the dock
const UNLOAD_TICKS_FOOT := 10   ## TPLA Laborers drop their load in 0.5 s
const NEAR := FX.ONE * 3 / 2

static func run(w: SimWorld) -> void:
	if w.tick % 20 != 0:
		return
	var hubs := {}       ## owner -> {def id: [count, income]}
	var earners := {}    ## M3.3: owner -> {def id: count} for income_amount structures
	var pumps := {}
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.owner < 0:
			continue
		if e.kind == SimEntity.Kind.BUILDING and e.built and e.powered:
			var d: BuildingDef = w.bdef(e)
			if d.passive_income > 0:
				if not hubs.has(e.owner):
					hubs[e.owner] = {}
				var cur: Array = hubs[e.owner].get(d.id, [0, d.passive_income])
				cur[0] += 1
				hubs[e.owner][d.id] = cur
			if d.income_amount > 0 and d.income_period_s > 0 and not (e.aux_t > 0 and d.tags.has("mobile")):   # packing: no income
				if not earners.has(e.owner):
					earners[e.owner] = {}
				earners[e.owner][d.id] = int(earners[e.owner].get(d.id, 0)) + 1
		elif e.kind == SimEntity.Kind.NEUTRAL and w.bdef(e).capture_income > 0:
			pumps[e.owner] = pumps.get(e.owner, 0) + w.bdef(e).capture_income
	for p in w.players:
		if p.eliminated:
			continue
		# passive income: every copy of an income structure pays (EU Hub +3/s, TPLA Scrap
		# Bazaar +6/s; M3.7.1, Malachi: no cap - was the first 4 copies of a type)
		var inc := 0
		for did in hubs.get(p.id, {}):
			var hc: Array = hubs[p.id][did]
			inc += int(hc[0]) * int(hc[1])
		if p.low_power:
			inc /= 2
		var sec := w.tick / FX.TICK_HZ
		for did in earners.get(p.id, {}):
			var ed: BuildingDef = Content.building(did)
			var pay := period_pay(ed, int(earners[p.id][did]), sec)
			if p.low_power and not ed.tags.has("no_power"):
				pay /= 2
			if pay > 0 and ed.tags.has("income_burst"):
				w.events.append({"t": "income", "owner": p.id, "def": did, "amount": pay})
			inc += pay
		if p.logistics_until > w.tick:
			inc *= 2
		inc += int(pumps.get(p.id, 0))
		add_supply(w, p, inc)

## M3.3: what n copies of an income structure pay in second `sec`. The amount per period is paid
## out evenly (integer steps that add up exactly over each period), or all at once on the last
## second of the period for "income_burst" structures (Russia's mine: $400 every 30 s).
static func period_pay(d: BuildingDef, n: int, sec: int) -> int:
	var per := maxi(1, d.income_period_s)
	var total := d.income_amount * n
	var k := sec % per
	if d.tags.has("income_burst"):
		return total if k == per - 1 else 0
	return total * (k + 1) / per - total * k / per

## M3.3: income per minute of one copy (info cards, HUD).
static func per_minute(d: BuildingDef) -> int:
	if d.income_amount > 0 and d.income_period_s > 0:
		return d.income_amount * 60 / d.income_period_s
	return d.passive_income * 60

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
				# nowhere to deliver (all refineries lost): go idle, keeping the cargo
				u.goal = Vector2i(-1, -1)
				u.orders.clear()
				u.phase = -1
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
			if u.phase_t >= (UNLOAD_TICKS if w.is_vehicle(u) else UNLOAD_TICKS_FOOT):
				add_supply(w, w.players[u.owner], u.carry)
				w.events.append({"t": "unload", "id": u.id, "amount": u.carry})
				u.carry = 0
				u.phase = 0
