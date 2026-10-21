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
