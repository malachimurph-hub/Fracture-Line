class_name AIPlayer
extends RefCounted
## Skirmish AI. Reads only its own entities plus its team's fog-limited view (fog memory of
## enemy structures, currently visible enemy units) and the map's start positions. Issues the
## same Commands as a human through MatchRunner.issue(). No resource or vision cheats.
## Layers: build planner (opening + dynamic), economy, production, army (defend / waves /
## retreat), scouting, pump capture, general powers. Allied AIs share a target via team_board.

const DIFF := {
	"easy":   {"think": 12, "harv_per_hub": 2, "first_wave_s": 420, "wave_mult": 70, "bunkers": 0, "retreat": false, "expand_s": 600, "powers": false, "scout": false, "crawlers": 1, "prod_gap": 3, "capture": false},
	"medium": {"think": 4, "harv_per_hub": 2, "first_wave_s": 300, "wave_mult": 100, "bunkers": 1, "retreat": true, "expand_s": 330, "powers": true, "scout": true, "crawlers": 1, "prod_gap": 1, "capture": true},
	"hard":   {"think": 2, "harv_per_hub": 3, "first_wave_s": 225, "wave_mult": 110, "bunkers": 2, "retreat": true, "expand_s": 240, "powers": true, "scout": true, "crawlers": 2, "prod_gap": 0, "capture": true},
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
	return {"pid": pid, "difficulty": difficulty, "persona": persona.id, "bb": bb.duplicate(true)}

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
	if cfg["scout"]:
		_scout()
	if cfg["capture"]:
		_capture()
	if cfg["powers"]:
		_powers()

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
	if h != null and crawlers.size() < want_crawlers and h.queue.is_empty() and p.supply >= Content.unit(&"eu_crawler").cost:
		cmd({"t": "queue", "target": h.id, "def": "eu_crawler", "n": 1})
	var hubs: Array = []
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if b.built and w.bdef(b).is_refinery:
			hubs.append(b)
	var want_h: int = hubs.size() * cfg["harv_per_hub"]
	var queued := 0
	for hb: SimEntity in hubs:
		queued += hb.queue.size()
	if harvesters.size() + queued < want_h and not hubs.is_empty() and p.supply >= Content.unit(&"eu_harvester").cost:
		# queue at the hub with the fewest harvesters nearby
		cmd({"t": "queue", "target": hubs[(w.tick / 40) % hubs.size()].id, "def": "eu_harvester", "n": 1})
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
			if id == &"eu_hub" and desired[id] >= 2 and seconds() < cfg["expand_s"]:
				continue
			if id == &"eu_gun_bunker" and desired[id] > cfg["bunkers"]:
				continue
			return id
	# dynamic: power headroom
	var p := me()
	if p.power_prod - p.power_used < 3:
		return &"eu_reactor"
	if counts.get(&"eu_gun_bunker", 0) < cfg["bunkers"]:
		return &"eu_gun_bunker"
	if seconds() > cfg["expand_s"] + 240 and counts.get(&"eu_hub", 0) < (3 if difficulty == "hard" else 2):
		return &"eu_hub"
	# mid-game base growth (ZH AI keeps adding production and defenses)
	if seconds() > 420 and counts.get(&"eu_barracks", 0) < 2 and p.supply > 1000:
		return &"eu_barracks"
	if seconds() > 540 and counts.get(&"eu_heavy_factory", 0) < 2 and p.supply > 2000:
		return &"eu_heavy_factory"
	if seconds() > 660 and difficulty != "easy" and counts.get(&"eu_gun_bunker", 0) < int(cfg["bunkers"]) + 2 and p.supply > 1200:
		return &"eu_gun_bunker"
	if seconds() > 780 and counts.get(&"eu_motor_pool", 0) < 2 and p.supply > 1500:
		return &"eu_motor_pool"
	return &""

func _build() -> void:
	var p := me()
	var crawlers: Array = []
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		if w.udef(u).tags.has("builder"):
			crawlers.append(u)
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
	var next := _next_building()
	if next == &"":
		return
	var d: BuildingDef = Content.building(next)
	if p.supply < d.cost:
		return
	if w.prereqs_met(pid, d.prereqs) != "":
		return
	var toward := _toward_for(next)
	var t := find_spot(next, toward)
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
	match id:
		&"eu_hub":
			var n := w.count_owned(pid, &"eu_hub")
			if n == 0:
				var res := EconSys.nearest_resource(w, base, 30)
				return res.pos if res != null else base
			var er := _pick_expansion()
			return er.pos if er != null else base
		&"eu_reactor":
			return base + (base - map_center()) / 8
		&"eu_gun_bunker":
			# ZH AI fortifies its expansions: every other bunker after the first two goes to the
			# newest remote Supply Hub, facing the map centre.
			var nb := w.count_owned(pid, &"eu_gun_bunker")
			if nb >= 2 and nb % 2 == 0:
				var far: SimEntity = null
				for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
					if w.bdef(b).is_refinery and FX.dist(b.pos, base) > FX.ONE * 20 and (far == null or b.id > far.id):
						far = b
				if far != null:
					return far.pos + (map_center() - far.pos) / 10
			return base + (map_center() - base) * 3 / 10
		&"eu_pylon":
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
func find_spot(id: StringName, toward: Vector2i) -> Vector2i:
	var d: BuildingDef = Content.building(id)
	for centre: Vector2i in [toward, base_pos()]:
		var c := FX.to_tile(centre)
		var cands: Array = []
		for yy in range(-12, 13):
			for xx in range(-12, 13):
				var t := Vector2i(c.x + xx - d.footprint.x / 2, c.y + yy - d.footprint.y / 2)
				var ctr := Vector2i(t.x * FX.ONE + d.footprint.x * FX.HALF, t.y * FX.ONE + d.footprint.y * FX.HALF)
				cands.append([FX.dist2(ctr, toward), t])
		cands.sort_custom(func(p, q): return p[0] < q[0] if p[0] != q[0] else (p[1].y * 1000 + p[1].x) < (q[1].y * 1000 + q[1].x))
		var tries := 0
		for cnd in cands:
			var t2: Vector2i = cnd[1]
			if not _margin_free(t2, d.footprint, 0 if id == &"eu_pylon" else 1):
				continue
			tries += 1
			if w.can_place(pid, id, t2) == "":
				return t2
			if tries > 300:
				break
	return Vector2i(-1, -1)

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
		var pick := _pick_unit(bd)
		if pick == &"":
			continue
		var cost: int = Content.unit(pick).cost
		if p.supply - cost >= reserve or p.supply > 6000:
			if p.pop + Content.unit(pick).pop <= p.pop_cap:
				cmd({"t": "queue", "target": b.id, "def": String(pick), "n": 1})

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
		if uid == "eu_flakwerk" and enemy_inf < 4:
			wgt /= 3
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
	for u: SimEntity in units:
		if not in_wave.has(u.id) and u.id != int(bb["scout"]) and u.id != int(bb["capture_unit"]):
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
			cmd({"t": "move", "ids": back, "pos": _staging()})
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
			else:
				cmd({"t": "move", "ids": bb["wave"].duplicate(), "pos": _staging()})
				bb["wave"] = []
	if not bb["wave"].is_empty():
		var idle := 0
		for id in bb["wave"]:
			if w.get_ent(id).is_idle():
				idle += 1
		if idle * 2 >= bb["wave"].size():
			var t2 := _pick_target()
			if t2.x >= 0:
				cmd({"t": "amove", "ids": bb["wave"].duplicate(), "pos": t2})
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

## True at most once per `period` ticks. AIs think on staggered ticks (tick + pid), so
## "w.tick % N == 0" checks never fired for most players - this replaces them.
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
				if u.def_id == &"eu_grenadier" or u.def_id == &"eu_wolfhound":
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
	if PowersSys.ready_in(w, pid, &"eu_recon_sweep") == 0 and not bb["wave"].is_empty():
		var tgt := _pick_target()
		if tgt.x >= 0:
			cmd({"t": "power", "def": "eu_recon_sweep", "pos": tgt})
