class_name PowerSys
## Zero Hour-style global power: Low Power (use > capacity) halves production, turns off
## powered defenses and collapses shields. EU Grid flavor: structures inside the grid radius
## of an HQ / Reactor / Pylon carry the Grid shield. Also: unit shields
## from Aegis aura / Shield Overcharge, and population count.

static func run(w: SimWorld) -> void:
	if w.power_dirty or w.tick % 10 == 0:
		recompute_grid(w)
	_shields(w)

static func recompute_grid(w: SimWorld) -> void:
	w.power_dirty = false
	for p in w.players:
		p.power_prod = 0
		p.power_used = 0
		p.pop = 0
	var by_owner := {}
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.owner < 0:
			continue
		if e.kind == SimEntity.Kind.UNIT:
			w.players[e.owner].pop += Content.unit(e.def_id).pop
			continue
		if e.kind != SimEntity.Kind.BUILDING:
			continue
		if not by_owner.has(e.owner):
			by_owner[e.owner] = []
		by_owner[e.owner].append(e)
	for pid in by_owner:
		var blds: Array = by_owner[pid]
		var p: SimPlayer = w.players[pid]
		# Zero Hour power: global per player. Every finished structure is powered unless the
		# player is in Low Power. The EU Grid radius (HQ, Reactor, Pylon) only decides which
		# structures get the faction's Grid shield.
		var sources: Array = []
		for b: SimEntity in blds:
			if b.built and w.bdef(b).grid_radius > 0:
				sources.append(b)
		for b: SimEntity in blds:
			var d: BuildingDef = w.bdef(b)
			var g := false
			for s: SimEntity in sources:
				var r2: int = w.bdef(s).grid_radius * FX.ONE
				if FX.dist2(s.pos, b.pos) <= r2 * r2:
					g = true
					break
			b.gridded = g
			if b.built:
				if d.power > 0:
					# Power Substations and the Nuclear Power Station both feed the base. Research only unlocks the station.
					p.power_prod += d.power
				else:
					p.power_used -= d.power
				p.power_used += EccSys.tower_draw(b)
		if p.power_down_until > w.tick:
			p.power_prod = 0
		var low := p.power_used > p.power_prod
		if low != p.low_power:
			p.low_power = low
			w.events.append({"t": "low_power", "owner": pid, "on": low})
		# M4.3 (Malachi): in Low Power every structure that draws power shuts down completely (no
		# production, income, fire, shields or auras); power plants, the HQ and no_power structures run on.
		for b: SimEntity in blds:
			var d2: BuildingDef = w.bdef(b)
			var pw: bool = b.built and not (low and d2.power < 0 and not d2.tags.has("no_power"))
			if b.powered != pw:
				b.powered = pw
				w.events.append({"t": "power_state", "id": b.id, "on": pw})

static func _shields(w: SimWorld) -> void:
	# Aegis carriers
	var aegis: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and w.udef(e).shield_aura_radius > 0:
			aegis.append(e)
	if w.tick % 4 == 0:
		for a in aegis:
			var ad: UnitDef = w.udef(a)
			var r: int = ad.shield_aura_radius * FX.ONE
			for u: SimEntity in w.units_in_radius(a.pos, r):
				if u.team == a.team:
					u.aura_tick = w.tick
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.owner < 0:
			continue
		if e.kind == SimEntity.Kind.BUILDING:
			var d: BuildingDef = w.bdef(e)
			var on: bool = e.built and e.gridded and not w.players[e.owner].low_power and d.shield_pct > 0
			e.max_shield = d.max_hp * d.shield_pct / 100 if on else 0
			if not on:
				if e.shield > 0:
					e.shield = 0
			elif w.tick - e.last_hit_tick > 100 and e.shield < e.max_shield:
				e.shield = mini(e.max_shield, e.shield + maxi(1, e.max_shield / 200))
		elif e.kind == SimEntity.Kind.UNIT:
			var over := e.overcharge_until > w.tick
			var in_aura := w.tick - e.aura_tick <= 8
			if over:
				e.max_shield = e.max_hp * 60 / 100
			elif in_aura:
				e.max_shield = e.max_hp * 35 / 100
			else:
				e.max_shield = 0
			if e.shield > e.max_shield:
				e.shield = maxi(e.max_shield, e.shield - maxi(1, e.max_hp / 40))
			elif e.max_shield > 0 and w.tick - e.last_hit_tick > 60:
				e.shield = mini(e.max_shield, e.shield + maxi(1, e.max_shield / 100))
