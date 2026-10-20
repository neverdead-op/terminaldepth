extends Node
## Геймпад: перекат лицом в стену, цель сзади, удержание RT и первый настоящий снаряд.
const DB := preload("res://scripts/item_db.gd")
class Target extends StaticBody3D:
	var hits := 0
	func take_damage(_amount: float, _element := &"physical", _source = null) -> float:
		hits += 1
		return _amount
	func is_dead() -> bool: return false

func _body(at: Vector3, size: Vector3, wall := false) -> Target:
	var body := Target.new()
	body.collision_layer = 1 if wall else 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return body

func _trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	Input.parse_input_event(event)

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var center := Vector3(2300, 0, 2300)
	_body(center - Vector3.UP, Vector3(40, 1, 40), true)
	var camera := get_viewport().get_camera_3d()
	camera.get_parent().set_physics_process(false)
	camera.global_position = center + Vector3(0, 11, 8)
	camera.look_at(center)
	var pool := get_tree().get_first_node_in_group("bullet_pool")
	var count := 0
	for id in [&"plasma_cutter", &"rifle", &"shotgun"]:
		var item := GearItem.create(DB.base_by_id(id), 1, 0)
		item.corp = &""
		player.inventory.add_item(item)
		var slot := 0 if id == &"plasma_cutter" else 1
		assert(player.inventory.equip_weapon(item, slot) == "")
		player.select_weapon(slot)
		for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			_trigger(0)
			for bullet in pool._bullets: bullet.deactivate()
			player.global_position = center + Vector3.UP * 0.02
			player.velocity = Vector3.ZERO
			player._using_mouse = false
			player._locked_target = null
			player._fire_cooldown = 0
			player._reload_left = 0
			player._ammo[slot] = player.current_magazine_size()
			var target := _body(center - direction * 4, Vector3(1.8, 2, 1.8))
			target.add_to_group("enemies")
			var wall := _body(center + direction * 4.1, Vector3(5, 3, 0.4) if absf(direction.z) > 0.1 else Vector3(0.4, 3, 5), true)
			await get_tree().create_timer(0.1).timeout
			player._start_dodge(direction)
			var ammo: int = player.current_ammo()
			_trigger(1)
			var deadline := Time.get_ticks_msec() + 2300
			while player.current_ammo() == ammo and Time.get_ticks_msec() < deadline:
				await get_tree().physics_frame
				if player._roll_elapsed < player.dodge_duration + player.dodge_recovery:
					assert(player.current_ammo() == ammo)
			assert(player.current_ammo() == ammo - 1)
			assert(player.get_node("Animator")._state != &"Roll")
			assert(player._roll_elapsed >= player.dodge_duration + player.dodge_recovery)
			var bullets := 0
			for bullet in pool._bullets:
				if not bullet.active: continue
				var desired: Vector3 = target.global_position - bullet.global_position
				desired.y = 0
				assert((-bullet.global_basis.z).dot(desired.normalized()) > 0.98)
				bullets += 1
			assert(bullets > 0)
			_trigger(0)
			await get_tree().create_timer(0.6).timeout
			assert(target.hits > 0 and wall.hits == 0)
			print("POST_ROLL_AIM_OK ", id, " direction=", direction, " hits=", target.hits)
			target.queue_free()
			wall.queue_free()
			await get_tree().physics_frame
			count += 1
	_trigger(0)
	print("ROLL_GAMEPAD_OK: ", count, " first-shot cases, RT held, full animation, target behind, wall ahead")
	get_tree().quit()
