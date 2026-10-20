extends Node
## Реальные физические цели, четыре семейства оружия, независимые модули и зарядка.
const DB := preload("res://scripts/item_db.gd")
const Modules := preload("res://scripts/module_db.gd")
class Target extends StaticBody3D:
	var hits := 0
	var damage := 0.0
	func take_damage(amount: float, _element := &"physical", _source = null) -> float:
		hits += 1
		damage += amount
		return amount
	func is_dead() -> bool: return false

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _target(at: Vector3) -> Target:
	var target := Target.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.21
	capsule.height = 1.6
	shape.shape = capsule
	target.add_child(shape)
	add_child(target)
	target.global_position = at
	return target

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	player.set_physics_process(false)
	var skills: Node = player.get_node("Skills")
	skills.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	assert(DB.available_bases(99).filter(func(b): return b.has("weapon")).size() == 7)
	assert(not DB.available_bases(3).any(func(b): return b.id == &"plasma_cutter_mk2"))
	assert(DB.available_bases(4).any(func(b): return b.id == &"plasma_cutter_mk2"))
	for i in 400:
		assert(DB.available_in_act_one(GearItem.random_drop(1 + i % 5).base))
	var mine := GearItem.create(DB.MINE_BASE, 1, 0)
	assert(not DB.available_in_act_one(mine.base))
	assert(player.inventory.equip_weapon(mine, 2) != "")
	assert(player.inventory.weapons[0].base.id == &"pistol")
	assert(DB.available_in_act_one(DB.base_by_id(&"pistol")))
	var saved := preload("res://scripts/save_game.gd")
	var legacy := GearItem.create(DB.base_by_id(&"heavy_pistol"), 1, 0)
	legacy.quality = 7
	legacy.modules[0] = Modules.by_id(&"fire")
	var migrated: GearItem = saved._item_from(saved._item_to(legacy))
	assert(migrated.base.id == &"plasma_cutter" and migrated.quality == 7 and migrated.modules[0].id == &"fire")
	var pistol := GearItem.create(DB.base_by_id(&"pistol"),1,0)
	var restored:GearItem=saved._item_from(saved._item_to(pistol))
	assert(restored.base.id==&"pistol" and restored.slot==&"weapon")
	var cases := 0
	for id in DB.ACT_ONE_WEAPONS:
		var item := GearItem.create(DB.base_by_id(id), 5, 0)
		item.corp = &""
		item.sockets = 3
		item.modules.resize(3)
		var index := 0 if item.slot == &"sidearm" else 1
		assert(player.inventory.add_item(item))
		assert(player.inventory.equip_weapon(item, index) == "")
		player.select_weapon(index)
		var baseline: float = player.weapon_stats(index).damage
		for source in Modules.ALL:
			var module: ModuleData = source.duplicate()
			var slot := 0 if module.is_ammo() else 1
			var allowed: bool = module.weapon_ok and not (item.weapon_data().projectile == &"plasma" and module.id == &"ricochet")
			assert(player.module_error(index, slot, module).is_empty() == allowed)
			if not allowed: continue
			assert(player.inventory.add_item(module))
			assert(player.insert_module(index, slot, module) == "")
			var expected := baseline * (1 + module.damage_bonus) * module.damage_multiplier
			assert(is_equal_approx(player.weapon_stats(index).damage, expected))
			if module.id == &"multishot" and item.weapon_data().icon == &"shotgun":
				assert(player.weapon_stats(index).spread > item.weapon_data().spread_degrees * 2)
			if module.id == &"nova_shot":
				assert(player.weapon_stats(index).nova_projectiles == 5)
				if item.secondary_skill() == &"plasma_pulse": assert(is_equal_approx(player.pulse_stats(index).damage, item.weapon_data().damage * item.weapon_data().secondary_damage_mult))

			player._on_modules_changed()
			assert(is_equal_approx(player.weapon_stats(index).damage, expected))
			if not module.is_ammo(): assert(player.module_error(index, 2, module) != "")
			assert(player.remove_module(index, slot) == "")
			assert(is_equal_approx(player.weapon_stats(index).damage, baseline))
			assert(player.weapon_stats(index).nova_projectiles == 0)
			if item.weapon_data().icon == &"shotgun": assert(is_equal_approx(player.weapon_stats(index).spread, item.weapon_data().spread_degrees))

			player.inventory.remove_item(module)
			cases += 1
		if item.secondary_skill() != &"":
			for source in Modules.ALL:
				var module: ModuleData = source.duplicate()
				if player.module_error(index, item.sockets, module) != "": continue
				assert(player.inventory.add_item(module))
				assert(player.insert_module(index, item.sockets, module) == "")
				assert(is_equal_approx(player.weapon_stats(index).damage, baseline))
				if item.secondary_skill() == &"plasma_pulse":
					var pulse: Dictionary = player.pulse_stats(index)
					var w := item.weapon_data()
					assert(is_equal_approx(pulse.damage, baseline * w.secondary_damage_mult * (1 + module.damage_bonus) * module.damage_multiplier))
					assert(is_equal_approx(pulse.width, w.secondary_width * module.area_mult))
					assert(is_equal_approx(pulse.cooldown, w.secondary_cooldown / (1 + module.reload_speed_bonus)))
					assert(pulse.pierce == w.secondary_pierce + module.pierce)
				else:
					assert(skills.has_grenade())
					assert(is_equal_approx(skills.grenade_stats().damage, skills.grenade_damage * (1 + module.damage_bonus) * module.damage_multiplier))
				var copy: GearItem = preload("res://scripts/save_game.gd")._item_from(preload("res://scripts/save_game.gd")._item_to(item))
				assert(copy.secondary_modules[0].id == module.id and copy.modules[1] == null)
				assert(player.remove_module(index, item.sockets) == "")
				player.inventory.remove_item(module)
				cases += 1
		# Убираем тестовые предметы, чтобы сохранялась свободная сумка.
		if index == 1: assert(player.inventory.unequip_weapon(index) == "")
		player.inventory.remove_item(item)
	print("ACT1_MODULES_OK cases=", cases)
	var origin := Vector3(2000, 1, 2000)
	var targets := [_target(origin + Vector3(-0.35, 0, -3)), _target(origin + Vector3(0.35, 0, -3)), _target(origin + Vector3(0, 0, -5)), _target(origin + Vector3(0, 0, -7)), _target(origin + Vector3(1.5, 0, -3))]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bullet := preload("res://scenes/bullet.tscn").instantiate()
	add_child(bullet)
	for pierce in [0, 1]:
		for target in targets: target.hits = 0
		bullet.activate(Transform3D(Basis.IDENTITY, origin), 20, 15, origin, {"damage": 10.0, "look": &"plasma", "width": 0.75, "pierce": pierce, "shooter": player})
		bullet.set_physics_process(false)
		assert(is_equal_approx(bullet.get_node("Mesh").scale.x, 0.75))
		for step in 35:
			if bullet.active: bullet._physics_process(0.025)
		assert(targets[0].hits == 1 and targets[1].hits == 1)
		assert(targets[2].hits == pierce and targets[3].hits == 0 and targets[4].hits == 0)
		assert(not bullet.visible and not bullet.active)
		print("PLASMA_COLLISION_OK pierce=", pierce)
	bullet.queue_free()
	for target in targets: target.queue_free()
	var cutter := GearItem.create(DB.base_by_id(&"plasma_cutter"), 1, 0)
	cutter.corp = &""
	assert(player.inventory.add_item(cutter))
	assert(player.inventory.equip_weapon(cutter, 1) == "")
	player.select_weapon(1)
	var primary: ModuleData = Modules.by_id(&"damage").duplicate()
	var secondary: ModuleData = Modules.by_id(&"damage").duplicate()
	assert(player.inventory.add_item(primary) and player.inventory.add_item(secondary))
	assert(player.insert_module(1, 1, primary) == "")
	assert(is_equal_approx(player.pulse_stats(1).damage, 120.0))
	assert(player.insert_module(1, cutter.sockets, secondary) == "")
	assert(is_equal_approx(player.pulse_stats(1).damage, 156.0))
	assert(is_equal_approx(player.weapon_stats(1).damage, 62.4))
	assert(player.remove_module(1, 1) == "")
	assert(is_equal_approx(player.pulse_stats(1).damage, 156.0))
	assert(cutter.has_modules())
	assert(player.remove_module(1, cutter.sockets) == "")
	assert(not cutter.has_modules())
	var ammo: int = player.current_ammo()
	assert(skills.start_pulse())
	skills._process(cutter.weapon_data().secondary_charge * 0.5)
	assert(player.current_ammo() == ammo and skills.is_charging_pulse())
	player.select_weapon(0)
	skills._process(0.01)
	assert(not skills.is_charging_pulse() and player._ammo[1] == ammo)
	player.select_weapon(1)
	assert(skills.start_pulse())
	skills._process(cutter.weapon_data().secondary_charge + 0.01)
	assert(player.current_ammo() == ammo - cutter.weapon_data().secondary_ammo_cost)
	assert(skills.pulse_cooldown > 0 and not skills.start_pulse())
	var camera: Node = get_viewport().get_camera_3d().get_parent()
	camera._trauma = 0
	for i in 100: camera.add_weapon_shake(0.045, 0.24)
	assert(camera._trauma <= 0.24)
	camera.add_shake(0.6)
	assert(camera._trauma > 0.24)
	print("ACT1_OK: seven bases, pistol round-trip, no mines, module lifecycle, plasma width/depth, charge cancellation, independent cooldown, bounded recoil")
	if "--capture" in OS.get_cmdline_user_args():
		player.global_position = Vector3(-12, 0, -33)
		camera.global_position = player.global_position
		player.rotation.y = 0
		player._using_mouse = false
		player._aim_dir = Vector3.FORWARD
		player._firing = true
		await get_tree().create_timer(0.25).timeout
		player._update_muzzle()
		for pulse in [false, true]:
			for projectile in player._bullet_pool._bullets: projectile.deactivate()
			player._shoot(cutter.weapon_data(), player.pulse_stats(1) if pulse else {})
			for projectile in player._bullet_pool._bullets:
				if projectile.active:
					projectile.set_physics_process(false)
					projectile._physics_process(0.08)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/screens/plasma_pulse.png" if pulse else "res://docs/screens/plasma_primary.png")
		for projectile in player._bullet_pool._bullets: projectile.deactivate()
		var shotgun := GearItem.create(DB.base_by_id(&"shotgun"), 1, 0)
		shotgun.corp = &""
		assert(player.inventory.add_item(shotgun))
		assert(player.inventory.equip_weapon(shotgun, 1) == "")
		await get_tree().create_timer(0.15).timeout
		player._update_muzzle()
		player._shoot(shotgun.weapon_data())
		for projectile in player._bullet_pool._bullets:
			if projectile.active: assert(projectile._look == &"pellet" and projectile.get_node("Mesh").visible)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/shotgun_blast.png")
	get_tree().quit()
