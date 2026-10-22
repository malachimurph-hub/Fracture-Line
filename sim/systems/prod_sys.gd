class_name ProdSys
## Construction (builders must stand next to the site; interrupted builds stay as a scaffold until
## a builder resumes them; one builder works at a time, as in Zero Hour) and unit production.

static func run(w: SimWorld) -> void:
	# construction: count adjacent builders working on each site
	var work := {}
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.orders.is_empty():
			continue
		var o: Dictionary = u.orders[0]
		if o.get("o", "") != "build":
			continue
		var s := w.get_ent(int(o["target"]))
		if s == null or s.built:
			continue
		if w.dist_to_building(u.pos, s) <= u.radius + FX.ONE:
			work[s.id] = work.get(s.id, 0) + 1
	for sid in work:
		var s: SimEntity = w.ents[sid]
		# Zero Hour: one builder constructs a structure at a time; extra builders sent to the
		# same scaffold stand by (they take over if the first is interrupted or killed)
		_build_step(w, s)
	# production
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if not b.alive or b.kind != SimEntity.Kind.BUILDING or not b.built or b.queue.is_empty():
			continue
		var p: SimPlayer = w.players[b.owner]
		if not b.powered:
			b.hold_reason = "REASON_NO_POWER"
			continue
		var ud: UnitDef = Content.unit(b.queue[0])
		var need := FX.ms_to_ticks(ud.build_time_ms) * 2
		if b.q_progress < need:
			b.q_progress += 1 if p.low_power else 2
			b.hold_reason = "REASON_LOW_POWER" if p.low_power else ""
			continue
		if p.pop + ud.pop > p.pop_cap:
			b.hold_reason = "REASON_POP_CAP"
			continue
		b.hold_reason = ""
		var uid: StringName = b.queue.pop_front()
		b.q_paid.pop_front()
		b.q_progress = 0
		var u := w.spawn_unit(uid, b.owner, b)
		p.pop += ud.pop
		p.stats["built"] += 1

		_after_spawn(w, b, u)
		if b.repeat:
			if p.supply >= ud.cost and b.queue.size() < 9:
				p.supply -= ud.cost
				b.queue.append(uid)
				b.q_paid.append(ud.cost)

static func _after_spawn(w: SimWorld, b: SimEntity, u: SimEntity) -> void:
	var ud: UnitDef = w.udef(u)
	if ud.harvest_capacity > 0:
		if EconSys.auto_harvest(w, u):
			return
	if b.rally.x >= 0:
		u.orders = [{"o": "amove" if b.rally_attack else "move", "pos": b.rally}]
	else:
		# step clear of the door
		var out := u.pos + _rot_dir(b.rot) * (FX.ONE * 2)
		u.orders = [{"o": "move", "pos": out}]

static func _rot_dir(r: int) -> Vector2i:
	match r:
		0: return Vector2i(0, 1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, -1)
	return Vector2i(-1, 0)

## HP a structure under construction has reached at `progress` (10 % at placement, full when
## complete). The view uses it as the scaffold's current maximum, so damage visuals only show
## damage actually taken, never the construction ramp (M2.4).
static func construction_hp_cap(max_hp: int, progress: int, build_ticks: int) -> int:
	return maxi(1, max_hp / 10 + (max_hp * 9 / 10) * progress / maxi(1, build_ticks))

static func _build_step(w: SimWorld, s: SimEntity) -> void:
	if s.built:
		return
	var d: BuildingDef = w.bdef(s)
	s.progress += 1
	var target_hp := construction_hp_cap(d.max_hp, s.progress, s.build_ticks)
	if target_hp > s.hp:
		s.hp = mini(d.max_hp, s.hp + (target_hp - s.hp))
	if s.progress >= s.build_ticks:
		s.built = true
		s.progress = s.build_ticks
		w.power_dirty = true
		w.players[s.owner].stats["built"] += 1
		w.events.append({"t": "built", "id": s.id, "owner": s.owner})
		if d.free_unit != &"":
			var u := w.spawn_unit(d.free_unit, s.owner, s)

			_after_spawn(w, s, u)
