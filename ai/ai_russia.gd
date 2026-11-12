class_name AIRussia
extends AIPlayer
## Russia skirmish AI. Ministry of Defense is the tech building. The Black Market is the hacker
## hub (still the income-role slot, it no longer pays a wage). FSB GRU is added once the
## Ministry is up. Airfield jets fly sorties through the shared air layer.

func roles() -> Dictionary:
	return {"builder": &"ecc_engineer", "harvester": &"ecc_cargo_truck", "refinery": &"ecc_depot", "power": &"ecc_power",
		"bunker": &"ecc_bunker", "barracks": &"ecc_barracks", "heavy": &"ecc_factory", "motor": &"ecc_factory",
		"tech": &"ecc_ministry", "support": &"", "aa_tower": &"ecc_aa_site", "income": &"ecc_black_market",
		"mine": &"", "pylon": &""}

func faction() -> StringName:
	return &"ecc"

func _unit_allowed(ud: UnitDef) -> bool:
	if ud.air_slots > 0:
		return _air_slot_ok(ud)
	# keep the pop for armour: the Barracks trains faster than the Vehicle Factory builds, so
	# without a cap the army fills with infantry that melts against defences (M3.0 F test).
	if ud.tags.has("infantry"):
		var inf := 0
		var all := combat_units()
		for u: SimEntity in all:
			if w.udef(u).tags.has("infantry"):
				inf += 1
		if inf >= maxi(8, all.size() * 2 / 5):
			return false
	if ud.id == &"ecc_msta" or ud.id == &"ecc_tos" or ud.id == &"ecc_iskander":
		return _count_type(ud.id) < 2 + combat_units().size() / 10
	if ud.id == &"ecc_reaper":
		return _count_type(ud.id) < 2
	if ud.id == &"ecc_alfa" or ud.id == &"ecc_spetsnaz" or ud.id == &"ecc_vdv":
		return _count_type(ud.id) < 1 + combat_units().size() / 12
	return true

func _is_scout_type(u: SimEntity) -> bool:
	return u.def_id == &"ecc_tigr"

## Researched towers, Red Dawn and the Black Market hacks. One action per think.
func _ecc_ops() -> void:
	var p := me()
	if p.supply > 1600:
		for b: SimEntity in my_ents(SimEntity.Kind.BUILDING):
			if not b.built or EccSys.tower_of(b) != "":
				continue
			var kind := ""
			if p.upgrades.has("ecc_up_tower_aa") and b.def_id == &"ecc_power":
				kind = "aa"
			elif p.upgrades.has("ecc_up_tower_at") and b.def_id in [&"ecc_factory", &"ecc_bunker"]:
				kind = "at"
			elif p.upgrades.has("ecc_up_tower_bal"):
				kind = "bal"
			if kind != "" and EccSys.can_install(w, pid, b, kind) == "":
				cmd({"t": "tower", "target": b.id, "def": kind})
				return
	for b2: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if b2.built and b2.def_id == &"ecc_ministry" and b2.powered and EccSys.ready_in(w, pid, "ecc_red_dawn") == 0:
			var drop := _pick_target()
			if drop.x >= 0:
				cmd({"t": "red_dawn", "ids": [b2.id], "pos": drop})
				return
	var hub: SimEntity = null
	for b3: SimEntity in my_ents(SimEntity.Kind.BUILDING):
		if b3.built and b3.powered and b3.def_id == &"ecc_black_market":
			hub = b3
			break
	if hub == null:
		return
	var veh: SimEntity = null
	var mark: SimEntity = null
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or not w.enemies(me().team, e.team):
			continue
		if e.kind == SimEntity.Kind.UNIT and e.res_id >= 0 and w.fog.is_visible_ent(w, me().team, e) and EccSys.hijack_ok(w, e):
			veh = e
		elif e.kind == SimEntity.Kind.BUILDING and e.built and (w.fog.is_visible_ent(w, me().team, e) or w.fog.memory.get(me().team, {}).has(e.id)):
			mark = e
	if veh != null and EccSys.ready_in(w, pid, "ecc_hack_hijack") == 0:
		cmd({"t": "hack", "ids": [hub.id], "target": veh.id, "def": "hijack"})
	elif mark != null and EccSys.ready_in(w, pid, "ecc_hack_power") == 0:
		cmd({"t": "hack", "ids": [hub.id], "target": mark.id, "def": "power"})
	elif mark != null and not bb["wave"].is_empty() and EccSys.ready_in(w, pid, "ecc_hack_radar") == 0:
		cmd({"t": "hack", "ids": [hub.id], "target": mark.id, "def": "radar"})
	elif mark != null and EccSys.ready_in(w, pid, "ecc_hack_funds") == 0:
		cmd({"t": "hack", "ids": [hub.id], "target": mark.id, "def": "funds"})

# ------------------------------------------------------------------ general powers
func _powers() -> void:
	var p := me()
	for id in Content.powers_for(&"ecc"):
		if p.points > 0 and PowersSys.can_buy(w, pid, id) == "":
			cmd({"t": "buy_power", "def": String(id)})
			return
	if PowersSys.ready_in(w, pid, &"ecc_logistics") == 0:
		cmd({"t": "power", "def": "ecc_logistics", "pos": base_pos()})
	var engaged: Array = []
	for id in bb["wave"]:
		var e := w.get_ent(int(id))
		if e != null and e.target != 0:
			engaged.append(e)
	if PowersSys.ready_in(w, pid, &"ecc_recon") == 0 and not bb["wave"].is_empty():
		var tgt := _pick_target()
		if tgt.x >= 0:
			cmd({"t": "power", "def": "ecc_recon", "pos": tgt})
	if engaged.size() >= 4:
		var c := _centroid(engaged)
		var t0 := w.get_ent(engaged[0].target)
		if PowersSys.ready_in(w, pid, &"ecc_strike") == 0 and t0 != null and _enemy_strength_near(t0.pos, 4) >= 1200:
			cmd({"t": "power", "def": "ecc_strike", "pos": t0.pos})
		if PowersSys.ready_in(w, pid, &"ecc_repair") == 0:
			var hurt := 0
			for u: SimEntity in engaged:
				if u.hp * 100 < u.max_hp * 55 and not w.udef(u).tags.has("infantry"):
					hurt += 1
			if hurt >= 3:
				cmd({"t": "power", "def": "ecc_repair", "pos": c})
