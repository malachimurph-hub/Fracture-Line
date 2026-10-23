class_name MapDef
extends Resource
@export var id: StringName
@export var name_key: String = ""
@export var size: Vector2i = Vector2i(128, 128)
@export var tiles_path: String = ""        ## text grid, one char per tile
@export var spawns: Array[Vector2i] = []   ## HQ top-left tile per player slot
@export var resources: Array[Dictionary] = [] ## {kind: seam|cache, tile: Vector2i, amount: int}
@export var neutrals: Array[Dictionary] = []  ## {kind, tile}
@export var description_key: String = ""
@export var env: StringName = &"desert"   ## M2.5 view environment (MapEnv): desert | winter | temperate
## M2.8 map builder: optional pre-placed units / buildings, {kind, spawn, tile}. Each belongs to
## the player who starts on spawn slot `spawn`; skipped when no player uses that slot.
@export var prebuilt: Array[Dictionary] = []
## M2.8 custom (user://maps) maps: not exported, set by MapStore.
var custom := false
var transient := false          ## embedded copy restored from a save (hidden from the lobby)
var tiles_text := ""            ## in-memory tile grid (used instead of tiles_path when set)
var content_hash := ""          ## MapStore.hash_of() of the map's sim-relevant data
