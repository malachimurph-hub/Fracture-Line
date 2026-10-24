// FRACTURE LINE model surface (M2): vertex-coloured low-poly parts with Zero Hour-style
// weathering, all object-space triplanar so it sticks to moving units:
//   panel lines + rivets, chipped paint / scratches (bare metal shows through), rust blotches
//   and streaks (rust colour: ambientCG CC0), grime, base dirt rising from the ground line,
//   and sparse stencil markings (procedural, original) on painted / team surfaces.
// Per-instance amounts (set by EntityView from the faction): rust_amt, wear_amt, dirt_amt.
// Texture quality (global fl_tex_quality): Medium skips scratches/stencils and biases mips.
global uniform float fl_tex_quality;
uniform sampler2D base_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_tex_amount = 0.0;
uniform float base_tex_scale = 0.6;
uniform sampler2D weather_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stencil_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform float metallic_v = 0.15;
uniform float roughness_v = 0.72;
uniform float panel_amount = 1.0;
uniform float stencil_amount = 0.0;
uniform float emission_v = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
instance uniform float rust_amt = 0.15;
instance uniform float wear_amt = 0.5;
instance uniform float dirt_amt = 0.6;
varying vec3 opos;
varying vec3 onrm;
#ifdef REVEAL
// construction (M2.4): world-space height built so far + build-edge colour (a = strength)
instance uniform float reveal_wy = 100.0;
instance uniform vec4 reveal_edge = vec4(1.6, 0.9, 0.35, 1.0);
varying float wy;
#endif

vec4 tri(sampler2D t, vec3 p, vec3 n, float s, float bias) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-4);
	return texture(t, p.zy * s, bias) * w.x + texture(t, p.xz * s, bias) * w.y + texture(t, p.xy * s, bias) * w.z;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
#ifdef REVEAL
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
#endif
}

void fragment() {
#ifdef REVEAL
	if (wy > reveal_wy)
		discard;
#endif
	bool hi = fl_tex_quality > 0.5;
	float bias = hi ? 0.0 : 1.0;
	vec3 base = albedo.rgb * (use_vertex_color ? srgb_to_linear(COLOR.rgb) : vec3(1.0));
	if (base_tex_amount > 0.0)
		base *= mix(vec3(1.0), tri(base_tex, opos, onrm, base_tex_scale, bias).rgb * 1.25, base_tex_amount);
	vec4 wt = tri(weather_tex, opos + vec3(0.37, 0.0, 0.11), onrm, 1.1, bias);   // panels, scratches
	vec4 wl = tri(weather_tex, opos * 0.8 + vec3(0.71, 0.3, 0.2), onrm, 0.22, bias); // large: grime, rust
	float side = 1.0 - abs(onrm.y);
	vec3 col = base;
	float metal = metallic_v;
	float rough = roughness_v;
	// panel lines + rivets
	col *= mix(1.0, wt.g, 0.45 * panel_amount);   // M3.1: softer, irregular seams
	// grime: overall cloudy darkening, a bit stronger in recesses facing down
	float grime = (1.0 - wl.r) * (0.22 + 0.16 * side);
	col *= 1.0 - grime * dirt_amt;
	// chipped paint / scratches: bare, slightly brighter metal
	if (hi) {
		float chip = smoothstep(0.5, 0.8, max(wt.b, wl.b)) * wear_amt;
		col = mix(col, vec3(0.42, 0.41, 0.39), chip * 0.75);
		metal = mix(metal, 0.7, chip);
		rough = mix(rough, 0.45, chip);
	}
	// rust patches and streaks
	float rsrc = wl.a * 0.6 + (1.0 - wl.r) * 0.6;
	float rmask = smoothstep(1.0 - rust_amt, 1.12 - rust_amt, rsrc);
	vec3 rc = tri(rust_tex, opos * 1.3, onrm, 0.7, bias).rgb;
	col = mix(col, rc * vec3(1.05, 0.9, 0.8), clamp(rmask, 0.0, 1.0) * 0.9);
	rough = mix(rough, 0.9, rmask);
	metal = mix(metal, 0.1, rmask);
	// base dirt: dusty band rising from the ground line
	float dirt = (1.0 - smoothstep(0.05, 0.4 + wl.r * 0.2, opos.y)) * dirt_amt * side;
	dirt += dirt_amt * 0.18 * (1.0 - side) * smoothstep(0.4, 0.8, wl.r); // dust settling on top faces
	col = mix(col, vec3(0.5, 0.42, 0.31), clamp(dirt, 0.0, 1.0) * 0.7);
	rough = mix(rough, 0.95, dirt);
	// stencils on painted / team surfaces, sparse (side faces only)
	if (hi && stencil_amount > 0.0) {
		vec2 suv = (abs(onrm.x) > abs(onrm.z) ? opos.zy : opos.xy) * 0.75 + vec2(0.13, 0.6);
		vec4 s = texture(stencil_tex, suv);
		float cellmask = step(0.55, fract(sin(dot(floor(suv), vec2(12.9898, 78.233))) * 43758.5453));
		col = mix(col, s.rgb * 0.92, s.a * side * cellmask * stencil_amount * (1.0 - rmask));
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	vec3 emit = vec3(0.0);
	if (emission_v > 0.0)
		emit = (emission_color.rgb * base) * emission_v;
#ifdef REVEAL
	emit += reveal_edge.rgb * reveal_edge.a * (1.0 - smoothstep(0.0, 0.04, reveal_wy - wy));
#endif
	EMISSION = emit;
}
