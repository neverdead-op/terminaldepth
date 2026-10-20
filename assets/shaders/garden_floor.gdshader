shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_meters : hint_range(1.0, 20.0) = 6.0;
uniform float relief_strength : hint_range(0.0, 1.0) = 0.0;
uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;
varying vec3 world_position;

float slab_height(vec2 uv) {
	vec3 c = texture(albedo_map, uv).rgb;
	return smoothstep(0.025, 0.13, dot(c, vec3(0.2126, 0.7152, 0.0722)));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Continuous world projection: adjoining route rectangles share one pattern.
	vec2 uv = world_position.xz / tile_meters;
	vec3 color = texture(albedo_map, uv).rgb;
	// Shallow relief at the painted joints; no invented glowing seams or displacement.
	vec2 e = vec2(0.003, 0.0);
	float dx = slab_height(uv + e.xy) - slab_height(uv - e.xy);
	float dz = slab_height(uv + e.yx) - slab_height(uv - e.yx);
	vec3 world_up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (dot(NORMAL, world_up_view) > 0.7) {
		NORMAL = normalize((VIEW_MATRIX * vec4(-dx * relief_strength, 1.0, -dz * relief_strength, 0.0)).xyz);
	}
	float patches = sin(world_position.x * 0.71 + sin(world_position.z * 0.42))
		* sin(world_position.z * 0.83 - world_position.x * 0.31);
	float damp = smoothstep(0.05, 0.65, patches) * wet_amount;
	ALBEDO = color * mix(1.0, 0.82, damp);
	ROUGHNESS = mix(0.88, 0.3, damp);
	METALLIC = 0.0;
}
