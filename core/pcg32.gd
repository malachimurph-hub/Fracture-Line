class_name PCG32
## PCG32 (XSH RR) deterministic RNG, implemented on 64-bit signed GDScript ints
## with explicit masking so it behaves like the unsigned reference.

const MULT := 6364136223846793005
var state: int = 0
var inc: int = 0

static func _lsr(x: int, n: int) -> int:
	if n == 0:
		return x
	return (x >> n) & ((1 << (64 - n)) - 1)

func seed(initstate: int, initseq: int = 54) -> void:
	state = 0
	inc = (initseq << 1) | 1
	next_u32()
	state = state + initstate
	next_u32()

func next_u32() -> int:
	var old := state
	state = old * MULT + inc
	var xorshifted := (_lsr(_lsr(old, 18) ^ old, 27)) & 0xFFFFFFFF
	var rot := _lsr(old, 59) & 31
	return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & 31))) & 0xFFFFFFFF

## Uniform int in [0, n)
func range_int(n: int) -> int:
	if n <= 1:
		return 0
	return next_u32() % n

func to_dict() -> Dictionary:
	return {"s": state, "i": inc}

func from_dict(d: Dictionary) -> void:
	state = int(d["s"])
	inc = int(d["i"])
