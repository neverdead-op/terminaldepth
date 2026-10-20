extends StaticBody3D
## Тренировочный манекен: принимает урон, взрывается и через время появляется снова.
## Нужен, чтобы проверить стрельбу и автоприцел, пока нет настоящих врагов.

const EXPLOSION := preload("res://scenes/explosion.tscn")

@export var max_hp := 100.0
@export var respawn_delay := 3.0
## Сколько заряда аптечки получает игрок за убийство (1 — целый заряд).
@export var flask_charge_reward := 0.5

@onready var mesh: MeshInstance3D = $Mesh
@onready var health_bar: Node3D = $HealthBar

var hp := 0.0
var _dead := false
var _material: StandardMaterial3D
var _layer := 0


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_layer = collision_layer
	_material = mesh.get_active_material(0).duplicate()
	mesh.set_surface_override_material(0, _material)
	health_bar.set_ratio(1.0)


func take_damage(amount: float, _element := &"physical", _source = null) -> void:
	if _dead:
		return
	hp -= amount
	health_bar.set_ratio(hp / max_hp)

	_material.emission_energy_multiplier = 3.0
	var flash := create_tween()
	flash.tween_property(_material, "emission_energy_multiplier", 0.0, 0.15)

	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")  # автоприцел больше не видит его
	collision_layer = 0  # пули пролетают насквозь
	mesh.visible = false
	health_bar.visible = false

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_flask_charge"):
		player.add_flask_charge(flask_charge_reward)

	var explosion := EXPLOSION.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position + Vector3.UP * 0.9

	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	hp = max_hp
	_dead = false
	collision_layer = _layer
	add_to_group("enemies")
	health_bar.set_ratio(1.0)
	health_bar.visible = true
	mesh.visible = true
	mesh.scale = Vector3(0.01, 0.01, 0.01)
	var grow := create_tween()
	grow.tween_property(mesh, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
