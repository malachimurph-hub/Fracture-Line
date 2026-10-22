// FRACTURE LINE M2.4 projectile streaks (tracers, shells, rocket flares, muzzle tongues) drawn as
// camera-facing ribbons from a MultiMesh: instance origin = head, basis x column = tail - head,
// COLOR = colour, INSTANCE_CUSTOM = (half width, core boost, seed, unused). Original shader.
varying vec4 col;
varying vec4 cust;
varying vec2 sv;
void vertex() {
	col = COLOR;
	cust = INSTANCE_CUSTOM;
	vec3 head = MODEL_MATRIX[3].xyz;
	vec3 tail = head + MODEL_MATRIX[0].xyz;
	float t = VERTEX.y * 0.5 + 0.5;          // 0 tail .. 1 head
	vec3 hv = (VIEW_MATRIX * vec4(head, 1.0)).xyz;
	vec3 tv = (VIEW_MATRIX * vec4(tail, 1.0)).xyz;
	vec3 d = hv - tv;
	float l = length(d);
	vec3 dn = l > 1e-5 ? d / l : vec3(0.0, 1.0, 0.0);
	vec3 a = mix(tv, hv, t);
	vec3 side = cross(dn, normalize(a));
	float sl = length(side);
	side = sl > 1e-5 ? side / sl : vec3(1.0, 0.0, 0.0);
	float w = cust.x;
	// round-ish caps: push the end vertices a little past head / tail
	a += dn * w * (t * 2.0 - 1.0);
	a += side * VERTEX.x * w;
	POSITION = PROJECTION_MATRIX * vec4(a, 1.0);
	sv = vec2(VERTEX.x, t);
}
void fragment() {
	float across = 1.0 - abs(sv.x);
	float body = smoothstep(0.0, 0.7, across);
	float core = smoothstep(0.55, 1.0, across);
	float along = smoothstep(0.0, 0.85, sv.y) * (1.0 - smoothstep(0.97, 1.0, sv.y) * 0.5);
	vec3 c = pow(col.rgb, vec3(2.2));
	ALBEDO = c * (1.0 + core * cust.y);
	ALPHA = clamp(col.a * body * along, 0.0, 1.0);
}
