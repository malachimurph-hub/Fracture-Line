class_name TplaSys
## TPLA (insurgent faction) mechanics, all deterministic sim code (GDD 3, 5.4, 7.2):
## - stealth: Demo Traps are always hidden; structures under a Camo Net are hidden until they
##   fire. Any enemy unit within DETECT range spots a hidden structure (no detector units yet).
## - Demo Traps: detonate when an enemy ground unit comes within TRAP_TRIGGER.
## - salvage: destroyed vehicles leave a salvage crate (when a TPLA player is in the match).
##   A TPLA salvage vehicle that drives over it gains a tier (max 3: +HP, +damage, bolt-on
##   weapons); other TPLA units (and tier-3 vehicles) turn it into Supply.
## - rebuild holes: a destroyed TPLA structure leaves a hole; after HOLE_DELAY a Laborer climbs
##   out and rebuilds it for free unless the hole is destroyed first.
## - tunnel network: one shared garrison for all of a player's tunnels; units enter any tunnel
##   and leave from any other instantly; units inside heal; losing the last tunnel kills them.
## - rust zones: corrosive weapons leave a patch that damages enemies over time.

const TIER_HP := 15          ## % max HP per salvage tier
const TIER_DMG := 20         ## % damage per salvage tier
const DETECT := FX.ONE * 2
const TRAP_TRIGGER := FX.ONE * 3 / 2
const CRATE_LIFE := 60 * 20
const HOLE_DELAY := 40 * 20
const TUNNEL_HEAL_PCT := 4   ## % max HP per second inside a tunnel
const REVEAL_AFTER_FIRE := 60

static func run(w: SimWorld) -> void:
	if not w.pending_holes.is_empty():
		_open_holes(w)
	if not w.has_tpla and w.zones.is_empty():
		return
	if w.tick % 4 == 1:
		_stealth(w)
		_traps(w)
		_crates(w)
	if w.tick % 10 == 3 and not w.zones.is_empty():
		_zones(w)
	if w.tick % 20 == 7:
		_holes(w)
		_tunnel_heal(w)

# ------------------------------------------------------------------ stealth / traps
static func _stealth(w: SimWorld) -> void:
	var nets := {}
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.BUILDING and e.built and Content.btag(e.def_id, "camo"):
			if not nets.has(e.owner):
				nets[e.owner] = []
			nets[e.owner].append(e)
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.kind != SimEntity.Kind.BUILDING or e.owner < 0:
			continue
		var bd: BuildingDef = w.bdef(e)
		var hide := false
		if e.built:
			if bd.tags.has("stealth"):
				hide = true
			elif nets.has(e.owner) and w.tick - e.firing_tick > REVEAL_AFTER_FIRE and not bd.tags.has("hole"):
				for n: SimEntity in nets[e.owner]:
					var r: int = w.bdef(n).aux_radius * FX.ONE
					if FX.dist2(n.pos, e.pos) <= r * r:
						hide = true
						break
		if hide != e.stealthy:
			e.stealthy = hide
			w.events.append({"t": "stealth", "id": e.id, "on": hide})
		var mask := 0
		if hide:
			for u: SimEntity in w.units_in_radius(e.pos, DETECT + e.radius):
				if u.team >= 0 and w.enemies(u.team, e.team):
					mask |= 1 << u.team
		e.stealth_mask = mask

static func _traps(w: SimWorld) -> void:
	var fire: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.kind != SimEntity.Kind.BUILDING or not e.built or not Content.btag(e.def_id, "trap"):
			continue
		for u: SimEntity in w.units_in_radius(e.pos, TRAP_TRIGGER):
			if u.res_id >= 0 and w.enemies(e.team, u.team):
				fire.append(e)
				break
	for t: SimEntity in fire:
		detonate_trap(w, t)

static func detonate_trap(w: SimWorld, t: SimEntity) -> void:
	if not t.alive:
		return
	CombatSys.explode(w, t, t.pos, Content.weapon(&"tpla_demo_charge"), 100)
	w._kill(t, null)

# ------------------------------------------------------------------ salvage
static func on_unit_death(w: SimWorld, e: SimEntity) -> void:
	var d: UnitDef = w.udef(e)
	if d.tags.has("suicide") and e.phase != 99:
		e.phase = 99
		CombatSys.explode(w, e, e.pos, Content.weapon(d.weapons[0]), 100)
	if w.has_tpla and d.tags.has("vehicle"):
		spawn_crate(w, e.pos, maxi(50, d.cost / 4))

static func spawn_crate(w: SimWorld, pos: Vector2i, value: int) -> SimEntity:
	var c := w._new_entity(SimEntity.Kind.CRATE, &"salvage_crate", -1)
	c.pos = pos
	c.tile = FX.to_tile(pos)
	c.amount = value
	c.max_amount = value
	c.radius = 400
	c.aux_t = w.tick + CRATE_LIFE
	w.events.append({"t": "crate", "id": c.id})
	return c

static func _crates(w: SimWorld) -> void:
	for id in w.ids:
		var c: SimEntity = w.ents[id]
		if not c.alive or c.kind != SimEntity.Kind.CRATE:
			continue
		if w.tick >= c.aux_t:
			_remove(w, c)
			continue
		var best: SimEntity = null
		for u: SimEntity in w.units_in_radius(c.pos, FX.ONE):
			if u.res_id < 0 or u.owner < 0 or w.faction_of(u.owner) != &"tpla":
				continue
			if best == null or u.id < best.id:
				best = u
		if best == null:
			continue
		var ud: UnitDef = w.udef(best)
		if ud.tags.has("salvage") and best.tier < 3:
			set_tier(w, best, best.tier + 1)
			w.events.append({"t": "salvage", "id": best.id, "tier": best.tier, "pos": c.pos})
		else:
			EconSys.add_supply(w, w.players[best.owner], c.amount)
			w.events.append({"t": "crate_cash", "id": best.id, "owner": best.owner, "amount": c.amount, "pos": c.pos})
		_remove(w, c)

static func set_tier(w: SimWorld, u: SimEntity, t: int) -> void:
	var old := u.max_hp
	u.tier = clampi(t, 0, 3)
	u.max_hp = w.unit_max_hp(u)
	u.hp = mini(u.max_hp, u.hp + maxi(0, u.max_hp - old))

static func _remove(w: SimWorld, e: SimEntity) -> void:
	e.alive = false
	w.events.append({"t": "death", "id": e.id, "kind": e.kind, "def": e.def_id, "pos": e.pos, "owner": e.owner, "silent": true})

# ------------------------------------------------------------------ rebuild holes
static func on_building_death(w: SimWorld, b: SimEntity) -> void:
	if b.kind != SimEntity.Kind.BUILDING or b.owner < 0 or not b.built:
		return
	if w.faction_of(b.owner) != &"tpla" or w.players[b.owner].eliminated:
		return
	if Content.btag(b.def_id, "no_hole"):
		return
	w.pending_holes.append({"def": b.def_id, "tile": b.tile, "fp": b.fp, "rot": b.rot, "owner": b.owner})

static func _open_holes(w: SimWorld) -> void:
	var list := w.pending_holes
	w.pending_holes = []
	for h in list:
		var owner: int = int(h["owner"])
		if w.players[owner].eliminated:
			continue
		var t: Vector2i = h["tile"]
		var fp: Vector2i = h["fp"]
		var free := true
		for yy in fp.y:
			for xx in fp.x:
				if w.map.occ[w.map.idx(Vector2i(t.x + xx, t.y + yy))] != 0:
					free = false
		if not free:
			continue
		var hd: BuildingDef = Content.building(&"tpla_hole")
		var e := w._new_entity(SimEntity.Kind.BUILDING, hd.id, owner)
		e.tile = t
		e.fp = fp
		e.rot = int(h["rot"])
		e.pos = Vector2i(t.x * FX.ONE + fp.x * FX.HALF, t.y * FX.ONE + fp.y * FX.HALF)
		e.max_hp = hd.max_hp
		e.hp = hd.max_hp
		e.sight = hd.sight
		e.radius = maxi(fp.x, fp.y) * FX.HALF
		e.built = true
		e.build_ticks = 1
		e.progress = 1
		e.cds = []
		e.aux_def = StringName(h["def"])
		e.aux_t = w.tick + HOLE_DELAY
		w.map.stamp(t, fp, e.id)
		w.events.append({"t": "site", "id": e.id, "owner": owner, "hole": true})

static func _holes(w: SimWorld) -> void:
	var due: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.BUILDING and e.def_id == &"tpla_hole" and w.tick >= e.aux_t:
			due.append(e)
	for h: SimEntity in due:
		var d: BuildingDef = Content.building(h.aux_def)
		h.alive = false
		w.map.unstamp(h.tile, h.fp)
		w.events.append({"t": "death", "id": h.id, "kind": h.kind, "def": h.def_id, "pos": h.pos, "owner": h.owner, "silent": true})
		if d == null:
			continue
		var site := w._place_building(d, h.owner, h.tile, h.rot, false)
		w.events.append({"t": "site", "id": site.id, "owner": h.owner})
		var lab := w.spawn_unit(&"tpla_laborer", h.owner, null, site.pos)
		lab.orders = [{"o": "build", "target": site.id}]
		w.events.append({"t": "hole_rebuild", "id": site.id, "owner": h.owner})

# ------------------------------------------------------------------ tunnel network
static func is_tunnel(w: SimWorld, b: SimEntity) -> bool:
	return b != null and b.kind == SimEntity.Kind.BUILDING and Content.btag(b.def_id, "tunnel")

static func tunnels_of(w: SimWorld, owner: int) -> Array:
	var out: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.owner == owner and e.kind == SimEntity.Kind.BUILDING and e.built and Content.btag(e.def_id, "tunnel"):
			out.append(e)
	return out

## Units inside the owner's tunnel network.
static func network_units(w: SimWorld, owner: int) -> Array:
	var tset := {}
	for t: SimEntity in tunnels_of(w, owner):
		tset[-t.id] = true
	var out: Array = []
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and u.owner == owner and u.res_id < 0 and tset.has(u.res_id):
			out.append(u)
	return out

static func network_capacity() -> int:
	return Content.building(&"tpla_tunnel").garrison_capacity

static func tunnel_destroyed(w: SimWorld, b: SimEntity) -> void:
	var other: SimEntity = null
	for t: SimEntity in tunnels_of(w, b.owner):
		if t.id != b.id and t.alive:
			other = t
			break
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and u.res_id == -b.id:
			if other != null:
				u.res_id = -other.id
			else:
				u.res_id = 0
				u.pos = b.pos
				w._kill(u, null)

## Evacuate the whole network at tunnel `t`.
static func evacuate(w: SimWorld, t: SimEntity) -> void:
	var units := network_units(w, t.owner)
	var i := 0
	for u: SimEntity in units:
		var veh := w.is_vehicle(u)
		var ex := w.exit_tile(t, veh)
		var off := Vector2i((i % 3) - 1, (i / 3) % 3) * (2 if veh else 1)
		u.res_id = 0
		u.pos = FX.tile_center(w.map.nearest_passable(ex + off, veh))
		u.home = u.pos
		u.orders.clear()
		u.goal = Vector2i(-1, -1)
		u.path = []
		u.path_goal = Vector2i(-1, -1)
		u.target = 0
		w.events.append({"t": "unload", "id": u.id, "b": t.id})
		i += 1

static func _tunnel_heal(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id >= 0 or u.hp >= u.max_hp:
			continue
		var b := w.get_ent(-u.res_id)
		if is_tunnel(w, b):
			u.hp = mini(u.max_hp, u.hp + maxi(1, u.max_hp * TUNNEL_HEAL_PCT / 100))

# ------------------------------------------------------------------ rust zones
static func add_zone(w: SimWorld, pos: Vector2i, r: int, ticks: int, dps: int, owner: int, team: int) -> void:
	w.zones.append({"pos": pos, "r": r, "until": w.tick + ticks, "dps": dps, "owner": owner, "team": team})
	w.events.append({"t": "rust_zone", "pos": pos, "r": r, "ticks": ticks})

static func _zones(w: SimWorld) -> void:
	var keep: Array = []
	for z in w.zones:
		if int(z["until"]) <= w.tick:
			continue
		keep.append(z)
		var team: int = int(z["team"])
		var src := w.get_ent(0)
		var per: int = int(z["dps"]) / 2
		for u: SimEntity in w.units_in_radius(z["pos"], int(z["r"])):
			if u.res_id < 0 or not w.enemies(team, u.team):
				continue
			var dmg: int = per * Content.combat.mult(&"corrosive", w.udef(u).armor_type) / 100
			w.damage(u, maxi(1, dmg), src)
		for id in w.ids:
			var b: SimEntity = w.ents[id]
			if b.alive and b.kind == SimEntity.Kind.BUILDING and w.enemies(team, b.team) and w.dist_to_building(z["pos"], b) <= int(z["r"]):
				w.damage(b, maxi(1, per * Content.combat.mult(&"corrosive", &"structure") / 100), src)
	w.zones = keep
