extends Node
const ItemDB := preload("res://scripts/item_db.gd")
## Проверка старта, экипировки, независимых модулей, сохранения и переходов без записи забега.

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()


func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(1.0).timeout
	assert(Game.in_intro())
	var camera: Node3D = player.get_parent().get_node("CameraRig")
	assert(camera._target == player)
	assert(is_equal_approx(camera.camera.fov, 50.0))
	assert(get_tree().get_nodes_in_group("enemies").size() == player.get_parent().pack_positions.size() * player.get_parent().pack_size + 1)
	var path := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, player.global_position, Vector3(0, 0, -241), true)
	assert(path.size() >= 10)
	assert(path[path.size() - 1].distance_to(Vector3(0, 0, -241)) < 1)
	var crawler: Enemy
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.name != "IntroGuardian":
			crawler = enemy
			break
	var shot: float = player.weapon_stats(0).damage
	assert(crawler.hp > shot and crawler.hp <= shot * 3)
	var intro: Node3D = player.get_parent()
	assert(is_instance_valid(intro._training_gate))
	var shotgun := GearItem.create(ItemDB.base_by_id(&"shotgun"), 1, 0)
	player.inventory.add_item(shotgun)
	assert(player.inventory.equip_weapon(shotgun, 1) == "")
	await get_tree().create_timer(0.4).timeout
	assert(not is_instance_valid(intro._training_gate))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/onboarding_surface.png")
	assert(player.weapon_item(0) != null)
	assert(player.inventory.weapons.size() == 2 and player.weapon_item(1) == shotgun)
	assert(not player.get_node("Skills").has_grenade())
	var rifle := GearItem.create(ItemDB.base_by_id(&"rifle"), 1, 0)
	player.inventory.add_item(rifle)
	assert(player.inventory.equip_weapon(rifle, 1) == "")
	player.select_weapon(1)
	assert(player.get_node("Skills").has_grenade())
	var damage := preload("res://data/modules/damage.tres")
	player.inventory.add_item(damage)
	assert(player.insert_module(1, rifle.sockets + 1, damage) == "")
	assert(rifle.secondary_modules[1] == damage and rifle.modules[1] == null)
	var save_script := preload("res://scripts/save_game.gd")
	var restored: GearItem = save_script._item_from(save_script._item_to(rifle))
	assert(restored.secondary_modules[1] == damage)
	var cutter := GearItem.create(ItemDB.base_by_id(&"plasma_cutter"), 1, 0)
	assert(player.inventory.add_item(cutter))
	assert(player.inventory.equip_weapon(cutter, 0) == "")
	player.select_weapon(0)
	assert(player.get_node("Skills").has_pulse())
	player.select_weapon(1)
	var screen: Control = player.get_node("HUD").inventory_screen
	screen.open_context(&"", null)
	await get_tree().process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/onboarding_inventory.png")
	screen._toggle()
	var boss: Enemy = player.get_parent().get_node("IntroGuardian")
	intro._summon(boss)
	assert(get_tree().get_nodes_in_group("intro_reinforcements").size() == 3)
	boss.take_damage(100000, &"physical", player)
	assert(player.level == 2 and player.passive_points > 0)
	await Game.complete_zone(player)
	assert(Game.in_hub() and Game.floor_number == 2)
	assert(player.get_node("Model").find_children("*", "Skeleton3D", true, false).size() == 1)
	var vendor := get_tree().get_first_node_in_group("interactables")
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.get("vendor_name") != null:
			vendor = n
			break
	preload("res://scripts/npc_conversation.gd").show_for(player, vendor, "Angie")
	await get_tree().process_frame
	var hud: Node = player.get_node("HUD")
	var conversation := hud.get_child(hud.get_child_count() - 1)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/onboarding_dialogue.png")
	conversation._opening_until = 0
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	conversation._input(right)
	assert(get_viewport().gui_get_focus_owner().text == Loc.t("Купить или продать"))
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	conversation._input(accept)
	assert(screen.visible and screen._context == &"vendor")
	screen._toggle()
	await Game.return_to_zone()
	assert(Game.floor_number == 2 and player.get_parent().zone_level == 2)
	assert(player.get_node("Model").find_children("*", "Skeleton3D", true, false).size() == 1)
	await get_tree().create_timer(1).timeout
	var current_zone := player.get_parent()
	for attempt in 600:
		if not get_tree().get_nodes_in_group("extra_population").is_empty():
			break
		await get_tree().physics_frame
	print("POPULATION_READY: ", current_zone._population_applied, " added=", get_tree().get_nodes_in_group("extra_population").size())
	assert(not get_tree().get_nodes_in_group("extra_population").is_empty())
	assert(is_equal_approx(current_zone.enemy_life_scale, 0.66))
	assert(current_zone.get_meta("population_xp_budget") == current_zone.get_meta("population_xp_total"))
	var probe: Enemy = preload("res://scenes/crawler.tscn").instantiate()
	var base_life := probe.max_hp
	current_zone.add_child(probe)
	assert(is_equal_approx(probe.max_hp, base_life * probe.health_scale * (1 + probe.hp_per_level) * 0.66))
	print("BALANCE_OK: floor2 life=", probe.max_hp, " cutter_hits=", ceili(probe.max_hp / player.weapon_stats(0).damage), " extra_enemies=", get_tree().get_nodes_in_group("extra_population").size())
	probe.queue_free()
	if "--population-only" in OS.get_cmdline_user_args():
		assert(is_equal_approx(current_zone.extra_enemy_ratio, 0.5))
		print("POPULATION_BALANCE_OK: intro route and gate, equipment, boss level-up, hub, floor2 density, HP, exact XP budget")
		get_tree().quit()
		return
	var quests := get_tree().get_first_node_in_group("zone_quests")
	assert(quests.quests.size() == 2)
	for q in quests.quests:
		assert(q.id in [&"allies", &"escort"])
		assert(q.reward_loot != q.reward_xp)
	var xp_before: int = player.xp
	for q in quests.quests:
		if q.id == &"escort":
			quests._reward(q)
	assert(player.xp == xp_before)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/onboarding_quests.png")
	await Game.complete_zone(player)
	assert(Game.floor_number == 3)
	await Game.return_to_zone()
	await get_tree().create_timer(0.7).timeout
	quests = get_tree().get_first_node_in_group("zone_quests")
	assert(quests.quests.size() == 2)
	for q in quests.quests:
		assert(q.reward_xp)
	quests.robot_xp_levels = 2.0
	var level_before: int = player.level
	for q in quests.quests:
		if q.id == &"allies":
			quests._reward(q)
	assert(player.level == mini(level_before + 2, 5))
	if "--capture" in OS.get_cmdline_user_args():
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		layer.add_child(preload("res://tools/icon_gallery.gd").new())
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/onboarding_icons.png")
		layer.queue_free()
	var pause: Node
	for child in screen.get_parent().get_children():
		if child.get_script() == preload("res://scripts/pause_menu.gd"):
			pause = child
	assert(pause != null)
	pause._open()
	assert(pause._item_at(pause._p(Vector2(640, 172 + 6 * 56))))
	assert(pause._cursor == 6)
	pause._accept()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(get_tree().current_scene.scene_file_path == Game.MAIN_MENU)
	print("ONBOARDING_OK: intro, equipment, independent modules, save roundtrip, level up, hub, dialogue, floor 2 quests")
	get_tree().quit()
