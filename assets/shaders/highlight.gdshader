shader_type spatial;
// Подсветка-обводка поверх модели (material_overlay): светящийся край по силуэту (френель), пульсирует.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float power = 2.2;
uniform float strength = 1.6;
uniform float pulse_speed = 3.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), power);
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb * strength * pulse;
	ALPHA = rim * color.a;
}
