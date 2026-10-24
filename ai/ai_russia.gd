class_name AIRussia
extends AIPlayer
## M3.0 F Russia skirmish AI. Same rules as every AI. Uses the power-economy build planner of
## AIPlayer with Russian structures (roles); no tech centre, support or income structure yet
## (stand-in base, pending Malachi's building list). Infiltrators are capped like US snipers.

func roles() -> Dictionary:
	return {"builder": &"ecc_engineer", "harvester": &"ecc_cargo_truck", "refinery": &"ecc_depot", "power": &"ecc_power",
		"bunker": &"ecc_bunker", "barracks": &"ecc_barracks", "heavy": &"ecc_factory", "motor": &"ecc_factory",
		"tech": &"", "support": &"", "aa_tower": &"ecc_aa_site", "income": &"",
		"mine": &"", "pylon": &""}

func faction() -> StringName:
	return &"ecc"

func _unit_allowed(ud: UnitDef) -> bool:
	if ud.id == &"ecc_infiltrator":
		return _count_type(ud.id) < 1 + combat_units().size() / 12
	if ud.id == &"ecc_msta":
		return _count_type(ud.id) < 2 + combat_units().size() / 10
	return true

func _is_scout_type(u: SimEntity) -> bool:
	return u.def_id == &"ecc_tigr" or u.def_id == &"ecc_rifleman"

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
