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

const UNIT_ORDER := [&"eu_crawler", &"eu_harvester", &"eu_grenadier", &"eu_lancer", &"eu_wolfhound", &"eu_flakwerk", &"eu_leopold", &"eu_aegis"]
const BUILDING_ORDER := [&"eu_hq", &"eu_reactor", &"eu_pylon", &"eu_hub", &"eu_barracks", &"eu_motor_pool", &"eu_heavy_factory", &"eu_gun_bunker"]

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
	_load_dir("res://data/buildings/eu", buildings)
	_load_dir("res://data/buildings/neutral", buildings)
	_load_dir("res://data/weapons", weapons)
	_load_dir("res://data/powers", powers)
	_load_dir("res://data/ai", ai_personalities)
	_load_dir("res://data/maps", maps)
	combat = load("res://data/combat_table.tres")
	power_order = [&"eu_recon_sweep", &"eu_emergency_logistics", &"eu_shield_overcharge", &"eu_blackout"]
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
	for id in UNIT_ORDER:
		if not units.has(id): errors.append("Missing unit " + id)
	for id in BUILDING_ORDER:
		if not buildings.has(id): errors.append("Missing building " + id)

func unit(id) -> UnitDef:
	return units.get(StringName(id))

func building(id) -> BuildingDef:
	return buildings.get(StringName(id))

func weapon(id) -> WeaponDef:
	return weapons.get(StringName(id))

func is_building(id) -> bool:
	return buildings.has(StringName(id))

func producer_of(unit_id) -> StringName:
	for bid in BUILDING_ORDER:
		var b: BuildingDef = buildings[bid]
		if b.produces.has(String(unit_id)):
			return bid
	return &""
