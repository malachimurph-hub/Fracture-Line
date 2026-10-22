shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Construction variant: clips above reveal_y with a glowing build edge. Swapped in only while a
// structure is being built (discard is costly on tile GPUs).
#define REVEAL
#include "res://view/materials/model_m3.gdshaderinc"
