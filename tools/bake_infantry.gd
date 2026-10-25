extends SceneTree
## Bakes CC0 Quaternius "Toon Shooter" characters into VatModel resources (M2.2 graphics).
##   godot --headless --path . -s res://tools/bake_infantry.gd
## For each soldier: loads the glTF at runtime (GLTFDocument), keeps body + head + pads + one
## weapon, recolours the materials per faction (team colour flagged in vertex alpha),
## decimates to ~TARGET_TRIS with the engine's LOD simplifier, compacts the vertex buffer,
## then samples Idle / Run_Gun / Idle_Shoot / Death at FPS with CPU skinning into textures.
const SRC := "res://assets_src/quaternius_toon_shooter/"
const OUT := "res://assets/models/infantry/"
const FPS := 15.0
const TARGET_TRIS := 1300
const HEIGHT := 0.5          # model units (old procedural soldiers were 0.5; WorldView scales infantry x1.4)
## M2.6 realistic proportions (Malachi: "less cartoony infantry"): the toon rig is re-proportioned
## at bake time in bone space - smaller head, longer legs and arms, taller torso - so soldiers read
## as adults at RTS distance (head ~1/7 of height instead of ~1/4).
const PROPORTIONS := {"Head": Vector3(0.66, 0.66, 0.66), "Neck": Vector3(0.9, 1.15, 0.9), "Torso": Vector3(0.95, 1.12, 0.95),
	"Abdomen": Vector3(0.92, 1.15, 0.92), "UpperLeg.L": Vector3(0.9, 1.32, 0.9), "UpperLeg.R": Vector3(0.9, 1.32, 0.9),
	"LowerLeg.L": Vector3(0.95, 1.12, 0.95), "LowerLeg.R": Vector3(0.95, 1.12, 0.95),
	"UpperArm.L": Vector3(0.95, 1.12, 0.95), "UpperArm.R": Vector3(0.95, 1.12, 0.95)}
const ANIMS := [["idle", "Idle", true], ["run", "Run_Gun", true], ["fire", "Idle_Shoot", true], ["die", "Death", false]]

## colours are linear-ish sRGB hex; "team" = flagged for the per-player colour
const WEAPON_COLORS := {"Grey": "#3d4043", "Grey2": "#2b2d2f", "DarkGrey": "#1d1e20", "LightGrey": "#6a6e72", "Red": "#5a2a22"}
const SPECS := {
	"eu_rifleman": {"gun": "eu_rifle_gl", "gear": [["plate_carrier", "#4f5742", "#3d4433"], ["canteen", "#3d4433", ""]], "head": ["helmet_cover", "#56603f", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "SMG", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#5d6849", "Pants": "#4f5742", "Grey": "team", "DarkGrey": "#30353a", "Black": "#1c1e20", "Skin": "#c79a76", "Grey2": "#5c6166", "Wood": "#6b5236", "LightGrey": "#9aa0a5"}},
	"tpla_rifleman": {"gun": "ak", "gear": [["chest_rig", "#6b5d3e", "#5a4b30"]], "head": ["wrap", "#c9bfa5", "#8f3a2e"], "head_node": "Character_Enemy_Head", "file": "Character_Enemy.gltf", "weapon": "AK", "keep": ["Character_Enemy", "Character_Enemy_Head"],
		"node_colors": {"Character_Enemy_Head": {"Enemy_Red": "#8f7d56", "Black": "team"}},
		"colors": {"Enemy_Red": "#a48c5f", "Grey": "#6b6a45", "DarkGrey": "#5e4d36", "Black": "#5a4c38", "Skin": "#b98a64", "Grey2": "#5a5b4a", "Wood": "#7a5530", "LightGrey": "#a89a80"}},
	# M2.5 United States (Marines in coyote-brown; team colour on the shoulder pads / helmet band)
	"us_rifleman": {"gun": "m16", "gear": [["plate_carrier", "#7a6c50", "#6a5e45"], ["pack", "#6e6250", "#5a5040"]], "head": ["helmet_cover", "#7d6e52", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "AK", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#7d6e52", "Pants": "#6e6250", "Grey": "team", "DarkGrey": "#3b3a33", "Black": "#24231f", "Skin": "#c79a76", "Grey2": "#5a564b", "Wood": "#6b5236", "LightGrey": "#a59d8a"}},
	"us_javelin": {"gun": "javelin", "gear": [["plate_carrier", "#7a6c50", "#6a5e45"], ["pack", "#6e6250", "#5a5040"]], "head": ["helmet_cover", "#7d6e52", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "RocketLauncher", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#7d6e52", "Pants": "#6e6250", "Grey": "team", "DarkGrey": "#3b3a33", "Black": "#24231f", "Skin": "#a8774f", "Grey2": "#5a564b", "Wood": "#6b5236", "LightGrey": "#a59d8a"}},
	"us_jtac": {"gun": "m4", "gear": [["plate_carrier", "#6a5f4a", "#5d5446"], ["radio", "#4a4a3e", "#cccccc"]], "head": ["headset", "", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "SMG", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#6a5f4a", "Pants": "#5d5446", "Grey": "team", "DarkGrey": "#2f2e2a", "Black": "#1c1b18", "Skin": "#d2a681", "Grey2": "#4c4a42", "Wood": "#6b5236", "LightGrey": "#c9b46a"}},
	"us_sniper": {"gun": "sniper", "gear": [["ghillie", "", ""]], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "Sniper", "keep": ["Body", "Head"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#5e6243", "Pants": "#585a40", "Grey": "#4d513a", "DarkGrey": "#3a3d2e", "Black": "#2a2c22", "Skin": "#b98a64", "Grey2": "#4c4f3c", "Wood": "#5a4a30", "LightGrey": "#7d7f62"}},
	# M2.6: the last old procedural squads move to baked soldiers
	"eu_lancer": {"gun": "eu_launcher", "gear": [["plate_carrier", "#4a523c", "#3d4433"], ["spare_tube", "#555b47", ""]], "head": ["helmet_cover", "#56603f", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "RocketLauncher", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#56603f", "Pants": "#4a523c", "Grey": "team", "DarkGrey": "#30353a", "Black": "#1c1e20", "Skin": "#d2a681", "Grey2": "#5c6166", "Wood": "#6b5236", "LightGrey": "#9aa0a5"}},
	"tpla_rocket": {"gun": "rpg", "gear": [["rocket_pack", "#5a4b30", ""]], "head": ["wrap", "#7d7356", "#4a3f30"], "head_node": "Character_Enemy_Head", "file": "Character_Enemy.gltf", "weapon": "RocketLauncher", "keep": ["Character_Enemy", "Character_Enemy_Head"],
		"node_colors": {"Character_Enemy_Head": {"Enemy_Red": "#5e5a4a", "Black": "team"}},
		"colors": {"Enemy_Red": "#7d7356", "Grey": "#5d5c40", "DarkGrey": "#4b3f2e", "Black": "#4a3f30", "Skin": "#a87c58", "Grey2": "#5a5b4a", "Wood": "#7a5530", "LightGrey": "#a89a80"}},
	"tpla_laborer": {"gear": [["pack", "#8a7a62", "#6e6250"]], "head_node": "Character_Enemy_Head", "file": "Character_Enemy.gltf", "weapon": "Shovel", "keep": ["Character_Enemy", "Character_Enemy_Head"],
		"node_colors": {"Character_Enemy_Head": {"Enemy_Red": "team", "Black": "#3a3128"}},
		"colors": {"Enemy_Red": "#8a7a62", "Grey": "#6e6250", "DarkGrey": "#5e4d36", "Black": "#4a3f30", "Skin": "#b98a64", "Grey2": "#5a5b4a", "Wood": "#7a5530", "LightGrey": "#a89a80"}},
	# M2.9 TPLA roster additions: SVD Marksman and the civilian-looking Insurgent scout
	"tpla_marksman": {"gun": "svd", "gear": [["chest_rig", "#5e5440", "#4a4030"]], "head": ["wrap", "#6e6650", "#3e3a2e"], "head_node": "Character_Enemy_Head", "file": "Character_Enemy.gltf", "weapon": "Sniper", "keep": ["Character_Enemy", "Character_Enemy_Head"],
		"node_colors": {"Character_Enemy_Head": {"Enemy_Red": "#5e5a4a", "Black": "team"}},
		"colors": {"Enemy_Red": "#6e6650", "Grey": "#4e4c3a", "DarkGrey": "#3e3528", "Black": "#3a3128", "Skin": "#a87c58", "Grey2": "#4a4b3e", "Wood": "#7a5530", "LightGrey": "#8a8070"}},
	"tpla_insurgent": {"head": ["wrap", "#e2dccb", "#b8ae96"], "head_node": "Character_Enemy_Head", "file": "Character_Enemy.gltf", "weapon": "Knife_1", "keep": ["Character_Enemy", "Character_Enemy_Head"],
		"node_colors": {"Character_Enemy_Head": {"Enemy_Red": "#d6cfbc", "Black": "team"}},
		"colors": {"Enemy_Red": "#d9d3c2", "Grey": "#5d5f66", "DarkGrey": "#4a3e30", "Black": "#3a3128", "Skin": "#b98a64", "Grey2": "#6a6a66", "Wood": "#7a5530", "LightGrey": "#b0a890"}},
	# M3.0 F Russia: single soldiers in green camo (Ratnik-style helmet cover, plate carrier); FSB
	# Infiltrator in black. Team colour on the shoulder pads / helmet band.
	"ecc_rifleman": {"gun": "ak74", "gear": [["plate_carrier", "#55603f", "#454f33"], ["pack", "#4d5639", "#3e462e"]], "head": ["helmet_cover", "#59643f", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "AK", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#5c6743", "Pants": "#4f5838", "Grey": "team", "DarkGrey": "#33372c", "Black": "#1e201b", "Skin": "#d2a681", "Grey2": "#565a4b", "Wood": "#6b5236", "LightGrey": "#9aa08c"}},
	"ecc_machine_gunner": {"gun": "pkm", "gear": [["plate_carrier", "#55603f", "#454f33"], ["pack", "#4d5639", "#3e462e"]], "head": ["helmet_cover", "#59643f", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "AK", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#5c6743", "Pants": "#4f5838", "Grey": "team", "DarkGrey": "#33372c", "Black": "#1e201b", "Skin": "#c79a76", "Grey2": "#565a4b", "Wood": "#6b5236", "LightGrey": "#9aa08c"}},
	"ecc_rpg": {"gun": "rpg", "gear": [["plate_carrier", "#55603f", "#454f33"], ["rocket_pack", "#4d5639", ""]], "head": ["helmet_cover", "#59643f", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "RocketLauncher", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#5c6743", "Pants": "#4f5838", "Grey": "team", "DarkGrey": "#33372c", "Black": "#1e201b", "Skin": "#b98a64", "Grey2": "#565a4b", "Wood": "#6b5236", "LightGrey": "#9aa08c"}},
	"ecc_infiltrator": {"gun": "ak12", "gear": [["plate_carrier", "#2a2c2b", "#202221"], ["radio", "#2a2c2b", "#555555"]], "head": ["helmet_cover", "#2c2e2d", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "SMG", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#343734", "Pants": "#2c2e2c", "Grey": "team", "DarkGrey": "#1f2120", "Black": "#151615", "Skin": "#d2a681", "Grey2": "#3e413e", "Wood": "#3a3a3a", "LightGrey": "#6a6e6a"}},
	"ecc_rifleman_placeholder": {"file": "Character_Hazmat.gltf", "weapon": "Shotgun", "keep": ["Character_Hazmat", "Character_Hazmat_Head"],
		"colors": {"Hazmat_Main": "#5d6748", "DarkGrey": "#3a3f33", "Black": "#1e201c", "Grey": "team", "Grey2": "#55594c", "Wood": "#6b5236", "LightGrey": "#9aa08c"}},
	# M3.2: US Drone Operator (radio + controller pack, headset) and German Field Engineer (tool pack, sapper bag)
	"us_drone_operator": {"gun": "m4", "gear": [["plate_carrier", "#5f5a48", "#4f4b3d"], ["radio", "#3a3d36", "#7fd0ff"], ["pack", "#5a5446", "#4a4538"]], "head": ["headset", "", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "SMG", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#6e6650", "Pants": "#5a5446", "Grey": "team", "DarkGrey": "#2f2e2a", "Black": "#1c1b18", "Skin": "#b98a64", "Grey2": "#4c4a42", "Wood": "#6b5236", "LightGrey": "#7fd0ff"}},
	"eu_field_engineer": {"gun": "eu_rifle_gl", "gear": [["plate_carrier", "#4f5742", "#3d4433"], ["pack", "#5a5338", "#c8742a"], ["canteen", "#3d4433", ""]], "head": ["helmet_cover", "#4f5a3a", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "SMG", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#58623f", "Pants": "#3f4632", "Grey": "team", "DarkGrey": "#30353a", "Black": "#1c1e20", "Skin": "#d2a681", "Grey2": "#5c6166", "Wood": "#6b5236", "LightGrey": "#d08a3a"}},
	# M3.2 capture specialists: US Breacher (dark gear, breaching pack), Sturmtrupp, Russian Saboteur
	"us_breacher": {"gear": [["plate_carrier", "#3e3d36", "#2f2e29"], ["pack", "#4a4639", "#3a372d"]], "head": ["helmet_cover", "#4a473c", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "Pistol", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#5a5647", "Pants": "#4a4639", "Grey": "team", "DarkGrey": "#2f2e2a", "Black": "#1c1b18", "Skin": "#c79a76", "Grey2": "#4c4a42", "Wood": "#6b5236", "LightGrey": "#a59d8a"}},
	"eu_sturmtrupp": {"gear": [["chest_rig", "#3d4433", "#30362a"], ["canteen", "#3d4433", ""]], "head": ["helmet_cover", "#3f4a33", ""], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "Pistol", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#4a5238", "Pants": "#3d4433", "Grey": "team", "DarkGrey": "#30353a", "Black": "#1c1e20", "Skin": "#d2a681", "Grey2": "#5c6166", "Wood": "#6b5236", "LightGrey": "#9aa0a5"}},
	"ecc_saboteur": {"gear": [["chest_rig", "#3a3f30", "#2c3025"], ["pack", "#3a3f30", "#2c3025"]], "head": ["wrap", "#2e322a", "#22251f"], "head_node": "Head", "file": "Character_Soldier.gltf", "weapon": "Pistol", "keep": ["Body", "Head", "ShoulderPad.L", "ShoulderPad.R"],
		"node_colors": {"Head": {"Black": "team"}},
		"colors": {"Character_Main": "#43493a", "Pants": "#363b2e", "Grey": "team", "DarkGrey": "#25281f", "Black": "#151712", "Skin": "#c79a76", "Grey2": "#3e413e", "Wood": "#3a3a3a", "LightGrey": "#6a6e6a"}},
}

func _initialize() -> void:
	var only := OS.get_environment("FL_BAKE_ONLY")
	for k in SPECS:
		if only != "" and not String(k).begins_with(only):
			continue
		var r := await _bake(k, SPECS[k])
		print("BAKED ", k, " ", r)
	quit(0)

func _bake(key: String, spec: Dictionary) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC + spec["file"]), state)
	if err != OK:
		push_error("gltf load failed %s" % err)
		return {}
	var scene: Node3D = doc.generate_scene(state)
	root.add_child(scene)
	await process_frame
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	# M2.8: a procedural weapon ("gun") replaces the kit weapon; the kit weapon still gives the grip
	var keep: Array = spec["keep"] + ([] if spec.has("gun") else [spec["weapon"]])
	# ---- gather vertices: [mesh instance, local pos, normal, bones, weights, color, team]
	var srcs: Array = []   # per mesh instance: {mi, skinned, binds, rel (attachments), arrays...}
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	var COL := PackedColorArray()
	var IDX := PackedInt32Array()
	var owner_of := PackedInt32Array()   # vertex -> srcs index
	var vb := []    # per vertex bones (PackedInt32Array 4) for skinned
	var vw := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not keep.has(String(mi.name)) or mi.mesh == null:
			continue
		var skinned := mi.skin != null
		var info := {"mi": mi, "skinned": skinned}
		if skinned:
			var binds := []
			for b in mi.skin.get_bind_count():
				var bi := mi.skin.get_bind_bone(b)
				if bi < 0:
					bi = skel.find_bone(mi.skin.get_bind_name(b))
				binds.append([bi, mi.skin.get_bind_pose(b)])
			info["binds"] = binds
		else:
			# attached to a bone (BoneAttachment3D ancestor) or a plain child of the skeleton
			var ba: Node = mi.get_parent()
			while ba != null and not (ba is BoneAttachment3D) and ba != scene:
				ba = ba.get_parent()
			if ba is BoneAttachment3D:
				info["bone"] = skel.find_bone((ba as BoneAttachment3D).bone_name)
				info["rel"] = (ba as BoneAttachment3D).global_transform.affine_inverse() * mi.global_transform
			else:
				info["bone"] = -1
				info["rel"] = skel.global_transform.affine_inverse() * mi.global_transform
		var si := srcs.size()
		srcs.append(info)
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var mat: Material = mi.get_active_material(s)
			var mname := String(mat.resource_name) if mat != null else ""
			# per-part overrides: the weapon keeps gunmetal colours (never team), the head can
			# carry its own (e.g. TPLA team-coloured head wrap)
			var cmap: Dictionary = spec["colors"].duplicate()
			var nname := String(mi.name)
			if nname == spec["weapon"] or nname.begins_with(spec["weapon"]):
				cmap.merge(WEAPON_COLORS, true)
			elif spec.has("node_colors") and spec["node_colors"].has(nname):
				cmap.merge(spec["node_colors"][nname], true)
			var cspec: String = cmap.get(mname, "")
			var team := cspec == "team"
			var c := Color.WHITE
			if cspec != "" and not team:
				c = Color(cspec)
			elif mat is BaseMaterial3D:
				c = (mat as BaseMaterial3D).albedo_color
			if team:
				c = Color(0.8, 0.8, 0.8)
			c.a = 1.0 if team else 0.0
			var base := P.size()
			var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nv: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if skinned and arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if skinned and arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var bpv := bones.size() / maxi(1, pv.size())
			for i in pv.size():
				P.append(pv[i])
				N.append(nv[i] if nv != null and nv.size() > i else Vector3.UP)
				COL.append(c)
				owner_of.append(si)
				if skinned:
					vb.append(bones.slice(i * bpv, i * bpv + bpv))
					vw.append(wts.slice(i * bpv, i * bpv + bpv))
				else:
					vb.append(PackedInt32Array())
					vw.append(PackedFloat32Array())
			var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(pv.size()))
			for i in ind:
				IDX.append(base + i)
	# ---- M2.8 detail: specific weapon + faction gear, rigid on hand / torso / head bones
	var EXTRA := PackedInt32Array()
	if spec.has("gun") or spec.has("gear") or spec.has("head"):
		EXTRA = _add_detail(scene, skel, player, spec, srcs, P, N, COL, owner_of, vb, vw)
	# ---- reference pose: first Idle frame (model space), for decimation and normalisation
	var ref := _pose(player, skel, "Idle", 0.0, srcs, P, N, owner_of, vb, vw)
	var aabb := AABB(ref[0][0], Vector3.ZERO)
	for p in ref[0]:
		aabb = aabb.expand(p)
	var scale := HEIGHT / aabb.size.y
	var foot := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
	# ---- decimate (LOD simplifier on the reference pose), then keep only used vertices
	var im := ImporterMesh.new()
	var a0 := []
	a0.resize(Mesh.ARRAY_MAX)
	a0[Mesh.ARRAY_VERTEX] = ref[0]
	a0[Mesh.ARRAY_NORMAL] = ref[1]
	a0[Mesh.ARRAY_COLOR] = COL
	a0[Mesh.ARRAY_INDEX] = IDX
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a0)
	im.generate_lods(25.0, 60.0, [])
	var best := IDX
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		if absi(li.size() / 3 - TARGET_TRIS) < absi(best.size() / 3 - TARGET_TRIS):
			best = li
	var remap := {}
	var keep_v := PackedInt32Array()
	var idx2 := PackedInt32Array()
	best = best + EXTRA      # detail parts are already low-poly: never decimated
	for i in best:
		if not remap.has(i):
			remap[i] = keep_v.size()
			keep_v.append(i)
		idx2.append(remap[i])
	var nv := keep_v.size()
	# ---- bake frames
	var width := mini(nv, 2048)
	var rows := int(ceil(nv / float(width)))
	var frames_total := 0
	var anim_info := {}
	var plan := []
	for a in ANIMS:
		var anim: Animation = player.get_animation(a[1])
		var n: int = maxi(2, int(round(anim.length * FPS))) if a[2] else int(ceil(anim.length * FPS)) + 1
		anim_info[a[0]] = [frames_total, n, FPS, 1 if a[2] else 0]
		plan.append([a[1], n, anim.length, a[2]])
		frames_total += n
	var pimg := Image.create_empty(width, rows * frames_total, false, Image.FORMAT_RGBAH)
	var nimg := Image.create_empty(width, rows * frames_total, false, Image.FORMAT_RGBA8)
	var f := 0
	for pl in plan:
		for k in pl[1]:
			var t: float = (float(k) / pl[1] * pl[2]) if pl[3] else minf(pl[2], float(k) / FPS)
			var pose := _pose(player, skel, pl[0], t, srcs, P, N, owner_of, vb, vw)
			for j in nv:
				var vi := keep_v[j]
				var p: Vector3 = (pose[0][vi] - foot) * scale
				var n3: Vector3 = (pose[1][vi] as Vector3).normalized()
				var x := j % width
				var y := j / width + f * rows
				pimg.set_pixel(x, y, Color(p.x, p.y, p.z, 1.0))
				nimg.set_pixel(x, y, Color(n3.x * 0.5 + 0.5, n3.y * 0.5 + 0.5, n3.z * 0.5 + 0.5, 1.0))
			f += 1
	# ---- final mesh (reference pose positions, vertex id in UV2, LODs generated again)
	var V2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var C2 := PackedColorArray()
	var U2 := PackedVector2Array()
	var CU := PackedVector2Array()
	for j in nv:
		var vi := keep_v[j]
		V2.append((ref[0][vi] - foot) * scale)
		N2.append((ref[1][vi] as Vector3).normalized())
		C2.append(COL[vi])
		U2.append(Vector2(j % 256, j / 256))
		# M2.6: part colour + team flag also packed in UV (float32, exact): x = R*256 + G, y = B + 1000 * team
		var cc: Color = COL[vi]
		CU.append(Vector2(float(cc.r8 * 256 + cc.g8), float(cc.b8) + (1000.0 if cc.a > 0.5 else 0.0)))
	var im2 := ImporterMesh.new()
	var a2 := []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = V2
	a2[Mesh.ARRAY_NORMAL] = N2
	a2[Mesh.ARRAY_COLOR] = C2
	a2[Mesh.ARRAY_TEX_UV2] = U2
	a2[Mesh.ARRAY_INDEX] = idx2
	im2.add_surface(Mesh.PRIMITIVE_TRIANGLES, a2, [], {}, null, "soldier")
	im2.generate_lods(25.0, 60.0, [])
	# M2.6: build the ArrayMesh directly so the UV-packed part colour survives uncompressed,
	# reusing the simplifier's LOD index lists
	var lods := {}
	for l in im2.get_surface_lod_count(0):
		lods[im2.get_surface_lod_size(0, l)] = im2.get_surface_lod_indices(0, l)
	a2[Mesh.ARRAY_TEX_UV] = CU
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2, [], lods)
	# animations move limbs (and Death lies down forward): generous fixed bounds
	mesh.custom_aabb = AABB(Vector3(-0.45, -0.05, -0.45), Vector3(0.9, HEIGHT + 0.2, 0.9))
	var vm := VatModel.new()
	vm.mesh = mesh
	vm.pos_tex = ImageTexture.create_from_image(pimg)
	vm.nrm_tex = ImageTexture.create_from_image(nimg)
	vm.width = width
	vm.rows = rows
	vm.vertex_count = nv
	vm.anims = anim_info
	vm.height = HEIGHT
	vm.source = "Quaternius Toon Shooter Game Kit (CC0): " + spec["file"] + " + " + spec["weapon"]
	DirAccess.make_dir_recursive_absolute(OUT)
	var path := OUT + key + ".res"
	ResourceSaver.save(vm, path, ResourceSaver.FLAG_COMPRESS)
	# facing check: weapon centre z in the fire pose (+z = our unit front)
	var fz := 0.0
	var fire := _pose(player, skel, "Idle_Shoot", 0.1, srcs, P, N, owner_of, vb, vw)
	var cnt := 0
	for i in P.size():
		if String(srcs[owner_of[i]]["mi"].name) == spec["weapon"]:
			fz += (fire[0][i] - foot).z
			cnt += 1
	scene.queue_free()
	return {"verts": nv, "tris": idx2.size() / 3, "src_tris": IDX.size() / 3, "lods": mesh.get_surface_count(), "frames": frames_total,
		"tex": "%dx%d" % [width, rows * frames_total], "anims": anim_info, "weapon_z": fz / maxi(1, cnt), "path": path}

## Model-space positions and normals of every gathered vertex at time t of `anim`.
func _pose(player: AnimationPlayer, skel: Skeleton3D, anim: String, t: float, srcs: Array, P: PackedVector3Array, N: PackedVector3Array, owner_of: PackedInt32Array, vb: Array, vw: Array) -> Array:
	player.play(anim)
	player.seek(t, true)
	player.pause()
	var nb := skel.get_bone_count()
	var g := []
	g.resize(nb)
	for i in nb:
		var par := skel.get_bone_parent(i)
		var lp := skel.get_bone_pose(i)
		var pr: Vector3 = PROPORTIONS.get(skel.get_bone_name(i), Vector3.ONE)
		if pr != Vector3.ONE:
			lp = lp * Transform3D(Basis.from_scale(pr), Vector3.ZERO)
		g[i] = lp if par < 0 else (g[par] as Transform3D) * lp
	var sk := skel.global_transform
	var mats := []   # per src: either per-bind skin transforms or one rigid transform
	for s in srcs:
		if s["skinned"]:
			var bt := []
			for b in s["binds"]:
				bt.append(sk * (g[b[0]] as Transform3D) * (b[1] as Transform3D))
			mats.append(bt)
		elif s["bone"] >= 0:
			mats.append(sk * (g[s["bone"]] as Transform3D) * (s["rel"] as Transform3D))
		else:
			mats.append(sk * (s["rel"] as Transform3D))
	var outp := PackedVector3Array()
	var outn := PackedVector3Array()
	outp.resize(P.size())
	outn.resize(P.size())
	for i in P.size():
		var s: Dictionary = srcs[owner_of[i]]
		if s["skinned"]:
			var bt: Array = mats[owner_of[i]]
			var bs: PackedInt32Array = vb[i]
			var ws: PackedFloat32Array = vw[i]
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for k in bs.size():
				if ws[k] <= 0.0:
					continue
				var tr: Transform3D = bt[bs[k]]
				p += (tr * P[i]) * ws[k]
				n += (tr.basis * N[i]) * ws[k]
			outp[i] = p
			outn[i] = n
		else:
			var tr2: Transform3D = mats[owner_of[i]]
			outp[i] = tr2 * P[i]
			outn[i] = tr2.basis * N[i]
	return [outp, outn]


## Bone global transforms (skeleton space, with the M2.6 proportions) at time t of `anim`.
func _bone_globals(player: AnimationPlayer, skel: Skeleton3D, anim: String, t: float) -> Array:
	player.play(anim)
	player.seek(t, true)
	player.pause()
	var g := []
	g.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		var par := skel.get_bone_parent(i)
		var lp := skel.get_bone_pose(i)
		var pr: Vector3 = PROPORTIONS.get(skel.get_bone_name(i), Vector3.ONE)
		if pr != Vector3.ONE:
			lp = lp * Transform3D(Basis.from_scale(pr), Vector3.ZERO)
		g[i] = lp if par < 0 else (g[par] as Transform3D) * lp
	return g

func _push(kit, name: String, bone: int, rel: Transform3D, srcs: Array, P: PackedVector3Array, N: PackedVector3Array, COL: PackedColorArray, owner_of: PackedInt32Array, vb: Array, vw: Array, out: PackedInt32Array) -> void:
	var holder := Node3D.new()
	holder.name = name
	var si := srcs.size()
	srcs.append({"mi": holder, "skinned": false, "bone": bone, "rel": rel})
	var base := P.size()
	for i in kit.P.size():
		P.append(kit.P[i])
		N.append(kit.N[i])
		var c: Color = kit.C[i]
		if c.a > 0.5:
			c = Color(0.8, 0.8, 0.8, 1.0)
		COL.append(c)
		owner_of.append(si)
		vb.append(PackedInt32Array())
		vw.append(PackedFloat32Array())
	for i in kit.I:
		out.append(base + i)

func _add_detail(scene: Node3D, skel: Skeleton3D, player: AnimationPlayer, spec: Dictionary, srcs: Array, P: PackedVector3Array, N: PackedVector3Array, COL: PackedColorArray, owner_of: PackedInt32Array, vb: Array, vw: Array) -> PackedInt32Array:
	var Kit := load("res://tools/gfx_m28/inf_kit.gd")
	var out := PackedInt32Array()
	var r0 := _pose(player, skel, "Idle", 0.0, srcs, P, N, owner_of, vb, vw)
	var body := AABB(r0[0][0], Vector3.ZERO)
	var head := AABB()
	var hfirst := true
	for i in r0[0].size():
		body = body.expand(r0[0][i])
		if String(srcs[owner_of[i]]["mi"].name) == spec.get("head_node", "Head"):
			head = AABB(r0[0][i], Vector3.ZERO) if hfirst else head.expand(r0[0][i])
			hfirst = false
	var sk := skel.global_transform
	var g0 := _bone_globals(player, skel, "Idle", 0.0)
	var tb := skel.find_bone("Torso")
	if tb < 0:
		tb = 0
	var hb := skel.find_bone("Head")
	if hb < 0:
		hb = tb
	var tris := 0
	if spec.has("gear"):
		var k = Kit.new()
		for gspec in spec["gear"]:
			k.gear(gspec[0], body, gspec[1], gspec[2])
		_push(k, "gear", tb, (sk * (g0[tb] as Transform3D)).affine_inverse(), srcs, P, N, COL, owner_of, vb, vw, out)
		tris += k.tris()
	if spec.has("head") and not hfirst:
		var k2 = Kit.new()
		k2.headgear(spec["head"][0], head, spec["head"][1], spec["head"][2])
		_push(k2, "headgear", hb, (sk * (g0[hb] as Transform3D)).affine_inverse(), srcs, P, N, COL, owner_of, vb, vw, out)
		tris += k2.tris()
	if spec.has("gun"):
		var mi: MeshInstance3D = null
		for m in scene.find_children("*", "MeshInstance3D", true, false):
			if String(m.name) == spec["weapon"]:
				mi = m
		var ba: Node = mi.get_parent()
		while ba != null and not (ba is BoneAttachment3D) and ba != scene:
			ba = ba.get_parent()
		var bone := -1
		var rel_o: Transform3D
		if ba is BoneAttachment3D:
			bone = skel.find_bone((ba as BoneAttachment3D).bone_name)
			rel_o = (ba as BoneAttachment3D).global_transform.affine_inverse() * mi.global_transform
		else:
			rel_o = skel.global_transform.affine_inverse() * mi.global_transform
		var la := mi.mesh.get_aabb()
		var gf := _bone_globals(player, skel, "Idle_Shoot", 0.1)
		var W: Transform3D = sk * ((gf[bone] as Transform3D) if bone >= 0 else Transform3D.IDENTITY) * rel_o
		var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		var a := 0
		for q in 3:
			if la.size[q] > la.size[a]:
				a = q
		var ctr := la.get_center()
		var ea: Vector3 = axes[a]
		var sgn := 1.0 if (W * (ctr + ea * la.size[a] * 0.5)).z > (W * (ctr - ea * la.size[a] * 0.5)).z else -1.0
		var u := -1
		var best_y := -1.0
		for q in 3:
			if q == a:
				continue
			var yy := absf((W.basis * (axes[q] as Vector3)).normalized().y)
			if yy > best_y:
				best_y = yy
				u = q
		var su := 1.0 if (W.basis * (axes[u] as Vector3)).y > 0.0 else -1.0
		var Z: Vector3 = ea * sgn
		var Y: Vector3 = (axes[u] as Vector3) * su
		var X := Y.cross(Z)
		var kchain := (W.basis * ea).length()
		var per_m := body.size.y / 1.8 * 1.15 / kchain
		var k3 = Kit.new()
		k3.call(spec["gun"])
		var ga := AABB(k3.P[0], Vector3.ZERO)
		for p in k3.P:
			ga = ga.expand(p)
		var B := Basis(X, Y, Z).scaled_local(Vector3.ONE * per_m)
		var T := Transform3D(B, ctr - B * ga.get_center())
		_push(k3, spec["weapon"], bone, rel_o * T, srcs, P, N, COL, owner_of, vb, vw, out)
		tris += k3.tris()
		print("  %s: %s replaces %s (axis %d sign %d up %d), %.2f m model scale" % [spec["file"], spec["gun"], spec["weapon"], a, sgn, u, per_m])
	print("  detail parts: %d tris" % tris)
	return out
