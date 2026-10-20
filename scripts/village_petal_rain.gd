extends GPUParticles3D
## World-space petals drift around the moving player; they never accumulate as decals.
@export_range(0, 500) var petal_count := 180
@export var area := Vector3(10, 0.4, 13)
@export var wind := Vector3(0.12, -0.16, 0.06)

func _ready() -> void:
	amount = maxi(1, petal_count)
	emitting = petal_count > 0
	lifetime = 11.0
	preprocess = 8.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-15, -20, -18), Vector3(30, 30, 36))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = area
	process.direction = Vector3(0.25, -1, 0.1)
	process.spread = 28
	process.gravity = wind
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.7
	process.angular_velocity_min = -55
	process.angular_velocity_max = 55
	process.angle_min = -180
	process.angle_max = 180
	process.scale_min = 0.22
	process.scale_max = 0.48
	process.particle_flag_rotate_y = false
	process_material = process
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/buildings/village_nature/textures/red_petal.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	draw_pass_1 = quad
