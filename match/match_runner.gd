class_name MatchRunner
extends RefCounted
## Owns the SimWorld, AI players, the CommandQueue and the replay recorder.
## Used by the Match scene (rendered) and by headless tests (identical code path).

var sim := SimWorld.new()
var ais: Dictionary = {}          ## player id -> AIPlayer
var replay: Array = []            ## [{tick, cmd}] commands in application order
var record_replay: bool = true
var team_board: Dictionary = {}   ## team -> {target_player, tick}  (allied AI coordination)
var setup_cfg: Dictionary = {}
var replay_mode: bool = false     ## replay: AIs disabled, commands fed from a log
var _replay_feed: Array = []
var _feed_i: int = 0

## cfg: {map, seed, options{fog,start_money,superweapons}, slots[{kind:human|ai, team, color, difficulty, spawn, personality}]}
func start(cfg: Dictionary) -> void:
	setup_cfg = cfg.duplicate(true)
	var map_def: MapDef = Content.maps[StringName(cfg.get("map", "varno_crossing"))]
	var slots: Array = []
	for s in cfg["slots"]:
		slots.append({"team": s["team"], "color": s["color"], "ai": s["kind"] == "ai", "spawn": s["spawn"]})
	sim.setup(map_def, slots, cfg.get("options", {}), int(cfg.get("seed", 1)))
	for i in cfg["slots"].size():
		var s: Dictionary = cfg["slots"][i]
		if s["kind"] == "ai":
			var ai := AIPlayer.new()
			ai.init(self, i, String(s.get("difficulty", "medium")), StringName(s.get("personality", "eu_ironclad")))
			ais[i] = ai

func issue(cmd: Dictionary) -> void:
	if replay_mode:
		return
	sim.queue_command(cmd)

func set_replay_feed(log: Array) -> void:
	replay_mode = true
	_replay_feed = log
	_feed_i = 0

func advance() -> void:
	if replay_mode:
		while _feed_i < _replay_feed.size() and int(_replay_feed[_feed_i]["tick"]) == sim.tick:
			sim.queue_command(_replay_feed[_feed_i]["cmd"])
			_feed_i += 1
	else:
		for pid in ais:
			var ai: AIPlayer = ais[pid]
			if not sim.players[pid].eliminated and (sim.tick + pid) % ai.think_every == 0:
				ai.think()
	if record_replay:
		for c in sim.pending:
			replay.append({"tick": sim.tick, "cmd": c.duplicate(true)})
	sim.step()

func serialize() -> Dictionary:
	var aid := {}
	for pid in ais:
		aid[pid] = ais[pid].to_dict()
	return {"sim": sim.serialize(), "ai": aid, "team_board": team_board.duplicate(true), "setup": setup_cfg}

func deserialize(d: Dictionary) -> void:
	setup_cfg = d["setup"]
	sim.deserialize(d["sim"])
	team_board = d["team_board"]
	ais.clear()
	for k in d["ai"]:
		var ai := AIPlayer.new()
		ai.from_dict(self, d["ai"][k])
		ais[int(k)] = ai
