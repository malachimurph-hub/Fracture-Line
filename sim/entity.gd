class_name SimEntity
extends RefCounted
## One simulation entity. Plain data only; systems in sim/systems operate on it.

enum Kind { UNIT, BUILDING, RESOURCE, NEUTRAL, CRATE }

var id: int = 0
var kind: int = Kind.UNIT
var def_id: StringName = &""
var owner: int = -1
var team: int = -1
var pos: Vector2i = Vector2i.ZERO      ## fixed-point center
var hp: int = 1
var max_hp: int = 1
var shield: int = 0
var max_shield: int = 0
var last_hit_tick: int = -1000
var alive: bool = true
var radius: int = 400                   ## fixed-point body radius
var sight: int = 6

# --- unit
var orders: Array = []                  ## Array[Dictionary]
var path: Array = []                    ## Array[Vector2i] tiles
var path_i: int = 0
var path_goal: Vector2i = Vector2i(-1, -1)
var path_pending: bool = false
var goal: Vector2i = Vector2i(-1, -1)  ## fixed-point move goal (-1 = none)
var stuck: int = 0
var done_goal: Vector2i = Vector2i(-1, -1)  ## last goal MoveSys finished (reached or gave up)
var vet: int = 0                        ## veterancy rank 0-3
var vxp: int = 0                        ## veterancy xp
var target: int = 0
var cds: Array = []                     ## weapon cooldown ticks
var home: Vector2i = Vector2i.ZERO      ## leash / guard anchor
var carry: int = 0
var res_id: int = 0
var phase: int = 0                      ## harvest phase
var phase_t: int = 0
var overcharge_until: int = 0
var dir: Vector2i = Vector2i(0, 1024)   ## last facing (view hint)
var moving: bool = false
var firing_tick: int = -100
var aura_tick: int = -100

# --- building
var tile: Vector2i = Vector2i.ZERO      ## top-left footprint tile
var fp: Vector2i = Vector2i.ONE
var rot: int = 0                        ## 0 south, 1 east, 2 north, 3 west (exit side)
var built: bool = true
var progress: int = 0
var build_ticks: int = 1
var queue: Array = []                   ## Array[StringName] unit ids
var q_progress: int = 0
var q_paid: Array = []                  ## supply paid per queue entry (refunds)
var rally: Vector2i = Vector2i(-1, -1)
var rally_attack: bool = false
var repeat: bool = false
var powered: bool = true
var gridded: bool = false   ## inside an EU Grid field (HQ / Reactor / Pylon) - drives Grid shields only
var hold_reason: String = ""            ## why production is paused (view)

# --- resource / salvage crate (amount = supply value)
var amount: int = 0
var max_amount: int = 0

# --- TPLA mechanics
var tier: int = 0                       ## salvage tier 0-3 (TPLA vehicles)
var aux_def: StringName = &""           ## rebuild hole: structure to rebuild
var aux_t: int = 0                      ## hole rebuild tick / crate expiry tick
var stealthy: bool = false              ## currently hidden from enemies (camo net / demo trap)
var stealth_mask: int = 0               ## bit per team that currently detects it
# M2.3 locomotion / aiming (fixed-point angles, FX.ANG per turn)
var face: int = 0                       ## hull heading
var spd: int = 0                        ## current speed, fx per tick
var gspd: int = 0                       ## group speed cap for this move (0 = none)
var tface: int = 0                      ## turret heading (absolute)
var pre: Array = []                     ## per weapon: pre-attack ticks left (0 = idle)
var pre_ok: Array = []                  ## per weapon: target id whose pre-attack is done
var ammo: Array = []                    ## per weapon: rounds left in clip

func is_unit() -> bool: return kind == Kind.UNIT
func is_building() -> bool: return kind == Kind.BUILDING

func head() -> Dictionary:
	return orders[0] if not orders.is_empty() else {}

func is_idle() -> bool:
	return orders.is_empty()

const _FIELDS := ["id", "kind", "def_id", "owner", "team", "pos", "hp", "max_hp", "shield", "max_shield", "last_hit_tick",
	"alive", "radius", "sight", "orders", "path", "path_i", "path_goal", "goal", "stuck", "done_goal", "vet", "vxp", "target", "cds", "home",
	"carry", "res_id", "phase", "phase_t", "overcharge_until", "dir", "moving", "aura_tick", "tile", "fp", "rot", "built",
	"progress", "build_ticks", "queue", "q_progress", "q_paid", "rally", "rally_attack", "repeat", "powered", "gridded", "hold_reason",
	"amount", "max_amount", "tier", "aux_def", "aux_t", "stealthy", "stealth_mask",
	"face", "spd", "gspd", "tface", "pre", "pre_ok", "ammo"]

func to_dict() -> Dictionary:
	var d := {}
	for f in _FIELDS:
		var v = get(f)
		if v is Array:
			d[f] = v.duplicate(true)
		else:
			d[f] = v
	return d

static func from_dict(d: Dictionary) -> SimEntity:
	var e := SimEntity.new()
	for f in _FIELDS:
		if d.has(f):
			var v = d[f]
			if v is Array:
				e.set(f, v.duplicate(true))
			else:
				e.set(f, v)
	e.path_pending = false
	return e
