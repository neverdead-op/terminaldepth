extends "res://scripts/enemy.gd"
## Босс этажа: охраняет лифт (лифт не работает, пока босс жив — группа «bosses»).
## Умения: ближний удар (из Enemy), удар по площади вокруг себя (круг-предупреждение), кольцо снарядов,
## призыв подмоги на 2/3 и 1/3 здоровья, ярость при малом здоровье. Полоска сверху — всегда, пока он рядом.
## Вид — любая модель Enemy (человек или робот); числа и умения — в сцене (scenes/boss_*.tscn).

const PROJECTILE := preload("res://scripts/enemy_projectile.gd")

## Имя босса (в полоске сверху).
@export var boss_title := "Босс"

@export_group("Удар по площади")
@export var slam_every := 6.5
@export var slam_windup := 1.1
@export var slam_recovery := 0.65
@export var slam_radius := 4.5
@export var slam_damage_mult := 1.6
@export var slam_element := &"physical"
@export var slam_color := Color(1.0, 0.45, 0.2)

@export_group("Кольцо снарядов")
@export var nova_every := 8.0
@export var nova_count := 14
@export var nova_damage_mult := 0.6
@export var nova_speed := 11.0
@export var nova_element := &"acid"
@export var nova_color := Color(0.45, 1.0, 0.15)

@export_group("Подмога и ярость")
@export var summon_scene: PackedScene
@export var summon_count := 5
## Ярость: ниже этой доли здоровья — быстрее и чаще умения.
@export_range(0.0, 1.0) var enrage_below := 0.3
@export var enrage_speed := 1.35

var _slam_left := 4.0
var _nova_left := 6.0
var _summons_done := 0
var _enraged := false


func _ready() -> void:
	guards_exit = true
	super()
	add_to_group("bosses")
	rarity = 2
	wander_radius = 0.0


func get_title() -> String:
	return Loc.t(boss_title)


func _physics_process(delta: float) -> void:
	super(delta)
	if _state == State.DEAD or _state == State.SLEEP:
		return
	# Полоска босса сверху — всё время боя, пока игрок рядом.
	if _player != null and global_position.distance_to(_player.global_position) < 35.0:
		last_target = self
		last_target_msec = Time.get_ticks_msec()
	if not _player_targetable():
		return
	var pace := 1.5 if _enraged else 1.0
	_slam_left -= delta * pace
	_nova_left -= delta * pace
	if _slam_left <= 0.0 and _state == State.CHASE:
		_slam_left = slam_every
		_start_slam()
	if _nova_left <= 0.0 and nova_count > 0:
		_nova_left = nova_every
		_nova()
	var ratio := hp / max_hp
	if summon_scene != null and _summons_done < 2 and ratio < (2.0 - _summons_done) / 3.0:
		_summons_done += 1
		_summon()
	if not _enraged and ratio < enrage_below:
		_enraged = true
		move_speed *= enrage_speed
		attack_cooldown *= 0.7
		Fx.shake(0.4)
		Sfx.play(&"brute_slam", global_position)


## Кольцо снарядов во все стороны.
func _nova() -> void:
	var origin := global_position + Vector3.UP * 1.2
	for i in nova_count:
		var a := TAU * i / nova_count + randf() * 0.2
		var dir := Vector3(cos(a), 0.0, sin(a))
		PROJECTILE.spawn(get_parent(), origin + dir * 1.2, origin + dir * 10.0, nova_speed, damage * nova_damage_mult,
				nova_element, nova_color)
	Sfx.play(&"spit", global_position)


## Подмога: несколько врагов вокруг, сразу бодрствуют.
func wake() -> void:
	if _state == State.SLEEP:
		Sfx.play(&"boss_roar", global_position)
		Fx.shake(0.35)
	super()


func _summon() -> void:
	for i in summon_count:
		var child: Node3D = summon_scene.instantiate()
		child.set("start_awake", true)
		get_parent().add_child(child)
		var a := TAU * i / summon_count
		child.global_position = global_position + Vector3(cos(a), 0.1, sin(a)) * 3.0
	Fx.shake(0.3)
	Sfx.play(&"brute_slam", global_position)


func _die() -> void:
	if _state == State.DEAD:
		return
	remove_from_group("bosses")
	Sfx.play(&"explosion_big", global_position)
	# Добыча босса: модуль (первый модуль игра даёт именно здесь), фрагмент, жёлтая вещь, шанс уникального.
	_drop_loot()
	var parent := get_parent()
	LOOT.drop(parent, global_position, &"currency", &"blank_module")
	if randf() < 0.2:
		var level_value := level
		var u := LOOT.ItemDB.random_unique(level_value)
		if not u.is_empty():
			LOOT.drop(parent, global_position, &"gear", GearItem.create_unique(u, level_value))
	LOOT.drop(parent, global_position, &"gear", GearItem.create(LOOT.ItemDB.random_base(&"", level), level, 2))
	if _player != null and _player.has_method("show_message"):
		_player.show_message(Loc.t("%s повержен! Лифт открыт.") % get_title(), 3.5)
	super()

func _start_slam() -> void:
	_melee_pending = false
	_state = State.RECOVER
	_timer = slam_windup + slam_recovery
	velocity.x = 0
	velocity.z = 0
	_delayed_blast(global_position, slam_radius, damage * slam_damage_mult, slam_element, slam_color, slam_windup)
	_play_attack_at_contact(slam_windup)
