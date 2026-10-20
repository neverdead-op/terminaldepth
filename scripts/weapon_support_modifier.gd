extends SkeletonModifier3D
## Подводит левую ладонь к оружию, сохраняя естественное направление локтя из анимации.
@export var body: Node3D
@export var blend_speed := 16.0
var _weight := 0.0
var last_error := 0.0

func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(body):
		return
	var data: WeaponData = body.current_weapon()
	if data != null and data.icon == &"bow": return
	var animator: AnimationTree = body.get_node("Animator")
	var enabled: bool = data != null and data.support_hand_enabled and data.projectile != &"mine" and not body.is_dead() and not body.is_dodging() and not body.is_sprinting()
	enabled = enabled and animator._state != &"Roll" and not animator.get("parameters/reload/active") and not animator.get("parameters/throw/active")
	enabled = enabled and (data.icon != &"pistol" or body.is_firing())
	enabled = enabled and not body.weapon_stats(body.current_weapon_index()).get("dual", false)
	_weight = move_toward(_weight, 1.0 if enabled else 0.0, blend_speed * delta)
	if _weight < 0.001:
		return
	var sk := get_skeleton()
	var upper := sk.find_bone("upperarm_l")
	var lower := sk.find_bone("lowerarm_l")
	var hand := sk.find_bone("hand_l")
	var right := sk.find_bone("hand_r")
	if mini(mini(upper, lower), mini(hand, right)) < 0:
		return
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var hand_pose := sk.get_bone_global_pose(hand)
	var c := hand_pose.origin
	var offset := data.support_hand_offset
	if data.icon == &"pistol":
		offset = data.pistol_support_offset
	var target: Vector3 = sk.get_bone_global_pose(right) * body.gun.transform * offset
	target = c.lerp(target, _weight)
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var ray := target - a
	if ray.length() < 0.001 or first < 0.001 or second < 0.001:
		return
	var direction := ray.normalized()
	var distance := clampf(ray.length(), absf(first - second) + 0.005, (first + second) * 0.985)
	var goal := a + direction * distance
	var pole := b - a - direction * (b - a).dot(direction)
	if pole.length_squared() < 0.0001:
		pole = Vector3.LEFT - direction * Vector3.LEFT.dot(direction)
	pole = pole.normalized()
	var along := (first * first + distance * distance - second * second) / (2 * distance)
	var elbow := a + direction * along + pole * sqrt(maxf(0, first * first - along * along))
	var pose := sk.get_bone_global_pose(upper)
	pose.basis = Basis(Quaternion((b - a).normalized(), (elbow - a).normalized())) * pose.basis
	sk.set_bone_global_pose(upper, pose)
	pose = sk.get_bone_global_pose(lower)
	var end := sk.get_bone_global_pose(hand).origin
	pose.basis = Basis(Quaternion((end - pose.origin).normalized(), (goal - pose.origin).normalized())) * pose.basis
	sk.set_bone_global_pose(lower, pose)
	pose = sk.get_bone_global_pose(hand)
	pose.basis = hand_pose.basis
	sk.set_bone_global_pose(hand, pose)
	last_error = pose.origin.distance_to(target)
