class_name FX
## Fixed-point helpers for the deterministic simulation.
## Positions are integers in 1/1024 tile. No transcendental floats in sim code.

const ONE := 1024
const HALF := 512
const TICK_HZ := 20

static func tile_center(t: Vector2i) -> Vector2i:
	return Vector2i(t.x * ONE + HALF, t.y * ONE + HALF)

static func to_tile(p: Vector2i) -> Vector2i:
	return Vector2i(p.x >> 10, p.y >> 10)

static func dist2(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy

## Integer square root (exact floor), deterministic: float sqrt is IEEE correctly
## rounded, then corrected with integer checks.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var r := int(sqrt(float(n)))
	while r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r

static func dist(a: Vector2i, b: Vector2i) -> int:
	return isqrt(dist2(a, b))

## milli-tiles per second -> fixed units per tick
static func speed_per_tick(mtps: int) -> int:
	return (mtps * ONE) / (1000 * TICK_HZ)

static func ms_to_ticks(ms: int) -> int:
	return maxi(1, (ms * TICK_HZ + 999) / 1000)

static func mt_to_fx(mt: int) -> int:
	return (mt * ONE) / 1000

## Move point a toward b by at most step. Returns new point.
static func step_toward(a: Vector2i, b: Vector2i, step: int) -> Vector2i:
	var d := dist(a, b)
	if d <= step or d == 0:
		return b
	return Vector2i(a.x + ((b.x - a.x) * step) / d, a.y + ((b.y - a.y) * step) / d)

static func to_world(p: Vector2i) -> Vector3:
	return Vector3(float(p.x) / ONE, 0.0, float(p.y) / ONE)

static func from_world(v: Vector3) -> Vector2i:
	return Vector2i(int(v.x * ONE), int(v.z * ONE))

## FNV-1a 32-bit over ints, for state hashes.
static func fnv_int(h: int, v: int) -> int:
	for i in 4:
		h = h ^ ((v >> (i * 8)) & 0xFF)
		h = (h * 16777619) & 0xFFFFFFFF
	return h
