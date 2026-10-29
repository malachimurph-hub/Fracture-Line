class_name PropMeshes
## Procedural, vertex-coloured, original low-poly meshes for environment props and the
## shared part helpers used by the unit/building generator (tools/gen_views.gd).
## Palette: Zero Hour-like warm, slightly saturated, sun-baked.
static var _cache: Dictionary = {}

## M2.9 urban props: footprint in tiles of props that block the ground (tall buildings stand on
## impassable tiles in the map; the map builder stamps these as Cliff). Others are 1 x 1 decor.
const FOOTPRINT := {"tower_glass": Vector2i(4, 4), "tower_apart": Vector2i(4, 4), "tower_office": Vector2i(4, 4),
	"tower_slim": Vector2i(3, 3), "shops": Vector2i(4, 3),
	"house_a": Vector2i(3, 3), "house_b": Vector2i(3, 3), "house_c": Vector2i(3, 3), "house_d": Vector2i(3, 3),
	"containers": Vector2i(3, 2)}
## M3.2 item 14: European village houses (tiled gable roofs, chimneys, framed windows, half-timbering)
## and a shipping-container stack. Blocking like the towers but not "urban" (no dark asphalt).
const HOUSES := ["house_a", "house_b", "house_c", "house_d", "containers"]
const URBAN := ["tower_glass", "tower_apart", "tower_office", "tower_slim", "shops", "car_red", "car_white", "car_blue",
	"car_silver", "car_taxi", "car_van", "car_suv", "streetlight_double", "streetlight"]
const CAR_COL := {"car_red": "#a3302a", "car_white": "#e2e0d8", "car_blue": "#2f5a8a", "car_silver": "#a7abae",
	"car_taxi": "#e0b22e", "car_van": "#d8d6ce", "car_suv": "#2a2c2e"}

## Floor bands of a w x d tower from y0 to y1: alternating wall and window strips on all 4 sides.
static func _tower_bands(st: SurfaceTool, w: float, d: float, y0: float, y1: float, floors: int, wall: Color, glass: Color) -> void:
	box(st, Vector3(0, (y0 + y1) * 0.5, 0), Vector3(w, y1 - y0, d), wall)
	var fh := (y1 - y0) / floors
	for i in floors:
		var y := y0 + fh * (i + 0.55)
		box(st, Vector3(0, y, 0), Vector3(w + 0.03, fh * 0.48, d * 0.86), glass)
		box(st, Vector3(0, y, 0), Vector3(w * 0.86, fh * 0.48, d + 0.03), glass)

## M3.0 civilian cars at real-world scale next to the units (~0.25 tile per metre: sedan 4.6 m
## = 1.15 long, 1.8 m = 0.45 wide, 1.45 m = 0.36 tall; van / SUV larger). Lower body with wheel
## arches, bonnet + boot, glasshouse with pillars, bumpers, grille, lamps, mirrors, plate, tyres.
static func _car(st: SurfaceTool, body: Color, kind: String) -> void:
	var van := kind == "car_van"
	var suv := kind == "car_suv"
	var l := 1.25 if van else (1.18 if suv else 1.15)
	var w := 0.5 if van else (0.47 if suv else 0.45)
	var sill := 0.1 if suv else 0.07
	var belt := sill + (0.2 if van or suv else 0.16)
	var roof := 0.5 if van else (0.44 if suv else 0.36)
	var dark := Color("#1f2224")
	var glass := Color("#25313b")
	# lower body, bumpers
	box(st, Vector3(0, (sill + belt) * 0.5, 0), Vector3(w, belt - sill, l - 0.04), body)
	box(st, Vector3(0, sill + 0.04, l * 0.5 - 0.02), Vector3(w + 0.01, 0.06, 0.05), dark)
	box(st, Vector3(0, sill + 0.04, -l * 0.5 + 0.02), Vector3(w + 0.01, 0.06, 0.05), dark)
	box(st, Vector3(0, sill + 0.005, 0), Vector3(w - 0.02, 0.02, l - 0.15), dark)   # sills / underbody
	# cabin (glasshouse): van = full length box, else pillars + sloped screens
	var cab_l := l * (0.86 if van else (0.6 if suv else 0.48))
	var cab_z := -0.03 if van else (-0.08 if suv else -0.05)
	var ch := roof - belt
	box(st, Vector3(0, belt + ch * 0.5, cab_z), Vector3(w * 0.92, ch, cab_l), body)
	box(st, Vector3(0, belt + ch * 0.5, cab_z), Vector3(w * 0.93, ch * 0.62, cab_l * 0.86), glass)   # side glass
	for zz in [-0.05, 0.12] if not van else [0.0]:
		box(st, Vector3(0, belt + ch * 0.5, cab_z + zz * cab_l), Vector3(w * 0.94, ch * 0.64, 0.025), body)   # B / C pillars
	if not van:
		wedge(st, Vector3(0, belt + ch * 0.5, cab_z + cab_l * 0.5 + 0.06), Vector3(w * 0.9, ch, 0.12), glass, Vector3(-90, 0, 0))   # raked windscreen
		wedge(st, Vector3(0, belt + ch * 0.5, cab_z - cab_l * 0.5 - 0.05), Vector3(w * 0.9, ch, 0.1), glass, Vector3(90, 0, 0))   # rear screen
	else:
		box(st, Vector3(0, belt + ch * 0.55, cab_z + cab_l * 0.5 + 0.004), Vector3(w * 0.8, ch * 0.55, 0.01), glass)
	# bonnet crease, grille, lamps, plate
	box(st, Vector3(0, belt + 0.003, l * 0.32), Vector3(w * 0.7, 0.006, l * 0.22), body.darkened(0.08))
	box(st, Vector3(0, sill + 0.09, l * 0.5 - 0.005), Vector3(w * 0.4, 0.05, 0.012), dark)
	for sx in [-1.0, 1.0]:
		box(st, Vector3(sx * w * 0.36, belt - 0.03, l * 0.5 - 0.01), Vector3(w * 0.2, 0.035, 0.015), lit("#f4efdc"))
		box(st, Vector3(sx * w * 0.38, belt - 0.03, -l * 0.5 + 0.015), Vector3(w * 0.18, 0.035, 0.012), Color("#b02a20"))
		box(st, Vector3(sx * (w * 0.5 + 0.02), belt + 0.03, cab_z + cab_l * 0.5 - 0.02), Vector3(0.04, 0.03, 0.03), body)   # mirrors
		box(st, Vector3(sx * (w * 0.5 + 0.002), (sill + belt) * 0.5 + 0.01, cab_z), Vector3(0.006, 0.006, cab_l * 0.9), body.darkened(0.15))   # door line
	box(st, Vector3(0, sill + 0.06, -l * 0.5 - 0.004), Vector3(0.12, 0.03, 0.006), Color("#e6e2d2"))
	# tyres in arches
	var wr := 0.09 if van or suv else 0.08
	for wx in [-w * 0.46, w * 0.46]:
		for wz in [-l * 0.33, l * 0.33]:
			cyl(st, Vector3(wx, wr, wz), wr, wr, 0.07, Color("#1b1a19"), 8, Vector3(0, 0, 90))
			cyl(st, Vector3(wx * 1.02, wr, wz), wr * 0.55, wr * 0.55, 0.072, Color("#8a8d90"), 6, Vector3(0, 0, 90))
	if kind == "car_taxi":
		box(st, Vector3(0, roof + 0.025, cab_z), Vector3(0.16, 0.05, 0.07), lit("#f2efe4"))
	if suv:
		for sx in [-1.0, 1.0]:
			box(st, Vector3(sx * w * 0.36, roof + 0.012, cab_z), Vector3(0.02, 0.02, cab_l * 0.9), dark)   # roof rails

# ---------------------------------------------------------------- M3.0 helpers
const LEAF := 0.75        ## vertex alpha: alpha-cut foliage card (prop.gdshader samples leaf_tex)
const LIT := 0.05         ## vertex alpha: steady emissive (lit windows, signs, lamps)
const BLINK := 0.3        ## vertex alpha: blinking aviation light
const TREES := ["palm", "scrub_tree", "pine", "pine_snow", "oak", "bush"]
const TREE_VARIANTS := 3

static func lit(hex: String) -> Color:
	return Color(hex, LIT)

## Textured foliage card: quad centred at c spanned by half-vectors r (across) and u (up), UVs in
## atlas quadrant q (0 broadleaf, 1 conifer, 2 palm frond, 3 scrub); normals bent away from `ctr`
## so the crown shades like a volume instead of flat planes.
static func card(st: SurfaceTool, c: Vector3, r: Vector3, u: Vector3, q: int, col: Color, ctr: Vector3, uv_lo := Vector2.ZERO, uv_hi := Vector2.ONE) -> void:
	var o := Vector2(float(q % 2), float(q / 2)) * 0.5
	var pts := [c - r - u, c + r - u, c + r + u, c - r + u]
	var uvs := [Vector2(uv_lo.x, uv_hi.y), Vector2(uv_hi.x, uv_hi.y), Vector2(uv_hi.x, uv_lo.y), Vector2(uv_lo.x, uv_lo.y)]
	var cc := Color(col.r, col.g, col.b, LEAF)
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(cc)
		var n: Vector3 = (pts[i] - ctr).normalized() + Vector3(0, 0.6, 0)
		st.set_normal(n.normalized())
		st.set_uv(o + uvs[i] * 0.5)
		st.add_vertex(pts[i])

## Cluster of three crossed cards (+ a flat one) - reads as a leafy clump from any angle.
static func clump(st: SurfaceTool, c: Vector3, size: float, q: int, col: Color, ctr: Vector3, rng: RandomNumberGenerator) -> void:
	var y0 := rng.randf() * PI
	for k in 3:
		var a := y0 + k * PI / 3.0
		var r := Vector3(cos(a), 0, sin(a)) * size * 0.5
		card(st, c, r, Vector3(0, size * 0.5, 0) + Vector3(-sin(a), 0, cos(a)) * size * 0.08, q, col.darkened(k * 0.06), ctr)
	card(st, c + Vector3(0, size * 0.12, 0), Vector3(size * 0.5, 0, 0), Vector3(0, 0, size * 0.5), q, col.lightened(0.06), ctr)

static func branch(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color) -> void:
	var d := b - a
	var l := d.length()
	var up := d / l
	var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(up)
	var m := CylinderMesh.new()
	m.top_radius = r1
	m.bottom_radius = r0
	m.height = l
	m.radial_segments = 5
	m.rings = 1
	add_prim(st, m, Transform3D(Basis(x, up, z), (a + b) * 0.5), col)

static func _tree(st: SurfaceTool, kind: String, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + v * 7919
	var bark := Color("#5c4a36").lightened(v * 0.04)
	match kind:
		"oak":
			var hues := [Color("#5a7a34"), Color("#b5832c"), Color("#a24f2a")]   # M3.2: green, autumn gold, rust red
			var leafc: Color = hues[v % 3]
			var top := Vector3(rng.randf_range(-0.08, 0.08), 1.05 + v * 0.12, rng.randf_range(-0.08, 0.08))
			branch(st, Vector3.ZERO, top, 0.13, 0.08, bark)
			var ctr := top + Vector3(0, 0.45, 0)
			# M3.3: a solid, lumpy inner crown in the leaf colour (was one near-black ball) so the
			# tree reads as a full volume from the side; the leaf cards sit on and around it
			sph(st, ctr, Vector3(0.55, 0.42, 0.55), leafc.darkened(0.2), 7)
			for i in 3:
				var la := TAU * i / 3.0 + rng.randf() * 0.8
				sph(st, ctr + Vector3(cos(la) * 0.32, rng.randf_range(-0.1, 0.15), sin(la) * 0.32), Vector3(0.36, 0.3, 0.36) * rng.randf_range(0.85, 1.1), leafc.darkened(rng.randf_range(0.12, 0.22)), 6)
			var nb := 4 + v
			for i in nb:
				var a := TAU * i / nb + rng.randf_range(-0.3, 0.3)
				var e := top + Vector3(cos(a) * rng.randf_range(0.5, 0.75), rng.randf_range(0.2, 0.55), sin(a) * rng.randf_range(0.5, 0.75))
				branch(st, top - Vector3(0, rng.randf_range(0.0, 0.25), 0), e, 0.06, 0.025, bark)
				clump(st, e + Vector3(0, 0.1, 0), rng.randf_range(0.8, 1.05), 0, leafc.lightened(rng.randf_range(-0.05, 0.08)), ctr, rng)
			clump(st, ctr + Vector3(0, 0.45, 0), 1.0, 0, leafc.lightened(0.1), ctr, rng)
		"pine", "pine_snow":
			var snow := kind == "pine_snow"
			var hgt := 2.6 + v * 0.35
			branch(st, Vector3.ZERO, Vector3(0, hgt, 0), 0.1, 0.03, bark)
			var tiers := 5 + v
			var g := Color("#46683a").lightened(v * 0.03)   # M3.3: a touch lighter (read black on phones)
			cyl(st, Vector3(0, hgt * 0.55, 0), 0.05, 0.55, hgt * 0.8, g.darkened(0.15), 7)   # dense core (M3.3: lighter, reads solid)
			for k in tiers:
				var t := float(k) / float(tiers)
				var y := 0.5 + t * (hgt - 0.6)
				var rr := lerpf(1.0, 0.25, t) * rng.randf_range(0.9, 1.1)
				var th := rr * 1.1
				var ctr := Vector3(0, y, 0)
				var a0 := rng.randf() * PI
				for j in 3:
					var a := a0 + j * PI / 3.0
					var col := g if not (snow and k % 2 == 1) else Color("#dfe6ec")
					card(st, Vector3(0, y + th * 0.25, 0), Vector3(cos(a), 0, sin(a)) * rr, Vector3(0, th * 0.5, 0), 1, col.darkened(j * 0.05), ctr - Vector3(0, 0.5, 0))
			if snow:
				cyl(st, Vector3(0, hgt * 0.98, 0), 0.0, 0.16, 0.3, Color("#e8eef5"), 6)
		"palm":
			var lean := rng.randf_range(-12.0, 12.0)
			var p := Vector3.ZERO
			var segs := 6
			for i in segs:
				var t := float(i + 1) / segs
				var q := Vector3(sin(t * 1.5) * 0.25 * (1.0 + v * 0.2), t * (2.6 + v * 0.3), 0).rotated(Vector3.UP, deg_to_rad(lean * 10.0))
				branch(st, p, q, 0.1 - t * 0.03, 0.09 - t * 0.03, Color("#8a6f4d").darkened(i * 0.03))
				p = q
			var top := p
			sph(st, top, Vector3(0.16, 0.13, 0.16), Color("#6b5530"), 5)
			for k in 3:
				sph(st, top + Vector3(cos(k * 2.1) * 0.1, -0.1, sin(k * 2.1) * 0.1), Vector3(0.06, 0.06, 0.06), Color("#5a4a2a"), 4)
			var nf := 8 + v
			for k in nf:
				var a := k * TAU / nf + rng.randf_range(-0.15, 0.15)
				var d := Vector3(cos(a), 0, sin(a))
				var side := Vector3(-sin(a), 0, cos(a))
				var l := rng.randf_range(1.0, 1.3)
				var droop := rng.randf_range(0.15, 0.45)
				var lc := Color("#5d7a2e") if k % 2 == 0 else Color("#6f8a35")
				var mid := top + d * l * 0.5 + Vector3(0, 0.12, 0)
				var tip := top + d * l + Vector3(0, -droop, 0)
				card(st, (top + mid) * 0.5, (mid - top) * 0.5, side * 0.3 + Vector3(0, 0.02, 0), 2, lc, top - Vector3(0, 1, 0), Vector2(0.0, 0.0), Vector2(0.5, 1.0))
				card(st, (mid + tip) * 0.5, (tip - mid) * 0.5, side * 0.28, 2, lc.darkened(0.06), top - Vector3(0, 1, 0), Vector2(0.5, 0.0), Vector2(1.0, 1.0))
		"scrub_tree":
			var hues2 := [Color("#7a7d3c"), Color("#858a45"), Color("#6c7034")]
			var lc2: Color = hues2[v % 3]
			var top2 := Vector3(rng.randf_range(-0.1, 0.1), 0.55 + v * 0.08, 0)
			branch(st, Vector3.ZERO, top2, 0.07, 0.045, Color("#6e5a40"))
			var ctr2 := top2 + Vector3(0, 0.3, 0)
			sph(st, ctr2, Vector3(0.35, 0.25, 0.35), lc2.darkened(0.18), 6)
			for i in 3 + v:
				var a := TAU * i / (3 + v) + rng.randf()
				var e := top2 + Vector3(cos(a) * 0.4, rng.randf_range(0.15, 0.4), sin(a) * 0.4)
				branch(st, top2, e, 0.035, 0.015, Color("#6e5a40"))
				clump(st, e, rng.randf_range(0.6, 0.8), 3, lc2.lightened(rng.randf_range(-0.05, 0.08)), ctr2, rng)
		"bush":
			var lc3 := Color("#53702f").lightened(v * 0.04)
			sph(st, Vector3(0, 0.18, 0), Vector3(0.35, 0.2, 0.32), lc3.darkened(0.18), 6)
			for i in 2 + v:
				var a := TAU * i / (2 + v) + rng.randf()
				clump(st, Vector3(cos(a) * 0.18, 0.28, sin(a) * 0.18), rng.randf_range(0.5, 0.7), 3 if v != 1 else 0, lc3.lightened(rng.randf_range(-0.05, 0.08)), Vector3(0, 0.1, 0), rng)

## M3.3 boulders: each rock is a cluster of irregular faceted stones (a jittered, squashed
## low-poly sphere per stone, flattened where it sits in the ground) with per-face shading:
## sun-facing tops lighter, flanks mid, undersides and creases darker, a few lichen / dust faces
## and darker strata bands - real depth and a different shape for every variant.
static func _rock(st: SurfaceTool, small: bool, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + v * 31 + (7 if small else 0)
	var sc := 0.35 if small else 1.0
	var base: Color = [Color("#9c8a72"), Color("#8f8678"), Color("#a39480")][v % 3]
	var n := 2 if small else 3 + v % 3
	for i in n:
		var a := rng.randf() * TAU
		var r := (0.0 if i == 0 else rng.randf_range(0.35, 0.6)) * sc
		var sz := Vector3(rng.randf_range(0.48, 0.7), rng.randf_range(0.4, 0.62), rng.randf_range(0.44, 0.66)) * sc * (1.0 if i == 0 else rng.randf_range(0.4, 0.65))
		var c := Vector3(cos(a) * r, sz.y * 0.35, sin(a) * r)
		_stone(st, c, sz, rng.randf() * TAU, base.darkened(rng.randf_range(0.0, 0.12)), rng, not small)
	if not small:   # loose scree round the foot
		for k in 4 + v % 3:
			var a2 := rng.randf() * TAU
			var r2 := rng.randf_range(0.55, 0.85)
			var s2 := Vector3(0.09, 0.06, 0.08) * rng.randf_range(0.8, 1.4)
			_stone(st, Vector3(cos(a2) * r2, s2.y * 0.3, sin(a2) * r2), s2, rng.randf() * TAU, base.darkened(rng.randf_range(0.05, 0.2)), rng, false)

## One irregular stone: rings x segments sphere, radii jittered, bottom flattened at the ground.
static func _stone(st: SurfaceTool, c: Vector3, sz: Vector3, yaw: float, col: Color, rng: RandomNumberGenerator, detail: bool) -> void:
	var rings := 4 if detail else (3 if sz.x > 0.12 else 2)   # phone-light: ~56 tris per big stone, 20 per pebble
	var segs := 7 if detail else 5
	var pts := []
	for ri in rings + 1:
		var row := []
		var th := PI * float(ri) / float(rings)
		for si in segs:
			var ph := TAU * float(si) / float(segs) + (0.3 if ri % 2 == 1 else 0.0)
			var j := rng.randf_range(0.78, 1.12) if ri > 0 and ri < rings else 1.0
			var p := Vector3(sin(th) * cos(ph) * j, cos(th), sin(th) * sin(ph) * j)
			if ri == 1:
				p.y *= rng.randf_range(0.75, 1.0)   # uneven, often flattish top
			p = (p * sz).rotated(Vector3.UP, yaw)
			p.y = maxf(p.y, -sz.y * 0.35)   # sits in the ground
			row.append(c + p)
		pts.append(row)
	var sun := Vector3(0.35, 1.0, 0.25).normalized()
	var strata := rng.randf_range(0.0, 1.0)
	for ri in rings:
		for si in segs:
			var a: Vector3 = pts[ri][si]
			var b: Vector3 = pts[ri][(si + 1) % segs]
			var cc: Vector3 = pts[ri + 1][(si + 1) % segs]
			var d: Vector3 = pts[ri + 1][si]
			for tri0 in [[a, cc, b], [a, d, cc]]:
				var tri: Array = tri0
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				var nrm: Vector3 = (p2 - p0).cross(p1 - p0)
				if nrm.length_squared() < 1e-10:
					continue
				nrm = nrm.normalized()
				var mid := (p0 + p1 + p2) / 3.0
				if nrm.dot(mid - c) < 0.0:
					nrm = -nrm
					tri = [p0, p2, p1]
				var lum := clampf(0.5 + 0.5 * nrm.dot(sun), 0.0, 1.0)
				var fc := col.darkened(lerpf(0.32, 0.0, lum)).lightened(lerpf(0.0, 0.1, lum))
				var my := mid.y
				if detail and fmod(my * 7.0 + strata, 1.0) < 0.16:
					fc = fc.darkened(0.12)   # strata band
				if detail and nrm.y > 0.7 and rng.randf() < 0.3:
					fc = fc.lerp(Color("#7d8256"), 0.55)   # lichen / dust on the tops
				fc = fc.darkened(rng.randf_range(0.0, 0.06))
				for q in tri:
					st.set_color(fc)
					st.set_normal(nrm)
					st.add_vertex(q)

## Lit / dark window panes over a tower's glass bands (fixed hash per kind -> stable look) and
## vertical mullions; ~lit_frac of the panes glow warm at night-ish exposure.
static func _tower_windows(st: SurfaceTool, w: float, d: float, y0: float, y1: float, floors: int, seed_i: int, lit_frac := 0.3) -> void:
	var fh := (y1 - y0) / floors
	var cols_w := maxi(3, int(w / 0.45))
	var cols_d := maxi(3, int(d / 0.45))
	var mull := Color("#5d666c")
	for face in 4:
		var along_x := face < 2
		var n := cols_w if along_x else cols_d
		var span := (w if along_x else d) * 0.86
		var off := (d if along_x else w) * 0.5 + 0.02
		var sgn := 1.0 if face % 2 == 0 else -1.0
		for k in range(1, n):
			var a := -span * 0.5 + span * k / n
			var pc := Vector3(a, (y0 + y1) * 0.5, sgn * off) if along_x else Vector3(sgn * off, (y0 + y1) * 0.5, a)
			box(st, pc, Vector3(0.03, y1 - y0, 0.03), mull)
		for f in floors:
			var y := y0 + fh * (f + 0.55)
			for k in n:
				if absi(hash(Vector3i(seed_i * 13 + face, f, k))) % 1000 >= int(lit_frac * 1000.0):
					continue
				var a2 := -span * 0.5 + span * (k + 0.5) / n
				var pc2 := Vector3(a2, y, sgn * (off + 0.002)) if along_x else Vector3(sgn * (off + 0.002), y, a2)
				var sz := Vector3(span / n * 0.62, fh * 0.36, 0.012) if along_x else Vector3(0.012, fh * 0.36, span / n * 0.62)
				var warm: String = ["#ffe2a0", "#fff1cc", "#ffd38a", "#dfe9ff"][absi(hash(Vector2i(f, k))) % 4]
				box(st, pc2, sz, lit(warm))

static func _roof_beacons(st: SurfaceTool, hw: float, hd: float, y: float) -> void:
	for c in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
		box(st, Vector3(c.x, y + 0.08, c.y), Vector3(0.1, 0.1, 0.1), Color("#ff3020", BLINK))

## Sidewalk-height planter / kerb ring around a building footprint (city detail at street level).
static func _plinth(st: SurfaceTool, w: float, d: float) -> void:
	box(st, Vector3(0, 0.03, 0), Vector3(w + 0.1, 0.06, d + 0.1), Color("#a9a59c"))

static func add_prim(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arr := prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	if idx.is_empty():
		for i in v.size():
			st.set_color(col)
			st.set_normal((nb * nm[i]).normalized())
			if not uv.is_empty():
				st.set_uv(uv[i])
			st.add_vertex(xf * v[i])
		return
	for i in idx:
		st.set_color(col)
		st.set_normal((nb * nm[i]).normalized())
		if not uv.is_empty():
			st.set_uv(uv[i])
		st.add_vertex(xf * v[i])

static func box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = s
	add_prim(st, b, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), c), col)

static func cyl(st: SurfaceTool, c: Vector3, r_top: float, r_bot: float, h: float, col: Color, sides: int = 8, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	add_prim(st, m, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), c), col)

static func sph(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, seg: int = 7) -> void:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = seg
	m.rings = maxi(3, seg / 2)
	add_prim(st, m, Transform3D(Basis().scaled(r), c), col)

static func wedge(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var p := PrismMesh.new()
	p.size = s
	p.left_to_right = 0.5
	add_prim(st, p, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), c), col)

## M3.2 item 14: European house. Gable roof along x with tile courses and a ridge cap, gable-end
## walls, stone plinth, framed windows with sills (+ shutters), a door, a chimney, optional
## half-timbering and dormers. ~0.25 tile per metre: a 2.4 x 2.0 footprint is a 10 x 8 m house.
static func _house(st: SurfaceTool, w: float, d: float, floors: int, wall: Color, roof: Color, timber: bool, shutters: Color, dormer: bool, seed_i: int) -> void:
	var fh := 0.62
	var h := floors * fh + 0.12
	var dark := Color("#3b2e24")
	box(st, Vector3(0, 0.06, 0), Vector3(w + 0.06, 0.12, d + 0.06), Color("#8d8578"))       # stone plinth
	box(st, Vector3(0, 0.12 + (h - 0.12) * 0.5, 0), Vector3(w, h - 0.12, d), wall)
	# windows + frames + sills on all four faces, door on the front (+z)
	for face in 4:
		var along_x := face < 2
		var span := w if along_x else d
		var sgn := 1.0 if face % 2 == 0 else -1.0
		var off := (d if along_x else w) * 0.5
		var n := maxi(2, int(span / 0.55))
		for f in floors:
			var y := 0.12 + f * fh + fh * 0.55
			for k in n:
				var a := -span * 0.5 + span * (k + 0.5) / n
				if face == 0 and f == 0 and k == n / 2:
					# door with frame and step
					var dc := Vector3(a, 0.12 + 0.24, sgn * (off + 0.012))
					box(st, dc, Vector3(0.24, 0.48, 0.02), Color("#5a3a24"))
					box(st, dc + Vector3(0, 0.26, 0.004), Vector3(0.3, 0.05, 0.03), Color("#e8e2d4"))
					box(st, Vector3(a, 0.06, sgn * (off + 0.08)), Vector3(0.34, 0.06, 0.14), Color("#9a9286"))
					continue
				var pos := Vector3(a, y, sgn * (off + 0.006)) if along_x else Vector3(sgn * (off + 0.006), y, a)
				var gs := Vector3(0.2, 0.28, 0.012) if along_x else Vector3(0.012, 0.28, 0.2)
				var fs := Vector3(0.26, 0.34, 0.02) if along_x else Vector3(0.02, 0.34, 0.26)
				box(st, pos, fs, Color("#ece6d8"))                                            # frame
				box(st, pos + (Vector3(0, 0, sgn * 0.006) if along_x else Vector3(sgn * 0.006, 0, 0)), gs, Color("#26303a"))   # glass
				var mul := Vector3(0.015, 0.28, 0.016) if along_x else Vector3(0.016, 0.28, 0.015)
				box(st, pos + (Vector3(0, 0, sgn * 0.009) if along_x else Vector3(sgn * 0.009, 0, 0)), mul, Color("#ece6d8"))
				var sill := Vector3(0.3, 0.035, 0.06) if along_x else Vector3(0.06, 0.035, 0.3)
				box(st, pos + Vector3(0, -0.18, 0) + (Vector3(0, 0, sgn * 0.02) if along_x else Vector3(sgn * 0.02, 0, 0)), sill, Color("#b5ad9e"))
				if shutters.a > 0.0:
					for sx in [-1.0, 1.0]:
						var so := Vector3(sx * 0.18, 0, sgn * 0.01) if along_x else Vector3(sgn * 0.01, 0, sx * 0.18)
						box(st, pos + so, Vector3(0.09, 0.32, 0.015) if along_x else Vector3(0.015, 0.32, 0.09), shutters)
		if timber:
			for f in floors + 1:
				var yb := 0.12 + f * fh
				var pc := Vector3(0, yb, sgn * (off + 0.008)) if along_x else Vector3(sgn * (off + 0.008), yb, 0)
				box(st, pc, Vector3(span, 0.05, 0.015) if along_x else Vector3(0.015, 0.05, span), dark)
			for k in n + 1:
				var a2 := -span * 0.5 + span * k / n
				var pc2 := Vector3(a2, 0.12 + (h - 0.12) * 0.5, sgn * (off + 0.008)) if along_x else Vector3(sgn * (off + 0.008), 0.12 + (h - 0.12) * 0.5, a2)
				box(st, pc2, Vector3(0.05, h - 0.12, 0.015) if along_x else Vector3(0.015, h - 0.12, 0.05), dark)
	# gable roof along x: gable-end walls, two slopes with tile courses, ridge cap
	var pitch := 38.0
	var rh := d * 0.5 * tan(deg_to_rad(pitch))
	wedge(st, Vector3(0, h + rh * 0.5, 0), Vector3(d, rh, w), wall, Vector3(0, 90, 0))
	var slope := d * 0.5 / cos(deg_to_rad(pitch)) + 0.12
	for sz in [-1.0, 1.0]:
		var mid := Vector3(0, h + rh * 0.5, sz * d * 0.25)
		var rot := Vector3(sz * pitch, 0, 0)
		box(st, mid + Vector3(0, 0.03, sz * 0.03), Vector3(w + 0.2, 0.05, slope), roof, rot)
		var courses := int(slope / 0.09)
		for c in courses:
			var t := (float(c) + 0.5) / courses - 0.5
			var q := Basis.from_euler(rot * PI / 180.0)
			var pc := mid + Vector3(0, 0.03, sz * 0.03) + q * Vector3(0, 0.03, t * slope)
			box(st, pc, Vector3(w + 0.2, 0.022, 0.05), roof.darkened(0.08 + 0.1 * float(c % 2)), rot)
	box(st, Vector3(0, h + rh + 0.03, 0), Vector3(w + 0.22, 0.07, 0.1), roof.darkened(0.25))   # ridge
	# chimney (+ cap) and optional dormers
	var cx := w * (0.28 if seed_i % 2 == 0 else -0.3)
	box(st, Vector3(cx, h + rh * 0.75, -d * 0.12), Vector3(0.18, rh * 0.9 + 0.3, 0.18), Color("#8a5a44"))
	box(st, Vector3(cx, h + rh * 1.22 + 0.17, -d * 0.12), Vector3(0.24, 0.05, 0.24), Color("#5a4a40"))
	if dormer:
		for dx in [-w * 0.22, w * 0.22]:
			var dcn := Vector3(dx, h + rh * 0.42, d * 0.22)
			box(st, dcn, Vector3(0.3, 0.3, 0.3), wall)
			box(st, dcn + Vector3(0, 0, 0.152), Vector3(0.16, 0.18, 0.01), Color("#26303a"))
			wedge(st, dcn + Vector3(0, 0.22, 0), Vector3(0.36, 0.16, 0.34), roof.darkened(0.1))

static func _containers(st: SurfaceTool, seed_i: int) -> void:
	var cols := [Color("#9a3b2c"), Color("#2f5d7a"), Color("#c08a2e"), Color("#4f6b3a"), Color("#8a8a86"), Color("#6a3a5a")]
	var k := 0
	for row in 2:
		for lvl in 2 - row % 2 + 1:
			var c: Color = cols[(seed_i + k * 7) % cols.size()]
			k += 1
			var p := Vector3(-0.2 + row * 0.15, 0.17 + lvl * 0.34, -0.45 + row * 0.9)
			box(st, p, Vector3(2.4, 0.33, 0.6), c)
			for r in 16:   # corrugation ribs
				box(st, p + Vector3(-1.1 + r * 0.147, 0, 0.302), Vector3(0.05, 0.3, 0.01), c.darkened(0.15))
				box(st, p + Vector3(-1.1 + r * 0.147, 0, -0.302), Vector3(0.05, 0.3, 0.01), c.darkened(0.15))
			box(st, p + Vector3(1.205, 0, 0), Vector3(0.01, 0.31, 0.56), c.darkened(0.25))   # doors
			box(st, p + Vector3(1.212, 0, 0), Vector3(0.01, 0.31, 0.02), Color("#3a3a38"))

static func make(kind: String) -> Mesh:
	if _cache.has(kind):
		return _cache[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# M3.0: trees come in TREE_VARIANTS shapes ("oak:2"); the bare kind is variant 0
	var base := kind.get_slice(":", 0)
	if base == "rock" or base == "rock_small":
		_rock(st, base == "rock_small", int(kind.get_slice(":", 1)) if kind.contains(":") else 0)
		st.index()
		var rm := st.commit()
		_cache[kind] = rm
		return rm
	if base in TREES:
		_tree(st, base, int(kind.get_slice(":", 1)) if kind.contains(":") else 0)
		st.index()
		var tm := st.commit()
		_cache[kind] = tm
		return tm
	match kind:
		"rubble_civ":   # M3.3 P3 (19): a destroyed civilian building, 1 x 1 tile (scaled to the footprint)
			var rng := RandomNumberGenerator.new()
			rng.seed = 3301
			var wall := Color("#b9ab92")
			var brick := Color("#9a6a52")
			var dark := Color("#5a534b")
			box(st, Vector3(0, 0.02, 0), Vector3(0.96, 0.04, 0.96), Color("#8a8070"))
			for i in 4:   # jagged wall stubs along the old outline
				var a := i * PI * 0.5
				var d := Vector3(sin(a), 0, cos(a)) * 0.4
				for k in 3:
					var off := Vector3(cos(a), 0, -sin(a)) * (k - 1) * 0.28
					var hgt := rng.randf_range(0.06, 0.3)
					box(st, d + off + Vector3(0, hgt * 0.5, 0), Vector3(0.26 if i % 2 == 0 else 0.06, hgt, 0.06 if i % 2 == 0 else 0.26), wall if k != 1 else brick, Vector3(0, 0, rng.randf_range(-6, 6)))
			for i in 26:  # debris heap: broken slabs, bricks, beams
				var p := Vector3(rng.randf_range(-0.36, 0.36), 0, rng.randf_range(-0.36, 0.36))
				var hh := 0.16 * (1.0 - p.length() / 0.55)
				var sz := Vector3(rng.randf_range(0.06, 0.2), rng.randf_range(0.03, 0.08), rng.randf_range(0.06, 0.2))
				var col: Color = [wall, brick, dark, Color("#7d7468")][i % 4]
				box(st, p + Vector3(0, maxf(0.03, hh * rng.randf_range(0.4, 1.0)), 0), sz, col, Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 90), rng.randf_range(-25, 25)))
			for i in 3:
				box(st, Vector3(rng.randf_range(-0.2, 0.2), 0.12, rng.randf_range(-0.2, 0.2)), Vector3(0.04, 0.04, 0.5), Color("#4a3a2c"), Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 180), 12))
		"fence":
			for fx in [-0.9, -0.3, 0.3, 0.9]:
				box(st, Vector3(fx, 0.3, 0), Vector3(0.08, 0.6, 0.08), Color("#6e5a42"))
			for fy in [0.22, 0.45]:
				box(st, Vector3(0, fy, 0), Vector3(1.9, 0.06, 0.04), Color("#7a6449"))
		"hay_bale":
			cyl(st, Vector3(0, 0.32, 0), 0.32, 0.32, 0.55, Color("#b89b55"), 9, Vector3(0, 0, 90))
		"streetlight":
			cyl(st, Vector3(0, 1.4, 0), 0.035, 0.05, 2.8, Color("#4b4f52"), 6)
			box(st, Vector3(0.28, 2.78, 0), Vector3(0.6, 0.05, 0.08), Color("#4b4f52"))
			box(st, Vector3(0.55, 2.72, 0), Vector3(0.22, 0.07, 0.14), Color("#d8d0b0"))
		"rock":
			sph(st, Vector3(0, 0.25, 0), Vector3(0.7, 0.55, 0.6), Color("#9c8a72"), 6)
			sph(st, Vector3(0.45, 0.15, 0.25), Vector3(0.4, 0.35, 0.35), Color("#8b7a64"), 5)
		"debris_chunk":
			box(st, Vector3.ZERO, Vector3(1, 0.6, 0.8), Color.WHITE)
		"rock_small":
			sph(st, Vector3(0, 0.08, 0), Vector3(0.28, 0.18, 0.24), Color("#a28f75"), 5)
		"power_pole":
			cyl(st, Vector3(0, 1.3, 0), 0.04, 0.06, 2.6, Color("#6a5236"), 5)
			box(st, Vector3(0, 2.45, 0), Vector3(0.9, 0.06, 0.07), Color("#5e4a31"))
			for xx in [-0.38, 0.0, 0.38]:
				cyl(st, Vector3(xx, 2.53, 0), 0.025, 0.03, 0.1, Color("#c9c2b0"), 5)
		"wreck_car":
			var burnt := Color("#3b3430")
			var rust := Color("#6b4a32")
			box(st, Vector3(0, 0.25, 0), Vector3(0.8, 0.28, 1.55), rust)
			box(st, Vector3(0, 0.5, -0.1), Vector3(0.72, 0.24, 0.78), burnt, Vector3(4, 0, 2))
			for wx in [-0.4, 0.4]:
				for wz in [-0.5, 0.5]:
					cyl(st, Vector3(wx, 0.12, wz), 0.14, 0.14, 0.12, Color("#1f1d1c"), 7, Vector3(0, 0, 90))
			box(st, Vector3(0.1, 0.43, 0.62), Vector3(0.5, 0.05, 0.3), Color("#55463a"), Vector3(-25, 0, 0))
		"shack":
			var wall := Color("#b0a083")
			box(st, Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 1.7), wall)
			box(st, Vector3(0, 1.05, 0), Vector3(2.0, 0.1, 1.9), Color("#7f7b72"), Vector3(4, 0, 0))   # corrugated roof
			box(st, Vector3(0.4, 0.35, 0.86), Vector3(0.45, 0.7, 0.04), Color("#5a4632"))
			box(st, Vector3(-0.45, 0.6, 0.86), Vector3(0.4, 0.3, 0.04), Color("#2e3338"))
			box(st, Vector3(-0.9, 0.3, -0.6), Vector3(0.35, 0.6, 0.35), Color("#8a6a3a"))
			box(st, Vector3(-0.45, 0.6, 0.875), Vector3(0.32, 0.22, 0.01), lit("#ffd38a"))   # lit window
			box(st, Vector3(0.4, 0.72, 0.88), Vector3(0.55, 0.04, 0.03), Color("#4a3a2a"))   # door lintel
			box(st, Vector3(0.95, 0.75, 0.2), Vector3(0.12, 0.2, 0.35), Color("#9a9a96"))   # AC box
			cyl(st, Vector3(-0.6, 1.25, -0.4), 0.03, 0.03, 0.4, Color("#6a6a66"), 5)   # flue
		"gas_station":
			var conc := Color("#c8bfae")
			box(st, Vector3(-0.6, 0.6, 0), Vector3(1.6, 1.2, 1.8), conc)                           # shop
			box(st, Vector3(-0.6, 1.22, 0), Vector3(1.7, 0.08, 1.9), Color("#8d877c"))
			box(st, Vector3(0.18, 0.5, 0), Vector3(0.04, 0.6, 1.2), Color("#2d3640"))               # window
			box(st, Vector3(0.9, 1.35, 0), Vector3(1.4, 0.14, 1.9), Color("#c33f2a"))               # canopy (red band)
			box(st, Vector3(0.9, 1.44, 0), Vector3(1.4, 0.05, 1.9), Color("#e8e2d5"))
			for zz in [-0.6, 0.6]:
				cyl(st, Vector3(0.9, 0.65, zz), 0.06, 0.06, 1.3, Color("#d9d3c7"), 6)
				box(st, Vector3(0.9, 0.3, zz * 0.5), Vector3(0.25, 0.6, 0.18), Color("#a83524"))     # pumps
			box(st, Vector3(1.55, 1.6, 0.8), Vector3(0.08, 1.2, 0.08), Color("#5a5650"))
			box(st, Vector3(1.55, 2.25, 0.8), Vector3(0.5, 0.35, 0.06), Color("#e7b23a"))           # sign
			box(st, Vector3(1.55, 2.25, 0.835), Vector3(0.42, 0.26, 0.01), lit("#ffe08a"))
			box(st, Vector3(0.9, 1.275, 0), Vector3(1.2, 0.01, 1.7), lit("#f4f0e0"))                 # canopy lights
			box(st, Vector3(0.2, 0.5, 0), Vector3(0.01, 0.5, 1.1), lit("#fff1cc"))                  # lit shop window
			box(st, Vector3(-0.6, 1.3, -0.5), Vector3(0.4, 0.14, 0.3), Color("#9a9a96"))
		# ---------------------------------------------------------- M2.9 urban props
		"tower_glass":   # 4 x 4 glass office tower with a podium, crown and rooftop plant
			box(st, Vector3(0, 0.6, 0), Vector3(3.9, 1.2, 3.9), Color("#9c968a"))
			box(st, Vector3(0, 0.55, 0), Vector3(3.95, 0.7, 3.2), Color("#2b3640"))
			_tower_bands(st, 3.2, 3.2, 1.2, 8.6, 12, Color("#7d8a93"), Color("#3a5468"))
			for c in [Vector2(-1.6, -1.6), Vector2(1.6, -1.6), Vector2(1.6, 1.6), Vector2(-1.6, 1.6)]:
				box(st, Vector3(c.x, 4.9, c.y), Vector3(0.14, 7.4, 0.14), Color("#c9cdd0"))
			box(st, Vector3(0, 8.75, 0), Vector3(3.3, 0.3, 3.3), Color("#c9cdd0"))
			box(st, Vector3(0.6, 9.1, 0.4), Vector3(1.2, 0.5, 1.0), Color("#8d9296"))
			cyl(st, Vector3(-0.8, 9.6, -0.8), 0.02, 0.05, 1.6, Color("#4b4f52"), 5)
			_tower_windows(st, 3.2, 3.2, 1.2, 8.6, 12, 1, 0.28)
			_roof_beacons(st, 1.55, 1.55, 8.9)
			box(st, Vector3(-0.8, 10.45, -0.8), Vector3(0.09, 0.09, 0.09), Color("#ff3020", BLINK))
			box(st, Vector3(0, 0.55, 1.985), Vector3(3.0, 0.5, 0.02), lit("#fff1cc"))   # lit lobby
			_plinth(st, 3.9, 3.9)
		"tower_apart":   # 4 x 4 concrete apartment block: window bands, balconies, water tanks
			_tower_bands(st, 3.8, 3.8, 0.0, 5.6, 8, Color("#c8bba0"), Color("#3d4650"))
			for i in 7:
				var y := 0.7 * (i + 1) + 0.05
				box(st, Vector3(0, y, 1.98), Vector3(2.8, 0.06, 0.32), Color("#b0a488"))
				box(st, Vector3(0, y + 0.16, 2.12), Vector3(2.8, 0.26, 0.03), Color("#9a8f78"))
				box(st, Vector3(0, y, -1.98), Vector3(2.8, 0.06, 0.32), Color("#b0a488"))
			box(st, Vector3(0, 5.7, 0), Vector3(3.9, 0.15, 3.9), Color("#8f8574"))
			for x in [-1.0, 0.9]:
				cyl(st, Vector3(x, 6.05, 0.8), 0.28, 0.28, 0.55, Color("#d9d4c8"), 8)
			box(st, Vector3(1.1, 0.4, 1.95), Vector3(0.8, 0.8, 0.06), Color("#5a4632"))
			_tower_windows(st, 3.8, 3.8, 0.0, 5.6, 8, 2, 0.35)
			_roof_beacons(st, 1.85, 1.85, 5.78)
			for x in [-1.0, 0.9]:
				cyl(st, Vector3(x, 6.5, 0.8), 0.02, 0.3, 0.35, Color("#a9a49a"), 8)   # tank roofs
			box(st, Vector3(-1.1, 0.4, 1.95), Vector3(0.6, 0.35, 0.03), lit("#ffe2a0"))
			_plinth(st, 3.8, 3.8)
		"tower_office":   # stepped 4 x 4 office: three setbacks and an antenna mast
			_tower_bands(st, 3.9, 3.9, 0.0, 3.0, 4, Color("#b7aa94"), Color("#33444f"))
			_tower_bands(st, 3.0, 3.0, 3.0, 6.4, 5, Color("#a99c86"), Color("#34505f"))
			_tower_bands(st, 2.0, 2.0, 6.4, 9.2, 4, Color("#9d907b"), Color("#355566"))
			box(st, Vector3(0, 9.3, 0), Vector3(2.1, 0.2, 2.1), Color("#7d7468"))
			cyl(st, Vector3(0, 10.6, 0), 0.03, 0.08, 2.6, Color("#4b4f52"), 6)
			box(st, Vector3(0, 0.45, 1.96), Vector3(1.4, 0.9, 0.06), Color("#24303a"))
			box(st, Vector3(0, 0.45, 1.995), Vector3(1.2, 0.7, 0.01), lit("#fff1cc"))
			_tower_windows(st, 3.9, 3.9, 0.0, 3.0, 4, 3, 0.3)
			_tower_windows(st, 3.0, 3.0, 3.0, 6.4, 5, 4, 0.3)
			_tower_windows(st, 2.0, 2.0, 6.4, 9.2, 4, 5, 0.3)
			_roof_beacons(st, 0.95, 0.95, 9.3)
			box(st, Vector3(0, 11.9, 0), Vector3(0.1, 0.1, 0.1), Color("#ff3020", BLINK))
			for c in [Vector2(-1.85, -1.85), Vector2(1.85, 1.85), Vector2(1.4, -1.4), Vector2(-1.4, 1.4)]:
				box(st, Vector3(c.x, 3.12, c.y), Vector3(0.08, 0.08, 0.08), Color("#ff3020", BLINK))
			_plinth(st, 3.9, 3.9)
		"tower_slim":   # 3 x 3 residential tower with a red crown
			_tower_bands(st, 2.7, 2.7, 0.0, 7.0, 10, Color("#d6cdb8"), Color("#3a4652"))
			box(st, Vector3(0, 7.2, 0), Vector3(2.8, 0.4, 2.8), Color("#a3402e"))
			box(st, Vector3(0, 7.6, 0), Vector3(1.2, 0.5, 1.2), Color("#8a8278"))
			_tower_windows(st, 2.7, 2.7, 0.0, 7.0, 10, 6, 0.33)
			_roof_beacons(st, 1.3, 1.3, 7.4)
			box(st, Vector3(0, 7.25, 1.405), Vector3(2.4, 0.12, 0.01), lit("#ffe9c0"))   # crown light strip
			_plinth(st, 2.7, 2.7)
		"shops":   # 4 x 3 two-storey shop row with coloured awnings and signs
			box(st, Vector3(0, 1.0, 0), Vector3(3.9, 2.0, 2.9), Color("#d2c3a2"))
			box(st, Vector3(0, 2.05, 0), Vector3(4.0, 0.12, 3.0), Color("#8f8574"))
			var cols := [Color("#b8402e"), Color("#2f6a8a"), Color("#3f7a3a"), Color("#c99a2e")]
			for i in 4:
				var x := -1.46 + i * 0.97
				box(st, Vector3(x, 0.45, 1.46), Vector3(0.8, 0.8, 0.04), Color("#28333c"))
				box(st, Vector3(x, 0.95, 1.62), Vector3(0.9, 0.06, 0.4), cols[i], Vector3(-18, 0, 0))
				box(st, Vector3(x, 1.4, 1.46), Vector3(0.6, 0.35, 0.04), Color("#3a4652"))
				box(st, Vector3(x, 1.85, 1.47), Vector3(0.7, 0.18, 0.04), cols[(i + 2) % 4])
			box(st, Vector3(1.2, 2.3, -0.6), Vector3(0.7, 0.4, 0.6), Color("#9a9a96"))
			for i in 4:   # M3.0: lit shop fronts + glowing signs, upstairs lights, AC units
				var x2 := -1.46 + i * 0.97
				box(st, Vector3(x2, 0.42, 1.475), Vector3(0.7, 0.55, 0.01), lit(["#ffe2a0", "#fff1cc", "#ffd38a", "#e8f0ff"][i]))
				box(st, Vector3(x2, 1.85, 1.49), Vector3(0.6, 0.12, 0.01), lit(["#ff6a50", "#7fd0ff", "#9cf08a", "#ffd060"][i]))
				if i % 2 == 0:
					box(st, Vector3(x2, 1.4, 1.475), Vector3(0.5, 0.25, 0.01), lit("#ffe2a0"))
				box(st, Vector3(x2 + 0.25, 1.4, 1.52), Vector3(0.22, 0.14, 0.1), Color("#b7b7b0"))
			box(st, Vector3(0, 2.13, 1.46), Vector3(4.0, 0.05, 0.08), Color("#6d6559"))   # parapet
			_plinth(st, 3.9, 2.9)
		"house_a":   # half-timbered two-storey, terracotta roof, green shutters
			_house(st, 2.3, 1.8, 2, Color("#e8dcc0"), Color("#a5482e"), true, Color("#3f6b3a"), false, 1)
		"house_b":   # three-storey town house, dark slate roof, dormers
			_house(st, 2.4, 2.0, 3, Color("#d9c9a8"), Color("#4a4e55"), false, Color(0, 0, 0, 0), true, 2)
		"house_c":   # ochre farmhouse, brown tile roof, red shutters
			_house(st, 2.5, 1.9, 2, Color("#d6b47c"), Color("#7a3e26"), false, Color("#8a2e24"), false, 3)
		"house_d":   # white-washed house, red roof, half-timbered, dormers
			_house(st, 2.2, 1.9, 2, Color("#f0ece2"), Color("#b0502e"), true, Color(0, 0, 0, 0), true, 4)
		"containers":
			_containers(st, 1)
		"car_red", "car_white", "car_blue", "car_silver", "car_taxi", "car_van", "car_suv":
			_car(st, Color(CAR_COL[kind]), kind)
		"streetlight_double":
			cyl(st, Vector3(0, 1.6, 0), 0.04, 0.06, 3.2, Color("#4b4f52"), 6)
			box(st, Vector3(0, 0.1, 0), Vector3(0.22, 0.2, 0.22), Color("#5a5e60"))
			for sx in [-1.0, 1.0]:
				box(st, Vector3(sx * 0.32, 3.18, 0), Vector3(0.64, 0.05, 0.08), Color("#4b4f52"), Vector3(0, 0, sx * -6.0))
				box(st, Vector3(sx * 0.6, 3.12, 0), Vector3(0.24, 0.07, 0.14), Color("#4b4f52"))
				box(st, Vector3(sx * 0.6, 3.08, 0), Vector3(0.2, 0.02, 0.11), Color("#fff2c0"))
		_:
			return null
	st.index()
	var mesh := st.commit()
	_cache[kind] = mesh
	return mesh
