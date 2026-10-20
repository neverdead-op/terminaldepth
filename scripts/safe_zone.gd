extends Area3D
## Безопасная комната: пока игрок внутри, враги его не видят и не преследуют.
## Размер зоны — size, отсчитывается от центра узла.

@export var size := Vector3(12, 3, 10)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_safe_zone"):
		body.enter_safe_zone()


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_safe_zone"):
		body.exit_safe_zone()
