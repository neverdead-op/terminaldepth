shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 effect_color : source_color = vec4(0.85, 0.08, 0.04, 1.0);
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float activation : hint_range(0.0, 1.0) = 1.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;

float stroke(float distance_to_line, float width) {
	float aa = max(fwidth(distance_to_line), 0.001);
	return 1.0 - smoothstep(width, width + aa, abs(distance_to_line));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float outer = stroke(r - 0.73, 0.004);
	float inner = stroke(r - 0.62, 0.003);
	float marks = stroke(r - 0.68, 0.025)
		* (1.0 - smoothstep(0.10, 0.20, abs(sin(angle * 18.0 + effect_time * 0.32))));
	float orbit = stroke(r - 0.48, 0.004)
		* smoothstep(-0.15, 0.15, sin(angle * 3.0 - effect_time * 0.55));
	// Шесть коротких лучей вместо плотной светящейся заливки.
	float rays = (1.0 - smoothstep(0.015, 0.045, abs(sin(angle * 3.0 - effect_time * 0.12))))
		* smoothstep(0.23, 0.27, r) * (1.0 - smoothstep(0.58, 0.61, r));
	float center = stroke(r - 0.22, 0.003);
	float breath = 0.78 + 0.22 * sin(effect_time * 1.7);
	float pattern = (outer + inner * 0.65 + marks + orbit + rays * 0.65 + center) * breath * activation;
	float wave = stroke(r - mix(0.12, 0.96, burst), 0.015) * sin(burst * 3.14159265);
	float mask = clamp(pattern + wave * 2.0, 0.0, 2.5) * (1.0 - smoothstep(0.97, 1.0, r));
	ALBEDO = effect_color.rgb * intensity * 2.0;
	ALPHA = clamp(mask * effect_color.a * intensity, 0.0, 1.0);
}
