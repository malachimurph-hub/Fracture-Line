class_name WorldView
extends Node3D
## Rendering only: builds views from the simulation, interpolates 20 Hz sim positions for
## smooth 60+ fps rendering, applies fog visibility, and plays view-only effects.

const VFX_COLORS := {"tracer": Color("#fff2b0"), "tracer_heavy": Color("#ffd166"), "missile": Color("#ff9b54"),
	"shell": Color("#ffe08a"), "grenade": Color("#c9e86b"), "flak": Color("#f7f7f7")}

var runner: MatchRunner
var sim: SimWorld
var local_pid: int = 0
var local_team: int = 0
var terrain: TerrainView
var vfx: Vfx
var views: Dictionary = {}       ## id -> EntityView
var ghosts: Dictionary = {}      ## dead buildings remembered in fog: id -> EntityView
var prev: Dictionary = {}        ## id -> Vector3
var cur: Dictionary = {}         ## id -> Vector3
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
	return Content.building(e.def_id).view_scene

func _ensure_view(e: SimEntity) -> EntityView:
	if views.has(e.id):
		return views[e.id]
	var ps: PackedScene = load(_scene_for(e))
	var v: EntityView = ps.instantiate()
	add_child(v)
	v.set_team_material(Palette.team_material(sim.players[e.owner].color if e.owner >= 0 else -1))
	v.position = _world_pos(e)
	if e.kind == SimEntity.Kind.BUILDING or e.kind == SimEntity.Kind.NEUTRAL:
		v.rotation.y = -e.rot * PI * 0.5 + (PI if e.rot == 0 else 0.0) * 0.0
		v.rotation.y = [0.0, PI * 0.5, PI, -PI * 0.5][e.rot]
	elif e.kind == SimEntity.Kind.UNIT:
		var d: UnitDef = Content.unit(e.def_id)
		if d.tags.has("infantry"):
			v.scale = Vector3.ONE * 1.4
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
			"spawn", "site":
				var e := sim.get_ent(int(ev["id"]))
				if e != null:
					_ensure_view(e)
					cur[e.id] = _world_pos(e)
					prev[e.id] = cur[e.id]
			"death":
				_on_death(ev)
			"fire":
				_on_fire(ev)
			"captured":
				var c := sim.get_ent(int(ev["id"]))
				if c != null and views.has(c.id):
					views[c.id].set_team_material(Palette.team_material(sim.players[c.owner].color))
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
	var from: Vector3 = (cur.get(src.id, _world_pos(src)) as Vector3)
	var to := FX.to_world(ev["to"])
	if not _visible_pos(src.pos) and not _visible_pos(ev["to"]):
		return
	var v: EntityView = views.get(src.id)
	if src.res_id < 0:
		var b := sim.get_ent(-src.res_id)
		if b != null:
			from = FX.to_world(b.pos) + Vector3(0, 1.2, 0)
			v = null
	else:
		from.y += 0.5 if src.kind == SimEntity.Kind.UNIT else 0.9
	to.y += 0.4
	var kind: String = String(ev["vfx"])
	var col: Color = VFX_COLORS.get(kind, Color.WHITE)
	match kind:
		"shell":
			vfx.tracer(from, to, col, 0.09, 0.12)
			vfx.flash(from, Color("#ffe6a0"), 0.35, 0.08)
			vfx.flash(to, Color("#ff9d4a"), 0.6, 0.2)
		"missile":
			vfx.tracer(from, to, col, 0.07, 0.25)
			vfx.flash(to, Color("#ff7a2a"), 0.5, 0.25)
		"grenade":
			vfx.tracer(from + Vector3(0, 0.4, 0), to, col, 0.05, 0.2)
			vfx.flash(to, Color("#c9e86b"), 0.8, 0.25)
		"flak":
			vfx.tracer(from, to, col, 0.04, 0.08)
			vfx.flash(to, Color("#eeeeee"), 0.45, 0.15)
		_:
			vfx.tracer(from, to, col, 0.035 if kind == "tracer" else 0.05, 0.07)

func _on_death(ev: Dictionary) -> void:
	var id := int(ev["id"])
	var v: EntityView = views.get(id)
	var pos := FX.to_world(ev["pos"])
	var seen := _visible_pos(ev["pos"]) or int(ev.get("owner", -1)) >= 0 and sim.player_team(int(ev["owner"])) == local_team
	if seen and not ev.get("silent", false):
		var big: bool = ev["kind"] != SimEntity.Kind.UNIT
		vfx.explosion(pos, 1.8 if big else 0.7)
	if shield_domes.has(id):
		shield_domes[id].queue_free()
		shield_domes.erase(id)
	if rings.has(id):
		rings[id].queue_free()
		rings.erase(id)
	views.erase(id)
	prev.erase(id)
	cur.erase(id)
	if v == null:
		return
	if not seen and (ev["kind"] == SimEntity.Kind.BUILDING) and local_team >= 0 and sim.fog.memory.get(local_team, {}).has(id):
		ghosts[id] = v      # player still remembers it until they look again
		v.set_overlay(fog_overlay)
	else:
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
			if v.turret != null:
				var tgt := sim.get_ent(e.target)
				if tgt != null and sim.tick - e.firing_tick < 40:
					var tp := FX.to_world(tgt.pos)
					var ang := atan2(tp.x - p.x, tp.z - p.z) - ny
					v.turret.rotation.y = lerp_angle(v.turret.rotation.y, ang, minf(1.0, delta * 10.0))
				else:
					v.turret.rotation.y = lerp_angle(v.turret.rotation.y, 0.0, minf(1.0, delta * 3.0))
			if shield_domes.has(id):
				var dome: MeshInstance3D = shield_domes[id]
				dome.visible = not icon_mode
				dome.position = p
		else:
			var show_mem := not vis and mem.has(id)
			v.visible = (vis or show_mem) and not (icon_mode and e.kind == SimEntity.Kind.UNIT)
			if e.kind == SimEntity.Kind.BUILDING:
				var k := 1.0 if e.built else 0.15 + 0.85 * float(e.progress) / float(maxi(1, e.build_ticks))
				if v.model:
					v.model.scale.y = k
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
