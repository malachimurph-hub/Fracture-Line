extends Node
## Headless test entry: godot --headless --path . res://tests/test_runner.tscn -- <test> [args]
## Tests: soak N | match <1v1|2v2|ffa> | replay | saveload | content | touch (needs rendering)

var results: Array = []
var failed := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var test := args[0] if args.size() > 0 else "match"
	print("=== FRACTURE LINE test: ", " ".join(args))
	match test:
		"match":
			var mode: String = args[1] if args.size() > 1 else "1v1"
			var seed := int(args[2]) if args.size() > 2 else 1
			# ZH 4-player games run long; allow 60 min there, 40 min for 1v1 (override with arg 3)
			var cap := int(args[3]) if args.size() > 3 else (40 if mode == "1v1" else 60)
			var mf: Array = (args[4] if args.size() > 4 else "").split(",", false)
			var md: Array = (args[5] if args.size() > 5 else "").split(",", false)
			run_match(mode, seed, true, cap, md, mf)
		"soak":
			var n := int(args[1]) if args.size() > 1 else 5
			var wins := {}
			var t0 := Time.get_ticks_msec()
			var off := int(args[2]) if args.size() > 2 else 0
			var modes: Array = (args[3] if args.size() > 3 else "1v1,1v1,2v2,ffa").split(",")
			# arg 4: faction pattern, e.g. "eu,tpla" (alternated per seed so both sides get each spawn)
			var fpat: Array = (args[4] if args.size() > 4 else "eu").split(",")
			var fwins := {}
			var diff_sets := [["medium", "medium"], ["hard", "easy"], ["easy", "hard"], ["hard", "medium", "medium", "hard"], ["medium", "hard", "easy", "medium"]]
			for i in n:
				var mode2: String = modes[(i + off) % modes.size()]
				var nsl := 2 if mode2 == "1v1" else 4
				var facs: Array = []
				for k in nsl:
					facs.append(fpat[(k + (i + off) + (k / 2 if mode2 == "2v2" else 0)) % fpat.size()] if fpat.size() > 1 else fpat[0])
				if mode2 == "2v2" and fpat.size() > 1:
					# teams 0/0/1/1 by slot -> give each team one faction, swapping per seed
					var a0: String = fpat[(i + off) % fpat.size()]
					var b0: String = fpat[(i + off + 1) % fpat.size()]
					facs = [a0, a0, b0, b0]
				var dset: Array = diff_sets[(i + off) % diff_sets.size()]
				if fpat.size() > 1 and nsl == 2:
					var dk := ((i + off) / 2) % 3
					dset = ["medium", "medium"] if dk == 0 else (["hard", "hard"] if dk == 1 else ["easy", "easy"])
				# arg 5: force one difficulty for every slot (e.g. "medium")
				if args.size() > 5 and args[5] != "":
					dset = []
					for k in nsl:
						dset.append(args[5])
				var res := run_match(mode2, 1000 + i + off, false, 40 if mode2 == "1v1" else 60, dset, facs, (i + off) / 2 if fpat.size() > 1 else 0)
				wins[mode2 + ":" + str(res["winner"])] = wins.get(mode2 + ":" + str(res["winner"]), 0) + 1
				var wf := "draw"
				if int(res["winner"]) >= 0:
					var wfs := {}
					for k in nsl:
						if int(res["teams"][k]) == int(res["winner"]):
							wfs[facs[k]] = true
					wf = "+".join(wfs.keys())
				fwins[wf] = fwins.get(wf, 0) + 1
				print("SOAK-RESULT seed=%d mode=%s facs=%s diffs=%s winner_team=%d winner_faction=%s time=%d:%02d" % [1000 + i + off, mode2, facs, dset, res["winner"], wf, int(res["secs"]) / 60, int(res["secs"]) % 60])
			print("SOAK done %d matches in %d s; outcomes=%s faction_wins=%s" % [n, (Time.get_ticks_msec() - t0) / 1000, wins, fwins])
		"replay":
			test_replay()
		"saveload":
			test_saveload()
		"corners":
			test_corners()
		"resume":
			test_resume()
		"placement":
			test_placement()
		"audio":
			test_audio()
		"content":
			test_content()
		"tpla":
			test_tpla()
		"duel":
			test_duel()
		"zh":
			test_zh()
		"roster":
			test_roster()
		"m24":
			test_m24()
		"m25":
			test_m25()
		"viewcost":
			view_cost()
		"turret":
			test_turret()
		"airspread":
			test_airspread()
		"stash":
			test_stash(args[1] if args.size() > 1 else "")
		"map_builder":
			await load("res://tests/map_builder_test.gd").run(self)   # M2.8
		"m33":
			await load("res://tests/m33_test.gd").run(self)   # M3.3 Phase 1
		"wb":
			await load("res://tests/world_builder_test.gd").run(self)   # M3.3 Phase 5 World Builder
		"m34":
			await load("res://tests/m34_test.gd").run(self)   # M3.4 night lights + infantry
		"m35":
			await load("res://tests/m35_test.gd").run(self)   # M3.5 menu, squads, poses, factions
		"stall":
			var r2 := MatchRunner.new()
			r2.record_replay = false
			r2.start(make_cfg(args[1] if args.size() > 1 else "ffa", int(args[2]) if args.size() > 2 else 3))
			var mins := int(args[3]) if args.size() > 3 else 15
			for i in mins * 1200:
				r2.advance()
				if i % 6000 == 5999 or i == mins * 1200 - 1:
					print("--- t=%d:00" % ((i + 1) / 1200))
					for pid in r2.ais:
						var a: AIPlayer = r2.ais[pid]
						if r2.sim.players[pid].eliminated:
							continue
						var wu: Array = []
						var idle := 0
						for id in a.bb["wave"]:
							var e := r2.sim.get_ent(id)
							wu.append(e)
							if e.is_idle(): idle += 1
						var orders := {}
						for e in wu:
							var o: String = e.orders[0].get("o", "") if not e.orders.is_empty() else "idle"
							orders[o] = orders.get(o, 0) + 1
						print("   threat_age=%d threat_pos=%s threat_val=%d" % [r2.sim.tick - int(a.bb["threat_tick"]), FX.to_tile(a.bb["threat_pos"]) if a.bb.has("threat_pos") else "-", a._enemy_strength_near(a.bb["threat_pos"], 12) if a.bb.has("threat_pos") else 0])
						print("P%d wave=%d idle=%d orders=%s centroid=%s target=%s board=%s home=%d pop=%d/%d need=%d staged_val=%d" % [pid, wu.size(), idle, orders,
							FX.to_tile(a._centroid(wu)) if not wu.is_empty() else "-", FX.to_tile(a._pick_target()), r2.team_board.get(r2.sim.players[pid].team, {}),
							a.combat_units().size() - wu.size(), r2.sim.players[pid].pop, r2.sim.players[pid].pop_cap, a._wave_threshold(), a.army_value(a.combat_units())])
					for p in r2.sim.players:
						var bl: Array = []
						for id in r2.sim.ids:
							var b: SimEntity = r2.sim.ents[id]
							if b.owner == p.id and b.kind == SimEntity.Kind.BUILDING:
								bl.append("%s@%s" % [String(b.def_id).substr(3, 4), b.tile])
						print("  P%d bld: %s" % [p.id, " ".join(bl)])
		"compile":
			var bad: Array = []
			var stack: Array = ["res://"]
			var n := 0
			while not stack.is_empty():
				var d: String = stack.pop_back()
				for sub in DirAccess.get_directories_at(d):
					if not sub.begins_with(".") and sub != "tools" and sub != "addons":
						stack.append(d.path_join(sub))
				for f in DirAccess.get_files_at(d):
					if f.ends_with(".gd"):
						n += 1
						var scr: GDScript = load(d.path_join(f))
						if scr == null or not scr.can_instantiate():
							bad.append(d.path_join(f))
			print("COMPILE: %d scripts, broken: %s" % [n, bad])
			failed = not bad.is_empty()
		"tdiag":
			var rt := MatchRunner.new()
			rt.record_replay = false
			rt.start(make_cfg("1v1", int(args[1]) if args.size() > 1 else 21, [], ["eu", "tpla"]))
			for i in (int(args[2]) if args.size() > 2 else 600):
				rt.advance()
			var ta = rt.ais[1]
			print("tpla? ", ta is AITpla, " builders=", ta.bb["builders"], " next=", ta._next_building(), " fs=", ta.bb.get("fs"), " supply=", rt.sim.players[1].supply)
			for u in ta._gatherers():
				print(" lab ", u.id, " orders=", u.orders, " phase=", u.phase, " idle=", u.is_idle())
			var nb2: StringName = ta._next_building()
			if nb2 != &"":
				var tw: Vector2i = ta._toward_for(nb2)
				print("toward ", FX.to_tile(tw), " prereq=", rt.sim.prereqs_met(1, Content.building(nb2).prereqs), " spot=", ta.find_spot(nb2, tw))
				for k in 5:
					print(" can_place ", FX.to_tile(tw) + Vector2i(k * 2, 0), " -> ", rt.sim.can_place(1, nb2, FX.to_tile(tw) + Vector2i(k * 2, 0)))
		"ediag":
			# economy / army timeline per player (balance diagnosis)
			var re := MatchRunner.new()
			re.record_replay = false
			var dfs := String(args[3]) if args.size() > 3 else "medium"
			# arg 4: spawn rotation as in soak (seed pair index); arg 5: "swap" puts TPLA in slot 0
			var efacs := ["tpla", "eu"] if args.size() > 5 and args[5] == "swap" else ["eu", "tpla"]
			re.start(make_cfg("1v1", int(args[1]) if args.size() > 1 else 21, [dfs, dfs], efacs, int(args[4]) if args.size() > 4 else 0))
			var mins := int(args[2]) if args.size() > 2 else 8
			var deaths := {}
			for mi in mins:
				for k in 1200:
					re.advance()
					for ev in re.sim.events:
						if ev["t"] == "death" and ev.get("kind", -1) == SimEntity.Kind.UNIT and ev.get("by", &"") != &"":
							var zone := "field"
							for b9 in re.sim.ids:
								var hq9: SimEntity = re.sim.ents[b9]
								if hq9.alive and hq9.kind == SimEntity.Kind.BUILDING and Content.building(hq9.def_id).is_hq and FX.dist(hq9.pos, ev["pos"]) < FX.ONE * 22:
									zone = "own_base" if hq9.owner == int(ev["owner"]) else "enemy_base"
							var kk := "%s<-%s @%s t%d" % [ev["def"], ev["by"], zone, re.sim.tick / 1200]
							deaths[kk] = deaths.get(kk, 0) + 1
					if re.sim.game_over:
						break
				for pid in 2:
					var pl = re.sim.players[pid]
					var harv := 0
					var army := 0
					var nb := 0
					var bl: Dictionary = {}
					for id in re.sim.ids:
						var e: SimEntity = re.sim.ents[id]
						if e.owner != pid:
							continue
						if e.kind == SimEntity.Kind.BUILDING:
							nb += 1
							bl[e.def_id] = bl.get(e.def_id, 0) + 1
						elif e.kind == SimEntity.Kind.UNIT:
							var ud: UnitDef = Content.unit(e.def_id)
							if ud.harvest_capacity > 0 and e.phase >= 0:
								harv += 1
							elif not ud.tags.has("builder") and not ud.tags.has("harvester"):
								army += ud.cost
					var oh := {}
					for id in re.sim.ids:
						var e7: SimEntity = re.sim.ents[id]
						if e7.alive and e7.owner == pid and e7.kind == SimEntity.Kind.UNIT and not Content.unit(e7.def_id).tags.has("builder") and not Content.unit(e7.def_id).tags.has("harvester"):
							var ok2: String = (e7.orders[0].get("o", "?") if not e7.orders.is_empty() else "idle") + ("+tgt" if e7.target != 0 else "")
							if e7.res_id < 0:
								ok2 = "inside"
							oh[ok2] = oh.get(ok2, 0) + 1
					print("   orders P%d %s" % [pid, str(oh)])
					print("min %d P%d %s supply=%d harvested=%d harvesting=%d army$=%d bld=%d %s kills=%d lost=%d" % [mi + 1, pid, re.sim.faction_of(pid), pl.supply, pl.stats["harvested"], harv, army, nb, str(bl), pl.stats["kills"], pl.stats["lost"]])
				if re.sim.game_over:
					print("game over")
					break
			# stall probe: every surviving building vs the other side's knowledge of it
			for id in re.sim.ids:
				var sb: SimEntity = re.sim.ents[id]
				if not sb.alive or sb.kind != SimEntity.Kind.BUILDING:
					continue
				var other := 1 - sb.owner
				var ot: int = re.sim.players[other].team
				var nd := 1 << 40
				for id2 in re.sim.ids:
					var u2: SimEntity = re.sim.ents[id2]
					if u2.alive and u2.owner == other and u2.kind == SimEntity.Kind.UNIT:
						nd = mini(nd, FX.dist(u2.pos, sb.pos))
				var ai2: AIPlayer = re.ais.get(other)
				print("  bld P%d %s tile=%s hp=%d visible_to_enemy=%s remembered=%s nearest_enemy_unit=%.1f tiles enemy_wave=%d" % [sb.owner, sb.def_id, sb.tile, sb.hp,
					re.sim.fog.is_visible_ent(re.sim, ot, sb), re.sim.fog.memory.get(ot, {}).has(id), nd / float(FX.ONE), (ai2.bb["wave"].size() if ai2 != null else -1)])
			for pid3 in 2:
				var ai3: AIPlayer = re.ais.get(pid3)
				if ai3 == null or ai3.bb["wave"].is_empty():
					continue
				var wu3: Array = []
				for id3 in ai3.bb["wave"]:
					var e3 := re.sim.get_ent(id3)
					if e3 != null:
						wu3.append(e3)
				print("  wave P%d n=%d centroid=%s pick_target=%s hunt_i=%d samples=%s" % [pid3, wu3.size(), FX.to_tile(ai3._centroid(wu3)), FX.to_tile(ai3._pick_target()), int(ai3.bb.get("hunt_i", 0)),
					str(wu3.slice(0, 4).map(func(x): return [x.def_id, FX.to_tile(x.pos), x.orders.slice(0, 1), x.target]))])
			var dk := deaths.keys()
			dk.sort_custom(func(x, y): return deaths[x] > deaths[y])
			for k2 in dk.slice(0, 25):
				print("  death %s x%d" % [k2, deaths[k2]])
		"spike":
			# worst-tick breakdown (AI think per player + sim systems)
			var rs := MatchRunner.new()
			rs.record_replay = false
			var sdf: String = args[3] if args.size() > 3 else "hard"
			rs.start(make_cfg("1v1", int(args[1]) if args.size() > 1 else 1002, [sdf, sdf], ["eu", "tpla"]))
			rs.sim.prof = {}
			var worst := []
			for i in 20 * 60 * int(args[2] if args.size() > 2 else "10"):
				var parts := {}
				for pid in rs.ais:
					var ai: AIPlayer = rs.ais[pid]
					if not rs.sim.players[pid].eliminated and (rs.sim.tick + pid) % ai.think_every == 0:
						var t0 := Time.get_ticks_usec()
						ai.think()
						parts["ai%d" % pid] = Time.get_ticks_usec() - t0
				var t1 := Time.get_ticks_usec()
				rs.sim.step()
				var tot := Time.get_ticks_usec() - t1
				for k in rs.sim.prof:
					parts[k] = rs.sim.prof[k]
				var all := tot
				for k in parts:
					if k.begins_with("ai"):
						all += parts[k]
				worst.append([all, rs.sim.tick, parts])
				if worst.size() > 40:
					worst.sort_custom(func(a, b): return a[0] > b[0])
					worst.resize(10)
				if rs.sim.game_over:
					break
			worst.sort_custom(func(a, b): return a[0] > b[0])
			for x in worst.slice(0, 8):
				print("tick %d total %.1f ms parts %s" % [x[1], x[0] / 1000.0, str(x[2])])
		"duel":
			# unit-vs-unit check without AI: duel eu_wolfhound*3 tpla_rocket_cell*5,tpla_militia*5
			var rd := MatchRunner.new()
			rd.record_replay = false
			rd.start(make_cfg("1v1", 5, [], ["eu", "tpla"]))
			rd.ais.clear()
			var wd := rd.sim
			wd.fog.disabled = true
			var mid := Vector2i(wd.map.w / 2, wd.map.h / 2)
			var sides := [[], []]
			for side in 2:
				var k := 0
				for spec in String(args[1 + side]).split(","):
					var parts2 := spec.split("*")
					for n in int(parts2[1]) if parts2.size() > 1 else 1:
						var at := mid + Vector2i(-7 if side == 0 else 7, -4 + k % 9) + Vector2i((k / 9) * (-1 if side == 0 else 1), 0)
						var u := wd.spawn_unit(StringName(parts2[0]), side, null, FX.tile_center(wd.map.nearest_passable(at, true)))
						sides[side].append(u)
						k += 1
			for side in 2:
				var ids2: Array = []
				for u: SimEntity in sides[side]:
					ids2.append(u.id)
				rd.issue({"p": side, "t": "amove", "ids": ids2, "pos": FX.tile_center(mid + Vector2i(7 if side == 0 else -7, 0))})
			for i in 20 * 90:
				rd.advance()
			for side in 2:
				var alive := 0
				var val := 0
				for u: SimEntity in sides[side]:
					if u.alive:
						alive += 1
						val += Content.unit(u.def_id).cost
				var spent := 0
				for u: SimEntity in sides[side]:
					spent += Content.unit(u.def_id).cost
				print("DUEL side %d (%s): %d/%d alive, $%d of $%d left" % [side, args[1 + side], alive, sides[side].size(), val, spent])
		"aidiag":
			var r := MatchRunner.new()
			r.start(make_cfg("1v1", 5))
			print("AI personalities: ", Content.ai_personalities.keys(), " maps: ", Content.maps.keys())
			print("hq.produces=", Content.building(&"eu_hq").produces, " crawler.tags=", Content.unit(&"eu_crawler").tags, " opening=", Content.ai_personalities[&"eu_ironclad"].opening, " weights=", Content.ai_personalities[&"eu_ironclad"].unit_weights, " hq.cost=", Content.building(&"eu_hq").cost, " fp=", Content.building(&"eu_hq").footprint)
			var ai0: AIPlayer = r.ais[0]
			print("my buildings=", ai0.my_ents(SimEntity.Kind.BUILDING).size(), " units=", ai0.my_ents(SimEntity.Kind.UNIT).size(), " hq=", ai0.hq())
			for id in r.sim.ids:
				var e: SimEntity = r.sim.ents[id]
				if e.owner == 0:
					print("  ent ", e.id, " ", e.def_id, " kind=", e.kind, " bdef_hq=", (Content.building(e.def_id).is_hq if e.kind == SimEntity.Kind.BUILDING else null))
			r.issue({"p": 0, "t": "queue", "target": ai0.hq().id if ai0.hq() else 0, "def": "eu_crawler", "n": 1})
			r.advance()
			print("supply after manual queue: ", r.sim.players[0].supply, " next_building=", ai0._next_building())
			for i in 400:
				r.advance()
			var ai: AIPlayer = r.ais[0]
			print("persona=", ai.persona, " think_every=", ai.think_every, " supply=", r.sim.players[0].supply, " ents=", r.sim.ids.size())
			print("ai state: ", str(ai.to_dict()).substr(0, 1500))
		_:
			print("unknown test")
			failed = true
	print("=== RESULT: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

static func make_cfg(mode: String, seed: int, diffs: Array = [], facs: Array = [], spawn_rot: int = 0) -> Dictionary:
	var slots: Array = []
	match mode:
		"1v1":
			slots = [{"team": 0, "spawn": 0}, {"team": 1, "spawn": 1}]
		"2v2":
			slots = [{"team": 0, "spawn": 0}, {"team": 0, "spawn": 3}, {"team": 1, "spawn": 1}, {"team": 1, "spawn": 2}]
		"ffa":
			slots = [{"team": 0, "spawn": 0}, {"team": 1, "spawn": 1}, {"team": 2, "spawn": 2}, {"team": 3, "spawn": 3}]
	# seed-varied start positions for faction balance batches (FL_SPAWN_ROT set by soak)
	if spawn_rot > 0:
		var pairs := [[0, 1], [1, 0], [2, 3], [3, 2], [0, 2], [2, 0], [1, 3], [3, 1], [0, 3], [3, 0], [1, 2], [2, 1]]
		if mode == "1v1":
			var pr: Array = pairs[spawn_rot % pairs.size()]
			slots[0]["spawn"] = pr[0]
			slots[1]["spawn"] = pr[1]
		else:
			for i in slots.size():
				slots[i]["spawn"] = (int(slots[i]["spawn"]) + spawn_rot) % 4
	for i in slots.size():
		slots[i]["kind"] = "ai"
		slots[i]["color"] = i
		slots[i]["difficulty"] = diffs[i] if i < diffs.size() else "medium"
		var f: String = facs[i] if i < facs.size() else "eu"
		slots[i]["faction"] = f
		slots[i]["personality"] = String(Content.faction(StringName(f))["personality"])
	# M2.5: FL_MAP=<map id> runs soaks / tests on another skirmish map
	var map_id := OS.get_environment("FL_MAP") if OS.get_environment("FL_MAP") != "" else "varno_crossing"
	return {"map": map_id, "seed": seed, "options": {"fog": true, "start_money": 10000}, "slots": slots}

func run_match(mode: String, seed: int, verbose: bool, max_minutes: int = 40, diffs: Array = [], facs: Array = [], spawn_rot: int = 0) -> Dictionary:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg(mode, seed, diffs, facs, spawn_rot))
	var t0 := Time.get_ticks_msec()
	var max_ticks := max_minutes * 60 * 20
	var first_attack := {}
	var friendly_hits := 0
	var worst_tick_ms := 0.0
	var sum_ms := 0.0
	var built := {}   # M2.4: which unit and structure types the AI actually fields
	var kval := {}    # M2.6 balance telemetry (test-side only): enemy value killed per killer type
	var snap := ""
	while not r.sim.game_over and r.sim.tick < max_ticks:
		var a := Time.get_ticks_usec()
		r.advance()
		var dt := (Time.get_ticks_usec() - a) / 1000.0
		sum_ms += dt
		worst_tick_ms = maxf(worst_tick_ms, dt)
		for ev in r.sim.events:
			if (ev["t"] == "spawn" or ev["t"] == "site") and r.sim.ents.has(ev["id"]):
				var se: SimEntity = r.sim.ents[ev["id"]]
				if se.owner >= 0:
					built[se.def_id] = int(built.get(se.def_id, 0)) + 1
			if ev["t"] == "attacked" and int(ev["by"]) >= 0 and int(ev["owner"]) >= 0 and int(ev["by"]) != int(ev["owner"]) and not r.sim.enemies(r.sim.player_team(int(ev["by"])), r.sim.player_team(int(ev["owner"]))):
				friendly_hits += 1
			if ev["t"] == "death" and int(ev["kind"]) == SimEntity.Kind.UNIT and str(ev["by"]) != "":
				var vd = Content.units.get(ev["def"])
				if vd != null:
					kval[ev["by"]] = int(kval.get(ev["by"], 0)) + int(vd.cost)
			if ev["t"] == "attacked" and r.sim.ents.has(ev["id"]):
				var tgt: SimEntity = r.sim.ents[ev["id"]]
				if tgt.kind == SimEntity.Kind.BUILDING and not first_attack.has(ev["by"]):
					first_attack[ev["by"]] = r.sim.tick / 20
		if (r.sim.tick >= 36000 and r.sim.tick % 2400 == 0) or (r.sim.tick == max_ticks - 1):
			_stall_diag(r)
		if r.sim.tick == 6000 or r.sim.tick == 12000:
			snap += " t%d:" % (r.sim.tick / 1200)
			for p in r.sim.players:
				snap += " %s h%d" % [p.faction, int(p.stats["harvested"])]
		if verbose and r.sim.tick % 1200 == 0:
			_print_state(r)
	var secs := r.sim.tick / 20
	var res := {"mode": mode, "seed": seed, "winner": r.sim.winner_team, "secs": secs, "over": r.sim.game_over,
		"avg_tick_ms": sum_ms / maxf(1, r.sim.tick), "worst_tick_ms": worst_tick_ms, "first_base_attack_s": first_attack,
		"wall_s": (Time.get_ticks_msec() - t0) / 1000.0}
	var tl: Array = []
	for p in r.sim.players:
		tl.append(p.team)
	res["teams"] = tl
	var ok: bool = r.sim.game_over and r.sim.winner_team >= 0
	# winner must be a team that still has a non-eliminated player, and all others eliminated
	if ok:
		for p in r.sim.players:
			if (p.team == r.sim.winner_team) == p.eliminated and p.team != r.sim.winner_team:
				ok = false
			if p.team != r.sim.winner_team and not p.eliminated:
				ok = false
	if friendly_hits > 0:
		ok = false
	res["friendly_hits"] = friendly_hits
	if not ok:
		failed = true
	print("ALLY-CHECK %s seed=%d: %d damage events between allies (must be 0)" % [mode, seed, friendly_hits])
	print("MATCH %s seed=%d -> winner team %d after %d:%02d (%s) avg_tick=%.2fms worst=%.1fms first_base_attack_s=%s wall=%.1fs %s" % [
		mode, seed, r.sim.winner_team, secs / 60, secs % 60, "over" if r.sim.game_over else "TIMEOUT", res["avg_tick_ms"],
		worst_tick_ms, first_attack, res["wall_s"], "OK" if ok else "FAIL"])
	for p in r.sim.players:
		print("   P%d %s team%d elim=%s supply=%d rank=%d stats=%s" % [p.id, p.faction, p.team, p.eliminated, p.supply, p.rank, p.stats])
	var bk := built.keys()
	bk.sort()
	var parts: Array = []
	for k in bk:
		parts.append("%s=%d" % [k, built[k]])
	print("   BUILT " + " ".join(parts))
	var kv := []
	for k in kval:
		kv.append([int(kval[k]), str(k)])
	kv.sort()
	kv.reverse()
	var ks := []
	for x in kv.slice(0, 12):
		ks.append("%s=%d" % [x[1], x[0]])
	print("   KILLVALUE " + " ".join(ks))
	print("   ECON" + snap)
	res["built"] = built
	return res

## M2.6 stalemate diagnosis (test-side): what keeps the loser alive and what the winner's army does.
func _stall_diag(r: MatchRunner) -> void:
	var s := r.sim
	print("   STALL-DIAG t=%d:%02d" % [s.tick / 1200, (s.tick / 20) % 60])
	for p in s.players:
		var keep: Array = []
		var units := 0
		var army := 0
		for id in s.ids:
			var e: SimEntity = s.ents[id]
			if not e.alive or e.owner != p.id:
				continue
			if e.kind == SimEntity.Kind.BUILDING:
				var d: BuildingDef = Content.building(e.def_id)
				if d.is_hq or d.produces.size() > 0:
					keep.append("%s@%s%s" % [e.def_id, e.tile, "" if e.built else "(site)"])
			elif e.kind == SimEntity.Kind.UNIT:
				units += 1
				if not s.udef(e).tags.has("builder") and not s.udef(e).tags.has("harvester"):
					army += s.udef(e).cost
		var ai_s := ""
		if r.ais.has(p.id):
			var ai: AIPlayer = r.ais[p.id]
			var wl: Array = []
			for id in ai.bb["wave"]:
				var we := s.get_ent(id)
				if we != null:
					wl.append(we)
			ai_s = " wave_n=%d wave=%d at %s idle=%d knows=%s" % [int(ai.bb["wave_n"]), wl.size(), FX.to_tile(ai._centroid(wl)) if not wl.is_empty() else Vector2i(-1, -1),
				wl.filter(func(x): return x.is_idle()).size(), ai._knows_enemy_structure()]
			var oc := {}
			for we: SimEntity in wl:
				var o: String = we.orders[0].get("o", "?") if not we.orders.is_empty() else "idle"
				oc[o] = int(oc.get(o, 0)) + 1
			ai_s += " orders=%s threat_age=%d hunt_i=%d" % [oc, s.tick - int(ai.bb["threat_tick"]), int(ai.bb.get("hunt_i", 0))]
		print("     P%d %s $%d pop %d/%d units %d army$%d keep=%s%s" % [p.id, p.faction, p.supply, p.pop, p.pop_cap, units, army, keep, ai_s])

func _print_state(r: MatchRunner) -> void:
	var s := r.sim
	var line := "t=%d:%02d" % [s.tick / 1200, (s.tick / 20) % 60]
	for p in s.players:
		var units := 0
		var blds := 0
		var army := 0
		for id in s.ids:
			var e: SimEntity = s.ents[id]
			if e.owner == p.id:
				if e.kind == SimEntity.Kind.UNIT:
					units += 1
					if not s.udef(e).tags.has("builder") and not s.udef(e).tags.has("harvester"):
						army += s.udef(e).cost
				elif e.kind == SimEntity.Kind.BUILDING:
					blds += 1
		line += " | P%d%s $%d u%d b%d army$%d pw%d/%d r%d%s" % [p.id, "T" if p.faction == &"tpla" else "", p.supply, units, blds, army, p.power_used, p.power_prod, p.rank, " X" if p.eliminated else ""]
		if r.ais.has(p.id):
			line += " w%d" % r.ais[p.id].bb["wave_n"]
	print(line)

func test_replay() -> void:
	var cfg := make_cfg("1v1", 77)
	var a := MatchRunner.new()
	a.start(cfg)
	var hashes := {}
	for i in 9000:
		a.advance()
		if a.sim.tick % 300 == 0:
			hashes[a.sim.tick] = a.sim.state_hash()
	var b := MatchRunner.new()
	b.start(cfg)
	b.set_replay_feed(a.replay)
	var mism := 0
	for i in 9000:
		b.advance()
		if hashes.has(b.sim.tick) and hashes[b.sim.tick] != b.sim.state_hash():
			mism += 1
			if mism == 1:
				print("REPLAY first mismatch at tick ", b.sim.tick)
	print("REPLAY-HASH: %d checkpoints, %d mismatches, %d commands replayed" % [hashes.size(), mism, a.replay.size()])
	if mism > 0:
		failed = true

func test_saveload() -> void:
	var cfg := make_cfg("2v2", 5)
	var a := MatchRunner.new()
	a.start(cfg)
	for i in 6000:
		a.advance()
	var data := a.serialize()
	SaveSystem.save_suspend(data)
	var loaded := SaveSystem.load_suspend()
	if loaded.is_empty():
		print("SAVELOAD: load failed")
		failed = true
		return
	var b := MatchRunner.new()
	b.deserialize(loaded)
	var ok := b.sim.state_hash() == a.sim.state_hash()
	print("SAVELOAD: hash after load %s (tick %d)" % ["matches" if ok else "DIFFERS", b.sim.tick])
	var mism := 0
	for i in 3000:
		a.advance()
		b.advance()
		if a.sim.state_hash() != b.sim.state_hash():
			mism += 1
	print("SAVELOAD: continued 3000 ticks side by side, %d hash mismatches" % mism)
	if not ok or mism > 0:
		failed = true
	SaveSystem.clear_suspend()

## Audio v1 + voice pipeline: every sound loads, every manifest line resolves (recorded or
## placeholder), shuffle bag never repeats back-to-back, priority/cooldown rules hold.
func test_audio() -> void:
	var ad = get_node("/root/AudioDirector")
	_check(not ad.manifest.is_empty(), "voice manifest loaded")
	for b in ["Music", "SFX", "Voice", "UI"]:
		_check(AudioServer.get_bus_index(b) >= 0, "bus " + b)
	var bad: Array = []
	for d in [ad.SFX, ad.UI, ad.MUSIC, ad.AMBIENT]:
		for k in d:
			if ad.stream(d[k]) == null:
				bad.append(d[k])
	_check(bad.is_empty(), "all SFX/UI/music/ambient streams load %s" % [bad])
	var m1: AudioStream = ad.stream(ad.MUSIC["menu"])
	_check(m1 is AudioStreamOggVorbis and (m1 as AudioStreamOggVorbis).loop, "menu music loops")
	var pl_ok: bool = ad.BATTLE_PLAYLIST.size() >= 4
	for t in ad.BATTLE_PLAYLIST:
		pl_ok = pl_ok and ad.stream(t) is AudioStreamOggVorbis
	_check(pl_ok, "M2.9 battle shuffle playlist (%d tracks) loads" % ad.BATTLE_PLAYLIST.size())
	var fac_ok := true
	var seen_fac := {}
	for fac in [&"us", &"ecc", &"eu", &"tpla"]:
		var pl: Array = ad.FACTION_PLAYLISTS[fac]
		fac_ok = fac_ok and not pl.is_empty() and not seen_fac.has(pl[0])
		seen_fac[pl[0]] = true
		for t in pl:
			fac_ok = fac_ok and ResourceLoader.exists(t) and load(t) is AudioStreamOggVorbis
	ad.battle_faction = &"ecc"
	fac_ok = fac_ok and ad.battle_playlist()[0].contains("ru_steppe_march")
	ad.battle_faction = &""
	_check(fac_ok, "M3.2 faction battle music: US / Russia hard bass / Germany club / Iran war drums load")
	# M3.4: Malachi's US tracks; "Base Command" is the menu music and leads the US shuffle
	ad.battle_faction = &"us"
	var us_pl: Array = ad.battle_playlist()
	ad.battle_faction = &""
	_check(us_pl.size() == 4 and us_pl[0] == ad.MUSIC["menu"] and String(ad.MUSIC["menu"]).ends_with("us_base_command.ogg") and us_pl.all(func(x): return String(x).contains("/us_")),
		"M3.4: US plays Malachi's four tracks, Base Command first and as the menu music")
	var old_in := false
	for d in [ad.MUSIC, ad.FACTION_PLAYLISTS]:
		old_in = old_in or str(d).contains("liberty_steel") or str(d).contains("breach_point") or str(d).contains("iron_convoy")
	_check(not old_in and FileAccess.file_exists("res://audio/music/superseded/.gdignore"), "M3.4: the old US rock tracks are out of the build")
	var missing: Array = []
	var units := 0
	for fac in ad.manifest["factions"]:
		for uid in ad.manifest["factions"][fac]["units"]:
			units += 1
			var ud: Dictionary = ad.manifest["factions"][fac]["units"][uid]
			for ev in ud["events"]:
				if ad.variants(fac, ud["folder"], ev)[0].is_empty():
					missing.append("%s/%s" % [uid, ev])
			_check(Content.units.has(StringName(uid)), "manifest unit exists in content: " + uid)
	var afolders: Dictionary = ad.manifest["announcer"].get("folders", {"eu": "announcer"})
	_check(afolders.has("eu") and afolders.has("tpla") and afolders["eu"] != afolders["tpla"], "separate announcer per faction %s" % [afolders])
	var not_ai: Array = []
	for f in afolders:
		for ev in ad.manifest["announcer"].get("faction_events", {}).get(f, ad.manifest["announcer"]["events"].keys()):
			var av: Array = ad.variants("announcer", afolders[f], ev)
			if av[0].is_empty():
				missing.append("%s/%s" % [afolders[f], ev])
			elif int(av[1]) == 2:
				not_ai.append("%s/%s" % [afolders[f], ev])
	for fac in ["eu", "tpla", "us"]:
		for uid in ad.manifest["factions"][fac]["units"]:
			var ud2: Dictionary = ad.manifest["factions"][fac]["units"][uid]
			for ev in ud2["events"]:
				if int(ad.variants(fac, ud2["folder"], ev)[1]) == 2:
					not_ai.append("%s/%s" % [uid, ev])
	_check(missing.is_empty(), "every manifest line has a voice %s" % [missing])
	_check(not_ai.is_empty(), "every EU + TPLA + US line has a recorded or AI voice (no robotic fallback) %s" % [not_ai.slice(0, 8)])
	# Malachi's rule: unit / soldier voices are male only (announcers may be female)
	var female: Array = []
	var idx = JSON.parse_string(FileAccess.get_file_as_string("res://audio/voice_ai/voice_ai_index.json"))
	for l in (idx["lines"] if idx is Dictionary else []):
		var f := String(l["file"])
		if f.contains("/announcer"):
			continue
		var v := String(l.get("voice", ""))
		if v.begins_with("chatterbox/"):
			var name := v.trim_prefix("chatterbox/")
			var sh := float(name.substr(name.find("+") if name.find("+") >= 0 else name.find("-")).trim_suffix("/ar-v2").trim_suffix("st"))
			if not (name.begins_with("amir") or name.begins_with("ganji") or name.begins_with("reza")) or sh > 2.5:
				female.append(f)
		else:
			for part in v.split(","):
				var id := part.get_slice(":", 0)
				if id.length() < 2 or id[1] != "m":
					female.append(f)
	_check(female.is_empty(), "unit voice sets use male voices only (%d female/unknown lines) %s" % [female.size(), female.slice(0, 5)])
	_check(ad.manifest["factions"]["tpla"]["units"].size() == Content.TPLA_UNIT_ORDER.size(), "manifest has every TPLA unit")
	var st: Dictionary = ad.voice_status()
	print("voice status: %d of %d lines recorded, %d AI, %d placeholder, %d missing" % [st["recorded"], st["total"], st["ai"], st["placeholder"], st["missing"]])
	_check(st["total"] > 50, "manifest covers %d lines" % st["total"])
	var paths := ["a", "b", "c"]
	var last := ""
	var rep := 0
	for i in 60:
		var p: String = ad._pick("test", paths)
		if p == last:
			rep += 1
		last = p
	_check(rep == 0, "shuffle bag never repeats a line back-to-back")
	ad._variants.clear()
	_check(ad.unit_voice("eu", "eu_leopold", "select"), "select line plays")
	_check(ad.unit_voice("eu", "eu_leopold", "under_fire"), "under_fire interrupts chatter (higher priority)")
	_check(not ad.unit_voice("eu", "eu_leopold", "move"), "low-priority move does not cut an under_fire line")
	ad._unit_voice.stop()
	ad._unit_prio = 0
	_check(not ad.unit_voice("eu", "eu_leopold", "under_fire"), "under_fire respects its 14 s cooldown")
	_check(ad.announce("low_power"), "announcer plays")
	_check(not ad.announce("low_power"), "announcer cooldown")
	ad.announcer_faction = "tpla"
	ad._announcer.stop()
	_check(ad.announce("victory"), "TPLA announcer plays")
	_check(String(ad._announcer.stream.resource_path).contains("announcer_tpla"), "TPLA announcer uses its own voice: " + String(ad._announcer.stream.resource_path))
	ad.announcer_faction = "us"
	ad._announcer.stop()
	_check(ad.announce("defeat"), "US announcer plays")
	_check(String(ad._announcer.stream.resource_path).contains("announcer_us"), "US announcer uses its own voice: " + String(ad._announcer.stream.resource_path))
	ad.announcer_faction = "eu"
	_check(ad.unit_voice("tpla", "tpla_rattler", "select"), "TPLA unit voice plays")
	ad._unit_voice.stop()
	ad._unit_prio = 0
	_check(ad.unit_voice("us", "us_jtac", "select"), "US unit voice plays")
	# Malachi's own US Scout Sniper recordings (audio/voice/us/sniper): his lines win for every
	# event he recorded (all variants, more than the AI set's 4), the AI lines stay for the rest.
	ad._unit_voice.stop()
	ad._unit_prio = 0
	var sn: Dictionary = ad.manifest["factions"]["us"]["units"]["us_sniper"]
	var own := 0
	for ev in sn["events"]:
		var files: Array = []
		for n in range(1, int(ad.manifest.get("max_variants", 9)) + 1):
			if FileAccess.file_exists("res://audio/voice/us/sniper/%s_%d.ogg" % [ev, n]) or ResourceLoader.exists("res://audio/voice/us/sniper/%s_%d.ogg" % [ev, n]):
				files.append("res://audio/voice/us/sniper/%s_%d.ogg" % [ev, n])
		var sv: Array = ad.variants("us", "sniper", ev)
		if files.is_empty():
			_check(int(sv[1]) == 1 and not sv[0].is_empty(), "sniper %s keeps the AI lines (not recorded)" % ev)
		else:
			own += 1
			_check(int(sv[1]) == 0 and sv[0] == files, "sniper %s uses all %d of Malachi's lines" % [ev, files.size()])
			var seen := {}
			var prev := ""
			var back := 0
			for i in files.size() * 12:
				var pk: String = ad._pick("sniper_test/" + ev, sv[0])
				seen[pk] = true
				if pk == prev:
					back += 1
				prev = pk
			_check(seen.size() == files.size() and back == 0, "sniper %s rotates through every variant, no back-to-back repeat" % ev)
			_check(ad.stream(files[-1]) != null, "sniper %s_%d loads" % [ev, files.size()])
	_check(own >= 4, "Malachi recorded %d sniper events" % own)
	_check(tr("CREDITS_BODY").contains("US Scout Sniper voiced by Malachi Murphy"), "credits name Malachi as the US Scout Sniper voice")
	# M3.5: credits name all four factions, carry no hard-coded milestone, credit Malachi's music; no stale menu subtitle
	var cb := tr("CREDITS_BODY")
	_check(cb.contains("United States, Russia, Germany and Iran") and not cb.contains("Milestone") and cb.contains("original music by Malachi Murphy"), "credits list all four factions, no milestone, Malachi's music")
	_check(tr("MENU_SUBTITLE") == "MENU_SUBTITLE", "stale MENU_SUBTITLE string is gone")
	_check(ad.unit_voice("us", "us_sniper", "select") and String(ad._unit_voice.stream.resource_path).begins_with("res://audio/voice/us/sniper/"), "sniper select plays Malachi's voice")
	ad._unit_voice.stop()
	ad._unit_prio = 0
	_check(ad.weapon_sfx("tpla", "rocket", false) == "tpla_rpg" and ad.stream(ad.SFX["tpla_rpg"]) != null, "TPLA weapon SFX mapped and loadable")

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failed = true

## Zero Hour build rules: no build radius; blocked by terrain, overlap, shroud, reachability.
func test_placement() -> void:
	var r := MatchRunner.new()
	r.record_replay = false
	var cfg := make_cfg("1v1", 3)
	r.start(cfg)
	var w := r.sim
	var hq: SimEntity = null
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.owner == 0 and e.kind == SimEntity.Kind.BUILDING:
			hq = e
	var ht := FX.to_tile(hq.pos)
	# 1. far from the HQ (no grid / radius) on explored ground -> valid
	var far := Vector2i(-1, -1)
	var best := 0
	for y in range(2, w.map.h - 4):
		for x in range(2, w.map.w - 4):
			var t := Vector2i(x, y)
			var dd := (t - ht).length_squared()
			if dd > best and dd < 40 * 40 and w.fog.explored_tile(0, t) and w.can_place(0, &"eu_reactor", t) == "":
				best = dd
				far = t
	var ex: PackedByteArray = w.fog.explored[0]
	ex.fill(1)
	w.fog.explored[0] = ex
	var far2 := Vector2i(-1, -1)
	for y in range(2, w.map.h - 4):
		for x in range(2, w.map.w - 4):
			var t2 := Vector2i(x, y)
			if (t2 - ht).length() > 45 and w.can_place(0, &"eu_reactor", t2) == "":
				far2 = t2
				break
		if far2.x >= 0:
			break
	_check(far2.x >= 0, "explored ground 45+ tiles from the HQ is buildable (no build radius) at %s" % far2)
	# 2. water / cliff -> terrain
	var water := Vector2i(-1, -1)
	for i in w.map.w * w.map.h:
		if w.map.tiles[i] == SimMap.T.WATER:
			water = Vector2i(i % w.map.w, i / w.map.w)
			break
	_check(w.can_place(0, &"eu_reactor", water) in ["REASON_TERRAIN", "REASON_BLOCKED", "REASON_RESOURCE"], "water is not buildable (%s)" % w.can_place(0, &"eu_reactor", water))
	# 3. overlapping the HQ -> blocked
	_check(w.can_place(0, &"eu_reactor", hq.tile) == "REASON_BLOCKED", "overlapping a building is blocked")
	# 4. unexplored shroud is buildable too (user rule: no build range of any kind)
	var r2 := MatchRunner.new()
	r2.record_replay = false
	r2.start(make_cfg("1v1", 3))
	var w2 := r2.sim
	var sh := Vector2i(-1, -1)
	for i in w2.map.w * w2.map.h:
		var t3 := Vector2i(i % w2.map.w, i / w2.map.w)
		if not w2.fog.explored_tile(0, t3) and SimMap.BUILD_OK[w2.map.tiles[i]] and w2.map.nobuild[i] == 0 and t3.x > 2 and t3.y > 2 and t3.x < w2.map.w - 6 and t3.y < w2.map.h - 6 \
				and w2.can_place(0, &"eu_reactor", t3) == "":
			sh = t3
			break
	_check(sh.x >= 0, "unexplored shroud is buildable (%s)" % sh)
	# 5. a placed far site is actually built by the Crawler driving there
	var crawler: SimEntity = null
	for id in w.ids:
		var e2: SimEntity = w.ents[id]
		if e2.owner == 0 and e2.kind == SimEntity.Kind.UNIT and w.udef(e2).tags.has("builder"):
			crawler = e2
	var site := far if far.x >= 0 else far2
	r.issue({"p": 0, "t": "place", "ids": [crawler.id], "def": "eu_reactor", "tile": site, "rot": 0})
	var built := false
	for i in 20 * 120:
		r.advance()
		var occ := w.map.occ[w.map.idx(site)]
		if occ != 0 and w.get_ent(occ) != null and w.get_ent(occ).owner == 0 and w.get_ent(occ).built:
			built = true
			break
	_check(built, "Crawler drives %d tiles and finishes a Reactor away from the base" % int((site - ht).length()))
	print("=== RESULT: %s" % ("FAIL" if failed else "PASS"))

## No build range at all: from the start of a match, with fog on, a builder of each faction
## can be sent to all four far corners of the map (black shroud); one far-corner site is then
## actually driven to and finished. Unreachable spots report REASON_UNREACHABLE.
func test_corners() -> void:
	for fac in ["eu", "tpla"]:
		var r := MatchRunner.new()
		r.record_replay = false
		r.start(make_cfg("1v1", 5, ["medium", "medium"], [fac, "eu"]))
		r.ais.clear()   # no AI on either side: this checks placement and driving, not survival
		var w := r.sim
		var bid: StringName = &"eu_reactor" if fac == "eu" else &"tpla_camp"
		var builder: SimEntity = null
		var home := Vector2i.ZERO
		for id in w.ids:
			var e: SimEntity = w.ents[id]
			if e.owner == 0 and e.kind == SimEntity.Kind.UNIT and w.udef(e).tags.has("builder"):
				builder = e
			if e.owner == 0 and e.kind == SimEntity.Kind.BUILDING:
				home = e.tile
		var fp: Vector2i = Content.building(bid).footprint
		var corners := [Vector2i(2, 2), Vector2i(w.map.w - 3 - fp.x, 2), Vector2i(2, w.map.h - 3 - fp.y), Vector2i(w.map.w - 3 - fp.x, w.map.h - 3 - fp.y)]
		var far_site := Vector2i(-1, -1)
		var far_d := -1.0
		for c: Vector2i in corners:
			# nearest valid spot to the corner (corners can hold a cliff, river or decor)
			var spot := Vector2i(-1, -1)
			var reason := ""
			for rr in 14:
				for yy in range(-rr, rr + 1):
					for xx in range(-rr, rr + 1):
						if spot.x >= 0 or maxi(absi(xx), absi(yy)) != rr:
							continue
						var t := c + Vector2i(xx, yy)
						var why := w.can_place(0, bid, t, true, [builder.id])
						if why == "":
							spot = t
						elif reason == "":
							reason = why
			var shroud := spot.x >= 0 and not w.fog.explored_tile(w.players[0].team, spot)
			_check(spot.x >= 0 and shroud, "%s: %s placeable in black shroud near corner %s at %s, %d tiles from base (first reject seen: %s)" % [fac, bid, c, spot, int((spot - home).length()), reason])
			if spot.x >= 0 and (spot - home).length() > far_d:
				far_d = (spot - home).length()
				far_site = spot
		# drive to the farthest corner and build it
		w.players[0].supply = 50000
		r.issue({"p": 0, "t": "place", "ids": [builder.id], "def": String(bid), "tile": far_site, "rot": 0})
		var built := false
		for i in 20 * 600:
			r.advance()
			var occ := w.map.occ[w.map.idx(far_site)]
			if occ != 0 and w.get_ent(occ) != null and w.get_ent(occ).owner == 0 and w.get_ent(occ).built:
				built = true
				print("  built after %d s" % (i / 20))
				break
		_check(built, "%s builder drives %d tiles into the far corner and finishes the %s (builder alive=%s at %s, orders=%s)" % [fac, int(far_d), bid, builder.alive, FX.to_tile(builder.pos), builder.orders])
		# a water tile reports a reason, never silently refuses
		var water := Vector2i(-1, -1)
		for i in w.map.w * w.map.h:
			if w.map.tiles[i] == SimMap.T.WATER:
				water = Vector2i(i % w.map.w, i / w.map.w)
				break
		var wr := w.can_place(0, bid, water, true, [builder.id])
		_check(wr != "" and TranslationServer.translate(wr) != wr, "%s: water gives a readable reason (%s = '%s')" % [fac, wr, tr(wr)])
	print("=== RESULT: %s" % ("FAIL" if failed else "PASS"))

## Zero Hour scaffolds: an interrupted build pauses and keeps its progress; a resume order
## finishes it; a second builder does not speed it up; the AI resumes its own scaffolds.
## M3.1: builders repair a damaged own structure (US Dozer, German crane, Iran Backhoe): gradual
## HP restore, pays ~25 % of the price for a full repair, stops at full HP, waits without money.
func _test_repair() -> void:
	for fac in ["us", "eu", "tpla"]:
		var r := MatchRunner.new()
		r.record_replay = false
		r.start(make_cfg("1v1", 9, ["medium", "medium"], [fac, "eu"]))
		r.ais.clear()
		var w := r.sim
		var hq: SimEntity = null
		var bu: SimEntity = null
		var bdef: StringName = Content.faction(StringName(fac))["builder"]
		for id in w.ids:
			var e: SimEntity = w.ents[id]
			if e.owner == 0 and e.kind == SimEntity.Kind.BUILDING and e.built and hq == null:
				hq = e
			if e.owner == 0 and e.def_id == bdef:
				bu = e
		if hq == null or bu == null:
			_check(false, "%s: repair test setup (hq %s builder %s)" % [fac, hq, bu])
			continue
		hq.hp = hq.max_hp / 2
		w.players[0].supply = 0
		r.issue({"p": 0, "t": "repair", "ids": [bu.id], "target": hq.id})
		for i in 20 * 15:
			r.advance()
		_check(hq.hp < hq.max_hp / 2 + hq.max_hp / 40 and w.players[0].supply == 0 and not bu.orders.is_empty() and bu.orders[0].get("o", "") == "repair", "%s: without money the builder waits at the damaged structure (hp %d/%d)" % [fac, hq.hp, hq.max_hp])
		w.players[0].supply = 10000
		var t := 0
		var mid := -1
		while hq.hp < hq.max_hp and t < 20 * 60:
			r.advance()
			t += 1
			if t == 20 * 5:
				mid = hq.hp
		var paid: int = 10000 - int(w.players[0].supply)
		var want: int = Content.building(hq.def_id).cost * OrderSys.REPAIR_COST_PCT / 100 / 2
		_check(hq.hp == hq.max_hp, "%s: repair brings the structure back to full HP (%d/%d after %d ticks)" % [fac, hq.hp, hq.max_hp, t])
		_check(mid > hq.max_hp / 2 and mid < hq.max_hp, "%s: repair is gradual (hp %d after 5 s)" % [fac, mid])
		_check(absi(paid - want) <= 2, "%s: half a repair costs ~%d supply (paid %d)" % [fac, want, paid])
		for i in 5:
			r.advance()
		_check(bu.orders.is_empty(), "%s: builder's repair order ends at full HP" % fac)

func test_resume() -> void:
	_test_repair()
	for fac in ["eu", "tpla"]:
		var r := MatchRunner.new()
		r.record_replay = false
		r.start(make_cfg("1v1", 7, ["medium", "medium"], [fac, "eu"]))
		r.ais.clear()
		var w := r.sim
		w.players[0].supply = 50000
		var bid: StringName = &"eu_reactor" if fac == "eu" else &"tpla_camp"
		var builders: Array = []
		var home := Vector2i.ZERO
		for id in w.ids:
			var e: SimEntity = w.ents[id]
			if e.owner == 0 and e.kind == SimEntity.Kind.BUILDING:
				home = e.tile
		# a second builder
		var bdef: StringName = Content.faction(StringName(fac))["builder"]
		for id in w.ids:
			var e2: SimEntity = w.ents[id]
			if e2.owner == 0 and e2.def_id == bdef:
				builders.append(e2)
		var extra := w.spawn_unit(bdef, 0, null, builders[0].pos + Vector2i(FX.ONE * 2, 0))
		if extra != null:
			builders.append(extra)
		var spot := Vector2i(-1, -1)
		for rr in range(4, 20):
			for dx in range(-rr, rr + 1):
				if spot.x < 0 and w.can_place(0, bid, home + Vector2i(dx, rr), true, [builders[0].id]) == "":
					spot = home + Vector2i(dx, rr)
		r.issue({"p": 0, "t": "place", "ids": [builders[0].id], "def": String(bid), "tile": spot, "rot": 0})
		r.advance()
		var site: SimEntity = w.get_ent(w.map.occ[w.map.idx(spot)])
		var t0 := 0
		while site.progress == 0 and t0 < 20 * 60:
			r.advance()
			t0 += 1
		for i in 40:
			r.advance()
		r.issue({"p": 0, "t": "stop", "ids": [builders[0].id]})
		r.advance()
		var p1 := site.progress
		for i in 200:
			r.advance()
		_check(not site.built and site.progress == p1 and p1 > 0, "%s: interrupted build stays a scaffold (progress %d kept, unchanged)" % [fac, p1])
		# resume with two builders: progress rate must equal one builder (Zero Hour)
		var ids2: Array = []
		for b in builders:
			ids2.append(b.id)
		r.issue({"p": 0, "t": "resume_build", "ids": ids2, "target": site.id})
		var t1 := 0
		var p2 := site.progress
		while site.progress == p2 and t1 < 20 * 60:
			r.advance()
			t1 += 1
		var p3 := site.progress
		for i in 40:
			r.advance()
		_check(builders.size() < 2 or site.built or site.progress - p3 == 40, "%s: two builders build at one builder's speed (+%d in 40 ticks, %d builders)" % [fac, site.progress - p3, builders.size()])
		var t2 := 0
		while not site.built and t2 < 20 * 300:
			r.advance()
			t2 += 1
		_check(site.built, "%s: resumed scaffold is finished" % fac)
		# the AI resumes its own scaffold
		var r2 := MatchRunner.new()
		r2.record_replay = false
		r2.start(make_cfg("1v1", 8, ["medium", "medium"], [fac, "eu"]))
		var w2 := r2.sim
		for i in 20 * 90:
			r2.advance()
		var site2: SimEntity = null
		for i in 20 * 120:
			r2.advance()
			for id in w2.ids:
				var s2: SimEntity = w2.ents[id]
				if s2.owner == 0 and s2.kind == SimEntity.Kind.BUILDING and not s2.built and s2.progress > 0:
					site2 = s2
			if site2 != null:
				break
		if site2 == null:
			_check(false, "%s AI: found an AI construction site to interrupt" % fac)
			continue
		var stop_ids: Array = []
		for id in w2.ids:
			var u: SimEntity = w2.ents[id]
			if u.owner == 0 and u.kind == SimEntity.Kind.UNIT and not u.orders.is_empty() and u.orders[0].get("o", "") == "build" and int(u.orders[0]["target"]) == site2.id:
				stop_ids.append(u.id)
		r2.issue({"p": 0, "t": "stop", "ids": stop_ids})
		var done := false
		for i in 20 * 240:
			r2.advance()
			if site2.built:
				done = true
				break
		_check(done, "%s AI resumes its own interrupted scaffold (%s)" % [fac, site2.def_id])
	print("=== RESULT: %s" % ("FAIL" if failed else "PASS"))

func test_content() -> void:
	print("CONTENT: %d units, %d buildings, %d weapons, %d powers, %d maps, errors=%s" % [Content.units.size(),
		Content.buildings.size(), Content.weapons.size(), Content.powers.size(), Content.maps.size(), Content.errors])
	if not Content.errors.is_empty():
		failed = true
	# CSV drift check: every CSV value must equal the loaded .tres value
	if not FileAccess.file_exists("res://data/balance/units.csv"):
		print("CONTENT: balance CSVs not packaged in this build (export) - drift check skipped")
		return
	var drift := 0
	var f := FileAccess.open("res://data/balance/units.csv", FileAccess.READ)
	var header := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size():
			continue
		var u: UnitDef = Content.unit(row[0])
		if u == null:
			drift += 1
			continue
		for c in ["cost", "build_time_ms", "max_hp", "speed_mtps", "sight", "pop"]:
			if str(u.get(c)) != row[header.find(c)]:
				drift += 1
				print("DRIFT ", row[0], " ", c)
	f = FileAccess.open("res://data/balance/buildings.csv", FileAccess.READ)
	header = f.get_csv_line()
	while not f.eof_reached():
		var row2 := f.get_csv_line()
		if row2.size() < header.size():
			continue
		var b: BuildingDef = Content.building(row2[0])
		if b == null:
			drift += 1
			continue
		for c in ["cost", "build_time_ms", "max_hp", "power", "grid_radius"]:
			if str(b.get(c)) != row2[header.find(c)]:
				drift += 1
				print("DRIFT ", row2[0], " ", c)
	print("CONTENT: balance CSV vs .tres drift = %d" % drift)
	if drift > 0:
		failed = true
	var rng := PCG32.new()
	rng.seed(42, 54)
	var seq := []
	for i in 3:
		seq.append(rng.next_u32())
	print("PCG32 seed(42,54) first outputs: ", seq, " (reference 0xa15c02b7=", 0xa15c02b7, ", 0x7b47f409=", 0x7b47f409, ")")
	if seq[0] != 0xa15c02b7 or seq[1] != 0x7b47f409:
		failed = true

# ------------------------------------------------------------------ M2: TPLA mechanics
func _tpla_spot(w: SimWorld, pid: int, def_id: StringName, near: Vector2i, skip: int = 0) -> Vector2i:
	var found := 0
	for r in range(3, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var t := near + Vector2i(dx, dy)
				if w.can_place(pid, def_id, t, false) == "":
					if found == skip:
						return t
					found += 1
	return Vector2i(-1, -1)

func _tpla_place(w: SimWorld, pid: int, def_id: StringName, near: Vector2i, skip: int = 0) -> SimEntity:
	var t := _tpla_spot(w, pid, def_id, near, skip)
	if t.x < 0:
		return null
	return w._place_building(Content.building(def_id), pid, t, 0, true)

func _ticks(r: MatchRunner, n: int) -> void:
	for i in n:
		r.advance()

## M2.9 TPLA roster mechanics: Marksman hidden unless shooting, Insurgent always hidden,
## Koksan waits its 5 s setup before the first shot.
## M2.9: the TPLA AI fills its Airfield with jets and flies fighters at enemy aircraft over the base.
func _m29_tpla_air() -> void:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", 30, ["hard", "hard"], ["tpla", "eu"]))
	r.ais.erase(1)
	var w := r.sim
	var ai: AIPlayer = r.ais[0]
	w.players[0].supply = 40000
	var base: Vector2i = ai.base_pos()
	var placed := {}
	for id in [&"tpla_chop_shop", &"tpla_workshop", &"tpla_airfield"]:
		var bd: BuildingDef = Content.building(id)
		var bt := FX.to_tile(base)
		var spot := Vector2i(-1, -1)
		for rr in range(6, 60):
			for dy in range(-rr, rr + 1):
				for dx in range(-rr, rr + 1):
					if spot.x >= 0 or maxi(absi(dx), absi(dy)) != rr:
						continue
					var t := bt + Vector2i(dx, dy)
					var ok := true
					for yy in bd.footprint.y + 2:
						for xx in bd.footprint.x + 2:
							var c := t + Vector2i(xx - 1, yy - 1)
							ok = ok and w.map.in_bounds(c) and w.map.passable(c, true) and w.map.occ[c.y * w.map.w + c.x] == 0
					if ok:
						spot = t
		placed[id] = w._place_building(bd, 0, spot, 0, true)
	_ticks(r, 2400)
	var jets: Array = []
	for e: SimEntity in w.ents.values():
		if e.alive and e.owner == 0 and e.kind == SimEntity.Kind.UNIT and w.udef(e).tags.has("jet"):
			jets.append(e)
	_check(jets.size() >= 2, "TPLA AI builds jets at its Airfield (%d)" % jets.size())
	var res: Dictionary = ai._reserved_ids()
	var kept := true
	for j: SimEntity in jets:
		kept = kept and res.has(j.id) and not ai.bb["wave"].has(j.id)
	_check(kept, "TPLA jets stay out of the ground waves")
	var bandit := w.spawn_unit(&"us_wraith", 1, null, placed[&"tpla_airfield"].pos + Vector2i(FX.ONE * 6, 0))
	var engaged := false
	for i in 40:
		_ticks(r, 15)
		for j: SimEntity in jets:
			if j.alive and j.target == bandit.id:
				engaged = true
		if engaged or not bandit.alive:
			break
	_check(engaged or not bandit.alive, "TPLA fighters scramble at an enemy jet over the base")

func _m29_tpla() -> void:
	var r := _zh_runner(29)
	var w := r.sim
	var c := _zh_open(w, 7)
	var mk := w.spawn_unit(&"tpla_marksman", 1, null, FX.tile_center(c))
	var ins := w.spawn_unit(&"tpla_insurgent", 1, null, FX.tile_center(c + Vector2i(2, 0)))
	_ticks(r, 80)
	_check(mk.stealthy and ins.stealthy, "Marksman and Insurgent are hidden while not shooting")
	var dummy := w.spawn_unit(&"eu_crawler", 0, null, FX.tile_center(c + Vector2i(0, 6)))
	dummy.max_hp = 100000
	dummy.hp = 100000
	r.issue({"p": 1, "t": "attack", "ids": [mk.id], "target": dummy.id})
	var seen := false
	for i in 120:
		r.advance()
		if not mk.stealthy:
			seen = true
	_check(seen and dummy.hp < 100000 and ins.stealthy, "Marksman is revealed when he fires; the Insurgent stays hidden")
	mk.alive = false
	var ks := w.spawn_unit(&"tpla_blight", 1, null, FX.tile_center(c + Vector2i(0, -6)))
	ks.pos = FX.tile_center(c + Vector2i(0, -6))
	var d2 := w.spawn_unit(&"eu_crawler", 0, null, FX.tile_center(c + Vector2i(0, 5)))
	d2.max_hp = 100000
	d2.hp = 100000
	r.issue({"p": 1, "t": "attack", "ids": [ks.id], "target": d2.id})
	var first := -1
	for i in 400:
		r.advance()
		if first < 0 and ks.firing_tick > 0 and ks.firing_tick >= w.tick - 1:
			first = i
	_check(first >= UsSys.SETUP_TICKS - 2, "Koksan sets up for 5 s before its first shot (first shot after %d ticks)" % first)

func test_tpla() -> void:
	_m29_tpla()
	_m29_tpla_air()
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", 11, [], ["tpla", "eu"]))
	r.ais.clear()   # scripted test: no AI orders
	var w := r.sim
	var ex: PackedByteArray = w.fog.explored[0]
	ex.fill(1)
	w.fog.explored[0] = ex
	var den: SimEntity = null
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.owner == 0 and e.def_id == &"tpla_den":
			den = e
	_check(den != null and w.faction_of(0) == &"tpla" and w.has_tpla, "TPLA player starts with a Den")
	var base := FX.to_tile(den.pos)
	w.players[0].supply = 20000
	# --- M3.3: TPLA (Iran) runs on Gas Turbine Plants like the other factions' power plants
	var camp := _tpla_place(w, 0, &"tpla_camp", base)
	_tpla_place(w, 0, &"tpla_chop_shop", base)
	_ticks(r, 2)
	var p0: SimPlayer = w.players[0]
	_check(Content.faction(&"tpla")["power"] and p0.low_power, "TPLA goes into low power without a Gas Turbine Plant (prod=%d used=%d)" % [p0.power_prod, p0.power_used])
	_tpla_place(w, 0, &"tpla_gas_plant", base)
	_ticks(r, 12)
	_check(not p0.low_power and p0.power_prod == 5 + 8, "a Gas Turbine Plant powers the base (prod=%d used=%d low=%s)" % [p0.power_prod, p0.power_used, p0.low_power])
	r.issue({"p": 0, "t": "queue", "target": camp.id, "def": "tpla_militia", "n": 3})
	_ticks(r, 20 * 20)
	var mil: Array = []
	for id in w.ids:
		var e2: SimEntity = w.ents[id]
		if e2.alive and e2.owner == 0 and e2.def_id == &"tpla_militia":
			mil.append(e2)
	_check(mil.size() == 3, "camp trains militia at full speed on gas power (%d)" % mil.size())
	# --- M2.9: Pickups gather, the Backhoe builds (separate jobs)
	var lab: SimEntity = null
	var hoe: SimEntity = null
	for id in w.ids:
		var e3: SimEntity = w.ents[id]
		if e3.alive and e3.owner == 0 and e3.def_id == &"tpla_pickup":
			lab = e3
		if e3.alive and e3.owner == 0 and e3.def_id == &"tpla_backhoe":
			hoe = e3
	var pk: UnitDef = Content.unit(&"tpla_pickup")
	var bh: UnitDef = Content.unit(&"tpla_backhoe")
	_check(lab != null and hoe != null and bh.harvest_capacity == 0 and not bh.tags.has("harvester") and pk.harvest_capacity > 0 and not pk.tags.has("builder"),
		"TPLA starts with a Backhoe (builds, never gathers) and a Pickup (gathers, never builds)")
	_tpla_place(w, 0, &"tpla_stash", FX.to_tile(EconSys.nearest_resource(w, den.pos).pos))   # pickups drop off at a Supply Stash
	var h0: int = p0.stats["harvested"]
	var res := EconSys.nearest_resource(w, den.pos)
	r.issue({"p": 0, "t": "harvest", "ids": [lab.id], "target": res.id})
	_ticks(r, 20 * 60)
	_check(p0.stats["harvested"] > h0, "Pickup harvests into a Supply Stash (+%d)" % (p0.stats["harvested"] - h0))
	# --- tunnel network
	var ta := _tpla_place(w, 0, &"tpla_tunnel", base)
	var tb := _tpla_place(w, 0, &"tpla_tunnel", base + Vector2i(14, 0) if w.map.in_bounds(base + Vector2i(14, 0)) else base - Vector2i(14, 0), 0)
	_check(ta != null and tb != null and ta.id != tb.id, "two tunnels placed")
	var ids: Array = []
	for u: SimEntity in mil:
		ids.append(u.id)
	r.issue({"p": 0, "t": "garrison", "ids": ids, "target": ta.id})
	_ticks(r, 20 * 25)
	_check(TplaSys.network_units(w, 0).size() == 3, "3 militia entered the tunnel network (%d)" % TplaSys.network_units(w, 0).size())
	for u: SimEntity in mil:
		u.hp = u.max_hp / 3
	_ticks(r, 20 * 6)
	_check(mil[0].hp > mil[0].max_hp / 3, "units heal inside the network (%d/%d)" % [mil[0].hp, mil[0].max_hp])
	r.issue({"p": 0, "t": "unload", "ids": [tb.id]})
	_ticks(r, 2)
	var near_b := true
	for u: SimEntity in mil:
		near_b = near_b and u.res_id == 0 and FX.dist(u.pos, tb.pos) < FX.ONE * 6
	_check(near_b, "evacuating at the other tunnel brings everyone out there (shared network)")
	r.issue({"p": 0, "t": "garrison", "ids": ids, "target": tb.id})
	_ticks(r, 20 * 10)
	w._kill(tb, null)
	_ticks(r, 2)
	_check(TplaSys.network_units(w, 0).size() == 3 and mil[0].res_id == -ta.id, "losing one tunnel moves the garrison to the next")
	w._kill(ta, null)
	_ticks(r, 2)
	var dead := 0
	for u: SimEntity in mil:
		if not u.alive:
			dead += 1
	_check(dead == 3, "losing the last tunnel kills the units inside (%d)" % dead)
	# --- salvage
	var rat := w.spawn_unit(&"tpla_rattler", 0, null, FX.tile_center(base + Vector2i(0, 6)))
	_ticks(r, 2)
	var hp0 := rat.max_hp
	TplaSys.spawn_crate(w, rat.pos, 150)
	_ticks(r, 25)
	_check(rat.tier == 1 and rat.max_hp > hp0, "salvage vehicle picks up a crate: tier %d, HP %d -> %d" % [rat.tier, hp0, rat.max_hp])
	TplaSys.spawn_crate(w, rat.pos, 150)
	_ticks(r, 25)
	TplaSys.spawn_crate(w, rat.pos, 150)
	_ticks(r, 25)
	TplaSys.spawn_crate(w, rat.pos, 150)
	# count only the crate's cash (Laborers keep harvesting in the background, so the raw
	# Supply delta also contains harvest income)
	var cash := 0
	var s0: int = p0.supply
	for i in 25:
		r.advance()
		for ev in w.events:
			if ev["t"] == "crate_cash" and int(ev["id"]) == rat.id:
				cash += int(ev["amount"])
	_check(rat.tier == 3 and cash == 150 and p0.supply - s0 >= 150, "tier caps at 3, extra crates become Supply (tier %d, crate +%d, Supply +%d incl. harvest)" % [rat.tier, cash, p0.supply - s0])
	var eu_tank := w.spawn_unit(&"eu_leopold", 1, null, FX.tile_center(base + Vector2i(8, 8)))
	_ticks(r, 1)
	var crates0 := 0
	for id in w.ids:
		if w.ents[id].alive and w.ents[id].kind == SimEntity.Kind.CRATE:
			crates0 += 1
	w._kill(eu_tank, rat)
	_ticks(r, 2)
	var crates1 := 0
	for id in w.ids:
		if w.ents[id].alive and w.ents[id].kind == SimEntity.Kind.CRATE:
			crates1 += 1
	_check(crates1 == crates0 + 1, "destroyed vehicles drop a salvage crate")
	# --- rebuild hole
	var camp2 := _tpla_place(w, 0, &"tpla_camp", base, 3)
	var ct := camp2.tile
	w._kill(camp2, null)
	_ticks(r, 3)
	var hole: SimEntity = null
	for id in w.ids:
		var e4: SimEntity = w.ents[id]
		if e4.alive and e4.def_id == &"tpla_hole" and e4.tile == ct:
			hole = e4
	_check(hole != null and hole.aux_def == &"tpla_camp", "destroyed TPLA structure leaves a rebuild hole")
	_ticks(r, TplaSys.HOLE_DELAY + 30)
	var site: SimEntity = null
	for id in w.ids:
		var e5: SimEntity = w.ents[id]
		if e5.alive and e5.def_id == &"tpla_camp" and e5.tile == ct:
			site = e5
	if site == null:
		for id in w.ids:
			var e9: SimEntity = w.ents[id]
			if e9.alive and e9.kind == SimEntity.Kind.BUILDING and e9.owner == 0:
				print("   dbg bld ", e9.def_id, " tile=", e9.tile, " built=", e9.built, " aux_t=", e9.aux_t, " tick=", w.tick)
		print("   dbg ct=", ct)
	_check(site != null, "a Backhoe climbs out of the hole and starts rebuilding")
	_ticks(r, 20 * 15)
	_check(site != null and site.built, "the structure is rebuilt for free")
	# --- demo trap + stealth
	var trap := _tpla_place(w, 0, &"tpla_demo_trap", base + Vector2i(-8, -8))
	_ticks(r, 25)
	_check(trap.stealthy and not w.fog.is_visible_ent(w, 1, trap), "Demo Trap is hidden from the enemy")
	_check(w.fog.is_visible_ent(w, 0, trap), "the owner still sees the trap")
	var gren := w.spawn_unit(&"eu_grenadier", 1, null, trap.pos + Vector2i(FX.ONE, 0))
	_ticks(r, 10)
	_check(not trap.alive and (not gren.alive or gren.hp < gren.max_hp), "enemy infantry walking onto the trap sets it off")
	var net := _tpla_place(w, 0, &"tpla_camo_net", base + Vector2i(-4, 8))
	_ticks(r, 5)
	var hidden := 0
	for id in w.ids:
		var e6: SimEntity = w.ents[id]
		if e6.alive and e6.owner == 0 and e6.kind == SimEntity.Kind.BUILDING and e6.stealthy:
			hidden += 1
	_check(net != null and hidden >= 1, "Camo Net hides structures under it (%d hidden)" % hidden)


# ---------------------------------------------------------------- M2.3 Zero Hour feel
## Scripted world for ZH-feel tests: no AI, map fully explored for player 0.
func _zh_runner(seed: int = 31) -> MatchRunner:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", seed, [], ["eu", "tpla"]))
	r.ais.clear()
	return r

## A tile with a clear, full-speed vehicle corridor of `n` tiles going +y (and 3 wide).
func _zh_open(w: SimWorld, n: int) -> Vector2i:
	for rr in 40:
		for dx in range(-rr, rr + 1):
			for dy in [-rr, rr]:
				var t := Vector2i(w.map.w / 2 + dx, w.map.h / 2 + dy)
				var ok := true
				for k in range(-n, n + 1):
					for side in range(-2, 3):
						var tt := t + Vector2i(side, k)
						if not w.map.passable(tt, true) or w.map.speed_pct(tt, true) != 100 or w.map.occ[tt.y * w.map.w + tt.x] != 0:
							ok = false
				if ok:
					return t
	return Vector2i(-1, -1)

func _zh_move_ticks(r: MatchRunner, u: SimEntity, dest: Vector2i, limit: int = 400) -> int:
	r.issue({"p": u.owner, "t": "move", "ids": [u.id], "pos": dest})
	for i in limit:
		r.advance()
		if u.goal == Vector2i(-1, -1) and u.orders.is_empty():
			return i + 1
	return limit

func test_zh() -> void:
	_zh_loco()
	_zh_weapons()
	_zh_scatter()
	_zh_victims()
	_zh_group()

func _zh_loco() -> void:
	var r := _zh_runner()
	var w := r.sim
	var c := _zh_open(w, 7)
	_check(c.x >= 0, "found an open test corridor %s" % [c])
	var res := {}
	for def in ["eu_leopold", "eu_grenadier", "tpla_rattler"]:
		var u := w.spawn_unit(StringName(def), 0, null, FX.tile_center(c + Vector2i(0, -5)))
		u.pos = FX.tile_center(c + Vector2i(0, -5))
		var d := Content.unit(StringName(def))
		var full := FX.speed_per_tick(d.speed_mtps)
		# 1) acceleration from rest straight ahead (+y = initial heading)
		r.issue({"p": 0, "t": "move", "ids": [u.id], "pos": FX.tile_center(c + Vector2i(0, 5))})
		_ticks(r, 5)
		var early := u.spd
		var arrive := 0
		for i in 400:
			r.advance()
			if u.goal == Vector2i(-1, -1) and u.orders.is_empty():
				arrive = i + 6
				break
		# 2) reverse direction: must turn 180 degrees first
		var back := _zh_move_ticks(r, u, FX.tile_center(c + Vector2i(0, -5)))
		var ideal := 10 * FX.ONE / full
		res[def] = {"early": early, "full": full, "fwd": arrive, "back": back, "ideal": ideal, "face": u.face}
		print("  loco %s kind=%s: speed after 5 ticks %d/%d, 10 tiles fwd %d ticks, reverse+10 tiles %d ticks (instant-turn ideal %d)" % [def, Loco.params(d)["kind"], early, full, arrive, back, ideal])
		u.hp = 0
		_ticks(r, 2)
	var tk: Dictionary = res["eu_leopold"]
	var inf: Dictionary = res["eu_grenadier"]
	var wh: Dictionary = res["tpla_rattler"]
	_check(tk["early"] < tk["full"], "tank accelerates over time (%d < %d after 5 ticks)" % [tk["early"], tk["full"]])
	_check(inf["early"] >= inf["full"] * 9 / 10, "infantry reaches speed almost instantly")
	_check(tk["back"] - tk["fwd"] >= 25, "tank pivots before reversing (+%d ticks)" % [tk["back"] - tk["fwd"]])
	_check(inf["back"] - inf["fwd"] <= 8, "infantry turns on the spot (+%d ticks)" % [inf["back"] - inf["fwd"]])
	_check(wh["back"] > wh["fwd"], "wheeled unit loses time turning around (+%d ticks)" % [wh["back"] - wh["fwd"]])
	_check(absi(FX.adiff(tk["face"], 512)) <= 8, "tank ends facing its travel direction (face=%d)" % tk["face"])
	# damaged vehicles are slower
	var u2 := w.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(c))
	var m_ok := Loco.max_step(w, u2, Content.unit(&"eu_leopold"))
	u2.hp = u2.max_hp / 4
	var m_dmg := Loco.max_step(w, u2, Content.unit(&"eu_leopold"))
	_check(m_dmg < m_ok, "damaged vehicle moves slower (%d < %d)" % [m_dmg, m_ok])
	# fixed-point angle helpers
	_check(FX.iatan2(0, 100) == 0 and FX.iatan2(100, 0) == 256 and FX.iatan2(0, -100) == 512 and FX.iatan2(-100, 0) == 768, "iatan2 cardinal directions")
	_check(FX.dir_of(256) == Vector2i(1024, 0) and FX.adiff(1000, 20) == 44, "dir_of / adiff")

## Spawn shooter (player 0) and a tough unarmed dummy (player 1) `off` tiles away; return shot ticks.
func _zh_shots(def: String, off: Vector2i, ticks: int, face: int = 0) -> Array:
	var r := _zh_runner(37)
	var w := r.sim
	var c := _zh_open(w, 7)
	var u := w.spawn_unit(StringName(def), 0, null, FX.tile_center(c))
	u.pos = FX.tile_center(c)
	u.face = face
	u.tface = face
	u.dir = FX.dir_of(face)
	var t := w.spawn_unit(&"eu_crawler", 1, null, FX.tile_center(c + off))
	t.pos = FX.tile_center(c + off)
	t.max_hp = 1000000
	t.hp = 1000000
	for p in [0, 1]:
		var ex: PackedByteArray = w.fog.explored[p]
		ex.fill(1)
		w.fog.explored[p] = ex
	r.issue({"p": 0, "t": "attack", "ids": [u.id], "target": t.id})
	var shots: Array = []
	var last := u.firing_tick
	for i in ticks:
		r.advance()
		if u.firing_tick != last:
			last = u.firing_tick
			shots.append(i + 1)
	return shots

func _zh_weapons() -> void:
	# turret traverse: a target behind the tank costs ~2 s of turret turn before the first shot
	var ahead := _zh_shots("eu_leopold", Vector2i(0, 4), 120)
	var behind := _zh_shots("eu_leopold", Vector2i(0, -4), 120)
	print("  tank first shot: target ahead tick %s, behind tick %s" % [ahead.slice(0, 1), behind.slice(0, 1)])
	_check(not ahead.is_empty() and not behind.is_empty() and int(behind[0]) - int(ahead[0]) >= 30, "turret must traverse before firing (behind +%s ticks)" % [(int(behind[0]) - int(ahead[0])) if not ahead.is_empty() and not behind.is_empty() else "-"])
	# hull-mounted: infantry turns to face the target first (fast)
	var inf_b := _zh_shots("eu_grenadier", Vector2i(0, -3), 60)
	_check(not inf_b.is_empty() and int(inf_b[0]) <= 15, "infantry turns and fires quickly (tick %s)" % [inf_b.slice(0, 1)])
	# pre-attack lock-on: Lancer waits 0.5 s on a new target, then fires on cooldown only
	var lan := _zh_shots("eu_lancer", Vector2i(0, 3), 160)
	var lan_ref := _zh_shots("eu_grenadier", Vector2i(0, 3), 160)
	print("  lancer shots %s ; grenadier shots %s" % [lan, lan_ref.slice(0, 3)])
	_check(lan.size() >= 2 and int(lan[0]) >= FX.ms_to_ticks(500) and int(lan[1]) - int(lan[0]) == FX.ms_to_ticks(2500), "lancer: pre-attack once per target, then plain cooldown")
	# clip + reload: Rattler HMG fires 8 quick shots then reloads
	var hmg := _zh_shots("tpla_rattler", Vector2i(0, 3), 140)
	var gaps: Array = []
	for i in range(1, hmg.size()):
		gaps.append(int(hmg[i]) - int(hmg[i - 1]))
	print("  rattler shot gaps %s" % [gaps])
	_check(gaps.size() >= 10 and gaps.count(FX.ms_to_ticks(200)) >= 7 and gaps.max() >= FX.ms_to_ticks(1400), "HMG clip: bursts of quick shots with a reload pause")

## Hit rate of `wd` from u against a fresh dummy of `tdef` (direct hits deal the full damage).
func _zh_hit_rate(w: SimWorld, u: SimEntity, tdef: String, wid: String, n: int) -> int:
	var wd: WeaponDef = Content.weapon(StringName(wid))
	var t := w.spawn_unit(StringName(tdef), 1, null, u.pos + Vector2i(0, FX.ONE * 4))
	t.pos = u.pos + Vector2i(0, FX.ONE * 4)
	var full := wd.damage * Content.combat.mult(wd.damage_type, w.udef(t).armor_type) / 100
	var hits := 0
	for i in n:
		t.max_hp = 1000000
		t.hp = 1000000
		t.shield = 0
		CombatSys.fire(w, u, t, wd, 100)
		if 1000000 - t.hp >= full:
			hits += 1
	t.hp = 0
	return hits * 100 / n

func _zh_scatter() -> void:
	var r := _zh_runner(41)
	var w := r.sim
	var c := _zh_open(w, 7)
	var u := w.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(c))
	var vs_veh := _zh_hit_rate(w, u, "eu_crawler", "eu_tank_cannon", 200)
	var vs_inf := _zh_hit_rate(w, u, "tpla_militia", "eu_tank_cannon", 200)
	var rifle := _zh_hit_rate(w, u, "tpla_militia", "eu_rifle", 200)
	var arty := _zh_hit_rate(w, u, "eu_grenadier", "tpla_rust_shell", 200)
	print("  direct-hit rate: tank cannon vs vehicle %d%%, vs infantry %d%%; rifle vs infantry %d%%; rust shell vs infantry %d%%" % [vs_veh, vs_inf, rifle, arty])
	_check(vs_veh == 100 and rifle == 100, "accurate weapons always hit")
	# M3.3 (Malachi: infantry more vulnerable, tank rounds splash): the tank cannon's extra scatter
	# vs soldiers dropped 900 -> 300 mt and its splash grew to 1000 mt, so it now mostly connects.
	_check(vs_inf >= 70, "tank cannon mostly hits infantry now (%d%%)" % vs_inf)
	_check(arty < 100, "artillery scatters (%d%%)" % arty)

## Distinct victims an engaged squad of 6 Grenadiers spreads its fire over, per AI difficulty.
func _zh_victim_spread(diff: String) -> int:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", 43, [diff, diff], ["eu", "tpla"]))
	var ai: AIPlayer = r.ais[0]
	r.ais.clear()
	var w := r.sim
	var c := _zh_open(w, 7)
	var ids: Array = []
	for i in 6:
		var u := w.spawn_unit(&"eu_grenadier", 0, null, FX.tile_center(c + Vector2i(i - 3, -2)))
		u.pos = FX.tile_center(c + Vector2i(i - 3, -2))
		u.face = 0
		ids.append(u.id)
	for i in 5:
		var e := w.spawn_unit(&"tpla_militia", 1, null, FX.tile_center(c + Vector2i(i * 2 - 4, 2)))
		e.pos = FX.tile_center(c + Vector2i(i * 2 - 4, 2))
		e.max_hp = 100000
		e.hp = 100000 - i * 10
	ai.bb["wave"] = ids
	_ticks(r, 30)
	ai._victims()
	_ticks(r, 30)
	var tg := {}
	for id in ids:
		var u := w.get_ent(id)
		if u != null and u.target != 0:
			tg[u.target] = true
	return tg.size()

func _zh_victims() -> void:
	var e := _zh_victim_spread("easy")
	var m := _zh_victim_spread("medium")
	var h := _zh_victim_spread("hard")
	print("  distinct victims of a 6-unit squad: easy %d, medium %d, hard %d" % [e, m, h])
	_check(h == 1, "hard AI focus-fires one victim")
	_check(m >= 2, "medium AI: each unit fights its nearest enemy")
	_check(e >= 2, "easy AI spreads fire")

## Arrival-tick gap of a Leopold + Wolfhound pair: one group move, or two separate moves to the same slots.
func _zh_pair_gap(grouped: bool) -> Array:
	var r := _zh_runner(47)
	var w := r.sim
	var c := _zh_open(w, 7)
	var tank := w.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(c + Vector2i(-1, -6)))
	tank.pos = FX.tile_center(c + Vector2i(-1, -6))
	var jeep := w.spawn_unit(&"eu_wolfhound", 0, null, FX.tile_center(c + Vector2i(1, -6)))
	jeep.pos = FX.tile_center(c + Vector2i(1, -6))
	r.issue({"p": 0, "t": "move", "ids": [tank.id, jeep.id], "pos": FX.tile_center(c + Vector2i(0, 6))})
	_ticks(r, 1)
	var cap := int(jeep.orders[0].get("spd", 0)) if not jeep.orders.is_empty() else 0
	if not grouped:
		var tp: Vector2i = tank.orders[0]["pos"]
		var jp: Vector2i = jeep.orders[0]["pos"]
		r.issue({"p": 0, "t": "move", "ids": [tank.id], "pos": tp})
		r.issue({"p": 0, "t": "move", "ids": [jeep.id], "pos": jp})
	var arrive := {}
	for i in 400:
		r.advance()
		for u: SimEntity in [tank, jeep]:
			if not arrive.has(u.id) and u.orders.is_empty() and u.goal == Vector2i(-1, -1):
				arrive[u.id] = i
		if arrive.size() == 2:
			break
	var single_ok := true
	r.issue({"p": 0, "t": "move", "ids": [jeep.id], "pos": FX.tile_center(c + Vector2i(0, -6))})
	_ticks(r, 1)
	single_ok = jeep.orders.is_empty() or not jeep.orders[0].has("spd")
	return [cap, int(arrive.get(tank.id, 999)) - int(arrive.get(jeep.id, 0)), single_ok]

func _zh_group() -> void:
	var g := _zh_pair_gap(true)
	var s := _zh_pair_gap(false)
	print("  tank-vs-jeep arrival gap: group move %d ticks, separate moves %d ticks" % [g[1], s[1]])
	_check(int(g[0]) == FX.speed_per_tick(1650), "group move caps the fast unit at the slowest member's speed (%d)" % g[0])
	_check(absi(int(g[1])) * 2 <= absi(int(s[1])), "mixed group arrives together (gap %d vs %d)" % [g[1], s[1]])
	_check(bool(g[2]), "single-unit move is not capped")

func test_duel() -> void:
	var comps := {
		"rush": [["tpla_militia", 5], ["tpla_rattler", 2], ["tpla_rocket_cell", 2]],
		"eu_def": [["eu_grenadier", 4], ["eu_wolfhound", 1], ["eu_lancer", 2]],
		"tpla_mid": [["tpla_scrapback", 3], ["tpla_rocket_cell", 3], ["tpla_militia", 3]],
		"eu_mid": [["eu_leopold", 3], ["eu_grenadier", 3], ["eu_lancer", 2]],
	}
	for pair in [["rush", "eu_def"], ["tpla_mid", "eu_mid"]]:
		var tw := 0
		var ew := 0
		for seed in range(5):
			var r := MatchRunner.new()
			r.record_replay = false
			var slots := [{"team": 0, "spawn": 0}, {"team": 1, "spawn": 1}]
			r.start(load("res://tests/test_runner.gd").make_cfg("1v1", seed + 50, [], ["eu", "tpla"]))
			r.ais.clear()
			var w := r.sim
			var c := Vector2i(48, 94)
			var a: Array = []
			var b: Array = []
			var k := 0
			for e in comps[pair[0]]:
				for n in e[1]:
					var u := w.spawn_unit(StringName(e[0]), 1, null, FX.tile_center(c + Vector2i(k % 5 - 2, 6 + k / 5)))
					a.append(u); k += 1
			k = 0
			for e in comps[pair[1]]:
				for n in e[1]:
					var u := w.spawn_unit(StringName(e[0]), 0, null, FX.tile_center(c + Vector2i(k % 5 - 2, -6 - k / 5)))
					b.append(u); k += 1
			var ia: Array = []; for u in a: ia.append(u.id)
			var ib: Array = []; for u in b: ib.append(u.id)
			r.issue({"p": 1, "t": "amove", "ids": ia, "pos": FX.tile_center(c + Vector2i(0, -8))})
			r.issue({"p": 0, "t": "amove", "ids": ib, "pos": FX.tile_center(c + Vector2i(0, 8))})
			for i in 1800:
				r.advance()
			var va := 0; var vb := 0
			for u in a: if u.alive: va += Content.unit(u.def_id).cost
			for u in b: if u.alive: vb += Content.unit(u.def_id).cost
			if va > vb: tw += 1
			elif vb > va: ew += 1
			print("%s vs %s seed %d: tpla left $%d, eu left $%d" % [pair[0], pair[1], seed, va, vb])
		print("== %s vs %s: tpla wins %d, eu wins %d" % [pair[0], pair[1], tw, ew])


# ------------------------------------------------------------------ M2.4 roster (ZH 1:1 widening)
const ROSTER_NEW_UNITS := ["eu_brennus", "eu_salamander", "eu_thunderhead", "eu_hearth", "eu_spectre", "eu_sentinel", "eu_kestrel", "eu_corvid",
	"tpla_bus", "tpla_marksman", "tpla_insurgent"]
const ROSTER_NEW_BUILDINGS := ["eu_flak_tower", "eu_signals", "eu_relay", "eu_exchange", "eu_airstrip", "eu_minefield",
	"tpla_wasp_nest"]

func test_roster() -> void:
	_roster_content()
	_retired_units()
	_roster_transport()
	_roster_jammer()
	_roster_mines()
	_roster_heal_stub_prod()
	_roster_m32()

func _roster_reveal(w: SimWorld) -> void:
	for p in w.players.size():
		var ex: PackedByteArray = w.fog.explored[p]
		ex.fill(1)
		w.fog.explored[p] = ex

## M3.2.2: the German shield truck (eu_aegis) is out of the game, but old saves / replays work.
func _retired_units() -> void:
	var made := false
	for bid in Content.buildings:
		made = made or Content.building(bid).produces.has("eu_aegis")
	_check(not made and not Content.faction(&"eu")["units"].has(&"eu_aegis"), "shield truck is in no build list, faction roster or Map Builder palette")
	var used := false
	for pid in Content.ai_personalities:
		used = used or (Content.ai_personalities[pid] as AIPersonalityDef).unit_weights.has("eu_aegis")
	_check(not used, "no AI personality builds the shield truck")
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", 5, [], ["eu", "tpla"]))
	r.ais.clear()
	var w := r.sim
	var hq: SimEntity = null
	for id in w.ids:
		if w.ents[id].owner == 0 and w.ents[id].kind == SimEntity.Kind.BUILDING:
			hq = w.ents[id]
	# an old save with a shield truck in the field and one in a Heavy Factory queue
	var ag := w.spawn_unit(&"eu_aegis", 0, null, FX.tile_center(hq.tile + Vector2i(6, 6)))
	var buddy := w.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(hq.tile + Vector2i(7, 6)))
	var hf := w._place_building(Content.building(&"eu_heavy_factory"), 0, hq.tile + Vector2i(-10, 8), 0, true)
	w.players[0].supply = 100000
	r.issue({"p": 0, "t": "queue", "target": hf.id, "def": "eu_aegis", "n": 1})   # replays of old games
	_ticks(r, 2)
	_check(hf.queue.has(&"eu_aegis"), "the sim still accepts a recorded shield-truck order (old replays play back)")
	var w2 := SimWorld.new()
	w2.deserialize(w.serialize())
	_check(w2.state_hash() == w.state_hash() and w2.get_ent(ag.id) != null and w2.get_ent(ag.id).def_id == &"eu_aegis", "a save with a shield truck loads identically")
	_ticks(r, 40)
	_check(buddy.aura_tick >= w.tick - 4, "a shield truck from an old save still covers nearby units")
	r.issue({"p": 0, "t": "queue", "target": hq.id, "def": "eu_aegis", "n": 1})
	_ticks(r, 2)
	_check(not hq.queue.has(&"eu_aegis"), "it cannot be queued anywhere else")

func _roster_content() -> void:
	for id in ROSTER_NEW_UNITS:
		if Content.RETIRED_UNITS.has(StringName(id)):
			continue   # M3.3: retired (eu_brennus); kept loadable for old saves/replays
		var d: UnitDef = Content.unit(StringName(id))
		_check(d != null and ResourceLoader.exists(d.view_scene) and tr(d.name_key) != d.name_key, "unit %s: def, model and name '%s'" % [id, tr(d.name_key) if d else "?"])
		var made := false
		for bid in Content.buildings:
			if Content.building(bid).produces.has(id):
				made = true
		_check(made, "unit %s is in a production building's build list" % id)
	for id in ROSTER_NEW_BUILDINGS:
		var b: BuildingDef = Content.building(StringName(id))
		_check(b != null and ResourceLoader.exists(b.view_scene) and tr(b.name_key) != b.name_key and b.buildable, "structure %s: def, model, name '%s', buildable" % [id, tr(b.name_key) if b else "?"])
	_check(Content.combat.table.has(&"flame") or Content.combat.table.has("flame"), "flame damage type in the combat table")
	_check(Content.unit(&"eu_wolfhound").transport_capacity == 4 and Content.unit(&"eu_wolfhound").stubs.is_empty(), "Wolfhound transport is real (capacity 4, no stub)")

func _roster_transport() -> void:
	var r := _zh_runner(41)
	var w := r.sim
	var c := _zh_open(w, 7)
	var t := w.spawn_unit(&"eu_wolfhound", 0, null, FX.tile_center(c))
	t.pos = FX.tile_center(c)
	var inf: Array = []
	for k in 5:
		var g := w.spawn_unit(&"eu_grenadier", 0, null, FX.tile_center(c + Vector2i(k - 2, 3)))
		g.pos = FX.tile_center(c + Vector2i(k - 2, 3))
		inf.append(g.id)
	r.issue({"p": 0, "t": "garrison", "ids": inf, "target": t.id})
	_ticks(r, 120)
	var inside := RosterSys.passengers(w, t).size()
	_check(inside == 4, "Wolfhound loads 4 infantry, the 5th stays out (%d inside)" % inside)
	r.issue({"p": 0, "t": "move", "ids": [t.id], "pos": FX.tile_center(c + Vector2i(0, 6))})
	_ticks(r, 100)
	var rides := true
	for u: SimEntity in RosterSys.passengers(w, t):
		rides = rides and u.pos == t.pos
	_check(rides and FX.to_tile(t.pos) != c, "passengers ride with the transport")
	# save/load with passengers aboard keeps the state identical
	var snap := w.serialize()
	var w2 := SimWorld.new()
	w2.deserialize(snap)
	_check(w2.state_hash() == w.state_hash() and RosterSys.passengers(w2, w2.get_ent(t.id)).size() == 4, "save/load keeps passengers aboard")
	r.issue({"p": 0, "t": "unload", "ids": [t.id]})
	_ticks(r, 2)
	_check(RosterSys.passengers(w, t).is_empty(), "Unload puts everyone out")
	r.issue({"p": 0, "t": "garrison", "ids": inf.slice(0, 3), "target": t.id})
	_ticks(r, 120)
	_check(RosterSys.passengers(w, t).size() == 3, "infantry board again (%d)" % RosterSys.passengers(w, t).size())
	w.damage(t, 100000, null)
	_ticks(r, 3)
	var alive := 0
	for id in inf.slice(0, 3):
		var u := w.get_ent(id)
		if u != null and u.alive and u.res_id >= 0:
			alive += 1
	_check(not t.alive and alive == 3, "passengers bail out when the transport is destroyed (%d)" % alive)
	# Rust Bus carries 8, vehicles cannot board
	var bus := w.spawn_unit(&"tpla_bus", 0, null, FX.tile_center(c))
	var tank := w.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(c + Vector2i(1, 1)))
	r.issue({"p": 0, "t": "garrison", "ids": [tank.id], "target": bus.id})
	_ticks(r, 40)
	_check(Content.unit(&"tpla_bus").transport_capacity == 8 and tank.res_id >= 0, "BMP-2 capacity 8; vehicles cannot board")

func _roster_jammer() -> void:
	var dmg := []
	for with_jammer in [true, false]:
		var r := _zh_runner(43)
		var w := r.sim
		var c := _zh_open(w, 7)
		_roster_reveal(w)
		var tank := w.spawn_unit(&"eu_leopold", 1, null, FX.tile_center(c + Vector2i(0, 4)))
		tank.pos = FX.tile_center(c + Vector2i(0, 4))
		var dummy := w.spawn_unit(&"eu_crawler", 0, null, FX.tile_center(c))
		dummy.pos = FX.tile_center(c)
		dummy.max_hp = 100000
		dummy.hp = 100000
		if with_jammer:
			var j := w.spawn_unit(&"eu_spectre", 0, null, FX.tile_center(c + Vector2i(-2, 0)))
			j.pos = FX.tile_center(c + Vector2i(-2, 0))
			j.max_hp = 100000
			j.hp = 100000
		r.issue({"p": 1, "t": "attack", "ids": [tank.id], "target": dummy.id})
		_ticks(r, 200)
		dmg.append(100000 - dummy.hp)
	_check(dmg[0] == 0 and dmg[1] > 0, "Spectre jammer stops enemy vehicle fire within 6 tiles (damage %d jammed vs %d free)" % dmg)

func _roster_mines() -> void:
	var r := _zh_runner(47)
	var w := r.sim
	var c := _zh_open(w, 7)
	var mine := w._place_building(Content.building(&"eu_minefield"), 0, c + Vector2i(0, 2), 0, true)
	_ticks(r, 10)
	_check(mine.stealthy and (mine.stealth_mask & (1 << w.player_team(1))) == 0, "EU minefield is hidden from the enemy")
	var ear := w.spawn_unit(&"eu_sentinel", 1, null, FX.tile_center(c + Vector2i(0, -6)))
	ear.pos = FX.tile_center(c + Vector2i(0, -6))
	_ticks(r, 10)
	_check((mine.stealth_mask & (1 << w.player_team(1))) != 0, "a detector (Sentinel) reveals the mine from 8 tiles")
	var rat := w.spawn_unit(&"tpla_rattler", 1, null, FX.tile_center(c + Vector2i(0, 6)))
	rat.pos = FX.tile_center(c + Vector2i(0, 6))
	r.issue({"p": 1, "t": "move", "ids": [rat.id], "pos": FX.tile_center(c + Vector2i(0, -2))})
	_ticks(r, 200)
	_check(not mine.alive and (not rat.alive or rat.hp < rat.max_hp), "minefield detonates under an enemy vehicle (rattler hp %d/%d)" % [rat.hp, rat.max_hp])

func _roster_heal_stub_prod() -> void:
	var r := _zh_runner(53)
	var w := r.sim
	var c := _zh_open(w, 7)
	var relay := w._place_building(Content.building(&"eu_relay"), 0, c + Vector2i(3, 0), 0, true)
	var tank := w.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(c))
	tank.pos = FX.tile_center(c)
	tank.hp = tank.max_hp / 2
	var h0 := tank.hp
	w.power_dirty = true
	_ticks(r, 100)
	_check(relay.powered and tank.hp > h0, "Field Relay Mast repairs nearby vehicles (%d -> %d)" % [h0, tank.hp])
	# M3.0 E: the German Airfield builds real aircraft (Tiger helicopter, multirole fighter)
	var strip := w._place_building(Content.building(&"eu_airstrip"), 0, c + Vector2i(-6, -6), 0, true)
	w.players[0].supply = 50000
	r.issue({"p": 0, "t": "queue", "target": strip.id, "def": "eu_kestrel", "n": 1})
	_ticks(r, 2)
	_check(not strip.queue.is_empty() and Content.building(&"eu_airstrip").air_slots == 6, "Tiger is queued at the German Airfield (6 parking slots)")
	var mp := w._place_building(Content.building(&"eu_motor_pool"), 0, c + Vector2i(-6, 4), 0, true)
	var before := w.count_owned(0, &"eu_salamander")
	r.issue({"p": 0, "t": "queue", "target": mp.id, "def": "eu_salamander", "n": 1})
	_ticks(r, 20 * 30)
	_check(w.count_owned(0, &"eu_salamander") > before, "Motor Pool produces the Salamander")


## M2.4 view tests (headless, real WorldView): construction sites look like construction (rig,
## no damage state) for every EU/TPLA structure, damage is relative to construction HP, paused
## sites stand still, rigs are struck on completion; every weapon maps to a travelling-round
## effect (no beams), rounds land at the sim impact point, misses on the ground; and attaching
## the view does not change the simulation (state hashes equal with and without it).
func test_m24() -> void:
	var cfg := make_cfg("1v1", 424, [], ["eu", "tpla"])
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(cfg)
	var wv := WorldView.new()
	add_child(wv)
	wv.setup(r, 0)
	var sim: SimWorld = r.sim
	# ---- construction
	var defs: Array = []
	for id in Content.buildings:
		var sid := String(id)
		if (sid.begins_with("eu_") or sid.begins_with("tpla_")) and id != &"tpla_hole":
			defs.append(id)
	var x := 6
	var y := 30
	var sites: Array = []
	for id in defs:
		var bd: BuildingDef = Content.building(id)
		if x + bd.footprint.x > sim.map.w - 6:
			x = 6
			y += 6
		var e: SimEntity = sim._place_building(bd, 0 if String(id).begins_with("eu_") else 1, Vector2i(x, y), 0, false)
		e.progress = e.build_ticks / 2
		e.hp = ProdSys.construction_hp_cap(e.max_hp, e.progress, e.build_ticks)
		wv._ensure_view(e)
		sites.append(e)
		x += bd.footprint.x + 2
	wv.frame(0.0, 0.016)
	var dirty: Array = []
	var no_rig: Array = []
	for e in sites:
		var v: EntityView = wv.views[e.id]
		if not wv.rigs.has(e.id):
			no_rig.append(e.def_id)
		if v is BuildingView and ((v as BuildingView)._state != 0 or ((v as BuildingView).dmg_light != null and (v as BuildingView).dmg_light.visible)):
			dirty.append(e.def_id)
		if WorldView.build_relative_health(e) < 0.999:
			dirty.append(e.def_id)
	_check(no_rig.is_empty(), "every EU/TPLA structure under construction gets a construction rig (%d sites) %s" % [sites.size(), no_rig])
	_check(dirty.is_empty(), "healthy construction sites show no damage state at 50 %% (HP %d%% of max) %s" % [100 * sites[0].hp / sites[0].max_hp, dirty])
	var fresh: SimEntity = sites[0]
	fresh.progress = 0
	fresh.hp = ProdSys.construction_hp_cap(fresh.max_hp, 0, fresh.build_ticks)
	wv.frame(0.0, 0.016)
	_check(WorldView.build_relative_health(fresh) >= 0.999 and fresh.hp * 10 <= fresh.max_hp + 10, "fresh site at 10 %% HP reads as full condition")
	var rig: ConstructionRig = wv.rigs[sites[1].id]
	sites[1].progress += 5
	wv.frame(0.0, 0.016)
	_check(rig.working(), "site animates while its progress advances")
	for i in 60:
		wv.frame(0.0, 0.016)
	_check(not rig.working(), "paused site (no progress) stands still")
	# shot-at scaffold: light damage only, relative to the HP built so far
	var hit: SimEntity = null
	for e in sites:
		if wv.views[e.id] is BuildingView:
			hit = e
			break
	hit.hp = hit.hp * 45 / 100
	wv.frame(0.0, 0.016)
	var hv: BuildingView = wv.views[hit.id]
	_check(hv._state == 1 and not hv.dmg_heavy.visible, "shot-at scaffold (45 %% of built HP) shows light damage only (state %d)" % hv._state)
	# a finished building at the same absolute HP is heavily damaged
	hit.progress = hit.build_ticks
	hit.built = true
	wv.frame(0.0, 0.016)
	_check(hv._state == 2 and not wv.rigs.has(hit.id), "finished building at that HP shows heavy damage and the rig is struck (state %d)" % hv._state)
	# a legacy (non-staged) view: clip materials restored on completion
	var leg: SimEntity = null
	for e in sites:
		if not (wv.views[e.id] is BuildingView) and wv.rigs.has(e.id):
			leg = e
			break
	if leg == null:
		# M2.9: the Grid Pylon (the last non-staged structure view) was removed
		print("  no legacy (non-staged) structure views left - clip test skipped")
	else:
		var lr: ConstructionRig = wv.rigs[leg.id]
		_check(lr.stats["swapped"] > 0, "legacy structure %s clips its meshes while building (%d surfaces)" % [leg.def_id, lr.stats["swapped"]])
		leg.progress = leg.build_ticks
		leg.built = true
		wv.frame(0.0, 0.016)
		var still_clipped := 0
		var stack: Array = [wv.views[leg.id]]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is ConstructionRig or n.is_queued_for_deletion():
				continue
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var mats: Array = [mi.material_override]
				for si in mi.get_surface_override_material_count():
					mats.append(mi.get_surface_override_material(si))
				for mt in mats:
					if mt is ShaderMaterial and (mt as ShaderMaterial).shader != null and (mt as ShaderMaterial).shader.resource_path.contains("reveal"):
						still_clipped += 1
			stack.append_array(n.get_children())
		_check(still_clipped == 0, "completed legacy structure is back on its normal materials (%d clipped left)" % still_clipped)
	# ---- weapon effects
	var unmapped: Array = []
	for wid in Content.weapons:
		var wd: WeaponDef = Content.weapon(wid)
		if not WeaponFx.CLASSES.has(wid) and String(wd.vfx) != "bomb":
			unmapped.append(wid)
	_check(unmapped.is_empty(), "every weapon has a Zero Hour-style effect class %s" % [unmapped])
	_check(not wv.vfx.has_method("tracer"), "beam / laser tracer removed from Vfx")
	var wfx: WeaponFx = wv.wfx
	var o := Vector3(20, 0, 20)
	var classes := ["rifle", "mg", "quad", "autocannon", "cannon", "flak", "missile", "rocket", "salvo", "artillery", "mortar", "grenade", "rust", "flame", "spray"]
	for c in classes:
		wfx.fire(c, [o + Vector3(0, 0.5, 0)], Vector3(0, 0, 1), o + Vector3(0, 0, 6), 0, -1, Vector3.ZERO)
	var flying := wfx.shots.size()
	_check(flying >= 12 and wfx.streams.size() == 2, "rounds fly (not instant): %d in flight, %d streams" % [flying, wfx.streams.size()])
	var max_glow := 0
	for i in 120:
		wfx._process(1.0 / 60.0)
		max_glow = maxi(max_glow, wfx.glow.n)
	_check(wfx.shots.is_empty() and wfx.streams.is_empty() and wfx.queued.is_empty(), "every round lands within 2 s")
	_check(int(wfx.stats["ground_misses"]) >= 12, "misses land on the ground (%d)" % wfx.stats["ground_misses"])
	_check(int(wfx.stats["airbursts"]) >= 1 and int(wfx.stats["trail_puffs"]) > 10 and int(wfx.stats["stream_particles"]) > 10, "flak airburst, rocket smoke trails and flame stream particles %s" % [wfx.stats])
	_check(max_glow > 0 and max_glow <= wfx.glow.cap, "streaks are pooled in one MultiMesh (peak %d of %d)" % [max_glow, wfx.glow.cap])
	# hits follow the target and delay its death visual until the round lands
	var tgt: SimEntity = sim.spawn_unit(&"eu_leopold", 0, null, FX.tile_center(Vector2i(30, 24)))
	wv._ensure_view(tgt)
	wfx.fire("rocket", [o + Vector3(0, 0.5, 0)], Vector3(1, 0, 0), FX.to_world(tgt.pos), tgt.id, 1, Vector3(0, 0.35, 0))
	_check(wfx.time_to_hit(tgt.id) > 0.1, "rocket in flight toward its target (%.2f s)" % wfx.time_to_hit(tgt.id))
	var flood := 0
	for i in 500:
		wfx.fire("mg", [o], Vector3(0, 0, 1), o + Vector3(0, 0, 5), 0, -1, Vector3.ZERO)
	for i in 3:
		wfx._process(0.05)
	flood = wfx.shots.size()
	_check(flood <= WeaponFx.MAX_SHOTS and wfx.glow.n <= wfx.glow.cap, "round pool is capped under a flood (%d live)" % flood)
	for i in 200:
		wfx._process(0.05)
	# ---- the sim is untouched by the view: fire events carry the weapon id; hashes match
	var a := MatchRunner.new()
	a.record_replay = false
	a.start(make_cfg("1v1", 99, ["hard", "hard"], ["eu", "tpla"]))
	var b := MatchRunner.new()
	b.record_replay = false
	b.start(make_cfg("1v1", 99, ["hard", "hard"], ["eu", "tpla"]))
	var bv := WorldView.new()
	add_child(bv)
	bv.setup(b, 0)
	var fires := 0
	var with_w := 0
	var mism := 0
	for i in 20 * 60 * 8:
		a.advance()
		b.advance()
		var evs: Array = b.sim.events.duplicate()
		for ev in evs:
			if ev["t"] == "fire":
				fires += 1
				with_w += 1 if ev.has("w") else 0
		bv.on_tick(evs)
		if i % 4 == 0:
			bv.frame(0.5, 0.05)
		if i % 600 == 599 and a.sim.state_hash() != b.sim.state_hash():
			mism += 1
	_check(fires > 0 and with_w == fires, "fire events carry the weapon id (%d of %d)" % [with_w, fires])
	_check(mism == 0, "view attached vs headless: identical sim state hashes over 8 min (%d mismatches)" % mism)
	print("M24 weapon fx stats: ", bv.wfx.stats)


## Diagnostic: draw surfaces (one draw call each, before shadow passes) and triangles of every
## unit / structure view, so render budgets can be traced to individual models.
func view_cost() -> void:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", 7, [], ["eu", "tpla"]))
	var wv := WorldView.new()
	add_child(wv)
	wv.setup(r, 0)
	var rows: Array = []
	for id in Content.units.keys() + Content.buildings.keys():
		var e := SimEntity.new()
		e.def_id = id
		e.kind = SimEntity.Kind.UNIT if Content.units.has(id) else SimEntity.Kind.BUILDING
		var ps: PackedScene = load(wv._scene_for(e))
		var v: Node3D = ps.instantiate()
		add_child(v)
		var surf := 0
		var tris := 0
		var mm := 0
		for n in v.find_children("*", "GeometryInstance3D", true, false):
			if not (n as GeometryInstance3D).is_visible_in_tree():
				continue
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				var mesh: Mesh = (n as MeshInstance3D).mesh
				surf += mesh.get_surface_count()
				for si in mesh.get_surface_count():
					var a := mesh.surface_get_arrays(si)
					var idx = a[Mesh.ARRAY_INDEX]
					tris += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
			elif n is MultiMeshInstance3D:
				mm += 1
				var mmi: MultiMesh = (n as MultiMeshInstance3D).multimesh
				if mmi != null and mmi.mesh != null:
					surf += mmi.mesh.get_surface_count()
		rows.append([surf, tris, String(id), mm])
		v.free()
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for row in rows:
		print("VIEWCOST %-22s surfaces=%3d tris=%6d multimesh=%d" % [row[2], row[0], row[1], row[3]])


# ================================================================== M2.5
func test_m25() -> void:
	_m25_supply()
	_m25_maps()
	_m25_minimap()
	_m25_us_content()
	_m25_air()
	_m25_sniper_jtac()

func _m25_supply() -> void:
	var md: MapDef = Content.maps.get(&"varno_crossing")
	var seam_min := 1 << 30
	var cache_min := 1 << 30
	for r in md.resources:
		if String(r["kind"]) == "seam":
			seam_min = mini(seam_min, int(r["amount"]))
		else:
			cache_min = mini(cache_min, int(r["amount"]))
	# M2.4 piles: seams 15000-20000, caches 3000-4000 -> doubled in M2.5
	_check(seam_min >= 30000 and cache_min >= 6000, "supply piles hold ~2x (smallest seam %d, smallest pile %d)" % [seam_min, cache_min])

func _m25_maps() -> void:
	for mid in ["varno_crossing", "kessel_pass", "harrow_junction", "ochre_wells"]:
		var md: MapDef = Content.maps.get(StringName(mid))
		_check(md != null, "map %s loads" % mid)
		if md == null:
			continue
		var garr := 0
		var pumps := 0
		for n in md.neutrals:
			var bd: BuildingDef = Content.building(StringName(n["kind"]))
			if bd != null and bd.garrison_capacity > 0:
				garr += 1
			if bd != null and bd.capturable:
				pumps += 1
		_check(md.spawns.size() == 4 and md.resources.size() >= 12 and garr >= 10 and pumps >= 2,
			"map %s: 4 spawns, %d supply piles, %d garrisonable buildings, %d derricks, env %s" % [mid, md.resources.size(), garr, pumps, md.env])
		var r := MatchRunner.new()
		r.record_replay = false
		var cfg := make_cfg("ffa", 5, [], ["us", "eu", "tpla", "us"])
		cfg["map"] = mid
		r.start(cfg)
		_ticks(r, 600)
		var hqs := 0
		for pl in r.sim.players.size():
			if r.sim.count_owned(pl, Content.faction(r.sim.players[pl].faction)["hq"]) > 0:
				hqs += 1
		_check(hqs == 4 and not r.sim.game_over, "map %s: 4-player match (US/EU/TPLA/US) runs 30 s, %d HQs standing" % [mid, hqs])
	_check(SkirmishConfig.map_ids().size() >= 4, "lobby lists %d maps" % SkirmishConfig.map_ids().size())

func _m25_minimap() -> void:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", 7, [], ["eu", "tpla"]))
	r.ais.clear()
	_ticks(r, 8)
	var w := r.sim
	var team: int = w.players[0].team
	var far: SimEntity = null
	var n_res := 0
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if e.kind == SimEntity.Kind.RESOURCE:
			n_res += 1
			if not w.fog.visible_tile(team, e.tile) and (far == null or FX.dist2(e.pos, w.ents[w.ids[0]].pos) > FX.dist2(far.pos, w.ents[w.ids[0]].pos)):
				far = e
	var known := {}
	var shown := 0
	for id in w.ids:
		var e2: SimEntity = w.ents[id]
		if e2.kind == SimEntity.Kind.RESOURCE and Minimap.known_fraction(w, team, e2, known) > 0.0:
			shown += 1
	_check(shown == n_res and n_res > 0, "minimap shows every supply pile from the start (%d / %d)" % [shown, n_res])
	if far != null:
		far.amount = 0
		_check(Minimap.known_fraction(w, team, far, known) == 1.0, "a pile emptied under the shroud keeps its last-seen icon")
		w.fog.disabled = true
		_check(Minimap.known_fraction(w, team, far, known) == 0.0, "once seen empty, the pile's icon is removed")

func _us_runner(seed: int) -> MatchRunner:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg("1v1", seed, [], ["us", "eu"]))
	r.ais.clear()
	r.sim.fog.disabled = true
	return r

func _m25_us_content() -> void:
	var f: Dictionary = Content.faction(&"us")
	_check(Content.FACTIONS.has(&"us") and f["hq"] == &"us_command", "United States is a playable faction")
	for id in f["units"]:
		var d: UnitDef = Content.unit(id)
		_check(d != null and ResourceLoader.exists(d.view_scene) and tr(d.name_key) != d.name_key and Content.producer_of(id) != &"", "US unit %s: def, model, name '%s', producer" % [id, tr(d.name_key) if d else "?"])
	for id in f["buildings"]:
		var b: BuildingDef = Content.building(id)
		_check(b != null and ResourceLoader.exists(b.view_scene) and tr(b.name_key) != b.name_key, "US structure %s: def, model, name '%s'" % [id, tr(b.name_key) if b else "?"])
	_check(Content.unit(&"us_thunderlance").air_slots == 4 and Content.unit(&"us_wraith").air_slots == 2 and Content.unit(&"us_harrier").air_slots == 0 and Content.building(&"us_airfield").air_slots == 6,
		"airfield slots: bomber 4, fighter 2, gunship 0, airfield 6")
	var g: int = Content.weapon(&"us_m16").damage
	_check(Content.weapon(&"us_m4").damage * 100 / g >= 135 and Content.unit(&"us_jtac").max_hp * 100 / Content.unit(&"us_grunt").max_hp >= 135 and Content.unit(&"us_jtac").sight > Content.unit(&"us_grunt").sight,
		"JTAC: 35% stronger than a Rifleman, wider sight")

func _m25_air() -> void:
	var r := _us_runner(51)
	var w := r.sim
	var c := _zh_open(w, 7)
	_tpla_place(w, 0, &"us_reactor", c + Vector2i(8, -8))
	_tpla_place(w, 0, &"us_reactor", c + Vector2i(-8, -8))
	_tpla_place(w, 0, &"us_barracks", c + Vector2i(8, 8))
	_tpla_place(w, 0, &"us_garage", c + Vector2i(-8, 8))
	var af := _tpla_place(w, 0, &"us_airfield", c)
	_tpla_place(w, 0, &"us_strategy", c + Vector2i(0, -8))
	w.power_dirty = true
	for def in ["us_thunderlance", "us_wraith", "us_wraith"]:
		r.issue({"p": 0, "t": "queue", "target": af.id, "def": def, "n": 1})
	_ticks(r, 1150)
	var jets: Array = []
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if u.alive and u.kind == SimEntity.Kind.UNIT and Content.unit(u.def_id).air_slots > 0:
			jets.append(u)
	var parked := 0
	for j: SimEntity in jets:
		if j.air_state == AirSys.PARKED and j.air_home == af.id:
			parked += 1
	_check(jets.size() == 2 and parked == 2 and AirSys.slots_used(w, af) == 6, "bomber (4) + fighter (2) fill the 6 slots, parked on the pad (%d jets, %d slots)" % [jets.size(), AirSys.slots_used(w, af)])
	_check(af.queue.size() == 1 and af.hold_reason == "REASON_AIRFIELD_FULL", "a third jet waits: airfield full (%s)" % af.hold_reason)
	var bomber: SimEntity = null
	var fighter: SimEntity = null
	for j: SimEntity in jets:
		if j.def_id == &"us_thunderlance":
			bomber = j
		else:
			fighter = j
	if bomber == null or fighter == null:
		_check(false, "jets built")
		return
	# ground units cannot shoot at flying aircraft; AA can
	var tank := w.spawn_unit(&"eu_leopold", 1, null, FX.tile_center(c + Vector2i(0, 22)))
	var flak := w.spawn_unit(&"eu_flakwerk", 1, null, FX.tile_center(c + Vector2i(30, 30)))
	var hp0 := tank.hp
	r.issue({"p": 0, "t": "attack", "ids": [bomber.id], "target": tank.id})
	var took_off := false
	var dropped := false
	var taxied := false
	var lift_ok := false
	var landed_rwy := false
	var max_rwy := 0
	var ground_tgt := true
	var tank2 := w.spawn_unit(&"eu_leopold", 1, null, FX.tile_center(c + Vector2i(-20, -12)))   # M3.1: second sortie (runway queue)
	r.issue({"p": 0, "t": "attack", "ids": [fighter.id], "target": tank2.id})
	for i in 2400:
		r.advance()
		var on_rwy := 0
		for j: SimEntity in [bomber, fighter]:
			if (j.air_state == AirSys.TAXI_OUT and j.phase >= 1) or (j.air_state == AirSys.LANDING and j.phase <= 2):
				on_rwy += 1
		max_rwy = maxi(max_rwy, on_rwy)
		if bomber.air_state == AirSys.TAXI_OUT:
			taxied = true
			ground_tgt = ground_tgt and not w.flying(bomber)
			# lift-off happens from the runway centre line
			var rw := AirSys.local_pos(af, AirSys.LIFT_X, AirSys.RWY_Z)
			if bomber.phase == 2 and FX.dist(bomber.pos, rw) < FX.ONE:
				lift_ok = true
		if bomber.air_state == AirSys.LANDING and bomber.phase == 1:
			landed_rwy = landed_rwy or absi(FX.adiff(bomber.face, AirSys.runway_face(af))) < FX.ANG / 32
		if bomber.air_state == AirSys.FLYING and not took_off:
			took_off = true
			_check(not OrderSys.valid_target(w, tank, bomber) and OrderSys.valid_target(w, flak, bomber), "flying bomber: the tank's cannon cannot target it, the flak gun can")
		if tank.hp < hp0 and not dropped:
			dropped = true
		if dropped and bomber.air_state == AirSys.PARKED:
			break
	_check(took_off and dropped, "bomber takes off and drops its strike on the tank (hp %d -> %d)" % [hp0, tank.hp])
	_check(taxied and ground_tgt and lift_ok, "M3.1: the bomber taxis to the runway on the ground and lifts off at the end of the strip")
	_check(landed_rwy, "M3.1: it lands on the strip aligned with the runway, then taxis back to its bay")
	_check(max_rwy <= 1, "M3.1: one aircraft on the runway at a time (others hold short / hold over the fix)")
	_check(bomber.air_state == AirSys.PARKED and bomber.air_t > 0, "after one strike the bomber flies home, lands and rearms (%d ticks left)" % bomber.air_t)
	_check(OrderSys.valid_target(w, tank, bomber), "a parked aircraft is a ground target")
	# save / load mid-rearm keeps the air state
	var snap := w.serialize()
	var w2 := SimWorld.new()
	w2.deserialize(snap)
	var b2 := w2.get_ent(bomber.id)
	_check(w2.state_hash() == w.state_hash() and b2.air_state == AirSys.PARKED and b2.air_t == bomber.air_t and b2.air_home == af.id, "save/load keeps airfield, parking and rearm state")
	# fighter shoots down an enemy helicopter
	var heli := w.spawn_unit(&"us_harrier", 1, null, FX.tile_center(c + Vector2i(-20, 6)))
	for i in 2400:   # M3.1: the fighter flew a sortie too; let it land and rearm first
		if fighter.air_state == AirSys.PARKED and fighter.air_t == 0:
			break
		r.advance()
	r.issue({"p": 0, "t": "attack", "ids": [fighter.id], "target": heli.id})
	_ticks(r, 700)
	if heli.alive:
		print("  fighter state %d alive %s ammo %s" % [fighter.air_state, fighter.alive, str(fighter.ammo)])
	_check(not heli.alive, "fighter missiles shoot down a gunship")
	# gunship hovers at its destination and never lands
	var g2 := w.spawn_unit(&"us_harrier", 0, null, FX.tile_center(c + Vector2i(-6, -12)))
	var dest := FX.tile_center(c + Vector2i(6, -12))
	r.issue({"p": 0, "t": "move", "ids": [g2.id], "pos": dest})
	_ticks(r, 200)
	var p1 := g2.pos
	_ticks(r, 40)
	_check(FX.dist(g2.pos, dest) < FX.ONE and g2.pos == p1 and g2.air_state == AirSys.FLYING, "gunship flies straight over terrain and hovers at its destination")

func _m25_sniper_jtac() -> void:
	var r := _us_runner(53)
	var w := r.sim
	var c := _zh_open(w, 7)
	var sn := w.spawn_unit(&"us_sniper", 0, null, FX.tile_center(c))
	sn.pos = FX.tile_center(c)
	_ticks(r, 60)
	_check(sn.stealthy and not w.fog.is_visible_ent(w, w.players[1].team, sn), "Scout Sniper is invisible to the enemy while standing still")
	var gren := w.spawn_unit(&"eu_grenadier", 1, null, FX.tile_center(c + Vector2i(0, 7)))
	gren.pos = FX.tile_center(c + Vector2i(0, 7))
	gren.orders = [{"o": "guard", "pos": gren.pos}]
	var hits := 0
	for i in 120:
		var hp_before := gren.hp
		r.advance()
		if gren.hp < hp_before or not gren.alive:
			hits += 1
		if not gren.alive:
			break
	_check(not gren.alive and hits == 1, "sniper kills an infantry soldier with one shot (%d hit)" % hits)
	_check(sn.stealthy, "and stays hidden while firing from a standstill")
	r.issue({"p": 0, "t": "move", "ids": [sn.id], "pos": FX.tile_center(c + Vector2i(0, -4))})
	_ticks(r, 6)
	_check(not sn.stealthy, "moving reveals the sniper")
	var vs_tank := Content.weapon(&"us_sniper_rifle").damage * Content.combat.mult(&"sniper", &"heavy") / 100
	_check(vs_tank < 10, "sniper rifle is useless against tanks (%d dmg)" % vs_tank)
	# JTAC: call-in and boost aura
	var tank := w.spawn_unit(&"eu_leopold", 1, null, FX.tile_center(c + Vector2i(3, 14)))
	tank.orders = [{"o": "guard", "pos": tank.pos}]
	var jt := w.spawn_unit(&"us_jtac", 0, null, FX.tile_center(c + Vector2i(3, 9)))
	jt.orders = [{"o": "guard", "pos": jt.pos}]
	var heli := w.spawn_unit(&"us_harrier", 0, null, FX.tile_center(c + Vector2i(-10, -10)))
	var called := false
	for i in 80:
		r.advance()
		if not heli.orders.is_empty() and int(heli.orders[0].get("target", 0)) == tank.id:
			called = true
			break
	_check(called, "JTAC calls the idle gunship onto his target")
	var how := w.spawn_unit(&"us_longreach", 0, null, FX.tile_center(c + Vector2i(-12, 0)))
	var gr := w.spawn_unit(&"us_grunt", 0, null, FX.tile_center(c + Vector2i(-12, 2)))
	_check(AirSys.boost_pct(w, how, tank.pos) == 125 and AirSys.boost_pct(w, heli, tank.pos) == 125 and AirSys.boost_pct(w, gr, tank.pos) == 100,
		"JTAC boosts artillery and aircraft near him (+25%), not rifles")
	var n0 := w.count_owned(0, &"us_grunt")
	w.players[0].powers["us_paradrop"] = {"ready": w.tick}
	PowersSys.fire(w, 0, &"us_paradrop", FX.tile_center(c + Vector2i(-8, -6)))
	_check(w.count_owned(0, &"us_grunt") == n0 + 5, "Paradrop lands five Marine Riflemen")


# ================================================================== M2.8
## M2.8 #9: every armed ground unit and every armed structure turns toward and hits a target
## placed behind it (stationary, then circling), from an attack order and from idle auto-acquire.
## M3.2.2: a big group of helicopters given one order fans out instead of stacking in one ball.
func _air_min_gap(units: Array) -> Array:
	var best := 1 << 40
	var stacked := 0
	for i in units.size():
		for j in range(i + 1, units.size()):
			var d := FX.dist(units[i].pos, units[j].pos)
			best = mini(best, d)
			if d < FX.ONE / 2:
				stacked += 1
	return [best, stacked]

func _air_group(w: SimWorld, def: StringName, owner: int, c: Vector2i, n: int) -> Array:
	var out: Array = []
	for k in n:
		var u := w.spawn_unit(def, owner, null, FX.tile_center(c + Vector2i(k % 4, k / 4)))
		u.pos = FX.tile_center(c + Vector2i(k % 4, k / 4))   # packed tight, one tile apart
		out.append(u)
	return out

func _air_move_run(seed: int) -> Array:
	var r := _us_runner(seed)
	var w := r.sim
	var c := _zh_open(w, 7)
	var helis := _air_group(w, &"us_harrier", 0, c + Vector2i(-24, -6), 40)
	var ids: Array = []
	for u in helis:
		ids.append(u.id)
	var dest := FX.tile_center(c + Vector2i(4, 0))
	r.issue({"p": 0, "t": "move", "ids": ids, "pos": dest})
	_ticks(r, 900)
	var far := 0
	for u: SimEntity in helis:
		if FX.dist(u.pos, dest) > FX.ONE * 9:
			far += 1
	return [r, helis, dest, far]

func test_airspread() -> void:
	var a := _air_move_run(77)
	var w: SimWorld = a[0].sim
	var helis: Array = a[1]
	var g := _air_min_gap(helis)
	var arrived := 0
	for u: SimEntity in helis:
		arrived += 1 if u.orders.is_empty() else 0
		if not u.orders.is_empty():
			print("  still moving: id %d dist %d spd %d goal %s order %s" % [u.id, FX.dist(u.pos, u.orders[0]["pos"]), u.spd, u.goal, u.orders[0]])
	print("move: min gap %.2f tiles, %d stacked pairs, %d of 40 finished the move, %d further than 9 tiles" % [g[0] / float(FX.ONE), g[1], arrived, a[3]])
	_check(g[0] >= FX.ONE * 12 / 10 and g[1] == 0, "40 helicopters moved to one point keep >= 1.2 tiles apart, none stacked (min %.2f)" % (g[0] / float(FX.ONE)))
	_check(arrived == 40 and a[3] == 0, "they all finish the move in a loose group around the point (%d done, %d far)" % [arrived, a[3]])
	# deterministic: the same run twice gives the same state
	var b := _air_move_run(77)
	_check(a[0].sim.state_hash() == b[0].sim.state_hash(), "air spreading is deterministic (same state hash twice)")
	# attack: they spread around the target inside weapon range
	var r: MatchRunner = a[0]
	var tgt := w.spawn_unit(&"eu_leopold", 1, null, FX.tile_center(FX.to_tile(a[2]) + Vector2i(14, 0)))
	tgt.max_hp = 100000000
	tgt.hp = tgt.max_hp
	tgt.orders = [{"o": "guard", "pos": tgt.pos}]
	var ids: Array = []
	for u in helis:
		ids.append(u.id)
	r.issue({"p": 0, "t": "attack", "ids": ids, "target": tgt.id})
	_ticks(r, 500)
	var inr := 0
	var firing := 0
	var sx := 0
	var sy := 0
	for u: SimEntity in helis:
		if w.edge_dist(u, tgt) <= OrderSys.max_range(w, u, tgt) + FX.ONE / 2:
			inr += 1
		if u.target == tgt.id:
			firing += 1
		sx += u.pos.x - tgt.pos.x
		sy += u.pos.y - tgt.pos.y
	var ga := _air_min_gap(helis)
	print("attack: min gap %.2f tiles, %d stacked, %d in range, %d on target" % [ga[0] / float(FX.ONE), ga[1], inr, firing])
	_check(ga[0] >= FX.ONE and ga[1] == 0, "attacking helicopters stay >= 1 tile apart, none stacked (min %.2f)" % (ga[0] / float(FX.ONE)))
	_check(inr >= 38 and firing == 40, "and (nearly) all of them sit in weapon range on the target (%d in range)" % inr)
	# mixed group: tanks keep the ground formation, helicopters the air one
	var tanks: Array = []
	var mixed: Array = []
	var c2 := FX.to_tile(a[2]) + Vector2i(-10, 8)
	for k in 6:
		var t := w.spawn_unit(&"us_halberd", 0, null, FX.tile_center(c2 + Vector2i(k * 2, 0)))
		tanks.append(t)
		mixed.append(t.id)
	for k in 10:
		mixed.append(helis[k].id)
	r.issue({"p": 0, "t": "move", "ids": mixed, "pos": FX.tile_center(c2 + Vector2i(0, -6))})
	_ticks(r, 2)
	var ok := true
	for t: SimEntity in tanks:
		ok = ok and not t.orders.is_empty() and w.map.passable(FX.to_tile(t.orders[0]["pos"]), true)
	_check(ok, "mixed group: ground units still get passable tile slots")
	# cost: 400 airborne helicopters in one area, separation pass only
	var r4 := _us_runner(78)
	var w4 := r4.sim
	var c4 := _zh_open(w4, 7)
	for k in 400:
		var u := w4.spawn_unit(&"us_harrier", k % 2, null, FX.tile_center(c4))
		u.pos = FX.tile_center(c4) + Vector2i((k % 20) * 900 - 9000, (k / 20) * 900 - 9000)
	w4.rebuild_spatial()
	var t0 := Time.get_ticks_usec()
	for i in 20:
		AirSys.separate(w4)
	var ms := (Time.get_ticks_usec() - t0) / 20000.0
	print("separation pass, 400 helicopters packed 0.9 tile apart: %.2f ms per tick (box)" % ms)
	_check(ms < 25.0, "separation for 400 aircraft is cheap (%.2f ms per tick on the box)" % ms)

func test_turret() -> void:
	var stuck: Array = []
	var n := 0
	for id in Content.units:
		var d: UnitDef = Content.units[id]
		if d.weapons.is_empty() or d.move_layer == &"air" or d.tags.has("stub") or d.tags.has("suicide"):
			continue
		var ground := false
		for wid in d.weapons:
			ground = ground or Content.weapon(wid).targets_ground
		if not ground:
			continue
		for mode in ["attack", "idle", "moving", "far"]:
			n += 1
			var res := _turret_case(String(id), mode)
			if not res[0]:
				stuck.append("%s/%s(%s)" % [id, mode, res[1]])
	for id in Content.buildings:
		var bd: BuildingDef = Content.buildings[id]
		if bd.weapons.is_empty():
			continue
		var ground2 := false
		for wid in bd.weapons:
			ground2 = ground2 or Content.weapon(wid).targets_ground
		if not ground2:
			continue
		for mode in ["idle", "moving"]:
			n += 1
			var res2 := _turret_case(String(id), mode, true)
			if not res2[0]:
				stuck.append("%s/%s(%s)" % [id, mode, res2[1]])
	_check(stuck.is_empty(), "turrets track and fire on targets behind / circling them (%d cases), stuck: %s" % [n, stuck])

func _turret_case(def: String, mode: String, building := false) -> Array:
	var r := _zh_runner(41)
	var w := r.sim
	var c := _zh_open(w, 7)
	var u: SimEntity
	if building:
		var bd: BuildingDef = Content.building(StringName(def))
		u = w._place_building(bd, 0, c - bd.footprint / 2, 0, true)
		u.powered = true
		w.players[0].low_power = false
	else:
		u = w.spawn_unit(StringName(def), 0, null, FX.tile_center(c))
		u.pos = FX.tile_center(c)
		u.face = 0
		u.tface = 0
		u.dir = FX.dir_of(0)
		u.home = u.pos
		w.rebuild_spatial()
	var wl: PackedStringArray = Content.building(StringName(def)).weapons if building else Content.unit(StringName(def)).weapons
	var rng := 1 << 30
	var rmax := 0
	var rmin := 0
	var slow := 0
	var sight := 99 if building else Content.unit(StringName(def)).sight
	for wid in wl:
		var wd: WeaponDef = Content.weapon(wid)
		rmax = maxi(rmax, wd.range_mt)
		if wd.targets_ground:
			rng = mini(rng, wd.range_mt)
			rmin = maxi(rmin, wd.min_range_mt)
			slow = maxi(slow, wd.cooldown_ms + wd.pre_attack_ms)
	var off := clampi(rng / 1000 - 2, rmin / 1000 + 2, sight - 2) + (1 if building else 0)
	if mode == "far":
		# beyond the ground weapons' reach but inside an anti-air weapon's: must close in (M2.8 stuck case)
		off = clampi(rmax / 1000 - 1, off, sight - 1)
		mode = "attack"
	var need := clampi(16000 / maxi(1, slow) / 2, 1, 3)
	var t := w.spawn_unit(&"eu_crawler", 1, null, FX.tile_center(c + Vector2i(0, -off)))
	t.pos = FX.tile_center(c + Vector2i(0, -off))
	t.max_hp = 1000000
	t.hp = 1000000
	for p in [0, 1]:
		var ex: PackedByteArray = w.fog.explored[p]
		ex.fill(1)
		w.fog.explored[p] = ex
	if mode == "attack":
		r.issue({"p": 0, "t": "attack", "ids": [u.id], "target": t.id})
	var hits := 0
	var last := t.hp
	var ang := 0
	for i in 20 * 16:
		if mode == "moving" and i % 20 == 0:
			# the target strafes around the shooter at a fixed range
			ang = (ang + 128) % FX.ANG
			var dv := FX.dir_of(ang)
			var dest := FX.to_tile(u.pos + Vector2i(dv.x * off, dv.y * off))
			r.issue({"p": 1, "t": "move", "ids": [t.id], "pos": FX.tile_center(dest)})
		r.advance()
		if t.hp < last:
			hits += 1
			last = t.hp
	return [hits >= need, "hits=%d/%d tface=%d off=%d" % [hits, need, u.tface, off]]

## M2.8 #2: the supply stashes by each spawn (home seam + home cache) should last ~17 minutes
## against a normal opening economy: real AI vs AI (medium) 1v1 matches, one per faction,
## recording when each player's home stashes run dry. Arg: comma list of maps (default varno).
func test_stash(maps_arg: String) -> void:
	var maps: Array = maps_arg.split(",", false) if maps_arg != "" else ["varno_crossing"]
	var times: Array = []
	for mid in maps:
		for pair in [["us", "eu"], ["eu", "tpla"], ["tpla", "us"]]:
			var r := MatchRunner.new()
			r.record_replay = false
			var cfg := make_cfg("1v1", 23, ["medium", "medium"], pair)
			cfg["map"] = mid
			r.start(cfg)
			var w := r.sim
			var home := {}     # resource id -> owner pid
			for p in w.players:
				var hq: SimEntity = null
				for id in w.ids:
					var e: SimEntity = w.ents[id]
					if e.owner == p.id and e.kind == SimEntity.Kind.BUILDING:
						hq = e
				for id in w.ids:
					var e2: SimEntity = w.ents[id]
					if e2.kind == SimEntity.Kind.RESOURCE and FX.dist(e2.pos, hq.pos) < FX.ONE * 20:
						home[e2.id] = p.id
			var left := {0: 0, 1: 0}
			for rid in home:
				left[home[rid]] += 1
			var hist := {0: [], 1: []}   # M3.2: [tick, supply left] per player, every 100 ticks
			var done := {}
			var harv := {0: 0, 1: 0}
			var cap := 20 * 60 * 26
			for i in cap:
				r.advance()
				if i % 100 != 0:
					continue
				for hp in [0, 1]:
					var amt := 0
					for rid in home:
						if home[rid] == hp and w.get_ent(rid) != null:
							amt += maxi(0, w.get_ent(rid).amount)
					hist[hp].append([w.tick, amt])
				if i == 20 * 60 * 6:
					for id in w.ids:
						var u: SimEntity = w.ents[id]
						if u.alive and u.owner >= 0 and u.kind == SimEntity.Kind.UNIT and w.udef(u).harvest_capacity > 0:
							harv[u.owner] += 1
				for rid in home:
					var re := w.get_ent(rid)
					var key := "%d" % rid
					if not done.has(key) and (re == null or re.amount <= 0):
						done[key] = w.tick
						left[home[rid]] -= 1
						if left[home[rid]] == 0:
							var t := float(w.tick) / 20.0 / 60.0
							times.append(t)
							print("STASH %s P%d %s: home stashes empty at %.1f min (harvesters at 6:00: %d)" % [mid, home[rid], pair[home[rid]], t, harv[home[rid]]])
				if (left[0] == 0 and left[1] == 0) or w.game_over:
					break
			for pid in [0, 1]:
				if left[pid] > 0:
					var rem := 0
					for rid in home:
						if home[rid] == pid and w.get_ent(rid) != null:
							rem += w.get_ent(rid).amount
					# M3.2: the rule is that stashes last ~17 min of mining, not that matches last
					# that long. When the match ends first, extrapolate the empty time from the
					# drain rate over the last 3 minutes (the economy is ramped up by then).
					var h: Array = hist[pid]
					var tm := float(w.tick) / 1200.0
					var j: int = maxi(0, h.size() - 1 - 36)
					var dt: int = int(h[-1][0]) - int(h[j][0])
					var drained: int = int(h[j][1]) - int(h[-1][1])
					var est: float = tm + (float(rem) / (float(drained) / float(dt))) / 1200.0 if drained > 0 and dt > 0 else 99.0
					print("STASH %s P%d %s: %d left after %.1f min, est. empty at %.1f min (drain %d / 3 min)" % [mid, pid, pair[pid], rem, tm, est, drained])
					times.append(est)
	times.sort()
	var med: float = times[times.size() / 2] if not times.is_empty() else 0.0
	print("STASH median %.1f min over %d players: %s" % [med, times.size(), times])
	_check(med >= 15.0 and med <= 19.0, "home supply stashes last ~17 min with the AI opening economy (median %.1f min)" % med)

## M3.2 new items: capture specialists, barricades, Drone Operator + research, Field Engineer,
## AA ground fire, queue 15 / no unit cap / $2M funds.
func _roster_m32() -> void:
	_check(ProdSys.MAX_QUEUE == 15 and SimWorld.SUPPLY_CAP == 9999999, "production queue 15, funds cap $9,999,999 (M3.3)")
	for aa in [&"us_patriot", &"eu_flak_tower", &"tpla_wasp_nest", &"ecc_aa_site"]:
		var air_dps := 0.0
		var gnd_dps := 0.0
		for wid in Content.building(aa).weapons:
			var wd: WeaponDef = Content.weapon(wid)
			if wd.targets_air:
				air_dps += float(wd.damage) / wd.cooldown_ms
			if wd.targets_ground:
				gnd_dps += float(wd.damage) / wd.cooldown_ms
		_check(gnd_dps > 0.0 and air_dps > gnd_dps, "%s shoots ground too but stays better vs air (%.3f air / %.3f ground)" % [aa, air_dps, gnd_dps])
	var fe := Content.unit(&"eu_field_engineer")
	_check(SimWorld.can_construct(fe, Content.building(&"eu_sandbags")) and SimWorld.can_construct(fe, Content.building(&"eu_minefield")) and not SimWorld.can_construct(fe, Content.building(&"eu_heavy_factory")), "Field Engineer builds barricades + minefields only")
	# --- capture (Germany Sturmtrupp vs a TPLA camp)
	var r := _zh_runner(61)
	var w := r.sim
	var c := _zh_open(w, 7)
	_roster_reveal(w)
	var camp := w._place_building(Content.building(&"tpla_camp"), 1, c + Vector2i(-1, 3), 0, true)
	var st := w.spawn_unit(&"eu_sturmtrupp", 0, null, FX.tile_center(c))
	st.pos = FX.tile_center(c)
	r.issue({"p": 0, "t": "capture", "ids": [st.id], "target": camp.id})
	_ticks(r, 60)
	r.issue({"p": 0, "t": "move", "ids": [st.id], "pos": FX.tile_center(c + Vector2i(0, -5))})
	_ticks(r, 120)
	_check(camp.owner == 1, "moving away cancels the capture")
	r.issue({"p": 0, "t": "capture", "ids": [st.id], "target": camp.id})
	_ticks(r, 260)
	_check(camp.owner == 0 and camp.team == w.player_team(0) and st.alive, "Sturmtrupp captures an enemy structure in ~6 s and survives (owner %d)" % camp.owner)
	w.players[0].supply = 5000
	r.issue({"p": 0, "t": "queue", "target": camp.id, "def": "tpla_militia"})
	_ticks(r, 2)
	_check(not camp.queue.is_empty(), "captured structure trains the original faction's units")
	# --- barricade: max 3, exit
	var bar := w._place_building(Content.building(&"eu_barricade"), 0, c + Vector2i(3, -3), 0, true)
	var inf: Array = []
	for k in 4:
		var g := w.spawn_unit(&"eu_grenadier", 0, null, FX.tile_center(c + Vector2i(k + 1, -1)))
		g.pos = FX.tile_center(c + Vector2i(k + 1, -1))
		inf.append(g.id)
	r.issue({"p": 0, "t": "garrison", "ids": inf, "target": bar.id})
	_ticks(r, 200)
	var inside := 0
	for id in inf:
		if w.ents[id].res_id == -bar.id:
			inside += 1
	_check(inside == 3, "infantry man a concrete barricade, max 3 (%d inside)" % inside)
	r.issue({"p": 0, "t": "unload", "ids": [bar.id]})
	_ticks(r, 2)
	inside = 0
	for id in inf:
		if w.ents[id].res_id == -bar.id:
			inside += 1
	_check(inside == 0, "barricade troops exit")
	# --- US research + Drone Operator
	var r2 := MatchRunner.new()
	r2.record_replay = false
	r2.start(make_cfg("1v1", 63, [], ["us", "tpla"]))
	r2.ais.clear()
	var w2 := r2.sim
	var c2 := _zh_open(w2, 7)
	_check(w2.prereqs_met(0, Content.unit(&"us_drone_operator").prereqs) != "", "Drone Operator locked before Drone Warfare research")
	var sc := w2._place_building(Content.building(&"us_strategy"), 0, c2 + Vector2i(-6, -2), 0, true)
	w2.players[0].supply = 20000
	r2.issue({"p": 0, "t": "queue", "target": sc.id, "def": "us_up_drones", "n": 3})
	_ticks(r2, 2)
	_check(sc.queue.size() == 1, "research queues once")
	_ticks(r2, 1400)
	_check(w2.players[0].upgrades.has("us_up_drones") and w2.prereqs_met(0, Content.unit(&"us_drone_operator").prereqs) == "", "Strategic Center research unlocks the Drone Operator")
	var op := w2.spawn_unit(&"us_drone_operator", 0, null, FX.tile_center(c2))
	op.pos = FX.tile_center(c2)
	r2.issue({"p": 0, "t": "drone", "ids": [op.id], "kind": "bomb"})
	r2.issue({"p": 0, "t": "drone", "ids": [op.id], "kind": "scout"})
	_ticks(r2, 4)
	var drones: Array = []
	for id in w2.ids:
		var e: SimEntity = w2.ents[id]
		if e.alive and e.kind == SimEntity.Kind.UNIT and Content.unit(e.def_id).tags.has("drone") and e.air_home == op.id:
			drones.append(e)
	_check(drones.size() == 2 and w2.drone_wait(op, "bomb") > 0, "operator launches a bomb drone and a scout drone (%d)" % drones.size())
	for d: SimEntity in drones:
		w2._kill(d, null)
	_ticks(r2, 2)
	var wt := w2.drone_wait(op, "scout")
	_check(wt > 1100 and wt <= 1200, "a lost drone comes back after 60 s (%d ticks)" % wt)
