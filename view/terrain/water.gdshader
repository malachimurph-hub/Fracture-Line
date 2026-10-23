shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// M2.8 water: smooth shoreline cut from a blurred wet field (shore_tex R) instead of tile quads,
// depth colour from the deep field (G), two scrolling layers of procedural wave normals, animated
// shore foam, fresnel sky reflection + sun glints. ~2 texture reads and 6 noise taps per pixel.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D shore_tex : hint_default_black, filter_linear, repeat_disable;
uniform vec2 map_size = vec2(128.0, 128.0);
uniform vec3 deep_col : source_color = vec3(0.16, 0.30, 0.32);
uniform vec3 shallow_col : source_color = vec3(0.34, 0.45, 0.38);
uniform vec3 sky_col : source_color = vec3(0.62, 0.72, 0.80);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	return vnoise(p * 1.3 + vec2(t * 0.15, t * 0.45)) * 0.55 + vnoise(p * 3.1 - vec2(t * 0.35, t * 0.2)) * 0.3 + vnoise(p * 7.0 + vec2(t * 0.6, -t * 0.5)) * 0.15;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	vec2 sh = texture(shore_tex, p / map_size).rg;
	float wet = sh.r;
	if (wet < 0.42) discard;                 // smooth, curved waterline
	float t = TIME;
	float e = 0.06;
	float h0 = waves(p, t);
	vec3 nw = normalize(vec3((h0 - waves(p + vec2(e, 0.0), t)) * 1.6, 0.3, (h0 - waves(p + vec2(0.0, e), t)) * 1.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float depth = smoothstep(0.45, 1.0, sh.g * 0.7 + wet * 0.3);
	vec3 col = mix(shallow_col * 1.08, deep_col, depth);
	// fresnel: grazing angles reflect the sky
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float fr = pow(1.0 - clamp(dot(nw, V), 0.0, 1.0), 4.0);
	col = mix(col, sky_col, clamp(fr * 0.85 + 0.06, 0.0, 0.7));
	// animated foam: a band at the waterline plus streaks that wash in and out
	float shore = 1.0 - smoothstep(0.42, 0.62, wet);
	float wash = sin(wet * 40.0 - t * 1.6 + vnoise(p * 0.8) * 6.0) * 0.5 + 0.5;
	float foam = clamp(shore * (0.55 + 0.45 * wash) * smoothstep(0.35, 0.65, vnoise(p * 2.5 + t * 0.2) + shore * 0.5), 0.0, 1.0);
	col = mix(col, vec3(0.88, 0.9, 0.88), foam * 0.75);
	float f = texture(fog_tex, p / map_size).r;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	ALBEDO = mix(vec3(0.0), mix(col * 0.45, col, vis), expl);
	ROUGHNESS = mix(0.06, 0.5, foam);
	SPECULAR = 0.7;
	ALPHA = clamp(mix(0.55, 0.9, depth) + foam * 0.3, 0.0, 1.0) * smoothstep(0.42, 0.47, wet);
}
