shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, ambient_light_disabled;
// Additive flash / fire. Same instance contract as billboard.gdshader.

uniform sampler2D disc : source_color, filter_linear, repeat_disable;

varying vec4 tint;

void vertex() {
	tint = INSTANCE_CUSTOM;
	float s = length(vec3(MODEL_MATRIX[0].x, MODEL_MATRIX[1].x, MODEL_MATRIX[2].x));
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 right = vec3(VIEW_MATRIX[0][0], VIEW_MATRIX[1][0], VIEW_MATRIX[2][0]);
	vec3 up = vec3(VIEW_MATRIX[0][1], VIEW_MATRIX[1][1], VIEW_MATRIX[2][1]);
	vec2 q = (UV - vec2(0.5)) * s;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(origin + right * q.x + up * q.y, 1.0));
}

void fragment() {
	float a = texture(disc, UV).a * tint.a;
	ALBEDO = tint.rgb * a;
	ALPHA = a;
}
