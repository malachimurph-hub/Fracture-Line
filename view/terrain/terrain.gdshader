shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// FRACTURE LINE terrain v1 (M1.2): 8 CC0 ground layers (ambientCG) blended by two splat
// maps (1 texel per tile, bilinear) with noise breakup, slope-based rock, macro variation
// against tiling, and the fog-of-war texture (0 = shroud, ~0.47 explored, 1 = visible).
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D splat_a : filter_linear, repeat_disable; // sand, dirt, dry scrub, green
uniform sampler2D splat_b : filter_linear, repeat_disable; // asphalt, rock, riverbed, concrete
uniform sampler2D t_sand : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_asphalt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_riverbed : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_concrete : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(128.0, 128.0);
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = vnoise(p * 0.9);
	float n2 = vnoise(p * 0.21 + 7.3);
	vec2 jitter = (vec2(n1, vnoise(p * 0.9 + 3.1)) - 0.5) * 0.9;
	vec2 suv = (p + jitter) / map_size;
	vec4 a = texture(splat_a, suv);
	vec4 b = texture(splat_b, (p + jitter * 0.25) / map_size);
	// cliffs: steep faces are rock
	float steep = smoothstep(0.92, 0.7, wnrm.y);
	b.g = max(b.g, steep);
	// sharpen transitions (height-blend-like)
	a = pow(a, vec4(1.6)); b = pow(b, vec4(1.6));
	b.r = pow(texture(splat_b, suv * 0.0 + p / map_size).r, 1.0); // asphalt stays crisp
	float sum = a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a + 1e-4;
	a /= sum; b /= sum;
	vec2 uv = p * 0.25;
	vec3 col = vec3(0.0);
	if (a.r > 0.01) col += a.r * texture(t_sand, uv * 0.8).rgb * vec3(1.06, 0.98, 0.86);
	if (a.g > 0.01) col += a.g * texture(t_dirt, uv).rgb * vec3(1.05, 0.95, 0.85);
	if (a.b > 0.01) {
		vec3 g = texture(t_grass, uv * 1.3).rgb;
		float l = dot(g, vec3(0.3, 0.59, 0.11));
		col += a.b * mix(vec3(l), g, 0.35) * vec3(1.45, 1.22, 0.72); // sun-dried scrub
	}
	if (a.a > 0.01) col += a.a * texture(t_grass, uv * 1.3 + 0.37).rgb * vec3(0.95, 1.08, 0.78);
	if (b.r > 0.01) col += b.r * texture(t_asphalt, uv * 1.5).rgb * vec3(1.15, 1.1, 1.05);
	if (b.g > 0.01) col += b.g * texture(t_rock, uv * 0.7 + vec2(0.0, wpos.y * 0.25)).rgb * vec3(1.12, 1.0, 0.86);
	if (b.b > 0.01) col += b.b * texture(t_riverbed, uv).rgb * vec3(0.8, 0.82, 0.78);
	if (b.a > 0.01) col += b.a * texture(t_concrete, uv * 0.9).rgb * vec3(0.98, 0.95, 0.9);
	col *= mix(0.86, 1.1, n2); // macro variation against visible tiling
	// fog of war
	float f = texture(fog_tex, p / map_size).r;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	vec3 grey = vec3(dot(col, vec3(0.3, 0.59, 0.11)));
	vec3 fogged = mix(grey, col, 0.45) * 0.5;
	ALBEDO = mix(vec3(0.0), mix(fogged, col, vis), expl);
	ROUGHNESS = 0.92 - b.r * 0.12;
	SPECULAR = 0.25;
}
