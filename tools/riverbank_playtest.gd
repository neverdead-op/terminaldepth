extends Node
## Изолированный тест нового макета. Использует существующие бой и героя без записи забега.
const MAP := "res://scenes/art/riverbank_blockout.tscn"
const Modules := preload("res://scripts/module_db.gd")
const Layout := preload("res://scripts/riverbank_layout.gd")
const ROUTE := Layout.ROUTE
@export var spawn_enemies := true
var player: Node3D
var level: Node3D
var overview := false
var completed := false
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("test_runner", true)
	_start.call_deferred()

func _start() -> void:
	completed = false
	overview = false
	player = Game.start_test(1, &"normal", MAP, {
		"fixed_bow_loadout": false, "start_weapon": &"rifle", "start_weapon_corp": &"",
		"animation_library_path": "res://assets/animations/model1_shooter.tres"})
	level = player.get_parent()
	var rifle: GearItem = player.weapon_item(0)
	rifle.modules[0] = Modules.by_id(&"fire").duplicate()
	rifle.modules[1] = Modules.by_id(&"ricochet").duplicate()
	player._on_modules_changed()
	player._ammo[0] = player.current_magazine_size()
	if spawn_enemies:
		_spawn_packs()
	var canvas := CanvasLayer.new()
	canvas.name = "BlockoutControls"
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	level.add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 64)
	canvas.add_child(panel)
	status = Label.new()
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	status.text = "ЗАТОПЛЕННЫЙ ПОДХОД • ИГРОВОЙ ТЕСТ\nWASD — идти • мышь + ЛКМ — стрелять\nПробел — перекат • R — перезарядка • E — лечение\nF2 — обзор / бой • F7 — сброс • Без сохранений"
	status.add_theme_font_size_override("font_size", 17)
	rows.add_child(status)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	var view_button := Button.new()
	view_button.text = "Обзор / играть (F2)"
	view_button.pressed.connect(_toggle_overview)
	buttons.add_child(view_button)
	var restart_button := Button.new()
	restart_button.text = "Заново (F7)"
	restart_button.pressed.connect(_start)
	buttons.add_child(restart_button)
	player.show_message("Тест берега: доберитесь до ворот. F2 — обзор, F7 — начать заново.", 5)
	var args := OS.get_cmdline_user_args()
	if "--check" in args or "--capture" in args or "--spawn-check" in args:
		_check.call_deferred()

func _spawn_packs() -> void:
	for pack in range(3):
		var center: Vector3 = level.get_node("Encounters/Pack%d" % (pack + 1)).position
		for i in range(6 + pack * 2):
			var scene: PackedScene = preload("res://scenes/crawler.tscn")
			if pack == 2 and i == 0: scene = preload("res://scenes/brute.tscn")
			elif pack > 0 and i % 4 == 3: scene = preload("res://scenes/spitter.tscn")
			var enemy: Enemy = scene.instantiate()
			enemy.name = "Pack%dEnemy%d" % [pack + 1, i + 1]
			enemy.position = center + Vector3((i % 3 - 1) * 2.4, 0.1, floori(i / 3.0) * -2.0)
			enemy.drops_enabled = false
			level.add_child(enemy)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F2:
		_toggle_overview()
	if event.physical_keycode == KEY_F7: _start.call_deferred()

func _toggle_overview() -> void:
	overview = not overview
	level.get_node("OverviewCamera").current = overview
	level.get_node("CameraRig/Camera3D").current = not overview
	player.get_node("HUD").visible = not overview
	# Останавливаются также пули и таймеры атак, а кнопки теста остаются доступны.
	get_tree().paused = overview

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	if player.global_position.y < -5:
		player.global_position = level.get_node("Spawn").position
		player.velocity = Vector3.ZERO
	if not completed and player.global_position.distance_to(level.get_node("Markers/Finish").position) < 3:
		completed = true
		status.text = "МАРШРУТ ПРОЙДЕН • F7 — повторить • F2 — обзор\nПереход в кампанию отключён: это отдельный макет."
		player.show_message("Макет пройден. Вы у ворот убежища.", 6)

func _check() -> void:
	await get_tree().create_timer(1.0).timeout
	assert(Game.testing)
	assert(player.is_on_floor(), "Spawn is not grounded")
	if "--spawn-check" in OS.get_cmdline_user_args():
		player.position = Layout.PACKS[1] + Vector3.UP * .1
		player._revive()
		assert(player.position.distance_to(level.get_node("Spawn").position) < .01, "Revive must return to entrance")
		print("RIVERBANK_REVIVE_OK: real revive returns to entrance, no saves")
		get_tree().quit()
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	assert(enemies.size() == (24 if spawn_enemies else 0))
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
	var nav_map := level.get_world_3d().navigation_map
	var finish: Vector3 = level.get_node("Markers/Finish").position
	var path := NavigationServer3D.map_get_path(nav_map, player.position, finish, true)
	assert(path.size() > 2 and path[-1].distance_to(finish) < 0.5, "No route to gate")
	var pocket: Vector3 = level.get_node("Markers/OptionalLoot").position
	var side_path := NavigationServer3D.map_get_path(nav_map, player.position, pocket, true)
	assert(side_path.size() > 1 and side_path[-1].distance_to(pocket) < 0.5, "No side pocket route")
	player.set_physics_process(false)
	if "--capture" in OS.get_cmdline_user_args():
		player.position = Vector3(22,0.1,-54)
		level.get_node("CameraRig").global_position = player.position
		player.get_node("HUD").visible = false
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/blockout_gameplay.png")
		player.position = Vector3(-10,0.1,-132)
		level.get_node("CameraRig").global_position = player.position
		await get_tree().create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/riverbank_gate.png")
		level.get_node("OverviewCamera").current = true
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/blockout_overview.png")
	# Проверяем настоящий выстрел из пула, урон и огненный модуль в новой карте.
	if not await _combat_check():
		get_tree().quit(1)
		return
	player.position = ROUTE[0] + Vector3.UP * 0.1
	for waypoint in ROUTE.slice(1):
		var reached := false
		for frame in range(800):
			await get_tree().physics_frame
			var direction: Vector3 = waypoint - player.position
			direction.y = 0
			if direction.length() < 0.4:
				reached = true
				break
			direction = direction.normalized()
			player.velocity = Vector3(direction.x * 5, player.velocity.y - 9.8 / 60.0, direction.z * 5)
			player.move_and_slide()
		if not reached:
			push_error("Physical walk blocked at %s toward %s" % [player.position, waypoint])
			get_tree().quit(1)
			return
	assert(completed, "Finish must complete the test route")
	_toggle_overview()
	assert(get_tree().paused and overview)
	_toggle_overview()
	assert(not get_tree().paused and not overview)
	print("RIVERBANK_CHECK_OK: grounded, 24 enemies, winding route + side pocket, physical walk, rifle damage + fire, pause, no saves")
	get_tree().quit()

func _combat_check() -> bool:
	player.position = ROUTE[0] + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	# Оконный снимок может прислать движение мыши; диагностика держит заданный прицел.
	player.set_process_input(false)
	var target: Enemy = preload("res://scenes/crawler.tscn").instantiate()
	target.position = player.position + Vector3(0,0,-6)
	target.max_hp = 100000
	target.damage = 0
	target.drops_enabled = false
	level.add_child(target)
	target.set_physics_process(false)
	player._using_mouse = false
	player._aim_dir = Vector3.FORWARD
	player.aim_target = target
	await get_tree().create_timer(.3).timeout
	var health := target.hp
	for i in range(12):
		player._using_mouse = false
		player._aim_dir = Vector3.FORWARD
		player.aim_target = target
		player._shoot(player.current_weapon())
		await get_tree().create_timer(.04).timeout
	await get_tree().create_timer(.5).timeout
	var hit_and_burned := target.hp < health and target._burn_left > 0
	print("RIVERBANK_SHOT_CHECK before=",health," after=",target.hp," burn=",target._burn_left)
	target.queue_free()
	player.aim_target = null
	await get_tree().process_frame
	if not hit_and_burned: push_error("Rifle must hit a real enemy and ignite")
	return hit_and_burned
