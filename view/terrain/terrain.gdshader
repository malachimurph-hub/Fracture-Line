shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// FRACTURE LINE terrain v2 (M2): 7 CC0 PBR ground layers (ambientCG 1K: colour + NormalGL +
// roughness + AO, packed in two Texture2DArrays, ETC2 / ASTC with mipmaps) blended by two
// splat maps with noise breakup and slope rock, plus a close-range detail layer (micro
// albedo + normal), a baked macro variation map against tiling, and fog of war.
// Texture quality (Settings): global fl_tex_quality 1 = High (normals, detail), 0 = Medium
// (albedo only + one mip of bias; no normal/detail fetches).
global uniform float fl_tex_quality;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D splat_a : filter_linear, repeat_disable; // sand, dirt, dry scrub, green
uniform sampler2D splat_b : filter_linear, repeat_disable; // asphalt, rock, riverbed, concrete
uniform sampler2DArray t_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray t_nrao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_macro : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(128.0, 128.0);
uniform sampler2D shore_tex : hint_default_black, filter_linear, repeat_disable; // M2.8 wet field (R)
uniform float dry_scrub = 1.0;    // M2.5 env: desert sun-dried scrub on the grass layer (0 = lush / snow)
uniform float asphalt_dark = 0.0; // M2.9 city maps: dark asphalt roads (any env)
uniform float cloud_amt = 0.13;    // M3.2 item 14: large soft drifting cloud shadows on the ground
uniform float worn_amt = 0.7;     // M3.2 item 14: large soft worn-dirt patches through the grass
uniform float desert_tint = 1.0;  // M2.5 env: warm desert per-layer tints (0 = neutral)
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// M2.9 anti-tiling: a second, rotated + rescaled copy of each layer blended in by low-frequency
// noise, so no repeat lines or repeated features line up across the map (2 fetches only where the
// blend is mid-way; most pixels take one).
const mat2 ROT2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
vec2 uv_alt(vec2 uv, float layer) { return ROT2 * uv * 0.83 + vec2(0.37 + layer * 0.21, 0.11 + layer * 0.13); }
float tile_mix(vec2 p, float layer) { return smoothstep(0.32, 0.68, vnoise(p * 0.09 + vec2(layer * 7.3, layer * 3.1))); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


// M3.1: B-spline bicubic splat lookup (4 bilinear taps): per-tile splat weights no longer show
// as stair-stepped squares / diamonds along road and shore edges.
vec4 cubic_w(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	return vec4(x, y, z, 6.0 - x - y - z) * (1.0 / 6.0);
}
vec4 tex_bicubic(sampler2D t, vec2 uv) {
	vec2 ts = vec2(textureSize(t, 0));
	vec2 tc = uv * ts - 0.5;
	vec2 f = fract(tc);
	tc -= f;
	vec4 xc = cubic_w(f.x);
	vec4 yc = cubic_w(f.y);
	vec4 c = tc.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 o = (c + vec4(xc.yw, yc.yw) / s) / ts.xxyy;
	vec4 s0 = texture(t, o.xz), s1 = texture(t, o.yz), s2 = texture(t, o.xw), s3 = texture(t, o.yw);
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
}

void fragment() {
	vec2 p = wpos.xz;
	bool hi = fl_tex_quality > 0.5;
	float bias = hi ? 0.4 : 1.0;   // M2.9: a little mip bias against shimmer / grain at RTS distance
	float n1 = vnoise(p * 0.9);
	vec2 jitter = (vec2(n1, vnoise(p * 0.9 + 3.1)) - 0.5) * 0.9
		+ (vec2(vnoise(p * 0.21 + 9.7), vnoise(p * 0.21 + 4.3)) - 0.5) * 1.6;   // M2.9: larger-scale wobble on blend edges
	vec2 suv = (p + jitter) / map_size;
	vec4 a = hi ? tex_bicubic(splat_a, suv) : texture(splat_a, suv);
	vec4 b = hi ? tex_bicubic(splat_b, (p + jitter * 0.25) / map_size) : texture(splat_b, (p + jitter * 0.25) / map_size);
	float steep = smoothstep(0.92, 0.7, wnrm.y);
	b.g = max(b.g, steep);
	a = pow(a, vec4(1.6)); b = pow(b, vec4(1.6));
	b.r = hi ? smoothstep(0.3, 0.7, tex_bicubic(splat_b, p / map_size).r) : texture(splat_b, p / map_size).r; // asphalt stays crisp, smooth curves
	float sum = a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a + 1e-4;
	a /= sum; b /= sum;
	float w[7] = float[](a.r, a.g, a.b + a.a, b.r, b.g, b.b, b.a);
	float sc[7] = float[](0.16, 0.2, 0.3, 0.3, 0.14, 0.32, 0.22);
	vec3 tint[7] = vec3[](vec3(1.02, 0.97, 0.88), vec3(1.05, 0.95, 0.85), vec3(1.0), vec3(1.12, 1.08, 1.04),
		vec3(1.08, 1.0, 0.88), vec3(0.85, 0.85, 0.8), vec3(0.98, 0.95, 0.9));
	vec3 col = vec3(0.0);
	vec4 nr = vec4(0.0);
	for (int i = 0; i < 7; i++) {
		if (w[i] > 0.01) {
			vec2 uv = p * sc[i];
			float tm = tile_mix(p, float(i));
			vec2 uv2 = uv_alt(uv, float(i));
			vec3 c = texture(t_albedo, vec3(uv, float(i)), bias).rgb;
			if (tm > 0.02) c = mix(c, texture(t_albedo, vec3(uv2, float(i)), bias).rgb, tm);
			if (i == 4) { // M3.0 mountains: triplanar rock on the faces (no smeared stretch), strata, crevices
				vec3 bw = pow(abs(wnrm), vec3(3.0)); bw /= (bw.x + bw.y + bw.z);
				if (bw.y < 0.95) {
					vec3 cx = texture(t_albedo, vec3(ROT2 * wpos.zy * sc[i] * 1.3, 4.0), bias).rgb;
					vec3 cz = texture(t_albedo, vec3(wpos.xy * sc[i] * 1.3 + 0.41, 4.0), bias).rgb;
					c = c * bw.y + cx * bw.x + cz * bw.z;
				}
				float sn = vnoise(p * 0.35 + wpos.y * 0.6);
				float strata = 0.5 + 0.5 * sin(wpos.y * 5.5 + sn * 3.5 + vnoise(p * 0.12) * 4.0);
				c *= mix(0.86, 1.1, strata);
				float crev = smoothstep(0.62, 0.8, vnoise(p * 1.7 + wpos.y * 1.3));
				c *= 1.0 - crev * 0.28 * (1.0 - wnrm.y);
				c = mix(c, c * vec3(1.08, 1.04, 0.98) + 0.03, smoothstep(0.75, 0.95, wnrm.y) * smoothstep(1.0, 2.2, wpos.y)); // sun-bleached ledges
				c *= mix(0.88, 1.08, smoothstep(0.3, 3.0, wpos.y)); // darker foot, lighter summits
			}
			c *= mix(vec3(1.0), tint[i], desert_tint);
			if (i == 3 && asphalt_dark > 0.0) { // M2.9: dark city asphalt, keeps the texture's grain
				float la = dot(c, vec3(0.3, 0.59, 0.11));
				c = mix(c, vec3(0.035, 0.037, 0.04) + vec3(la * 0.1), asphalt_dark);
			}
			if (i == 2) { // grass: green layer vs sun-dried scrub
				float l = dot(c, vec3(0.3, 0.59, 0.11));
				vec3 dry = mix(vec3(l), c, 0.35) * vec3(1.45, 1.22, 0.72);
				c = mix(mix(c, dry, dry_scrub), c * mix(vec3(1.0), vec3(0.95, 1.08, 0.78), desert_tint), a.a / max(1e-4, a.b + a.a));
			}
			col += w[i] * c;
			if (hi) {
				vec4 n0 = texture(t_nrao, vec3(uv, float(i)), bias);
				if (tm > 0.02) n0 = mix(n0, texture(t_nrao, vec3(uv2, float(i)), bias), tm);
				nr += w[i] * n0;
			}
		}
	}
	// M3.0: flat ledges high on the massifs catch dust / dry grass (breaks up big rock fields)
	if (w[4] > 0.05 && wpos.y > 0.9) {
		float cap = smoothstep(0.86, 0.97, wnrm.y) * smoothstep(0.35, 0.7, vnoise(p * 0.5 + 5.0)) * w[4];
		if (cap > 0.01) {
			vec3 g = texture(t_albedo, vec3(p * sc[2], 2.0), bias).rgb * mix(vec3(1.0), vec3(1.15, 1.0, 0.7), desert_tint * dry_scrub);
			col = mix(col, g, cap * 0.7);
		}
	}
	// M3.2 item 14: big soft worn / bare-dirt patches through the grass (painterly, no tiling)
	if (w[2] > 0.05 && worn_amt > 0.0) {
		float wn = vnoise(p * 0.05 + 17.0) * 0.7 + vnoise(p * 0.19 + 3.0) * 0.3;
		float wp = smoothstep(0.6, 0.8, wn) * w[2] * worn_amt;
		if (wp > 0.01) {
			vec3 dt = texture(t_albedo, vec3(p * sc[1], 1.0), bias).rgb * mix(vec3(1.0), tint[1], desert_tint);
			col = mix(col, dt, wp);
		}
	}
	// macro variation (baked, ~64 m period) against visible tiling
	// M2.9: seamless macro map at two unrelated scales / rotations (no 64 m repeat lines)
	vec3 mac = mix(texture(t_macro, p / 64.0, bias).rgb, texture(t_macro, ROT2 * p / 173.0 + 0.31, bias).rgb, 0.5);
	mac = (mac - 0.5) * 1.35 + 0.5;
	col *= mix(0.84, 1.1, mac.r);
	col *= mix(mix(vec3(1.0), vec3(1.04, 0.99, 0.92), desert_tint), mix(vec3(1.0), vec3(0.95, 0.99, 1.04), desert_tint), mac.g * 0.6);
	col = mix(col, col * mix(vec3(1.0), vec3(1.08, 1.0, 0.86), desert_tint), (mac.b - 0.5) * 0.35 * (a.r + a.g));
	// M3.2 Zero Hour look: richer colour, painterly warm / cool patches, darker steep slopes
	float lum0 = dot(col, vec3(0.3, 0.59, 0.11));
	col = max(vec3(0.0), mix(vec3(lum0), col, mix(1.14, 0.96, desert_tint * 0.0 + dry_scrub * 0.6)));
	float pn = vnoise(p * 0.09 + 3.7);
	col *= mix(vec3(0.92, 0.95, 1.0), vec3(1.05, 1.0, 0.94), pn);   // painterly cool / warm patches
	float pn2 = vnoise(p * 0.6 + 9.1);
	col *= mix(0.9, 1.07, pn2);                                        // mid-scale mottling
	col *= mix(1.0, 0.8, smoothstep(0.8, 0.45, wnrm.y));
	// M3.2 item 14: warm, slightly desaturated grade + slow drifting cloud shadows
	float lum1 = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(lum1), col, 0.9) * vec3(1.03, 1.0, 0.95);
	if (cloud_amt > 0.0) {
		vec2 cp = p + TIME * vec2(0.22, 0.12);
		float cn = vnoise(cp * 0.028) * 0.72 + vnoise(cp * 0.085 + 7.0) * 0.28;
		col *= 1.0 - smoothstep(0.42, 0.8, cn) * cloud_amt;
	}
	vec3 n_t = vec3(0.0, 0.0, 1.0);
	float rough = 0.92 - b.r * 0.12;
	float ao = 1.0;
	if (hi) {
		n_t = vec3((nr.rg * 2.0 - 1.0) * 0.8, 0.0);
		rough = mix(rough, nr.b, 0.85);
		ao = mix(1.0, nr.a, 0.7);
		col *= mix(0.72, 1.0, nr.a);   // M3.2: cavity / crevice darkening baked into the albedo
		// detail layer: fades in near the camera
		float dist = length(wpos - CAMERA_POSITION_WORLD);
		float df = smoothstep(42.0, 16.0, dist);
		if (df > 0.01) {
			vec3 d = texture(t_detail, p * 1.1).rgb;
			col *= mix(1.0, 0.88 + d.r * 0.24, df * 0.45);   // M2.9: softer micro detail (less grain)
			n_t.xy += (d.gb * 2.0 - 1.0) * 0.25 * df;
		}
		n_t.z = sqrt(max(0.0, 1.0 - dot(n_t.xy, n_t.xy)));
		// tangent frame from world axes (terrain UVs are planar world XZ)
		vec3 N = normalize(wnrm);
		vec3 T = normalize(vec3(1.0, 0.0, 0.0) - N * N.x);
		vec3 B = cross(N, T);
		vec3 nw = normalize(T * n_t.x - B * n_t.y + N * n_t.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	// M2.8: damp, darker ground in a soft band along the waterline
	float wet = texture(shore_tex, p / map_size).r;
	float damp = smoothstep(0.12, 0.48, wet);
	col *= mix(1.0, 0.62, damp);
	rough = mix(rough, 0.35, damp);
	// fog of war
	float f = texture(fog_tex, p / map_size).r;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	vec3 grey = vec3(dot(col, vec3(0.3, 0.59, 0.11)));
	vec3 fogged = mix(grey, col, 0.45) * 0.5;
	ALBEDO = mix(vec3(0.0), mix(fogged, col, vis), expl);
	ROUGHNESS = rough;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	SPECULAR = 0.25;
}
