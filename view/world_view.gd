class_name WorldView
extends Node3D
## Rendering only: builds views from the simulation, interpolates 20 Hz sim positions for
## smooth 60+ fps rendering, applies fog visibility, and plays view-only effects.

var runner: MatchRunner
var sim: SimWorld
var local_pid: int = 0
var local_team: int = 0
var terrain: TerrainView
var vfx: Vfx
var wfx: WeaponFx                ## M2.4 weapon effects (travelling rounds, no beams)
var views: Dictionary = {}       ## id -> EntityView
var ghosts: Dictionary = {}      ## dead buildings remembered in fog: id -> EntityView
var prev: Dictionary = {}        ## id -> Vector3
var cur: Dictionary = {}         ## id -> Vector3
var fx_acc: Dictionary = {}      ## id -> seconds since last ambient puff (dust / smoke)
var yaw: Dictionary = {}         ## id -> float
var rings: Dictionary = {}       ## id -> MeshInstance3D
var ring_meshes: Array = []
var selected: Array = []
var fog_version: int = -1
var fog_overlay: StandardMaterial3D
var shield_domes: Dictionary = {}  ## aegis id -> MeshInstance3D
var dome_mat: StandardMaterial3D
var rally_nodes: Array = []
var alpha: float = 0.0
var unit_scale: float = 1.0      ## readability scale
const INF_SCALE := 1.0           ## M3.3 item 16: infantry at vehicle scale (was 1.4x, GDD 14.2)
var icon_mode: bool = false      ## far zoom: models hidden, overlay draws role icons
var deferred_deaths: Dictionary = {}   ## unit id -> true while its killing round is in flight
var rigs: Dictionary = {}        ## building id -> ConstructionRig while under construction

## HP fraction for visuals: a structure under construction is measured against the HP its
## scaffold has reached so far (ProdSys.construction_hp_cap), so only real damage shows.
static func build_relative_health(e: SimEntity) -> float:
	if e.built:
		return clampf(float(e.hp) / float(maxi(1, e.max_hp)), 0.0, 1.0)
	return clampf(float(e.hp) / float(ProdSys.construction_hp_cap(e.max_hp, e.progress, e.build_ticks)), 0.0, 1.0)

func setup(r: MatchRunner, pid: int) -> void:
	runner = r
	sim = r.sim
	local_pid = pid
	local_team = sim.players[pid].team if pid >= 0 else -1
	terrain = TerrainView.new()
	add_child(terrain)
	terrain.decor_override = (Content.maps[sim.map_id] as MapDef).decor
	terrain.build(sim.map, Content.maps[sim.map_id].tiles_path, MapEnv.for_map(sim.map_id))
	vfx = Vfx.new()
	add_child(vfx)
	vfx.set_fog(terrain.fog_texture, Vector2(sim.map.w, sim.map.h))
	wfx = WeaponFx.new()
	add_child(wfx)
	wfx.setup(self, vfx)
	fog_overlay = Palette.flat(Color(0.05, 0.06, 0.08), 0.55)
	dome_mat = StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.43, 0.89, 1.0, 0.10)
	dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome_mat.rim_enabled = false
	for s in Palette.SHAPES:
		ring_meshes.append(Palette.ring_mesh(s))
	for id in sim.ids:
		_ensure_view(sim.ents[id])
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		cur[id] = _world_pos(e)
		prev[id] = cur[id]
	_refresh_fog()

func team_shape_index(team: int) -> int:
	return clampi(team, 0, 3)

## M2.5 aircraft (view only): altitude eased from the sim air_state (jets ~6 m, helicopters ~4 m,
## parked = on the pad), spinning Rotor/TailRotor nodes, bank in turns and a ground shadow.
const JET_ALT := 6.0
const HELI_ALT := 4.0
var air_alt := {}
var air_shadows := {}

func _air_view(id: int, e: SimEntity, ud: UnitDef, v: Node3D, p: Vector3, delta: float) -> Vector3:
	var jet := ud.tags.has("jet")
	var want := 0.0 if e.air_state == AirSys.PARKED or e.air_state == AirSys.TAXI_OUT else (JET_ALT if jet else HELI_ALT)
	if e.air_state == AirSys.LANDING and jet:
		want = 0.0
		var home := sim.get_ent(e.air_home)
		if home != null and e.phase == 0:   # M3.1: glide slope down to the touchdown point
			var td := FX.to_world(AirSys.local_pos(home, AirSys.RWY_X0, AirSys.RWY_Z))
			want = clampf(FX.to_world(e.pos).distance_to(td) * 0.6, 0.0, JET_ALT)
	var dive := ud.tags.has("suicide") and want > 0.0
	if dive:
		# M3.3 (Malachi: bomb drone dives onto its target): over the last ~4 tiles before it is in
		# detonation range the drone drops from cruise height to just above the target
		var tid := e.target
		if tid == 0 and not e.orders.is_empty():
			tid = int(e.orders[0].get("target", 0))
		var tgt := sim.get_ent(tid) if tid != 0 else null
		if tgt != null and not ud.weapons.is_empty():
			var dist_fx := sqrt(float(FX.dist2(e.pos, tgt.pos)))
			var reach := float(FX.mt_to_fx(Content.weapon(ud.weapons[0]).range_mt))
			want = lerpf(0.3, want, clampf((dist_fx - reach) / float(FX.ONE * 4), 0.0, 1.0))
	var alt: float = air_alt.get(id, want)
	alt = move_toward(alt, want, delta * (3.0 if jet else (4.0 if dive else 2.0)))
	air_alt[id] = alt
	var spin := alt > 0.2 or not jet
	var rotors: Array = v.get_meta("_rotors", [])
	if not v.has_meta("_rotors"):   # M3.2: quadcopters have Rotor, TailRotor, Rotor2, Rotor3
		for rn0 in v.find_children("*Rotor*", "Node3D", true, false):
			if not rn0 is MeshInstance3D:
				rotors.append(rn0)
		v.set_meta("_rotors", rotors)
	for rn in rotors:
		if rn is Node3D and spin:
			if String(rn.get_meta("rotor_axis", "y")) == "x":
				rn.rotate_object_local(Vector3.RIGHT, delta * 40.0)
			else:
				rn.rotate_object_local(Vector3.UP, delta * 28.0 * float(rn.get_meta("rotor_dir", 1.0)))   # M3.2: coaxial rotors counter-rotate
	var sh: MeshInstance3D = air_shadows.get(id)
	if sh == null:
		sh = MeshInstance3D.new()
		# M3.2 polish: soft silhouette shadow (the aircraft's own outline, rasterised once per type)
		var sil: Array = _air_silhouette(v, e.def_id)
		var q := QuadMesh.new()
		q.size = Vector2.ONE * float(sil[1])
		q.orientation = PlaneMesh.FACE_Y
		sh.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0, 0, 0, 0.42)
		m.albedo_texture = sil[0]
		sh.material_override = m
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sh)
		air_shadows[id] = sh
	sh.visible = v.visible and alt > 0.2
	sh.position = Vector3(p.x + alt * 0.25, p.y + 0.04, p.z + alt * 0.15)
	sh.rotation.y = v.rotation.y
	# higher = bigger and softer-looking (fainter)
	var k := clampf(alt / 3.0, 0.0, 1.0)
	sh.scale = Vector3.ONE * (1.0 + k * 0.15)
	(sh.material_override as StandardMaterial3D).albedo_color.a = 0.46 - k * 0.14
	return p + Vector3(0, alt, 0)

## [texture, quad size]: top-down coverage of the view's meshes in its local frame (+Z forward),
## blurred; spinning rotors become a faint disc. Cached per unit type.
var _sil_cache := {}
func _air_silhouette(v: Node3D, def_id: StringName) -> Array:
	if _sil_cache.has(def_id):
		return _sil_cache[def_id]
	const N := 64
	var tris := PackedVector2Array()
	var discs: Array = []
	var ext := 0.3
	var inv := v.global_transform.affine_inverse()
	var rotors: Array = v.get_meta("_rotors", [])
	var mroot: Node = v.get_node_or_null("Model")
	if mroot == null:
		mroot = v
	for mi in mroot.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.mesh == null or not mm.visible:
			continue
		var in_rotor := false
		for rn in rotors:
			if rn == mm or (rn as Node).is_ancestor_of(mm):
				in_rotor = true
		var xf := inv * mm.global_transform
		if in_rotor:
			var bb := xf * mm.get_aabb()
			var c := bb.get_center()
			var r := maxf(bb.size.x, bb.size.z) * 0.5
			if r > 0.15:
				discs.append([Vector2(c.x, c.z), r])
				ext = maxf(ext, maxf(absf(c.x), absf(c.z)) + r)
			continue
		for si in mm.mesh.get_surface_count():
			var arr := mm.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var cnt := ix.size() if ix.size() > 0 else vs.size()
			for t in range(0, cnt - 2, 3):
				for k in 3:
					var w := xf * vs[ix[t + k] if ix.size() > 0 else t + k]
					tris.append(Vector2(w.x, w.z))
					ext = maxf(ext, maxf(absf(w.x), absf(w.z)))
	ext *= 1.12
	var cov := PackedFloat32Array()
	cov.resize(N * N)
	var to_px := func(q: Vector2) -> Vector2: return (q / ext * 0.5 + Vector2(0.5, 0.5)) * N
	for t in range(0, tris.size(), 3):
		var a: Vector2 = to_px.call(tris[t])
		var b: Vector2 = to_px.call(tris[t + 1])
		var c: Vector2 = to_px.call(tris[t + 2])
		var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(den) < 1e-6:
			continue
		for py in range(maxi(0, int(minf(a.y, minf(b.y, c.y)))), mini(N, int(maxf(a.y, maxf(b.y, c.y))) + 1)):
			for px in range(maxi(0, int(minf(a.x, minf(b.x, c.x)))), mini(N, int(maxf(a.x, maxf(b.x, c.x))) + 1)):
				var pp := Vector2(px + 0.5, py + 0.5)
				var l1 := ((b.y - c.y) * (pp.x - c.x) + (c.x - b.x) * (pp.y - c.y)) / den
				var l2 := ((c.y - a.y) * (pp.x - c.x) + (a.x - c.x) * (pp.y - c.y)) / den
				if l1 >= -0.01 and l2 >= -0.01 and l1 + l2 <= 1.02:
					cov[py * N + px] = 1.0
	for d in discs:
		var dc: Vector2 = to_px.call(d[0])
		var dr: float = float(d[1]) / ext * 0.5 * N
		for py in N:
			for px in N:
				var dd := Vector2(px + 0.5, py + 0.5).distance_to(dc)
				if dd < dr:
					cov[py * N + px] = maxf(cov[py * N + px], 0.3 * smoothstep(dr, dr * 0.7, dd))
	var img := Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for py in N:
		for px in N:
			img.set_pixel(px, py, Color(1, 1, 1, cov[py * N + px]))
	img.resize(24, 24, Image.INTERPOLATE_BILINEAR)   # soft edge
	img.resize(64, 64, Image.INTERPOLATE_CUBIC)
	var res := [ImageTexture.create_from_image(img), ext * 2.0]
	_sil_cache[def_id] = res
	return res

## M3.2: chimney tops of industrial buildings (tall, thin mesh parts near the roof), cached per type.
var _stack_cache := {}
var _stack_bld := {}      ## id -> [world points, acc]
var _stack_scan := 0.0
## Chimney smoke: rescans built industrial buildings every 2 s, then puffs from the ones on
## screen and visible (max 10 buildings per frame, ~3 puffs/s each).
func _update_stacks(delta: float) -> void:
	_stack_scan -= delta
	if _stack_scan <= 0.0:
		_stack_scan = 2.0
		var nb := {}
		for id in views:
			var e: SimEntity = sim.ents.get(id)
			if e == null or e.kind != SimEntity.Kind.BUILDING or not e.built or not e.alive:
				continue
			var v: EntityView = views[id]
			if not v.is_inside_tree():
				continue
			var pts: Array = _stack_points(v, e.def_id)
			if pts.is_empty():
				continue
			var wp: Array = []
			for sp in pts:
				wp.append(v.global_transform * (sp as Vector3))
			nb[id] = [wp, _stack_bld[id][1] if _stack_bld.has(id) else randf() * 0.3, _stack_steam.has(e.def_id)]
		_stack_bld = nb
	var n := 0   # (buildings still draw as models at the far, icon zoom, so their chimneys smoke too)
	for id in _stack_bld:
		var it: Array = _stack_bld[id]
		it[1] += delta
		if it[1] < 0.32:
			continue
		it[1] = 0.0
		var v: EntityView = views.get(id)
		if v == null or not v.visible or not m_cam_sees(v.position):
			continue
		n += 1
		if n > 10:
			break
		for wp in it[0]:
			vfx.stack_puff(wp, it[2])

var _stack_steam := {}   ## M3.3: def ids whose Stack markers are cooling towers (big white steam)
const STACK_WORDS := ["factory", "reactor", "power", "plant", "refinery", "forge", "foundry", "chop_shop", "garage", "works", "mill"]
func _stack_points(v: EntityView, def_id: StringName) -> Array:
	if _stack_cache.has(def_id):
		return _stack_cache[def_id]
	var pts: Array = []
	# M3.3: models with explicit Stack markers (cooling towers, exhaust stacks) use those
	if v.model != null:
		for c in v.model.get_children():
			if c is Marker3D and String(c.name).begins_with("Stack"):
				pts.append((c as Marker3D).position)
				if String(c.name).contains("Steam"):
					_stack_steam[def_id] = true
	if not pts.is_empty():
		_stack_cache[def_id] = pts
		return pts
	var ok := false
	for w in STACK_WORDS:
		ok = ok or String(def_id).contains(w)
	if ok and v.model != null:
		# building meshes are merged, so find chimneys as sharp local height peaks of the
		# vertices on a coarse top-down grid (0.15-tile cells)
		var inv := v.global_transform.affine_inverse()
		const CS := 0.15
		var hmax := {}
		var top := 0.0
		for mi in v.model.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			if mm.mesh == null or not mm.is_visible_in_tree():
				continue
			var xf := inv * mm.global_transform
			for si in mm.mesh.get_surface_count():
				var vs: PackedVector3Array = mm.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for vv in vs:
					var w := xf * vv
					var k := Vector2i(floori(w.x / CS), floori(w.z / CS))
					if w.y > float(hmax.get(k, -1.0)):
						hmax[k] = w.y
					top = maxf(top, w.y)
		var cands: Array = []
		for k in hmax:
			var hk: float = hmax[k]
			if hk < 0.9 or hk < top * 0.6:
				continue
			var ring_hi := 0
			var ring_n := 0
			for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]:
				ring_n += 1
				if float(hmax.get(k + d, 0.0)) > hk - 0.35:
					ring_hi += 1
			if ring_hi <= 1:
				cands.append([hk, k])
		cands.sort_custom(func(a, b): return a[0] > b[0])
		for cd in cands:
			if pts.size() >= 2:
				break
			var c := Vector3((cd[1].x + 0.5) * CS, float(cd[0]) + 0.05, (cd[1].y + 0.5) * CS)
			var far := true
			for q in pts:
				far = far and Vector2(q.x - c.x, q.z - c.z).length() > 0.6
			if far:
				pts.append(c)
	_stack_cache[def_id] = pts
	return pts

## M3.3 item 10: where a squad manning a barricade stands: [world pos, yaw] on the side away
## from what it is shooting at (or behind the wall's front), squads spread along the wall.
## [] when the unit is not on a barricade.
func _barricade_slot(e: SimEntity) -> Array:
	var host := sim.get_ent(-e.res_id)
	if host == null or host.kind != SimEntity.Kind.BUILDING or not CommandSys.is_barricade(sim, host):
		return []
	var crew: Array = []
	for id in sim.ids:
		var u: SimEntity = sim.ents[id]
		if u.kind == SimEntity.Kind.UNIT and u.res_id == -host.id:
			crew.append(id)
	var k := maxi(0, crew.find(e.id))
	var n := maxi(1, crew.size())
	var c := FX.to_world(host.pos)
	var along := Vector3.RIGHT if host.fp.x >= host.fp.y else Vector3.BACK
	var nrm := Vector3(-along.z, 0, along.x)
	var front := Vector3(sin(host.rot * PI * 0.5), 0, cos(host.rot * PI * 0.5))
	var side: float = -1.0 if nrm.dot(front) > 0.0 else 1.0   # default: behind the wall's front
	var tgt := sim.get_ent(e.target)
	if tgt != null and tgt.alive:
		side = -1.0 if nrm.dot(FX.to_world(tgt.pos) - c) > 0.0 else 1.0
	if views.has(host.id):
		var last: float = views[host.id].get_meta("crew_side", side)
		if tgt == null or not tgt.alive:
			side = last
		views[host.id].set_meta("crew_side", side)
	var length := float(maxi(host.fp.x, host.fp.y))
	var depth := float(mini(host.fp.x, host.fp.y)) * 0.25 + 0.12   # just behind the wall line
	var pos := c + along * ((k - (n - 1) * 0.5) * length / float(n) * 0.9) + nrm * side * depth
	var face := -nrm * side
	if tgt != null and tgt.alive:
		var d := FX.to_world(tgt.pos) - pos
		if d.length() > 0.1 and d.normalized().dot(face) > 0.2:
			face = d.normalized()
	return [pos, atan2(face.x, face.z)]

## M3.3: the builder stands at an unfinished site it is building (OrderSys "build", in reach).
func _builder_working(e: SimEntity) -> bool:
	var o: Dictionary = e.head()
	if String(o.get("o", "")) != "build" or e.goal != MoveSys.NONE:
		return false
	var site := sim.get_ent(int(o.get("target", 0)))
	return site != null and not site.built and sim.dist_to_building(e.pos, site) <= OrderSys.build_reach(e, o)

func m_cam_sees(p: Vector3) -> bool:
	var c := get_viewport().get_camera_3d()
	return c != null and c.is_position_in_frustum(p)

func _world_pos(e: SimEntity) -> Vector3:
	var p := FX.to_world(e.pos)
	var t := FX.to_tile(e.pos)
	var tt := sim.map.ttype(t)
	if tt == SimMap.T.FORD:
		p.y = -0.12
	elif tt == SimMap.T.BRIDGE:
		p.y = 0.08
	return p

func _scene_for(e: SimEntity) -> String:
	match e.kind:
		SimEntity.Kind.UNIT:
			return Content.unit(e.def_id).view_scene
		SimEntity.Kind.RESOURCE:
			return "res://view/neutral/%s.tscn" % String(e.def_id)
		SimEntity.Kind.CRATE:
			return "res://view/neutral/salvage_crate.tscn"
	return Content.building(e.def_id).view_scene

func _ensure_view(e: SimEntity) -> EntityView:
	if views.has(e.id):
		return views[e.id]
	var ps: PackedScene = load(_scene_for(e))
	var v: EntityView = ps.instantiate()
	add_child(v)
	v.set_team_material(Palette.team_material(sim.players[e.owner].color if e.owner >= 0 else -1))
	var did := String(e.def_id)
	Weathering.apply(v, &"tpla" if did.begins_with("tpla_") else (&"eu" if did.begins_with("eu_") else (&"ecc" if did.begins_with("ecc_") else &"neutral")))
	v.position = _world_pos(e)
	if e.kind == SimEntity.Kind.BUILDING or e.kind == SimEntity.Kind.NEUTRAL:
		v.rotation.y = [0.0, PI * 0.5, PI, -PI * 0.5][e.rot]
		if e.kind == SimEntity.Kind.BUILDING:
			terrain.clear_area(e.tile, e.fp)   # M3.3: construction clears trees, rocks and clutter
		if e.kind == SimEntity.Kind.BUILDING and Content.btag(e.def_id, "hole") and v.model != null:
			# a rebuild hole covers the footprint of the structure that died there
			var hf: Vector2i = Content.building(e.def_id).footprint
			v.model.scale = Vector3(float(e.fp.x) / maxf(1, hf.x), 1.0, float(e.fp.y) / maxf(1, hf.y))
			v.footprint = Vector2(e.fp)
	elif e.kind == SimEntity.Kind.CRATE:
		v.rotation.y = float(e.id % 7) * 0.9
	elif e.kind == SimEntity.Kind.UNIT:
		var d: UnitDef = Content.unit(e.def_id)
		if d.tags.has("infantry"):
			v.scale = Vector3.ONE * INF_SCALE   # M3.3 item 16: at vehicle scale (was 1.4x)
		if e.tier > 0:
			v.set_tier(e.tier)
		if d.shield_aura_radius > 0:
			var dome := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = d.shield_aura_radius
			sm.height = d.shield_aura_radius * 1.2
			sm.radial_segments = 24
			sm.rings = 8
			dome.mesh = sm
			dome.material_override = dome_mat
			dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(dome)
			shield_domes[e.id] = dome
	views[e.id] = v
	v.set_meta("owner", e.owner)
	if e.kind == SimEntity.Kind.NEUTRAL and e.owner >= 0:
		GarrisonMark.apply(v, sim.players[e.owner].color)   # M3.3: a loaded save keeps the flag
	return v

## Called after every simulation tick.
func on_tick(events: Array) -> void:
	for ev in events:
		match ev["t"]:
			"spawn", "site", "crate":
				var e := sim.get_ent(int(ev["id"]))
				if e != null:
					_ensure_view(e)
					cur[e.id] = _world_pos(e)
					prev[e.id] = cur[e.id]
			"death":
				_on_death(ev)
			"salvage":
				var su := sim.get_ent(int(ev["id"]))
				if su != null and views.has(su.id):
					views[su.id].set_tier(int(ev["tier"]))
				if _visible_pos(ev["pos"]):
					vfx.salvage_fx(FX.to_world(ev["pos"]), Palette.COLORS[sim.players[su.owner].color] if su != null else Color.WHITE)
					AudioDirector.sfx("salvage", FX.to_world(ev["pos"]))
			"crate_cash":
				if _visible_pos(ev["pos"]):
					vfx.salvage_fx(FX.to_world(ev["pos"]), Color("#ffd75e"))
					AudioDirector.sfx("salvage", FX.to_world(ev["pos"]), -4.0)
			"repair_fx":   # M3.2 Field Engineer fixing a vehicle: welding sparks
				var rv := sim.get_ent(int(ev["id"]))
				if rv != null and _visible_pos(rv.pos) and randf() < 0.5:
					vfx.sparks(FX.to_world(rv.pos) + Vector3(0, 0.35, 0), Vector3(0, 0.4, 0), 4, 0.8)
			"explode":
				if _visible_pos(ev["pos"]):
					vfx.big_blast(FX.to_world(ev["pos"]), float(ev["r"]) / FX.ONE)
					AudioDirector.sfx("expl_huge", FX.to_world(ev["pos"]))
			"rust_zone":
				if _visible_pos(ev["pos"]) or local_team < 0:
					vfx.rust_cloud(FX.to_world(ev["pos"]), float(ev["r"]) / FX.ONE, float(ev["ticks"]) / FX.TICK_HZ)
			"fire":
				_on_fire(ev)
			"captured":
				var c := sim.get_ent(int(ev["id"]))
				if c != null and views.has(c.id):
					views[c.id].set_team_material(Palette.team_material(sim.players[c.owner].color))
					if rigs.has(c.id):
						rigs[c.id].refresh_team()
			"garrison":
				var b := sim.get_ent(int(ev["b"]))
				if b != null and views.has(b.id):
					views[b.id].set_team_material(Palette.team_material(sim.players[b.owner].color))
					if b.kind == SimEntity.Kind.NEUTRAL:
						views[b.id].set_meta("owner", b.owner)
						GarrisonMark.apply(views[b.id], sim.players[b.owner].color if b.owner >= 0 else -1)
			"power_fired":
				var col := Color("#6fe3ff") if ev["def"] != &"eu_recon_sweep" else Color("#ffe08a")
				var r := float(ev["r"])
				if r > 0 and (sim.player_team(int(ev["owner"])) == local_team or _visible_pos(ev["pos"])):
					vfx.ring(FX.to_world(ev["pos"]), r, col, 1.2, false)
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.kind == SimEntity.Kind.UNIT:
			prev[id] = cur.get(id, _world_pos(e))
			cur[id] = _world_pos(e)
	# neutral ownership resets when garrison is ejected
	if sim.tick % 10 == 0:
		for id in sim.ids:
			var n: SimEntity = sim.ents[id]
			if n.kind == SimEntity.Kind.NEUTRAL and views.has(id):
				var want: int = n.owner
				if views[id].get_meta("owner") != want:
					views[id].set_meta("owner", want)
					views[id].set_team_material(Palette.team_material(sim.players[want].color if want >= 0 else -1))
					GarrisonMark.apply(views[id], sim.players[want].color if want >= 0 else -1)   # M3.3: flag + team colour
	if sim.fog.version != fog_version:
		_refresh_fog()

func _refresh_fog() -> void:
	fog_version = sim.fog.version
	terrain.update_fog(sim.fog, local_team)

func _visible_pos(p: Vector2i) -> bool:
	return local_team < 0 or sim.fog.visible_tile(local_team, FX.to_tile(p))

func _on_fire(ev: Dictionary) -> void:
	var src := sim.get_ent(int(ev["id"]))
	if src == null:
		return
	if not _visible_pos(src.pos) and not _visible_pos(ev["to"]):
		return
	var v: EntityView = views.get(src.id)
	var garrison: SimEntity = null
	if src.res_id < 0:
		garrison = sim.get_ent(-src.res_id)
		if garrison != null and v != null and v.visible and CommandSys.is_barricade(sim, garrison):
			garrison = null   # M3.3 item 10: a barricade crew shoots from its own soldiers
	var kind: String = String(ev["vfx"])
	var cls := WeaponFx.class_of(StringName(ev.get("w", &"")), kind)
	if cls == "none":
		return   # bombs / charges: the "explode" event draws the blast
	var to := FX.to_world(ev["to"])
	var tgt := sim.get_ent(int(ev.get("tid", 0)))
	var tv: EntityView = views.get(tgt.id) if tgt != null else null
	var hitk := -1
	var off := Vector3.ZERO
	if not ev.get("miss", false) and tgt != null:
		if tgt.kind == SimEntity.Kind.UNIT:
			var inf := Content.unit(tgt.def_id).tags.has("infantry")
			hitk = 0 if inf else 1
			off = Vector3(0, 0.22 if inf else 0.35, 0)
		else:
			hitk = 2
	var base: Vector3 = v.position if (v != null and garrison == null) else (cur.get(src.id, _world_pos(src)) as Vector3)
	if garrison != null:
		base = FX.to_world(garrison.pos)
	var dir := to - base
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	if hitk == 2 and tv != null:
		# rounds strike the facing wall of a structure, not its centre
		off = -dir * minf(tv.footprint.x, tv.footprint.y) * 0.38 + Vector3(0, tv.bar_height * 0.4, 0)
	var muzzles := _muzzles(src, v, garrison, base, dir, cls)
	if v != null and garrison == null and v.has_method("on_fire"):
		v.on_fire()
	var aim: Vector3 = (to + off) - (muzzles[0] as Vector3)
	wfx.fire(cls, muzzles, aim, to, tgt.id if tgt != null else 0, hitk, off)
	var is_struct := src.kind != SimEntity.Kind.UNIT or garrison != null
	var snd: String = AudioDirector.weapon_sfx(_faction_of(src), kind, is_struct)
	if cls == "flame":
		snd = "flame"
	elif cls == "artillery":
		snd = "howitzer"
	AudioDirector.sfx(snd, base, -3.0 if snd in ["rifle", "tpla_carbine"] else 0.0, 0.1)

## Muzzle points for one shot: squads fire from their standing soldiers, articulated vehicles
## from the barrel tip, turrets from the turret, garrisons from the building's windows.
func _muzzles(src: SimEntity, v: EntityView, garrison: SimEntity, base: Vector3, dir: Vector3, cls: String) -> Array:
	if garrison != null:
		var gv: EntityView = views.get(garrison.id)
		var r := (minf(gv.footprint.x, gv.footprint.y) * 0.5 if gv != null else 1.0)
		return [base + dir * r + Vector3(randf_range(-0.3, 0.3), 1.0 + randf() * 0.4, randf_range(-0.3, 0.3))]
	if v == null:
		return [base + Vector3(0, 0.5, 0) + dir * 0.4]
	if v is InfantryView:
		var iv := v as InfantryView
		var out: Array = []
		var up := iv.vat.height * 0.6 if iv.vat != null else 0.25
		for i in iv.formation.size():
			if iv._state.size() > i and iv._state[i] != 3:
				out.append(iv.global_transform * (iv.formation[i] + Vector3(0, up, 0)) + dir * 0.14)
		out.shuffle()
		if out.is_empty():
			out.append(v.position + Vector3(0, 0.35, 0))
		return out
	var barrel: Node3D = v.get("barrel") if "barrel" in v else null
	if barrel != null and is_instance_valid(barrel):
		if not barrel.has_meta("tip"):
			var tip := 0.3
			for c in [barrel] + barrel.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
					var bb: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).mesh.get_aabb() if c != barrel else (c as MeshInstance3D).mesh.get_aabb()
					tip = maxf(tip, bb.end.z)
			barrel.set_meta("tip", tip)
		var bt := barrel.global_transform
		return [bt * Vector3(0, 0, float(barrel.get_meta("tip")) + 0.02)]
	if v.turret != null:
		return [v.turret.global_position + Vector3(0, 0.12, 0) + dir * (0.45 if src.kind == SimEntity.Kind.UNIT else 0.6)]
	var h := 0.5 if src.kind == SimEntity.Kind.UNIT else 0.9
	if cls in ["rocket", "missile"] and src.kind == SimEntity.Kind.UNIT and Content.unit(src.def_id).tags.has("infantry"):
		h = 0.45
	return [base + Vector3(0, h, 0) + dir * 0.4]

func _faction_of(e: SimEntity) -> String:
	if e.owner < 0:
		return "neutral"
	if e.kind == SimEntity.Kind.UNIT:
		return String(Content.unit(e.def_id).faction)
	var bd = Content.buildings.get(e.def_id)
	return String(bd.faction) if bd != null and "faction" in bd else "eu"

func _on_death(ev: Dictionary) -> void:
	var id := int(ev["id"])
	var v: EntityView = views.get(id)
	# the killing round may still be in the air (the sim resolves hits when it fires): keep the
	# unit standing until the round lands so the wreck / fall matches the impact (view only)
	if wfx != null and v != null and ev["kind"] == SimEntity.Kind.UNIT and not ev.get("deferred", false):
		var wait := minf(wfx.time_to_hit(id), 1.0)
		if wait > 0.01 and is_inside_tree():
			var ev2 := ev.duplicate()
			ev2["deferred"] = true
			deferred_deaths[id] = true
			get_tree().create_timer(wait, false).timeout.connect(_on_death.bind(ev2))
			return
	deferred_deaths.erase(id)
	var pos := FX.to_world(ev["pos"])
	var seen := _visible_pos(ev["pos"]) or int(ev.get("owner", -1)) >= 0 and sim.player_team(int(ev["owner"])) == local_team
	# M2.8: destroyed aircraft fall out of the sky trailing smoke and fire, crash, explode and
	# leave a burning wreck (view only: the sim entity is already gone)
	var ud0: UnitDef = Content.unit(ev.get("def", &"")) if ev["kind"] == SimEntity.Kind.UNIT else null
	if seen and not ev.get("silent", false) and v != null and ud0 != null and ud0.move_layer == &"air" and v.position.y > 0.6:
		_start_crash(v, ud0)
		AudioDirector.sfx("expl_large", pos, -6.0)
		vfx.explosion(v.position, 0.5)
		_forget_view(id)
		return
	if seen and not ev.get("silent", false):
		if ev["kind"] == SimEntity.Kind.UNIT:
			var inf := v != null and v is InfantryView
			AudioDirector.sfx("body_fall" if inf else "expl_large", pos, -4.0 if inf else -2.0)
			if inf:
				vfx.impact(pos + Vector3(0, 0.2, 0), 0.4)
			else:
				vfx.explosion(pos, 0.9)
				vfx.wreck(pos, 18.0, 0.45)   # M3.2: scorch + tall burning-wreck smoke column
		else:
			vfx.building_destroyed(pos, v.footprint if v != null else Vector2(3, 3))
			AudioDirector.sfx("collapse", pos)
			AudioDirector.sfx("expl_large", pos, 0.0, 0.1)
	_forget_view(id)
	if v == null:
		return
	if not seen and (ev["kind"] == SimEntity.Kind.BUILDING) and local_team >= 0 and sim.fog.memory.get(local_team, {}).has(id):
		ghosts[id] = v      # player still remembers it until they look again
		v.set_overlay(fog_overlay)
	else:
		# M2.2 views can play a death (squad falls, vehicle wreck, building rubble) and free
		# themselves after it; everything else disappears at once as before
		if seen and not ev.get("silent", false) and v.has_method("play_death"):
			var linger: float = v.play_death()
			if linger > 0.0:
				get_tree().create_timer(linger, false).timeout.connect(v.queue_free)
				return
		v.queue_free()

func _forget_view(id: int) -> void:
	if shield_domes.has(id):
		shield_domes[id].queue_free()
		shield_domes.erase(id)
	if rigs.has(id):
		rigs[id].finish()   # the scaffold goes down with the site
		rigs.erase(id)
	if rings.has(id):
		rings[id].queue_free()
		rings.erase(id)
	views.erase(id)
	air_alt.erase(id)
	if air_shadows.has(id):
		air_shadows[id].queue_free()
		air_shadows.erase(id)
	fx_acc.erase(id)
	prev.erase(id)
	cur.erase(id)

## ---------------------------------------------------------------- M2.8 aircraft crashes
## M2.9: tell the tower material which visible units are near the screen centre (nearest 24).
func _update_tower_fade() -> void:
	var camn := get_viewport().get_camera_3d()
	if camn == null:
		return
	var fwd := -camn.global_transform.basis.z
	var c := camn.global_position
	var focus := c + fwd * (-c.y / minf(-0.05, fwd.y))
	var best: Array = []
	for id in views:
		var v: EntityView = views[id]
		if not v.visible or not cur.has(id):
			continue
		var e: SimEntity = sim.ents.get(id)
		if e == null or e.kind != SimEntity.Kind.UNIT:
			continue
		var p: Vector3 = cur[id]
		var d := Vector2(p.x - focus.x, p.z - focus.z).length_squared()
		if d < 1600.0:
			best.append([d, p])
	best.sort_custom(func(x, y): return x[0] < y[0])
	var pts := PackedVector4Array()
	for i in mini(24, best.size()):
		var p: Vector3 = best[i][1]
		pts.append(Vector4(p.x, p.y + 0.4, p.z, 0.0))
	terrain.set_occluded_units(pts)

var crashes: Array = []     ## [{v, vel, spin, heli, acc, t, down}]
static var _burnt: StandardMaterial3D

func _start_crash(v: Node3D, ud: UnitDef) -> void:
	var heli := ud.tags.has("helicopter")
	var yaw := v.rotation.y
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var spd := 1.2 if heli else 7.0
	crashes.append({"v": v, "vel": fwd * spd + Vector3(0, -0.5, 0), "spin": (6.0 if heli else 1.6) * (1.0 if v.get_instance_id() % 2 == 0 else -1.0),
		"heli": heli, "acc": 0.0, "t": 0.0, "down": false})

func _update_crashes(delta: float) -> void:
	if crashes.is_empty():
		return
	var keep: Array = []
	for c: Dictionary in crashes:
		var v: Node3D = c["v"]
		if not is_instance_valid(v):
			continue
		c["t"] += delta
		if not c["down"]:
			var vel: Vector3 = c["vel"]
			vel.y -= (6.0 if c["heli"] else 4.0) * delta
			vel.x *= 1.0 - 0.25 * delta
			vel.z *= 1.0 - 0.25 * delta
			c["vel"] = vel
			v.position += vel * delta
			if c["heli"]:
				v.rotation.y += c["spin"] * delta                     # tail-rotor-loss spin
				v.rotation.z = lerpf(v.rotation.z, 0.35, delta * 2.0)
			else:
				v.rotation.z += c["spin"] * delta                     # roll
				v.rotation.x = lerpf(v.rotation.x, 0.6, delta * 1.5)  # nose drops
			c["acc"] += delta
			if c["acc"] > 0.05:
				c["acc"] = 0.0
				vfx.smoke_puff(v.position, 0.55, true)
			var ground := 0.05
			if v.position.y <= ground:
				c["down"] = true
				v.position.y = ground
				v.rotation.x = 0.12
				v.rotation.z = 0.25
				vfx.explosion(v.position, 1.4)
				vfx.dust(v.position, 2.0, 0.9)
				vfx.wreck(v.position, 20.0, 0.55)
				AudioDirector.sfx("expl_large", v.position, 0.0)
				if _burnt == null:
					_burnt = StandardMaterial3D.new()
					_burnt.albedo_color = Color(0.09, 0.08, 0.075)
					_burnt.roughness = 1.0
				if v.has_method("set_overlay"):
					v.set_overlay(_burnt)
				v.scale *= Vector3(1.0, 0.7, 1.0)                     # crumpled
				c["t"] = 0.0
		elif c["t"] > 9.0:
			v.queue_free()
			continue
		keep.append(c)
	crashes = keep

## Called every rendered frame.
func frame(a: float, delta: float) -> void:
	_update_stacks(delta)
	alpha = a
	_update_crashes(delta)
	if terrain.has_towers:
		_update_tower_fade()
	var mem: Dictionary = sim.fog.memory.get(local_team, {}) if local_team >= 0 else {}
	for id in views:
		var e: SimEntity = sim.ents.get(id)
		var v: EntityView = views[id]
		if e == null:
			continue
		var vis := _is_visible(e, mem)
		if e.kind == SimEntity.Kind.UNIT:
			v.visible = vis and not icon_mode
			if not vis:
				if shield_domes.has(id):
					shield_domes[id].visible = false
				if air_shadows.has(id):
					air_shadows[id].visible = false
				continue
			var p: Vector3 = (prev.get(id, Vector3.ZERO) as Vector3).lerp(cur.get(id, Vector3.ZERO), a)
			var ud: UnitDef = Content.unit(e.def_id)
			if ud.move_layer == &"air":
				p = _air_view(id, e, ud, v, p, delta)
			var man := _barricade_slot(e) if e.res_id < 0 else []
			if not man.is_empty():
				p = man[0]
			if v is InfantryView:
				(v as InfantryView).set_braced(not man.is_empty())
			v.position = p
			# M2.5 sniper stealth: own (or spectated) hidden units draw translucent
			v.set_ghosted(e.stealthy and (e.team == local_team or local_team < 0))
			var want := atan2(float(e.dir.x), float(e.dir.y))
			if not man.is_empty():
				want = man[1]
			var y0: float = yaw.get(id, want)
			var ny := lerp_angle(y0, want, minf(1.0, delta * 8.0))
			yaw[id] = ny
			v.rotation.y = ny
			if v.has_method("set_health"):
				v.set_health(float(e.hp) / float(maxi(1, e.max_hp)))
			if v.turret != null and Content.unit(e.def_id).turret_dps > 0:
				# M2.3: the sim owns turret traverse (units only fire once aimed)
				var tang := float(e.tface) * TAU / float(FX.ANG) - ny
				v.turret.rotation.y = lerp_angle(v.turret.rotation.y, tang, minf(1.0, delta * 12.0))
			elif v.turret != null and ud.tags.has("spg"):
				v.turret.rotation.y = 0.0   # M3.3: self-propelled howitzers have a fixed turret; the hull aims
			elif v.turret != null:
				var tgt := sim.get_ent(e.target)
				if tgt != null and sim.tick - e.firing_tick < 40:
					var tp := FX.to_world(tgt.pos)
					var ang := atan2(tp.x - p.x, tp.z - p.z) - ny
					v.turret.rotation.y = lerp_angle(v.turret.rotation.y, ang, minf(1.0, delta * 10.0))
				else:
					v.turret.rotation.y = lerp_angle(v.turret.rotation.y, 0.0, minf(1.0, delta * 3.0))
			# M3.3: builders animate (blade / backhoe arm / crane boom) while they work at a site
			if v is VehicleView and not (v as VehicleView).work_parts.is_empty():
				(v as VehicleView).working = _builder_working(e)
			# dust behind moving vehicles (M3.3: drones leave no trail; helicopters and jets keep theirs)
			if not v is InfantryView and not icon_mode and not ud.tags.has("drone"):
				var spd: float = p.distance_to(v.get_meta("lastp", p)) / maxf(delta, 0.001)
				v.set_meta("lastp", p)
				var acc: float = fx_acc.get(id, 0.0) + delta
				if spd > 0.6 and acc > 0.14:
					acc = 0.0
					vfx.dust(p - Vector3(sin(ny), 0, cos(ny)) * 0.5, 0.45, 0.45)
				fx_acc[id] = acc
			# M3.2: persistent tread / tyre marks behind ground vehicles (fade over ~80 s)
			if ud.move_layer == &"vehicle" and not icon_mode:
				var lt: Vector3 = v.get_meta("trackp", p)
				var dd := Vector2(p.x - lt.x, p.z - lt.z).length()
				if dd > 0.3:
					if dd < 1.2:
						var w := clampf(float(ud.radius_mt) / 1000.0 * 1.25, 0.3, 0.9)
						vfx.track((p + lt) * 0.5, ny, w, dd + 0.04, 1.0 if w > 0.45 else 0.6)
					v.set_meta("trackp", p)
				elif not v.has_meta("trackp"):
					v.set_meta("trackp", p)
			if shield_domes.has(id):
				var dome: MeshInstance3D = shield_domes[id]
				dome.visible = not icon_mode
				dome.position = p
		else:
			var show_mem := not vis and mem.has(id)
			v.visible = (vis or show_mem) and not (icon_mode and e.kind == SimEntity.Kind.UNIT)
			if e.kind == SimEntity.Kind.BUILDING:
				v.set_ghosted(e.stealthy and (e.team == local_team or local_team < 0))
				var bk := 1.0 if e.built else float(e.progress) / float(maxi(1, e.build_ticks))
				# M2.4: under construction = construction site (scaffold, rising structure), never
				# damage; damage visuals use HP relative to what the scaffold has reached so far
				var rig: ConstructionRig = rigs.get(id)
				if not e.built and rig == null:
					rig = ConstructionRig.new()
					v.add_child(rig)
					rig.setup(v, StringName(_faction_of(e)))
					rigs[id] = rig
				elif e.built and rig != null:
					rig.finish()
					rigs.erase(id)
					rig = null
				var hpk := build_relative_health(e)
				if v.has_method("set_build_progress"):
					v.set_build_progress(bk)
					v.set_damage(hpk, not e.built)
				if rig != null:
					rig.update(bk, delta, vfx, vis and not icon_mode)
				if vis and not icon_mode:
					var acc2: float = fx_acc.get(id, 0.0) + delta
					if rig != null and rig.working() and acc2 > 0.35:
						acc2 = 0.0   # construction dust around the footprint while a builder works
						var r := v.footprint * 0.5
						vfx.dust(v.position + Vector3(randf_range(-r.x, r.x), 0, randf_range(-r.y, r.y)), 0.6, 0.4)
					elif e.built and hpk < 0.5 and acc2 > (0.22 if hpk < 0.25 else 0.4):
						acc2 = 0.0   # damaged: smoke column, on fire below 25 %
						vfx.smoke_puff(v.position + Vector3(randf_range(-0.6, 0.6), v.bar_height * 0.6, randf_range(-0.6, 0.6)), 0.5 if hpk < 0.25 else 0.3, hpk < 0.25)
					elif not e.built and hpk < 0.5 and acc2 > 0.6:
						acc2 = 0.0   # a site that took real fire: a thin smoke wisp, never flames
						vfx.smoke_puff(v.position + Vector3(randf_range(-0.4, 0.4), v.bar_height * 0.4, randf_range(-0.4, 0.4)), 0.15, false)
					fx_acc[id] = acc2
				if v.turret != null:
					# M2.8: defence turrets traverse smoothly onto (and follow) their target, and
					# swing back to rest after a few seconds without one, instead of snapping / freezing
					var t2 := sim.get_ent(e.target) if e.target != 0 else null
					if t2 != null and t2.alive:
						var tp2 := FX.to_world(t2.pos)
						var ta := atan2(tp2.x - v.position.x, tp2.z - v.position.z) - v.rotation.y
						v.turret.rotation.y = lerp_angle(v.turret.rotation.y, ta, minf(1.0, delta * 9.0))
					elif sim.tick - e.firing_tick > 80:
						v.turret.rotation.y = lerp_angle(v.turret.rotation.y, 0.0, minf(1.0, delta * 2.0))
			if v.get_meta("fogged", false) != show_mem:
				v.set_meta("fogged", show_mem)
				v.set_overlay(fog_overlay if show_mem else null)
	# remembered ghosts disappear once the area is looked at again
	for gid in ghosts.keys():
		if not mem.has(gid):
			ghosts[gid].queue_free()
			ghosts.erase(gid)
	_update_rings()

func _is_visible(e: SimEntity, _mem: Dictionary) -> bool:
	if local_team < 0:
		return true
	if e.kind == SimEntity.Kind.UNIT:
		if e.res_id < 0:
			# M3.3 item 10: troops manning a barricade stand behind it in plain view
			var host := sim.get_ent(-e.res_id)
			if host == null or host.kind != SimEntity.Kind.BUILDING or not CommandSys.is_barricade(sim, host):
				return false
			return host.team == local_team or sim.fog.is_visible_ent(sim, local_team, host)
		return e.team == local_team or sim.fog.is_visible_ent(sim, local_team, e)
	if e.team == local_team:
		return true
	if e.kind == SimEntity.Kind.RESOURCE or (e.kind == SimEntity.Kind.NEUTRAL and e.owner < 0):
		return sim.fog.explored_tile(local_team, FX.to_tile(e.pos)) or sim.fog.explored_tile(local_team, e.tile)
	return sim.fog.is_visible_ent(sim, local_team, e)

func set_selection(ids: Array) -> void:
	selected = ids.duplicate()
	for id in rings.keys():
		if not (id in selected):
			rings[id].queue_free()
			rings.erase(id)

func _update_rings() -> void:
	for id in selected:
		var e := sim.get_ent(id)
		var v: EntityView = views.get(id)
		if e == null or v == null:
			continue
		var ring: MeshInstance3D = rings.get(id)
		if ring == null:
			ring = MeshInstance3D.new()
			ring.mesh = ring_meshes[team_shape_index(e.team)]
			ring.material_override = Palette.flat(Palette.color(sim.players[e.owner].color if e.owner >= 0 else -1).lightened(0.25))
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ring)
			rings[id] = ring
		ring.visible = v.visible
		var r := v.selection_radius * (INF_SCALE if (e.kind == SimEntity.Kind.UNIT and Content.unit(e.def_id).tags.has("infantry")) else 1.0) + 0.15
		ring.position = v.position + Vector3(0, 0.05, 0)
		ring.scale = Vector3(r, 1, r)

func marker(p: Vector2i, col: Color) -> void:
	vfx.ring(FX.to_world(p), 0.9, col, 0.5, true)

# ---------------------------------------------------------------- placement ghost
var ghost_root: Node3D
var ghost_model: EntityView
var ghost_def: StringName = &""
var ghost_pad: MeshInstance3D
var ghost_rings: Array = []
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var ghost_overlay_ok: StandardMaterial3D
var ghost_overlay_bad: StandardMaterial3D

func show_ghost(def_id: StringName, tile: Vector2i, rot: int, ok: bool, pid: int) -> void:
	if ghost_root == null:
		ghost_root = Node3D.new()
		add_child(ghost_root)
		ghost_pad = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		ghost_pad.mesh = pm
		ghost_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost_root.add_child(ghost_pad)
		ghost_ok_mat = Palette.flat(Color(0.3, 1.0, 0.45), 0.45)
		ghost_bad_mat = Palette.flat(Color(1.0, 0.25, 0.2), 0.5)
		ghost_overlay_ok = Palette.flat(Color(0.4, 1.0, 0.5), 0.35)
		ghost_overlay_bad = Palette.flat(Color(1.0, 0.3, 0.25), 0.45)
	ghost_root.visible = true
	var d: BuildingDef = Content.building(def_id)
	var fpv := d.footprint if rot % 2 == 0 else Vector2i(d.footprint.y, d.footprint.x)
	if ghost_def != def_id:
		ghost_def = def_id
		if ghost_model != null:
			ghost_model.queue_free()
		ghost_model = (load(d.view_scene) as PackedScene).instantiate()
		ghost_root.add_child(ghost_model)
		ghost_model.set_team_material(Palette.team_material(sim.players[pid].color))
		_rebuild_grid_rings(pid, d)
	var center := Vector3(tile.x + fpv.x * 0.5, 0.0, tile.y + fpv.y * 0.5)
	ghost_pad.position = center + Vector3(0, 0.07, 0)
	ghost_pad.scale = Vector3(fpv.x, 1, fpv.y)
	ghost_pad.material_override = ghost_ok_mat if ok else ghost_bad_mat
	ghost_model.position = center
	ghost_model.rotation.y = [0.0, PI * 0.5, PI, -PI * 0.5][rot]
	ghost_model.set_overlay(ghost_overlay_ok if ok else ghost_overlay_bad)

func _rebuild_grid_rings(pid: int, d: BuildingDef) -> void:
	for r in ghost_rings:
		r.queue_free()
	ghost_rings.clear()
	if d.power >= 0 and d.grid_radius > 0 and not d.is_hq:
		pass
	for id in sim.ids:
		var e: SimEntity = sim.ents[id]
		if e.owner != pid or e.kind != SimEntity.Kind.BUILDING:
			continue
		var bd := Content.building(e.def_id)
		if bd.grid_radius <= 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = Palette.ring_mesh("circle", 0.03)
		mi.material_override = Palette.flat(Color("#6fe3ff"), 0.7)
		mi.position = FX.to_world(e.pos) + Vector3(0, 0.08, 0)
		mi.scale = Vector3.ONE * float(bd.grid_radius)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost_root.add_child(mi)
		ghost_rings.append(mi)

func hide_ghost() -> void:
	if ghost_root != null:
		ghost_root.visible = false
		ghost_def = &""
		if ghost_model != null:
			ghost_model.queue_free()
			ghost_model = null
		for r in ghost_rings:
			r.queue_free()
		ghost_rings.clear()

# ---------------------------------------------------------------- rally flags
var rally_flag: Node3D
var rally_line: MeshInstance3D

func update_rally(b: SimEntity) -> void:
	if rally_flag == null:
		rally_flag = Node3D.new()
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 1.4
		pole.mesh = cm
		pole.position.y = 0.7
		pole.material_override = Palette.flat(Color("#ffd166"))
		rally_flag.add_child(pole)
		var fl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.3, 0.04)
		fl.mesh = bm
		fl.position = Vector3(0.27, 1.25, 0)
		fl.material_override = Palette.flat(Color("#ffd166"))
		rally_flag.add_child(fl)
		add_child(rally_flag)
		rally_line = MeshInstance3D.new()
		rally_line.mesh = BoxMesh.new()
		rally_line.material_override = Palette.flat(Color("#ffd166"), 0.6)
		rally_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rally_line)
	var show := b != null and b.rally.x >= 0
	rally_flag.visible = show
	rally_line.visible = show
	if not show:
		return
	var a := FX.to_world(b.pos) + Vector3(0, 0.1, 0)
	var t := FX.to_world(b.rally) + Vector3(0, 0.1, 0)
	rally_flag.position = t - Vector3(0, 0.1, 0)
	var len := a.distance_to(t)
	if len > 0.1:
		rally_line.transform = Transform3D(Basis.looking_at(t - a, Vector3.UP), (a + t) * 0.5).scaled_local(Vector3(0.06, 0.02, len))
