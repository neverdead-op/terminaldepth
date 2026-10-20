shader_type spatial;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool has_texture = true;
uniform float metalness = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.25;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 base = tint.rgb;
	if (has_texture) base *= texture(base_map, UV).rgb;
	float patches = sin(world_pos.x * 1.3 + sin(world_pos.z * 0.8)) * sin(world_pos.y * 1.1 + world_pos.z * 0.7);
	float damp = smoothstep(-0.2, 0.7, patches) * wetness;
	ALBEDO = base * mix(1.0, 0.86, damp);
	ROUGHNESS = mix(0.86 - metalness * 0.25, 0.30, damp);
	METALLIC = metalness;
}
