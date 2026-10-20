shader_type spatial;
render_mode specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float metalness = 0.0;
uniform float surface_roughness = 0.85;
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_strength = 0.0;
uniform float weathering = 0.22;
uniform float flat_normals = 0.0;
uniform float rim_strength = 0.08;
uniform float cel_amount = 0.65;
uniform float cel_steps = 4.0;
uniform float cel_softness = 0.18;
uniform sampler2D stone_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform float stone_amount = 0.0;
varying vec3 world_normal;
varying vec3 world_position;
void vertex() { world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 face=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
    if(dot(face,NORMAL)<0.0) face=-face;
    NORMAL=normalize(mix(NORMAL,face,flat_normals));
    vec3 painted=texture(atlas,UV).rgb*tint.rgb;
    if(stone_amount>0.001) {
    vec3 weights=pow(abs(world_normal),vec3(5.0)); weights/=max(dot(weights,vec3(1.0)),0.001);
    vec3 mineral=texture(stone_detail,world_position.yz*.32).rgb*weights.x+texture(stone_detail,world_position.xz*.32).rgb*weights.y+texture(stone_detail,world_position.xy*.32).rgb*weights.z;
    // Restrained, broad tonal planes rather than full photographic contrast.
    mineral=floor(mineral*12.0)/12.0;
    painted*=mix(vec3(1.0),clamp(mineral*2.5,vec3(.65),vec3(1.3)),stone_amount);
    }
    float patch=sin(world_position.x*0.81+sin(world_position.z*0.73))*sin(world_position.z*0.49+world_position.y*0.39);
    float wet=smoothstep(0.25,0.85,patch)*weathering;
    ALBEDO=painted*(1.0-wet*0.12);
    ROUGHNESS=clamp(surface_roughness-wet*0.28,0.25,1.0);
    METALLIC=metalness;
    EMISSION=painted*glow_color*glow_strength+painted*rim_strength*pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0)*0.25;
}
void light() {
    float diffuse=max(dot(NORMAL,LIGHT),0.0);
    float levels=max(cel_steps-1.0,1.0);
    // Quantize received light, including local falloff. Quantizing only N.L
    // makes the entire horizontal courtyard remain almost continuously lit.
    float received=diffuse*ATTENUATION;
    float scaled=received*levels;
    float band=(floor(scaled)+smoothstep(0.5-cel_softness,0.5+cel_softness,fract(scaled)))/levels;
    float shaped=clamp(band,0.0,1.0)*smoothstep(0.0,0.035,received);
    DIFFUSE_LIGHT+=mix(received,shaped,cel_amount)*LIGHT_COLOR/PI;
}
