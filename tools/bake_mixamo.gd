extends SceneTree
## Перенос Mixamo на скелет Quaternius без изменения исходных FBX.
## Запуск: Godot --headless --path . --script res://tools/bake_mixamo.gd
const TARGET := preload("res://assets/characters/base/Superhero_Male_FullBody.gltf")
const OUTPUT := "res://assets/animations/mixamo_fitted.tres"
const ONCE := ["Reloading", "Zombie Stand Up", "Running Right Turn"]
const MAP := {
	"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck", "Head": "Head",
	"clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
	"clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
	"thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
	"thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var target := TARGET.instantiate()
	root.add_child(target)
	var sk := target.find_child("Skeleton3D", true, false) as Skeleton3D
	var library := AnimationLibrary.new()
	library.set_meta("pelvis_rest", sk.get_bone_rest(sk.find_bone("pelvis")).origin)
	var files := DirAccess.get_files_at("res://animation")
	for file in files:
		if file.get_extension().to_lower() != "fbx" or file.get_basename() in ["Ch15_nonPBR", "Parasite L Starkie", "Running Dive Roll"]:
			continue
		var packed := load("res://animation/" + file) as PackedScene
		assert(packed != null, "Не удалось загрузить " + file)
		var source := packed.instantiate()
		root.add_child(source)
		var from := source.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(from != null and ap != null)
		var clip: Animation
		for name in ap.get_animation_list():
			if name != "RESET":
				clip = ap.get_animation(name)
		assert(clip != null)
		var name := StringName("MX_" + file.get_basename().replace(" ", "_"))
		var baked := _bake(from, sk, clip, file.get_basename() not in ONCE)
		library.add_animation(name, baked)
		print("BAKED ", name, " duration=", baked.length, " tracks=", baked.get_track_count())
		source.free()
	assert(library.get_animation_list().size() >= 15)
	assert(ResourceSaver.save(library, OUTPUT) == OK)
	target.free()
	print("MIXAMO_BAKE_OK")
	quit()

func _mapping(target: Skeleton3D, source: Skeleton3D) -> Dictionary:
	var names := MAP.duplicate()
	for side in ["l", "r"]:
		for finger in ["index", "middle", "ring", "pinky", "thumb"]:
			for joint in range(1, 4):
				names["%s_%02d_%s" % [finger, joint, side]] = ("Left" if side == "l" else "Right") + "Hand" + finger.capitalize() + str(joint)
	var result := {}
	for i in target.get_bone_count():
		var name := target.get_bone_name(i)
		if names.has(name):
			var source_index := source.find_bone("mixamorig_" + names[name])
			assert(source_index >= 0, "Нет кости " + names[name])
			result[i] = source_index
	return result

func _source_poses(sk: Skeleton3D, clip: Animation, time: float) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for i in sk.get_bone_count():
		poses.append(sk.get_bone_rest(i))
	for t in clip.get_track_count():
		var i := sk.find_bone(String(clip.track_get_path(t).get_concatenated_subnames()))
		if i < 0:
			continue
		match clip.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				poses[i].basis = Basis(clip.rotation_track_interpolate(t, time))
			Animation.TYPE_POSITION_3D:
				poses[i].origin = clip.position_track_interpolate(t, time)
	for i in sk.get_bone_count():
		var parent := sk.get_bone_parent(i)
		if parent >= 0:
			poses[i] = poses[parent] * poses[i]
	return poses

func _bake(source: Skeleton3D, target: Skeleton3D, clip: Animation, looped: bool) -> Animation:
	var mapping := _mapping(target, source)
	var result := Animation.new()
	result.length = clip.length
	result.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	var tracks := {}
	for i in mapping:
		var t := result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(t, NodePath("Armature/Skeleton3D:" + target.get_bone_name(i)))
		tracks[i] = t
	var pelvis := target.find_bone("pelvis")
	var source_hip: int = mapping[pelvis]
	var hip_track := result.add_track(Animation.TYPE_POSITION_3D)
	result.track_set_path(hip_track, NodePath("Armature/Skeleton3D:pelvis"))
	var ratio := target.get_bone_global_rest(pelvis).origin.y / source.get_bone_global_rest(source_hip).origin.y
	var first := _source_poses(source, clip, 0)[source_hip].origin
	var last := _source_poses(source, clip, clip.length)[source_hip].origin
	var steps := maxi(1, ceili(clip.length * 30))
	for frame in range(steps + 1):
		var time := clip.length * frame / steps
		var pose := _source_poses(source, clip, time)
		var globals: Array[Basis] = []
		for i in target.get_bone_count():
			var parent := target.get_bone_parent(i)
			var parent_basis := globals[parent] if parent >= 0 else Basis.IDENTITY
			var global_basis := parent_basis * target.get_bone_rest(i).basis
			if mapping.has(i):
				var from: int = mapping[i]
				global_basis = pose[from].basis * source.get_bone_global_rest(from).basis.inverse() * target.get_bone_global_rest(i).basis
				var local := parent_basis.inverse() * global_basis
				var rotation := local.orthonormalized().get_rotation_quaternion().normalized()
				result.rotation_track_insert_key(tracks[i], time, rotation)
			globals.append(global_basis)
		# Убираем перемещение клипа по полу: движением и столкновениями управляет игрок.
		var hip := pose[source_hip].origin * ratio
		var drift := first.lerp(last, time / maxf(clip.length, 0.001)) * ratio
		hip.x -= drift.x
		hip.z -= drift.z
		var parent_rest := target.get_bone_global_rest(target.get_bone_parent(pelvis))
		result.position_track_insert_key(hip_track, time, parent_rest.affine_inverse() * hip)
	return result
