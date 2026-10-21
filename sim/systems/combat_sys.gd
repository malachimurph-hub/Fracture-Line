class_name CombatSys
## Weapon cooldowns, firing (hitscan, with splash), structure and garrison fire, veterancy.

const VET_DMG := [100, 110, 120, 130]
const VET_HP := [100, 110, 120, 130]
const GARRISON_RANGE_BONUS := FX.ONE * 2

static func run(w: SimWorld) -> void:
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive:
			continue
		for i in e.cds.size():
			if e.cds[i] > 0:
				e.cds[i] -= 1
		if e.kind == SimEntity.Kind.UNIT:
			if e.res_id < 0:
				continue
			if e.target != 0:
				var t := w.get_ent(e.target)
				if t != null and OrderSys.valid_target(w, e, t):
					_fire_unit(w, e, t)
			# heroic self-heal 1% / s
			if e.vet >= 3 and w.tick % 20 == 0 and e.hp < e.max_hp:
				e.hp = mini(e.max_hp, e.hp + maxi(1, e.max_hp / 100))
		elif e.kind == SimEntity.Kind.BUILDING and e.built and not e.cds.is_empty():
			_structure_fire(w, e)
		elif e.kind == SimEntity.Kind.NEUTRAL and e.owner >= 0 and (w.tick + e.id) % 2 == 0:
			_garrison_fire(w, e)

static func _fire_unit(w: SimWorld, u: SimEntity, t: SimEntity) -> void:
	var d: UnitDef = w.udef(u)
	var dist := w.edge_dist(u, t)
	for i in d.weapons.size():
		if u.cds[i] > 0:
			continue
		var wd: WeaponDef = Content.weapon(d.weapons[i])
		if dist > FX.mt_to_fx(wd.range_mt) or dist < FX.mt_to_fx(wd.min_range_mt):
			continue
		fire(w, u, t, wd, VET_DMG[u.vet])
		u.cds[i] = FX.ms_to_ticks(wd.cooldown_ms * (90 if u.vet >= 2 else 100) / 100)

static func fire(w: SimWorld, src: SimEntity, t: SimEntity, wd: WeaponDef, dmg_pct: int) -> void:
	src.firing_tick = w.tick
	if src.kind == SimEntity.Kind.UNIT:
		src.dir = t.pos - src.pos
	w.events.append({"t": "fire", "id": src.id, "to": t.pos, "tid": t.id, "vfx": wd.vfx})
	var armor := _armor_of(w, t)
	var dmg := wd.damage * Content.combat.mult(wd.damage_type, armor) / 100 * dmg_pct / 100
	w.damage(t, maxi(1, dmg), src)
	if wd.splash_mt > 0:
		var r := FX.mt_to_fx(wd.splash_mt)
		for o: SimEntity in w.units_in_radius(t.pos, r):
			if o.id == t.id or not w.enemies(src.team, o.team) or o.res_id < 0:
				continue
			var frac := 100 - 50 * FX.dist(o.pos, t.pos) / maxi(1, r)
			var sd := wd.damage * Content.combat.mult(wd.damage_type, _armor_of(w, o)) / 100 * frac / 100 * dmg_pct / 100
			w.damage(o, sd, src)

static func _armor_of(w: SimWorld, t: SimEntity) -> StringName:
	if t.kind == SimEntity.Kind.UNIT:
		return w.udef(t).armor_type
	return &"structure"

static func _structure_fire(w: SimWorld, b: SimEntity) -> void:
	var bd: BuildingDef = w.bdef(b)
	if bd.needs_power_to_fire and (not b.powered or w.players[b.owner].low_power):
		return
	for i in bd.weapons.size():
		if b.cds[i] > 0:
			continue
		var wd: WeaponDef = Content.weapon(bd.weapons[i])
		var r := FX.mt_to_fx(wd.range_mt)
		var t := w.get_ent(b.target)
		if t == null or not OrderSys.valid_target(w, b, t) or w.dist_to_building(t.pos, b) > r + t.radius:
			t = null
			b.target = 0
			if (w.tick + b.id) % 5 == 0:
				t = _nearest_enemy_unit(w, b, b.pos, r + b.radius)
		if t != null:
			b.target = t.id
			fire(w, b, t, wd, 100)
			b.cds[i] = FX.ms_to_ticks(wd.cooldown_ms)

static func _nearest_enemy_unit(w: SimWorld, src: SimEntity, p: Vector2i, r: int) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 50
	for e: SimEntity in w.units_in_radius(p, r):
		if not OrderSys.valid_target(w, src, e):
			continue
		var d := FX.dist2(e.pos, p)
		if d < bd:
			bd = d
			best = e
	return best

## Garrisoned infantry fire from the building with +range; damage hits the building first.
static func _garrison_fire(w: SimWorld, b: SimEntity) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.res_id != -b.id:
			continue
		var d: UnitDef = w.udef(u)
		for i in d.weapons.size():
			if u.cds[i] > 0:
				continue
			var wd: WeaponDef = Content.weapon(d.weapons[i])
			var r := FX.mt_to_fx(wd.range_mt) + GARRISON_RANGE_BONUS
			var t := _nearest_enemy_unit(w, u, b.pos, r + b.radius)
			if t == null:
				continue
			u.pos = b.pos
			fire(w, u, t, wd, VET_DMG[u.vet])
			u.cds[i] = FX.ms_to_ticks(wd.cooldown_ms)

static func grant_vet_xp(w: SimWorld, a: SimEntity, value: int) -> void:
	if a.kind != SimEntity.Kind.UNIT:
		return
	a.vxp += value
	var cost := maxi(100, w.udef(a).cost)
	var nv := 0
	if a.vxp >= cost * 4:
		nv = 3
	elif a.vxp >= cost * 2:
		nv = 2
	elif a.vxp >= cost:
		nv = 1
	if nv > a.vet:
		var old_max := a.max_hp
		a.vet = nv
		a.max_hp = w.udef(a).max_hp * VET_HP[nv] / 100
		a.hp += a.max_hp - old_max
		w.events.append({"t": "promoted", "id": a.id, "vet": nv})
