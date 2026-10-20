extends Area3D
## Ключ-карта. Подбирается, когда игрок подходит; открывает двери с тем же key_id.

@export var key_id := &"armory"
@export var key_name := "Оружейная"
@export var color := Color(1.0, 0.25, 0.15)
@export var model: PackedScene = preload("res://assets/essentials/Prop_KeyCard.gltf")
@export var model_scale := 1.8

var _visual: Node3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # только игрок
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	var card := model.instantiate() as Node3D
	card.scale = Vector3.ONE * model_scale
	_visual.add_child(card)
	preload("res://scripts/highlight.gd").apply(card, Color(1.0, 0.85, 0.3))

	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 5.0
	light.light_energy = 3.0
	add_child(light)
	# Предмет задания — высокий яркий столб, видно издалека (как в PoE 2).
	var beam := preload("res://scripts/loot_beam.gd").new()
	beam.color = color
	beam.height = 12.0
	beam.width = 0.25
	beam.position.y = -0.9
	add_child(beam)
	add_to_group("quest_items")

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y = _time * 2.0
	_visual.position.y = sin(_time * 3.0) * 0.1


func _on_body_entered(body: Node) -> void:
	if not body.has_method("add_key"):
		return
	body.add_key(key_id, key_name)
	Sfx.play(&"key_pickup", global_position)
	queue_free()
