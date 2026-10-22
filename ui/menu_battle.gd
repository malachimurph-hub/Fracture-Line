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

const DT := 0.05
const WAVE := 9              ## units per side per wave
const REFILL_BELOW := 4      ## new wave when a side drops under this many units
const MAP_SECONDS := 150.0   ## then a fresh battle on another map
const SHOT_SECONDS := 11.0   ## each cinematic shot
const FX_MUL := 0.45         ## explosion / smoke particle scale in the menu
const BASE_BACK := 13.0      ## tiles from a side's front back to its base

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

## Slow cinematic camera: a free Camera3D placed by the menu each frame. `focus` is the point
## it looks at (kept for the UI tests, same name as CameraRig's).
class MenuCam extends Node3D:
	var cam: Camera3D
	var focus := Vector3.ZERO
	func _ready() -> void:
		cam = Camera3D.new()
		cam.fov = 38.0
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
		cam.rotate_object_local(Vector3.UP, -0.1)
		cam.rotate_object_local(Vector3.RIGHT, 0.07)

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
	var maps: Array = Content.maps.keys()
	maps.sort()
	var mid: StringName = maps[_rng.randi() % maps.size()]
	var facs: Array = Content.FACTIONS.keys()
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
	_drift = Vector3(dir.y, 0, -dir.x)
	_shot = _rng.randi() % 4
	_shot_t = 0.0
	_place_cam(0.0)
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

## Four slow shots, cycling: 0 wide establishing orbit over the battle, 1 side-on tracking
## along the front, 2 / 3 low push-in over a side's base toward the fighting.
func _place_cam(s: float) -> void:
	var e := s * s * (3.0 - 2.0 * s) * 0.6 + s * 0.4     # gentle ease
	var side := _drift.normalized()
	match _shot:
		0:
			var a := lerpf(-0.45, 0.45, e)
			var back := (-_dir3).rotated(Vector3.UP, 1.1 + a)
			cam.place(_look + back * 15.0 + Vector3(0, 10.5, 0), _look + Vector3(0, 0.6, 0))
		1:
			var along := _dir3 * lerpf(-8.0, 8.0, e)
			cam.place(_look + along + side * 13.0 + Vector3(0, 6.0, 0), _look + along + Vector3(0, 0.6, 0))
		_:
			var pid := _shot - 2
			var b: Vector3 = _bases[pid]
			var toward := (_look - b).normalized()
			var eye := b - toward * lerpf(15.0, 12.0, e) + side * lerpf(-4.0, 4.0, e) + Vector3(0, lerpf(9.5, 8.0, e), 0)
			cam.place(eye, b + toward * 6.0 + Vector3(0, 0.5, 0))

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
	if not ids.is_empty():
		runner.issue({"p": pid, "t": "amove", "ids": ids, "pos": FX.tile_center(Vector2i(to.round()))})

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
					runner.issue({"p": pid, "t": "amove", "ids": idle, "pos": FX.tile_center(Vector2i((_front[1 - pid] as Vector2).round()))})
		if runner.sim.game_over or _map_t > MAP_SECONDS:
			_new_battle()
			return
	# camera: the shots look at the fighting (smoothed centroid of both armies, kept between
	# the two bases) and cycle every SHOT_SECONDS
	var sum := Vector3.ZERO
	var n := 0
	for pid in 2:
		for id in _pools[pid]:
			var e := runner.sim.get_ent(id)
			if e != null and e.alive:
				sum += FX.to_world(e.pos)
				n += 1
	var mid: Vector3 = (_bases[0] + _bases[1]) * 0.5
	var goal := mid
	if n > 0:
		goal = (sum / n).lerp(mid, 0.3)
	_look = _look.lerp(Vector3(goal.x, 0, goal.z), minf(1.0, delta * 0.25))
	_shot_t += delta
	if _shot_t > SHOT_SECONDS:
		_shot_t = 0.0
		_shot = (_shot + 1) % 4
	_place_cam(_shot_t / SHOT_SECONDS)
