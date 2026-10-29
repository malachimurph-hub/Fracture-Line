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
