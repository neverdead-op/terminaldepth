shader_type spatial;
// Пол из металлических панелей: швы, свой оттенок у каждой панели, грязь и потёртости.
// Узор считается по мировым координатам — панели ровно стыкуются на любых кусках пола.

uniform vec4 base_color : source_color = vec4(0.16, 0.16, 0.18, 1.0);
uniform vec4 seam_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 grime_color : source_color = vec4(0.09, 0.08, 0.07, 1.0);
uniform float panel_size = 2.0;
uniform float seam_width = 0.035;
uniform float grime_amount = 0.55;
// Металличность: высокая делает пол тёмным (металл почти не рассеивает свет ламп).
uniform float metallic = 0.25;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / panel_size;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = 1.0 - smoothstep(seam_width * 0.5, seam_width, edge);
	float tint = (hash(cell) - 0.5) * 0.12;
	vec3 col = base_color.rgb * (1.0 + tint);
	// Крупная грязь и мелкие потёртости.
	float g = noise(world_pos.xz * 0.35) * 0.6 + noise(world_pos.xz * 1.7) * 0.4;
	col = mix(col, grime_color.rgb, smoothstep(0.45, 0.85, g) * grime_amount);
	// Болты в углах панелей.
	float bolt = 1.0 - smoothstep(0.03, 0.05, length(abs(f - 0.5) - vec2(0.42)));
	col = mix(col, seam_color.rgb * 1.6, bolt * 0.7);
	col = mix(col, seam_color.rgb, seam);
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = mix(0.45, 0.85, g) + seam * 0.1;
}
