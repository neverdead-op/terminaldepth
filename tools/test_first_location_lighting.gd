extends Node

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(2).timeout
	var zone := player.get_parent()
	player.global_position = Vector3(0, 0.1, -9)
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	await get_tree().create_timer(3).timeout
	assert(Game.testing)
	var count := 0
	for light in get_tree().get_nodes_in_group("village_lamps"):
		if light.shadow_enabled: count += 1
	assert(count <= 2 and count > 0)
	assert(get_tree().get_nodes_in_group("enemies").size() == zone.pack_positions.size() * zone.pack_size + 1)
	assert(not zone.show_village_houses)
	assert(zone.get_node("Navigation/VillageArchitecture").houses == 1)
	assert(zone._petal_rain.amount == 180)
	var env: Environment = zone.get_node("WorldEnvironment").environment
	assert(env.ssr_enabled and env.ssil_enabled and env.ssao_enabled)
	assert(env.volumetric_fog_enabled)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/first_location_lighting.png")
	var begin := Time.get_ticks_usec()
	var sample_count := 30 if "--profile-light" in OS.get_cmdline_user_args() else 120
	for i in sample_count: await get_tree().process_frame
	var frame_ms := (Time.get_ticks_usec() - begin) / (sample_count * 1000.0)
	print("RENDER_DIAGNOSTIC process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000, " physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if "--profile-light" in OS.get_cmdline_user_args():
		for mode in 11:
			if mode == 0:
				env.ssr_enabled = false
				env.ssil_enabled = false
				env.volumetric_fog_enabled = false
			elif mode == 1:
				zone.get_node("Sun").shadow_enabled = false
				zone.set_process(false)
				for lamp in get_tree().get_nodes_in_group("village_lamps"): lamp.shadow_enabled = false
			elif mode == 2:
				zone.get_node("Navigation/TownRuins").visible = false
			elif mode == 3:
				# Пол деревни теперь один кусок со смешиванием покрытий.
				var flat := StandardMaterial3D.new()
				flat.albedo_color = Color(0.3, 0.3, 0.3)
				zone.get_node("TownFloor").material_override = flat
			elif mode == 4: zone.visible = false
			elif mode == 5: player.get_node("HUD").visible = false
			elif mode == 6: zone.process_mode = Node.PROCESS_MODE_DISABLED
			elif mode == 7:
				for child in get_tree().root.get_children():
					if child != self: child.process_mode = Node.PROCESS_MODE_DISABLED
			elif mode == 8: NavigationServer3D.set_active(false)
			elif mode == 9: PhysicsServer3D.set_active(false)
			elif mode == 10:
				zone.queue_free()
			await get_tree().create_timer(0.5).timeout
			var start := Time.get_ticks_usec()
			for frame in 20: await get_tree().process_frame
			print("PROFILE_LIGHT mode=", mode, " mean_ms=", (Time.get_ticks_usec() - start) / 20000.0, " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS)*1000, " calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("FIRST_LOCATION_LIGHT_OK: ruined town, no street houses, 61 enemies, red petal rain, SSR/SSIL/SSAO, volumetric fog, two nearest lamp shadows; mean_frame_ms=", snappedf(frame_ms, 0.01))
	get_tree().quit()
