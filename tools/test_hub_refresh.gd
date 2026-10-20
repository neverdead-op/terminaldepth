extends Node

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	var intro := player.get_parent()
	assert(is_equal_approx(intro.get_node("IntroGuardian").max_hp, intro.miniboss_life * 0.8))
	await Game.complete_zone(player)
	await get_tree().create_timer(1.0).timeout
	player.set_physics_process(false)
	player._using_mouse = true
	var hub := player.get_parent()
	for npc_name in ["Vendor", "VendorBases", "Workbench"]:
		var npc := hub.get_node(npc_name)
		assert(npc._label.get_meta("new_dialog", false))
		var meshes: Array[Node] = npc._model.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() >= 5)
		for mesh in meshes:
			assert(mesh.material_overlay == null)
		var key: String = npc.vendor_name if npc_name != "Workbench" else npc.NPC_NAME
		preload("res://scripts/npc_dialog.gd").mark_seen(key)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(not npc._label.get_meta("new_dialog", false))
	Game.dialog_seen.clear()
	Input.warp_mouse(Vector2(800, 360))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(800, 360)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.4).timeout
	for control in player.get_node("HUD").get_children():
		if control.get_script() == preload("res://scripts/hud_crosshair.gd"):
			assert(control.visible)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/hub_refresh.png")
		var camera := hub.get_node("CameraRig")
		camera.set_process(false)
		camera.set_physics_process(false)
		camera.camera.global_position = Vector3(-1.5, 6.5, 4)
		camera.camera.look_at(Vector3(-4.6, 1, -1.0))
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/hub_npcs_refresh.png")
	print("HUB_REFRESH_OK: dressed NPCs, hair, no overlays, dialog badges clear after reading, boss HP reduced")
	get_tree().quit()
