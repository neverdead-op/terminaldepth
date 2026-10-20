shader_type spatial;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform bool window_glow = false;
uniform vec3 haze_color : source_color = vec3(0.055,0.14,0.18);
uniform float layer_fade : hint_range(0.0,1.0) = 0.35;
void fragment() {
    vec3 painted=texture(atlas,UV).rgb;
    float fade=clamp(layer_fade+smoothstep(45.0,120.0,length(VERTEX))*0.30,0.0,0.90);
    ALBEDO=mix(painted*0.22,haze_color,fade);
    ROUGHNESS=1.0;
    EMISSION=vec3(0.0);
    if(window_glow) EMISSION+=painted*vec3(1.0,0.57,0.22)*(1.0-fade)*1.8;
}
