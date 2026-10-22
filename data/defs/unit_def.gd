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
@export var move_layer: StringName = &"foot" ## foot | vehicle | air (M2.5)
@export var sight: int = 7                   ## tiles
@export var radius_mt: int = 400             ## body radius, milli-tiles
@export var shield_aura_radius: int = 0      ## tiles; Aegis
@export var shield_aura_pct: int = 0         ## % of max hp granted as shield to units in aura
@export var harvest_capacity: int = 0
@export var role: StringName = &"infantry"   ## role icon key for far zoom
@export var view_scene: String = ""
## M2.3 locomotor (ZH-style movement feel; our own tuning values). "" = derived from tags:
## infantry -> legs, tank / builder / shield -> treads, other vehicles -> wheels.
@export var loco: StringName = &""
@export var turn_dps: int = 0                ## hull turn rate, deg/s (0 = locomotor default)
@export var accel_ms: int = 0                ## time 0 -> full speed (0 = default)
@export var turret_dps: int = 0              ## turret traverse deg/s; 0 = no turret (hull must face target)
@export var abilities: PackedStringArray = []
@export var transport_capacity: int = 0      ## M2.4: infantry slots (transport vehicles)
@export var detector: bool = false           ## M2.4: reveals stealthed units/structures in sight
@export var air_slots: int = 0             ## M2.5: Airfield parking slots used (bomber 4, fighter 2, gunship 0)
@export var stubs: PackedStringArray = []    ## features listed but not implemented (shown as [STUB])
