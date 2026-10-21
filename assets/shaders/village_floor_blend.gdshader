shader_type spatial;
render_mode specular_schlick_ggx;
#include "res://assets/shaders/village_floor_sampling.gdshaderinc"
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 xz = world_position.xz;
	float relief_sum;
	vec4 ground = ground_sample(xz, relief_sum);
	vec3 color = ground.rgb;
	float wet_sum = ground.a;
	// Мягкий рельеф швов по яркости итогового рисунка.
	float h = smoothstep(0.025, 0.13, lum(color));
	vec3 world_up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (dot(NORMAL, world_up_view) > 0.7) {
		NORMAL = normalize((VIEW_MATRIX * vec4(-dFdx(h) * relief_sum * 3.0, 1.0, -dFdy(h) * relief_sum * 3.0, 0.0)).xyz);
	}
	float patches = sin(xz.x * 0.71 + sin(xz.y * 0.42)) * sin(xz.y * 0.83 - xz.x * 0.31);
	float damp = smoothstep(0.05, 0.65, patches) * wet_sum;
	ALBEDO = color * mix(1.0, 0.82, damp);
	ROUGHNESS = mix(0.88, 0.3, damp);
	METALLIC = 0.0;
}
