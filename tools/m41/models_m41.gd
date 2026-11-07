extends SceneTree
## M4.1 (Malachi's list): original procedural models for the new units and structures, on the
## m3 surface kit (flat-shaded vertex colour, one draw per part, faction paint via the PAINT
## class at run time). Low poly to stay light on phones; LODs + AO added by add_lods/bake_ao.
##   godot --headless --path . -s res://tools/m41/models_m41.gd
## Writes: view/units/us/blackhawk, view/units/ecc/hind, view/units/eu/h145m,
##         view/buildings/eu/guard_tower, javelin_pit, mantis, view/neutral/cache (oil reserve).
const K := preload("res://tools/gfx_m7/kit8.gd")
const Geo := preload("res://tools/gfx_m3/geo.gd")
const VK := preload("res://tools/gfx_m3/vehicle_kit.gd")
const UV8 := preload("res://tools/gfx_m7/us_v8.gd")
const B4 := preload("res://tools/gfx_m4/buildings_m4.gd")
const Y0 := 0.08
const PNT := "#7e8a5c"      ## base paint (replaced by the faction paint in game)
const PNT_D := "#66704a"
const STL := "#464a46"
const GLS := "#2a3a46"
const DRK := "#1d1f1e"
const SOLDIER := "#5b6244"
const SKIN := "#c29a78"
var wrote: Array = []
var struct_fac := "eu"   ## M4.2: folder for _structure scenes

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	_blackhawk(mat)
	_hind(mat)
	_h145m(mat)
	_guard_tower(mat)
	_javelin_pit(mat)
	_mantis(mat)
	_oil_reserve(mat)
	var f := FileAccess.open("/tmp/m41_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line(p)
	print("M41 wrote %d scenes" % wrote.size())
	quit(0)

func _finish(root: Node3D, model: Node3D, h, mat: Material, path: String, bar: float, parts: Array) -> void:
	var hull := VK._mi(model, root, "Hull", h.commit(mat))
	hull.set_meta("moves", true)
	var t: int = h.tris
	for g in parts:
		t += g.tris
	print("  %s: %d tris" % [path, t])
	VK._save(root, path, bar)
	wrote.append(path)

func _marker(parent: Node3D, root: Node3D, name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	parent.add_child(m)
	m.owner = root
	return m

## pintle-mounted door gun pointing out of the cabin side s (-1 left, +1 right)
func _door_gun(h, s: float, at: Vector3, length: float, r: float, barrels: int) -> Vector3:
	h.color(STL, Geo.STEEL)
	h.tube(at + Vector3(-s * 0.05, -0.08, 0), at, 0.008, 4)            # pintle post
	var tip := at + Vector3(s * length * 0.8, -0.03, length * 0.6)
	h.cbox(at + Vector3(s * 0.02, 0, 0), Vector3(0.05, 0.045, 0.08), 0.01)
	if barrels > 1:   # rotary cluster
		for k in barrels:
			var a := TAU * float(k) / float(barrels)
			var o := Vector3(0, cos(a), sin(a)) * r * 0.6
			h.tube(at + o, tip + o, r * 0.35, 4)
		h.color(DRK, Geo.DARK)
		h.tube(tip - (tip - at).normalized() * 0.02, tip, r * 1.2, 6)
	else:
		h.tube(at, tip, r, 5)
	h.color("#4a4e44", Geo.PAINT)
	h.box(at + Vector3(s * -0.02, -0.04, -0.03), Vector3(0.04, 0.05, 0.06))   # ammo can
	return tip

func _heli_root(sel: float, bar: float) -> Node3D:
	return VK._root({"selection_radius": sel, "bar_height": bar, "recoil": 0.0, "wreck_s": 6.0})

# ---------------------------------------------------------------- UH-60 Black Hawk (US)
func _blackhawk(mat: Material) -> void:
	var root := _heli_root(0.95, 1.2)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.95, K.sect(0.22, 0.27, 0.33, 0.03, 0.05, 0.03, 0.01)], [0.8, K.sect(0.13, 0.27, 0.46, 0.13, 0.16, 0.1, 0.03)],
		[0.56, K.sect(0.08, 0.27, 0.58, 0.19, 0.22, 0.16, 0.05)], [-0.22, K.sect(0.08, 0.28, 0.6, 0.2, 0.23, 0.17, 0.05)],
		[-0.48, K.sect(0.2, 0.34, 0.56, 0.1, 0.13, 0.1, 0.03)]])
	# windscreen + chin windows
	h.color(GLS, Geo.GLASS)
	h.xloft([[0.84, K.sect(0.4, 0.44, 0.47, 0.1, 0.11, 0.07, 0.015)], [0.62, K.sect(0.44, 0.52, 0.59, 0.16, 0.17, 0.12, 0.03)]])
	for s in [-1.0, 1.0]:
		h.pane([Vector3(s * 0.2, 0.36, 0.7), Vector3(s * 0.2, 0.52, 0.62), Vector3(s * 0.23, 0.52, 0.5), Vector3(s * 0.23, 0.36, 0.5)], Vector3(s, 0, 0))
		# open cabin door (dark opening) with the gunner's window behind it
		h.color("#141615", Geo.DARK)
		h.pane([Vector3(s * 0.232, 0.17, 0.4), Vector3(s * 0.232, 0.5, 0.4), Vector3(s * 0.232, 0.5, -0.02), Vector3(s * 0.232, 0.17, -0.02)], Vector3(s, 0, 0), 0.004, 0.001)
		h.color(GLS, Geo.GLASS)
		h.pane([Vector3(s * 0.232, 0.36, -0.06), Vector3(s * 0.232, 0.5, -0.06), Vector3(s * 0.225, 0.5, -0.2), Vector3(s * 0.225, 0.36, -0.2)], Vector3(s, 0, 0))
		h.color(PNT, Geo.PAINT)
	# engines, exhaust, mast, ESSS-less clean sides
	for s in [-1.0, 1.0]:
		h.color(PNT_D, Geo.PAINT)
		h.tube(Vector3(s * 0.12, 0.64, 0.24), Vector3(s * 0.12, 0.64, -0.28), 0.07, 8, 0.06)
		h.color(DRK, Geo.DARK)
		h.tube(Vector3(s * 0.12, 0.64, 0.245), Vector3(s * 0.12, 0.64, 0.25), 0.05, 8)
		h.color(STL, Geo.STEEL)
		h.plate(Vector3(s * 0.2, 0.62, -0.33), Vector3(0.05, 0.07, 0.1), Vector3(0, 0, s * 30.0))
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.34, K.sect(0.58, 0.62, 0.68, 0.1, 0.11, 0.07, 0.02)], [-0.36, K.sect(0.58, 0.62, 0.7, 0.1, 0.11, 0.07, 0.02)]])
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.68, -0.04), Vector3(0, 0.76, -0.04), 0.035, 6)
	# tail boom, canted tail rotor pylon, stabilator
	h.color(PNT, Geo.PAINT)
	h.tube(Vector3(0, 0.42, -0.46), Vector3(0, 0.5, -1.42), 0.09, 8, 0.045)
	UV8._surf(h, [Vector3(0, 0.48, -1.28), Vector3(0, 0.86, -1.44), Vector3(0, 0.86, -1.54), Vector3(0, 0.48, -1.5)], Vector3(1, 0, 0), 0.04, 0.02)
	UV8._surf(h, [Vector3(-0.3, 0.46, -1.3), Vector3(0.3, 0.46, -1.3), Vector3(0.3, 0.46, -1.42), Vector3(-0.3, 0.46, -1.42)], Vector3(0, 1, 0), 0.02, 0.012)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.235, 0.24, 0.62), Vector3(0.006, 0.05, 0.16))
	h.box(Vector3(0, 0.7, -1.47), Vector3(0.045, 0.08, 0.05))
	UV8._gear(h, [Vector3(-0.2, 0.0, 0.55), Vector3(0.2, 0.0, 0.55)], 0.055)
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.42, -1.2), Vector3(0, 0.05, -1.24), 0.012, 4)
	h.tyre(Vector3(0, 0.04, -1.24), 0.035, 0.03, false, STL, 8)
	# two M134 door miniguns
	for s in [-1.0, 1.0]:
		var tip: Vector3 = _door_gun(h, s, Vector3(s * 0.26, 0.38, 0.34), 0.2, 0.02, 6)
		_marker(model, root, "MuzzleL" if s < 0 else "MuzzleR", tip)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.78, -0.04), 1.6, 4)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(0.07, 0.74, -1.5), 0.34, 4, true)
	_finish(root, model, h, mat, "res://view/units/us/blackhawk.tscn", 1.2, [])

# ---------------------------------------------------------------- Mi-24 Hind (Russia)
func _hind(mat: Material) -> void:
	var root := _heli_root(1.0, 1.25)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(PNT, Geo.PAINT)
	h.xloft([[1.0, K.sect(0.2, 0.24, 0.3, 0.03, 0.05, 0.03, 0.01)], [0.82, K.sect(0.12, 0.24, 0.42, 0.1, 0.13, 0.08, 0.03)],
		[0.5, K.sect(0.08, 0.26, 0.56, 0.17, 0.2, 0.15, 0.05)], [-0.3, K.sect(0.08, 0.27, 0.6, 0.19, 0.21, 0.16, 0.05)],
		[-0.55, K.sect(0.22, 0.34, 0.54, 0.09, 0.12, 0.09, 0.03)]])
	# stepped tandem bubble canopies (gunner low in front, pilot behind)
	h.color(GLS, Geo.GLASS)
	h.dome(0.1, 0.12, 3, 10, Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, 1.4)), Vector3(0, 0.38, 0.84)))
	h.dome(0.12, 0.14, 3, 10, Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, 1.4)), Vector3(0, 0.5, 0.6)))
	# cabin side windows + door
	for s in [-1.0, 1.0]:
		for z in [0.3, 0.12, -0.06]:
			h.pane([Vector3(s * 0.215, 0.36, z + 0.06), Vector3(s * 0.215, 0.44, z + 0.06), Vector3(s * 0.215, 0.44, z - 0.06), Vector3(s * 0.215, 0.36, z - 0.06)], Vector3(s, 0, 0))
	# engines with intakes, exhausts turned out, big mast fairing
	for s in [-1.0, 1.0]:
		h.color(PNT_D, Geo.PAINT)
		h.tube(Vector3(s * 0.13, 0.66, 0.38), Vector3(s * 0.13, 0.66, -0.2), 0.075, 8, 0.065)
		h.color(DRK, Geo.DARK)
		h.tube(Vector3(s * 0.13, 0.66, 0.385), Vector3(s * 0.13, 0.66, 0.39), 0.055, 8)
		h.color(STL, Geo.STEEL)
		h.tube(Vector3(s * 0.15, 0.66, -0.2), Vector3(s * 0.28, 0.62, -0.32), 0.05, 6)
		# stub wings with anhedral and rocket pods (UB-32 style)
		h.color(PNT, Geo.PAINT)
		UV8._surf(h, [Vector3(s * 0.18, 0.42, 0.06), Vector3(s * 0.7, 0.34, 0.02), Vector3(s * 0.7, 0.34, -0.14), Vector3(s * 0.18, 0.42, -0.2)], Vector3(0, 1, 0), 0.035, 0.022)
		h.color("#4a4e44", Geo.PAINT)
		for x in [0.36, 0.56]:
			h.tube(Vector3(s * x, 0.3, 0.12), Vector3(s * x, 0.3, -0.22), 0.05, 8)
			h.color(DRK, Geo.DARK)
			h.tube(Vector3(s * x, 0.3, 0.121), Vector3(s * x, 0.3, 0.13), 0.04, 8)
			h.color("#4a4e44", Geo.PAINT)
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.42, K.sect(0.58, 0.63, 0.7, 0.1, 0.11, 0.07, 0.02)], [-0.36, K.sect(0.58, 0.63, 0.72, 0.1, 0.11, 0.07, 0.02)]])
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.7, -0.02), Vector3(0, 0.78, -0.02), 0.035, 6)
	# tail boom, fin with the tail rotor on the left, stabiliser
	h.color(PNT, Geo.PAINT)
	h.tube(Vector3(0, 0.42, -0.52), Vector3(0, 0.52, -1.5), 0.09, 8, 0.04)
	UV8._surf(h, [Vector3(0, 0.5, -1.34), Vector3(0, 0.88, -1.5), Vector3(0, 0.88, -1.6), Vector3(0, 0.5, -1.56)], Vector3(1, 0, 0), 0.04, 0.02)
	UV8._surf(h, [Vector3(-0.28, 0.44, -1.22), Vector3(0.28, 0.44, -1.22), Vector3(0.28, 0.44, -1.34), Vector3(-0.28, 0.44, -1.34)], Vector3(0, 1, 0), 0.02, 0.012)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.22, 0.25, 0.2), Vector3(0.006, 0.05, 0.3))
	h.box(Vector3(0, 0.76, -1.55), Vector3(0.045, 0.08, 0.05))
	UV8._gear(h, [Vector3(-0.24, 0.0, -0.1), Vector3(0.24, 0.0, -0.1), Vector3(0.0, 0.0, 0.72)], 0.05)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.8, -0.02), 1.6, 5)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(-0.07, 0.76, -1.56), 0.34, 3, true)
	# chin turret with the 20 mm cannon
	var piv := VK._n3(model, root, "TurretPivot", Vector3(0, 0.16, 0.86))
	var t = K.new()
	t.color(STL, Geo.STEEL)
	t.dome(0.06, 0.06, 2, 8, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.02, 0)))
	VK._mi(piv, root, "Turret", t.commit(mat))
	var bn := VK._n3(piv, root, "Barrel", Vector3(0, -0.02, 0.03))
	var b = K.new()
	b.color(STL, Geo.STEEL)
	b.gun(0.0, 0.26, 0.016, 0.012, -1.0, false, 6)
	VK._mi(bn, root, "BarrelMesh", b.commit(mat))
	_finish(root, model, h, mat, "res://view/units/ecc/hind.tscn", 1.25, [t, b])

# ---------------------------------------------------------------- H145M (Germany)
func _h145m(mat: Material) -> void:
	var root := _heli_root(0.85, 1.1)
	var model := VK._n3(root, root, "Model")
	var h = K.new()
	h.color(PNT, Geo.PAINT)
	h.xloft([[0.78, K.sect(0.24, 0.3, 0.38, 0.04, 0.07, 0.04, 0.02)], [0.62, K.sect(0.14, 0.3, 0.52, 0.14, 0.17, 0.11, 0.04)],
		[0.2, K.sect(0.12, 0.3, 0.58, 0.18, 0.2, 0.15, 0.05)], [-0.28, K.sect(0.16, 0.32, 0.56, 0.15, 0.17, 0.13, 0.04)],
		[-0.42, K.sect(0.3, 0.38, 0.52, 0.07, 0.09, 0.07, 0.02)]])
	h.color(GLS, Geo.GLASS)   # big glazed nose
	h.xloft([[0.74, K.sect(0.3, 0.38, 0.46, 0.06, 0.09, 0.06, 0.02)], [0.5, K.sect(0.32, 0.46, 0.57, 0.16, 0.18, 0.13, 0.04)]])
	for s in [-1.0, 1.0]:
		h.color("#141615", Geo.DARK)   # open sliding door
		h.pane([Vector3(s * 0.2, 0.18, 0.3), Vector3(s * 0.2, 0.5, 0.3), Vector3(s * 0.2, 0.5, -0.06), Vector3(s * 0.2, 0.18, -0.06)], Vector3(s, 0, 0), 0.004, 0.001)
		h.color(GLS, Geo.GLASS)
		h.pane([Vector3(s * 0.195, 0.36, -0.1), Vector3(s * 0.195, 0.5, -0.1), Vector3(s * 0.18, 0.5, -0.24), Vector3(s * 0.18, 0.36, -0.24)], Vector3(s, 0, 0))
	h.color(PNT_D, Geo.PAINT)
	h.xloft([[0.24, K.sect(0.56, 0.6, 0.68, 0.12, 0.13, 0.09, 0.03)], [-0.34, K.sect(0.56, 0.6, 0.66, 0.12, 0.13, 0.09, 0.03)]])
	h.color(STL, Geo.STEEL)
	h.tube(Vector3(0, 0.66, 0.0), Vector3(0, 0.72, 0.0), 0.03, 6)
	# slim boom ending in a shrouded fenestron tail rotor
	h.color(PNT, Geo.PAINT)
	h.tube(Vector3(0, 0.44, -0.4), Vector3(0, 0.5, -1.2), 0.07, 8, 0.045)
	h.lathe([[-0.05, 0.13], [0.05, 0.13], [0.05, 0.09], [-0.05, 0.09]], 12, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.56, -1.28)), false, false)
	UV8._surf(h, [Vector3(0, 0.62, -1.24), Vector3(0, 0.82, -1.36), Vector3(0, 0.82, -1.42), Vector3(0, 0.62, -1.34)], Vector3(1, 0, 0), 0.03, 0.018)
	UV8._surf(h, [Vector3(-0.2, 0.48, -1.04), Vector3(0.2, 0.48, -1.04), Vector3(0.2, 0.48, -1.12), Vector3(-0.2, 0.48, -1.12)], Vector3(0, 1, 0), 0.02, 0.012)
	h.color("#ffffff", Geo.TEAM)
	for s in [-1.0, 1.0]:
		h.box(Vector3(s * 0.205, 0.26, 0.48), Vector3(0.006, 0.05, 0.16))
	# skids
	h.color(STL, Geo.STEEL)
	for s in [-1.0, 1.0]:
		h.tube(Vector3(s * 0.24, 0.02, 0.5), Vector3(s * 0.24, 0.02, -0.32), 0.016, 5)
		h.tube(Vector3(s * 0.24, 0.02, 0.5), Vector3(s * 0.23, 0.06, 0.6), 0.016, 5)
		for z in [0.32, -0.16]:
			h.tube(Vector3(s * 0.24, 0.02, z), Vector3(s * 0.14, 0.14, z), 0.014, 4)
	# two light door MGs (MG3 class, single barrel)
	for s in [-1.0, 1.0]:
		var tip: Vector3 = _door_gun(h, s, Vector3(s * 0.23, 0.36, 0.22), 0.17, 0.012, 1)
		_marker(model, root, "MuzzleL" if s < 0 else "MuzzleR", tip)
	UV8._rotor(model, root, mat, "Rotor", Vector3(0, 0.74, 0.0), 1.35, 4)
	UV8._rotor(model, root, mat, "TailRotor", Vector3(0.0, 0.56, -1.28), 0.1, 8, true)
	_finish(root, model, h, mat, "res://view/units/eu/h145m.tscn", 1.1, [])

# ---------------------------------------------------------------- structures (Germany)
## Shared structure shell (pad, scaffold, damage overlays, rubble, fire anchors) like M2.4's
## buildings_m4._make, plus extra markers (Spot* searchlights, Muzzle*).
func _structure(short: String, fp: Vector2, top: float, mat: Material, hull_fn: Callable, turret_fn: Callable, tpos: Vector3, markers: Dictionary, extra: Callable = Callable()) -> void:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/buildings/building_view.gd"))
	root.set("selection_radius", maxf(fp.x, fp.y) * 0.5)
	root.set("bar_height", top + 0.15)
	root.set("footprint", fp)
	root.set("is_structure", true)
	root.set("top_y", top + 0.05)
	root.set("scaffold_top", top * 0.8)
	var model := VK._n3(root, root, "Model")
	var f = B4._foundation(fp, false)
	VK._mi(model, root, "Foundation", f.commit(mat))
	var h = K.new()
	hull_fn.call(h)
	VK._mi(model, root, "Hull", h.commit(mat))
	var parts: Array = [h, f]
	if turret_fn.is_valid():
		var pv := VK._n3(model, root, "TurretPivot", tpos)
		var t = K.new()
		turret_fn.call(t)
		VK._mi(pv, root, "Turret", t.commit(mat))
		parts.append(t)
		for k in markers.get("turret", {}):
			_marker(pv, root, k, markers["turret"][k])
	for k in markers.get("model", {}):
		_marker(model, root, k, markers["model"][k])
	if extra.is_valid():
		extra.call(model, root, mat)
	var s = B4._scaffold(fp, top * 0.8)
	VK._mi(model, root, "Scaffold", s.commit(mat)).visible = false
	var l = B4._damage_light(fp, false)
	VK._mi(model, root, "DamageLight", l.commit(mat)).visible = false
	var hv = B4._damage_heavy(fp, top, false)
	VK._mi(model, root, "DamageHeavy", hv.commit(mat)).visible = false
	var rb = B4._rubble(fp, false)
	VK._mi(model, root, "Rubble", rb.commit(mat)).visible = false
	parts.append_array([s, l, hv, rb])
	var i := 0
	for p in [Vector3(-fp.x * 0.3, top * 0.6, fp.y * 0.15), Vector3(fp.x * 0.3, top * 0.5, -fp.y * 0.3), Vector3(0, top * 0.3, fp.y * 0.3)]:
		_marker(model, root, "Fire%d" % i, p)
		i += 1
	VK._report(short, parts)
	var path := "res://view/buildings/%s/%s.tscn" % [struct_fac, short]
	VK._save(root, path, top + 0.15)
	wrote.append(path)

## Guard tower: four steel legs with cross bracing, a sandbagged cabin with a roof, ladder;
## the .50 cal on a pintle and the searchlight turn together (TurretPivot).
const TW_H := 1.25
func _guard_tower(mat: Material) -> void:
	_structure("guard_tower", Vector2(2, 2), TW_H + 0.55, mat, func(g) -> void:
		g.color("#4b5043", Geo.STEEL)
		var lx := 0.42
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				g.tube(Vector3(sx * (lx + 0.1), Y0, sz * (lx + 0.1)), Vector3(sx * lx, Y0 + TW_H, sz * lx), 0.03, 6)
		for y in [0.35, 0.8]:   # X bracing
			for side in 4:
				var a := Vector3(-lx - 0.07, Y0 + y - 0.2, lx + 0.07)
				var b := Vector3(lx + 0.07, Y0 + y + 0.2, lx + 0.07)
				var rot := Basis(Vector3.UP, PI * 0.5 * side)
				g.tube(rot * a, rot * b, 0.01, 4)
				g.tube(rot * Vector3(a.x, b.y, a.z), rot * Vector3(b.x, a.y, b.z), 0.01, 4)
		# cabin deck, sandbag walls, corner posts and a tin roof
		g.color("#5e6457", Geo.STEEL)
		g.box(Vector3(0, Y0 + TW_H, 0), Vector3(1.0, 0.05, 1.0))
		for k in 4:
			var rot := Basis(Vector3.UP, PI * 0.5 * k)
			for j in 4:
				g.sandbag(rot * Vector3(-0.36 + j * 0.24, Y0 + TW_H + 0.06, 0.46), 0.24, -90.0 * k)
				g.sandbag(rot * Vector3(-0.24 + j * 0.24 - 0.12 * (j % 2), Y0 + TW_H + 0.13, 0.46), 0.22, -90.0 * k)
		g.color("#4b5043", Geo.STEEL)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				g.tube(Vector3(sx * 0.46, Y0 + TW_H, sz * 0.46), Vector3(sx * 0.46, Y0 + TW_H + 0.52, sz * 0.46), 0.015, 4)
		g.color("#6f7b5f", Geo.PAINT)
		g.plate(Vector3(0, Y0 + TW_H + 0.56, 0), Vector3(1.08, 0.03, 1.08), Vector3(0, 0, 4))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, Y0 + TW_H + 0.58, 0), Vector3(0.5, 0.012, 0.5))
		g.color("#4a5056", Geo.STEEL)   # ladder up the back
		for x in [-0.12, 0.0]:
			g.tube(Vector3(x, Y0, -0.62), Vector3(x, Y0 + TW_H, -0.5), 0.01, 4)
		for k in 7:
			var y := 0.12 + k * 0.16
			g.tube(Vector3(-0.12, Y0 + y, -0.62 + y * 0.1), Vector3(0.0, Y0 + y, -0.62 + y * 0.1), 0.007, 3)
		for c in [Vector3(0.75, 0, 0.7), Vector3(-0.72, 0, -0.74)]:
			g.sandbag(Vector3(c.x, Y0 + 0.035, c.z), 0.2, 45)
			g.sandbag(Vector3(c.x, Y0 + 0.1, c.z), 0.2, 45),
	func(t) -> void:
		t.color(STL, Geo.STEEL)
		t.tube(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.02, 6)               # pintle
		t.cbox(Vector3(0, 0.15, 0.0), Vector3(0.09, 0.08, 0.2), 0.012)        # receiver
		t.tube(Vector3(0, 0.16, 0.1), Vector3(0, 0.16, 0.5), 0.016, 6)        # heavy barrel
		t.tube(Vector3(0, 0.16, 0.38), Vector3(0, 0.16, 0.5), 0.022, 6)       # flash hider
		t.color("#4a4e44", Geo.PAINT)
		t.box(Vector3(0.08, 0.13, 0.0), Vector3(0.06, 0.07, 0.11))            # ammo can
		t.color(STL, Geo.STEEL)
		t.box(Vector3(0, 0.12, -0.12), Vector3(0.12, 0.02, 0.04))             # spade grips
		# searchlight on its own bracket, right of the gun, aimed with it
		t.tube(Vector3(-0.2, 0.0, 0.0), Vector3(-0.2, 0.2, 0.0), 0.012, 4)
		t.cyl(0.07, 0.07, 0.14, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 0.26, -0.06)))
		t.color("#fff6d8", Geo.LAMP)
		t.cyl(0.06, 0.06, 0.006, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 0.26, 0.085))),
		Vector3(0, Y0 + TW_H + 0.05, 0.1),
		{"turret": {"Spot0": Vector3(-0.2, 0.26, 0.1), "Muzzle0": Vector3(0, 0.16, 0.52)}})

## Javelin foxhole: a dug-in sandbag ring with a parapet, ammo crates, and two kneeling Javelin
## teams (gunner + loader) on the pivot so they turn to face the target.
func _javelin_pit(mat: Material) -> void:
	_structure("javelin_pit", Vector2(2, 2), 0.55, mat, func(g) -> void:
		g.color("#6d5e45", Geo.CONCRETE)   # trodden earth floor of the pit
		g.cyl(0.8, 0.8, 0.02, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0)))
		for ring in 3:
			var n := 14
			for i in n:
				var a := TAU * (float(i) + 0.5 * (ring % 2)) / float(n)
				g.sandbag(Vector3(cos(a) * 0.82, Y0 + 0.04 + ring * 0.075, sin(a) * 0.82), 0.3, -rad_to_deg(a) + 90.0, "#9c8a62" if (i + ring) % 3 else "#8a7a56")
		g.color("#6b5b3a", Geo.WOOD)   # ammo crates and spare tubes
		g.box(Vector3(-0.5, Y0 + 0.06, -0.42), Vector3(0.24, 0.1, 0.14))
		g.box(Vector3(-0.46, Y0 + 0.16, -0.42), Vector3(0.22, 0.1, 0.13))
		g.color("#4a5038", Geo.CANVAS)
		g.tube(Vector3(0.36, Y0 + 0.06, -0.5), Vector3(0.66, Y0 + 0.06, -0.36), 0.045, 6)
		g.tube(Vector3(0.32, Y0 + 0.15, -0.52), Vector3(0.62, Y0 + 0.15, -0.38), 0.045, 6)
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, Y0 + 0.26, -0.84), Vector3(0.3, 0.05, 0.02)),
	func(t) -> void:
		# M4.2: the crews are real animated infantry (same models and size as barracks troops),
		# placed at the Crew* markers by WorldView; the turret carries only their kit.
		for s in [-1.0, 1.0]:
			t.color("#4a5038", Geo.CANVAS)
			t.tube(Vector3(s * 0.56, 0.05, -0.36), Vector3(s * 0.3, 0.05, -0.44), 0.045, 6)   # spare round
			t.color("#565c46", Geo.STEEL)
			t.box(Vector3(s * 0.12, 0.04, -0.3), Vector3(0.1, 0.08, 0.12)),   # CLU battery case
		Vector3(0, Y0, 0),
		{"turret": {"Muzzle0": Vector3(-0.28, 0.36, 0.42), "Muzzle1": Vector3(0.28, 0.36, 0.42),
			"Crew0": Vector3(-0.28, 0.0, 0.05), "Crew1": Vector3(0.28, 0.0, 0.05),
			"Crew2": Vector3(-0.5, 0.0, -0.2), "Crew3": Vector3(0.5, 0.0, -0.2)}})

## Kneeling AT gunner (one knee down, launcher on the shoulder, aimed along +Z).
func _kneeling_gunner(t, p: Vector3) -> void:
	t.color(SOLDIER, Geo.CANVAS)
	t.box(p + Vector3(0.05, 0.05, 0.02), Vector3(0.06, 0.06, 0.18))        # left shin on the ground
	t.rbox(p + Vector3(0.05, 0.11, 0.1), Vector3(0.06, 0.06, 0.14), Vector3(-40, 0, 0))
	t.box(p + Vector3(-0.05, 0.08, 0.12), Vector3(0.06, 0.16, 0.06))       # right shin up
	t.box(p + Vector3(-0.05, 0.15, 0.06), Vector3(0.06, 0.06, 0.14))       # right thigh
	t.rbox(p + Vector3(0, 0.25, 0.0), Vector3(0.15, 0.2, 0.1), Vector3(12, 0, 0))   # torso
	t.color("#3f4430", Geo.CANVAS)
	t.box(p + Vector3(0, 0.26, -0.07), Vector3(0.12, 0.13, 0.05))          # pack
	t.color(SKIN, Geo.CANVAS)
	t.dome(0.04, 0.06, 2, 8, Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.33, 0.04)))
	t.color("#4b5136", Geo.CANVAS)
	t.dome(0.048, 0.04, 2, 8, Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.37, 0.04)))   # helmet
	t.color("#565c46", Geo.STEEL)   # Javelin: tube + command launch unit
	t.tube(p + Vector3(0.07, 0.34, -0.25), p + Vector3(0.07, 0.36, 0.36), 0.045, 8)
	t.box(p + Vector3(0.02, 0.32, 0.02), Vector3(0.08, 0.08, 0.1))
	t.color(SOLDIER, Geo.CANVAS)
	t.tube(p + Vector3(0.07, 0.28, 0.02), p + Vector3(0.07, 0.33, 0.12), 0.02, 4)   # arms on the CLU
	t.tube(p + Vector3(-0.06, 0.28, 0.02), p + Vector3(0.02, 0.31, 0.1), 0.02, 4)

func _kneeling_loader(t, p: Vector3) -> void:
	t.color(SOLDIER, Geo.CANVAS)
	t.box(p + Vector3(0.04, 0.04, 0.0), Vector3(0.06, 0.06, 0.16))
	t.box(p + Vector3(-0.04, 0.08, 0.08), Vector3(0.06, 0.16, 0.06))
	t.box(p + Vector3(-0.04, 0.15, 0.02), Vector3(0.06, 0.06, 0.12))
	t.rbox(p + Vector3(0, 0.23, -0.02), Vector3(0.14, 0.19, 0.1), Vector3(20, 0, 0))
	t.color(SKIN, Geo.CANVAS)
	t.dome(0.04, 0.06, 2, 8, Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.31, 0.02)))
	t.color("#4b5136", Geo.CANVAS)
	t.dome(0.048, 0.04, 2, 8, Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.35, 0.02)))
	t.color("#4a5038", Geo.CANVAS)
	t.tube(p + Vector3(-0.1, 0.2, -0.12), p + Vector3(0.1, 0.2, -0.12), 0.04, 6)   # spare round

## MANTIS-style air-defence turret: a squat boxy gun house on a low plinth with a single long
## 35 mm revolver-cannon barrel, plus the separate sensor mast on the pad.
func _mantis(mat: Material) -> void:
	_structure("mantis", Vector2(2, 2), 1.15, mat, func(g) -> void:
		g.color("#8f8a7c", Geo.CONCRETE)
		g.bbox(Vector3(0, Y0 + 0.14, 0), Vector3(1.2, 0.28, 1.2), 0.05)
		g.color("#6f7b5f", Geo.PAINT)
		g.cyl(0.42, 0.44, 0.12, 16, Transform3D(Basis.IDENTITY, Vector3(0, Y0 + 0.28, 0)))
		g.color("#4b5043", Geo.STEEL)   # sensor mast with a small search radar, cable run
		g.tube(Vector3(-0.72, Y0, -0.7), Vector3(-0.72, Y0 + 0.95, -0.7), 0.025, 6)
		g.color("#6f7b5f", Geo.PAINT)
		g.cbox(Vector3(-0.72, Y0 + 1.0, -0.7), Vector3(0.22, 0.12, 0.08), 0.015)
		g.color(DRK, Geo.DARK)
		g.box(Vector3(-0.72, Y0 + 1.0, -0.655), Vector3(0.18, 0.09, 0.01))
		g.color("#3a3d3a", Geo.STEEL)
		g.box(Vector3(-0.4, Y0 + 0.01, -0.7), Vector3(0.6, 0.02, 0.03))
		g.color("#ffffff", Geo.TEAM)
		g.box(Vector3(0, Y0 + 0.2, 0.61), Vector3(0.5, 0.06, 0.01)),
	func(t) -> void:
		t.color("#6f7b5f", Geo.PAINT)
		t.lathe([[0.0, 0.34], [0.06, 0.34], [0.1, 0.3]], 14, Transform3D.IDENTITY)
		# faceted gun house, sloped front
		t.xloft([[0.32, K.sect(0.1, 0.3, 0.46, 0.26, 0.27, 0.2, 0.05)], [-0.36, K.sect(0.1, 0.3, 0.5, 0.28, 0.29, 0.24, 0.05)]])
		t.color("#5d6650", Geo.PAINT)
		t.plate(Vector3(0, 0.36, 0.36), Vector3(0.4, 0.2, 0.04), Vector3(-35, 0, 0))
		t.color("#ffffff", Geo.TEAM)
		for s in [-1.0, 1.0]:
			t.box(Vector3(s * 0.285, 0.32, -0.02), Vector3(0.006, 0.06, 0.3))
		t.color(STL, Geo.STEEL)   # mantlet, single long barrel, muzzle velocity radar ring
		t.cbox(Vector3(0, 0.3, 0.42), Vector3(0.14, 0.14, 0.1), 0.02)
		t.tube(Vector3(0, 0.3, 0.42), Vector3(0, 0.3, 1.25), 0.03, 8, 0.024)
		t.tube(Vector3(0, 0.3, 0.9), Vector3(0, 0.3, 1.0), 0.036, 8)   # barrel clamp
		t.cyl(0.04, 0.04, 0.07, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.3, 1.2)))
		t.color(DRK, Geo.DARK)
		t.box(Vector3(0.12, 0.47, -0.1), Vector3(0.08, 0.05, 0.08)),
		Vector3(0, Y0 + 0.34, 0),
		{"turret": {"Muzzle0": Vector3(0, 0.3, 1.27)}})

# ---------------------------------------------------------------- Crude Oil Reserve (neutral)
## M4.1 (Malachi: "Increase structure size of oil reserves", "Redesign supply stashes, enhance
## graphics"): about twice the footprint of M3.5's reserve - three big floating-roof storage tanks
## inside a bund wall, a pump house, a manifold with valves, a loading gantry and drums on pallets.
## Smooth vertex colours (no texture), low poly, one mesh.
const DRUMS := ["#2f4560", "#7a2b22", "#2c2d2b", "#2f4560", "#4a5a3a", "#7a2b22"]
func _oil_reserve(mat: Material) -> void:
	var root := Node3D.new()
	root.name = "View"
	root.set_script(load("res://view/wrappers/entity_view.gd"))
	root.set("selection_radius", 1.35)
	root.set("bar_height", 1.0)
	var model := VK._n3(root, root, "Model")
	var g = K.new()
	g.color("#a9a497", Geo.CONCRETE)   # pad
	g.bbox(Vector3(0, 0.02, 0), Vector3(2.5, 0.04, 2.1), 0.02)
	g.color("#8f8a7c", Geo.CONCRETE)   # low bund wall around the tank farm
	for seg in [[Vector3(-0.2, 0.08, -0.98), Vector3(2.0, 0.09, 0.06)], [Vector3(-0.2, 0.08, 0.2), Vector3(2.0, 0.09, 0.06)],
			[Vector3(-1.17, 0.08, -0.39), Vector3(0.06, 0.09, 1.24)], [Vector3(0.77, 0.08, -0.39), Vector3(0.06, 0.09, 1.24)]]:
		g.box(seg[0], seg[1])
	g.color("#2a2622", Geo.DARK)   # oil stains
	g.cyl(0.22, 0.22, 0.004, 12, Transform3D(Basis.IDENTITY, Vector3(0.6, 0.042, 0.55)))
	g.cyl(0.12, 0.12, 0.004, 10, Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.042, 0.7)))
	# three storage tanks: white shells, red stencil band, roof cone, wind girder, spiral-ish stair
	var tanks := [[Vector3(-0.72, 0.04, -0.44), 0.34, 0.62], [Vector3(0.0, 0.04, -0.5), 0.4, 0.74], [Vector3(0.52, 0.04, -0.4), 0.22, 0.48]]
	for tk in tanks:
		var c: Vector3 = tk[0]
		var r: float = tk[1]
		var hh: float = tk[2]
		g.color("#d6d2c6", Geo.PAINT)
		g.plain = true
		g.cyl(r, r, hh, 20, Transform3D(Basis.IDENTITY, c))
		g.color("#cbc6b8", Geo.PAINT)
		g.cyl(r + 0.005, r * 0.12, r * 0.22, 20, Transform3D(Basis.IDENTITY, c + Vector3(0, hh, 0)))
		g.color("#8f3a2a", Geo.PAINT)
		g.cyl(r + 0.004, r + 0.004, 0.05, 20, Transform3D(Basis.IDENTITY, c + Vector3(0, hh * 0.68, 0)), false)
		g.color("#9a968c", Geo.STEEL)
		g.cyl(r + 0.02, r + 0.02, 0.012, 20, Transform3D(Basis.IDENTITY, c + Vector3(0, hh - 0.02, 0)), false)
		g.plain = false
		g.color("#45474a", Geo.STEEL)
		var steps := int(hh / 0.08)
		for k in steps:   # stair treads winding up the front
			var a := 0.4 + float(k) / float(steps) * 1.4
			g.box(c + Vector3(sin(a) * (r + 0.04), 0.04 + k * 0.08, cos(a) * (r + 0.04)), Vector3(0.07, 0.008, 0.04), Transform3D(Basis(Vector3.UP, a), Vector3.ZERO))
		g.tube(c + Vector3(0, 0.06, r), c + Vector3(0, 0.06, 0.72 + 0.5 - c.z * 0.0 - 0.5 + 0.12), 0.026, 8)   # outlet line to the manifold
	# manifold, valves, pump house
	g.color("#45474a", Geo.STEEL)
	g.tube(Vector3(-0.95, 0.1, 0.12), Vector3(0.7, 0.1, 0.12), 0.035, 8)
	g.color("#c9a227", Geo.PAINT)
	for x in [-0.72, 0.0, 0.52]:
		g.cyl(0.04, 0.04, 0.03, 8, Transform3D(Basis.IDENTITY, Vector3(x, 0.135, 0.12)))
		g.box(Vector3(x, 0.18, 0.12), Vector3(0.1, 0.01, 0.01))
	g.color("#8a8e8a", Geo.CORR)
	g.bbox(Vector3(-0.95, 0.18, 0.62), Vector3(0.38, 0.3, 0.32), 0.02)
	g.color("#6c706c", Geo.CORR)
	g.plate(Vector3(-0.95, 0.35, 0.62), Vector3(0.42, 0.02, 0.36), Vector3(0, 0, 6))
	g.color(DRK, Geo.DARK)
	g.box(Vector3(-0.85, 0.13, 0.785), Vector3(0.1, 0.18, 0.01))
	# loading gantry over the truck bay with a swing arm
	g.color("#4c4f52", Geo.STEEL)
	for x in [0.95, 1.15]:
		for z in [-0.3, 0.3]:
			g.tube(Vector3(x, 0.04, z), Vector3(x, 0.6, z), 0.018, 5)
	g.box(Vector3(1.05, 0.6, 0.0), Vector3(0.28, 0.025, 0.7))
	g.tube(Vector3(1.05, 0.58, 0.1), Vector3(1.05, 0.3, 0.1), 0.02, 6)
	g.color("#c9a227", Geo.PAINT)
	g.box(Vector3(1.05, 0.64, 0.0), Vector3(0.3, 0.02, 0.02))
	# drums on pallets ready for export
	g.color("#8a6e4a", Geo.WOOD)
	g.box(Vector3(0.25, 0.055, 0.6), Vector3(0.5, 0.03, 0.32))
	g.box(Vector3(-0.4, 0.055, 0.75), Vector3(0.36, 0.03, 0.2))
	var spots := [Vector3(0.06, 0, 0.52), Vector3(0.18, 0, 0.52), Vector3(0.3, 0, 0.52), Vector3(0.42, 0, 0.52),
		Vector3(0.06, 0, 0.68), Vector3(0.18, 0, 0.68), Vector3(0.3, 0, 0.68), Vector3(-0.5, 0, 0.75), Vector3(-0.38, 0, 0.75), Vector3(-0.26, 0, 0.75)]
	for i in spots.size():
		var p: Vector3 = spots[i] + Vector3(0, 0.07, 0)
		_drum(g, p, DRUMS[i % DRUMS.size()])
		if i in [0, 1, 4, 8]:
			_drum(g, p + Vector3(0, 0.125, 0), DRUMS[(i + 3) % DRUMS.size()])
	g.color(DRUMS[1], Geo.PAINT)
	g.tube(Vector3(0.55, 0.085, 0.82), Vector3(0.67, 0.085, 0.86), 0.045, 12)
	VK._mi(model, root, "Body", g.commit(mat))
	print("  cache: %d tris" % g.tris)
	VK._save(root, "res://view/neutral/cache.tscn", 1.0)

func _drum(g, p: Vector3, col: String) -> void:
	g.color(col, Geo.PAINT)
	g.cyl(0.045, 0.045, 0.12, 10, Transform3D(Basis.IDENTITY, p))
	g.color("#3a3b3c", Geo.STEEL)
	g.cyl(0.047, 0.047, 0.008, 10, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.06, 0)), false)
