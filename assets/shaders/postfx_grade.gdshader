shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float effect_weight = 1.0;
uniform float temperature = 0.0;
uniform float tint = 0.0;
uniform vec4 shadows : source_color = vec4(1.0);
uniform vec4 highlights : source_color = vec4(1.0);
uniform vec4 lift : source_color = vec4(0.0,0.0,0.0,1.0);
uniform vec4 gamma : source_color = vec4(1.0);
uniform vec4 gain : source_color = vec4(1.0);
uniform float vignette = 0.0;
uniform float vignette_softness = 0.55;
uniform float sharpen = 0.0;
uniform float chromatic_aberration = 0.0;
uniform float grain = 0.0;
uniform float lens_distortion = 0.0;
void fragment() {
	vec2 center = SCREEN_UV-.5;
	vec2 uv = clamp(SCREEN_UV+center*dot(center,center)*lens_distortion,vec2(.001),vec2(.999));
	vec3 original = texture(screen_tex,SCREEN_UV).rgb;
	vec3 c = texture(screen_tex,uv).rgb;
	if (chromatic_aberration>0.0) {
		c.r = texture(screen_tex,clamp(uv+center*chromatic_aberration,vec2(.001),vec2(.999))).r;
		c.b = texture(screen_tex,clamp(uv-center*chromatic_aberration,vec2(.001),vec2(.999))).b;
	}
	if (sharpen>0.0) {
		vec2 p = SCREEN_PIXEL_SIZE;
		vec3 neighbors = (texture(screen_tex,uv+vec2(p.x,0)).rgb+texture(screen_tex,uv-vec2(p.x,0)).rgb+texture(screen_tex,uv+vec2(0,p.y)).rgb+texture(screen_tex,uv-vec2(0,p.y)).rgb)*.25;
		c += (c-neighbors)*sharpen;
	}
	float luminance = dot(c,vec3(.2126,.7152,.0722));
	c *= mix(shadows.rgb,highlights.rgb,smoothstep(.12,.8,luminance));
	c += vec3(.035,.005,-.035)*temperature+vec3(-.012,.025,-.012)*tint;
	c = pow(max(c+lift.rgb,vec3(0.0)),1.0/max(gamma.rgb,vec3(.05)))*gain.rgb;
	float edge = smoothstep(max(.05,.72-vignette_softness),.76,length(center*vec2(1.0,.85)));
	c *= 1.0-edge*vignette;
	float random = fract(sin(dot(FRAGCOORD.xy+floor(TIME*24.0),vec2(12.9898,78.233)))*43758.5453);
	c += (random-.5)*grain;
	COLOR = vec4(mix(original,clamp(c,vec3(0),vec3(1)),effect_weight),1.0);
}
