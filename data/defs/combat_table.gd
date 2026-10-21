class_name CombatTable
extends Resource
## damage_type -> { armor_type -> percent }
@export var table: Dictionary = {}

func mult(damage_type: StringName, armor_type: StringName) -> int:
	var row: Dictionary = table.get(String(damage_type), {})
	return int(row.get(String(armor_type), 100))
