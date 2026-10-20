shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Паутина в углу стен, нарисованная без картинки: лучи от угла и провисшие кольца.
// Центр паутины — верхний край квадрата (там, где сходятся стены).

uniform vec4 web_color : source_color = vec4(0.82, 0.82, 0.78, 0.5);
uniform float strands = 9.0;
uniform float rings = 6.0;
instance uniform float seed = 0.0;

float hash(float x) {
	return fract(sin(x * 91.17 + seed * 13.3) * 43758.5453);
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, UV.y - 0.02);
	float r = length(p);
	float a = atan(p.x, p.y);  // 0 — прямо вниз
	// Лучи.
	float sector = a * strands / 6.2831853;
	float ang = abs(fract(sector + 0.5) - 0.5) * 6.2831853 / strands;
	float strand = 1.0 - smoothstep(0.0025, 0.006, ang * r);
	// Кольца провисают между лучами; часть колец порвана.
	float sag = sin(fract(sector) * 3.14159) * 0.025;
	float ring_pos = (r + sag) * rings / 0.5;
	float ring_index = floor(ring_pos);
	float f = fract(ring_pos);
	float ring = 1.0 - smoothstep(0.0025, 0.006, min(f, 1.0 - f) * 0.5 / rings);
	ring *= step(0.25, hash(ring_index * 7.0 + floor(sector)));
	float mask = max(strand, ring);
	mask *= 1.0 - smoothstep(0.38, 0.5, r);
	mask *= step(0.0, p.y);
	ALBEDO = web_color.rgb;
	ALPHA = mask * web_color.a;
}
