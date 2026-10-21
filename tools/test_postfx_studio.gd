extends Node
const Profile := preload("res://scripts/postfx_profile.gd")
const Volume := preload("res://scripts/postfx_volume.gd")
const TEMP := "res://ztest/postfx_roundtrip_20261021.tres"

func _ready() -> void:
	set_meta("test_runner",true)
	run.call_deferred()

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/"+name+".png")

func run() -> void:
	var player := Game.start_test(1,&"normal","res://scenes/art/riverbank_blockout.tscn",{"fixed_bow_loadout":false,"start_weapon":&"rifle"})
	var zone := player.get_parent()
	await get_tree().create_timer(1).timeout
	var studio: Node = zone.get_node("PostFXStudio")
	var world: WorldEnvironment = zone.get_node("Lighting/RiverbankEnvironment/WorldEnvironment")
	var saved: Resource = studio.profile.duplicate(true)
	player.set_physics_process(false)
	player.position = Vector3(-30,.1,-54)
	zone.get_node("CameraRig").position = player.position
	studio.before = true;studio.apply()
	await shot("postfx_before")
	studio.before = false;studio.apply()
	await shot("postfx_after")
	var detail := Camera3D.new()
	zone.add_child(detail);detail.position = Vector3(-17,10,-38);detail.look_at(Vector3(-22,0,-48));detail.fov=45;detail.make_current()
	await shot("terrain_transition_detail")
	detail.queue_free();zone.get_node("CameraRig/Camera3D").make_current()
	var open_event := InputEventAction.new();open_event.action="postfx_studio";open_event.pressed=true
	Input.parse_input_event(open_event)
	await get_tree().process_frame
	assert(studio.window.visible and get_tree().paused)
	var panel: Control = studio.panel
	assert(panel.controls.size()>90,"Missing native controls")
	panel.controls["env/tonemap_exposure"][0].value = 1.25
	panel.controls["env/glow_enabled"].button_pressed = false
	panel.controls["temperature"][0].value = .25
	assert(is_equal_approx(world.environment.tonemap_exposure,1.25) and not world.environment.glow_enabled)
	assert(is_equal_approx(studio.grade_material.get_shader_parameter("temperature"),.25))
	assert(not FileAccess.file_exists(TEMP))
	assert(studio.save_profile(TEMP)==OK)
	studio.preset(true)
	studio.reload_profile(TEMP)
	assert(is_equal_approx(studio.profile.get("env/tonemap_exposure"),1.25))
	assert(DirAccess.remove_absolute(TEMP)==OK)
	# Пауза восстанавливается и при открытии окна поверх уже поставленной паузы.
	studio.close_window();assert(not get_tree().paused)
	get_tree().paused = true
	studio.toggle_window();studio.close_window();assert(get_tree().paused)
	get_tree().paused = false
	var volume := Volume.new()
	volume.profile = Profile.defaults()
	volume.profile.environment.tonemap_exposure = 2.0
	volume.size = Vector3(10,10,10);volume.blend_radius=5
	zone.add_child(volume)
	assert(is_equal_approx(volume.influence(Vector3.ZERO),1.0))
	assert(is_equal_approx(volume.influence(Vector3(7.5,0,0)),.5))
	assert(is_zero_approx(volume.influence(Vector3(11,0,0))))
	var camera: Camera3D = zone.get_node("CameraRig/Camera3D")
	volume.global_position = camera.global_position
	studio.apply();assert(is_equal_approx(world.environment.tonemap_exposure,2.0))
	var higher := Volume.new();higher.profile=Profile.defaults();higher.priority=10;higher.blend_weight=.5
	higher.profile.environment.tonemap_exposure=1.5;higher.overrides=PackedStringArray(["env/tonemap_exposure"])
	zone.add_child(higher);higher.global_position=camera.global_position
	studio.apply();assert(is_equal_approx(world.environment.tonemap_exposure,1.75))
	assert(world.environment.glow_enabled)
	higher.enabled=false;higher.queue_free()
	volume.enabled = false;studio.profile = saved;studio.apply()
	assert(not is_equal_approx(world.environment.tonemap_exposure,2.0))
	volume.queue_free()
	studio.before=true;studio.apply();assert(world.environment==studio.original_environment)
	studio.before=false;studio.apply()
	studio.toggle_window()
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.5,true).timeout
		await RenderingServer.frame_post_draw
		studio.window.get_texture().get_image().save_png("res://docs/art_direction/riverbank/postfx_panel.png")
	studio.close_window()
	player.position = Vector3(34.5,.1,-48)
	zone.get_node("CameraRig").position = player.position
	await shot("postfx_garden")
	print("POSTFX_STUDIO_OK: ",panel.controls.size()," live controls; env/camera/grade; roundtrip; pause restore; A/B; box falloff; volume blend; no campaign saves")
	get_tree().quit()
