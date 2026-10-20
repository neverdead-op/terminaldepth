shader_type spatial;
render_mode specular_schlick_ggx;

// Пол деревни одним куском: до шести покрытий смешиваются по «карте смешивания» (splat).
// Граница между покрытиями рвётся шумом и учитывает рисунок: трава сначала заходит в щели между камнями.

uniform sampler2D layer0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Размер повтора каждого покрытия в метрах.
uniform float tiles[6];
// Мокрый блеск и рельеф швов по покрытиям (0..1).
uniform float wet[6];
uniform float relief[6];
// Веса покрытий 0–3 в RGBA и 4–5 в RG; по пикселю на клетку 2×2 м.
uniform sampler2D splat_a : filter_linear, repeat_disable;
uniform sampler2D splat_b : filter_linear, repeat_disable;
// Где лежит карта смешивания: xy — угол (x, z), zw — размер в метрах.
uniform vec4 splat_rect;
// Насколько рвётся граница (0 — ровная плавная, 1 — сильно рваная).
uniform float edge_noise : hint_range(0.0, 1.5) = 0.7;
// Влияние рисунка на границу: больше — трава и листва сначала лезут в тёмные щели.
uniform float height_blend : hint_range(0.0, 1.0) = 0.35;
// Ширина мягкой зоны после рваного края.
uniform float edge_softness : hint_range(0.01, 0.5) = 0.12;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return value_noise(p) * 0.55 + value_noise(p * 2.3 + 17.0) * 0.3 + value_noise(p * 5.1 + 41.0) * 0.15;
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sample_layer(int i, vec2 xz) {
	vec2 uv = xz / tiles[i];
	if (i == 0) return texture(layer0, uv).rgb;
	if (i == 1) return texture(layer1, uv).rgb;
	if (i == 2) return texture(layer2, uv).rgb;
	if (i == 3) return texture(layer3, uv).rgb;
	if (i == 4) return texture(layer4, uv).rgb;
	return texture(layer5, uv).rgb;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = world_position.xz;
	vec2 suv = (xz - splat_rect.xy) / splat_rect.zw;
	vec4 wa = texture(splat_a, suv);
	vec2 wb = texture(splat_b, suv).rg;
	float w[6] = float[6](wa.r, wa.g, wa.b, wa.a, wb.r, wb.g);
	vec3 colors[6];
	float score[6];
	float best = -10.0;
	for (int i = 0; i < 6; i++) {
		colors[i] = vec3(0.0);
		score[i] = -10.0;
		if (w[i] < 0.002) continue;
		colors[i] = sample_layer(i, xz);
		// Свой шум у каждого покрытия: края пятнистые, а не по линейке.
		float n = fbm(xz * 0.45 + float(i) * 13.7) - 0.5;
		score[i] = w[i] + n * edge_noise * w[i] * (1.0 - w[i]) * 4.0 + lum(colors[i]) * height_blend;
		best = max(best, score[i]);
	}
	vec3 color = vec3(0.0);
	float total = 0.0;
	float wet_sum = 0.0;
	float relief_sum = 0.0;
	float weights[6];
	for (int i = 0; i < 6; i++) {
		weights[i] = max(score[i] - best + edge_softness, 0.0);
		total += weights[i];
	}
	if (total <= 0.0) {
		weights[2] = 1.0;
		colors[2] = sample_layer(2, xz);
		total = 1.0;
	}
	for (int i = 0; i < 6; i++) {
		float k = weights[i] / total;
		color += colors[i] * k;
		wet_sum += wet[i] * k;
		relief_sum += relief[i] * k;
	}
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
