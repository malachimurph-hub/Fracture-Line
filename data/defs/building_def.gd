class_name BuildingDef
extends Resource
@export var id: StringName
@export var faction: StringName = &"eu"
@export var name_key: String = ""
@export var desc_key: String = ""
@export var category: StringName = &"base"  ## base | production | defense | tech | superweapon
@export var cost: int = 500
@export var build_time_ms: int = 10000
@export var footprint: Vector2i = Vector2i(3, 3)
@export var max_hp: int = 1000
@export var power: int = 0                   ## +produces / -consumes
@export var grid_radius: int = 0             ## tiles; grid source radius
@export var sight: int = 6
@export var prereqs: PackedStringArray = []
@export var produces: PackedStringArray = []
@export var is_hq: bool = false
@export var is_refinery: bool = false
@export var passive_income: int = 0          ## supply per second (Hub)
@export var free_unit: StringName = &""      ## unit spawned on completion
@export var shield_pct: int = 25             ## grid shield as % of max hp
@export var view_scene: String = ""
@export var stubs: PackedStringArray = []
@export var weapons: PackedStringArray = []   ## defensive structures
@export var needs_power_to_fire: bool = true
@export var garrison_capacity: int = 0        ## civilian buildings (infantry squads)
@export var capturable: bool = false          ## neutral tech (Veridite Pump)
@export var capture_income: int = 0           ## supply per second when owned
@export var buildable: bool = true            ## shows in the build grid
@export var tags: PackedStringArray = []      ## tunnel | trap | stealth | camo | hole | no_hole (TPLA mechanics)
@export var aux_radius: int = 0               ## tiles; camo net cover radius
