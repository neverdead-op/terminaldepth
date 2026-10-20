extends Node3D
## F6: browse all 49 assets in a neutral inspection light; 1–4 or arrows switch sections.
var page := 0
var content: Node3D
var caption: Label
var camera: Camera3D
var catalog: Array
var counts := [0, 0, 0, 0]

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/victorian_kit/v1/catalog.json"))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.75, 0.81)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color(1, 0.86, 0.71)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(11, 14, 18)
	camera.fov = 48
	add_child(camera)
	camera.look_at(Vector3(0, 0.4, 0))
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(22, 16)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 5)
	canvas.add_child(caption)
	_show()
	if "--capture" in OS.get_cmdline_user_args():
		for i in 4:
			page = i
			_show()
			await get_tree().create_timer(3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/screens/victorian_kit_%d.png" % i)
		assert(counts[0] + counts[1] + counts[2] + counts[3] == 49)
		print("VICTORIAN_KIT_GALLERY_OK: 49 models, 4 pages rendered, ", counts)
		get_tree().quit()

func _show() -> void:
	if content:
		remove_child(content)
		content.queue_free()
	content = Node3D.new()
	add_child(content)
	var items: Array = []
	for entry in catalog:
		var group: String = entry.group
		if (page == 0 and group == "furniture") or (page == 1 and group == "architecture") or (page == 2 and group == "structure") or (page == 3 and group == "floors"):
			items.append({"path": "res://assets/environment/victorian_kit/v1/" + entry.id + ".glb", "label": entry.label})
	if page == 3:
		for pair in [["gothic_lantern", "Готический фонарь"], ["tree_bare", "Сухое дерево"], ["tree_red", "Дерево · красная листва"], ["barrel", "Бочка"], ["bench", "Скамья"], ["planter", "Клумба"]]:
			items.append({"path": "res://assets/buildings/village_nature/" + pair[0] + ".glb", "label": pair[1]})
		for pair in [["wall_straight", "Высокая стена"], ["gate_round", "Круглая арка"], ["basket", "Корзина"], ["crate", "Ящик"], ["carriage", "Карета"]]:
			items.append({"path": "res://assets/buildings/village_props/" + pair[0] + ".glb", "label": pair[1]})
	counts[page] = items.size()
	caption.text = "ВИКТОРИАНСКИЙ НАБОР · %s · %d моделей\n1–4 / стрелки — разделы · колесо — приближение" % [["Мебель", "Двери и ставни", "Стены и ограды", "Полы, растения и улица"][page], items.size()]
	var spacing := 4.0 if page != 3 else 5.0
	var columns := 4
	var rows := ceili(items.size() / 4.0)
	for i in items.size():
		var model := load(items[i].path).instantiate() as Node3D
		model.position = Vector3((i % columns - 1.5) * spacing, 0, (floorf(i / 4.0) - (rows - 1) * 0.5) * spacing)
		if items[i].label == "Круглая арка": model.scale = Vector3.ONE * 0.3
		if items[i].path.contains("floor_"): model.scale = Vector3.ONE * 0.75
		content.add_child(model)
		var label := Label3D.new()
		label.text = items[i].label
		label.font = Loc.MAIN_FONT
		label.font_size = 32
		label.pixel_size = 0.010
		label.position = model.position + Vector3(0, 0.08, spacing * 0.34)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		content.add_child(label)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(22, maxf(15, rows * spacing + 2))
	ground.mesh = plane
	ground.position.y = -0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.16, 0.17)
	mat.roughness = 0.9
	ground.material_override = mat
	content.add_child(ground)
	camera.position = Vector3(11, 14, 18) * (1.22 if page == 3 else 1.0)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.fov = 43

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.fov = maxf(20, camera.fov - 3)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.fov = minf(70, camera.fov + 3)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		page = event.keycode - KEY_1
	elif event.keycode == KEY_RIGHT: page = (page + 1) % 4
	elif event.keycode == KEY_LEFT: page = (page + 3) % 4
	else: return
	_show()
