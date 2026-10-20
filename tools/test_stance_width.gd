extends SceneTree
## Проверяет ширину, высоту стоп и длины костей во всех направлениях огнестрельной локомоции.
const Transfer := preload("res://tools/animation_transfer.gd")
class BodyStub extends Node3D:
	var fixed_bow_loadout := false
	var _recovery_left := 0.0
	func is_dead() -> bool: return false
	func is_dodging() -> bool: return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var model := preload("res://assets/characters/model1_player.tscn").instantiate()
	root.add_child(model)
	var sk := model.get_node("Armature/Skeleton3D") as Skeleton3D
	var body := BodyStub.new()
	root.add_child(body)
	var modifier := preload("res://scripts/stance_width_modifier.gd").new()
	modifier.body = body
	modifier.max_width = model.max_stance_width
	sk.add_child(modifier)
	var library: AnimationLibrary = load("res://assets/animations/model1_shooter.tres")
	var samples := 0
	for name in library.get_animation_list():
		if name != "SP_idle" and not name.begins_with("SP_walk_") and not name.begins_with("SP_run_") and not name.begins_with("SP_sprint_"): continue
		var clip := library.get_animation(name)
		for frame in 9:
			var poses := Transfer.poses(sk, clip, clip.length * frame / 8.0)
			for i in sk.get_bone_count():
				var parent := sk.get_bone_parent(i)
				var local := poses[parent].affine_inverse() * poses[i] if parent >= 0 else poses[i]
				sk.set_bone_pose_position(i, local.origin)
				sk.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
			var before := {}
			for side in ["l", "r"]:
				for bone in ["thigh_", "calf_", "foot_"]:
					before[bone + side] = sk.get_bone_global_pose(sk.find_bone(bone + side)).origin
			modifier._process_modification_with_delta(1.0 / 60)
			assert(modifier.last_width_after <= modifier.max_width + .005, str(name))
			assert(modifier.last_foot_error < .005, str(name))
			for side in ["l", "r"]:
				var hip := sk.get_bone_global_pose(sk.find_bone("thigh_" + side)).origin
				var knee := sk.get_bone_global_pose(sk.find_bone("calf_" + side)).origin
				var foot := sk.get_bone_global_pose(sk.find_bone("foot_" + side)).origin
				assert(absf(foot.y - before["foot_" + side].y) < .005, str(name))
				assert(absf(hip.distance_to(knee) - before["thigh_" + side].distance_to(before["calf_" + side])) < .0001)
				assert(absf(knee.distance_to(foot) - before["calf_" + side].distance_to(before["foot_" + side])) < .0001)
			samples += 1
	print("STANCE_WIDTH_TEST_OK samples=", samples, " max_width=", modifier.max_width, " unchanged bone lengths and foot heights")
	model.free()
	body.free()
	quit()
