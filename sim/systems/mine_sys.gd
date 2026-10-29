class_name MineSys
## M3.3 Phase 3 item 28 (Malachi: the Russian Minerals Mining excavator "can move very slowly").
## Plan Page default: it packs up and earns nothing while moving, drives at about a quarter of
## the engineer's speed, and unpacks in 10 s on open ground. Income starts again once it is set
## up. It does not need an ore deposit.
##   "pack"   {target: building}  -> 10 s pack-up (building.aux_t = done tick), then the
##                                    structure becomes the ecc_mine_mobile vehicle (same hp %)
##   "unpack" {ids: [vehicle]}    -> 10 s set-up where it stands (unit.aux_t = done tick, unit.tile =
##                                    footprint), then it becomes the structure again
## Any move order while setting up cancels it. Packing is cancelled by "unpack" on the building.
const PACK_MS := 10000
const MOBILE := &"ecc_mine_mobile"
const SITE := &"ecc_black_market"

static func is_mobile_site(w: SimWorld, b: SimEntity) -> bool:
	return b != null and b.alive and b.kind == SimEntity.Kind.BUILDING and w.bdef(b).tags.has("mobile")

static func packing(w: SimWorld, b: SimEntity) -> bool:
	return is_mobile_site(w, b) and b.aux_t > 0

static func unpacking(e: SimEntity) -> bool:
	return e != null and e.kind == SimEntity.Kind.UNIT and e.def_id == MOBILE and e.aux_t > 0

static func ticks_left(w: SimWorld, e: SimEntity) -> int:
	return maxi(0, e.aux_t - w.tick) if e.aux_t > 0 else 0

## Footprint (top-left tile) a mobile mine would unpack onto, centred on where it stands.
static func site_tile(w: SimWorld, u: SimEntity) -> Vector2i:
	var fp: Vector2i = Content.building(SITE).footprint
	return FX.to_tile(u.pos) - Vector2i(fp.x / 2, fp.y / 2)

## "" if the mine can set up at t (open, buildable ground, nothing built there, no enemy on it).
static func can_unpack_at(w: SimWorld, u: SimEntity, t: Vector2i) -> String:
	var d: BuildingDef = Content.building(SITE)
	for yy in d.footprint.y:
		for xx in d.footprint.x:
			var c := Vector2i(t.x + xx, t.y + yy)
			if not w.map.in_bounds(c) or c.x < 1 or c.y < 1 or c.x >= w.map.w - 1 or c.y >= w.map.h - 1:
				return "REASON_BLOCKED"
			var i := w.map.idx(c)
			if not SimMap.BUILD_OK[w.map.tiles[i]]:
				return "REASON_TERRAIN"
			if w.map.occ[i] != 0:
				return "REASON_BLOCKED"
			if w.map.nobuild[i] != 0:
				return "REASON_RESOURCE"
	var center := Vector2i(t.x * FX.ONE + d.footprint.x * FX.HALF, t.y * FX.ONE + d.footprint.y * FX.HALF)
	for o: SimEntity in w.units_in_radius(center, maxi(d.footprint.x, d.footprint.y) * FX.ONE):
		if w.enemies(o.team, u.team):
			return "REASON_ENEMY"
	return ""

static func pack(w: SimWorld, pid: int, b: SimEntity) -> void:
	if not is_mobile_site(w, b) or b.owner != pid or not b.built:
		return
	if b.aux_t > 0:
		b.aux_t = 0                      # second tap: cancel the pack-up
	else:
		b.aux_t = w.tick + FX.ms_to_ticks(PACK_MS)
	w.events.append({"t": "mine_pack", "id": b.id, "on": b.aux_t > 0})

static func unpack(w: SimWorld, pid: int, u: SimEntity) -> void:
	if u == null or not u.alive or u.owner != pid or u.def_id != MOBILE:
		return
	if u.aux_t > 0:
		u.aux_t = 0
		w.events.append({"t": "mine_unpack", "id": u.id, "on": false})
		return
	var t := site_tile(w, u)
	var why := can_unpack_at(w, u, t)
	if why != "":
		w.events.append({"t": "mine_unpack", "id": u.id, "on": false, "why": why})
		return
	u.orders.clear()
	u.goal = Vector2i(-1, -1)
	u.path = []
	u.tile = t
	u.aux_t = w.tick + FX.ms_to_ticks(PACK_MS)
	w.events.append({"t": "mine_unpack", "id": u.id, "on": true})

static func run(w: SimWorld) -> void:
	var done: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.aux_t <= 0:
			continue
		if e.kind == SimEntity.Kind.UNIT and e.def_id == MOBILE:
			if not e.orders.is_empty():
				e.aux_t = 0          # ordered to move: setting up is called off
				w.events.append({"t": "mine_unpack", "id": e.id, "on": false})
			elif w.tick >= e.aux_t:
				done.append(e)
		elif e.kind == SimEntity.Kind.BUILDING and w.tick >= e.aux_t and is_mobile_site(w, e):
			done.append(e)
	for e: SimEntity in done:
		if e.kind == SimEntity.Kind.BUILDING:
			_to_vehicle(w, e)
		else:
			_to_site(w, e)

static func _to_vehicle(w: SimWorld, b: SimEntity) -> void:
	var pct := b.hp * 1000 / maxi(1, b.max_hp)
	b.alive = false
	b.aux_t = 0
	w.map.unstamp(b.tile, b.fp)
	w.power_dirty = true
	w._eject_garrison(b)
	var u := w.spawn_unit(MOBILE, b.owner, null, b.pos)
	u.team = b.team
	u.hp = maxi(1, u.max_hp * pct / 1000)
	u.vet = b.vet
	u.face = FX.ANG / 2 if b.rot == 2 else 0
	w.events.append({"t": "death", "id": b.id, "kind": b.kind, "def": b.def_id, "pos": b.pos, "owner": b.owner, "silent": true, "packed": true})
	w.events.append({"t": "mine_moved", "from": b.id, "to": u.id, "owner": b.owner})

static func _to_site(w: SimWorld, u: SimEntity) -> void:
	u.aux_t = 0
	if can_unpack_at(w, u, u.tile) != "":
		w.events.append({"t": "mine_unpack", "id": u.id, "on": false, "why": "REASON_BLOCKED"})
		return
	var pct := u.hp * 1000 / maxi(1, u.max_hp)
	u.alive = false
	var b := w._place_building(Content.building(SITE), u.owner, u.tile, 0, true)
	b.team = u.team
	b.hp = maxi(1, b.max_hp * pct / 1000)
	b.vet = u.vet
	w.events.append({"t": "death", "id": u.id, "kind": u.kind, "def": u.def_id, "pos": u.pos, "owner": u.owner, "silent": true, "packed": true})
	w.events.append({"t": "mine_moved", "from": u.id, "to": b.id, "owner": u.owner})
