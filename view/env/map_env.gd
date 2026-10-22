class_name MapEnv
extends RefCounted
## M2.5: per-map environment (view only; the sim never reads it). Terrain material set, sun,
## ambient, haze, grade, water colours and prop tinting for each biome. MapDef.env picks one.

const ENVS := {
	&"desert": {
		"albedo": "res://assets/textures/terrain/terrain_albedo.png", "nrao": "res://assets/textures/terrain/terrain_nrao.png",
		"dry": 1.0, "tint": 1.0,
		"sun_rot": Vector3(-50, -35, 0), "sun_energy": 1.55, "sun_col": Color("#ffe3b8"),
		"ambient": Color("#8ea3c4"), "ambient_energy": 0.62, "fog_col": Color("#cdbb9c"), "fog_density": 0.0016,
		"saturation": 1.12, "contrast": 1.06, "exposure": 1.05,
		"water_deep": Color(0.16, 0.30, 0.32), "water_shallow": Color(0.34, 0.45, 0.38), "prop_tint": Color(1, 1, 1),
	},
	&"winter": {
		"albedo": "res://assets/textures/terrain/terrain_albedo_winter.png", "nrao": "res://assets/textures/terrain/terrain_nrao_winter.png",
		"dry": 0.0, "tint": 0.0,
		"sun_rot": Vector3(-34, -150, 0), "sun_energy": 1.25, "sun_col": Color("#fff1e0"),
		"ambient": Color("#9fb4d6"), "ambient_energy": 0.78, "fog_col": Color("#d6e0ec"), "fog_density": 0.0034,
		"saturation": 0.92, "contrast": 1.04, "exposure": 0.92,
		"water_deep": Color(0.32, 0.42, 0.48), "water_shallow": Color(0.62, 0.72, 0.78), "prop_tint": Color(0.92, 0.96, 1.04),
	},
	# M2.5 Ochre Wells: low late-afternoon sun, long shadows, dusty amber haze
	&"arid": {
		"albedo": "res://assets/textures/terrain/terrain_albedo_arid.png", "nrao": "res://assets/textures/terrain/terrain_nrao_arid.png",
		"dry": 1.0, "tint": 0.0,
		"sun_rot": Vector3(-30, 120, 0), "sun_energy": 1.45, "sun_col": Color("#ffcf96"),
		"ambient": Color("#a99a8a"), "ambient_energy": 0.58, "fog_col": Color("#d9b48a"), "fog_density": 0.0042,
		"saturation": 1.1, "contrast": 1.08, "exposure": 1.0,
		"water_deep": Color(0.10, 0.26, 0.24), "water_shallow": Color(0.30, 0.44, 0.36), "prop_tint": Color(1.06, 1.0, 0.9),
	},
	&"temperate": {
		"albedo": "res://assets/textures/terrain/terrain_albedo_temperate.png", "nrao": "res://assets/textures/terrain/terrain_nrao_temperate.png",
		"dry": 0.15, "tint": 0.0,
		"sun_rot": Vector3(-56, 25, 0), "sun_energy": 1.4, "sun_col": Color("#fff4dc"),
		"ambient": Color("#93a9c2"), "ambient_energy": 0.66, "fog_col": Color("#b9c6cf"), "fog_density": 0.0022,
		"saturation": 1.08, "contrast": 1.05, "exposure": 1.0,
		"water_deep": Color(0.12, 0.24, 0.27), "water_shallow": Color(0.26, 0.38, 0.33), "prop_tint": Color(1, 1, 1),
	},
}

static func of(id: StringName) -> Dictionary:
	return ENVS.get(id, ENVS[&"desert"])

static func for_map(map_id: StringName) -> Dictionary:
	var md: MapDef = Content.maps.get(map_id)
	return of(md.env if md != null else &"desert")
