extends Area3D
## Лифт вниз — цель этажа. Работает, только когда босс этажа (группа «bosses») повержен.

@export var size := Vector3(3, 2, 3)
@export var restart_delay := 4.0

var _used := false
var _warned := false
var _check := 0.0


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

	# Площадка лифта: светящаяся рамка на полу.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.3, 0.8, 1.0)
	material.emission_energy_multiplier = 0.8
	for i in 4:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var horizontal := i < 2
		mesh.size = Vector3(size.x, 0.05, 0.15) if horizontal else Vector3(0.15, 0.05, size.z)
		mesh.material = material
		bar.mesh = mesh
		var s := -1.0 if i % 2 == 0 else 1.0
		bar.position = Vector3(0, 0.03, s * size.z * 0.5) if horizontal else Vector3(s * size.x * 0.5, 0.03, 0)
		add_child(bar)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.8, 1.0)
	light.position = Vector3(0, 1.5, 0)
	light.omni_range = 5.0
	light.light_energy = 2.0
	add_child(light)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Игрок может стоять в лифте, пока добивают босса, — проверяем время от времени.
	_check -= delta
	if _check > 0.0 or _used:
		return
	_check = 0.5
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return
	var bosses := get_tree().get_nodes_in_group("bosses")
	if not bosses.is_empty():
		if not _warned and body.has_method("show_message"):
			_warned = true
			body.show_message(Loc.t("Лифт заблокирован — сначала одолейте: %s") % bosses[0].get_title(), 3.0)
		return
	_used = true
	Sfx.play(&"door_unlock", global_position)
	if body.has_method("show_message"):
		body.show_message("Лифт найден — этаж пройден!", restart_delay)
	await get_tree().create_timer(restart_delay).timeout
	Game.complete_zone(body)
