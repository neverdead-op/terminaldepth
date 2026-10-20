shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 effect_color : source_color = vec4(0.22, 0.18, 0.23, 1.0);
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float activation : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	vec2 drift = vec2(effect_time * 0.09, -effect_time * 0.06);
	float n = noise(p * 5.0 + drift) * 0.65 + noise(p * 11.0 - drift * 1.4) * 0.35;
	float edge = smoothstep(0.25, 0.45, length(p)) * (1.0 - smoothstep(0.65, 0.97, length(p)));
	ALBEDO = effect_color.rgb;
	ALPHA = smoothstep(0.35, 0.78, n) * edge * 0.35 * intensity * activation * effect_color.a;
}
