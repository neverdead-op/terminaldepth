@tool
extends Node
## Профиль Riverbank и общий инструмент предпросмотра. Пишет только явным сохранением.
const Profile := preload("res://scripts/postfx_profile.gd")
const StylePanel := preload("res://addons/threshold_style/style_panel.gd")
const SAVE_PATH := "res://data/visual/riverbank_postfx_saved.tres"
@export var initial_profile: Resource
var profile: Resource
var preview_camera: Camera3D
var grade_material: ShaderMaterial
var scene_root: Node
var window: Window
var panel: Control
var before := false
var original_environment: Environment
var original_sun: Dictionary
var _world: WorldEnvironment
var _sun: DirectionalLight3D
var _layer: CanvasLayer
var _lights: Array = []
var _paused_before := false
var _timer := 0.0
var _volume_state := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root = get_parent()
	_world = scene_root.get_node("Lighting/RiverbankEnvironment/WorldEnvironment")
	_sun = scene_root.get_node("Lighting/RiverbankEnvironment/Moon")
	original_environment = _world.environment
	original_sun = {"light_energy":_sun.light_energy,"light_color":_sun.light_color,"rotation_degrees":_sun.rotation_degrees}
	profile = ResourceLoader.load(SAVE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE).duplicate(true) if FileAccess.file_exists(SAVE_PATH) else initial_profile.duplicate(true) if initial_profile!=null else Profile.defaults()
	for light in scene_root.find_children("*","OmniLight3D",true,false):
		_lights.append([light,light.light_energy,light.light_color])
	grade_material = ShaderMaterial.new()
	grade_material.shader = preload("res://assets/shaders/postfx_grade.gdshader")
	if not Engine.is_editor_hint():
		_layer = CanvasLayer.new();_layer.layer = -5;add_child(_layer)
		var rect := ColorRect.new();rect.mouse_filter = Control.MOUSE_FILTER_IGNORE;rect.material = grade_material
		_layer.add_child(rect);rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply()

func make_panel() -> Control:
	var result := StylePanel.new()
	result.schema_override = Profile.schema(profile)
	result.title_override = "СВЕТ И POST FX · RIVERBANK"
	result.note_override = "Изменения видны сразу. HUD не обрабатывается. Запись профиля — только кнопкой. Тяжёлые GI/SSR/DOF включайте осознанно."
	result.art_profiles = []
	result.preset_names = ["Genesis · база","Нейтральный"]
	result.target = self
	return result

static func copy_properties(source: Resource,target: Resource,weight := 1.0) -> void:
	for property in source.get_property_list():
		var id: String = property.name
		if not property.usage & PROPERTY_USAGE_STORAGE or id.begins_with("resource_") or id=="script": continue
		var value: Variant = source.get(id)
		var current: Variant = target.get(id)
		if weight<1:
			if value is float or value is Color or value is Vector3: value = lerp(current,value,weight)
			elif weight<.5: continue
		if current!=value: target.set(id,value)

func apply() -> void:
	if not is_instance_valid(_world) or profile==null: return
	var effective: Resource = profile
	var active: Array = []
	var camera := preview_camera if is_instance_valid(preview_camera) else get_viewport().get_camera_3d()
	if camera!=null:
		for volume in get_tree().get_nodes_in_group("postfx_volumes"):
			if scene_root.is_ancestor_of(volume) and volume.influence(camera.global_position)>0: active.append(volume)
	active.sort_custom(func(a,b): return a.priority<b.priority)
	if not active.is_empty():
		effective = profile.duplicate(true)
		for volume in active:
			var weight: float = volume.influence(camera.global_position)
			if not volume.overrides.is_empty():
				for key: String in volume.overrides:
					var value: Variant = volume.profile.get(key)
					var previous: Variant = effective.get(key)
					if value==null or previous==null: continue
					if value is float or value is Color or value is Vector3: effective.set(key,lerp(previous,value,weight))
					elif weight>=.5: effective.set(key,value)
				continue
			copy_properties(volume.profile.environment,effective.environment,weight)
			copy_properties(volume.profile.camera,effective.camera,weight)
			for row in Profile.schema(profile):
				var id: String = row[1]
				if "/" in id: continue
				var value: Variant = effective.get(id)
				effective.set(id,lerp(value,volume.profile.get(id),weight))
	if before:
		_world.environment = original_environment
		_world.camera_attributes = null
		for key: String in original_sun: _sun.set(key,original_sun[key])
	else:
		_world.environment = effective.environment
		_world.camera_attributes = effective.camera
		_sun.light_color = effective.sun_color
		_sun.light_energy = effective.sun_energy
		_sun.rotation_degrees = Vector3(effective.sun_elevation,effective.sun_azimuth,0)
	for entry in _lights:
		if not is_instance_valid(entry[0]): continue
		entry[0].light_energy = entry[1] if before else entry[1]*effective.lantern_multiplier
		entry[0].light_color = entry[2] if before else effective.lantern_color
	for id in ["temperature","tint","shadows","highlights","lift","gamma","gain","vignette","vignette_softness","sharpen","chromatic_aberration","grain","lens_distortion","effect_weight"]:
		grade_material.set_shader_parameter(id,0.0 if before and id=="effect_weight" else effective.get(id))

func _process(delta: float) -> void:
	_timer -= delta
	if _timer>0 or not is_instance_valid(scene_root): return
	_timer = .1
	var camera := preview_camera if is_instance_valid(preview_camera) else get_viewport().get_camera_3d()
	if camera==null: return
	var state := ""
	for volume in get_tree().get_nodes_in_group("postfx_volumes"):
		if scene_root.is_ancestor_of(volume):
			state += str(volume.get_instance_id())+":"+str(volume.priority)+":"+str(volume.overrides)+":"+str(snappedf(volume.influence(camera.global_position),.01))
			if volume.profile!=null:
				var values: Array = []
				for row in Profile.schema(volume.profile): values.append(volume.profile.get(row[1]))
				state += str(hash(values))
	if state!=_volume_state:
		_volume_state = state
		apply()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if event.is_action_pressed("postfx_studio"):
		toggle_window();get_viewport().set_input_as_handled()
	elif window!=null and window.visible and event.is_action_pressed("menu_back"):
		close_window();get_viewport().set_input_as_handled()

func toggle_window() -> void:
	if window!=null and window.visible:
		close_window();return
	if window==null:
		window = Window.new();window.title = "Свет и постобработка · F4 — закрыть";window.size = Vector2i(940,760)
		window.close_requested.connect(close_window);add_child(window)
		window.window_input.connect(func(event: InputEvent):
			if event.is_action_pressed("postfx_studio") or event.is_action_pressed("menu_back"): close_window())
		panel = make_panel();window.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var compare := CheckButton.new();compare.text = "До обработки (A/B)";panel.add_child(compare)
		compare.toggled.connect(func(value: bool): before=value;apply())
	_paused_before = get_tree().paused
	get_tree().paused = true
	window.popup_centered()
	panel.refresh()

func close_window() -> void:
	if window==null or not window.visible: return
	window.hide();get_tree().paused = _paused_before

func save_profile(path := SAVE_PATH) -> Error:
	return ResourceSaver.save(profile,path)

func reload_profile(path := SAVE_PATH) -> void:
	profile = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE).duplicate(true) if FileAccess.file_exists(path) else Profile.defaults()
	apply()

func preset(neutral := false) -> void:
	profile = Profile.defaults()
	if neutral:
		profile.environment = original_environment.duplicate(true)
		profile.sun_energy = original_sun.light_energy;profile.sun_color = original_sun.light_color
		profile.sun_elevation = original_sun.rotation_degrees.x;profile.sun_azimuth = original_sun.rotation_degrees.y
		profile.effect_weight = 0.0
	apply()
