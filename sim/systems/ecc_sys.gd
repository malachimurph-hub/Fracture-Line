class_name EccSys
## Russia tech-tree mechanics.
##  - Modular towers: one researched fitting per structure (balanced / anti-armor / anti-air).
##  - T-90M reactive armour: 40% less damage from rounds and rockets, once researched.
##  - Red Dawn: a Ministry ability on a long cooldown. Transport planes drop conscript squads.
##  - Black Market hacks: four researched abilities, each on its own cooldown.
##  - Grim Reaper: the launcher must deploy; the missile splits into warheads on the way down.
## Stealth-until-engaged and the deploy timer live in UsSys / CombatSys next to the other stealth tags.

const DEPLOY_TICKS := 160          ## 8 s planted before the Grim Reaper can fire
const RED_DAWN_MS := 450000        ## 7.5 min
const RED_DAWN_SQUADS := 3
const ERA_KEEP := 60               ## incoming rounds and rockets keep this percent
const MIRV := 6
const MIRV_SPREAD_MT := 1100
const TOWER_COST := {"bal": 450, "at": 800, "aa": 800}
const TOWER_POWER := {"bal": 1, "at": 2, "aa": 2}
const TOWER_UP := {"bal": "ecc_up_tower_bal", "at": "ecc_up_tower_at", "aa": "ecc_up_tower_aa"}
const TOWER_WPN := {"bal": &"ecc_tower_bal", "at": &"ecc_tower_at", "aa": &"ecc_tower_aa"}
## Rounds and rockets. Small arms, sniper fire, flame and corrosive are not on this list.
const ERA_TYPES := {
	&"cannon": true, &"anti_tank": true, &"autocannon": true, &"explosive": true, &"demolition": true,
	&"hmg": true, &"quad": true, &"flak": true, &"aa_ground": true, &"aa_missile": true,
}
const HACKS := {
	"power": {"up": "ecc_up_hack_power", "cd": 180000, "dur": 18000},
	"radar": {"up": "ecc_up_hack_radar", "cd": 210000, "dur": 25000},
	"funds": {"up": "ecc_up_hack_funds", "cd": 240000, "dur": 30000, "rate": 30},
	"hijack": {"up": "ecc_up_hack_hijack", "cd": 300000},
}

static func run(w: SimWorld) -> void:
	if w.tick % FX.TICK_HZ != 0:
		return
	for p in w.players:
		if p.siphon_until <= w.tick or p.siphon_from < 0 or p.siphon_from >= w.players.size():
			continue
		var v: SimPlayer = w.players[p.siphon_from]
		if v.eliminated:
			continue
		var n: int = mini(p.siphon_rate, v.supply)
		if n <= 0:
			continue
		v.supply -= n
		p.supply = mini(SimWorld.SUPPLY_CAP, p.supply + n)
		w.events.append({"t": "income", "owner": p.id, "def": &"ecc_black_market", "amount": n})

## 40% reduction for a researched T-90M against rounds and rockets. Other damage is unchanged.
static func mitigate(w: SimWorld, target: SimEntity, amount: int, dtype: StringName) -> int:
	if amount <= 0 or target == null or target.kind != SimEntity.Kind.UNIT:
		return amount
	if target.def_id != &"ecc_t90" or target.owner < 0:
		return amount
	if not w.players[target.owner].upgrades.has("ecc_up_era"):
		return amount
	if not ERA_TYPES.has(dtype):
		return amount
	return maxi(1, amount * ERA_KEEP / 100)

static func tower_of(b: SimEntity) -> String:
	var s := String(b.aux_def)
	return s if TOWER_COST.has(s) else ""

static func has_tower(b: SimEntity) -> bool:
	return tower_of(b) != ""

static func tower_draw(b: SimEntity) -> int:
	return int(TOWER_POWER.get(tower_of(b), 0))

static func _own_built(w: SimWorld, pid: int, b: SimEntity) -> bool:
	return b != null and b.alive and b.owner == pid and b.kind == SimEntity.Kind.BUILDING and b.built

static func can_install(w: SimWorld, pid: int, b: SimEntity, kind: String) -> String:
	if not TOWER_COST.has(kind):
		return "REASON_INVALID"
	if not _own_built(w, pid, b) or w.bdef(b).faction != &"ecc":
		return "REASON_INVALID"
	if tower_of(b) == kind:
		return "REASON_OWNED"
	if not w.players[pid].upgrades.has(TOWER_UP[kind]):
		return "REASON_PREREQ"
	if w.players[pid].supply < int(TOWER_COST[kind]):
		return "REASON_FUNDS"
	return ""

static func install_tower(w: SimWorld, pid: int, b: SimEntity, kind: String) -> void:
	if can_install(w, pid, b, kind) != "":
		return
	w.players[pid].supply -= int(TOWER_COST[kind])
	b.aux_def = StringName(kind)
	var n: int = w.bdef(b).weapons.size()
	while b.cds.size() < n + 1:
		b.cds.append(0)
	b.cds[n] = 0
	w.power_dirty = true
	w.events.append({"t": "tower", "id": b.id, "kind": kind, "owner": pid})

## Fired from CombatSys once the structure's own weapons have had their turn.
static func fire_tower(w: SimWorld, b: SimEntity) -> void:
	var kind := tower_of(b)
	if kind == "":
		return
	if not b.powered:
		return
	var wd: WeaponDef = Content.weapon(TOWER_WPN[kind])
	if wd == null:
		return
	var slot: int = w.bdef(b).weapons.size()
	while b.cds.size() <= slot:
		b.cds.append(0)
	if int(b.cds[slot]) > 0:
		return
	var r := FX.mt_to_fx(wd.range_mt)
	var t: SimEntity = w.get_ent(b.target)
	if t == null or not OrderSys.valid_target(w, b, t) or not CombatSys.layer_ok(w, wd, t) or w.dist_to_building(t.pos, b) > r + t.radius:
		t = null
		if (w.tick + b.id) % 5 == 0:
			t = _tower_target(w, b, r, wd)
	if t == null:
		return
	b.target = t.id
	CombatSys.fire(w, b, t, wd, 100)
	b.cds[slot] = FX.ms_to_ticks(wd.cooldown_ms)

static func _tower_target(w: SimWorld, b: SimEntity, r: int, wd: WeaponDef) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 50
	for e: SimEntity in w.units_in_radius(b.pos, r + b.radius):
		if not OrderSys.valid_target(w, b, e) or not CombatSys.layer_ok(w, wd, e):
			continue
		var d := FX.dist2(e.pos, b.pos)
		if d < bd:
			bd = d
			best = e
	return best

## Ticks until the ability can be used again. -1 when the research is not done.
static func ready_in(w: SimWorld, pid: int, key: String) -> int:
	var p: SimPlayer = w.players[pid]
	var up := _upgrade_for(key)
	if up != "" and not p.upgrades.has(up):
		return -1
	if not p.ability_ready.has(key):
		return 0
	return maxi(0, int(p.ability_ready[key]) - w.tick)

static func _upgrade_for(key: String) -> String:
	if key == "ecc_red_dawn":
		return "ecc_up_red_dawn"
	if key.begins_with("ecc_hack_"):
		var kind := key.trim_prefix("ecc_hack_")
		if HACKS.has(kind):
			return HACKS[kind]["up"]
	return ""

static func _arm(w: SimWorld, pid: int, key: String, cd_ms: int) -> bool:
	if ready_in(w, pid, key) != 0:
		return false
	w.players[pid].ability_ready[key] = w.tick + FX.ms_to_ticks(cd_ms)
	return true

static func red_dawn(w: SimWorld, pid: int, b: SimEntity, pos: Vector2i) -> void:
	if not _own_built(w, pid, b) or b.def_id != &"ecc_ministry" or not b.powered:
		return
	if not _arm(w, pid, "ecc_red_dawn", RED_DAWN_MS):
		return
	for i in RED_DAWN_SQUADS:
		var ang := i * 2 + 1
		var off := Vector2i(((ang % 3) - 1) * FX.ONE * 2, ((ang * 2 % 3) - 1) * FX.ONE * 2)
		var u := w.spawn_unit(&"ecc_squad", pid, null, pos + off)
		u.orders = [{"o": "guard", "pos": u.pos}]
	w.events.append({"t": "red_dawn", "owner": pid, "pos": pos, "id": b.id})

static func hack(w: SimWorld, pid: int, b: SimEntity, kind: String, victim_id: int) -> void:
	if not HACKS.has(kind) or not _own_built(w, pid, b) or b.def_id != &"ecc_black_market" or not b.powered:
		return
	var spec: Dictionary = HACKS[kind]
	var victim := w.get_ent(victim_id)
	if victim == null or not victim.alive or victim.owner < 0 or not w.enemies(w.player_team(pid), victim.team):
		return
	if kind == "hijack":
		if not hijack_ok(w, victim):
			return
		if not _arm(w, pid, "ecc_hack_hijack", int(spec["cd"])):
			return
		_take(w, pid, victim)
		return
	if victim.kind != SimEntity.Kind.BUILDING and victim.kind != SimEntity.Kind.UNIT:
		return
	if not _arm(w, pid, "ecc_hack_" + kind, int(spec["cd"])):
		return
	var foe: SimPlayer = w.players[victim.owner]
	var until := w.tick + FX.ms_to_ticks(int(spec["dur"]))
	if kind == "power":
		foe.power_down_until = until
		w.power_dirty = true
	elif kind == "radar":
		foe.radar_until = until
	elif kind == "funds":
		w.players[pid].siphon_from = victim.owner
		w.players[pid].siphon_until = until
		w.players[pid].siphon_rate = int(spec["rate"])
	w.events.append({"t": "hack", "owner": pid, "kind": kind, "foe": victim.owner, "id": b.id})

static func hijack_ok(w: SimWorld, e: SimEntity) -> bool:
	if e == null or not e.alive or e.kind != SimEntity.Kind.UNIT or e.res_id < 0:
		return false
	var d: UnitDef = w.udef(e)
	return d.tags.has("drone") or d.move_layer == &"vehicle"

static func _take(w: SimWorld, pid: int, e: SimEntity) -> void:
	e.owner = pid
	e.team = w.player_team(pid)
	e.orders.clear()
	e.path.clear()
	e.goal = MoveSys.NONE
	e.target = 0
	e.air_home = 0
	w.power_dirty = true
	w.events.append({"t": "hijack", "id": e.id, "owner": pid})

## Ballistic flight for the Iskander and the Grim Reaper. Zeus stays on its own timing.
static func ballistic_ticks(wd: WeaponDef, dist_fx: int) -> int:
	if wd.id != &"ecc_reaper_mirv" and wd.id != &"ecc_iskander" and wd.id != &"ecc_mzkt_cm":
		return -1
	var ms: int = dist_fx * 1000 / (FX.ONE * 8)
	return maxi(8, ms * FX.TICK_HZ / 1000)

## The Grim Reaper's round bursts into MIRV warheads instead of detonating as one shell.
static func split_mirv(w: SimWorld, r: Dictionary) -> void:
	var wd: WeaponDef = Content.weapon(StringName(r["w"]))
	var impact := Vector2i(int(r["ix"]), int(r["iy"]))
	var pts: Array = []
	var spread := FX.mt_to_fx(MIRV_SPREAD_MT)
	for i in MIRV:
		var ang := float(i) / float(MIRV) * TAU
		var off := Vector2i(int(cos(ang) * spread), int(sin(ang) * spread))
		var at: Vector2i = impact + off
		pts.append(at)
		w.flight.append({
			"at": w.tick + 12 + i * 2, "src": int(r["src"]), "team": int(r["team"]), "owner": int(r["owner"]),
			"tid": 0, "w": String(wd.id), "pct": int(r["pct"]), "hit": false, "ix": at.x, "iy": at.y,
			"air": false, "arty": true, "sub": 1,
		})
	w.events.append({"t": "mirv", "pos": impact, "pts": pts, "owner": int(r["owner"]), "r": FX.mt_to_fx(wd.splash_mt)})

## Bare MZKT-7930. One permanent module, fitted in place. Costs are on top of the hull price.
const MZKT_HULL := &"ecc_mzkt"
const INSTALL_TICKS := 80          ## 4 s, the truck stays put
const AURA_HALT := 20              ## 1 s halted before the radar buffs artillery
const MZKT := {
	"aa": {"id": &"ecc_mzkt_aa", "cost": 800, "need": "ecc_ministry"},
	"radar": {"id": &"ecc_mzkt_radar", "cost": 1600, "need": ""},
	"missile": {"id": &"ecc_mzkt_missile", "cost": 1100, "need": ""},
}

static func mzkt_reason(w: SimWorld, pid: int, u: SimEntity, kind: String) -> String:
	if not MZKT.has(kind):
		return "REASON_INVALID"
	if u == null or not u.alive or u.owner != pid or u.kind != SimEntity.Kind.UNIT or u.def_id != MZKT_HULL:
		return "REASON_OWNED"
	if u.aux_def != &"":
		return "HUD_MZKT_FITTING"
	var spec: Dictionary = MZKT[kind]
	if String(spec["need"]) != "" and not w.has_completed(pid, spec["need"]):
		return String(spec["need"])
	if w.players[pid].supply < int(spec["cost"]):
		return "REASON_FUNDS"
	return ""

static func begin_mzkt(w: SimWorld, pid: int, u: SimEntity, kind: String) -> void:
	if mzkt_reason(w, pid, u, kind) != "":
		return
	var spec: Dictionary = MZKT[kind]
	w.players[pid].supply -= int(spec["cost"])
	u.aux_def = spec["id"]
	u.phase = INSTALL_TICKS
	u.orders.clear()
	u.goal = MoveSys.NONE
	u.target = 0
	w.events.append({"t": "mzkt_fit", "id": u.id, "def": String(spec["id"]), "owner": pid})

## Called every tick. phase counts down, then the definition swaps. Hit points keep their fraction.
static func installs(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.phase <= 0 or u.aux_def == &"":
			continue
		if not String(u.aux_def).begins_with("ecc_mzkt_"):
			continue
		u.goal = MoveSys.NONE
		u.orders.clear()
		u.phase -= 1
		if u.phase > 0:
			continue
		var nd: UnitDef = Content.unit(u.aux_def)
		if nd == null:
			u.aux_def = &""
			continue
		var frac := float(u.hp) / float(maxi(1, u.max_hp))
		u.def_id = nd.id
		u.max_hp = nd.max_hp
		u.hp = clampi(int(round(frac * float(nd.max_hp))), 1, nd.max_hp)
		u.sight = nd.sight
		u.radius = FX.mt_to_fx(nd.radius_mt)
		u.cds.clear()
		u.pre.clear()
		u.pre_ok.clear()
		u.ammo.clear()
		u.aux_def = &""
		u.still = 0
		w.events.append({"t": "mzkt", "id": u.id, "def": String(nd.id), "owner": u.owner})

## Friendly artillery inside a halted radar's aura. One bonus, never stacked. Minimum range is unchanged.
static func range_mt(w: SimWorld, u: SimEntity, base_mt: int) -> int:
	if u == null or not w.udef(u).tags.has("artillery"):
		return base_mt
	var reach := 0
	for id in w.ids:
		var r: SimEntity = w.ents[id]
		if not r.alive or r.kind != SimEntity.Kind.UNIT or r.res_id < 0 or r.owner != u.owner or r.id == u.id:
			continue
		var rd: UnitDef = w.udef(r)
		if rd == null or rd.range_aura_radius <= 0 or rd.range_aura_pct <= 0:
			continue
		if r.moving or r.goal != MoveSys.NONE or r.still < AURA_HALT:
			continue
		var lim: int = rd.range_aura_radius * FX.ONE
		if FX.dist(r.pos, u.pos) > lim:
			continue
		reach = maxi(reach, rd.range_aura_pct)
	if reach <= 0:
		return base_mt
	return base_mt * (100 + reach) / 100
