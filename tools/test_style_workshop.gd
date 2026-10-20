extends Node

func _ready() -> void:
	set_meta("test_runner",true)
	_run.call_deferred()

func _shot(viewport: Viewport, name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://docs/screens/"+name+".png")

func _run() -> void:
	var player := Game.start_test(1,&"normal","res://scenes/art/threshold_composition.tscn")
	var zone: Node3D = player.get_parent()
	await get_tree().create_timer(3).timeout
	var controller: Node = zone.get_node("LookController")
	assert(controller.materials.size()>0)
	assert(zone.find_children("VolumeBillow*","FogVolume",true,false).size()==3)
	for visual in get_tree().get_nodes_in_group("threshold_lantern_visuals"):
		assert(visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(is_equal_approx(zone.get_node("FluffyFog").density,controller.profile.courtyard_fog))
	var original: Resource = controller.profile.duplicate(true)
	if "--capture" in OS.get_cmdline_user_args(): await _shot(get_viewport(),"threshold_style_soft")
	zone.open_style_window()
	await get_tree().process_frame
	assert(zone.style_window.visible and not player.is_physics_processing())
	var panel: Control = zone.style_window.get_child(0)
	assert(panel.controls.size()==32)
	panel.controls["cel_enabled"].button_pressed = true
	panel.controls["cel_steps"][0].value = 3
	panel.controls["exposure"][0].value = 1.2
	assert(controller.profile.cel_enabled and controller.profile.cel_steps==3)
	assert(is_equal_approx(zone.get_node("WorldEnvironment").environment.tonemap_exposure,1.2))
	for material in controller.materials: assert(material.shader.resource_path.ends_with("threshold_cel.gdshader"))
	if "--capture" in OS.get_cmdline_user_args(): await _shot(zone.style_window,"threshold_style_window")
	assert(controller.save_profile("user://threshold_style_test.tres")==OK)
	controller.preset(false)
	assert(not controller.profile.cel_enabled)
	controller.reload_profile("user://threshold_style_test.tres")
	assert(controller.profile.cel_enabled and controller.profile.cel_steps==3)
	DirAccess.remove_absolute("user://threshold_style_test.tres")
	zone.close_style_window()
	assert(not zone.style_window.visible and player.is_physics_processing())
	controller.preset(true)
	await get_tree().create_timer(0.8).timeout
	if "--capture" in OS.get_cmdline_user_args(): await _shot(get_viewport(),"threshold_style_cel")
	controller.profile = original;controller.apply()
	# Real close view of the formerly self-shadowed lantern and adjacent wall.
	var camera := zone.get_node("OverviewCamera") as Camera3D
	camera.position = Vector3(-2,7,4);camera.look_at(Vector3(-7,1,-4.5));camera.fov = 45
	await get_tree().process_frame
	if "--capture" in OS.get_cmdline_user_args(): await _shot(get_viewport(),"threshold_lantern_shadow_fixed")
	print("STYLE_WORKSHOP_OK: 32 live controls, actual cel shader, exposure, profile disk roundtrip, presets, body input restore, 3 fog volumes, lantern shadow proxies")
	get_tree().quit()
