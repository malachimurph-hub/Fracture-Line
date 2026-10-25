class_name MapEnv
extends RefCounted
## M2.5: per-map environment (view only; the sim never reads it). Terrain material set, sun,
## ambient, haze, grade, water colours and prop tinting for each biome. MapDef.env picks one.
## M3.2 Zero Hour look: cooler, darker ambient (warm sun vs blue shadow side), much less haze,
## higher contrast + saturation; glow is added per graphics preset in Match.

const ENVS := {
	&"desert": {
		"albedo": "res://assets/textures/terrain/terrain_albedo.png", "nrao": "res://assets/textures/terrain/terrain_nrao.png",
		"dry": 1.0, "tint": 1.0,
		"sun_rot": Vector3(-50, -35, 0), "sun_energy": 1.55, "sun_col": Color("#ffe3b8"),
		"ambient": Color("#8197c2"), "ambient_energy": 0.52, "fog_col": Color("#c9bba2"), "fog_density": 0.0009,
		"saturation": 1.1, "contrast": 1.16, "exposure": 0.98,
		"water_deep": Color(0.16, 0.30, 0.32), "water_shallow": Color(0.34, 0.45, 0.38), "prop_tint": Color(1, 1, 1),
	},
	&"winter": {
		"albedo": "res://assets/textures/terrain/terrain_albedo_winter.png", "nrao": "res://assets/textures/terrain/terrain_nrao_winter.png",
		"dry": 0.0, "tint": 0.0, "worn": 0.0, "clouds": 0.12,
		"sun_rot": Vector3(-34, -150, 0), "sun_energy": 1.25, "sun_col": Color("#fff1e0"),
		"ambient": Color("#93aad6"), "ambient_energy": 0.68, "fog_col": Color("#d6e0ec"), "fog_density": 0.0022,
		"saturation": 1.02, "contrast": 1.12, "exposure": 0.9,
		"water_deep": Color(0.32, 0.42, 0.48), "water_shallow": Color(0.62, 0.72, 0.78), "prop_tint": Color(0.92, 0.96, 1.04),
	},
	# M2.5 Ochre Wells: low late-afternoon sun, long shadows, dusty amber haze
	&"arid": {
		"albedo": "res://assets/textures/terrain/terrain_albedo_arid.png", "nrao": "res://assets/textures/terrain/terrain_nrao_arid.png",
		"dry": 1.0, "tint": 0.0,
		"sun_rot": Vector3(-40, 120, 0), "sun_energy": 1.45, "sun_col": Color("#ffe0b8"),
		"ambient": Color("#8a95b4"), "ambient_energy": 0.5, "fog_col": Color("#d2b48e"), "fog_density": 0.0012,
		"saturation": 1.04, "contrast": 1.2, "exposure": 0.9,
		"water_deep": Color(0.10, 0.26, 0.24), "water_shallow": Color(0.30, 0.44, 0.36), "prop_tint": Color(1.06, 1.0, 0.9),
	},
	&"temperate": {
		"albedo": "res://assets/textures/terrain/terrain_albedo_temperate.png", "nrao": "res://assets/textures/terrain/terrain_nrao_temperate.png",
		"dry": 0.15, "tint": 0.0,
		"sun_rot": Vector3(-56, 25, 0), "sun_energy": 1.4, "sun_col": Color("#fff4dc"),
		"ambient": Color("#8aa2c6"), "ambient_energy": 0.56, "fog_col": Color("#b9c6cf"), "fog_density": 0.0012,
		"saturation": 1.12, "contrast": 1.14, "exposure": 0.97,
		"water_deep": Color(0.12, 0.24, 0.27), "water_shallow": Color(0.26, 0.38, 0.33), "prop_tint": Color(1, 1, 1),
	},
}

static func of(id: StringName) -> Dictionary:
	return ENVS.get(id, ENVS[&"desert"])

static func for_map(map_id: StringName) -> Dictionary:
	var md: MapDef = Content.maps.get(map_id)
	return of(md.env if md != null else &"desert")
