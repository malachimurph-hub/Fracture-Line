class_name MenuBattle
extends Node3D
## M2.6 (Malachi): Zero Hour-style live battle behind the main menu.
## A real match on a real map: real SimWorld, WorldView, unit models, weapons and VFX. Two random
## factions trade waves of units in the middle of a random skirmish map while the camera drifts
## slowly over the fighting. Nothing here is hard-coded per unit or map: the map comes from
## Content.maps and each wave is drawn from Content.units for the faction, so new maps and
## units appear here automatically in future builds.
## Light on the phone: rendered in a half-resolution SubViewport by the menu, no shadows, 30 FPS
## cap while the menu is up, about 8 units a side, no AI economy, silent (menu music only).
## Purely cosmetic: it never touches saves, replays or the deterministic match path.

const DT := 0.05
const WAVE := 8              ## units per side per wave
const REFILL_BELOW := 4      ## new wave when a side drops under this many units
const MAP_SECONDS := 150.0   ## then a fresh battle on another map

var runner: MatchRunner
var world: WorldView
var cam: CameraRig
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
	_pools.clear()
	for pid in 2:
		_pools[pid] = []
		_wave(pid)
	cam.jump_to(Vector3(c.x, 0, c.y), false)
	cam.set_level(0)      # close: the units are the show
	_drift = Vector3(dir.y, 0, -dir.x) * 0.6
	_map_t = 0.0

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
	cam = CameraRig.new()
	cam.map_size = Vector2(runner.sim.map.w, runner.sim.map.h)
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
	# camera: ease toward the fighting (centroid of both armies) with a slow sideways drift
	var sum := Vector3.ZERO
	var n := 0
	for pid in 2:
		for id in _pools[pid]:
			var e := runner.sim.get_ent(id)
			if e != null and e.alive:
				sum += FX.to_world(e.pos)
				n += 1
	var goal := cam.focus
	if n > 0:
		goal = sum / n
	goal += _drift * sin(_t * 0.15) * 6.0
	cam.focus = cam.focus.lerp(Vector3(goal.x, 0, goal.z), minf(1.0, delta * 0.35))
