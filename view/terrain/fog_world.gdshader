shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Shared by terrain and environment props: samples the 1-pixel-per-tile fog texture
// (0 = shroud, 0.5 = explored/fogged, 1 = visible) with bilinear blur (GDD 17.5).
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(128.0, 128.0);
uniform float use_instance_color = 0.0;
varying vec3 wpos;
varying vec3 vcol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR.rgb;
}

void fragment() {
	vec2 uv = wpos.xz / map_size;
	float f = texture(fog_tex, uv).r;
	vec3 c = vcol;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	vec3 grey = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	vec3 fogged = mix(grey, c, 0.4) * 0.5;
	ALBEDO = mix(vec3(0.0), mix(fogged, c, vis), expl);
	ROUGHNESS = 0.95;
}
