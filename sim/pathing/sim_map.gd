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
## Same for foot builders (TPLA Laborers walk through forest and fords).
var foot_region: PackedInt32Array
## M3.3 Phase 3 (17) elevation: ground height at every tile corner in milli-units, built in
## integers from MapDef.hills so every device gets the same numbers. 0 everywhere on maps
## without hills (all maps before M3.3), and always 0 at the water's edge.
var elev: PackedInt32Array
## Vehicle slow-down per tile from the steepest corner-to-corner rise (percent, 0..SLOPE_MAX).
var slope: PackedByteArray
var has_elev := false
const SLOPE_MAX := 20          ## steepest slopes cost vehicles 20% speed
const SLOPE_DIV := 12          ## mm of rise per tile for each 1% slow-down
const ELEV_CAP := 3200         ## mm

func load_from(def: MapDef) -> void:
	w = def.size.x
	h = def.size.y
	tiles = PackedByteArray()
	tiles.resize(w * h)
	occ = PackedInt32Array()
	occ.resize(w * h)
	nobuild = PackedByteArray()
	nobuild.resize(w * h)
	# M2.8: custom maps carry their grid in memory (MapDef.tiles_text)
	var lines := PackedStringArray()
	if def.tiles_text != "":
		lines = def.tiles_text.split("\n", false)
	else:
		var f := FileAccess.open(def.tiles_path, FileAccess.READ)
		assert(f != null, "map tiles missing: " + def.tiles_path)
		while not f.eof_reached():
			lines.append(f.get_line())
	var y := 0
	for line in lines:
		if y >= h:
			break
		if line.length() < w:
			continue
		for x in w:
			tiles[y * w + x] = CHAR_TO_T.get(line[x], T.GRASS)
		y += 1
	pf = Pathfinder.new()
	pf.bind(self)
	pf.setup(self)
	_build_regions()
	build_elevation(def.hills)

## hills: [[centre_x, centre_y, radius, height_mm], ...] (tiles; height may be negative for a
## hollow). Each is a smooth bump (1 - d^2/r^2)^2, summed and clamped. Corners that touch water,
## a ford or a bridge stay at 0 so rivers keep their banks.
func build_elevation(hills: Array) -> void:
	elev = PackedInt32Array()
	elev.resize((w + 1) * (h + 1))
	slope = PackedByteArray()
	slope.resize(w * h)
	has_elev = not hills.is_empty()
	if not has_elev:
		return
	for hl in hills:
		var cx := int(hl[0])
		var cy := int(hl[1])
		var r := maxi(2, int(hl[2]))
		var hm := int(hl[3])
		var r2 := r * r
		for y in range(maxi(0, cy - r), mini(h, cy + r) + 1):
			for x in range(maxi(0, cx - r), mini(w, cx + r) + 1):
				var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
				if d2 >= r2:
					continue
				var u := 1024 - d2 * 1024 / r2
				elev[y * (w + 1) + x] += hm * (u * u / 1024) / 1024
	for y in h + 1:
		for x in w + 1:
			var k := y * (w + 1) + x
			var v := clampi(elev[k], -ELEV_CAP, ELEV_CAP)
			for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var tt := ttype(Vector2i(x, y) + d) if in_bounds(Vector2i(x, y) + d) else T.GRASS
				if tt == T.WATER or tt == T.FORD or tt == T.BRIDGE:
					v = 0
			elev[k] = v
	for y in h:
		for x in w:
			var a := elev[y * (w + 1) + x]
			var b := elev[y * (w + 1) + x + 1]
			var c := elev[(y + 1) * (w + 1) + x]
			var d := elev[(y + 1) * (w + 1) + x + 1]
			var rise := maxi(maxi(absi(a - b), absi(c - d)), maxi(absi(a - c), absi(b - d)))
			slope[y * w + x] = mini(SLOPE_MAX, rise / SLOPE_DIV)

## Ground height (world units) at a point in tile space, bilinear over the corner heights.
func height_at(x: float, z: float) -> float:
	if not has_elev:
		return 0.0
	var fx := clampf(x, 0.0, float(w) - 0.001)
	var fz := clampf(z, 0.0, float(h) - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var k := iz * (w + 1) + ix
	var a := lerpf(float(elev[k]), float(elev[k + 1]), tx)
	var b := lerpf(float(elev[k + w + 1]), float(elev[k + w + 2]), tx)
	return lerpf(a, b, tz) * 0.001

func corner_height(x: int, y: int) -> float:
	return float(elev[clampi(y, 0, h) * (w + 1) + clampi(x, 0, w)]) * 0.001 if has_elev else 0.0

func _build_regions() -> void:
	region = _flood(VEH_OK)
	foot_region = _flood(FOOT_OK)

func _flood(ok: Array) -> PackedInt32Array:
	var region := PackedInt32Array()
	region.resize(w * h)
	var next := 1
	for start in w * h:
		if region[start] != 0 or not ok[tiles[start]]:
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
				if region[j] == 0 and ok[tiles[j]]:
					region[j] = next
					stack.append(j)
		next += 1
	return region

## Region of a tile for a move layer; if the tile itself is not passable (a unit standing
## on a building edge, a seam, a bridge end) the nearest passable tile within 3 is used.
func region_near(t: Vector2i, foot: bool) -> int:
	var reg := foot_region if foot else region
	for r in 4:
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if maxi(absi(xx), absi(yy)) != r:
					continue
				var c := t + Vector2i(xx, yy)
				if in_bounds(c) and reg[idx(c)] != 0:
					return reg[idx(c)]
	return 0

## Regions (vehicle, or foot) a building footprint touches (any passable tile on its border ring).
func footprint_regions(t: Vector2i, fp: Vector2i, foot: bool = false) -> Dictionary:
	var reg := foot_region if foot else region
	var out := {}
	for yy in range(-1, fp.y + 1):
		for xx in range(-1, fp.x + 1):
			if xx >= 0 and yy >= 0 and xx < fp.x and yy < fp.y:
				continue
			var c := Vector2i(t.x + xx, t.y + yy)
			if in_bounds(c):
				var r := reg[idx(c)]
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
	var i := idx(t)
	if vehicle and has_elev:   # M3.3 P3 (17): vehicles slow a little on slopes
		return SPEED_PCT[tiles[i]][1] * (100 - slope[i]) / 100
	return SPEED_PCT[tiles[i]][1 if vehicle else 0]

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
