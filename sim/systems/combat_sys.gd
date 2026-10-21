class_name CombatSys
## Weapon cooldowns, firing (hitscan, with splash), structure and garrison fire, veterancy.

const VET_DMG := [100, 110, 120, 130]
const VET_HP := [100, 110, 120, 130]
const GARRISON_RANGE_BONUS := FX.ONE * 2

const REPAIR_RADIUS := FX.ONE * 10
const REPAIR_IDLE_TICKS := 200

static func run(w: SimWorld) -> void:
	if w.tick % 20 == 10:
		_base_repair(w)
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

static func dmg_pct(u: SimEntity) -> int:
	return VET_DMG[u.vet] * (100 + TplaSys.TIER_DMG * u.tier) / 100

static func _fire_unit(w: SimWorld, u: SimEntity, t: SimEntity) -> void:
	var d: UnitDef = w.udef(u)
	var dist := w.edge_dist(u, t)
	for i in d.weapons.size():
		if u.cds[i] > 0:
			continue
		var wd: WeaponDef = Content.weapon(d.weapons[i])
		if wd.min_tier > u.tier:
			continue
		if dist > FX.mt_to_fx(wd.range_mt) or dist < FX.mt_to_fx(wd.min_range_mt):
			continue
		if d.tags.has("suicide"):
			# bomb truck: drives into the target and detonates (GDD 5.4 Mule)
			u.phase = 99
			u.firing_tick = w.tick
			explode(w, u, u.pos, wd, dmg_pct(u))
			w._kill(u, null)
			return
		fire(w, u, t, wd, dmg_pct(u))
		u.cds[i] = FX.ms_to_ticks(wd.cooldown_ms * (90 if u.vet >= 2 else 100) / 100)

## Area blast (Demo Trap, Mule bomb truck): hits enemy units and enemy structures in the radius.
static func explode(w: SimWorld, src: SimEntity, center: Vector2i, wd: WeaponDef, pct: int) -> void:
	var r := FX.mt_to_fx(wd.splash_mt)
	w.events.append({"t": "explode", "id": src.id, "owner": src.owner, "trap": src.kind == SimEntity.Kind.BUILDING, "pos": center, "r": r, "vfx": wd.vfx})
	for o: SimEntity in w.units_in_radius(center, r):
		if o.res_id < 0 or not w.enemies(src.team, o.team):
			continue
		var frac := 100 - 50 * FX.dist(o.pos, center) / maxi(1, r)
		var sd := wd.damage * Content.combat.mult(wd.damage_type, _armor_of(w, o)) / 100 * frac / 100 * pct / 100
		w.damage(o, maxi(1, sd), src)
	var blds: Array = []
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if b.alive and (b.kind == SimEntity.Kind.BUILDING or b.kind == SimEntity.Kind.NEUTRAL) and w.enemies(src.team, b.team) and w.dist_to_building(center, b) <= r:
			blds.append(b)
	for b: SimEntity in blds:
		w.damage(b, maxi(1, wd.damage * Content.combat.mult(wd.damage_type, &"structure") / 100 * pct / 100), src)

static func fire(w: SimWorld, src: SimEntity, t: SimEntity, wd: WeaponDef, dmg_pct: int) -> void:
	src.firing_tick = w.tick
	if src.kind == SimEntity.Kind.UNIT:
		src.dir = t.pos - src.pos
	w.events.append({"t": "fire", "id": src.id, "to": t.pos, "tid": t.id, "vfx": wd.vfx})
	var armor := _armor_of(w, t)
	var dmg := wd.damage * Content.combat.mult(wd.damage_type, armor) / 100 * dmg_pct / 100
	w.damage(t, maxi(1, dmg), src)
	if wd.damage_type == &"corrosive":
		TplaSys.add_zone(w, t.pos, maxi(FX.ONE, FX.mt_to_fx(wd.splash_mt)), 120, wd.damage * dmg_pct / 100, src.owner, src.team)
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
			fire(w, u, t, wd, dmg_pct(u))
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
		a.max_hp = w.unit_max_hp(a)
		a.hp += a.max_hp - old_max
		w.events.append({"t": "promoted", "id": a.id, "vet": nv})

## Zero Hour-style field repair: units that have not been hit for 10 s and stand within
## 10 tiles of their own finished HQ or production building regain 2% max HP per second.
## Gives retreating (Medium/Hard AI or player) units a reason to fall back home.
static func _base_repair(w: SimWorld) -> void:
	var anchors := {}
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if b.alive and b.built and b.kind == SimEntity.Kind.BUILDING and b.owner >= 0:
			var bd: BuildingDef = Content.building(b.def_id)
			if bd != null and (bd.is_hq or not bd.produces.is_empty()):
				if not anchors.has(b.owner):
					anchors[b.owner] = []
				anchors[b.owner].append(b.pos)
	if anchors.is_empty():
		return
	var r2 := REPAIR_RADIUS * REPAIR_RADIUS
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.hp >= u.max_hp or not anchors.has(u.owner):
			continue
		if w.tick - u.last_hit_tick < REPAIR_IDLE_TICKS:
			continue
		for p: Vector2i in anchors[u.owner]:
			if FX.dist2(p, u.pos) <= r2:
				u.hp = mini(u.max_hp, u.hp + maxi(1, u.max_hp / 50))
				break
