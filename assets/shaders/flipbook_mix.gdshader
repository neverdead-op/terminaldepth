shader_type spatial;
// Покадровая анимация из листа-сетки (flipbook). Кадр, цвет, поворот — свои у каждого экземпляра.
// billboard — квад повёрнут к камере; иначе лежит как есть (например, кольцо на полу).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(8.0, 8.0);
uniform bool billboard = true;
instance uniform float frame = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float spin = 0.0;
// 1 — перекрасить картинку в tint по яркости (кровь любого цвета из красного листа).
instance uniform float colorize = 0.0;

void vertex() {
	float c = cos(spin), s = sin(spin);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
	}
	float total = grid.x * grid.y;
	float f = clamp(floor(frame), 0.0, total - 1.0);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	UV = (UV + cell) / grid;
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec3 rgb = c.rgb * tint.rgb;
	if (colorize > 0.5) {
		float lum = max(max(c.r, c.g), c.b);
		rgb = tint.rgb * lum * 1.3;
	}
	ALBEDO = rgb;
	ALPHA = c.a * tint.a;
}
