class_name IncomePopups
extends RefCounted
## M3.4 (Malachi: "For all passive income buildings, have the amount it generates pop up and
## fade like supply trucks do"). View only: works out, from the sim's state after each economy
## second, what each of the local player's income structures earned (the same rules as
## EconSys.run: up to 4 copies of a type pay, low power halves, Logistics doubles; captured
## pumps), adds it up per structure and hands back a "+$N" popup every WINDOW_S seconds per
## structure (staggered by id so a base does not flash all at once). The lump-sum mine pays
## through its own "income" event (match.gd) and is skipped here. One pass over the entities
## per sim second; the popups are the overlay's drawn floaters (no nodes).
const WINDOW_S := 10
const MAX_FLOATERS := 40   ## WorldOverlay keeps at most this many popups alive
var acc := {}              ## structure id -> $ earned since its last popup (float)

## Did the economy run on the tick that just ended? (EconSys runs at tick % 20 == 0, then +1.)
static func econ_ran(w: SimWorld) -> bool:
	return w.tick > 0 and (w.tick - 1) % FX.TICK_HZ == 0

## What pid's income structures look like to the economy right now (call on the tick before
## it runs: power and pack-up states change later in the same tick).
static func snapshot(w: SimWorld, pid: int) -> Dictionary:
	var by_def := {}    ## def id -> [ids]
	var pumps: Array = []
	if pid < 0 or pid >= w.players.size() or w.players[pid].eliminated:
		return {}
	var p: SimPlayer = w.players[pid]
	for id in w.ids:
		var e: SimEntity = w.ents[id]
		if not e.alive or e.owner != pid:
			continue
		if e.kind == SimEntity.Kind.BUILDING and e.built and e.powered:
			var d: BuildingDef = w.bdef(e)
			if d.passive_income > 0 or (d.income_amount > 0 and d.income_period_s > 0 and not d.tags.has("income_burst") and not (e.aux_t > 0 and d.tags.has("mobile"))):
				if not by_def.has(d.id):
					by_def[d.id] = []
				by_def[d.id].append(id)
		elif e.kind == SimEntity.Kind.NEUTRAL and w.bdef(e).capture_income > 0:
			pumps.append([id, w.bdef(e).capture_income])
	return {"tick": w.tick, "by_def": by_def, "pumps": pumps, "low": p.low_power, "boost": p.logistics_until > w.tick}

## Each structure's share of what the economy pays in the second the snapshot was taken for
## (integer rules as in EconSys.run): {id: $ float}.
static func pay_out(snap: Dictionary) -> Dictionary:
	var out := {}
	if snap.is_empty():
		return out
	var sec: int = int(snap["tick"]) / FX.TICK_HZ
	var low: bool = snap["low"]
	var hub_raw := {}
	var hub_sum := 0
	var pay := {}
	for did in snap["by_def"]:
		var d: BuildingDef = Content.building(did)
		var n := mini(4, (snap["by_def"][did] as Array).size())
		if d.passive_income > 0:
			hub_raw[did] = d.passive_income * n
			hub_sum += d.passive_income * n
		else:
			var pp := EconSys.period_pay(d, n, sec)
			if low and not d.tags.has("no_power"):
				pp /= 2
			pay[did] = float(pp)
	var hub_paid := hub_sum / 2 if low else hub_sum   # the sim halves the hubs' total
	for did in hub_raw:
		pay[did] = float(hub_paid) * float(hub_raw[did]) / float(maxi(1, hub_sum))
	var k := 2.0 if snap["boost"] else 1.0
	for did in pay:
		var ids: Array = snap["by_def"][did]
		for id in ids:
			out[id] = pay[did] * k / float(ids.size())
	for pu in snap["pumps"]:
		out[pu[0]] = float(pu[1])
	return out

## What each of pid's income structures earned in the economy second that just ran, from the
## current state (tests / one-off use; step() uses the snapshot taken just before).
static func shares(w: SimWorld, pid: int) -> Dictionary:
	var s := snapshot(w, pid)
	if not s.is_empty():
		s["tick"] = w.tick - 1
	return pay_out(s)

var _snap := {}
var last := {}   ## the shares of the last economy second (tests)

## Call after every sim tick; returns the popups due now: [[entity, amount]].
func step(w: SimWorld, pid: int) -> Array:
	var due: Array = []
	if w.tick % FX.TICK_HZ == 0:
		_snap = snapshot(w, pid)   # the economy runs on this tick, before power is re-solved
	if not econ_ran(w):
		return due
	var sec := (w.tick - 1) / FX.TICK_HZ
	var sh := pay_out(_snap) if not _snap.is_empty() and int(_snap["tick"]) == w.tick - 1 else shares(w, pid)
	last = sh
	for id in sh:
		acc[id] = float(acc.get(id, 0.0)) + float(sh[id])
	for id in acc.keys():
		var e: SimEntity = w.get_ent(id)
		if e == null or not e.alive or e.owner != pid:
			acc.erase(id)
			continue
		if (sec + id) % WINDOW_S == WINDOW_S - 1:
			var amt := roundi(float(acc[id]))
			acc[id] = float(acc[id]) - float(amt)
			if amt >= 1:
				due.append([e, amt])
	return due
