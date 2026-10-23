class_name SimWorld
extends RefCounted
## Deterministic simulation. No Node / scene dependencies. All state changes come
## from Commands (applied at tick start) and the fixed system order (GDD 16.4).

const SAVE_VERSION := 2
const CELL := 4096        ## spatial hash cell = 4 tiles
const SUPPLY_CAP := 50000

var tick: int = 0
var rng := PCG32.new()
var seed_value: int = 1
var map := SimMap.new()
var map_id: StringName = &"varno_crossing"
var players: Array = []          ## Array[SimPlayer]
var ents: Dictionary = {}        ## id -> SimEntity
var ids: Array = []              ## stable iteration order (ascending id)
var next_id: int = 1
var events: Array = []           ## view events produced this tick (not saved)
var options: Dictionary = {"fog": true, "start_money": 10000, "superweapons": false}
var fog := SimFog.new()
var winner_team: int = -1
var game_over: bool = false
var cells: Dictionary = {}       ## spatial hash: cell key -> Array[int] unit ids
var path_queue: Array = []       ## unit ids waiting for a path
var power_dirty: bool = true
var temp_vision: Array = []      ## [{team, pos(tile), r, until}]
var pending: Array = []          ## commands to apply next tick
var zones: Array = []            ## rust (corrosive) zones: {pos, r, until, dps, owner, team}
var pending_holes: Array = []    ## TPLA rebuild holes to open after the death pass
var has_tpla: bool = false       ## salvage crates drop only when a TPLA player is in the match

# ------------------------------------------------------------------ setup
func setup(map_def: MapDef, slots: Array, opts: Dictionary, p_seed: int) -> void:
	## slots: Array of {team:int, color:int, ai:bool, difficulty:String, spawn:int}
	options.merge(opts, true)
	seed_value = p_seed
	rng.seed(p_seed)
	map_id = map_def.id
	map.load_from(map_def)
	players.clear()
	for i in slots.size():
		var s: Dictionary = slots[i]
		var p := SimPlayer.new()
		p.id = i
		p.team = int(s.get("team", i))
		p.color = int(s.get("color", i))
		p.is_ai = bool(s.get("ai", false))
		p.faction = StringName(s.get("faction", "eu"))
		if not Content.FACTIONS.has(p.faction):
			p.faction = &"eu"
		if p.faction == &"tpla":
			has_tpla = true
		p.supply = int(options["start_money"])
		players.append(p)
	fog.setup(map.w, map.h, 4, not options["fog"])
	# resources
	for r in map_def.resources:
		var e := _new_entity(SimEntity.Kind.RESOURCE, StringName(r["kind"]), -1)
		e.tile = r["tile"]
		e.pos = FX.tile_center(r["tile"])
		e.amount = int(r["amount"])
		e.max_amount = e.amount
		e.radius = 900
		map.mark_nobuild(r["tile"], 3)
	# neutrals
	for n in map_def.neutrals:
		var d: BuildingDef = Content.building(n["kind"])
		var b := _place_building(d, -1, n["tile"], 0, true)
		b.kind = SimEntity.Kind.NEUTRAL
	# start bases
	for i in slots.size():
		var sp: int = int(slots[i].get("spawn", i))
		var t: Vector2i = map_def.spawns[sp]
		var fac: Dictionary = Content.faction(players[i].faction)
		var hq := _place_building(Content.building(fac["hq"]), i, t, _spawn_rot(t), true)
		for su in fac["start_units"]:
			var c := spawn_unit(su, i, hq)
			c.home = c.pos
	# M2.8 map builder: pre-placed units / buildings, owned by the player on that start slot
	for pb in map_def.prebuilt:
		var owner := -1
		for i in slots.size():
			if int(slots[i].get("spawn", i)) == int(pb["spawn"]):
				owner = i
		if owner < 0:
			continue
		var pt: Vector2i = pb["tile"]
		if Content.is_building(pb["kind"]):
			_place_building(Content.building(pb["kind"]), owner, pt, _spawn_rot(pt), true)
		elif Content.unit(pb["kind"]) != null:
			var pu := spawn_unit(StringName(pb["kind"]), owner, null, FX.tile_center(pt))
			pu.home = pu.pos
	power_dirty = true
	PowerSys.run(self)
	FogSys.run(self, true)

func _spawn_rot(t: Vector2i) -> int:
	# exit toward map center
	return 0 if t.y < map.h / 2 else 2

func _new_entity(kind: int, def_id: StringName, owner: int) -> SimEntity:
	var e := SimEntity.new()
	e.id = next_id
	next_id += 1
	e.kind = kind
	e.def_id = def_id
	e.owner = owner
	e.team = players[owner].team if owner >= 0 else -1
	ents[e.id] = e
	ids.append(e.id)
	return e

func _place_building(d: BuildingDef, owner: int, t: Vector2i, rot: int, complete: bool) -> SimEntity:
	var e := _new_entity(SimEntity.Kind.BUILDING, d.id, owner)
	e.tile = t
	e.fp = d.footprint
	e.rot = rot
	e.pos = Vector2i(t.x * FX.ONE + d.footprint.x * FX.HALF, t.y * FX.ONE + d.footprint.y * FX.HALF)
	e.max_hp = d.max_hp
	e.sight = d.sight
	e.radius = maxi(d.footprint.x, d.footprint.y) * FX.HALF
	e.build_ticks = FX.ms_to_ticks(d.build_time_ms)
	e.built = complete
	e.hp = d.max_hp if complete else maxi(1, d.max_hp / 10)
	e.progress = e.build_ticks if complete else 0
	e.cds = []
	for w in d.weapons:
		e.cds.append(0)
	map.stamp(t, d.footprint, e.id)
	_shove_units_out(e)
	power_dirty = true
	return e

func spawn_unit(def_id: StringName, owner: int, from_building: SimEntity = null, at: Vector2i = Vector2i(-1, -1)) -> SimEntity:
	var d: UnitDef = Content.unit(def_id)
	var e := _new_entity(SimEntity.Kind.UNIT, def_id, owner)
	e.max_hp = d.max_hp
	e.hp = d.max_hp
	e.sight = d.sight
	e.radius = FX.mt_to_fx(d.radius_mt)
	e.cds = []
	for w in d.weapons:
		e.cds.append(0)
	var veh := d.move_layer == &"vehicle"
	var t: Vector2i
	if from_building != null:
		t = exit_tile(from_building, veh)
	elif at.x >= 0:
		t = map.nearest_passable(FX.to_tile(at), veh)
	else:
		t = Vector2i(1, 1)
	e.pos = FX.tile_center(t)
	e.home = e.pos
	e.dir = Vector2i(0, 1024)
	events.append({"t": "spawn", "id": e.id})
	return e

func exit_tile(b: SimEntity, vehicle: bool) -> Vector2i:
	var c := Vector2i(b.tile.x + b.fp.x / 2, b.tile.y + b.fp.y / 2)
	var t: Vector2i
	match b.rot:
		0: t = Vector2i(c.x, b.tile.y + b.fp.y)
		1: t = Vector2i(b.tile.x + b.fp.x, c.y)
		2: t = Vector2i(c.x, b.tile.y - 1)
		_: t = Vector2i(b.tile.x - 1, c.y)
	return map.nearest_passable(t, vehicle)

func dock_point(b: SimEntity) -> Vector2i:
	return FX.tile_center(exit_tile(b, true))

func _shove_units_out(b: SimEntity) -> void:
	for id in ids:
		var u: SimEntity = ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT:
			continue
		if is_air(u):
			continue
		var t := FX.to_tile(u.pos)
		if map.occ[map.idx(t)] == b.id:
			var veh := is_vehicle(u)
			u.pos = FX.tile_center(map.nearest_passable(t, veh))
			u.path = []
			u.path_goal = Vector2i(-1, -1)

# ------------------------------------------------------------------ queries
func udef(e: SimEntity) -> UnitDef:
	return Content.unit(e.def_id)

func bdef(e: SimEntity) -> BuildingDef:
	return Content.building(e.def_id)

func is_vehicle(e: SimEntity) -> bool:
	return Content.unit(e.def_id).move_layer == &"vehicle"

## M2.5 air layer: aircraft (move_layer air) ignore terrain; only weapons with targets_air hit
## them while airborne. A parked aircraft (air_state 1) is a ground target.
func is_air(e: SimEntity) -> bool:
	return e.kind == SimEntity.Kind.UNIT and Content.unit(e.def_id).move_layer == &"air"

func flying(e: SimEntity) -> bool:
	return e.kind == SimEntity.Kind.UNIT and e.air_state != AirSys.PARKED and Content.unit(e.def_id).move_layer == &"air"

func faction_of(pid: int) -> StringName:
	return players[pid].faction if pid >= 0 and pid < players.size() else &"neutral"

## Max HP of a unit with veterancy and salvage tier applied.
func unit_max_hp(e: SimEntity) -> int:
	return udef(e).max_hp * CombatSys.VET_HP[e.vet] / 100 * (100 + TplaSys.TIER_HP * e.tier) / 100

func get_ent(id: int) -> SimEntity:
	var e = ents.get(id)
	return e if e != null and e.alive else null

func enemies(a: int, b: int) -> bool:
	## a, b are team ids; -1 = neutral (never hostile)
	return a >= 0 and b >= 0 and a != b

func player_team(pid: int) -> int:
	return players[pid].team

func has_completed(pid: int, def_id) -> bool:
	for id in ids:
		var e: SimEntity = ents[id]
		if e.alive and e.owner == pid and e.kind == SimEntity.Kind.BUILDING and e.built and e.def_id == StringName(def_id):
			return true
	return false

func count_owned(pid: int, def_id, include_unbuilt: bool = true) -> int:
	var n := 0
	for id in ids:
		var e: SimEntity = ents[id]
		if e.alive and e.owner == pid and e.def_id == StringName(def_id) and (include_unbuilt or e.built):
			n += 1
	return n

func prereqs_met(pid: int, prereqs: PackedStringArray) -> String:
	for p in prereqs:
		if not has_completed(pid, p):
			return p
	return ""

func units_in_radius(pos: Vector2i, r: int) -> Array:
	var out: Array = []
	var cx0 := (pos.x - r) / CELL
	var cx1 := (pos.x + r) / CELL
	var cy0 := (pos.y - r) / CELL
	var cy1 := (pos.y + r) / CELL
	var r2 := r * r
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var arr = cells.get(cy * 1000 + cx)
			if arr == null:
				continue
			for id in arr:
				var e = ents.get(id)
				if e != null and e.alive and FX.dist2(e.pos, pos) <= r2:
					out.append(e)
	return out

func rebuild_spatial() -> void:
	cells.clear()
	for id in ids:
		var e: SimEntity = ents[id]
		if not e.alive or e.kind != SimEntity.Kind.UNIT:
			continue
		if e.res_id < 0:   # garrisoned (inside a building)
			continue
		var k: int = (e.pos.y / CELL) * 1000 + (e.pos.x / CELL)
		var arr = cells.get(k)
		if arr == null:
			cells[k] = [id]
		else:
			arr.append(id)

## Distance from point to a building's footprint edge (fixed-point).
func dist_to_building(p: Vector2i, b: SimEntity) -> int:
	var x0 := b.tile.x * FX.ONE
	var y0 := b.tile.y * FX.ONE
	var x1 := x0 + b.fp.x * FX.ONE
	var y1 := y0 + b.fp.y * FX.ONE
	var dx := maxi(maxi(x0 - p.x, 0), p.x - x1)
	var dy := maxi(maxi(y0 - p.y, 0), p.y - y1)
	return FX.isqrt(dx * dx + dy * dy)

## Distance between two entities' edges.
func edge_dist(a: SimEntity, b: SimEntity) -> int:
	if b.kind != SimEntity.Kind.UNIT:
		return maxi(0, dist_to_building(a.pos, b) - a.radius)
	return maxi(0, FX.dist(a.pos, b.pos) - a.radius - b.radius)

# ------------------------------------------------------------------ placement
## Returns "" if valid, else a localization key with the reason.
func can_place(pid: int, def_id: StringName, t: Vector2i, check_cost: bool = true, builder_ids: Array = []) -> String:
	var d: BuildingDef = Content.building(def_id)
	if d == null or not d.buildable:
		return "REASON_INVALID"
	var p: SimPlayer = players[pid]
	if check_cost and p.supply < d.cost:
		return "REASON_FUNDS"
	var missing := prereqs_met(pid, d.prereqs)
	if missing != "":
		return "REASON_PREREQ"
	for yy in d.footprint.y:
		for xx in d.footprint.x:
			var c := Vector2i(t.x + xx, t.y + yy)
			if not map.in_bounds(c) or c.x < 1 or c.y < 1 or c.x >= map.w - 1 or c.y >= map.h - 1:
				return "REASON_BLOCKED"
			var i := map.idx(c)
			if not SimMap.BUILD_OK[map.tiles[i]]:
				return "REASON_TERRAIN"
			if map.occ[i] != 0:
				return "REASON_BLOCKED"
			if map.nobuild[i] != 0:
				return "REASON_RESOURCE"
	# enemy units standing on the footprint block placement
	var center := Vector2i(t.x * FX.ONE + d.footprint.x * FX.HALF, t.y * FX.ONE + d.footprint.y * FX.HALF)
	for u: SimEntity in units_in_radius(center, maxi(d.footprint.x, d.footprint.y) * FX.ONE):
		if enemies(u.team, p.team):
			return "REASON_ENEMY"
	# Zero Hour rules: no build radius and no explored-ground rule. A builder can be sent
	# anywhere it can physically get to, shroud included; it drives there itself.
	if not d.is_hq and not _builder_can_reach(pid, t, d.footprint, builder_ids):
		return "REASON_UNREACHABLE"
	return ""

## True if one of the player's builders (or of builder_ids when given) shares a region with the
## footprint's border, using foot regions for foot builders and vehicle regions otherwise.
## The player's builder regions are cached per tick (AI placement searches call this a lot).
var _reach_tick := -1
var _reach: Dictionary = {}   ## pid -> {"v3": true, "f1": true}, or {"none": true}
func _builder_regions(ids_in: Array) -> Dictionary:
	var rs := {}
	for id in ids_in:
		var e: SimEntity = ents.get(int(id))
		if e == null or not e.alive or e.kind != SimEntity.Kind.UNIT or not udef(e).tags.has("builder"):
			continue
		var foot := udef(e).move_layer == &"foot"
		var rg := map.region_near(FX.to_tile(e.pos), foot)
		if rg != 0:
			rs[("f" if foot else "v") + str(rg)] = true
		else:
			rs["stuck"] = true
	if rs.is_empty():
		rs["none"] = true
	return rs

func _builder_can_reach(pid: int, t: Vector2i, fp: Vector2i, builder_ids: Array = []) -> bool:
	var mine: Dictionary
	if not builder_ids.is_empty():
		mine = _builder_regions(builder_ids)
	else:
		if _reach_tick != tick:
			_reach_tick = tick
			_reach.clear()
		if not _reach.has(pid):
			var own: Array = []
			for id in ids:
				var e: SimEntity = ents[id]
				if e.alive and e.owner == pid and e.kind == SimEntity.Kind.UNIT:
					own.append(id)
			_reach[pid] = _builder_regions(own)
		mine = _reach[pid]
	if mine.has("none"):
		return true   # no builder: the command itself is rejected (REASON_NO_BUILDER)
	var has_f := false
	var has_v := false
	for k: String in mine:
		has_f = has_f or k.begins_with("f")
		has_v = has_v or k.begins_with("v")
	if has_v:
		for r in map.footprint_regions(t, fp, false):
			if mine.has("v" + str(r)):
				return true
	if has_f:
		for r in map.footprint_regions(t, fp, true):
			if mine.has("f" + str(r)):
				return true
	return false

func in_grid(pid: int, p: Vector2i) -> bool:
	for id in ids:
		var e: SimEntity = ents[id]
		if not e.alive or e.owner != pid or e.kind != SimEntity.Kind.BUILDING or not e.built:
			continue
		var d: BuildingDef = Content.building(e.def_id)
		if d.grid_radius <= 0:
			continue
		var r := d.grid_radius * FX.ONE
		if FX.dist2(e.pos, p) <= r * r:
			return true
	return false

# ------------------------------------------------------------------ commands
func queue_command(c: Dictionary) -> void:
	pending.append(c)

# ------------------------------------------------------------------ main step
## Test-only profiling: when non-null, step() records usec per system for the last tick.
var prof: Variant = null

func _pt(key: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	prof[key] = t1 - t0
	return t1

func step() -> void:
	var t := Time.get_ticks_usec() if prof != null else 0
	events.clear()
	# 1 commands
	var cmds := pending
	pending = []
	for c in cmds:
		CommandSys.apply(self, c)
	if game_over:
		tick += 1
		return
	rebuild_spatial()
	if prof != null: t = _pt("cmd", t)
	# 2 orders (+ target acquisition) 3 path requests 4 movement
	OrderSys.run(self)
	# M2.5 aircraft: airfield binding, return / land / rearm, JTAC call-ins
	AirSys.run(self)
	if prof != null: t = _pt("orders", t)
	MoveSys.run_paths(self)
	if prof != null: t = _pt("paths", t)
	MoveSys.run(self)
	rebuild_spatial()
	if prof != null: t = _pt("move", t)
	# 5 combat 6 damage & death
	CombatSys.run(self)
	_reap()
	rebuild_spatial()
	if prof != null: t = _pt("combat", t)
	# 7 economy
	EconSys.run(self)
	# 8 production & construction
	ProdSys.run(self)
	# power grid + shields
	PowerSys.run(self)
	# 9 powers
	PowersSys.run(self)
	if prof != null: t = _pt("econ_prod_power", t)
	# 10 faction mechanics (TPLA: stealth, traps, salvage, holes, tunnels, rust zones)
	TplaSys.run(self)
	# M2.4 roster mechanics (transports, heal auras)
	RosterSys.run(self)
	# M2.5 US mechanics (stealth while stationary)
	UsSys.run(self)
	if prof != null: t = _pt("tpla", t)
	# 11 fog (5 Hz)
	if tick % 4 == 0:
		FogSys.run(self, false)
	if prof != null: t = _pt("fog", t)
	# 12 win/lose
	if tick % 20 == 0:
		_check_victory()
	tick += 1

func damage(target: SimEntity, amount: int, attacker: SimEntity) -> void:
	if not target.alive or amount <= 0:
		return
	if target.kind == SimEntity.Kind.RESOURCE:
		return
	target.last_hit_tick = tick
	if target.shield > 0:
		var absorbed := mini(target.shield, amount)
		target.shield -= absorbed
		amount -= absorbed
		if absorbed > 0:
			events.append({"t": "shield_hit", "id": target.id})
	target.hp -= amount
	if attacker != null and attacker.owner >= 0 and target.owner >= 0:
		if target.owner != attacker.owner:
			events.append({"t": "attacked", "id": target.id, "owner": target.owner, "by": attacker.owner})
	if target.hp <= 0:
		target.hp = 0
		_kill(target, attacker)

func _kill(e: SimEntity, attacker: SimEntity) -> void:
	if not e.alive:
		return
	e.alive = false
	var value := 0
	if e.kind == SimEntity.Kind.UNIT:
		value = udef(e).cost
		if e.owner >= 0:
			players[e.owner].stats["lost"] += 1
		if udef(e).transport_capacity > 0:
			RosterSys.unload(self, e, 40)   # passengers bail out of the wreck, stunned 2 s
		TplaSys.on_unit_death(self, e)
	elif e.kind == SimEntity.Kind.BUILDING or e.kind == SimEntity.Kind.NEUTRAL:
		value = bdef(e).cost / 2 + 200
		if e.owner >= 0:
			players[e.owner].stats["structures_lost"] += 1
		map.unstamp(e.tile, e.fp)
		power_dirty = true
		_eject_garrison(e)
		TplaSys.on_building_death(self, e)
	if attacker != null and attacker.owner >= 0 and e.owner >= 0 and enemies(attacker.team, e.team):
		var ap: SimPlayer = players[attacker.owner]
		ap.xp += value
		if e.kind == SimEntity.Kind.UNIT:
			ap.stats["kills"] += 1
		else:
			ap.stats["structures_killed"] += 1
		CombatSys.grant_vet_xp(self, attacker, value)
		_update_rank(ap)
	events.append({"t": "death", "id": e.id, "kind": e.kind, "def": e.def_id, "pos": e.pos, "owner": e.owner, "by": attacker.def_id if attacker != null else &""})

func _eject_garrison(b: SimEntity) -> void:
	if b.kind == SimEntity.Kind.BUILDING and Content.btag(b.def_id, "tunnel"):
		TplaSys.tunnel_destroyed(self, b)
		return
	for id in ids:
		var u: SimEntity = ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and u.res_id == -b.id:
			u.res_id = 0
			u.pos = FX.tile_center(map.nearest_passable(FX.to_tile(b.pos), false))
			u.orders.clear()
			u.phase_t = tick + 40   # stunned 2 s
	if b.kind == SimEntity.Kind.NEUTRAL:
		b.owner = -1
		b.team = -1

func _update_rank(p: SimPlayer) -> void:
	while p.rank < 5 and p.xp >= SimPlayer.RANK_XP[p.rank + 1]:
		p.rank += 1
		p.points += 1 if p.rank < 5 else 2
		events.append({"t": "rank", "owner": p.id, "rank": p.rank})

func _reap() -> void:
	var any_dead := false
	for id in ids:
		if not ents[id].alive:
			any_dead = true
			break
	if not any_dead:
		return
	var keep: Array = []
	for id in ids:
		var e: SimEntity = ents[id]
		if e.alive:
			keep.append(id)
		else:
			ents.erase(id)
	ids = keep

func _check_victory() -> void:
	var alive_teams := {}
	for p in players:
		if p.eliminated:
			continue
		var has := false
		for id in ids:
			var e: SimEntity = ents[id]
			if e.alive and e.owner == p.id and e.kind == SimEntity.Kind.BUILDING:
				var d: BuildingDef = Content.building(e.def_id)
				if d.is_hq or d.produces.size() > 0:
					has = true
					break
		if not has:
			eliminate(p.id)
		else:
			alive_teams[p.team] = true
	if alive_teams.size() <= 1 and not game_over:
		game_over = true
		winner_team = alive_teams.keys()[0] if alive_teams.size() == 1 else -1
		events.append({"t": "game_over", "winner": winner_team})

func eliminate(pid: int) -> void:
	var p: SimPlayer = players[pid]
	if p.eliminated:
		return
	p.eliminated = true
	events.append({"t": "eliminated", "owner": pid})
	for id in ids:
		var e: SimEntity = ents[id]
		if e.alive and e.owner == pid:
			if e.kind == SimEntity.Kind.NEUTRAL:
				e.owner = -1
				e.team = -1
				continue
			_kill(e, null)

# ------------------------------------------------------------------ hash / save
func state_hash() -> int:
	var h := 2166136261
	h = FX.fnv_int(h, tick)
	for p in players:
		h = FX.fnv_int(h, p.supply)
		h = FX.fnv_int(h, p.xp)
	for id in ids:
		var e: SimEntity = ents[id]
		h = FX.fnv_int(h, e.id)
		h = FX.fnv_int(h, e.pos.x)
		h = FX.fnv_int(h, e.pos.y)
		h = FX.fnv_int(h, e.hp)
		h = FX.fnv_int(h, e.shield)
		h = FX.fnv_int(h, e.owner)
		h = FX.fnv_int(h, e.tier)
	h = FX.fnv_int(h, zones.size())
	return h

func serialize() -> Dictionary:
	var ed: Array = []
	for id in ids:
		ed.append(ents[id].to_dict())
	var pd: Array = []
	for p in players:
		pd.append(p.to_dict())
	return {"save_version": SAVE_VERSION, "tick": tick, "rng": rng.to_dict(), "seed": seed_value, "map_id": map_id,
		"players": pd, "ents": ed, "next_id": next_id, "options": options.duplicate(), "fog": fog.to_dict(),
		"winner_team": winner_team, "game_over": game_over, "temp_vision": temp_vision.duplicate(true),
		"pending": pending.duplicate(true), "zones": zones.duplicate(true), "pending_holes": pending_holes.duplicate(true),
		"has_tpla": has_tpla, "path_queue": path_queue.duplicate(), "hash": state_hash(), "map_data": _map_data()}

## M2.8: custom maps travel inside the save (resume works after the map is edited or deleted).
func _map_data() -> Dictionary:
	var md: MapDef = Content.maps.get(map_id)
	return MapStore.to_dict(md) if md != null and md.custom else {}

func deserialize(d: Dictionary) -> void:
	var map_def: MapDef = MapStore.resolve(StringName(d["map_id"]), d.get("map_data", {}))
	map_id = map_def.id
	map.load_from(map_def)
	for r in map_def.resources:
		map.mark_nobuild(r["tile"], 3)
	tick = int(d["tick"])
	rng.from_dict(d["rng"])
	seed_value = int(d["seed"])
	options = d["options"]
	players.clear()
	for pd in d["players"]:
		players.append(SimPlayer.from_dict(pd))
	ents.clear()
	ids.clear()
	for ed in d["ents"]:
		var e := SimEntity.from_dict(ed)
		ents[e.id] = e
		ids.append(e.id)
		if (e.kind == SimEntity.Kind.BUILDING or e.kind == SimEntity.Kind.NEUTRAL) and e.alive:
			map.stamp(e.tile, e.fp, e.id)
	next_id = int(d["next_id"])
	fog.from_dict(d["fog"])
	winner_team = int(d["winner_team"])
	game_over = bool(d["game_over"])
	temp_vision = d["temp_vision"]
	pending = d["pending"]
	zones = d.get("zones", [])
	pending_holes = d.get("pending_holes", [])
	has_tpla = bool(d.get("has_tpla", false))
	power_dirty = true
	path_queue.clear()
	for id in ids:
		var e: SimEntity = ents[id]
		e.path_pending = false
	# pending path requests are part of the state (PATH_BUDGET defers them across ticks);
	# dropping them on load made loaded games diverge from the original (M2.1 fix)
	for qid in d.get("path_queue", []):
		var qe: SimEntity = ents.get(int(qid))
		if qe != null and not qe.path_pending:
			qe.path_pending = true
			path_queue.append(qe.id)
	PowerSys.recompute_grid(self)
	rebuild_spatial()
