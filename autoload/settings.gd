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
	"graphics_preset": "ultra",    # M3.1: ultra (default) | high | medium | low
	"render_scale": 0.8,
	"texture_quality": "high",      # high | medium (M2)
	"fps_cap": 60,
	"perf_overlay": false,
	"always_health_bars": false,
	"haptics": true,
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

## M3.1 graphics presets: render scale, texture quality, MSAA, shadow map size, anisotropy.
## Ultra = 2048 px detail normals with a second octave, 16x anisotropic, 2x MSAA, 4096 shadows.
const PRESETS := {
	"ultra": {"render_scale": 0.8, "texture_quality": "high", "msaa": Viewport.MSAA_2X, "shadow": 4096, "aniso": Viewport.ANISOTROPY_16X, "tq": 2.0, "glow": true, "scatter": 1.0},
	"high": {"render_scale": 0.75, "texture_quality": "high", "msaa": Viewport.MSAA_2X, "shadow": 2048, "aniso": Viewport.ANISOTROPY_8X, "tq": 1.0, "glow": true, "scatter": 0.6},
	"medium": {"render_scale": 0.7, "texture_quality": "medium", "msaa": Viewport.MSAA_DISABLED, "shadow": 2048, "aniso": Viewport.ANISOTROPY_4X, "tq": 0.0, "glow": false, "scatter": 0.3},
	"low": {"render_scale": 0.6, "texture_quality": "medium", "msaa": Viewport.MSAA_DISABLED, "shadow": 1024, "aniso": Viewport.ANISOTROPY_2X, "tq": 0.0, "glow": false, "scatter": 0.0},
}

func preset() -> Dictionary:
	return PRESETS.get(String(data.get("graphics_preset", "ultra")), PRESETS["ultra"])

func s(key: String, value) -> void:
	data[key] = value
	if key == "graphics_preset":   # a preset also sets the render-scale / texture-quality options
		data["render_scale"] = preset()["render_scale"]
		data["texture_quality"] = preset()["texture_quality"]
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
	var pr := preset()
	var tq := 0.0
	if data["texture_quality"] == "high":
		tq = maxf(1.0, float(pr["tq"]))
	RenderingServer.global_shader_parameter_set(&"fl_tex_quality", tq)
	RenderingServer.directional_shadow_atlas_set_size(int(pr["shadow"]), true)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(data["render_scale"])
		vp.msaa_3d = int(pr["msaa"])
		vp.anisotropic_filtering_level = int(pr["aniso"])
