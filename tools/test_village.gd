extends Node

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(2).timeout
	var intro := player.get_parent()
	assert(intro.get_node("Navigation/VillageArchitecture").houses == 1)
	assert(not intro.show_village_houses)
	assert(get_tree().get_nodes_in_group("enemies").size() == intro.pack_positions.size() * intro.pack_size + 1)
	assert(intro._floor_cell_counts.all(func(n): return n > 0))
	assert(intro.get_node("Navigation/TownRuins").corpse_count == 50)
	assert(intro.get_node("Navigation/TownRuins").hanging_count == 6)
	var path := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, player.global_position, Vector3(0, 0, -241), true)
	assert(path.size() >= 10)
	assert(path[path.size() - 1].distance_to(Vector3(0, 0, -241)) < 1)
	# Navigation must respect each new narrow gate, not cut through its side piers.
	for gate_at in [Vector3(-12, 0, -34), Vector3(8, 0, -68), Vector3(-6, 0, -166)]:
		var through := NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, gate_at + Vector3(0, 0, 4), gate_at - Vector3(0, 0, 4), true)
		assert(through.size() >= 2)
		assert(through[through.size() - 1].distance_to(gate_at - Vector3(0, 0, 4)) < 1)
		for point in through:
			if absf(point.z - gate_at.z) < 0.6: assert(absf(point.x - gate_at.x) < 2.1)
	# Full tutorial gate still requires equipping the chest weapon.
	var shotgun := GearItem.create(preload("res://scripts/item_db.gd").base_by_id(&"shotgun"), 1, 0)
	player.inventory.add_item(shotgun)
	assert(player.inventory.equip_weapon(shotgun, 1) == "")
	await get_tree().create_timer(0.4).timeout
	assert(not is_instance_valid(intro._training_gate))
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/village_start.png")
		player.global_position = Vector3(0, 0.1, -233)
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/village_tavern_exterior.png")
	var boss := intro.get_node("IntroGuardian") as Enemy
	boss.take_damage(boss.hp * 100, &"physical", player)
	await get_tree().create_timer(0.2).timeout
	assert(player.level == 2)
	await Game.complete_zone(player)
	await get_tree().create_timer(2).timeout
	var hub := player.get_parent()
	assert(hub.has_meta("tavern"))
	assert(hub.get_node("LiftDoor").tavern_exit)
	for service in ["Vendor", "VendorBases", "Workbench", "Stash"]:
		assert(hub.has_node(service))
	assert(Game.testing)
	assert(Game.floor_number == 2)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/tavern_hub.png")
	# Actual exit path transfers the same player/inventory to the next area.
	await Game.return_to_zone()
	await get_tree().create_timer(1).timeout
	assert(player.get_parent() != hub)
	assert(player.inventory.weapons[1].base.id == &"shotgun")
	print("VILLAGE_OK: ruined town, 61 enemies, four floor materials, full navigation and three narrow gates, equipment gate, boss level-up, tavern services, exit to zone 2, same inventory, no saves")
	get_tree().quit()
