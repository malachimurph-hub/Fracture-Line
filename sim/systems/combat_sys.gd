class_name CombatSys
## Weapon cooldowns, firing (hitscan, with splash), structure and garrison fire, veterancy.
## M2.3 (Zero Hour-style weapon feel, studied from ZH's Weapon / TurretAI and reimplemented):
##  - units must face their target (hull, or turret if they have one) within aim_deg to fire
##  - pre-attack delay per shot / per new target / per clip
##  - clips: clip_size shots cooldown_ms apart, then reload_ms; idle units top the clip up
##  - scatter: shots land within scatter_mt (+ scatter_inf_mt vs infantry) of the aim point;
##    a miss deals no direct damage, splash still applies around the impact point

const VET_DMG := [100, 110, 120, 130]
const VET_HP := [100, 110, 120, 130]
const GARRISON_RANGE_BONUS := FX.ONE * 2

const REPAIR_RADIUS := FX.ONE * 10
const REPAIR_IDLE_TICKS := 200

static func run(w: SimWorld) -> void:
	if w.tick % 20 == 10:
		_base_repair(w)
	var js := RosterSys.jammers(w)
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
			var t: SimEntity = null
			if e.target != 0:
				t = w.get_ent(e.target)
				if t != null and not OrderSys.valid_target(w, e, t):
					t = null
			if not e.cds.is_empty():
				_aim(w, e, t)
			if t != null and not RosterSys.is_jammed(w, e, js):
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

## Turn turret (or idle hull) toward the target; recentre the turret when there is none.
static func _aim(w: SimWorld, u: SimEntity, t: SimEntity) -> void:
	var d: UnitDef = w.udef(u)
	var lp := Loco.params(d)
	var tr: int = lp["turret"]
	if t == null:
		if tr > 0:
			u.tface = Loco.turn(u.tface, u.face, tr)
		else:
			u.tface = u.face
		_refill_idle(w, u, d)
		return
	var want := FX.iatan2(t.pos.x - u.pos.x, t.pos.y - u.pos.y)
	if tr > 0:
		u.tface = Loco.turn(u.tface, want, tr)
	elif u.goal == MoveSys.NONE:
		# hull-mounted weapon: the whole unit turns to face the target
		u.face = Loco.turn(u.face, want, lp["turn"])
		u.dir = FX.dir_of(u.face)
		u.tface = u.face
	else:
		u.tface = u.face

static func _ensure(u: SimEntity, d: UnitDef) -> void:
	var n := d.weapons.size()
	if u.ammo.size() == n and u.pre.size() == n and u.pre_ok.size() == n:
		return
	u.ammo.resize(n)
	u.pre.resize(n)
	u.pre_ok.resize(n)
	for i in n:
		if u.ammo[i] == null:
			u.ammo[i] = Content.weapon(d.weapons[i]).clip_size
		if u.pre[i] == null:
			u.pre[i] = 0
		if u.pre_ok[i] == null:
			u.pre_ok[i] = 0

## Idle units reload a partly used clip once a full reload time has passed since the last shot.
static func _refill_idle(w: SimWorld, u: SimEntity, d: UnitDef) -> void:
	if (w.tick + u.id) % 10 != 0:
		return
	_ensure(u, d)
	for i in d.weapons.size():
		var wd: WeaponDef = Content.weapon(d.weapons[i])
		if wd.clip_size > 0 and int(u.ammo[i]) < wd.clip_size and w.tick - u.firing_tick >= FX.ms_to_ticks(wd.reload_ms):
			u.ammo[i] = wd.clip_size

static func aimed(u: SimEntity, t: SimEntity, wd: WeaponDef) -> bool:
	var want := FX.iatan2(t.pos.x - u.pos.x, t.pos.y - u.pos.y)
	return absi(FX.adiff(u.tface, want)) <= maxi(1, wd.aim_deg * FX.ANG / 360)

## Cooldown after a shot: between-shot delay, or clip reload when the clip runs dry.
static func after_shot(u: SimEntity, i: int, wd: WeaponDef) -> void:
	var vet_pct := 90 if u.vet >= 2 else 100
	if wd.clip_size > 0 and i < u.ammo.size():
		u.ammo[i] = int(u.ammo[i]) - 1
		if int(u.ammo[i]) <= 0:
			u.ammo[i] = wd.clip_size
			u.cds[i] = FX.ms_to_ticks(wd.reload_ms * vet_pct / 100)
			if wd.pre_attack_type == &"clip":
				u.pre[i] = 0
			return
	u.cds[i] = FX.ms_to_ticks(wd.cooldown_ms * vet_pct / 100)

static func _fire_unit(w: SimWorld, u: SimEntity, t: SimEntity) -> void:
	var d: UnitDef = w.udef(u)
	_ensure(u, d)
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
		if not aimed(u, t, wd):
			continue
		# pre-attack: aim / lock-on time. pre[i] = ticks spent, -1 = done for this target
		if int(u.pre_ok[i]) != t.id:
			u.pre_ok[i] = t.id
			u.pre[i] = 0
		var pt := FX.ms_to_ticks(wd.pre_attack_ms) if wd.pre_attack_ms > 0 else 0
		if pt > 0 and int(u.pre[i]) >= 0:
			u.pre[i] = int(u.pre[i]) + 1
			if int(u.pre[i]) < pt:
				continue
		fire(w, u, t, wd, dmg_pct(u))
		u.pre[i] = 0 if wd.pre_attack_type == &"shot" else -1
		after_shot(u, i, wd)

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
	var impact := t.pos
	var hit := true
	var sc := scatter_of(w, t, wd)
	if sc > 0:
		# radius uniform in [0, sc] (more shots land near the aim point), random bearing
		var rr := w.rng.range_int(sc + 1)
		var hv := FX.dir_of(w.rng.range_int(FX.ANG))
		impact = t.pos + Vector2i(hv.x * rr / FX.ONE, hv.y * rr / FX.ONE)
		hit = rr <= t.radius
	w.events.append({"t": "fire", "id": src.id, "to": impact, "tid": t.id, "vfx": wd.vfx, "w": wd.id, "miss": not hit})
	if hit:
		var armor := _armor_of(w, t)
		var dmg := wd.damage * Content.combat.mult(wd.damage_type, armor) / 100 * dmg_pct / 100
		w.damage(t, maxi(1, dmg), src)
	if wd.damage_type == &"corrosive":
		TplaSys.add_zone(w, impact, maxi(FX.ONE, FX.mt_to_fx(wd.splash_mt)), 120, wd.damage * dmg_pct / 100, src.owner, src.team)
	if wd.splash_mt > 0:
		var r := FX.mt_to_fx(wd.splash_mt)
		for o: SimEntity in w.units_in_radius(impact, r):
			if (hit and o.id == t.id) or not w.enemies(src.team, o.team) or o.res_id < 0:
				continue
			var frac := 100 - 50 * FX.dist(o.pos, impact) / maxi(1, r)
			var sd := wd.damage * Content.combat.mult(wd.damage_type, _armor_of(w, o)) / 100 * frac / 100 * dmg_pct / 100
			w.damage(o, sd, src)

## Scatter radius in fx for this shot: base scatter plus extra against infantry.
static func scatter_of(w: SimWorld, t: SimEntity, wd: WeaponDef) -> int:
	var sc := wd.scatter_mt
	if wd.scatter_inf_mt > 0 and t.kind == SimEntity.Kind.UNIT and w.udef(t).tags.has("infantry"):
		sc += wd.scatter_inf_mt
	return FX.mt_to_fx(sc) if sc > 0 else 0

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
			_ensure(u, d)
			fire(w, u, t, wd, dmg_pct(u))
			after_shot(u, i, wd)

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
