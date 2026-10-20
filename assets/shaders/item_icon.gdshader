shader_type canvas_item;
render_mode unshaded;
// Старые иконки нарисованы на почти чёрной подложке. Убираем её только при показе в UI.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float brightness = max(c.r, max(c.g, c.b));
	c.a *= smoothstep(0.028, 0.075, brightness);
	COLOR = c;
}
