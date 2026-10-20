extends Node3D
## Пул пуль: заранее создаёт запас пуль и переиспользует их.
## Это дешевле, чем создавать и удалять сотни объектов в секунду.

@export var bullet_scene: PackedScene
@export var pool_size := 200

var _bullets: Array[Node3D] = []
var _next := 0


func _ready() -> void:
	for i in pool_size:
		var bullet: Node3D = bullet_scene.instantiate()
		add_child(bullet)
		bullet.deactivate()
		_bullets.append(bullet)


## payload — что пуля делает при попадании (урон, стихии, пробивание…), см. bullet.gd.
func fire(start: Transform3D, speed: float, max_range: float, shooter_point: Vector3, payload: Dictionary) -> void:
	# Ищем свободную пулю. Если все в полёте — берём самую старую.
	for i in pool_size:
		var bullet := _bullets[_next]
		_next = (_next + 1) % pool_size
		if not bullet.active:
			bullet.activate(start, speed, max_range, shooter_point, payload)
			return
	_bullets[_next].activate(start, speed, max_range, shooter_point, payload)
	_next = (_next + 1) % pool_size
