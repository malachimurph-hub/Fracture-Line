class_name RigGeo
extends RefCounted
## Runtime mesh builder for view-only construction props (M2.4): boxes and square tubes,
## flat-shaded and vertex-coloured for view/materials/model_m3.gdshader (part class in vertex
## alpha, see the shader header), so every prop is ONE surface / one draw call.
enum { PAINT = 0, GLASS = 2, LAMP = 5, STEEL = 6, CANVAS = 9, CONCRETE = 10, CORR = 11, WOOD = 12, SANDBAG = 13, DARK = 16, SCRAP = 17 }

var st := SurfaceTool.new()
var tris := 0
var _col := Color.WHITE

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func color(c: Variant, cls: int) -> void:
	var cc: Color = Color(c) if c is String else c
	cc.a = float(cls) / 20.0
	_col = cc

## Quad a-b-c-d, turned to face away from `ctr` (Godot front faces are clockwise).
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ctr: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c + d) * 0.25 - ctr) < 0.0:
		var t := b
		b = d
		d = t
		n = -n
	for p in [a, c, b, a, d, c]:
		st.set_color(_col)
		st.set_normal(n)
		st.add_vertex(p)
	tris += 2

## Box with half extents h under basis b, centred at c (all six faces, outward).
func obox(c: Vector3, h: Vector3, b: Basis = Basis.IDENTITY) -> void:
	var x := b.x * h.x
	var y := b.y * h.y
	var z := b.z * h.z
	var p := [c - x - y - z, c + x - y - z, c + x - y + z, c - x - y + z,
		c - x + y - z, c + x + y - z, c + x + y + z, c - x + y + z]
	_quad(p[4], p[5], p[6], p[7], c)   # top
	_quad(p[3], p[2], p[1], p[0], c)   # bottom
	_quad(p[0], p[1], p[5], p[4], c)   # -z
	_quad(p[2], p[3], p[7], p[6], c)   # +z
	_quad(p[3], p[0], p[4], p[7], c)   # -x
	_quad(p[1], p[2], p[6], p[5], c)   # +x

func box(c: Vector3, s: Vector3, yaw: float = 0.0) -> void:
	obox(c, s * 0.5, Basis(Vector3.UP, yaw))

## Square tube (pole, ledger, brace) of half-width r between two points.
func tube(a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	obox((a + b) * 0.5, Vector3(r, l * 0.5, r), Basis(x, y, z))

## Thin sheet (tarp, netting, board) spanning a..b horizontally and rising h, thickness t.
func sheet(a: Vector3, b: Vector3, h: float, t: float = 0.01, sag: float = 0.0) -> void:
	var m := (a + b) * 0.5 + Vector3(0, h * 0.5, 0)
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return
	var x := d / l
	var y := Vector3.UP
	var z := x.cross(y).normalized()
	obox(m + z * sag, Vector3(l * 0.5, h * 0.5, t), Basis(x, y, z))

func commit(mat: Material) -> ArrayMesh:
	var m := st.commit()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, mat)
	return m
