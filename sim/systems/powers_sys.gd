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
	w.events.append({"t": "power_fired", "owner": pid, "def": id, "pos": pos, "r": d.radius})
