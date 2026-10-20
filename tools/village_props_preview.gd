extends Node3D

func _ready() -> void:
	var items := [
		[preload("res://assets/buildings/village_props/gate_round.glb"), Vector3(0, 0, -4)],
		[preload("res://assets/buildings/village_props/wall_straight.glb"), Vector3(-6, 0, 0)],
		[preload("res://assets/buildings/village_props/carriage.glb"), Vector3(2.4, 0, 1.5)],
		[preload("res://assets/buildings/village_props/basket.glb"), Vector3(-1.8, 0, 2.6)],
		[preload("res://assets/buildings/village_props/crate.glb"), Vector3(-3.3, 0, 2.5)],
	]
	for item in items:
		var mesh: Node3D = item[0].instantiate()
		mesh.position = item[1]
		add_child(mesh)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 20)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.19)
	mat.roughness = 0.85
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.065, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.75, 0.83)
	env.ambient_light_energy = 0.7
	env.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color(1, 0.82, 0.65)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(12, 10, 17)
	camera.fov = 48
	add_child(camera)
	camera.look_at(Vector3(0, 1.5, -0.5))
	get_viewport().msaa_3d = Viewport.MSAA_4X
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/village_props_models.png")
		print("VILLAGE_PROPS_PREVIEW_OK: wall, round gate, basket, crate, carriage rendered")
		get_tree().quit()
