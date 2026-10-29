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

# ------------------------------------------------------------------ M3.3 manual save slots
## Malachi: "load/save, multiple slots, time stamped saves". 8 manual slots next to the suspend
## autosave: slot_<i>.sav (same format + check as the suspend save) and a small slot_<i>.json
## with the time stamp and a label so the list doesn't have to open every save.
const MANUAL_SLOTS := 8

func _manual_path(i: int) -> String:
	return "%s/slot_%d.sav" % [DIR, i]

func _meta_path(i: int) -> String:
	return "%s/slot_%d.json" % [DIR, i]

func save_slot(i: int, data: Dictionary, label: String = "") -> bool:
	if i < 0 or i >= MANUAL_SLOTS:
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open_compressed(_manual_path(i), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var at: float = float(data.get("saved_at", Time.get_unix_time_from_system()))
	data["saved_at"] = at
	f.store_var(data, false)
	f.close()
	var tick := int(data.get("sim", {}).get("tick", 0))
	var mf := FileAccess.open(_meta_path(i), FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({"saved_at": at, "label": label, "tick": tick}))
		mf.close()
	return true

## [{slot, empty, saved_at, label, tick}] for every manual slot.
func list_slots() -> Array:
	var out: Array = []
	for i in MANUAL_SLOTS:
		var e := {"slot": i, "empty": true, "saved_at": 0.0, "label": "", "tick": 0}
		if FileAccess.file_exists(_manual_path(i)):
			e["empty"] = false
			var j = JSON.parse_string(FileAccess.get_file_as_string(_meta_path(i))) if FileAccess.file_exists(_meta_path(i)) else null
			if j is Dictionary:
				e["saved_at"] = float(j.get("saved_at", 0.0))
				e["label"] = String(j.get("label", ""))
				e["tick"] = int(j.get("tick", 0))
		out.append(e)
	return out

func has_any_slot() -> bool:
	for i in MANUAL_SLOTS:
		if FileAccess.file_exists(_manual_path(i)):
			return true
	return false

## The save in slot i, or {} when missing, from another version or failing its check.
func load_slot(i: int) -> Dictionary:
	var p := _manual_path(i)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open_compressed(p, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var d = f.get_var(false)
	f.close()
	if d is Dictionary and d.has("sim") and int(d["sim"].get("save_version", 0)) == SimWorld.SAVE_VERSION and _verify(d):
		return d
	return {}

func delete_slot(i: int) -> void:
	for p in [_manual_path(i), _meta_path(i)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

## "2026-10-28 23:41" in local time.
static func stamp(unix: float) -> String:
	if unix <= 0.0:
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + bias)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]

func has_suspend() -> bool:
	return FileAccess.file_exists(_slot_path(0))

func clear_suspend() -> void:
	for i in SLOTS:
		if FileAccess.file_exists(_slot_path(i)):
			DirAccess.remove_absolute(_slot_path(i))
