extends "res://scripts/enemy.gd"
## Прыгун: с расстояния 4–10 м присаживается, под игроком загорается круг — и через миг прыгает туда.
## Кто не откатился из круга, получает удар. Вблизи бьёт обычно. Учит пользоваться перекатом.

@export_group("Прыжок")
@export var leap_min := 4.0
@export var leap_max := 10.0
## Подготовка (присед) и полёт, сек.
@export var leap_windup := 0.7
@export var leap_time := 0.45
@export var leap_cooldown := 3.5
@export var leap_radius := 1.7
@export var leap_damage_mult := 1.6
@export var leap_height := 1.4

var _leap_cd := 1.0
var _leap_prep := 0.0
var _leap_left := 0.0
var _leap_target := Vector3.ZERO
var _leap_from := Vector3.ZERO


func _think(delta: float, to_player: Vector3, distance: float) -> Array:
	_leap_cd -= delta
	if _leap_left > 0.0:
		_leap_left -= delta
		var t := 1.0 - _leap_left / leap_time
		_visual.position.y = sin(clampf(t, 0.0, 1.0) * PI) * leap_height
		var flat := _leap_target - _leap_from
		flat.y = 0.0
		var v := flat / leap_time
		velocity.x = v.x
		velocity.z = v.z
		if _leap_left <= 0.0:
			_visual.position.y = 0.0
			_play_once(&"Jump_Land", 0.35)
			Fx.shake(0.12)
			_state = State.RECOVER
			_timer = 0.6
		return [Vector3(v.x, 0, v.z), v]
	if _leap_prep > 0.0:
		_leap_prep -= delta
		if _leap_prep <= 0.0:
			_leap_left = leap_time
			_leap_from = global_position
			Sfx.play(&"dodge", global_position)
		return [Vector3.ZERO, _leap_target - global_position]
	if _state == State.CHASE and _player_targetable() and _sees_player and _leap_cd <= 0.0 \
			and distance > leap_min and distance < leap_max:
		_leap_cd = leap_cooldown * randf_range(0.8, 1.2)
		_leap_prep = leap_windup
		_leap_target = _player.global_position
		_play_once(&"Jump_Start", leap_windup + 0.2)
		Sfx.play(&"zombie_attack", global_position)
		# Круг-предупреждение; урон — в момент приземления.
		_delayed_blast(_leap_target, leap_radius, damage * leap_damage_mult, attack_element, Color(1.0, 0.3, 0.2),
				leap_windup + leap_time)
		return [Vector3.ZERO, to_player]
	return super(delta, to_player, distance)
