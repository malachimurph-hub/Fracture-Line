shader_type spatial;
// M3.2 item 14: persistent tread/tyre track marks (MultiMesh quads, one per ~0.3-tile segment).
// Instance custom: x = birth time (s), y = seed, z = strength. Fades out over `life` seconds in the
// shader (no per-frame CPU work). Original procedural.
render_mode cull_disabled, depth_draw_never, shadows_disabled, unshaded;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(128.0, 128.0);
uniform float now = 0.0;
uniform float life = 80.0;
varying vec4 cust;
varying vec3 wpos;
void vertex() { cust = INSTANCE_CUSTOM; wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float u = abs(UV.x * 2.0 - 1.0);
	// two treads, soft edges
	float tread = smoothstep(0.52, 0.62, u) * smoothstep(1.0, 0.86, u);
	// cross bars along the segment (soft, no hard squares)
	float bars = 0.75 + 0.25 * sin((UV.y + cust.y) * 6.2831 * 3.0);
	float ends = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
	float age = clamp((now - cust.x) / life, 0.0, 1.0);
	float a = tread * bars * mix(0.55, 1.0, ends) * cust.z * (1.0 - age * age);
	float f = texture(fog_tex, wpos.xz / map_size).r;
	ALBEDO = vec3(0.13, 0.1, 0.075) * smoothstep(0.08, 0.6, f);
	ALPHA = a * 0.42;
}
