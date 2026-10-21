class_name SimMap
extends RefCounted
## Tile grid, passability per move layer, building occupancy, and the pathfinder.

enum T { GRASS, ROAD, ROUGH, WATER, FORD, BRIDGE, CLIFF, FOREST }
const CHAR_TO_T := {".": T.GRASS, ":": T.ROAD, ",": T.ROUGH, "~": T.WATER, "=": T.FORD, "#": T.BRIDGE, "^": T.CLIFF, "T": T.FOREST}
const FOOT_OK := [true, true, true, false, true, true, false, true]
const VEH_OK := [true, true, true, false, false, true, false, false]
const BUILD_OK := [true, true, true, false, false, false, false, false]
## speed multiplier percent [foot, vehicle]
const SPEED_PCT := [[100, 100], [100, 115], [90, 70], [0, 0], [70, 0], [100, 100], [0, 0], [80, 0]]

var w: int = 128
var h: int = 128
var tiles: PackedByteArray
var occ: PackedInt32Array            ## building entity id per tile (0 = none)
var nobuild: PackedByteArray         ## 1 near resources
var pf: Pathfinder
## Static vehicle-terrain connectivity (flood fill at load, ignores buildings). 0 = not
## vehicle-passable. Zero Hour lets a dozer build anywhere it can drive to.
var region: PackedInt32Array

func load_from(def: MapDef) -> void:
	w = def.size.x
	h = def.size.y
	tiles = PackedByteArray()
	tiles.resize(w * h)
	occ = PackedInt32Array()
	occ.resize(w * h)
	nobuild = PackedByteArray()
	nobuild.resize(w * h)
	var f := FileAccess.open(def.tiles_path, FileAccess.READ)
	assert(f != null, "map tiles missing: " + def.tiles_path)
	var y := 0
	while not f.eof_reached() and y < h:
		var line := f.get_line()
		if line.length() < w:
			continue
		for x in w:
			tiles[y * w + x] = CHAR_TO_T.get(line[x], T.GRASS)
		y += 1
	pf = Pathfinder.new()
	pf.bind(self)
	pf.setup(self)
	_build_regions()

func _build_regions() -> void:
	region = PackedInt32Array()
	region.resize(w * h)
	var next := 1
	for start in w * h:
		if region[start] != 0 or not VEH_OK[tiles[start]]:
			continue
		var stack := PackedInt32Array([start])
		region[start] = next
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := i % w
			var y := i / w
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var j := ny * w + nx
				if region[j] == 0 and VEH_OK[tiles[j]]:
					region[j] = next
					stack.append(j)
		next += 1

## Vehicle region a building footprint touches (any passable tile on its border ring).
func footprint_regions(t: Vector2i, fp: Vector2i) -> Dictionary:
	var out := {}
	for yy in range(-1, fp.y + 1):
		for xx in range(-1, fp.x + 1):
			if xx >= 0 and yy >= 0 and xx < fp.x and yy < fp.y:
				continue
			var c := Vector2i(t.x + xx, t.y + yy)
			if in_bounds(c):
				var r := region[idx(c)]
				if r != 0:
					out[r] = true
	return out

func idx(t: Vector2i) -> int:
	return t.y * w + t.x

func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < w and t.y < h

func ttype(t: Vector2i) -> int:
	return tiles[idx(t)] if in_bounds(t) else T.CLIFF

func passable(t: Vector2i, vehicle: bool) -> bool:
	if not in_bounds(t):
		return false
	var i := idx(t)
	if occ[i] != 0:
		return false
	return VEH_OK[tiles[i]] if vehicle else FOOT_OK[tiles[i]]

func terrain_passable(t: Vector2i, vehicle: bool) -> bool:
	if not in_bounds(t):
		return false
	var tt := tiles[idx(t)]
	return VEH_OK[tt] if vehicle else FOOT_OK[tt]

func speed_pct(t: Vector2i, vehicle: bool) -> int:
	if not in_bounds(t):
		return 100
	return SPEED_PCT[tiles[idx(t)]][1 if vehicle else 0]

func stamp(tile: Vector2i, fp: Vector2i, id: int) -> void:
	for yy in fp.y:
		for xx in fp.x:
			var t := Vector2i(tile.x + xx, tile.y + yy)
			if in_bounds(t):
				occ[idx(t)] = id
				pf.set_solid(t, true)

func unstamp(tile: Vector2i, fp: Vector2i) -> void:
	for yy in fp.y:
		for xx in fp.x:
			var t := Vector2i(tile.x + xx, tile.y + yy)
			if in_bounds(t):
				occ[idx(t)] = 0
				pf.set_solid(t, false)

func mark_nobuild(center: Vector2i, r: int) -> void:
	for yy in range(-r, r + 1):
		for xx in range(-r, r + 1):
			var t := center + Vector2i(xx, yy)
			if in_bounds(t):
				nobuild[idx(t)] = 1

## Nearest passable tile to t (spiral search), or t if none within maxr.
func nearest_passable(t: Vector2i, vehicle: bool, maxr: int = 12) -> Vector2i:
	if passable(t, vehicle):
		return t
	for r in range(1, maxr + 1):
		var best := Vector2i(-1, -1)
		var bestd := 1 << 30
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if absi(xx) != r and absi(yy) != r:
					continue
				var c := t + Vector2i(xx, yy)
				if passable(c, vehicle):
					var d := xx * xx + yy * yy
					if d < bestd:
						bestd = d
						best = c
		if best.x >= 0:
			return best
	return t
