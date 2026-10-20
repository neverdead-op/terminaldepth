extends Node
## Настоящие столкновения: одна цель, пять соседних, исключение исходной цели и рекурсии.
const DB := preload("res://scripts/item_db.gd")
const Modules := preload("res://scripts/module_db.gd")
class Target extends StaticBody3D:
	var hits := 0
	var damage := 0.0
	var lethal := false
	func take_damage(amount: float, _element := &"physical", _source = null) -> float:
		hits += 1
		damage += amount
		if lethal: queue_free()
		return amount
	func is_dead() -> bool: return false

func _target(at: Vector3) -> Target:
	var target := Target.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.8
	collider.shape = capsule
	target.add_child(collider)
	add_child(target)
	target.global_position = at
	target.add_to_group("enemies")
	return target

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var pool := get_tree().get_first_node_in_group("bullet_pool")
	var nova: ModuleData = Modules.by_id(&"nova_shot").duplicate()
	assert(nova != null and nova.nova_projectiles == 5)
	var shotgun := GearItem.create(DB.base_by_id(&"shotgun"), 1, 0)
	shotgun.corp = &""
	player.inventory.add_item(shotgun)
	assert(player.inventory.equip_weapon(shotgun, 1) == "")
	player.select_weapon(1)
	assert(player.inventory.add_item(nova))
	assert(player.insert_module(1, 1, nova) == "")
	assert(is_equal_approx(player.weapon_stats(1).damage, shotgun.weapon_data().damage * 0.8))
	var saved := preload("res://scripts/save_game.gd")
	var restored: GearItem = saved._item_from(saved._item_to(shotgun))
	assert(restored.modules[1].id == &"nova_shot")
	assert(player.remove_module(1, 1) == "")
	assert(is_equal_approx(player.weapon_stats(1).damage, shotgun.weapon_data().damage))
	var origin := Vector3(2100, 1, 2100)
	for look in [&"bullet", &"pellet", &"plasma"]:
		for lethal in [false, true]:
			for projectile in pool._bullets: projectile.deactivate()
			var at := origin + Vector3.FORWARD * 3
			var primary := _target(at)
			primary.lethal = lethal
			var neighbors: Array[Target] = []
			for i in 5:
				neighbors.append(_target(at + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 5) * 2))
			await get_tree().physics_frame
			await get_tree().physics_frame
			var state := {"triggered": false}
			var payload := {"damage": 80.0, "nova_projectiles": 5, "nova_damage_ratio": 0.5, "nova_state": state, "look": look, "width": 0.4, "shooter": player}
			var bullet := preload("res://scenes/bullet.tscn").instantiate()
			add_child(bullet)
			bullet.activate(Transform3D(Basis.IDENTITY, origin), 40, 15, origin, payload)
			bullet.set_physics_process(false)
			bullet._physics_process(0.1)
			assert(state.triggered)
			if not lethal: assert(primary.hits == 1 and is_equal_approx(primary.damage, 80.0))
			await get_tree().create_timer(0.14).timeout
			for target in neighbors:
				assert(target.hits == 1 and is_equal_approx(target.damage, 40.0))
			var children: Array = pool._bullets.filter(func(b): return b._payload != null and b._payload.get("nova_secondary", false))
			assert(children.size() == 5)
			for child in children:
				assert(child._payload.nova_projectiles == 0)
				# Чистим историю для следующего варианта и сохраняем только живые снаряды теста.
				child._payload = {}
			if not lethal:
				assert(primary.hits == 1)
				# Ещё одна дробинка того же выстрела не должна породить вторую нову.
				bullet._damage(primary)
				await get_tree().process_frame
				await get_tree().process_frame
				assert(pool._bullets.filter(func(b): return b._payload != null and b._payload.get("nova_secondary", false)).is_empty())
				primary.queue_free()
			for target in neighbors: target.queue_free()
			bullet.queue_free()
			await get_tree().process_frame
			print("NOVA_OK look=", look, " lethal=", lethal, " primary=80 secondaries=5x40")
	print("NOVA_MODULE_OK: equip/remove/save, five physical projectiles, no original-target repeat, no recursion, once per volley")
	get_tree().quit()
