class_name SimFog
extends RefCounted
var w: int = 128
var h: int = 128
var disabled: bool = false
var teams: Array = []           ## team ids in play
var count: Dictionary = {}      ## team -> PackedInt32Array (vision refcount)
var explored: Dictionary = {}   ## team -> PackedByteArray
var stamps: Dictionary = {}     ## key -> [team, tile, r]
var memory: Dictionary = {}     ## team -> {building id: snapshot}
var version: int = 0            ## bumps when any vision changes (view refresh)
static var _circles: Dictionary = {}

func setup(mw: int, mh: int, nteams: int, p_disabled: bool) -> void:
	w = mw
	h = mh
	disabled = p_disabled
	teams = []
	for t in nteams:
		teams.append(t)
		var c := PackedInt32Array()
		c.resize(w * h)
		count[t] = c
		var ex := PackedByteArray()
		ex.resize(w * h)
		if disabled:
			ex.fill(1)
		explored[t] = ex
		memory[t] = {}

static func circle(r: int) -> PackedInt32Array:
	if _circles.has(r):
		return _circles[r]
	var out := PackedInt32Array()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				out.append(dx)
				out.append(dy)
	_circles[r] = out
	return out

func _apply(team: int, tile: Vector2i, r: int, delta: int) -> void:
	var c: PackedInt32Array = count[team]
	var ex: PackedByteArray = explored[team]
	var off := circle(r)
	var i := 0
	var n := off.size()
	while i < n:
		var x := tile.x + off[i]
		var y := tile.y + off[i + 1]
		i += 2
		if x < 0 or y < 0 or x >= w or y >= h:
			continue
		var k := y * w + x
		c[k] += delta
		if delta > 0:
			ex[k] = 1
	count[team] = c
	explored[team] = ex
	version += 1

func update_stamp(key: String, team: int, tile: Vector2i, r: int) -> void:
	if not count.has(team):
		return
	var s = stamps.get(key)
	if s != null:
		if s[0] == team and s[1] == tile and s[2] == r:
			return
		_apply(s[0], s[1], s[2], -1)
	_apply(team, tile, r, 1)
	stamps[key] = [team, tile, r]

func remove_stamp(key: String) -> void:
	var s = stamps.get(key)
	if s != null:
		_apply(s[0], s[1], s[2], -1)
		stamps.erase(key)

func visible_tile(team: int, t: Vector2i) -> bool:
	if disabled:
		return true
	if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h or not count.has(team):
		return false
	return count[team][t.y * w + t.x] > 0

func explored_tile(team: int, t: Vector2i) -> bool:
	if disabled:
		return true
	if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h:
		return false
	return explored[team][t.y * w + t.x] != 0

func is_visible_ent(sim, team: int, e) -> bool:
	if disabled or e.team == team:
		return true
	if e.kind == SimEntity.Kind.UNIT:
		return visible_tile(team, FX.to_tile(e.pos))
	var t: Vector2i = e.tile
	return visible_tile(team, FX.to_tile(e.pos)) or visible_tile(team, t) or visible_tile(team, t + e.fp - Vector2i.ONE) \
		or visible_tile(team, Vector2i(t.x + e.fp.x - 1, t.y)) or visible_tile(team, Vector2i(t.x, t.y + e.fp.y - 1))

func to_dict() -> Dictionary:
	var mem := {}
	for t in memory:
		mem[t] = memory[t].duplicate(true)
	return {"w": w, "h": h, "disabled": disabled, "teams": teams.duplicate(), "count": count.duplicate(true),
		"explored": explored.duplicate(true), "stamps": stamps.duplicate(true), "memory": mem}

func from_dict(d: Dictionary) -> void:
	w = d["w"]; h = d["h"]; disabled = d["disabled"]; teams = d["teams"]
	count = d["count"]; explored = d["explored"]; stamps = d["stamps"]; memory = d["memory"]
	version += 1
