shader_type spatial;
// Ground scorch / crater decal (MultiMesh quads). Instance custom: x = kind (0 scorch,
// 1 crater, 2 rubble), y = seed, z = alpha. Original procedural.
render_mode cull_disabled, depth_draw_never, shadows_disabled, diffuse_burley;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(128.0, 128.0);
varying vec4 cust;
varying vec3 wpos;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { cust = INSTANCE_CUSTOM; wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.y, p.x);
	float n = vn(vec2(ang * 2.5, cust.y * 31.0)) * 0.35 + vn(UV * 7.0 + cust.y * 13.0) * 0.25;
	float d = length(p) + n * 0.5;
	float a = smoothstep(1.0, 0.45, d);
	vec3 c = mix(vec3(0.035, 0.03, 0.026), vec3(0.16, 0.12, 0.09), smoothstep(0.2, 0.95, d));
	if (cust.x > 0.5 && cust.x < 1.5) {
		float rim = smoothstep(0.55, 0.7, d) * smoothstep(0.95, 0.75, d);
		c = mix(c * 0.7, vec3(0.42, 0.35, 0.26), rim);
		a = max(a, rim);
	} else if (cust.x > 1.5) {
		float chunks = step(0.62, vn(UV * 22.0 + cust.y * 3.0));
		c = mix(vec3(0.12, 0.11, 0.1), vec3(0.36, 0.33, 0.29), chunks);
		c = mix(c, vec3(0.04, 0.035, 0.03), smoothstep(0.5, 0.0, d) * 0.6);
		a = smoothstep(1.0, 0.7, d) * 0.95;
	}
	float f = texture(fog_tex, wpos.xz / map_size).r;
	ALBEDO = c * smoothstep(0.08, 0.6, f);
	ALPHA = a * cust.z;
	ROUGHNESS = 1.0;
}
