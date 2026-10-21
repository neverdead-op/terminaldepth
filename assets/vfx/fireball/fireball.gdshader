shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D fire_texture : source_color, filter_linear;
uniform float screen_rotation = 0.0;

void vertex() {
	float c = cos(screen_rotation);
	float s = sin(screen_rotation);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 fire = texture(fire_texture, UV);
	ALBEDO = fire.rgb;
	ALPHA = fire.a;
}
