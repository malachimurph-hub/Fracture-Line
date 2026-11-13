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

# ------------------------------------------------------------------ M3.5 Combat Squad weapons
## M240B-style medium machine gun (US): long receiver, perforated heat shield, carry handle,
## bipod, butt stock, 100-round soft pouch on the left.
func m240b() -> void:
	color(BLK)
	box(Vector3(0, 0.05, 0.08), Vector3(0.06, 0.09, 0.4))                     # receiver
	box(Vector3(0, 0.11, 0.08), Vector3(0.035, 0.03, 0.26))                   # feed cover + rail
	box(Vector3(0, 0.03, -0.26), Vector3(0.045, 0.1, 0.3))                    # butt stock
	box(Vector3(0, -0.04, -0.02), Vector3(0.03, 0.09, 0.04))                  # pistol grip
	color("#2c2e2b")
	cyl(Vector3(0, 0.065, 0.28), Vector3(0, 0.065, 0.62), 0.022, 0.022, 8)   # heat shield
	color(STEEL)
	cyl(Vector3(0, 0.065, 0.62), Vector3(0, 0.065, 0.9), 0.012)              # barrel
	cyl(Vector3(0, 0.065, 0.9), Vector3(0, 0.065, 0.96), 0.017)             # flash hider
	box(Vector3(0, 0.14, 0.3), Vector3(0.012, 0.05, 0.08))                    # carry handle
	color(BLK)
	for s in [-1.0, 1.0]:
		cyl(Vector3(0, 0.04, 0.6), Vector3(s * 0.07, -0.13, 0.66), 0.006)     # bipod legs
	color("#6f6550")
	box(Vector3(-0.07, -0.02, 0.06), Vector3(0.07, 0.11, 0.12))               # ammo pouch

## MG3-style general-purpose machine gun (Germany): slim receiver, fully perforated barrel
## jacket, conical muzzle booster, bipod at the muzzle end, 50-round belt drum on the left.
func mg3() -> void:
	color(BLK)
	box(Vector3(0, 0.05, 0.06), Vector3(0.05, 0.085, 0.36))                   # receiver
	box(Vector3(0, 0.1, 0.08), Vector3(0.04, 0.025, 0.2))                     # feed cover
	box(Vector3(0, 0.02, -0.25), Vector3(0.04, 0.1, 0.32))                    # polymer stock
	box(Vector3(0, -0.04, -0.02), Vector3(0.03, 0.09, 0.04))
	color("#30322f")
	cyl(Vector3(0, 0.06, 0.24), Vector3(0, 0.06, 0.74), 0.024, 0.024, 8)     # perforated jacket
	color(STEEL)
	cyl(Vector3(0, 0.06, 0.74), Vector3(0, 0.06, 0.86), 0.02, 0.011)         # muzzle booster
	color(BLK)
	for s in [-1.0, 1.0]:
		cyl(Vector3(0, 0.04, 0.68), Vector3(s * 0.07, -0.13, 0.74), 0.006)
	color("#3c4033")
	cyl(Vector3(-0.08, -0.02, 0.06), Vector3(-0.04, -0.02, 0.06), 0.055, 0.055, 10)   # belt drum

## Rifles with an under-barrel 40 mm grenade launcher (Combat Squad grenadier placeholders).
func _ugl(z0: float, z1: float, y: float) -> void:
	color("#2e3030")
	cyl(Vector3(0, y, z0), Vector3(0, y, z1), 0.022, 0.022, 8)                # launcher tube
	box(Vector3(0, y - 0.03, z0 + 0.02), Vector3(0.022, 0.05, 0.03))          # trigger housing

func m16_gl() -> void:
	m16()
	_ugl(0.22, 0.46, -0.005)

func ak_gl() -> void:
	ak()
	_ugl(0.2, 0.42, 0.0)

## AK-47 is the wood-furniture rifle already in the kit. RPG-7 with a loaded round and four fins.
func rpg7() -> void:
	rpg()
	color("#5a6a38")
	for s in [-1.0, 1.0]:
		box(Vector3(s * 0.055, 0.1, 0.66), Vector3(0.045, 0.006, 0.1))
		box(Vector3(0, 0.1 + s * 0.055, 0.66), Vector3(0.006, 0.045, 0.1))
	color("#6a5a32")
	cyl(Vector3(0, 0.1, 0.28), Vector3(0, 0.1, 0.4), 0.034, 0.034, 8)

## PKM with a wood butt and pistol grip, the way the issued gun is finished.
func pkm_ru() -> void:
	color(STEEL)
	box(Vector3(0, 0.05, 0.08), Vector3(0.055, 0.08, 0.38))
	cyl(Vector3(0, 0.06, 0.27), Vector3(0, 0.06, 0.84), 0.012)
	cyl(Vector3(0, 0.06, 0.84), Vector3(0, 0.06, 0.92), 0.018, 0.012)
	cyl(Vector3(0, 0.1, 0.26), Vector3(0, 0.1, 0.6), 0.01)
	box(Vector3(0, 0.12, 0.1), Vector3(0.05, 0.02, 0.2))
	color(WOOD)
	box(Vector3(0, 0.02, -0.22), Vector3(0.04, 0.09, 0.28))
	box(Vector3(0, -0.03, -0.02), Vector3(0.032, 0.09, 0.042))
	color(BLK)
	for s in [-1.0, 1.0]:
		cyl(Vector3(0, 0.05, 0.7), Vector3(s * 0.06, -0.12, 0.76), 0.006)
	color("#4a5a32")
	box(Vector3(0.075, -0.01, 0.1), Vector3(0.08, 0.11, 0.14))
	color(STEEL)
	box(Vector3(0, 0.14, 0.02), Vector3(0.012, 0.04, 0.1))

func ak74_gl() -> void:
	ak74()
	_ugl(0.2, 0.42, 0.0)

## Stand-alone 40 mm revolver launcher (MK 23 team). Same grip frame as a carbine.
func mk23() -> void:
	color(BLK)
	box(Vector3(0, 0.03, -0.22), Vector3(0.045, 0.08, 0.22))                 # stock
	box(Vector3(0, -0.04, -0.02), Vector3(0.03, 0.09, 0.04))                 # grip
	color("#3e4329")
	cyl(Vector3(0, 0.05, 0.08), Vector3(0, 0.05, 0.32), 0.048, 0.048, 10)   # cylinder
	color(STEEL)
	cyl(Vector3(0, 0.05, 0.32), Vector3(0, 0.05, 0.58), 0.012)
	color(BLK)
	box(Vector3(0, 0.1, 0.18), Vector3(0.02, 0.02, 0.16))                    # sight rail
	box(Vector3(0, 0.02, 0.2), Vector3(0.05, 0.03, 0.12))                    # foregrip

## Carbine with a suppressor (SEAL). Grip points match m4.
func seal_carbine() -> void:
	m4()
	color("#1a1c1c")
	cyl(Vector3(0, 0.06, 0.58), Vector3(0, 0.06, 0.74), 0.016, 0.016, 8)
