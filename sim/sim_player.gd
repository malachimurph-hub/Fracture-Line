class_name SimPlayer
extends RefCounted
var id: int = 0
var team: int = 0
var color: int = 0
var faction: StringName = &"eu"
var supply: int = 10000
var xp: int = 0                 ## general's Command XP
var rank: int = 1
var points: int = 1             ## unspent general points
var powers: Dictionary = {}     ## power id -> {"bought": bool, "ready": tick}
var logistics_until: int = 0
var power_prod: int = 0
var power_used: int = 0
var low_power: bool = false
var pop: int = 0
var pop_cap: int = 60
var eliminated: bool = false
var is_ai: bool = false
var stats: Dictionary = {"built": 0, "lost": 0, "kills": 0, "harvested": 0, "structures_lost": 0, "structures_killed": 0}

const RANK_XP := [0, 0, 2500, 7000, 14000, 24000]   ## index = rank

func to_dict() -> Dictionary:
	return {"id": id, "team": team, "color": color, "faction": faction, "supply": supply, "xp": xp, "rank": rank,
		"points": points, "powers": powers.duplicate(true), "logistics_until": logistics_until, "eliminated": eliminated,
		"is_ai": is_ai, "stats": stats.duplicate(), "pop_cap": pop_cap}

static func from_dict(d: Dictionary) -> SimPlayer:
	var p := SimPlayer.new()
	for k in d:
		p.set(k, d[k])
	return p
