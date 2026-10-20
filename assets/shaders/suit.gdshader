shader_type spatial;
// Боевой костюм поверх голой базовой модели. Разметка частей тела лежит в цвете вершин
// (её считает scripts/suit.gd по исходной позе модели):
//   COLOR.r — голова (1 — оставить кожу и лицо), COLOR.g — высота (0 — пятки, 1 — макушка),
//   COLOR.b — удаление от середины тела по ширине (руки в стороны — ближе к 1), COLOR.a — перед (1) / спина (0).

uniform sampler2D skin_texture : source_color, filter_linear_mipmap;
uniform vec4 suit_color : source_color = vec4(0.13, 0.14, 0.16, 1.0);
uniform vec4 plate_color : source_color = vec4(0.42, 0.45, 0.5, 1.0);
uniform vec4 glove_color : source_color = vec4(0.04, 0.04, 0.045, 1.0);
uniform vec4 accent_color : source_color = vec4(0.15, 0.85, 1.0, 1.0);
uniform float accent_energy = 3.0;
// Оттенок кожи (у заражённых — бледно-зелёный), белый — как есть.
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform bool head_only = false;

float band(float v, float a, float b) {
	return step(a, v) * step(v, b);
}

void fragment() {
	vec3 skin = texture(skin_texture, UV).rgb * skin_tint.rgb;
	float head = COLOR.r;
	// Под одеждой (Outfit) тело не рисуем — остаётся только голова.
	if (head_only && head < 0.5) {
		discard;
	}
	float h = COLOR.g;
	float side = COLOR.b;
	float front = COLOR.a;

	vec3 col = suit_color.rgb;
	float metal = 0.15;
	float rough = 0.75;
	float glow = 0.0;

	// Бронепластины: грудь, наплечники, предплечья, голени, наколенники.
	float plate = 0.0;
	plate = max(plate, band(h, 0.66, 0.81) * band(side, 0.0, 0.12) * step(0.45, front));
	plate = max(plate, band(h, 0.77, 0.85) * band(side, 0.12, 0.27));
	plate = max(plate, band(side, 0.44, 0.62));
	plate = max(plate, band(h, 0.08, 0.26) * step(0.5, front));
	plate = max(plate, band(h, 0.27, 0.31));
	col = mix(col, plate_color.rgb, plate);
	metal = mix(metal, 0.65, plate);
	rough = mix(rough, 0.4, plate);

	// Пояс, перчатки, ботинки.
	float belt = band(h, 0.53, 0.565) * band(side, 0.0, 0.13);
	col = mix(col, glove_color.rgb, belt);
	float gloves = step(0.68, side);
	float boots = band(h, -0.1, 0.075);
	col = mix(col, glove_color.rgb, max(gloves, boots));
	rough = mix(rough, 0.55, max(gloves, boots));

	// Светящиеся вставки: полоса на груди, пряжка, полоски на предплечьях и голенях.
	glow = max(glow, band(h, 0.742, 0.752) * band(side, 0.0, 0.11) * step(0.5, front));
	glow = max(glow, band(h, 0.537, 0.558) * band(side, 0.0, 0.025) * step(0.5, front));
	glow = max(glow, band(side, 0.52, 0.535));
	glow = max(glow, band(h, 0.17, 0.18) * step(0.5, front));

	ALBEDO = mix(col, skin, head);
	METALLIC = mix(metal, 0.0, head);
	ROUGHNESS = mix(rough, 0.55, head);
	EMISSION = accent_color.rgb * accent_energy * glow * (1.0 - head);
}
