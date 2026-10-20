shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;

uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 effect_color : source_color = vec4(1.0, 0.06, 0.025, 1.0);
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float activation : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sprite_tint : source_color = vec4(0.8, 0.8, 0.8, 1.0);

void fragment() {
	vec4 tex = texture(source_texture, UV);
	// Маска красного выделяет кристалл и сохраняет серый камень без свечения.
	float red = tex.r - max(tex.g, tex.b);
	float crystal = smoothstep(0.035, 0.20, red) * smoothstep(0.06, 0.18, tex.r);
	float pulse = 0.55 + 0.45 * sin(effect_time * 2.1);
	float veins = 0.8 + 0.2 * sin(UV.y * 95.0 - effect_time * 2.5 + sin(UV.x * 40.0));
	ALBEDO = tex.rgb * sprite_tint.rgb;
	EMISSION = effect_color.rgb * crystal * (pulse * veins * activation * intensity * 2.5 + flash * 5.0);
	ALPHA = tex.a * sprite_tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.25;
}
