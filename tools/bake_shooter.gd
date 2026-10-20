extends SceneTree
## Собирает родную библиотеку Shooter Pack; FBX и архивы не изменяет.
const Transfer := preload("res://tools/animation_transfer.gd")
const Model := preload("res://assets/characters/shooter_model.tscn")
const OldModel := preload("res://assets/characters/base/Superhero_Male_FullBody.gltf")
const LEGACY := preload("res://assets/animations/UAL1_Standard.glb")
const LEGACY2 := preload("res://assets/animations/UAL2_Standard.glb")
var _library := AnimationLibrary.new()
var _target: Skeleton3D

func _initialize() -> void:
	_run.call_deferred()

func _clip(ap: AnimationPlayer) -> Animation:
	if ap.has_animation(&"mixamo_com"):
		return ap.get_animation(&"mixamo_com")
	for name in ap.get_animation_list():
		if name != "RESET":
			return ap.get_animation(name)
	return null

func _add_file(path: String, name: StringName, looped: bool) -> void:
	var source: Node = load(path).instantiate()
	root.add_child(source)
	var sk := source.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(sk != null and ap != null)
	var clip := _clip(ap)
	var baked := Transfer.bake(sk, _target, clip, looped)
	# Скорость поступательного движения из исходника, с учётом роста модели.
	var hip := -1
	for i in sk.get_bone_count():
		if String(sk.get_bone_name(i)).ends_with("Hips"):
			hip = i
	if hip >= 0:
		var first := Transfer.poses(sk, clip, 0)[hip].origin
		var last := Transfer.poses(sk, clip, clip.length)[hip].origin
		var target_hip := _target.get_bone_global_rest(_target.find_bone("pelvis")).origin.y
		var ratio := target_hip / sk.get_bone_global_rest(hip).origin.y
		var stride_speed := Vector2(last.x - first.x, last.z - first.z).length() * ratio / maxf(clip.length, 0.01)
		if stride_speed > 0.1:
			baked.set_meta("locomotion_speed", stride_speed)
	_library.add_animation(name, baked)
	print("SHOOTER ", name)
	source.free()

func _run() -> void:
	var model := Model.instantiate()
	root.add_child(model)
	_target = model.get_node("Armature/Skeleton3D")
	_library.set_meta("pelvis_rest", _target.get_bone_rest(_target.find_bone("pelvis")).origin)
	for folder in ["locomotion", "combat"]:
		var base: String = "res://animation/shooter pack/" + folder + "/"
		for file in DirAccess.get_files_at(base):
			if file.get_extension().to_lower() == "fbx":
				var name := StringName(("SP_" if folder == "locomotion" else "SC_") + file.get_basename().replace(" ", "_").replace("(", "").replace(")", ""))
				var once := file.contains("death") or file.contains("dying") or file.contains("jump") or file.contains("turn") or file.contains("start") or file.contains("stop")
				_add_file(base + file, name, not once)
	_add_file("res://animation/Pistol Run.fbx", &"MX_Pistol_Run", true)
	_add_file("res://animation/Reloading.fbx", &"MX_Reloading", false)
	_add_file("res://animation/Running Dive Roll.fbx", &"SP_dive_roll", false)
	_prepare_full_roll("res://animation/Running Dive Roll.fbx", &"SP_dive_roll")
	for file in DirAccess.get_files_at("res://animation/roll"):
		if file.get_extension().to_lower() == "fbx":
			_add_file("res://animation/roll/" + file, StringName("DR_" + file.get_basename().replace(" ", "_")), false)
	for file in DirAccess.get_files_at("res://animation/pack 12/action"):
		if file.get_extension().to_lower() == "fbx" and file != "X Bot.fbx":
			var name := StringName("AA_" + file.get_basename().replace(" ", "_").replace("(", "").replace(")", ""))
			_add_file("res://animation/pack 12/action/" + file, name, file.begins_with("idle") or file in ["running.fbx", "walking.fbx", "falling idle.fbx"])

	var old := OldModel.instantiate()
	root.add_child(old)
	var sk := old.find_child("Skeleton3D", true, false) as Skeleton3D
	_library.set_meta("grip_correction", _target.get_bone_global_rest(_target.find_bone("hand_r")).basis.inverse() * sk.get_bone_global_rest(sk.find_bone("hand_r")).basis)
	# Пока отдельного родного переката и броска нет — переносим проверенные клипы.
	for name in [&"Roll", &"Pistol_Idle", &"Pistol_Aim_Neutral", &"Pistol_Shoot", &"Pistol_Reload", &"OverhandThrow"]:
		var lib: AnimationLibrary = LEGACY if LEGACY.has_animation(name) else LEGACY2
		_library.add_animation(name, Transfer.bake(sk, _target, lib.get_animation(name), false))
	assert(ResourceSaver.save(_library, "res://assets/animations/shooter_native.tres") == OK)
	print("SHOOTER_BAKE_OK: ", _library.get_animation_list().size(), " animations")
	old.free()
	model.free()
	quit()

## Полный Running Dive Roll: исходная поза и нормированная траектория для физики.
func _prepare_full_roll(path: String, name: StringName) -> void:
	var source: Node = load(path).instantiate()
	root.add_child(source)
	var sk := source.find_child("Skeleton3D", true, false) as Skeleton3D
	var clip := _clip(source.find_child("AnimationPlayer", true, false))
	var hip := -1
	for i in sk.get_bone_count():
		if String(sk.get_bone_name(i)).ends_with("Hips"):
			hip = i
	var first := Transfer.poses(sk, clip, 0)[hip].origin
	var last := Transfer.poses(sk, clip, clip.length)[hip].origin
	var distance := absf(last.z - first.z)
	var profile := PackedFloat32Array()
	var baked := _library.get_animation(name)
	for i in 65:
		var time := clip.length * i / 64.0
		var at := Transfer.poses(sk, clip, time)[hip].origin
		profile.append(clampf(absf(at.z - first.z) / distance, 0, 1))
	for t in baked.get_track_count():
		if baked.track_get_type(t) == Animation.TYPE_POSITION_3D:
			for k in baked.track_get_key_count(t):
				var at: Vector3 = baked.track_get_key_value(t, k)
				at.x = 0
				at.z = 0
				baked.track_set_key_value(t, k, at)
	baked.set_meta("motion_profile", profile)
	baked.set_meta("source_distance", distance)
	source.free()
