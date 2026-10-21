extends Node
## Versioned, ZSTD-compressed suspend saves with 3 rotating slots and hash integrity check.
const SLOTS := 3
const DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func _slot_path(i: int) -> String:
	return "%s/suspend_%d.sav" % [DIR, i]

func save_suspend(data: Dictionary) -> bool:
	# rotate: 1->2, 0->1, new->0
	for i in range(SLOTS - 1, 0, -1):
		if FileAccess.file_exists(_slot_path(i - 1)):
			DirAccess.rename_absolute(_slot_path(i - 1), _slot_path(i))
	var f := FileAccess.open_compressed(_slot_path(0), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	f.store_var(data, false)
	f.close()
	return true

func load_suspend() -> Dictionary:
	for i in SLOTS:
		var p := _slot_path(i)
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open_compressed(p, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if f == null:
			continue
		var d = f.get_var(false)
		f.close()
		if d is Dictionary and d.has("sim") and int(d["sim"].get("save_version", 0)) == SimWorld.SAVE_VERSION:
			if _verify(d):
				return d
	return {}

func _verify(d: Dictionary) -> bool:
	var w := SimWorld.new()
	w.deserialize(d["sim"])
	return w.state_hash() == int(d["sim"]["hash"])

func has_suspend() -> bool:
	return FileAccess.file_exists(_slot_path(0))

func clear_suspend() -> void:
	for i in SLOTS:
		if FileAccess.file_exists(_slot_path(i)):
			DirAccess.remove_absolute(_slot_path(i))
