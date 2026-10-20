extends Node3D
## Отдельная витрина эффектов. F6, управление кнопками; без запуска кампании и записи настроек.

const EFFECT := preload("res://scripts/gothic_ritual_fx.gd")
const FLAT := preload("res://scripts/flat_sprite.gd")
const OBELISK := preload("res://assets/environment/graveyard_2d/obelisk.png")
const ALTAR := preload("res://assets/environment/graveyard_2d/ritual_circle.png")

var _effects: Array[Node3D] = []
var _enable_toggle: CheckButton


func _ready() -> void:
	set_meta("test_runner", true)
	Game.testing = true
	_build_world()
	_build_props()
	_build_controls()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.023, 0.033)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.53, 0.68)
	environment.ambient_light_energy = 0.45
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(36, 28)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/victorian_garden/stylized_v2/flagstones_red_petals_albedo.png")
	material.albedo_color = Color(0.32, 0.35, 0.39)
	material.uv1_scale = Vector3(6, 5, 1)
	material.roughness = 0.95
	floor_mesh.material_override = material
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_color = Color(0.73, 0.8, 1.0)
	sun.light_energy = 0.65
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	camera.position = Vector3(0, 16.56, 13.31)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 1.0))
	camera.current = true
	get_viewport().msaa_3d = Viewport.MSAA_2X


func _build_props() -> void:
	var obelisk := Node3D.new()
	obelisk.position = Vector3(-3.4, 0, 1.0)
	add_child(obelisk)
	var sprite := FLAT.make(OBELISK, 2.8)
	obelisk.add_child(sprite)
	var glow := EFFECT.new()
	glow.radius = 2.2
	obelisk.add_child(glow)
	glow.bind_crystal(sprite)
	_effects.append(glow)
	var altar := Node3D.new()
	altar.position = Vector3(3.3, 0, 1.0)
	add_child(altar)
	altar.add_child(FLAT.make(ALTAR, 4.7, false, true))
	var ritual := EFFECT.new()
	ritual.radius = 3.2
	ritual.effect_color = Color(0.8, 0.20, 0.07)
	altar.add_child(ritual)
	_effects.append(ritual)


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.position = Vector2(24, 20)
	layer.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "ENDORAMA — обелиск и ритуал"
	title.add_theme_font_size_override("font_size", 28)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Пробные эффекты • камера 52° • настройки не сохраняются"
	rows.add_child(hint)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for i in 2:
		var button := Button.new()
		button.text = "Импульс обелиска" if i == 0 else "Импульс ритуала"
		button.pressed.connect(_effects[i].pulse)
		buttons.add_child(button)
		if i == 0:
			button.grab_focus()
	_enable_toggle = CheckButton.new()
	_enable_toggle.text = "Эффекты"
	_enable_toggle.button_pressed = true
	_enable_toggle.toggled.connect(func(value: bool) -> void:
		for effect in _effects:
			effect.active = value)
	buttons.add_child(_enable_toggle)
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 20)
	rows.add_child(settings)
	_add_slider(settings, "Яркость", 0.0, 2.5, 1.0, func(value: float) -> void:
		for effect in _effects:
			effect.intensity = value)
	_add_slider(settings, "Скорость", 0.0, 2.0, 1.0, func(value: float) -> void:
		for effect in _effects:
			effect.speed = value)
	var mist := CheckButton.new()
	mist.text = "Низкая дымка"
	mist.button_pressed = true
	mist.toggled.connect(func(value: bool) -> void:
		for effect in _effects:
			effect.mist_enabled = value)
	buttons.add_child(mist)
	var color := ColorPickerButton.new()
	color.text = "Цвет свечения"
	color.color = Color(0.85, 0.08, 0.04)
	color.edit_alpha = false
	color.color_changed.connect(func(value: Color) -> void:
		for effect in _effects:
			effect.effect_color = value)
	color.custom_minimum_size.x = 140
	settings.add_child(color)


func _add_slider(parent: Control, text: String, minimum: float, maximum: float, initial: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 85
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 180
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.value_changed.connect(callback)
	row.add_child(slider)


func _capture() -> void:
	var directory := "res://output/gothic_fx_preview"
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory + "/idle.png")
	for effect in _effects:
		effect.pulse()
	await get_tree().create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory + "/pulse.png")
	_enable_toggle.button_pressed = false
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory + "/off.png")
	print("GOTHIC_FX_PREVIEW_OK: idle, pulse, off")
	get_tree().quit()
