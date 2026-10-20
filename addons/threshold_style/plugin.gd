@tool
extends EditorPlugin
var panel: VBoxContainer
var viewport_grades: Array[CanvasLayer] = []
var reported := false

func _enter_tree() -> void:
	panel = preload("res://addons/threshold_style/style_panel.gd").new()
	add_control_to_bottom_panel(panel,"Стиль сцены")
	var open_button := Button.new();open_button.text = "Открыть композицию"
	panel.add_child(open_button)
	open_button.pressed.connect(func(): get_editor_interface().open_scene_from_path("res://scenes/art/threshold_composition.tscn"))
	var run_button := Button.new();run_button.text = "Запустить игровой тест · F1 — окно стиля"
	panel.add_child(run_button)
	run_button.pressed.connect(func(): get_editor_interface().play_custom_scene("res://scenes/tools/threshold_preview.tscn"))
	scene_changed.connect(_scene_changed)
	_scene_changed.call_deferred(get_editor_interface().get_edited_scene_root())

func _scene_changed(scene: Node) -> void:
	panel.bind(scene.get_node_or_null("LookController") if scene != null else null)
	_clear_viewport_grades()
	if is_instance_valid(panel.target): _attach_viewport_grades.call_deferred(scene)

func _attach_viewport_grades(scene: Node) -> void:
	if not is_instance_valid(scene) or not is_instance_valid(panel.target): return
	var material: Material = scene.get_node("WorldGrade/ColorGrade").material
	for index in 4:
		var viewport := get_editor_interface().get_editor_viewport_3d(index)
		var layer := CanvasLayer.new();layer.layer = -10;viewport.add_child(layer)
		var rect := ColorRect.new();rect.mouse_filter = Control.MOUSE_FILTER_IGNORE;rect.material = material
		layer.add_child(rect);rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport_grades.append(layer)
	if "--style-editor-check" in OS.get_cmdline_user_args():
		assert(panel.controls.size()==32 and viewport_grades.size()==4)
		print("EDITOR_STYLE_READY: 32 controls bound, 4 editor viewport grades")

func _process(_delta: float) -> void:
	if is_instance_valid(panel) and is_instance_valid(panel.target):
		var scene: Node = panel.target.get_parent()
		var fog := scene.get_node_or_null("FluffyFog")
		if fog != null: fog.preview_camera = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()

func _clear_viewport_grades() -> void:
	for layer in viewport_grades:
		if is_instance_valid(layer): layer.queue_free()
	viewport_grades.clear()

func _exit_tree() -> void:
	_clear_viewport_grades()
	if is_instance_valid(panel):
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
