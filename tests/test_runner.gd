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
		"placement":
			test_placement()
		"audio":
			test_audio()
		"content":
			test_content()
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
			for u in ta._laborers():
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
			re.start(make_cfg("1v1", int(args[1]) if args.size() > 1 else 21, [dfs, dfs], ["eu", "tpla"]))
			var mins := int(args[2]) if args.size() > 2 else 8
			var deaths := {}
			for mi in mins:
				for k in 1200:
					re.advance()
					for ev in re.sim.events:
						if ev["t"] == "death" and ev.get("kind", -1) == SimEntity.Kind.UNIT and ev.get("by", &"") != &"":
							var kk := "%s<-%s" % [ev["def"], ev["by"]]
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
					print("min %d P%d %s supply=%d harvested=%d harvesting=%d army$=%d bld=%d %s kills=%d lost=%d" % [mi + 1, pid, re.sim.faction_of(pid), pl.supply, pl.stats["harvested"], harv, army, nb, str(bl), pl.stats["kills"], pl.stats["lost"]])
				if re.sim.game_over:
					print("game over")
					break
			var dk := deaths.keys()
			dk.sort_custom(func(x, y): return deaths[x] > deaths[y])
			for k2 in dk.slice(0, 25):
				print("  death %s x%d" % [k2, deaths[k2]])
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
	return {"map": "varno_crossing", "seed": seed, "options": {"fog": true, "start_money": 10000}, "slots": slots}

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
	while not r.sim.game_over and r.sim.tick < max_ticks:
		var a := Time.get_ticks_usec()
		r.advance()
		var dt := (Time.get_ticks_usec() - a) / 1000.0
		sum_ms += dt
		worst_tick_ms = maxf(worst_tick_ms, dt)
		for ev in r.sim.events:
			if ev["t"] == "attacked" and int(ev["by"]) >= 0 and int(ev["owner"]) >= 0 and int(ev["by"]) != int(ev["owner"]) and not r.sim.enemies(r.sim.player_team(int(ev["by"])), r.sim.player_team(int(ev["owner"]))):
				friendly_hits += 1
			if ev["t"] == "attacked" and r.sim.ents.has(ev["id"]):
				var tgt: SimEntity = r.sim.ents[ev["id"]]
				if tgt.kind == SimEntity.Kind.BUILDING and not first_attack.has(ev["by"]):
					first_attack[ev["by"]] = r.sim.tick / 20
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
	return res

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
	var m1: AudioStream = ad.stream(ad.MUSIC["battle"])
	_check(m1 is AudioStreamOggVorbis and (m1 as AudioStreamOggVorbis).loop, "battle music loops")
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
	for fac in ["eu", "tpla"]:
		for uid in ad.manifest["factions"][fac]["units"]:
			var ud2: Dictionary = ad.manifest["factions"][fac]["units"][uid]
			for ev in ud2["events"]:
				if int(ad.variants(fac, ud2["folder"], ev)[1]) == 2:
					not_ai.append("%s/%s" % [uid, ev])
	_check(missing.is_empty(), "every manifest line has a voice %s" % [missing])
	_check(not_ai.is_empty(), "every EU + TPLA line has a recorded or AI voice (no robotic fallback) %s" % [not_ai.slice(0, 8)])
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
	ad.announcer_faction = "eu"
	_check(ad.unit_voice("tpla", "tpla_rattler", "select"), "TPLA unit voice plays")
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
	# 4. black shroud -> forbidden (ZH)
	var r2 := MatchRunner.new()
	r2.record_replay = false
	r2.start(make_cfg("1v1", 3))
	var w2 := r2.sim
	var sh := Vector2i(-1, -1)
	for i in w2.map.w * w2.map.h:
		var t3 := Vector2i(i % w2.map.w, i / w2.map.w)
		if not w2.fog.explored_tile(0, t3) and SimMap.BUILD_OK[w2.map.tiles[i]] and w2.map.nobuild[i] == 0 and t3.x > 2 and t3.y > 2 and t3.x < w2.map.w - 6 and t3.y < w2.map.h - 6:
			sh = t3
			break
	_check(w2.can_place(0, &"eu_reactor", sh) == "REASON_SHROUD", "unexplored shroud is not buildable (%s)" % w2.can_place(0, &"eu_reactor", sh))
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
