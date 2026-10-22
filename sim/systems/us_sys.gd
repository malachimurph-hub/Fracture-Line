class_name UsSys
## M2.5 US mechanics that are not air-related.
##  - Scout Sniper (tag "stealth_still"): hidden from enemies after STILL_TICKS without moving;
##    reuses the M2.4 stealth mask: enemy units within TplaSys.DETECT and detectors in sight see it.
const STILL_TICKS := 40

static func run(w: SimWorld) -> void:
	var dets: Array = []
	var dets_done := false
	for id in w.ids:
		var u: SimEntity = w.ents[id]
		if not u.alive or u.kind != SimEntity.Kind.UNIT or u.res_id < 0:
			continue
		if not w.udef(u).tags.has("stealth_still"):
			continue
		if u.moving or u.goal != MoveSys.NONE:
			u.still = 0
		elif u.still < 10000:
			u.still += 1
		var hide := u.still >= STILL_TICKS
		if hide != u.stealthy:
			u.stealthy = hide
			w.events.append({"t": "stealth", "id": u.id, "on": hide})
		var mask := 0
		if hide:
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
