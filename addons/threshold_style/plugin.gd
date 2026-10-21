@tool
extends EditorPlugin
var panel: VBoxContainer
var viewport_grades: Array[CanvasLayer] = []
var reported := false
var postfx_gizmo: EditorNode3DGizmoPlugin

func _enter_tree() -> void:
	postfx_gizmo = preload("res://addons/threshold_style/postfx_volume_gizmo.gd").new()
	add_node_3d_gizmo_plugin(postfx_gizmo)
	add_custom_type("PostFXVolume3D","Node3D",preload("res://scripts/postfx_volume.gd"),get_editor_interface().get_base_control().get_theme_icon("Area3D","EditorIcons"))
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
	_clear_viewport_grades()
	var studio: Node = scene.get_node_or_null("PostFXStudio") if scene!=null else null
	if is_instance_valid(panel):
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
	panel = studio.make_panel() if studio!=null else preload("res://addons/threshold_style/style_panel.gd").new()
	add_control_to_bottom_panel(panel,"Стиль сцены")
	panel.bind(studio if studio!=null else scene.get_node_or_null("LookController") if scene!=null else null)
	var actions := HFlowContainer.new();panel.add_child(actions)
	var open := Button.new();open.text = "Открыть Riverbank";actions.add_child(open)
	open.pressed.connect(func(): get_editor_interface().open_scene_from_path("res://scenes/art/riverbank_blockout.tscn"))
	var run := Button.new();run.text = "Запустить Riverbank · F8 / L3 — свет";actions.add_child(run)
	run.pressed.connect(func(): get_editor_interface().play_custom_scene("res://scenes/tools/riverbank_playtest.tscn"))
	if studio==null:
		var legacy_open := Button.new();legacy_open.text="Открыть композицию Threshold";actions.add_child(legacy_open)
		legacy_open.pressed.connect(func(): get_editor_interface().open_scene_from_path("res://scenes/art/threshold_composition.tscn"))
		var legacy_run := Button.new();legacy_run.text="Запустить Threshold · F1 — стиль";actions.add_child(legacy_run)
		legacy_run.pressed.connect(func(): get_editor_interface().play_custom_scene("res://scenes/tools/threshold_preview.tscn"))
	if studio!=null:
		var add_volume := Button.new();add_volume.text = "Добавить локальную PostFX-зону";actions.add_child(add_volume)
		add_volume.pressed.connect(func():
			var volume := preload("res://scripts/postfx_volume.gd").new()
			volume.name = "PostFXVolume"
			volume.profile = studio.profile.duplicate(true)
			volume.position = Vector3(0,10,-60)
			var undo := get_undo_redo()
			undo.create_action("Добавить PostFX-зону")
			undo.add_do_method(scene,"add_child",volume,true)
			undo.add_do_property(volume,"owner",scene)
			undo.add_undo_method(scene,"remove_child",volume)
			undo.add_do_reference(volume)
			undo.commit_action()
			get_editor_interface().edit_node(volume))
		var compare := CheckButton.new();compare.text = "До обработки (A/B)";actions.add_child(compare)
		compare.toggled.connect(func(value: bool): studio.before=value;studio.apply())
		for entry in [["Все параметры Environment","environment"],["Все параметры камеры","camera"]]:
			var button := Button.new();button.text=entry[0];actions.add_child(button)
			var property: String=entry[1]
			button.pressed.connect(func(): get_editor_interface().inspect_object(studio.profile.get(property)))
		var profile_button := Button.new();profile_button.text = "Профиль целиком / Save As…";actions.add_child(profile_button)
		profile_button.pressed.connect(func(): get_editor_interface().inspect_object(studio.profile))
	if is_instance_valid(panel.target): _attach_viewport_grades.call_deferred(scene)

func _attach_viewport_grades(scene: Node) -> void:
	if not is_instance_valid(scene) or not is_instance_valid(panel.target): return
	var studio := scene.get_node_or_null("PostFXStudio")
	var material: Material = studio.grade_material if studio!=null else scene.get_node("WorldGrade/ColorGrade").material
	for index in 4:
		var viewport := get_editor_interface().get_editor_viewport_3d(index)
		var layer := CanvasLayer.new();layer.layer = -10;viewport.add_child(layer)
		var rect := ColorRect.new();rect.mouse_filter = Control.MOUSE_FILTER_IGNORE;rect.material = material
		layer.add_child(rect);rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport_grades.append(layer)
	if "--style-editor-check" in OS.get_cmdline_user_args():
		assert(panel.controls.size()==32 and viewport_grades.size()==4)
		print("EDITOR_STYLE_READY: 32 controls bound, 4 editor viewport grades")
	if studio!=null and "--postfx-editor-check" in OS.get_cmdline_user_args():
		assert(panel.controls.size()>90 and viewport_grades.size()==4)
		make_bottom_panel_item_visible(panel)
		while get_editor_interface().get_resource_filesystem().is_scanning():
			await get_tree().create_timer(1.0).timeout
		await get_tree().create_timer(12.0).timeout
		await RenderingServer.frame_post_draw
		get_editor_interface().get_base_control().get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/postfx_editor.png")
		print("EDITOR_POSTFX_READY: ",panel.controls.size()," controls, 4 viewport grades")
		get_tree().quit()

func _process(_delta: float) -> void:
	if is_instance_valid(panel) and is_instance_valid(panel.target):
		var scene: Node = panel.target.get_parent()
		if scene.has_node("PostFXStudio"):
			panel.target.preview_camera = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
		var fog := scene.get_node_or_null("FluffyFog")
		if fog != null: fog.preview_camera = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()

func _clear_viewport_grades() -> void:
	for layer in viewport_grades:
		if is_instance_valid(layer): layer.queue_free()
	viewport_grades.clear()

func _exit_tree() -> void:
	remove_custom_type("PostFXVolume3D")
	if postfx_gizmo!=null: remove_node_3d_gizmo_plugin(postfx_gizmo)
	_clear_viewport_grades()
	if is_instance_valid(panel):
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
