shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_color : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0,1.0) = 0.8;
uniform float softness : hint_range(0.0,0.2) = 0.055;
uniform float vignette_strength : hint_range(0.0,0.4) = 0.13;
uniform float contrast_amount = 1.07;
uniform float saturation_amount = 1.0;
uniform float temperature = 0.0;
uniform float split_amount = 0.8;
uniform float posterize_amount = 0.0;
uniform float color_steps = 24.0;
void fragment() {
    vec3 original=textureLod(scene_color,SCREEN_UV,0.0).rgb;
    vec3 c=mix(original,textureLod(scene_color,SCREEN_UV,1.4).rgb,softness);
    float luminance=dot(c,vec3(0.2126,0.7152,0.0722));
    float shadows=1.0-smoothstep(0.06,0.42,luminance);
    float lights=smoothstep(0.25,0.78,luminance);
    c+=vec3(-0.010,0.006,0.014)*shadows*split_amount/0.8;
    c+=vec3(0.026,0.009,-0.016)*lights*split_amount/0.8;
    // Gentle contrast and a lifted, coloured toe instead of crushed black corners.
    c=(c-0.18)*contrast_amount+0.18;
    c=mix(vec3(dot(c,vec3(0.2126,0.7152,0.0722))),c,saturation_amount);
    c+=vec3(0.035,0.006,-0.035)*temperature;
    c=mix(c,floor(max(c,vec3(0.0))*color_steps+0.5)/color_steps,posterize_amount);
    c=max(c,vec3(0.006,0.011,0.016));
    float edge=smoothstep(0.24,0.77,length((SCREEN_UV-0.5)*vec2(1.0,0.86)));
    c*=1.0-edge*vignette_strength;
    COLOR=vec4(mix(original,clamp(c,vec3(0.0),vec3(1.0)),amount),1.0);
}
