extends Node
class Target extends Node3D:
	var hits := 0
	var fraction := 0.0
	func is_dead() -> bool: return false
	func is_safe() -> bool: return false
	func take_damage(_amount: float, _element := &"physical", source = null) -> void:
		hits += 1
		if source != null and source._model_anim != null:
			fraction = source._model_anim.current_animation_position / source._model_anim.get_animation(source.anim_attack).length

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.6).timeout
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var brute: Enemy = player.get_parent().get_node("IntroGuardian")
	brute.rotation = Vector3.ZERO
	var fake := Target.new()
	player.get_parent().add_child(fake)
	brute._player = fake
	for mode in ["hit", "behind", "side", "far", "return_late"]:
		fake.hits = 0
		fake.global_position = brute.global_position + Vector3(0, 0, -1.6)
		brute._state = Enemy.State.CHASE
		brute._melee_pending = false
		brute._model_anim.play(brute.anim_idle)
		brute._model_anim.advance(0)
		var hit_time := -1.0
		for frame in 145:
			var time := frame / 120.0
			if time > 0.35:
				match mode:
					"behind": fake.global_position = brute.global_position + Vector3(0, 0, 1.6)
					"side": fake.global_position = brute.global_position + Vector3(2.2, 0, 0)
					"far", "return_late": fake.global_position = brute.global_position + Vector3(0, 0, -6)
			if mode == "return_late" and time > brute.attack_windup + 0.1:
				fake.global_position = brute.global_position + Vector3(0, 0, -1.6)
			var to := fake.global_position - brute.global_position
			brute._think(1.0 / 120, to, to.length())
			brute._animate_model(1.0 / 120, 0)
			if fake.hits > 0 and hit_time < 0:
				hit_time = time
		if mode == "hit":
			assert(fake.hits == 1)
			assert(absf(hit_time - brute.attack_windup) < 0.025)
			assert(absf(fake.fraction - brute.attack_contact_fraction) < 0.02)
		else:
			assert(fake.hits == 0, "Запоздалый удар: " + mode)
		print("MELEE_OK ", mode)
	var boss: Enemy = preload("res://scenes/boss_foreman.tscn").instantiate()
	player.get_parent().add_child(boss)
	boss.set_physics_process(false)
	boss.global_position = brute.global_position + Vector3(8, 0, 0)
	boss._player = fake
	boss.slam_windup = 0.35
	for escape in [false, true]:
		fake.hits = 0
		fake.global_position = boss.global_position + Vector3.FORWARD
		boss._start_slam()
		for frame in 32:
			if escape and frame == 7:
				fake.global_position = boss.global_position + Vector3(0, 0, -8)
			await get_tree().physics_frame
			boss._animate_model(1.0 / Engine.physics_ticks_per_second, 0)
		assert(fake.hits == (0 if escape else 1))
		if not escape:
			assert(absf(fake.fraction - boss.attack_contact_fraction) < 0.06)
		print("SLAM_OK escape=", escape)
	boss.queue_free()
	fake.queue_free()
	Fx.muzzle(player.global_position + Vector3.UP, Vector3.FORWARD)
	assert(Fx._muzzles.size() == Fx.muzzle_pool_size)
	await get_tree().create_timer(0.12).timeout
	for flash in Fx._muzzles:
		assert(not flash.visible)
	print("COMBAT_OK: contact timing, cone, escape, no late hit, synchronized slam, pooled flashes")
	get_tree().quit()
