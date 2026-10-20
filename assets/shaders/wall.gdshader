shader_type spatial;
// Стена: вертикальные панели со швами, тёмный цоколь снизу, светящаяся полоса поверху.
// Высота стены — wall_height (низ стены — на уровне пола y = 0).

uniform vec4 base_color : source_color = vec4(0.22, 0.23, 0.26, 1.0);
uniform vec4 seam_color : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform vec4 trim_color : source_color = vec4(0.25, 0.7, 1.0, 1.0);
uniform float trim_energy = 1.4;
uniform float panel_width = 2.0;
uniform float wall_height = 2.4;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Вдоль стены идём по той горизонтальной оси, которая лежит в плоскости грани.
	float along = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	float u = along / panel_width;
	float panel = floor(u);
	float fu = fract(u);
	float h = world_pos.y / wall_height;
	float seam = 1.0 - smoothstep(0.012, 0.025, min(fu, 1.0 - fu));
	vec3 col = base_color.rgb * (1.0 + (hash(panel) - 0.5) * 0.15);
	// Цоколь и горизонтальный шов посередине.
	col = mix(col, seam_color.rgb * 1.3, step(h, 0.12));
	seam = max(seam, 1.0 - smoothstep(0.006, 0.014, abs(h - 0.55)));
	col = mix(col, seam_color.rgb, seam);
	float trim = step(0.9, h) * step(h, 0.94);
	ALBEDO = mix(col, trim_color.rgb, trim);
	EMISSION = trim_color.rgb * trim_energy * trim;
	METALLIC = 0.35;
	ROUGHNESS = 0.7;
}
