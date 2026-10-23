class_name WeaponFx
extends Node3D
## Zero Hour-style weapon effects (M2.4), view only. Every sim "fire" event (already timed by
## the M2.3 weapon model: aim, pre-attack, clips, scatter) becomes a visible round that flies
## from the muzzle to the sim's real impact point: misses land on the ground near the target.
## No beams: rounds are short streaks that travel; rockets and missiles fly with smoke trails;
## artillery, mortars and grenades arc; flak bursts in the air; flamers spray a particle stream.
## Rendering is pooled: two StreakLayer MultiMeshes (glowing / solid rounds) plus the shared
## Vfx particle layers, so a battle costs a fixed handful of draw calls.
const CLASSES := {
	# weapon id -> effect class (falls back to the weapon's vfx kind)
	&"eu_tank_cannon": "cannon", &"eu_twin_cannon": "cannon", &"tpla_scrap_cannon": "cannon",
	&"eu_autocannon": "autocannon", &"eu_bunker_cannon": "autocannon",
	&"tpla_hmg": "mg", &"tpla_tunnel_mg": "mg", &"tpla_30mm": "autocannon", &"eu_harvester_mg": "mg",
	&"eu_rifle": "rifle", &"tpla_carbine": "rifle",
	&"eu_gatling": "quad", &"tpla_quad": "autocannon", &"eu_flak": "flak",
	&"eu_lancer_missile": "missile", &"tpla_wasp_missile": "missile",
	&"tpla_rpg": "rocket", &"tpla_mirage_rockets": "salvo", &"tpla_mica": "missile", &"tpla_r73": "missile", &"tpla_buggy_rockets": "salvo",
	&"eu_howitzer": "artillery", &"eu_mortar": "mortar", &"eu_grenade": "grenade",
	&"tpla_rust_shell": "artillery", &"tpla_svd": "rifle", &"tpla_cd_laser": "rifle", &"tpla_f16_bombs": "mortar", &"eu_flamer": "flame",
	# M2.5 United States
	&"us_m16": "rifle", &"us_m4": "rifle", &"us_sniper_rifle": "rifle", &"us_lynx_hmg": "mg", &"us_avenger_mg": "mg",
	&"us_chaingun": "autocannon", &"us_tank_gun": "cannon", &"us_javelin": "missile", &"us_hellfire": "missile",
	&"us_stinger": "missile", &"us_aam": "missile", &"us_sam": "missile", &"us_howitzer": "artillery",
	&"us_firebase_gun": "artillery", &"us_gbu": "mortar",
}
const BY_KIND := {"tracer": "rifle", "tracer_heavy": "mg", "shell": "cannon", "missile": "missile",
	"rocket": "rocket", "rocket_salvo": "salvo", "tracer_quad": "quad", "flak": "flak", "grenade": "grenade",
	"rust_shell": "rust", "flame": "flame", "bomb": "none"}
## Per class: speed (tiles/s, 0 = timed arc), arc (apex height per tile of range), rounds per sim
## shot and gap between them, streak tail length / half width / colour, solid body, muzzle size,
## impact size, smoke trail interval.
const P := {
	"rifle": {"spd": 62.0, "arc": 0.0, "n": 2, "gap": 0.07, "tail": 0.55, "w": 0.018, "col": Color(1.0, 0.93, 0.62), "muz": 0.08, "imp": 0.16},
	"mg": {"spd": 56.0, "arc": 0.0, "n": 3, "gap": 0.055, "tail": 0.75, "w": 0.024, "col": Color(1.0, 0.8, 0.42), "muz": 0.13, "imp": 0.2},
	"quad": {"spd": 64.0, "arc": 0.0, "n": 2, "gap": 0.04, "tail": 0.8, "w": 0.022, "col": Color(1.0, 0.86, 0.5), "muz": 0.12, "imp": 0.2},
	"autocannon": {"spd": 48.0, "arc": 0.0, "n": 1, "gap": 0.0, "tail": 0.9, "w": 0.036, "col": Color(1.0, 0.7, 0.32), "muz": 0.2, "imp": 0.3},
	"cannon": {"spd": 36.0, "arc": 0.02, "n": 1, "gap": 0.0, "tail": 1.1, "w": 0.05, "col": Color(1.0, 0.78, 0.45), "muz": 0.42, "imp": 0.62},
	"flak": {"spd": 42.0, "arc": 0.0, "n": 1, "gap": 0.0, "tail": 0.7, "w": 0.03, "col": Color(1.0, 0.9, 0.7), "muz": 0.2, "imp": 0.45},
	"missile": {"spd": 14.0, "arc": 0.06, "n": 1, "gap": 0.0, "tail": 0.32, "w": 0.05, "col": Color(1.0, 0.82, 0.5), "muz": 0.16, "imp": 0.6, "trail": 0.022},
	"rocket": {"spd": 17.0, "arc": 0.03, "n": 1, "gap": 0.0, "tail": 0.28, "w": 0.045, "col": Color(1.0, 0.68, 0.35), "muz": 0.15, "imp": 0.48, "trail": 0.026},
	"salvo": {"spd": 15.0, "arc": 0.16, "n": 1, "gap": 0.0, "tail": 0.26, "w": 0.04, "col": Color(1.0, 0.66, 0.32), "muz": 0.14, "imp": 0.42, "trail": 0.03},
	"artillery": {"spd": 0.0, "arc": 0.38, "n": 1, "gap": 0.0, "tail": 0.5, "w": 0.04, "col": Color(1.0, 0.72, 0.4), "muz": 0.65, "imp": 1.25, "trail": 0.05, "solid": true},
	"mortar": {"spd": 0.0, "arc": 0.5, "n": 1, "gap": 0.0, "tail": 0.25, "w": 0.035, "col": Color(0.95, 0.75, 0.5), "muz": 0.22, "imp": 0.75, "trail": 0.06, "solid": true},
	"grenade": {"spd": 0.0, "arc": 0.32, "n": 1, "gap": 0.0, "tail": 0.12, "w": 0.03, "col": Color(0.25, 0.27, 0.2), "muz": 0.06, "imp": 0.48, "solid": true},
	"rust": {"spd": 0.0, "arc": 0.42, "n": 1, "gap": 0.0, "tail": 0.3, "w": 0.045, "col": Color(0.72, 0.9, 0.3), "muz": 0.3, "imp": 0.6, "trail": 0.045},
	"spray": {"spd": 0.0, "arc": 0.0, "n": 0, "gap": 0.0, "tail": 0.0, "w": 0.0, "col": Color(0.66, 0.84, 0.25), "muz": 0.0, "imp": 0.3},
	"flame": {"spd": 0.0, "arc": 0.0, "n": 0, "gap": 0.0, "tail": 0.0, "w": 0.0, "col": Color(1.0, 0.55, 0.15), "muz": 0.0, "imp": 0.4},
}
const SMOKE := Color(0.62, 0.6, 0.57)
const DUST := Color("#c2a77e")
const MAX_SHOTS := 360

var world: WorldView
var vfx: Vfx
var glow: StreakLayer
var solid: StreakLayer
var shots: Array = []      ## live rounds (Dictionary each; pooled rendering via the layers)
var queued: Array = []     ## rounds of a burst waiting for their offset [delay, Dictionary]
var flashes: Array = []    ## muzzle tongues [head, tail, w, col, t, life]
var streams: Array = []    ## flame / spray streams [from, to, t, life, kind, acc, hitk]
var stats := {"fired": 0, "rounds": 0, "impacts": 0, "airbursts": 0, "ground_misses": 0, "trail_puffs": 0, "stream_particles": 0}

func setup(w: WorldView, fx: Vfx) -> void:
	world = w
	vfx = fx
	glow = StreakLayer.new()
	glow.setup(420, true)
	add_child(glow)
	solid = StreakLayer.new()
	solid.setup(96, false)
	add_child(solid)

static func class_of(weapon: StringName, kind: String) -> String:
	if CLASSES.has(weapon):
		return CLASSES[weapon]
	return BY_KIND.get(kind, "rifle")

## One sim shot. muzzles: one muzzle point per visual round (squads fire from several soldiers);
## to: the sim impact point (world, ground level); tid / hitk: target id and what was hit
## (0 infantry, 1 vehicle, 2 structure) or -1 for a miss on the ground.
func fire(cls: String, muzzles: Array, dir: Vector3, to: Vector3, tid: int, hitk: int, hit_off: Vector3) -> void:
	var pr: Dictionary = P.get(cls, P["rifle"])
	stats["fired"] += 1
	if cls == "flame" or cls == "spray":
		var m0: Vector3 = muzzles[0]
		streams.append([m0, to + (hit_off if hitk >= 0 else Vector3(0, 0.05, 0)), 0.0, 0.42 if cls == "flame" else 0.36, cls, 0.0, hitk, tid])
		_muzzle(cls, m0, dir, pr)
		return
	var n: int = pr["n"]
	for i in n:
		var m: Vector3 = muzzles[i % muzzles.size()]
		var sh := {"c": cls, "p0": m, "to": to, "tid": tid, "hitk": hitk, "off": hit_off, "t": 0.0, "acc": 0.0,
			"wob": randf() * TAU, "jit": Vector3(randf_range(-0.07, 0.07), randf_range(-0.04, 0.06), randf_range(-0.07, 0.07)) * (0.0 if i == 0 else 1.0)}
		if i == 0:
			_launch(sh, dir)
		else:
			queued.append([pr["gap"] * i, sh, dir])

func _launch(sh: Dictionary, dir: Vector3) -> void:
	var pr: Dictionary = P[sh["c"]]
	var dest := _dest(sh)
	var dist: float = (sh["p0"] as Vector3).distance_to(dest)
	var dur: float
	if float(pr["spd"]) > 0.0:
		dur = maxf(0.03, dist / float(pr["spd"]))
	else:
		match sh["c"]:
			"artillery": dur = clampf(dist / 15.0, 0.5, 0.95)
			"mortar": dur = clampf(dist / 11.0, 0.45, 0.85)
			"rust": dur = clampf(dist / 13.0, 0.4, 0.9)
			_: dur = clampf(dist / 9.0, 0.3, 0.6)
	sh["dur"] = dur
	sh["h"] = float(pr["arc"]) * dist
	sh["L"] = maxf(0.1, dist)
	if shots.size() >= MAX_SHOTS:
		_arrive(sh)   # pool full: resolve at once rather than drop the impact
		return
	shots.append(sh)
	stats["rounds"] += 1
	_muzzle(sh["c"], sh["p0"], dir, pr)

## Where the round is going now: misses fly to their fixed ground point; hits follow the
## target's rendered body so the round lands on it.
func _dest(sh: Dictionary) -> Vector3:
	var to: Vector3 = sh["to"]
	if int(sh["hitk"]) >= 0 and world != null:
		var tv: EntityView = world.views.get(int(sh["tid"]))
		if tv != null and is_instance_valid(tv):
			to = tv.position
		return to + (sh["off"] as Vector3) + (sh["jit"] as Vector3)
	return to + Vector3(0, 0.02, 0) + (sh["jit"] as Vector3) * 2.0

func _pos(sh: Dictionary, u: float) -> Vector3:
	var p0: Vector3 = sh["p0"]
	var p := p0.lerp(_dest(sh), u) + Vector3.UP * float(sh["h"]) * 4.0 * u * (1.0 - u)
	if sh["c"] == "rocket" or sh["c"] == "salvo":
		# unguided: a little corkscrew wobble that settles on the target
		var s := sin(u * 15.0 + float(sh["wob"])) * 0.07 * (1.0 - u)
		p += Vector3(s, absf(s) * 0.3, -s * 0.5)
	elif sh["c"] == "missile":
		var s2 := sin(u * 7.0 + float(sh["wob"])) * 0.04 * (1.0 - u)
		p += Vector3(s2, 0.0, s2)
	return p

## Seconds until the last round in flight toward target id lands (0 = none in flight).
func time_to_hit(id: int) -> float:
	var best := 0.0
	for sh in shots:
		if int(sh["tid"]) == id and int(sh["hitk"]) >= 0:
			best = maxf(best, float(sh["dur"]) - float(sh["t"]))
	for q in queued:
		if int(q[1]["tid"]) == id and int(q[1]["hitk"]) >= 0:
			best = maxf(best, float(q[0]) + 0.2)
	for st in streams:
		if int(st[7]) == id and int(st[6]) >= 0:
			best = maxf(best, float(st[3]) - float(st[2]))
	return best

func active() -> int:
	return shots.size() + streams.size()

func count_class(classes: Array) -> int:
	var c := 0
	for sh in shots:
		if sh["c"] in classes:
			c += 1
	return c

# ------------------------------------------------------------------ muzzle
func _muzzle(cls: String, p: Vector3, dir: Vector3, pr: Dictionary) -> void:
	if vfx == null:
		return
	var d := dir.normalized()
	var s: float = pr["muz"]
	match cls:
		"cannon":
			vfx.muzzle(p, d, s)
			var side := d.cross(Vector3.UP).normalized()
			for sg in [-1.0, 1.0]:   # muzzle brake side jets
				vfx.fire.emit(p + d * 0.05, side * sg * 2.2 + d * 0.6, 0.07, s * 0.45, s * 0.2, Color("#fff1b8"), Color(1.0, 0.5, 0.12, 0.0), 1.0)
			for k in 3:   # lingering gun smoke
				vfx.smoke.emit(p + d * (0.1 + k * 0.15), d * 0.5 + Vector3(randf_range(-0.15, 0.15), 0.35, randf_range(-0.15, 0.15)), 1.6, s * 0.5, s * 2.2, Color(SMOKE, 0.55), Color(SMOKE, 0.0))
			var g := Vector3(p.x, 0.05, p.z) - d * 0.3   # blast kicks up dust under the barrel
			for k in 3:
				vfx.smoke.emit(g + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), Vector3(randf_range(-0.6, 0.6), 0.25, randf_range(-0.6, 0.6)), 0.9, 0.3, 0.9, Color(DUST, 0.45), Color(DUST, 0.0))
			_tongue(p, d, 0.55, 0.11)
		"artillery":
			vfx.muzzle(p, d, s)
			for k in 6:
				vfx.smoke.emit(p + Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2)), Vector3(randf_range(-0.8, 0.8), randf_range(0.4, 1.0), randf_range(-0.8, 0.8)), 2.2, s * 0.5, s * 2.4, Color(SMOKE, 0.6), Color(SMOKE, 0.0))
			for k in 6:
				var a := k * TAU / 6.0
				vfx.smoke.emit(Vector3(p.x, 0.06, p.z) + Vector3(cos(a), 0, sin(a)) * 0.3, Vector3(cos(a), 0.12, sin(a)) * 1.6, 1.1, 0.35, 1.1, Color(DUST, 0.5), Color(DUST, 0.0))
			_tongue(p, d, 0.8, 0.14)
		"missile", "rocket", "salvo":
			vfx.fire.emit(p, d * 1.5, 0.08, s * 0.9, s * 0.4, Color("#fff1b8"), Color(1.0, 0.55, 0.15, 0.0), 1.0)
			for k in 3:   # back-blast
				vfx.smoke.emit(p - d * (0.25 + k * 0.18), -d * 1.4 + Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3)), 1.3, 0.14, 0.6, Color(0.8, 0.78, 0.74, 0.55), Color(0.8, 0.78, 0.74, 0.0))
		"mortar", "rust":
			vfx.muzzle(p, Vector3(d.x * 0.3, 1.0, d.z * 0.3).normalized(), s)
		"grenade":
			vfx.smoke.emit(p, d * 0.4 + Vector3(0, 0.3, 0), 0.5, 0.06, 0.25, Color(SMOKE, 0.4), Color(SMOKE, 0.0))
		"flame":
			vfx.fire.emit(p, d * 1.0, 0.1, 0.12, 0.2, Color("#ffd27a"), Color(1.0, 0.4, 0.1, 0.0), 1.0)
		"spray":
			pass
		_:
			# small arms, MGs, autocannons, flak: a flash and a forward tongue, no casings
			for k in 2:
				vfx.fire.emit(p + d * (0.04 + k * 0.07), d * 1.2, 0.05, s * (1.0 - k * 0.3), s * 0.3, Color("#fff1b8"), Color(1.0, 0.6, 0.2, 0.0), 1.0)
			if s >= 0.13:
				vfx.smoke.emit(p + d * 0.1, d * 0.4 + Vector3(0, 0.3, 0), 0.5, s * 0.4, s * 1.4, Color(SMOKE, 0.3), Color(SMOKE, 0.0))
			_tongue(p, d, s * 2.2, s * 0.32)

func _tongue(p: Vector3, d: Vector3, len: float, w: float) -> void:
	flashes.append([p + d * len, p, w, Color(1.0, 0.85, 0.5, 1.0), 0.0, 0.05 + w * 0.2])

# ------------------------------------------------------------------ impacts
func _arrive(sh: Dictionary) -> void:
	stats["impacts"] += 1
	var p := _dest(sh)
	var hitk: int = sh["hitk"]
	var cls: String = sh["c"]
	var pr: Dictionary = P[cls]
	if hitk < 0:
		stats["ground_misses"] += 1
	_impact(cls, p, hitk, float(pr["imp"]))

func _impact(cls: String, p: Vector3, hitk: int, s: float) -> void:
	if vfx == null:
		return
	var ground := Vector3(p.x, 0.04, p.z)
	match cls:
		"rifle", "mg", "quad", "autocannon":
			if hitk == 1 or hitk == 2:   # rounds striking armour / walls: sparks, a little grit
				vfx.sparks(p, Vector3.ZERO, 3 if cls == "rifle" else 5, 1.2)
				if hitk == 1 and randf() < 0.35:
					AudioDirector.sfx("hit_metal", p, -9.0, 0.15)
				vfx.fire.emit(p, Vector3.ZERO, 0.04, s * 0.5, s * 0.2, Color("#fff4d0"), Color(1, 0.6, 0.2, 0), 1.0)
				if hitk == 2:
					vfx.smoke.emit(p, Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2)), 0.6, s * 0.4, s * 1.2, Color(0.7, 0.68, 0.64, 0.5), Color(0.7, 0.68, 0.64, 0.0))
			else:   # dust puffs where rounds hit the ground (or the dirt around a squad)
				vfx.smoke.emit(ground, Vector3(randf_range(-0.2, 0.2), 0.7, randf_range(-0.2, 0.2)), 0.55, s * 0.35, s * 1.5, Color(DUST, 0.7), Color(DUST, 0.0))
				if randf() < 0.5:
					vfx.debris.emit(ground, Vector3(randf_range(-0.6, 0.6), randf_range(1.2, 2.2), randf_range(-0.6, 0.6)), 0.6, 0.02, 0.02, Color("#6b5a44"), Color("#5a4a38"))
			if cls == "autocannon":
				vfx.fire.emit(p, Vector3(0, 0.3, 0), 0.08, s * 0.6, s * 0.3, Color("#ffe3a0"), Color(1, 0.5, 0.1, 0), 1.0)
		"flak":
			# airburst above the target: flash, black puff, fragments raining down
			stats["airbursts"] += 1
			var b := p + Vector3(randf_range(-0.25, 0.25), randf_range(0.55, 1.0), randf_range(-0.25, 0.25))
			vfx.flak_burst(b)
			vfx.sparks(b, Vector3(0, -1.0, 0), 5, 1.4)
			vfx.smoke.emit(ground, Vector3(0, 0.3, 0), 0.6, 0.12, 0.4, Color(DUST, 0.4), Color(DUST, 0.0))
		"rust":
			vfx.fire.emit(p, Vector3.ZERO, 0.1, s * 0.6, s * 0.2, Color("#e4ff9a"), Color(0.5, 0.8, 0.2, 0.0), 1.0)
			for k in 6:
				vfx.smoke.emit(ground, Vector3(randf_range(-1, 1), randf_range(0.4, 1.0), randf_range(-1, 1)), 1.4, s * 0.4, s * 1.4, Color(0.62, 0.75, 0.23, 0.65), Color(0.45, 0.5, 0.2, 0.0))
			vfx.spark_layer.emit(p, Vector3(0, 2.0, 0), 0.4, 0.06, 0.03, Color(0.7, 0.9, 0.3), Color(0.4, 0.6, 0.1, 0.0), 1.0)
			vfx.decal(ground, s * 0.6, 0)
		_:
			# explosive rounds: fireball, smoke, debris and a scorch / crater
			var es := s
			if hitk == 1:   # on armour: tighter, sparkier
				vfx.sparks(p, Vector3(0, 0.5, 0), 6, 1.8)
			var ep := ground if hitk < 0 or hitk == 0 else p - Vector3(0, 0.3, 0)
			vfx.explosion(ep, es)
			if hitk < 0 or cls in ["artillery", "mortar"]:
				# shell into dirt: a spray of soil and a dust ring
				for k in int(4 + es * 6):
					vfx.debris.emit(ground, Vector3(randf_range(-1.6, 1.6), randf_range(2.5, 5.0), randf_range(-1.6, 1.6)) * sqrt(es), 1.4, randf_range(0.03, 0.07) * sqrt(es), 0.04, Color("#6b5a44"), Color("#4f4234"))
				for k in 3:
					vfx.smoke.emit(ground, Vector3(randf_range(-0.5, 0.5), randf_range(1.2, 2.2), randf_range(-0.5, 0.5)) * es, 1.6, es * 0.4, es * 1.6, Color(0.55, 0.47, 0.37, 0.7), Color(DUST, 0.0))
			if cls == "artillery":
				vfx.decal(ground, es * 1.1, 1)
			var key := "expl_large" if cls == "artillery" else "expl_small"
			AudioDirector.sfx(key, p, -4.0 if cls != "artillery" else -1.0, 0.12)

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	# bursts: later rounds of a sim shot leave on their offset
	if not queued.is_empty():
		var kq: Array = []
		for q in queued:
			q[0] -= delta
			if q[0] <= 0.0:
				_launch(q[1], q[2])
			else:
				kq.append(q)
		queued = kq
	glow.begin()
	solid.begin()
	var keep: Array = []
	for sh in shots:
		sh["t"] += delta
		var dur: float = sh["dur"]
		var u := clampf(float(sh["t"]) / dur, 0.0, 1.0)
		if u >= 1.0:
			_arrive(sh)
			continue
		keep.append(sh)
		var cls: String = sh["c"]
		var pr: Dictionary = P[cls]
		var head := _pos(sh, u)
		var tu := maxf(0.0, u - float(pr["tail"]) / float(sh["L"]))
		var tail := _pos(sh, tu)
		if pr.get("solid", false):
			solid.put(head, tail, float(pr["w"]), Color(0.16, 0.15, 0.14, 1.0), 0.0)
			if cls != "grenade":
				glow.put(head, head.lerp(tail, 0.5), float(pr["w"]) * 0.7, Color(pr["col"], 0.45), 0.5)
		else:
			glow.put(head, tail, float(pr["w"]), pr["col"], 2.0)
			if cls in ["missile", "rocket", "salvo"]:
				# motor flare at the head
				glow.put(head + (head - tail).normalized() * 0.02, head - (head - tail).normalized() * 0.1, float(pr["w"]) * 1.8, Color(1.0, 0.9, 0.65, 1.0), 3.0)
		if pr.has("trail") and vfx != null:
			sh["acc"] += delta
			var ti: float = pr["trail"]
			while float(sh["acc"]) >= ti:
				sh["acc"] -= ti
				stats["trail_puffs"] += 1
				if cls == "missile":
					vfx.smoke.emit(tail, Vector3(randf_range(-0.08, 0.08), 0.12, randf_range(-0.08, 0.08)), 1.5, 0.07, 0.42, Color(0.9, 0.89, 0.86, 0.7), Color(0.85, 0.84, 0.8, 0.0))
				elif cls == "rust":
					vfx.smoke.emit(tail, Vector3(0, 0.1, 0), 0.9, 0.06, 0.25, Color(0.7, 0.85, 0.3, 0.5), Color(0.5, 0.6, 0.2, 0.0))
				elif cls in ["rocket", "salvo"]:
					vfx.smoke.emit(tail, Vector3(randf_range(-0.1, 0.1), 0.15, randf_range(-0.1, 0.1)), 1.1, 0.07, 0.36, Color(0.72, 0.7, 0.66, 0.65), Color(0.6, 0.58, 0.55, 0.0))
				else:
					vfx.smoke.emit(tail, Vector3(0, 0.05, 0), 0.6, 0.04, 0.16, Color(0.7, 0.7, 0.68, 0.35), Color(0.7, 0.7, 0.68, 0.0))
	shots = keep
	# muzzle tongues
	var kf: Array = []
	for f in flashes:
		f[4] += delta
		if f[4] < f[5]:
			var a: float = 1.0 - f[4] / f[5]
			glow.put(f[0], f[1], f[2] * (0.6 + 0.4 * a), Color(f[3], a), 2.5)
			kf.append(f)
	flashes = kf
	# flame / spray streams
	var ks: Array = []
	for st in streams:
		st[2] += delta
		st[5] += delta
		var from: Vector3 = st[0]
		var to: Vector3 = st[1]
		var tid: int = st[7]
		if int(st[6]) >= 0 and world != null:
			var tv: EntityView = world.views.get(tid)
			if tv != null and is_instance_valid(tv):
				to = tv.position + Vector3(0, 0.3, 0)
		var dist := from.distance_to(to)
		var spd := 9.0
		while st[5] >= 0.018 and vfx != null:
			st[5] -= 0.018
			stats["stream_particles"] += 1
			var v := (to - from) / maxf(0.05, dist) * spd + Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.5), randf_range(-0.35, 0.35))
			var life := dist / spd
			if st[4] == "flame":
				vfx.fire.emit(from, v, life * randf_range(0.9, 1.15), 0.08, 0.4, Color("#ffe08a"), Color(1.0, 0.3, 0.05, 0.0), 1.0)
				if randf() < 0.25:
					vfx.smoke.emit(from.lerp(to, 0.8), v * 0.2 + Vector3(0, 0.8, 0), 1.0, 0.2, 0.7, Color(0.2, 0.18, 0.16, 0.5), Color(0.3, 0.28, 0.26, 0.0))
			else:
				vfx.spark_layer.emit(from, v + Vector3(0, 0.5 * life * 9.0, 0) * 0.5, life * 1.05, 0.05, 0.08, Color(0.72, 0.9, 0.3, 0.9), Color(0.5, 0.7, 0.15, 0.0), 0.3)
		if st[2] >= st[3]:
			if vfx != null:
				if st[4] == "flame":
					for k in 3:
						vfx.fire.emit(to + Vector3(randf_range(-0.2, 0.2), -0.1, randf_range(-0.2, 0.2)), Vector3(0, 1.0, 0), 0.5, 0.25, 0.1, Color("#ffb347"), Color(0.9, 0.25, 0.05, 0.0), 1.0)
					vfx.decal(Vector3(to.x, 0.04, to.z), 0.45, 0)
				else:
					for k in 3:
						vfx.smoke.emit(Vector3(to.x, 0.06, to.z), Vector3(randf_range(-0.4, 0.4), 0.4, randf_range(-0.4, 0.4)), 1.2, 0.2, 0.7, Color(0.62, 0.75, 0.23, 0.6), Color(0.45, 0.5, 0.2, 0.0))
			stats["impacts"] += 1
			continue
		ks.append(st)
	streams = ks
	glow.end()
	solid.end()
