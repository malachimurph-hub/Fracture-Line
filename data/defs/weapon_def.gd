class_name WeaponDef
extends Resource
@export var id: StringName
@export var damage: int = 10
@export var range_mt: int = 5000          ## milli-tiles
@export var min_range_mt: int = 0
@export var cooldown_ms: int = 1000
@export var damage_type: StringName = &"small_arms"
@export var splash_mt: int = 0            ## splash radius, milli-tiles (0 = single target)
@export var targets_air: bool = false
@export var targets_ground: bool = true
@export var vfx: StringName = &"tracer"   ## view-only effect key
@export var min_tier: int = 0            ## TPLA salvage tier needed before this weapon fires (bolt-on guns)
## M2.3 weapon timing / accuracy (ZH-style behaviour; our own tuning values)
@export var pre_attack_ms: int = 0          ## aim / set-up delay before firing
@export var pre_attack_type: StringName = &"attack"  ## shot | attack (first shot at a new target) | clip
@export var clip_size: int = 0              ## 0 = no clip (cooldown only)
@export var reload_ms: int = 0              ## clip reload time (cooldown_ms is the delay between shots)
@export var aim_deg: int = 12               ## must face the target within this angle to fire
@export var scatter_mt: int = 0             ## shot lands within this radius of the aim point
@export var scatter_inf_mt: int = 0         ## extra scatter vs infantry (cannons / rockets miss soldiers)
