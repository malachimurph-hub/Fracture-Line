class_name PowersSys
## General powers: bought with general points (earned by rank-ups from Command XP), then fired.

static func run(w: SimWorld) -> void:
	if w.temp_vision.is_empty():
		return
	var keep: Array = []
	for tv in w.temp_vision:
		if int(tv["until"]) > w.tick:
			keep.append(tv)
	w.temp_vision = keep

static func can_buy(w: SimWorld, pid: int, id: StringName) -> String:
	var d: PowerDef = Content.powers.get(id)
	if d == null or d.stub:
		return "REASON_STUB"
	var p: SimPlayer = w.players[pid]
	if p.powers.has(String(id)):
		return "REASON_OWNED"
	if Content.faction_of_id(id) != p.faction:
		return "REASON_INVALID"
	if p.rank < d.rank_required:
		return "REASON_RANK"
	if p.points < d.point_cost:
		return "REASON_POINTS"
	return ""

static func buy(w: SimWorld, pid: int, id: StringName) -> void:
	if can_buy(w, pid, id) != "":
		return
	var d: PowerDef = Content.powers[id]
	var p: SimPlayer = w.players[pid]
	p.points -= d.point_cost
	p.powers[String(id)] = {"ready": w.tick}
	w.events.append({"t": "power_bought", "owner": pid, "def": id})

static func ready_in(w: SimWorld, pid: int, id: StringName) -> int:
	var p: SimPlayer = w.players[pid]
	if not p.powers.has(String(id)):
		return -1
	return maxi(0, int(p.powers[String(id)]["ready"]) - w.tick)

static func fire(w: SimWorld, pid: int, id: StringName, pos: Vector2i) -> void:
	if ready_in(w, pid, id) != 0:
		return
	var d: PowerDef = Content.powers[id]
	var p: SimPlayer = w.players[pid]
	p.powers[String(id)]["ready"] = w.tick + FX.ms_to_ticks(d.cooldown_ms)
	match d.kind:
		&"recon":
			w.temp_vision.append({"team": p.team, "tile": FX.to_tile(pos), "r": d.radius, "until": w.tick + FX.ms_to_ticks(d.duration_ms)})
		&"overcharge":
			var r := d.radius * FX.ONE
			for u: SimEntity in w.units_in_radius(pos, r):
				if u.owner == pid:
					u.overcharge_until = w.tick + FX.ms_to_ticks(d.duration_ms)
					u.shield = u.max_hp * d.amount / 100
					u.max_shield = u.shield
		&"logistics":
			EconSys.add_supply(w, p, d.amount)
			p.logistics_until = w.tick + FX.ms_to_ticks(d.duration_ms)
		&"ambush":
			# TPLA: a Militia cell climbs out of a spider hole at the target
			for i in d.amount:
				var u := w.spawn_unit(&"tpla_militia", pid, null, pos + Vector2i((i % 3 - 1) * FX.ONE, (i / 3) * FX.ONE))
				u.orders = [{"o": "guard", "pos": u.pos}]
		&"scrap_rain":
			for i in d.amount:
				var ang := i * 2 + 1
				var off := Vector2i(((ang % 5) - 2) * FX.ONE, ((ang * 3 % 5) - 2) * FX.ONE)
				TplaSys.spawn_crate(w, pos + off, 150)
		&"rust_barrage":
			TplaSys.add_zone(w, pos, d.radius * FX.ONE, FX.ms_to_ticks(d.duration_ms), d.amount, pid, p.team)
		&"uprising":
			var hq: SimEntity = null
			for eid in w.ids:
				var b: SimEntity = w.ents[eid]
				if b.alive and b.owner == pid and b.kind == SimEntity.Kind.BUILDING and b.built and w.bdef(b).is_hq:
					hq = b
					break
			if hq == null:
				for eid in w.ids:
					var b2: SimEntity = w.ents[eid]
					if b2.alive and b2.owner == pid and b2.kind == SimEntity.Kind.BUILDING and b2.built:
						hq = b2
						break
			if hq != null:
				for i in d.amount:
					var u2 := w.spawn_unit(&"tpla_militia", pid, hq)
					u2.vet = 1
					u2.max_hp = w.unit_max_hp(u2)
					u2.hp = u2.max_hp
		&"paradrop":
			# US: a Marine rifle squad parachutes onto the target
			for i in d.amount:
				var pu := w.spawn_unit(&"us_grunt", pid, null, pos + Vector2i((i % 3 - 1) * FX.ONE, (i / 3) * FX.ONE))
				pu.orders = [{"o": "guard", "pos": pu.pos}]
		&"strike":
			# US: precision air strike, three bombs along a short line (JTAC nearby: +25 %)
			var src := SimEntity.new()
			src.kind = SimEntity.Kind.BUILDING
			src.owner = pid
			src.team = p.team
			src.def_id = id
			var wd := WeaponDef.new()
			wd.id = id
			wd.damage = d.amount * (100 + AirSys.JTAC_BONUS) / 100 if AirSys.jtac_near(w, pid, pos) else d.amount
			wd.damage_type = &"demolition"
			wd.splash_mt = d.radius * 1000 / 2
			wd.vfx = &"bomb"
			for k in 3:
				CombatSys.explode(w, src, pos + Vector2i((k - 1) * FX.ONE * 3 / 2, (k - 1) * FX.ONE / 2), wd, 100)
		&"repair":
			# US: field repair - own vehicles, aircraft and structures in the radius regain amount % HP
			var rr := d.radius * FX.ONE
			for ru: SimEntity in w.units_in_radius(pos, rr):
				if ru.owner == pid and ru.res_id >= 0 and not w.udef(ru).tags.has("infantry"):
					ru.hp = mini(ru.max_hp, ru.hp + ru.max_hp * d.amount / 100)
			for bid in w.ids:
				var rb: SimEntity = w.ents[bid]
				if rb.alive and rb.owner == pid and rb.kind == SimEntity.Kind.BUILDING and rb.built and w.dist_to_building(pos, rb) <= rr:
					rb.hp = mini(rb.max_hp, rb.hp + rb.max_hp * d.amount / 100)
	w.events.append({"t": "power_fired", "owner": pid, "def": id, "pos": pos, "r": d.radius})
