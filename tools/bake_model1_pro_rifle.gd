extends SceneTree
## Перенос единого набора движения X Bot на действующий скелет MODEL 1.
const Transfer := preload("res://tools/animation_transfer.gd")
const Model := preload("res://scripts/shooter_model.gd")
const BASE := "res://animation/Pro Rifle Pack/"
const OUTPUT := "res://assets/animations/model1_shooter.tres"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var backup := "res://art_source/model1_before_pro_rifle_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	assert(DirAccess.make_dir_recursive_absolute(backup) == OK)
	var ignore := FileAccess.open(backup + "/.gdignore", FileAccess.WRITE)
	ignore.close()
	assert(DirAccess.copy_absolute(OUTPUT, backup + "/model1_shooter.tres") == OK)
	var library := load(OUTPUT) as AnimationLibrary
	var target := Model.new()
	target.source_path = "res://assets/characters/model1/v1/model1.glb"
	root.add_child(target)
	var to := target.get_node("Armature/Skeleton3D") as Skeleton3D
	var count := 0
	for mode in ["walk", "run", "sprint", "idle"]:
		var directions := [""] if mode == "idle" else ["forward", "forward right", "right", "backward right", "backward", "backward left", "left", "forward left"]
		for direction in directions:
			var file: String = mode + (" " + direction if direction != "" else "") + ".fbx"
			var source := load(BASE + file).instantiate() as Node3D
			root.add_child(source)
			var from := source.find_child("Skeleton3D", true, false) as Skeleton3D
			var ap := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
			assert(from != null and ap != null)
			var clip: Animation
			var max_keys := -1
			for name in ap.get_animation_list():
				if name == "RESET": continue
				var candidate := ap.get_animation(name)
				var keys := 0
				for t in candidate.get_track_count(): keys += candidate.track_get_key_count(t)
				if keys > max_keys:
					clip = candidate
					max_keys = keys
			assert(clip != null and max_keys > 0)
			var baked := Transfer.bake(from, to, clip, true, PackedStringArray(["thigh_l", "calf_l", "thigh_r", "calf_r"]))
			baked.set_meta("leg_axis_alignment", true)
			baked.set_meta("source_file", BASE + file)
			if mode != "idle": baked.set_meta("locomotion_speed", _stride_speed(from, to, clip))
			var id := StringName("SP_" + file.get_basename().replace(" ", "_"))
			assert(library.has_animation(id))
			library.remove_animation(id)
			library.add_animation(id, baked)
			print("PRO_RIFLE_CLIP ", id, " seconds=", baked.length, " speed=", baked.get_meta("locomotion_speed", 0.0))
			count += 1
			source.free()
	assert(count == 25)
	library.set_meta("locomotion_source", BASE)
	assert(ResourceSaver.save(library, OUTPUT) == OK)
	target.free()
	print("PRO_RIFLE_BAKE_OK clips=", count, " backup=", backup, " weapon actions and roll preserved")
	quit()

func _stride_speed(from: Skeleton3D, to: Skeleton3D, clip: Animation) -> float:
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
		var pose := Transfer.poses(from, clip, clip.length * f / 60.0)
		var root_motion := Vector3(pose[hip].origin.x, 0, pose[hip].origin.z)
		var pair := [(pose[feet[0]].origin - root_motion) * ratio, (pose[feet[1]].origin - root_motion) * ratio]
		for side in 2: minima[side] = minf(minima[side], pair[side].y)
		samples.append(pair)
	var speeds: Array[float] = []
	for f in range(1, 61):
		for side in 2:
			var a: Vector3 = samples[f - 1][side]
			var b: Vector3 = samples[f][side]
			var speed := Vector2(b.x - a.x, b.z - a.z).length() / (clip.length / 60.0)
			if maxf(a.y, b.y) < minima[side] + .035 and speed > .2: speeds.append(speed)
	assert(not speeds.is_empty())
	speeds.sort()
	return speeds[speeds.size() / 2]
