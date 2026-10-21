shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D fire_texture : source_color, filter_linear;
uniform float screen_rotation = 0.0;
uniform float animation_frame = 0.0;

void vertex() {
	float c = cos(screen_rotation);
	float s = sin(screen_rotation);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 grid = vec2(6.0, 4.0);
	vec2 local_uv = UV * grid;
	float frame_a = floor(animation_frame);
	float frame_b = min(frame_a + 1.0, 11.0);
	vec2 cell_a = vec2(mod(frame_a, 6.0), floor(frame_a / 6.0));
	vec2 cell_b = vec2(mod(frame_b, 6.0), floor(frame_b / 6.0));
	vec4 fire = mix(texture(fire_texture, (local_uv + cell_a) / grid),
		texture(fire_texture, (local_uv + cell_b) / grid), fract(animation_frame));
	ALBEDO = fire.rgb;
	ALPHA = fire.a;
}
