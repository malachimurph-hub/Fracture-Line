extends Node
## M3.3 Phase 4 (item 9): HUD icons rendered from the game's own models (no outside art).
##   xvfb-run -a godot --path . --rendering-method mobile res://tools/gfx_m33/icons.tscn [-- <id> ...]
## Every unit and structure with a view scene -> res://ui/icons/<id>.png (128 x 128, transparent):
## three-quarter front view, auto-framed on the model's meshes, team blue, the faction's finish,
## soft dark rim so the icon reads on any button colour.
const SRC := 384
const OUT := 128
const DIR := "res://ui/icons/"

var vp: SubViewport
var cam: Camera3D

func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	vp = SubViewport.new()
	vp.size = Vector2i(SRC, SRC)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.78)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.35
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.fov = 22.0
	vp.add_child(cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var jobs: Array = []
	for id in Content.units:
		jobs.append([id, Content.units[id].view_scene])
	for id in Content.buildings:
		jobs.append([id, Content.buildings[id].view_scene])
	var n := 0
	for j in jobs:
		if not only.is_empty() and not only.has(String(j[0])):
			continue
		if String(j[1]) == "" or not ResourceLoader.exists(j[1]):
			print("ICON SKIP ", j[0], " (no view)")
			continue
		await _render(StringName(j[0]), String(j[1]))
		n += 1
	print("ICONS DONE ", n)
	get_tree().quit(0)

func _meshes(n: Node, out: Array) -> void:
	if n is GeometryInstance3D and (n as GeometryInstance3D).visible:
		var nm := String(n.name).to_lower()
		var g := n as GeometryInstance3D
		if not (nm.contains("shadow") or nm.contains("ring") or nm.contains("blob") or nm.contains("select") or nm.contains("dust") or nm.contains("smoke")) \
				and g.visibility_range_begin <= 0.0 and (n is MeshInstance3D or n is MultiMeshInstance3D):
			out.append(n)
	for c in n.get_children():
		if c is Node3D and not (c as Node3D).visible:
			continue
		_meshes(c, out)

func _render(id: StringName, scene: String) -> void:
	var v: Node3D = load(scene).instantiate()
	vp.add_child(v)
	if v.has_method("set_team_material"):
		v.set_team_material(Palette.team_material(0))
	var s := String(id)
	Weathering.apply(v, &"tpla" if s.begins_with("tpla_") else (&"eu" if s.begins_with("eu_") else (&"ecc" if s.begins_with("ecc_") else &"neutral")))
	for k in 3:
		await get_tree().process_frame
	var ms: Array = []
	_meshes(v, ms)
	var box := AABB()
	var first := true
	for m in ms:
		var gi := m as GeometryInstance3D
		var bb: AABB = gi.global_transform * gi.get_aabb()
		if not (bb.position.is_finite() and bb.size.is_finite()) or bb.size.length() > 200.0 or bb.size.length() < 0.001:
			continue
		box = bb if first else box.merge(bb)
		first = false
	if v is InfantryView:   # VAT squads: the mesh AABB covers every animation frame, frame the soldiers
		var hgt: float = float(v.get("bar_height")) * 0.95
		first = true
		for fpt: Vector3 in v.get("formation"):
			var bb2 := AABB(fpt + Vector3(-0.22, 0, -0.22), Vector3(0.44, hgt, 0.44))
			box = bb2 if first else box.merge(bb2)
			first = false
	if first:
		box = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	if OS.has_environment("ICON_DBG"): print("DBG ", id, " ", ms.size(), " ", box)
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var yaw := deg_to_rad(-38.0)
	var pitch := deg_to_rad(30.0)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var dist := r / sin(deg_to_rad(cam.fov * 0.5)) * (0.62 if v is InfantryView else 0.8)
	cam.position = c + dir * dist
	cam.look_at(c)
	cam.near = maxf(0.01, dist - r * 2.0)
	cam.far = dist + r * 2.0
	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img = _rim(img)
	img = _square_crop(img)
	img.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(DIR + s + ".png"))
	print("ICON ", s)
	v.queue_free()
	await get_tree().process_frame

## Crop to the drawn pixels and centre them on a square with a small margin, so every icon fills
## its button the same way whatever the model's proportions.
static func _square_crop(img: Image) -> Image:
	var r := img.get_used_rect()
	if r.size.x < 4 or r.size.y < 4:
		return img
	var side := int(maxf(r.size.x, r.size.y) * 1.06)
	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, r, Vector2i((side - r.size.x) / 2, (side - r.size.y) / 2))
	return out

## A soft dark rim (dilated alpha) behind the model so it reads on light and dark buttons.
static func _rim(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var a := PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = img.get_pixel(x, y).a
	var d := a.duplicate()
	var rad := 5
	for pass_i in 2:   # separable max filter
		var src := d.duplicate()
		for y in h:
			for x in w:
				var mx := 0.0
				for k in range(-rad, rad + 1):
					var xx := x + k if pass_i == 0 else x
					var yy := y if pass_i == 0 else y + k
					if xx >= 0 and xx < w and yy >= 0 and yy < h:
						mx = maxf(mx, src[yy * w + xx])
				d[y * w + x] = mx
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var col := img.get_pixel(x, y)
			var rim := Color(0.04, 0.05, 0.06, d[y * w + x] * 0.55)
			out.set_pixel(x, y, rim.blend(col) if col.a > 0.0 else rim)
	return out
