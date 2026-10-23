extends Node
## Loads and indexes every definition in data/, validates references at boot,
## and fails loudly on errors (GDD 16.2).

var units: Dictionary = {}       ## StringName -> UnitDef
var buildings: Dictionary = {}   ## StringName -> BuildingDef
var weapons: Dictionary = {}     ## StringName -> WeaponDef
var powers: Dictionary = {}      ## StringName -> PowerDef
var ai_personalities: Dictionary = {}
var maps: Dictionary = {}
var combat: CombatTable
var errors: PackedStringArray = []
var power_order: Array[StringName] = []

const UNIT_ORDER := [&"eu_crawler", &"eu_harvester", &"eu_grenadier", &"eu_lancer", &"eu_wolfhound", &"eu_flakwerk", &"eu_leopold", &"eu_aegis", &"eu_salamander", &"eu_hearth", &"eu_spectre", &"eu_sentinel", &"eu_brennus", &"eu_thunderhead", &"eu_kestrel", &"eu_corvid"]
const BUILDING_ORDER := [&"eu_hq", &"eu_reactor", &"eu_pylon", &"eu_hub", &"eu_barracks", &"eu_motor_pool", &"eu_heavy_factory", &"eu_gun_bunker", &"eu_flak_tower", &"eu_minefield", &"eu_signals", &"eu_relay", &"eu_exchange", &"eu_airstrip", &"eu_concord"]
const TPLA_UNIT_ORDER := [&"tpla_laborer", &"tpla_militia", &"tpla_rocket_cell", &"tpla_rattler", &"tpla_scrapback", &"tpla_hailstorm", &"tpla_shrike", &"tpla_mule", &"tpla_blight", &"tpla_junkhammer", &"tpla_sprayer", &"tpla_earwig", &"tpla_jackal", &"tpla_bus"]
const US_UNIT_ORDER := [&"us_dozer", &"us_supply_truck", &"us_grunt", &"us_javelin", &"us_jtac", &"us_sniper", &"us_lynx", &"us_halberd", &"us_picket", &"us_longreach", &"us_harrier", &"us_wraith", &"us_thunderlance"]
const US_BUILDING_ORDER := [&"us_command", &"us_reactor", &"us_supply_center", &"us_barracks", &"us_garage", &"us_airfield", &"us_strategy", &"us_patriot", &"us_firebase", &"us_drop_zone"]
const TPLA_BUILDING_ORDER := [&"tpla_den", &"tpla_stash", &"tpla_camp", &"tpla_chop_shop", &"tpla_tunnel", &"tpla_workshop", &"tpla_bazaar", &"tpla_demo_trap", &"tpla_camo_net", &"tpla_wasp_nest", &"tpla_decoy", &"tpla_rust_silo"]

## Playable factions (skirmish). "power": whether the faction uses the power economy.
const FACTIONS := {
	&"eu": {"name_key": "FACTION_EU", "hq": &"eu_hq", "builder": &"eu_crawler", "start_units": [&"eu_crawler"],
		"units": UNIT_ORDER, "buildings": BUILDING_ORDER, "power": true, "personality": &"eu_ironclad",
		"powers": [&"eu_recon_sweep", &"eu_emergency_logistics", &"eu_shield_overcharge", &"eu_blackout"]},
	&"tpla": {"name_key": "FACTION_TPLA", "hq": &"tpla_den", "builder": &"tpla_laborer", "start_units": [&"tpla_laborer", &"tpla_laborer"],
		"units": TPLA_UNIT_ORDER, "buildings": TPLA_BUILDING_ORDER, "power": false, "personality": &"tpla_scrapjack",
		"powers": [&"tpla_ambush", &"tpla_scrap_rain", &"tpla_blight_shells", &"tpla_uprising"]},
	# M2.5: United States (Malachi's roster; unspecified slots are ZH USA equivalents, placeholders)
	&"us": {"name_key": "FACTION_US", "hq": &"us_command", "builder": &"us_dozer", "start_units": [&"us_dozer"],
		"units": US_UNIT_ORDER, "buildings": US_BUILDING_ORDER, "power": true, "personality": &"us_vanguard",
		"powers": [&"us_uav_recon", &"us_paradrop", &"us_precision_strike", &"us_field_repair"]},
}

func faction(f) -> Dictionary:
	return FACTIONS.get(StringName(f), FACTIONS[&"eu"])

func building_order(f) -> Array:
	return faction(f)["buildings"]

func powers_for(f) -> Array:
	return faction(f)["powers"]

## Faction of a data id by prefix (eu_*, tpla_*); "neutral" otherwise.
static func faction_of_id(id) -> StringName:
	var s := String(id)
	if s.begins_with("tpla_"):
		return &"tpla"
	if s.begins_with("eu_"):
		return &"eu"
	if s.begins_with("us_"):
		return &"us"
	return &"neutral"

func btag(id, tag: String) -> bool:
	var b: BuildingDef = buildings.get(StringName(id))
	return b != null and b.tags.has(tag)

func _ready() -> void:
	load_all()

func _load_dir(path: String, into: Dictionary) -> void:
	var files := ResourceLoader.list_directory(path)
	files.sort()
	for f in files:
		var fname := String(f).trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var r = load(path + "/" + fname)
		if r == null:
			errors.append("Failed to load " + path + "/" + fname)
			continue
		into[StringName(r.id)] = r

func load_all() -> void:
	units.clear(); buildings.clear(); weapons.clear(); powers.clear(); errors.clear()
	_load_dir("res://data/units/eu", units)
	_load_dir("res://data/units/tpla", units)
	_load_dir("res://data/units/us", units)
	_load_dir("res://data/buildings/eu", buildings)
	_load_dir("res://data/buildings/tpla", buildings)
	_load_dir("res://data/buildings/us", buildings)
	_load_dir("res://data/buildings/neutral", buildings)
	_load_dir("res://data/weapons", weapons)
	_load_dir("res://data/powers", powers)
	_load_dir("res://data/ai", ai_personalities)
	_load_dir("res://data/maps", maps)
	MapStore.register_all(maps)   # M2.8: map-builder maps from user://maps
	combat = load("res://data/combat_table.tres")
	power_order = []
	for f in FACTIONS:
		for pw in FACTIONS[f]["powers"]:
			power_order.append(pw)
	_validate()
	if not errors.is_empty():
		for e in errors:
			push_error("CONTENT: " + e)

func _validate() -> void:
	for id in units:
		var u: UnitDef = units[id]
		for w in u.weapons:
			if not weapons.has(StringName(w)):
				errors.append("Unit %s references missing weapon %s" % [id, w])
		if u.view_scene != "" and not ResourceLoader.exists(u.view_scene):
			errors.append("Unit %s view scene missing: %s" % [id, u.view_scene])
	for id in buildings:
		var b: BuildingDef = buildings[id]
		for p in b.produces:
			if not units.has(StringName(p)):
				errors.append("Building %s produces missing unit %s" % [id, p])
		for p in b.prereqs:
			if not buildings.has(StringName(p)):
				errors.append("Building %s prereq missing %s" % [id, p])
		if b.view_scene != "" and not ResourceLoader.exists(b.view_scene):
			errors.append("Building %s view scene missing: %s" % [id, b.view_scene])
	for id in weapons:
		var w: WeaponDef = weapons[id]
		if combat == null or not combat.table.has(String(w.damage_type)):
			errors.append("Weapon %s damage type not in combat table: %s" % [id, w.damage_type])
	# Guards against data silently lost in export (e.g. PackedStringArray fields coming back
	# empty after binary conversion - see KNOWN_ISSUES): every unit has tags, HQ produces.
	for id in units:
		if (units[id] as UnitDef).tags.is_empty():
			errors.append("Unit %s has no tags (data lost?)" % id)
	if buildings.has(&"eu_hq") and (buildings[&"eu_hq"] as BuildingDef).produces.is_empty():
		errors.append("HQ produces nothing (data lost?)")
	for id in ai_personalities:
		if (ai_personalities[id] as AIPersonalityDef).opening.is_empty():
			errors.append("AI personality %s has no opening (data lost?)" % id)
	for f in FACTIONS:
		for id in FACTIONS[f]["units"]:
			if not units.has(id): errors.append("Missing unit " + id)
		for id in FACTIONS[f]["buildings"]:
			if not buildings.has(id): errors.append("Missing building " + id)
		for id in FACTIONS[f]["powers"]:
			if not powers.has(id): errors.append("Missing power " + id)
		if not ai_personalities.has(FACTIONS[f]["personality"]):
			errors.append("Missing AI personality " + FACTIONS[f]["personality"])
	if buildings.has(&"tpla_tunnel") and not (buildings[&"tpla_tunnel"] as BuildingDef).tags.has("tunnel"):
		errors.append("Tunnel has no tunnel tag (data lost?)")
	for id in weapons:
		var wd: WeaponDef = weapons[id]
		if wd.min_tier < 0 or wd.min_tier > 3:
			errors.append("Weapon %s bad min_tier" % id)

func unit(id) -> UnitDef:
	return units.get(StringName(id))

func building(id) -> BuildingDef:
	return buildings.get(StringName(id))

func weapon(id) -> WeaponDef:
	return weapons.get(StringName(id))

func is_building(id) -> bool:
	return buildings.has(StringName(id))

func producer_of(unit_id) -> StringName:
	for bid in BUILDING_ORDER + TPLA_BUILDING_ORDER + US_BUILDING_ORDER:
		var b: BuildingDef = buildings[bid]
		if b.produces.has(String(unit_id)):
			return bid
	return &""
