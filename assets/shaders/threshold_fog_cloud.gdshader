shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D cloud_map : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 fog_tint : source_color = vec4(0.38,0.52,0.57,1.0);
uniform float opacity : hint_range(0.0,1.0) = 0.40;
uniform float softness : hint_range(0.05,6.0) = 0.9;
uniform float phase = 0.0;
uniform bool clear_around_player = false;
uniform vec3 clear_center = vec3(0.0);
uniform float clear_radius = 2.1;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 uv=UV;
    uv.x+=sin(UV.y*13.0+TIME*0.11+phase)*0.012;
    uv.y+=sin(UV.x*10.0-TIME*0.08+phase)*0.009;
    vec4 cloud=texture(cloud_map,uv);
    float border=smoothstep(0.0,0.11,UV.x)*smoothstep(0.0,0.11,1.0-UV.x);
    border*=smoothstep(0.0,0.09,UV.y)*smoothstep(0.0,0.09,1.0-UV.y);
    float depth=texture(scene_depth,SCREEN_UV).r;
    vec4 surface=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth,1.0);
    float distance_to_surface=-surface.z/surface.w;
    float intersection=clamp((distance_to_surface+VERTEX.z)/softness,0.0,1.0);
    float player_clear=1.0;
    if(clear_around_player) player_clear=mix(0.15,1.0,smoothstep(clear_radius,clear_radius+1.8,distance(world_position.xz,clear_center.xz)));
    ALBEDO=fog_tint.rgb*mix(0.68,1.15,cloud.r);
    float billow=0.83+0.17*sin(UV.x*7.0+sin(UV.y*9.0+phase)+TIME*0.07);
    ALPHA=cloud.a*mix(0.35,1.0,cloud.r)*border*opacity*intersection*player_clear*billow;
}
