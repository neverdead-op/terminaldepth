extends Node
## Изолированный тест нового макета. Использует существующие бой и героя без записи забега.
const MAP := "res://scenes/art/riverbank_blockout.tscn"
const Modules := preload("res://scripts/module_db.gd")
const ROUTE := [Vector3(0,0,6), Vector3(0,0,-17), Vector3(-6,0,-34), Vector3(-4,0,-50), Vector3(-4,0,-69), Vector3(6,0,-86), Vector3(6,0,-106)]
@export var spawn_enemies := true
var player: Node3D
var level: Node3D
var overview := false
var completed := false
var status: Label

func _ready() -> void:
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
	level.add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 64)
	canvas.add_child(panel)
	status = Label.new()
	status.text = "ЗАТОПЛЕННЫЙ ПОДХОД • БЛОКАУТ\nF2 — обзор / бой • F7 — сброс\nМаршрут: берег → поляна → мост → ворота\nТри группы врагов • Боковой карман справа • Без сохранений"
	status.add_theme_font_size_override("font_size", 17)
	panel.add_child(status)
	player.show_message("Тест берега: доберитесь до ворот. F2 — обзор, F7 — начать заново.", 5)
	var args := OS.get_cmdline_user_args()
	if "--check" in args or "--capture" in args:
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
			enemy.position = center + Vector3((i % 3 - 1) * 2.4, 0.1, (i / 3) * -2.0)
			enemy.drops_enabled = false
			level.add_child(enemy)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F2:
		overview = not overview
		level.get_node("OverviewCamera").current = overview
		level.get_node("CameraRig/Camera3D").current = not overview
		player.get_node("HUD").visible = not overview
		# Обзор замораживает бой, чтобы можно было спокойно оценить планировку.
		player.set_physics_process(not overview)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if level.is_ancestor_of(enemy): enemy.set_physics_process(not overview)
	if event.physical_keycode == KEY_F7: _start.call_deferred()

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
		player.position = Vector3(-4,0.1,-44)
		level.get_node("CameraRig").global_position = player.position
		player.get_node("HUD").visible = false
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/blockout_gameplay.png")
		level.get_node("OverviewCamera").current = true
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/art_direction/riverbank/blockout_overview.png")
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
		assert(reached, "Physical walk blocked at %s toward %s" % [player.position, waypoint])
	print("RIVERBANK_CHECK_OK: grounded, 24 enemies, navigation to gate and side pocket, physical route, no saves")
	get_tree().quit()
