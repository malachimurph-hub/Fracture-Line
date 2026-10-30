## M3.4 (Malachi's 0.3.5 play-test): night lights that follow the vehicles' real headlights every
## frame, floodlights on buildings instead of a glow round them, and the infantry overhaul.
## Also the Minerals Mining excavator's pack-up animation (_mine_packup).
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_lamps_on_models(t)
	_beams_every_frame(t)
	_floodlights(t)
	_structure_fill(t)
	_mine_packup(t)
	if ResourceLoader.exists("res://tests/m34_inf_test.gd"):
		await load("res://tests/m34_inf_test.gd").run(t)

static func _night_view(t: Node, facs: Array) -> WorldView:
	var r: MatchRunner = load("res://tests/m33_p3_test.gd")._runner_on("riverside_metro_night", facs)
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	return wv

# ------------------------------------------------------------------ headlights on the model's lamps
static func _lamps_on_models(t: Node) -> void:
	var wv := _night_view(t, ["us", "eu"])
	var w := wv.sim
	var at := FX.to_tile(M33._hq(w, 0).pos) + Vector2i(10, 0)
	var bad: Array = []
	var n := 0
	var with_geo := 0
	for id in Content.units:
		var ud: UnitDef = Content.units[id]
		if ud.move_layer != &"vehicle" or ud.view_scene == "" or not ResourceLoader.exists(ud.view_scene):
			continue
		var u := w.spawn_unit(id, 0, null, FX.tile_center(at))
		wv._ensure_view(u)
		var v: EntityView = wv.views[u.id]
		var lamps := WorldView.headlights_of(v)
		n += 1
		if lamps.size() < 1 or lamps.size() > 2:
			bad.append("%s: %d lamps" % [id, lamps.size()])
		for l: Vector3 in lamps:
			if l.z <= 0.0 or l.y <= 0.05 or l.y > 3.0 or absf(l.x) > 2.0:
				bad.append("%s: lamp at %s" % [id, l])
		if lamps.size() == 2 and (lamps[0].x * lamps[1].x >= 0.0 or absf(lamps[0].z - lamps[1].z) > 0.25):
			bad.append("%s: lamps not a left/right pair %s" % [id, lamps])
		if not WorldView._lamp_cache.is_empty() and _has_lamp_verts(v):
			with_geo += 1
		w.ents.erase(u.id)
		w.ids.erase(u.id)
		v.queue_free()
		wv.views.erase(u.id)
	t._check(bad.is_empty() and n > 30, "every vehicle's headlights sit at its lamps, a left/right pair at the front (%d models)%s" % [n, "" if bad.is_empty() else ": " + str(bad.slice(0, 4))])
	t._check(with_geo * 2 > n, "most models have modelled lamps the lights are taken from (%d of %d)" % [with_geo, n])
	# a known model: the IFV's lamp boxes are at (+-0.45, 0.42, 0.85) in its source
	var u2 := w.spawn_unit(&"us_bradley", 0, null, FX.tile_center(at))
	wv._ensure_view(u2)
	var bl := WorldView.headlights_of(wv.views[u2.id])
	var ok := bl.size() == 2
	for l: Vector3 in bl:
		ok = ok and absf(absf(l.x) - 0.45) < 0.12 and absf(l.y - 0.42) < 0.12 and absf(l.z - 0.85) < 0.15
	t._check(ok, "the IFV's beams come from its modelled headlights %s" % str(bl))
	t.remove_child(wv)
	wv.free()

static func _has_lamp_verts(v: EntityView) -> bool:
	for n in v.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.visibility_range_begin > 0.0:
			continue
		for si in mi.mesh.get_surface_count():
			var cols = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_COLOR]
			if cols == null:
				continue
			for c: Color in cols:
				if absf(c.a - 0.25) < 0.02 and c.r > 0.8 and c.g > 0.7:
					return true
	return false

# ------------------------------------------------------------------ beams move every frame
## Malachi: "lights are choppy with vehicle movement" - they were placed 8 times a second. Now
## every rendered frame puts the beams on the interpolated hull, between sim ticks too.
static func _beams_every_frame(t: Node) -> void:
	var wv := _night_view(t, ["us", "eu"])
	var w := wv.sim
	var at := FX.to_tile(M33._hq(w, 0).pos) + Vector2i(10, 4)
	var u := w.spawn_unit(&"us_halberd", 0, null, FX.tile_center(at))
	u.face = FX.ANG / 4
	u.dir = FX.dir_of(u.face)
	wv._ensure_view(u)
	wv.cur[u.id] = wv._world_pos(u)
	wv.prev[u.id] = wv.cur[u.id]
	wv.frame(0.0, 0.2)   # lists the vehicle (0.12 s cadence)
	wv.prev[u.id] = wv.cur[u.id]
	wv.cur[u.id] = wv.cur[u.id] + Vector3(1.0, 0, 0)   # one tick of travel
	var v: EntityView = wv.views[u.id]
	var lamps := WorldView.headlights_of(v)
	var errs: Array = []
	var last := Vector3.INF
	var moved := 0
	for k in 5:
		wv.frame(0.2 * k, 0.016)   # 60 fps: well inside the 0.12 s list cadence
		var ends: Array = wv.night.beam_ends
		var near := _nearest(ends, v.global_position)
		if near == Vector3.INF:
			errs.append("frame %d: no beam" % k)
			continue
		# the beam starts in line with one of the lamps of the hull as drawn this frame
		var best := 1e9
		for l: Vector3 in lamps:
			var lw := v.global_transform * l
			var side := v.global_transform.basis.x.normalized()
			best = minf(best, absf((near - lw).dot(side)))
		if best > 0.05:
			errs.append("frame %d: beam %.2f m off the lamp" % [k, best])
		if last != Vector3.INF and near.distance_to(last) > 0.1:
			moved += 1
		last = near
	t._check(errs.is_empty() and moved >= 3, "the beams move with the drawn vehicle every frame, from its lamps (%d of 4 frames moved)%s" % [moved, "" if errs.is_empty() else ": " + str(errs)])
	t.remove_child(wv)
	wv.free()

static func _nearest(ends: Array, p: Vector3) -> Vector3:
	var best := Vector3.INF
	for e in ends:
		var a: Vector3 = e[0]
		if best == Vector3.INF or Vector2(a.x - p.x, a.z - p.z).length() < Vector2(best.x - p.x, best.z - p.z).length():
			best = a
	return best

# ------------------------------------------------------------------ floodlights, no glow
static func _floodlights(t: Node) -> void:
	var src := FileAccess.get_file_as_string("res://view/env/night_lights.gd")
	t._check(not src.contains("func set_buildings") and not src.contains("Light3D.new") and not src.contains("OmniLight3D"), "structures no longer cast a glow round themselves and no real lights are used")
	var cols := {}
	for fac in ["us", "eu", "tpla", "ecc"]:
		var wv := _night_view(t, [fac, "us" if fac != "us" else "eu"])
		var w := wv.sim
		var hq: SimEntity = M33._hq(w, 0)
		wv._ensure_view(hq)
		var v: EntityView = wv.views[hq.id]
		var fx: Array = wv._floodlights_of(v, StringName(fac))
		var ok := fx.size() >= 2 and fx.size() <= 4
		var bb := AABB(v.global_position - Vector3(v.footprint.x * 0.5 + 0.3, 0.0, v.footprint.y * 0.5 + 0.3), Vector3(v.footprint.x + 0.6, 6.0, v.footprint.y + 0.6))
		for f in fx:
			var lens: Vector3 = f[0]
			var aim: Vector3 = f[1]
			ok = ok and bb.grow(0.05).has_point(lens) and lens.y > aim.y + 0.5 and not bb.has_point(Vector3(aim.x, bb.position.y + 0.1, aim.z))
			cols[fac] = f[2]
		t._check(ok, "%s HQ: %d floodlights mounted on it, pointing out and down at the ground" % [fac, fx.size()])
		wv.frame(1.0, 0.2)
		t._check(wv.night.flood_count >= 2 and wv.night.flood_count <= NightLights.MAX_FLOOD and wv.night.flare_count >= wv.night.flood_count, "%s: floodlights drawn with lens flares (%d)" % [fac, wv.night.flood_count])
		# walls and sandbags carry no floodlights
		var small := 0
		for id in w.ids:
			var e: SimEntity = w.ents[id]
			if e.kind == SimEntity.Kind.BUILDING and wv.views.has(id):
				var bv: EntityView = wv.views[id]
				if (bv.footprint.x < 2 or bv.footprint.y < 2) and not wv._floodlights_of(bv, StringName(fac)).is_empty():
					small += 1
		t._check(small == 0, "%s: no floodlights on walls and other one-tile pieces" % fac)
		t.remove_child(wv)
		wv.free()
	var distinct := {}
	for c in cols.values():
		distinct[str(c)] = true
	t._check(distinct.size() == 4, "each faction's floodlights have their own colour")

# ------------------------------------------------------------------ structure shading (sky fill)
## Malachi: "the shading on the structures might be a little too dark". Structures, hulls and
## civilian buildings get a cheap sky fill from the fl_fill global; much stronger by moonlight,
## a little by day; the infantry shader is left alone and no lights are added.
static func _structure_fill(t: Node) -> void:
	var day := MapEnv.model_fill(MapEnv.for_map(&"riverside_metro"))
	var night := MapEnv.model_fill(MapEnv.for_map(&"riverside_metro_night"))
	var dl := Vector3(day.x, day.y, day.z).length()
	var nl := Vector3(night.x, night.y, night.z).length()
	t._check(dl > 0.0 and nl > dl * 3.0 and nl < 2.0, "structures get a sky fill: a little by day (%.3f), more by moonlight (%.3f)" % [dl, nl])
	var model := FileAccess.get_file_as_string("res://view/materials/model_m3.gdshaderinc")
	var prop := FileAccess.get_file_as_string("res://view/terrain/prop.gdshader")
	var inf := FileAccess.get_file_as_string("res://view/infantry/vat_soldier.gdshader")
	t._check(model.contains("global uniform vec4 fl_fill") and prop.contains("global uniform vec4 fl_fill") and not inf.contains("fl_fill"), "the fill is in the structure / vehicle and prop shaders, not the infantry's")
	t._check(ProjectSettings.has_setting("shader_globals/fl_fill"), "fl_fill is a project shader global")
	var mt := FileAccess.get_file_as_string("res://match/match.gd")
	t._check(mt.contains("MapEnv.model_fill(menv)") and mt.contains("\"fl_fill\", Vector4.ZERO"), "the match sets the fill for its map and clears it on the way out")

# ------------------------------------------------------------------ Minerals Mining pack-up animation
## Malachi: "Pack up animation for Russian minerals mining". The sim already has a 10 s pack-up
## (and a 10 s set-up); the view now plays it: wheel stops, stays unhooked, conveyor swings in,
## boom lowers and draws in, mast folds, spoil levelled, stabiliser jacks retract. View only.
static func _aabb_of(n: Node3D) -> AABB:
	return n.transform * (n as MeshInstance3D).mesh.get_aabb()

static func _mine_packup(t: Node) -> void:
	t._check(MineSys.PACK_MS == 10000 and FX.ms_to_ticks(MineSys.PACK_MS) == 200, "the sim's pack-up stays 10 s (200 ticks): the animation is timed to it, no sim change")
	var r := M33._runner(["ecc", "us"])
	var w := r.sim
	var ref := M33._runner(["ecc", "us"])   # the same match without a view: the animation must not touch the sim
	var wv := WorldView.new()
	t.add_child(wv)
	wv.setup(r, 0)
	var hq := M33._hq(w, 0)
	var st := M33.spot(w, 0, &"ecc_black_market", hq.tile + Vector2i(6, 0))
	var b := w._place_building(Content.building(&"ecc_black_market"), 0, st, 0, true)
	var b2 := ref.sim._place_building(Content.building(&"ecc_black_market"), 0, st, 0, true)
	wv._ensure_view(b)
	var v := wv.views[b.id] as BuildingView
	var rig: PackRig = v.pack_rig if v != null else null
	t._check(rig != null, "the excavator view has a pack-up rig")
	if rig == null:
		t.remove_child(wv)
		wv.free()
		return
	var names := {}
	for p in rig.parts:
		names[String((p[0] as Node).name)] = p[0]
	var want := ["BucketWheel", "Boom", "Mast", "Stays", "Conveyor", "Spoil", "Jack0", "Jack1", "Jack2", "Jack3"]
	var missing: Array = want.filter(func(n): return not names.has(n))
	t._check(missing.is_empty(), "rig parts: wheel, boom, mast, stays, conveyor, spoil and four stabiliser jacks%s" % ("" if missing.is_empty() else " (missing %s)" % str(missing)))
	if not missing.is_empty():
		t.remove_child(wv)
		wv.free()
		return
	wv.frame(0.0, 0.05)
	t._check(v.pack_target == 0.0 and v.pack_k == 0.0, "set up: the rig rests in the digging pose")
	rig.pose(0.0)
	var rest := {}
	for n in names:
		rest[n] = _aabb_of(names[n])
	# packed pose: every part where it should be
	rig.pose(1.0)
	# reference points on the parts (model space, as the generator built them)
	var top := Vector3(0, 2.13, -0.25)          # mast head
	var hub := Vector3(0, 1.38, 1.62)           # wheel hub, boom tip
	var dend := Vector3(1.55, 0.68, -0.95)      # discharge conveyor end
	var mast_drop: float = top.y - ((names["Mast"] as Node3D).transform * top).y
	var hub1: Vector3 = (names["Boom"] as Node3D).transform * hub
	var wheel1: Vector3 = (names["BucketWheel"] as Node3D).position
	var conv_x: float = ((names["Conveyor"] as Node3D).transform * dend).x
	var spoil_down: bool = _aabb_of(names["Spoil"]).end.y < 0.1
	var jacks_in := true
	for i in 4:
		var c0: Vector3 = (rest["Jack%d" % i] as AABB).get_center()
		var c1: Vector3 = _aabb_of(names["Jack%d" % i]).get_center()
		jacks_in = jacks_in and Vector2(c1.x, c1.z).length() < Vector2(c0.x, c0.z).length() - 0.4 and _aabb_of(names["Jack%d" % i]).position.y > (rest["Jack%d" % i] as AABB).position.y + 0.04
	t._check(mast_drop > 0.4 and hub1.y < hub.y - 0.15 and hub1.z < hub.z - 0.1 and wheel1.distance_to(hub1) < 0.01,
		"packed: mast folded (head %.2f lower), boom lowered and drawn in (tip %s), the wheel stays on it" % [mast_drop, hub1])
	t._check(conv_x < dend.x - 0.6 and spoil_down and not (names["Stays"] as Node3D).visible, "packed: conveyor swung in (end x %.2f), spoil levelled, stays unhooked" % conv_x)
	t._check(jacks_in, "packed: the stabiliser jacks lift off the ground and retract under the turntable")
	# the reverse of setting up: conveyor first, boom, mast, jacks last
	rig.pose(0.15)
	var early_ok: bool = ((names["Conveyor"] as Node3D).transform * dend).x < dend.x - 0.05 and _aabb_of(names["Jack0"]).is_equal_approx(rest["Jack0"]) and _aabb_of(names["Mast"]).is_equal_approx(rest["Mast"]) and _aabb_of(names["Boom"]).is_equal_approx(rest["Boom"])
	rig.pose(0.6)
	var mid_ok: bool = ((names["Boom"] as Node3D).transform * hub).y < hub.y - 0.15 and _aabb_of(names["Jack0"]).is_equal_approx(rest["Jack0"])
	t._check(early_ok and mid_ok, "pack-up order: conveyor swings in first, the boom lowers next, the jacks retract last (%s %s)" % [early_ok, mid_ok])
	t._check(PackRig.spin_factor(0.0) == 1.0 and PackRig.spin_factor(0.1) == 0.0, "the bucket wheel stops turning as packing starts")
	rig.pose(0.0)
	# the trigger: Pack Up drives the pose from the sim's own timer
	r.issue({"p": 0, "t": "pack", "target": b.id})
	ref.issue({"p": 0, "t": "pack", "target": b2.id})
	for i in 100:
		r.advance()
		ref.advance()
		if i % 4 == 0:
			wv.frame(0.0, 0.05)
			v._pack_step(0.05)
	wv.frame(0.0, 0.05)
	v._pack_step(0.05)
	var pr := MineSys.progress(w, b)
	t._check(MineSys.packing(w, b) and absf(pr - 0.5) < 0.03 and absf(v.pack_target - pr) < 0.001 and absf(v.pack_k - pr) < 0.05,
		"Pack Up starts the animation; half way through the 10 s it is half packed (sim %.2f, shown %.2f)" % [pr, v.pack_k])
	t._check(b.alive and b.tile == st and w.map.occ[w.map.idx(st)] != 0, "the excavator stays put on its site while it packs")
	t._check(w.state_hash() == ref.sim.state_hash(), "the animation is view only: same sim state as a match without a view")
	# a save in the middle of packing comes back at the same point of the animation
	var w2 := SimWorld.new()
	w2.deserialize(w.serialize())
	t._check(absf(MineSys.progress(w2, w2.get_ent(b.id)) - pr) < 0.001, "a save mid pack-up restores the same pack-up progress")
	# cancelling eases back out (no snap)
	r.issue({"p": 0, "t": "pack", "target": b.id})
	r.advance()
	wv.frame(0.0, 0.05)
	var k0 := v.pack_k
	v._pack_step(0.25)
	t._check(v.pack_target == 0.0 and v.pack_k < k0 and v.pack_k > 0.0, "a cancelled pack-up unfolds again smoothly (%.2f -> %.2f)" % [k0, v.pack_k])
	# pack all the way: the vehicle carries on in the packed pose and unfolds on Set Up
	r.issue({"p": 0, "t": "pack", "target": b.id})
	for i in 205:
		r.advance()
	var mob: SimEntity = null
	for id in w.ids:
		if w.ents[id].def_id == &"ecc_mine_mobile" and w.ents[id].alive:
			mob = w.ents[id]
	t._check(mob != null and not b.alive, "after the 10 s it drives off as the vehicle")
	if mob != null:
		wv._ensure_view(mob)
		var mv := wv.views[mob.id] as VehicleView
		t._check(mv != null and mv.pack_rig != null and mv.find_child("Spoil", true, false) == null, "the vehicle has the same parts, packed (the spoil stays behind)")
		if mv != null and mv.pack_rig != null:
			wv.frame(0.0, 0.05)
			t._check(mv.pack_k == 1.0 and mv.pack_target == 1.0, "the vehicle drives in the packed pose")
			r.issue({"p": 0, "t": "unpack", "ids": [mob.id]})
			for i in 101:
				r.advance()
			wv.frame(0.0, 0.05)
			t._check(MineSys.unpacking(mob) and absf(mv.pack_target - (1.0 - MineSys.progress(w, mob))) < 0.001 and mv.pack_target < 0.55,
				"Set Up plays it in reverse, in step with the set-up timer (%.2f)" % mv.pack_target)
	t.remove_child(wv)
	wv.free()
