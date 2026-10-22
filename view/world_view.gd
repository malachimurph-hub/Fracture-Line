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
var unit_scale: float = 1.0      ## readability scale; infantry squads render ~1.4x (GDD 14.2)
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
	terrain.build(sim.map, Content.maps[sim.map_id].tiles_path)
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
	Weathering.apply(v, &"tpla" if did.begins_with("tpla_") else (&"eu" if did.begins_with("eu_") else &"neutral"))
	v.position = _world_pos(e)
	if e.kind == SimEntity.Kind.BUILDING or e.kind == SimEntity.Kind.NEUTRAL:
		v.rotation.y = [0.0, PI * 0.5, PI, -PI * 0.5][e.rot]
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
			v.scale = Vector3.ONE * 1.4
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
	if seen and not ev.get("silent", false):
		if ev["kind"] == SimEntity.Kind.UNIT:
			var inf := v != null and v.scale.x > 1.2
			AudioDirector.sfx("body_fall" if inf else "expl_large", pos, -4.0 if inf else -2.0)
			if inf:
				vfx.impact(pos + Vector3(0, 0.2, 0), 0.4)
			else:
				vfx.explosion(pos, 0.9)
				vfx.sources.append([pos, 5.0, 0.4, 0.0])   # burning wreck
		else:
			vfx.building_destroyed(pos, v.footprint if v != null else Vector2(3, 3))
			AudioDirector.sfx("collapse", pos)
			AudioDirector.sfx("expl_large", pos, 0.0, 0.1)
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
	fx_acc.erase(id)
	prev.erase(id)
	cur.erase(id)
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

## Called every rendered frame.
func frame(a: float, delta: float) -> void:
	alpha = a
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
				continue
			var p: Vector3 = (prev.get(id, Vector3.ZERO) as Vector3).lerp(cur.get(id, Vector3.ZERO), a)
			v.position = p
			var want := atan2(float(e.dir.x), float(e.dir.y))
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
			elif v.turret != null:
				var tgt := sim.get_ent(e.target)
				if tgt != null and sim.tick - e.firing_tick < 40:
					var tp := FX.to_world(tgt.pos)
					var ang := atan2(tp.x - p.x, tp.z - p.z) - ny
					v.turret.rotation.y = lerp_angle(v.turret.rotation.y, ang, minf(1.0, delta * 10.0))
				else:
					v.turret.rotation.y = lerp_angle(v.turret.rotation.y, 0.0, minf(1.0, delta * 3.0))
			# dust behind moving vehicles
			if v.scale.x < 1.2 and not icon_mode:
				var spd: float = p.distance_to(v.get_meta("lastp", p)) / maxf(delta, 0.001)
				v.set_meta("lastp", p)
				var acc: float = fx_acc.get(id, 0.0) + delta
				if spd > 0.6 and acc > 0.14:
					acc = 0.0
					vfx.dust(p - Vector3(sin(ny), 0, cos(ny)) * 0.5, 0.45, 0.45)
				fx_acc[id] = acc
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
				if v.turret != null and e.target != 0:
					var t2 := sim.get_ent(e.target)
					if t2 != null:
						var tp2 := FX.to_world(t2.pos)
						v.turret.rotation.y = atan2(tp2.x - v.position.x, tp2.z - v.position.z) - v.rotation.y
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
			return false
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
		var r := v.selection_radius * (1.4 if (e.kind == SimEntity.Kind.UNIT and Content.unit(e.def_id).tags.has("infantry")) else 1.0) + 0.15
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
