class_name CommandSys
## Validates and applies Commands. Same path for human, AI and replay input.
## Command = {tick, p (player), t (type), ids[], pos (fixed Vector2i), target, q (queue), def, n, flag}

static func apply(w: SimWorld, c: Dictionary) -> void:
	var pid: int = int(c.get("p", -1))
	if pid < 0 or pid >= w.players.size() or w.players[pid].eliminated:
		return
	var t: String = c.get("t", "")
	match t:
		"move", "amove", "guard":
			_unit_orders(w, pid, c, t)
			for u: SimEntity in _own_units(w, pid, c):
				if w.udef(u).harvest_capacity > 0:
					u.phase = -1   # parked by the player: no auto-harvest until ordered
		"attack":
			var tgt := w.get_ent(int(c.get("target", 0)))
			if tgt == null:
				return
			for u: SimEntity in _own_units(w, pid, c):
				_push(u, {"o": "attack", "target": tgt.id, "force": bool(c.get("flag", false))}, bool(c.get("q", false)))
		"stop":
			for u: SimEntity in _own_units(w, pid, c):
				u.orders.clear()
				u.goal = Vector2i(-1, -1)
				u.path = []
				u.target = 0
				u.home = u.pos
				if w.udef(u).harvest_capacity > 0:
					u.phase = -1
		"scatter":
			for u: SimEntity in _own_units(w, pid, c):
				var off := Vector2i(w.rng.range_int(5) - 2, w.rng.range_int(5) - 2) * FX.ONE
				if off == Vector2i.ZERO:
					off = Vector2i(FX.ONE * 2, 0)
				u.orders = [{"o": "move", "pos": u.pos + off}]
		"harvest":
			var r := w.get_ent(int(c.get("target", 0)))
			if r == null or r.kind != SimEntity.Kind.RESOURCE:
				return
			for u: SimEntity in _own_units(w, pid, c):
				if w.udef(u).harvest_capacity > 0:
					u.res_id = r.id
					u.phase = 0
					u.orders = [{"o": "harvest"}]
		"garrison":
			var b := w.get_ent(int(c.get("target", 0)))
			if RosterSys.capacity(w, b) > 0:
				if b.owner == pid:
					for u: SimEntity in _own_units(w, pid, c):
						if u.id != b.id and RosterSys.can_board(w, u):
							_push(u, {"o": "garrison", "target": b.id}, bool(c.get("q", false)))
				return
			if TplaSys.is_tunnel(w, b) and b.owner == pid and b.built:
				for u: SimEntity in _own_units(w, pid, c):
					_push(u, {"o": "garrison", "target": b.id}, bool(c.get("q", false)))
				return
			if b != null and b.kind == SimEntity.Kind.BUILDING and b.owner == pid and b.built and is_barricade(w, b):
				for u: SimEntity in _own_units(w, pid, c):   # M3.2: man an own barricade (max 3)
					if w.udef(u).tags.has("garrison"):
						_push(u, {"o": "garrison", "target": b.id}, bool(c.get("q", false)))
				return
			if b == null or b.kind != SimEntity.Kind.NEUTRAL or w.bdef(b).garrison_capacity <= 0:
				return
			if b.owner >= 0 and w.enemies(b.team, w.player_team(pid)):
				return
			for u: SimEntity in _own_units(w, pid, c):
				if w.udef(u).tags.has("garrison"):
					_push(u, {"o": "garrison", "target": b.id}, bool(c.get("q", false)))
		"capture":
			var b2 := w.get_ent(int(c.get("target", 0)))
			if b2 == null or b2.kind != SimEntity.Kind.NEUTRAL or not w.bdef(b2).capturable:
				return
			for u: SimEntity in _own_units(w, pid, c):
				var ud := w.udef(u)
				if ud.tags.has("builder") or ud.tags.has("infantry"):
					_push(u, {"o": "capture", "target": b2.id}, bool(c.get("q", false)))
		"unload":
			for id in c.get("ids", []):
				var b3 := w.get_ent(int(id))
				if RosterSys.capacity(w, b3) > 0 and b3.owner == pid:
					RosterSys.unload(w, b3)
					continue
				if TplaSys.is_tunnel(w, b3) and b3.owner == pid and b3.built:
					TplaSys.evacuate(w, b3)
					continue
				if b3 != null and b3.kind == SimEntity.Kind.BUILDING and b3.owner == pid and is_barricade(w, b3):
					leave_barricade(w, b3)   # M3.2: troops step out, no stun
					continue
				if b3 != null and b3.kind == SimEntity.Kind.NEUTRAL and b3.owner == pid:
					w._eject_garrison(b3)
					b3.owner = -1
					b3.team = -1
		"place":
			_place(w, pid, c)
		"drone":   # M3.2: Drone Operator launches a bomb or scout drone (one of each per operator)
			var kind := String(c.get("kind", "bomb"))
			var did := &"us_bomb_drone" if kind == "bomb" else &"us_scout_drone"
			for u: SimEntity in _own_units(w, pid, c):
				if not w.udef(u).tags.has("drone_operator") or u.res_id < 0 or w.drone_wait(u, kind) > 0:
					continue
				var dr := w.spawn_unit(did, pid, null, u.pos)
				dr.air_home = u.id
				if kind == "bomb":
					u.air_t = SimWorld.DRONE_BUSY
				else:
					u.aux_t = SimWorld.DRONE_BUSY
				w.events.append({"t": "drone", "id": dr.id, "op": u.id, "owner": pid})
		"resume_build":
			var site := w.get_ent(int(c.get("target", 0)))
			if site == null or site.owner != pid or site.built:
				return
			for u: SimEntity in _own_units(w, pid, c):
				if SimWorld.can_construct(w.udef(u), w.bdef(site)):
					_push(u, {"o": "build", "target": site.id}, bool(c.get("q", false)))
					if w.udef(u).harvest_capacity > 0:
						u.phase = -1
		"repair":   # M3.1 (ZH): builders restore an own damaged structure, paying as they go
			var rb := w.get_ent(int(c.get("target", 0)))
			if rb == null or rb.owner != pid or rb.kind != SimEntity.Kind.BUILDING or not rb.built or rb.hp >= rb.max_hp:
				return
			for u: SimEntity in _own_units(w, pid, c):
				if SimWorld.is_constructor(w.udef(u)):
					_push(u, {"o": "repair", "target": rb.id, "acc": 0}, bool(c.get("q", false)))
					if w.udef(u).harvest_capacity > 0:
						u.phase = -1
		"cancel_build":
			var s2 := w.get_ent(int(c.get("target", 0)))
			if s2 != null and s2.owner == pid and s2.kind == SimEntity.Kind.BUILDING and not s2.built:
				w.players[pid].supply += w.bdef(s2).cost
				s2.alive = false
				w.map.unstamp(s2.tile, s2.fp)
				w.power_dirty = true
				w.events.append({"t": "death", "id": s2.id, "kind": s2.kind, "def": s2.def_id, "pos": s2.pos, "owner": pid, "silent": true})
		"queue":
			_queue(w, pid, c)
		"dequeue":
			var b4 := w.get_ent(int(c.get("target", 0)))
			if b4 == null or b4.owner != pid:
				return
			var i: int = int(c.get("n", -1))
			if i < 0:
				i = b4.queue.size() - 1
			if i >= 0 and i < b4.queue.size():
				w.players[pid].supply += int(b4.q_paid[i])
				b4.queue.remove_at(i)
				b4.q_paid.remove_at(i)
				if i == 0:
					b4.q_progress = 0
		"repeat":
			var b5 := w.get_ent(int(c.get("target", 0)))
			if b5 != null and b5.owner == pid:
				b5.repeat = bool(c.get("flag", false))
		"rally":
			for id in c.get("ids", []):
				var b6 := w.get_ent(int(id))
				if b6 != null and b6.owner == pid and b6.kind == SimEntity.Kind.BUILDING:
					if bool(c.get("clear", false)):
						b6.rally = Vector2i(-1, -1)
					else:
						b6.rally = c["pos"]
						b6.rally_attack = bool(c.get("flag", false))
		"buy_power":
			PowersSys.buy(w, pid, StringName(c.get("def", "")))
		"power":
			PowersSys.fire(w, pid, StringName(c.get("def", "")), c.get("pos", Vector2i.ZERO))
		"detonate":
			for id in c.get("ids", []):
				var tr := w.get_ent(int(id))
				if tr != null and tr.owner == pid and tr.kind == SimEntity.Kind.BUILDING and tr.built and Content.btag(tr.def_id, "trap"):
					TplaSys.detonate_trap(w, tr)
		"surrender":
			w.eliminate(pid)

static func _own_units(w: SimWorld, pid: int, c: Dictionary) -> Array:
	var out: Array = []
	for id in c.get("ids", []):
		var e := w.get_ent(int(id))
		if e != null and e.owner == pid and e.kind == SimEntity.Kind.UNIT and e.res_id >= 0:
			out.append(e)
	return out

static func _push(u: SimEntity, o: Dictionary, queued: bool) -> void:
	if not queued:
		u.orders.clear()
		u.target = 0
		u.goal = Vector2i(-1, -1)
	u.orders.append(o)

## Group move: each unit gets its own slot around the target so the group spreads in a formation.
static func _unit_orders(w: SimWorld, pid: int, c: Dictionary, t: String) -> void:
	var units := _own_units(w, pid, c)
	if units.is_empty():
		return
	var pos: Vector2i = c["pos"]
	var center_tile := FX.to_tile(pos)
	var slots := formation_slots(w, center_tile, units.size(), w.is_vehicle(units[0]))
	# assign slots in a stable way: sort units by distance to target
	units.sort_custom(func(a, b): return FX.dist2(a.pos, pos) < FX.dist2(b.pos, pos) if FX.dist2(a.pos, pos) != FX.dist2(b.pos, pos) else a.id < b.id)
	var caps := group_speed(w, units)
	for i in units.size():
		var u: SimEntity = units[i]
		var dest := pos if units.size() == 1 else FX.tile_center(slots[i])
		# harvesters ordered to move simply move
		var o := {"o": t, "pos": dest}
		if caps.has(u.id):
			o["spd"] = caps[u.id]
		_push(u, o, bool(c.get("q", false)))
		if t == "guard":
			u.home = dest

## Zero Hour-style group move (studied from ZH's AIGroup, reimplemented): a group travels at the
## speed of its slowest member so it arrives together. Only units within GROUP_RADIUS of the
## group's centre are capped; stragglers catch up at full speed. Returns id -> cap (fx/tick).
const GROUP_RADIUS := FX.ONE * 10
static func group_speed(w: SimWorld, units: Array) -> Dictionary:
	var out := {}
	if units.size() < 2:
		return out
	var cx := 0
	var cy := 0
	for u: SimEntity in units:
		cx += u.pos.x
		cy += u.pos.y
	var cen := Vector2i(cx / units.size(), cy / units.size())
	var near: Array = []
	var slow := 1 << 30
	var fast := 0
	for u: SimEntity in units:
		if FX.dist(u.pos, cen) <= GROUP_RADIUS:
			near.append(u)
			var s := FX.speed_per_tick(w.udef(u).speed_mtps)
			slow = mini(slow, s)
			fast = maxi(fast, s)
	if near.size() < 2 or slow == fast:
		return out
	for u: SimEntity in near:
		out[u.id] = slow
	return out

static func formation_slots(w: SimWorld, center: Vector2i, n: int, vehicle: bool) -> Array:
	var out: Array = []
	var spacing := 2 if vehicle else 1
	var r := 0
	while out.size() < n and r < 12:
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if maxi(absi(xx), absi(yy)) != r:
					continue
				var t := center + Vector2i(xx * spacing, yy * spacing)
				if w.map.passable(t, vehicle):
					out.append(t)
					if out.size() >= n:
						return out
		r += 1
	while out.size() < n:
		out.append(center)
	return out

static func is_barricade(w: SimWorld, b: SimEntity) -> bool:
	return w.bdef(b).garrison_capacity > 0 and w.bdef(b).tags.has("barricade")

static func leave_barricade(w: SimWorld, b: SimEntity) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and u.res_id == -b.id:
			u.res_id = 0
			u.pos = FX.tile_center(w.map.nearest_passable(FX.to_tile(b.pos) + Vector2i(0, b.fp.y), false))
			u.orders.clear()
			u.goal = MoveSys.NONE

static func _place(w: SimWorld, pid: int, c: Dictionary) -> void:
	var def_id := StringName(c.get("def", ""))
	var t: Vector2i = c.get("tile", Vector2i.ZERO)
	var builders: Array = []
	var bids: Array = []
	var pd: BuildingDef = Content.building(def_id)
	for u: SimEntity in _own_units(w, pid, c):
		if pd != null and SimWorld.can_construct(w.udef(u), pd):
			builders.append(u)
			bids.append(u.id)
	if builders.is_empty():
		w.events.append({"t": "reject", "owner": pid, "reason": "REASON_NO_BUILDER"})
		return
	var reason := w.can_place(pid, def_id, t, true, bids)
	if reason != "":
		w.events.append({"t": "reject", "owner": pid, "reason": reason})
		return
	var d: BuildingDef = Content.building(def_id)
	w.players[pid].supply -= d.cost
	var site := w._place_building(d, pid, t, int(c.get("rot", 0)), false)
	w.events.append({"t": "site", "id": site.id, "owner": pid})
	for u: SimEntity in builders:
		_push(u, {"o": "build", "target": site.id}, bool(c.get("q", false)))
		if w.udef(u).harvest_capacity > 0:
			u.phase = -1   # a laborer sent to build stays a builder until told to harvest

## M3.2: an upgrade already in some production queue of this player.
static func upgrade_queued(w: SimWorld, pid: int, uid: StringName) -> bool:
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if b.alive and b.owner == pid and b.kind == SimEntity.Kind.BUILDING and b.queue.has(uid):
			return true
	return false

static func _queue(w: SimWorld, pid: int, c: Dictionary) -> void:
	var b := w.get_ent(int(c.get("target", 0)))
	if b == null or b.owner != pid or b.kind != SimEntity.Kind.BUILDING or not b.built:
		return
	var uid := StringName(c.get("def", ""))
	var bd: BuildingDef = w.bdef(b)
	if not bd.produces.has(String(uid)):
		return
	var ud: UnitDef = Content.unit(uid)
	if ud.tags.has("stub"):   # [STUB] aircraft: listed in the build tree, not producible yet
		w.events.append({"t": "reject", "owner": pid, "reason": "REASON_STUB"})
		return
	if w.prereqs_met(pid, ud.prereqs) != "":
		w.events.append({"t": "reject", "owner": pid, "reason": "REASON_PREREQ"})
		return
	if ud.tags.has("upgrade") and (w.players[pid].upgrades.has(String(uid)) or upgrade_queued(w, pid, uid)):
		w.events.append({"t": "reject", "owner": pid, "reason": "REASON_RESEARCHED"})
		return
	var n: int = 1 if ud.tags.has("upgrade") else maxi(1, int(c.get("n", 1)))
	for i in n:
		if b.queue.size() >= ProdSys.MAX_QUEUE:
			break
		if w.players[pid].supply < ud.cost:
			w.events.append({"t": "reject", "owner": pid, "reason": "REASON_FUNDS"})
			break
		w.players[pid].supply -= ud.cost
		b.queue.append(uid)
		b.q_paid.append(ud.cost)
