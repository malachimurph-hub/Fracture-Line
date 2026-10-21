shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// River surface: drifting ripples (procedural normals, flow along +z), murky teal-brown
// tint over the riverbed, soft edge foam, and fog of war.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(128.0, 128.0);
uniform vec3 deep_col : source_color = vec3(0.16, 0.30, 0.32);
uniform vec3 shallow_col : source_color = vec3(0.34, 0.45, 0.38);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	return vnoise(p * 1.7 + vec2(0.0, t * 0.6)) * 0.6 + vnoise(p * 3.9 - vec2(t * 0.3, t * 0.9)) * 0.4;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float e = 0.08;
	float h0 = waves(p, t);
	vec3 nw = normalize(vec3(h0 - waves(p + vec2(e, 0.0), t), 0.35, h0 - waves(p + vec2(0.0, e), t)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float edge = COLOR.r; // 1 at the bank
	vec3 col = mix(deep_col, shallow_col, edge * 0.8 + h0 * 0.15);
	col += vec3(0.5, 0.48, 0.42) * smoothstep(0.75, 1.0, edge + (h0 - 0.5) * 0.4) * 0.35; // foam at banks
	float f = texture(fog_tex, p / map_size).r;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	ALBEDO = mix(vec3(0.0), mix(col * 0.45, col, vis), expl);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	ALPHA = mix(0.78, 0.55, edge);
}
