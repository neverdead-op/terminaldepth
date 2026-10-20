extends Node
func _ready() -> void:
	set_meta("test_runner",true)
	_run.call_deferred()
func _run() -> void:
	var player := Game.start_test(1,&"normal","res://scenes/art/threshold_composition.tscn")
	var zone: Node3D = player.get_parent()
	await get_tree().create_timer(3).timeout
	assert(Game.testing)
	assert(zone.get_node("FluffyFog").cards.size()==16)
	var fog_image := (load("res://assets/environment/threshold_fog/v1/fog_cloud.png") as Texture2D).get_image()
	if fog_image.is_compressed(): fog_image.decompress()
	assert(fog_image.detect_alpha()!=Image.ALPHA_NONE)
	assert(get_tree().get_nodes_in_group("threshold_skyline").size()==16)
	assert(zone.get_node("WorldGrade").layer < player.get_node("HUD").layer)
	assert(zone.get_node("WorldGrade/ColorGrade").size.x >= get_viewport().get_visible_rect().size.x-1)
	assert(player.is_on_floor(),"Player must stand on the courtyard")
	assert(zone.get_node("Navigation").navigation_mesh.get_polygon_count()>0)
	var chains := zone.find_children("*","MultiMeshInstance3D",true,false)
	assert(chains.size()==5)
	for chain: MultiMeshInstance3D in chains:
		assert(chain.multimesh.get_instance_transform(5).origin.y < -4,"Chain transforms must survive scene save/reload")
	var map: RID = zone.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map,Vector3(0,.1,2),Vector3(-5,.1,-4),true)
	assert(path.size()>1 and path[-1].distance_to(Vector3(-5,.1,-4))<1.0)
	var stairs := NavigationServer3D.map_get_path(map,Vector3(0,.1,3),Vector3(0,-1.5,13),true)
	assert(stairs.size()>1 and stairs[-1].distance_to(Vector3(0,-1.5,13))<1.0,"Entry stair must be connected")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/threshold_overview.png")
		zone.enable_color_grade = false
		zone._apply_grade()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/threshold_grade_off.png")
		zone.enable_color_grade = true
		zone._apply_grade()
	zone.overview = false
	zone._apply_camera()
	await get_tree().create_timer(1).timeout
	assert(zone.get_node("CameraRig/Camera3D").current)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/threshold_gameplay.png")
	var key := InputEventKey.new();key.pressed = true;key.keycode = KEY_F5
	zone._unhandled_key_input(key)
	assert(not zone.get_node("WorldGrade").visible)
	zone._unhandled_key_input(key)
	assert(zone.get_node("WorldGrade").visible)
	key.keycode = KEY_F3
	zone._unhandled_key_input(key)
	assert(zone.get_node("WorldEnvironment").environment.volumetric_fog_density == 0.0)
	assert(not zone.get_node("FluffyFog").enabled)
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/threshold_gameplay_fog_off.png")
	zone._unhandled_key_input(key)
	assert(zone.get_node("WorldEnvironment").environment.volumetric_fog_density > 0.0)
	key.keycode = KEY_F4
	zone._unhandled_key_input(key)
	assert(get_tree().get_nodes_in_group("enemies").size()==3)
	zone._unhandled_key_input(key)
	assert(get_tree().get_nodes_in_group("enemies").size()==3,"No repeated enemy spawning")
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var start := Time.get_ticks_usec()
	for i in 30: await get_tree().process_frame
	print("THRESHOLD_TEST_OK: no saves, grounded player, stair paths, cameras, 16 skyline buildings, 16 alpha fog cards, grade below HUD, F3/F5 toggles, 3 enemies; mean_frame_ms=",(Time.get_ticks_usec()-start)/30000.0)
	get_tree().quit()
