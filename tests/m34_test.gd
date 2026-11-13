## M3.4 (Malachi's 0.3.5 play-test): night lights that follow the vehicles' real headlights every
## frame, floodlights on buildings instead of a glow round them, and the infantry overhaul.
## Also the Minerals Mining excavator's pack-up animation (_mine_packup), income popups, the live
## menu battle (_menu_battle) and the Campaign 'Coming soon' entry (_menu_campaign).
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_lamps_on_models(t)
	_beams_every_frame(t)
	_floodlights(t)
	_structure_fill(t)
	_mine_packup(t)
	_income_popups(t)
	await _menu_campaign(t)
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
	# The excavator pack-up belonged to the old Minerals Mining mesh. The hub no longer packs.
	# The vehicle scene from that era is kept so a save that was already on the move still draws.
	t._check(MineSys.PACK_MS == 10000, "the old pack-up timer constant is unchanged for saves that were mid-move")
	var scene: Node = load("res://view/buildings/ecc/black_market.tscn").instantiate()
	var rig = PackRig.from(scene.get_node("Model"))
	t._check(rig == null and scene.find_child("BucketWheel", true, false) == null, "the hacker hub has no excavator pack rig")
	scene.free()
	var mob: Node = load("res://view/units/ecc/mine_mobile.tscn").instantiate()
	t._check(mob.find_child("BucketWheel", true, false) != null, "old saves still have the packed excavator model")
	mob.free()

# ------------------------------------------------------------------ passive income popups
## Malachi: "For all passive income buildings, have the amount it generates pop up and fade like
## supply trucks do". IncomePopups works out each structure's earnings from the sim (view only)
## and match.gd shows them with the truck's "+$N" floater every 10 s per structure.
static func _income_popups(t: Node) -> void:
	var r := M33._runner(["us", "eu"])
	var w := r.sim
	var placed := {}
	for pid in 2:
		var hq := M33._hq(w, pid)
		var k := 0
		for did in [&"us_reactor", &"us_reactor", &"us_drop_zone", &"eu_hub", &"eu_exchange", &"tpla_bazaar", &"eu_hub"]:
			var st := M33.spot(w, pid, did, hq.tile + Vector2i(6, 4), k)
			var b := w._place_building(Content.building(did), pid, st, 0, true)
			placed[b.id] = did
			k += 1
	var pops := IncomePopups.new()
	pops.step(w, 0)   # the snapshot before the first economy second
	var got := {}        ## id -> [count, total]
	var bad: Array = []
	var seconds := 0
	var ref := r.sim.state_hash()
	for i in 61 * 20:
		var h0: int = w.players[0].stats["harvested"]
		r.advance()
		var unl := 0
		for ev in w.events:
			if ev["t"] == "unload" and ev.has("amount"):
				var u := w.get_ent(int(ev["id"]))
				if u != null and u.owner == 0:
					unl += int(ev["amount"])
		var due := pops.step(w, 0)
		if IncomePopups.econ_ran(w):
			seconds += 1
			var sum := 0.0
			for id in pops.last:
				sum += float(pops.last[id])
			var real: int = w.players[0].stats["harvested"] - h0 - unl
			if absf(sum - real) > 0.01 and bad.size() < 4:
				bad.append("t=%d: popups %.2f, sim paid %d" % [w.tick, sum, real])
		for pu in due:
			var e: SimEntity = pu[0]
			var g: Array = got.get(e.id, [0, 0])
			g[0] += 1
			g[1] += int(pu[1])
			got[e.id] = g
	t._check(seconds == 61 and bad.is_empty(), "income popups add up to what the sim actually paid, every second (%d s)%s" % [seconds, "" if bad.is_empty() else ": " + str(bad)])
	var mine := 0
	var theirs := 0
	var kinds := {}
	for id in got:
		var e := w.get_ent(id)
		if e.owner == 0:
			mine += 1
			kinds[e.def_id] = true
		else:
			theirs += 1
	t._check(theirs == 0 and mine >= 4 and kinds.size() == 4, "every kind of income structure the player owns pops its payout (%s), never the enemy's" % str(kinds.keys()))
	var each_ok := true
	for id in got:
		each_ok = each_ok and int(got[id][0]) >= 5 and int(got[id][0]) <= 7 and int(got[id][1]) > 0
	t._check(each_ok, "each structure pops about every 10 s (%s)" % str(got.values().slice(0, 5)))
	# a Data Center ($500 / min) shows about $500 a minute in its popups
	var dz := 0
	for id in got:
		if w.get_ent(id).def_id == &"us_drop_zone":
			dz += int(got[id][1])
	t._check(w.players[0].low_power or (dz >= 400 and dz <= 600), "a Data Center's popups add up to about its $500 a minute ($%d in 61 s, low power %s)" % [dz, w.players[0].low_power])
	t._check(IncomePopups.shares(w, -1).is_empty(), "no popups for a spectator")
	var src := FileAccess.get_file_as_string("res://match/match.gd")
	t._check(src.contains("_income.step(runner.sim, local_pid)") and src.contains("\"+$%d\" % int(pu[1]), Color(\"#ffd166\"))") and src.contains("bv.visible"),
		"the match shows them with the supply-truck floater (same text, colour, rise and fade), only for structures on view")
	var ov := FileAccess.get_file_as_string("res://ui/hud/world_overlay.gd")
	t._check(ov.contains("IncomePopups.MAX_FLOATERS"), "floaters are capped (drawn text, no nodes)")

# ------------------------------------------------------------------ Campaign "Coming soon"
static func _menu_campaign(t: Node) -> void:
	var menu: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	t.add_child(menu)
	await t.get_tree().process_frame
	var cb := menu.find_child("Campaign", true, false) as Button
	var soon := menu.find_child("CampaignSoon", true, false) as Label
	t._check(cb != null and soon != null and soon.text == "Coming soon", "the menu has a Campaign entry with a small 'Coming soon' line")
	if cb != null:
		t._check(cb.text == "Campaign" and (menu.find_child("MapBuilder", true, false) as Button).custom_minimum_size == cb.custom_minimum_size, "Campaign is styled like the other menu buttons (beside Map Builder)")
		var scene0 := t.get_tree().current_scene
		cb.pressed.emit()
		await t.get_tree().process_frame
		var toast := menu.find_child("Toast", true, false) as Label
		t._check(toast != null and toast.visible and toast.text.contains("coming soon"), "tapping Campaign says it is coming soon")
		t._check(menu.is_inside_tree() and t.get_tree().current_scene == scene0, "and starts nothing")
	t._check(menu.find_child("BattleBackdrop", true, false) == null and menu.find_child("KeyArt", true, false) != null, "headless: the static key art backdrop")
	menu.queue_free()
	await t.get_tree().process_frame
