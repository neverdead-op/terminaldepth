shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 ground_world;
void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	float bend = VERTEX.y*VERTEX.y;
	VERTEX.x += sin(TIME*1.5+ground_world.x*.7+ground_world.z*.4)*bend*.23;
}
void fragment() {
	// Корни и земля используют одну текстуру в одинаковом мировом масштабе.
	vec3 base = texture(ground_tex,ground_world.xz/6.0).rgb;
	ALBEDO = base*mix(.95,1.6,UV.y)*COLOR.r;
	NORMAL = normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
	EMISSION = ALBEDO*.06;
	ROUGHNESS = .95;
}
