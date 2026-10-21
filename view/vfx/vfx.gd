class_name Vfx
extends Node3D
## Pooled, view-only effects: tracers, muzzle flashes, explosions, rings, scorch decals,
## command markers. Never touches the simulation. Respects the "reduce flashing" idea by
## keeping flashes small and short.

var items: Array = []      ## [{node, t, life, kind, data}]
var pool: Dictionary = {}  ## kind -> Array[MeshInstance3D]
var _box := BoxMesh.new()
var _sph := SphereMesh.new()
var _quad := PlaneMesh.new()
var _ring: ArrayMesh

func _ready() -> void:
	_box.size = Vector3.ONE
	_sph.radius = 0.5
	_sph.height = 1.0
	_sph.radial_segments = 10
	_sph.rings = 5
	_quad.size = Vector2.ONE
	_ring = Palette.ring_mesh("circle", 0.12)

func _take(kind: String, mesh: Mesh) -> MeshInstance3D:
	var arr: Array = pool.get(kind, [])
	var mi: MeshInstance3D
	if arr.is_empty():
		mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	else:
		mi = arr.pop_back()
		mi.visible = true
	return mi

func _add(kind: String, mi: MeshInstance3D, life: float, data: Dictionary = {}) -> void:
	items.append({"n": mi, "t": 0.0, "life": life, "k": kind, "d": data})

func tracer(from: Vector3, to: Vector3, col: Color, width: float = 0.05, life: float = 0.09) -> void:
	if items.size() > 400:
		return
	var mi := _take("box", _box)
	var mid := (from + to) * 0.5
	var len := from.distance_to(to)
	if len < 0.01:
		return
	mi.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), mid).scaled_local(Vector3(width, width, len))
	mi.material_override = Palette.flat(col)
	_add("box", mi, life)

func flash(p: Vector3, col: Color, size: float, life: float = 0.12) -> void:
	if items.size() > 400:
		return
	var mi := _take("sph", _sph)
	mi.position = p
	mi.scale = Vector3.ONE * size
	mi.material_override = Palette.flat(col, 0.85)
	_add("sph", mi, life, {"grow": size * 0.6, "s": size})

func explosion(p: Vector3, size: float) -> void:
	flash(p + Vector3(0, 0.3, 0), Color("#ffd27a"), size * 1.2, 0.22)
	flash(p + Vector3(0, 0.5, 0), Color("#ff7a2a"), size * 0.8, 0.35)
	flash(p + Vector3(0, 0.8, 0), Color("#4a4a4a"), size * 1.0, 0.7)
	scorch(p, size)

func scorch(p: Vector3, size: float) -> void:
	var mi := _take("quad", _quad)
	mi.position = p + Vector3(0, 0.03, 0)
	mi.scale = Vector3(size * 1.4, 1, size * 1.4)
	mi.rotation = Vector3(0, fmod(p.x * 7.0 + p.z * 3.0, TAU), 0)
	mi.material_override = Palette.flat(Color(0.08, 0.07, 0.06), 0.6)
	_add("quad", mi, 60.0, {"fade": true})

func ring(p: Vector3, radius: float, col: Color, life: float = 0.6, shrink: bool = true) -> void:
	var mi := _take("ring", _ring)
	mi.position = p + Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * radius
	mi.material_override = Palette.flat(col, 0.9)
	_add("ring", mi, life, {"r": radius, "shrink": shrink})

func _process(delta: float) -> void:
	var keep: Array = []
	for it in items:
		it["t"] += delta
		var mi: MeshInstance3D = it["n"]
		var k: float = it["t"] / it["life"]
		if k >= 1.0:
			mi.visible = false
			if not pool.has(it["k"]):
				pool[it["k"]] = []
			pool[it["k"]].append(mi)
			continue
		var d: Dictionary = it["d"]
		if d.has("grow"):
			mi.scale = Vector3.ONE * (d["s"] + d["grow"] * k)
		elif d.has("shrink"):
			var r: float = d["r"] * ((1.0 - 0.6 * k) if d["shrink"] else (0.4 + 0.6 * k))
			mi.scale = Vector3.ONE * r
		keep.append(it)
	items = keep
