class_name AIUs
extends AIPlayer
## M2.5 United States skirmish AI. Same rules as every AI (own entities + fog-limited view, the
## same Commands as a human). Uses the power-economy build planner of AIPlayer with US structures
## (roles), plus an air layer:
##  - jets (bombers, fighters) are kept out of the ground waves and fly sorties from the Airfield:
##    fighters hunt visible enemy aircraft near the base or the wave, else strafe what the wave is
##    fighting; bombers attack-move onto the wave's target or a threat at home. AirSys flies them
##    home to land and rearm on its own.
##  - gunships, JTACs and snipers go with the ground waves (JTAC call-ins and the artillery / air
##    boost are automatic in the sim); the airfield is never asked for a jet it has no slot for.

func roles() -> Dictionary:
	return {"builder": &"us_dozer", "harvester": &"us_supply_truck", "refinery": &"us_supply_center", "power": &"us_reactor",
		"bunker": &"us_firebase", "barracks": &"us_barracks", "heavy": &"us_airfield", "motor": &"us_garage",
		"tech": &"us_strategy", "support": &"", "aa_tower": &"us_patriot", "income": &"us_drop_zone",
		"mine": &"", "pylon": &""}

func faction() -> StringName:
	return &"us"

func think() -> void:
	super.think()
	if not me().eliminated and _every("t_air", 40):
		_air()

func _unit_allowed(ud: UnitDef) -> bool:
	if ud.air_slots > 0 and _cur_b != null and w.bdef(_cur_b).air_slots > 0:
		var queued := 0
		for q in _cur_b.queue:
			queued += Content.unit(q).air_slots
		return AirSys.slots_free(w, _cur_b) - queued >= ud.air_slots
	var n := combat_units().size()
	if ud.tags.has("jtac") or ud.tags.has("sniper"):
		return _count_type(ud.id) < 1 + n / 12
	return true

func _reserved_ids() -> Dictionary:
	var out := {}
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		if w.udef(u).tags.has("jet"):
			out[u.id] = true
	return out

func _is_scout_type(u: SimEntity) -> bool:
	return u.def_id == &"us_lynx" or u.def_id == &"us_grunt"

# ------------------------------------------------------------------ air layer
func _air() -> void:
	var wave_units: Array = []
	for id in bb["wave"]:
		var e := w.get_ent(int(id))
		if e != null:
			wave_units.append(e)
	var wave_c := _centroid(wave_units) if not wave_units.is_empty() else Vector2i(-1, -1)
	var threat: bool = w.tick - int(bb["threat_tick"]) < 200
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		var d: UnitDef = w.udef(u)
		if not d.tags.has("jet") or not u.orders.is_empty() or u.target != 0:
			continue
		if u.air_state == AirSys.RETURNING or (u.air_state == AirSys.PARKED and u.air_t > 0) or not AirSys.has_ammo(u, d):
			continue
		if d.tags.has("fighter"):
			var air := _enemy_air_near([base_pos(), wave_c], 28)
			if air != null:
				cmd({"t": "attack", "ids": [u.id], "target": air.id})
				continue
			var gt := _engaged_enemy(wave_units)
			if gt == null and threat:
				gt = _visible_enemy_near(bb["threat_pos"], 10)
			if gt != null:
				cmd({"t": "attack", "ids": [u.id], "target": gt.id})
		else:
			# bomber: the threat at home first, then the wave's objective once the wave is out
			if threat and _enemy_strength_near(bb["threat_pos"], 10) >= 1500:
				cmd({"t": "amove", "ids": [u.id], "pos": bb["threat_pos"]})
			elif wave_c.x >= 0 and int(bb["wave_n"]) >= 1:
				var tgt := _pick_target()
				if tgt.x >= 0 and FX.dist(tgt, wave_c) < FX.ONE * 30:
					cmd({"t": "amove", "ids": [u.id], "pos": tgt})

func _enemy_air_near(points: Array, tiles: int) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 60
	for p: Vector2i in points:
		if p.x < 0:
			continue
		for e: SimEntity in w.units_in_radius(p, tiles * FX.ONE):
			if w.enemies(me().team, e.team) and w.flying(e) and e.res_id >= 0 and w.fog.is_visible_ent(w, me().team, e):
				var dd := FX.dist2(e.pos, p)
				if dd < bd:
					bd = dd
					best = e
	return best

func _visible_enemy_near(p: Vector2i, tiles: int) -> SimEntity:
	var best: SimEntity = null
	var bd := 1 << 60
	for e: SimEntity in w.units_in_radius(p, tiles * FX.ONE):
		if w.enemies(me().team, e.team) and e.res_id >= 0 and not w.flying(e) and w.fog.is_visible_ent(w, me().team, e):
			var dd := FX.dist2(e.pos, p)
			if dd < bd:
				bd = dd
				best = e
	return best

func _engaged_enemy(wave_units: Array) -> SimEntity:
	for u: SimEntity in wave_units:
		if u.target != 0:
			var t := w.get_ent(u.target)
			if t != null and t.alive and t.kind == SimEntity.Kind.UNIT and not w.flying(t):
				return t
	return null

# ------------------------------------------------------------------ general powers
func _powers() -> void:
	var p := me()
	for id in Content.powers_for(&"us"):
		if p.points > 0 and PowersSys.can_buy(w, pid, id) == "":
			cmd({"t": "buy_power", "def": String(id)})
			return
	var engaged: Array = []
	for id in bb["wave"]:
		var e := w.get_ent(int(id))
		if e != null and e.target != 0:
			engaged.append(e)
	if PowersSys.ready_in(w, pid, &"us_uav_recon") == 0 and not bb["wave"].is_empty():
		var tgt := _pick_target()
		if tgt.x >= 0:
			cmd({"t": "power", "def": "us_uav_recon", "pos": tgt})
	if engaged.size() >= 4:
		var c := _centroid(engaged)
		var t0 := w.get_ent(engaged[0].target)
		if PowersSys.ready_in(w, pid, &"us_precision_strike") == 0 and t0 != null and _enemy_strength_near(t0.pos, 4) >= 1200:
			cmd({"t": "power", "def": "us_precision_strike", "pos": t0.pos})
		if PowersSys.ready_in(w, pid, &"us_paradrop") == 0:
			cmd({"t": "power", "def": "us_paradrop", "pos": c})
		if PowersSys.ready_in(w, pid, &"us_field_repair") == 0:
			var hurt := 0
			for u: SimEntity in engaged:
				if u.hp * 100 < u.max_hp * 55 and not w.udef(u).tags.has("infantry"):
					hurt += 1
			if hurt >= 3:
				cmd({"t": "power", "def": "us_field_repair", "pos": c})
