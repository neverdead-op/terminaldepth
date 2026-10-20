shader_type fog;
uniform float density : hint_range(0.0,0.3) = 0.13;
uniform float cloud_scale = 0.15;
uniform float wind = 0.45;
uniform vec4 cloud_color : source_color = vec4(0.43,0.58,0.65,1.0);
float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
    vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fog() {
    vec3 p=WORLD_POSITION*cloud_scale+vec3(TIME*0.025*wind,0.0,TIME*0.018*wind);
    float n=noise3(p)*0.68+noise3(p*2.08+5.7)*0.32;
    float boundary=1.0-smoothstep(0.55,1.0,length((UVW-0.5)*2.0));
    DENSITY=density*boundary*smoothstep(0.23,0.76,n);
    ALBEDO=cloud_color.rgb;
    EMISSION=cloud_color.rgb*0.16;
}
