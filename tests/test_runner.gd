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
			run_match(mode, seed, true)
		"soak":
			var n := int(args[1]) if args.size() > 1 else 5
			var wins := {}
			var t0 := Time.get_ticks_msec()
			for i in n:
				var mode2: String = ["1v1", "1v1", "2v2", "ffa"][i % 4]
				var res := run_match(mode2, 1000 + i, false)
				wins[mode2 + ":" + str(res["winner"])] = wins.get(mode2 + ":" + str(res["winner"]), 0) + 1
			print("SOAK done %d matches in %d s; outcomes=%s" % [n, (Time.get_ticks_msec() - t0) / 1000, wins])
		"replay":
			test_replay()
		"saveload":
			test_saveload()
		"content":
			test_content()
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

static func make_cfg(mode: String, seed: int, diffs: Array = []) -> Dictionary:
	var slots: Array = []
	match mode:
		"1v1":
			slots = [{"team": 0, "spawn": 0}, {"team": 1, "spawn": 1}]
		"2v2":
			slots = [{"team": 0, "spawn": 0}, {"team": 0, "spawn": 3}, {"team": 1, "spawn": 1}, {"team": 1, "spawn": 2}]
		"ffa":
			slots = [{"team": 0, "spawn": 0}, {"team": 1, "spawn": 1}, {"team": 2, "spawn": 2}, {"team": 3, "spawn": 3}]
	for i in slots.size():
		slots[i]["kind"] = "ai"
		slots[i]["color"] = i
		slots[i]["difficulty"] = diffs[i] if i < diffs.size() else "medium"
		slots[i]["personality"] = "eu_ironclad"
	return {"map": "varno_crossing", "seed": seed, "options": {"fog": true, "start_money": 10000}, "slots": slots}

func run_match(mode: String, seed: int, verbose: bool, max_minutes: int = 40) -> Dictionary:
	var r := MatchRunner.new()
	r.record_replay = false
	r.start(make_cfg(mode, seed))
	var t0 := Time.get_ticks_msec()
	var max_ticks := max_minutes * 60 * 20
	var first_attack := {}
	var worst_tick_ms := 0.0
	var sum_ms := 0.0
	while not r.sim.game_over and r.sim.tick < max_ticks:
		var a := Time.get_ticks_usec()
		r.advance()
		var dt := (Time.get_ticks_usec() - a) / 1000.0
		sum_ms += dt
		worst_tick_ms = maxf(worst_tick_ms, dt)
		for ev in r.sim.events:
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
	var ok: bool = r.sim.game_over and r.sim.winner_team >= 0
	# winner must be a team that still has a non-eliminated player, and all others eliminated
	if ok:
		for p in r.sim.players:
			if (p.team == r.sim.winner_team) == p.eliminated and p.team != r.sim.winner_team:
				ok = false
			if p.team != r.sim.winner_team and not p.eliminated:
				ok = false
	if not ok:
		failed = true
	print("MATCH %s seed=%d -> winner team %d after %d:%02d (%s) avg_tick=%.2fms worst=%.1fms first_base_attack_s=%s wall=%.1fs %s" % [
		mode, seed, r.sim.winner_team, secs / 60, secs % 60, "over" if r.sim.game_over else "TIMEOUT", res["avg_tick_ms"],
		worst_tick_ms, first_attack, res["wall_s"], "OK" if ok else "FAIL"])
	for p in r.sim.players:
		print("   P%d team%d elim=%s supply=%d rank=%d stats=%s" % [p.id, p.team, p.eliminated, p.supply, p.rank, p.stats])
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
		line += " | P%d $%d u%d b%d army$%d pw%d/%d r%d%s" % [p.id, p.supply, units, blds, army, p.power_used, p.power_prod, p.rank, " X" if p.eliminated else ""]
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
