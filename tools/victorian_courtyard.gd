extends Node3D
## Isolated art-direction playground. No campaign geometry or materials are changed.
@export var warm_light_energy := 3.0
@export var ambient_energy := 0.65
@export var fog_density := 0.012
var stone: StandardMaterial3D
var iron: StandardMaterial3D
var brick: StandardMaterial3D
var bronze: StandardMaterial3D

func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.72
	return m

func box(at: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var resource := BoxShape3D.new()
		resource.size = size
		shape.shape = resource
		body.add_child(shape)
		visual.add_child(body)
	return visual

func lamp(at: Vector3) -> void:
	box(at + Vector3(0, 1.1, 0), Vector3(0.12, 2.2, 0.12), iron)
	box(at + Vector3(0, 0.12, 0), Vector3(0.55, 0.24, 0.55), stone)
	var glass := material(Color(1, 0.66, 0.29))
	glass.emission_enabled = true
	glass.emission = Color(1, 0.48, 0.12)
	glass.emission_energy_multiplier = 2.0
	box(at + Vector3(0, 2.35, 0), Vector3(0.32, 0.48, 0.32), glass)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			box(at + Vector3(x, 2.35, z), Vector3(0.045, 0.62, 0.045), iron)
	box(at + Vector3(0, 2.68, 0), Vector3(0.55, 0.12, 0.55), iron)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 2.2, 0)
	light.light_color = Color(1, 0.68, 0.36)
	light.light_energy = warm_light_energy
	light.omni_range = 7.5
	light.shadow_enabled = true
	add_child(light)

func _ready() -> void:
	seed(16310)
	stone = material(Color(0.32, 0.32, 0.30))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.075
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.48, 0.46, 0.42))
	ramp.set_color(1, Color(0.92, 0.89, 0.82))
	texture.color_ramp = ramp
	stone.albedo_texture = texture
	iron = material(Color(0.065, 0.075, 0.08), 0.65)
	brick = material(Color(0.25, 0.16, 0.13))
	bronze = material(Color(0.30, 0.22, 0.12), 0.6)
	box(Vector3(0, -0.35, 0), Vector3(23, 0.7, 27), stone, true)
	# Individual broad paving slabs: geometry and quiet color variation, no drawn backdrop.
	for x in range(-11, 11):
		for z in range(-13, 13):
			var shade := randf_range(0.95, 1.06)
			var m := material(Color(0.48, 0.46, 0.42) * shade)
			m.albedo_texture = texture
			box(Vector3(x + 0.5, 0.025, z + 0.5), Vector3(0.96, 0.05, 0.96), m)
	# Back wall, chunky piers, and conservatory frame.
	box(Vector3(0, 1.2, -12), Vector3(23, 2.4, 0.6), brick, true)
	for row in 7:
		box(Vector3(0, row * 0.32 + 0.1, -11.68), Vector3(23, 0.025, 0.015), stone)
		for col in 23:
			box(Vector3(col - 11 + (row % 2) * 0.5, row * 0.32 + 0.25, -11.67), Vector3(0.025, 0.29, 0.02), stone)
	for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		box(Vector3(x, 1.7, -11.4), Vector3(0.65, 3.4, 0.8), stone, true)
		box(Vector3(x, 3.45, -11.4), Vector3(0.9, 0.18, 1), stone)
	# Open roof ribs, simple repeated ironwork rather than futuristic architecture.
	for z in [-10.0, -6.0, -2.0]:
		box(Vector3(-10.4, 2.3, z), Vector3(0.14, 4.6, 0.14), iron)
		var rib := box(Vector3(-8.8, 4.9, z), Vector3(3.6, 0.12, 0.12), iron)
		rib.rotation.z = deg_to_rad(20)
	for side in [-1, 1]:
		box(Vector3(side * 11, 0.35, 0), Vector3(0.45, 0.7, 24), stone, true)
		for z in range(-11, 12):
			box(Vector3(side * 11, 1.1, z), Vector3(0.07, 1.5, 0.07), iron)
		box(Vector3(side * 11, 1.5, 0), Vector3(0.1, 0.08, 24), iron)
	for at in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-9, 0, 5), Vector3(9, 0, 5)]: lamp(at)
	for at in [Vector3(-8.5, 0, -4), Vector3(8.5, 0, -3)]:
		box(at + Vector3(0, 0.3, 0), Vector3(2.5, 0.6, 3), stone, true)
		var plant := preload("res://assets/plants/Plant_Fern.tscn").instantiate()
		plant.position = at + Vector3(0, 0.6, 0)
		add_child(plant)
	# Two simple park benches and bare branching trees frame the path.
	var wood := material(Color(0.19, 0.105, 0.065))
	for side in [-1, 1]:
		for z in [-7.0, -3.0]:
			var at := Vector3(side * 6.7, 0, z)
			box(at + Vector3(0, 0.5, 0), Vector3(1.8, 0.12, 0.65), wood, true)
			box(at + Vector3(0, 0.9, -0.3), Vector3(1.8, 0.6, 0.09), wood)
			for x in [-0.65, 0.65]: box(at + Vector3(x, 0.25, 0), Vector3(0.09, 0.5, 0.5), iron)
		var trunk := Vector3(side * 9.0, 0, -8.5)
		box(trunk + Vector3(0, 1.4, 0), Vector3(0.26, 2.8, 0.3), wood)
		for j in 4:
			var branch := box(trunk + Vector3((j % 2 * 2 - 1) * 0.4, 1.9 + j * 0.3, 0), Vector3(0.13, 1.5, 0.14), wood)
			branch.rotation.z = deg_to_rad(40 * (j % 2 * 2 - 1))
	var shrine := preload("res://assets/plants/Shrine_Candles.tscn").instantiate()
	shrine.position = Vector3(0, 0, -9.8)
	add_child(shrine)
	# Distant abyss silhouettes: simple volumes, no collision outside the courtyard.
	var distant := material(Color(0.06, 0.12, 0.14))
	for i in 10:
		box(Vector3(17 + i % 3 * 3, -5, -20 + i * 4), Vector3(2, 12 + i % 4, 2), distant)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.095, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.65, 0.75)
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.23, 0.26)
	env.fog_density = fog_density
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color(0.60, 0.71, 0.83)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(10, 3, -4)
	rim.light_color = Color(0.17, 0.7, 0.64)
	rim.light_energy = 3
	rim.omni_range = 13
	add_child(rim)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(preload("res://scripts/camera_rig.gd"))
	rig.target_path = NodePath("../Player")
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 50
	camera.current = true
	rig.add_child(camera)
	add_child(rig)
	var pool := Node3D.new()
	pool.set_script(preload("res://scripts/bullet_pool.gd"))
	pool.bullet_scene = preload("res://scenes/bullet.tscn")
	pool.add_to_group("bullet_pool")
	add_child(pool)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 0.1, -5)
	add_child(spawn)
