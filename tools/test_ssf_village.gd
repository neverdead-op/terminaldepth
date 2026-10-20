extends Node
## Проверка SSF, расширения деревни и четырёх активностей. Обычный запуск не пишет сохранения.

func _ready() -> void:
	set_meta("test_runner", true)
	get_tree().create_timer(90).timeout.connect(func(): push_error("SSF_VILLAGE_TIMEOUT"); get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	var player: Node3D
	if "--menu-start" in OS.get_cmdline_user_args():
		assert("ssf_test_user" in OS.get_user_data_dir().replace("\\", "/"), "Menu test requires isolated APPDATA")
		var menu: Control = load(Game.MAIN_MENU).instantiate()
		get_tree().root.add_child(menu)
		get_tree().current_scene = menu
		menu._open_page(&"new")
		menu._cursor = 0
		menu._accept()
		player = Game.player
		assert(Game.SaveGame.exists())
		Game.testing = true
	else:
		player = Game.start_test(1, &"normal")
	var zone: Node3D = player.get_parent()
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for attempt in 1200:
		await get_tree().physics_frame
		if NavigationServer3D.region_get_iteration_id(zone.get_node("Navigation").get_rid()) > 0: break
	await get_tree().create_timer(0.8).timeout
	assert(Game.testing and Game.mode == &"normal" and zone.scene_file_path == Game.INTRO_SCENE)
	# SSF начинается с коломётом и дробовиком (пистолет убран); огненный камень — из первого сундука.
	assert(not player.fixed_bow_loadout and player.weapon_item(0).base.id == &"rifle" and player.weapon_item(1).base.id == &"shotgun")
	assert(player.get_node("Model").animation_library_path == "res://assets/animations/model1_shooter.tres")
	assert(player.current_ammo() == player.current_magazine_size())
	# Новый план (village_route_plan.gd): площадь в клетках 2×2 м.
	var ratio: float = zone._count_floor_cells() * 4.0
	print("SSF_AREA_M2 ", ratio)
	assert(ratio >= 6000.0)
	var composition := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			var kind: String = enemy.get_script().resource_path.get_file().get_basename()
			composition[kind] = composition.get(kind, 0) + 1
			if enemy.name != "IntroGuardian": assert(enemy.drops_enabled)
	assert(composition.size() >= 5 and composition.has("necromancer"))
	assert(composition.values().reduce(func(a, b): return a + b, 0) == zone.pack_positions.size() * zone.pack_size + 1)
	var quests: Node = zone.get_node("Quests")
	assert(quests.quests.size() == 4)
	print("SSF_START_OK stake gun + shotgun, full magazine; area_m2=", ratio, " enemies=", composition)
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("ssf_village_start")
	var chests: Array = get_tree().get_nodes_in_group("chests").filter(func(n): return zone.is_ancestor_of(n))
	assert(chests.size() == 4)
	var rifle: GearItem = player.weapon_item(0)
	var shotgun: GearItem = player.weapon_item(1)
	var fire_chest: Node
	for chest in chests:
		if chest.guaranteed_modules.any(func(m): return m.id == &"fire"): fire_chest = chest
	assert(fire_chest != null and chests.all(func(c): return c.guaranteed_base == &"" and not c._opened))
	fire_chest.interact(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var fire_module: ModuleData
	for pickup in get_tree().get_nodes_in_group("loot"):
		if pickup.kind == &"module" and pickup.module.id == &"fire":
			fire_module = pickup.module
			assert(pickup.pick(player))
	assert(fire_module != null)
	rifle.modules[0] = fire_module
	player._on_modules_changed()
	assert(player.weapon_stats(0).ammo == &"fire")
	var map: RID = zone.get_world_3d().navigation_map
	for rect in zone.landmark_rects:
		var at := Vector3(rect.get_center().x, 0, rect.get_center().y)
		_assert_path(map, Vector3(0, 0, 8), at)
		player.global_position = at + Vector3.UP * 0.1
		zone._landmark_check = 0
		zone._clock = 0
		zone._process(0.5)
	for chest in chests:
		_assert_path(map, player.global_position, chest.global_position)
		if not chest._opened: chest.interact(player)
	for obelisk in get_tree().get_nodes_in_group("quest_obelisk"):
		_assert_path(map, player.global_position, obelisk.global_position + Vector3(2, 0, 0))
		obelisk.take_damage(10000, &"physical", player)
	var ritual: Node3D = zone.get_node("VillageRitual")
	_assert_path(map, player.global_position, ritual.global_position)
	player.global_position = ritual.global_position + Vector3(0, 0, 5)
	ritual.interact(player)
	assert(ritual.running and ritual._alive.size() == 4)
	for enemy in ritual._alive: enemy.set_physics_process(false)
	if "--capture" in OS.get_cmdline_user_args(): await _capture("ssf_village_ritual")
	# Таймер не закрывает ритуал, пока волна жива.
	ritual._process(35)
	assert(ritual._wave == 0 and not ritual.destroyed)
	for wave in ritual.waves.size():
		for enemy in ritual._alive:
			enemy.set_physics_process(false)
			enemy.take_damage(10000, &"physical", player)
		await get_tree().process_frame
		ritual._process(2.0)
	assert(ritual.destroyed and not ritual.running)
	await get_tree().create_timer(0.7).timeout
	assert(quests.quests.all(func(q): return q.finished and not q.get("failed", false)))
	_assert_path(map, Vector3(0, 0, 8), Vector3(0, 0, -241))
	zone.get_node("IntroGuardian").take_damage(100000, &"physical", player)
	await Game.complete_zone(player)
	assert(Game.in_hub() and Game.floor_number == 2)
	assert(player.weapon_item(0) == rifle and player.weapon_item(1) == shotgun)
	assert(player.weapon_stats(0).ammo == &"fire")
	print("SSF_VILLAGE_OK stake gun + shotgun start, fire chest, four activities, ritual waves, tavern and preserved gear")
	get_tree().quit()


func _assert_path(map: RID, from: Vector3, to: Vector3) -> void:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	assert(path.size() >= 2 and path[-1].distance_to(to) < 1.5, "Unreachable activity: " + str(to))


func _capture(label: String) -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/" + label + ".png")
