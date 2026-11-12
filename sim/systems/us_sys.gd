class_name UsSys
## M2.5 US mechanics that are not air-related.
##  - Scout Sniper (tag "stealth_still"): hidden from enemies after STILL_TICKS without moving;
##    reuses the M2.4 stealth mask: enemy units within TplaSys.DETECT and detectors in sight see it.
##  - M2.9 TPLA: Marksman (tag "stealth_fire") is hidden unless it fired in the last FIRE_REVEAL_TICKS;
##    Insurgent (tag "stealth_always") always blends in; both are seen the same way (nearby enemies,
##    detectors). Heavy artillery (tag "setup") counts ticks standing still (CombatSys waits SETUP_TICKS).
const STILL_TICKS := 40
const FIRE_REVEAL_TICKS := 60    ## 3 s
const SETUP_TICKS := 100         ## 5 s

static func run(w: SimWorld) -> void:
	var dets: Array = []
	var dets_done := false
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
			continue
		var tags: PackedStringArray = w.udef(u).tags
		var still_t := tags.has("stealth_still")
		if still_t or tags.has("setup") or tags.has("deploy"):
			if u.moving or u.goal != MoveSys.NONE:
				u.still = 0
			elif u.still < 10000:
				u.still += 1
		var hide := false
		var kind := ""
		if still_t:
			hide = u.still >= STILL_TICKS
			kind = "still"
		elif tags.has("stealth_fire"):
			hide = w.tick - u.firing_tick >= FIRE_REVEAL_TICKS
			kind = "fire"
		elif tags.has("stealth_combat"):
			# Hidden until this soldier shoots or is shot. Nearby troops and detectors still spot it.
			hide = w.tick - u.firing_tick >= FIRE_REVEAL_TICKS and w.tick - u.last_hit_tick >= FIRE_REVEAL_TICKS
			kind = "fire"
		elif tags.has("stealth_always"):
			hide = true
			kind = "always"
		elif tags.has("stealth_defense"):
			hide = true
			kind = "defense"
		elif tags.has("stealth_air"):
			hide = w.flying(u)
			kind = "air"
		elif tags.has("low_sig"):
			hide = true
			kind = "low"
		else:
			continue
		if hide != u.stealthy:
			u.stealthy = hide
			w.events.append({"t": "stealth", "id": u.id, "on": hide})
		var mask := 0
		if hide:
			if kind == "defense":
				mask = _defense_mask(w, u)
			elif kind == "air":
				mask = _air_stealth_mask(w, u, dets, dets_done)
				dets_done = true
			elif kind == "low":
				mask = _low_sig_mask(w, u)
			else:
				if not dets_done:
					dets_done = true
					for id2 in w.ids:
						var d: SimEntity = w.ents[id2]
						if d.alive and d.kind == SimEntity.Kind.UNIT and d.res_id >= 0 and d.team >= 0 and w.udef(d).detector:
							dets.append(d)
				for o: SimEntity in w.units_in_radius(u.pos, TplaSys.DETECT + u.radius):
					if o.team >= 0 and o.res_id >= 0 and w.enemies(o.team, u.team):
						mask |= 1 << o.team
				for d2: SimEntity in dets:
					var sr: int = w.udef(d2).sight * FX.ONE
					if w.enemies(d2.team, u.team) and FX.dist2(d2.pos, u.pos) <= sr * sr:
						mask |= 1 << d2.team
		u.stealth_mask = mask

## Base-defence buildings (category defense) whose sight reaches the unit.
static func _defense_mask(w: SimWorld, u: SimEntity) -> int:
	var mask := 0
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if not b.alive or b.kind != SimEntity.Kind.BUILDING or not b.built or b.team < 0:
			continue
		if not w.enemies(b.team, u.team):
			continue
		var bd: BuildingDef = w.bdef(b)
		if bd.category != &"defense":
			continue
		var r: int = bd.sight * FX.ONE
		if bd.tags.has("zeus_pylon"):
			r = maxi(r, bd.aux_radius * FX.ONE)
		if w.dist_to_building(u.pos, b) <= r:
			mask |= 1 << b.team
	return mask

## YF-22: hidden from ground troops unless they are on top of it. Aircraft, detectors and
## base defences see it at their normal sight.
static func _air_stealth_mask(w: SimWorld, u: SimEntity, dets: Array, dets_done: bool) -> int:
	var mask := _defense_mask(w, u)
	if not dets_done:
		for id2 in w.ids:
			var d: SimEntity = w.ents[id2]
			if d.alive and d.kind == SimEntity.Kind.UNIT and d.res_id >= 0 and d.team >= 0 and w.udef(d).detector:
				dets.append(d)
	for o: SimEntity in w.units_in_radius(u.pos, 14 * FX.ONE):
		if o.team < 0 or o.res_id < 0 or not w.enemies(o.team, u.team):
			continue
		var od: UnitDef = w.udef(o)
		var reach := TplaSys.DETECT * 2 + u.radius
		if od.move_layer == &"air" or od.detector:
			reach = od.sight * FX.ONE
		if FX.dist2(o.pos, u.pos) <= reach * reach:
			mask |= 1 << o.team
	for d2: SimEntity in dets:
		var sr: int = w.udef(d2).sight * FX.ONE
		if w.enemies(d2.team, u.team) and FX.dist2(d2.pos, u.pos) <= sr * sr:
			mask |= 1 << d2.team
	return mask

## AH-6: spotted at 60% of a unit's sight. Base defences use their full sight.
static func _low_sig_mask(w: SimWorld, u: SimEntity) -> int:
	var mask := _defense_mask(w, u)
	for o: SimEntity in w.units_in_radius(u.pos, 12 * FX.ONE):
		if o.team < 0 or o.res_id < 0 or not w.enemies(o.team, u.team):
			continue
		var reach: int = w.udef(o).sight * FX.ONE * 60 / 100
		if FX.dist2(o.pos, u.pos) <= reach * reach:
			mask |= 1 << o.team
	return mask
