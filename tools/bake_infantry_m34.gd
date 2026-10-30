extends SceneTree
## M3.4 infantry bake: realistic procedural soldiers (tools/gfx_m34: our own body, gear, rig and
## animation; weapons from our own procedural kit) baked into VatModel resources.
##   godot --headless --path . -s res://tools/bake_infantry_m34.gd   [FL_BAKE_ONLY=us_]
## Replaces the M2.2-M3.3 toon-kit bake (tools/bake_infantry.gd, kept for history). Clips:
## idle, walk, run, fire (two-handed aim, recoil), fire_kneel, lean (over a barricade), die
## (on his back), die2 (forward). Four look variants per model (head gear / packs, chosen per
## soldier by the view), plus per-soldier skin tone, tint and size in the shader / view.
const Rig := preload("res://tools/gfx_m34/soldier_rig.gd")
const Body := preload("res://tools/gfx_m34/soldier_body.gd")
const Anims := preload("res://tools/gfx_m34/soldier_anims.gd")
const Kit := preload("res://tools/gfx_m34/kit34.gd")
const VatModelScript := preload("res://view/infantry/vat_model.gd")
const OUT := "res://assets/models/infantry/"
const FPS := 10.0           ## the shader blends between frames
## packed position range (model units): 11 / 11 / 10 bits over these bounds
const PMIN := Vector3(-0.6, -0.1, -0.7)
const PMAX := Vector3(0.6, 0.7, 0.7)
const HEIGHT := 0.5
const TALL := 1.84            ## metres mapped to HEIGHT (helmet top)
const CLIP_ORDER := ["idle", "walk", "run", "fire", "fire_kneel", "lean", "die", "die2"]

## weapon points in the (mirrored) gun frame: butt = stock in the shoulder, shoulder = where a
## launcher tube rests on it, grip = right palm, support = left palm
const GUNS := {
	"m16": {"butt": Vector3(0, 0.03, -0.4), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, 0.025, 0.24)},
	"m4": {"butt": Vector3(0, 0.03, -0.27), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, -0.07, 0.25)},
	"sniper": {"butt": Vector3(0, 0.0, -0.42), "grip": Vector3(0, -0.05, -0.02), "support": Vector3(0, 0.0, 0.24)},
	"ak": {"butt": Vector3(0, 0.02, -0.4), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, 0.03, 0.28)},
	"ak74": {"butt": Vector3(0, 0.03, -0.35), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, 0.03, 0.28)},
	"ak12": {"butt": Vector3(0, 0.03, -0.35), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, 0.03, 0.28)},
	"svd": {"butt": Vector3(0, 0.0, -0.37), "grip": Vector3(0, -0.03, -0.05), "support": Vector3(0, 0.03, 0.29)},
	"eu_rifle_gl": {"butt": Vector3(0, 0.03, -0.33), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, -0.03, 0.3)},
	"pkm": {"butt": Vector3(0, 0.0, -0.39), "grip": Vector3(0, -0.04, -0.02), "support": Vector3(0, 0.02, 0.28)},
	"shotgun": {"butt": Vector3(0, 0.03, -0.36), "grip": Vector3(0, -0.04, -0.03), "support": Vector3(0, 0.0, 0.33)},
	"smg": {"butt": Vector3(0, 0.04, -0.2), "grip": Vector3(0, -0.04, -0.02), "support": Vector3(0, -0.05, 0.14)},
	"pistol": {"butt": Vector3(0, 0.0, -0.05), "grip": Vector3(0, -0.03, -0.01), "support": Vector3(0.02, -0.045, 0.0)},
	"rpg": {"shoulder": Vector3(0, 0.065, -0.28), "grip": Vector3(0, -0.03, -0.02), "support": Vector3(0, -0.02, 0.2)},
	"eu_launcher": {"shoulder": Vector3(0, 0.04, -0.22), "grip": Vector3(0, -0.03, 0.0), "support": Vector3(0, -0.03, 0.22)},
	"javelin": {"shoulder": Vector3(0, 0.035, -0.15), "grip": Vector3(0.15, -0.02, 0.0), "support": Vector3(0, 0.04, 0.38)},
	"shovel": {"grip": Vector3(0, 0, 0.0), "support": Vector3(0, 0, 0.45)},
}
const STYLE := {"rpg": "launcher", "eu_launcher": "launcher", "javelin": "launcher", "pistol": "pistol", "shovel": "tool"}

## faction looks (original palettes): US coyote-brown blotch camo, German spot camo,
## Iranian-style militia in plain olive / mixed civilian kit, Russian fine green camo
const FAC := {
	"us": {"jacket": "#7d7059", "trousers": "#756a54", "camo": 1, "carrier": "#7a6b4e", "pouch": "#6b5e45", "pack": "#6e6250",
		"helmet": "#7b6d52", "boots": "#9a8462", "gloves": "#4d4334", "skin": "#c79a76", "armour": "plate", "kneepads": true, "belt": "#5a4e3a"},
	"eu": {"jacket": "#5c6448", "trousers": "#565e44", "camo": 2, "carrier": "#4f5741", "pouch": "#454c38", "pack": "#4d543e",
		"helmet": "#58613f", "boots": "#1d1d1d", "gloves": "#262626", "skin": "#d2a681", "armour": "plate", "belt": "#2e3226"},
	"tpla": {"jacket": "#6b6a4b", "trousers": "#5f5c45", "camo": 0, "carrier": "#6b5d3e", "pouch": "#5a4b30", "pack": "#6a5c42",
		"helmet": "#5e5c42", "boots": "#2a241e", "gloves": "", "skin": "#b38560", "armour": "chest_rig", "hair": "#1e1814", "belt": "#3a3124"},
	"ecc": {"jacket": "#5d6844", "trousers": "#535d3c", "camo": 2, "carrier": "#55603f", "pouch": "#4a5436", "pack": "#4d5639",
		"helmet": "#59643f", "boots": "#26261f", "gloves": "#2a2b28", "skin": "#d2a681", "armour": "plate", "kneepads": true, "belt": "#2e3226"},
}
const HEADS_US := ["helmet+goggles", "helmet+nvg", "helmet+nvg+headset", "helmet"]
const HEADS_EU := ["helmet+goggles", "helmet", "helmet+headset", "helmet+nvg"]
const HEADS_RU := ["helmet_ru+goggles", "helmet_ru", "helmet_ru+headset", "helmet_ru+nvg"]
const HEADS_TP := ["shemagh", "cap+beard", "hair+beard", "wrap+beard"]
const SPECS := {
	"us_rifleman": {"fac": "us", "gun": "m16", "heads": HEADS_US, "backs": ["pack", "hydration", "pack", "hydration"]},
	"us_javelin": {"fac": "us", "gun": "javelin", "heads": HEADS_US, "backs": ["bigpack"]},
	"us_jtac": {"fac": "us", "gun": "m4", "heads": ["helmet+headset+nvg", "boonie+headset", "helmet+headset", "helmet+headset+goggles"], "backs": ["radio"], "chest_extra": ["binoculars"]},
	"us_sniper": {"fac": "us", "gun": "sniper", "heads": ["boonie"], "backs": ["ghillie"], "armour": "vest", "kneel": 2},
	"us_drone_operator": {"fac": "us", "gun": "m4", "heads": ["helmet+headset", "boonie+headset", "helmet+headset+goggles", "helmet+headset+nvg"], "backs": ["radio"], "chest_extra": ["controller"]},
	"us_breacher": {"fac": "us", "gun": "shotgun", "heads": ["helmet+goggles", "helmet+nvg", "helmet+goggles", "helmet+headset"], "backs": ["satchel_back"], "thigh_pouch": true, "carrier": "#4a473c", "pouch": "#3e3d36"},
	"eu_rifleman": {"fac": "eu", "gun": "eu_rifle_gl", "heads": HEADS_EU, "backs": ["pack", "hydration", "hydration", "pack"]},
	"eu_lancer": {"fac": "eu", "gun": "eu_launcher", "heads": HEADS_EU, "backs": ["tube"]},
	"eu_field_engineer": {"fac": "eu", "gun": "eu_rifle_gl", "heads": ["helmet", "helmet+goggles", "helmet+headset", "helmet"], "backs": ["tools"], "armour": "vest", "kneepads": true},
	"eu_sturmtrupp": {"fac": "eu", "gun": "smg", "heads": ["helmet+goggles", "helmet", "helmet+goggles", "helmet+headset"], "backs": ["hydration"], "armour": "chest_rig", "thigh_pouch": true, "kneepads": true},
	"tpla_rifleman": {"fac": "tpla", "gun": "ak", "heads": HEADS_TP, "backs": ["", "pack", "", "satchel_back"], "kneel": 1},
	"tpla_rocket": {"fac": "tpla", "gun": "rpg", "heads": ["shemagh", "wrap+beard", "cap+beard", "hair+beard"], "backs": ["rockets"]},
	"tpla_marksman": {"fac": "tpla", "gun": "svd", "heads": ["shemagh", "wrap", "cap+beard", "shemagh"], "backs": ["hydration"], "kneel": 2},
	"tpla_insurgent": {"fac": "tpla", "gun": "pistol", "heads": ["shemagh", "hair+beard", "cap+beard", "wrap"], "armour": "", "jacket": "#cfc7b2", "trousers": "#4a4a52", "rolled": true, "cargo": false, "boots": "#3a3128", "wrap": "#e2dccb", "wrap2": "#b8ae96"},
	"tpla_laborer": {"fac": "tpla", "gun": "shovel", "heads": ["cap", "hair+beard", "wrap", "beanie"], "armour": "", "jacket": "#8a7a62", "trousers": "#5e5444", "rolled": true, "backs": ["pack"], "wrap": "#a49680"},
	"ecc_rifleman": {"fac": "ecc", "gun": "ak74", "heads": HEADS_RU, "backs": ["pack", "hydration", "pack", "hydration"]},
	"ecc_machine_gunner": {"fac": "ecc", "gun": "pkm", "heads": HEADS_RU, "backs": ["mgbox"], "chest_extra": ["ammo_belt"]},
	"ecc_rpg": {"fac": "ecc", "gun": "rpg", "heads": HEADS_RU, "backs": ["rockets"]},
	"ecc_infiltrator": {"fac": "ecc", "gun": "ak12", "heads": ["balaclava+headset", "helmet_ru+balaclava", "balaclava", "helmet_ru+balaclava+nvg"], "backs": ["hydration"],
		"jacket": "#343734", "trousers": "#2c2e2c", "camo": 0, "carrier": "#2a2c2b", "pouch": "#202221", "helmet": "#2c2e2d", "pack": "#2a2c2b", "gloves": "#1a1a1a", "boots": "#1a1a1a"},
	"ecc_saboteur": {"fac": "ecc", "gun": "pistol", "heads": ["beanie", "balaclava", "beanie+headset", "balaclava"], "backs": ["satchel_back"], "chest_extra": ["satchel"], "armour": "chest_rig",
		"jacket": "#43493a", "trousers": "#363b2e", "camo": 0, "wrap": "#2e322a", "kneepads": false},
}

func _initialize() -> void:
	var only := OS.get_environment("FL_BAKE_ONLY")
	for k in SPECS:
		if only != "" and not String(k).begins_with(only):
			continue
		var r := bake(k)
		print("BAKED ", k, " ", r)
	if only == "" or "ecc_rifleman_placeholder".begins_with(only):
		print("BAKED ecc_rifleman_placeholder ", bake("ecc_rifleman", "ecc_rifleman_placeholder"))   # legacy id, kept loadable
	quit(0)

static func spec_of(key: String) -> Dictionary:
	var s: Dictionary = SPECS[key].duplicate()
	var f: Dictionary = FAC[s["fac"]]
	for k in f:
		if not s.has(k):
			s[k] = f[k]
	return s

static func build_rig(key: String) -> Array:
	var spec := spec_of(key)
	var r = Rig.new()
	Body.build(r, spec)
	var kit = Kit.new()
	kit.call(spec["gun"])
	r.add_kit(kit)
	return [r, spec]

func bake(key: String, out_key := "") -> Dictionary:
	if out_key == "":
		out_key = key
	var rs := build_rig(key)
	var r = rs[0]
	# the builders emit counter-clockwise front faces; Godot's front faces are clockwise
	for t in range(0, r.I.size(), 3):
		var tmp: int = r.I[t + 1]
		r.I[t + 1] = r.I[t + 2]
		r.I[t + 2] = tmp
	var spec: Dictionary = rs[1]
	var gun: Dictionary = GUNS[spec["gun"]]
	var style: String = STYLE.get(spec["gun"], "rifle")
	var scale := HEIGHT / TALL
	var ref: Array = r.skin(r.solve(Anims.pose("idle", 0.0, style), gun))
	var nv: int = r.P.size()
	var width := mini(nv, 4096)   # M3.4: one texel row per frame (phones take 4096-wide textures)
	var rows := int(ceil(nv / float(width)))
	var plan := []
	var frames_total := 0
	var anim_info := {}
	for cn in CLIP_ORDER:
		var cl: Array = Anims.CLIPS[cn]
		var n: int = maxi(2, int(round(cl[0] * FPS))) if cl[1] else int(ceil(cl[0] * FPS)) + 1
		anim_info[cn] = [frames_total, n, FPS, 1 if cl[1] else 0]
		plan.append([cn, n, cl[0], cl[1]])
		frames_total += n
	# M3.4 compact VAT: position packed in RGBA8 (x 11 bits, y 11, z 10 over PMIN..PMAX),
	# normal octahedral-encoded in RG8: 6 bytes per vertex per frame (was 12)
	var pb := PackedByteArray()
	pb.resize(width * rows * frames_total * 4)
	var nb := PackedByteArray()
	nb.resize(width * rows * frames_total * 2)
	var f := 0
	var max_y := 0.0
	var span := PMAX - PMIN
	for pl in plan:
		for k in pl[1]:
			var t: float = (float(k) / pl[1] * pl[2]) if pl[3] else minf(pl[2], float(k) / FPS)
			var sk: Array = r.skin(r.solve(Anims.pose(pl[0], t, style), gun))
			for j in nv:
				var p: Vector3 = (sk[0][j] as Vector3) * scale
				max_y = maxf(max_y, p.y)
				var q := ((p - PMIN) / span).clamp(Vector3.ZERO, Vector3.ONE)
				var xi := int(round(q.x * 2047.0))
				var yi := int(round(q.y * 2047.0))
				var zi := int(round(q.z * 1023.0))
				var o := ((j / width + f * rows) * width + j % width)
				pb[o * 4] = xi & 255
				pb[o * 4 + 1] = (xi >> 8) | ((yi & 31) << 3)
				pb[o * 4 + 2] = (yi >> 5) | ((zi & 3) << 6)
				pb[o * 4 + 3] = zi >> 2
				var e := oct_encode(sk[1][j])
				nb[o * 2] = int(round(e.x * 255.0))
				nb[o * 2 + 1] = int(round(e.y * 255.0))
			f += 1
	var pimg := Image.create_from_data(width, rows * frames_total, false, Image.FORMAT_RGBA8, pb)
	var nimg := Image.create_from_data(width, rows * frames_total, false, Image.FORMAT_RG8, nb)
	var V2 := PackedVector3Array()
	var N2 := PackedVector3Array()
	var C2 := PackedColorArray()
	var U2 := PackedVector2Array()
	var CU := PackedVector2Array()
	for j in nv:
		V2.append((ref[0][j] as Vector3) * scale)
		N2.append(ref[1][j])
		var cc: Color = r.C[j]
		C2.append(cc)
		U2.append(Vector2(j % 256, j / 256))
		# part colour + flags for the shader: x = R*256 + G, y = B + 256 * (flags + 16 * variant mask)
		CU.append(Vector2(float(cc.r8 * 256 + cc.g8), float(cc.b8 + 256 * (int(r.F[j]) + 16 * int(r.VM[j])))))
	var a2 := []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = V2
	a2[Mesh.ARRAY_NORMAL] = N2
	a2[Mesh.ARRAY_COLOR] = C2
	a2[Mesh.ARRAY_TEX_UV2] = U2
	a2[Mesh.ARRAY_INDEX] = r.I
	var im2 := ImporterMesh.new()
	im2.add_surface(Mesh.PRIMITIVE_TRIANGLES, a2, [], {}, null, "soldier")
	im2.generate_lods(25.0, 60.0, [])
	var lods := {}
	for l in im2.get_surface_lod_count(0):
		lods[im2.get_surface_lod_size(0, l)] = im2.get_surface_lod_indices(0, l)
	a2[Mesh.ARRAY_TEX_UV] = CU
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2, [], lods)
	mesh.custom_aabb = AABB(Vector3(-0.45, -0.05, -0.45), Vector3(0.9, HEIGHT + 0.25, 0.9))
	var vm = VatModelScript.new()
	vm.mesh = mesh
	vm.pos_tex = ImageTexture.create_from_image(pimg)
	vm.nrm_tex = ImageTexture.create_from_image(nimg)
	vm.width = width
	vm.rows = rows
	vm.vertex_count = nv
	vm.anims = anim_info
	vm.height = HEIGHT
	vm.variants = 4
	vm.fire_kneel = int(spec.get("kneel", 1))
	vm.fmt = 3
	vm.pos_min = PMIN
	vm.pos_max = PMAX
	vm.source = "Original procedural soldier (tools/gfx_m34, M3.4): %s, %s" % [key, spec["gun"]]
	DirAccess.make_dir_recursive_absolute(OUT)
	var path := OUT + out_key + ".res"
	ResourceSaver.save(vm, path, ResourceSaver.FLAG_COMPRESS)
	var vis := 0
	for t in range(0, r.I.size(), 3):
		var m0: int = r.VM[r.I[t]]
		if m0 == 0 or (m0 & 1) != 0:
			vis += 1
	return {"verts": nv, "tris": r.I.size() / 3, "tris_v0": vis, "lods": lods.keys(), "frames": frames_total, "tex": "%dx%d" % [width, rows * frames_total], "top": max_y, "path": path}

## unit normal -> octahedral 0..1 pair
static func oct_encode(n: Vector3) -> Vector2:
	n = n.normalized()
	var d := absf(n.x) + absf(n.y) + absf(n.z)
	var o := Vector2(n.x, n.z) / d
	if n.y < 0.0:
		o = Vector2((1.0 - absf(o.y)) * signf(o.x if o.x != 0.0 else 1.0), (1.0 - absf(o.x)) * signf(o.y if o.y != 0.0 else 1.0))
	return o * 0.5 + Vector2(0.5, 0.5)
