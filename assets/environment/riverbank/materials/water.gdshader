shader_type spatial;
render_mode unshaded, cull_disabled;
// Два слоя течения, завихрения и пена по форме берега.
uniform vec4 deep_color : source_color = vec4(0.018,0.085,0.12,1.0);
uniform vec4 shallow_color : source_color = vec4(0.035,0.29,0.32,1.0);
uniform vec4 foam_color : source_color = vec4(0.43,0.76,0.73,1.0);
uniform float flow_speed = 0.65;
uniform float wave_strength = 0.16;
uniform float foam_strength = 0.8;
uniform vec3 foam_rocks[16];
varying vec3 world_pos;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float shore_x(float z) { return -66.0+sin(z*0.047)*8.0+sin(z*0.11)*2.5; }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float t=TIME*flow_speed;
 float n=noise2(p*0.19+vec2(t*0.16,-t*0.24));
 float fine=noise2(p*0.63+vec2(-t*0.21,t*0.31));
 float wave=sin(p.x*3.0+p.y*0.9+n*4.0-t*1.8);
 float cross_wave=sin(p.y*2.8-p.x*0.38+fine*2.6+t*1.3);
 float distance_shore=shore_x(p.y)-p.x;
 float shallows=1.0-smoothstep(0.0,16.0,distance_shore);
 vec3 color=mix(deep_color.rgb,shallow_color.rgb,0.18+n*0.38+shallows*0.36);
 float ribbons=smoothstep(0.81,0.98,wave)*smoothstep(0.4,0.72,fine)*0.24;
 float edge=exp(-abs(distance_shore-2.2-sin(p.y*0.8+t)*0.5)*1.25);
 float pulse=sin(p.y*2.0+t*2.0+n*5.0);
 float shore_foam=edge*(0.45+0.55*pulse*pulse);
 float ring=0.0;
 for(int i=0;i<16;i++) {
  vec2 d=p-foam_rocks[i].xy;
  float radius=foam_rocks[i].z;
  float ripple=length(d)-radius-0.5*sin(atan(d.y,d.x)*4.0+t*1.5);
  ring=max(ring,exp(-abs(ripple-1.2)*3.4)*(0.35+fine*0.65));
 }
 float foam=clamp((ribbons+shore_foam+ring*0.6)*foam_strength,0.0,0.85);
 ALBEDO=mix(color,foam_color.rgb,foam);
 NORMAL_MAP=vec3(0.5+wave*wave_strength,0.5+cross_wave*wave_strength*0.65,1.0);
 NORMAL_MAP_DEPTH=0.7;
 ROUGHNESS=mix(0.27,0.7,foam);
 SPECULAR=0.42;
 EMISSION=mix(color,foam_color.rgb,foam)*0.12;
}
