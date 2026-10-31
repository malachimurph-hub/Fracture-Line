## M3.3 Phase 2 headless checks (run from m33_test): new models, Iran power, insignia,
## builder work animations.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_builders(t)
	_garrison_flag(t)
	_props(t)
	_barricade_crew(t)
	_infantry_scale(t)
	_new_models(t)
	_cc_plant(t)

# ------------------------------------------------------------------ builders at work (45 / 33 / 36)
static func _builders(t: Node) -> void:
	for pair in [["us", &"us_dozer", &"us_barracks", "Blade"], ["tpla", &"tpla_backhoe", &"tpla_camp", "Arm"], ["eu", &"eu_crawler", &"eu_barracks", "Boom"]]:
		var r := M33._runner([pair[0], "ecc"])
		var w := r.sim
		var wv := WorldView.new()
		t.add_child(wv)
		wv.setup(r, 0)
		var hq := M33._hq(w, 0)
		var st := M33.spot(w, 0, pair[2], hq.tile + Vector2i(5, 5))
		var site := w._place_building(Content.building(pair[2]), 0, st, 0, false)
		var b := w.spawn_unit(pair[1], 0, null, FX.tile_center(st + Vector2i(-3, 0)))
		b.orders = [{"o": "build", "target": site.id}]
		var v: VehicleView = null
		var worked := false
		var moved := false
		var rest := Vector3.ZERO
		for i in 400:
			r.advance()
			if v == null:
				v = wv._ensure_view(b) as VehicleView
				if v != null and not v.work_parts.is_empty():
					rest = (v.work_parts[0][0] as Node3D).rotation
			wv.frame(1.0, 1.0 / 15.0)
			if v != null and v.working:
				worked = true
				v._process(0.4)
				if (v.work_parts[0][0] as Node3D).rotation.distance_to(rest) > 0.05:
					moved = true
			if worked and moved:
				break
		t._check(v != null and v.work_parts.size() == 1 and v.work_parts[0][0].name == pair[3], "%s: the %s is a separate moving part" % [pair[1], pair[3]])
		t._check(worked and moved, "%s: animates its %s while it works at the site" % [pair[1], pair[3]])
		wv.queue_free()

# ------------------------------------------------------------------ garrisoned civilian structures (11)
static func _garrison_flag(t: Node) -> void:
	var v: Node3D = load("res://view/buildings/neutral/house_a.tscn").instantiate()
	t.add_child(v)
	GarrisonMark.apply(v, 1)
	var m: GarrisonMark = v.get_node_or_null("GarrisonMark")
	t._check(m != null and m.visible and m.flag != null and m._mat.albedo_color == Palette.color(1), "a garrisoned house flies a flag in the occupier's colour")
	GarrisonMark.apply(v, -1)
	t._check(m != null and not m.visible, "the flag comes down when the house is empty")
	v.queue_free()
	var src: String = FileAccess.get_file_as_string("res://view/world_view.gd")
	t._check(src.count("GarrisonMark.apply(") >= 3, "WorldView raises the flag on garrison, on empty-out and on load")

# ------------------------------------------------------------------ trees and rocks (18)
static func _props(t: Node) -> void:
	var sh: String = FileAccess.get_file_as_string("res://view/terrain/prop.gdshader")
	t._check(sh.contains("BACKLIGHT") and sh.contains("leaf cards flutter"), "leaves let light through and flutter in the wind")
	var counts := []
	for k in ["rock", "rock:1", "rock:2"]:
		var m: Mesh = PropMeshes.make(k)
		counts.append(m.surface_get_array_index_len(0) if m.surface_get_array_index_len(0) > 0 else m.surface_get_array_len(0))
	t._check(counts[0] != counts[1] and counts[1] != counts[2] and counts.max() < 1200, "rocks are irregular stone clusters, different per variant and phone-light (%s)" % str(counts))

# ------------------------------------------------------------------ barricade crews (10)
static func _barricade_crew(t: Node) -> void:
	var r := M33._runner(["us", "ecc"])
	var w := r.sim
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	var hq := M33._hq(w, 0)
	var st := M33.spot(w, 0, &"us_sandbags", hq.tile + Vector2i(6, 0))
	var b := w._place_building(Content.building(&"us_sandbags"), 0, st, 0, true)
	var units := []
	for k in 2:
		var u := w.spawn_unit(&"us_grunt", 0, null, b.pos)
		u.res_id = -b.id
		units.append(u)
		wv._ensure_view(u)
	wv._ensure_view(b)
	wv.frame(1.0, 1.0 / 15.0)
	var v0: InfantryView = wv.views[units[0].id]
	var v1: InfantryView = wv.views[units[1].id]
	var c := FX.to_world(b.pos)
	t._check(v0.visible and v0.braced and v1.braced, "troops manning a barricade are shown (not hidden inside it) and lean over it")
	t._check(v0.position.distance_to(c) < 1.6 and v0.position.distance_to(v1.position) > 0.4, "they stand behind the wall, spread along it (%.2f from the centre, %.2f apart)" % [v0.position.distance_to(c), v0.position.distance_to(v1.position)])
	t._check(v0.vat.anims.has("lean"), "soldier bakes carry the barricade lean pose")
	units[0].res_id = 0
	wv.frame(1.0, 1.0 / 15.0)
	t._check(not v0.braced, "a soldier who steps out stands normally again")
	wv.queue_free()

# ------------------------------------------------------------------ infantry scale (16)
static func _infantry_scale(t: Node) -> void:
	t._check(is_equal_approx(WorldView.INF_SCALE, 1.0), "infantry draw at vehicle scale (x%.1f, was x1.4)" % WorldView.INF_SCALE)
	var src: String = FileAccess.get_file_as_string("res://tools/bake_infantry.gd")
	t._check(src.contains("TARGET_TRIS := 1800") and src.contains('"Head": Vector3(0.6,'), "soldiers re-baked with more detail and adult proportions")

# ------------------------------------------------------------------ new models, Iran power, silo, insignia (25-29, 31, 37, 42, 43, 34)
static func _scene_has(path: String, names: Array) -> bool:
	var v: Node = load(path).instantiate()
	var ok := true
	for n in names:
		if v.find_child(n, true, false) == null:
			ok = false
	v.free()
	return ok

static func _new_models(t: Node) -> void:
	var gp := Content.building(&"tpla_gas_plant")
	t._check(gp != null and gp.power == 8 and gp.cost == 600 and gp.footprint == Vector2i(3, 3) and Content.faction(&"tpla")["buildings"].has(&"tpla_gas_plant"),
		"Iran builds a 3x3 Gas Turbine Plant ($600, +8 power)")
	t._check(Content.building(&"us_drop_zone").footprint == Vector2i(4, 4) and Content.building(&"tpla_bazaar").footprint == Vector2i(2, 2),
		"Data Center is 4x4 and the Oil Derrick 2x2")
	var er := Content.weapon(&"ecc_eng_rocket")
	t._check(Content.unit(&"ecc_engineer").weapons.has("ecc_eng_rocket") and er.damage == 60 and er.cooldown_ms == 8000,
		"the ECC engineer carries a slow rocket launcher (60 dmg / 8 s)")
	var sm := Content.weapon(&"ecc_silo_missile")
	t._check(Content.building(&"ecc_bunker").weapons.has("ecc_silo_missile") and sm.damage == 240 and sm.range_mt == 9500,
		"the missile silo fires a 240-damage missile at 9.5 tiles")
	t._check(_scene_has("res://view/buildings/ecc/bunker.tscn", ["DoorL", "DoorR"]), "the silo has two hatch doors")
	t._check(_scene_has("res://view/buildings/ecc/black_market.tscn", ["BucketWheel"]), "the excavator has a bucket wheel")
	t._check(_scene_has("res://view/buildings/tpla/bazaar.tscn", ["Beam"]), "the oil derrick has a walking beam")
	t._check(_scene_has("res://view/buildings/us/reactor.tscn", ["Stack0", "Stack1"]) and _scene_has("res://view/buildings/tpla/gas_plant.tscn", ["Stack0", "Stack1"]),
		"reactor towers and gas-plant stacks carry steam/smoke emitters")
	var crossed := true
	for b in ["hq", "barracks", "motor_pool", "heavy_factory"]:
		if not _scene_has("res://view/buildings/eu/%s.tscn" % b, ["Insignia"]):
			crossed = false
	t._check(crossed, "eu HQ, barracks, motor pool and heavy factory carry the cross insignia")
	var modern := true
	for b in ["den", "camp", "chop_shop", "workshop", "stash", "airfield", "tunnel", "wasp_nest", "bazaar"]:
		var v: Node = load("res://view/buildings/tpla/%s.tscn" % b).instantiate()
		var hit := false
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.has_meta("tpla_modern"):
				hit = true
		if not hit:
			modern = false
		v.free()
	t._check(modern, "Iran buildings use the modern paint pass")

# ------------------------------------------------------------------ Iran Combined-Cycle Gas Plant (Malachi 2026-10-29)
static func _cc_plant(t: Node) -> void:
	var cc := Content.building(&"tpla_cc_plant")
	var gt := Content.building(&"tpla_gas_plant")
	var nuc := Content.building(&"us_reactor")
	# M3.5 item 15: Russia and Iran swapped power-station models; Iran's big plant is now the
	# 3x3 Gas Processing Plant, the 4x4 combined-cycle model is Russia's; the stats followed the
	# models (Iran now has Russia's old $800 / +10 plant, Russia the old $1,600 / +19 one)
	t._check(cc != null and cc.power == 10 and cc.cost == 800 and cc.build_time_ms == 10000 and cc.max_hp == 1000 and cc.footprint == Vector2i(3, 3) and cc.prereqs.has("tpla_workshop"),
		"Iran Gas Processing Plant: $800, +10 power, 3x3, needs the Defence Workshop")
	t._check(cc.power > gt.power and cc.cost > gt.cost and nuc != null,
		"it out-powers the Gas Turbine Plant and costs more")
	var order: Array = Content.faction(&"tpla")["buildings"]
	t._check(order.has(&"tpla_cc_plant") and order.find(&"tpla_cc_plant") == order.find(&"tpla_gas_plant") + 1, "it sits next to the Gas Turbine Plant in Iran's build list")
	t._check(TranslationServer.translate(cc.name_key) == "Gas Processing Plant" and TranslationServer.translate(cc.desc_key) != cc.desc_key, "it has a name and an info-card description")
	var ru := Content.building(&"ecc_power")
	t._check(TranslationServer.translate(ru.name_key) == "Combined-Cycle Gas Plant" and ru.footprint == Vector2i(4, 4)
		and ru.cost == 1600 and ru.power == 19 and ru.build_time_ms == 20000 and ru.max_hp == 1500 and ru.prereqs.is_empty(),
		"Russia's power station is now the Combined-Cycle Gas Plant (4x4, $1,600, +19 power, no prereq)")
	var v: Node = load(ru.view_scene).instantiate()
	var fans := 0
	for n in v.find_children("Fan*", "MeshInstance3D", true, false):
		if n.get_meta("anim", "") == "spin":
			fans += 1
	t._check(fans == 8 and v.find_child("Stack0", true, false) != null and v.find_child("Stack1", true, false) != null and v.get("footprint") == Vector2(4, 4),
		"the combined-cycle model (Russia) has two smoking stacks and 8 spinning condenser fans (%d)" % fans)
	v.free()
	# in a match: locked until the workshop, then +10 power; the AI picks it when it can
	var r := M33._runner(["tpla", "ecc"])
	var w := r.sim
	var hq := M33._hq(w, 0)
	w.players[0].supply = 20000
	t._check(w.prereqs_met(0, cc.prereqs) == "tpla_workshop", "locked until a Defence Workshop is built")
	for id in [&"tpla_camp", &"tpla_chop_shop", &"tpla_workshop"]:
		w._place_building(Content.building(id), 0, M33.spot(w, 0, id, hq.tile), 0, true)
	for i in 3:
		r.advance()
	var ai := AITpla.new()
	ai.init(r, 0, "normal", &"tpla_scrapjack")
	t._check(w.prereqs_met(0, cc.prereqs) == "" and ai._next_building() == &"tpla_cc_plant", "the Iran AI builds it once the workshop is up and power runs short")
	var p0: SimPlayer = w.players[0]
	var before := p0.power_prod
	w._place_building(cc, 0, M33.spot(w, 0, &"tpla_cc_plant", hq.tile), 0, true)
	for i in 12:
		r.advance()
	t._check(p0.power_prod - before == 10 and not p0.low_power, "a Gas Processing Plant adds 10 power (%d -> %d)" % [before, p0.power_prod])
