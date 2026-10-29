## M3.3 Phase 2 headless checks (run from m33_test): new models, Iran power, insignia,
## builder work animations.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_builders(t)

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
