extends RefCounted
## Two-bone solver used only by the animation baker.
func _reach(sk: Skeleton3D, side: String, world_goal: Vector3, world_pole: Vector3, weight: float) -> void:
	var upper := sk.find_bone("upperarm_" + side)
	var lower := sk.find_bone("lowerarm_" + side)
	var hand := sk.find_bone("hand_" + side)
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var c := sk.get_bone_global_pose(hand).origin
	var goal := c.lerp(sk.to_local(world_goal), weight)
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var ray := goal - a
	if ray.length_squared() < 0.0001: return
	var direction := ray.normalized()
	var distance := clampf(ray.length(), absf(first - second) + 0.005, (first + second) * 0.985)
	goal = a + direction * distance
	var pole := sk.to_local(world_pole) - a
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 0.0001: pole = Vector3.UP
	pole = pole.normalized()
	var along := (first * first - second * second + distance * distance) / (2 * distance)
	var elbow := a + direction * along + pole * sqrt(maxf(0, first * first - along * along))
	var upper_pose := sk.get_bone_global_pose(upper)
	upper_pose.basis = Basis(Quaternion((b-a).normalized(), (elbow-a).normalized())) * upper_pose.basis
	sk.set_bone_global_pose(upper, upper_pose)
	b = sk.get_bone_global_pose(lower).origin
	c = sk.get_bone_global_pose(hand).origin
	var lower_pose := sk.get_bone_global_pose(lower)
	lower_pose.basis = Basis(Quaternion((c-b).normalized(), (goal-b).normalized())) * lower_pose.basis
	sk.set_bone_global_pose(lower, lower_pose)
