extends Node
## Blockout shots of the unwired MZKT chassis.
##   xvfb-run -a godot --path . --rendering-method mobile --resolution 1600x900 \
##     res://tools/m47/mzkt_shot.tscn -- /tmp/mzkt

var out_dir := "/tmp/mzkt"

var only := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/mzkt"
	only = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await _views()
	print("=== MZKT SHOTS")
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())

func _views() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.91, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.60, 0.55)
	e.ambient_light_energy = 1.05
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -55, 0)
	sun.light_energy = 1.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-70, 140, 0)
	fill.light_energy = 0.42
	add_child(fill)
	var truck := (load("res://view/units/ecc/mzkt_base.tscn") as PackedScene).instantiate() as Node3D
	add_child(truck)
	_paint(truck)
	_measure(truck)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.current = true
	if only == "missile":
		await _missile(cam, sun, truck)
		return
	# Side. Camera on +X. size is the vertical world span. Nose is +Z.
	var eye := Vector3(0, 0.7, 0)
	cam.size = 1.85
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(12, eye.y, 0)
	cam.look_at(eye, Vector3.UP)
	await frames(4)
	await shot("side")
	print("CAM side size ", cam.size, " eye ", eye, " pos ", cam.global_position, " basis_x ", cam.global_basis.x)
	# 2x side crops. Same camera, half the vertical span.
	cam.size = 0.925
	var cab_eye := Vector3(0, 0.72, 1.15)
	cam.global_position = Vector3(12, cab_eye.y, cab_eye.z)
	cam.look_at(cab_eye, Vector3.UP)
	await frames(3)
	await shot("side_cab")
	var bed_eye := Vector3(0, 0.48, -0.55)
	cam.global_position = Vector3(12, bed_eye.y, bed_eye.z)
	cam.look_at(bed_eye, Vector3.UP)
	await frames(3)
	await shot("side_bed")
	cam.size = 1.85
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := Vector3(0, 0.7, 0.2)
	cam.global_position = focus + Vector3(4.6, 2.3, 4.2)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-40, 30, 0)
	await frames(3)
	await shot("three_quarter")
	var cab := Vector3(0.15, 0.85, 1.35)
	cam.global_position = cab + Vector3(2.15, 0.75, 1.35)
	cam.look_at(cab, Vector3.UP)
	sun.rotation_degrees = Vector3(-36, 40, 0)
	await frames(3)
	await shot("cab")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.35
	var front := Vector3(0, 0.72, 1.55)
	cam.global_position = Vector3(0, front.y, 8.0)
	cam.look_at(front, Vector3.UP)
	sun.rotation_degrees = Vector3(-25, 180, 0)
	await frames(3)
	await shot("front")
	print("CAM front basis_x ", cam.global_basis.x)
	cam.size = 4.4
	cam.global_position = Vector3(0, 14, 0.01)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	sun.rotation_degrees = Vector3(-70, 20, 0)
	await frames(3)
	await shot("top")
	await _radar(cam, sun, truck)
	await _missile(cam, sun, truck)
	# Lineup on one ground line, noses toward +Z, gaps measured from each mesh.
	var lineup: Array[Node3D] = [truck]
	var paths := ["res://view/units/ecc/t90.tscn", "res://view/units/ecc/bmp3_v2.tscn", "res://view/units/ecc/mi8_v2.tscn"]
	for pth in paths:
		var n := (load(pth) as PackedScene).instantiate() as Node3D
		add_child(n)
		_paint(n)
		lineup.append(n)
	# Order: T-90, BMP-3, MZKT, Mi-8. truck is already in the tree at index 0 of lineup
	# but was created first. Reorder by moving along Z.
	# Camera right is -Z, so the last vehicle placed (highest Z) appears on the left.
	var order: Array[Node3D] = [lineup[3], lineup[0], lineup[2], lineup[1]]
	var labels := ["mi8", "mzkt", "bmp3", "t90"]
	var cursor := 0.0
	for i in order.size():
		var ab := _aabb(order[i])
		var sz: Vector3 = ab.size
		print("LINE ", labels[i], " size ", sz, " min ", ab.position)
		order[i].position = Vector3(0, 0, cursor - ab.position.z)
		cursor += sz.z + 0.55
	var span := cursor
	var mid := span * 0.5
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	cam.size = (span + 1.2) / aspect
	var look := Vector3(0, 1.1, mid)
	cam.global_position = Vector3(18, look.y, mid)
	cam.look_at(look, Vector3.UP)
	sun.rotation_degrees = Vector3(-30, 80, 0)
	await frames(4)
	await shot("lineup")
	print("CAM lineup size ", cam.size, " look ", look, " basis_x ", cam.global_basis.x, " span ", span)

## Base truck with the unwired radar module parented on ModuleMount.
func _radar(cam: Camera3D, sun: DirectionalLight3D, base: Node3D) -> void:
	base.visible = false
	var rig := (load("res://view/units/ecc/mzkt_base.tscn") as PackedScene).instantiate() as Node3D
	var mod := (load("res://view/units/ecc/mzkt_radar_module.tscn") as PackedScene).instantiate() as Node3D
	var mount := rig.find_child("ModuleMount", true, false) as Node3D
	mount.add_child(mod)
	add_child(rig)
	_paint(rig)
	var whole := _aabb(rig)
	var alone := _aabb(mod)
	var sc := 0.311
	print("RADAR whole u ", whole.size, " m ", whole.size / sc)
	print("RADAR module u ", alone.size, " min ", alone.position, " m ", alone.size / sc, " min m ", alone.position / sc)
	print("RADAR tris ", _tris(mod))
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	var center := whole.get_center()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var side_size := maxf(whole.size.y * 1.12, whole.size.z * 1.08 / aspect)
	cam.size = side_size
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(14, center.y, center.z)
	cam.look_at(center, Vector3.UP)
	await frames(4)
	await shot("radar_side")
	print("CAM radar side size ", cam.size, " center ", center)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := center + Vector3(0, 0.15, 0.2)
	cam.global_position = focus + Vector3(5.4, 2.6, 4.6)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-38, 28, 0)
	await frames(3)
	await shot("radar_three_quarter")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var front_size := maxf(whole.size.y * 1.15, whole.size.x * 1.4 / aspect)
	cam.size = front_size
	var front_at := Vector3(center.x, center.y, whole.position.z + whole.size.z * 0.55)
	cam.global_position = Vector3(front_at.x, front_at.y, whole.position.z + whole.size.z + 6.0)
	cam.look_at(front_at, Vector3.UP)
	sun.rotation_degrees = Vector3(-22, 180, 0)
	await frames(3)
	await shot("radar_front")
	cam.size = maxf(whole.size.z * 1.15 / aspect, whole.size.x * 1.4)
	cam.global_position = Vector3(center.x, center.y + 12.0, center.z + 0.01)
	cam.look_at(Vector3(center.x, 0, center.z), Vector3(0, 0, -1))
	sun.rotation_degrees = Vector3(-70, 20, 0)
	await frames(3)
	await shot("radar_top")
	# 2x the radar side shot, framed on the cabin floor where it meets the deck.
	cam.size = side_size * 0.5
	var join := mount.global_position + Vector3(0.35, 0.02, -0.35)
	sun.rotation_degrees = Vector3(-30, 75, 0)
	cam.global_position = Vector3(12, join.y, join.z)
	cam.look_at(join, Vector3.UP)
	await frames(3)
	await shot("radar_join")
	print("CAM radar join size ", cam.size, " at ", join)
	var hinge := mount.global_position + Vector3(0.1, 1.15, 0.85) * sc
	cam.global_position = Vector3(12, hinge.y, hinge.z)
	cam.look_at(hinge, Vector3.UP)
	await frames(3)
	await shot("radar_hinge")
	print("CAM radar hinge size ", cam.size, " at ", hinge)
	var cabin_side := mount.global_position + Vector3(0.15, 1.00, -1.35) * sc
	cam.global_position = Vector3(12, cabin_side.y, cabin_side.z)
	cam.look_at(cabin_side, Vector3.UP)
	await frames(3)
	await shot("radar_cabin")
	print("CAM radar cabin size ", cam.size, " at ", cabin_side)
	# Array face, from in front of the tilted panel, and the ribbed back.
	var face := mount.global_position + Vector3(0, 2.6, 0.7) * sc
	cam.global_position = face + Vector3(0.15, 0.35, 2.4)
	cam.look_at(face, Vector3.UP)
	sun.rotation_degrees = Vector3(-30, 160, 0)
	await frames(3)
	await shot("radar_array")
	print("CAM radar array size ", cam.size, " at ", face)
	var back := mount.global_position + Vector3(0.2, 2.4, 0.15) * sc
	cam.global_position = back + Vector3(1.6, 0.15, -2.2)
	cam.look_at(back, Vector3.UP)
	sun.rotation_degrees = Vector3(-28, 40, 0)
	await frames(3)
	await shot("radar_array_back")
	print("CAM radar array back size ", cam.size, " at ", back)
	rig.queue_free()
	base.visible = true

## Base truck with the unwired missile module on ModuleMount.
func _missile(cam: Camera3D, sun: DirectionalLight3D, base: Node3D) -> void:
	base.visible = false
	var rig := (load("res://view/units/ecc/mzkt_base.tscn") as PackedScene).instantiate() as Node3D
	var mod := (load("res://view/units/ecc/mzkt_missile_module.tscn") as PackedScene).instantiate() as Node3D
	var mount := rig.find_child("ModuleMount", true, false) as Node3D
	mount.add_child(mod)
	add_child(rig)
	_paint(rig)
	var whole := _aabb(rig)
	var alone := _aabb(mod)
	var sc := 0.311
	print("MISSILE whole u ", whole.size, " m ", whole.size / sc)
	print("MISSILE module u ", alone.size, " min ", alone.position, " m ", alone.size / sc, " min m ", alone.position / sc)
	print("MISSILE tris ", _tris(mod))
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	var center := whole.get_center()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var side_size := maxf(whole.size.y * 1.12, whole.size.z * 1.08 / aspect)
	cam.size = side_size
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(14, center.y, center.z)
	cam.look_at(center, Vector3.UP)
	await frames(4)
	await shot("missile_side")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := center + Vector3(0, 0.1, 0.1)
	cam.global_position = focus + Vector3(5.2, 2.4, 4.4)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-36, 32, 0)
	await frames(3)
	await shot("missile_three_quarter")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(whole.size.y * 1.15, whole.size.x * 1.4 / aspect)
	var front_at := Vector3(center.x, center.y, whole.position.z + whole.size.z * 0.55)
	cam.global_position = Vector3(front_at.x, front_at.y, whole.position.z + whole.size.z + 6.0)
	cam.look_at(front_at, Vector3.UP)
	sun.rotation_degrees = Vector3(-22, 180, 0)
	await frames(3)
	await shot("missile_front")
	cam.size = maxf(whole.size.z * 1.15 / aspect, whole.size.x * 1.4)
	cam.global_position = Vector3(center.x, center.y + 12.0, center.z + 0.01)
	cam.look_at(Vector3(center.x, 0, center.z), Vector3(0, 0, -1))
	sun.rotation_degrees = Vector3(-70, 20, 0)
	await frames(3)
	await shot("missile_top")
	cam.size = side_size * 0.5
	var hinge := mount.global_position + Vector3(0.1, 0.9, 0.7) * sc
	sun.rotation_degrees = Vector3(-30, 75, 0)
	cam.global_position = Vector3(12, hinge.y, hinge.z)
	cam.look_at(hinge, Vector3.UP)
	await frames(3)
	await shot("missile_hinge")
	print("CAM missile hinge size ", cam.size, " at ", hinge)
	var join := mount.global_position + Vector3(0.2, 0.15, 0.4) * sc
	cam.global_position = Vector3(12, join.y, join.z)
	cam.look_at(join, Vector3.UP)
	await frames(3)
	await shot("missile_join")
	print("CAM missile join size ", cam.size, " at ", join)
	await _missile_setup(cam, sun, rig, mod, mount, sc)
	rig.queue_free()
	base.visible = true

## Stowed and deployed poses, two close views, and six frames of deploy.
## The scene rest pose is stowed. The AnimationPlayer is not wired to gameplay.
func _missile_setup(cam: Camera3D, sun: DirectionalLight3D, rig: Node3D, mod: Node3D, mount: Node3D, sc: float) -> void:
	var ap := mod.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("ANIMS ", ap.get_animation_list())
	await _pose(ap, 0.0)
	_report_motion(mod, sc, 0.0)
	var aspect := get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y
	await _pose_views(cam, sun, rig, "missile_stowed", aspect)
	var side_size := maxf(_aabb(rig).size.y * 1.12, _aabb(rig).size.z * 1.08 / aspect)
	var piv := mod.get_node("LauncherYaw/LauncherPivot") as Node3D
	var stack := piv.to_global(Vector3(0, 0.82 * sc, -2.55 * sc))
	await _zoom_side(cam, sun, stack, side_size * 0.5, "missile_zoom_stack")
	print("ZOOM stack size ", side_size * 0.5, " at ", stack, " stowed |x| m ", _half_x(mod) / sc)
	await _pose(ap, 8.0)
	_report_motion(mod, sc, 8.0)
	var deployed_size := await _pose_views(cam, sun, rig, "missile_deployed", aspect)
	var deck := mod.to_global(Vector3(0, 0.25 * sc, -2.40 * sc))
	await _zoom_side(cam, sun, deck, side_size * 0.5, "missile_zoom_deck")
	print("ZOOM deck size ", side_size * 0.5, " at ", deck)
	var pad := mod.find_child("OutriggerFR", true, false).find_child("Sole", true, false) as Node3D
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	sun.rotation_degrees = Vector3(-28, 50, 0)
	var at := pad.global_position + Vector3(0, 0.18, 0)
	cam.global_position = at + Vector3(0.70, 0.02, 0.45)
	cam.look_at(at, Vector3.UP)
	await frames(3)
	await shot("missile_zoom_pad")
	print("CAM pad zoom fov ", cam.fov, " at ", at)
	var tip := mod.get_node("LauncherYaw/RamR/Rod/Tip") as Node3D
	var eye := mod.get_node("LauncherYaw/LauncherPivot/EyeR") as Node3D
	var ram_at := (tip.global_position + eye.global_position) * 0.5
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.36
	sun.rotation_degrees = Vector3(-24, 70, 0)
	cam.global_position = Vector3(ram_at.x + 3.2, ram_at.y, ram_at.z)
	cam.look_at(ram_at, Vector3.UP)
	await frames(3)
	await shot("missile_zoom_rams")
	print("CAM ram zoom size ", cam.size, " at ", ram_at, " gap m ", tip.global_position.distance_to(eye.global_position) / sc)
	# One three-quarter camera for the whole strip, framed on the planted truck.
	var whole := _aabb(rig)
	var center := whole.get_center()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 30.0
	var focus := center + Vector3(0, 0.05, 0)
	cam.global_position = focus + Vector3(6.4, 3.2, 5.2)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-36, 32, 0)
	print("STRIP focus ", focus)
	for i in 6:
		var t := 8.0 * float(i) / 5.0
		await _pose(ap, t)
		_report_motion(mod, sc, t)
		await frames(2)
		await shot("missile_deploy_%d" % i)
	print("DEPLOYED side size was ", deployed_size)
	for t in [0.4, 2.0, 3.0, 4.4, 5.05, 6.48, 7.15]:
		await _pose(ap, t)
		_report_motion(mod, sc, t)
	ap.play(&"pack")
	ap.seek(0.0, true)
	ap.pause()
	await get_tree().process_frame
	_report_motion(mod, sc, 0.0)
	print("PACK t0 is the deployed pose")
	ap.seek(8.0, true)
	await get_tree().process_frame
	_report_motion(mod, sc, 8.0)
	print("PACK t8 is the stowed pose")
	await _pose(ap, 8.0)
	var yaw_node := mod.get_node("LauncherYaw") as Node3D
	mod.aim_at(yaw_node.global_position + Vector3(20.0, 0.0, 0.0))
	print("AIM right deg ", rad_to_deg(yaw_node.rotation.y))
	mod.aim_at(yaw_node.global_position + Vector3(0.0, 0.0, -20.0))
	print("AIM aft deg ", rad_to_deg(yaw_node.rotation.y))
	await _missile_yaw(cam, sun, rig, mod, sc, aspect)

func _pose_views(cam: Camera3D, sun: DirectionalLight3D, rig: Node3D, prefix: String, aspect: float) -> float:
	var whole := _aabb(rig)
	var center := whole.get_center()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var side_size := maxf(whole.size.y * 1.12, whole.size.z * 1.08 / aspect)
	cam.size = side_size
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(14, center.y, center.z)
	cam.look_at(center, Vector3.UP)
	await frames(3)
	await shot(prefix + "_side")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var focus := center + Vector3(0, 0.05, 0.05)
	cam.global_position = focus + Vector3(5.6, 2.6, 4.6)
	cam.look_at(focus, Vector3.UP)
	sun.rotation_degrees = Vector3(-36, 32, 0)
	await frames(3)
	await shot(prefix + "_three_quarter")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(whole.size.y * 1.2, whole.size.x * 1.15 / aspect)
	var front_at := Vector3(center.x, center.y, whole.position.z + whole.size.z * 0.62)
	cam.global_position = Vector3(front_at.x, front_at.y, whole.position.z + whole.size.z + 6.0)
	cam.look_at(front_at, Vector3.UP)
	sun.rotation_degrees = Vector3(-22, 180, 0)
	await frames(3)
	await shot(prefix + "_front")
	return side_size

## Deployed cradle at three bearings. Top has the cab toward the top of the frame.
func _missile_yaw(cam: Camera3D, sun: DirectionalLight3D, rig: Node3D, mod: Node3D, sc: float, aspect: float) -> void:
	for deg in [0, 90, 135, 180]:
		mod.target_yaw_deg = float(deg)
		await get_tree().process_frame
		_report_motion(mod, sc, 8.0)
		var held: float = rad_to_deg((mod.get_node("LauncherYaw") as Node3D).rotation.y)
		print("YAW set ", deg, " held ", held)
		var whole := _aabb(rig)
		var center := whole.get_center()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(whole.size.x * 1.2, whole.size.z * 1.12 / aspect)
		cam.global_position = Vector3(center.x, center.y + 16.0, center.z)
		cam.look_at(Vector3(center.x, 0.0, center.z), Vector3(0, 0, 1))
		sun.rotation_degrees = Vector3(-70, 25, 0)
		await frames(3)
		await shot("missile_yaw_%d_top" % deg)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 28.0
		var focus := center + Vector3(0, 0.1, 0)
		cam.global_position = focus + Vector3(6.4, 3.6, 5.2)
		cam.look_at(focus, Vector3.UP)
		sun.rotation_degrees = Vector3(-36, 32, 0)
		await frames(3)
		await shot("missile_yaw_%d_three_quarter" % deg)
	mod.target_yaw_deg = 0.0

func _zoom_side(cam: Camera3D, sun: DirectionalLight3D, at: Vector3, size: float, name: String) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	sun.rotation_degrees = Vector3(-28, 70, 0)
	cam.global_position = Vector3(14.0, at.y, at.z)
	cam.look_at(at, Vector3.UP)
	await frames(3)
	await shot(name)

func _half_x(mod: Node3D) -> float:
	var ab := _aabb(mod)
	return maxf(absf(ab.position.x), absf(ab.position.x + ab.size.x))

func _pose(ap: AnimationPlayer, t: float) -> void:
	ap.play(&"deploy")
	ap.seek(t, true)
	ap.pause()
	await get_tree().process_frame

func _report_motion(mod: Node3D, sc: float, t: float) -> void:
	var worst := 0.0
	var worst_name := ""
	for pair in [["RamR", "EyeR"], ["RamL", "EyeL"]]:
		var tip := mod.get_node("LauncherYaw/" + String(pair[0]) + "/Rod/Tip") as Node3D
		var eye := mod.get_node("LauncherYaw/LauncherPivot/" + String(pair[1])) as Node3D
		var d := tip.global_position.distance_to(eye.global_position) / sc
		if d > worst:
			worst = d
			worst_name = String(pair[0])
	var low := 100.0
	var high := -100.0
	var wide := 0.0
	for sole in mod.find_children("Sole", "Marker3D", true, false):
		var y: float = (sole as Node3D).global_position.y
		low = minf(low, y)
		high = maxf(high, y)
		wide = maxf(wide, absf((sole as Node3D).global_position.x))
	var ab := _aabb(mod)
	var half_x := maxf(absf(ab.position.x), absf(ab.position.x + ab.size.x))
	print("MOTION t %.2f  ram gap %s %.4f m  sole y %.4f..%.4f  sole |x| %.3f m  module |x| %.3f m" % [t, worst_name, worst, low, high, wide / sc, half_x / sc])

func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == null:
			continue
		var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		if first:
			out = ab
			first = false
		else:
			out = out.merge(ab)
	return out

func _paint(n: Node) -> void:
	var olive := Color("#96A468")
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.set_instance_shader_parameter(&"paint_color", olive)
		gi.set_instance_shader_parameter(&"rust_amt", 0.15)
		gi.set_instance_shader_parameter(&"wear_amt", 0.35)
		gi.set_instance_shader_parameter(&"dirt_amt", 0.45)

func _tris(n: Node) -> int:
	var t := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		if m == null:
			continue
		for s in m.get_surface_count():
			t += m.surface_get_array_index_len(s) / 3
	return t

func _measure(model: Node3D) -> void:
	var sc := 0.311
	var ab := _aabb(model)
	var sz := ab.size
	print("AABB min ", ab.position, " size u ", sz)
	print("AABB m ", sz / sc, " ground y ", ab.position.y)
	print("TRIS ", _tris(model))
	print("BAR ", (model.find_child("HealthBarAnchor", true, false) as Node3D).position, " sel ", model.get("selection_radius"))
	var mount := model.find_child("ModuleMount", true, false) as Node3D
	print("MOUNT ", mount.position, " m ", mount.position / sc)
	for name in ["JackFL", "JackFR", "JackRL", "JackRR"]:
		var mk := model.find_child(name, true, false) as Node3D
		print("JACK ", name, " ", mk.position, " m ", mk.position / sc)
