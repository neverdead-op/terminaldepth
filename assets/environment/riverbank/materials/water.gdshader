shader_type spatial;
render_mode unshaded, cull_disabled;
// Спокойные графические полосы воды; без зеркальных бликов поверх читаемого боя.
uniform vec4 deep_color : source_color = vec4(0.025, 0.11, 0.14, 1.0);
uniform vec4 light_color : source_color = vec4(0.055, 0.24, 0.27, 1.0);
uniform vec4 foam_color : source_color = vec4(0.28, 0.47, 0.48, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float broad = sin(p.x * 0.37 + p.y * 0.16 + sin(p.y * 0.11) * 2.0 + TIME * 0.13);
	float stroke = sin(p.x * 0.9 + p.y * 1.1 + sin(p.y * 0.31) * 1.7 + TIME * 0.18);
	float broken = smoothstep(0.05, 0.75, sin(p.y * 0.8 - p.x * 0.16));
	float line = smoothstep(0.982, 0.998, stroke) * broken;
	vec3 color = mix(deep_color.rgb, light_color.rgb, broad * 0.18 + 0.45);
	ALBEDO = mix(color, foam_color.rgb, line * 0.18);
}
