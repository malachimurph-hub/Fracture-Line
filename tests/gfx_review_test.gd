extends RefCounted
## Headless checks for the isolated graphics review.
## This does not judge how the scene looks. Screenshots do that.
##   godot --headless --path . res://tests/test_runner.tscn -- gfx_review

const BANNED := ["Lockheed", "Boeing", "Sikorsky", "Raytheon", "Northrop", "General Dynamics", "Textron"]


static func run(t: Node) -> void:
	t._check(str(ProjectSettings.get_setting("application/config/version")) == "0.4.6", "version stays 0.4.6")
	var u: UnitDef = Content.unit(&"us_halberd")
	t._check(u.view_scene == "res://view/units/us/halberd.tscn" and u.cost == 1200 and u.max_hp == 980, "live M1A3 card is untouched")
	var pad: BuildingDef = Content.building(&"us_zeus_launcher")
	t._check(pad.cost == 8500 and pad.power == -11 and pad.footprint == Vector2i(4, 3), "ZEUS launcher card is untouched")
	var menu := FileAccess.get_file_as_string("res://ui/main_menu.gd")
	t._check(menu.contains("res://demo/gfx_quality/combat_review.tscn"), "the main menu can open the review")
	t._check(not menu.contains("view/units/us/halberd.tscn"), "the menu does not retarget the live tank")
	for path in ["res://demo/gfx_quality/combat_review.gd", "res://demo/gfx_quality/README.md", "res://assets/gfx_review/SOURCES.md"]:
		var text := FileAccess.get_file_as_string(path)
		for word in BANNED:
			t._check(not text.contains(word), "%s has no company name (%s)" % [path.get_file(), word])
	var scene: Node = load("res://demo/gfx_quality/combat_review.tscn").instantiate()
	t.add_child(scene)
	await t.get_tree().process_frame
	scene.set_process(false)
	t._check(scene.get_node_or_null("ScorchGround") is MeshInstance3D, "the scorch mark is a mesh quad")
	t._check(scene.find_child("Decal*", true, false) == null, "the review does not use a Decal node")
	var hull := scene.find_child("Hull", true, false) as MeshInstance3D
	t._check(hull != null and hull.mesh != null, "the M1A3 hull mesh loaded")
	if hull != null and hull.mesh != null:
		var uv: PackedVector2Array = hull.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		t._check(uv.size() > 200, "the hull has a UV map (%d verts)" % uv.size())
		var tris: int = int(hull.mesh.surface_get_array_index_len(0) / 3)
		t._check(tris > 400 and tris < 12000, "the hull is a fitted mesh, not a single box (%d tris)" % tris)
	var img := Image.new()
	t._check(img.load("res://assets/gfx_review/m1a3_albedo.png") == OK, "tank albedo loads")
	if img.get_width() > 0:
		var mean := 0.0
		var n := 0
		for y in range(0, img.get_height(), 47):
			for x in range(0, img.get_width(), 47):
				mean += img.get_pixel(x, y).r
				n += 1
		mean /= maxf(1.0, float(n))
		var varc := 0.0
		for y in range(0, img.get_height(), 47):
			for x in range(0, img.get_width(), 47):
				var d: float = img.get_pixel(x, y).r - mean
				varc += d * d
		varc /= maxf(1.0, float(n))
		t._check(varc > 0.004, "tank albedo is not a flat colour (variance %.4f)" % varc)
	var method := RenderingServer.get_current_rendering_method()
	var decal_ok := method == "forward_plus" or method == "mobile"
	print("GFX-REVIEW headless renderer=%s decal_node_supported=%s (scorch does not depend on it)" % [method, decal_ok])
	# Drive the shot without rendering a frame per step.
	for _i in 220:
		scene._advance(0.05)
		if scene.phase == "aftermath":
			break
	t._check(scene.phase == "aftermath" and scene.wrecked, "the sequence reaches the wreck")
	t._check(scene.live_smoke() <= scene.SMOKE_MAX, "smoke stays inside the cap (%d/%d)" % [scene.live_smoke(), scene.SMOKE_MAX])
	t._check(scene.live_fire() <= scene.FIRE_MAX, "fire stays inside the cap (%d/%d)" % [scene.live_fire(), scene.FIRE_MAX])
	var before: int = scene.live_smoke()
	scene._impact()
	t._check(scene.live_smoke() <= scene.SMOKE_MAX and scene.impacts == 2, "a second hit recycles the pool (%d live, %d impacts)" % [scene.live_smoke(), scene.impacts])
	t._check(before <= scene.SMOKE_MAX, "the first burst was already capped")
	scene.queue_free()
