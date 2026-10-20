extends Node
## Проверка эффектов на настоящих объектах кампании, без новой игры и записи сохранений.

var _capture_enabled := false


func _ready() -> void:
	set_meta("test_runner", true)
	_capture_enabled = "--capture" in OS.get_cmdline_user_args()
	get_tree().create_timer(90).timeout.connect(func() -> void:
		push_error("GOTHIC_CAMPAIGN_FX_TIMEOUT")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	var player: Node3D = Game.start_test(1, &"normal")
	var zone := player.get_parent()
	player.set_physics_process(false)
	await get_tree().create_timer(0.8).timeout
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	assert(Game.testing and zone.scene_file_path == Game.INTRO_SCENE)
	var obelisks: Array = get_tree().get_nodes_in_group("quest_obelisk")
	assert(obelisks.size() == 2)
	var obelisk: Node3D = obelisks[0]
	var glow: Node3D = obelisk.get_node("GothicFx")
	assert(glow.active and obelisk._light.light_energy == 0.0)
	assert(obelisk._sprite.material_override is ShaderMaterial)
	player.global_position = obelisk.global_position + Vector3(0, 0, 2)
	await _capture("obelisk_active")
	get_tree().paused = true
	var clock: float = glow._clock
	await get_tree().create_timer(0.15, true).timeout
	assert(is_equal_approx(glow._clock, clock), "Эффекты должны останавливаться на паузе")
	get_tree().paused = false
	var dealt: float = obelisk.take_damage(obelisk.max_hp + 1.0, &"physical", player)
	assert(dealt > 0.0 and obelisk.destroyed and not glow.active)
	assert(obelisk.collision_layer == 0 and not obelisk.is_in_group("enemies"))
	await _capture("obelisk_destroyed")
	await get_tree().create_timer(0.8).timeout
	assert(glow._activation == 0.0)
	var tint: Color = obelisk._sprite.material_override.get_shader_parameter("sprite_tint")
	assert(tint.r < 0.4, "Разрушенный обелиск должен потемнеть и с новым шейдером")
	var ritual: Node3D = zone.get_node("VillageRitual")
	ritual.set_process(false)
	var ritual_fx: Node3D = ritual.get_node("GothicFx")
	assert(not ritual_fx.active and not ritual._rift.visible and not ritual._ring.visible)
	player.global_position = ritual.global_position + Vector3(0, 0, 4)
	ritual.interact(player)
	assert(ritual.running and ritual_fx.active and ritual._alive.size() == 4)
	for enemy in ritual._alive:
		enemy.set_physics_process(false)
	await _capture("ritual_active")
	for wave in ritual.waves.size():
		for enemy in ritual._alive:
			enemy.set_physics_process(false)
			enemy.take_damage(10000, &"physical", player)
		await get_tree().process_frame
		ritual._process(2.0)
	assert(ritual.destroyed and not ritual.running and not ritual_fx.active)
	await _capture("ritual_complete")
	await get_tree().create_timer(1.4).timeout
	assert(ritual_fx._activation == 0.0 and ritual_fx._burst == 1.0)
	assert(Game.testing)
	print("GOTHIC_CAMPAIGN_FX_OK: two obelisks, pause, destruction tint, ritual waves and completion")
	get_tree().quit()


func _capture(label: String) -> void:
	await get_tree().create_timer(0.8).timeout
	if not _capture_enabled:
		return
	DirAccess.make_dir_recursive_absolute("res://output/gothic_campaign_fx")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/gothic_campaign_fx/" + label + ".png")
