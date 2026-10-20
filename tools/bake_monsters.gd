extends SceneTree
## Подготавливает существующие боевые движения под новые скелеты монстров.
const Transfer := preload("res://tools/animation_transfer.gd")
const UAL := preload("res://assets/animations/UAL1_Standard.glb")
const UAL2 := preload("res://assets/animations/UAL2_Standard.glb")
const MX := preload("res://assets/animations/mixamo_fitted.tres")
const Base := preload("res://assets/characters/base/Superhero_Male_FullBody.gltf")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var base := Base.instantiate()
	root.add_child(base)
	var source := base.get_node("Armature/Skeleton3D") as Skeleton3D
	var names: Array = [&"Zombie_Idle", &"Zombie_Walk_Fwd", &"MX_Zombie_Run", &"MX_Mutant_Run", &"Zombie_Scratch", &"Sword_Attack", &"Punch_Cross", &"Death01", &"Hit_Knockback", &"Jump_Start", &"Jump_Land", &"Crouch_Idle", &"Walk", &"Jog_Fwd"]
	var once: Array = [&"Zombie_Scratch", &"Sword_Attack", &"Punch_Cross", &"Death01", &"Hit_Knockback", &"Jump_Start", &"Jump_Land"]
	var fitted := _prepare(source, names, once)
	for kind in ["parasite", "mutant"]:
		var model: Node = load("res://assets/characters/" + kind + ".tscn").instantiate()
		root.add_child(model)
		var target := model.get_node("Armature/Skeleton3D") as Skeleton3D
		var library := AnimationLibrary.new()
		for name in names:
			library.add_animation(name, Transfer.bake(source, target, fitted.get_animation(name), name not in once))
		assert(ResourceSaver.save(library, "res://assets/animations/" + kind + ".tres") == OK)
		print("MONSTER_BAKE_OK ", kind, " bones=", target.get_bone_count(), " clips=", names.size())
		model.free()
	base.free()
	quit()

func _prepare(sk: Skeleton3D, names: Array, once: Array) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var rest := UAL.get_animation(&"A_TPose")
	var ratio := 1.0
	for t in rest.get_track_count():
		if rest.track_get_type(t) == Animation.TYPE_POSITION_3D and String(rest.track_get_path(t).get_concatenated_subnames()) == "pelvis":
			ratio = sk.get_bone_rest(sk.find_bone("pelvis")).origin.length() / rest.track_get_key_value(t, 0).length()
	for name in names:
		var src: AnimationLibrary = MX if MX.has_animation(name) else (UAL if UAL.has_animation(name) else UAL2)
		var clip := src.get_animation(name).duplicate(true) as Animation
		for t in range(clip.get_track_count() - 1, -1, -1):
			var kind := clip.track_get_type(t)
			if kind == Animation.TYPE_SCALE_3D or (kind == Animation.TYPE_POSITION_3D and String(clip.track_get_path(t).get_concatenated_subnames()) != "pelvis"):
				clip.remove_track(t)
			elif kind == Animation.TYPE_POSITION_3D and src != MX:
				for k in clip.track_get_key_count(t):
					clip.track_set_key_value(t, k, clip.track_get_key_value(t, k) * ratio)
		clip.loop_mode = Animation.LOOP_NONE if name in once else Animation.LOOP_LINEAR
		library.add_animation(name, clip)
	return library
