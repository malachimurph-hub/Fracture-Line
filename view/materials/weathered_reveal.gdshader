shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Construction variant (M2.4): clips above reveal_wy (world space) with a build edge. Swapped in
// only while a structure is being built (discard is costly on tile GPUs).
#define REVEAL
#include "res://view/materials/weathered.gdshaderinc"
