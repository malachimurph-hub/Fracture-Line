extends Node3D
## Traverse for the unwired missile module. Yaw 0 points the canisters aft, along -Z.
## With the cradle raised, the box clears the cab, the engine bay and the jacks
## all the way round, so the stop is a full circle. Gameplay does not call this.

@export_range(-180.0, 180.0, 0.1) var target_yaw_deg: float = 0.0:
	set(value):
		target_yaw_deg = wrapf(value, -180.0, 180.0)
		_apply_yaw()

## Degrees either side of aft. 180 meets itself, so nothing stops the turntable short.
const YAW_LIMIT_DEG := 180.0

func _apply_yaw() -> void:
	var yaw := get_node_or_null("LauncherYaw") as Node3D
	if yaw == null:
		return
	yaw.rotation.y = deg_to_rad(target_yaw_deg)

## Face a world point. Only the bearing moves. Elevation stays on the deploy pose.
func aim_at(world_pos: Vector3) -> void:
	var yaw := get_node_or_null("LauncherYaw") as Node3D
	if yaw == null:
		return
	var local := to_local(world_pos)
	var flat := Vector2(local.x - yaw.position.x, local.z - yaw.position.z)
	if flat.length() < 0.001:
		return
	# At yaw 0 the canisters point aft: direction (-sin yaw, -cos yaw) in (x, z).
	var deg := rad_to_deg(atan2(-flat.x, -flat.y))
	target_yaw_deg = clampf(wrapf(deg, -180.0, 180.0), -YAW_LIMIT_DEG, YAW_LIMIT_DEG)
