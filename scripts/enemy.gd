class_name Enemy
extends CharacterBody3D
## Общая основа всех врагов: здоровье и броня, состояния от стихий (огонь, электричество, кислота),
## сон и пробуждение, поиск пути к игроку, ближняя атака с замахом, смерть, выпадение модулей.
## Конкретные враги (crawler.gd, brute.gd, spitter.gd) задают вид и меняют поведение там, где нужно.

signal died

## В обучении добыча задаётся вручную, без случайных наград.
@export var drops_enabled := true

const EXPLOSION := preload("res://scenes/explosion.tscn")
const LOOT := preload("res://scripts/loot_pickup.gd")
const LOS_MASK := 1 | 16  # стены и двери закрывают обзор
const Highlight := preload("res://scripts/highlight.gd")
const Ragdoll := preload("res://scripts/ragdoll.gd")
const Mods := preload("res://scripts/monster_mods.gd")
const Suit := preload("res://scripts/suit.gd")
const Animator := preload("res://scripts/player_animator.gd")
const EnemyAnimationProfiles := preload("res://scripts/enemy_animation_profiles.gd")
const Hair := preload("res://scripts/hair.gd")
const Outfit := preload("res://scripts/outfit.gd")

enum State { SLEEP, CHASE, WINDUP, RECOVER, DEAD }

## Имя врага (в полоске цели сверху экрана).
@export var display_name := "Враг"
## Редкость, как в PoE 2: 0 — обычный, 1 — синий (одно свойство), 2 — жёлтый (2–3 свойства, своё имя).
@export_enum("Обычный", "Синий", "Жёлтый") var rarity := 0
## Охраняет лифт: пока жив, лифт заблокирован (как босс). Ставит генератор финальной стае.
@export var guards_exit := false
## Свойства (monster_mods.gd). Пусто — выпадут случайно по редкости.
@export var mods: Array[StringName] = []

@export_group("Здоровье")
@export var max_hp := 30.0
## Общий баланс здоровья всех врагов, включая редких, боссов и подкрепления.
@export_range(0.1, 2.0, 0.01) var health_scale := 0.72
## Броня: какую долю ФИЗИЧЕСКОГО урона срезает (0.5 = половину). Кислота её снимает.
@export_range(0.0, 0.9) var armor := 0.0

@export_group("Награда")
## Уровень врага = уровень выпадающих предметов. Берётся у этажа (zone.gd: zone_level), если он есть.
@export var level := 1
## Насколько крепче и больнее враг с каждым уровнем выше первого (доли).
@export var hp_per_level := 0.3
@export var damage_per_level := 0.15
## Сколько заряда аптечки получает игрок за убийство.
@export var flask_charge_reward := 0.2
## Шанс выпадения чистого модуля оружия (0..1).
@export_range(0.0, 1.0) var module_drop_chance := 0.04
## Шанс выпадения ксено-фрагмента.
@export_range(0.0, 1.0) var currency_drop_chance := 0.1
## Шанс выпадения предмета экипировки и насколько он чаще бывает синим/жёлтым.
@export_range(0.0, 1.0) var gear_drop_chance := 0.08
@export_range(0.0, 1.0) var rarity_bonus := 0.0
## Опыт за убийство.
@export var xp_reward := 6
## Шанс выпадения золота и сколько (от и до).
@export_range(0.0, 1.0) var gold_drop_chance := 0.15
@export var gold_amount := Vector2i(2, 6)

@export_group("Движение")
@export var move_speed := 6.0
@export var acceleration := 40.0
@export var turn_speed := 12.0
## Как часто пересчитывать путь (сек). Реже — дешевле при толпе.
@export var path_update_interval := 0.4

@export_group("Повадки")
## Заходит сбоку, а не строго в лоб (0 — прямо на игрока). Вблизи всё равно бьёт в лоб.
@export_range(0.0, 1.0) var flank := 0.45
## Рывки «полубегом»: каждые surge_every с враг на surge_time с ускоряется в surge_mult раз (0 — без рывков).
@export var surge_every := 0.0
@export var surge_time := 1.2
@export var surge_mult := 1.8
## Разброс скорости между врагами одного вида (0.15 = ±15%).
@export var speed_jitter := 0.15

@export_group("Атака")
@export var damage := 8.0
## С какого расстояния начинает замах.
@export var attack_range := 1.4
## Длительность замаха (сек) — окно, чтобы откатиться.
@export var attack_windup := 0.3
## Доля клипа, на которой рука достигает цели; замах синхронизируется с уроном.
@export_range(0.1, 0.9) var attack_contact_fraction := 0.42
## Удар проверяется только перед врагом, по текущему положению цели.
@export_range(30, 180) var attack_arc_degrees := 90.0
## Удар попадает, если игрок в конце замаха ближе этого расстояния.
@export var attack_reach := 1.9
@export var attack_cooldown := 0.7
@export var lunge_speed := 7.0
@export var attack_sound := &"crawler_bite"

@export_group("Внимание")
## Сразу бежит к игроку (для тех, кто вылезает волнами).
@export var start_awake := false
## С какого расстояния замечает игрока, если видит его.
@export var aggro_range := 15.0
## Будит спящих сородичей в этом радиусе, когда просыпается сам.
@export var wake_radius := 7.0

@export_group("Смерть")
@export var death_sound := &"crawler_death"
@export var death_effect_scale := 1.0
## Сколько кусков разлетается при смерти (0 — без кусков).
@export var gib_count := 11
## Цвет свежей плоти в органических фрагментах, отдельно от старого оттенка костюма.
@export var gib_flesh_color := Color(0.42, 0.16, 0.12)
## Доля попаданий, от которых на пол и стены летят брызги крови.
@export_range(0.0, 1.0) var blood_on_hit := 0.8
## Дополнительные небольшие куски при ранении; дробь не создаёт их на каждую дробинку.
@export_range(0.0, 1.0) var hit_gib_chance := 0.18
@export var hit_gib_interval := 0.18
@export var death_blood_scale := 1.7
@export var corpse_blood_patches := 7
var _next_hit_gib_at := 0
## Кого выпускает при смерти (Носитель лопается на ползунов).
@export var death_spawn_scene: PackedScene
@export var death_spawn_count := 0

@export_group("Блуждание")
## Пока спит, враг бродит вокруг места, где стоял (в этом радиусе, м), медленно.
@export var wander_radius := 3.5
@export_range(0.0, 1.0) var wander_speed_ratio := 0.3
## Бродят только враги ближе этого расстояния до игрока — дальние стоят, экономим физику.
@export var wander_active_range := 45.0

@export_group("Модель")
## Готовая модель с анимациями (роботы из Sci-Fi Essentials). Пусто — вид собирается в коде (_build_visual).
@export var model: PackedScene
@export var model_scale := 1.0
@export var model_offset := Vector3.ZERO
## Поворот модели (градусы): у моделей из паков «вперёд» — это +Z, у наших врагов — −Z.
@export var model_yaw := 180.0
@export var anim_idle := &"Idle"
@export var anim_walk := &"Walk"
@export var anim_run := &"Run"
@export var anim_attack := &"Attack"
## Быстрее этой скорости играем бег, медленнее — ходьбу.
@export var run_threshold := 3.0
## С какой скоростью (м/с) «идут» ноги в клипах ходьбы и бега при обычной скорости анимации.
## Скорость клипа подгоняется под реальное движение — ноги не скользят. 0 — прежний расчёт.
@export var anim_walk_speed := 0.0
@export var anim_run_speed := 0.0

@export_group("Модель-человек")
## Заражённый сотрудник: базовая модель Quaternius с анимациями UAL (вместо вида, собранного в коде).
## Вторая модель (если задана) выбирается случайно — для разнообразия.
@export var humanoid_model: PackedScene
@export var humanoid_alt: PackedScene
## Дополнительные полноценные модели: выбираются случайно для разнообразия врагов.
@export var humanoid_variants: Array[PackedScene] = []
## Пустое значение оставляет прежнюю библиотеку; иначе переносит движения из нового пака.
@export var animation_profile := ""
## Одежда (Modular Character Outfits): случайная подходящая по полу, с шансом outfit_chance.
@export var outfits: Array[PackedScene] = []
@export_range(0.0, 1.0) var outfit_chance := 0.0
## Цвет ткани (умножается на текстуру): потёртая, грязная одежда.
@export var outfit_tint := Color(0.5, 0.45, 0.4)
@export var humanoid_scale := Vector3.ONE
## Цвета «костюма»: светящиеся пятна и основа (тёмная кожа / лохмотья).
@export var skin_accent := Color(0.4, 1.0, 0.3)
@export var skin_plate := Color(0.2, 0.2, 0.18)
## Оттенок кожи: бледно-зелёный у заражённых.
@export var skin_tint := Color(0.62, 0.75, 0.55)
## Одежда: рабочий комбинезон, халат — чтобы заражённых не путать с героем.
@export var skin_cloth := Color(0.55, 0.32, 0.12)
@export var anim_death := &"Death01"
## Реакция на сильный удар (вздрагивает и отшатывается), не чаще раза в hit_anim_cooldown сек.
@export var anim_hit := &"Hit_Knockback"
@export var hit_anim_cooldown := 1.5
## Дополнительные анимации из UAL (прыжок и т.п.) — для особых врагов.
@export var extra_anims: Array[StringName] = []
## Причёски на выбор (случайно; иногда — лысый).
@export var hair_styles: Array[PackedScene] = []
@export var hair_tint := Color(0.55, 0.55, 0.5)

@export_group("Ощущение попаданий")
## Цвет крови (брызги из раны).
@export var blood_color := Color(0.75, 0.85, 0.15)
## Насколько далеко отбрасывает от попадания (Носителя почти не сдвинуть).
@export var knockback := 4.0
@export_range(0.0, 1.0) var knockback_resist := 0.0
## Общий множитель отброса от пуль (1 — как было; меньше — враг почти не дёргается).
@export_range(0.0, 1.0) var hit_push := 0.28
## Верхняя скорость от пуль: несколько дробинок не складываются в огромный отброс.
@export var max_hit_push_speed := 2.2
## Белая вспышка всего тела при попадании (выключена: выглядело мультяшно).
@export var hit_flash := false
## «Сплющивание» тела при попадании (0 — нет; раньше было 0.15 и выглядело мультяшно).
## Правило Disney «сжатие и растяжение»: тело на миг приседает вширь, затем пружинит обратно.
@export_range(0.0, 0.3) var hit_squash := 0.06
## Сколько секунд тело пружинит обратно после сплющивания.
@export_range(0.05, 0.5, 0.01) var hit_squash_time := 0.16
## Перелёт при возврате («инерция»): 0 — ровно возвращается, больше — заметнее подпрыгивает вверх.
@export_range(0.0, 3.0, 0.1) var hit_squash_spring := 1.6
## Доля здоровья за один удар, после которой враг отшатывается (анимация).
@export_range(0.0, 1.0) var hit_anim_threshold := 0.35
## Высота, на которой всплывают цифры урона.
@export var number_height := 1.3
## Сила тряски камеры при смерти.
@export var death_shake := 0.12

@export_group("Стихии")
## Горение: доля урона огнём, которую враг получает каждую секунду, пока горит.
@export var burn_ratio := 0.6
@export var burn_time := 3.0
## Шок: на сколько больше урона получает враг.
@export var shock_bonus := 0.2
@export var shock_time := 3.0
## Кислота: броня не работает, враг замедлен.
@export var corrode_time := 4.0
@export_range(0.0, 0.9) var corrode_slow := 0.3
## Красить врага цветом состояния (огонь — оранжевый, кислота — зелёный). Состояние всё равно видно в полоске цели.
@export var status_tint := false

static var _overlays := {}
## Трупы на полу: сколько лежит одновременно (самые старые исчезают). 0 — трупы не остаются.
@export_range(0, 80, 1) var max_corpses := 28
## Тело падает физикой (scripts/ragdoll.gd); выключено или нет нужных костей — анимация смерти.
@export var ragdoll_on_death := true
## Скорость толчка от добивающего кола (м/с на метр отлёта) и от обычного попадания.
@export var ragdoll_stake_force := 2.4
@export var ragdoll_hit_force := 2.0
## Подбрасывание вверх при смерти (м/с).
@export var ragdoll_lift := 1.2
static var _corpses: Array = []
## Подогнанные под скелет анимации — одна библиотека на модель, общая для всех врагов.
static var _libraries := {}
## Последний враг, по которому попал игрок, — его показывает полоска цели сверху экрана.
static var last_target: Enemy
static var last_target_msec := 0
## false — попадание «вторичное» (рикошет, прострел, взрыв): полоску цели сверху не переключаем.
static var mark_target := true

var _rare_parts: Array = []
var attack_element := &"physical"
## Откуда пришёл последний удар — куски при смерти летят в эту сторону.
var _last_hit_dir := Vector3.ZERO
## Добивающий кол коломёта: куда и на сколько метров отлетит тело (bullet.gd ставит перед уроном).
var impale_push := Vector3.ZERO
var _hit_anim_at := 0
var _hit_anim_left := 0.0
var _hit_slow_left := 0.0
## Краткая потеря темпа от пули; сопротивление отбрасыванию ослабляет её у тяжёлых врагов.
@export var hit_slow_duration := 0.22
@export_range(0.0, 1.0) var hit_slow_ratio := 0.55
@export var hit_stop_duration := 0.065
## Минимальная пауза между остановками от попаданий: очередь не держит врага навечно.
@export var hit_stop_cooldown := 0.38
var _next_hit_stop := 0
var _home := Vector3.ZERO
var _wandering := false
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0
var _wander_left := 0.0
var _wander_velocity := Vector3.ZERO
var _storm_left := 0.0
var _flank_side := 1.0
var _surge_left := 0.0
var _surge_wait := 0.0
var _regen := 0.0

var hp := 0.0
var _melee_pending := false
var _attack_direction := Vector3.FORWARD
var _state := State.SLEEP
var _player  # цель: игрок (player.gd) или провоцирующий робот-союзник
var _taunt_left := randf() * 0.5
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _path := PackedVector3Array()
var _path_index := 0
var _repath_left := 0.0
var _sense_left := 0.0
var _sees_player := false
var _timer := 0.0
var _anim_time := 0.0
var _visual: Node3D
## Меши, на которые накладывается вспышка попадания и цвет состояния.
var _overlay_targets: Array[MeshInstance3D] = []
var _burn_left := 0.0
var _burn_dps := 0.0
var _shock_left := 0.0
var _shock_extra := 0.0
var _corrode_left := 0.0
var _overlay_key := &""
var _flashing := false
var _number_accum := 0.0
var _number_left := 0.0
var _punch: Tween
## Обычный размер тела (у «огромных» 1.2): сплющивание возвращается к нему.
var _visual_scale := Vector3.ONE
var _model_anim: AnimationPlayer
var _anim_lock := 0.0  # пока идёт атака, ходьбу не включаем

@onready var health_bar: Node3D = $HealthBar


func _ready() -> void:
	add_to_group("enemies")
	if guards_exit:
		add_to_group("bosses")
	_apply_zone_level()
	_apply_rarity()
	hp = max_hp
	_home = global_position
	move_speed *= 1.0 + randf_range(-speed_jitter, speed_jitter)
	_flank_side = -1.0 if randf() < 0.5 else 1.0
	_surge_wait = randf_range(0.5, maxf(surge_every, 0.5))
	_wander_wait = randf_range(0.5, 5.0)
	_storm_left = randf_range(2.0, 4.0)
	_player = get_tree().get_first_node_in_group("player")
	# Разносим таймеры, чтобы сотня врагов не считала путь в один и тот же кадр.
	_repath_left = randf() * path_update_interval
	_sense_left = randf() * 0.3
	_anim_time = randf() * 10.0
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	if rarity > 0:
		_build_rarity_ring()
	if mods.has(&"huge"):
		_visual.scale = Vector3.ONE * 1.2
	_visual_scale = _visual.scale
	health_bar.fit_above_visual(_visual)
	if start_awake:
		_state = State.CHASE


## Уровень этажа: ищем среди родителей узел с zone_level. Усиливаем врага и награду под этот уровень.
func _apply_zone_level() -> void:
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			level = node.zone_level
			break
		node = node.get_parent()
	var extra := level - 1
	max_hp *= health_scale * (1.0 + hp_per_level * extra)
	damage *= 1.0 + damage_per_level * extra
	xp_reward = roundi(xp_reward * (1.0 + 0.35 * extra))
	gold_amount = Vector2i(roundi(gold_amount.x * (1.0 + 0.3 * extra)), roundi(gold_amount.y * (1.0 + 0.3 * extra)))
	# Общие настройки этажа: темп (скорость врагов) и доля опыта (чтобы зачистка ≈ один уровень).
	var zone := _zone()
	if zone != null:
		var life_scale = zone.get("enemy_life_scale")
		if life_scale != null and not guards_exit and rarity == 0:
			max_hp *= life_scale
		move_speed *= zone.get("enemy_speed_scale") if zone.get("enemy_speed_scale") != null else 1.0
		var xp_scale = zone.get("xp_scale")
		if xp_scale != null:
			xp_reward = maxi(1, roundi(xp_reward * xp_scale))


func _zone() -> Node:
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			return node
		node = node.get_parent()
	return null


## Редкость: синие и жёлтые крепче, опаснее и щедрее, у них есть свойства.
func _apply_rarity() -> void:
	if rarity > 0 and mods.is_empty():
		# Число свойств растёт с этажом: на первом жёлтый — с одним, дальше 2–3.
		var count := 1 if rarity == 1 else (1 if level <= 1 else (2 if level <= 3 else randi_range(2, 3)))
		mods = Mods.roll(count, level)
	match rarity:
		1:
			max_hp *= 1.8
			damage *= 1.15
			xp_reward *= 2
			currency_drop_chance *= 2.0
			gear_drop_chance *= 2.5
			gold_drop_chance *= 1.5
			rarity_bonus += 0.25

		2:
			max_hp *= 3.5
			damage *= 1.3
			xp_reward *= 5
			currency_drop_chance = minf(currency_drop_chance * 4.0, 0.9)
			gear_drop_chance = 1.0
			gold_drop_chance = 1.0
			gold_amount *= 3
			module_drop_chance *= 3.0
			rarity_bonus += 0.6
			knockback_resist = maxf(knockback_resist, 0.5)
			_rare_parts = Mods.rare_name()
	for id in mods:
		match id:
			&"swift":
				move_speed *= 1.3
				attack_cooldown *= 0.75
				attack_windup *= 0.85
			&"armored":
				armor = minf(armor + 0.3, 0.8)
			&"huge":
				max_hp *= 1.5
				knockback_resist = maxf(knockback_resist, 0.6)
			&"berserk":
				damage *= 1.4
			&"shocking", &"burning", &"acidic":
				attack_element = {&"shocking": &"electric", &"burning": &"fire", &"acidic": &"acid"}[id]
				if "projectile_element" in self:
					set("projectile_element", attack_element)
					set("projectile_color", Mods.MODS[id]["color"])
			&"regen":
				_regen = 0.03


## Цветное кольцо под ногами: синее или жёлтое — видно, что враг особый.
## Синий/жёлтый враг: обводка цветом редкости (вместо кольца под ногами).
func _build_rarity_ring() -> void:
	_apply_overlay.call_deferred(_status_overlay())


func _old_rarity_ring() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 0.9
	ring.rings = 24
	ring.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Mods.RARITY_COLORS[rarity]
	ring.material = m
	var inst := MeshInstance3D.new()
	inst.mesh = ring
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position.y = 0.05
	inst.scale = Vector3(1, 0.15, 1) * (1.3 if rarity == 2 else 1.0)
	add_child(inst)


## Полное имя с учётом редкости и языка: «Стремительный Ползун», «Гнилоклык».
func get_title() -> String:
	match rarity:
		1:
			return "%s %s" % [Loc.t(Mods.MODS[mods[0]]["name"]), Loc.t(display_name)]
		2:
			if _rare_parts.size() == 2:
				return Loc.t(_rare_parts[0]) + Loc.t(_rare_parts[1])
	return Loc.t(display_name)


## Состояния для полоски цели: горит, шок, кислота.
func status_list() -> Array[StringName]:
	var result: Array[StringName] = []
	if _burn_left > 0.0:
		result.append(&"fire")
	if _shock_left > 0.0:
		result.append(&"electric")
	if _corrode_left > 0.0:
		result.append(&"acid")
	return result


func is_dead() -> bool:
	return _state == State.DEAD


# --- Урон и стихии -------------------------------------------------------------

## Возвращает урон, который реально прошёл (после брони и усилений) — нужен для вампиризма.
func take_damage(amount: float, element := &"physical", _source = null, allow_stagger := true) -> float:
	if _state == State.DEAD:
		return 0.0
	var mult := 1.0
	if _shock_left > 0.0:
		mult *= 1.0 + shock_bonus + _shock_extra
	if element == &"physical" and _corrode_left <= 0.0:
		mult *= 1.0 - armor
	var dealt := amount * mult

	# Сила состояний растёт от пассивок стрелка (ветки стихий): burn_pct, shock_pct, corrode_pct.
	var src_gear = _source.get("_gear") if _source != null and is_instance_valid(_source) and _source is Object else null
	var gear: Dictionary = src_gear if src_gear is Dictionary else {}
	match element:
		&"fire":
			var burn: float = amount * burn_ratio * (1.0 + gear.get(&"burn_pct", 0) / 100.0)
			_burn_dps = maxf(_burn_dps if _burn_left > 0.0 else 0.0, burn)
			_burn_left = burn_time
		&"electric":
			_shock_left = shock_time
			_shock_extra = gear.get(&"shock_pct", 0) / 100.0
		&"acid":
			_corrode_left = corrode_time * (1.0 + gear.get(&"corrode_pct", 0) / 100.0)

	hp -= dealt
	health_bar.set_ratio(hp / max_hp)
	if mark_target and _source != null and is_instance_valid(_source) and _source is Node and _source.is_in_group("player"):
		last_target = self
		last_target_msec = Time.get_ticks_msec()
	if hit_flash:
		_flash()
	if element == &"physical":
		_hit_reaction(amount, _source, allow_stagger)
	_number_accum += dealt
	wake()
	if hp <= 0.0:
		_die()
	return dealt


## Отдача от попадания: отлёт назад, «вздрагивание» тела, брызги из раны.
func _hit_reaction(amount: float, source, allow_stagger := true) -> void:
	var dir := -global_basis.z
	if source != null and is_instance_valid(source) and source is Node3D:
		dir = global_position - source.global_position
		dir.y = 0.0
		dir = dir.normalized()
	_last_hit_dir = dir
	# Сильный удар (больше 15% здоровья) — анимация отшатывания, если враг не замахивается.
	_hit_slow_left = hit_slow_duration * (1.0 - knockback_resist)
	if Time.get_ticks_msec() >= _next_hit_stop:
		_next_hit_stop = Time.get_ticks_msec() + int(hit_stop_cooldown * 1000)
		_hit_anim_left = maxf(_hit_anim_left, hit_stop_duration * (1.0 - knockback_resist))
	if allow_stagger and humanoid_model != null and _state == State.CHASE and amount > max_hp * hit_anim_threshold 			and Time.get_ticks_msec() > _hit_anim_at:
		_hit_anim_at = Time.get_ticks_msec() + int(hit_anim_cooldown * 1000.0)
		var duration := 0.45
		if _model_anim != null and _model_anim.has_animation(anim_hit):
			duration = maxf(duration, _model_anim.get_animation(anim_hit).length)
		_play_once(anim_hit, duration)
		_hit_anim_left = maxf(_hit_anim_left, duration)
		velocity.x = 0.0
		velocity.z = 0.0
	var force := knockback * hit_push * clampf(amount / 10.0, 0.3, 2.0) * (1.0 - knockback_resist)
	var push := Vector2(velocity.x + dir.x * force, velocity.z + dir.z * force).limit_length(max_hit_push_speed)
	velocity.x = push.x
	velocity.z = push.y
	if hit_squash > 0.0:
		if _punch != null and _punch.is_valid():
			_punch.kill()
		var squash := hit_squash * clampf(amount / 10.0, 0.5, 1.5) * (1.0 - knockback_resist * 0.5)
		_punch = create_tween()
		_punch.tween_method(_set_squash.bind(squash), 0.0, 1.0, hit_squash_time)
	Fx.hit(global_position + Vector3.UP * number_height * 0.55 - dir * 0.2, dir, spray_color(blood_color))
	if death_sound != &"explosion" and randf() < blood_on_hit:
		Fx.blood_spray(global_position + Vector3.UP * 0.9, dir, gore_color(blood_color), 1.0)
	if death_sound != &"explosion" and Time.get_ticks_msec() >= _next_hit_gib_at and randf() < hit_gib_chance:
		_next_hit_gib_at = Time.get_ticks_msec() + int(hit_gib_interval * 1000)
		Fx.gibs(global_position + Vector3.UP * 0.6, dir, gore_color(blood_color), gib_flesh_color, 1, 0.4)


## Пружина сплющивания: t от 0 до 1. Сначала тело сплющено, затем чуть вытягивается вверх
## (перелёт на hit_squash_spring) и успокаивается в обычном размере.
func _set_squash(t: float, squash: float) -> void:
	var k := 1.0 - t
	var wave := cos(t * PI * (1.0 + hit_squash_spring * 0.5)) * k * k
	var s := squash * wave
	_visual.scale = _visual_scale * Vector3(1.0 + s, 1.0 - s, 1.0 + s)


func _update_statuses(delta: float) -> void:
	if _burn_left > 0.0:
		_burn_left -= delta
		hp -= _burn_dps * delta
		health_bar.set_ratio(hp / max_hp)
		if hp <= 0.0:
			_die()
			return
	_shock_left = maxf(_shock_left - delta, 0.0)
	_corrode_left = maxf(_corrode_left - delta, 0.0)
	var key := &""
	if _burn_left > 0.0:
		key = &"fire"
	elif _shock_left > 0.0:
		key = &"electric"
	elif _corrode_left > 0.0:
		key = &"acid"
	if key != _overlay_key:
		_overlay_key = key
		if not _flashing:
			_apply_overlay(_status_overlay())


func _status_overlay() -> Material:
	if status_tint and _overlay_key != &"":
		return _overlay(_overlay_key)
	# Синий и жёлтый враг без состояния — светящийся контур цвета редкости.
	return Highlight.material(Mods.RARITY_COLORS[rarity]) if rarity > 0 else null


func _apply_overlay(material: Material) -> void:
	for mesh in _overlay_targets:
		mesh.material_overlay = material


func _flash() -> void:
	if Fx.clean_combat: return  # белая вспышка тела при попадании — тоже самодельная
	_flashing = true
	_apply_overlay(_overlay(&"hit"))
	await get_tree().create_timer(0.07).timeout
	if not is_instance_valid(self):
		return
	_flashing = false
	_apply_overlay(_status_overlay())


static func _overlay(key: StringName) -> Material:
	if _overlays.is_empty():
		var colors := {
			&"hit": Color(1, 1, 1, 0.7),
			&"fire": Color(1.0, 0.45, 0.05, 0.45),
			&"electric": Color(0.35, 0.65, 1.0, 0.45),
			&"acid": Color(0.45, 1.0, 0.2, 0.4),
			&"corpse": Color(0.04, 0.03, 0.03, 0.55),
		}
		for k in colors:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = colors[k]
			_overlays[k] = m
	return _overlays[key]


# --- Поведение -----------------------------------------------------------------

func wake() -> void:
	if _state != State.SLEEP:
		return
	_state = State.CHASE
	if humanoid_model != null and randf() < 0.35:
		Sfx.play(&"zombie_growl", global_position)
	_repath_left = 0.0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and other.has_method("wake") and global_position.distance_to(other.global_position) < wake_radius:
			other.call_deferred("wake")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_update_statuses(delta)
	if _state == State.DEAD:
		return
	# Цифры урона: быстрые попадания складываем в одну цифру (дробовик не сыплет восемь цифр).
	_number_left -= delta
	if _number_accum > 0.0 and _number_left <= 0.0:
		Fx.number(global_position + Vector3.UP * number_height, _number_accum, Color(1, 1, 1), false, _last_hit_dir)
		_number_accum = 0.0
		_number_left = 0.12

	_find_player()
	_sense_left -= delta
	if _sense_left <= 0.0:
		_sees_player = _can_see_player()
		_sense_left = 0.25
		if _state == State.SLEEP:
			# Далёкие спящие проверяют обзор реже — в большой зоне их сотни.
			var far: bool = _player == null or global_position.distance_to(_player.global_position) > aggro_range + 10.0
			_sense_left = 1.0 if far else 0.25
			if _sees_player:
				wake()

	if _regen > 0.0 and hp < max_hp:
		hp = minf(hp + max_hp * _regen * delta, max_hp)
		health_bar.set_ratio(hp / max_hp)
	if mods.has(&"storm") and _state != State.SLEEP:
		_update_storm(delta)

	# Спящий бродит вокруг своего места; далёкий спящий ничего не двигает — экономим физику.
	if _state == State.SLEEP and is_on_floor() and _burn_left <= 0.0:
		var near: bool = _player != null and \
				global_position.distance_squared_to(_player.global_position) < wander_active_range * wander_active_range
		if not near or not _wander(delta):
			if near:
				_animate(delta, 0.0)
			return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _hit_anim_left > 0.0:
		_hit_anim_left = maxf(0.0, _hit_anim_left - delta)
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		_animate(0.0 if _state == State.WINDUP else delta, 0.0)
		return


	var to_player := Vector3.ZERO
	var distance := INF
	if _player != null:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		distance = to_player.length()

	var result := _think(delta, to_player, distance)
	var desired: Vector3 = result[0]
	var face_dir: Vector3 = result[1]
	if _state == State.SLEEP:
		desired = _wander_velocity
		face_dir = desired
	if _corrode_left > 0.0:
		desired *= 1.0 - corrode_slow
	_hit_slow_left = maxf(0.0, _hit_slow_left - delta)
	if _hit_slow_left > 0.0:
		desired *= 1.0 - hit_slow_ratio

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _state != State.RECOVER or horizontal.length() < 0.5:
		horizontal = horizontal.move_toward(desired, acceleration * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, acceleration * 0.5 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if face_dir.length() > 0.1:
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	_animate(delta, horizontal.length())


## Решает, куда двигаться и куда смотреть. Возвращает [желаемая скорость, направление взгляда].
## Здесь — ближний бой: догнать, замахнуться, ударить. Стрелки переопределяют.
func _think(delta: float, to_player: Vector3, distance: float) -> Array:
	var desired := Vector3.ZERO
	var face_dir := Vector3.ZERO
	match _state:
		State.CHASE:
			if not _player_targetable():
				pass
			elif distance < attack_range:
				_state = State.WINDUP
				_timer = attack_windup
				_attack_direction = to_player.normalized()
				_melee_pending = true
				_on_windup()
			else:
				desired = _approach(_chase_direction(delta, to_player, distance), distance, delta) * move_speed
				face_dir = desired
		State.WINDUP:
			face_dir = _attack_direction
			_timer -= delta
			# У модели момент контакта является единственным источником урона.
			if _timer <= 0.0 and (_model_anim == null or not _model_anim.has_animation(anim_attack)):
				_resolve_melee()
		State.RECOVER:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.CHASE
	return [desired, face_dir]


## Медленно бродит к случайной точке рядом с домом, потом стоит несколько секунд.
## Возвращает true, пока идёт (нужна физика).
func _wander(delta: float) -> bool:
	if not _wandering:
		_wander_velocity = Vector3.ZERO
		_wander_wait -= delta
		if _wander_wait > 0.0:
			return Vector2(velocity.x, velocity.z).length() > 0.05
		var angle := randf() * TAU
		_wander_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.0, wander_radius)
		_wander_left = 5.0
		_wandering = true
	var to := _wander_target - global_position
	to.y = 0.0
	_wander_left -= delta
	if to.length() < 0.4 or _wander_left <= 0.0:
		_wandering = false
		_wander_wait = randf_range(2.0, 6.0)
		_wander_velocity = Vector3.ZERO
		return true
	_wander_velocity = to.normalized() * move_speed * wander_speed_ratio
	return true


## Свойство «Грозовой»: раз в несколько секунд под игроком загорается круг, через секунду бьёт молния.
func _update_storm(delta: float) -> void:
	_storm_left -= delta
	if _storm_left > 0.0 or not _player_targetable():
		return
	_storm_left = randf_range(3.5, 5.0)
	if global_position.distance_to(_player.global_position) > 16.0:
		return
	_delayed_blast(_player.global_position, 2.0, damage * 1.3, &"electric", Color(0.5, 0.7, 1.0), 1.0)


## Отложенный удар по области: сначала круг-предупреждение, потом вспышка и урон, если игрок внутри.
func _delayed_blast(at: Vector3, radius: float, amount: float, element: StringName, color: Color, delay: float, allow_after_death := false) -> void:
	var parent := get_parent()
	var player = _player
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(at.x, at.y + 0.06, at.z)
	# Мягкое пятно на полу (наполняется к удару).
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.4, radius * 2.4)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = preload("res://assets/vfx/circle_05.png")
	gm.albedo_color = Color(color, 0.15)
	quad.material = gm
	glow.mesh = quad
	glow.rotation.x = -PI / 2
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	# Граница — тонкое кольцо, и второе кольцо сжимается к центру: когда сойдутся — удар.
	var edge := _blast_ring(radius, color, 0.9)
	root.add_child(edge)
	var closing := _blast_ring(radius, color, 0.7)
	root.add_child(closing)
	var tween := root.create_tween().set_parallel()
	tween.tween_property(closing, "scale", Vector3(0.05, 1, 0.05), delay).from(Vector3.ONE)
	tween.tween_property(gm, "albedo_color:a", 0.55, delay)
	tween.chain().tween_callback(func() -> void:
		if is_dead() and not allow_after_death:
			root.queue_free()
			return
		var pos := root.global_position
		if element == &"electric":
			Sfx.play(&"zap", pos)
			Fx.flipbook(&"spark", pos + Vector3.UP * 0.5, radius * 2.6, 0.3, color)
			_lightning_strike(pos, color)
		else:
			Sfx.play(&"explosion", pos)
			Fx.flipbook(&"explosion", pos + Vector3.UP * radius * 0.4, radius * 1.9, 0.9, color.lightened(0.3))
		Fx.hit(pos + Vector3.UP * 0.3, Vector3.UP, color, 16)
		Fx.shake(0.15)
		if player != null and is_instance_valid(player) and not player.is_dead():
			var flat: Vector3 = player.global_position - pos
			flat.y = 0.0
			if flat.length() <= radius:
				player.take_damage(amount, element, self)
		edge.visible = false
		closing.visible = false)
	tween.chain().tween_property(gm, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(root.queue_free)


func _blast_ring(radius: float, color: Color, alpha: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.06
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lightened(0.2), alpha)
	torus.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 0.05, 1)
	return mi


## Молния с неба: яркий столб на долю секунды и вспышка света.
func _lightning_strike(pos: Vector3, color: Color) -> void:
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 9.0, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lightened(0.5), 1.0)
	box.material = m
	bolt.mesh = box
	get_parent().add_child(bolt)
	bolt.global_position = pos + Vector3.UP * 4.5
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 7.0
	bolt.add_child(light)
	light.position.y = -4.0
	var tw := bolt.create_tween().set_parallel()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_property(light, "light_energy", 0.0, 0.25).from(5.0)
	tw.chain().tween_callback(bolt.queue_free)


## Живее, чем «магнит»: заход с фланга на расстоянии и рывки полубегом. Возвращает направление × множитель.
func _approach(dir: Vector3, distance: float, delta: float) -> Vector3:
	var mult := 1.0
	if surge_every > 0.0:
		if _surge_left > 0.0:
			_surge_left -= delta
			mult = surge_mult
		else:
			_surge_wait -= delta
			if _surge_wait <= 0.0:
				_surge_left = surge_time
				_surge_wait = surge_every * randf_range(0.7, 1.3)
	if flank > 0.0 and distance > 3.0:
		var side := dir.cross(Vector3.UP) * _flank_side
		var k := flank * clampf((distance - 3.0) / 7.0, 0.0, 1.0)
		dir = (dir + side * k).normalized()
	return dir * mult


## Игрок жив и не в безопасной комнате.
func _player_targetable() -> bool:
	return _player != null and not _player.is_dead() and not _player.is_safe()


## Если игрок виден и недалеко — бежим прямо, иначе по пути, который обходит стены.
func _chase_direction(delta: float, to_player: Vector3, distance: float) -> Vector3:
	if _sees_player and distance < 10.0:
		return to_player / distance
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = path_update_interval
		var map := get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, global_position, _player.global_position, true)
		_path_index = 1
	while _path_index < _path.size():
		var to_point := _path[_path_index] - global_position
		to_point.y = 0.0
		if to_point.length() > 0.6:
			return to_point.normalized()
		_path_index += 1
	return to_player / maxf(distance, 0.01)


func _can_see_player() -> bool:
	if _player == null or _player.is_safe():
		return false
	var target: Vector3 = _player.global_position + Vector3.UP
	if _state == State.SLEEP and global_position.distance_to(target) > aggro_range:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, target, LOS_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Ближняя атака: рывок вперёд и урон, если игрок не успел отойти.
func _attack(to_player: Vector3, distance: float) -> void:
	var dir := _attack_direction
	velocity.x = dir.x * lunge_speed
	velocity.z = dir.z * lunge_speed
	Sfx.play(attack_sound, global_position)
	_on_attack()
	if not is_instance_valid(_player) or distance > attack_reach:
		return
	var facing := -global_basis.z
	var in_arc := distance < 0.1 or facing.dot(to_player.normalized()) >= cos(deg_to_rad(attack_arc_degrees * 0.5))
	if in_arc and _player.has_method("take_damage"):
		_player.take_damage(damage, attack_element, self)


func _resolve_melee() -> void:
	if not _melee_pending or _state != State.WINDUP:
		return
	_melee_pending = false
	_state = State.RECOVER
	_timer = attack_cooldown
	if not is_instance_valid(_player):
		return
	var to: Vector3 = _player.global_position - global_position
	to.y = 0
	_attack(to, to.length())


## Игрока ищем заново, если его ещё нет: этаж, загруженный через портал, появляется в сцене раньше,
## чем туда переносят игрока, — без этого враги стояли бы «без цели» и не давали опыт.
func _find_player() -> void:
	_taunt_left -= get_physics_process_delta_time()
	if _taunt_left <= 0.0:
		_taunt_left = 0.5
		_player = _hero()
		# Робот-союзник с провокацией перетягивает на себя врагов рядом с ним.
		for a in get_tree().get_nodes_in_group("taunting"):
			if a is Node3D and a.has_method("is_dead") and not a.is_dead() and a.global_position.distance_to(global_position) < a.taunt_radius:
				_player = a
				break
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = _hero()


func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _die() -> void:
	_player = _hero()
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_melee_pending = false
	remove_from_group("enemies")
	if guards_exit:
		remove_from_group("bosses")
		if _player != null and _player.has_method("show_message"):
			_player.show_message(Loc.t("%s повержен! Лифт открыт.") % get_title(), 3.5)
	collision_layer = 0
	collision_mask = 0
	if _player != null and _player.has_method("add_flask_charge"):
		_player.add_flask_charge(flask_charge_reward)
		_player.add_xp(xp_reward, level)
	if _number_accum > 0.0:
		Fx.number(global_position + Vector3.UP * number_height, _number_accum, Color(1.0, 0.85, 0.4), true, _last_hit_dir)
	Fx.shake(death_shake)
	var explosion := EXPLOSION.instantiate()
	# Зомби (человекоподобная модель) стонут по-своему, остальные — своим звуком смерти.
	explosion.sound = &"zombie_death" if humanoid_model != null and death_sound == &"crawler_death" else death_sound
	explosion.scale = Vector3.ONE * death_effect_scale
	get_parent().add_child(explosion)
	explosion.global_position = global_position + Vector3.UP * 0.5 * death_effect_scale
	if death_sound == &"explosion":
		# Робот взрывается огненным шаром, живой — брызгами крови.
		Fx.flipbook(&"explosion", global_position + Vector3.UP * 0.8 * death_effect_scale, 2.2 * death_effect_scale, 1.1)
		# Робот: обломки корпуса.
		Fx.gibs(global_position, _last_hit_dir, Color(0.25, 0.26, 0.28), Color(0.5, 0.42, 0.3),
				roundi(gib_count * 1.3), death_effect_scale * 0.9)
	else:
		Fx.flipbook(&"blood", global_position + Vector3.UP * 0.7, 1.4 * death_effect_scale, 0.6,
				Color(spray_color(blood_color), 0.8), false, true)
		Fx.gibs(global_position, _last_hit_dir, gore_color(blood_color), gib_flesh_color, gib_count,
				death_effect_scale * 0.8)
	if humanoid_model != null:
		Sfx.play(&"gore_splat", global_position, -4.0)
	if death_sound != &"explosion":
		Fx.blood_spray(global_position + Vector3.UP * 0.9, _last_hit_dir, gore_color(blood_color), death_blood_scale * death_effect_scale)
	_leave_corpse()
	_drop_loot()
	if rarity == 2:
		_drop_loot()  # жёлтый — двойная добыча
	if mods.has(&"volatile"):
		_delayed_blast(global_position, 3.0, damage * 2.0, &"fire", Color(1.0, 0.5, 0.15), 1.2, true)
	if death_spawn_scene != null:
		for i in death_spawn_count:
			var child: Node3D = death_spawn_scene.instantiate()
			child.set("start_awake", true)
			get_parent().call_deferred("add_child", child)
			var offset := Vector3(randf_range(-1, 1), 0.1, randf_range(-1, 1))
			child.set_deferred("global_position", global_position + offset)
	died.emit()
	queue_free()


## Добитый колом отлетает назад по линии выстрела; стена на пути — пригвождён к ней.
func _fly_back(corpse: Node3D, body: Node3D) -> void:
	var from := corpse.global_position + Vector3.UP * 1.0
	var to := from + impale_push
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var travel := impale_push
	var pinned := not hit.is_empty()
	if pinned:
		travel = (hit.position - from) - impale_push.normalized() * 0.45
	var fly := corpse.create_tween()
	fly.tween_property(corpse, "global_position", corpse.global_position + travel, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Короткий подскок: тело отрывает от земли.
	var hop := body.create_tween()
	hop.tween_property(body, "position:y", body.position.y + 0.45, 0.14).set_ease(Tween.EASE_OUT)
	if not pinned:
		hop.tween_property(body, "position:y", body.position.y, 0.2).set_ease(Tween.EASE_IN)
	else:
		Fx.shake(0.12)
		Sfx.play(&"bow_impact", corpse.global_position + travel)


## Труп и лужа крови: модель врага остаётся лежать на полу (потемневшая, без анимации).
func _leave_corpse() -> void:
	var level := get_parent()
	if level == null or not level.is_inside_tree():
		return
	var corpse := Node3D.new()
	level.add_child(corpse)
	corpse.global_position = Vector3(global_position.x, 0.0, global_position.z)
	# Кровь: неровное пятно с брызгами (наклейка на пол), цвет тёмный и приглушённый. У роботов — масло.
	var robot := death_sound == &"explosion"
	var ground := gore_color(blood_color, robot)
	for i in (0 if Fx.clean_combat else corpse_blood_patches):
		var d := Decal.new()
		d.texture_albedo = splat_texture(i % SPLATS)
		d.modulate = ground
		d.cull_mask = 1
		var big := i == 0
		var r := randf_range(1.6, 2.4) if big else randf_range(0.5, 1.0)
		d.size = Vector3(r * 1.6, 0.3, r * 1.6) * (1.2 if mods.has(&"huge") else 1.0)
		d.rotation.y = randf() * TAU
		var off := Vector3.ZERO if big else Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) \
				+ _last_hit_dir * randf_range(0.4, 1.0)
		d.position = off + Vector3(0, 0.05, 0)
		corpse.add_child(d)
		# Растекается за полсекунды.
		var full := d.size
		d.size = Vector3(full.x * 0.3, full.y, full.z * 0.3)
		d.create_tween().tween_property(d, "size", full, 0.5).set_ease(Tween.EASE_OUT)
	# Тело: переносим вид врага в труп, кладём набок, затемняем, останавливаем анимацию.
	if _punch != null and _punch.is_valid():
		_punch.kill()
	_visual.scale = _visual_scale
	var body := _visual
	var t := body.global_transform
	remove_child(body)
	corpse.add_child(body)
	body.global_transform = t
	body.scale = Vector3.ONE * (1.2 if mods.has(&"huge") else 1.0)
	body.position.y = -0.05
	var death_clip: Animation = _model_anim.get_animation(anim_death) if _model_anim != null and _model_anim.has_animation(anim_death) else null
	# Если перенос смерти на конкретный вариант ползуна не нашёл кости, клип
	# существует, но пустой — оставлять такую модель стоять в T-позе нельзя.
	var ragdolled := false
	if ragdoll_on_death and humanoid_model != null:
		body.position.y = 0.0
		# Толчок: добивающий кол — сильно по линии выстрела, обычная смерть — слегка от попадания.
		var push := impale_push * ragdoll_stake_force if impale_push.length() > 0.1 else _last_hit_dir * ragdoll_hit_force
		ragdolled = Ragdoll.start(body.find_child("Skeleton3D", true, false) as Skeleton3D, push + Vector3.UP * ragdoll_lift, _model_anim)
	if ragdolled:
		pass
	elif humanoid_model != null and death_clip != null and death_clip.get_track_count() >= 6:
		body.position.y = 0.0
		_model_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		_model_anim.speed_scale = 1.0
		_model_anim.play(anim_death, 0.1)
	else:
		for child in body.get_children():
			if child is Node3D and child.position.y > 0.8:
				child.position.y = 0.3  # дрон падает на пол
		body.rotate_object_local(Vector3.FORWARD, deg_to_rad(randf_range(70.0, 95.0) * (1.0 if randf() < 0.5 else -1.0)))
		if _model_anim != null:
			_model_anim.pause()
	if impale_push.length() > 0.1 and not ragdolled:
		_fly_back(corpse, body)
	var dark := _overlay(&"corpse")
	for mesh in _overlay_targets:
		if is_instance_valid(mesh):
			mesh.material_overlay = dark
	_corpses.append(corpse)
	_corpses = _corpses.filter(func(c): return is_instance_valid(c))
	while _corpses.size() > max_corpses:
		var old: Node3D = _corpses.pop_front()
		old.queue_free()


## Цвет крови на полу: темнее и тусклее цвета брызг, чтобы не «кислотная лужа». Робот — тёмное масло.
static func gore_color(c: Color, robot := false) -> Color:
	if robot:
		return Color(0.05, 0.045, 0.04, 0.8)
	return Color(Color(0.32, 0.025, 0.018).lerp(c.darkened(0.65), 0.15), 0.92)


## Цвет брызг и клубов: тёмно-красный с лёгким оттенком «своей» крови врага.
static func spray_color(c: Color) -> Color:
	return Color(0.42, 0.05, 0.04).lerp(c.darkened(0.3), 0.3)


const SPLATS := 3
static var _splats: Array[Texture2D] = []


## Пятно крови: клякса из кругов + капли вокруг, мягкий край (делается один раз при запуске).
static func splat_texture(index: int) -> Texture2D:
	if _splats.is_empty():
		for k in SPLATS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1234 + k * 77
			var n := 128
			var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
			var blobs := []
			for j in 9:
				var a := rng.randf() * TAU
				var dist := rng.randf_range(0.0, 0.22) * n
				blobs.append([Vector2(n * 0.5, n * 0.5) + Vector2(cos(a), sin(a)) * dist, rng.randf_range(0.12, 0.24) * n])
			for j in 14:
				var a := rng.randf() * TAU
				var dist := rng.randf_range(0.3, 0.46) * n
				blobs.append([Vector2(n * 0.5, n * 0.5) + Vector2(cos(a), sin(a)) * dist, rng.randf_range(0.015, 0.045) * n])
			for y in n:
				for x in n:
					var v := 0.0
					for bl in blobs:
						var dd: float = Vector2(x, y).distance_to(bl[0]) / bl[1]
						v = maxf(v, clampf((1.0 - dd) * 4.0, 0.0, 1.0))
					# Чуть светлее к краю — «высохший» ободок, темнее в центре.
					img.set_pixel(x, y, Color(1, 1, 1, v))
			_splats.append(ImageTexture.create_from_image(img))
	return _splats[index % _splats.size()]


func _drop_loot() -> void:
	if not drops_enabled:
		return
	var parent := get_parent()
	var mult := Game.loot_mult()
	var density_scale := 1.0
	var zone := _zone()
	if zone != null and zone.get("ordinary_loot_scale") != null and rarity == 0 and not guards_exit:
		density_scale = zone.ordinary_loot_scale
	mult *= density_scale
	# Модули — редкость: только с жёлтых врагов (и боссов — boss.gd). На этаж выходит 1–2.
	if rarity == 2 and randf() < 0.12 * mult / 0.3:
		LOOT.drop(parent, global_position, &"currency", &"blank_module")
	if randf() < currency_drop_chance * mult:
		LOOT.drop(parent, global_position, &"currency", LOOT.ItemDB.random_currency(level))
	# Золото — реже и меньше (экономика: вещи у торговцев должны быть дорогими).
	if randf() < gold_drop_chance * 0.45 * density_scale:
		LOOT.drop(parent, global_position, &"gold", maxi(1, roundi(randi_range(gold_amount.x, gold_amount.y) * 0.5)))
	if randf() < gear_drop_chance * mult:
		LOOT.drop(parent, global_position, &"gear", GearItem.random_drop(level, rarity_bonus))


# --- Для конкретных врагов -------------------------------------------------------

## Собрать внешний вид в _visual. Меши, которые должны мигать, добавить в _overlay_targets.
## По умолчанию — готовая модель (если задана).
func _build_visual() -> void:
	if model != null:
		_build_model()
	elif humanoid_model != null:
		_build_humanoid()


## Человеческая модель: «костюм» заражённого, общая библиотека анимаций, анимация — вручную (только у
## ближних и активных врагов: далёкие спящие стоят и не тратят время процессора).
func _build_humanoid() -> void:
	var choices: Array[PackedScene] = []
	for variant in humanoid_variants:
		if variant != null:
			choices.append(variant)
	if choices.is_empty():
		if humanoid_model != null:
			choices.append(humanoid_model)
		if humanoid_alt != null:
			choices.append(humanoid_alt)
	var scene: PackedScene = choices.pick_random() if choices.size() > 1 else choices[0]
	var inst: Node3D = scene.instantiate()
	_visual.add_child(inst)
	inst.scale = humanoid_scale
	inst.rotation.y = deg_to_rad(model_yaw)
	var fitting := outfits.filter(func(o: PackedScene) -> bool: return o != null and Outfit.fits(scene, o))
	if inst.has_meta("native_creature"):
		fitting.clear()
	var dressed := not fitting.is_empty() and randf() < outfit_chance
	Suit.apply(inst, skin_accent, skin_plate, skin_tint, skin_cloth, dressed)
	var hooded := false
	if dressed:
		var outfit: PackedScene = fitting.pick_random()
		Outfit.attach(inst, outfit, outfit_tint, skin_tint)
		hooded = outfit.resource_path.contains("Ranger")  # капюшон — без причёски
	if not inst.has_meta("native_creature") and not hooded and not hair_styles.is_empty() and randf() < 0.75:
		Hair.attach(inst, hair_styles.pick_random(), hair_tint)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		_overlay_targets.append(m)
	var skeleton: Skeleton3D = inst.get_node("Armature/Skeleton3D")
	var used: Array = [anim_idle, anim_walk, anim_run, anim_attack, anim_death, anim_hit]
	used.append_array(extra_anims)
	var key := scene.resource_path + "|" + "|".join(used)
	if not _libraries.has(key):
		var once: Array = [anim_attack, anim_death, anim_hit]
		once.append_array(extra_anims)
		if inst.has_meta("animation_library_path"):
			_libraries[key] = load(inst.get_meta("animation_library_path")) as AnimationLibrary
		elif animation_profile != "" or inst.has_meta("animation_profile"):
			var profile := animation_profile if animation_profile != "" else String(inst.get_meta("animation_profile"))
			_libraries[key] = EnemyAnimationProfiles.build(skeleton, profile)
		else:
			_libraries[key] = Animator.fit_library(skeleton, used, once)
	var library := _libraries[key] as AnimationLibrary
	if library == null:
		library = AnimationLibrary.new()
	_repair_humanoid_animations(library, skeleton)
	_libraries[key] = library
	_model_anim = AnimationPlayer.new()
	inst.add_child(_model_anim)
	_model_anim.root_node = NodePath("..")
	_model_anim.add_animation_library(&"", _libraries[key])
	_model_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_model_anim.play(anim_idle)
	_model_anim.seek(randf() * 1.5, true)


## Некоторые скачанные модели не совпадают со скелетом клипа и получают пустую анимацию.
## Подменяем только такие клипы обычными движениями UAL, чтобы враг не оставался в T-позе.
func _repair_humanoid_animations(library: AnimationLibrary, skeleton: Skeleton3D) -> void:
	var fallbacks := [
		[anim_idle, &"Idle", false], [anim_walk, &"Walk", false], [anim_run, &"Jog_Fwd", false],
		[anim_attack, &"Punch_Cross", true], [anim_death, &"Death01", true], [anim_hit, &"Hit_Chest", true],
	]
	for row in fallbacks:
		var requested: StringName = row[0]
		var source: StringName = row[1]
		if requested == &"":
			continue
		if library.has_animation(requested) and library.get_animation(requested).get_track_count() >= 6:
			continue
		var fitted := Animator.fit_library(skeleton, [source], [source] if row[2] else [])
		var replacement := fitted.get_animation(source).duplicate(true) as Animation
		if library.has_animation(requested):
			library.remove_animation(requested)
		library.add_animation(requested, replacement)


## Анимация каждый кадр (speed — текущая скорость).
func _animate(delta: float, speed: float) -> void:
	if _model_anim != null:
		_animate_model(delta, speed)


## Начало замаха (визуальная подсказка игроку).
func _on_windup() -> void:
	if _model_anim != null:
		_play_attack_at_contact(attack_windup)
		return
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.15, 0.75, 0.85), attack_windup * 0.8)


## Момент удара (визуал).
func _on_attack() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(0.9, 1.08, 1.15), 0.06)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.2)


# --- Готовая модель ---------------------------------------------------------------

func _build_model() -> void:
	var inst: Node3D = model.instantiate()
	_visual.add_child(inst)
	inst.scale = Vector3.ONE * model_scale
	inst.position = model_offset
	inst.rotation.y = deg_to_rad(model_yaw)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		_overlay_targets.append(m)
	_model_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _model_anim != null:
		for loop_name in [anim_idle, anim_walk, anim_run]:
			if _model_anim.has_animation(loop_name):
				_model_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		_model_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_model_anim.play(anim_idle)
		_model_anim.seek(randf() * 1.0, true)


func _animate_model(delta: float, speed: float) -> void:
	if _model_anim.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		_model_anim.advance(delta)
	if _melee_pending and _state == State.WINDUP and _model_anim.current_animation == anim_attack:
		var contact := _model_anim.get_animation(anim_attack).length * attack_contact_fraction
		if _model_anim.current_animation_position >= contact:
			_resolve_melee()
	_anim_lock -= delta
	if _anim_lock > 0.0:
		return
	var want := anim_idle
	if speed > run_threshold and _model_anim.has_animation(anim_run):
		want = anim_run
	elif speed > 0.4 and _model_anim.has_animation(anim_walk):
		want = anim_walk
	if _model_anim.current_animation != want:
		_model_anim.play(want, 0.15)
	var natural := anim_run_speed if want == anim_run else anim_walk_speed
	if want != anim_idle and natural > 0.0:
		_model_anim.speed_scale = clampf(speed / natural, 0.4, 2.2)
	elif want != anim_idle:
		_model_anim.speed_scale = clampf(speed / maxf(move_speed * 0.8, 0.1), 0.6, 1.6)
	else:
		_model_anim.speed_scale = 1.0


## Проиграть анимацию один раз (атака) и на это время не перебивать её ходьбой.
func _play_once(anim: StringName, duration: float) -> void:
	if _model_anim == null or not _model_anim.has_animation(anim):
		return
	_model_anim.speed_scale = 1.0
	_model_anim.play(anim, 0.08)
	_anim_lock = duration


## Вспомогательное: меш в _visual. overlay — участвует ли во вспышке/цвете состояния.
func _mesh(mesh: Mesh, pos: Vector3, scale_ := Vector3.ONE, parent: Node3D = null, overlay := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.scale = scale_
	(parent if parent != null else _visual).add_child(m)
	if overlay:
		_overlay_targets.append(m)
	return m


static func _material(color: Color, emission := 0.0, roughness := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## Одна шкала времени для замаха и визуального контакта.
func _play_attack_at_contact(windup: float) -> void:
	if _model_anim == null or not _model_anim.has_animation(anim_attack):
		return
	var length := _model_anim.get_animation(anim_attack).length
	var rate := length * attack_contact_fraction / maxf(windup, 0.05)
	_play_once(anim_attack, length / maxf(rate, 0.01))
	_model_anim.seek(0.0, true)
	_model_anim.speed_scale = rate
