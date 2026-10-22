// FRACTURE LINE M2.2 model surface ("m3" kit): ONE material per mesh, the part's look chosen by
// a class id in vertex alpha (COLOR.a * 20). This keeps a vehicle at 1 draw per moving node
// (hull, turret, barrel) instead of one per material. Classes:
//  0 painted metal   1 team paint      2 glass           3 rubber          4 track (scrolls)
//  5 lamp (emissive) 6 bare steel      7 wheel rubber*   8 wheel steel*    9 canvas
// 10 concrete       11 corrugated      12 wood           13 sandbag        14 charred
// 15 team lamp      16 dark interior   17 rusty scrap
// (* spins: UV = axle (y, z), UV2 = (axle x, radius [+10 = steers]))
// Weathering (object-space triplanar, so it sticks to moving parts) as the M2 shader: panel
// lines, chipped paint, rust, grime, ground dirt, stencils, plus damage soot / scorch.
global uniform float fl_tex_quality;
uniform sampler2D weather_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rust_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D stencil_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform float stencil_amount = 0.6;
instance uniform vec4 team_color : source_color = vec4(0.18, 0.5, 0.88, 1.0);
instance uniform float rust_amt = 0.15;
instance uniform float wear_amt = 0.5;
instance uniform float dirt_amt = 0.6;
instance uniform float wheel_dist = 0.0;   // distance travelled (world units): wheels + tracks
instance uniform float steer = 0.0;        // radians, wheels flagged as steering
instance uniform float damage_amt = 0.0;   // 0 pristine .. 1 burnt-out
#ifdef REVEAL
instance uniform float reveal_y = 10.0;    // construction: object-space height built so far
#endif
varying vec3 opos;
varying vec3 onrm;
varying flat int cls;

vec4 tri(sampler2D t, vec3 p, vec3 n, float s, float bias) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-4);
	return texture(t, p.zy * s, bias) * w.x + texture(t, p.xz * s, bias) * w.y + texture(t, p.xy * s, bias) * w.z;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	cls = int(COLOR.a * 20.0 + 0.5);
	opos = VERTEX;
	onrm = NORMAL;
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
	vec4 wt = tri(weather_tex, opos + vec3(0.37, 0.0, 0.11), onrm, 1.6, bias);   // panels, scratches
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
	} else if (cls == 6 || cls == 8) {
		metal = 0.75; rough = 0.42; panel = 0.25; weather = 0.6;
	} else if (cls == 9 || cls == 13) {
		metal = 0.0; rough = 0.95; panel = 0.0; weather = 0.0;
		base *= mix(0.8, 1.08, wt.r);
		if (cls == 13) base *= mix(0.75, 1.0, smoothstep(0.0, 0.2, abs(fract(opos.y * 9.0) - 0.5)));
	} else if (cls == 10) {
		metal = 0.0; rough = 0.92; panel = 0.35; weather = 0.0;
		base *= mix(0.82, 1.06, wl.g);
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
	col *= mix(1.0, wt.g, 0.7 * panel);
	float grime = (1.0 - wl.r) * (0.22 + 0.16 * side);
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
	col = mix(col, vec3(0.5, 0.42, 0.31), clamp(dirt, 0.0, 1.0) * 0.7);
	rough = mix(rough, 0.95, dirt);
	if (hi && stencil > 0.0) {
		vec2 suv = (abs(onrm.x) > abs(onrm.z) ? opos.zy : opos.xy) * 0.75 + vec2(0.13, 0.6);
		vec4 s = texture(stencil_tex, suv);
		float cellmask = step(0.55, fract(sin(dot(floor(suv), vec2(12.9898, 78.233))) * 43758.5453));
		col = mix(col, s.rgb * 0.92, s.a * side * cellmask * stencil * (1.0 - rmask));
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
	emit += vec3(1.6, 0.9, 0.35) * edge;
#endif
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
}
