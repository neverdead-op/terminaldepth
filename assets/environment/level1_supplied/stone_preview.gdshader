shader_type spatial;
varying vec3 world_normal;
void vertex() {
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 float floor_weight = smoothstep(0.55, 0.85, normalize(world_normal).y);
 ALBEDO = mix(vec3(0.19, 0.205, 0.22), vec3(0.33, 0.305, 0.27), floor_weight);
 ROUGHNESS = 1.0;
 SPECULAR = 0.15;
}
