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
uniform vec3 vat_min = vec3(0.0);
uniform vec3 vat_max = vec3(1.0);
// M3.4 per soldier: look variant (0..3: head gear / packs), skin tone, uniform tint
instance uniform float variant = 0.0;
instance uniform float skin_tone = 1.0;
instance uniform float tint = 1.0;
instance uniform vec4 team_color : source_color = vec4(0.18, 0.5, 0.88, 1.0);
instance uniform float rust_amt = 0.15;
instance uniform float wear_amt = 0.5;
instance uniform float dirt_amt = 0.6;
// 0 keep the baked look, 1 US MultiCam, 2 German Flecktarn, 3 Russian EMR, 4 Iranian woodland
instance uniform float pat = 0.0;
varying float vy;
varying vec4 pcol;
varying float fade;
varying vec3 rest;     // M3.4: rest-pose position (camouflage stays on the cloth as he moves)
varying float fl_skin;
varying float fl_camo;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// M3.4 compact VAT (fmt 3): position = 11 / 11 / 10 bits in RGBA8 over vat_min..vat_max
vec3 vat_unpack(vec4 c) {
	ivec4 b = ivec4(round(c * 255.0));
	int x = b.r | ((b.g & 7) << 8);
	int y = (b.g >> 3) | ((b.b & 63) << 5);
	int z = (b.b >> 6) | (b.a << 2);
	vec3 q = vec3(float(x) / 2047.0, float(y) / 2047.0, float(z) / 1023.0);
	return vat_min + q * (vat_max - vat_min);
}
vec3 oct_decode(vec2 e) {
	vec2 f = e * 2.0 - 1.0;
	vec3 n = vec3(f.x, 1.0 - abs(f.x) - abs(f.y), f.y);
	float t = max(-n.y, 0.0);
	n.x += n.x >= 0.0 ? -t : t;
	n.z += n.z >= 0.0 ? -t : t;
	return normalize(n);
}

void vertex() {
	int vid = int(UV2.x + 0.5) + int(UV2.y + 0.5) * 256;
	int fa = int(INSTANCE_CUSTOM.x + 0.5);
	int fb = int(INSTANCE_CUSTOM.y + 0.5);
	ivec2 base = ivec2(vid % vat_w, vid / vat_w);
	vec3 pa;
	vec3 pb;
	vec3 na;
	vec3 nb;
	if (vat_fmt >= 3) {
		pa = vat_unpack(texelFetch(vat_pos, base + ivec2(0, fa * vat_rows), 0));
		pb = vat_unpack(texelFetch(vat_pos, base + ivec2(0, fb * vat_rows), 0));
		na = oct_decode(texelFetch(vat_nrm, base + ivec2(0, fa * vat_rows), 0).rg);
		nb = oct_decode(texelFetch(vat_nrm, base + ivec2(0, fb * vat_rows), 0).rg);
	} else {
		pa = texelFetch(vat_pos, base + ivec2(0, fa * vat_rows), 0).xyz;
		pb = texelFetch(vat_pos, base + ivec2(0, fb * vat_rows), 0).xyz;
		na = texelFetch(vat_nrm, base + ivec2(0, fa * vat_rows), 0).xyz * 2.0 - 1.0;
		nb = texelFetch(vat_nrm, base + ivec2(0, fb * vat_rows), 0).xyz * 2.0 - 1.0;
	}
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

float wave(vec3 p, vec3 k, float phase) {
	return 0.5 + 0.5 * sin(dot(p, k) + phase);
}

// Large soft blotches. Frequencies are low so a phone at match zoom still sees regions, not grain.
vec3 multicam(vec3 p) {
	vec3 tan = srgb_to_linear(vec3(0.73, 0.62, 0.45));
	vec3 pale = srgb_to_linear(vec3(0.84, 0.74, 0.56));
	vec3 brown = srgb_to_linear(vec3(0.45, 0.30, 0.18));
	vec3 green = srgb_to_linear(vec3(0.34, 0.40, 0.24));
	vec3 dark = srgb_to_linear(vec3(0.26, 0.22, 0.16));
	float a = wave(p, vec3(34.0, 46.0, 28.0), 0.4);
	float b = wave(p, vec3(-28.0, 40.0, 36.0), 1.7);
	float c = wave(p, vec3(38.0, -24.0, 32.0), 2.8);
	vec3 col = tan;
	col = mix(col, pale, smoothstep(0.18, 0.42, a) * (1.0 - smoothstep(0.35, 0.6, b)));
	col = mix(col, green, smoothstep(0.48, 0.72, a));
	col = mix(col, brown, smoothstep(0.52, 0.78, b));
	col = mix(col, dark, smoothstep(0.7, 0.9, c) * 0.85);
	return col;
}

vec3 flecktarn(vec3 p) {
	vec3 base_c = srgb_to_linear(vec3(0.46, 0.48, 0.30));
	vec3 sc = vec3(22.0, 26.0, 22.0);
	vec3 cell = floor(p * sc);
	vec3 f = fract(p * sc) - 0.5;
	float dotm = 1.0 - smoothstep(0.16, 0.34, length(f));
	float id = mod(cell.x + cell.y * 2.0 + cell.z * 3.0, 5.0);
	vec3 spot = srgb_to_linear(vec3(0.10, 0.12, 0.08));
	spot = mix(spot, srgb_to_linear(vec3(0.16, 0.28, 0.14)), step(0.5, id));
	spot = mix(spot, srgb_to_linear(vec3(0.32, 0.36, 0.18)), step(1.5, id));
	spot = mix(spot, srgb_to_linear(vec3(0.40, 0.26, 0.14)), step(2.5, id));
	spot = mix(spot, srgb_to_linear(vec3(0.55, 0.62, 0.32)), step(3.5, id));
	return mix(base_c, spot, dotm);
}

vec3 emr(vec3 p) {
	vec3 sc = vec3(26.0, 32.0, 26.0);
	vec3 cell = floor(p * sc);
	vec3 f = abs(fract(p * sc) - 0.5);
	float edge = smoothstep(0.42, 0.5, max(f.x, max(f.y, f.z)));
	float id = mod(cell.x + cell.y * 2.0 + cell.z * 5.0, 4.0);
	vec3 a = srgb_to_linear(vec3(0.55, 0.58, 0.40));
	vec3 b = srgb_to_linear(vec3(0.32, 0.40, 0.22));
	vec3 c = srgb_to_linear(vec3(0.42, 0.32, 0.20));
	vec3 d = srgb_to_linear(vec3(0.22, 0.26, 0.16));
	vec3 col = a;
	col = mix(col, b, step(0.5, id));
	col = mix(col, c, step(1.5, id));
	col = mix(col, d, step(2.5, id));
	return mix(col, a, edge * 0.35);
}

vec3 woodland(vec3 p) {
	vec3 olive = srgb_to_linear(vec3(0.36, 0.40, 0.22));
	vec3 dk = srgb_to_linear(vec3(0.14, 0.22, 0.12));
	vec3 brown = srgb_to_linear(vec3(0.34, 0.24, 0.12));
	vec3 black = srgb_to_linear(vec3(0.10, 0.11, 0.08));
	float a = wave(p, vec3(30.0, 40.0, 26.0), 0.2);
	float b = wave(p, vec3(-26.0, 34.0, 32.0), 1.4);
	float c = wave(p, vec3(36.0, -20.0, 28.0), 2.2);
	vec3 col = olive;
	col = mix(col, dk, smoothstep(0.55, 0.78, a));
	col = mix(col, brown, smoothstep(0.58, 0.82, b));
	col = mix(col, black, smoothstep(0.78, 0.94, c) * 0.45);
	return col;
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
			if (pat > 3.5) {
				base = woodland(rest);
			} else if (pat > 2.5) {
				base = emr(rest);
			} else if (pat > 1.5) {
				base = flecktarn(rest);
			} else if (pat > 0.5) {
				base = multicam(rest);
			} else {
				// Conscripts and any unit left on the baked look: the old smooth blotch.
				float fq = fl_camo > 1.5 ? 70.0 : 38.0;
				float n1 = vnoise(rest * fq + vec3(3.1, 0.0, 1.7));
				float n2 = vnoise(rest * fq * 1.3 + vec3(-7.0, 2.0, 5.0));
				float dark = smoothstep(0.5, 0.58, n1);
				float lite = smoothstep(0.6, 0.68, n2) * (1.0 - dark);
				vec3 dk = fl_camo > 1.5 ? base * vec3(0.5, 0.58, 0.46) : base * vec3(0.6, 0.6, 0.5);
				vec3 lt = base * vec3(1.16, 1.12, 1.02);
				if (fl_camo > 1.5) {
					float n3 = vnoise(rest * 95.0 + vec3(11.0, 4.0, -2.0));
					dk = mix(dk, base * vec3(0.78, 0.62, 0.48), smoothstep(0.45, 0.55, n3));
				}
				base = mix(mix(base, dk, dark), lt, lite);
			}
		} else if (pat > 0.5 && pat < 1.5 && fl_skin < 0.5 && pcol.a < 0.5) {
			// Coyote plate carrier, pouches and helmet. Boots and weapons stay dark.
			float y = dot(base, vec3(0.3, 0.59, 0.11));
			if (y > 0.07 && y < 0.42) {
				base = mix(base, srgb_to_linear(vec3(0.52, 0.40, 0.26)), 0.55);
			}
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
