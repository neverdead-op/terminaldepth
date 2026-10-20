extends Node
## Проверка контактов ступней в родных восьми направлениях без записи сохранения.
const DB := preload("res://scripts/item_db.gd")

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var rifle := GearItem.create(DB.base_by_id(&"rifle"), 1, 0)
	player.inventory.add_item(rifle)
	assert(player.inventory.equip_weapon(rifle, 1) == "")
	player.select_weapon(1)
	player.rotation = Vector3.ZERO
	var animator: AnimationTree = player.get_node("Animator")
	for kind in [&"step", &"step_run"]:
		for clip in Sfx.SOUNDS[kind]: assert(clip.get_length() <= 0.22)
	assert(Sfx.SOUNDS[&"reload_start"].get_length() < 0.35)
	assert(Sfx.SOUNDS[&"reload_end"].get_length() < 0.35)
	var directions := [Vector3.FORWARD, Vector3(1, 0, -1).normalized(), Vector3.RIGHT, Vector3(1, 0, 1).normalized(), Vector3.BACK, Vector3(-1, 0, 1).normalized(), Vector3.LEFT, Vector3(-1, 0, -1).normalized()]
	for mode in ["Walk", "Run", "Sprint"]:
		player._sprinting = mode == "Sprint"
		player._firing = mode == "Walk"
		var speed := 1.55 if mode == "Walk" else (6.3 if mode == "Sprint" else 4.8)
		for direction in directions:
			player.velocity = direction * speed
			await get_tree().create_timer(0.25).timeout
			var before: int = animator.step_count
			var last_count := before
			var last_time := -1.0
			var last_foot := -1
			var until := Time.get_ticks_msec() + 1400
			while Time.get_ticks_msec() < until:
				await get_tree().process_frame
				if animator.step_count != last_count:
					assert(animator.step_count == last_count + 1)
					assert(animator._last_step - last_time >= animator.step_min_interval - 0.001)
					assert(animator._last_step_foot != last_foot)
					last_count = animator.step_count
					last_time = animator._last_step
					last_foot = animator._last_step_foot
			var count: int = animator.step_count - before
			print("FOOTSTEPS ", mode, " ", direction, " contacts=", count)
			assert(count >= 1 and count <= 9)
			var playing := 0
			for sound in Sfx._players:
				if sound.playing and sound.get_meta("sound_id", &"") in [&"step", &"step_run"]: playing += 1
			assert(playing <= 1)
	player._sprinting = false
	player._firing = false
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	var stopped: int = animator.step_count
	await get_tree().create_timer(0.4).timeout
	assert(animator.step_count == stopped)
	var last_dodge: float = Sfx._last_play.get(&"dodge", -1.0)
	player._start_dodge(Vector3.FORWARD)
	assert(Sfx._last_play.get(&"dodge", -1.0) == last_dodge)
	print("FOOTSTEPS_OK: 24 directions/modes, alternating contacts, single voice, silent idle and dodge, short clips")
	get_tree().quit()
