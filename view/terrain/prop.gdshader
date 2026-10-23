shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Vertex-coloured props (trees, rocks, poles, wrecks, civilian buildings) with optional
// triplanar texture detail, per-instance tint, palm-frond sway and fog of war.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_amount = 0.0;
uniform float sway = 0.0;
uniform vec2 map_size = vec2(128.0, 128.0);
// M2.9 tall towers: dither out the parts that stand between the camera and a unit
uniform int occl_n = 0;
uniform vec4 occl_pts[24];
varying vec3 wpos;
varying vec3 vcol;
varying vec3 wn;
void vertex() {
	vcol = pow(COLOR.rgb, vec3(2.2)); // MultiMesh instance colour is already multiplied in
	if (sway > 0.0) {
		float k = max(0.0, VERTEX.y - 1.0) * sway;
		float ph = MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.4;
		VERTEX.x += sin(TIME * 1.3 + ph) * k * 0.05;
		VERTEX.z += cos(TIME * 1.1 + ph) * k * 0.04;
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
	ROUGHNESS = 0.85;
}
