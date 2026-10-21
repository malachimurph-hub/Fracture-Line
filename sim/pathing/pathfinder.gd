class_name Pathfinder
extends RefCounted
## Pathfinding interface for the sim. M1 backend: Godot's AStarGrid2D (single-threaded,
## deterministic C++ grid A* with jump-point search), one grid per move layer.
## GDD 17.4 flowfields are planned behind this same interface (see KNOWN_ISSUES).

var foot := AStarGrid2D.new()
var veh := AStarGrid2D.new()

func setup(m: SimMap) -> void:
	for g in [foot, veh]:
		g.region = Rect2i(0, 0, m.w, m.h)
		g.cell_size = Vector2(1, 1)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.jumping_enabled = true
		g.update()
	for y in m.h:
		for x in m.w:
			var t := Vector2i(x, y)
			foot.set_point_solid(t, not m.terrain_passable(t, false))
			veh.set_point_solid(t, not m.terrain_passable(t, true))

func set_solid(t: Vector2i, solid: bool) -> void:
	# Re-apply terrain when un-solidifying
	foot.set_point_solid(t, solid or _terrain_solid(t, false))
	veh.set_point_solid(t, solid or _terrain_solid(t, true))

var _map: SimMap
func bind(m: SimMap) -> void:
	_map = m

func _terrain_solid(t: Vector2i, vehicle: bool) -> bool:
	if _map == null:
		return false
	return not _map.terrain_passable(t, vehicle)

## Returns Array[Vector2i] of tiles from start (exclusive) to goal, partial if unreachable.
func find(from: Vector2i, to: Vector2i, vehicle: bool) -> Array:
	var g: AStarGrid2D = veh if vehicle else foot
	if not g.is_in_boundsv(from) or not g.is_in_boundsv(to):
		return []
	var p: Array[Vector2i] = g.get_id_path(from, to, true)
	var out: Array = []
	for i in range(1, p.size()):
		out.append(p[i])
	return out
