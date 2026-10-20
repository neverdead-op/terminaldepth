extends CharacterBody3D
## Учёный (задание этажа «Выведите учёных»). Прячется в комнате, присев; F / ○ — «Идёмте со мной».
## Дальше ходит за героем, сам не атакует. Враги рядом — пригибается и уходит за спину героя (подальше от врагов),
## но от героя далеко не отходит. Враги вплотную бьют его (группа taunting с маленьким радиусом).
## Довели до лифта (exit_position зоны) — спасён: опыт и добыча. Убили — задание по нему провалено.

const HealthBar := preload("res://scripts/health_bar_3d.gd")
const Highlight := preload("res://scripts/highlight.gd")
const Suit := preload("res://scripts/suit.gd")
const Hair := preload("res://scripts/hair.gd")
const Animator := preload("res://scripts/player_animator.gd")
const LOOT := preload("res://scripts/loot_pickup.gd")
const MODELS := [preload("res://assets/characters/base/Superhero_Male_FullBody.gltf"),
		preload("res://assets/characters/base/Superhero_Female_FullBody.gltf")]
const HAIR := [preload("res://assets/characters/hair/Hair_SimpleParted.gltf"),
		preload("res://assets/characters/hair/Hair_Long.gltf"), preload("res://assets/characters/hair/Hair_Buzzed.gltf")]
const ANIMS := [&"Idle", &"Walk", &"Jog_Fwd", &"Death01", &"Hit_Chest"]

@export var max_hp := 160.0
@export var walk_speed := 3.2
@export var run_speed := 4.8
## На каком расстоянии от героя держится.
@export var follow_distance := 2.6
## Враги ближе этого — пугается и прячется за героя.
@export var fear_radius := 7.0
## Враги ближе этого бьют учёного, а не героя.
@export var taunt_radius := 1.8
## Сколько метров до лифта — уже спасён.
@export var rescue_radius := 8.0
## Имя и короткие реплики сотрудника, задаются генератором для каждого спасаемого NPC.
@export var staff_name := "Учёный"
@export var rescue_dialogue := "Помогите мне добраться до лифта."
@export var rescue_thanks := "Спасибо, что не бросили меня."
## Халат и вставки костюма.
@export var coat_color := Color(0.62, 0.66, 0.7)

var prompt := "Спасти сотрудника"
var interact_range := 2.4
var following := false
var rescued := false
var failed := false
var hp := 0.0

var _player: Node3D
var _anim: AnimationPlayer
var _bar: Node3D
var _level := 1
var _path := PackedVector3Array()
var _path_index := 0
var _repath_left := 0.0
var _fear := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _exit := Vector3.INF
var _model: Node3D
var _hit_left := 0.0


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("quest_escort")
	# Слой героя (2): двери открываются, враги толкаются и бьют плевками; пули героя пролетают насквозь.
	collision_layer = 2
	collision_mask = 1 | 16
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	var scene: PackedScene = MODELS.pick_random()
	_model = scene.instantiate()
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * 0.95
	add_child(_model)
	Suit.apply(_model, Color(0.3, 0.8, 0.9), coat_color.darkened(0.15), Color.WHITE, coat_color)
	Hair.attach(_model, HAIR.pick_random(), Color(0.35, 0.3, 0.25))
	Highlight.apply(_model, Color(0.4, 0.9, 1.0))
	var skeleton: Skeleton3D = _model.get_node("Armature/Skeleton3D")
	_anim = AnimationPlayer.new()
	_model.add_child(_anim)
	_anim.root_node = NodePath("..")
	_anim.add_animation_library(&"", Animator.fit_library(skeleton, ANIMS, [&"Death01", &"Hit_Chest"]))
	_anim.play(&"Idle")
	_bar = HealthBar.new()
	_bar.width = 0.8
	_bar.fill_color = Color(0.4, 0.9, 1.0)
	_bar.position = Vector3(0, 2.1, 0)
	add_child(_bar)
	_bar.visible = false
	var node := get_parent()
	while node != null:
		if "zone_level" in node:
			_level = node.zone_level
			if "exit_position" in node:
				var e: Vector2 = node.exit_position
				_exit = Vector3(e.x, 0, e.y)
			break
		node = node.get_parent()
	hp = max_hp * (1.0 + 0.4 * (_level - 1))


func is_dead() -> bool:
	return failed or rescued or not following


func is_safe() -> bool:
	return false


func interact(player: Node) -> void:
	if following or failed or rescued:
		return
	following = true
	_player = player
	remove_from_group("interactables")
	add_to_group("taunting")
	Highlight.clear(_model)
	_bar.visible = true
	Sfx.play(&"door_unlock", global_position, -6.0)
	player.show_message("%s: «%s»" % [Loc.t(staff_name), Loc.t(rescue_dialogue)], 4.0)
	player.show_message("Отведите сотрудника к лифту — голубой квадрат на мини-карте", 4.5)


func take_damage(amount: float, _element := &"physical", _source = null) -> float:
	if not following or failed or rescued:
		return 0.0
	hp -= amount
	_bar.set_ratio(hp / (max_hp * (1.0 + 0.4 * (_level - 1))))
	Fx.hit(global_position + Vector3.UP * 1.2, Vector3.UP, Color(0.6, 0.05, 0.05), 6)
	if _hit_left <= 0.0:
		_hit_left = 0.8
		_anim.play(&"Hit_Chest", 0.1)
	if hp <= 0.0:
		_fail()
	return amount


func _fail() -> void:
	failed = true
	following = false
	remove_from_group("taunting")
	collision_layer = 0
	_bar.visible = false
	_anim.play(&"Death01", 0.15)
	if _player != null and is_instance_valid(_player):
		_player.show_message("Сотрудник погиб", 3.0)


func _rescue() -> void:
	rescued = true
	following = false
	remove_from_group("taunting")
	_bar.visible = false
	_anim.play(&"Idle", 0.3)
	if _player != null and is_instance_valid(_player):
		_player.show_message("%s: «%s»" % [Loc.t(staff_name), Loc.t(rescue_thanks)], 4.0)
	Sfx.play(&"unique_drop", global_position)


func _physics_process(delta: float) -> void:
	_hit_left -= delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not following or _player == null or not is_instance_valid(_player):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _exit != Vector3.INF and Vector2(global_position.x - _exit.x, global_position.z - _exit.z).length() < rescue_radius:
		_rescue()
		return
	# Ближайший враг рядом — страшно: держаться за спиной героя, подальше от врага.
	var threat := _nearest_enemy()
	_fear = threat != null
	var goal: Vector3 = _player.global_position
	if _fear:
		var away: Vector3 = _player.global_position - threat.global_position
		away.y = 0.0
		goal = _player.global_position + away.normalized() * 2.2
	var to_goal := goal - global_position
	to_goal.y = 0.0
	var desired := Vector3.ZERO
	var near := 0.6 if _fear else follow_distance
	if to_goal.length() > near:
		var speed := run_speed if (_fear or to_goal.length() > 6.0) else walk_speed
		desired = _path_dir(goal, delta) * speed
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 25.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	# Застрял далеко позади — догоняет.
	if global_position.distance_to(_player.global_position) > 22.0:
		global_position = _player.global_position + Vector3(1.2, 0.2, 1.2)
	var face := horizontal if horizontal.length() > 0.3 else (threat.global_position - global_position if threat != null else Vector3.ZERO)
	face.y = 0.0
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-10.0 * delta))
	if _anim.current_animation != &"Hit_Chest" or not _anim.is_playing():
		var moving := horizontal.length() > 0.5
		var want: StringName
		if _fear:
			want = &"Walk" if moving else &"Idle"
		else:
			want = (&"Jog_Fwd" if horizontal.length() > walk_speed + 0.3 else &"Walk") if moving else &"Idle"
		if _anim.current_animation != want:
			_anim.play(want, 0.2)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := fear_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D:
			var d := global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _path_dir(goal: Vector3, delta: float) -> Vector3:
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = 0.4
		_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, goal, true)
		_path_index = 1
	while _path_index < _path.size():
		var to := _path[_path_index] - global_position
		to.y = 0.0
		if to.length() > 0.5:
			return to.normalized()
		_path_index += 1
	var direct := goal - global_position
	direct.y = 0.0
	return direct.normalized()
