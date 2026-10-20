extends Node
## A/B lighting study on the actual hub. Geometry, textures and campaign stay intact.
@export var cool_fill_energy := 0.44
@export var warm_pool_energy := 2.8
@export var cool_rim_energy := 2.0
@export var contrast := 1.08
@export var saturation := 0.84
var hub: Node3D
var world: WorldEnvironment
var original_environment: Environment
var styled_environment: Environment
var originals: Array[Dictionary] = []
var accents: Node3D
var caption: Label
var enabled := true

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(2, &"normal", "res://scenes/hub.tscn")
	hub = player.get_parent()
	await get_tree().create_timer(0.5).timeout
	world = hub.get_node("WorldEnvironment")
	original_environment = world.environment
	styled_environment = original_environment.duplicate()
	styled_environment.ambient_light_color = Color(0.40, 0.56, 0.65)
	styled_environment.ambient_light_energy = cool_fill_energy
	styled_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	styled_environment.tonemap_exposure = 1.0
	styled_environment.ssao_enabled = true
	styled_environment.ssao_radius = 1.0
	styled_environment.ssao_intensity = 1.3
	styled_environment.glow_enabled = true
	styled_environment.glow_intensity = 0.22
	styled_environment.glow_hdr_threshold = 1.8
	styled_environment.adjustment_enabled = true
	styled_environment.adjustment_contrast = contrast
	styled_environment.adjustment_saturation = saturation
	styled_environment.fog_enabled = true
	styled_environment.fog_density = 0.005
	styled_environment.fog_light_color = Color(0.14, 0.23, 0.27)
	for node in hub.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		originals.append({"light": light, "energy": light.light_energy, "color": light.light_color})
	accents = Node3D.new()
	accents.name = "LightingStudyAccents"
	hub.add_child(accents)
	_add_light(Vector3(-5.5, 2.9, -1.4), Color(1, 0.63, 0.30), warm_pool_energy, 6.0, true)
	_add_light(Vector3(5.3, 2.7, -1.5), Color(1, 0.66, 0.34), warm_pool_energy, 5.5, true)
	_add_light(Vector3(0, 3.2, 3), Color(1, 0.73, 0.48), warm_pool_energy * 0.65, 5.0, true)
	# Soft front fill retains character readability instead of merely darkening the room.
	_add_light(Vector3(0, 4.0, 6), Color(0.79, 0.84, 0.87), 1.5, 9.0, false)
	_add_light(Vector3(0, 2.2, -5), Color(0.20, 0.66, 0.71), cool_rim_energy, 7, false)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var canvas := CanvasLayer.new()
	canvas.layer = 40
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(24, 100)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 5)
	canvas.add_child(caption)
	_apply()
	if "--capture" in OS.get_cmdline_user_args():
		player.set_physics_process(false)
		# Identical viewpoint and character pose in both comparisons.
		for state in [false, true]:
			enabled = state
			_apply()
			await get_tree().create_timer(5).timeout
			await RenderingServer.frame_post_draw
			var file := "hub_light_styled" if state else "hub_light_original"
			get_viewport().get_texture().get_image().save_png("res://docs/screens/%s.png" % file)
		assert(Game.testing)
		print("LIGHT_STYLE_OK: original and styled lighting rendered on identical hub geometry, test saving disabled")
		get_tree().quit()

func _add_light(at: Vector3, color: Color, energy: float, radius: float, shadows: bool) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = shadows
	light.light_size = 0.3
	accents.add_child(light)

func _apply() -> void:
	world.environment = styled_environment if enabled else original_environment
	for entry in originals:
		var light: Light3D = entry.light
		light.light_color = Color(0.62, 0.73, 0.83) if enabled and light is DirectionalLight3D else entry.color
		light.light_energy = (0.42 if light is DirectionalLight3D else float(entry.energy) * 0.20) if enabled else entry.energy
	accents.visible = enabled
	caption.text = "F2 — сравнить свет: %s\nТе же модели и материалы · сохранение отключено" % ("НОВЫЙ" if enabled else "ИСХОДНЫЙ")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		enabled = not enabled
		_apply()
