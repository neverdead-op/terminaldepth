extends SkeletonModifier3D
## Доворачивает грудь с двуручным оружием к прицелу после смешивания ног и рук.
## При перезарядке, броске и перекате руки свободно следуют своей анимации.
@export var blend_speed := 12.0
@export var body: Node3D
var _weight := 0.0
var facing_dot := 0.0

func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(body):
		return
	var animator := body.get_node_or_null("Animator") as AnimationTree
	var data: WeaponData = body.weapon_data(body.current_weapon_index())
	if data != null and data.icon == &"bow": return
	var ready: bool = data != null and (data.icon not in [&"pistol", &"mines"] or (body.get_node("Model").has_meta("native_shooter") and data.icon == &"pistol")) and not body.is_dead() and not body.is_dodging() and not body.is_sprinting()
	# В спокойной пистолетной позе грудь и свободная рука следуют анимации.
	if data != null and data.icon == &"pistol":
		ready = ready and body.is_firing()
	if animator != null:
		ready = ready and animator._state != &"Roll" and not animator.get("parameters/reload/active") and not animator.get("parameters/throw/active")
	_weight = move_toward(_weight, 1.0 if ready else 0.0, blend_speed * delta)
	if _weight <= 0:
		return
	var skeleton := get_skeleton()
	var chest := skeleton.find_bone("spine_02")
	var hand := skeleton.find_bone("hand_r")
	if chest < 0 or hand < 0:
		return
	var forward: Vector3 = -(skeleton.global_basis * skeleton.get_bone_global_pose(hand).basis * body._gun_base.basis).z
	# В спокойном хвате сохраняем положение оружия, выравниваем только взгляд.
	# Иначе поворот таза из Rifle Idle складывается с поворотом перенесённой стойки.
	var resting_weapon: bool = not body.is_firing()
	if resting_weapon:
		var head := skeleton.find_bone("Head")
		if head >= 0:
			forward = skeleton.global_basis * skeleton.get_bone_global_pose(head).basis.z
	var desired: Vector3 = -body.global_basis.z
	if forward.length_squared() < 0.001:
		return
	# Наводим по вертикали и азимуту отдельно: кратчайший 3D-поворот наклонял плечи набок.
	var flat := Vector3(forward.x, 0, forward.z)
	if flat.length_squared() < 0.001:
		return
	var yaw := flat.normalized().signed_angle_to(desired.normalized(), Vector3.UP)
	var turn := Basis(Vector3.UP, yaw)
	var pitched := turn * forward.normalized()
	var pitch := 0.0 if resting_weapon else pitched.signed_angle_to(desired.normalized(), body.global_basis.x)
	var rotation := (Basis(body.global_basis.x, pitch) * turn).get_rotation_quaternion()
	var correction := Basis(Quaternion.IDENTITY.slerp(rotation, _weight))
	var local := skeleton.global_basis.inverse() * correction * skeleton.global_basis
	var pose := skeleton.get_bone_global_pose(chest)
	pose.basis = local * pose.basis
	skeleton.set_bone_global_pose(chest, pose)
	var corrected: Vector3
	if resting_weapon:
		corrected = skeleton.global_basis * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).basis.z
	else:
		corrected = -(skeleton.global_basis * skeleton.get_bone_global_pose(hand).basis * body._gun_base.basis).z
	corrected.y = 0
	facing_dot = corrected.normalized().dot(desired.normalized())
