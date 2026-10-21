shader_type spatial;
render_mode blend_mix, depth_draw_never, specular_schlick_ggx;
#include "res://assets/shaders/village_floor_sampling.gdshaderinc"

uniform float contact_ground_y = 0.0;
uniform float contact_height : hint_range(0.05, 1.0) = 0.2;
uniform float contact_breakup : hint_range(0.0, 0.4) = 0.24;
uniform sampler2D contact_source_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 contact_uv_scale = vec3(1.0);
uniform vec3 contact_uv_offset = vec3(0.0);
uniform bool contact_has_texture = false;
uniform vec3 contact_limits = vec3(-85.0,19.0,60.0);
varying vec3 contact_world;

void vertex() {
	contact_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	if (contact_world.z<contact_limits.x || contact_world.z>contact_limits.y || contact_world.x>contact_limits.z || contact_world.x<(-66.0+sin(contact_world.z*.047)*2.0)) discard;
	float crease = 0.0;
	if (contact_has_texture) crease=1.0-smoothstep(.03,.14,lum(texture(contact_source_tex,UV*contact_uv_scale.xy+contact_uv_offset.xy).rgb));
	float edge = contact_height + (fbm(contact_world.xz*5.0)-0.5)*contact_breakup+crease*.08;
	float height = max(contact_world.y-contact_ground_y,0.0);
	float cover = 1.0-smoothstep(max(.015,edge-.1),max(edge+.035,.03),height);
	// Пятна по высоте и вдоль стены разрывают сплошную полосу у основания.
	float mottling=fbm(vec2(dot(contact_world.xz,vec2(1.7,.9))*5.0,contact_world.y*17.0));
	cover*=smoothstep(.2,.65,mottling)*.9;
	if (cover < 0.005) discard;
	float detail;
	vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	vec4 ground = ground_sample(contact_world.xz+world_normal.xz*height*2.0,detail);
	float patches = sin(contact_world.x*.71+sin(contact_world.z*.42))*sin(contact_world.z*.83-contact_world.x*.31);
	float damp = smoothstep(.05,.65,patches)*ground.a;
	ALBEDO = ground.rgb*mix(1.0,.82,damp);
	ROUGHNESS = mix(.88,.3,damp);
	METALLIC = 0.0;
	// Сохраняем объём и тень стены; небольшой поворот нормали связывает самый низ с полом.
	vec3 up = (VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL = normalize(mix(NORMAL,up,cover*.2));
	ALPHA = cover;
}
