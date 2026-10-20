extends "res://scripts/zone.gd"
## Викторианская деревня: путь от окраины до таверны первого акта.

@export_group("Обучение")
@export var pack_size := 5
## Дверь, которая открывается только с дробовиком в руках. Выключено — проход свободен, сундук остаётся наградой.
@export var shotgun_gate := false
## Что точно лежит в первом сундуке на пути (перед кладбищем).
## Пусто — оружия в сундуке нет: коломёт и дробовик героиня получает на старте.
@export var gate_chest_weapon := &""
@export var gate_chest_modules: Array[ModuleData] = [preload("res://data/modules/fire.tres")]
## Камни поддержки во втором сундуке с добычей (рынок у кольца).
@export var second_chest_modules: Array[ModuleData] = [preload("res://data/modules/ricochet.tres")]
@export_group("Активности деревни")
## Сундуки, обелиски, ритуал и задание на ориентиры. Выключено — остаётся только путь.
@export var expanded_quarters := true
@export_range(0.0, 1.0) var enemy_gear_drop_chance := 0.45
@export_range(0.0, 1.0) var enemy_currency_drop_chance := 0.3
var original_floor_cells := 0
@export_group("Пол сада")
@export var garden_floor_texture: Texture2D = preload("res://assets/textures/victorian_garden/stylized_v2/flagstones_red_petals_albedo.png")
## Размер одного повтора в метрах; больше — крупнее камни.
@export_range(2.0, 12.0, 0.5) var garden_floor_tile_meters := 6.0
## Размер повтора остальных покрытий (м): 1 булыжник, 2 грязь с лужами, 3 плитка с корнями, 4 мох, 5 листва.
@export var floor_tile_meters := PackedFloat32Array([6.0, 5.0, 7.0, 6.0, 5.0, 4.0])
## Ширина перехода между покрытиями (в клетках по 2 м): 0 — резкая граница.
@export_range(0, 4) var floor_blend_cells := 2
## Насколько рвётся граница покрытий.
@export_range(0.0, 1.5) var floor_edge_noise := 0.7
@export_group("Стены")
## Размер повтора текстуры кладки в метрах.
@export var wall_tile_meters := 3.0
## Затемнение кладки под ночной свет.
@export var wall_tint := Color(0.85, 0.85, 0.88)
## Сколько мха на стенах (0..1).
@export_range(0.0, 1.0) var wall_moss := 0.55
## Насколько гуляет высота стен (0.2 — ±20%).
@export_range(0.0, 0.5) var wall_height_variation := 0.2
## Доля кусков стены со сколотым верхом и обломками.
@export_range(0.0, 1.0) var wall_broken_chance := 0.14
## Доля кусков с каменным навершием.
@export_range(0.0, 1.0) var wall_cap_chance := 0.08
## Доля внутренних углов с паутиной.
@export_range(0.0, 1.0) var cobweb_chance := 0.3
@export_group("Кладбище")
## Сколько нарисованных надгробий и крестов расставить.
@export var grave_count := 26
## Сколько оград (кованый забор, низкая стена, разрушенная стена) поставить на кладбищах.
@export var fence_count := 9
## Цвет-затемнение картинок: нарисованы при дневном свете, а в деревне ночь.
@export var grave_tint := Color(0.5, 0.5, 0.56)
## Насколько нарисованные предметы заваливаются в перспективе, как 3D: 0 — никак (кажутся «приклеенными»), 1 — как стоящая стена.
@export_range(0.0, 1.0) var prop_lean := 0.45
## Доля нарисованных мёртвых деревьев среди деревьев рощи и леса за стенами.
@export_range(0.0, 1.0) var painted_tree_chance := 0.5
## Доля нарисованных фонарей среди фонарей вдоль пути.
@export_range(0.0, 1.0) var painted_lamp_chance := 0.5
@export_group("Викторианский свет")
@export var moonlight_energy := 0.14
@export var village_ambient_energy := 0.22
@export var village_fog_density := 0.025
@export var hero_fill_energy := 0.28
@export_range(0.0, 1.0) var stone_wetness := 0.85
@export_range(0.0, 1.0) var stone_relief := 0.35
@export var enhanced_lighting := true
@export_range(0, 500) var falling_petal_count := 180
@export_group("Обучение")
@export var enemy_life := 88.0
@export var enemy_damage := 9.0
## Урон снарядов плевунов и некромантов.
@export var enemy_projectile_damage := 11.0
@export var miniboss_life := 1200.0
@export var miniboss_damage := 18.0
@export var summon_interval := 9.0
@export var summon_count := 3
@export var summon_limit := 6
@export_group("Привратник")
## Во сколько раз модель привратника крупнее обычного громилы.
@export var boss_size := 1.35
## Секунд между кругами-ударами под ногами героя.
@export var boss_nova_interval := 5.0
@export var boss_nova_damage := 20.0
@export_group("Редкие враги и засады")
## Каждый какой отряд получает синего вожака (0 — нет).
@export var magic_leader_every := 3
## Отряды (номера из плана) с жёлтым вожаком.
@export var rare_packs := PackedInt32Array([5, 6, 11, 13, 16, 18])
## Отряды, где есть некромант.
@export var necromancer_packs := PackedInt32Array([3, 6, 9, 11, 14, 17])
## Сколько мертвецов встаёт после сундука или обелиска.
@export var ambush_size := 4
## Центры отрядов. Пусто — берутся из плана уровня (scripts/village_route_plan.gd).
@export var pack_positions := PackedVector2Array()

var _hints := {}
var _boss_down := false
var _clock := 0.0
var _summon_left := 4.0
var _training_gate: StaticBody3D
var _gate_label: Label3D
var _readability_fill: OmniLight3D
var _village_dressing: Node3D
var _petal_rain: GPUParticles3D
var _route_points := PackedVector2Array()
var _main_path_rects: Array[Rect2] = []
var _town_plazas: Array[Rect2] = []
var _floor_cell_counts := [0, 0, 0, 0, 0, 0]
const RoutePlan = preload("res://scripts/village_route_plan.gd")
var _plan: RoutePlan
var _soil_rects: Array[Rect2] = []
const GraveRise := preload("res://scripts/grave_rise.gd")
const FlatSprite := preload("res://scripts/flat_sprite.gd")
const BlendedFloor := preload("res://scripts/blended_floor.gd")
const PROP_CHEST := preload("res://assets/environment/graveyard_2d/chest.png")
const PROP_OBELISK := preload("res://assets/environment/graveyard_2d/obelisk.png")
const PROP_RITUAL := preload("res://assets/environment/graveyard_2d/ritual_circle.png")
const PROP_DEAD_TREE := preload("res://assets/environment/graveyard_2d/dead_tree.png")
const PROP_BENCH := preload("res://assets/environment/graveyard_2d/stone_bench.png")
const PROP_LAMP := preload("res://assets/environment/graveyard_2d/lamp_post.png")
## Свойства жёлтых вожаков первого уровня: заметные эффекты (огонь, молнии, взрыв после смерти).
const RARE_MOD_SETS := [[&"burning", &"swift"], [&"shocking", &"storm"], [&"acidic", &"volatile"]]
var _ambush_sources: Array = []
var _wall_materials: Array[Material] = []
var _wall_noise := FastNoiseLite.new()
var _cobweb_material: ShaderMaterial
var _boss_nova_left := 4.0
var _boss_phase_two := false
var _boss_aura: Node3D


func _ready() -> void:
	set_meta("intro", true)
	zone_level = 1
	_plan = RoutePlan.new()
	_plan.build()
	map_rects = _plan.merged_rects()
	_route_points = _plan.route
	_town_plazas = _plan.plazas
	# Узкое начало мостим одобренной плиткой; поляны — земля, кольцо — бутовый камень.
	_main_path_rects = [Rect2(-20, -90, 40, 110)]
	original_floor_cells = _count_floor_cells()
	if expanded_quarters:
		landmark_rects = _plan.landmark_rects
		landmark_names = _plan.landmark_names
	if pack_positions.is_empty():
		pack_positions = _plan.packs
	exit_position = _plan.exit
	_build_garden()
	var architecture := preload("res://scripts/village_architecture.gd").new()
	architecture.name = "VillageArchitecture"
	architecture.use_gothic_houses = true
	$Navigation.add_child(architecture)
	for lamp_at in _plan.lanterns:
		var at := _beside_wall(lamp_at)
		var painted := _wall_hash(Vector3(at.x, 0, at.y)) < painted_lamp_chance
		architecture.lantern(Vector3(at.x, 0, at.y), 2.6, not painted)
		if painted:
			# Фонарь нарисован рожком влево: рожок должен смотреть от стены — на дорогу.
			var to_wall := at - lamp_at
			var flip := to_wall.x < 0.0 if absf(to_wall.x) > 0.3 else _faces_right(at)
			var lamp := FlatSprite.make(PROP_LAMP, 1.1, flip)
			lamp.modulate = Color(0.78, 0.76, 0.74)
			lamp.position = Vector3(at.x, 0, at.y)
			add_child(lamp)
	architecture.house(Vector3(_plan.tavern.x, 0, _plan.tavern.y), 0, 17, 8, true)
	architecture.lantern(Vector3(_plan.exit.x - 3, 0, _plan.exit.y + 1), 3.0)
	architecture.lantern(Vector3(_plan.exit.x + 3, 0, _plan.exit.y + 1), 3.0)
	# Дверь шире горловины, чтобы обойти её было нельзя.
	if shotgun_gate:
		_training_gate = _box($Navigation, Vector3(_plan.gate.x, 1.1, _plan.gate.y), Vector3(14, 2.2, 0.5), Color(0.16, 0.105, 0.07))
		_training_gate.collision_layer = 16
		_gate_label = Label3D.new()
		_gate_label.position = Vector3(_plan.gate.x, 3, _plan.gate.y)
		_gate_label.text = Loc.t("Экипируйте дробовик, чтобы открыть дверь")
		_gate_label.font = Loc.MAIN_FONT
		_gate_label.font_size = 32
		_gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_gate_label)
	var chest := preload("res://scripts/loot_chest.gd").new()
	chest.position = Vector3(_plan.gate_chest.x, 0.1, _plan.gate_chest.y)
	# Первый сундук на пути: автомат и камень поддержки (огненный заряд) — учит вставлять модификатор.
	chest.guaranteed_base = gate_chest_weapon
	chest.guaranteed_modules.assign(gate_chest_modules)
	chest.sprite = PROP_CHEST
	chest.sprite_flip = _faces_right(_plan.gate_chest)
	add_child(chest)
	if expanded_quarters:
		_build_test_activities(architecture)
	for pack_index in pack_positions.size():
		var center := pack_positions[pack_index]
		for i in pack_size:
			var scene: PackedScene = preload("res://scenes/crawler.tscn")
			if pack_index > 0:
				if i == 3: scene = preload("res://scenes/spitter.tscn")
				elif i == 4: scene = preload("res://scenes/leaper.tscn")
				elif i == 0 and pack_index % 3 == 2: scene = preload("res://scenes/brute.tscn")
				elif i == 2 and pack_index in necromancer_packs: scene = preload("res://scenes/necromancer.tscn")
			var enemy: Enemy = scene.instantiate()
			# Вожак отряда — второй враг: жёлтый с эффектами или синий.
			if i == 1 and pack_index in rare_packs:
				enemy.rarity = 2
				enemy.mods.assign(RARE_MOD_SETS[rare_packs.find(pack_index) % RARE_MOD_SETS.size()])
			elif i == 1 and pack_index > 1 and magic_leader_every > 0 and pack_index % magic_leader_every == 0:
				enemy.rarity = 1
			var at := center + Vector2((i - (pack_size - 1) * 0.5) * 1.5, 0)
			# Враг отряда на узкой тропе не должен появиться в стене.
			if not _plan.has_floor(at) or _plan.distance_to_edge(at, 2.0) < 1.5:
				at = center + Vector2(0, (i - (pack_size - 1) * 0.5) * 1.5)
				if not _plan.has_floor(at): at = center
			enemy.position = Vector3(at.x, 0.1, at.y)
			enemy.max_hp = enemy_life * (2.0 if scene == preload("res://scenes/brute.tscn") else 1.0)
			enemy.damage = enemy_damage * (1.6 if scene == preload("res://scenes/brute.tscn") else 1.0)
			if scene == preload("res://scenes/spitter.tscn") or scene == preload("res://scenes/necromancer.tscn"): enemy.projectile_damage = enemy_projectile_damage
			enemy.xp_reward = 0
			enemy.drops_enabled = true
			enemy.gear_drop_chance = enemy_gear_drop_chance
			enemy.currency_drop_chance = enemy_currency_drop_chance
			enemy.aggro_range = 9
			enemy.wake_radius = 5
			enemy.wander_radius = 1
			add_child(enemy)
	var boss: Enemy = preload("res://scenes/brute.tscn").instantiate()
	boss.name = "IntroGuardian"
	boss.display_name = "Проклятый привратник"
	boss.position = Vector3(_plan.boss.x, 0.1, _plan.boss.y)
	# Жёлтый (редкий): множители редкости заранее сняты, чтобы итог был близок к miniboss_life/damage.
	boss.rarity = 2
	boss.mods.assign([&"burning"])
	boss.max_hp = miniboss_life * 1.2 / 3.5
	boss.damage = miniboss_damage / 1.3
	boss.humanoid_scale *= boss_size
	boss.attack_range *= boss_size
	boss.attack_reach *= boss_size
	var boss_shape := boss.get_node("CollisionShape3D") as CollisionShape3D
	boss_shape.shape = boss_shape.shape.duplicate()
	boss_shape.shape.radius *= 1.3
	boss.move_speed = 2.2
	boss.attack_windup = 0.9
	boss.attack_cooldown = 1.6
	boss.armor = 0.15
	boss.xp_reward = 0
	boss.drops_enabled = false
	boss.death_spawn_scene = null
	boss.guards_exit = true
	boss.aggro_range = 10
	boss.wake_radius = 0
	boss.wander_radius = 0
	boss.died.connect(_on_boss_defeated)
	add_child(boss)
	boss.set("_rare_parts", [])  # имя остаётся «Проклятый привратник»
	_build_boss_aura(boss)
	_pickup(&"plasma_cutter", _plan.plasma_pickup.y, _plan.plasma_pickup.x)
	var support := preload("res://scripts/loot_pickup.gd").new()
	support.kind = &"module"
	support.module = preload("res://data/modules/damage.tres")
	support.position = Vector3(_plan.support_pickup.x, 0.1, _plan.support_pickup.y)
	add_child(support)
	_apply_village_light()
	_petal_rain = preload("res://scripts/village_petal_rain.gd").new()
	_petal_rain.petal_count = falling_petal_count
	_petal_rain.position = Vector3(0, 5, 8)
	add_child(_petal_rain)
	$Navigation.bake_navigation_mesh(true)
	_remove_owned_pickups.call_deferred()


## Считаем уникальные клетки, чтобы сравнивать реальную площадь, а не перекрывающиеся прямоугольники.
func _count_floor_cells() -> int:
	var cells := {}
	for rect in map_rects:
		for x in range(int(rect.position.x), int(rect.end.x), 2):
			for z in range(int(rect.position.y), int(rect.end.y), 2):
				cells[Vector2i(x, z)] = true
	return cells.size()


## Точка у ближайшей стены (в пределах 8 м): фонари и мебель не загораживают проход.
func _beside_wall(at: Vector2, gap := 1.3) -> Vector2:
	var best := at
	var best_distance := INF
	for step in 16:
		var dir := Vector2.from_angle(step * TAU / 16)
		for d in range(1, 17):
			var p := at + dir * d * 0.5
			if not _plan.has_floor(p):
				if d * 0.5 < best_distance:
					best_distance = d * 0.5
					best = at + dir * (d * 0.5 - gap)  # слишком близко к стене — отходим назад
				break
	return best


func _build_test_activities(architecture: Node3D) -> void:
	var quests := preload("res://scripts/zone_quests.gd").new()
	quests.name = "Quests"
	quests.enabled_quests.assign([&"chests", &"obelisks", &"seals", &"landmarks"])
	add_child(quests)
	for index in _plan.chests.size():
		var at: Vector2 = _plan.chests[index]
		var chest := preload("res://scripts/loot_chest.gd").new()
		chest.position = Vector3(at.x, 0.1, at.y)
		chest.item_counts = Vector3i(1, 1, 1)
		# Тупик могильщика — точно дробовик; рынок — ещё один камень поддержки (рикошет).
		if index == 0:
			pass  # дробовик теперь стартовый — здесь обычная добыча
		elif index == 1:
			chest.guaranteed_modules.assign(second_chest_modules)
		chest.sprite = PROP_CHEST
		chest.sprite_flip = _faces_right(at)
		add_child(chest)
		_ambush_sources.append([chest, false])
	for at: Vector2 in _plan.obelisks:
		var obelisk := preload("res://scripts/destructible.gd").new()
		obelisk.position = Vector3(at.x, 0.1, at.y)
		obelisk.max_hp = 180
		obelisk.sprite = PROP_OBELISK
		add_child(obelisk)
		_ambush_sources.append([obelisk, true])
	var ritual := preload("res://scripts/seal_event.gd").new()
	ritual.name = "VillageRitual"
	ritual.position = Vector3(_plan.ritual.x, 0.1, _plan.ritual.y)
	ritual.gothic_altar = true
	ritual.altar_sprite = PROP_RITUAL
	ritual.magic_chance = 0.0
	ritual.final_rare_leader = false
	ritual.enemy_life = enemy_life
	ritual.enemy_damage = enemy_damage
	ritual.wave_timeout = 0.0
	ritual.waves = [PackedStringArray(["crawler", "crawler", "leaper", "spitter"]), PackedStringArray(["crawler", "leaper", "spitter", "brute"])]
	add_child(ritual)
	# Летающие надписи мест убраны: название появляется сообщением при входе в место.


## При продолжении обучения не размножаем уже сохранённые учебные предметы.
func _remove_owned_pickups() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		return
	var items: Array = player.inventory.weapons.duplicate()
	for entry in player.inventory.entries:
		items.append(entry.item)
	var bases := {}
	var modules := {}
	for item in items:
		if item is GearItem:
			bases[item.base.id] = true
			for support in item.modules + item.secondary_modules:
				if support != null:
					modules[support.id] = true
		elif item is ModuleData:
			modules[item.id] = true
	for child in get_children():
		if child.get_script() == preload("res://scripts/loot_pickup.gd"):
			if (child.kind == &"gear" and bases.has(child.gear_base)) or (child.kind == &"module" and modules.has(child.module.id)):
				child.queue_free()
		elif child.get_script() == preload("res://scripts/loot_chest.gd") and child.guaranteed_base != &"" and bases.has(child.guaranteed_base):
			child._opened = true
			child.remove_from_group("interactables")
			child._label.visible = false


func _build_garden() -> void:
	var cells := {}
	for rect in map_rects:
		var floor_body := _box($Navigation, Vector3(rect.get_center().x, -0.5, rect.get_center().y), Vector3(rect.size.x, 1, rect.size.y), Color(0.25, 0.27, 0.28))
		# Keep the floor colliders, but render one non-overlapping cell mesh per material.
		(floor_body.get_child(1) as MeshInstance3D).visible = false
		for x in range(int(rect.position.x), int(rect.end.x), 2):
			for z in range(int(rect.position.y), int(rect.end.y), 2):
				cells[Vector2i(x, z)] = true
	_build_town_floor(cells)
	_village_dressing = preload("res://scripts/village_set_dressing.gd").new()
	_village_dressing.name = "VillageDressing"
	$Navigation.add_child(_village_dressing)
	# Tall masonry edges follow the exact playable plan; bends remain open.
	for cell: Vector2i in cells:
		for dir in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			if cells.has(cell + dir):
				continue
			var at := Vector3(cell.x + 1 + dir.x * 0.5, 0, cell.y + 1 + dir.y * 0.5)
			_vary_wall(_village_dressing.wall($Navigation, at, dir.x != 0, _wall_material(at)), at)
		# Внутренний угол (стены с двух сторон) — иногда паутина.
		for corner in [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]:
			if not cells.has(cell + Vector2i(corner.x, 0)) and not cells.has(cell + Vector2i(0, corner.y)) and _wall_hash(Vector3(cell.x, 0, cell.y) + Vector3(corner.x, 0, corner.y) * 0.3) < cobweb_chance:
				_cobweb(Vector3(cell.x + 1 + corner.x * 0.5, 0, cell.y + 1 + corner.y * 0.5), Vector2(-corner.x, -corner.y).normalized())
	var ruins := preload("res://scripts/town_ruin_dressing.gd").new()
	ruins.name = "TownRuins"
	$Navigation.add_child(ruins)
	_dress_route(ruins)
	var rng := RandomNumberGenerator.new()
	rng.seed = 701
	# Грунт и скалы за ограждением: декорация не добавляет обходных путей.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 320)
	ground.mesh = plane
	ground.position = Vector3(0, -1.2, -112)
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.12, 0.115, 0.11)
	dust.roughness = 1
	ground.material_override = dust
	add_child(ground)
	for i in 90:
		var rock: Node3D = preload("res://assets/nature/Rock_Medium_1.gltf").instantiate()
		rock.position = Vector3(rng.randf_range(-80, 80), -1, rng.randf_range(-260, 30))
		# Скалы только за стенами: под полом они протыкали бы плитку.
		if _plan.near_floor(Vector2(rock.position.x, rock.position.z), 6.0):
			rock.free()
			continue
		rock.rotation.y = rng.randf() * TAU
		rock.scale = Vector3.ONE * rng.randf_range(1.5, 3.5)
		add_child(rock)


## Обстановка по плану: острова на полянах, арки на перешейках, мебель и завалы у стен, лес за стенами.
func _dress_route(ruins: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1888
	var busy: Array[Vector2] = [_plan.start, _plan.gate, _plan.gate_chest, _plan.boss, _plan.exit, _plan.ritual, _plan.rifle_pickup, _plan.plasma_pickup, _plan.support_pickup]
	busy.append_array(_plan.chests)
	busy.append_array(_plan.obelisks)
	busy.append_array(_plan.lanterns)
	for island in _plan.islands:
		_island(island[0], island[1], island[2], rng)
		busy.append(island[0])
	# Арки отмечают переход в новую часть уровня.
	for passage in [[Vector2(0, -188), Vector2(0, -1)], [Vector2(7, -132), Vector2(6, -16)], [Vector2(-40, -100), Vector2(-24, 8)]]:
		_village_dressing.gate(Vector3(passage[0].x, 0, passage[0].y), atan2(passage[1].x, passage[1].y))
		busy.append(passage[0])
	var mounds := []
	var hanging := []
	var rubble := []
	var stalls := []
	var placed: Array[Vector2] = []
	for cell: Vector2i in _plan.cells:
		var at := Vector2(cell.x + 1, cell.y + 1)
		if rng.randf() > 0.35:
			continue
		var edge := _plan.distance_to_edge(at, 4.0)
		if edge > 2.6 or _plan.distance_to_route(at) < 4.5 or _near_any(placed, at, 6.5) or _near_any(busy, at, 4.5):
			continue
		placed.append(at)
		var spot := _beside_wall(at, 1.1)
		var where := Vector3(spot.x, 0, spot.y)
		var roll := rng.randi() % 7
		if at.x < -24 and at.y < -200 and stalls.size() < 4:
			stalls.append(where)
		elif roll == 0: _village_dressing.prop(_village_dressing.Barrel, where, Vector3(0.95, 1.1, 0.95))
		elif roll == 1:
			_village_dressing.prop(_village_dressing.Basket, where, Vector3(0.95, 0.75, 0.95))
			_village_dressing.prop(_village_dressing.Crate, where + Vector3(1.2, 0, 0.3), Vector3(1.0, 0.9, 1.0), 0.12)
		elif roll == 2:
			_village_dressing.prop(_village_dressing.Planter, where, Vector3(1.8, 0.75, 1.8))
			var tree: Node3D = _village_dressing.RedTree.instantiate()
			tree.position = where + Vector3(0, 0.65, 0)
			tree.scale = Vector3.ONE * 0.72
			_village_dressing.add_child(tree)
			preload("res://scripts/village_materials.gd").apply(tree)
		elif roll == 3 and hanging.size() < 8: hanging.append(where + Vector3(0, 0.3, 0))
		elif roll == 4 and mounds.size() < 6 and edge > 1.5: mounds.append(where)
		elif roll == 5:
			_flat_prop(PROP_BENCH, spot, 2.2, Vector3(2.0, 0.7, 0.7), 0.0, false, rng.randf() < 0.5)
		else: rubble.append(where)
	ruins.populate_at(_village_dressing, mounds, hanging, rubble, stalls)
	_place_graves(rng, busy)
	# Лес за оградой: кроны закрывают пустоту по краям и не открывают новых путей.
	var trees := 0
	for x in range(-84, 86, 5):
		for z in range(-268, 30, 5):
			var at := Vector2(x, z) + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
			if _plan.near_floor(at, 2.5) or not _plan.near_floor(at, 9.0) or rng.randf() < 0.35:
				continue
			if rng.randf() < painted_tree_chance:
				var painted := FlatSprite.make(PROP_DEAD_TREE, rng.randf_range(3.5, 5.0), rng.randf() < 0.5)
				painted.modulate = grave_tint
				painted.position = Vector3(at.x, -1.0, at.y)
				_village_dressing.add_child(painted)
				trees += 1
				continue
			var tree: Node3D = (_village_dressing.RedTree if trees % 3 == 0 else _village_dressing.BareTree).instantiate()
			tree.position = Vector3(at.x, -1.1, at.y)
			tree.rotation.y = rng.randf() * TAU
			tree.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
			_village_dressing.add_child(tree)
			preload("res://scripts/village_materials.gd").apply(tree)
			trees += 1


## Нарисованные надгробия и кресты (2D-картинки, повёрнутые к камере) на кладбищенских местах.
func _place_graves(rng: RandomNumberGenerator, busy: Array[Vector2]) -> void:
	var kinds := [
		[preload("res://assets/environment/graveyard_2d/tombstone_arch.png"), 1.7, Vector3(1.0, 1.2, 0.6)],
		[preload("res://assets/environment/graveyard_2d/stone_cross.png"), 2.0, Vector3(0.9, 1.4, 0.9)],
		[preload("res://assets/environment/graveyard_2d/tombstone_candles.png"), 1.5, Vector3(1.7, 1.1, 0.8)],
	]
	var areas := [[Vector2(-4, -106), Vector2(24, 17)], [Vector2(-56, -94), Vector2(8, 7)], [Vector2(34, -214), Vector2(9, 11)]]
	var placed: Array[Vector2] = []
	var avoid: Array[Vector2] = busy.duplicate()
	avoid.append_array(pack_positions)
	# Сначала ограды: нарисованы под углом ~11°, такой же поворот получает их преграда.
	var fences := [
		[preload("res://assets/environment/graveyard_2d/fence_iron.png"), 4.4, Vector3(4.2, 1.6, 0.5)],
		[preload("res://assets/environment/graveyard_2d/wall_low.png"), 4.6, Vector3(4.4, 1.0, 0.6)],
		[preload("res://assets/environment/graveyard_2d/wall_broken.png"), 4.4, Vector3(4.2, 1.0, 0.6)],
	]
	var fence_spots: Array[Vector2] = []
	for area in areas:
		for x in range(int(area[0].x - area[1].x), int(area[0].x + area[1].x), 4):
			for z in range(int(area[0].y - area[1].y), int(area[0].y + area[1].y), 4):
				fence_spots.append(Vector2(x, z) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
	fence_spots.shuffle()
	var fence_index := 0
	for spot: Vector2 in fence_spots:
		if fence_index >= fence_count:
			break
		# Забор длинный: пол и свободное место нужны по обе стороны от центра.
		var clear := true
		for end in [spot + Vector2(-2.2, 0), spot, spot + Vector2(2.2, 0)]:
			if not _plan.has_floor(end) or _plan.distance_to_edge(end, 3.0) < 1.6 or _plan.distance_to_route(end) < 4.0 or _near_any(avoid, end, 3.5) or _near_any(placed, end, 3.0):
				clear = false
		if not clear:
			continue
		var fence: Array = fences[fence_index % fences.size()]
		fence_index += 1
		_flat_prop(fence[0], spot, fence[1], fence[2], deg_to_rad(-11.0), false)
		avoid.append(spot)
		placed.append(spot)
		placed.append(spot + Vector2(-1.8, 0))
		placed.append(spot + Vector2(1.8, 0))
	var graves := 0
	for area in areas:
		var center: Vector2 = area[0]
		var radius: Vector2 = area[1]
		for x in range(int(center.x - radius.x), int(center.x + radius.x), 3):
			for z in range(int(center.y - radius.y), int(center.y + radius.y), 3):
				var at := Vector2(x, z) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
				if graves >= grave_count or rng.randf() < 0.45:
					continue
				if not _plan.has_floor(at) or _plan.distance_to_edge(at, 3.0) < 1.6 or _plan.distance_to_route(at) < 4.0:
					continue
				if _near_any(placed, at, 3.2) or _near_any(avoid, at, 4.5):
					continue
				placed.append(at)
				graves += 1
				var roll := rng.randf()
				var kind: Array = kinds[0 if roll < 0.45 else (1 if roll < 0.8 else 2)]
				_flat_prop(kind[0], at, kind[1] * texture_aspect(kind[0]), kind[2], 0.0, kind == kinds[2])


static func texture_aspect(texture: Texture2D) -> float:
	return float(texture.get_width()) / texture.get_height()


## Нарисованный предмет: вертикальная плоскость лицом к камере (не поворачивается за ней),
## поэтому в перспективе заваливается вместе с настоящими 3D-предметами. Высоту растягиваем на 1/cos(угла камеры),
## чтобы на экране картинка выглядела как нарисована. width — ширина в метрах, yaw — поворот преграды.
func _flat_prop(texture: Texture2D, at: Vector2, width: float, block: Vector3, yaw: float, candles: bool, flip := false) -> void:
	var elevation: float = $CameraRig.get("elevation_degrees") if $CameraRig.get("elevation_degrees") != null else 52.0
	var sprite := FlatSprite.make(texture, width, flip, false, prop_lean, elevation)
	sprite.modulate = grave_tint
	sprite.position = Vector3(at.x, 0.0, at.y)
	_village_dressing.add_child(sprite)
	_village_dressing.solid(Vector3(at.x, block.y * 0.5, at.y), block, _village_dressing, yaw)
	if candles:
		var flame := OmniLight3D.new()
		flame.light_color = Color(1.0, 0.7, 0.35)
		flame.light_energy = 1.4
		flame.omni_range = 4.5
		flame.position = Vector3(at.x - 0.5, 0.6, at.y + 0.4)
		_village_dressing.add_child(flame)


func _near_any(points: Array, at: Vector2, distance: float) -> bool:
	for p: Vector2 in points:
		if p.distance_to(at) < distance:
			return true
	return false


## Остров-препятствие: склеп в низкой ограде, мёртвое дерево в камнях, валун или колонна.
func _island(at: Vector2, size: Vector2, kind: StringName, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Island_%s" % kind
	root.position = Vector3(at.x, 0, at.y)
	_village_dressing.add_child(root)
	var height: float = {&"crypt": 1.2, &"tree": 3.0, &"rock": 1.6, &"column": 3.2}[kind]
	var body: StaticBody3D = _village_dressing.solid(Vector3(at.x, height * 0.5, at.y), Vector3(size.x, height, size.y), _village_dressing)
	body.set_meta("village_occluder", root)
	match kind:
		&"crypt":
			var low_wall: PackedScene = preload("res://assets/environment/victorian_kit/v1/wall_low_stone.glb")
			for side in 4:
				var along_x := side < 2
				var length: float = size.x if along_x else size.y
				var count := maxi(1, roundi(length / 2.1))
				for i in count:
					var piece: Node3D = low_wall.instantiate()
					var offset := (i + 0.5) * length / count - length * 0.5
					var edge_offset: float = (size.y if along_x else size.x) * 0.5 * (1 if side % 2 == 0 else -1)
					piece.position = Vector3(offset, 0, edge_offset) if along_x else Vector3(edge_offset, 0, offset)
					piece.rotation.y = 0.0 if along_x else PI * 0.5
					piece.scale.x = length / count / 2.1
					root.add_child(piece)
					# Ограда склепа — та же кладка с плющом, что и на стенах.
					for mesh: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
						mesh.material_override = _wall_material(Vector3(at.x, 0, at.y)) if _wall_materials.is_empty() else _wall_materials[0]
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var pillar: Node3D = preload("res://assets/environment/victorian_kit/v1/pillar_square.glb").instantiate()
				pillar.position = Vector3(corner.x * size.x * 0.5, 0, corner.y * size.y * 0.5)
				pillar.scale = Vector3(0.8, 0.7, 0.8)
				root.add_child(pillar)
				_dress_like_wall(pillar, Vector3(at.x, 0, at.y))
			var tomb: Node3D = preload("res://assets/environment/threshold_set/v1/column_cap.glb").instantiate()
			tomb.rotation.y = rng.randf() * TAU
			root.add_child(tomb)
			_dress_like_wall(tomb, Vector3(at.x, 0, at.y))
		&"tree":
			if rng.randf() < painted_tree_chance:
				var painted := FlatSprite.make(PROP_DEAD_TREE, rng.randf_range(3.8, 4.6), rng.randf() < 0.5)
				painted.modulate = grave_tint
				root.add_child(painted)
			else:
				var tree: Node3D = preload("res://assets/nature/DeadTree_1.gltf").instantiate()
				tree.rotation.y = rng.randf() * TAU
				tree.scale = Vector3.ONE * rng.randf_range(0.6, 0.8)
				root.add_child(tree)
			for i in 4:
				var stone: Node3D = preload("res://assets/nature/Rock_Medium_2.gltf").instantiate()
				stone.position = Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 4 + rng.randf()) * size.x * 0.45
				stone.rotation.y = rng.randf() * TAU
				stone.scale = Vector3.ONE * rng.randf_range(0.35, 0.5)
				root.add_child(stone)
		&"rock":
			var rock: Node3D = preload("res://assets/nature/Rock_Medium_2.gltf").instantiate()
			rock.rotation.y = rng.randf() * TAU
			rock.scale = Vector3.ONE * size.x / 2.6
			root.add_child(rock)
		&"column":
			root.add_child(preload("res://assets/environment/victorian_kit/v1/pillar_square.glb").instantiate())
	preload("res://scripts/village_materials.gd").apply(root)


## Кладка стены по месту: начало — камень с плющом, поляны — плющ вперемешку с облупленной штукатуркой,
## у кольца привратника — ровная тёмная кладка. Пятна вариантов задаёт шум, чтобы не было полос.
func _wall_material(at: Vector3) -> Material:
	if _wall_materials.is_empty():
		for path in ["res://assets/textures/level1_v3/wall_ivy_stone_albedo.png", "res://assets/textures/level1_v3/wall_plaster_ruin_albedo.png", "res://assets/textures/level1_v3/wall_dark_blocks_albedo.png"]:
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/shaders/village_wall.gdshader")
			mat.set_shader_parameter("base_tex", load(path))
			mat.set_shader_parameter("moss_tex", preload("res://assets/textures/level1_v3/floor_moss_albedo.png"))
			mat.set_shader_parameter("tint", wall_tint)
			mat.set_shader_parameter("tile_meters", wall_tile_meters)
			mat.set_shader_parameter("moss_amount", wall_moss)
			_wall_materials.append(mat)
		_wall_noise.seed = 77
		_wall_noise.frequency = 0.06
	var n := _wall_noise.get_noise_2d(at.x, at.z)
	if at.distance_to(Vector3(_plan.ring_center.x, 0, _plan.ring_center.y)) < _plan.ring_radii.y + 16.0:
		return _wall_materials[0] if n > 0.35 else _wall_materials[2]
	if at.z > -88.0:
		return _wall_materials[1] if n > 0.3 else _wall_materials[0]
	return _wall_materials[0] if n < 0.0 else _wall_materials[1]


## Сундук нарисован замком влево: зеркалим, если ближайшая дорога правее — замок смотрит на дорогу и героя.
func _faces_right(at: Vector2) -> bool:
	var nearest := at
	var best := INF
	for i in _plan.route.size() - 1:
		var p := Geometry2D.get_closest_point_to_segment(at, _plan.route[i], _plan.route[i + 1])
		if p.distance_to(at) < best:
			best = p.distance_to(at)
			nearest = p
	return nearest.x > at.x


## Одинаковый для точки «случайный» номер 0..1: стены выглядят одинаково при каждом запуске.
func _wall_hash(at: Vector3) -> float:
	return fposmod(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453, 1.0)


## Разные верха: высота гуляет пятнами, местами верх сколот (без карниза, с обломками), местами навершие.
func _vary_wall(body: StaticBody3D, at: Vector3) -> void:
	var model := body.get_meta("village_occluder") as Node3D
	var height := 1.0 + _wall_noise.get_noise_2d(at.x * 0.9 + 300.0, at.z * 0.9) * wall_height_variation
	model.scale.y = height
	var top := 2.92 * height
	var roll := _wall_hash(at)
	if roll < wall_broken_chance:
		# Сколотый верх: карниз той же кладкой, сверху обломки.
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mesh.set_surface_override_material(1, mesh.get_surface_override_material(0))
		var rubble: Node3D = preload("res://assets/environment/town_ruins/rubble.glb").instantiate()
		rubble.position = Vector3(0, top - 1.4 - 0.1, 0)
		rubble.rotation.y = roll * 40.0
		rubble.scale = Vector3(0.55, 0.7, 0.4)
		body.add_child(rubble)
		_dress_like_wall(rubble, at)
	elif roll < wall_broken_chance + wall_cap_chance:
		var cap: Node3D = preload("res://assets/environment/threshold_set/v1/column_cap.glb").instantiate()
		cap.position = Vector3(0, top - 1.4 - 0.05, 0)
		cap.scale = Vector3(0.9, 0.32, 0.9)
		body.add_child(cap)
		_dress_like_wall(cap, at)


## Обломки и навершия той же кладкой, что и стена под ними, — не выделяются светлыми пятнами.
func _dress_like_wall(node: Node3D, at: Vector3) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _wall_material(at)


## Паутина: квадрат по диагонали угла, верхний край у гребня стены.
func _cobweb(corner: Vector3, inward: Vector2) -> void:
	if _cobweb_material == null:
		_cobweb_material = ShaderMaterial.new()
		_cobweb_material.shader = preload("res://assets/shaders/cobweb.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var web := MeshInstance3D.new()
	web.mesh = quad
	web.material_override = _cobweb_material
	web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var height := 2.6 + _wall_noise.get_noise_2d(corner.x * 0.9 + 300.0, corner.z * 0.9) * wall_height_variation * 2.6
	web.position = corner + Vector3(inward.x, 0, inward.y) * 1.0 + Vector3.UP * (height - 0.8)
	# Плоскость поперёк угла: смотрит из угла наружу, к игроку.
	web.rotation.y = atan2(inward.x, inward.y)
	web.set_instance_shader_parameter("seed", corner.x + corner.z)
	add_child(web)


func _fit_plant(plant: Node3D, height: float) -> void:
	var bounds := AABB()
	var has_bounds := false
	for node in plant.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local_bounds: AABB = (plant.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null:
				var tint := material.duplicate() as StandardMaterial3D
				tint.albedo_color *= Color(0.58, 0.65, 0.52)
				mesh.set_surface_override_material(surface, tint)
	if has_bounds and bounds.size.y > 0.01:
		plant.scale *= height / bounds.size.y


func _build_town_floor(cells: Dictionary) -> void:
	var textures := BlendedFloor.default_textures()
	textures[0] = garden_floor_texture
	var variants := {}
	for cell: Vector2i in cells:
		var center := Vector2(cell.x + 1, cell.y + 1)
		var variant := 2
		for rect in _main_path_rects:
			if rect.has_point(center): variant = 0
		# Поляны: кладбище во мху, роща и дальние дворы в палой листве; тропинки между ними — грязь с лужами.
		if variant == 2 and _plan != null and _plan.distance_to_edge(center, 6.0) > 3.0:
			variant = 4 if center.y > -135.0 else 5
		# Кольцо вокруг площади привратника — старая плитка, проросшая корнями.
		if _plan != null:
			var ring_distance := center.distance_to(_plan.ring_center)
			if ring_distance > _plan.ring_radii.x - 1.0 and ring_distance < _plan.ring_radii.y + 1.0: variant = 3
		for i in _town_plazas.size():
			if _town_plazas[i].has_point(center): variant = 3 if i % 2 else 0
		var road_distance := INF
		for i in _route_points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(center, _route_points[i], _route_points[i + 1])
			road_distance = minf(road_distance, center.distance_to(closest))
		if road_distance < 2.3: variant = 1
		_floor_cell_counts[variant] += 1
		variants[cell] = variant
	var tiles := PackedFloat32Array()
	var wets := PackedFloat32Array()
	var reliefs := PackedFloat32Array()
	for i in 6:
		tiles.append(garden_floor_tile_meters if i == 0 else floor_tile_meters[mini(i, floor_tile_meters.size() - 1)])
		# Камень мокро блестит; лужи — тоже; мох и листва матовые.
		wets.append(stone_wetness if i <= 3 else 0.15)
		reliefs.append(stone_relief if i <= 3 else 0.08)
	add_child(BlendedFloor.build(variants, textures, tiles, wets, reliefs, floor_blend_cells, floor_edge_noise))


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	parent.add_child(body)
	return body


func _light(at: Vector3, color: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.omni_range = 9
	lamp.light_energy = 1.8
	add_child(lamp)


func _label(title: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = Loc.t(title)
	label.position = at
	label.font = Loc.TITLE_FONT
	label.font_size = 32
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _pickup(base: StringName, z: float, x := 0.0) -> void:
	var pickup := preload("res://scripts/loot_pickup.gd").new()
	pickup.kind = &"gear"
	pickup.gear_base = base
	pickup.position = Vector3(x, 0.1, z)
	add_child(pickup)


func _on_boss_defeated() -> void:
	_boss_down = true
	if is_instance_valid(_boss_aura):
		_boss_aura.queue_free()
	for raised in get_tree().get_nodes_in_group("intro_reinforcements"):
		if is_instance_valid(raised) and raised is Enemy and not raised.is_dead():
			raised.take_damage(raised.hp + 1000.0, &"physical", null, false)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.level == 1:
			player.add_xp(player.xp_for_next_level() - player.xp)
		player.show_message(Loc.t("Путь свободен. Получено очко пассивок — откройте дерево развития. В таверне можно передохнуть."), 8)


func _process(delta: float) -> void:
	super(delta)
	_clock -= delta
	if _clock > 0:
		return
	_clock = 0.3
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not is_ancestor_of(player):
		return
	_update_village_lamps(player)
	if _petal_rain: _petal_rain.global_position = player.global_position + Vector3(0, 5, 0)
	if _village_dressing:
		_village_dressing.update_occlusion(player, get_viewport().get_camera_3d())
	if is_instance_valid(_training_gate):
		if player.fixed_bow_loadout:
			_training_gate.queue_free()
			_gate_label.queue_free()
		for weapon in player.inventory.weapons:
			if not player.fixed_bow_loadout and weapon != null and weapon.base.id == &"shotgun":
				_training_gate.queue_free()
				_gate_label.queue_free()
				Sfx.play(&"door_unlock", player.global_position)
				player.show_message(Loc.t("Дробовик экипирован. Дверь открыта — продолжайте путь."), 5)
				break
	if not player.fixed_bow_loadout:
		if shotgun_gate:
			_hint(player, "equip_gate", player.position.z < _plan.hint_gate_z, "Откройте сундук у двери. Подберите дробовик, откройте инвентарь и экипируйте оружие — дверь разблокируется.")
		else:
			_hint(player, "equip_gate", player.position.z < _plan.hint_gate_z, "Откройте сундук: в нём камень поддержки. Вставьте его в гнездо навыка коломёта (K).")
	_check_ambushes(player)
	var boss := get_node_or_null("IntroGuardian") as Enemy
	if boss != null and not _boss_down and boss.global_position.distance_to(player.global_position) < 18:
		_summon_left -= 0.3
		if _summon_left <= 0:
			_summon_left = summon_interval
			_summon(boss)
		_boss_nova_left -= 0.3
		if _boss_nova_left <= 0 and boss.get("_state") != Enemy.State.SLEEP:
			_boss_nova_left = boss_nova_interval
			# Три круга вокруг героя: стоять нельзя, надо двигаться.
			for k in 3:
				var offset := Vector3.ZERO if k == 0 else Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 3.2
				boss._delayed_blast(player.global_position + offset, 2.2, boss_nova_damage, &"fire", GraveRise.COLOR, 1.2 + k * 0.2)
		if not _boss_phase_two and boss.hp < boss.max_hp * 0.5:
			_boss_phase_two = true
			Sfx.play(&"boss_roar", boss.global_position)
			Fx.shake(0.35)
			player.show_message(Loc.t("Привратник поднимает мертвецов!"), 3)
			for k in 6:
				GraveRise.raise(self, preload("res://scenes/crawler.tscn"), boss.global_position + Vector3(cos(k * TAU / 6), 0, sin(k * TAU / 6)) * 6.0, _setup_reinforcement, 0.6 + k * 0.12)
	_hint(player, "move", true, "Доберитесь до таверны «Последний огонь». WASD / левый стик — движение; ЛКМ / RT — выстрел; Space / A — перекат.")
	if not player.fixed_bow_loadout:
		_hint(player, "rifle", player.position.z < _plan.hint_quarters_z, "Боковые тропы ведут к сундукам, обелискам и ритуалу. Исследуйте их ради дополнительной добычи.")
	var item: GearItem = player.weapon_item(player.current_weapon_index())
	_hint(player, "grenade", item != null and item.base.id == &"rifle", "Коломёт бьёт тяжёлыми кольями. Добивающий кол отбрасывает врага.")
	_hint(player, "switch", item != null and item.base.id == &"shotgun", "Сменить оружие — 1, 2, 3 или колесо мыши / крестовина.")
	if not player.fixed_bow_loadout:
		_hint(player, "plasma", player.position.z < _plan.hint_plasma_z, "Запасное оружие: %s — зарядить усиленный выстрел. Модификаторы двух навыков независимы." % Loc.action_key("skill_grenade"))
		_hint(player, "support", player.position.z < _plan.hint_support_z, "Модификатор усиливает навык. Нажмите K и вставьте его в свободное круглое гнездо нужного навыка.")
	_hint(player, "boss", player.position.z < _plan.hint_boss_z, "Проклятый привратник преграждает путь к таверне. Уходите перекатом от его замаха.")
	if _boss_down and player.position.z < _plan.exit.y + 1 and not Game.is_transitioning():
		Game.complete_zone(player)


func _summon(boss: Enemy) -> void:
	var remaining := summon_limit - get_tree().get_nodes_in_group("intro_reinforcements").size()
	for i in mini(summon_count, remaining):
		var at := boss.global_position + Vector3(cos(i * TAU / summon_count), 0, sin(i * TAU / summon_count)) * 4
		GraveRise.raise(self, preload("res://scenes/crawler.tscn"), at, _setup_reinforcement)


func _setup_reinforcement(enemy: Enemy) -> void:
	enemy.max_hp = enemy_life
	enemy.damage = enemy_damage
	enemy.add_to_group("intro_reinforcements")


## Сундук открыт или обелиск разбит — вокруг героя встают мертвецы, у обелиска с ними некромант.
func _check_ambushes(player: Node3D) -> void:
	for source in _ambush_sources:
		if source[0] == null:
			continue
		var node = source[0]
		var fired: bool = not is_instance_valid(node) or node.get("_opened") == true or node.get("destroyed") == true
		if not fired:
			continue
		source[0] = null
		player.show_message(Loc.t("Мертвецы поднимаются!"), 2.5)
		var kinds: Array[PackedScene] = []
		for k in ambush_size:
			kinds.append(preload("res://scenes/leaper.tscn") if k == ambush_size - 1 else preload("res://scenes/crawler.tscn"))
		if source[1]:
			kinds.append(preload("res://scenes/necromancer.tscn"))
		for k in kinds.size():
			var angle := k * TAU / kinds.size() + randf() * 0.5
			var distance := 9.0 if kinds[k] == preload("res://scenes/necromancer.tscn") else randf_range(4.5, 6.5)
			var at := player.global_position + Vector3(cos(angle), 0, sin(angle)) * distance
			GraveRise.raise(self, kinds[k], at, _setup_ambusher, 0.6 + k * 0.25)


func _setup_ambusher(enemy: Enemy) -> void:
	enemy.max_hp = enemy_life * (1.2 if enemy.scene_file_path.ends_with("necromancer.tscn") else 1.0)
	enemy.damage = enemy_damage
	if "projectile_damage" in enemy: enemy.set("projectile_damage", enemy_projectile_damage)
	enemy.aggro_range = 20
	enemy.drops_enabled = true
	enemy.gear_drop_chance = enemy_gear_drop_chance
	enemy.currency_drop_chance = enemy_currency_drop_chance


## Аура привратника: фиолетовый свет и медленно вращающийся круг под ногами.
func _build_boss_aura(boss: Enemy) -> void:
	_boss_aura = Node3D.new()
	boss.add_child(_boss_aura)
	var light := OmniLight3D.new()
	light.light_color = GraveRise.COLOR
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.position.y = 2.0
	_boss_aura.add_child(light)
	var circle := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(5.5, 5.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = preload("res://assets/vfx/circle_05.png")
	material.albedo_color = Color(GraveRise.COLOR, 0.55)
	quad.material = material
	circle.mesh = quad
	circle.rotation.x = -PI / 2
	circle.position.y = 0.06
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boss_aura.add_child(circle)
	circle.create_tween().set_loops().tween_property(circle, "rotation:y", TAU, 6.0).from(0.0)
	var pulse := light.create_tween().set_loops()
	pulse.tween_property(light, "light_energy", 4.0, 0.8)
	pulse.tween_property(light, "light_energy", 2.5, 0.8)


func _hint(player: Node, id: String, condition: bool, message: String) -> void:
	if condition and not _hints.has(id):
		_hints[id] = true
		player.show_message(Loc.t(message), 7)


func _apply_village_light() -> void:
	var env := $WorldEnvironment.environment.duplicate() as Environment
	$WorldEnvironment.environment = env
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.61, 0.69)
	env.ambient_light_energy = village_ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_intensity = 1.1
	env.ssao_radius = 1.0
	env.ssil_enabled = enhanced_lighting
	env.ssil_intensity = 0.45
	env.ssr_enabled = enhanced_lighting
	env.glow_enabled = true
	env.glow_intensity = 0.23
	env.glow_hdr_threshold = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.88
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.17, 0.23, 0.25)
	env.volumetric_fog_enabled = enhanced_lighting
	env.volumetric_fog_density = village_fog_density
	env.volumetric_fog_albedo = Color(0.36, 0.43, 0.46)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_ambient_inject = 0.25
	if enhanced_lighting:
		var mist := FogMaterial.new()
		mist.density = 0.035
		mist.albedo = Color(0.42, 0.48, 0.50)
		mist.height_falloff = 1.2
		for point in _plan.fog_points:
			var volume := FogVolume.new()
			volume.size = Vector3(16, 2.2, 20)
			volume.position = Vector3(point.x, 0.65, point.y)
			volume.material = mist
			add_child(volume)
	$Sun.light_energy = moonlight_energy
	$Sun.light_color = Color(0.65, 0.75, 0.85)
	$Sun.directional_shadow_max_distance = 55
	$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	$Sun.shadow_bias = 0.035
	$Sun.shadow_normal_bias = 0.6
	get_viewport().msaa_3d = Viewport.MSAA_4X if enhanced_lighting else Viewport.MSAA_DISABLED
	_readability_fill = OmniLight3D.new()
	_readability_fill.light_color = Color(1.0, 0.62, 0.32)
	_readability_fill.light_energy = hero_fill_energy
	_readability_fill.omni_range = 7
	add_child(_readability_fill)


func _update_village_lamps(player: Node3D) -> void:
	if _readability_fill:
		_readability_fill.global_position = player.global_position + Vector3(0, 3, 2)
	var lamps := get_tree().get_nodes_in_group("village_lamps")
	lamps.sort_custom(func(a, b): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	for i in lamps.size():
		var lamp := lamps[i] as OmniLight3D
		var distance := lamp.global_position.distance_to(player.global_position)
		lamp.visible = distance < 36
		lamp.shadow_enabled = i < 2 and distance < 15
		lamp.shadow_bias = 0.035
		lamp.shadow_normal_bias = 0.35
