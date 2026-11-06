class_name ZeusSys
## M4.4 ZEUS. A Launch Station fires six missiles, 0.4 s apart, at enemies standing inside
## any friendly Zeus Pylon. The salvo then recharges for 30 s. When several targets are in
## the pylons, successive missiles pick different ones.

const SALVO := 6
const GAP := 8             ## ticks between missiles (0.4 s)
const RECHARGE := 600      ## 30 s at 20 Hz
const WEAPON := &"us_zeus_missile"

static func run(w: SimWorld) -> void:
	for id in w.ids:
		var b: SimEntity = w.ents[id]
		if not b.alive or b.kind != SimEntity.Kind.BUILDING or not b.built:
			continue
		if not Content.btag(b.def_id, "zeus_launcher"):
			continue
		if not b.powered or w.players[b.owner].low_power:
			continue
		if b.phase > 0:
			if w.tick >= b.phase_t:
				_shot(w, b)
				b.phase -= 1
				b.phase_t = w.tick + GAP
				b.still += 1
		elif w.tick >= b.air_t and (w.tick + b.id) % 10 == 0:
			if not _targets(w, b).is_empty():
				b.phase = SALVO
				b.phase_t = w.tick
				b.air_t = w.tick + RECHARGE

static func _shot(w: SimWorld, b: SimEntity) -> void:
	var tgts := _targets(w, b)
	if tgts.is_empty():
		return
	var t: SimEntity = tgts[b.still % tgts.size()]
	var wd: WeaponDef = Content.weapon(WEAPON)
	if wd == null:
		return
	CombatSys.fire(w, b, t, wd, 100)

## Enemies whose centre lies inside a friendly pylon disc. The pylon is the sensor, so fog
## does not hide a target that is standing in the ring.
static func _targets(w: SimWorld, launcher: SimEntity) -> Array:
	var zones: Array = []
	for id in w.ids:
		var p: SimEntity = w.ents[id]
		if p.alive and p.kind == SimEntity.Kind.BUILDING and p.built and p.owner == launcher.owner and Content.btag(p.def_id, "zeus_pylon"):
			zones.append(p)
	if zones.is_empty():
		return []
	var out: Array = []
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or not w.enemies(launcher.team, e.team):
			continue
		if e.kind == SimEntity.Kind.RESOURCE or e.kind == SimEntity.Kind.CRATE:
			continue
		if e.kind == SimEntity.Kind.UNIT and e.res_id < 0:
			continue
		if _in_zones(w, e, zones):
			out.append(e)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out

static func _in_zones(w: SimWorld, e: SimEntity, zones: Array) -> bool:
	for p: SimEntity in zones:
		var r: int = w.bdef(p).aux_radius * FX.ONE
		if FX.dist2(e.pos, p.pos) <= r * r:
			return true
	return false
