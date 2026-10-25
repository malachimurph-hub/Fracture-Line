class_name AIPlayer
extends RefCounted
## Skirmish AI. Reads only its own entities plus its team's fog-limited view (fog memory of
## enemy structures, currently visible enemy units) and the map's start positions. Issues the
## same Commands as a human through MatchRunner.issue(). No resource or vision cheats.
## Layers: build planner (opening + dynamic), economy, production, army (defend / waves /
## retreat), scouting, pump capture, general powers. Allied AIs share a target via team_board.

const DIFF := {
	"easy":   {"think": 12, "harv_per_hub": 2, "first_wave_s": 420, "wave_mult": 70, "bunkers": 0, "retreat": false, "expand_s": 600, "powers": false, "scout": false, "crawlers": 1, "prod_gap": 3, "capture": false, "victim": "random"},
	"medium": {"think": 4, "harv_per_hub": 2, "first_wave_s": 300, "wave_mult": 100, "bunkers": 1, "retreat": true, "expand_s": 330, "powers": true, "scout": true, "crawlers": 1, "prod_gap": 1, "capture": true, "victim": "nearest"},
	"hard":   {"think": 2, "harv_per_hub": 3, "first_wave_s": 225, "wave_mult": 110, "bunkers": 2, "retreat": true, "expand_s": 240, "powers": true, "scout": true, "crawlers": 2, "prod_gap": 0, "capture": true, "victim": "focus"},
}

var r: MatchRunner
var pid: int = 0
var difficulty: String = "medium"
var persona: AIPersonalityDef
var think_every: int = 4
var cfg: Dictionary
var bb: Dictionary = {}     ## blackboard (saved)

func init(runner: MatchRunner, p_id: int, diff: String, personality: StringName) -> void:
	r = runner
	pid = p_id
	difficulty = diff if DIFF.has(diff) else "medium"
	persona = Content.ai_personalities.get(personality)
	cfg = DIFF[difficulty]
	think_every = cfg["think"]
	bb = {"wave": [], "wave_n": 0, "wave_start_value": 0, "staging": Vector2i(-1, -1), "threat_pos": Vector2i(-1, -1),
		"threat_tick": -10000, "scout": 0, "scout_i": 0, "retreated": [], "last_wave_tick": 0, "expand_res": 0,
		"capture_unit": 0, "next_think_prod": 0, "target_player": -1, "pylon_fail": 0, "defenders": []}

func to_dict() -> Dictionary:
	return {"pid": pid, "difficulty": difficulty, "persona": persona.id, "faction": String(faction()), "bb": bb.duplicate(true)}

## Structure / unit ids per role for the power-economy build planner (EU; AIUs overrides).
## "" = the faction has no such structure.
func roles() -> Dictionary:
	return {"builder": &"eu_crawler", "harvester": &"eu_harvester", "refinery": &"eu_hub", "power": &"eu_reactor",
		"bunker": &"eu_gun_bunker", "barracks": &"eu_barracks", "heavy": &"eu_heavy_factory", "motor": &"eu_motor_pool",
		"tech": &"eu_signals", "support": &"eu_relay", "aa_tower": &"eu_flak_tower", "income": &"eu_exchange",
		"mine": &"eu_minefield", "pylon": &""}   # M2.9: Grid Pylon removed

var R: Dictionary:
	get:
		if _roles.is_empty():
			_roles = roles()
		return _roles
var _roles: Dictionary = {}

## Faction this AI plays (subclasses such as AITpla override the faction-specific layers).
func faction() -> StringName:
	return w.faction_of(pid)

## Factory used by MatchRunner: picks the AI class for the slot's faction.
static func create(fac: StringName) -> AIPlayer:
	if fac == &"tpla":
		return AITpla.new()
	if fac == &"us":
		return AIUs.new()
	if fac == &"ecc":
		return AIRussia.new()
	return AIPlayer.new()

func from_dict(runner: MatchRunner, d: Dictionary) -> void:
	init(runner, int(d["pid"]), d["difficulty"], StringName(d["persona"]))
	bb = d["bb"]

# ------------------------------------------------------------------ helpers
var w: SimWorld:
	get: return r.sim

func me() -> SimPlayer:
	return w.players[pid]

func cmd(c: Dictionary) -> void:
	c["p"] = pid
	r.issue(c)

func my_ents(kind: int) -> Array:
	var out: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.owner == pid and e.kind == kind:
			out.append(e)
	return out

func hq() -> SimEntity:
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if w.bdef(b).is_hq:
			return b
	return null

func base_pos() -> Vector2i:
	var h := hq()
	if h != null:
		return h.pos
	var bl := my_ents(SimEntity.Kind.BUILDING)
	return bl[0].pos if not bl.is_empty() else Vector2i(64 * FX.ONE, 64 * FX.ONE)

func map_center() -> Vector2i:
	return Vector2i(w.map.w * FX.HALF, w.map.h * FX.HALF)

func seconds() -> int:
	return w.tick / FX.TICK_HZ

func army_value(units: Array) -> int:
	var v := 0
	for u: SimEntity in units:
		v += w.udef(u).cost
	return v

func combat_units() -> Array:
	var out: Array = []
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		var d: UnitDef = w.udef(u)
		if d.tags.has("builder") or d.tags.has("harvester") or u.res_id < 0:
			continue
		out.append(u)
	return out

# ------------------------------------------------------------------ main
func think() -> void:
	if me().eliminated:
		return
	_update_threats()
	_economy()
	_build()
	_production()
	_army()
	_victims()
	if cfg["scout"]:
		_scout()
	if cfg["capture"]:
		_capture()
	if cfg["powers"]:
		_powers()
	if (faction() == &"eu" or faction() == &"ecc") and _every("t_air", 40):   # M3.0 E / M3.2: German, Russian jets
		_air()

# ------------------------------------------------------------------ threat detection
func _update_threats() -> void:
	# visible enemy units near my structures/harvesters
	var nearest: SimEntity = null
	var nd := 1 << 50
	var my_team := me().team
	var anchors := my_ents(SimEntity.Kind.BUILDING)
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.kind != SimEntity.Kind.UNIT or not w.enemies(my_team, e.team) or e.res_id < 0:
			continue
		if w.udef(e).weapons.is_empty():
			continue
		if not w.fog.is_visible_ent(w, my_team, e):
			continue
		for b: SimEntity in anchors:
			var d := FX.dist2(b.pos, e.pos)
			if d < (FX.ONE * 14) * (FX.ONE * 14) and d < nd:
				nd = d
				nearest = e
	if nearest != null:
		bb["threat_pos"] = nearest.pos
		bb["threat_tick"] = w.tick

# ------------------------------------------------------------------ economy
func _economy() -> void:
	var p := me()
	var h := hq()
	var crawlers: Array = []
	var harvesters: Array = []
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		var d: UnitDef = w.udef(u)
		if d.tags.has("builder"):
			crawlers.append(u)
		elif d.tags.has("harvester"):
			harvesters.append(u)
	var want_crawlers: int = cfg["crawlers"] if seconds() > 180 else 1
	if h != null and crawlers.size() < want_crawlers and h.queue.is_empty() and p.supply >= Content.unit(R["builder"]).cost:
		cmd({"t": "queue", "target": h.id, "def": String(R["builder"]), "n": 1})
	var hubs: Array = []
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if b.built and w.bdef(b).is_refinery:
			hubs.append(b)
	var want_h: int = hubs.size() * cfg["harv_per_hub"]
	var queued := 0
	for hb: SimEntity in hubs:
		queued += hb.queue.size()
	if harvesters.size() + queued < want_h and not hubs.is_empty() and p.supply >= Content.unit(R["harvester"]).cost:
		# queue at the hub with the fewest harvesters nearby
		cmd({"t": "queue", "target": hubs[(w.tick / 40) % hubs.size()].id, "def": String(R["harvester"]), "n": 1})
	# idle / parked harvesters go back to work; harvesters under attack flee to the nearest hub
	for hv: SimEntity in harvesters:
		if hv.is_idle():
			var res := EconSys.nearest_resource(w, hv.pos)
			if res != null:
				cmd({"t": "harvest", "ids": [hv.id], "target": res.id})
	# spread harvesters: assign some to the expansion resource if a hub is next to it
	var er := w.get_ent(int(bb["expand_res"]))
	if er != null and er.amount > 0:
		for hb2: SimEntity in hubs:
			if FX.dist(hb2.pos, er.pos) < FX.ONE * 9:
				var n_there := 0
				for hv2: SimEntity in harvesters:
					if hv2.res_id == er.id:
						n_there += 1
				if n_there < cfg["harv_per_hub"]:
					for hv3: SimEntity in harvesters:
						if hv3.res_id != er.id and hv3.phase != 1:
							cmd({"t": "harvest", "ids": [hv3.id], "target": er.id})
							break
				break

# ------------------------------------------------------------------ build planner
func _next_building() -> StringName:
	var counts := {}
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		counts[b.def_id] = counts.get(b.def_id, 0) + 1
	var desired := {}
	for item in persona.opening:
		var id := StringName(item)
		desired[id] = desired.get(id, 0) + 1
		if counts.get(id, 0) < desired[id]:
			if id == R["refinery"] and desired[id] >= 2 and seconds() < cfg["expand_s"]:
				continue
			if id == R["bunker"] and desired[id] > cfg["bunkers"]:
				continue
			return id
	# dynamic: power headroom
	var p := me()
	if p.power_prod - p.power_used < 3:
		return R["power"]
	if counts.get(R["bunker"], 0) < cfg["bunkers"]:
		return R["bunker"]
	if seconds() > cfg["expand_s"] + 240 and counts.get(R["refinery"], 0) < (3 if difficulty == "hard" else 2):
		return R["refinery"]
	# mid-game base growth (ZH AI keeps adding production and defenses)
	if seconds() > 420 and counts.get(R["barracks"], 0) < 2 and p.supply > 1000:
		return R["barracks"]
	if seconds() > 540 and counts.get(R["heavy"], 0) < 2 and p.supply > 2000:
		return R["heavy"]
	if seconds() > 660 and difficulty != "easy" and counts.get(R["bunker"], 0) < int(cfg["bunkers"]) + 2 and p.supply > 1200:
		return R["bunker"]
	if seconds() > 780 and counts.get(R["motor"], 0) < 2 and p.supply > 1500:
		return R["motor"]
	# M2.4 tech and support structures (ZH China-style: tech centre, repair, income, AA, mines)
	if _has_role("tech") and seconds() > 480 and counts.get(R["heavy"], 0) >= 1 and counts.get(R["tech"], 0) < 1 and p.supply > 1700:
		return R["tech"]
	if _has_role("support") and counts.get(R["tech"], 0) >= 1 and counts.get(R["support"], 0) < 1 and p.supply > 800:
		return R["support"]
	if seconds() > 600 and difficulty != "easy" and _has_role("aa_tower") and counts.get(R["aa_tower"], 0) < 1 and p.supply > 1200:
		return R["aa_tower"]
	if _has_role("income") and counts.get(R["tech"], 0) >= 1 and counts.get(R["income"], 0) < 1 and p.supply > 2600:
		return R["income"]
	if seconds() > 540 and difficulty != "easy" and _has_role("mine") and counts.get(R["mine"], 0) < (4 if difficulty == "hard" else 2) and p.supply > 600:
		return R["mine"]
	# M3.0 E: Germany gets a working Airfield (Tiger, multirole fighter) once the tech centre is up
	if faction() == &"eu" and seconds() > (840 if difficulty == "hard" else 1020) and difficulty != "easy" \
			and counts.get(R["tech"], 0) >= 1 and counts.get(&"eu_airstrip", 0) < 1 and p.supply > 2400:
		return &"eu_airstrip"
	# M3.2: Russia's Airfield (Su-57, Ka-52, Tu-160) once the Ministry of Defense is up
	if faction() == &"ecc" and seconds() > (780 if difficulty == "hard" else 960) and difficulty != "easy" \
			and counts.get(R["tech"], 0) >= 1 and counts.get(&"ecc_airfield", 0) < 1 and p.supply > 2400:
		return &"ecc_airfield"
	return &""

## Dynamic build pick for a role; "" when the faction lacks that structure.
func _has_role(k: String) -> bool:
	return R.get(k, &"") != &""

## Units allowed to take build orders (EU: every Crawler; TPLA: the reserved Laborers).
func _builders() -> Array:
	var out: Array = []
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		if w.udef(u).tags.has("builder"):
			out.append(u)
	return out

func _build() -> void:
	var p := me()
	var crawlers: Array = _builders()
	if crawlers.is_empty():
		return
	# unfinished sites without a builder: resume
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if not b.built:
			var someone := false
			for c: SimEntity in crawlers:
				if not c.orders.is_empty() and c.orders[0].get("o", "") == "build" and int(c.orders[0]["target"]) == b.id:
					someone = true
			if not someone:
				for c2: SimEntity in crawlers:
					if c2.is_idle():
						cmd({"t": "resume_build", "ids": [c2.id], "target": b.id})
						return
	var free: SimEntity = null
	for c3: SimEntity in crawlers:
		if c3.is_idle():
			free = c3
			break
	if free == null:
		return
	# M3.1: an idle builder repairs a badly damaged structure when there is money to spare
	if p.supply > 800:
		for b2: SimEntity in my_ents(SimEntity.Kind.BUILDING):
			if b2.built and b2.hp * 5 < b2.max_hp * 2:
				cmd({"t": "repair", "ids": [free.id], "target": b2.id})
				return
	var next := _next_building()
	if next == &"":
		return
	var d: BuildingDef = Content.building(next)
	if p.supply < d.cost:
		return
	if w.prereqs_met(pid, d.prereqs) != "":
		return
	var toward := _toward_for(next)
	var t := find_spot_step(next, toward)
	if t.x < 0:
		return
	cmd({"t": "place", "ids": [free.id], "def": String(next), "tile": t, "rot": _rot_toward(t, map_center())})

func _rot_toward(t: Vector2i, p: Vector2i) -> int:
	var c := FX.tile_center(t)
	var dx := p.x - c.x
	var dy := p.y - c.y
	if absi(dx) > absi(dy):
		return 1 if dx > 0 else 3
	return 0 if dy > 0 else 2

func _toward_for(id: StringName) -> Vector2i:
	var base := base_pos()
	if id == R["refinery"]:
			var n := w.count_owned(pid, id)
			if n == 0:
				var res := EconSys.nearest_resource(w, base, 30)
				return res.pos if res != null else base
			var er := _pick_expansion()
			return er.pos if er != null else base
	if id == R["power"]:
			return base + (base - map_center()) / 8
	if id == R["bunker"]:
			# ZH AI fortifies its expansions: every other bunker after the first two goes to the
			# newest remote Supply Hub, facing the map centre.
			var nb := w.count_owned(pid, id)
			if nb >= 2 and nb % 2 == 0:
				var far: SimEntity = null
				for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
					if w.bdef(b).is_refinery and FX.dist(b.pos, base) > FX.ONE * 20 and (far == null or b.id > far.id):
						far = b
				if far != null:
					return far.pos + (map_center() - far.pos) / 10
			return base + (map_center() - base) * 3 / 10
	if id == R["aa_tower"] or id == R["mine"]:
			# forward, on the road toward the map centre (mines spread a little by count)
			var nm := w.count_owned(pid, id)
			return base + (map_center() - base) * (28 + 6 * (nm % 3)) / 100
	if id == R["pylon"]:
			# pylons only extend the Grid shield now; keep them among the base buildings
			return base + (map_center() - base) / 5
	return base + (map_center() - base) / 6

func _pick_expansion() -> SimEntity:
	var cur := w.get_ent(int(bb["expand_res"]))
	if cur != null and cur.amount > 1000:
		return cur
	var base := base_pos()
	var best: SimEntity = null
	var bd := 1 << 50
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.kind != SimEntity.Kind.RESOURCE or e.amount < 2000:
			continue
		# skip resources already covered by one of my hubs, and ones next to known enemy structures
		var covered := false
		for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
			if w.bdef(b).is_refinery and FX.dist(b.pos, e.pos) < FX.ONE * 9:
				covered = true
		if covered:
			continue
		var hostile := false
		for mid in w.fog.memory.get(me().team, {}):
			var m: Dictionary = w.fog.memory[me().team][mid]
			if int(m["owner"]) >= 0 and FX.dist(FX.tile_center(m["tile"]), e.pos) < FX.ONE * 14:
				hostile = true
		if hostile:
			continue
		var d := FX.dist2(e.pos, base)
		if d < bd:
			bd = d
			best = e
	if best != null:
		bb["expand_res"] = best.id
	return best

## Best valid placement tile for building `id`, preferring spots close to `toward`.
## Zero Hour rules: there is no build radius, so the search ring is centred on the goal
## itself (a supply field, an oil derrick, a forward choke) and the base is only a fallback.
const SPOT_PENDING := Vector2i(-2, -2)
const SPOT_R := 12
const SPOT_BUDGET := 40          ## can_place() calls per think (M1.2 spikes: ~600 in one tick)
const SPOT_MAX_TRIES := 300
static var _spot_offs: Array = []

## Search offsets sorted by distance (computed once; the old per-call sort of 625 entries
## with a lambda was half of the M1.2 ~90 ms hitch).
static func _offsets() -> Array:
	if _spot_offs.is_empty():
		for yy in range(-SPOT_R, SPOT_R + 1):
			for xx in range(-SPOT_R, SPOT_R + 1):
				_spot_offs.append(Vector2i(xx, yy))
		_spot_offs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := a.x * a.x + a.y * a.y
			var db := b.x * b.x + b.y * b.y
			return da < db if da != db else (a.y * 1000 + a.x) < (b.y * 1000 + b.x))
	return _spot_offs

func _margin_for(id: StringName) -> int:
	return 0 if id == R["pylon"] else 1

## Incremental placement search spread over several thinks: returns a tile, SPOT_PENDING
## while still searching (state in bb["fs"]), or (-1,-1) when nothing fits.
func find_spot_step(id: StringName, toward: Vector2i) -> Vector2i:
	var st: Dictionary = bb.get("fs", {})
	if st.is_empty() or StringName(st["id"]) != id or st["toward"] != toward:
		st = {"id": String(id), "toward": toward, "c": 0, "i": 0, "tries": 0}
	var d: BuildingDef = Content.building(id)
	var offs := _offsets()
	var m := _margin_for(id)
	var calls := 0
	var checks := 0
	while int(st["c"]) < 2:
		var centre: Vector2i = toward if int(st["c"]) == 0 else base_pos()
		var c := FX.to_tile(centre)
		while int(st["i"]) < offs.size() and int(st["tries"]) <= SPOT_MAX_TRIES:
			var o: Vector2i = offs[int(st["i"])]
			st["i"] = int(st["i"]) + 1
			var t2 := Vector2i(c.x + o.x - d.footprint.x / 2, c.y + o.y - d.footprint.y / 2)
			checks += 1
			if not _margin_free(t2, d.footprint, m):
				if checks > 400:
					bb["fs"] = st
					return SPOT_PENDING
				continue
			st["tries"] = int(st["tries"]) + 1
			calls += 1
			if w.can_place(pid, id, t2) == "":
				bb.erase("fs")
				return t2
			if calls >= SPOT_BUDGET:
				bb["fs"] = st
				return SPOT_PENDING
		st["c"] = int(st["c"]) + 1
		st["i"] = 0
		st["tries"] = 0
	bb.erase("fs")
	return Vector2i(-1, -1)

## Synchronous search (tools/tests); the AI itself uses find_spot_step.
func find_spot(id: StringName, toward: Vector2i) -> Vector2i:
	bb.erase("fs")
	var t := find_spot_step(id, toward)
	while t == SPOT_PENDING:
		t = find_spot_step(id, toward)
	return t

func _margin_free(t: Vector2i, fp: Vector2i, m: int) -> bool:
	for yy in range(-m, fp.y + m):
		for xx in range(-m, fp.x + m):
			var c := Vector2i(t.x + xx, t.y + yy)
			if not w.map.in_bounds(c):
				return false
			var i := w.map.idx(c)
			if w.map.occ[i] != 0:
				return false
			if (xx < 0 or yy < 0 or xx >= fp.x or yy >= fp.y) and not SimMap.VEH_OK[w.map.tiles[i]] and SimMap.BUILD_OK[w.map.tiles[i]] == false and m > 0:
				pass
	return true

# ------------------------------------------------------------------ production
func _production() -> void:
	var p := me()
	var reserve := 0
	var nb := _next_building()
	if nb != &"":
		reserve = Content.building(nb).cost
	var staging := _staging()
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if not b.built:
			continue
		var bd: BuildingDef = w.bdef(b)
		if bd.is_hq or bd.is_refinery or bd.produces.is_empty():
			continue
		if b.rally != staging:
			cmd({"t": "rally", "ids": [b.id], "pos": staging, "flag": false})
		if b.queue.size() > cfg["prod_gap"]:
			continue
		_cur_b = b
		var pick := _pick_unit(bd)
		if pick == &"":
			continue
		var cost: int = Content.unit(pick).cost
		if p.supply - cost >= reserve or p.supply > 6000:
			if p.pop + Content.unit(pick).pop <= p.pop_cap:
				cmd({"t": "queue", "target": b.id, "def": String(pick), "n": 1})

var _cur_b: SimEntity = null   ## producer being filled by _production (for _unit_allowed)

## Faction hook: may this unit be queued at _cur_b right now (e.g. US airfield slots)?
func _unit_allowed(ud: UnitDef) -> bool:
	if (faction() == &"eu" or faction() == &"ecc") and ud.air_slots > 0:   # German / Russian Airfield parking slots
		return _air_slot_ok(ud)
	return true

func _pick_unit(bd: BuildingDef) -> StringName:
	# counter-aware weights: more anti-tank if we see enemy armor, more grenadiers vs infantry
	var enemy_armor := 0
	var enemy_inf := 0
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and w.enemies(me().team, e.team) and w.fog.is_visible_ent(w, me().team, e):
			var d: UnitDef = w.udef(e)
			if d.armor_type == &"infantry":
				enemy_inf += 1
			elif d.tags.has("vehicle") and not d.tags.has("harvester"):
				enemy_armor += 1
	var total := 0
	var weights := {}
	var have_aegis := 0
	for u: SimEntity in combat_units():
		if u.def_id == &"eu_aegis":
			have_aegis += 1
	for uid in bd.produces:
		var wgt: int = int(persona.unit_weights.get(uid, 1)) * 10
		var ud: UnitDef = Content.unit(uid)
		if ud.tags.has("at") and enemy_armor > enemy_inf:
			wgt *= 2
		if uid == "eu_grenadier" and enemy_inf > enemy_armor:
			wgt *= 2
		if uid == "eu_aegis" and have_aegis >= 1 + combat_units().size() / 10:
			wgt = 0
		if ud.tags.has("aa") and _enemy_air_seen() > 0:
			wgt *= 4   # M2.5: enemy aircraft spotted - build anti-air
		elif uid == "eu_flakwerk" and enemy_inf < 4:
			wgt /= 3
		# M2.4: support units (detector / jammer / artillery) in small numbers; [STUB] never
		if ud.tags.has("stub") or ud.tags.has("builder") or ud.tags.has("harvester") or not _unit_allowed(ud):
			wgt = 0
		elif (ud.tags.has("detector") or ud.tags.has("jammer")) and _count_type(StringName(uid)) >= 1 + combat_units().size() / 12:
			wgt = 0
		elif ud.tags.has("artillery") and _count_type(StringName(uid)) >= 2 + combat_units().size() / 8:
			wgt = 0
		if w.prereqs_met(pid, ud.prereqs) != "":
			wgt = 0
		weights[uid] = wgt
		total += wgt
	if total <= 0:
		return &""
	var roll := w.tick * 7919 % total   # deterministic, sim-seeded by tick
	for uid in bd.produces:
		roll -= weights[uid]
		if roll < 0:
			return StringName(uid)
	return StringName(bd.produces[0])

## Enemy aircraft currently visible, or seen in the last 3 minutes (M2.5 air layer).
func _enemy_air_seen() -> int:
	if _every("t_air_scan", 40):
		var n := 0
		for id in w.ids:
			var e: SimEntity = w.ents[id]
			if e.alive and e.kind == SimEntity.Kind.UNIT and w.enemies(me().team, e.team) and w.is_air(e) and w.fog.is_visible_ent(w, me().team, e):
				n += 1
		if n > 0:
			bb["air_seen_tick"] = w.tick
		bb["air_seen"] = n if n > 0 else (1 if w.tick - int(bb.get("air_seen_tick", -100000)) < 3600 else 0)
	return int(bb.get("air_seen", 0))

func _count_type(def_id: StringName) -> int:
	var n := 0
	for u: SimEntity in combat_units():
		if u.def_id == def_id:
			n += 1
	return n

func _staging() -> Vector2i:
	if bb["staging"].x < 0 or _every("t_staging", 600):
		var base := base_pos()
		var st := base + (map_center() - base) * 22 / 100
		bb["staging"] = FX.tile_center(w.map.nearest_passable(FX.to_tile(st), true))
	return bb["staging"]

# ------------------------------------------------------------------ army
func _alive_ids(arr: Array) -> Array:
	var out: Array = []
	for id in arr:
		var e := w.get_ent(int(id))
		if e != null and e.owner == pid:
			out.append(e.id)
	return out

func _army() -> void:
	bb["wave"] = _alive_ids(bb["wave"])
	bb["retreated"] = _alive_ids(bb["retreated"])
	var units := combat_units()
	var in_wave := {}
	for id in bb["wave"]:
		in_wave[id] = true
	var home: Array = []
	var reserved := _reserved_ids()
	for u: SimEntity in units:
		if not in_wave.has(u.id) and u.id != int(bb["scout"]) and u.id != int(bb["capture_unit"]) and not reserved.has(u.id):
			home.append(u)
	# 1. defend the base
	var threatened: bool = w.tick - int(bb["threat_tick"]) < 100
	if threatened:
		# Proportional defence: send the nearest idle home units worth ~2x the visible threat
		# (min 1500). The rest stay available for waves/reinforcement - an all-hands
		# response to every raid on an outlying structure used to freeze the army for good.
		var threat_val: int = _enemy_strength_near(bb["threat_pos"], 12)
		var budget: int = maxi(1500, threat_val * 2)
		var cands: Array = []
		for u: SimEntity in home:
			if u.is_idle() or (not u.orders.is_empty() and u.orders[0].get("o", "") == "move"):
				cands.append(u)
		var tp: Vector2i = bb["threat_pos"]
		cands.sort_custom(func(a: SimEntity, b: SimEntity) -> bool: return FX.dist2(a.pos, tp) < FX.dist2(b.pos, tp) or (FX.dist2(a.pos, tp) == FX.dist2(b.pos, tp) and a.id < b.id))
		var ids: Array = []
		var sent := 0
		for u: SimEntity in cands:
			if sent >= budget:
				break
			ids.append(u.id)
			sent += w.udef(u).cost
		if not ids.is_empty():
			cmd({"t": "amove", "ids": ids, "pos": tp})
		# recall the wave if the base is under heavy attack and the wave is far away
		if not bb["wave"].is_empty() and threat_val > army_value(home) + 1500:
			var wave_units: Array = []
			for id in bb["wave"]:
				wave_units.append(w.get_ent(id))
			if not wave_units.is_empty() and FX.dist(_centroid(wave_units), base_pos()) > FX.ONE * 40:
				cmd({"t": "amove", "ids": bb["wave"].duplicate(), "pos": tp})
				bb["wave"] = []
		if threat_val * 3 + 2000 > army_value(home):
			return
		# Small raid and a big home army: keep running the wave logic with the units not
		# committed to defence.
		var keep: Array = []
		for u: SimEntity in home:
			if not (u.id in ids) and FX.dist(u.pos, tp) > FX.ONE * 10:
				keep.append(u)
		home = keep
	# 2. retreat badly damaged wave units (medium/hard)
	if cfg["retreat"] and not bb["wave"].is_empty():
		var back: Array = []
		for id in bb["wave"]:
			var e := w.get_ent(id)
			if e != null and e.hp * 100 < e.max_hp * 30 and e.def_id != &"eu_aegis":
				back.append(e.id)
		if not back.is_empty():
			_send_back(back)
			for id in back:
				bb["wave"].erase(id)
				bb["retreated"].append(id)
		# whole-wave retreat if it lost most of its value against a stronger visible force
		var cur := 0
		var wu: Array = []
		for id in bb["wave"]:
			var e2 := w.get_ent(id)
			cur += w.udef(e2).cost
			wu.append(e2)
		if not wu.is_empty() and cur * 100 < int(bb["wave_start_value"]) * 35:
			var c := _centroid(wu)
			if _enemy_strength_near(c, 10) > cur * 2:
				cmd({"t": "move", "ids": bb["wave"].duplicate(), "pos": _staging()})
				bb["wave"] = []
	# 3. launch waves
	var staged: Array = []
	for u: SimEntity in home:
		if u.id in bb["retreated"]:
			if u.hp * 100 < u.max_hp * 90:
				# send it home to the field-repair zone; it rejoins once repaired
				if u.is_idle() and FX.dist(u.pos, base_pos()) > FX.ONE * 8:
					cmd({"t": "move", "ids": [u.id], "pos": base_pos()})
				continue
			bb["retreated"].erase(u.id)
		staged.append(u)
	var need := _wave_threshold()
	# ZH-style pressure: at (near) the unit cap there is nothing to wait for - attack with
	# what we have instead of idling at staging (prevents late-game stalemates).
	var pl := me()
	if pl.pop >= pl.pop_cap - 6:
		need = mini(need, maxi(3000, army_value(staged)))
	# Late-game pressure (ZH games end; turtling to a 40-minute draw is not ZH pacing):
	# from 16 min the wave threshold ramps down so armies keep colliding and bases fall.
	if seconds() > 960:
		need = mini(need, maxi(2500, 6000 - (seconds() - 960) * 5))
	var t_ok := seconds() >= int(cfg["first_wave_s"]) or (difficulty != "easy" and army_value(staged) >= need * 2)
	if bb["wave"].is_empty() and t_ok and army_value(staged) >= need:
		var target := _pick_target()
		if target.x >= 0:
			var ids2: Array = []
			for u: SimEntity in staged:
				ids2.append(u.id)
			# keep a small home guard on harder difficulties after the first wave
			bb["wave"] = ids2
			bb["wave_start_value"] = army_value(staged)
			bb["wave_n"] = int(bb["wave_n"]) + 1
			bb["last_wave_tick"] = w.tick
			cmd({"t": "amove", "ids": ids2, "pos": target})
			for id in ids2:
				bb["retreated"].erase(id)
			return
	# 4. keep the wave moving: when most of it is idle, push to the next target; reinforce from staging
	if not bb["wave"].is_empty() and _every("t_watchdog", 1200):
		# stuck-wave watchdog: if the wave's centroid hardly moved in a minute and it isn't
		# fighting, re-target it at the nearest remembered enemy structure (or dissolve it).
		var wl: Array = []
		var fighting := false
		for id in bb["wave"]:
			var we := w.get_ent(id)
			wl.append(we)
			if w.tick - we.firing_tick < 200:
				fighting = true
		var cen := _centroid(wl)
		var last: Vector2i = bb.get("wave_last_pos", Vector2i(-1, -1))
		bb["wave_last_pos"] = cen
		if not fighting and last.x >= 0 and FX.dist(cen, last) < FX.ONE * 4:
			r.team_board.erase(me().team)
			var t3 := _pick_target()
			if t3.x >= 0 and FX.dist(t3, cen) > FX.ONE * 6:
				cmd({"t": "amove", "ids": bb["wave"].duplicate(), "pos": t3})
			elif seconds() > 600 and not _knows_enemy_structure():
				# nothing known left to hit: sweep the map (spawns, centre, quadrants) so a
				# hidden last structure cannot stall the game into a draw
				var hp := _hunt_points()
				var hi := int(bb.get("hunt_i", 0))
				bb["hunt_i"] = hi + 1
				cmd({"t": "amove", "ids": bb["wave"].duplicate(), "pos": hp[hi % hp.size()]})
			else:
				cmd({"t": "move", "ids": bb["wave"].duplicate(), "pos": _staging()})
				bb["wave"] = []
	if not bb["wave"].is_empty() and not bb.get("hold_wave", false):
		var idle := 0
		var idle_ids: Array = []
		for id in bb["wave"]:
			if w.get_ent(id).is_idle():
				idle += 1
				idle_ids.append(id)
		var push_all: bool = idle * 2 >= bb["wave"].size()
		if push_all or (not idle_ids.is_empty() and _every("t_idle_push", 200)):
			# idle part of a strung-out wave (reinforcements still walking up) must not just
			# stand there: it pushes on alone, otherwise a won game can stall into a draw
			var t2 := _pick_target()
			if seconds() > 600 and not _knows_enemy_structure():
				var hp2 := _hunt_points()
				var hi2 := int(bb.get("hunt_i", 0))
				bb["hunt_i"] = hi2 + 1
				t2 = hp2[hi2 % hp2.size()]
			if t2.x >= 0:
				cmd({"t": "amove", "ids": bb["wave"].duplicate() if push_all else idle_ids, "pos": t2})
		if _every("t_reinforce", 200) and army_value(staged) >= (1200 if seconds() > 960 else 2500):
			var rein: Array = []
			for u: SimEntity in staged:
				rein.append(u.id)
				bb["wave"].append(u.id)
			var wu2: Array = []
			for id in bb["wave"]:
				wu2.append(w.get_ent(id))
			cmd({"t": "amove", "ids": rein, "pos": _centroid(wu2)})
	# idle home units gather at staging
	var gather: Array = []
	for u: SimEntity in staged:
		if u.is_idle() and FX.dist(u.pos, _staging()) > FX.ONE * 6:
			gather.append(u.id)
	if not gather.is_empty():
		cmd({"t": "move", "ids": gather, "pos": _staging()})

# ------------------------------------------------------------------ victim selection (M2.3)
## Zero Hour-style difficulty differences in how a fighting army picks victims (behaviour studied
## from ZH's AI attack states, reimplemented): Easy spreads fire over random visible enemies,
## Medium leaves each unit on its nearest enemy (default acquisition), Hard focus-fires the whole
## engaged group on one victim (the weakest armed enemy) until it dies. Same commands as a human.
func _victims() -> void:
	var mode: String = cfg.get("victim", "nearest")
	if mode == "nearest" or bb["wave"].is_empty():
		return
	if not _every("t_victim", 20 if mode == "focus" else 60):
		return
	var engaged: Array = []
	for id in bb["wave"]:
		var u := w.get_ent(id)
		if u != null and u.alive and u.target != 0 and not u.cds.is_empty() and w.tick - u.firing_tick < 100:
			engaged.append(u)
	if engaged.is_empty():
		return
	var cen := _centroid(engaged)
	var foes: Array = []
	for e: SimEntity in w.units_in_radius(cen, FX.ONE * 9):
		if OrderSys.valid_target(w, engaged[0], e):
			foes.append(e)
	if foes.is_empty():
		return
	var resume := _pick_target()
	if mode == "focus":
		var cur := w.get_ent(int(bb.get("victim", 0)))
		if cur == null or not foes.has(cur):
			cur = null
			var best := 1 << 50
			for e: SimEntity in foes:
				# weakest armed enemy first (unarmed ones only when nothing shoots back)
				var sc: int = e.hp + e.shield + (0 if not e.cds.is_empty() else 1 << 30) + FX.dist(e.pos, cen) / 8
				if sc < best:
					best = sc
					cur = e
		var ids: Array = []
		for u: SimEntity in engaged:
			if u.target != cur.id:
				ids.append(u.id)
		bb["victim"] = cur.id
		if not ids.is_empty():
			cmd({"t": "attack", "ids": ids, "target": cur.id})
			if resume.x >= 0:
				cmd({"t": "amove", "ids": ids, "pos": resume, "q": true})
	else:
		# easy: a few engaged units switch to a pseudo-random visible enemy (deterministic hash,
		# never the sim RNG, so replays stay identical)
		var n := 0
		for u: SimEntity in engaged:
			if n >= 6:
				break
			var h := FX.fnv_int(FX.fnv_int(2166136261, w.tick), u.id)
			var e: SimEntity = foes[absi(h) % foes.size()]
			if e.id != u.target:
				cmd({"t": "attack", "ids": [u.id], "target": e.id})
				if resume.x >= 0:
					cmd({"t": "amove", "ids": [u.id], "pos": resume, "q": true})
				n += 1

## True at most once per `period` ticks. AIs think on staggered ticks (tick + pid), so
## "w.tick % N == 0" checks never fired for most players - this replaces them.
## Units the wave logic must not touch (raid squads, salvage runs, tunnel guards...).
func _reserved_ids() -> Dictionary:
	var out := {}
	if faction() == &"eu" or faction() == &"ecc":   # jets fly their own sorties (see _air)
		for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
			if w.udef(u).tags.has("jet"):
				out[u.id] = true
	return out

## Where badly damaged wave units go (EU: staging, then the base repair zone).
func _send_back(ids: Array) -> void:
	cmd({"t": "move", "ids": ids, "pos": _staging()})

func _is_scout_type(u: SimEntity) -> bool:
	return u.def_id == &"eu_grenadier" or u.def_id == &"eu_wolfhound"

func _every(key: String, period: int) -> bool:
	if w.tick - int(bb.get(key, -1000000)) >= period:
		bb[key] = w.tick
		return true
	return false

func _wave_threshold() -> int:
	var base: int = persona.first_wave_value * int(cfg["wave_mult"]) / 100
	var n: int = int(bb["wave_n"])
	var v := base
	for i in n:
		v = v * (100 + persona.wave_growth_pct) / 100
	return mini(v, 16000)

func _centroid(units: Array) -> Vector2i:
	var s := Vector2i.ZERO
	var n := 0
	for u: SimEntity in units:
		if u != null:
			s += u.pos
			n += 1
	return s / maxi(1, n)

func _enemy_strength_near(p: Vector2i, tiles: int) -> int:
	var v := 0
	for e: SimEntity in w.units_in_radius(p, tiles * FX.ONE):
		if w.enemies(me().team, e.team) and w.fog.is_visible_ent(w, me().team, e):
			v += w.udef(e).cost
	return v

## Chooses the enemy player (shared with allied AIs through team_board) and a target point:
## nearest remembered enemy structure (production / economy first), else their start position.
func _pick_target() -> Vector2i:
	var my_team := me().team
	var board: Dictionary = r.team_board.get(my_team, {})
	var tp := int(board.get("target_player", -1))
	if tp < 0 or w.players[tp].eliminated or w.tick - int(board.get("tick", 0)) > 20 * 240:
		# Pick the enemy with the best mix of proximity and weakness (army + base size).
		# Allies share this choice through the team board, so they converge on one enemy.
		tp = -1
		var bd := 1 << 50
		for p in w.players:
			if p.eliminated or not w.enemies(my_team, p.team):
				continue
			var sp := _spawn_of(p.id)
			var d := FX.dist(sp, base_pos()) / FX.ONE
			var strength := 0
			for id in w.ids:
				var e: SimEntity = w.ents[id]
				if e.owner == p.id and e.alive:
					if e.kind == SimEntity.Kind.UNIT and e.res_id >= 0:
						strength += w.udef(e).cost
					elif e.kind == SimEntity.Kind.BUILDING:
						strength += 400
			var score := d * 60 + strength
			if score < bd:
				bd = score
				tp = p.id
		r.team_board[my_team] = {"target_player": tp, "tick": w.tick}
	if tp < 0:
		return Vector2i(-1, -1)
	var mem: Dictionary = w.fog.memory.get(my_team, {})
	var best := Vector2i(-1, -1)
	var best_s := 1 << 60
	var from := base_pos()
	if not bb["wave"].is_empty():
		var wu: Array = []
		for id in bb["wave"]:
			wu.append(w.get_ent(id))
		from = _centroid(wu)
	for id in mem:
		var m: Dictionary = mem[id]
		if int(m["owner"]) != tp:
			continue
		var bd2: BuildingDef = Content.building(m["def"])
		var c := Vector2i(m["tile"].x * FX.ONE + bd2.footprint.x * FX.HALF, m["tile"].y * FX.ONE + bd2.footprint.y * FX.HALF)
		var s := FX.dist2(c, from)
		if bd2.produces.is_empty() and not bd2.is_refinery:
			s = s * 2
		if s < best_s:
			best_s = s
			best = c
	if best.x < 0:
		best = _spawn_of(tp)
	return best

func _knows_enemy_structure() -> bool:
	var my_team := me().team
	var mem: Dictionary = w.fog.memory.get(my_team, {})
	for id in mem:
		var m: Dictionary = mem[id]
		var o := int(m["owner"])
		if o >= 0 and w.enemies(my_team, w.players[o].team) and not w.players[o].eliminated:
			return true
	return false

func _hunt_points() -> Array:
	# M2.6: the sweep used to visit only spawns + 9 coarse points, so a lone expansion Supply
	# Hub or barracks off that path could survive to the 40:00 cap. Order now: enemy spawns,
	# then every resource site (where expansions are built), then a ~20-tile grid; each group
	# sorted by distance from the target enemy's spawn so the likely hideouts are checked first.
	var out: Array = []
	var map_def: MapDef = Content.maps[w.map_id]
	var anchor := base_pos()
	for p in w.players:
		if not p.eliminated and w.enemies(me().team, p.team):
			anchor = _spawn_of(p.id)
			break
	for sp in map_def.spawns:
		out.append(FX.tile_center(sp + Vector2i(2, 2)))
	var res_pts: Array = []
	for rd: Dictionary in map_def.resources:
		res_pts.append(FX.tile_center(rd["tile"]))
	res_pts.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return FX.dist2(a, anchor) < FX.dist2(b, anchor))
	out.append_array(res_pts)
	var W := w.map.w
	var H := w.map.h
	var grid: Array = []
	var step := 20
	var y := step / 2
	while y < H:
		var x := step / 2
		while x < W:
			grid.append(FX.tile_center(w.map.nearest_passable(Vector2i(x, y), false)))
			x += step
		y += step
	grid.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return FX.dist2(a, anchor) < FX.dist2(b, anchor))
	out.append_array(grid)
	return out

func _spawn_of(p_id: int) -> Vector2i:
	var map_def: MapDef = Content.maps[w.map_id]
	var sp: int = int(r.setup_cfg["slots"][p_id].get("spawn", p_id))
	var t: Vector2i = map_def.spawns[sp]
	return FX.tile_center(t + Vector2i(2, 2))

# ------------------------------------------------------------------ scouting
func _scout() -> void:
	if seconds() < 50:
		return
	var s := w.get_ent(int(bb["scout"]))
	if s == null:
		if int(bb["scout_i"]) >= 0 and int(bb["scout_i"]) < 4:
			for u: SimEntity in combat_units():
				if _is_scout_type(u):
					if not (u.id in bb["wave"]):
						bb["scout"] = u.id
						s = u
						break
		if s == null:
			return
	if s.is_idle():
		var pts := _scout_points()
		var i := int(bb["scout_i"])
		if i >= pts.size():
			bb["scout"] = 0
			bb["scout_i"] = -1     # scouting done; the unit rejoins the army
			return
		cmd({"t": "move", "ids": [s.id], "pos": pts[i]})
		bb["scout_i"] = i + 1

func _scout_points() -> Array:
	var pts: Array = []
	for p in w.players:
		if w.enemies(me().team, p.team):
			var sp := _spawn_of(p.id)
			pts.append(sp + (base_pos() - sp) / 4)   # stop short of the base
	pts.append(map_center())
	return pts

# ------------------------------------------------------------------ neutral capture
func _capture() -> void:
	if seconds() < 120:
		return
	var cu := w.get_ent(int(bb["capture_unit"]))
	if cu != null and not cu.is_idle():
		return
	var best: SimEntity = null
	var bd := 1 << 50
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.NEUTRAL and w.bdef(e).capturable and e.owner != pid:
			if e.owner >= 0 and not w.enemies(me().team, e.team):
				continue   # ally owns it
			var d := FX.dist2(e.pos, base_pos())
			if d < bd and d < (FX.ONE * 60) * (FX.ONE * 60):
				bd = d
				best = e
	if best == null:
		bb["capture_unit"] = 0
		return
	if cu == null:
		for u: SimEntity in combat_units():
			if w.udef(u).tags.has("infantry") and not (u.id in bb["wave"]):
				cu = u
				break
	if cu == null:
		return
	bb["capture_unit"] = cu.id
	cmd({"t": "capture", "ids": [cu.id], "target": best.id})

# ------------------------------------------------------------------ general powers
func _powers() -> void:
	var p := me()
	for id in Content.power_order:
		if p.points > 0 and PowersSys.can_buy(w, pid, id) == "":
			cmd({"t": "buy_power", "def": String(id)})
			return
	if PowersSys.ready_in(w, pid, &"eu_emergency_logistics") == 0:
		cmd({"t": "power", "def": "eu_emergency_logistics", "pos": base_pos()})
	if PowersSys.ready_in(w, pid, &"eu_shield_overcharge") == 0 and not bb["wave"].is_empty():
		var engaged: Array = []
		for id in bb["wave"]:
			var e := w.get_ent(id)
			if e != null and e.target != 0:
				engaged.append(e)
		if engaged.size() >= 4:
			cmd({"t": "power", "def": "eu_shield_overcharge", "pos": _centroid(engaged)})
	if PowersSys.ready_in(w, pid, &"eu_blackout") == 0 and not bb["wave"].is_empty():   # M3.0 E: Artillery Barrage
		var tb := _pick_target()
		if tb.x >= 0:
			cmd({"t": "power", "def": "eu_blackout", "pos": tb})
	if PowersSys.ready_in(w, pid, &"eu_recon_sweep") == 0 and not bb["wave"].is_empty():
		var tgt := _pick_target()
		if tgt.x >= 0:
			cmd({"t": "power", "def": "eu_recon_sweep", "pos": tgt})

# ------------------------------------------------------------------ air layer (M2.9: shared by the US and TPLA AIs)
func _air() -> void:
	var wave_units: Array = []
	for id in bb["wave"]:
		var e := w.get_ent(int(id))
		if e != null:
			wave_units.append(e)
	var wave_c := _centroid(wave_units) if not wave_units.is_empty() else Vector2i(-1, -1)
	var threat: bool = w.tick - int(bb["threat_tick"]) < 200
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		var d: UnitDef = w.udef(u)
		if not d.tags.has("jet") or not u.orders.is_empty() or u.target != 0:
			continue
		if u.air_state == AirSys.RETURNING or u.air_state == AirSys.LANDING or (u.air_state == AirSys.PARKED and u.air_t > 0) or not AirSys.has_ammo(u, d):
			continue
		if d.tags.has("fighter"):
			var air := _enemy_air_near([base_pos(), wave_c], 28)
			if air != null:
				cmd({"t": "attack", "ids": [u.id], "target": air.id})
				continue
			var gt := _engaged_enemy(wave_units)
			if gt == null and threat:
				gt = _visible_enemy_near(bb["threat_pos"], 10)
			if gt != null:
				cmd({"t": "attack", "ids": [u.id], "target": gt.id})
		else:
			# bomber: the threat at home first, then the wave's objective once the wave is out
			if threat and _enemy_strength_near(bb["threat_pos"], 10) >= 1500:
				cmd({"t": "amove", "ids": [u.id], "pos": bb["threat_pos"]})
			elif wave_c.x >= 0 and int(bb["wave_n"]) >= 1:
				var tgt := _pick_target()
				if tgt.x >= 0 and FX.dist(tgt, wave_c) < FX.ONE * 30:
					cmd({"t": "amove", "ids": [u.id], "pos": tgt})

func _enemy_air_near(points: Array, tiles: int) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 60
	for p: Vector2i in points:
		if p.x < 0:
			continue
		for e: SimEntity in w.units_in_radius(p, tiles * FX.ONE):
			if w.enemies(me().team, e.team) and w.flying(e) and e.res_id >= 0 and w.fog.is_visible_ent(w, me().team, e):
				var dd := FX.dist2(e.pos, p)
				if dd < bd:
					bd = dd
					best = e
	return best

func _visible_enemy_near(p: Vector2i, tiles: int) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 60
	for e: SimEntity in w.units_in_radius(p, tiles * FX.ONE):
		if w.enemies(me().team, e.team) and e.res_id >= 0 and not w.flying(e) and w.fog.is_visible_ent(w, me().team, e):
			var dd := FX.dist2(e.pos, p)
			if dd < bd:
				bd = dd
				best = e
	return best

func _engaged_enemy(wave_units: Array) -> SimEntity:
	for u: SimEntity in wave_units:
		if u.target != 0:
			var t := w.get_ent(u.target)
			if t != null and t.alive and t.kind == SimEntity.Kind.UNIT and not w.flying(t):
				return t
	return null

## Airfield slot check for jets at the producer being filled (_cur_b).
func _air_slot_ok(ud: UnitDef) -> bool:
	if _cur_b == null or w.bdef(_cur_b).air_slots <= 0:
		return false
	var queued := 0
	for q in _cur_b.queue:
		queued += Content.unit(q).air_slots
	return AirSys.slots_free(w, _cur_b) - queued >= ud.air_slots

