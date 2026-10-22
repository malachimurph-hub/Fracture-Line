shader_type spatial;
// Static ground decals (M2): tire tracks, cracks, oil stains, sand drifts, rubble from a
// procedural 4x4 atlas (original). MultiMesh quads; INSTANCE_CUSTOM.x = atlas cell,
// .y = opacity. Fog of war applied like the terrain.
render_mode cull_disabled, depth_draw_never, shadows_disabled, diffuse_burley;
global uniform float fl_tex_quality;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(128.0, 128.0);
varying vec2 cell;
varying float opac;
varying vec3 wpos;
void vertex() {
	float c = floor(INSTANCE_CUSTOM.x + 0.5);
	cell = vec2(mod(c, 4.0), floor(c / 4.0));
	opac = INSTANCE_CUSTOM.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = (cell + clamp(UV, vec2(0.01), vec2(0.99))) * 0.25;
	vec4 t = texture(atlas, uv, fl_tex_quality > 0.5 ? 0.0 : 1.0);
	float f = texture(fog_tex, wpos.xz / map_size).r;
	float vis = smoothstep(0.55, 0.95, f);
	float expl = smoothstep(0.08, 0.42, f);
	ALBEDO = t.rgb * mix(0.5, 1.0, vis) * expl;
	ALPHA = t.a * opac;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
