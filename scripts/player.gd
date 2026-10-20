extends CharacterBody3D
## Игрок: движение, прицел (мышь / правый стик / автоприцел), стрельба и перекат.
## Все цифры с @export можно менять справа в Inspector, не трогая код.

const InputSetup := preload("res://scripts/input_setup.gd")
const Suit := preload("res://scripts/suit.gd")
const PassiveDB := preload("res://scripts/passive_db.gd")
const OverheadBar := preload("res://scripts/player_bar_3d.gd")
const Hair := preload("res://scripts/hair.gd")
const Skills := preload("res://scripts/player_skills.gd")
const WeaponSupport := preload("res://scripts/weapon_support_modifier.gd")
const WeaponRecoil := preload("res://scripts/weapon_recoil_modifier.gd")
const WeaponAim := preload("res://scripts/weapon_aim_modifier.gd")
const HeadUp := preload("res://scripts/head_up_modifier.gd")

## Сообщает аниматору, что началась перезарядка (длительность в секундах) или что её прервали.
signal reload_started(duration: float)
signal reload_cancelled
signal died
## Игрок получил урон: hp_lost — сколько ушло со здоровья, shield_lost — с энергощита (для эффектов на экране).
signal damaged(hp_lost: float, shield_lost: float)
## Новый уровень персонажа (показать вспышку и сообщение).
signal leveled_up(new_level: int)
## Текст для экрана (подсказки дверей, найденные ключи). Показывает HUD.
signal message(text: String, duration: float)
## Модули вставили / вынули / подобрали — окно модулей и HUD перерисовываются.
signal modules_changed

const ItemDB := preload("res://scripts/item_db.gd")
@export_group("Уровень")
## Опыт, нужный для каждого уровня: [для 2-го, для 3-го, …]. Последний уровень — потолок демо.
## Подобрано так, чтобы полная зачистка этажа давала примерно один уровень (как в PoE 2).
@export var xp_to_level: Array[int] = [2860, 4270, 4910, 5630]
## Сколько ХП добавляет каждый уровень.
@export var hp_per_level := 12.0

@export_group("Вид")
## Цвет светящихся вставок на костюме.
@export var suit_accent := Color(0.15, 0.85, 1.0)

@export_group("Здоровье и защита")
## Базовое ХП без экипировки.
@export var base_max_hp := 125.0
## Энергощит начинает восстанавливаться через столько секунд без урона…
@export var es_recharge_delay := 2.0
## …и восполняет такую долю максимума в секунду.
@export var es_recharge_rate := 0.35
## Потолок сопротивлений, %.
@export var resist_cap := 75.0
## Через сколько секунд после смерти уровень начинается заново.
@export var restart_delay := 2.5

@export_group("Аптечка")
@export var flask_max_charges := 3
## Сколько ХП восстанавливает один заряд.
@export var flask_heal := 60.0
## За сколько секунд лечение «доливается» (как фласка в PoE: не мгновенно).
@export var flask_heal_time := 1.2
## С какими зарядами начинаем.
@export var flask_start_charges := 3.0

@export_group("Движение")
@export var move_speed := 4.0
## Пока зажата стрельба, персонаж замедляется.
@export var shoot_move_speed := 1.55
## Как быстро набирает и сбрасывает скорость. Меньше — тяжелее и инертнее.
@export var acceleration := 30.0
## Скорость поворота за прицелом. У Бастиона потом сделаем меньше.
@export var turn_speed := 18.0

@export_group("Перекат")
## Дальность полного нырка; скорость берётся из траектории исходной анимации.
@export var dodge_distance := 3.36
@export var dodge_duration := 0.64
## Визуальный подъём: ходьба уже разрешена, новый перекат и стрельба — после полного цикла.
@export var dodge_recovery := 0.12
## Первый выстрел после переката ждёт, пока корпус и оружие повернутся к прицелу.
@export_range(1.0, 30.0, 1.0) var post_roll_fire_angle_degrees := 8.0
var _post_roll_aim_pending := false
## Фаза исходного клипа для начала звука касания; учитывает короткую атаку записи.
@export_range(0.0, 1.0, 0.01) var dodge_sound_phase := 0.34
var _dodge_contact_played := false
## Короткое нажатие перед концом восстановления запоминается.
@export var dodge_buffer_time := 0.18
var _dodge_motion := PackedFloat32Array()

@export_group("Спринт")
## Если после переката держать кнопку переката — персонаж бежит. Стрелять в спринте нельзя.
@export var sprint_speed := 6.3

@export_group("Оружие")
## Временный проход: один закреплённый лук, предметы в сумке не меняются.
@export var fixed_bow_loadout := true
@export_range(0.2, 1.5) var bow_draw_time := 0.74
@export_range(0.05, 1.5) var bow_release_time := 0.42
## Стартовое оружие в первом из двух обычных слотов. Его можно снять или заменить.
@export var start_weapon := &"plasma_cutter"
## Стартовый резак без случайного встроенного пробивания Orion.
@export var start_weapon_corp := &"helix"
## Высота полёта пуль над полом (м). Хитбоксы всех врагов достают до неё.
@export var fire_height := 1.0
## Показывать запасное оружие за спиной. Оружие в руках видно всегда.
@export var show_stowed_weapons := false
## Зажатая кнопка стреляет непрерывно у любого оружия (темп — скорострельность). false — одиночное ждёт нажатия.
@export var hold_to_fire := true
## Насколько приподнять голову над позой анимации (градусы) — чтобы герой смотрел вперёд, а не в пол.
@export var head_pitch := 12.0
## Общий темп стрельбы всего оружия (0.8 — на 20% медленнее, чем в файлах оружия).
@export var fire_rate_scale := 0.72
## Общая длительность перезарядки: 0.8 — на 20% меньше времени, включая анимацию.
@export_range(0.1, 2.0, 0.05) var reload_time_scale := 0.8
## Причёска героя (assets/characters/hair).
@export var hairstyle: PackedScene = preload("res://assets/characters/hair/Hair_SimpleParted.gltf")
## Цвет волос (умножается на текстуру причёски).
@export var hair_color := Color(0.09, 0.075, 0.07)
## Фонарь на плече: светит туда, куда смотрит герой (0 — выключен).
@export var flashlight_energy := 0.0
@export var flashlight_range := 20.0
@export var flashlight_angle := 32.0
## Мягкий свет над героем (видно его и врагов рядом в тёмных местах). 0 — выключить.
@export var aura_energy := 0.5
@export var aura_range := 3.6
@export var aura_color := Color(1.0, 0.58, 0.27)
## Сама начинать перезарядку, когда магазин опустел.
@export var auto_reload := true
## Пауза после смены оружия, прежде чем можно стрелять (сек).
@export var switch_delay := 0.25

@export_group("Прицел мышью")
## Если враг на экране ближе этого к курсору (пиксели при высоте экрана 720), прицел «прилипает» к нему.
@export var mouse_assist_radius := 70.0

@export_group("Прицел на геймпаде")
## Насколько автоприцел предпочитает врагов по ходу движения (0 — просто ближайший).
@export_range(0.0, 1.0) var auto_aim_direction_bias := 0.5
## «Магнит» при ручном прицеле правым стиком.
@export_range(0.0, 30.0) var aim_assist_cone := 12.0
@export var aim_assist_range := 20.0

@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var gun: MeshInstance3D = $RightHand/Gun
@onready var inventory: PlayerInventory = $Inventory

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _using_mouse := true
## Враг под курсором, к которому прилип прицел мыши (рисует курсор-прицел в HUD), или null.
var mouse_target: Node3D
## Враг, в которого сейчас целимся (мышь, стик или автоприцел) — в него летит граната.
var aim_target: Node3D
var _aim_dir := Vector3.FORWARD
var _fire_cooldown := 0.0
var _dodge_left := 0.0
var _roll_elapsed := 0.0
var _dodge_buffer_left := 0.0
var _recovery_left := 0.0
var _dodge_dir := Vector3.ZERO
var _sprinting := false
var _firing := false
var _locked_target: Node3D
var _bullet_pool: Node
var _weapon_index := 0
var _ammo: Array[int] = []
var _reload_left := 0.0
var _gun_base: Transform3D
var _gun_rest := Vector3.ZERO  # положение оружия в руке (отдача уводит его назад и возвращает)
var _gun_kick: Tween
var _body_recoil: SkeletonModifier3D
var _flash_mesh: MeshInstance3D
## Вибрация геймпада (можно выключить в меню).
var vibration_enabled := true
var hp := 0.0
var max_hp := 100.0
var es := 0.0
var max_es := 0.0
var _es_wait := 0.0
## Итоговые характеристики персонажа от экипировки (см. _recalculate_defense).
var armor := 0.0
var resists := {&"fire": 0.0, &"electric": 0.0, &"acid": 0.0}
## Сопротивления без потолка (как «75% (83%)» в PoE 2).
var resists_raw := {&"fire": 0.0, &"electric": 0.0, &"acid": 0.0}
var level := 1
var xp := 0
## Свободные очки пассивных умений и взятые узлы дерева (passive_db.gd).
var passive_points := 0
var allocated: Array[StringName] = [&"start"]
var gold := 0
var move_speed_mult := 1.0
var hp_regen := 0.0
var _es_recharge_mult := 1.0
var _gear := {}
var _dead := false
var flask_charges := 0.0
var _heal_left := 0.0  # сколько ХП ещё «дольётся» от аптечки
var _keys: Array[StringName] = []
## Какой предмет лежал в каждом слоте оружия при прошлом пересчёте (новый ствол — полный магазин).
var _slot_items: Array = [null, null]
## Где кончик ствола у оружия в руках (в координатах узла Gun) — туда ставим дуло каждый кадр.
var _muzzle_local := Vector3.ZERO
## Настоящий кончик ствола (мир): отсюда вспышка, дым и начало следа пули. Сама пуля летит на линии огня.
var muzzle_tip := Vector3.ZERO
var _last_smoke_at := -1.0
## Отметка попадания для прицела: время последнего попадания и было ли оно смертельным.
var hit_marker_msec := -10000
var hit_marker_kill := false
## Итоговые цифры каждого оружия с учётом модулей (пересчитываются при смене модулей).
var _stats: Array[Dictionary] = []
var _safe_zones := 0
var _fixed_bow_item: GearItem
var _bow_draw_elapsed := 0.0
var _bow_release_left := 0.0
var _bow_equip_left := 0.0
var _bow_equip_duration := 0.9
var _bow_nock_time := 0.64
var bow_shots_fired := 0
var _bow_modifier: SkeletonModifier3D


func _ready() -> void:
	InputSetup.setup()
	if fixed_bow_loadout:
		var bow_library: AnimationLibrary = load($Model.animation_library_path)
		bow_draw_time = bow_library.get_meta("bow_draw_time", bow_draw_time)
		bow_release_time = bow_library.get_meta("bow_recovery_time", bow_release_time)
		_bow_equip_duration = bow_library.get_meta("bow_equip_time", 0.9)
		_bow_nock_time = bow_library.get_meta("bow_nock_time", 0.64)
		_fixed_bow_item = GearItem.create({"id": &"huntress_bow", "name": "Охотничий лук", "slot": &"weapon", "weapon": "res://data/weapons/huntress_bow.tres", "icon": "res://assets/icons/weapons/bow.png", "armor": 0, "es": 0}, 1, 0)
		_fixed_bow_item.modules.clear()
		_fixed_bow_item.secondary_modules.clear()
	if not $Model.has_meta("native_shooter"):
		Suit.apply($Model, suit_accent)
		Hair.attach($Model, hairstyle, hair_color)
	var skills := Skills.new()
	skills.name = "Skills"
	add_child(skills)
	var skeleton := $Model.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton != null:
		var aim_modifier := WeaponAim.new()
		aim_modifier.body = self
		skeleton.add_child(aim_modifier)
		_body_recoil = WeaponRecoil.new()
		_body_recoil.body = self
		skeleton.add_child(_body_recoil)
		var support := WeaponSupport.new()
		support.body = self
		skeleton.add_child(support)
		if not fixed_bow_loadout and $Model.get("max_stance_width") != null and $Model.max_stance_width > 0:
			var stance := preload("res://scripts/stance_width_modifier.gd").new()
			stance.name = "StanceWidth"
			stance.body = self
			stance.max_width = $Model.max_stance_width
			skeleton.add_child(stance)
		if fixed_bow_loadout:
			_bow_modifier = preload("res://scripts/bow_pose_modifier.gd").new()
			_bow_modifier.body = self
			skeleton.add_child(_bow_modifier)
	if skeleton != null and head_pitch != 0.0:
		var head_up := HeadUp.new()
		head_up.body = self
		head_up.head_pitch = head_pitch
		head_up.neck_pitch = head_pitch * 0.5
		skeleton.add_child(head_up)
	if flashlight_energy > 0.0:
		var lamp := SpotLight3D.new()
		lamp.name = "Flashlight"
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.light_energy = flashlight_energy
		lamp.spot_range = flashlight_range
		lamp.spot_angle = flashlight_angle
		lamp.spot_attenuation = 0.8
		lamp.position = Vector3(0, 1.7, 0.1)
		lamp.rotation_degrees = Vector3(-12, 0, 0)
		add_child(lamp)
	if aura_energy > 0.0:
		# Мягкий свет над героем: его и ближайших врагов видно даже в тёмных углах.
		var aura := OmniLight3D.new()
		aura.name = "Aura"
		aura.light_color = aura_color
		aura.light_energy = aura_energy
		aura.omni_range = aura_range
		aura.position = Vector3(0, 1.65, 0)
		aura.light_specular = 0.0
		aura.shadow_enabled = false
		add_child(aura)
	var bar := OverheadBar.new()
	bar.player = self
	bar.position = Vector3(0, 2.25, 0)
	add_child(bar)
	inventory.changed.connect(_on_inventory_changed)
	_recalculate_defense()
	hp = max_hp
	es = max_es
	flask_charges = flask_start_charges
	# Место возрождения в этом уровне — там, где игрок появился.
	if get_parent() != null and not get_parent().has_meta("spawn"):
		get_parent().set_meta("spawn", global_position)
	if fixed_bow_loadout:
		$RightHand.bone_name = "hand_l"
		gun.transform = Transform3D.IDENTITY
	elif $Model.has_meta("native_shooter"):
		var correction: Basis = preload("res://scripts/player_animator.gd").native_library(skeleton).get_meta("grip_correction", Basis.IDENTITY)
		gun.transform = Transform3D(correction, Vector3.ZERO) * gun.transform
	# Скелет собирается моделью при входе в дерево: обновляем крепление после создания и переименования костей.
	if skeleton != null:
		$RightHand.external_skeleton = $RightHand.get_path_to(skeleton)
		$RightHand.bone_idx = skeleton.find_bone($RightHand.bone_name)
	_gun_base = gun.transform
	if not fixed_bow_loadout and inventory.weapons[0] == null:
		inventory.weapons[0] = GearItem.create(ItemDB.base_by_id(start_weapon), 1, 0)
		inventory.weapons[0].corp = start_weapon_corp
	_ammo.assign([0, 0])
	_recalculate_stats()
	_sync_weapon_slots()
	_equip(0)
	if fixed_bow_loadout: _bow_equip_left = _bow_equip_duration


func _unhandled_input(event: InputEvent) -> void:
	if _dead or get_tree().paused:
		return
	if event.is_action_pressed("town_portal") and not Game.in_hub():
		Game.open_town_portal(self)
	elif event.is_action_pressed("interact"):
		var target := nearest_interactable()
		if target != null:
			target.interact(self)


## С какого расстояния можно поднять вещь кнопкой X.
const PICKUP_RANGE := 2.4

var _highlighted_loot: Node3D  # ближайшая подсвеченная вещь (сбрасывается, когда её поднимают)
## Подписи добычи на экране (HUD): знают, какая вещь под курсором мыши.
var loot_labels: Node
## Вещь, к которой герой идёт сам (щёлкнули ПКМ по далёкой подписи). Любое движение отменяет.
var _walk_to_loot: Node3D


## Ближайшая добыча в пределах досягаемости (кроме золота — оно подбирается само), или null.
func nearest_loot() -> Node3D:
	var best: Node3D = null
	var best_distance := PICKUP_RANGE
	for node in get_tree().get_nodes_in_group("loot"):
		if node.kind == &"gold" or node.is_queued_for_deletion():
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_distance:
			best = node
			best_distance = d
	return best


## Подсветить ближайшую вещь и поднять её по кнопке «поднять».
func _update_pickup() -> void:
	var loot := nearest_loot()
	if not is_instance_valid(_highlighted_loot):
		_highlighted_loot = null
	if loot != _highlighted_loot:
		if _highlighted_loot != null:
			_highlighted_loot.set_highlight(false)
		_highlighted_loot = loot
		if loot != null:
			loot.set_highlight(true)
	if not Input.is_action_just_pressed("pickup"):
		return
	# ПКМ по подписи на экране — именно эта вещь (если далеко — подходим к ней сами).
	var hovered: Node3D = loot_labels.get("hovered") if loot_labels != null else null
	if hovered != null and is_instance_valid(hovered) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if global_position.distance_to(hovered.global_position) <= PICKUP_RANGE:
			_pick_loot(hovered)
		else:
			_walk_to_loot = hovered
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	if loot != null:
		_pick_loot(loot)


func _pick_loot(loot: Node3D) -> void:
	if loot.pick(self):
		if loot == _highlighted_loot:
			_highlighted_loot = null  # вещь удаляется — не держим на неё ссылку
		if loot == _walk_to_loot:
			_walk_to_loot = null


## Сам идём к вещи, по подписи которой щёлкнули; дошли — поднимаем.
func _loot_walk_dir(move_dir: Vector3) -> Vector3:
	if _walk_to_loot == null:
		return move_dir
	if move_dir.length() > 0.1 or not is_instance_valid(_walk_to_loot) or _walk_to_loot.is_queued_for_deletion():
		_walk_to_loot = null
		return move_dir
	var to: Vector3 = _walk_to_loot.global_position - global_position
	to.y = 0.0
	if to.length() <= PICKUP_RANGE * 0.7:
		_pick_loot(_walk_to_loot)
		_walk_to_loot = null
		return Vector3.ZERO
	return to.normalized()


## Ближайший объект, с которым можно взаимодействовать (торговец, верстак, портал), или null.
func nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("interactables"):
		var d := global_position.distance_to(node.global_position)
		if d < node.interact_range and d < best_distance:
			best = node
			best_distance = d
	return best


## Вызывает Game после переноса в другой уровень.
func on_level_changed(at: Vector3) -> void:
	_low_level_warned = false
	_bullet_pool = null
	_locked_target = null
	_safe_zones = 0
	if not get_parent().has_meta("spawn"):
		get_parent().set_meta("spawn", at)


# --- Опыт и уровень --------------------------------------------------------------

func xp_for_next_level() -> int:
	return xp_to_level[level - 1] if level - 1 < xp_to_level.size() else 0


func is_max_level() -> bool:
	return level - 1 >= xp_to_level.size()


## source_level — уровень врага. Если персонаж выше уровня этажа, опыт не начисляется:
## нельзя «нафармить» уровни на первом этаже.
var _low_level_warned := false


func add_xp(amount: int, source_level := 0) -> void:
	if is_max_level() or _dead:
		return
	if source_level > 0 and level > source_level:
		if not _low_level_warned:
			_low_level_warned = true
			show_message("Этаж ниже вашего уровня — опыт здесь не начисляется", 3.0)
		return
	xp += amount
	while not is_max_level() and xp >= xp_for_next_level():
		xp -= xp_for_next_level()
		level += 1
		passive_points += 1
		_recalculate_defense()
		Sfx.play(&"level_up", global_position, -2.0)
		Fx.level_up(self)
		leveled_up.emit(level)
	if is_max_level():
		xp = 0


# --- Дерево пассивок -----------------------------------------------------------

func can_allocate(id: StringName) -> bool:
	if passive_points <= 0 or id in allocated:
		return false
	return PassiveDB.neighbors(id).any(func(n): return n in allocated)


func allocate(id: StringName) -> bool:
	if not can_allocate(id):
		return false
	allocated.append(id)
	passive_points -= 1
	_on_inventory_changed()
	return true


## Вернуть очко можно, только если остальные взятые узлы остаются связаны с началом дерева.
func can_refund(id: StringName) -> bool:
	if id == &"start" or not id in allocated:
		return false
	var rest := allocated.filter(func(n): return n != id)
	var seen := [&"start"]
	var stack := [&"start"]
	while not stack.is_empty():
		var cur: StringName = stack.pop_back()
		for n in PassiveDB.neighbors(cur):
			if n in rest and not n in seen:
				seen.append(n)
				stack.append(n)
	return seen.size() == rest.size()


func refund(id: StringName) -> bool:
	if not can_refund(id):
		return false
	allocated.erase(id)
	passive_points += 1
	_on_inventory_changed()
	return true


func passive_stats() -> Dictionary:
	var total := {}
	for id in allocated:
		var stats: Dictionary = PassiveDB.node(id).stats
		for stat in stats:
			total[stat] = total.get(stat, 0) + stats[stat]
	return total


func add_gold(amount: int) -> void:
	gold += amount
	inventory.changed.emit()


func _input(event: InputEvent) -> void:
	# Запоминаем, чем игрок управляет сейчас: мышью или геймпадом.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse = true
	elif event is InputEventJoypadButton:
		_using_mouse = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_using_mouse = false


func is_dodging() -> bool:
	return _dodge_left > 0.0


func is_sprinting() -> bool:
	return _sprinting


## Зажата ли стрельба прямо сейчас (для анимации: руки поднимают оружие).
func is_firing() -> bool:
	return _firing or get_node("Skills").is_charging_pulse()


# --- Модули оружия ------------------------------------------------------------

## Подобрать добычу с пола. false — не влезло (подбор повторится, пока игрок рядом).
func pick_up_loot(pickup: Node) -> bool:
	match pickup.kind:
		&"gold":
			add_gold(pickup.amount)
			return true
		&"currency":
			var left: int = inventory.add_currency(pickup.currency_id, pickup.amount)
			if left > 0:
				pickup.amount = left  # что не влезло — остаётся лежать
				show_message("Инвентарь полон", 1.0)
				return false
			show_message("Подобрано: %s" % pickup.ItemDB.CURRENCY[pickup.currency_id].name, 1.5)
			return true
		&"gear", &"module":
			var item = pickup.gear if pickup.kind == &"gear" else pickup.module
			if not inventory.add_item(item):
				show_message("Инвентарь полон", 1.0)
				return false
			var title: String = item.display_name() if item is GearItem else item.display_name
			show_message("Подобрано: %s  —  Tab / Back: инвентарь" % title, 1.8)
			return true
	return false


## Предмет-оружие в одном из двух слотов или null.
func weapon_item(index: int) -> GearItem:
	if fixed_bow_loadout: return _fixed_bow_item if index == 0 else null
	return inventory.weapons[index] if index >= 0 and index < inventory.weapons.size() else null


## Цифры базы оружия в слоте или null.
func weapon_data(index: int) -> WeaponData:
	var item := weapon_item(index)
	return item.weapon_data() if item != null else null


## Гнездо типа патронов (стихия оружия).
const AMMO_SOCKET := 0


## Сколько гнёзд у оружия в слоте.
func sockets_of(index: int) -> int:
	if fixed_bow_loadout: return 0
	var item := weapon_item(index)
	return item.sockets + (2 if item.secondary_skill() != &"" else 0) if item != null else 0


func get_module(weapon_index: int, slot: int) -> ModuleData:
	var item := weapon_item(weapon_index)
	if item == null or slot < 0 or slot >= sockets_of(weapon_index):
		return null
	var slots: Array = item.modules if slot < item.sockets else item.secondary_modules
	var local_slot := slot if slot < item.sockets else slot - item.sockets
	return slots[local_slot] if local_slot >= 0 and local_slot < slots.size() else null


## Вставить модуль из сумки в слот. Если слот занят — старый возвращается в сумку на его место.
## Один и тот же модуль дважды в одно оружие не вставить. Возвращает текст ошибки или "".
func module_error(weapon_index: int, slot: int, module: ModuleData) -> String:
	if weapon_index < 0 or weapon_index >= inventory.weapons.size() or weapon_item(weapon_index) == null:
		return "В этом слоте нет оружия"
	var item := weapon_item(weapon_index)
	if slot < 0 or slot >= sockets_of(weapon_index) or module == null:
		return "Нет такого гнезда"
	var secondary := slot >= item.sockets
	var local_slot := slot - item.sockets if secondary else slot
	var slots: Array = item.secondary_modules if secondary else item.modules
	if local_slot >= slots.size():
		return "Нет такого гнезда"
	for i in slots.size():
		if i != local_slot and slots[i] != null and slots[i].id == module.id:
			return "Такой модуль уже стоит в этом навыке"
	if secondary:
		var allowed := [&"damage", &"fire", &"electric", &"acid", &"concentrate", &"fast_reload"]
		if item.secondary_skill() == &"plasma_pulse": allowed.append_array([&"pierce", &"leech"])
		if item.secondary_skill() == &"" or module.id not in allowed:
			return "Этот модификатор не подходит дополнительному навыку"
	else:
		if item.weapon_data().projectile == &"plasma" and module.id == &"ricochet":
			return "Рикошет работает с обычными пулями; резак использует цельную полосу"
		if slot == AMMO_SOCKET and not module.is_ammo():
			return "Первое гнездо — тип патронов: только огненный, кислотный или электрический заряд"
		if slot != AMMO_SOCKET and module.is_ammo():
			return "Стихийный заряд ставится только в первое гнездо"
		if item.slot == &"mines" and not module.mine_ok:
			return "Этот модуль только для пуль — на мины не ставится"
		if item.slot != &"mines" and not module.weapon_ok:
			return "Этот модуль ставится в дополнительный навык, а не в основной выстрел"
	return ""


func insert_module(weapon_index: int, slot: int, module: ModuleData) -> String:
	var error := module_error(weapon_index, slot, module)
	if error != "":
		return error
	var entry := inventory.find_entry(module)
	if entry.is_empty():
		return "Модуль должен находиться в сумке"
	var item := weapon_item(weapon_index)
	var slots: Array = item.modules if slot < item.sockets else item.secondary_modules
	var local_slot := slot if slot < item.sockets else slot - item.sockets
	if slots[local_slot] != null:
		entry.item = slots[local_slot]
	else:
		inventory.entries.erase(entry)
	slots[local_slot] = module
	_on_modules_changed()
	inventory.changed.emit()
	return ""


## Вынуть модуль в сумку. Возвращает текст ошибки или "".
func remove_module(weapon_index: int, slot: int) -> String:
	if weapon_index < 0 or weapon_index >= inventory.weapons.size() or slot < 0 or slot >= sockets_of(weapon_index):
		return "Нет такого гнезда"
	if weapon_item(weapon_index) == null:
		return ""
	var item := weapon_item(weapon_index)
	var slots: Array = item.modules if slot < item.sockets else item.secondary_modules
	if slot >= item.sockets:
		slot -= item.sockets
	if slots[slot] == null:
		return ""
	if not inventory.add_item(slots[slot]):
		return "Инвентарь полон"
	slots[slot] = null
	_on_modules_changed()
	inventory.changed.emit()
	return ""


func _on_modules_changed() -> void:
	_recalculate_stats()
	_sync_weapon_slots()
	_update_offhand()
	for i in PlayerInventory.WEAPON_COUNT:
		if not _stats[i].is_empty():
			_ammo[i] = mini(_ammo[i], _stats[i].magazine)
	modules_changed.emit()


## В слоте сменилось оружие: новому даётся полный магазин; при снятии активного берём второе.
func _sync_weapon_slots() -> void:
	for i in PlayerInventory.WEAPON_COUNT:
		var item := weapon_item(i)
		if item != _slot_items[i]:
			_slot_items[i] = item
			_ammo[i] = _stats[i].magazine if item != null else 0
			if i == _weapon_index and is_inside_tree() and gun != null and item != null:
				_equip(i)
	if weapon_item(_weapon_index) == null:
		var alternate := 1 - _weapon_index
		if weapon_item(alternate) != null:
			_equip(alternate)
		elif gun != null:
			gun.visible = false
	if is_inside_tree() and gun != null:
		_update_stowed()


## Итоговые цифры оружия: база из WeaponData + все вставленные модули.
func weapon_stats(index: int) -> Dictionary:
	return _stats[index]

## Импульс: общие свойства оружия и экипировки, модули только его строки.
func pulse_stats(index: int) -> Dictionary:
	var item := weapon_item(index)
	if item == null or item.secondary_skill() != &"plasma_pulse": return {}
	var w := item.weapon_data()
	var local := item.stats()
	var cls := String(item.weapon_class())
	var bonus: float = (_gear.get(&"damage_pct", 0) + local.get(&"w_damage", 0) + _gear.get(StringName(cls + "_dmg"), 0)) / 100.0
	var multiplier := 1.0
	var area := 1.0
	var recharge := 0.0
	var result := {"elements": {}, "pierce": w.secondary_pierce + int(local.get(&"w_pierce", 0) + _gear.get(&"pierce", 0)), "chain": 0, "leech": (local.get(&"w_leech", 0) + _gear.get(&"leech_pct", 0)) / 100.0,
		"explode_radius": 0.0, "explode_ratio": 0.0, "homing": 0.0, "ammo": &"electric" if w.projectile == &"plasma" else &"", "pellets": 1, "spread": 0.0, "range_mult": 1.0 + (local.get(&"w_range", 0) + _gear.get(&"proj_speed", 0)) / 100.0}
	for element in [&"fire", &"electric", &"acid"]:
		var ratio: float = local.get(StringName("w_" + element), 0) / maxf(w.damage, 1) + _gear.get(StringName(element + "_dmg"), 0) / 100.0
		if ratio > 0: result.elements[element] = ratio
	for m in item.secondary_modules:
		if m == null: continue
		bonus += m.damage_bonus
		multiplier *= m.damage_multiplier
		area *= m.area_mult
		recharge += m.reload_speed_bonus
		result.pierce += m.pierce
		result.leech += m.leech
		if m.element != &"": result.elements[m.element] = result.elements.get(m.element, 0.0) + m.element_ratio
	result.damage = w.damage * w.secondary_damage_mult * (1.0 + bonus) * multiplier
	result.width = w.secondary_width * area
	result.cooldown = w.secondary_cooldown / maxf(0.1, 1.0 + recharge)
	return result

func fire_plasma_pulse() -> bool:
	var w := current_weapon()
	if w == null or w.secondary_skill != &"plasma_pulse" or current_ammo() < w.secondary_ammo_cost or is_reloading() or is_dodging(): return false
	_ammo[_weapon_index] -= w.secondary_ammo_cost
	_shoot(w, pulse_stats(_weapon_index))
	_fire_cooldown = maxf(_fire_cooldown, 0.18)
	return true


func _recalculate_stats() -> void:
	_stats.clear()
	for i in inventory.weapons.size():
		var item := weapon_item(i)
		if item == null:
			_stats.append({})
			continue
		var w := item.weapon_data()
		var local := item.stats()  # свойства самого оружия (w_*)
		# Экипировка даёт бонусы ко всему оружию сразу, свойства ствола — только ему.
		# Ветки дерева по классу оружия: лёгкое / среднее / тяжёлое.
		var cls := String(item.weapon_class())
		var damage_bonus: float = (_gear.get(&"damage_pct", 0) + local.get(&"w_damage", 0)
				+ _gear.get(StringName(cls + "_dmg"), 0)) / 100.0
		var damage_mult := 1.0
		var fire_rate_bonus: float = (_gear.get(&"fire_rate_pct", 0) + local.get(&"w_fire_rate", 0)
				+ _gear.get(StringName(cls + "_fire_rate"), 0)) / 100.0
		var reload_bonus: float = (_gear.get(&"reload_pct", 0) + local.get(&"w_reload", 0)
				+ _gear.get(StringName(cls + "_reload"), 0)) / 100.0
		var magazine_bonus: float = (local.get(&"w_magazine", 0) + _gear.get(StringName(cls + "_magazine"), 0)) / 100.0
		var extra := int(local.get(&"w_extra", 0))
		var s := {"pierce": int(local.get(&"w_pierce", 0) + _gear.get(&"pierce", 0)), "chain": int(local.get(&"w_chain", 0)),
				"leech": (local.get(&"w_leech", 0) + _gear.get(&"leech_pct", 0)) / 100.0, "elements": {}}
		for element in [&"fire", &"electric", &"acid"]:
			# Свойство оружия — плоский урон к выстрелу; экипировки — % от урона.
			var ratio: float = local.get(StringName("w_" + element), 0) / maxf(w.damage, 1.0) \
					+ _gear.get(StringName(element + "_dmg"), 0) / 100.0
			if ratio > 0.0:
				s.elements[element] = ratio
		s.range_mult = 1.0 + (local.get(&"w_range", 0) + _gear.get(&"proj_speed", 0)) / 100.0
		s.explode_radius = w.explode_radius
		s.explode_ratio = w.explode_ratio
		s.homing = 0.0
		s.pierce += w.pierce
		if w.element != &"":
			s.elements[w.element] = s.elements.get(w.element, 0.0) + w.element_ratio
		var accuracy: float = 1.0 - local.get(&"w_accuracy", 0) / 100.0
		var area := 1.0
		var has_multishot := false
		s.nova_projectiles = 0
		s.nova_damage_ratio = 0.5
		for m in item.modules:
			if m == null:
				continue
			damage_bonus += m.damage_bonus
			damage_mult *= m.damage_multiplier
			fire_rate_bonus += m.fire_rate_bonus
			reload_bonus += m.reload_speed_bonus
			magazine_bonus += m.magazine_bonus
			extra += m.extra_projectiles
			has_multishot = has_multishot or m.extra_projectiles > 0
			if m.nova_projectiles > 0:
				s.nova_projectiles = m.nova_projectiles
				s.nova_damage_ratio = m.nova_damage_ratio
			s.pierce += m.pierce
			s.chain += m.chain
			s.leech += m.leech
			s.explode_radius = maxf(s.explode_radius, m.explode_radius)
			s.explode_ratio += m.explode_ratio
			s.homing += m.homing
			area *= m.area_mult
			if m.element != &"":
				s.elements[m.element] = s.elements.get(m.element, 0.0) + m.element_ratio
		# Тип патронов — стихийный заряд в первом гнезде: цвет пуль, вспышек и попаданий.
		s.ammo = &""
		if not item.modules.is_empty() and item.modules[AMMO_SOCKET] != null and item.modules[AMMO_SOCKET].is_ammo():
			s.ammo = item.modules[AMMO_SOCKET].element
		s.damage = w.damage * (1.0 + damage_bonus) * damage_mult
		# Мины: радиус — от ранца (взрывные модули его не заменяют), множители площади — от модулей.
		if item.slot == &"mines":
			s.explode_radius = w.explode_radius
			s.explode_ratio = 1.0
		s.explode_radius *= area
		s.fire_rate = w.fire_rate * (1.0 + fire_rate_bonus) * fire_rate_scale
		s.reload_time = w.reload_time * reload_time_scale / (1.0 + reload_bonus)
		s.magazine = maxi(1, ceili(w.magazine_size * (1.0 + magazine_bonus)))
		s.pellets = w.pellets + extra
		s.width = w.projectile_width
		if w.projectile == &"plasma":
			s.width *= 1.0 + extra * 0.5
			s.pellets = 1
		# Особые узлы дерева по виду оружия.
		var family: StringName = ItemDB.WEAPON_ICON_KIND.get(item._weapon_file(), &"")
		s.dual = family == &"pistol" and _gear.get(&"dual_pistols", 0) > 0
		if s.dual:
			s.magazine *= 2
			s.fire_rate *= 1.6
			s.reload_time *= 1.5
		s.ricochet_chance = _gear.get(&"rifle_ricochet", 0) / 100.0 if family in [&"smg", &"rifle"] else 0.0
		s.instant_reload = _gear.get(&"shotgun_instant", 0) / 100.0 if family == &"shotgun" else 0.0
		# Доп. снаряды у однопульного оружия раскладываются небольшим веером.
		s.spread = (maxf(w.spread_degrees, w.multishot_spread_degrees) if extra > 0 and w.pellets == 1 else w.spread_degrees) * accuracy
		s.wide_shotgun = w.icon == &"shotgun" and has_multishot
		if s.wide_shotgun:
			s.spread = maxf(w.spread_degrees, w.multishot_spread_degrees) * accuracy
		if w.projectile == &"plasma": s.spread = 0.0
		_stats.append(s)


## Экипировка поменялась: пересчитать защиту и оружие.
func _on_inventory_changed() -> void:
	_recalculate_defense()
	_on_modules_changed()


## Итог экипировки: ХП, броня, энергощит, сопротивления, скорость, регенерация.
func _recalculate_defense() -> void:
	_gear = inventory.gear_stats()
	var passive := passive_stats()
	for stat in passive:
		_gear[stat] = _gear.get(stat, 0) + passive[stat]
	# Здоровье само не восстанавливается: рост максимума (вещь, уровень) не лечит — только аптечка и свойства вещей.
	max_hp = base_max_hp + (level - 1) * hp_per_level + _gear.get(&"max_hp", 0)
	hp = minf(hp, max_hp)
	armor = _gear.get(&"armor_flat", 0) * (1.0 + _gear.get(&"armor_pct", 0) / 100.0)
	max_es = _gear.get(&"es_flat", 0) * (1.0 + _gear.get(&"es_pct", 0) / 100.0)
	es = minf(es, max_es)
	for element in resists:
		resists_raw[element] = float(_gear.get(StringName("res_" + element), 0) + _gear.get(&"res_all", 0))
		resists[element] = minf(resists_raw[element], resist_cap)
	move_speed_mult = 1.0 + _gear.get(&"move_speed", 0) / 100.0
	hp_regen = _gear.get(&"hp_regen", 0)
	_es_recharge_mult = 1.0 + _gear.get(&"es_recharge", 0) / 100.0


## Доля физического удара, которую срезает броня (как в PoE: против мелких ударов броня сильнее).
func armor_reduction(hit: float) -> float:
	if armor <= 0.0 or hit <= 0.0:
		return 0.0
	return minf(armor / (armor + 5.0 * hit), 0.9)


## Вампиризм: пуля сообщает, сколько урона нанесла.
func on_damage_dealt(amount: float, leech: float) -> void:
	if _dead or leech <= 0.0:
		return
	hp = minf(hp + amount * leech, max_hp)


# --- Безопасная зона ------------------------------------------------------------

## Пока игрок в безопасной комнате, враги его не видят и не преследуют.
func is_safe() -> bool:
	return _safe_zones > 0


func enter_safe_zone() -> void:
	_safe_zones += 1


func exit_safe_zone() -> void:
	_safe_zones = maxi(_safe_zones - 1, 0)


# --- Ключи и сообщения --------------------------------------------------------

func has_key(id: StringName) -> bool:
	return id in _keys


func add_key(id: StringName, key_name: String) -> void:
	if not has_key(id):
		_keys.append(id)
	show_message("Получена ключ-карта: %s" % key_name)


func show_message(text: String, duration := 2.5) -> void:
	message.emit(text, duration)


# --- Здоровье и аптечка --------------------------------------------------------

func is_dead() -> bool:
	return _dead


## Сколько ХП ещё восстановится от выпитой аптечки (для полоски ХП).
func pending_heal() -> float:
	return minf(_heal_left, max_hp - hp)


## Урон по игроку: сначала защита (броня — от физического, сопротивления — от стихий),
## потом энергощит принимает урон первым, остаток идёт в ХП.
func take_damage(amount: float, element := &"physical", _source = null) -> void:
	if _dead:
		return
	if Game.is_god():
		amount = 0.0
	if element == &"physical":
		amount *= 1.0 - armor_reduction(amount)
	elif resists.has(element):
		amount *= 1.0 - resists[element] / 100.0
	_es_wait = es_recharge_delay
	var absorbed := minf(es, amount)
	es -= absorbed
	amount -= absorbed
	hp = maxf(hp - amount, 0.0)
	Sfx.play(&"hit_flesh", global_position + Vector3.UP)
	# Ощущение удара: тряска сильнее, чем больше доля потерянного здоровья; вспышка модели; брызги.
	var share := (amount + absorbed * 0.5) / maxf(max_hp, 1.0)
	Fx.shake(0.18 + share * 2.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent().has_method("add_dip"):
		camera.get_parent().add_dip(0.15)
	if amount > 0.0:
		Fx.hit(global_position + Vector3.UP * 1.2, Vector3.UP, Color(0.7, 0.05, 0.05), 8)
	_flash_body(amount > 0.0)
	vibrate(0.4, 0.4 + share, 0.15)
	damaged.emit(amount, absorbed)
	if hp <= 0.0:
		_die()


## Ощущение выстрела: тряска камеры, оружие дёргается назад, вспышка у дула, гильза, вибрация геймпада.
func _shot_feedback(weapon: WeaponData) -> void:
	if fixed_bow_loadout:
		vibrate(0.12, 0.08, 0.045)
		return
	get_node("Animator").play_shot(weapon)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent().has_method("add_weapon_shake"):
		camera.get_parent().add_weapon_shake(weapon.recoil_shake, weapon.recoil_shake_cap)
	if _body_recoil != null:
		_body_recoil.kick(weapon)
	_push_body(weapon)
	if _gun_kick != null and _gun_kick.is_valid():
		_gun_kick.kill()
	gun.position = _gun_rest + gun.basis.z * weapon.gun_kick
	_gun_kick = create_tween()
	_gun_kick.tween_property(gun, "position", _gun_rest, weapon.gun_return_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_muzzle_flash(weapon)
	if weapon.projectile != &"plasma": Fx.shell(gun.global_position, global_basis.x + Vector3.UP * 0.6)
	vibrate(weapon.vibration_weak, weapon.vibration_strong, weapon.vibration_time)


var _push_tween: Tween
var _model_rest := Vector3.INF


## Отдача всем телом: модель отскакивает назад от линии выстрела и быстро возвращается.
## Двигается только вид героини — сама она (столкновения, прицел) остаётся на месте.
func _push_body(weapon: WeaponData) -> void:
	if weapon.body_push <= 0.0 or is_dodging():
		return
	var model := get_node("Model") as Node3D
	if _model_rest == Vector3.INF:
		_model_rest = model.position
	if _push_tween != null and _push_tween.is_valid():
		_push_tween.kill()
	var back: Vector3 = model.get_parent().global_basis.inverse() * Vector3(-_aim_dir.x, 0, -_aim_dir.z).normalized() if _aim_dir.length() > 0.1 else Vector3(0, 0, 1)
	model.position = _model_rest + back * weapon.body_push
	_push_tween = create_tween()
	_push_tween.tween_property(model, "position", _model_rest, weapon.body_push_return).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Вибрация геймпада (если он подключён и им сейчас играют).
func vibrate(weak: float, strong: float, duration: float) -> void:
	if not vibration_enabled or _using_mouse or (weak <= 0.0 and strong <= 0.0):
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


## Размер вспышки зависит от оружия; общий пул используется и стрелками-врагами.
func _show_muzzle_flash(weapon: WeaponData) -> void:
	var direction := _aim_dir if _aim_dir.length() > 0.1 else -global_basis.z
	var strength := 1.35 if weapon.pellets > 1 else (0.72 if weapon.icon == &"pistol" else 1.0)
	var tint: Color = Color(0.15, 0.8, 1.0) if weapon.projectile == &"plasma" else Fx.ELEMENT_COLORS.get(_stats[_weapon_index].get("ammo", &"physical"), Color(1, 0.66, 0.28))
	Fx.muzzle(_tip(), direction, strength, tint, weapon.muzzle_flash_energy)
	if weapon.icon == &"shotgun": Fx.shotgun_blast(_tip(), direction, tint)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_smoke_at >= weapon.smoke_interval:
		Fx.smoke(_tip() + direction * 0.08, direction)
		_last_smoke_at = now


## Модель вспыхивает: красным, если задело здоровье, голубым — если удар принял энергощит.
func _flash_body(hurt: bool) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(1.0, 0.1, 0.1, 0.5) if hurt else Color(0.4, 0.75, 1.0, 0.45)
	var meshes := $Model.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		m.material_overlay = overlay
	await get_tree().create_timer(0.09).timeout
	for m in meshes:
		if is_instance_valid(m):
			m.material_overlay = null


## Заряды аптечки за убийства (дробные: 0.5 — половина заряда).
func add_flask_charge(amount: float) -> void:
	flask_charges = minf(flask_charges + amount, float(flask_max_charges))


## Свойство «+% к лечению аптечкой».
func _flask_mult() -> float:
	return 1.0 + _gear.get(&"flask_pct", 0) / 100.0


func _use_flask() -> void:
	if flask_charges < 1.0 or hp >= max_hp:
		return
	flask_charges -= 1.0
	_heal_left += flask_heal * _flask_mult()
	Sfx.play(&"heal", global_position)


func _update_health(delta: float) -> void:
	if Input.is_action_just_pressed("heal"):
		_use_flask()
	if hp_regen > 0.0:
		hp = minf(hp + hp_regen * delta, max_hp)
	if _es_wait > 0.0:
		_es_wait -= delta
	elif es < max_es:
		es = minf(es + max_es * es_recharge_rate * _es_recharge_mult * delta, max_es)
	if _heal_left > 0.0:
		var step := minf(flask_heal * _flask_mult() / flask_heal_time * delta, _heal_left)
		_heal_left -= step
		hp = minf(hp + step, max_hp)
		if hp >= max_hp:
			_heal_left = 0.0


func _die() -> void:
	_dead = true
	_heal_left = 0.0
	_firing = false
	_sprinting = false
	if is_reloading():
		_reload_left = 0.0
		reload_cancelled.emit()
	died.emit()
	if Game.is_hardcore():
		Game.SaveGame.delete()  # хардкор: смерть — конец забега, сохранение стирается
		Game.player = null
		show_message("Хардкор: персонаж погиб. Забег окончен.", 4.0)
		await get_tree().create_timer(restart_delay + 2.0).timeout
		Game.to_main_menu()
		return
	await get_tree().create_timer(restart_delay).timeout
	_revive()


## Возрождение у входа в текущий уровень (как чекпоинт в PoE 2). Вещи и враги остаются как были.
func _revive() -> void:
	var level_node := get_parent()
	global_position = level_node.get_meta("spawn", global_position)
	velocity = Vector3.ZERO
	_dead = false
	hp = max_hp
	es = max_es
	flask_charges = float(flask_max_charges)
	_es_wait = 0.0
	show_message("Вы очнулись у входа в зону", 2.5)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return
	_update_health(delta)
	_update_pickup()
	_update_muzzle()
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(move_input.x, 0.0, move_input.y)
	move_dir = _loot_walk_dir(move_dir)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_dodge_buffer_left = maxf(0.0, _dodge_buffer_left - delta)
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer_left = dodge_buffer_time
	if _dodge_buffer_left > 0 and not is_dodging() and _recovery_left <= 0:
		_dodge_buffer_left = 0
		_start_dodge(move_dir)

	# Спринт держится, пока зажата кнопка и игрок двигается.
	if _sprinting and (not Input.is_action_pressed("dodge") or move_dir.length() < 0.1):
		_sprinting = false
		_recovery_left = 0.0

	if is_dodging() or _recovery_left > 0:
		var total := dodge_duration + dodge_recovery
		var before := _roll_elapsed
		_roll_elapsed = minf(total, _roll_elapsed + delta)
		if not _dodge_contact_played and roll_source_phase(_roll_elapsed) >= dodge_sound_phase:
			_dodge_contact_played = true
			Sfx.play(&"roll_contact", global_position)

		_dodge_left = maxf(0, dodge_duration - _roll_elapsed)
		_recovery_left = clampf(total - _roll_elapsed, 0, dodge_recovery) if _dodge_left <= 0 else 0.0
		var speed := dodge_distance * (_roll_progress(roll_source_phase(_roll_elapsed)) - _roll_progress(roll_source_phase(before))) / delta
		var horizontal := _dodge_dir * speed
		if _dodge_left <= 0 and move_dir.length_squared() > 0.01:
			# Подъём продолжается визуально, но больше не задерживает управление ногами.
			var walk_speed := sprint_speed if Input.is_action_pressed("dodge") else move_speed
			horizontal = Vector3(velocity.x, 0, velocity.z).move_toward(move_dir * walk_speed * move_speed_mult, acceleration * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if _dodge_left <= 0 and _recovery_left <= 0:
			_sprinting = Input.is_action_pressed("dodge") and move_dir.length() > 0.1
	else:
		var speed := move_speed
		if _sprinting:
			speed = sprint_speed
		elif is_firing():
			speed = shoot_move_speed
		speed *= move_speed_mult
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		horizontal = horizontal.move_toward(move_dir * speed, acceleration * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	move_and_slide()
	_update_aim(move_dir, delta)
	_update_muzzle() # Дуло после движения и поворота, а не из начала кадра.
	_update_shooting(delta)


# --- Перекат -----------------------------------------------------------------

## Весь исходный клип: основная часть и подъём имеют собственный темп.
func roll_source_phase(elapsed: float) -> float:
	const SPLIT := 0.72 / 0.92
	if elapsed <= dodge_duration:
		return SPLIT * clampf(elapsed / maxf(dodge_duration, 0.001), 0, 1)
	return SPLIT + (1.0 - SPLIT) * clampf((elapsed - dodge_duration) / maxf(dodge_recovery, 0.001), 0, 1)


func _roll_progress(time: float) -> float:
	var phase := clampf(time, 0, 1)
	if _dodge_motion.is_empty():
		return smoothstep(0.0, 1.0, phase)
	var index := phase * (_dodge_motion.size() - 1)
	var first := mini(floori(index), _dodge_motion.size() - 1)
	return lerpf(_dodge_motion[first], _dodge_motion[mini(first + 1, _dodge_motion.size() - 1)], index - first)


func _start_dodge(move_dir: Vector3) -> void:
	var animator := get_node("Animator") as AnimationTree
	_dodge_motion = animator.get_animation(animator.roll_anim).get_meta("motion_profile", PackedFloat32Array())
	_recovery_left = 0
	_roll_elapsed = 0.0
	_dodge_contact_played = false
	_post_roll_aim_pending = true
	# Перезарядка продолжает отсчёт под полным клипом переката.
	_dodge_dir = move_dir.normalized() if move_dir.length() > 0.1 else _aim_dir
	_dodge_left = dodge_duration
	# Кувырок идёт вперёд по модели, поэтому сразу разворачиваем персонажа по направлению переката.
	rotation.y = atan2(-_dodge_dir.x, -_dodge_dir.z)
	Fx.smoke(global_position + Vector3.UP * 0.06, -_dodge_dir)


# --- Прицел ------------------------------------------------------------------

func _update_aim(move_dir: Vector3, delta: float) -> void:
	var desired := _aim_dir
	mouse_target = null
	aim_target = null

	if is_dodging() or (_recovery_left > 0 and get_node("Animator")._state == &"Roll"):
		desired = _dodge_dir
	elif _sprinting:
		# В спринте смотрим туда, куда бежим.
		desired = move_dir.normalized()
		_locked_target = null
	elif _using_mouse:
		mouse_target = _find_mouse_target()
		var point = _mouse_point()
		if mouse_target != null:
			aim_target = mouse_target
			desired = _flat_dir_to(mouse_target)
		elif point != null:
			var to_point: Vector3 = point - global_position
			to_point.y = 0.0
			if to_point.length() > 0.3:
				desired = to_point.normalized()
	else:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.25:
			# Ручной прицел правым стиком + лёгкий «магнит».
			desired = Vector3(stick.x, 0.0, stick.y).normalized()
			var assisted := _find_target(desired, aim_assist_cone, aim_assist_range)
			if assisted:
				aim_target = assisted
				desired = _flat_dir_to(assisted)
			_locked_target = null
		else:
			# Как в PoE: сами целимся в любого видимого на экране врага.
			var base := move_dir.normalized() if move_dir.length() > 0.1 else _aim_dir
			var target := _find_visible_target(base)
			if target:
				aim_target = target
				desired = _flat_dir_to(target)
			elif move_dir.length() > 0.1:
				desired = base

	_aim_dir = desired
	var target_yaw := atan2(-desired.x, -desired.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Враг рядом с курсором на экране (и не за стеной) — для «магнита» мыши.
func _find_mouse_target() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var radius := mouse_assist_radius * get_viewport().get_visible_rect().size.y / 720.0
	var best: Node3D = null
	var best_d := radius * radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.global_position.distance_squared_to(global_position) > 900.0:
			continue
		var center: Vector3 = enemy.global_position + Vector3.UP * 0.9
		if camera.is_position_behind(center):
			continue
		var d := camera.unproject_position(center).distance_squared_to(mouse)
		if d < best_d:
			best_d = d
			best = enemy
	if best != null and not _is_valid_target(best, camera):
		return null
	return best


func _mouse_point() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.UP, muzzle.global_position.y)
	return plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))


func _find_target(dir: Vector3, cone_degrees: float, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var cos_limit := cos(deg_to_rad(cone_degrees))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance < 0.01 or distance > max_range:
			continue
		var facing := dir.dot(to_enemy / distance)
		if facing < cos_limit:
			continue
		var score := distance * (2.0 - facing)  # ближе и точнее по курсу — лучше
		if score < best_score:
			best_score = score
			best = enemy
	return best


## Автоприцел: враг на экране и не за стеной. Предпочитаем ближних и тех, кто по ходу движения.
## Текущую цель держим, пока новая не станет заметно лучше, — чтобы прицел не дёргался.
func _find_visible_target(dir: Vector3) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var locked_score := INF
	if _locked_target != null and is_instance_valid(_locked_target) and _is_valid_target(_locked_target, camera):
		locked_score = _target_score(_locked_target, dir)
	else:
		_locked_target = null

	var best: Node3D = _locked_target
	var best_score := locked_score * 0.7
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == _locked_target or not enemy is Node3D:
			continue
		if not _is_valid_target(enemy, camera):
			continue
		var score := _target_score(enemy, dir)
		if score < best_score:
			best_score = score
			best = enemy
	_locked_target = best
	return best


func _is_valid_target(enemy: Node3D, camera: Camera3D) -> bool:
	if not enemy.is_in_group("enemies"):
		return false
	var center := enemy.global_position + Vector3.UP * 0.9
	if not camera.is_position_in_frustum(center):
		return false
	# Не стреляем в того, кто за стеной, ящиком или закрытой дверью (слои 1 и 5).
	var eye := global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(eye, center, 1 | 16)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _target_score(enemy: Node3D, dir: Vector3) -> float:
	var to_enemy := enemy.global_position - global_position
	to_enemy.y = 0.0
	var distance := maxf(to_enemy.length(), 0.01)
	var facing := dir.dot(to_enemy / distance)  # 1 — прямо по курсу, -1 — сзади
	return distance * (1.0 + auto_aim_direction_bias * (1.0 - facing))


func _flat_dir_to(node: Node3D) -> Vector3:
	var to_node := node.global_position - global_position
	to_node.y = 0.0
	return to_node.normalized()


# --- Оружие ------------------------------------------------------------------

func current_weapon() -> WeaponData:
	return weapon_data(_weapon_index)


## Взять оружие в руки (из инвентаря). То же, что кнопки 1/2.
func select_weapon(index: int) -> void:
	if fixed_bow_loadout: return
	if index != _weapon_index and weapon_item(index) != null:
		_equip(index)


func current_weapon_index() -> int:
	return _weapon_index


func current_magazine_size() -> int:
	return _stats[_weapon_index].get("magazine", 0) if not _stats.is_empty() else 0


func current_ammo() -> int:
	return _ammo[_weapon_index] if not _ammo.is_empty() else 0


func is_reloading() -> bool:
	return _reload_left > 0.0


## Доля оставшейся перезарядки: 1 — только начали, 0 — готово.
func reload_progress() -> float:
	var weapon := current_weapon()
	if weapon == null or not is_reloading():
		return 0.0
	return 1.0 - _reload_left / _stats[_weapon_index].reload_time


func _equip(index: int) -> void:
	if fixed_bow_loadout and index != 0: return
	if index < 0 or index >= PlayerInventory.WEAPON_COUNT or weapon_item(index) == null:
		return
	if not fixed_bow_loadout and not ItemDB.available_in_act_one(weapon_item(index).base):
		show_message("Это оружие отложено для следующих актов")
		return
	if is_reloading():
		_reload_left = 0.0
		reload_cancelled.emit()
	_weapon_index = index
	gun.visible = true
	_fire_cooldown = maxf(_fire_cooldown, switch_delay)

	# Брусок-заглушка нужного размера: задний край остаётся в ладони, ствол вытягивается вперёд.
	var weapon := weapon_data(index)
	var mesh := BoxMesh.new()
	mesh.size = weapon.model_size
	var material := StandardMaterial3D.new()
	material.albedo_color = weapon.model_color
	material.metallic = 0.7
	material.roughness = 0.45
	mesh.material = material
	gun.mesh = mesh
	gun.transform = _gun_base
	gun.position = _gun_base.origin + _gun_base.basis * Vector3(0.0, 0.0, -(weapon.model_size.z * 0.5 - 0.12))
	# Настоящая модель оружия (если есть) вместо бруска.
	for child in gun.get_children():
		if child.has_meta("weapon_model"):
			child.queue_free()
	if weapon.model != null:
		gun.mesh = null
		gun.position = _gun_base.origin
		var model := weapon.model.instantiate() as Node3D
		model.set_meta("weapon_model", true)
		model.rotation.y = deg_to_rad(weapon.model_yaw)
		model.scale = Vector3.ONE * weapon.model_scale
		model.position = weapon.model_offset
		gun.add_child(model)
	gun.transform = gun.transform * Transform3D(Basis.from_euler(weapon.grip_rotation_degrees * PI / 180.0), weapon.grip_offset)
	_gun_rest = gun.position
	_muzzle_local = _gun_tip_local()
	if not fixed_bow_loadout: Sfx.play(&"reload_end", global_position)
	_update_stowed()
	_update_offhand()


## «Два ствола»: копия пистолета в левой руке (зеркально правой).
var _offhand: BoneAttachment3D


func _update_offhand() -> void:
	if _offhand != null:
		_offhand.queue_free()
		_offhand = null
	if _stats.size() <= _weapon_index or not _stats[_weapon_index].get("dual", false):
		return
	var weapon := weapon_data(_weapon_index)
	if weapon == null or weapon.model == null:
		return
	_offhand = BoneAttachment3D.new()
	_offhand.bone_name = "hand_l"
	_offhand.use_external_skeleton = true
	add_child(_offhand)
	_offhand.external_skeleton = _offhand.get_path_to($Model/Armature/Skeleton3D)
	var holder := Node3D.new()
	# Зеркало правой руки: та же поза, ось X наоборот.
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	holder.transform = Transform3D(mirror * _gun_base.basis * mirror, mirror * _gun_base.origin)
	_offhand.add_child(holder)
	var model := weapon.model.instantiate() as Node3D
	model.rotation.y = deg_to_rad(weapon.model_yaw)
	model.scale = Vector3.ONE * weapon.model_scale
	model.position = weapon.model_offset
	holder.add_child(model)


## Оружие не в руках крепится на спине.
var _stowed: Array[Node3D] = []


## Центр габаритов модели в координатах её родителя.
func _local_center(model: Node3D) -> Vector3:
	var inv: Transform3D = model.get_parent().global_transform.affine_inverse() if model.is_inside_tree() else Transform3D.IDENTITY
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inv * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center() if not first else Vector3.ZERO


func _update_stowed() -> void:
	for n in _stowed:
		if is_instance_valid(n):
			n.queue_free()
	_stowed.clear()
	if fixed_bow_loadout or not show_stowed_weapons: return
	var skeleton := $Model.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
	if skeleton == null:
		return
	var back_i := 0
	for i in PlayerInventory.WEAPON_COUNT:
		if i == _weapon_index:
			continue
		var data := weapon_data(i)
		if data == null or data.model == null:
			continue
		var holster := false
		var bone := "spine_03"
		if skeleton.find_bone(bone) < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = bone
		skeleton.add_child(att)
		var model := data.model.instantiate() as Node3D
		model.scale = Vector3.ONE * data.model_scale
		att.add_child(model)
		var target: Vector3
		if holster:
			# Ствол вниз вдоль бедра, снаружи.
			model.rotation_degrees = Vector3(0, data.model_yaw, -90)
			target = Vector3(-0.11, 0.18, 0.0)
		else:
			# На спине наискосок; второе — крест-накрест.
			var side := 1.0 if back_i == 0 else -1.0
			model.rotation_degrees = Vector3(0, data.model_yaw, 90 + 35 * side)
			target = Vector3(0.0, 0.08, -0.2)
			back_i += 1
		# У моделей центр смещён — ставим по центру их габаритов.
		model.position = target - _local_center(model)
		_stowed.append(att)


## Кончик ствола: самая дальняя вперёд (−Z) точка модели оружия, на высоте верхней трети.
func _gun_tip_local() -> Vector3:
	var inv := gun.global_transform.affine_inverse()
	# Точная отметка дула у моделей с заданной точкой вылета.
	for model in gun.get_children():
		if model.is_queued_for_deletion() or not model.has_meta("weapon_model"):
			continue
		var tip := model.get_node_or_null("MuzzleTip") as Marker3D
		if tip != null:
			return inv * tip.global_position
	var box := AABB()
	var first := true
	var meshes: Array = gun.find_children("*", "MeshInstance3D", true, false)
	if gun.mesh != null:
		meshes.append(gun)
	for mi in meshes:
		var old_model := false
		var n: Node = mi
		while n != null and n != gun:
			if n.is_queued_for_deletion():
				old_model = true
			n = n.get_parent()
		if old_model:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return Vector3.ZERO
	return Vector3(box.get_center().x, box.position.y + box.size.y * 0.7, box.position.z)


## Дуло следует за кончиком ствола (рука двигается в анимации).
func _update_muzzle() -> void:
	if fixed_bow_loadout and _bow_modifier != null and _bow_modifier.has_meta("arrow_origin"):
		muzzle_tip = _bow_modifier.get_meta("arrow_origin")
		muzzle.global_position = Vector3(muzzle_tip.x, global_position.y + fire_height, muzzle_tip.z)
		return
	if gun != null and _muzzle_local != Vector3.ZERO:
		# По горизонтали — кончик ствола, по высоте — «линия огня» (fire_height): иначе пуля из поднятого
		# ствола пролетает над пригнувшимися врагами вплотную.
		var tip: Vector3 = gun.global_transform * _muzzle_local
		muzzle_tip = tip
		muzzle.global_position = Vector3(tip.x, global_position.y + fire_height, tip.z)


func _tip() -> Vector3:
	return muzzle_tip if muzzle_tip != Vector3.ZERO else muzzle.global_position


## Пуля попала во врага (зовёт bullet.gd): для отметки на прицеле.
func on_hit_confirmed(killed: bool) -> void:
	hit_marker_msec = Time.get_ticks_msec()
	hit_marker_kill = killed


func _start_reload() -> void:
	if fixed_bow_loadout: return
	var weapon := current_weapon()
	if weapon == null or is_reloading() or current_ammo() >= current_magazine_size():
		return
	# «Быстрый затвор» (дробовики): иногда магазин полон сразу.
	if randf() < _stats[_weapon_index].get("instant_reload", 0.0):
		_ammo[_weapon_index] = current_magazine_size()
		Sfx.play(&"reload_end", global_position)
		return
	_reload_left = _stats[_weapon_index].reload_time
	reload_started.emit(_reload_left)
	Sfx.play(&"reload_start", global_position)


func _update_weapon_switch() -> void:
	if fixed_bow_loadout:
		if _weapon_index != 0: _equip(0)
		return
	for i in PlayerInventory.WEAPON_COUNT:
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)) and i != _weapon_index:
			_equip(i)
	# Следующее / предыдущее — по кругу, пропуская пустые слоты.
	var step := 1 if Input.is_action_just_pressed("weapon_next") else (-1 if Input.is_action_just_pressed("weapon_prev") else 0)
	if step != 0:
		for k in range(1, PlayerInventory.WEAPON_COUNT):
			var i := (_weapon_index + step * k + PlayerInventory.WEAPON_COUNT) % PlayerInventory.WEAPON_COUNT
			if weapon_item(i) != null:
				_equip(i)
				break


# --- Стрельба ----------------------------------------------------------------

## Без фиксированной добавочной задержки: ждём окончательную позу и реальное направление.
func weapon_ready_after_roll() -> bool:
	if not _post_roll_aim_pending: return true
	if is_dodging() or _recovery_left > 0.0: return false
	var animator: AnimationTree = get_node("Animator")
	if animator._state == &"Roll" or animator.get("parameters/roll_mix/blend_amount") > 0.001:
		return false
	var desired := Vector3(_aim_dir.x, 0, _aim_dir.z).normalized()
	var forward := -global_basis.z
	if fixed_bow_loadout:
		return forward.dot(desired) >= cos(deg_to_rad(post_roll_fire_angle_degrees))
	var weapon_forward := -gun.global_basis.z
	weapon_forward.y = 0.0
	var min_dot := cos(deg_to_rad(post_roll_fire_angle_degrees))
	return forward.dot(desired) >= min_dot and weapon_forward.normalized().dot(desired) >= min_dot


func _update_shooting(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	muzzle_flash.light_energy = move_toward(muzzle_flash.light_energy, 0.0, delta * 60.0)
	_update_weapon_switch()
	var weapon := current_weapon()
	if weapon == null:
		return
	if fixed_bow_loadout:
		_update_bow_shooting(delta)
		return

	weapon = current_weapon()
	if get_node("Skills").is_charging_pulse():
		_firing = false
		return
	if weapon.projectile == &"mine":
		_firing = Input.is_action_pressed("shoot") and not is_dodging() and not _sprinting and _recovery_left <= 0.0
		if _firing and _fire_cooldown <= 0:
			if get_node("Skills").place_mine():
				_fire_cooldown = 1.0 / maxf(_stats[_weapon_index].fire_rate, 0.1)
			else:
				_fire_cooldown = 0.15
		return

	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo[_weapon_index] = current_magazine_size()
			Sfx.play(&"reload_end", global_position)
	elif Input.is_action_just_pressed("reload") and not (Input.is_action_just_pressed("pickup") and nearest_loot() != null):
		# На геймпаде X и перезаряжает, и поднимает: если рядом вещь — X её поднимает.
		_start_reload()

	_firing = Input.is_action_pressed("shoot") and not is_dodging() and not _sprinting and _recovery_left <= 0.0
	if not _firing or _fire_cooldown > 0.0 or is_reloading() or not weapon_ready_after_roll():
		return
	if not hold_to_fire and not weapon.automatic and not Input.is_action_just_pressed("shoot"):
		return
	if current_ammo() <= 0:
		if Input.is_action_just_pressed("shoot"):
			Sfx.play(&"empty", global_position)
		if auto_reload:
			_start_reload()
		return

	_fire_cooldown = 1.0 / _stats[_weapon_index].fire_rate
	_ammo[_weapon_index] -= 1
	_post_roll_aim_pending = false
	_shoot(weapon)
	if current_ammo() <= 0 and auto_reload:
		_start_reload()


func bow_draw_fraction() -> float:
	return clampf(_bow_draw_elapsed / bow_draw_time, 0, 1)

func _update_bow_shooting(delta: float) -> void:
	_bow_equip_left = maxf(0, _bow_equip_left - delta)
	if _bow_equip_left > 0:
		_firing = false
		return
	_bow_release_left = maxf(0.0, _bow_release_left - delta)
	_firing = Input.is_action_pressed("shoot") and not is_dodging() and not _sprinting and _recovery_left <= 0 and not is_dead()
	if not _firing or not weapon_ready_after_roll():
		_bow_draw_elapsed = 0.0
		return
	if _bow_release_left > 0.0 or _fire_cooldown > 0.0: return
	if _bow_draw_elapsed == 0.0: Sfx.play(&"bow_draw", global_position, -16.0)
	_bow_draw_elapsed += delta
	if _bow_draw_elapsed < bow_draw_time: return
	_bow_draw_elapsed = 0.0
	_bow_release_left = bow_release_time
	_fire_cooldown = maxf(bow_release_time, 1.0 / maxf(_stats[0].fire_rate, 0.1) - bow_draw_time)
	_post_roll_aim_pending = false
	_shoot(current_weapon())
	bow_shots_fired += 1

func _shoot(weapon: WeaponData, override_stats: Dictionary = {}) -> void:
	if _bullet_pool == null:
		_bullet_pool = get_tree().get_first_node_in_group("bullet_pool")
		if _bullet_pool == null:
			return

	_update_muzzle()
	# Направление считаем от груди, а не от дула: враг вплотную может стоять ближе кончика ствола,
	# и тогда «от дула к врагу» смотрит назад — пули уходили мимо.
	var chest := Vector3(global_position.x, muzzle.global_position.y, global_position.z)
	var dir := _aim_dir if not _using_mouse else -muzzle.global_basis.z
	if not _using_mouse and is_instance_valid(aim_target):
		# Автонаведение задаёт траекторию независимо от плавного поворота корпуса.
		dir = aim_target.global_position - chest
	elif _using_mouse and mouse_target != null and is_instance_valid(mouse_target):
		# Прицел прилип к врагу — стреляем точно в него.
		dir = mouse_target.global_position - chest
	elif _using_mouse:
		# Пуля летит точно в курсор, даже если персонаж ещё доворачивается.
		var point = _mouse_point()
		if point != null:
			var to_point: Vector3 = point - chest
			to_point.y = 0.0
			if to_point.length() > 1.5:
				dir = to_point
	dir.y = 0.0
	if dir.length_squared() < 0.0025:  # враг ровно в герое — стреляем, куда смотрит ствол
		dir = Vector3(-muzzle.global_basis.z.x, 0.0, -muzzle.global_basis.z.z)
	dir = dir.normalized()

	var stats := _stats[_weapon_index] if override_stats.is_empty() else override_stats
	var pellets: int = stats.pellets
	var spread: float = stats.spread
	var payload := {
		"damage": stats.damage, "elements": stats.elements, "pierce": stats.pierce,
		"chain": stats.chain, "leech": stats.leech, "shooter": self,
		"explode_radius": stats.explode_radius, "explode_ratio": stats.explode_ratio, "homing": stats.homing,
		"allow_stagger": weapon.allow_hit_stagger,
		"nova_projectiles": stats.get("nova_projectiles", 0),
		"nova_damage_ratio": stats.get("nova_damage_ratio", 0.5),
		"nova_state": {"triggered": false},
		"look": &"pellet" if weapon.icon == &"shotgun" else weapon.projectile, "lift": _tip().y - muzzle.global_position.y, "ammo": stats.ammo,
		"hide_tracer": false,
		"pellet_visual_scale": weapon.pellet_visual_scale,
		"width": stats.get("width", 0.0),
	}
	# «Злая очередь» (автоматы): выстрел с шансом прошивает и рикошетит.
	if randf() < stats.get("ricochet_chance", 0.0):
		payload.pierce += 1
		payload.chain += 1
	for i in pellets:
		var angle := randf_range(-spread, spread)
		# Обычный сноп плотнее в центре узкого конуса; «Мультишот» покрывает широкий конус.
		if weapon.icon == &"shotgun" and not stats.get("wide_shotgun", false):
			angle = (angle + randf_range(-spread, spread)) * 0.5
		var pellet_dir := dir.rotated(Vector3.UP, deg_to_rad(angle))
		var bullet_transform := Transform3D(Basis.looking_at(pellet_dir, Vector3.UP), muzzle.global_position)
		var speed_variation := randf_range(0.86, 1.14) if weapon.icon == &"shotgun" else 1.0
		_bullet_pool.fire(bullet_transform, weapon.bullet_speed * stats.range_mult * speed_variation, weapon.bullet_range * stats.range_mult,
				chest, payload)

	muzzle_flash.light_energy = 0.0
	muzzle_flash.light_color = Fx.ELEMENT_COLORS.get(stats.ammo, Color(1.0, 0.8, 0.5))
	_shot_feedback(weapon)
	Sfx.play(weapon.shot_sound, muzzle.global_position, weapon.shot_volume_db)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent().has_method("add_dip"):
		camera.get_parent().add_dip(weapon.camera_kick)

