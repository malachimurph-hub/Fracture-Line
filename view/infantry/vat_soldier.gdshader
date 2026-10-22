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
instance uniform vec4 team_color : source_color = vec4(0.18, 0.5, 0.88, 1.0);
instance uniform float rust_amt = 0.15;
instance uniform float wear_amt = 0.5;
instance uniform float dirt_amt = 0.6;
varying float vy;
varying vec4 pcol;
varying float fade;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	int vid = int(UV2.x + 0.5) + int(UV2.y + 0.5) * 256;
	int fa = int(INSTANCE_CUSTOM.x + 0.5);
	int fb = int(INSTANCE_CUSTOM.y + 0.5);
	ivec2 base = ivec2(vid % vat_w, vid / vat_w);
	vec3 pa = texelFetch(vat_pos, base + ivec2(0, fa * vat_rows), 0).xyz;
	vec3 pb = texelFetch(vat_pos, base + ivec2(0, fb * vat_rows), 0).xyz;
	vec3 na = texelFetch(vat_nrm, base + ivec2(0, fa * vat_rows), 0).xyz * 2.0 - 1.0;
	vec3 nb = texelFetch(vat_nrm, base + ivec2(0, fb * vat_rows), 0).xyz * 2.0 - 1.0;
	VERTEX = mix(pa, pb, INSTANCE_CUSTOM.z);
	NORMAL = normalize(mix(na, nb, INSTANCE_CUSTOM.z));
	vy = VERTEX.y;
	// M2.6: part colour packed in UV (x = R*256 + G, y = B + 1000*team); COLOR is unreliable on
	// MultiMesh without per-instance colours in the compatibility renderer (soldiers drew black).
	float team_f = step(500.0, UV.y);
	float rr = floor(UV.x / 256.0 + 0.001);
	pcol = vec4(rr, UV.x - rr * 256.0, UV.y - 1000.0 * team_f, 255.0 * team_f) / 255.0;
	fade = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec3 base = srgb_to_linear(pcol.rgb);
	vec3 team = team_color.rgb * (0.55 + 0.45 * dot(base, vec3(0.3, 0.59, 0.11)) / 0.6);
	vec3 col = mix(base, team, pcol.a);
	// M2.6 fabric / gear detail: object-space weave + seam darkening so uniforms are not flat
	float weave = 0.5 + 0.5 * sin(vy * 220.0) * sin(vy * 37.0 + 1.7);
	col *= mix(0.93, 1.04, weave);
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
