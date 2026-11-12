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
var pop_cap: int = 1000000   ## M3.2: no unit cap (Malachi). Kept as a field for saves; never reached.
var upgrades: Dictionary = {}   ## M3.2: researched upgrades (unit-def ids with tag "upgrade") -> true
var ability_ready: Dictionary = {}  ## Russia ability id -> tick it becomes ready
var power_down_until: int = 0       ## hack: power plants produce nothing until this tick
var radar_until: int = 0            ## hack: minimap stays blank until this tick
var siphon_from: int = -1           ## hack: player id cash is drawn from
var siphon_until: int = 0
var siphon_rate: int = 0            ## supply per second
var eliminated: bool = false
var is_ai: bool = false
var stats: Dictionary = {"built": 0, "lost": 0, "kills": 0, "harvested": 0, "structures_lost": 0, "structures_killed": 0}

const RANK_XP := [0, 0, 2500, 7000, 14000, 24000]   ## index = rank

func to_dict() -> Dictionary:
	return {"id": id, "team": team, "color": color, "faction": faction, "supply": supply, "xp": xp, "rank": rank,
		"points": points, "powers": powers.duplicate(true), "logistics_until": logistics_until, "eliminated": eliminated,
		"is_ai": is_ai, "stats": stats.duplicate(), "pop_cap": pop_cap, "upgrades": upgrades.duplicate(),
		"ability_ready": ability_ready.duplicate(), "power_down_until": power_down_until, "radar_until": radar_until,
		"siphon_from": siphon_from, "siphon_until": siphon_until, "siphon_rate": siphon_rate}

static func from_dict(d: Dictionary) -> SimPlayer:
	var p := SimPlayer.new()
	for k in d:
		p.set(k, d[k])
	p.pop_cap = maxi(p.pop_cap, 1000000)   # M3.2: older saves carried the 60 cap
	return p
