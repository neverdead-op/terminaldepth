extends Enemy
## Плевун — держит дистанцию и плюётся кислотой. Сгусток летит не мгновенно: от него можно откатиться.
## Если игрок подходит слишком близко — пятится; если далеко или за стеной — подходит.

const PROJECTILE := preload("res://scripts/enemy_projectile.gd")

@export_group("Плевок")
## Держится на расстоянии между min и max.
@export var keep_distance_min := 6.0
@export var keep_distance_max := 11.0
@export var projectile_speed := 13.0
@export var projectile_damage := 12.0
## Насколько стреляет на упреждение (0 — в текущую точку, 1 — точно туда, куда игрок прибежит).
@export_range(0.0, 1.0) var lead := 0.5
## Стихия и цвет снаряда (у Плевуна — кислота, у дрона — электричество).
@export var projectile_element := &"acid"
@export var projectile_color := Color(0.45, 1.0, 0.15)
@export var spit_sound := &"spit"

static var _meshes := {}

var _sac: MeshInstance3D
var _neck: Node3D
var _legs: Array[Node3D] = []


func _think(delta: float, to_player: Vector3, distance: float) -> Array:
	var desired := Vector3.ZERO
	var face_dir := to_player
	match _state:
		State.CHASE:
			if not _player_targetable():
				face_dir = Vector3.ZERO
			elif distance > keep_distance_max or not _sees_player:
				desired = _approach(_chase_direction(delta, to_player, distance), distance, delta) * move_speed
				face_dir = desired
			elif distance < keep_distance_min:
				desired = -to_player.normalized() * move_speed * 0.8
			else:
				_state = State.WINDUP
				_timer = attack_windup
				_on_windup()
		State.WINDUP:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.RECOVER
				_timer = attack_cooldown
				_spit()
		State.RECOVER:
			_timer -= delta
			# Между плевками немного смещается вбок — сложнее попасть.
			desired = to_player.normalized().cross(Vector3.UP) * move_speed * 0.4 * (1.0 if int(_anim_time) % 2 == 0 else -1.0)
			if _timer <= 0.0:
				_state = State.CHASE
	return [desired, face_dir]


func _spit() -> void:
	if not _player_targetable():
		return
	var start := global_position + Vector3.UP * 1.0 - global_basis.z * 0.6
	var target: Vector3 = _player.global_position + Vector3.UP * 1.0
	var flight_time := start.distance_to(target) / projectile_speed
	target += Vector3(_player.velocity.x, 0, _player.velocity.z) * flight_time * lead
	PROJECTILE.spawn(get_parent(), start, target, projectile_speed, projectile_damage, projectile_element, projectile_color)
	Fx.flipbook(&"spark", start, 0.48, 0.16, projectile_color, false, true)
	Sfx.play(spit_sound, global_position)
	_on_attack()


func _build_visual() -> void:
	if humanoid_model != null:
		super()
		return
	if _meshes.is_empty():
		var skin := _material(Color(0.18, 0.2, 0.17), 0.0, 0.5)
		var sac := _material(Color(0.4, 1.0, 0.15), 2.2)
		var body := SphereMesh.new()
		body.radius = 0.5
		body.height = 1.0
		body.material = skin
		var sac_mesh := SphereMesh.new()
		sac_mesh.radius = 0.5
		sac_mesh.height = 1.0
		sac_mesh.material = sac
		var limb := CapsuleMesh.new()
		limb.radius = 0.06
		limb.height = 0.9
		limb.material = skin
		_meshes = {"body": body, "sac": sac_mesh, "limb": limb}

	_mesh(_meshes.body, Vector3(0, 0.6, 0.1), Vector3(0.6, 0.45, 0.8))
	_sac = _mesh(_meshes.sac, Vector3(0, 0.85, 0.45), Vector3(0.7, 0.6, 0.7))
	_neck = Node3D.new()
	_neck.position = Vector3(0, 0.75, -0.2)
	_visual.add_child(_neck)
	var neck_mesh := _mesh(_meshes.limb, Vector3(0, 0.3, -0.1), Vector3(2.2, 0.7, 2.2), _neck)
	neck_mesh.rotation.x = -0.4
	_mesh(_meshes.body, Vector3(0, 0.62, -0.3), Vector3(0.35, 0.3, 0.45), _neck)
	for i in 4:
		var side := 1.0 if i % 2 == 0 else -1.0
		var row := -0.25 if i < 2 else 0.35
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.22, 0.6, row)
		_visual.add_child(pivot)
		var leg := _mesh(_meshes.limb, Vector3(side * 0.25, -0.3, 0), Vector3.ONE, pivot, false)
		leg.rotation.z = side * 0.6
		_legs.append(pivot)


func _animate(delta: float, speed: float) -> void:
	if humanoid_model != null:
		super(delta, speed)
		return
	_anim_time += delta * (3.0 + speed * 2.5)
	var amount := clampf(speed / maxf(move_speed, 0.1), 0.0, 1.0)
	for i in _legs.size():
		_legs[i].rotation.x = sin(_anim_time + PI * (i % 2) + i) * 0.5 * amount
	# Мешок с кислотой «дышит», перед плевком раздувается.
	var swell := 1.0 + sin(_anim_time * 1.5) * 0.06
	if _state == State.WINDUP:
		swell = 1.0 + (1.0 - _timer / attack_windup) * 0.35
	_sac.scale = Vector3(0.7, 0.6, 0.7) * swell


func _on_windup() -> void:
	if humanoid_model != null:
		super()
		return
	var tween := create_tween()
	tween.tween_property(_neck, "rotation:x", 0.5, attack_windup * 0.8)


func _on_attack() -> void:
	if humanoid_model != null:
		super()
		return
	var tween := create_tween()
	tween.tween_property(_neck, "rotation:x", -0.4, 0.07)
	tween.tween_property(_neck, "rotation:x", 0.0, 0.25)
