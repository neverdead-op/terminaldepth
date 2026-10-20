extends CharacterBody3D
## Робот-союзник (мини-задание этажа). Сначала лежит отключённым — мигает красный огонёк, на мини-карте
## голубая точка. F / ○ рядом — перезапуск: робот светится голубым, ходит за героем и стреляет по ближайшим
## видимым врагам. Урон небольшой, работает от батареи lifetime секунд, потом снова отключается.
## Перезапустить всех роботов этажа — задание (zone_quests.gd) с наградой.

const HealthBar := preload("res://scripts/health_bar_3d.gd")
const Highlight := preload("res://scripts/highlight.gd")
const MODEL := preload("res://assets/essentials/Enemy_QuadShell.gltf")
const HEAVY := preload("res://assets/essentials/Enemy_Trilobite.gltf")
const LOS_MASK := 1 | 16

@export var lifetime := 90.0
@export var damage := 20.0
## Урон растёт с уровнем этажа: ×(1 + damage_per_level · (уровень − 1)).
@export var damage_per_level := 0.3
@export var fire_interval := 0.45
@export var fire_range := 13.0
@export var move_speed := 4.8
@export var follow_distance := 3.0
@export var model_scale := 0.62
@export var glow := Color(0.35, 0.85, 1.0)
## Ближний боец (танк): провоцирует врагов рядом, бьёт вплотную. Иначе — стрелок.
@export var melee := false
@export var max_hp := 260.0
## Радиус провокации: враги ближе этого бьют робота, а не героя.
@export var taunt_radius := 6.0
@export var melee_damage := 32.0

## Для подсказки «F / ○ — …» (как у interactable.gd).
var prompt := "Перезапустить робота"
var interact_range := 2.6
var active := false
var spent := false

var _player: Node3D
var _left := 0.0
var _fire_left := 0.0
var _target: Node3D
var _target_left := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _repath_left := 0.0
var _anim: AnimationPlayer
var _light: OmniLight3D
var _bar: Node3D
var _time := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _level := 1
var hp := 0.0
var _robot_model: Node3D
var _on_overlay: Material
var _dead := false


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("ally_robots")
	collision_layer = 0
	collision_mask = 1 | 16
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.2
	shape.shape = capsule
	shape.position.y = 0.6
	add_child(shape)
	var model: Node3D = (HEAVY if melee else MODEL).instantiate()
	model.scale = Vector3.ONE * (model_scale * 1.25 if melee else model_scale)
	model.rotation.y = PI
	add_child(model)
	# Голубой налёт поверх модели — видно, что это «свой».
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(glow, 0.18)
	overlay.emission_enabled = true
	overlay.emission = glow
	overlay.emission_energy_multiplier = 0.35
	# Отключённый робот подсвечен голубым — его можно перезапустить.
	Highlight.apply(model, Color(0.35, 0.85, 1.0))
	_robot_model = model
	_on_overlay = overlay
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for loop_name in [&"Idle", &"Walk", &"Run"]:
			if _anim.has_animation(loop_name):
				_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		_power_down_pose()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.2, 0.15)
	_light.omni_range = 2.5
	_light.light_energy = 1.2
	_light.position = Vector3(0, 1.2, 0)
	add_child(_light)
	_bar = HealthBar.new()
	_bar.width = 0.9
	_bar.fill_color = glow
	_bar.position = Vector3(0, 1.7, 0)
	_bar.visible = false
	add_child(_bar)
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			_level = node.zone_level
			break
		node = node.get_parent()


func _power_down_pose() -> void:
	if _anim != null and _anim.has_animation(&"TurnOff"):
		_anim.play(&"TurnOff")
		_anim.seek(_anim.current_animation_length, true)
		_anim.pause()


func is_dead() -> bool:
	return _dead or not active


func is_safe() -> bool:
	return false


## Урон от врагов (робот-танк принимает удары на себя).
func take_damage(amount: float, _element := &"physical", _source = null) -> float:
	if not active:
		return 0.0
	hp -= amount
	Fx.impact(global_position + Vector3.UP, Vector3.UP, glow)
	if hp <= 0.0:
		_shut_down()
	return amount


func interact(player: Node) -> void:
	if active or spent:
		return
	active = true
	for m in _robot_model.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _on_overlay
	hp = max_hp * (1.0 + 0.4 * (_level - 1))
	if melee:
		add_to_group("taunting")
	_player = player
	_left = lifetime
	remove_from_group("interactables")
	_light.light_color = glow
	_light.light_energy = 1.6
	_bar.visible = true
	if _anim != null:
		_anim.play(&"Idle", 0.3)
	Fx.impact(global_position + Vector3.UP, Vector3.UP, glow)
	player.show_message("Робот-союзник перезапущен и прикрывает вас", 3.0)


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not active:
		# Отключён: мигает красным, ждёт героя.
		_light.light_energy = 1.2 if fmod(_time, 1.2) < 0.25 else 0.15
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_left -= delta
	_bar.set_ratio(minf(_left / lifetime, hp / (max_hp * (1.0 + 0.4 * (_level - 1)))))
	if _left <= 0.0 or _player == null or not is_instance_valid(_player):
		_shut_down()
		return
	_update_target(delta)
	var desired := Vector3.ZERO
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	if melee and _target != null:
		# Танк бежит к врагу и бьёт вплотную.
		var to_enemy: Vector3 = _target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > 1.8:
			desired = to_enemy.normalized() * move_speed
	elif to_player.length() > follow_distance:
		desired = _path_dir(delta) * move_speed * (1.4 if to_player.length() > 9.0 else 1.0)
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 30.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	# Отстал слишком сильно (застрял) — догоняет рывком к герою.
	if to_player.length() > 25.0:
		global_position = _player.global_position + Vector3(1.5, 0.2, 1.5)
	var face := horizontal
	if _target != null:
		face = _target.global_position - global_position
		_fire_left -= delta
		if _fire_left <= 0.0:
			_fire_left = fire_interval * randf_range(0.85, 1.15) * (2.2 if melee else 1.0)
			if melee:
				_punch()
			else:
				_shoot()
	face.y = 0.0
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-10.0 * delta))
	if _anim != null:
		var want := &"Walk" if horizontal.length() > 0.5 else &"Idle"
		if _anim.current_animation != want and _anim.current_animation != &"Attack":
			_anim.play(want, 0.15)


func _path_dir(delta: float) -> Vector3:
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = 0.5
		_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, _player.global_position, true)
		_path_index = 1
	while _path_index < _path.size():
		var to := _path[_path_index] - global_position
		to.y = 0.0
		if to.length() > 0.5:
			return to.normalized()
		_path_index += 1
	var direct: Vector3 = _player.global_position - global_position
	direct.y = 0.0
	return direct.normalized()


## Ближайший видимый враг в пределах fire_range (ищем раз в 0.3 с).
func _update_target(delta: float) -> void:
	_target_left -= delta
	if _target != null and (not is_instance_valid(_target) or not _target.is_in_group("enemies")):
		_target = null
	if _target_left > 0.0:
		return
	_target_left = 0.3
	_target = null
	var best := fire_range
	var space := get_world_3d().direct_space_state
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d >= best:
			continue
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, LOS_MASK)
		if not space.intersect_ray(q).is_empty():
			continue
		best = d
		_target = enemy


func _shoot() -> void:
	var pool := get_tree().get_first_node_in_group("bullet_pool")
	if pool == null or _target == null:
		return
	var from := global_position + Vector3.UP * 1.0
	var dir: Vector3 = _target.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-3.0, 3.0)))
	var payload := {"damage": damage * (1.0 + damage_per_level * (_level - 1)), "elements": {&"electric": 0.3},
			"pierce": 0, "chain": 0, "leech": 0.0, "shooter": self, "look": &"bullet"}
	pool.fire(Transform3D(Basis.looking_at(dir, Vector3.UP), from + dir * 0.5), 38.0, fire_range + 4.0,
			global_position + Vector3.UP, payload)
	Fx.impact(from + dir * 0.5, -dir, glow)
	if _anim != null and _anim.has_animation(&"Attack") and _anim.current_animation != &"Attack":
		_anim.play(&"Attack", 0.05)


## Удар вплотную по цели (танк).
func _punch() -> void:
	if _target == null or _target.global_position.distance_to(global_position) > 2.4:
		return
	_target.take_damage(melee_damage * (1.0 + damage_per_level * (_level - 1)), &"physical", self)
	Fx.sparks(_target.global_position + Vector3.UP, Vector3.UP)
	if _anim != null and _anim.has_animation(&"Attack"):
		_anim.play(&"Attack", 0.05)


func _shut_down() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("taunting")
	active = false
	spent = true
	_bar.visible = false
	_light.light_energy = 0.0
	_power_down_pose()
	if _player != null and is_instance_valid(_player):
		_player.show_message("Робот-союзник выведен из строя" if hp <= 0.0 else "Батарея робота-союзника разрядилась", 2.5)
