extends SkeletonModifier3D
## Сужает постановку ног после переноса анимаций, сохраняя длины костей и поворот стоп.
@export var body: Node3D
@export_range(0.2, 0.6, 0.01) var max_width := 0.4
var last_width_before := 0.0
var last_width_after := 0.0
var last_foot_error := 0.0

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(body) or body.fixed_bow_loadout or body.is_dead() or body.is_dodging() or body._recovery_left > 0:
		return
	var sk := get_skeleton()
	var pelvis := sk.find_bone("pelvis")
	var left := sk.find_bone("foot_l")
	var right := sk.find_bone("foot_r")
	if mini(pelvis, mini(left, right)) < 0: return
	var hips := sk.get_bone_global_pose(pelvis)
	var axis := hips.basis * sk.get_bone_global_rest(pelvis).basis.inverse() * Vector3.RIGHT
	axis.y = 0
	if axis.length_squared() < .01: return
	axis = axis.normalized()
	last_width_before = absf((sk.get_bone_global_pose(left).origin - sk.get_bone_global_pose(right).origin).dot(axis))
	last_foot_error = 0.0
	for side in ["l", "r"]:
		var upper := sk.find_bone("thigh_" + side)
		var lower := sk.find_bone("calf_" + side)
		var foot := sk.find_bone("foot_" + side)
		if mini(upper, mini(lower, foot)) < 0: continue
		var foot_pose := sk.get_bone_global_pose(foot)
		var lateral := (foot_pose.origin - hips.origin).dot(axis)
		var shift := clampf(lateral, -max_width * .5, max_width * .5) - lateral
		if absf(shift) < .0001: continue
		var target := foot_pose.origin + axis * shift
		var a := sk.get_bone_global_pose(upper).origin
		var b := sk.get_bone_global_pose(lower).origin
		var c := foot_pose.origin
		var first := a.distance_to(b)
		var second := b.distance_to(c)
		var ray := target - a
		if minf(first, second) < .001 or ray.length() < .001: continue
		var direction := ray.normalized()
		var distance := clampf(ray.length(), absf(first - second) + .001, first + second - .001)
		var goal := a + direction * distance
		var pole := b - a - direction * (b - a).dot(direction)
		# Сохраняем плоскость сгиба исходного колена.
		if pole.length_squared() < .00001:
			pole = Vector3.BACK - direction * Vector3.BACK.dot(direction)
		if pole.length_squared() < .00001: continue
		pole = pole.normalized()
		var along := (first * first + distance * distance - second * second) / (2 * distance)
		var knee := a + direction * along + pole * sqrt(maxf(0, first * first - along * along))
		var pose := sk.get_bone_global_pose(upper)
		pose.basis = Basis(Quaternion((b - a).normalized(), (knee - a).normalized())) * pose.basis
		sk.set_bone_global_pose(upper, pose)
		pose = sk.get_bone_global_pose(lower)
		var end := sk.get_bone_global_pose(foot).origin
		pose.basis = Basis(Quaternion((end - pose.origin).normalized(), (goal - pose.origin).normalized())) * pose.basis
		sk.set_bone_global_pose(lower, pose)
		pose = sk.get_bone_global_pose(foot)
		pose.basis = foot_pose.basis
		sk.set_bone_global_pose(foot, pose)
		last_foot_error = maxf(last_foot_error, pose.origin.distance_to(target))
	last_width_after = absf((sk.get_bone_global_pose(left).origin - sk.get_bone_global_pose(right).origin).dot(axis))
