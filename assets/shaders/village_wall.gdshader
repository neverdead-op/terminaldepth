shader_type spatial;
render_mode specular_schlick_ggx;

// Кладка стен деревни: текстура по метрам мира (без швов между кусками),
// мох пятнами — гуще у земли и на гребне, тёмные потёки у основания.

uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.85, 0.85, 0.88, 1.0);
uniform float tile_meters = 3.0;
uniform float moss_tile_meters = 2.5;
// Сколько мха: 0 — нет, 1 — много.
uniform float moss_amount : hint_range(0.0, 1.0) = 0.55;
// Тёмные потёки и грязь у основания.
uniform float grime : hint_range(0.0, 1.0) = 0.5;

varying vec3 wpos;
varying vec3 wnormal;

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
	return value_noise(p) * 0.55 + value_noise(p * 2.2 + 7.0) * 0.3 + value_noise(p * 4.7 + 19.0) * 0.15;
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = triplanar(base_tex, wpos / tile_meters, wnormal);
	vec3 moss = triplanar(moss_tex, wpos / moss_tile_meters, wnormal);
	float h = wpos.y;
	float patches = fbm(wpos.xz * 0.35 + vec2(wpos.y * 0.6, 0.0));
	// Мох: внизу (сырость), на верхних гранях и случайными пятнами по стене.
	float wet_bottom = 1.0 - smoothstep(0.0, 1.3, h);
	float on_top = smoothstep(0.4, 0.8, wnormal.y);
	float mask = smoothstep(0.62, 0.78, patches + wet_bottom * 0.3 + on_top * 0.35) * moss_amount;
	vec3 color = mix(base, moss * 0.85, mask);
	// Потёки: тёмные вертикальные полосы, сильнее у земли.
	float streak = value_noise(vec2(wpos.x * 3.1 + wpos.z * 3.1, h * 0.35));
	float dirt = (1.0 - smoothstep(0.0, 0.9, h)) * 0.55 + smoothstep(0.6, 0.9, streak) * (1.0 - smoothstep(0.5, 2.6, h)) * 0.35;
	color *= 1.0 - dirt * grime;
	ALBEDO = color * tint.rgb;
	ROUGHNESS = mix(0.92, 0.8, mask);
	METALLIC = 0.0;
}
