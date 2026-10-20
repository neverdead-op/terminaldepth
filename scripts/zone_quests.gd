extends Node
## Задания этажа (доп. активности, как в PoE 2): создаёт zone.gd. Какие задания есть на этаже, решает генератор —
## тем, что кладёт на карту: сундуки, роботов-союзников, обелиски культа, инкубаторы. Здесь — только подсчёт:
## раз в полсекунды проверяем прогресс; выполнено задание — сообщение и награда рядом с героем.

const LOOT := preload("res://scripts/loot_pickup.gd")

## Описание видов заданий: группа объектов, текст, сколько нужно (0 — все объекты группы), как проверить «готово».
const KINDS := [
	{"id": &"chests", "group": &"chests", "title": "Откройте сундуки", "need": 4},
	{"id": &"obelisks", "group": &"quest_obelisk", "title": "Разрушьте обелиски культа", "need": 0},
	{"id": &"nests", "group": &"quest_nest", "title": "Уничтожьте инкубаторы", "need": 0},
	{"id": &"allies", "group": &"ally_robots", "title": "Перезапустите роботов-союзников", "need": 0},
	{"id": &"seals", "group": &"quest_seal", "title": "Запечатайте разлом", "need": 0},
	{"id": &"escort", "group": &"quest_escort", "title": "Спасите учёных", "need": 0},
	{"id": &"landmarks", "group": &"", "title": "Исследуйте старые кварталы", "need": 0},
]

## Текущие задания: {id, title, done, need, finished}
var quests: Array = []
var _check := 0.0
var _level := 1
## Доля уровня за задание; значение 2.0 выдаст опыт на два полных повышения.
@export var robot_xp_levels := 0.18
@export var scientist_xp_levels := 0.12
@export var reward_item_count := 1
## Пустой список сохраняет обычный набор задач этажа.
@export var enabled_quests: Array[StringName] = []


func _ready() -> void:
	add_to_group("zone_quests")
	var zone := get_parent()
	if zone != null and "zone_level" in zone:
		_level = zone.zone_level
	_setup.call_deferred()


func _setup() -> void:
	for kind in KINDS:
		if not enabled_quests.is_empty() and kind.id not in enabled_quests:
			continue
		if kind.id == &"landmarks" and kind.id not in enabled_quests:
			continue
		var early_quests: Array[StringName] = [&"allies", &"escort"]
		if _level == 2:
			early_quests.append_array([&"obelisks", &"nests"])
		if enabled_quests.is_empty() and _level <= 3 and kind.id not in early_quests:
			continue
		var count: int = get_parent().landmark_rects.size() if kind.id == &"landmarks" else get_tree().get_nodes_in_group(kind.group).filter(_is_mine).size()
		if count == 0:
			continue
		var need: int = mini(kind.need, count) if kind.need > 0 else count
		quests.append({"id": kind.id, "group": kind.group, "title": kind.title, "done": 0, "need": need,
				"finished": false})
		var q: Dictionary = quests.back()
		q.reward_loot = kind.id == &"escort" or _level > 3 or not enabled_quests.is_empty()
		q.reward_xp = kind.id == &"allies" or _level >= 2
		if kind.id == &"escort":
			q.title = "Найдите и спасите персонал" if _level == 2 else "Носитель протокола"
			q.description = "Доведите сотрудников до лифта."
		elif kind.id == &"allies":
			q.title = "Искра в тишине" if _level == 2 else "Страж без приказа"
			q.description = "Восстановите питание охранного робота."


## Объект принадлежит этому этажу (база и другие зоны вне дерева не мешают, но на всякий случай).
func _is_mine(node: Node) -> bool:
	return get_parent().is_ancestor_of(node)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or quests.is_empty():
		return
	_check = 0.5
	for q in quests:
		if q.finished:
			continue
		if q.id == &"landmarks":
			q.done = mini(get_parent()._visited.size(), q.need)
			if q.done >= q.need:
				q.finished = true
				_reward(q)
			continue
		var nodes := get_tree().get_nodes_in_group(q.group).filter(_is_mine)
		if q.id == &"escort" and _level == 2:
			var escorting := nodes.any(func(n: Node) -> bool: return n.get("following") == true)
			q.title = "Сопроводите персонал к лифту" if escorting else "Найдите и спасите персонал"
		# Погибшие (учёные) уменьшают цель; погибли все — задание провалено.
		var lost := nodes.filter(func(n: Node) -> bool: return n.get("failed") == true).size()
		if lost > 0:
			if not q.has("need0"):
				q.need0 = q.need
			q.need = maxi(q.need0 - lost, 0)
			if q.need == 0:
				q.finished = true
				q.failed = true
				continue
		q.done = mini(nodes.filter(_is_complete).size(), q.need)
		if q.done >= q.need:
			q.finished = true
			_reward(q)


func _is_complete(node: Node) -> bool:
	if node.get("_opened") == true:
		return true
	if node.get("destroyed") == true or node.get("rescued") == true:
		return true
	return node.get("active") == true or node.get("spent") == true


## Награда за задание: вещь получше, фрагменты, золото.
func _reward(q: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not get_parent().is_ancestor_of(player):
		return
	var parent := player.get_parent()
	var at := player.global_position
	if q.get("reward_loot", true):
		for i in reward_item_count:
			LOOT.drop(parent, at, &"gear", GearItem.random_drop(_level, 0.5))
	if q.get("reward_xp", true):
		var levels := robot_xp_levels if q.id == &"allies" else scientist_xp_levels
		# Выдаём по частям: доля следующего уровня пересчитывается после каждого повышения.
		while levels > 0 and not player.is_max_level():
			var portion := minf(levels, 1.0)
			player.add_xp(maxi(1, roundi(player.xp_for_next_level() * portion)))
			levels -= portion
	Sfx.play(&"unique_drop", at)
	player.show_message(Loc.t("Задание выполнено: %s") % Loc.t(q.title), 4.0)
