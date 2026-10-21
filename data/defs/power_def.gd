class_name PowerDef
extends Resource
@export var id: StringName
@export var name_key: String = ""
@export var desc_key: String = ""
@export var rank_required: int = 1
@export var point_cost: int = 1
@export var stub: bool = false        ## listed in the General tray as [STUB], cannot be bought
@export var cooldown_ms: int = 120000
@export var radius: int = 6           ## tiles (0 = untargeted)
@export var duration_ms: int = 20000
@export var amount: int = 0           ## kind-specific
@export var kind: StringName = &"recon"
