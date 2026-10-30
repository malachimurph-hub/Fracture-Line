shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Vertex-coloured props (trees, rocks, poles, wrecks, civilian buildings) with optional
// triplanar texture detail, per-instance tint, palm-frond sway and fog of war.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_amount = 0.0;
// M3.0: alpha-cut foliage cards (vertex alpha ~0.75) sample this atlas; vertex alpha < 0.5 marks
// emissive parts (lit windows < 0.15 steady, 0.15..0.5 blinking aviation lights)
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform float sway = 0.0;
uniform vec2 map_size = vec2(128.0, 128.0);
// M3.4: the models' sky fill (see model_m3.gdshaderinc) on the solid props - civilian
// buildings, walls, trunks, rocks - so a city block reads by moonlight
global uniform vec4 fl_fill;
// M2.9 tall towers: dither out the parts that stand between the camera and a unit
uniform int occl_n = 0;
uniform vec4 occl_pts[24];
varying vec3 wpos;
varying vec3 vcol;
varying vec3 wn;
varying float vkind;
varying float vphase;
void vertex() {
	vkind = COLOR.a;
	vphase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.61;
	vcol = pow(COLOR.rgb, vec3(2.2)); // MultiMesh instance colour is already multiplied in
	if (sway > 0.0) {
		float k = max(0.0, VERTEX.y - 1.0) * sway;
		float ph = MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.4;
		VERTEX.x += sin(TIME * 1.3 + ph) * k * 0.05;
		VERTEX.z += cos(TIME * 1.1 + ph) * k * 0.04;
	}
	// M3.3: leaf cards flutter on top of the slow trunk sway (cheap: a few sines per vertex)
	if (sway > 0.0 && COLOR.a > 0.6 && COLOR.a < 0.9) {
		float lp = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 1.3 + VERTEX.x * 3.1 + VERTEX.z * 2.7;
		float lk = min(1.0, VERTEX.y * 0.5) * sway;
		VERTEX.y += sin(TIME * 2.6 + lp) * 0.025 * lk;
		VERTEX.x += sin(TIME * 2.1 + lp * 1.3) * 0.02 * lk;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	if (occl_n > 0 && wpos.y > 0.35) {
		vec3 C = CAMERA_POSITION_WORLD;
		float hide = 0.0;
		for (int i = 0; i < occl_n; i++) {
			vec3 v = occl_pts[i].xyz - C;
			float t = dot(wpos - C, v) / dot(v, v);
			if (t > 0.0 && t < 0.96) {
				float d = length(C + v * t - wpos);
				hide = max(hide, smoothstep(2.4, 1.3, d));
			}
		}
		// ordered dither keeps the opaque pipeline (no sorting); ~75 % of the pixels go
		vec2 q = mod(floor(FRAGCOORD.xy), 2.0);
		float th = (q.x * 2.0 + q.y + 1.0) * 0.2;
		if (hide * 0.8 > th) discard;
	}
	vec3 c = vcol;
	if (vkind > 0.6 && vkind < 0.9) {
		vec4 lt = texture(leaf_tex, UV);
		if (lt.a < 0.45) discard;
		c *= lt.rgb * 1.15;
	}
	if (detail_amount > 0.0) {
		vec3 bw = pow(abs(wn), vec3(4.0)); bw /= (bw.x + bw.y + bw.z);
		vec3 d = texture(detail, wpos.zy * 0.5).rgb * bw.x + texture(detail, wpos.xz * 0.5).rgb * bw.y + texture(detail, wpos.xy * 0.5).rgb * bw.z;
		c *= mix(vec3(1.0), d * 1.6, detail_amount);
	}
	float f = texture(fog_tex, wpos.xz / map_size).r;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	vec3 grey = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	ALBEDO = mix(vec3(0.0), mix(mix(grey, c, 0.45) * 0.5, c, vis), expl);
	if (vkind > 0.9)
		EMISSION = ALBEDO * fl_fill.rgb * (0.7 + 0.3 * clamp(wn.y, -1.0, 1.0));
	if (vkind < 0.5) {
		float on = vkind < 0.15 ? 1.0 : step(0.55, fract(TIME * 0.7 + vphase));
		EMISSION = c * (vkind < 0.15 ? 0.55 : 2.6) * on * mix(0.25, 1.0, vis) * expl;
	}
	if (vkind > 0.6 && vkind < 0.9) {
		BACKLIGHT = c * 0.55;   // M3.3: sunlight shows through the leaves
	}
	ROUGHNESS = 0.85;
}
