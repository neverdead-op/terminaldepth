extends Node3D
## Большая зона (этаж). Собрана генератором tools/gen_zone.py.
## Хранит план комнат и коридоров для мини-карты и строит карту проходимости при запуске
## (в фоне — зона большая; пока строится, враги спят и никуда не идут).

## Уровень этажа = уровень врагов и выпадающих вещей. Персонаж выше этого уровня здесь опыта не получает.
@export var zone_level := 1

## Проходимые прямоугольники (x, z, ширина, глубина) — для мини-карты.
@export var map_rects: Array[Rect2] = []
## Где лифт-выход (x, z) — появится на мини-карте, когда игрок увидит эту комнату.
@export var exit_position := Vector2.ZERO
## Темп: множитель скорости всех врагов этажа (меньше 1 — игра спокойнее).
@export var enemy_speed_scale := 0.85
## Здоровье врагов этого этажа, включая подкрепления.
@export var enemy_life_scale := 0.85
## Дополнительные обычные враги рядом с существующими группами.
@export_range(0, 0.5) var extra_enemy_ratio := 0.5
## Доля добычи с обычного врага при повышенной плотности.
@export var ordinary_loot_scale := 1.0
var _population_applied := false
## Доля опыта за врага: генератор подбирает так, чтобы полная зачистка ≈ один уровень персонажа.
@export var xp_scale := 1.0
## Ориентиры: залы с названиями (как места в PoE 2). Вошёл впервые — название появляется в ленте сообщений.
@export var landmark_rects: Array[Rect2] = []
@export var landmark_names := PackedStringArray()

var _visited := {}
var _landmark_check := 0.0


## Переодеть зону в стиль первого уровня (scripts/gothic_restyle.gd): пол, стены, свет, предметы.
@export var gothic_style := false


func _enter_tree() -> void:
	if gothic_style and not is_node_ready():
		preload("res://scripts/gothic_restyle.gd").prepare(self)
	if is_node_ready() and extra_enemy_ratio > 0 and not _population_applied:
		_populate_extra.call_deferred()


func _ready() -> void:
	if gothic_style:
		preload("res://scripts/gothic_restyle.gd").new().apply(self)
	# Задания этажа (сундуки, обелиски, инкубаторы, роботы-союзники).
	var quests := preload("res://scripts/zone_quests.gd").new()
	quests.name = "Quests"
	add_child(quests)
	# Стартовый запас вещей и фрагментов — только в тестовом режиме.
	var start_loot := get_node_or_null("StartLoot")
	if start_loot != null and not Game.is_god():
		start_loot.queue_free()
	if extra_enemy_ratio > 0:
		$Navigation.bake_finished.connect(_populate_extra, CONNECT_ONE_SHOT)
	$Navigation.bake_navigation_mesh(true)


func _process(delta: float) -> void:
	_landmark_check -= delta
	if _landmark_check > 0.0 or landmark_rects.is_empty():
		return
	_landmark_check = 0.5
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not is_ancestor_of(player):
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	for i in landmark_rects.size():
		if not _visited.has(i) and landmark_rects[i].grow(-1.0).has_point(p):
			_visited[i] = true
			player.show_message(Loc.t(landmark_names[i]), 2.5)


func _populate_extra() -> void:
	if _population_applied:
		return
	_population_applied = true
	var tree := get_tree()
	var region := get_node("Navigation") as NavigationRegion3D
	var map := get_world_3d().navigation_map
	var reference := Vector3(map_rects[0].get_center().x, 0, map_rects[0].get_center().y)
	var ready := false
	for attempt in 600:
		await tree.physics_frame
		if not is_inside_tree():
			_population_applied = false
			return
		if NavigationServer3D.region_get_iteration_id(region.get_rid()) > 0 and NavigationServer3D.map_get_closest_point_owner(map, reference) == region.get_rid():
			ready = true
			break
	if not ready:
		_population_applied = false
		return
	var candidates: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		# В этой группе есть не только враги: обелиски, инкубаторы и манекены
		# тоже получают попадания и поэтому находятся в группе для прицеливания.
		if not (node is Enemy) or not is_ancestor_of(node):
			continue
		var enemy := node as Enemy
		if enemy.is_in_group("bosses") or enemy.rarity != 0 or enemy.scene_file_path == "":
			continue
		candidates.append(enemy)
	if candidates.is_empty():
		return
	var population: Array[Enemy] = candidates.duplicate()
	var xp_budget := 0
	for enemy in candidates:
		xp_budget += enemy.xp_reward
	var count := ceili(candidates.size() * extra_enemy_ratio)
	for i in count:
		var source := candidates[(i * 7 + 3) % candidates.size()]
		var angle := i * 2.39996
		var proposed := source.global_position + Vector3(cos(angle), 0, sin(angle)) * 1.35
		var at := NavigationServer3D.map_get_closest_point(map, proposed)
		if at.distance_to(proposed) > 1.0:
			continue
		var packed := load(source.scene_file_path) as PackedScene
		if packed == null:
			continue
		var extra := packed.instantiate() as Enemy
		if extra == null:
			continue
		extra.position = to_local(at + Vector3.UP * 0.05)
		extra.add_to_group("extra_population")
		get_node("Enemies").add_child(extra)
		population.append(extra)
	# Суммарный опыт обычных врагов сохраняем точно, включая округление до целых.
	var expanded_xp := 0
	for enemy in population:
		expanded_xp += enemy.xp_reward
	var allocated := 0
	var cumulative := 0.0
	for enemy in population:
		cumulative += enemy.xp_reward * float(xp_budget) / maxf(expanded_xp, 1)
		var next := roundi(cumulative)
		enemy.xp_reward = next - allocated
		allocated = next
	ordinary_loot_scale *= float(candidates.size()) / population.size()
	set_meta("population_xp_budget", xp_budget)
	set_meta("population_xp_total", allocated)
