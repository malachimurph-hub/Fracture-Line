extends "res://tools/m41/models_m41.gd"
## M4.2 (Malachi's 0.4.2 list): original procedural models on the m3 kit.
##   godot --headless --path . -s res://tools/m42/models_m42.gd
## Writes: view/buildings/eu/javelin_pit (crew markers for the animated infantry crews),
##         view/buildings/tpla/sayad3 (Sayad-3 long-range SAM site).

func _initialize() -> void:
	var mat: Material = load(VK.MAT_PATH)
	struct_fac = "eu"
	_javelin_pit(mat)
	struct_fac = "tpla"
	_sayad3(mat)
	var f := FileAccess.open("/tmp/m42_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line(p)
	print("M42 wrote %d scenes" % wrote.size())
	quit(0)

## Sayad-3 site, modelled on the real system's layout: a turntable launcher with four square
## missile canisters (2 x 2) on a raised erector, a separate flat phased-array radar on its
## shelter, a generator and an earth berm. Iran's clean sand / pale grey paint.
const SAND := "#c9bb98"
const SAND_D := "#a99a76"
const PALE := "#d8d4c8"
func _sayad3(mat: Material) -> void:
	var dir := Vector3(0, sin(deg_to_rad(42.0)), cos(deg_to_rad(42.0)))
	var cc := Vector3(0, 0.62, 0.05)     # canister block centre (turret space)
	var muz := {}
	var k := 0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var off: Vector3 = Vector3(sx * 0.11, 0, 0) + Vector3(0, cos(deg_to_rad(42.0)), -sin(deg_to_rad(42.0))) * sy * 0.11
			muz["Muzzle%d" % k] = cc + off + dir * 0.55
			k += 1
	_structure("sayad3", Vector2(3, 3), 1.25, mat, func(g) -> void:
		# earth berm on three sides
		g.color("#9c8a66", Geo.CONCRETE)
		g.rbox(Vector3(0, Y0 + 0.08, -1.32), Vector3(2.8, 0.18, 0.3), Vector3(-12, 0, 0))
		g.rbox(Vector3(-1.32, Y0 + 0.08, 0), Vector3(0.3, 0.18, 2.6), Vector3(0, 0, 12))
		g.rbox(Vector3(1.32, Y0 + 0.08, 0.35), Vector3(0.3, 0.18, 1.9), Vector3(0, 0, -12))
		# radar shelter + flat phased-array panel (back left)
		var rp := Vector3(-0.78, Y0, -0.78)
		g.color(SAND, Geo.PAINT)
		g.cbox(rp + Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.5), 0.02)
		g.color(SAND_D, Geo.PAINT)
		g.cbox(rp + Vector3(0, 0.42, 0), Vector3(0.74, 0.04, 0.54), 0.01)
		g.color("#4a4e50", Geo.STEEL)
		g.tube(rp + Vector3(0, 0.44, 0), rp + Vector3(0, 0.6, 0), 0.04, 8)
		g.color(PALE, Geo.PAINT)
		g.rbox(rp + Vector3(0, 0.92, 0.05), Vector3(0.66, 0.66, 0.06), Vector3(-22, 35, 0))   # array face
		g.color("#5a6064", Geo.DARK)
		g.rbox(rp + Vector3(0.03, 0.9, 0.0), Vector3(0.58, 0.58, 0.02), Vector3(-22, 35, 0))
		g.color("#ffffff", Geo.TEAM)
		g.box(rp + Vector3(0, 0.26, 0.26), Vector3(0.3, 0.06, 0.01))
		# generator and cable run (back right)
		var gp := Vector3(0.85, Y0, -0.95)
		g.color(SAND_D, Geo.PAINT)
		g.cbox(gp + Vector3(0, 0.14, 0), Vector3(0.44, 0.28, 0.26), 0.02)
		g.vent(gp + Vector3(0.0, 0.15, 0.135), 0.3, 0.16, 5)
		g.color("#2a2b2a", Geo.DARK)
		g.tube(gp + Vector3(-0.22, 0.02, 0.05), Vector3(-0.45, Y0 + 0.02, -0.7), 0.015, 4)
		g.tube(gp + Vector3(-0.1, 0.02, 0.13), Vector3(0.0, Y0 + 0.02, 0.0), 0.015, 4)
		# concrete launch apron
		g.color("#8f8b80", Geo.CONCRETE)
		g.cyl(0.62, 0.62, 0.03, 18, Transform3D(Basis.IDENTITY, Vector3(0, Y0, 0.1))),
	func(t) -> void:
		# turntable, cab-less launcher chassis, erector arms
		t.color("#4a4e50", Geo.STEEL)
		t.cyl(0.42, 0.44, 0.08, 18, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)))
		t.color(SAND, Geo.PAINT)
		t.cbox(Vector3(0, 0.14, -0.05), Vector3(0.6, 0.12, 0.75), 0.02)
		t.color(SAND_D, Geo.PAINT)
		t.cbox(Vector3(0, 0.24, -0.32), Vector3(0.5, 0.1, 0.18), 0.02)   # hydraulics housing
		t.color("#4a4e50", Geo.STEEL)
		for sx in [-1.0, 1.0]:
			t.tube(Vector3(sx * 0.27, 0.22, -0.3), cc + Vector3(sx * 0.27, -0.12, -0.1), 0.03, 6)   # erector arm
			t.tube(Vector3(sx * 0.2, 0.2, 0.1), cc + Vector3(sx * 0.2, -0.14, 0.12), 0.035, 6)      # ram
		# four square canisters (2 x 2) on the erector, pointing up toward +Z
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var off: Vector3 = Vector3(sx * 0.11, 0, 0) + Vector3(0, cos(deg_to_rad(42.0)), -sin(deg_to_rad(42.0))) * sy * 0.11
				t.color(PALE, Geo.PAINT)
				t.rbox(cc + off, Vector3(0.2, 0.2, 1.08), Vector3(-42, 0, 0))
				t.color("#3a3d40", Geo.DARK)
				t.rbox(cc + off + dir * 0.545, Vector3(0.17, 0.17, 0.02), Vector3(-42, 0, 0))   # front cover
		t.color(SAND_D, Geo.PAINT)
		for z in [-0.3, 0.3]:   # canister band clamps
			t.rbox(cc + dir * z, Vector3(0.48, 0.48, 0.05), Vector3(-42, 0, 0))
		t.color("#ffffff", Geo.TEAM)
		t.rbox(cc + Vector3(0.245, 0, 0) + dir * 0.1, Vector3(0.01, 0.12, 0.3), Vector3(-42, 0, 0)),
		Vector3(0.05, Y0 + 0.03, 0.15),
		{"turret": muz})
