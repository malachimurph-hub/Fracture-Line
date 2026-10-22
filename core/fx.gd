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

# ---- fixed-point angles (M2.3 locomotors / aiming): 1024 units per full turn, 0 = +y (south),
# 256 = +x. Tables are precomputed constants so every platform gets identical integers.
const ANG := 1024
const ATAN_LUT := [0, 1, 1, 2, 3, 3, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 12, 13, 13, 14, 15, 15, 16, 16, 17, 18, 18, 19, 20, 20, 21, 22, 22, 23, 23, 24, 25, 25, 26, 27, 27, 28, 28, 29, 30, 30, 31, 31, 32, 33, 33, 34, 34, 35, 36, 36, 37, 38, 38, 39, 39, 40, 41, 41, 42, 42, 43, 44, 44, 45, 45, 46, 46, 47, 48, 48, 49, 49, 50, 51, 51, 52, 52, 53, 53, 54, 55, 55, 56, 56, 57, 57, 58, 58, 59, 60, 60, 61, 61, 62, 62, 63, 63, 64, 65, 65, 66, 66, 67, 67, 68, 68, 69, 69, 70, 70, 71, 71, 72, 72, 73, 74, 74, 75, 75, 76, 76, 77, 77, 78, 78, 79, 79, 80, 80, 81, 81, 82, 82, 83, 83, 84, 84, 84, 85, 85, 86, 86, 87, 87, 88, 88, 89, 89, 90, 90, 91, 91, 91, 92, 92, 93, 93, 94, 94, 95, 95, 96, 96, 96, 97, 97, 98, 98, 99, 99, 99, 100, 100, 101, 101, 102, 102, 102, 103, 103, 104, 104, 104, 105, 105, 106, 106, 106, 107, 107, 108, 108, 108, 109, 109, 110, 110, 110, 111, 111, 112, 112, 112, 113, 113, 113, 114, 114, 115, 115, 115, 116, 116, 116, 117, 117, 118, 118, 118, 119, 119, 119, 120, 120, 120, 121, 121, 121, 122, 122, 122, 123, 123, 123, 124, 124, 124, 125, 125, 125, 126, 126, 126, 127, 127, 127, 128, 128]
const SIN_LUT := [0, 6, 13, 19, 25, 31, 38, 44, 50, 57, 63, 69, 75, 82, 88, 94, 100, 107, 113, 119, 125, 132, 138, 144, 150, 156, 163, 169, 175, 181, 187, 194, 200, 206, 212, 218, 224, 230, 237, 243, 249, 255, 261, 267, 273, 279, 285, 291, 297, 303, 309, 315, 321, 327, 333, 339, 345, 351, 357, 363, 369, 374, 380, 386, 392, 398, 403, 409, 415, 421, 426, 432, 438, 443, 449, 455, 460, 466, 472, 477, 483, 488, 494, 499, 505, 510, 516, 521, 526, 532, 537, 543, 548, 553, 558, 564, 569, 574, 579, 584, 590, 595, 600, 605, 610, 615, 620, 625, 630, 635, 640, 645, 650, 654, 659, 664, 669, 674, 678, 683, 688, 692, 697, 702, 706, 711, 715, 720, 724, 729, 733, 737, 742, 746, 750, 755, 759, 763, 767, 771, 775, 779, 784, 788, 792, 796, 799, 803, 807, 811, 815, 819, 822, 826, 830, 834, 837, 841, 844, 848, 851, 855, 858, 862, 865, 868, 872, 875, 878, 882, 885, 888, 891, 894, 897, 900, 903, 906, 909, 912, 915, 917, 920, 923, 926, 928, 931, 934, 936, 939, 941, 944, 946, 948, 951, 953, 955, 958, 960, 962, 964, 966, 968, 970, 972, 974, 976, 978, 980, 982, 983, 985, 987, 989, 990, 992, 993, 995, 996, 998, 999, 1000, 1002, 1003, 1004, 1006, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014, 1015, 1016, 1016, 1017, 1018, 1018, 1019, 1020, 1020, 1021, 1021, 1022, 1022, 1022, 1023, 1023, 1023, 1024, 1024, 1024, 1024, 1024, 1024]

## Angle of vector (x, y) in ANG units, 0 along +y, increasing toward +x.
static func iatan2(x: int, y: int) -> int:
	if x == 0 and y == 0:
		return 0
	var ax := absi(x)
	var ay := absi(y)
	var a: int
	if ax <= ay:
		a = ATAN_LUT[ax * 256 / ay]          # 0..128 measured from +y toward x
	else:
		a = 256 - ATAN_LUT[ay * 256 / ax]
	if y < 0:
		a = 512 - a
	if x < 0:
		a = -a
	return posmod(a, ANG)

static func isin(a: int) -> int:
	a = posmod(a, ANG)
	if a <= 256:
		return SIN_LUT[a]
	if a <= 512:
		return SIN_LUT[512 - a]
	if a <= 768:
		return -SIN_LUT[a - 512]
	return -SIN_LUT[1024 - a]

static func icos(a: int) -> int:
	return isin(a + 256)

## Unit vector (x, y) * ONE for heading a (matches iatan2: 0 = +y).
static func dir_of(a: int) -> Vector2i:
	return Vector2i(isin(a), icos(a))

## Signed shortest difference b - a in (-512, 512].
static func adiff(a: int, b: int) -> int:
	var d := posmod(b - a, ANG)
	return d - ANG if d > 512 else d

## Degrees per second -> ANG units per tick (at least 1).
static func dps_to_apt(dps: int) -> int:
	return maxi(1, dps * ANG / 360 / TICK_HZ)
