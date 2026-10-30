class_name MenuBattle
extends Node3D
## M3.4 (Malachi: bring back a live battle behind the main menu): a scripted background battle
## in a SubViewport behind the menu. Real SimWorld / WorldView / models / weapons / VFX, but its
## own throw-away sim (never saves, replays or touches a match). Two sides from different
## factions trade capped waves of tanks, self-propelled guns, IFVs, helicopters and jets in front
## of two small bases (burning wrecks, smoke and explosions come from the normal views). A
## director cycles CLIPS: wide, high cinematic shots with slow pans (along the front, orbit over
## the clash, crane over a base toward the fight, high diagonal fly-over). Every CLIPS_PER_MAP
## clips it fades to the key-art image, builds the next battlefield (day and night maps
## alternate; night uses the normal night lighting: headlights, floodlights, lamps, muzzle
## flashes) and fades back in.
## Phone budget (Galaxy S24 Ultra class): 3D at 67 % resolution, no shadows, 30 FPS cap while the
## menu is up, at most MAX_SIDE units a side, the sim at 20 Hz with at most 2 steps a frame. The
## menu checks the frame rate (menu_main.gd) and drops back to the static key art if it falls.
## Previous version: M2.6-M3.0.1 (removed in M3.1). Differences: high wide framing instead of
## close shots, clips with night maps, aircraft, the unit cap, the frame-rate fallback.

## Tests / shots: pin the first map and clip; empty = automatic.
static var force_map: StringName = &""
static var force_clip := -1
const DT := 0.05
const WAVE := 8               ## units per side per wave
const MAX_SIDE := 16          ## alive units per side (cap)
const REFILL_BELOW := 9
const CLIP_SECONDS := 16.0
const CLIPS_PER_MAP := 3
const FX_MUL := 0.7
const BASE_BACK := 9.0
const HOT_SECONDS := 3.0
const NIGHT_MAPS := [&"riverside_metro_night", &"varno_crossing_night"]
const DAY_MAPS := [&"ochre_wells", &"harvest_valley", &"sunfall_basin", &"varno_crossing", &"twin_ridges", &"kessel_pass"]
## Clip kinds: 0 high pan along the front, 1 high slow orbit over the clash, 2 crane over a base
## toward the fight, 3 high diagonal fly-over.
const CLIP_KINDS := 4

signal battle_ready
signal wants_rebuild           ## the menu fades out, then calls next_map()

var runner: MatchRunner
var world: WorldView
var cam: Camera3D
var night := false
var clip := 0
var clips_on_map := 0
var shots_seen := 0
var building := false
var _acc := 0.0
var _t := 0.0
var _clip_t := 0.0
var _rng := RandomNumberGenerator.new()
var _facs: Array = []
var _pools := {}
var _front: Array = []
var _dir3 := Vector3.RIGHT
var _bases: Array = [Vector3.ZERO, Vector3.ZERO]
var _airfields: Array = [null, null]
var _env_nodes: Array = []
var _clash := Vector3.ZERO
var _hot: Array = []
var _eye := Vector3.ZERO
var _at := Vector3.ZERO
var _cut := true
var _map_i := 0

func _ready() -> void:
	_rng.randomize()
	night = false
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		await build_battle()

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"fl_night", 0.0)
	RenderingServer.global_shader_parameter_set(&"fl_fill", Vector4.ZERO)

## Next map (the other of day / night), built over several frames.
func next_map() -> void:
	night = not night
	await build_battle()

func _step() -> bool:
	await get_tree().process_frame
	return is_inside_tree()

func pick_map() -> StringName:
	if force_map != &"" and Content.maps.has(force_map):
		var f := force_map
		force_map = &""
		night = f in NIGHT_MAPS
		return f
	var pool: Array = []
	for m in (NIGHT_MAPS if night else DAY_MAPS):
		if Content.maps.has(m):
			pool.append(m)
	if pool.is_empty():
		for k in Content.maps:
			if not (Content.maps[k] as MapDef).custom:
				pool.append(k)
	_map_i += 1
	return pool[(_rng.randi() + _map_i) % pool.size()]

## Ground and air units a faction can field here: no builders, harvesters, stubs, suicide
## units or infantry (they read as specks from the high camera).
static func roster_pool(fac: StringName, air: bool) -> Array:
	var out: Array = []
	for id in Content.units:
		var d: UnitDef = Content.units[id]
		if d.faction != fac or d.max_hp <= 0 or d.view_scene == "":
			continue
		var bad := false
		for tg in ["builder", "harvester", "stub", "suicide", "drone", "transport", "infantry", "shield"]:
			if d.tags.has(tg):
				bad = true
		if bad or d.move_layer == &"foot":
			continue
		if (d.move_layer == &"air") == air:
			out.append(id)
	out.sort()
	return out

func build_battle() -> void:
	building = true
	for n in _env_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_env_nodes.clear()
	if world != null:
		world.queue_free()
		world = null
	if cam != null:
		cam.queue_free()
		cam = null
	runner = null
	if not await _step():
		return
	var mid := pick_map()
	var facs: Array = Content.playable_factions()
	facs.shuffle()
	_facs = [facs[0], facs[1]]
	var cfg := SkirmishConfig.default_setup()
	cfg["seed"] = _rng.randi_range(1, 999999)
	cfg["map"] = String(mid)
	for i in 4:
		cfg["slots"][i]["kind"] = "closed"
	for i in 2:
		cfg["slots"][i]["kind"] = "ai"
		cfg["slots"][i]["faction"] = String(_facs[i])
		cfg["slots"][i]["team"] = i
	cfg["options"]["fog"] = false
	runner = MatchRunner.new()
	runner.record_replay = false
	runner.start(SkirmishConfig.resolve(cfg))
	runner.ais.clear()
	for p in runner.sim.players:
		p.supply = 0
	if not await _step():
		return
	_build_view()
	if not await _step():
		return
	var hq: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	for id in runner.sim.ids:
		var e: SimEntity = runner.sim.ents[id]
		if e.kind == SimEntity.Kind.BUILDING and e.owner >= 0 and e.owner < 2:
			hq[e.owner] = Vector2(e.tile)
	var c := Vector2(runner.sim.map.w, runner.sim.map.h) * 0.5
	var dir: Vector2 = (hq[1] - hq[0]).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_front = [c - dir * 7.0, c + dir * 7.0]
	_dir3 = Vector3(dir.x, 0, dir.y)
	for pid in 2:
		var side := -1.0 if pid == 0 else 1.0
		var bc: Vector2 = c + dir * side * (7.0 + BASE_BACK)
		bc = bc.clamp(Vector2(9, 9), Vector2(runner.sim.map.w - 9, runner.sim.map.h - 9))
		_bases[pid] = Vector3(bc.x, 0, bc.y)
		_lay_base(pid, bc)
		if not await _step():
			return
	_pools = {0: [], 1: []}
	for pid in 2:
		_wave(pid)
		_air_wave(pid)
		if not await _step():
			return
	# let the fight start before it is shown
	for i in 60:
		runner.advance()
		world.on_tick(runner.sim.events.duplicate())
	_clash = Vector3(c.x, 0, c.y)
	_hot.clear()
	clip = force_clip if force_clip >= 0 else _rng.randi() % CLIP_KINDS
	force_clip = -1
	clips_on_map = 0
	_clip_t = 0.0
	_cut = true
	_place_cam(0.0, 1.0)
	building = false
	battle_ready.emit()

func _build_view() -> void:
	var menv := MapEnv.for_map(runner.sim.map_id)
	night = float(menv.get("night", 0.0)) > 0.0
	RenderingServer.global_shader_parameter_set(&"fl_night", float(menv.get("night", 0.0)))
	RenderingServer.global_shader_parameter_set(&"fl_fill", MapEnv.model_fill(menv))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b0c0e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = menv["ambient"]
	e.ambient_light_energy = menv["ambient_energy"]
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = menv["exposure"] * (1.25 if night else 1.0)   # night: the hulls read from up high
	e.tonemap_white = 6.0
	e.fog_enabled = true
	e.fog_light_color = menv["fog_col"]
	e.fog_light_energy = 0.9
	e.fog_density = menv["fog_density"]
	e.adjustment_enabled = true
	e.adjustment_saturation = menv["saturation"]
	e.adjustment_contrast = menv["contrast"]
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = menv["sun_rot"]
	sun.light_energy = menv["sun_energy"]
	sun.light_color = menv["sun_col"]
	sun.shadow_enabled = false       # phones: no shadow pass behind the menu
	add_child(sun)
	_env_nodes = [env, sun]
	world = WorldView.new()
	add_child(world)
	world.setup(runner, -1)
	world.vfx.fx_mul = FX_MUL
	cam = Camera3D.new()
	cam.fov = 44.0
	cam.near = 0.5
	cam.far = 300.0
	add_child(cam)
	cam.current = true

## A small base per side: its biggest unarmed structures (and an airfield when it fits, for the
## jets), complete and sturdy (10x hp) so they stay standing as set dressing.
func _lay_base(pid: int, at: Vector2) -> void:
	var defs: Array = []
	var air: BuildingDef = null
	for id in Content.buildings:
		var d: BuildingDef = Content.buildings[id]
		if d.faction != _facs[pid] or d.tags.has("trap") or d.tags.has("hole"):
			continue
		if d.air_slots > 0:
			air = d
		elif d.weapons.is_empty() and d.footprint.x >= 2 and d.footprint.y >= 2 and d.footprint.x <= 4:
			defs.append(d)
	defs.sort_custom(func(a: BuildingDef, b: BuildingDef) -> bool:
		var ka := a.footprint.x * a.footprint.y
		var kb := b.footprint.x * b.footprint.y
		return ka > kb if ka != kb else String(a.id) < String(b.id))
	var sum := Vector3.ZERO
	var placed := 0
	_airfields[pid] = null
	if air != null:
		var away: Vector2 = (at - Vector2(runner.sim.map.w, runner.sim.map.h) * 0.5).normalized()
		var ta := _near_free(Vector2i((at + away * 6.0 - Vector2(air.footprint) * 0.5).round()), air.footprint, 6)
		if ta.x >= 0:
			var af := runner.sim._place_building(air, pid, ta, 0, true)
			af.max_hp *= 10
			af.hp = af.max_hp
			world._ensure_view(af)
			_airfields[pid] = af
	for d: BuildingDef in defs:
		if placed >= 5:
			break
		var t := _near_free(Vector2i((at - Vector2(d.footprint) * 0.5).round()), d.footprint, 9)
		if t.x >= 0:
			var e := runner.sim._place_building(d, pid, t, 0, true)
			e.max_hp *= 10
			e.hp = e.max_hp
			world._ensure_view(e)
			sum += FX.to_world(e.pos)
			placed += 1
	if placed > 0:
		_bases[pid] = sum / placed

func _near_free(t: Vector2i, fp: Vector2i, rmax: int = 7) -> Vector2i:
	for r in rmax + 1:
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if maxi(absi(xx), absi(yy)) == r and _free(t + Vector2i(xx, yy), fp):
					return t + Vector2i(xx, yy)
	return Vector2i(-1, -1)

func _free(t: Vector2i, fp: Vector2i) -> bool:
	var m := runner.sim.map
	for yy in range(-1, fp.y + 1):
		for xx in range(-1, fp.x + 1):
			var cc := Vector2i(t.x + xx, t.y + yy)
			if not m.in_bounds(cc) or cc.x < 2 or cc.y < 2 or cc.x >= m.w - 2 or cc.y >= m.h - 2:
				return false
			var i := m.idx(cc)
			if not SimMap.BUILD_OK[m.tiles[i]] or m.occ[i] != 0 or m.nobuild[i] != 0:
				return false
	return true

func _spawned(pid: int, u: SimEntity) -> void:
	_pools[pid].append(u.id)
	world._ensure_view(u)
	world.cur[u.id] = world._world_pos(u)
	world.prev[u.id] = world.cur[u.id]

func _wave(pid: int) -> void:
	var pool := roster_pool(_facs[pid], false)
	if pool.is_empty():
		return
	var room := MAX_SIDE - _alive(pid).size()
	var at: Vector2 = _front[pid]
	var to: Vector2 = _front[1 - pid]
	var ids: Array = []
	for i in mini(WAVE, room):
		var uid: StringName = pool[_rng.randi() % pool.size()]
		var off := Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5))
		var t := Vector2i((at + off - (to - at).normalized() * 3.0).round())
		t = t.clamp(Vector2i(2, 2), Vector2i(runner.sim.map.w - 3, runner.sim.map.h - 3))
		var u := runner.sim.spawn_unit(uid, pid, null, FX.tile_center(t))
		if u != null:
			ids.append(u.id)
			_spawned(pid, u)
	if not ids.is_empty():
		runner.issue({"p": pid, "t": "amove", "ids": ids, "pos": _push_target(pid)})

## One or two aircraft a side: helicopters anywhere, jets only from the side's airfield.
func _air_wave(pid: int) -> void:
	var pool := roster_pool(_facs[pid], true)
	var ids: Array = []
	for i in 2:
		if pool.is_empty() or _alive(pid).size() >= MAX_SIDE:
			break
		var uid: StringName = pool[_rng.randi() % pool.size()]
		var jet := Content.unit(uid).tags.has("jet")
		var af: SimEntity = _airfields[pid]
		if jet and (af == null or not af.alive or AirSys.slots_free(runner.sim, af) < Content.unit(uid).air_slots):
			continue
		var u := runner.sim.spawn_unit(uid, pid, af if jet else null, FX.tile_center(Vector2i(_front[pid].round())) if not jet else Vector2i(-1, -1))
		if u == null:
			continue
		if jet:
			u.air_home = af.id
		ids.append(u.id)
		_spawned(pid, u)
	if not ids.is_empty():
		runner.issue({"p": pid, "t": "amove", "ids": ids, "pos": FX.tile_center(Vector2i(_front[1 - pid].round()))})

func _push_target(pid: int) -> Vector2i:
	var b: Vector3 = _bases[1 - pid]
	var t := Vector2i(roundi(b.x), roundi(b.z))
	return FX.tile_center(t.clamp(Vector2i(2, 2), Vector2i(runner.sim.map.w - 3, runner.sim.map.h - 3)))

func _alive(pid: int) -> Array:
	var out: Array = []
	for id in _pools.get(pid, []):
		var e := runner.sim.get_ent(id)
		if e != null and e.alive:
			out.append(id)
	_pools[pid] = out
	return out

func unit_count() -> int:
	return _alive(0).size() + _alive(1).size()

## Wide, high cinematic framing of the clash (s = 0..1 through the clip).
func _place_cam(s: float, delta: float) -> void:
	var e := s * s * (3.0 - 2.0 * s) * 0.5 + s * 0.5
	var side := Vector3(-_dir3.z, 0, _dir3.x)
	var eye := Vector3.ZERO
	var at := _clash
	match clip:
		0:   # high, wide pan along the front line
			eye = _clash + side * 18.0 + _dir3 * lerpf(-9.0, 9.0, e) + Vector3(0, 13.5, 0)
			at = _clash + _dir3 * lerpf(-5.0, 5.0, e)
		1:   # slow high orbit
			var a := lerpf(-0.5, 0.5, e) + 0.9
			eye = _clash + (-_dir3).rotated(Vector3.UP, a) * 19.0 + Vector3(0, 14.0, 0)
		2:   # crane from behind a base over its buildings toward the fight
			var b: Vector3 = _bases[0]
			var toward := (_clash - b)
			toward.y = 0.0
			toward = toward.normalized() if toward.length() > 1.0 else _dir3
			eye = b - toward * lerpf(10.0, 4.0, e) + side * 8.0 + Vector3(0, lerpf(11.0, 14.0, e), 0)
			at = b.lerp(_clash, lerpf(0.6, 0.9, e))
		_:   # high diagonal fly-over across the battlefield
			eye = _clash - _dir3 * 16.0 + side * lerpf(-11.0, 11.0, e) + Vector3(0, 15.0, 0)
			at = _clash + side * lerpf(-4.0, 4.0, e)
	at.y = 0.5
	if _cut:
		_eye = eye
		_at = at
		_cut = false
	else:
		var k := minf(1.0, delta * 1.5)
		_eye = _eye.lerp(eye, k)
		_at = _at.lerp(at, k)
	cam.position = _eye
	cam.look_at(_at, Vector3.UP)
	# compose: the action left of centre (the buttons are on the right)
	pass   # (the clash sits in the open middle, between the emblem and the buttons)

func _process(delta: float) -> void:
	if runner == null or building or world == null:
		return
	_acc += minf(delta, 0.1)
	var steps := 0
	while _acc >= DT and steps < 2:
		runner.advance()
		for ev in runner.sim.events:
			if ev["t"] == "fire":
				shots_seen += 1
				_hot.append([_t, int(ev["id"]), ev["to"]])
		world.on_tick(runner.sim.events.duplicate())
		_acc -= DT
		steps += 1
	if _acc > DT * 2.0:
		_acc = DT   # never catch up in bursts on a slow frame (a lower sim rate instead)
	world.frame(clampf(_acc / DT, 0.0, 1.0), delta)
	_t += delta
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		for pid in 2:
			var al := _alive(pid)
			if al.size() < REFILL_BELOW:
				_wave(pid)
				if _rng.randf() < 0.5:
					_air_wave(pid)
			else:
				var idle: Array = []
				for id in al:
					var u := runner.sim.get_ent(id)
					if u.orders.is_empty() and u.target == 0:
						idle.append(id)
				if not idle.is_empty():
					runner.issue({"p": pid, "t": "amove", "ids": idle, "pos": _push_target(pid)})
	while not _hot.is_empty() and _t - float(_hot[0][0]) > HOT_SECONDS:
		_hot.pop_front()
	var sum := Vector3.ZERO
	var n := 0
	for h in _hot:
		if h[2] is Vector2i:
			sum += FX.to_world(h[2])
			n += 1
	if n == 0:
		for pid in 2:
			for id in _pools[pid]:
				var e := runner.sim.get_ent(id)
				if e != null and e.alive:
					sum += FX.to_world(e.pos)
					n += 1
	var goal: Vector3 = (_bases[0] + _bases[1]) * 0.5 if n == 0 else sum / n
	goal.y = 0.0
	_clash = _clash.lerp(goal, minf(1.0, delta * 0.35))
	_clip_t += delta
	if _clip_t > CLIP_SECONDS:
		_clip_t = 0.0
		clips_on_map += 1
		if clips_on_map >= CLIPS_PER_MAP or runner.sim.game_over:
			wants_rebuild.emit()
			return
		clip = (clip + 1 + _rng.randi() % (CLIP_KINDS - 1)) % CLIP_KINDS
		_cut = true
	_place_cam(_clip_t / CLIP_SECONDS, delta)
