shader_type spatial;
uniform vec4 amber : source_color = vec4(1.0, 0.58, 0.19, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float phase = dot(world_pos.xz, vec2(0.31, 0.17));
	float pulse = 1.25 + sin(TIME * 2.1 + phase) * 0.045 + sin(TIME * 3.7 + phase * 2.0) * 0.022;
	ALBEDO = amber.rgb * 0.25;
	EMISSION = amber.rgb * pulse;
	ROUGHNESS = 0.35;
}
