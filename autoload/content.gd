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

const UNIT_ORDER := [&"eu_crawler", &"eu_harvester", &"eu_squad", &"eu_wolfhound", &"eu_boxer", &"eu_flakwerk", &"eu_leopold", &"eu_salamander", &"eu_hearth", &"eu_thunderhead", &"eu_kestrel", &"eu_h145m", &"eu_corvid", &"eu_field_engineer", &"eu_sturmtrupp"]
const BUILDING_ORDER := [&"eu_hq", &"eu_reactor", &"eu_hub", &"eu_barracks", &"eu_motor_pool", &"eu_gun_bunker", &"eu_guard_tower", &"eu_javelin_pit", &"eu_flak_tower", &"eu_mantis", &"eu_minefield", &"eu_signals", &"eu_relay", &"eu_exchange", &"eu_airstrip", &"eu_sandbags", &"eu_barricade"]
## M2.9: Malachi's TPLA roster (notes 2026-10-22). Internal ids kept where a unit took over a slot:
## militia = Rifleman, rocket_cell = Rocket Man, rattler = Technical, scrapback = Striker (Karrar MBT),
## bus = BMP-2 transport, hailstorm = BHX-35 (35 mm AA), blight = Koksan, shrike = Fajr-5.
## M3.2.2: units taken out of the game (Malachi: "Remove Germany shield truck"). Their defs,
## models, voices and names stay so old saves and replays still load and play back the same:
## the sim still accepts a queue order for them at their old producer (replays), nothing in the
## UI, AI or Map Builder offers them, and units already on the field keep working.
## M3.3: Germany's heavy tank (eu_brennus) retired the same way (Malachi: "Remove heavy tank").
## M3.5: single line infantry (rifleman / machine gunner / anti-tank) gave way to Combat Squads,
## and Germany's non-lethal Fuchs jammer and Fennek recon left the motor pool, the same way.
const RETIRED_UNITS := {&"eu_aegis": &"eu_heavy_factory", &"eu_brennus": &"eu_heavy_factory",
	&"us_grunt": &"us_barracks", &"us_javelin": &"us_barracks", &"eu_grenadier": &"eu_barracks", &"eu_lancer": &"eu_barracks",
	&"tpla_militia": &"tpla_camp", &"tpla_rocket_cell": &"tpla_camp", &"ecc_rifleman": &"ecc_barracks",
	&"ecc_machine_gunner": &"ecc_barracks", &"ecc_rpg": &"ecc_barracks", &"eu_spectre": &"eu_motor_pool", &"eu_sentinel": &"eu_motor_pool"}
## M3.5: Germany's Heavy Factory merged into the Motor Pool (def kept, not buildable: old saves).
## M3.7: Iran has one power plant (the Gas Processing Plant); the Gas Turbine Plant is retired the same way.
const RETIRED_BUILDINGS := [&"eu_heavy_factory", &"tpla_gas_plant"]

## M3.5 Combat Squads (Malachi: "3 Rifleman 1 Machine Gunner 1 anti Tank troop 1 grenadier").
## One selectable unit of six soldiers with one pooled HP bar. Members are listed leader first:
## as the pool drains they fall from the END of the list (the last one listed dies first), and
## a fallen soldier's weapons stop firing (CombatSys scales each weapon by its live carriers).
## Each member: [infantry model (assets/models/infantry/<model>.res), [weapon ids]].
## GRENADIERS are PLACEHOLDERS (no faction grenadier existed): a rifle with an under-barrel
## grenade launcher. Change the model / weapons here (and the weapon stats in weapons.csv).
const GRENADIERS := {
	&"us": ["us_grenadier", [&"us_m16", &"us_m203"]],        # Marine rifleman + M203 (placeholder)
	&"eu": ["eu_rifleman", [&"eu_rifle", &"eu_ag36"]],   # Infanterie model (rifle + launcher) + AG36 (placeholder)
	&"tpla": ["tpla_grenadier", [&"tpla_carbine", &"tpla_gp25"]],   # rifleman + GP-25 (placeholder)
	&"ecc": ["ecc_grenadier", [&"ecc_ak74", &"ecc_gp25"]],   # AK-74M + GP-25 (placeholder)
}
const SQUAD_MEMBERS := {
	&"us_squad": [["us_rifleman", [&"us_m16"]], ["us_machine_gunner", [&"us_m240b"]], ["us_javelin", [&"us_javelin"]],
		["us_rifleman", [&"us_m16"]], &"us", ["us_rifleman", [&"us_m16"]]],
	&"eu_squad": [["eu_rifleman", [&"eu_rifle"]], ["eu_machine_gunner", [&"eu_mg3"]], ["eu_lancer", [&"eu_lancer_missile"]],
		["eu_rifleman", [&"eu_rifle"]], &"eu", ["eu_rifleman", [&"eu_rifle"]]],
	&"tpla_squad": [["tpla_rifleman", [&"tpla_carbine"]], ["tpla_machine_gunner", [&"tpla_pkm"]], ["tpla_rocket", [&"tpla_rpg"]],
		["tpla_rifleman", [&"tpla_carbine"]], &"tpla", ["tpla_rifleman", [&"tpla_carbine"]]],
	&"ecc_squad": [["ecc_rifleman", [&"ecc_ak74"]], ["ecc_machine_gunner", [&"ecc_pkm"]], ["ecc_rpg", [&"ecc_rpg7"]],
		["ecc_rifleman", [&"ecc_ak74"]], &"ecc", ["ecc_rifleman", [&"ecc_ak74"]]],
}
## M3.5 Drone Operators: which drone each operator launches (US: scout only; Russia: explosive only).
const OPERATOR_DRONES := {&"us_drone_operator": {"scout": &"us_scout_drone"}, &"ecc_drone_operator": {"bomb": &"ecc_bomb_drone"}}
const TPLA_UNIT_ORDER := [&"tpla_backhoe", &"tpla_pickup", &"tpla_squad", &"tpla_marksman", &"tpla_insurgent", &"tpla_rattler", &"tpla_scrapback", &"tpla_bus", &"tpla_hailstorm", &"tpla_blight", &"tpla_shrike", &"tpla_mirage", &"tpla_mig29", &"tpla_f16"]
const US_UNIT_ORDER := [&"us_dozer", &"us_supply_truck", &"us_squad", &"us_jtac", &"us_sniper", &"us_lynx", &"us_bradley", &"us_halberd", &"us_picket", &"us_longreach", &"us_harrier", &"us_blackhawk", &"us_wraith", &"us_thunderlance", &"us_drone_operator", &"us_breacher"]
const US_BUILDING_ORDER := [&"us_command", &"us_reactor", &"us_supply_center", &"us_barracks", &"us_garage", &"us_airfield", &"us_strategy", &"us_patriot", &"us_firebase", &"us_drop_zone", &"us_sandbags", &"us_barricade"]
## M3.0 F: Russia (Malachi's list 2026-10-23: T-90M, Tiger-M, BTR, Typhoon, 2S Msta, Zeus and four
## single soldiers). Engineer, Cargo Truck and every building are stand-ins until his list covers them.
const ECC_UNIT_ORDER := [&"ecc_engineer", &"ecc_cargo_truck", &"ecc_squad", &"ecc_infiltrator", &"ecc_saboteur", &"ecc_drone_operator", &"ecc_tigr", &"ecc_btr", &"ecc_typhoon", &"ecc_t90", &"ecc_zeus", &"ecc_msta", &"ecc_ka52", &"ecc_hind", &"ecc_su57", &"ecc_tu160"]
const ECC_BUILDING_ORDER := [&"ecc_hq", &"ecc_power", &"ecc_depot", &"ecc_barracks", &"ecc_factory", &"ecc_airfield", &"ecc_ministry", &"ecc_black_market", &"ecc_bunker", &"ecc_aa_site", &"ecc_sandbags", &"ecc_barricade"]
const TPLA_BUILDING_ORDER := [&"tpla_den", &"tpla_cc_plant", &"tpla_stash", &"tpla_camp", &"tpla_chop_shop", &"tpla_tunnel", &"tpla_workshop", &"tpla_bazaar", &"tpla_demo_trap", &"tpla_camo_net", &"tpla_wasp_nest", &"tpla_sayad3", &"tpla_airfield", &"tpla_sandbags", &"tpla_barricade"]

## Playable factions (skirmish). "power": whether the faction uses the power economy.
const FACTIONS := {
	&"eu": {"name_key": "FACTION_EU", "hq": &"eu_hq", "builder": &"eu_crawler", "start_units": [&"eu_crawler"],
		"units": UNIT_ORDER, "buildings": BUILDING_ORDER, "power": true, "personality": &"eu_ironclad",
		"powers": [&"eu_recon_sweep", &"eu_emergency_logistics", &"eu_shield_overcharge", &"eu_blackout"]},
	# M2.8: "home_stash_pct" scales the supply stashes by this faction's spawn so they last ~17 min
	# against its AI opening economy. M2.9: TPLA builds with a Backhoe and gathers with Pickups (separate jobs)
	&"tpla": {"name_key": "FACTION_TPLA", "home_stash_pct": 120, "hq": &"tpla_den", "builder": &"tpla_backhoe", "start_units": [&"tpla_backhoe", &"tpla_pickup"],
		"units": TPLA_UNIT_ORDER, "buildings": TPLA_BUILDING_ORDER, "power": true,   # M3.3: Gas Turbine Plants
		 "personality": &"tpla_scrapjack",
		"powers": [&"tpla_ambush", &"tpla_scrap_rain", &"tpla_blight_shells", &"tpla_uprising"]},
	# M2.5: United States (Malachi's roster; unspecified slots are ZH USA equivalents, placeholders)
	&"us": {"name_key": "FACTION_US", "hq": &"us_command", "builder": &"us_dozer", "start_units": [&"us_dozer"],
		"units": US_UNIT_ORDER, "buildings": US_BUILDING_ORDER, "power": true, "personality": &"us_vanguard",
		"powers": [&"us_uav_recon", &"us_paradrop", &"us_precision_strike", &"us_field_repair"]},
	# M3.0 F: Russia (power economy like the US; separate builder and gatherer)
	&"ecc": {"name_key": "FACTION_ECC", "hq": &"ecc_hq", "builder": &"ecc_engineer", "start_units": [&"ecc_engineer"],
		"units": ECC_UNIT_ORDER, "buildings": ECC_BUILDING_ORDER, "power": true, "personality": &"ecc_steppe",
		"powers": [&"ecc_recon", &"ecc_logistics", &"ecc_strike", &"ecc_repair"]},
		# M3.2: Russia unlocked (Malachi). The lock stays for future factions: add "enabled": false.
}

## M3.3 (Malachi: "Remove general points and abilities for all teams until we can make them
## better"): the General button, tray, rank alerts and AI powers are off. The code, the power defs
## and the sim commands stay (old saves and replays that bought powers still play back), and rank
## and XP still count in the background. Set true to bring it all back.
const GENERALS_ENABLED := false

## M3.0: false for a faction that is shown as "Coming soon" (locked, never picked by players, AI or random).
func faction_enabled(f) -> bool:
	var k := StringName(f)
	return FACTIONS.has(k) and bool(FACTIONS[k].get("enabled", true))

func playable_factions() -> Array:
	return FACTIONS.keys().filter(func(k): return faction_enabled(k))

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
	if s.begins_with("ecc_"):
		return &"ecc"
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
	_load_dir("res://data/units/ecc", units)
	_load_dir("res://data/buildings/eu", buildings)
	_load_dir("res://data/buildings/tpla", buildings)
	_load_dir("res://data/buildings/us", buildings)
	_load_dir("res://data/buildings/ecc", buildings)
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
	for sid in SQUAD_MEMBERS:
		var sd: UnitDef = units.get(sid)
		if sd == null:
			errors.append("Squad %s has no unit def" % sid)
			continue
		for m in squad_members(sid):
			if not ResourceLoader.exists("res://assets/models/infantry/%s.res" % m[0]):
				errors.append("Squad %s member model missing: %s" % [sid, m[0]])
			for wid in m[1]:
				if not sd.weapons.has(String(wid)):
					errors.append("Squad %s member weapon %s not in the unit's weapons" % [sid, wid])
	for op in OPERATOR_DRONES:
		for k in OPERATOR_DRONES[op]:
			if not units.has(OPERATOR_DRONES[op][k]):
				errors.append("Drone operator %s: missing drone %s" % [op, OPERATOR_DRONES[op][k]])
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
	for bid in BUILDING_ORDER + TPLA_BUILDING_ORDER + US_BUILDING_ORDER + ECC_BUILDING_ORDER:
		var b: BuildingDef = buildings[bid]
		if b.produces.has(String(unit_id)):
			return bid
	return &""

## M3.5 squads: members as [model, [weapon ids]] (grenadier placeholders resolved), [] if not a squad.
func squad_members(unit_id) -> Array:
	var l: Array = SQUAD_MEMBERS.get(StringName(unit_id), [])
	var out: Array = []
	for m in l:
		out.append(GRENADIERS[m] if m is StringName else m)
	return out

func is_squad(unit_id) -> bool:
	return SQUAD_MEMBERS.has(StringName(unit_id))

## carriers[alive][weapon index]: how many of the first `alive` members carry each of the
## unit's weapons (cached per unit def; sim-safe, data only).
var _carriers := {}
func squad_carriers(ud: UnitDef) -> Array:
	if _carriers.has(ud.id):
		return _carriers[ud.id]
	var ms := squad_members(ud.id)
	var out: Array = []
	for alive in ms.size() + 1:
		var row := PackedInt32Array()
		row.resize(ud.weapons.size())
		for wi in ud.weapons.size():
			var n := 0
			for j in alive:
				if (ms[j][1] as Array).has(StringName(ud.weapons[wi])):
					n += 1
			row[wi] = n
		out.append(row)
	_carriers[ud.id] = out
	return out

## Drone def an operator launches for kind ("bomb" / "scout"), or &"" if it has none of that kind.
func operator_drone(op_def, kind: String) -> StringName:
	return OPERATOR_DRONES.get(StringName(op_def), {}).get(kind, &"")
