// FRACTURE LINE M2.2 model surface ("m3" kit): ONE material per mesh, the part's look chosen by
// a class id in vertex alpha (COLOR.a * 20). This keeps a vehicle at 1 draw per moving node
// (hull, turret, barrel) instead of one per material. Classes:
//  0 painted metal   1 team paint      2 glass           3 rubber          4 track (scrolls)
//  5 lamp (emissive) 6 bare steel      7 wheel rubber*   8 wheel steel*    9 canvas
// 10 concrete       11 corrugated      12 wood           13 sandbag        14 charred
// 15 team lamp      16 dark interior   17 rusty scrap
// 18 spinner (M2.7: fans / radar dishes turn about a vertical axis at UV = pivot xz, UV2.x = rad/s;
//    UV2.y > 0.5: the part is painted (class 0 look) else bare steel)
// 19 pulse lamp (M2.7: emissive that breathes, e.g. the fusion core; UV2.x = phase)
// 20 camo paint (M2.7b: painted metal with a faction camo pattern from the base colour;
//    UV2.x = pattern 0 US three-tone soft blotches, 1 EU splinter, 2 TPLA hand-sprayed bands)
// (* spins: UV = axle (y, z), UV2 = (axle x, radius [+10 = steers]))
// Weathering (object-space triplanar, so it sticks to moving parts) as the M2 shader: panel
// lines, chipped paint, rust, grime, ground dirt, stencils, plus damage soot / scorch.
global uniform float fl_tex_quality;
uniform sampler2D weather_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// M3.1: 2048 px detail normal map (plate seams, rivets, hatches, grain), object-space triplanar.
// Replaces the old derivative (dFdx/fwidth) bump + edge tricks that showed 2x2-pixel blocks.
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stencil_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform float stencil_amount = 0.6;
instance uniform vec4 team_color : source_color = vec4(0.18, 0.5, 0.88, 1.0);
instance uniform float rust_amt = 0.15;
instance uniform float wear_amt = 0.5;
instance uniform float dirt_amt = 0.6;
instance uniform float wheel_dist = 0.0;   // distance travelled (world units): wheels + tracks
instance uniform float steer = 0.0;        // radians, wheels flagged as steering
instance uniform float damage_amt = 0.0;   // 0 pristine .. 1 burnt-out
// M3.2 item 14: per-asset baked surface texture (tools/gfx_m32/tex14): one Texture2DArray layer
// holds 6 axis views of each mesh's local box. R = AO, G = signed curvature + panel seams,
// B = grime (<= 0.75) / faction markings (> 0.8). Set per MeshInstance by the bake tool:
// bake_o = (box origin xyz, layer), bake_s = (box size xyz, strength; 0 = not baked),
// bake_r = rect of the mesh's 3 x 2 view grid in the layer (uv).
uniform sampler2DArray bake_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
instance uniform vec4 bake_o = vec4(0.0);
instance uniform vec4 bake_s = vec4(0.0);
instance uniform vec4 bake_r = vec4(0.0);
#ifdef REVEAL
instance uniform float reveal_y = 10.0;    // construction: object-space height built so far
instance uniform vec4 reveal_edge = vec4(1.6, 0.9, 0.35, 1.0);   // build-edge colour, a = strength
#endif
varying vec3 opos;
varying vec3 onrm;
varying flat int cls;

vec4 tri(sampler2D t, vec3 p, vec3 n, float s, float bias) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-4);
	return texture(t, p.zy * s, bias) * w.x + texture(t, p.xz * s, bias) * w.y + texture(t, p.xy * s, bias) * w.z;
}

vec3 dn(vec2 uv, float bias) {
	vec2 t = texture(detail_n, uv, bias).rg * 2.0 - 1.0;
	return vec3(t, sqrt(clamp(1.0 - dot(t, t), 0.0, 1.0)));
}
// whiteout-blended triplanar tangent normals -> object-space normal around n
vec3 tri_n(vec3 p, vec3 n, float s, float k, float bias) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-4);
	vec3 tx = dn(p.zy * s, bias); tx.xy *= k;
	vec3 ty = dn(p.xz * s, bias); ty.xy *= k;
	vec3 tz = dn(p.xy * s, bias); tz.xy *= k;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

vec3 bake_view(int k, vec2 uv) {
	vec2 tile = bake_r.zw / vec2(3.0, 2.0);
	vec2 o = bake_r.xy + vec2(float(k % 3), float(k / 3)) * tile;
	return texture(bake_tex, vec3(o + tile * (0.01 + clamp(uv, 0.0, 1.0) * 0.98), bake_o.w)).rgb;
}
// triplanar over the 6 baked views (each picked by the sign of the normal component)
vec3 bake_sample(vec3 p, vec3 n) {
	vec3 t = (p - bake_o.xyz) / bake_s.xyz;
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-4);
	vec3 r = vec3(0.0);
	if (w.x > 0.02) r += w.x * bake_view(n.x > 0.0 ? 0 : 3, vec2(t.z, 1.0 - t.y));
	if (w.y > 0.02) r += w.y * bake_view(n.y > 0.0 ? 1 : 4, vec2(t.x, 1.0 - t.z));
	if (w.z > 0.02) r += w.z * bake_view(n.z > 0.0 ? 2 : 5, vec2(t.x, 1.0 - t.y));
	return r / max(w.x * step(0.02, w.x) + w.y * step(0.02, w.y) + w.z * step(0.02, w.z), 1e-4);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	cls = int(COLOR.a * 20.0 + 0.5);
	opos = VERTEX;
	onrm = NORMAL;
	if (cls == 18) {
		float a = TIME * UV2.x;
		float c = cos(a), s = sin(a);
		vec2 q = VERTEX.xz - UV;
		VERTEX.xz = UV + vec2(q.x * c - q.y * s, q.x * s + q.y * c);
		NORMAL.xz = vec2(NORMAL.x * c - NORMAL.z * s, NORMAL.x * s + NORMAL.z * c);
	}
	if (cls == 7 || cls == 8) {
		float r = UV2.y;
		bool steers = r > 9.0;
		r = max(0.02, steers ? r - 10.0 : r);
		float a = wheel_dist / r;
		float c = cos(a), s = sin(a);
		vec2 q = VERTEX.yz - UV;
		VERTEX.yz = UV + vec2(q.x * c - q.y * s, q.x * s + q.y * c);
		NORMAL.yz = vec2(NORMAL.y * c - NORMAL.z * s, NORMAL.y * s + NORMAL.z * c);
		if (steers) {
			float cs = cos(steer), ss = sin(steer);
			vec2 h = VERTEX.xz - vec2(UV2.x, UV.y);
			VERTEX.xz = vec2(UV2.x, UV.y) + vec2(h.x * cs + h.y * ss, -h.x * ss + h.y * cs);
			NORMAL.xz = vec2(NORMAL.x * cs + NORMAL.z * ss, -NORMAL.x * ss + NORMAL.z * cs);
		}
	}
}

void fragment() {
#ifdef REVEAL
	if (opos.y > reveal_y)
		discard;
#endif
	bool hi = fl_tex_quality > 0.5;
	float bias = hi ? 0.0 : 1.0;
	vec3 base = srgb_to_linear(COLOR.rgb);
	float metal = 0.3;
	float rough = 0.62;
	float panel = 0.8;
	float weather = 1.0;     // how much rust / chipping applies
	float stencil = 0.0;
	vec3 emit = vec3(0.0);
	vec4 wt = tri(weather_tex, opos + vec3(0.37, 0.0, 0.11), onrm, 1.0, bias);   // M3.1: 2048 px, ~0.12 u plates   // panels, scratches
	vec4 wl = tri(weather_tex, opos * 0.8 + vec3(0.71, 0.3, 0.2), onrm, 0.35, bias); // large blotches
	if (cls == 1 || cls == 15) {
		base = team_color.rgb * mix(0.85, 1.0, COLOR.r);
		stencil = stencil_amount;
		emit = team_color.rgb * (cls == 15 ? 1.6 : 0.12);
	} else if (cls == 2) {
		metal = 0.6; rough = 0.08; panel = 0.0; weather = 0.15;
		base *= 0.55;
	} else if (cls == 3 || cls == 7) {
		metal = 0.0; rough = 0.88; panel = 0.0; weather = 0.0;
	} else if (cls == 4) {
		float along = fract((UV.x - wheel_dist) * 6.0);
		float link = smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.55, 0.7, along));
		float pin = 1.0 - smoothstep(0.0, 0.18, abs(UV.y - 0.5) - 0.32);
		base *= mix(0.45, 1.0, link) * mix(1.0, 1.35, pin * (1.0 - link));
		metal = mix(0.25, 0.75, link); rough = mix(0.9, 0.45, link); panel = 0.0; weather = 0.4;
	} else if (cls == 5) {
		emit = base * 3.0; panel = 0.0; weather = 0.0; rough = 0.2;
	} else if (cls == 19) {
		float pulse = 0.5 + 0.5 * sin(TIME * 2.1 + UV2.x);
		emit = base * mix(1.6, 4.2, pulse * pulse); panel = 0.0; weather = 0.0; rough = 0.25;
	} else if (cls == 20) {
		int pat = int(UV2.x + 0.5);
		vec3 dk = base * vec3(0.7, 0.68, 0.6);
		vec3 lt = base * vec3(1.18, 1.12, 0.95) + vec3(0.01, 0.008, 0.0);
		if (pat == 3) {
			// M3.0 US desert tan: solid CARC tan with faint low-frequency tone variation (no camo)
			vec4 cm = tri(weather_tex, opos * 0.35 + vec3(1.3, 0.0, 2.9), onrm, 0.3, bias);
			base = vec3(0.56, 0.47, 0.33) * mix(0.92, 1.06, cm.r);
		} else if (pat == 4) {
			// M3.0 US woodland (M81-style): green base, brown and black blotches, khaki highlights
			vec4 cm = tri(weather_tex, opos * 0.8 + vec3(3.1, 0.0, 1.7), onrm, 0.45, bias);
			vec4 cm2 = tri(weather_tex, opos * 1.3 + vec3(7.7, 2.0, 0.3), onrm, 0.45, bias);
			vec3 w = vec3(0.36, 0.42, 0.24);
			w = mix(w, vec3(0.42, 0.31, 0.19), smoothstep(0.52, 0.56, cm.r));
			w = mix(w, vec3(0.13, 0.135, 0.12), 1.0 - smoothstep(0.36, 0.4, cm.r));   // M3.1: noise only (G = plate seams)
			w = mix(w, vec3(0.58, 0.55, 0.38), smoothstep(0.66, 0.7, cm2.r));
			base = w;
		} else if (pat == 1) {
			// splinter: hard-edged shards from quantised noise on a sheared lattice (M3.1: slanted
			// parallelograms, not axis-aligned boxes)
			vec3 q = floor(mat3(vec3(3.0, 0.0, -1.1), vec3(1.3, 2.0, 0.6), vec3(0.9, 0.0, 3.0)) * opos + vec3(0.3, 0.1, 0.7));
			float n = fract(sin(dot(q, vec3(12.99, 78.23, 37.71))) * 43758.55);
			vec4 sp = tri(weather_tex, opos * 0.5 + q * 0.13, onrm, 0.6, bias);
			float k = sp.r * 0.5 + n * 0.5;
			base = k > 0.66 ? dk : (k < 0.3 ? lt : base);
		} else {
			vec4 cm = tri(weather_tex, opos + vec3(3.1, 0.0, 1.7), onrm, pat == 2 ? 0.55 : 0.42, bias);
			float a1 = smoothstep(0.55, 0.6, cm.r);
			float a2 = 1.0 - smoothstep(0.38, 0.43, cm.r);   // M3.1: three tones from one noise (G = plate seams now)
			vec3 c2 = pat == 2 ? base * vec3(0.8, 0.68, 0.55) : base * vec3(0.86, 0.78, 0.6);
			base = mix(mix(base, c2, a1), pat == 2 ? lt : dk, a2);
		}
		stencil = stencil_amount * 0.5;
	} else if (cls == 18) {
		if (UV2.y > 0.5) { metal = 0.3; rough = 0.6; } else { metal = 0.75; rough = 0.42; }
		panel = 0.15; weather = 0.5;
	} else if (cls == 6 || cls == 8) {
		metal = 0.75; rough = 0.42; panel = 0.25; weather = 0.6;
	} else if (cls == 9 || cls == 13) {
		metal = 0.0; rough = 0.95; panel = 0.0; weather = 0.0;
		base *= mix(0.8, 1.08, wt.r);
		if (cls == 13) base *= mix(0.75, 1.0, smoothstep(0.0, 0.2, abs(fract(opos.y * 9.0) - 0.5)));
	} else if (cls == 10) {
		metal = 0.0; rough = 0.92; panel = 0.35; weather = 0.0;
		base *= mix(0.84, 1.05, wl.r);   // M3.1: smooth tone (G is plate seams)
	} else if (cls == 11) {
		float rib = 0.5 + 0.5 * sin(opos.x * 75.0);
		base *= mix(0.78, 1.04, rib);
		metal = 0.4; rough = 0.55; panel = 0.3;
		stencil = stencil_amount * 0.6;
	} else if (cls == 12) {
		metal = 0.0; rough = 0.9; panel = 0.0; weather = 0.3;
		base *= mix(0.75, 1.1, fract(sin(floor(opos.x * 14.0 + opos.z * 14.0) * 91.7) * 4375.5) * 0.5 + wt.r * 0.5);
	} else if (cls == 14) {
		metal = 0.1; rough = 0.95; panel = 0.0; weather = 0.0;
		base = vec3(0.03, 0.028, 0.026) * mix(0.6, 1.4, wl.r);
	} else if (cls == 16) {
		metal = 0.0; rough = 1.0; panel = 0.0; weather = 0.0;
	} else if (cls == 17) {
		metal = 0.45; rough = 0.7; panel = 0.5; weather = 1.6;
	} else {
		stencil = stencil_amount * 0.5;
	}
	vec3 col = base;
	float side = 1.0 - abs(onrm.y);
	bool baked = bake_s.w > 0.0 && cls != 2 && cls != 5 && cls != 7 && cls != 8 && cls != 15 && cls != 18 && cls != 19;
	vec3 bk = baked ? bake_sample(opos, onrm) : vec3(1.0, 0.5, 0.0);
	float proc = baked ? 0.45 : 1.0;   // procedural grime / dirt is toned down where the bake has it
	col *= mix(1.0, wt.g, 0.42 * panel);   // M3.1: thin irregular seams, softer
	float grime = (1.0 - wl.r) * (0.22 + 0.16 * side) * proc;
	col *= 1.0 - grime * dirt_amt;
	if (hi && weather > 0.0) {
		float chip = smoothstep(0.5, 0.8, max(wt.b, wl.b)) * wear_amt * weather;
		col = mix(col, vec3(0.42, 0.41, 0.39), clamp(chip, 0.0, 1.0) * 0.75);
		metal = mix(metal, 0.7, chip);
		rough = mix(rough, 0.45, chip);
	}
	float ra = clamp(rust_amt * weather, 0.0, 1.0);
	float rsrc = wl.a * 0.6 + (1.0 - wl.r) * 0.6;
	float rmask = clamp(smoothstep(1.0 - ra, 1.12 - ra, rsrc), 0.0, 1.0) * step(0.01, weather);
	vec3 rc = tri(rust_tex, opos * 1.3, onrm, 0.7, bias).rgb;
	col = mix(col, rc * vec3(1.05, 0.9, 0.8), rmask * 0.9);
	rough = mix(rough, 0.9, rmask);
	metal = mix(metal, 0.1, rmask);
	float dirt = (1.0 - smoothstep(0.05, 0.4 + wl.r * 0.2, opos.y)) * dirt_amt * side;
	dirt += dirt_amt * 0.18 * (1.0 - side) * smoothstep(0.4, 0.8, wl.r);
	col = mix(col, vec3(0.5, 0.42, 0.31), clamp(dirt * proc, 0.0, 1.0) * 0.7);
	rough = mix(rough, 0.95, dirt * proc);
	if (baked) {
		float bs = bake_s.w;
		float curv = bk.g * 2.0 - 1.0;
		float mark = smoothstep(0.79, 0.86, bk.b);
		float gr = clamp(bk.b / 0.75, 0.0, 1.0) * (1.0 - mark);
		// faction marking: stencilled cream paint, chipped with the plate wear
		float mchip = smoothstep(0.55, 0.85, max(wt.b, wl.b)) * wear_amt;
		col = mix(col, vec3(0.74, 0.72, 0.64) * mix(0.85, 1.0, wt.r), mark * (1.0 - mchip) * 0.92 * bs * (1.0 - rmask));
		// grime: mud / dust low down, darker soot-grime higher up
		float hy = clamp((opos.y - bake_o.y) / bake_s.y, 0.0, 1.0);
		vec3 gcol = mix(vec3(0.42, 0.35, 0.25), vec3(0.17, 0.15, 0.13), smoothstep(0.2, 0.7, hy));
		col = mix(col, gcol, gr * (0.25 + 0.3 * dirt_amt) * bs);
		rough = mix(rough, 0.95, gr * 0.6 * bs);
		// convex edges: worn paint to bare metal on painted parts, lighter edges elsewhere
		float edge = max(curv, 0.0);
		if (weather > 0.0 && (cls == 0 || cls == 1 || cls == 20 || cls == 6 || cls == 17)) {
			float ew = smoothstep(0.15, 0.6, edge) * (0.45 + 0.55 * wear_amt) * bs * (1.0 - damage_amt);
			col = mix(col, vec3(0.52, 0.5, 0.47), ew * 0.55);
			metal = mix(metal, 0.75, ew * 0.6);
			rough = mix(rough, 0.4, ew * 0.6);
		}
		col *= 1.0 + 0.22 * edge * bs;
		col *= 1.0 + 0.55 * min(curv, 0.0) * bs;      // creases + panel seams
		col *= mix(1.0, bk.r, 0.9 * bs);               // baked AO
	}
	if (hi && stencil > 0.0) {
		vec2 suv = (abs(onrm.x) > abs(onrm.z) ? opos.zy : opos.xy) * 0.75 + vec2(0.13, 0.6);
		vec4 s = texture(stencil_tex, suv);
		float cellmask = step(0.55, fract(sin(dot(floor(suv), vec2(12.9898, 78.233))) * 43758.5453));
		col = mix(col, s.rgb * 0.92, s.a * side * cellmask * stencil * (1.0 - rmask));
	}
	// ---- M2.6 surface detail (Zero Hour-style crispness at RTS distance) ----
	float side2 = 1.0 - abs(onrm.y);
	if (hi && cls != 2 && cls != 5 && cls != 15 && cls != 19) {
		// vertical rain / grime streaks running down walls and hull sides
		float sk = texture(weather_tex, vec2((opos.x + opos.z) * 2.3, opos.y * 0.22), bias).r;
		float streak = smoothstep(0.45, 0.85, sk) * side2 * (cls == 10 || cls == 11 ? 0.32 : 0.2);
		col *= 1.0 - streak * dirt_amt;
		// micro roughness breakup (M3.1: the fwidth edge-wear term is gone: it drew blocky
		// 2x2-pixel quads on mobile GPUs; chipping now follows the plate bevels in weather.png B)
		rough = clamp(rough + (wt.r - 0.5) * 0.12, 0.05, 1.0);
	}
	// contact shadow / cavity near the ground plane (reads like baked AO)
	col *= mix(0.62, 1.0, smoothstep(0.0, 0.14, opos.y));
	// ---- M2.7b form readability (Zero Hour-like hard modelling at RTS range) ----
	if (cls != 5 && cls != 15 && cls != 19) {
		col *= mix(0.48, 1.0, smoothstep(-0.7, 0.15, onrm.y));      // dark undersides
		col *= mix(0.84, 1.2, smoothstep(0.25, 0.9, onrm.y));      // sun-catching tops vs walls
		float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		col *= 1.0 + 0.3 * rim * rim * rim;                         // silhouette lift
		if (hi) {
			// M3.2 hand-painted edge highlight on plate bevels (weather.png B ring), sun side
			float bev = smoothstep(0.56, 0.7, wt.b) * (1.0 - smoothstep(0.74, 0.86, wt.b));
			col *= 1.0 + bev * (0.16 + 0.14 * max(onrm.y, 0.0)) * (1.0 - damage_amt);
		}
	}
	if (hi && cls != 2 && cls != 5 && cls != 15 && cls != 19) {
		// M3.1 detail normals: plate seams / rivets / hatches where there are panels, fine grain
		// everywhere else; Ultra adds a second, larger octave so the pattern never reads as a tile
		float k = 0.22 + panel * 0.5;
		vec3 nd = tri_n(opos + vec3(0.37, 0.0, 0.11), onrm, 1.0, k, bias);
		if (fl_tex_quality > 1.5)
			nd = normalize(nd + tri_n(opos * 0.8 + vec3(0.71, 0.3, 0.2), onrm, 0.45, 0.5, bias) - onrm);
		vec3 dv = (VIEW_MATRIX * (MODEL_MATRIX * vec4(nd - onrm, 0.0))).xyz;
		NORMAL = normalize(NORMAL + dv / max(length((MODEL_MATRIX * vec4(onrm, 0.0)).xyz), 1e-3));
	}
	if (damage_amt > 0.0) {
		// soot + scorch blotches grow with damage; burnt-out = nearly all char, embers in cracks
		float n = wl.r * 0.6 + wt.r * 0.4;
		float soot = smoothstep(1.0 - damage_amt * 1.1, 1.05 - damage_amt * 0.9, n);
		col = mix(col, vec3(0.035, 0.032, 0.03), soot * 0.92);
		rough = mix(rough, 0.97, soot);
		metal = mix(metal, 0.05, soot);
		emit = mix(emit, vec3(0.0), soot);
		float ember = smoothstep(0.75, 1.0, damage_amt) * smoothstep(0.62, 0.7, wt.b) * soot;
		emit += vec3(1.4, 0.35, 0.05) * ember;
	}
#ifdef REVEAL
	float edge = 1.0 - smoothstep(0.0, 0.035, reveal_y - opos.y);
	emit += reveal_edge.rgb * reveal_edge.a * edge;
#endif
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
}
