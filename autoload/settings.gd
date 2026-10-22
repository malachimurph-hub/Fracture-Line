extends Node
## user://settings.cfg: graphics, input thresholds, UI scale, accessibility.
const PATH := "user://settings.cfg"
var data := {
	"ui_scale": 1.0,
	"hold_ms": 350,
	"double_tap_ms": 300,
	"drag_deadzone_dp": 10.0,
	"ghost_offset_mm": 12.0,
	"hold_action": "attack_move",   # attack_move | move
	"render_scale": 0.75,
	"texture_quality": "high",      # high | medium (M2)
	"fps_cap": 60,
	"perf_overlay": false,
	"always_health_bars": false,
	"haptics": true,
	"menu_battle": true,     ## M2.6: live battle behind the main menu
	"edge_pan": false,
	"camera_inertia": true,
	"vol_master": 0.9,
	"vol_music": 0.55,
	"vol_sfx": 0.85,
	"vol_voice": 1.0,
	"vol_ui": 0.7,
}

func _ready() -> void:
	load_settings()
	apply()

func g(key: String):
	return data.get(key)

func s(key: String, value) -> void:
	data[key] = value
	save_settings()
	apply()
	EventBus.settings_changed.emit()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in data.keys():
			data[k] = cf.get_value("settings", k, data[k])

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in data:
		cf.set_value("settings", k, data[k])
	cf.save(PATH)

func apply() -> void:
	Engine.max_fps = int(data["fps_cap"])
	# High: terrain normal/roughness/AO maps, close-range detail layer, model scratches and
	# stencils. Medium: albedo only, one mip level of bias (less bandwidth, cheaper shaders).
	RenderingServer.global_shader_parameter_set(&"fl_tex_quality", 1.0 if data["texture_quality"] == "high" else 0.0)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(data["render_scale"])
