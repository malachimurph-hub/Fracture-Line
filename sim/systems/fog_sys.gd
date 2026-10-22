class_name FogSys
## Fog of war and shroud, per team (allies share vision). Reference-counted vision stamps:
## only entities that changed tile are re-stamped, so cost scales with movement (GDD 17.6: 5 Hz).

static func run(w: SimWorld, force: bool) -> void:
	var f := w.fog
	if f.disabled:
		return
	var seen := {}
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.team < 0 or e.kind == SimEntity.Kind.RESOURCE:
			continue
		if e.kind == SimEntity.Kind.UNIT and e.res_id < 0:
			continue
		var sk := str(id)
		if e.kind == SimEntity.Kind.BUILDING and not e.built:
			# sites under construction reveal a small radius
			f.update_stamp(sk, e.team, FX.to_tile(e.pos), 3)
		else:
			f.update_stamp(sk, e.team, FX.to_tile(e.pos), e.sight)
		seen[sk] = true
	for tv in w.temp_vision:
		var key := "tv%d_%d_%d" % [int(tv["until"]), tv["tile"].x, tv["tile"].y]
		f.update_stamp(key, int(tv["team"]), tv["tile"], int(tv["r"]))
		seen[key] = true
	for key in f.stamps.keys():
		if not seen.has(key):
			f.remove_stamp(key)
	_memory(w)

static func _memory(w: SimWorld) -> void:
	var f := w.fog
	for team in f.teams:
		var mem: Dictionary = f.memory[team]
		for id in w.ids:
			var e: SimEntity = w.ents[id]
			if not e.alive or (e.kind != SimEntity.Kind.BUILDING and e.kind != SimEntity.Kind.NEUTRAL):
				continue
			if e.team == team:
				if mem.has(id):
					mem.erase(id)
				continue
			if f.is_visible_ent(w, team, e):
				# only (re)write the memory entry when it changed (def/tile/rot never change)
				var old = mem.get(id)
				if old == null or old["built"] != e.built or old["owner"] != e.owner:
					mem[id] = {"def": e.def_id, "tile": e.tile, "owner": e.owner, "rot": e.rot, "built": e.built, "team": e.team}
		for id in mem.keys():
			var m: Dictionary = mem[id]
			var e2 := w.get_ent(int(id))
			var c: Vector2i = m["tile"]
			if e2 == null and f.visible_tile(team, c):
				mem.erase(id)
