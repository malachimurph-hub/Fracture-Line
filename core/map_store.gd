class_name MapStore
## M2.8 custom maps (map builder). One JSON file per map in user://maps/<id>.json:
##   {format, id, name, size:[w,h], env, tiles:[row strings, SimMap chars], spawns:[[x,y]],
##    resources:[{kind, tile:[x,y], amount}], neutrals:[{kind, tile}], prebuilt:[{kind, spawn, tile}]}
## Content registers them in Content.maps beside the built-in maps (MapDef.custom = true), so
## the lobby, MatchRunner, AI and view use them unchanged. Suspend saves embed the map
## (SimWorld.serialize "map_data") so a match on a custom map resumes even after the map was
## edited or deleted (resolve()).

const DIR := "user://maps"
const FORMAT := 1
const PREFIX := "custom_"
const SIZES := [Vector2i(64, 64), Vector2i(128, 128), Vector2i(192, 192), Vector2i(256, 256)]
const DEFAULT_SIZE := 3        ## 256x256 (Malachi: large maps, double the M2.7 128x128)
const HQ_FP := Vector2i(4, 4)
const SUPPLY_NEAR := 32          ## tiles from an HQ centre to its nearest supply
const T_TO_CHAR := [".", ":", ",", "~", "=", "#", "^", "T"]

static func _v(a) -> Vector2i:
	if a is Vector2i:
		return a
	return Vector2i(int(a[0]), int(a[1]))

static func _a(v: Vector2i) -> Array:
	return [v.x, v.y]

## MapDef -> JSON-ready dictionary (tiles from tiles_text or the tiles file).
static func to_dict(md: MapDef) -> Dictionary:
	var rows := PackedStringArray()
	var text := md.tiles_text if md.tiles_text != "" else FileAccess.get_file_as_string(md.tiles_path)
	for ln in text.split("\n", false):
		if ln.length() >= md.size.x:
			rows.append(ln.substr(0, md.size.x))
	var sp: Array = []
	for s in md.spawns:
		sp.append(_a(s))
	var rs: Array = []
	for r in md.resources:
		rs.append({"kind": String(r["kind"]), "tile": _a(r["tile"]), "amount": int(r["amount"])})
	var ns: Array = []
	for n in md.neutrals:
		ns.append({"kind": String(n["kind"]), "tile": _a(n["tile"])})
	var pb: Array = []
	for p in md.prebuilt:
		pb.append({"kind": String(p["kind"]), "spawn": int(p["spawn"]), "tile": _a(p["tile"])})
	return {"format": FORMAT, "id": String(md.id), "name": tr_name(md), "size": _a(md.size), "env": String(md.env),
		"tiles": Array(rows), "spawns": sp, "resources": rs, "neutrals": ns, "prebuilt": pb, "decor": md.decor.duplicate(true),
		"hills": md.hills.duplicate(true), "night": md.night}

static func tr_name(md: MapDef) -> String:
	return TranslationServer.translate(md.name_key) if md.name_key != "" else String(md.id)

static func from_dict(d: Dictionary) -> MapDef:
	var md := MapDef.new()
	md.id = StringName(d.get("id", "custom_map"))
	md.name_key = String(d.get("name", md.id))
	md.description_key = ""
	md.size = _v(d.get("size", [64, 64]))
	md.env = StringName(d.get("env", "desert"))
	if not MapEnv.ENVS.has(md.env):
		md.env = &"desert"
	var rows: Array = d.get("tiles", [])
	md.tiles_text = "\n".join(PackedStringArray(rows))
	var sp: Array[Vector2i] = []
	for s in d.get("spawns", []):
		sp.append(_v(s))
	md.spawns = sp
	var rs: Array[Dictionary] = []
	for r in d.get("resources", []):
		rs.append({"kind": String(r["kind"]), "tile": _v(r["tile"]), "amount": int(r.get("amount", 10000))})
	md.resources = rs
	var ns: Array[Dictionary] = []
	for n in d.get("neutrals", []):
		ns.append({"kind": String(n["kind"]), "tile": _v(n["tile"])})
	md.neutrals = ns
	var pb: Array[Dictionary] = []
	for p in d.get("prebuilt", []):
		pb.append({"kind": String(p["kind"]), "spawn": int(p.get("spawn", 0)), "tile": _v(p["tile"])})
	md.prebuilt = pb
	var dc: Array = []
	for e in d.get("decor", []):
		if e is Array and e.size() >= 4:
			dc.append([String(e[0]), float(e[1]), float(e[2]), int(e[3])])
	md.decor = dc
	var hl: Array = []
	for e2 in d.get("hills", []):
		if e2 is Array and e2.size() >= 4:
			hl.append([int(e2[0]), int(e2[1]), int(e2[2]), int(e2[3])])
	md.hills = hl
	md.night = bool(d.get("night", false))
	md.custom = true
	md.content_hash = hash_of(d)
	return md

## Hash of everything the deterministic sim reads (not the name / id / env).
static func hash_of(d: Dictionary) -> String:
	var core := [d.get("size"), d.get("tiles"), d.get("spawns"), d.get("resources"), d.get("neutrals"), d.get("prebuilt", [])]
	if not d.get("hills", []).is_empty():   # M3.3 P3: only maps with hills hash them (old hashes unchanged)
		core.append(d["hills"])
	return JSON.stringify(core).md5_text()

static func path_of(id) -> String:
	return "%s/%s.json" % [DIR, String(id)]

static func slug(name: String) -> String:
	var out := ""
	for c in name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif out != "" and not out.ends_with("_"):
			out += "_"
	out = out.trim_suffix("_")
	return PREFIX + (out if out != "" else "map")

## A free id for a new map called `name` (custom_<slug>, then _2, _3...).
static func new_id(name: String, taken: Dictionary) -> String:
	var base := slug(name)
	var id := base
	var n := 2
	while taken.has(StringName(id)) or FileAccess.file_exists(path_of(id)):
		id = "%s_%d" % [base, n]
		n += 1
	return id

static func save_dict(d: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path_of(d["id"]), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if d.get("draft", false):
		Content.maps.erase(StringName(d["id"]))   # drafts (failed the check) stay out of Skirmish
	else:
		register(Content.maps, d)
	return OK

static func load_dict(id) -> Dictionary:
	var p := path_of(id)
	if not FileAccess.file_exists(p):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Dictionary and int(v.get("format", 0)) == FORMAT else {}

static func delete(id) -> void:
	if FileAccess.file_exists(path_of(id)):
		DirAccess.remove_absolute(path_of(id))
	var md: MapDef = Content.maps.get(StringName(id))
	if md != null and md.custom:
		Content.maps.erase(StringName(id))

static func list_ids() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort()
	return out

static func register(into: Dictionary, d: Dictionary) -> MapDef:
	var md := from_dict(d)
	into[md.id] = md
	return md

## Called by Content.load_all(): (re)loads every user map.
static func register_all(into: Dictionary) -> void:
	for k in into.keys():
		if (into[k] as MapDef).custom and not (into[k] as MapDef).transient:
			into.erase(k)
	for id in list_ids():
		var d := load_dict(id)
		if not d.is_empty() and not d.get("draft", false) and not into.has(StringName(d["id"])):
			register(into, d)

## Save/resume: the map for a saved match. Uses the registered map when its content still
## matches, otherwise registers the embedded copy under a hidden id.
static func resolve(map_id: StringName, map_data: Dictionary) -> MapDef:
	var md: MapDef = Content.maps.get(map_id)
	if map_data.is_empty():
		return md
	var h := hash_of(map_data)
	if md != null and md.content_hash == h:
		return md
	var tid := StringName("%s~%s" % [String(map_data["id"]).get_slice("~", 0), h.substr(0, 8)])
	if Content.maps.has(tid):
		return Content.maps[tid]
	var d := map_data.duplicate(true)
	d["id"] = String(tid)
	var nm := register(Content.maps, d)
	nm.transient = true
	return nm

static func blank(name: String, size: Vector2i, env: StringName) -> Dictionary:
	var rows: Array = []
	for y in size.y:
		var row := ""
		for x in size.x:
			row += "^" if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1 else "."
		rows.append(row)
	return {"format": FORMAT, "id": "", "name": name, "size": _a(size), "env": String(env), "tiles": rows,
		"spawns": [], "resources": [], "neutrals": [], "prebuilt": []}

# ------------------------------------------------------------------ validation
static func footprint_of(kind: String) -> Vector2i:
	var b: BuildingDef = Content.building(kind)
	return b.footprint if b != null else Vector2i.ONE

## Returns a list of human-readable problems; empty means the map is playable.
static func validate(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var md := from_dict(d)
	var m := SimMap.new()
	m.load_from(md)
	if md.spawns.size() < 2:
		errs.append("Place at least 2 start positions (have %d)." % md.spawns.size())
	if md.spawns.size() > SkirmishConfig.SLOTS:   # M3.3 P3 (21): up to 8 players
		errs.append("At most %d start positions." % SkirmishConfig.SLOTS)
	var occ := {}   # tile -> label
	var claim := func(t0: Vector2i, fp: Vector2i, label: String) -> void:
		var bad_t := false
		var clash := ""
		for yy in fp.y:
			for xx in fp.x:
				var t := t0 + Vector2i(xx, yy)
				if t.x < 1 or t.y < 1 or t.x >= m.w - 1 or t.y >= m.h - 1 or not SimMap.BUILD_OK[m.ttype(t)]:
					bad_t = true
				if occ.has(t) and clash == "":
					clash = occ[t]
				occ[t] = label
		if bad_t:
			errs.append("%s at %d,%d sits on blocked ground (water, cliff, forest, ford, bridge or map edge)." % [label, t0.x, t0.y])
		if clash != "":
			errs.append("%s at %d,%d overlaps %s." % [label, t0.x, t0.y, clash])
	for i in md.spawns.size():
		claim.call(md.spawns[i], HQ_FP, "Start %d" % (i + 1))
	for n in md.neutrals:
		claim.call(n["tile"], footprint_of(n["kind"]), _name(n["kind"]))
	for p in md.prebuilt:
		if Content.is_building(p["kind"]):
			claim.call(p["tile"], footprint_of(p["kind"]), _name(p["kind"]))
			if int(p["spawn"]) < 0 or int(p["spawn"]) >= md.spawns.size():
				errs.append("%s at %d,%d belongs to a start position that is not placed." % [_name(p["kind"]), p["tile"].x, p["tile"].y])
		else:
			var u: UnitDef = Content.unit(p["kind"])
			var t: Vector2i = p["tile"]
			if u == null:
				errs.append("Unknown unit %s." % p["kind"])
			elif u.move_layer != &"air" and not m.terrain_passable(t, u.move_layer == &"vehicle"):
				errs.append("%s at %d,%d is on ground it cannot stand on." % [_name(p["kind"]), t.x, t.y])
			if int(p["spawn"]) < 0 or int(p["spawn"]) >= md.spawns.size():
				errs.append("%s at %d,%d belongs to a start position that is not placed." % [_name(p["kind"]), t.x, t.y])
	for r in md.resources:
		var t: Vector2i = r["tile"]
		if not m.terrain_passable(t, true) or occ.has(t):
			errs.append("Supply %s at %d,%d is on blocked ground or under a building." % [r["kind"], t.x, t.y])
		if int(r["amount"]) <= 0:
			errs.append("Supply at %d,%d is empty." % [t.x, t.y])
	# every start must reach every other start by ground (vehicle layer)
	var regs: Array = []
	for s in md.spawns:
		regs.append(m.footprint_regions(s, HQ_FP, false))
	for i in md.spawns.size():
		for j in range(i + 1, md.spawns.size()):
			var shared := false
			for k in regs[i]:
				if regs[j].has(k):
					shared = true
			if not shared:
				errs.append("Start %d cannot reach Start %d by ground." % [i + 1, j + 1])
	# every start needs a reachable supply nearby
	for i in md.spawns.size():
		var c: Vector2i = md.spawns[i] + HQ_FP / 2
		var ok := false
		for r in md.resources:
			var t: Vector2i = r["tile"]
			if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= SUPPLY_NEAR and regs[i].has(m.region_near(t, false)):
				ok = true
		if not ok:
			errs.append("Start %d has no reachable supply within %d tiles." % [i + 1, SUPPLY_NEAR])
	return errs

static func _name(kind) -> String:
	var b: BuildingDef = Content.building(kind)
	if b != null:
		return TranslationServer.translate(b.name_key)
	var u: UnitDef = Content.unit(kind)
	if u != null:
		return TranslationServer.translate(u.name_key)
	return String(kind)
