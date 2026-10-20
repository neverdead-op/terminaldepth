extends Node3D
## Галерея загруженных моделей персонажей и зомби.

const MODELS := [
	{"path": "res://assets/Ch25_nonPBR.fbx", "title": "Ch25"},
	{"path": "res://assets/Ch41_nonPBR.fbx", "title": "Ch41"},
	{"path": "res://assets/Zombiegirl W Kurniawan.fbx", "title": "Зомби-девушка"},
	{"path": "res://assets/зомби с пушкой.fbx", "title": "Зомби с оружием"},
	{"path": "res://assets/босс 2 уровня.fbx", "title": "Босс 2 уровня"},
	{"path": "res://assets/animations/pro_rifle_pack_source/Ch33_nonPBR.fbx", "title": "Ch33"},
	{"path": "res://assets/animations/creature_pack_source/Warrok W Kurniawan.fbx", "title": "Мутант Warrok"},
]

func _ready() -> void:
	_make_stage()
	for index in MODELS.size():
		_add_model(index, MODELS[index])
	_make_camera()

func _make_stage() -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 12.0)
	floor.mesh = plane
	floor.position = Vector3(0.0, -0.03, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.045, 0.052, 0.06)
	floor_material.roughness = 0.82
	floor.material_override = floor_material
	add_child(floor)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	light.light_energy = 2.0
	add_child(light)

	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color(0.018, 0.023, 0.03)
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.55, 0.59, 0.66)
	world.ambient_light_energy = 0.65
	environment.environment = world
	add_child(environment)

func _add_model(index: int, item: Dictionary) -> void:
	var packed := load(item.path) as PackedScene
	if packed == null:
		push_warning("Не удалось загрузить модель: " + item.path)
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		push_warning("В файле нет корневого Node3D: " + item.path)
		return
	add_child(model)
	var spacing := 3.05
	model.position.x = (float(index) - (MODELS.size() - 1) * 0.5) * spacing
	var bounds := AABB()
	var found := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.1:
		var fit_scale := 2.05 / bounds.size.y
		model.scale = Vector3.ONE * fit_scale
		model.position.y = -bounds.position.y * fit_scale
	else:
		push_warning("В модели не нашлись меши: " + item.path)

	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		var chosen := ""
		for clip_name in player.get_animation_list():
			var lowered := String(clip_name).to_lower()
			if clip_name != &"RESET" and (lowered.contains("idle") or lowered.contains("stand")):
				chosen = clip_name
				break
		if chosen == "":
			for clip_name in player.get_animation_list():
				if clip_name != &"RESET":
					chosen = clip_name
					break
		if chosen != "":
			player.play(chosen)

	var label := Label3D.new()
	label.text = item.title
	label.position = Vector3(model.position.x, 2.35, 0.0)
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = Color(0.88, 0.82, 0.67)
	label.outline_size = 8
	label.outline_modulate = Color(0.025, 0.027, 0.03)
	add_child(label)

func _make_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 5.6, 17.5)
	camera.fov = 46.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
