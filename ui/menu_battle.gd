class_name MenuBattle
extends Node3D
## M2.6 (Malachi): Zero Hour-style live battle behind the main menu.
## A real match on a real map: real SimWorld, WorldView, unit models, weapons and VFX. Two random
## factions trade waves of units in the middle of a random skirmish map while the camera drifts
## slowly over the fighting. Nothing here is hard-coded per unit or map: the map comes from
## Content.maps and each wave is drawn from Content.units for the faction, so new maps and
## units appear here automatically in future builds.
## Light on the phone: rendered at reduced 3D resolution by the menu, no shadows, 30 FPS
## cap while the menu is up, about 8 units a side, no AI economy, silent (menu music only).
## Purely cosmetic: it never touches saves, replays or the deterministic match path.
## M2.7 reframe (Malachi: "it shows basically only explosions"): a small base for each side is
## laid out behind its front, the camera is a pulled-back cinematic rig that cycles through four
## slow shots (wide establishing orbit, side-on tracking along the front, and a push-in over
## each base toward the fight), and explosions / smoke are toned down (Vfx.fx_mul) so the
## units and buildings stay readable.
## M2.7b reframe (Malachi: "the menu battle is still small in the wide shots"): no empty wide
## shots any more. The camera is an engagement director that frames the actual fighting, read
## from the sim's own "fire" events: 0 tracks a vehicle column pushing toward the enemy and
## firing, 1 a close slow orbit over the hottest clash, 2 a low angle past a base building with
## the fight behind it, 3 a close 3/4 shot on the unit that fired last. The bases sit closer to
## the front and waves attack-move into the enemy base, so fights spill around the buildings.

## Test hook (tests/gfx_m27_menu.gd): pin the backdrop map; empty = random.
static var force_map: StringName = &""
const DT := 0.05
const WAVE := 9              ## units per side per wave
const REFILL_BELOW := 4      ## new wave when a side drops under this many units
const MAP_SECONDS := 150.0   ## then a fresh battle on another map
const SHOT_SECONDS := 11.0   ## each cinematic shot
const FX_MUL := 0.45         ## explosion / smoke particle scale in the menu
const BASE_BACK := 8.0       ## tiles from a side's front back to its base (M2.7b: closer)
const HOT_SECONDS := 3.0     ## fire events this recent count toward the clash point

var runner: MatchRunner
var world: WorldView
var cam: MenuCam
var shots_seen := 0
var _acc := 0.0
var _t := 0.0
var _map_t := 0.0
var _rng := RandomNumberGenerator.new()
var _facs: Array = []
var _pools: Dictionary = {}     ## pid -> [unit ids]
var _front: Array = []          ## two rally points (fixed-point) facing each other
var _drift := Vector3.ZERO
var _env_nodes: Array = []
var _bases: Array = [Vector3.ZERO, Vector3.ZERO]   ## world-space base centres per side
var _dir3 := Vector3.RIGHT                        ## from side 0 toward side 1
var _shot := 0
var _shot_t := 0.0
var _look := Vector3.ZERO                         ## smoothed battle centre
var _clash := Vector3.ZERO                        ## smoothed centre of recent firing
var _hot: Array = []                              ## recent fire events [time, shooter id, impact]
var _subject := 0                                 ## unit the close shots follow
var _eye := Vector3.ZERO                          ## smoothed camera position
var _at := Vector3.ZERO                           ## smoothed look-at point
var _cut := true                                  ## next placement snaps (new shot)
var _last_shot := -1

## Slow cinematic camera: a free Camera3D placed by the menu each frame. `focus` is the point
## it looks at (kept for the UI tests, same name as CameraRig's).
class MenuCam extends Node3D:
	var cam: Camera3D
	var focus := Vector3.ZERO
	func _ready() -> void:
		cam = Camera3D.new()
		cam.fov = 40.0
		cam.near = 0.5
		cam.far = 260.0
		add_child(cam)
		cam.current = true
	func place(eye: Vector3, at: Vector3) -> void:
		focus = at
		cam.position = eye
		cam.look_at(at, Vector3.UP)
		# compose: subject a little left of centre and below it (the menu buttons sit on the
		# right, the title in the middle-left)
		cam.rotate_object_local(Vector3.UP, -0.06)
		cam.rotate_object_local(Vector3.RIGHT, 0.06)

func _ready() -> void:
	_rng.randomize()
	_new_battle()

## Units a faction can field here: everything it builds except builders, harvesters, stubs,
## suicide units and jets (jets need an airfield to return to).
static func roster_pool(fac: StringName) -> Array:
	var out: Array = []
	for id in Content.units:
		var d: UnitDef = Content.units[id]
		if not String(id).begins_with(String(fac) + "_"):
			continue
		var bad := false
		for tg in ["builder", "harvester", "stub", "suicide", "jet"]:
			if d.tags.has(tg):
				bad = true
		if not bad and d.max_hp > 0:
			out.append(id)
	out.sort()
	return out

func pool_size() -> int:
	var n := 0
	for f in _facs:
		n += roster_pool(f).size()
	return n

func _new_battle() -> void:
	for n in _env_nodes:
		n.queue_free()
	_env_nodes.clear()
	if world != null:
		world.queue_free()
	if cam != null:
		cam.queue_free()
	var maps: Array = []
	for k in Content.maps:
		if not (Content.maps[k] as MapDef).custom:   # M2.8: built-in maps only behind the menu
			maps.append(k)
	maps.sort()
	var mid: StringName = maps[_rng.randi() % maps.size()]
	if force_map != &"" and Content.maps.has(force_map):
		mid = force_map
	var facs: Array = Content.playable_factions()   # M3.0: never a "Coming soon" faction
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
	runner.ais.clear()               # no economy / base building: just the fight
	for p in runner.sim.players:
		p.supply = 0
	_build_view()
	# two fronts either side of the map centre, along the line between the two bases
	var hq: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	for id in runner.sim.ids:
		var e: SimEntity = runner.sim.ents[id]
		if e.kind == SimEntity.Kind.BUILDING and e.owner >= 0 and e.owner < 2:
			hq[e.owner] = Vector2(e.tile)
	var c := Vector2(runner.sim.map.w, runner.sim.map.h) * 0.5
	var dir: Vector2 = (hq[1] - hq[0]).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_front = [c - dir * 6.0, c + dir * 6.0]
	_dir3 = Vector3(dir.x, 0, dir.y)
	for pid in 2:
		var side := -1.0 if pid == 0 else 1.0
		var bc: Vector2 = c + dir * side * (6.0 + BASE_BACK)
		bc = bc.clamp(Vector2(8, 8), Vector2(runner.sim.map.w - 8, runner.sim.map.h - 8))
		_bases[pid] = Vector3(bc.x, 0, bc.y)
		_lay_base(pid, bc, dir * -side)
	_pools.clear()
	for pid in 2:
		_pools[pid] = []
		_wave(pid)
	_look = Vector3(c.x, 0, c.y)
	_clash = _look
	_hot.clear()
	_subject = 0
	_drift = Vector3(dir.y, 0, -dir.x)
	_shot = _rng.randi() % 4
	_shot_t = 0.0
	_cut = true
	_place_cam(0.0, 1.0)
	_map_t = 0.0

## A small, recognisable base for a side: its unarmed structures (HQ, power, production, tech)
## from the content, biggest first, in two rows across the line of battle facing the front.
## Placed complete and sturdy (10x hp) so they stay standing as set dressing.
func _lay_base(pid: int, at: Vector2, face: Vector2) -> void:
	var defs: Array = []
	for id in Content.buildings:
		var d: BuildingDef = Content.buildings[id]
		if d.faction == _facs[pid] and d.weapons.is_empty() and d.footprint.x >= 2 and d.footprint.y >= 2 and not d.tags.has("trap") and not d.tags.has("hole"):
			defs.append(d)
	defs.sort_custom(func(a: BuildingDef, b: BuildingDef) -> bool:
		var ka := a.footprint.x * a.footprint.y
		var kb := b.footprint.x * b.footprint.y
		return ka > kb if ka != kb else String(a.id) < String(b.id))
	# pack them tightly around the base centre (spiral search from the middle outward)
	var placed := 0
	var sum := Vector3.ZERO
	for d: BuildingDef in defs:
		if placed >= 6:
			break
		var t := _near_free(Vector2i((at - Vector2(d.footprint) * 0.5).round()), d.footprint, 9)
		if t.x >= 0:
			var e := runner.sim._place_building(d, pid, t, 0, true)
			e.max_hp *= 10
			e.hp = e.max_hp
			world._ensure_view(e)      # placed outside the event stream, so make its view now
			sum += FX.to_world(e.pos)
			placed += 1
	if placed > 0:
		_bases[pid] = sum / placed

## Nearest free footprint origin within rmax tiles of t (rings outward), or (-1, -1).
func _near_free(t: Vector2i, fp: Vector2i, rmax: int = 7) -> Vector2i:
	for r in rmax + 1:
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if maxi(absi(xx), absi(yy)) != r:
					continue
				if _free(t + Vector2i(xx, yy), fp):
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

## Engagement shots, cycling every SHOT_SECONDS (s = 0..1 through the shot):
## 0 track a vehicle column toward the enemy, 1 close orbit over the clash, 2 low angle past a
## base building with the fight behind it, 3 close 3/4 shot on the last unit to fire.
func _place_cam(s: float, delta: float) -> void:
	var e := s * s * (3.0 - 2.0 * s) * 0.6 + s * 0.4     # gentle ease
	var side := _drift.normalized()
	var eye := Vector3.ZERO
	var at := Vector3.ZERO
	match _shot:
		0, 3:
			var u := _subject_pos()
			if u == Vector3.INF:
				eye = _clash - _dir3 * 7.0 + side * 3.0 + Vector3(0, 4.0, 0)
				at = _clash + Vector3(0, 0.5, 0)
			else:
				var fwd := _clash - u
				fwd.y = 0.0
				fwd = fwd.normalized() if fwd.length() > 0.5 else _subject_dir()
				var lat := Vector3(-fwd.z, 0, fwd.x)
				if _shot == 0:   # trailing 3/4 view, looking past the column at the enemy
					eye = u - fwd * lerpf(6.5, 5.0, e) + lat * lerpf(3.2, 2.2, e) + Vector3(0, lerpf(3.4, 2.7, e), 0)
					at = u + fwd * 4.0 + Vector3(0, 0.4, 0)
				else:            # low 3/4 front: the shooter large, its target zone behind it
					eye = u + fwd * 3.2 + lat * lerpf(-3.4, -2.4, e) + Vector3(0, lerpf(1.9, 1.5, e), 0)
					at = u + fwd * 0.8 + Vector3(0, 0.45, 0)
		1:
			var a := lerpf(-0.6, 0.6, e)
			var back := (-_dir3).rotated(Vector3.UP, 1.2 + a)
			eye = _clash + back * 8.5 + Vector3(0, 5.2, 0)
			at = _clash + Vector3(0, 0.4, 0)
		_:
			var b := _building_near(_clash)
			var toward := _clash - b
			toward.y = 0.0
			var d := maxf(toward.length(), 1.0)
			toward /= d
			var lat2 := Vector3(-toward.z, 0, toward.x)
			# low, just beside the building's front corner, the fight filling the frame behind it
			eye = b + toward * lerpf(0.4, 1.6, e) + lat2 * 2.6 + Vector3(0, 1.6, 0)
			at = b + toward * minf(d, 9.0) + Vector3(0, 0.6, 0)
	if _cut:
		_eye = eye
		_at = at
		_cut = false
	else:
		var k := minf(1.0, delta * 2.2)
		_eye = _eye.lerp(eye, k)
		_at = _at.lerp(at, k)
	cam.place(_eye, _at)

## Pick the close-shot subject: a recent shooter (vehicles preferred) of either side, else the
## unit nearest the clash.
func _pick_subject() -> void:
	_subject = 0
	var best := -1.0
	var now := _t
	for h in _hot:
		var e := runner.sim.get_ent(h[1])
		if e == null or not e.alive or e.kind != SimEntity.Kind.UNIT:
			continue
		var veh := Content.unit(e.def_id).move_layer != &"foot"
		var sc: float = (2.0 if veh else 1.0) + (h[0] - now) * 0.2 + _rng.randf() * 0.3
		if _shot == 0:
			sc -= FX.to_world(e.pos).distance_to(_clash) * 0.05
		if sc > best:
			best = sc
			_subject = h[1]
	if _subject != 0:
		return
	var dmin := INF
	for pid in 2:
		for id in _pools[pid]:
			var e := runner.sim.get_ent(id)
			if e != null and e.alive:
				var dd := FX.to_world(e.pos).distance_to(_clash)
				if dd < dmin:
					dmin = dd
					_subject = id

func _subject_pos() -> Vector3:
	var e := runner.sim.get_ent(_subject) if _subject != 0 else null
	if e == null or not e.alive:
		_pick_subject()
		e = runner.sim.get_ent(_subject) if _subject != 0 else null
		if e == null:
			return Vector3.INF
	var p := FX.to_world(e.pos)
	if world.views.has(_subject):
		p = (world.views[_subject] as Node3D).global_position   # smooth interpolated view position
	p.y = 0.0
	return p

func _subject_dir() -> Vector3:
	if world.views.has(_subject):
		var v: Node3D = world.views[_subject]
		var f := -v.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.1:
			return f.normalized()
	return _dir3

## World position of the base building nearest p (either side), or the nearer base centre.
func _building_near(p: Vector3) -> Vector3:
	var best := Vector3.INF
	for id in runner.sim.ids:
		var e: SimEntity = runner.sim.ents[id]
		if e.kind == SimEntity.Kind.BUILDING and e.owner >= 0 and e.owner < 2 and e.alive:
			var w := FX.to_world(e.pos)
			if best == Vector3.INF or w.distance_to(p) < best.distance_to(p):
				best = w
	if best == Vector3.INF:
		best = _bases[0] if (_bases[0] as Vector3).distance_to(p) < (_bases[1] as Vector3).distance_to(p) else _bases[1]
	return Vector3(best.x, 0, best.z)

func _build_view() -> void:
	var menv := MapEnv.for_map(runner.sim.map_id)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b0c0e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = menv["ambient"]
	e.ambient_light_energy = menv["ambient_energy"]
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = menv["exposure"]
	e.fog_enabled = true
	e.fog_light_color = menv["fog_col"]
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
	sun.shadow_enabled = false       # keep the menu light on phones
	add_child(sun)
	_env_nodes = [env, sun]
	world = WorldView.new()
	add_child(world)
	world.setup(runner, -1)
	world.vfx.fx_mul = FX_MUL
	cam = MenuCam.new()
	add_child(cam)

func _wave(pid: int) -> void:
	var pool := roster_pool(_facs[pid])
	if pool.is_empty():
		return
	var at: Vector2 = _front[pid]
	var to: Vector2 = _front[1 - pid]
	var ids: Array = []
	for i in WAVE:
		var uid: StringName = pool[_rng.randi() % pool.size()]
		# M2.7: favour vehicles (squads read as specks from the pulled-back camera)
		if Content.unit(uid).move_layer == &"foot" and _rng.randf() < 0.6:
			uid = pool[_rng.randi() % pool.size()]
		var off := Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		var t := Vector2i((at + off - (to - at).normalized() * 2.0).round())
		t = t.clamp(Vector2i(2, 2), Vector2i(runner.sim.map.w - 3, runner.sim.map.h - 3))
		var u := runner.sim.spawn_unit(uid, pid, null, FX.tile_center(t))
		if u != null:
			ids.append(u.id)
			_pools[pid].append(u.id)
			# spawned between sim steps: step() clears events before the view sees this
			# spawn, so make the view here (M2.7b - wave units were never drawn before)
			world._ensure_view(u)
			world.cur[u.id] = world._world_pos(u)
			world.prev[u.id] = world.cur[u.id]
	if not ids.is_empty():
		runner.issue({"p": pid, "t": "amove", "ids": ids, "pos": _push_target(pid)})

## Where a side's units attack-move: through the enemy front into its base (M2.7b), so the
## fighting reaches the buildings the low-angle shot frames.
func _push_target(pid: int) -> Vector2i:
	var b: Vector3 = _bases[1 - pid]
	var t := Vector2i(roundi(b.x), roundi(b.z))
	return FX.tile_center(t.clamp(Vector2i(2, 2), Vector2i(runner.sim.map.w - 3, runner.sim.map.h - 3)))

func _alive(pid: int) -> Array:
	var out: Array = []
	for id in _pools[pid]:
		var e := runner.sim.get_ent(id)
		if e != null and e.alive:
			out.append(id)
	_pools[pid] = out
	return out

func _process(delta: float) -> void:
	if runner == null:
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
	world.frame(clampf(_acc / DT, 0.0, 1.0), delta)
	_t += delta
	_map_t += delta
	if int(_t * 2.0) != int((_t - delta) * 2.0):     # twice a second
		for pid in 2:
			var al := _alive(pid)
			if al.size() < REFILL_BELOW:
				_wave(pid)
			else:
				# idle survivors push on toward the other front
				var idle: Array = []
				for id in al:
					var u := runner.sim.get_ent(id)
					if u.orders.is_empty() and u.target == 0:
						idle.append(id)
				if not idle.is_empty():
					runner.issue({"p": pid, "t": "amove", "ids": idle, "pos": _push_target(pid)})
		if runner.sim.game_over or _map_t > MAP_SECONDS:
			_new_battle()
			return
	# camera: the clash point is the smoothed centre of recent firing (both shooters and
	# impacts), falling back to the armies' centroid; shots cycle every SHOT_SECONDS
	while not _hot.is_empty() and _t - float(_hot[0][0]) > HOT_SECONDS:
		_hot.pop_front()
	var sum := Vector3.ZERO
	var n := 0
	for h in _hot:
		var se := runner.sim.get_ent(h[1])
		if se != null and se.alive:
			sum += FX.to_world(se.pos)
			n += 1
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
	var mid: Vector3 = (_bases[0] + _bases[1]) * 0.5
	var goal := mid
	if n > 0:
		goal = sum / n
	goal.y = 0.0
	_clash = _clash.lerp(goal, minf(1.0, delta * 0.6))
	_look = _look.lerp(Vector3(goal.x, 0, goal.z), minf(1.0, delta * 0.25))
	_shot_t += delta
	if _shot_t > SHOT_SECONDS:
		_shot_t = 0.0
		_shot = (_shot + 1) % 4
	if _shot != _last_shot:   # a new shot cuts (also when a test or debug jumps shots)
		_last_shot = _shot
		_cut = true
		_pick_subject()
	_place_cam(_shot_t / SHOT_SECONDS, delta)
