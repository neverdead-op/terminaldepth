extends Node
## Проверка новых движений на настоящем игроке: направления, оружие, перезарядка и бросок.
const ItemDB := preload("res://scripts/item_db.gd")
var _player: Node3D
var _animator: AnimationTree

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	_player = Game.start_test(1, &"normal")
	await get_tree().create_timer(0.6).timeout
	_player.set_physics_process(false)
	_player.rotation = Vector3.ZERO
	_animator = _player.get_node("Animator")
	assert(_player.get_node("Model").has_meta("native_shooter"))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var rifle := GearItem.create(ItemDB.base_by_id(&"rifle"), 1, 0)
	_player.inventory.add_item(rifle)
	assert(_player.inventory.equip_weapon(rifle, 1) == "")
	_player.select_weapon(1)
	var directions := [[Vector3(0, 0, -4), &"Run"], [Vector3(0, 0, 4), &"RunBack"], [Vector3(-4, 0, 0), &"RunLeft"], [Vector3(4, 0, 0), &"RunRight"], [Vector3(3, 0, -3), &"RunForwardRight"], [Vector3(-3, 0, -3), &"RunForwardLeft"], [Vector3(3, 0, 3), &"RunBackRight"], [Vector3(-3, 0, 3), &"RunBackLeft"]]
	for pair in directions:
		_player.velocity = pair[0]
		await get_tree().create_timer(0.3).timeout
		assert(_animator._state == pair[1])
	_player._sprinting = true
	for pair in directions:
		_player.velocity = pair[0]
		await get_tree().create_timer(0.2).timeout
		assert(String(_animator._state) == String(pair[1]).replace("Run", "Sprint"))
	_player._sprinting = false
	_player.velocity = Vector3(1.55, 0, 0)
	_player._firing = true
	await get_tree().create_timer(0.3).timeout
	assert(_animator._state == &"WalkRight")
	assert(_animator._rifle_pose > 0.99)
	_player.velocity = Vector3.ZERO
	_player._firing = false
	await get_tree().create_timer(0.3).timeout
	assert(_animator._state == &"Idle")
	_animator._on_reload_started(1.5)
	await get_tree().create_timer(0.15).timeout
	assert(_animator._reload_node.animation == &"MX_Reloading")
	assert(_animator.get("parameters/reload/active"))
	assert(is_equal_approx(_animator.get("parameters/reload_speed/scale"), _animator.get_animation(&"MX_Reloading").length / 1.5))
	_animator._on_reload_cancelled()
	await get_tree().create_timer(0.3).timeout
	assert(not _animator.get("parameters/reload/active"))
	_player.select_weapon(0)
	_player._firing = false
	await get_tree().create_timer(0.35).timeout
	assert(_player.inventory.weapons[0].base.id == &"plasma_cutter")
	for modifier in _animator._skeleton.get_children():
		if modifier.get_script() == preload("res://scripts/weapon_aim_modifier.gd"):
			print("CUTTER_FACING ", modifier.facing_dot)
			assert(modifier.facing_dot > 0.97)
	assert(_animator.hold_anim == &"Pistol_Idle")
	assert(_animator.aim_anim == &"Pistol_Aim_Neutral")
	for modifier in _animator._skeleton.get_children():
		if modifier.get_script() == preload("res://scripts/weapon_support_modifier.gd"):
			assert(modifier._weight < 0.01) # В покое левая рука не ищет винтовочное цевьё.
	_player.velocity = Vector3(0, 0, -4)
	await get_tree().create_timer(0.3).timeout
	assert(_animator._pistol_move > 0.95)
	assert(_animator.has_animation(&"MX_Pistol_Run"))
	_player.velocity = Vector3.ZERO
	_player._firing = true
	_animator.play_shot(_player.current_weapon())
	await get_tree().create_timer(0.08).timeout
	assert(_animator.get("parameters/pistol_fire/active"))
	_player._firing = false
	_animator._on_reload_started(1.0)
	await get_tree().create_timer(0.15).timeout
	assert(_animator._reload_node.animation == &"Pistol_Reload")
	_animator._on_reload_cancelled()
	await get_tree().create_timer(0.3).timeout
	_animator.play_throw()
	await get_tree().create_timer(0.08).timeout
	assert(_animator.get("parameters/throw/active"))
	await get_tree().create_timer(0.4).timeout
	assert(not _animator.get("parameters/throw/active"))
	var origin := _player.global_position
	_player._firing = false
	var roll_started_at := Time.get_ticks_msec() / 1000.0
	var previous_roll_sound: float = Sfx._last_play.get(&"roll_contact", -1.0)
	_player._start_dodge(Vector3.RIGHT)
	_player.set_physics_process(true)
	await get_tree().create_timer(0.08).timeout
	assert(_animator._state == &"Roll")
	assert(Sfx._last_play.get(&"roll_contact", -1.0) == previous_roll_sound)
	var skeleton := _animator._skeleton as Skeleton3D
	var inverted := false
	for frame in 100:
		await get_tree().physics_frame
		if _animator._state == &"Roll":
			inverted = inverted or skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin.y < skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin.y
	assert(inverted)
	var contact_at: float = Sfx._last_play.get(&"roll_contact", -1.0)
	assert(contact_at > roll_started_at + 0.2 and contact_at < roll_started_at + 0.45)
	print("ROLL_CONTACT_OK: one short impact timed to body landing")

	assert(_animator._state != &"Roll")
	var moved := _player.global_position.distance_to(origin)
	assert(absf(moved - _player.dodge_distance) < 0.25)
	# Все направления на отдельной площадке, чтобы стены обучения не меняли дальность.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var ground := BoxShape3D.new()
	ground.size = Vector3(100, 1, 100)
	floor_shape.shape = ground
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.global_position = Vector3(2000, -0.5, 2000)
	for direction in directions:
		_player.global_position = Vector3(2000, 0.1, 2000)
		_player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		var start := _player.global_position
		_player._start_dodge(direction[0].normalized())
		for frame in 100:
			await get_tree().physics_frame
		var displacement := _player.global_position - start
		displacement.y = 0
		assert(absf(displacement.length() - _player.dodge_distance) < 0.2)
		assert(displacement.normalized().dot(direction[0].normalized()) > 0.99)
		assert(_animator._state != &"Roll")
	# Во время подъёма можно уже уйти в сторону, пока полный клип ещё смешивается с шагом.
	# Перезарядка не сбрасывается и может закончиться прямо в кувырке.
	_player._ammo[_player.current_weapon_index()] = 0
	_player._start_reload()
	_player._reload_left = 0.3
	_player._start_dodge(Vector3.FORWARD)
	await get_tree().create_timer(0.12).timeout
	assert(_player.is_reloading() and _player._reload_left < 0.25)
	await get_tree().create_timer(0.24).timeout
	assert(_player.is_dodging() and not _player.is_reloading())
	assert(_player.current_ammo() == _player.current_magazine_size())
	assert(not _player.is_firing())
	await get_tree().create_timer(0.5).timeout
	print("ROLL_RELOAD_OK: countdown continues and magazine fills during dodge")
	_player.global_position = Vector3(2000, 0.1, 2000)
	_player.velocity = Vector3.ZERO
	_player._start_dodge(Vector3.FORWARD)
	await get_tree().create_timer(_player.dodge_duration + 0.015).timeout
	assert(not _player.is_dodging() and _player._recovery_left > 0)
	var getup_start := _player.global_position
	Input.action_press("move_right")
	await get_tree().create_timer(0.04).timeout
	assert(_player.global_position.x - getup_start.x > 0.015)
	assert(_player.velocity.x > 0.5)
	assert(_player._recovery_left > 0)
	assert(_animator.get("parameters/roll_mix/blend_amount") > 0 and _animator.get("parameters/roll_mix/blend_amount") < 1)
	Input.action_release("move_right")
	await get_tree().create_timer(0.25).timeout
	# Позднее нажатие запоминается; повтор действительно начинает клип заново.
	_player.global_position = Vector3(2000, 0.1, 2000)
	_player._start_dodge(Vector3.FORWARD)
	await get_tree().create_timer(_player.dodge_duration + _player.dodge_recovery - 0.08).timeout
	Input.action_press("dodge")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dodge")
	await get_tree().create_timer(0.22).timeout
	assert(_player.is_dodging())
	assert(_player._roll_elapsed < (_player.dodge_duration + _player.dodge_recovery) * 0.5)
	await get_tree().create_timer(_player.dodge_duration + _player.dodge_recovery).timeout
	Input.action_press("move_up")
	Input.action_press("shoot")
	await get_tree().create_timer(0.7).timeout
	assert(_player.velocity.length() <= _player.shoot_move_speed + 0.2)
	Input.action_release("shoot")
	await get_tree().create_timer(0.5).timeout
	assert(_player.velocity.length() > _player.move_speed - 0.2)
	Input.action_release("move_up")
	await get_tree().create_timer(0.2).timeout
	var stopped_step: float = _animator._last_step
	await get_tree().create_timer(0.4).timeout
	assert(is_equal_approx(_animator._last_step, stopped_step))
	assert(stopped_step > 0)
	floor_body.queue_free()
	_player.set_physics_process(false)
	_player.global_position = origin
	_player.velocity = Vector3.ZERO
	_player.rotation = Vector3.ZERO
	if "--capture" in OS.get_cmdline_user_args():
		var camera := get_viewport().get_camera_3d()
		camera.get_parent().set_process(false)
		camera.get_parent().set_physics_process(false)
		camera.global_position = _player.global_position + Vector3(2.4, 2.4, -4.5)
		camera.look_at(_player.global_position + Vector3.UP * 1.0)
		camera.fov = 35
		var light := OmniLight3D.new()
		_player.add_child(light)
		light.position = Vector3(1, 3, -2)
		light.light_energy = 3
		light.omni_range = 10
		for i in [0, 1]:
			_player.select_weapon(i)
			if i == 0:
				_player._firing = false
				await get_tree().create_timer(0.35).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://docs/screens/cutter_idle.png")
			_player._firing = true
			await get_tree().create_timer(0.5).timeout
			assert((-_player.gun.global_basis.z).normalized().dot(-_player.global_basis.z) > 0.97)
			for modifier in _animator._skeleton.get_children():
				if modifier.get_script() == preload("res://scripts/weapon_support_modifier.gd"):
					print("GRIP_ERROR ", i, " ", modifier.last_error)
					assert(modifier.last_error < 0.15)
			_player._update_muzzle()
			_player._shot_feedback(_player.current_weapon())
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/screens/mixamo_weapon_%d.png" % i)
		_player.select_weapon(1)
		_player._firing = true
		_player.velocity = Vector3(0, 0, -_player.shoot_move_speed)
		await get_tree().create_timer(0.35).timeout
		for frame in 4:
			await get_tree().create_timer(0.16).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/screens/walk_weapon_%d.png" % frame)
	print("SHOOTER_RUNTIME_OK: native model, eight-way run/sprint, aligned weapons, timed reload, cancellation, throw, full dive roll, movement during getup, pistol poses")
	get_tree().quit()
