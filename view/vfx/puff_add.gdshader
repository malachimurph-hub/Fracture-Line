shader_type spatial;
// Camera-facing soft puff for smoke, dust and fire (MultiMesh). Instance custom:
// x = size, y = rotation, z = seed, w = heat (0 smoke .. 1 fire). Original procedural sprite.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
const bool additive = true;
varying vec4 cust;
varying vec4 col;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	cust = INSTANCE_CUSTOM;
	col = COLOR;
	float s = cust.x; float r = cust.y;
	vec2 q = mat2(vec2(cos(r), sin(r)), vec2(-sin(r), cos(r))) * VERTEX.xy * s;
	vec3 c = MODEL_MATRIX[3].xyz;
	vec4 vp = VIEW_MATRIX * vec4(c, 1.0);
	vp.xy += q;
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float n = vn(UV * 4.0 + cust.z * 17.0) * 0.6 + vn(UV * 9.0 + cust.z * 5.0) * 0.4;
	float a = smoothstep(1.0, 0.35, d + (n - 0.5) * 0.55);
	vec3 c = pow(col.rgb, vec3(2.2));
	// fake lighting: top-left brighter, core hotter for fire
	c *= mix(0.75 + 0.35 * (-p.y * 0.5 + 0.5), 1.0 + 1.5 * (1.0 - d), cust.w);
	if (additive) {
		ALBEDO = c;
		ALPHA = a * col.a;
	} else {
		ALBEDO = c * (0.85 + 0.3 * n);
		ALPHA = a * col.a;
	}
}
