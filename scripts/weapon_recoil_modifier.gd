extends SkeletonModifier3D
## Импульс плеч и корпуса после наведения; левая рука затем остаётся на цевье.
@export var body: Node3D
var _impulse := 0.0
var _return_speed := 14.0
var _arm := 0.0

func kick(data: WeaponData) -> void:
	_impulse = minf(_impulse + deg_to_rad(data.body_recoil_degrees), deg_to_rad(data.body_recoil_degrees * 1.8))
	_return_speed = data.body_recoil_return
	_arm = data.arm_recoil

func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(body):
		return
	if body.is_dead() or body.is_dodging() or body._recovery_left > 0 or body.is_reloading():
		_impulse = 0
	if _impulse > 0.0001:
		var sk := get_skeleton()
		var axis: Vector3 = sk.global_basis.inverse() * body.global_basis.x
		var bones: Array = [["spine_01", 0.35], ["spine_02", 0.65]]
		# Тяжёлое оружие: ещё грудь и плечи — ствол подбрасывает, корпус откидывает назад.
		if _arm > 0.0:
			bones.append_array([["spine_03", 0.5 * _arm], ["upperarm_r", 0.8 * _arm], ["upperarm_l", 0.6 * _arm], ["Head", -0.4 * _arm]])
		for entry in bones:
			var bone := sk.find_bone(entry[0])
			if bone >= 0:
				var pose := sk.get_bone_global_pose(bone)
				pose.basis = Basis(axis.normalized(), _impulse * entry[1]) * pose.basis
				sk.set_bone_global_pose(bone, pose)
	_impulse *= exp(-_return_speed * delta)
