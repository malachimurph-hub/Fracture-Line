class_name UnitDef
extends Resource
@export var id: StringName
@export var faction: StringName = &"eu"
@export var name_key: String = ""
@export var desc_key: String = ""
@export var cost: int = 100
@export var build_time_ms: int = 10000
@export var pop: int = 1
@export var prereqs: PackedStringArray = []
@export var tags: PackedStringArray = []   ## infantry, vehicle, builder, harvester, aa, shield, transport
@export var max_hp: int = 100
@export var armor_type: StringName = &"infantry"
@export var weapons: PackedStringArray = []
@export var speed_mtps: int = 1000          ## milli-tiles per second
@export var move_layer: StringName = &"foot" ## foot | vehicle | air(future)
@export var sight: int = 7                   ## tiles
@export var radius_mt: int = 400             ## body radius, milli-tiles
@export var shield_aura_radius: int = 0      ## tiles; Aegis
@export var shield_aura_pct: int = 0         ## % of max hp granted as shield to units in aura
@export var harvest_capacity: int = 0
@export var role: StringName = &"infantry"   ## role icon key for far zoom
@export var view_scene: String = ""
@export var abilities: PackedStringArray = []
@export var stubs: PackedStringArray = []    ## features listed but not implemented (shown as [STUB])
