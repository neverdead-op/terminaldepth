shader_type spatial;
render_mode specular_schlick_ggx;
#include "res://assets/shaders/village_floor_sampling.gdshaderinc"
uniform sampler2D source_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 source_tint : source_color=vec4(1.0);
uniform vec3 source_uv_scale=vec3(1.0);
uniform vec3 source_uv_offset=vec3(0.0);
uniform bool source_has_texture=false;
uniform float source_roughness=0.9;
uniform float source_metallic=0.0;
uniform vec3 contact_limits=vec3(-85.0,19.0,60.0);
varying vec3 contact_world;
void vertex() {
	contact_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	if (contact_world.z<contact_limits.x || contact_world.z>contact_limits.y || contact_world.x>contact_limits.z || contact_world.x<(-66.0+sin(contact_world.z*.047)*2.0)) discard;
	vec3 stone=source_tint.rgb;
	if (source_has_texture) stone*=texture(source_tex,UV*source_uv_scale.xy+source_uv_offset.xy).rgb;
	float detail;
	vec4 ground=ground_sample(contact_world.xz,detail);
	float patches=sin(contact_world.x*.71+sin(contact_world.z*.42))*sin(contact_world.z*.83-contact_world.x*.31);
	float damp=smoothstep(.05,.65,patches)*ground.a;
	float blend=smoothstep(0.0,.95,UV2.x);
	ALBEDO=mix(stone,ground.rgb*mix(1.0,.82,damp),blend);
	ROUGHNESS=mix(source_roughness,mix(.88,.3,damp),blend);
	METALLIC=source_metallic*(1.0-blend);
}
