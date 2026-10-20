extends Node3D
## Standalone art study; campaign progression and saves are not used.
@export var show_controls := true
@export var enable_volumetric_fog := true
@export_range(0.0,0.03) var fog_density := 0.0045
@export var follow_distance := 17.5
@export var enable_color_grade := true
@export_range(0.0,1.0) var grade_amount := 0.8
var overview := true
var spawned := false
var style_window: Window
var frozen_bodies: Array = []

func _ready() -> void:
	_apply_fog()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_apply_grade()
	if show_controls:
		var canvas := CanvasLayer.new()
		canvas.name = "PreviewControls"
		add_child(canvas)
		var label := Label.new()
		label.text = "ПОСЛЕДНИЙ ЧЕЛОВЕЧЕСКИЙ ПОРОГ    •    F1 — стиль    F2 — камера    F3 — туман    F4 — враги    F5 — цвет"
		label.position = Vector2(20,62)
		label.add_theme_font_size_override("font_size",16)
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_outline_size",4)
		canvas.add_child(label)
	_apply_camera.call_deferred()

func open_style_window() -> void:
	if not is_instance_valid(style_window):
		style_window = Window.new();style_window.name = "StyleWorkshop";style_window.title = "Мастерская стиля"
		style_window.size = Vector2i(490,650);style_window.min_size = Vector2i(450,540)
		style_window.transient = true
		add_child(style_window)
		var panel := preload("res://addons/threshold_style/style_panel.gd").new()
		style_window.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.bind($LookController)
		style_window.close_requested.connect(close_style_window)
	frozen_bodies.clear()
	var bodies := get_tree().get_nodes_in_group("enemies")
	if is_instance_valid(Game.player): bodies.append(Game.player)
	for body in bodies:
		frozen_bodies.append([weakref(body),body.is_physics_processing()]);body.set_physics_process(false)
	style_window.popup_centered()

func close_style_window() -> void:
	if is_instance_valid(style_window): style_window.hide()
	for entry in frozen_bodies:
		var body: Node = entry[0].get_ref()
		if is_instance_valid(body): body.set_physics_process(entry[1])
	frozen_bodies.clear()

func _apply_grade() -> void:
	$WorldGrade.visible = enable_color_grade
	($WorldGrade/ColorGrade.material as ShaderMaterial).set_shader_parameter("amount",grade_amount)

func _apply_fog() -> void:
	# Avoid rebuilding all Forward+ material variants when comparing fog.
	$WorldEnvironment.environment.volumetric_fog_density = fog_density if enable_volumetric_fog else 0.0
	for volume in find_children("*","FogVolume",true,false): volume.visible = enable_volumetric_fog
	if has_node("FluffyFog"): $FluffyFog.enabled = enable_volumetric_fog

func _apply_camera() -> void:
	$OverviewCamera.current = overview
	$CameraRig/Camera3D.current = not overview
	$CameraRig.distance = follow_distance

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F1:
		if is_instance_valid(style_window) and style_window.visible: close_style_window()
		else: open_style_window()
	elif event.keycode == KEY_F2:
		overview = not overview
		_apply_camera()
	elif event.keycode == KEY_F3:
		enable_volumetric_fog = not enable_volumetric_fog
		_apply_fog()
	elif event.keycode == KEY_F5:
		enable_color_grade = not enable_color_grade
		_apply_grade()
	elif event.keycode == KEY_F4 and not spawned:
		spawned = true
		for at in [Vector3(3,0.2,-3),Vector3(-2,0.2,-4),Vector3(5,0.2,2)]:
			var enemy: Enemy = preload("res://scenes/crawler.tscn").instantiate()
			enemy.position = at
			enemy.max_hp = 88
			enemy.xp_reward = 0
			enemy.drops_enabled = false
			add_child(enemy)

func _physics_process(_delta: float) -> void:
	# Safety if a test teleport places the player below the scenic platform.
	if is_instance_valid(Game.player) and Game.player.global_position.y < -5:
		Game.player.global_position = $Spawn.global_position
		Game.player.velocity = Vector3.ZERO
