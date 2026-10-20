extends Node
## Автозагрузка Game: переходы между уровнями без потери вещей.
## Игрок (со всем инвентарём) не пересоздаётся, а переносится из уровня в уровень.
## Зона, из которой ушли на базу, не удаляется: она «замирает» вне дерева сцены и ждёт возвращения —
## враги, добыча и открытые двери остаются как были (как портал в город в PoE 2).

const HUB_SCENE := "res://scenes/tavern_hub.tscn"
## Этажи демо: scenes/zones/zone_1.tscn … zone_5.tscn (уровень этажа = номер).
const ZONE_SCENE := "res://scenes/zones/zone_%d.tscn"
const FLOORS := 6
const INTRO_SCENE := "res://scenes/lunar_intro.tscn"
const PORTAL := preload("res://scripts/hub_portal.gd")
const MAIN_MENU := "res://scenes/main_menu.tscn"
## Сколько добычи падает в режиме (множитель шансов у врагов и числа вещей в сундуках).
const LOOT_MULT := {&"normal": 0.08, &"hardcore": 0.08, &"god": 1.5, &"demo": 1.5}
## Демо-арена: оружейная со всем снаряжением и арена с волнами врагов.
const DEMO_SCENE := "res://scenes/demo.tscn"

## Длительность затемнения экрана при переходе (туда и обратно), сек.
@export var fade_time := 0.35

var player: Node3D
## Сектор 1 — ботанический сад на Луне «Сады Эдема». Названия ярусов (этажей) по порядку.
const SECTOR_NAME := "Преддверие Бездны"
const FLOOR_NAMES := ["Погасшая деревня", "Заброшенные сады", "Аллея Пилигримов", "Квартал Благовещения", "Корневые катакомбы",
		"Порог Бездны"]
## Текущий этаж (1…FLOORS). Лифт в конце этажа переводит на следующий.
var floor_number := 1
## Режим забега: normal — обычный, hardcore — одна жизнь, god — тест (бессмертие, стартовый запас).
var mode := &"normal"
var _zone: Node  # зона, ожидающая возвращения (вне дерева сцены)
var _zone_return := Vector3.ZERO
var _hub: Node
var _zone_portal: Node3D  # портал, открытый в зоне (ведёт на базу)
var _fade: ColorRect
var _transitioning := false
## Склад на базе: вкладки с вещами (как сумка) и вкладка валюты (id фрагмента → сколько).
const STASH_TABS := 3
var stash_tabs: Array[PlayerInventory] = []
var stash_currency := {}
## Прочитанные разговоры на базе: "имя:этаж" → true.
var dialog_seen := {}


func _ready() -> void:
	for i in STASH_TABS:
		var tab := PlayerInventory.new()
		tab.name = "StashTab%d" % (i + 1)
		add_child(tab)
		stash_tabs.append(tab)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func loot_mult() -> float:
	return LOOT_MULT.get(mode, 1.0)


func is_god() -> bool:
	return mode == &"god" or mode == &"demo"


func is_hardcore() -> bool:
	return mode == &"hardcore"


## Стартовое золото (купить экипировку у Angie и Mira перед первым этажом).
const START_GOLD := 0
const PLAYER_SCENE := "res://scenes/player.tscn"


const SaveGame := preload("res://scripts/save_game.gd")
## Автосохранение во время игры (сек). Ещё сохраняемся при входе на базу, после этажа и при выходе в меню.
const AUTOSAVE_EVERY := 60.0
var _autosave_left := AUTOSAVE_EVERY


## Тестовый запуск (scenes/tools/test_zone.tscn): не сохраняемся, чтобы не затереть настоящий забег.
var testing := false


## Сохранить прогресс (если идёт забег).
func save() -> void:
	if testing:
		return
	if player != null and is_instance_valid(player) and player.is_inside_tree() and not player.is_dead():
		SaveGame.write(self, player)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or _transitioning:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_EVERY
		save()


## Продолжить сохранённую игру: старт на базе, вещи и уровень — из сохранения.
func continue_game() -> void:
	var data := SaveGame.read_all()
	if data.is_empty():
		return
	new_game(StringName(data.get("mode", "normal")), data)


## Новая игра из главного меню: старт в деревне. SSF и HC SSF — с пистолетом (автомат — из первого сундука),
## God mode и Demo — сразу с автоматом, огненным зарядом и рикошетом.
## data — сохранение (тогда это «Продолжить»).
func new_game(new_mode: StringName, data := {}) -> void:
	mode = new_mode
	_reset_run()
	var tree := get_tree()
	var old := tree.current_scene
	var intro := data.is_empty() or (int(data.get("campaign_version", 1)) >= 2 and int(data.get("floor", 1)) == 1)
	var start: Node = load(INTRO_SCENE if intro else HUB_SCENE).instantiate()
	if not intro:
		_hub = start
	tree.root.add_child(start)
	tree.current_scene = start
	if old != null:
		old.queue_free()
	player = load(PLAYER_SCENE).instantiate()
	player.name = "Player"
	_configure_campaign_player(player)
	var at := _spawn_of(start)
	start.add_child(player)
	player.global_position = at
	if data.is_empty():
		_give_campaign_modules(player)
		player.gold = 5000 if is_god() else START_GOLD
		player.show_message.call_deferred(Loc.t("Деревня погасла. Доберитесь до таверны «Последний огонь»."), 5.0)
		save()
	else:
		floor_number = int(data.get("floor", 1)) + (1 if int(data.get("campaign_version", 1)) < 2 else 0)
		SaveGame.apply(data, self, player)
		player._on_inventory_changed()
		player.hp = player.max_hp
		player.es = player.max_es
		player._equip(0)
		player.show_message.call_deferred(Loc.t("Прогресс загружен. Лифт ведёт на этаж %d.") % floor_number, 4.0)
	_autosave_left = AUTOSAVE_EVERY


## Тест: сразу на этаж floor (без меню и базы). Сохранения в этом запуске отключены.
func start_test(floor: int, test_mode: StringName, scene_path := "", player_options: Dictionary = {}) -> Node3D:
	mode = test_mode
	_reset_run()
	testing = true
	floor_number = floor
	var tree := get_tree()
	var old := tree.current_scene
	var zone: Node = load(scene_path if scene_path != "" else zone_scene(floor)).instantiate()
	tree.root.add_child(zone)
	tree.current_scene = zone
	# Узел тестовой сцены остаётся жить (снимки, настройки), остальное убираем.
	if old != null and not old.has_meta(&"test_runner"):
		old.queue_free()
	player = load(PLAYER_SCENE).instantiate()
	player.name = "Player"
	var campaign_intro := zone.scene_file_path == INTRO_SCENE and player_options.is_empty()
	if campaign_intro:
		_configure_campaign_player(player)
	for key in player_options:
		if key == "animation_library_path":
			player.get_node("Model").animation_library_path = player_options[key]
		else:
			player.set(key, player_options[key])
	var at := _spawn_of(zone)
	zone.add_child(player)
	player.global_position = at
	if campaign_intro:
		_give_campaign_modules(player)
	player.gold = 5000 if is_god() else START_GOLD
	player.show_message.call_deferred(floor_title(), 3.0)
	return player


## Настройка до входа в дерево: огнестрельный хват без изменения сцены героя и лука.
func _configure_campaign_player(hero: Node3D) -> void:
	hero.fixed_bow_loadout = false
	hero.start_weapon = &"rifle"
	hero.start_weapon_corp = &""
	hero.get_node("Model").animation_library_path = "res://assets/animations/model1_shooter.tres"


## Только новый комплект; сохранённые предметы и их модификаторы загружаются как прежде.
func _give_campaign_modules(hero: Node3D) -> void:
	var rifle: GearItem = hero.weapon_item(0)
	if _starts_with_rifle():
		rifle.modules[0] = preload("res://data/modules/fire.tres").duplicate()
		rifle.modules[1] = preload("res://data/modules/ricochet.tres").duplicate()
	hero._on_modules_changed()
	hero._ammo[0] = hero.current_magazine_size()
	if hero.weapon_item(1) == null:
		var shotgun := GearItem.create(preload("res://scripts/item_db.gd").base_by_id(&"shotgun"), 1, 0)
		shotgun.corp = &""
		var added: bool = hero.inventory.add_item(shotgun)
		var equip_error: String = hero.inventory.equip_weapon(shotgun, 1)
		assert(added and equip_error.is_empty())


func _starts_with_rifle() -> bool:
	return mode == &"demo" or mode == &"god"


## Демо (меню «Новая игра» → Demo): первый уровень деревни с автоматом, огненным зарядом и рикошетом. Без сохранения.
func start_demo() -> void:
	var p := start_test(1, &"demo", INTRO_SCENE)
	p.show_message.call_deferred(Loc.t("Демо: коломёт с огненным зарядом и рикошетом. Доберитесь до таверны «Последний огонь»."), 6.0)


## Сразу в таверне (меню «Новая игра» → Таверна): SSF-героиня с пистолетом и золотом, дверь ведёт на этаж 2.
## Для проверки торговцев и следующего уровня; сохранение отключено, настоящее не затирается.
func start_tavern(gold := 500) -> void:
	mode = &"normal"
	_reset_run()
	testing = true
	floor_number = 2
	var tree := get_tree()
	var old := tree.current_scene
	_hub = load(HUB_SCENE).instantiate()
	tree.root.add_child(_hub)
	tree.current_scene = _hub
	if old != null and not old.has_meta(&"test_runner"):
		old.queue_free()
	player = load(PLAYER_SCENE).instantiate()
	player.name = "Player"
	_configure_campaign_player(player)
	var at := _spawn_of(_hub)
	_hub.add_child(player)
	player.global_position = at
	_give_campaign_modules(player)
	player.gold = gold
	player.show_message.call_deferred(Loc.t("Таверна «Последний огонь». Золото: %d. Дверь ведёт в область 2. Без сохранения.") % gold, 5.0)


## Прежнее демо — арена «Арсенал» со всем оружием и модулями (в меню не выводится, для тестов).
func start_arsenal_demo() -> void:
	var p := start_test(3, &"demo", DEMO_SCENE)
	while not p.is_max_level():
		p.add_xp(p.xp_for_next_level() - p.xp)
	p.passive_points += 20
	p.hp = p.max_hp
	p.show_message.call_deferred(Loc.t("Демо: «Арсенал» — всё оружие и модули (F у сундука). Арена с врагами — на юге."), 6.0)


## В главное меню (из паузы или после гибели в хардкоре).
func to_main_menu() -> void:
	save()
	_reset_run()
	get_tree().change_scene_to_file(MAIN_MENU)


func _reset_run() -> void:
	get_tree().paused = false
	for level in [_hub, _zone]:
		if level != null and is_instance_valid(level) and not level.is_inside_tree():
			level.free()
	_hub = null
	_zone = null
	_zone_portal = null
	player = null
	floor_number = 1
	testing = false
	_transitioning = false
	_fade.color.a = 0.0
	for tab in stash_tabs:
		tab.entries.clear()
	stash_currency.clear()
	dialog_seen.clear()


func is_transitioning() -> bool:
	return _transitioning


## Кнопка H / L3: открыть портал на базу перед игроком (на ближайшем проходимом месте).
func open_town_portal(who: Node3D) -> void:
	player = who
	if in_hub() or in_intro() or _transitioning:
		return
	var level := player.get_parent()
	if _zone_portal != null and is_instance_valid(_zone_portal):
		_zone_portal.queue_free()
	var at: Vector3 = player.global_position - player.global_basis.z * 2.5
	var map := player.get_world_3d().navigation_map
	var snapped := NavigationServer3D.map_get_closest_point(map, at)
	if snapped != Vector3.ZERO:
		at = Vector3(snapped.x, 0.0, snapped.z)
	_zone_portal = PORTAL.new()
	_zone_portal.destination = &"hub"
	level.add_child(_zone_portal)
	_zone_portal.global_position = at
	# Повернуть кольцом к игроку.
	var to_player := player.global_position - at
	_zone_portal.rotation.y = atan2(to_player.x, to_player.z)


## Затемнить экран, выполнить переход, проявить экран.
func _fade_through(action: Callable) -> void:
	_transitioning = true
	player.set_physics_process(false)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", 1.0, fade_time)
	await tween.finished
	action.call()
	await get_tree().process_frame
	player.set_physics_process(true)
	var back := create_tween()
	back.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	back.tween_property(_fade, "color:a", 0.0, fade_time * 1.4)
	await back.finished
	_transitioning = false


## Подчищаем уровни, которые держали вне сцены (иначе при выходе из игры они «утекают»).
func _exit_tree() -> void:
	for level in [_hub, _zone]:
		if level != null and is_instance_valid(level) and level.get_parent() == null:
			level.free()


func in_hub() -> bool:
	return _hub != null and _hub.is_inside_tree()


## Телепорт на базу. Из зоны — с запоминанием места, чтобы вернуться туда же.
func go_to_hub(who: Node3D) -> void:
	player = who
	if in_hub() or in_intro() or _transitioning:
		return
	await _fade_through(func():
		var level := player.get_parent()
		_zone = level
		_zone_return = player.global_position
		if _hub == null:
			_hub = load(HUB_SCENE).instantiate()
		_switch(level, _hub, _spawn_of(_hub), false)
		player.show_message("Таверна «Последний огонь». Дверь ведёт обратно в зону.", 2.5))
	save()


## Вернуться из базы в зону (в то же место). Если зона пройдена — в новую.
func return_to_zone() -> void:
	if not in_hub() or _transitioning:
		return
	await _fade_through(func():
		var target := _zone
		var at := _zone_return
		var first_visit := target == null
		if target == null:
			target = load(zone_scene(floor_number)).instantiate()
			at = _spawn_of(target)
			_zone_portal = null
		elif _zone_portal != null and is_instance_valid(_zone_portal):
			# Выходим из того же портала; он не сработает, пока игрок не отойдёт.
			# Зона ещё вне сцены — берём координаты портала внутри неё (зона стоит в начале координат).
			at = _zone_portal.position + Vector3(0, 0, 1.6)
			_zone_portal.wait_for_exit = true
		_zone = null
		_switch(_hub, target, at, false)
		if first_visit:
			player.show_message.call_deferred(floor_title(), 4.0))


## «Сады Эдема · Ярус 2 — Аллея Пилигримов» — для сообщения при входе и карты.
func zone_scene(floor: int) -> String:
	return INTRO_SCENE if floor <= 1 else ZONE_SCENE % (floor - 1)


func in_intro() -> bool:
	return player != null and is_instance_valid(player) and player.is_inside_tree() and player.get_parent().has_meta("intro")


func floor_title() -> String:
	var name := Loc.t(FLOOR_NAMES[floor_number - 1]) if floor_number <= FLOOR_NAMES.size() else ""
	return "%s %d — %s: %s" % [Loc.t("Уровень"), floor_number, Loc.t(SECTOR_NAME), name]


## Этаж пройден (лифт): старую зону выбрасываем, игрок попадает на базу; портал ведёт в новую зону.
func complete_zone(who: Node3D) -> void:
	player = who
	if _transitioning:
		return
	await _fade_through(func():
		var level := player.get_parent()
		if _hub == null:
			_hub = load(HUB_SCENE).instantiate()
		_switch(level, _hub, _spawn_of(_hub), true)
		_zone = null
		_zone_portal = null
		if floor_number < FLOORS:
			floor_number += 1
			player.show_message("Путь открыт! Дверь таверны ведёт в следующую область: %d." % floor_number, 3.5)
		else:
			player.show_message("Демо пройдено! Портал снова ведёт на этаж %d." % floor_number, 4.0))
	save()


## Где появляться в уровне: место встроенного в сцену игрока-заготовки (его убираем) или маркер Spawn.
func _spawn_of(level: Node) -> Vector3:
	var embedded := level.get_node_or_null("Player")
	if embedded != null and embedded != player:
		var at: Vector3 = embedded.position
		level.remove_child(embedded)
		embedded.free()
		level.set_meta("spawn", at)
		return at
	if level.has_meta("spawn"):
		return level.get_meta("spawn")
	var marker := level.get_node_or_null("Spawn")
	return marker.position if marker != null else Vector3.ZERO


func _switch(from: Node, to: Node, at: Vector3, free_old: bool) -> void:
	var tree := get_tree()
	tree.paused = false
	from.remove_child(player)
	tree.root.remove_child(from)
	if free_old:
		from.queue_free()
	tree.root.add_child(to)
	tree.current_scene = to
	to.add_child(player)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.on_level_changed(at)
