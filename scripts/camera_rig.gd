extends Node3D
## Камера сверху под углом, плавно следует за игроком.

@export var target_path: NodePath
## Где камера относительно игрока: выше (y) и чуть позади (z).
@export var offset := Vector3(0.0, 15.0, 9.0)
## Отключите, если хотите задавать старый offset вручную.
@export var use_distance_angle := true
## Как в PoE 2: камера ниже и дальше, объектив уже (меньше перспективных искажений).
@export var distance := 19.0
## Угол над горизонтом: меньше — камера ниже и сильнее видны боковые стороны.
@export_range(25.0, 80.0) var elevation_degrees := 45.0
## Угол обзора объектива (°). 0 — оставить тот, что задан у Camera3D в сцене.
@export_range(0.0, 90.0) var fov_degrees := 38.0

func _camera_offset() -> Vector3:
	if not use_distance_angle:
		return offset
	var angle := deg_to_rad(elevation_degrees)
	return Vector3(0, sin(angle), cos(angle)) * distance

@export var follow_speed := 8.0
## Временно отключены толчки от шагов, выстрелов и попаданий.
@export var camera_impulses_enabled := false
## Как быстро камера возвращается на место после толчка (шаг, взрыв).
@export var shake_recovery := 0.6

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
var _dip := 0.0
var _trauma := 0.0
## Насколько далеко камеру уводит при самой сильной тряске (м) и как быстро тряска затихает.
@export var shake_max_offset := 0.45
@export var shake_decay := 2.2


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null
	if _target:
		global_position = _target.global_position
	if fov_degrees > 0.0:
		camera.fov = fov_degrees
	camera.position = _camera_offset()
	camera.look_at(global_position, Vector3.UP)


## Короткий толчок камеры вниз — даёт ощущение веса (шаги, отдача, взрывы).
func add_dip(amount: float) -> void:
	if not camera_impulses_enabled: return
	_dip = maxf(_dip, amount)


## Тряска: накапливается от ударов и затухает. Сила тряски растёт как квадрат — мелкие удары еле заметны.
func add_shake(amount: float) -> void:
	if not camera_impulses_enabled: return
	_trauma = minf(_trauma + amount, 1.0)

## Очередь не накапливает бесконечную тряску; сильный полученный удар не ослабляется.
func add_weapon_shake(amount: float, cap: float) -> void:
	if not camera_impulses_enabled: return
	_trauma = maxf(_trauma, minf(_trauma + amount, cap))


func _physics_process(delta: float) -> void:
	if not camera_impulses_enabled:
		_dip = 0.0
		_trauma = 0.0
	_dip = move_toward(_dip, 0.0, shake_recovery * delta)
	_trauma = move_toward(_trauma, 0.0, shake_decay * delta)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _trauma * _trauma * shake_max_offset
	camera.position = _camera_offset() + Vector3.DOWN * _dip + jitter
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		# Игрока могли перенести в этот уровень позже (переход база ↔ зона) — ищем снова.
		_target = get_node_or_null(target_path) as Node3D if not target_path.is_empty() else get_tree().get_first_node_in_group("player") as Node3D
		if _target == null or not _target.is_inside_tree():
			return
		global_position = _target.global_position
	global_position = global_position.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))
