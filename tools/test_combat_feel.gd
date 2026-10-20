extends Node
## Реальные пули против двух физических тел, мины, отдача и установка модулей обоими способами.
const DB = preload("res://scripts/item_db.gd")
class Target extends StaticBody3D:
	var hits := 0
	func take_damage(_amount: float, _element := &"physical", _source = null) -> float:
		hits += 1
		return _amount
	func is_dead() -> bool: return false

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(0.8).timeout
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var origin := Vector3(2000, 1, 2000)
	var targets: Array[Target] = []
	for distance in [3.0, 5.0]:
		var target := Target.new()
		target.collision_layer = 4
		target.collision_mask = 0
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		shape.shape = capsule
		target.add_child(shape)
		add_child(target)
		target.global_position = origin + Vector3.FORWARD * distance
		targets.append(target)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bullet := preload("res://scenes/bullet.tscn").instantiate()
	add_child(bullet)
	# На первом кадре трассер непрерывно идёт от реального дула, в том числе при 30 FPS.
	for fps in [30, 60, 120]:
		bullet.activate(Transform3D(Basis.IDENTITY, origin), 55, 35, origin, {"damage": 10.0, "lift": 0.4, "shooter": player})
		bullet.set_physics_process(false)
		assert(is_equal_approx(bullet.get_node("Mesh").position.y, 0.4))
		bullet._physics_process(1.0 / fps)
		var mesh: MeshInstance3D = bullet.get_node("Mesh")
		var tail := mesh.global_transform * Vector3(0, 0, bullet.TRACER_LEN * 0.5)
		assert(tail.distance_to(origin + Vector3.UP * 0.4) < 0.001)
		bullet.deactivate()
	# После повторного использования пул не сохраняет наклон предыдущего следа.
	bullet.activate(Transform3D(Basis.IDENTITY, origin), 55, 35, origin, {"damage": 10.0, "shooter": player})
	assert(bullet.get_node("Mesh").rotation.is_zero_approx())
	bullet.deactivate()
	print("MUZZLE_TRACER_OK: no first-frame gap at 30/60/120 FPS, pooled rotation reset")
	for pierce in [0, 1]:
		for t in targets: t.hits = 0
		bullet.activate(Transform3D(Basis.IDENTITY, origin), 40, 15, origin, {"damage": 10.0, "pierce": pierce, "shooter": player})
		bullet.set_physics_process(false)
		assert(bullet.get_node("Mesh").position.z >= 0)
		for step in 10:
			if bullet.active: bullet._physics_process(0.025)
		assert(targets[0].hits == 1)
		assert(targets[1].hits == pierce)
		assert(not bullet.active)
		assert(bullet.global_position.z >= targets[pierce].global_position.z)
		print("PROJECTILE_OK pierce=", pierce)
	bullet.queue_free()
	for target in targets: target.queue_free()
	var mine := GearItem.create(DB.MINE_BASE, 1, 0)
	assert(player.inventory.equip_weapon(mine, 2) != "" )
	var rifle := GearItem.create(DB.base_by_id(&"rifle"), 1, 0)
	rifle.corp = &""
	player.inventory.add_item(rifle)
	assert(player.inventory.equip_weapon(rifle, 1) == "")
	player.select_weapon(1)
	assert(is_equal_approx(player.weapon_stats(1).reload_time, rifle.weapon_data().reload_time * 0.8))
	player._ammo[1] = 0
	player._start_reload()
	assert(is_equal_approx(player._reload_left, player.weapon_stats(1).reload_time))
	player._reload_left = 0
	player.reload_cancelled.emit()
	player._ammo[1] = int(player.weapon_stats(1).magazine)

	var screen: Control = player.get_node("HUD").skills_screen
	screen.open_context(&"", null)
	await get_tree().process_frame
	var damage := preload("res://data/modules/damage.tres").duplicate()
	player.inventory.add_item(damage)
	screen._layout()
	# Геймпад: выбрать модуль, A, навигация к сокету, A.
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	screen._cursor = screen._find_grid(player.inventory.find_entry(damage).pos)
	screen._input(accept)
	assert(screen._mode == screen.Mode.HOLD_MODULE)
	assert(screen._cells[screen._cursor].kind == "socket")
	screen._input(accept)
	assert(rifle.modules[1] == damage)
	screen._input(accept)
	assert(rifle.modules[1] == null and not player.inventory.find_entry(damage).is_empty())
	# Мышь: перетаскивание из сумки в обычный сокет.
	screen._cursor = screen._find_grid(player.inventory.find_entry(damage).pos)
	assert(screen._pick_up(screen._cursor))
	screen._cursor = screen._find_socket(1, 1)
	assert(screen._place_held())
	assert(rifle.modules[1] == damage)
	# Граната: концентратор во второе гнездо, стихия в любое пустое.
	var concentrate := preload("res://data/modules/concentrate.tres").duplicate()
	player.inventory.add_item(concentrate)
	assert(player.insert_module(1, rifle.sockets + 1, concentrate) == "")
	assert(rifle.secondary_modules[1] == concentrate)
	assert(player.insert_module(1, -1, damage) != "")
	assert(player.insert_module(1, 99, damage) != "")
	assert(player.insert_module(1, 1, damage) != "") # Уже установлен: нельзя дублировать ресурс.
	for a in screen._cells:
		for b in screen._cells:
			if a != b and a.kind == "socket" and b.kind == "socket":
				assert(not a.rect.intersects(b.rect))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screens/combat_modules.png")
	screen._toggle()
	var recoil: Node = player._body_recoil
	player._shot_feedback(player.current_weapon())
	assert(recoil._impulse > 0)
	await get_tree().create_timer(0.6).timeout
	assert(recoil._impulse < 0.001)
	print("COMBAT_FEEL_OK: first-hit collision, pierce, gamepad modules, drag modules, grenade support, recoil decay")
	get_tree().quit()
