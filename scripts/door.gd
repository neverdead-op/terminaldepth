extends Node3D
## Автоматическая раздвижная дверь. Открывается, когда рядом игрок или враг.
## Зелёный свет — дверь работает. Красный — заперта: нужна ключ-карта (key_id).
## Проём идёт вдоль локальной оси Z, створки — поперёк (по X). Для стены «восток–запад» поверните на 90°.
## Створки на слое 5 (значение 16): карта проходимости их не видит, поэтому враги умеют ходить через двери.

@export var width := 4.0
@export var height := 2.4
@export var locked := false
## Какой ключ открывает дверь (если заперта).
@export var key_id := &""
## Название для подсказки: «Нужна ключ-карта: …».
@export var key_name := ""
@export var open_time := 0.35
## Открывается ли перед врагами. У двери безопасной комнаты — нет.
@export var enemies_can_open := true
## Насколько далеко от проёма дверь «чувствует» подходящих (м).
@export var sense_depth := 2.6

const OPEN_COLOR := Color(0.2, 1.0, 0.45)
const LOCKED_COLOR := Color(1.0, 0.15, 0.1)

static var _shared := {}

var _open := false
var _left: AnimatableBody3D
var _right: AnimatableBody3D
var _sensor: Area3D
var _strip: MeshInstance3D
var _lights: Array[OmniLight3D] = []
var _check_left := 0.0
var _message_cooldown := 0.0


func _ready() -> void:
	_build()
	_update_color()


func _physics_process(delta: float) -> void:
	_message_cooldown -= delta
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.12

	var player: Node = null
	var someone := false
	for body in _sensor.get_overlapping_bodies():
		if body.is_in_group("player"):
			player = body
			someone = true
		elif enemies_can_open:
			someone = true

	if locked:
		if player != null:
			_try_unlock(player)
		if locked:
			return
	if someone != _open:
		_set_open(someone)


func _try_unlock(player: Node) -> void:
	if player.has_method("has_key") and player.has_key(key_id):
		locked = false
		_update_color()
		Sfx.play(&"door_unlock", global_position)
		if player.has_method("show_message"):
			player.show_message("Дверь разблокирована: %s" % key_name)
	elif _message_cooldown <= 0.0:
		_message_cooldown = 3.0
		Sfx.play(&"door_locked", global_position)
		if player.has_method("show_message"):
			player.show_message("Заперто. Нужна ключ-карта: %s" % key_name)


func _set_open(value: bool) -> void:
	_open = value
	var shift := width * 0.5 if value else 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_left, "position:x", -width * 0.25 - shift, open_time)
	tween.tween_property(_right, "position:x", width * 0.25 + shift, open_time)
	Sfx.play(&"door_open" if value else &"door_close", global_position + Vector3.UP)


func _update_color() -> void:
	var color := LOCKED_COLOR if locked else OPEN_COLOR
	_strip.material_override = _shared.strip_locked if locked else _shared.strip_open
	for light in _lights:
		light.light_color = color


func _build() -> void:
	if _shared.is_empty():
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.3, 0.32, 0.36)
		metal.metallic = 0.7
		metal.roughness = 0.4
		var trim := StandardMaterial3D.new()
		trim.albedo_color = Color(0.85, 0.6, 0.1)
		trim.metallic = 0.4
		trim.roughness = 0.5
		_shared = {
			"metal": metal,
			"trim": trim,
			"strip_open": _glow(OPEN_COLOR),
			"strip_locked": _glow(LOCKED_COLOR),
		}

	var panel_size := Vector3(width * 0.5, height, 0.25)
	_left = _panel(panel_size, -width * 0.25)
	_right = _panel(panel_size, width * 0.25)

	# Световая полоса сверху — её хорошо видно камерой сверху.
	_strip = MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(width + 0.2, 0.06, 0.18)
	_strip.mesh = strip_mesh
	_strip.position = Vector3(0, height + 0.08, 0)
	_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_strip)

	# Свет на пол с обеих сторон двери.
	for side in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, height - 0.3, side * 1.2)
		light.omni_range = 4.0
		light.light_energy = 0.6
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)

	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2 | 4  # игрок и враги
	_sensor.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 1.0, 2.0, sense_depth * 2.0)
	shape.shape = box
	shape.position = Vector3(0, 1.0, 0)
	_sensor.add_child(shape)
	add_child(_sensor)


func _panel(panel_size: Vector3, x: float) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = Vector3(x, 0, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = panel_size
	shape.shape = box
	shape.position = Vector3(0, panel_size.y * 0.5, 0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = panel_size
	box_mesh.material = _shared.metal
	mesh.mesh = box_mesh
	mesh.position = shape.position
	body.add_child(mesh)
	# Жёлтая полоса-предупреждение по краю створки.
	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(0.12, panel_size.y, panel_size.z + 0.04)
	trim_mesh.material = _shared.trim
	trim.mesh = trim_mesh
	trim.position = Vector3(-signf(x) * (panel_size.x * 0.5 - 0.06), panel_size.y * 0.5, 0)
	body.add_child(trim)
	add_child(body)
	return body


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.3
	return m
