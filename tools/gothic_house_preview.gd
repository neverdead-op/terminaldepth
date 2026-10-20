extends Node3D
## F6: actual model turntable. Mouse wheel zooms; Space pauses rotation.
@export var rotate_model := true
var model: Node3D
var camera: Camera3D
var elapsed := 0.0

func _ready() -> void:
	model = preload("res://assets/buildings/gothic_house/gothic_house.tscn").instantiate()
	add_child(model)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://assets/shaders/garden_floor.gdshader")
	floor_material.set_shader_parameter("albedo_map", preload("res://assets/textures/victorian_garden/stylized_v2/flagstones_red_petals_albedo.png"))
	floor_material.set_shader_parameter("tile_meters", 6.0)
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.065, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.8)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_color = Color(1, 0.86, 0.69)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(11, 9, 14)
	camera.fov = 42
	add_child(camera)
	camera.look_at(Vector3(0, 3.6, 0))
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(24, 22)
	label.text = "ГОТИЧЕСКИЙ ДОМ · настоящая 3D-модель\nПробел — остановить вращение · колесо — масштаб"
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(label)
	if "--capture" in OS.get_cmdline_user_args():
		rotate_model = false
		await get_tree().create_timer(4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/gothic_house_model.png")
		model.rotation.y = PI
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/gothic_house_back.png")
		print("GOTHIC_HOUSE_PREVIEW_OK: standalone textured GLB rendered front and rear")
		get_tree().quit()

func _process(delta: float) -> void:
	if rotate_model and model: model.rotation.y += delta * 0.22

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		rotate_model = not rotate_model
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.fov = maxf(25, camera.fov - 2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.fov = minf(65, camera.fov + 2)
