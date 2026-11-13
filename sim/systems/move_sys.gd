class_name MoveSys
## Path requests (budgeted per tick), path following, terrain speed, and separation steering.
const NONE := Vector2i(-1, -1)
const PATH_BUDGET := 24

static func request(w: SimWorld, u: SimEntity) -> void:
	if not u.path_pending:
		u.path_pending = true
		w.path_queue.append(u.id)

static func run_paths(w: SimWorld) -> void:
	var n := 0
	while n < PATH_BUDGET and not w.path_queue.is_empty():
		var id: int = w.path_queue.pop_front()
		var u := w.get_ent(id)
		if u == null or not u.path_pending:
			continue
		u.path_pending = false
		if u.goal == NONE:
			continue
		var veh := w.is_vehicle(u)
		var from := FX.to_tile(u.pos)
		var gt := FX.to_tile(u.goal)
		var to := w.map.nearest_passable(gt, veh)
		u.path = w.map.pf.find(from, to, veh)
		u.path_i = 0
		u.path_goal = gt
		u.stuck = 0
		n += 1

static func run(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
			continue
		u.moving = false
		var ud: UnitDef = w.udef(u)
		if ud.move_layer == &"air":
			AirSys.fly(w, u, ud)
			continue
		if u.goal == NONE:
			u.spd = 0
		elif u.aux_def != &"" and String(u.aux_def).begins_with("ecc_mzkt_"):
			u.spd = 0
		elif ud.tags.has("pack_move") and u.still > 0:
			u.still -= 1
			u.spd = 0
		elif not u.path_pending:
			_follow(w, u)
	_separate(w)
	AirSys.separate(w)

static func _follow(w: SimWorld, u: SimEntity) -> void:
	var d: UnitDef = w.udef(u)
	var veh := d.move_layer == &"vehicle"
	var gt := FX.to_tile(u.goal)
	var cur_t := FX.to_tile(u.pos)
	if u.path_goal != gt:
		# short direct hop without A*
		if FX.dist2(u.pos, u.goal) <= (FX.ONE * 2) * (FX.ONE * 2) and w.map.passable(gt, veh):
			u.path = []
			u.path_i = 0
			u.path_goal = gt
		else:
			request(w, u)
			return
	var wp: Vector2i
	if u.path_i < u.path.size():
		var t: Vector2i = u.path[u.path_i]
		wp = u.goal if (u.path_i == u.path.size() - 1 and t == gt) else FX.tile_center(t)
	else:
		if w.map.passable(gt, veh) or cur_t == gt:
			wp = u.goal
		else:
			_arrive(u)
			return
	var lp := Loco.params(d)
	var kind: StringName = lp["kind"]
	var maxs := Loco.max_step(w, u, d)
	var final := wp == u.goal and u.path_i >= u.path.size() - 1
	var dist := FX.dist(u.pos, wp)
	# intermediate waypoints are cut once close: smooth cornering instead of stop-and-turn
	if not final and dist <= maxi(u.spd, 300) and u.path_i < u.path.size():
		u.path_i += 1
		return _follow_again(w, u)
	var want := FX.iatan2(wp.x - u.pos.x, wp.y - u.pos.y)
	var rate: int = lp["turn"]
	if kind == Loco.WHEELS and u.spd == 0:
		rate = maxi(1, rate / 3)
	u.face = Loco.turn(u.face, want, rate)
	var rel := FX.adiff(u.face, want)
	var gs := Loco.goal_speed(kind, maxs, rel)
	var brake_pt := maxi(1, maxs * 50 / maxi(1, int(lp["brake_ms"])))
	var accel_pt := maxi(1, maxs * 50 / maxi(1, int(lp["accel_ms"])))
	if final:
		# brake into the destination: v^2 = 2 * b * d
		gs = mini(gs, maxi(16, FX.isqrt(2 * brake_pt * dist)))
	elif kind == Loco.WHEELS and dist < FX.ONE and absi(rel) > FX.ANG / 8:
		gs = mini(gs, maxs / 4)
	if u.spd < gs:
		u.spd = mini(gs, u.spd + accel_pt)
	else:
		u.spd = maxi(gs, u.spd - brake_pt)
	u.dir = FX.dir_of(u.face)
	if u.spd <= 0:
		u.spd = 0
		return
	var np: Vector2i
	if dist <= u.spd and absi(rel) <= FX.ANG / 16:
		np = wp
	else:
		var hv := FX.dir_of(u.face)
		np = u.pos + Vector2i(hv.x * u.spd / FX.ONE, hv.y * u.spd / FX.ONE)
	if np == wp and final:
		_set_pos(u, np)
		_arrive(u)
		return
	var nt := FX.to_tile(np)
	if nt != cur_t and not w.map.passable(nt, veh):
		var alt1 := Vector2i(np.x, u.pos.y)
		var alt2 := Vector2i(u.pos.x, np.y)
		if w.map.passable(FX.to_tile(alt1), veh):
			np = alt1
		elif w.map.passable(FX.to_tile(alt2), veh):
			np = alt2
		else:
			np = u.pos
		u.spd = u.spd / 2
	if np == u.pos:
		u.stuck += 1
		if u.stuck > 12:
			u.stuck = 0
			if FX.dist(u.pos, u.goal) < FX.ONE * 2:
				_arrive(u)
			else:
				u.path_goal = NONE   # forces re-path
	else:
		u.stuck = maxi(0, u.stuck - 1)
		_set_pos(u, np)

## Re-run follow after advancing a waypoint (bounded: each call consumes one waypoint).
static func _follow_again(w: SimWorld, u: SimEntity) -> void:
	_follow(w, u)

static func _set_pos(u: SimEntity, np: Vector2i) -> void:
	var dv := np - u.pos
	if dv != Vector2i.ZERO:
		u.moving = true
	u.pos = np

static func _arrive(u: SimEntity) -> void:
	u.spd = 0
	u.done_goal = u.goal
	u.goal = NONE
	u.path = []
	u.path_i = 0
	u.path_goal = NONE

## Separation steering: overlapping units push apart; never into blocked tiles.
static func _separate(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0 or w.is_air(u):
			continue
		var veh := w.is_vehicle(u)
		var push := Vector2i.ZERO
		for n: SimEntity in w.units_in_radius(u.pos, u.radius + 700):
			if n.id == u.id or n.res_id < 0 or w.is_air(n):
				continue
			var minr := u.radius + n.radius
			var dx := u.pos.x - n.pos.x
			var dy := u.pos.y - n.pos.y
			var d2 := dx * dx + dy * dy
			if d2 >= minr * minr:
				continue
			var dd := FX.isqrt(d2)
			if dd == 0:
				dx = 1 if u.id > n.id else -1
				dy = 0
				dd = 1
			var ov := minr - dd
			# moving units push idle ones harder; idle units yield
			var f := 4   # eighths of the overlap this unit resolves
			if u.moving and not n.moving:
				f = 2
			elif n.moving and not u.moving:
				f = 6
			push += Vector2i(dx * ov / dd, dy * ov / dd) * f / 8
		if push != Vector2i.ZERO:
			push.x = clampi(push.x, -90, 90)
			push.y = clampi(push.y, -90, 90)
			var np := u.pos + push
			if w.map.passable(FX.to_tile(np), veh):
				u.pos = np
