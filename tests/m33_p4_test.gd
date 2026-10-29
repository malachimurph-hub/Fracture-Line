## M3.3 Phase 4 headless checks (run from m33_test): unit / structure icons, the re-voiced
## German engineering lines and the traditional Russian theme.
extends RefCounted

static func run(t: Node) -> void:
	_icons(t)
	_german_voices(t)
	_russian_music(t)
	_no_floating(t)

# ------------------------------------------------------------------ 9: icons
static func _icons(t: Node) -> void:
	var missing: Array = []
	for fac in [&"us", &"ecc", &"eu", &"tpla"]:
		var fd: Dictionary = Content.faction(fac)
		for uid in fd["units"]:
			if UnitIcons.of(StringName(uid)) == null:
				missing.append(uid)
		for bid in fd["buildings"]:
			if UnitIcons.of(StringName(bid)) == null:
				missing.append(bid)
		for bid in Content.buildings:   # anything a faction building trains
			if String(bid).begins_with(String(fac) + "_"):
				for p in Content.building(bid).produces:
					if UnitIcons.of(StringName(p)) == null and not missing.has(p):
						missing.append(p)
	t._check(missing.is_empty(), "every unit and structure of the 4 factions has an icon (%s)" % (str(missing.slice(0, 8)) if not missing.is_empty() else "all"))
	var ic := UnitIcons.of(&"us_dozer")
	t._check(ic != null and ic.get_width() == 128 and ic.get_height() == 128 and UnitIcons.of(&"no_such_unit") == null,
		"icons are 128 px squares and an unknown id has none (text stays)")

# ------------------------------------------------------------------ 38: German engineers
static func _german_voices(t: Node) -> void:
	var ad: Node = t.get_node("/root/AudioDirector")
	var bad: Array = []
	var evs := {"crawler": ["created", "select", "move", "build"], "field_engineer": ["created", "select", "move", "attack", "build"],
		"sturmtrupp": ["created", "select", "move", "attack"]}
	for folder in evs:
		for ev in evs[folder]:
			var v: Array = ad.variants("eu", folder, ev)
			if v[1] != 1 or (v[0] as Array).is_empty():
				bad.append("%s/%s source %d" % [folder, ev, v[1]])
	t._check(bad.is_empty(), "German engineer / Sturmtrupp 'reporting' lines are the natural voice, not the robotic placeholder (%s)" % (str(bad) if not bad.is_empty() else "ok"))

# ------------------------------------------------------------------ 44: Russian theme
static func _russian_music(t: Node) -> void:
	var ad: Node = t.get_node("/root/AudioDirector")
	var pl: Array = ad.FACTION_PLAYLISTS[&"ecc"]
	var s: Variant = load(pl[0])
	t._check(pl[0].ends_with("battle_ru_steppe_march.ogg") and s is AudioStreamOggVorbis and (s as AudioStream).get_length() > 90.0,
		"Russia's battle music opens with the traditional theme Steppe March (%.0f s)" % ((s as AudioStream).get_length() if s is AudioStream else 0.0))

# ------------------------------------------------------------------ fix: floating stacks
## Malachi: the Gas Turbine Plant's exhaust stacks floated above the boilers. The float check
## (tools/gfx_m33/float_check.gd) finds no unsupported part on these models any more.
static func _no_floating(t: Node) -> void:
	var FC: GDScript = load("res://tools/gfx_m33/float_check.gd")
	var bad: Array = []
	for p in ["res://view/buildings/tpla/gas_plant.tscn", "res://view/buildings/us/reactor.tscn", "res://view/buildings/ecc/bunker.tscn"]:
		var v: Node = load(p).instantiate()
		for b in FC.check(v):
			bad.append(p.get_file() + ": " + b)
		v.free()
	t._check(bad.is_empty(), "gas plant stacks sit on the boilers; reactor and silo parts are grounded (%s)" % (str(bad.slice(0, 3)) if not bad.is_empty() else "no floating parts"))
	# combined-cycle stacks stand on the ground (they started 1.25 up)
	var cc: Node = load("res://view/buildings/tpla/cc_plant.tscn").instantiate()
	var low := 99.0
	for mi in cc.find_children("Hull", "MeshInstance3D", true, false):
		var a: PackedVector3Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for q in a:
			if Vector2(q.x - 0.15, q.z + 1.2).length() < 0.16 and q.y < low:
				low = q.y
	cc.free()
	t._check(low < 0.12, "combined-cycle exhaust stacks rise from the ground (lowest point %.2f)" % low)
