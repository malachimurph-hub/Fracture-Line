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
	if not me().eliminated and _every("t_drone", 30):
		_drones()

## M3.2 Drone Operators: launch a bomb drone when enemy vehicles / infantry are near, and send
## idle bomb drones at the closest visible enemy (preferring vehicles). Scout drones are player-only.
func _drones() -> void:
	var team := me().team
	for u: SimEntity in my_ents(SimEntity.Kind.UNIT):
		var d: UnitDef = w.udef(u)
		if d.tags.has("drone_operator") and u.res_id >= 0 and w.drone_wait(u, "bomb") == 0 and _enemy_strength_near(FX.to_tile(u.pos), 12) > 0:
			cmd({"t": "drone", "ids": [u.id], "kind": "bomb"})
		elif d.tags.has("drone") and d.tags.has("suicide") and u.target <= 0 and u.orders.is_empty():
			var best: SimEntity = null
			var bd := 1 << 60
			for id in w.ids:
				var e: SimEntity = w.ents[id]
				if not e.alive or e.kind != SimEntity.Kind.UNIT or not w.enemies(team, e.team) or w.flying(e) or not w.fog.is_visible_ent(w, team, e):
					continue
				var dd := FX.dist2(u.pos, e.pos) / (4 if w.is_vehicle(e) else 1)
				if dd < bd:
					bd = dd
					best = e
			if best != null:
				cmd({"t": "attack", "ids": [u.id], "target": best.id})

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
