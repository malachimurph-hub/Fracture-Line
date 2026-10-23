class_name SkirmishConfig
## Lobby model (Generals-style): 4 slots, each Human / Closed / AI (difficulty Easy / Medium / Hard),
## with team 1-4, color, faction and start position (or random). resolve() turns a lobby
## into a MatchRunner cfg; validate() returns "" or a localization key explaining the error.

const MONEY := [5000, 10000, 20000, 50000]
const DIFFS := ["easy", "medium", "hard"]

static func default_setup() -> Dictionary:
	return {
		"map": "varno_crossing", "seed": 0,
		"options": {"fog": true, "start_money": 10000, "superweapons": false},
		"slots": [
			{"kind": "human", "team": 0, "color": 0, "difficulty": "", "spawn": -1, "faction": "eu"},
			{"kind": "ai", "team": 1, "color": 1, "difficulty": "medium", "spawn": -1, "faction": "eu"},
			{"kind": "closed", "team": 2, "color": 2, "difficulty": "medium", "spawn": -1, "faction": "eu"},
			{"kind": "closed", "team": 3, "color": 3, "difficulty": "medium", "spawn": -1, "faction": "eu"},
		],
	}

## M2.5: skirmish maps in lobby order (Varno Crossing first, then by id).
## M2.8: map-builder maps follow the built-in ones (hidden save-embedded copies are left out).
static func map_ids() -> Array:
	var ids: Array = []
	var custom: Array = []
	for k in Content.maps:
		var md: MapDef = Content.maps[k]
		if md.transient:
			continue
		(custom if md.custom else ids).append(k)
	ids.sort_custom(func(a, b): return a == &"varno_crossing" or (b != &"varno_crossing" and String(a) < String(b)))
	custom.sort_custom(func(a, b): return MapStore.tr_name(Content.maps[a]).naturalnocasecmp_to(MapStore.tr_name(Content.maps[b])) < 0)
	return ids + custom

static func active(cfg: Dictionary) -> Array:
	var out: Array = []
	for s in cfg["slots"]:
		if s["kind"] == "human" or s["kind"] == "ai":
			out.append(s)
	return out

static func validate(cfg: Dictionary) -> String:
	var act := active(cfg)
	if act.size() < 2:
		return "LOBBY_ERR_PLAYERS"
	var teams := {}
	var colors := {}
	var spawns := {}
	for s in act:
		teams[int(s["team"])] = true
		if colors.has(int(s["color"])):
			return "LOBBY_ERR_COLOR"
		colors[int(s["color"])] = true
		var sp := int(s["spawn"])
		if sp >= 0:
			if spawns.has(sp):
				return "LOBBY_ERR_SPAWN"
			spawns[sp] = true
	if teams.size() < 2:
		return "LOBBY_ERR_ONE_TEAM"
	var map_def: MapDef = Content.maps.get(StringName(cfg.get("map", "varno_crossing")))
	if map_def == null:
		return "LOBBY_ERR_MAP"
	if act.size() > map_def.spawns.size():
		return "LOBBY_ERR_PLAYERS"
	return ""

## Lobby -> runner cfg: drops open/closed slots, picks a seed if 0, fills random spawns.
static func resolve(cfg: Dictionary) -> Dictionary:
	var out := cfg.duplicate(true)
	var seed := int(cfg.get("seed", 0))
	if seed == 0:
		seed = int(Time.get_unix_time_from_system()) % 1000000 + 1
	out["seed"] = seed
	var rng := PCG32.new()
	rng.seed(seed, 54)
	var act: Array = []
	for s in cfg["slots"]:
		if s["kind"] == "human" or s["kind"] == "ai":
			act.append((s as Dictionary).duplicate())
	var map_def: MapDef = Content.maps[StringName(cfg.get("map", "varno_crossing"))]
	var used := {}
	for s in act:
		if int(s["spawn"]) >= 0:
			used[int(s["spawn"])] = true
	var free: Array = []
	for i in map_def.spawns.size():
		if not used.has(i):
			free.append(i)
	for s in act:
		if int(s["spawn"]) < 0:
			var k := rng.range_int(free.size())
			s["spawn"] = free[k]
			free.remove_at(k)
		if not s.has("faction") or not Content.FACTIONS.has(StringName(s["faction"])):
			s["faction"] = "eu"
		if s["kind"] == "ai" and not s.has("personality"):
			s["personality"] = String(Content.faction(StringName(s["faction"]))["personality"])
	out["slots"] = act
	return out
