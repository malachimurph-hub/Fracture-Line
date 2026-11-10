shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The review field uses the game's winter ground array (the snow layer),
// mipmapped and anisotropic, with no normal map. The custom 2048 maps read
// as dark mud and a fine ripple, which is not this scene's job.
uniform sampler2DArray t_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Same planar scale the terrain shader uses for the grass / snow layer.
	vec3 c = texture(t_albedo, vec3(p * 0.30, 2.0)).rgb;
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
