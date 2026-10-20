extends Enemy
## Робот-стрелок (тяжёлый робот): держит дистанцию и стреляет из пушек короткими очередями.
## Перед очередью — прицеливание: красный луч к игроку. Очередь летит туда, где игрок был в конце
## прицеливания, и лишь медленно доворачивает — перекат вбок уводит из-под огня.
## Если игрок подошёл вплотную — бьёт корпусом, как обычный враг.

const PROJECTILE := preload("res://scripts/enemy_projectile.gd")

@export_group("Очередь")
## Держится на расстоянии между min и max.
@export var keep_distance_min := 5.0
@export var keep_distance_max := 12.0
## Прицеливание перед очередью (красный луч), сек.
@export var aim_time := 0.9
@export var burst_count := 6
@export var burst_interval := 0.12
@export var bullet_speed := 17.0
@export var bullet_damage := 6.0
## Разброс пуль в очереди, градусы.
@export var burst_spread := 4.0
## Как быстро очередь доворачивает за игроком, градусов в секунду.
@export var burst_track := 22.0
## Пауза между очередями.
@export var burst_cooldown := 2.2
@export var shot_sound := &"shot_lmg"
@export var shot_volume := -10.0
## Стихия и цвет пуль (свойства «Огненный» и т. п. меняют их).
@export var projectile_element := &"physical"
@export var projectile_color := Color(1.0, 0.55, 0.2)
@export var anim_shoot := &"AttackAuto"

enum Gun { NONE, AIM, FIRE }

var _gun := Gun.NONE
var _gun_timer := 0.0
var _shots_left := 0
var _aim := Vector3.FORWARD
var _side := 1.0
var _laser: MeshInstance3D
var _laser_mat: StandardMaterial3D
var _skeleton: Skeleton3D
var _gun_bones: Array[int] = []
var _strafe := 1.0
var _base_damage := 1.0


func _ready() -> void:
	_base_damage = damage
	super()
	if _visual != null:
		_skeleton = _visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null:
		for bone_name in ["Gun.L", "Gun.R"]:
			var i := _skeleton.find_bone(bone_name)
			if i >= 0:
				_gun_bones.append(i)
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _think(delta: float, to_player: Vector3, distance: float) -> Array:
	# Вплотную — обычный удар корпусом (замах из базового врага).
	if _gun == Gun.NONE and (_state == State.WINDUP or _state == State.RECOVER
			or (distance < attack_range and _state == State.CHASE)):
		return super(delta, to_player, distance)
	var desired := Vector3.ZERO
	var face_dir := to_player
	match _gun:
		Gun.NONE:
			if _state != State.CHASE or not _player_targetable():
				return [Vector3.ZERO, Vector3.ZERO]
			_gun_timer -= delta
			if distance > keep_distance_max or not _sees_player:
				desired = _approach(_chase_direction(delta, to_player, distance), distance, delta) * move_speed
				face_dir = desired
			elif distance < keep_distance_min:
				desired = -to_player.normalized() * move_speed * 0.7
			else:
				# Медленно обходит игрока боком, пока не готов стрелять.
				desired = to_player.normalized().cross(Vector3.UP) * move_speed * 0.35 * _strafe
				if _gun_timer <= 0.0:
					_start_aim()
		Gun.AIM:
			_gun_timer -= delta
			_update_laser(to_player)
			if _gun_timer <= 0.0:
				_aim = to_player.normalized() if distance > 0.1 else -global_basis.z
				_gun = Gun.FIRE
				_shots_left = burst_count
				_gun_timer = 0.0
				_set_laser(false)
		Gun.FIRE:
			face_dir = _aim
			# Очередь медленно доворачивает за игроком.
			if distance > 0.1:
				var want := to_player.normalized()
				var angle := _aim.signed_angle_to(want, Vector3.UP)
				var step := deg_to_rad(burst_track) * delta
				_aim = _aim.rotated(Vector3.UP, clampf(angle, -step, step))
			_gun_timer -= delta
			if _gun_timer <= 0.0:
				_fire_one()
				_shots_left -= 1
				_gun_timer = burst_interval
				if _shots_left <= 0:
					_gun = Gun.NONE
					_gun_timer = burst_cooldown * randf_range(0.8, 1.2)
					_strafe = -_strafe
	return [desired, face_dir]


func _start_aim() -> void:
	_gun = Gun.AIM
	_gun_timer = aim_time
	_play_once(anim_shoot, aim_time + burst_count * burst_interval)
	_set_laser(true)


func _muzzle() -> Vector3:
	_side = -_side
	var right := global_basis.x
	if _skeleton != null and _gun_bones.size() == 2:
		var bone := _gun_bones[0 if _side < 0.0 else 1]
		var p := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin
		return Vector3(p.x, global_position.y + 1.0, p.z) + _aim * 0.4
	return global_position + Vector3.UP * 1.0 + right * 0.6 * _side + _aim * 0.9


func _fire_one() -> void:
	var start := _muzzle()
	var dir := _aim.rotated(Vector3.UP, deg_to_rad(randf_range(-burst_spread, burst_spread)))
	PROJECTILE.spawn(get_parent(), start, start + dir * 10.0, bullet_speed, bullet_damage * _damage_mult(),
			projectile_element, projectile_color, true)
	Sfx.play(shot_sound, start, shot_volume)
	Fx.muzzle(start, dir, 1.05, projectile_color, 3.5)


## Урон пуль растёт с уровнем этажа так же, как удар (damage уже умножен на уровень).
func _damage_mult() -> float:
	return damage / maxf(_base_damage, 0.01)


func _update_laser(to_player: Vector3) -> void:
	if _laser == null or _player == null:
		return
	var from := global_position + Vector3.UP * 1.0
	var to: Vector3 = _player.global_position + Vector3.UP * 1.0
	var length := from.distance_to(to)
	_laser.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from.lerp(to, 0.5))
	_laser.scale = Vector3(1, 1, length)
	var k := 1.0 - _gun_timer / aim_time
	_laser_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.25 + 0.6 * k)


func _set_laser(on: bool) -> void:
	if on and _laser == null:
		_laser_mat = StandardMaterial3D.new()
		_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_laser_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_laser_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.04, 1.0)
		box.material = _laser_mat
		_laser = MeshInstance3D.new()
		_laser.mesh = box
		_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_laser.top_level = true
		add_child(_laser)
	if _laser != null:
		_laser.visible = on


func _die() -> void:
	_set_laser(false)
	_gun = Gun.NONE
	super()
