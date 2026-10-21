class_name AIPersonalityDef
extends Resource
## AI personality: pure data. Weights 1-5 per GDD section 12.
@export var id: StringName
@export var name_key: String = ""
@export var aggression: int = 3
@export var expansion: int = 3
@export var tech_rush: int = 3
@export var harass: int = 1
@export var opening: PackedStringArray = []     ## scripted build order (building/unit ids)
@export var unit_weights: Dictionary = {}       ## unit id -> weight for late production
@export var wave_growth_pct: int = 35           ## each wave asks for this much more army value
@export var first_wave_value: int = 3500        ## army value needed for wave 1 (Normal)
