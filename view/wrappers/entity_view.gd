class_name EntityView
extends Node3D
## View wrapper for a unit/structure (GDD 14.6). Placeholder art lives under "Model";
## swapping art means replacing that child and refitting the anchors below. Simulation data
## is never edited for art.
@export var selection_radius: float = 0.6     ## world units (tiles)
@export var bar_height: float = 1.2           ## health bar anchor height
@export var footprint: Vector2 = Vector2.ONE  ## structures
@export var is_structure: bool = false

var model: Node3D
var turret: Node3D
var team_meshes: Array = []
var tier_meshes: Array = []   ## TPLA salvage bolt-ons (meta "tier" = 1..3)
var _ghosted := false

func _ready() -> void:
	model = get_node_or_null("Model")
	turret = find_child("TurretPivot", true, false)
	_collect(self)

func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and (c.has_meta("team") or c.has_meta("team_surface")):
			team_meshes.append(c)
		if c is Node3D and c.has_meta("tier"):
			tier_meshes.append(c)
		_collect(c)

func set_team_material(mat: Material) -> void:
	for m in team_meshes:
		if m.has_meta("team_surface"):
			m.set_surface_override_material(int(m.get_meta("team_surface")), mat)
		else:
			m.material_override = mat

func set_overlay(mat: Material) -> void:
	_overlay(self, mat)

func _overlay(n: Node, mat: Material) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.material_overlay = mat
		_overlay(c, mat)

## Shows the salvage bolt-ons up to tier t (0 = stock).
func set_tier(t: int) -> void:
	for m in tier_meshes:
		m.visible = int(m.get_meta("tier")) <= t

## Own structure hidden by a Camo Net / Demo Trap: drawn see-through for its owner.
func set_ghosted(on: bool) -> void:
	if on == _ghosted:
		return
	_ghosted = on
	_ghost(self, 0.55 if on else 0.0)

func _ghost(n: Node, a: float) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.transparency = a
		_ghost(c, a)
