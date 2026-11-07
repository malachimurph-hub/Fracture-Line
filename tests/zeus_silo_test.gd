## ZEUS silo presentation and pylon coverage ring. Gameplay numbers stay on the 0.4.4 card.
extends RefCounted
const M33 := preload("res://tests/m33_test.gd")

static func run(t: Node) -> void:
	_balance(t)
	_scene(t)
	_round(t)
	_hatches(t)
	_rings(t)

static func _balance(t: Node) -> void:
	var pad := Content.building(&"us_zeus_launcher")
	var pyl := Content.building(&"us_zeus_pylon")
	var wpn := Content.weapon(&"us_zeus_missile")
	t._check(pad.cost == 8500 and pad.power == -11 and pad.footprint == Vector2i(4, 3) and pad.max_hp == 2200, "ZEUS launcher card is unchanged")
	t._check(pyl.cost == 2000 and pyl.power == -3 and pyl.footprint == Vector2i(2, 2) and pyl.aux_radius == 14 and pyl.max_hp == 900, "ZEUS pylon card and 14-tile ring are unchanged")
	t._check(wpn.damage == 150 and wpn.splash_mt == 1200 and wpn.vfx == &"missile" and ZeusSys.SALVO == 6 and ZeusSys.RECHARGE == 600 and ZeusSys.GAP == 8, "the salvo is still six demolition missiles")
	t._check(WeaponFx.class_of(&"us_zeus_missile", "missile") == "icbm", "the ZEUS round uses the heavy missile presentation")
	t._check(WeaponFx.class_of(&"us_javelin", "missile") == "missile" and WeaponFx.class_of(&"ecc_silo_missile", "missile") == "missile", "other missiles stay on the small streak")
	var heavy: Dictionary = WeaponFx.P["icbm"]
	var small: Dictionary = WeaponFx.P["missile"]
	t._check(float(heavy["w"]) > float(small["w"]) * 2.0 and float(heavy["imp"]) > float(small["imp"]) and float(heavy["muz"]) > 0.8, "the heavy round is wider, with a larger launch and impact")
	var csv := FileAccess.get_file_as_string("res://locale/strings.csv")
	for word in ["Textron", "Lockheed", "Boeing", "Sikorsky", "Raytheon", "Northrop"]:
		t._check(not csv.contains(word), "strings have no company name (%s)" % word)
	var launch := TranslationServer.translate("BLD_US_ZEUS_LAUNCHER_DESC")
	var pylon := TranslationServer.translate("BLD_US_ZEUS_PYLON_DESC")
	t._check(launch.contains("Fortified silo") and launch.contains("six heavy missiles"), "launcher text describes the silo")
	t._check(pylon.contains("while you place") and pylon.contains("selected"), "pylon text describes when the ring shows")

static func _scene(t: Node) -> void:
	var v: Node = load("res://view/buildings/us/zeus_launcher.tscn").instantiate()
	var tris := 0
	var doors := 0
	var muzzles: Array = []
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null and m.get_surface_count() > 0:
			tris += m.surface_get_array_index_len(0) / 3
		if String(mi.get_meta("anim", "")) == "door":
			doors += 1
	for n in v.find_children("Muzzle*", "Marker3D", true, false):
		muzzles.append(String(n.name))
	muzzles.sort()
	t._check(tris >= 2500 and tris <= 14000, "the silo is a fitted model (%d tris)" % tris)
	t._check(doors == 5, "five silo lids swing open (%d)" % doors)
	t._check(muzzles.size() == 6 and muzzles[0] == "Muzzle0" and muzzles[5] == "Muzzle5", "six launch points, one per shaft")
	var round := v.get_node_or_null("Model/LoadedRound")
	t._check(round != null and round is MeshInstance3D, "the open shaft holds a loaded round")
	if round != null:
		var rb: AABB = (round as MeshInstance3D).mesh.get_aabb()
		t._check(rb.size.y > 1.2 and rb.size.x < 0.8, "the loaded round reads as a large upright missile (%.2f tall)" % rb.size.y)
	var hull := v.get_node("Model/Hull") as MeshInstance3D
	var hb: AABB = hull.mesh.get_aabb()
	t._check(hb.position.x > -2.05 and hb.position.z > -1.6 and hb.end.x < 2.05 and hb.end.z < 1.6, "the fort stays inside the 4 x 3 pad")
	t._check(v.get_script() != null, "the silo is a building view")
	v.free()

static func _round(t: Node) -> void:
	var mesh := WeaponFx.icbm_mesh()
	var bb: AABB = mesh.get_aabb()
	t._check(bb.size.z > 1.2 and bb.size.x > 0.18 and bb.size.y > 0.18, "the flying round is a large missile body (%.2f long)" % bb.size.z)
	var wfx := WeaponFx.new()
	t.add_child(wfx)
	wfx.fire("icbm", [Vector3(0, 1.5, 0)], Vector3.UP, Vector3(8, 0, 3), 0, -1, Vector3.ZERO)
	t._check(wfx.shots.size() == 1 and wfx.shots[0].get("body") != null, "a launch puts a missile mesh in the air")
	var body: MeshInstance3D = wfx.shots[0]["body"]
	t._check(body.mesh == mesh or body.mesh.get_aabb().size.z > 1.2, "the airborne mesh is the heavy round")
	wfx.free()

static func _hatches(t: Node) -> void:
	var v: BuildingView = load("res://view/buildings/us/zeus_launcher.tscn").instantiate()
	t.add_child(v)
	t._check(v.loaded_round != null and v.loaded_round.visible, "the loaded round shows while the silo is closed")
	v.on_fire()
	v._process(0.25)
	var opened := 0
	for a in v.anim_parts:
		if a[1] == "door" and absf((a[0] as Node3D).rotation.z) > 0.4:
			opened += 1
	t._check(opened == 5, "a launch swings every lid (%d)" % opened)
	t._check(not v.loaded_round.visible, "the standing round steps aside while a missile is leaving")
	v._door_t = 0.0
	v._process(0.05)
	t._check(v.loaded_round.visible, "the round is back once the lids shut")
	v.play_death()
	var lingering := 0
	if v.loaded_round.visible:
		lingering += 1
	for a in v.anim_parts:
		if (a[0] as Node3D).visible:
			lingering += 1
	t._check(lingering == 0, "destruction clears the round and the lids")
	v.free()

static func _rings(t: Node) -> void:
	var r := M33._runner(["us", "eu"])
	var w: SimWorld = r.sim
	var hq := M33._hq(w, 0)
	var wv := WorldView.new()
	t.add_child(wv)
	wv.sim = w
	wv.local_pid = 0
	wv.local_team = w.players[0].team
	wv.terrain = TerrainView.new()
	wv.add_child(wv.terrain)
	for s in Palette.SHAPES:
		wv.ring_meshes.append(Palette.ring_mesh(s))
	var pyl := w._place_building(Content.building(&"us_zeus_pylon"), 0, hq.tile + Vector2i(8, 0), 0, true)
	var pad := w._place_building(Content.building(&"us_zeus_launcher"), 0, hq.tile + Vector2i(8, 6), 0, true)
	var want := float(Content.building(&"us_zeus_pylon").aux_radius)
	wv._ensure_view(pyl)
	wv._ensure_view(pad)
	wv.selected = []
	wv._update_rings()
	t._check(wv.pylon_cover(pyl.id) == null and wv.views[pyl.id].find_child("PylonRange", true, false) == null, "a finished pylon draws no ring until it is selected")
	t._check(wv.views[pad.id].find_child("PylonRange", true, false) == null, "the launcher does not draw a pylon ring")
	wv.selected = [pyl.id]
	wv._update_rings()
	var ring := wv.pylon_cover(pyl.id)
	t._check(ring != null and is_equal_approx(ring.scale.x, want) and is_equal_approx(ring.scale.z, want), "the selected ring uses the real %d-tile coverage" % int(want))
	wv.selected = [pad.id]
	wv._update_rings()
	t._check(wv.pylon_cover(pyl.id) == null and wv.pylon_cover(pad.id) == null, "selecting the launcher hides the pylon ring")
	wv.selected = [pyl.id]
	wv._update_rings()
	wv.selected = []
	wv._update_rings()
	t._check(wv.pylon_cover(pyl.id) == null, "deselecting the pylon hides the ring")
	wv.selected = [pyl.id]
	wv._update_rings()
	pyl.alive = false
	wv._update_rings()
	t._check(wv.pylon_cover(pyl.id) == null, "a destroyed pylon does not keep a ring")
	var site := w._place_building(Content.building(&"us_zeus_pylon"), 0, hq.tile + Vector2i(-8, 0), 0, false)
	wv._ensure_view(site)
	wv.selected = []
	wv._update_rings()
	t._check(wv.pylon_cover(site.id) == null, "an unselected construction site has no ring")
	wv.selected = [site.id]
	wv._update_rings()
	t._check(wv.pylon_cover(site.id) != null and is_equal_approx(wv.pylon_cover(site.id).scale.x, want), "selecting the site shows the real radius")
	site.built = true
	wv._update_rings()
	t._check(wv.pylon_cover(site.id) != null, "finishing construction keeps the ring while the site stays selected")
	wv.selected = []
	wv._update_rings()
	t._check(wv.pylon_cover(site.id) == null, "finishing construction hides the ring when nothing is selected")
	wv._forget_view(site.id)
	t._check(wv.pylon_cover(site.id) == null, "forgetting the view leaves no ring")
	wv.local_team = w.players[1].team
	var foe := w._place_building(Content.building(&"us_zeus_pylon"), 0, hq.tile + Vector2i(0, 10), 0, true)
	wv._ensure_view(foe)
	wv.selected = [foe.id]
	wv._update_rings()
	t._check(wv.pylon_cover(foe.id) == null, "an enemy pylon does not show its coverage")
	wv.local_team = w.players[0].team
	wv.show_ghost(&"us_zeus_pylon", hq.tile + Vector2i(14, -6), 0, true, 0)
	var ghost := wv.ghost_pylon_cover()
	t._check(ghost != null and is_equal_approx(ghost.scale.x, want) and is_equal_approx(ghost.scale.z, want), "placement shows the real coverage radius")
	wv.hide_ghost()
	t._check(wv.ghost_pylon_cover() == null, "cancelling placement removes the coverage ring")
	wv.show_ghost(&"us_barracks", hq.tile + Vector2i(14, 4), 0, true, 0)
	t._check(wv.ghost_pylon_cover() == null, "placing another building does not keep the pylon ring")
	wv.show_ghost(&"us_zeus_pylon", hq.tile + Vector2i(14, -6), 1, true, 0)
	t._check(wv.ghost_pylon_cover() != null and is_equal_approx(wv.ghost_pylon_cover().scale.x, want), "rotating the ghost keeps the real radius")
	wv.hide_ghost()
	t._check(wv.ghost_pylon_cover() == null, "the ring is gone after the ghost is dismissed")
	wv.free()
