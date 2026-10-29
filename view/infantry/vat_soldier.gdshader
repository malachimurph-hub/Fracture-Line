shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// FRACTURE LINE soldiers (M2.2): vertex-animation-texture playback. Each MultiMesh instance is
// one soldier; INSTANCE_CUSTOM = (frame A, frame B, blend, fade). Positions / normals come from
// baked textures (tools/bake_infantry.gd), so no skeleton runs on the CPU.
// Vertex colour = baked part colour; vertex alpha 1 = team-coloured part (helmet band, pads,
// insurgent scarf). Small object-space grime / dust so they sit in the same world as the
// weathered vehicles.
uniform sampler2D vat_pos : filter_nearest, repeat_disable;
uniform sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform int vat_w = 1;
uniform int vat_rows = 1;
// M3.4: 2 = flags / variant masks packed in UV.y (see tools/bake_infantry_m34.gd)
uniform int vat_fmt = 1;
// M3.4 per soldier: look variant (0..3: head gear / packs), skin tone, uniform tint
instance uniform float variant = 0.0;
instance uniform float skin_tone = 1.0;
instance uniform float tint = 1.0;
instance uniform vec4 team_color : source_color = vec4(0.18, 0.5, 0.88, 1.0);
instance uniform float rust_amt = 0.15;
instance uniform float wear_amt = 0.5;
instance uniform float dirt_amt = 0.6;
varying float vy;
varying vec4 pcol;
varying float fade;
varying vec3 rest;     // M3.4: rest-pose position (camouflage stays on the cloth as he moves)
varying float fl_skin;
varying float fl_camo;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	int vid = int(UV2.x + 0.5) + int(UV2.y + 0.5) * 256;
	int fa = int(INSTANCE_CUSTOM.x + 0.5);
	int fb = int(INSTANCE_CUSTOM.y + 0.5);
	ivec2 base = ivec2(vid % vat_w, vid / vat_w);
	vec3 pa = texelFetch(vat_pos, base + ivec2(0, fa * vat_rows), 0).xyz;
	vec3 pb = texelFetch(vat_pos, base + ivec2(0, fb * vat_rows), 0).xyz;
	vec3 na = texelFetch(vat_nrm, base + ivec2(0, fa * vat_rows), 0).xyz * 2.0 - 1.0;
	vec3 nb = texelFetch(vat_nrm, base + ivec2(0, fb * vat_rows), 0).xyz * 2.0 - 1.0;
	rest = VERTEX;
	VERTEX = mix(pa, pb, INSTANCE_CUSTOM.z);
	NORMAL = normalize(mix(na, nb, INSTANCE_CUSTOM.z));
	vy = VERTEX.y;
	float rr = floor(UV.x / 256.0 + 0.001);
	fl_skin = 0.0;
	fl_camo = 0.0;
	if (vat_fmt >= 2) {
		float hi = floor(UV.y / 256.0 + 0.001);
		float bb = UV.y - hi * 256.0;
		float fl = mod(hi, 16.0);
		float vmask = floor(hi / 16.0 + 0.001);
		float team_b = mod(fl, 2.0);
		fl_skin = step(1.5, mod(fl, 4.0));
		fl_camo = step(3.5, mod(fl, 8.0)) * (1.0 + step(7.5, fl));
		pcol = vec4(rr, UV.x - rr * 256.0, bb, 255.0 * team_b) / 255.0;
		// parts of the other look variants collapse away
		if (vmask > 0.5 && mod(floor(vmask / exp2(floor(variant + 0.5)) + 0.001), 2.0) < 0.5) {
			VERTEX = vec3(0.0, -10.0, 0.0);
		}
	} else {
		// M2.6: part colour packed in UV (x = R*256 + G, y = B + 1000*team); COLOR is unreliable on
		// MultiMesh without per-instance colours in the compatibility renderer (soldiers drew black).
		float team_f = step(500.0, UV.y);
		pcol = vec4(rr, UV.x - rr * 256.0, UV.y - 1000.0 * team_f, 255.0 * team_f) / 255.0;
	}
	fade = INSTANCE_CUSTOM.w;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	vec3 base = srgb_to_linear(pcol.rgb);
	// M2.6: brighter but less saturated, so uniforms read at RTS distance and skin doesn't go orange in warm sun
	base = mix(vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), base, 0.72) * 1.3;
	if (vat_fmt >= 2) {
		// M3.4: smooth, soft-edged camouflage in rest-pose space (no grain, no tiling), per-soldier
		// skin tone and a slight per-soldier tint of the uniform
		if (fl_camo > 0.5) {
			float fq = fl_camo > 1.5 ? 70.0 : 38.0;
			float n1 = vnoise(rest * fq + vec3(3.1, 0.0, 1.7));
			float n2 = vnoise(rest * fq * 1.3 + vec3(-7.0, 2.0, 5.0));
			float dark = smoothstep(0.52, 0.6, n1);
			float lite = smoothstep(0.6, 0.68, n2) * (1.0 - dark);
			vec3 dk = fl_camo > 1.5 ? base * vec3(0.55, 0.62, 0.5) : base * vec3(0.7, 0.68, 0.6);
			vec3 lt = base * vec3(1.16, 1.12, 1.02);
			if (fl_camo > 1.5) {
				float n3 = vnoise(rest * 95.0 + vec3(11.0, 4.0, -2.0));
				dk = mix(dk, base * vec3(0.78, 0.62, 0.48), smoothstep(0.45, 0.55, n3));
			}
			base = mix(mix(base, dk, dark), lt, lite);
		}
		if (fl_skin > 0.5) {
			base *= skin_tone;
		} else if (pcol.a < 0.5) {
			base *= tint;
		}
	}
	vec3 team = team_color.rgb * (0.55 + 0.45 * dot(base, vec3(0.3, 0.59, 0.11)) / 0.6);
	vec3 col = mix(base, team, pcol.a);
	if (vat_fmt < 2) {
		// M2.6 fabric / gear detail: object-space weave + seam darkening so uniforms are not flat
		float weave = 0.5 + 0.5 * sin(vy * 220.0) * sin(vy * 37.0 + 1.7);
		col *= mix(0.93, 1.04, weave);
	}
	// dust on boots / trousers, slight overall grime
	float dust = (1.0 - smoothstep(0.0, 0.16, vy)) * dirt_amt;
	col = mix(col, vec3(0.42, 0.35, 0.26), dust * 0.55);
	col *= 1.0 - 0.12 * dirt_amt;
	// corpses darken as they fade out (no transparency: keeps the opaque pass cheap)
	col *= 1.0 - 0.6 * fade;
	ALBEDO = col;
	ROUGHNESS = mix(0.84, 0.5, pcol.a);
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
