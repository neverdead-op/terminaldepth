extends SceneTree
## Общий перенос нижней части движения; по умолчанию обновляет шаг вперёд новой модели.
const Transfer := preload("res://tools/animation_transfer.gd")
const Model := preload("res://scripts/shooter_model.gd")
const SOURCE := "res://animation/Walking 1 test.fbx"
var source_path := SOURCE
var target_clips: Array[String] = ["SP_walk_forward"]
## Лук отложен: его библиотеку обновляем только при явном запросе.
var target_libraries: Array[String] = ["shooter"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source: Node3D = load(source_path).instantiate()
	root.add_child(source)
	var from := source.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(from != null and ap != null)
	var clip: Animation
	var max_keys := 0
	for name in ap.get_animation_list():
		if name != "RESET":
			var candidate := ap.get_animation(name)
			var keys := 0
			for t in candidate.get_track_count(): keys += candidate.track_get_key_count(t)
			# FBX также содержит неподвижный Take 001; выбираем дорожку с настоящими ключами шага.
			if keys > max_keys:
				max_keys = keys
				clip = candidate
	assert(clip != null)
	var target := Model.new()
	target.source_path = "res://assets/characters/model1/v1/model1.glb"
	root.add_child(target)
	var to := target.get_node("Armature/Skeleton3D") as Skeleton3D
	var baked := Transfer.bake(from, to, clip, true)
	var hip := -1
	var feet: Array[int] = []
	for i in from.get_bone_count():
		var alias := Model.bone_alias(from.get_bone_name(i))
		if alias == "pelvis": hip = i
		if alias in ["foot_l", "foot_r"]: feet.append(i)
	assert(hip >= 0 and feet.size() == 2)
	var ratio := to.get_bone_global_rest(to.find_bone("pelvis")).origin.y / from.get_bone_global_rest(hip).origin.y
	var samples: Array = []
	var minima := [INF, INF]
	for f in 61:
		var poses := Transfer.poses(from, clip, clip.length * f / 60.0)
		var root_motion := Vector3(poses[hip].origin.x, 0, poses[hip].origin.z) * ratio
		var pair := [poses[feet[0]].origin * ratio - root_motion, poses[feet[1]].origin * ratio - root_motion]
		for side in 2: minima[side] = minf(minima[side], pair[side].y)
		samples.append(pair)
	var speeds: Array[float] = []
	for f in range(1, 61):
		for side in 2:
			var a: Vector3 = samples[f - 1][side]
			var b: Vector3 = samples[f][side]
			var speed := absf(b.z - a.z) / (clip.length / 60.0)
			if maxf(a.y, b.y) < minima[side] + 0.035 and speed > 0.2:
				speeds.append(speed)
	assert(not speeds.is_empty())
	speeds.sort()
	var stride_speed := speeds[speeds.size() / 2]
	for kind in target_libraries:
		var path: String = "res://assets/animations/model1_" + kind + ".tres"
		var library: AnimationLibrary = load(path)
		for clip_name in target_clips:
			_replace_lower(library, clip_name, baked, stride_speed)
		assert(ResourceSaver.save(library, path) == OK)
		print("LOCOMOTION_BAKE_OK ", kind, " source=", source_path, " clips=", target_clips, " seconds=", baked.length, " stride_speed=", stride_speed)
	source.free()
	target.free()
	quit()

func _replace_lower(library: AnimationLibrary, clip_name: String, baked: Animation, stride_speed: float) -> void:
	var lower := ["pelvis", "spine_01", "thigh_l", "calf_l", "foot_l", "ball_l", "ball_leaf_l", "thigh_r", "calf_r", "foot_r", "ball_r", "ball_leaf_r"]
	var merged := library.get_animation(clip_name).duplicate(true) as Animation
	# Сохраняем прежние движения верха; новое движение таза и ног не зависит от оружия.
	for t in range(merged.get_track_count() - 1, -1, -1):
		if String(merged.track_get_path(t).get_concatenated_subnames()) in lower:
			merged.remove_track(t)
		else:
			for k in merged.track_get_key_count(t):
				merged.track_set_key_time(t, k, merged.track_get_key_time(t, k) * baked.length / merged.length)
	for t in baked.get_track_count():
		if String(baked.track_get_path(t).get_concatenated_subnames()) in lower:
			baked.copy_track(t, merged)
	merged.length = baked.length
	merged.loop_mode = Animation.LOOP_LINEAR
	merged.set_meta("source_file", source_path)
	merged.set_meta("locomotion_speed", stride_speed)
	library.remove_animation(clip_name)
	library.add_animation(clip_name, merged)
