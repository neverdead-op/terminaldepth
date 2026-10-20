extends SkeletonModifier3D
## Original pose following for the coat; no cloth physics or wind.
@export_range(0.0, 1.0) var follow := 0.72
@export_range(1.0, 30.0) var response := 12.0
var _rotations: Dictionary = {}

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	for side in ["l", "r"]:
		var panel := sk.find_bone("coat_" + side)
		var thigh := sk.find_bone("thigh_" + side)
		if panel < 0 or thigh < 0: continue
		var rest := sk.get_bone_rest(panel).basis
		var motion := sk.get_bone_pose_rotation(thigh) * sk.get_bone_rest(thigh).basis.get_rotation_quaternion().inverse()
		var previous: Quaternion = _rotations.get(side, Quaternion.IDENTITY)
		var rotation := previous.slerp(Quaternion.IDENTITY.slerp(motion, follow), 1.0 - exp(-response * delta))
		_rotations[side] = rotation
		sk.set_bone_pose_rotation(panel, (Basis(rotation) * rest).get_rotation_quaternion())
