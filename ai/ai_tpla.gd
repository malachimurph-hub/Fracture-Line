class_name AITpla
extends AIPlayer
## TPLA skirmish AI (insurgent playstyle, after Zero Hour's GLA AI): a Laborer economy with a
## few reserved builders, Gas Turbine Plants for power (M3.3), tunnels used as forward bases (guards that pop out to
## ambush, damaged units heal inside), swarm raids by Rattlers / Shrikes against the enemy
## economy with hit-and-run retreats, salvage hunting by idle salvage vehicles, Demo Traps on
## the approach routes and at expansions, and TPLA general powers. Same command interface
## and fog rules as the EU AI.

const TDIFF := {
	"easy":   {"lps": 2, "builders": 1, "raid": 0, "traps": 1, "tunnels": 1, "salvage": false, "stashes": 2, "guards": 0, "nets": 0, "bazaars": 1},
	"medium": {"lps": 3, "builders": 2, "raid": 3, "traps": 2, "tunnels": 2, "salvage": true, "stashes": 3, "guards": 2, "nets": 1, "bazaars": 1},
	"hard":   {"lps": 3, "builders": 2, "raid": 4, "traps": 4, "tunnels": 3, "salvage": true, "stashes": 4, "guards": 3, "nets": 2, "bazaars": 2},
}
const MAX_PICKUPS := 12

var tc: Dictionary

func init(runner: MatchRunner, p_id: int, diff: String, personality: StringName) -> void:
	super.init(runner, p_id, diff, personality)
	tc = TDIFF[difficulty]
	bb["builders"] = []
	bb["raid"] = []
	bb["raid_cd"] = 0
	bb["raid_n"] = 0
	bb["salvagers"] = {}
	bb["guards"] = []

func faction() -> StringName:
	return &"tpla"

func think() -> void:
	if me().eliminated:
		return
	_update_threats()
	_economy()
	_build()
	_production()
	if int(tc["raid"]) > 0:
		_raids()
	if tc["salvage"]:
		_salvage()
	_tunnels()
	_army()
	_victims()
	_gather_wave()
	if cfg["scout"]:
		_scout()
	if cfg["capture"]:
		_capture()
		if _every("t_breach", 50):
			_breach()
	if cfg["powers"] and Content.GENERALS_ENABLED:   # M3.3: generals are off
		_powers()
	if _every("t_air", 40):
		_air()   # M2.9: jets fly sorties from the TPLA Airfield (shared AIPlayer air layer)

# ------------------------------------------------------------------ economy
## M2.9: Pickups gather, Backhoes build (separate jobs; the base _builders() returns the Backhoes).
func _gatherers() -> Array:
	var out: Array = []
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		if w.udef(u).tags.has("harvester"):
			out.append(u)
	return out

func _queued(producers: Array, id: StringName) -> int:
	var n := 0
	for b: SimEntity in producers:
		for q in b.queue:
			if StringName(q) == id:
				n += 1
	return n

func _economy() -> void:
	var p := me()
	var labs := _gatherers()
	var stashes: Array = []
	var dens: Array = []
	var pick_src: Array = []
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if not b.built:
			continue
		var bd: BuildingDef = w.bdef(b)
		if bd.is_refinery:
			stashes.append(b)
		if bd.produces.has("tpla_backhoe"):
			dens.append(b)
		if bd.produces.has("tpla_pickup"):
			pick_src.append(b)
	# builders: keep tc["builders"] Backhoes (1 in the opening)
	var want_b: int = int(tc["builders"]) if seconds() > 120 else 1
	var cost_b: int = Content.unit(&"tpla_backhoe").cost
	if _builders().size() + _queued(dens, &"tpla_backhoe") < want_b and p.supply >= cost_b and not dens.is_empty():
		cmd({"t": "queue", "target": dens[0].id, "def": "tpla_backhoe", "n": 1})
	# gatherers: "lps" Pickups per Supply Stash (each Stash also brings one free)
	var want: int = mini(MAX_PICKUPS, maxi(1, stashes.size()) * int(tc["lps"]))
	var cost: int = Content.unit(&"tpla_pickup").cost
	if labs.size() + _queued(pick_src, &"tpla_pickup") < want and p.supply >= cost and not pick_src.is_empty():
		var best: SimEntity = null
		for b2: SimEntity in pick_src:
			if b2.queue.is_empty() and (best == null or w.bdef(b2).is_refinery):
				best = b2
		if best != null:
			cmd({"t": "queue", "target": best.id, "def": "tpla_pickup", "n": 1})
	# idle gatherers back to the seam nearest a stash; spread some to the expansion
	var er := w.get_ent(int(bb["expand_res"]))
	var n_exp := 0
	var exp_stash := false
	if er != null and er.amount > 0:
		for st: SimEntity in stashes:
			if FX.dist(st.pos, er.pos) < FX.ONE * 9:
				exp_stash = true
		for u: SimEntity in labs:
			if u.res_id == er.id:
				n_exp += 1
	for u: SimEntity in labs:
		if not u.is_idle() or stashes.is_empty():
			continue
		var res: SimEntity = null
		if exp_stash and n_exp < int(tc["lps"]):
			res = er
			n_exp += 1
		else:
			var st2: SimEntity = null
			var bd2 := 1 << 50
			for st: SimEntity in stashes:
				var d := FX.dist2(st.pos, u.pos)
				if d < bd2:
					bd2 = d
					st2 = st
			res = EconSys.nearest_resource(w, st2.pos if st2 != null else u.pos)
		if res != null:
			cmd({"t": "harvest", "ids": [u.id], "target": res.id})

# ------------------------------------------------------------------ build planner
func _margin_for(id: StringName) -> int:
	return 0 if Content.btag(id, "trap") or Content.btag(id, "camo") else 1

func _next_building() -> StringName:
	var counts := {}
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		counts[b.def_id] = counts.get(b.def_id, 0) + 1
	# M3.3: Iran runs on power now (Gas Turbine Plants): keep a little headroom ahead of the build list
	var pw := me()
	if counts.get(&"tpla_den", 0) > 0 and pw.power_prod - pw.power_used < 3:
		# M3.3: once the Defence Workshop is up and money allows, the Combined-Cycle Gas Plant
		if counts.get(&"tpla_workshop", 0) > 0 and pw.supply >= Content.building(&"tpla_cc_plant").cost + 400:
			return &"tpla_cc_plant"
		if pw.supply >= Content.building(&"tpla_gas_plant").cost:
			return &"tpla_gas_plant"
	var desired := {}
	for item in persona.opening:
		var id := StringName(item)
		desired[id] = desired.get(id, 0) + 1
		if counts.get(id, 0) < desired[id]:
			if id == &"tpla_stash" and desired[id] >= 2 and seconds() < cfg["expand_s"]:
				continue
			if id == &"tpla_demo_trap" and desired[id] > int(tc["traps"]):
				continue
			if id == &"tpla_camo_net" and desired[id] > int(tc["nets"]):
				continue
			if id == &"tpla_tunnel" and desired[id] > int(tc["tunnels"]):
				continue
			return id
	var p := me()
	var s := seconds()
	if s > int(cfg["expand_s"]) + 180 and counts.get(&"tpla_stash", 0) < int(tc["stashes"]):
		return &"tpla_stash"
	if s > 360 and counts.get(&"tpla_camp", 0) < 2 and p.supply > 900:
		return &"tpla_camp"
	if s > 420 and counts.get(&"tpla_chop_shop", 0) < 2 and p.supply > 1700:
		return &"tpla_chop_shop"
	if counts.get(&"tpla_tunnel", 0) < int(tc["tunnels"]) + maxi(0, counts.get(&"tpla_stash", 0) - 2) and s > 300 and p.supply > 900:
		return &"tpla_tunnel"
	if s > 540 and counts.get(&"tpla_bazaar", 0) < int(tc["bazaars"]) and p.supply > 2600:
		return &"tpla_bazaar"
	if counts.get(&"tpla_demo_trap", 0) < int(tc["traps"]) + (counts.get(&"tpla_stash", 0) - 1 if difficulty == "hard" else 0):
		return &"tpla_demo_trap"
	if s > 600 and counts.get(&"tpla_camo_net", 0) < int(tc["nets"]) and p.supply > 800:
		return &"tpla_camo_net"
	if s > 900 and difficulty == "hard" and counts.get(&"tpla_chop_shop", 0) < 3 and p.supply > 2000:
		return &"tpla_chop_shop"
	# M2.4: rocket nests for anti-vehicle / AA cover (not on easy)
	if s > 420 and difficulty != "easy" and counts.get(&"tpla_wasp_nest", 0) < (2 if difficulty == "hard" else 1) and p.supply > 1100:
		return &"tpla_wasp_nest"
	# M2.9: an Airfield for the Mirage / Fulcrum / Falcon once the Chop Shop economy is running
	if s > (780 if difficulty == "hard" else 960) and difficulty != "easy" and counts.get(&"tpla_chop_shop", 0) >= 1 \
			and counts.get(&"tpla_airfield", 0) < 1 and p.supply > 2400:
		return &"tpla_airfield"
	return &""

func _enemy_spawn() -> Vector2i:
	var my_team := me().team
	var best := map_center()
	var bd := 1 << 50
	for pl in w.players:
		if pl.eliminated or not w.enemies(my_team, pl.team):
			continue
		var sp := _spawn_of(pl.id)
		var d := FX.dist2(sp, base_pos())
		if d < bd:
			bd = d
			best = sp
	return best

func _remote_stash() -> SimEntity:
	var far: SimEntity = null
	for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if w.bdef(b).is_refinery and FX.dist(b.pos, base_pos()) > FX.ONE * 18 and (far == null or b.id > far.id):
			far = b
	return far

func _toward_for(id: StringName) -> Vector2i:
	var base := base_pos()
	match id:
		&"tpla_stash":
			if w.count_owned(pid, &"tpla_stash") == 0:
				var res := EconSys.nearest_resource(w, base, 30)
				return res.pos if res != null else base
			var er := _pick_expansion()
			return er.pos if er != null else base
		&"tpla_wasp_nest":
			return base + (_enemy_spawn() - base) * 22 / 100
		&"tpla_tunnel":
			var n := w.count_owned(pid, &"tpla_tunnel")
			var far := _remote_stash()
			if n % 2 == 1 and far != null:
				return far.pos + (map_center() - far.pos) / 8
			# forward tunnel on the road to the nearest enemy
			return base + (_enemy_spawn() - base) * (25 + 8 * mini(n, 2)) / 100
		&"tpla_demo_trap":
			var k := w.count_owned(pid, &"tpla_demo_trap")
			var far2 := _remote_stash()
			if k % 3 == 2 and far2 != null:
				return far2.pos + (_enemy_spawn() - far2.pos) / 7
			# the approach route: a stretch of the line toward the enemy, alternately offset
			var dir := _enemy_spawn() - base
			var side := Vector2i(-dir.y, dir.x) / 12 * (1 if k % 2 == 0 else -1)
			return base + dir * (30 + 6 * (k % 3)) / 100 + side
		&"tpla_camo_net":
			var best: SimEntity = null
			for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
				if TplaSys.is_tunnel(w, b) and (best == null or FX.dist(b.pos, base) > FX.dist(best.pos, base)):
					best = b
			return best.pos if best != null else base + (map_center() - base) / 5
		&"tpla_bazaar", &"tpla_workshop":
			return base + (base - map_center()) / 10
	return base + (map_center() - base) / 6

# ------------------------------------------------------------------ production
func _pick_unit(bd: BuildingDef) -> StringName:
	var enemy_armor := 0
	var enemy_inf := 0
	var enemy_air := 0
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and w.enemies(me().team, e.team) and w.fog.is_visible_ent(w, me().team, e):
			var d: UnitDef = w.udef(e)
			if d.move_layer == &"air":
				enemy_air += 1
			elif d.armor_type == &"infantry":
				enemy_inf += 1
			elif d.tags.has("vehicle") and not d.tags.has("harvester"):
				enemy_armor += 1
	var have := {}
	for u: SimEntity in combat_units():
		have[u.def_id] = have.get(u.def_id, 0) + 1
	var n_combat := combat_units().size()
	var total := 0
	var weights := {}
	for uid in bd.produces:
		var sid := StringName(uid)
		var ud: UnitDef = Content.unit(sid)
		var wgt: int = int(persona.unit_weights.get(uid, persona.unit_weights.get(String(uid), 1))) * 10
		if ud.tags.has("builder") or ud.tags.has("harvester"):
			wgt = 0
		if ud.air_slots > 0:
			# M2.9 jets: only with a free Airfield slot; fighters when enemy aircraft are about
			if not _air_slot_ok(ud):
				wgt = 0
			elif ud.tags.has("fighter") and enemy_air > 0:
				wgt *= 2
		if ud.tags.has("at") and enemy_armor > enemy_inf:
			wgt *= 2
		elif ud.tags.has("at") and enemy_inf > enemy_armor * 2:
			wgt = wgt / 2       # rockets are wasted on infantry; grenadiers shred slow AT teams
		if sid == &"tpla_hailstorm":
			wgt = wgt * 4 if enemy_air > 0 else (wgt * 3 if enemy_inf > enemy_armor else wgt)   # the BHX-35's 35 mm gun also shreds infantry
		if ud.tags.has("squad") and enemy_inf > enemy_armor:
			wgt = wgt * 3 / 2   # M3.5 Combat Squad: MG + grenadier shred infantry
		if sid == &"tpla_scrapback" and enemy_armor > enemy_inf:
			wgt = wgt * 3 / 2
		if (sid == &"tpla_marksman" or sid == &"tpla_insurgent") and int(have.get(sid, 0)) >= 1 + n_combat / 12:
			wgt = 0
		if sid == &"tpla_blight" and int(have.get(sid, 0)) >= 1 + n_combat / 10:
			wgt = 0
		if ud.tags.has("raider") and seconds() < 420:
			wgt = wgt * 3 / 2     # early swarm raids
		# M2.4: one detector per dozen fighters; [STUB] never
		if ud.tags.has("stub"):
			wgt = 0
		elif ud.tags.has("detector") and int(have.get(sid, 0)) >= 1 + n_combat / 12:
			wgt = 0
		if w.prereqs_met(pid, ud.prereqs) != "":
			wgt = 0
		weights[uid] = wgt
		total += wgt
	if total <= 0:
		return &""
	var roll := w.tick * 7919 % total
	for uid in bd.produces:
		roll -= weights[uid]
		if roll < 0:
			return StringName(uid)
	return &""

# ------------------------------------------------------------------ army hooks
func _reserved_ids() -> Dictionary:
	var out := {}
	for id in bb["raid"]:
		out[int(id)] = true
	for id in bb["salvagers"]:
		out[int(id)] = true
	for id in bb["guards"]:
		out[int(id)] = true
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		if w.udef(u).tags.has("jet"):
			out[u.id] = true   # M2.9: jets fly their own sorties, never in the ground waves
	return out

func _is_scout_type(u: SimEntity) -> bool:
	return u.def_id == &"tpla_rattler"

func _nearest_tunnel(p: Vector2i, max_tiles: int) -> SimEntity:
	var best: SimEntity = null
	var bd := (FX.ONE * max_tiles) * (FX.ONE * max_tiles)
	for t: SimEntity in TplaSys.tunnels_of(w, pid):
		var d := FX.dist2(t.pos, p)
		if d < bd:
			bd = d
			best = t
	return best

## Damaged units dive into the nearest tunnel (they heal inside), else fall back to staging.
func _send_back(ids: Array) -> void:
	var into: Array = []
	var rest: Array = []
	var room := TplaSys.network_capacity() - TplaSys.network_units(w, pid).size()
	var tun: SimEntity = null
	for id in ids:
		var e := w.get_ent(int(id))
		if e == null:
			continue
		var t := _nearest_tunnel(e.pos, 30)
		if t != null and room > 0:
			into.append(e.id)
			tun = t
			room -= 1
		else:
			rest.append(e.id)
	if not into.is_empty():
		cmd({"t": "garrison", "ids": into, "target": tun.id})
	if not rest.is_empty():
		cmd({"t": "move", "ids": rest, "pos": _staging()})

# ------------------------------------------------------------------ swarm raids (hit and run)
func _raid_target() -> Vector2i:
	var my_team := me().team
	var from := base_pos()
	var raid_units: Array = []
	for id in bb["raid"]:
		raid_units.append(w.get_ent(int(id)))
	if not raid_units.is_empty():
		from = _centroid(raid_units)
	# visible enemy gatherers first, then remembered refineries away from the enemy HQ
	var best := Vector2i(-1, -1)
	var bd := 1 << 60
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and w.enemies(my_team, e.team) and w.udef(e).tags.has("harvester") \
				and w.fog.is_visible_ent(w, my_team, e):
			var d := FX.dist2(e.pos, from)
			if d < bd:
				bd = d
				best = e.pos
	if best.x >= 0:
		return best
	var mem: Dictionary = w.fog.memory.get(my_team, {})
	for id in mem:
		var m: Dictionary = mem[id]
		if int(m["owner"]) < 0 or not w.enemies(my_team, int(m["team"])):
			continue
		var bd2: BuildingDef = Content.building(m["def"])
		if not bd2.is_refinery:
			continue
		var c := Vector2i(m["tile"].x * FX.ONE + bd2.footprint.x * FX.HALF, m["tile"].y * FX.ONE + bd2.footprint.y * FX.HALF)
		var s := FX.dist2(c, from)
		# prefer outlying hubs (less defended): penalize ones near the owner's start
		if FX.dist(c, _spawn_of(int(m["owner"]))) < FX.ONE * 14:
			s = s * 3
		if s < bd:
			bd = s
			best = c
	if best.x >= 0:
		return best
	return _pick_target()

func _raids() -> void:
	bb["raid"] = _alive_ids(bb["raid"])
	var raid: Array = []
	for id in bb["raid"]:
		raid.append(w.get_ent(int(id)))
	if raid.is_empty():
		if w.tick < int(bb["raid_cd"]) or seconds() < 200:
			return
		var in_wave := {}
		for id in bb["wave"]:
			in_wave[int(id)] = true
		var cands: Array = []
		for u: SimEntity in combat_units():
			if w.udef(u).tags.has("raider") and not in_wave.has(u.id) and not bb["salvagers"].has(u.id) \
					and u.hp * 100 >= u.max_hp * 75 and not (u.id in bb["retreated"]):
				cands.append(u)
		if cands.size() < int(tc["raid"]):
			return
		var ids: Array = []
		for u: SimEntity in cands.slice(0, int(tc["raid"]) + 2):
			ids.append(u.id)
		bb["raid"] = ids
		bb["raid_n"] = 0
		var t := _raid_target()
		if t.x >= 0:
			cmd({"t": "amove", "ids": ids, "pos": t})
		return
	# hit and run: wounded raiders peel off; the whole squad runs from a stronger force
	var val := army_value(raid)
	var c := _centroid(raid)
	var back: Array = []
	for u: SimEntity in raid:
		if u.hp * 100 < u.max_hp * 50:
			back.append(u.id)
	if not back.is_empty():
		_send_back(back)
		for id in back:
			bb["raid"].erase(id)
			bb["retreated"].append(id)
	if _enemy_strength_near(c, 9) > val * 3 / 2:
		_send_back(bb["raid"].duplicate())
		for id in bb["raid"]:
			bb["retreated"].append(id)
		bb["raid"] = []
		bb["raid_cd"] = w.tick + 20 * 45
		return
	var idle := 0
	for u: SimEntity in raid:
		if u.is_idle():
			idle += 1
	if idle * 2 >= raid.size():
		bb["raid_n"] = int(bb["raid_n"]) + 1
		if int(bb["raid_n"]) > 4:
			cmd({"t": "move", "ids": bb["raid"].duplicate(), "pos": _staging()})
			bb["raid"] = []
			bb["raid_cd"] = w.tick + 20 * 30
			return
		var t2 := _raid_target()
		if t2.x >= 0:
			cmd({"t": "amove", "ids": bb["raid"].duplicate(), "pos": t2})

# ------------------------------------------------------------------ salvage hunting
func _salvage() -> void:
	var cur: Dictionary = bb["salvagers"]
	for k in cur.keys():
		var u := w.get_ent(int(k))
		var cr := w.get_ent(int(cur[k]))
		if u == null or u.owner != pid or cr == null or not cr.alive:
			if u != null and u.owner == pid and u.is_idle():
				cmd({"t": "move", "ids": [u.id], "pos": _staging()})
			cur.erase(k)
	if not _every("t_salvage", 20):
		return
	var my_team := me().team
	var taken := {}
	for k in cur:
		taken[int(cur[k])] = true
	var in_wave := {}
	for id in bb["wave"]:
		in_wave[int(id)] = true
	for id in bb["raid"]:
		in_wave[int(id)] = true
	for id in w.ids:
		var cr2: SimEntity = w.ents[id]
		if not cr2.alive or cr2.kind != SimEntity.Kind.CRATE or taken.has(cr2.id) or not w.fog.is_visible_ent(w, my_team, cr2):
			continue
		if FX.dist(cr2.pos, base_pos()) > FX.ONE * 40 and FX.dist(cr2.pos, _staging()) > FX.ONE * 30:
			continue
		if _enemy_strength_near(cr2.pos, 8) > 400:
			continue
		var best: SimEntity = null
		var bd := (FX.ONE * 25) * (FX.ONE * 25)
		for u: SimEntity in combat_units():
			if in_wave.has(u.id) or cur.has(u.id) or u.tier >= 3 or not w.udef(u).tags.has("salvage"):
				continue
			if not u.is_idle() and not (not u.orders.is_empty() and u.orders[0].get("o", "") == "move"):
				continue
			var d := FX.dist2(u.pos, cr2.pos)
			if d < bd:
				bd = d
				best = u
		if best != null:
			cur[best.id] = cr2.id
			taken[cr2.id] = true
			cmd({"t": "move", "ids": [best.id], "pos": cr2.pos})

# ------------------------------------------------------------------ tunnels: guards and ambushes
func _tunnels() -> void:
	var tuns := TplaSys.tunnels_of(w, pid)
	bb["guards"] = _alive_ids(bb["guards"])
	if tuns.is_empty():
		bb["guards"] = []
		return
	var inside := TplaSys.network_units(w, pid)
	var my_team := me().team
	# ambush: an enemy force next to a tunnel -> everybody out
	for t: SimEntity in tuns:
		if inside.is_empty():
			break
		var near := 0
		for e: SimEntity in w.units_in_radius(t.pos, FX.ONE * 9):
			if w.enemies(my_team, e.team) and w.fog.is_visible_ent(w, my_team, e):
				near += w.udef(e).cost
		if near >= 300:
			cmd({"t": "unload", "ids": [t.id]})
			bb["guards"] = []
			for u: SimEntity in inside:
				bb["retreated"].erase(u.id)
			return
	# healed units leave the network when it is quiet (whole network ejects together)
	if not inside.is_empty() and _every("t_tunnel_out", 20 * 40):
		var hurt := false
		var non_guard := 0
		for u: SimEntity in inside:
			if not (u.id in bb["guards"]):
				non_guard += 1
				if u.hp * 100 < u.max_hp * 90:
					hurt = true
		if non_guard > 0 and not hurt:
			var exit_t: SimEntity = tuns[0]
			for t2: SimEntity in tuns:
				if FX.dist(t2.pos, _staging()) < FX.ONE * 12 or FX.dist(t2.pos, base_pos()) < FX.dist(exit_t.pos, base_pos()):
					exit_t = t2
			cmd({"t": "unload", "ids": [exit_t.id]})
			bb["guards"] = []
			for u: SimEntity in inside:
				bb["retreated"].erase(u.id)
			return
	# station a few infantry guards inside (medium / hard)
	var want: int = int(tc["guards"]) * mini(tuns.size(), 2)
	if bb["guards"].size() < want and _every("t_guard", 200):
		var in_wave := {}
		for id in bb["wave"]:
			in_wave[int(id)] = true
		var fwd: SimEntity = tuns[0]
		for t3: SimEntity in tuns:
			if FX.dist(t3.pos, base_pos()) > FX.dist(fwd.pos, base_pos()):
				fwd = t3
		var ids: Array = []
		for u: SimEntity in combat_units():
			if ids.size() + bb["guards"].size() >= want:
				break
			if w.udef(u).tags.has("garrison") and not in_wave.has(u.id) and not (u.id in bb["guards"]) and u.is_idle():
				ids.append(u.id)
		if not ids.is_empty() and inside.size() + ids.size() <= TplaSys.network_capacity():
			cmd({"t": "garrison", "ids": ids, "target": fwd.id})
			bb["guards"].append_array(ids)

# ------------------------------------------------------------------ general powers
func _powers() -> void:
	var p := me()
	for id in Content.powers_for(&"tpla"):
		if p.points > 0 and PowersSys.can_buy(w, pid, id) == "":
			cmd({"t": "buy_power", "def": String(id)})
			return
	var threatened: bool = w.tick - int(bb["threat_tick"]) < 100
	if PowersSys.ready_in(w, pid, &"tpla_uprising") == 0 and (threatened or not bb["wave"].is_empty()):
		cmd({"t": "power", "def": "tpla_uprising", "pos": base_pos()})
	if PowersSys.ready_in(w, pid, &"tpla_ambush") == 0:
		if threatened:
			cmd({"t": "power", "def": "tpla_ambush", "pos": bb["threat_pos"]})
		elif not bb["wave"].is_empty():
			var eng := _engaged_wave()
			if eng.size() >= 3:
				cmd({"t": "power", "def": "tpla_ambush", "pos": _centroid(eng)})
	if PowersSys.ready_in(w, pid, &"tpla_blight_shells") == 0:
		var tgt := _enemy_clump()
		if tgt.x >= 0:
			cmd({"t": "power", "def": "tpla_blight_shells", "pos": tgt})
	if PowersSys.ready_in(w, pid, &"tpla_scrap_rain") == 0:   # M3.0 E: Shahed Drone Strike (was Scrap Rain)
		var tgs := _enemy_clump()
		if tgs.x >= 0:
			cmd({"t": "power", "def": "tpla_scrap_rain", "pos": tgs})

func _engaged_wave() -> Array:
	var eng: Array = []
	for id in bb["wave"]:
		var e := w.get_ent(int(id))
		if e != null and e.target != 0:
			eng.append(e)
	return eng

## Densest visible enemy group near my wave or my base (for Blight Shells).
func _enemy_clump() -> Vector2i:
	var my_team := me().team
	var best := Vector2i(-1, -1)
	var bv := 1200
	var anchors: Array = [base_pos()]
	var eng := _engaged_wave()
	if not eng.is_empty():
		anchors.append(_centroid(eng))
	for a: Vector2i in anchors:
		for e: SimEntity in w.units_in_radius(a, FX.ONE * 14):
			if not w.enemies(my_team, e.team) or not w.fog.is_visible_ent(w, my_team, e):
				continue
			var v := 0
			for e2: SimEntity in w.units_in_radius(e.pos, FX.ONE * 4):
				if w.enemies(my_team, e2.team):
					v += w.udef(e2).cost
			if v > bv:
				bv = v
				best = e.pos
	return best

# ------------------------------------------------------------------ wave gathering
## Mixed-speed TPLA armies (3000 mm/s Rattlers next to 1150 mm/s Rocket Cells) used to arrive
## strung out and die piecemeal at the enemy's defences. A new wave first regroups at a
## forward rally point (40% of the way), then attacks together once 75% are there or after
## 40 s, ZH-style.
func _gather_wave() -> void:
	if bb["wave"].is_empty():
		bb["hold_wave"] = false
		bb.erase("rally")
		return
	if int(bb.get("rally_wave", 0)) != int(bb["wave_n"]):
		var tgt := _pick_target()
		if tgt.x < 0:
			return
		var st := _staging()
		var rp: Vector2i = st + (tgt - st) * 2 / 5
		bb["rally"] = rp
		bb["rally_tgt"] = tgt
		bb["rally_t"] = w.tick
		bb["rally_wave"] = int(bb["wave_n"])
		bb["hold_wave"] = true
		cmd({"t": "move", "ids": bb["wave"].duplicate(), "pos": rp})
		return
	if not bb.has("rally"):
		return
	var rp2: Vector2i = bb["rally"]
	var near := 0
	var n := 0
	for id in bb["wave"]:
		var e := w.get_ent(id)
		if e == null:
			continue
		n += 1
		if FX.dist(e.pos, rp2) < FX.ONE * 8:
			near += 1
	if near * 4 >= n * 3 or w.tick - int(bb["rally_t"]) > 20 * 40:
		var tgt2 := _pick_target()
		if tgt2.x < 0:
			tgt2 = bb["rally_tgt"]
		cmd({"t": "amove", "ids": bb["wave"].duplicate(), "pos": tgt2})
		bb.erase("rally")
		bb["hold_wave"] = false
