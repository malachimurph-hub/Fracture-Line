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
		if u.goal != NONE and not u.path_pending:
			_follow(w, u)
	_separate(w)

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
	var step := FX.speed_per_tick(d.speed_mtps) * w.map.speed_pct(cur_t, veh) / 100
	if u.vet >= 2:
		step = step * 110 / 100
	step = maxi(step, 8)
	var np := FX.step_toward(u.pos, wp, step)
	if np == wp:
		if u.path_i < u.path.size():
			u.path_i += 1
		elif wp == u.goal:
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

static func _set_pos(u: SimEntity, np: Vector2i) -> void:
	var dv := np - u.pos
	if dv != Vector2i.ZERO:
		u.dir = dv
		u.moving = true
	u.pos = np

static func _arrive(u: SimEntity) -> void:
	u.done_goal = u.goal
	u.goal = NONE
	u.path = []
	u.path_i = 0
	u.path_goal = NONE

## Separation steering: overlapping units push apart; never into blocked tiles.
static func _separate(w: SimWorld) -> void:
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
			continue
		var veh := w.is_vehicle(u)
		var push := Vector2i.ZERO
		for n: SimEntity in w.units_in_radius(u.pos, u.radius + 700):
			if n.id == u.id or n.res_id < 0:
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
