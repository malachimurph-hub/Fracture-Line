extends "res://tools/gfx_m28/inf_kit.gd"
## M3.4 additions to the procedural weapon kit (original): combat shotgun, compact PDW, pistol,
## entrenching shovel. Same frame: metres, +Z muzzle, +Y up, origin = pistol grip.

func shotgun() -> void:
	color(BLK)
	box(Vector3(0, 0.05, 0.03), Vector3(0.05, 0.08, 0.26))
	box(Vector3(0, 0.03, -0.22), Vector3(0.042, 0.085, 0.28))
	box(Vector3(0, -0.04, -0.03), Vector3(0.03, 0.09, 0.04))
	color(STEEL)
	cyl(Vector3(0, 0.065, 0.16), Vector3(0, 0.065, 0.62), 0.011)
	cyl(Vector3(0, 0.02, 0.16), Vector3(0, 0.02, 0.54), 0.013)          # magazine tube
	color("#2a2b2c")
	box(Vector3(0, 0.02, 0.33), Vector3(0.05, 0.045, 0.16))             # fore-end
	box(Vector3(0, 0.11, 0.04), Vector3(0.02, 0.025, 0.08))             # ghost-ring sight

func smg() -> void:
	color(BLK)
	box(Vector3(0, 0.05, 0.05), Vector3(0.045, 0.09, 0.24))
	box(Vector3(0, 0.105, 0.06), Vector3(0.025, 0.02, 0.22))
	color(STEEL)
	cyl(Vector3(0, 0.06, 0.17), Vector3(0, 0.06, 0.26), 0.008)
	color(BLK)
	cyl(Vector3(0, 0.07, -0.07), Vector3(0, 0.07, -0.2), 0.008, 0.008, 5)
	cyl(Vector3(0, 0.03, -0.07), Vector3(0, 0.03, -0.2), 0.008, 0.008, 5)
	box(Vector3(0, 0.05, -0.21), Vector3(0.04, 0.07, 0.02))            # butt plate
	box(Vector3(0, -0.06, -0.02), Vector3(0.03, 0.16, 0.045))          # grip + mag
	box(Vector3(0, -0.03, 0.14), Vector3(0.025, 0.07, 0.03))           # front grip
	color("#141516")
	box(Vector3(0, 0.13, 0.05), Vector3(0.035, 0.035, 0.06))           # red dot

func pistol() -> void:
	color(BLK)
	box(Vector3(0, 0.04, 0.06), Vector3(0.03, 0.035, 0.19))
	box(Vector3(0, -0.025, 0.0), Vector3(0.028, 0.1, 0.045))
	box(Vector3(0, 0.015, 0.06), Vector3(0.026, 0.02, 0.1))
	color(STEEL)
	cyl(Vector3(0, 0.045, 0.155), Vector3(0, 0.045, 0.165), 0.006)

func shovel() -> void:
	color(WOOD)
	cyl(Vector3(0, 0, -0.02), Vector3(0, 0, 0.86), 0.016, 0.016, 6)
	color(STEEL)
	box(Vector3(0, 0, -0.04), Vector3(0.11, 0.03, 0.03))               # D-grip
	box(Vector3(0, 0, 0.98), Vector3(0.17, 0.012, 0.24))               # blade
	cyl(Vector3(0, 0, 0.84), Vector3(0, 0, 0.88), 0.022, 0.03, 6)
