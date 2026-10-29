shader_type spatial;
// M3.3 Phase 3 (20) night maps: cheap fake lights. Additive, unshaded quads lying on the ground
// (street-lamp pools, building floodlights, vehicle headlight beams) and small lamp glows. No real
// lights, so the phone pays one draw call per group. Fogged like the decals (nothing shows in the
// shroud, half strength in explored fog).
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D fog_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 map_size = vec2(256.0, 256.0);
uniform float cone = 0.0;     // 1 = headlight beam (bright near the vehicle, fans out along +UV.y)
uniform float strength = 1.0;
varying vec3 wpos;
varying vec4 col;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	col = COLOR;
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float a;
	if (cone > 0.5) {
		float along = UV.y;                       // 0 at the vehicle, 1 at the far end
		float half_w = mix(0.18, 1.0, along);
		a = (1.0 - smoothstep(0.0, 1.0, abs(d.x) / half_w)) * (1.0 - along) * smoothstep(0.0, 0.12, along);
	} else {
		float r = length(d);
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.7);
	}
	float f = texture(fog_tex, wpos.xz / map_size).r;
	float vis = smoothstep(0.08, 0.42, f) * mix(0.45, 1.0, smoothstep(0.55, 0.95, f));
	ALBEDO = col.rgb * a * col.a * strength * vis;
}
