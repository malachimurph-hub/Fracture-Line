shader_type spatial;
// M3.4 night lights: camera-facing additive sprites (MultiMesh, no real lights).
//   axial = 0: lamp flare - a soft round glow at a headlight or floodlight lens
//   axial = 1: light shaft - a faint cone from a floodlight down to its ground pool; the
//              instance basis Y runs from the lamp (local +0.5) to the pool (local -0.5),
//              basis X length = shaft width at the pool end
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform sampler2D fog_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 map_size = vec2(256.0, 256.0);
uniform float axial = 0.0;
uniform float strength = 1.0;
varying vec3 wpos;
varying vec4 col;
varying float t_v;   // shafts: 0 at the lamp, 1 at the ground
void vertex() {
	col = COLOR;
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 w;
	if (axial > 0.5) {
		vec3 ax = MODEL_MATRIX[1].xyz;                 // lamp -> ground (full length)
		float wid = length(MODEL_MATRIX[0].xyz);
		t_v = 0.5 - VERTEX.y;
		vec3 p = o + ax * VERTEX.y;
		vec3 side = normalize(cross(normalize(ax), normalize(cam - p)));
		w = p + side * VERTEX.x * wid * mix(0.12, 1.0, t_v);
	} else {
		t_v = 0.0;
		float s = length(MODEL_MATRIX[0].xyz);
		w = o + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
		w += normalize(cam - o) * 0.15;                // in front of the lens it sits on
	}
	wpos = w;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float a;
	if (axial > 0.5) {
		a = (1.0 - smoothstep(0.2, 1.0, abs(d.x))) * (1.0 - t_v) * smoothstep(0.0, 0.08, t_v) * 0.35;
	} else {
		float r = length(d);
		a = pow(clamp(1.0 - r, 0.0, 1.0), 2.2) + pow(clamp(1.0 - r * 3.0, 0.0, 1.0), 2.0) * 1.5;
	}
	float f = texture(fog_tex, wpos.xz / map_size).r;
	float vis = smoothstep(0.08, 0.42, f) * mix(0.45, 1.0, smoothstep(0.55, 0.95, f));
	ALBEDO = col.rgb * a * col.a * strength * vis;
}
