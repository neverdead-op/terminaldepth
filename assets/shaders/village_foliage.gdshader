shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D leaf_map : source_color, filter_linear_mipmap_anisotropic;
uniform float wind_strength : hint_range(0.0, 0.2) = 0.045;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * 1.1 + dot(world.xz, vec2(0.7, 0.4));
	VERTEX.x += sin(phase) * wind_strength;
	VERTEX.z += cos(phase * 0.8) * wind_strength * 0.5;
}
void fragment() {
	vec4 leaf = texture(leaf_map, UV);
	ALBEDO = leaf.rgb * vec3(0.78, 0.72, 0.66);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.95;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
