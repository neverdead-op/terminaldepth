extends SceneTree
## Перенос одобренных библиотек на отдельный скелет MODEL 1.
const Model := preload("res://scripts/shooter_model.gd")
const Transfer := preload("res://tools/animation_transfer.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := Model.new()
	source.source_path = "res://assets/characters/red_huntress/v1/huntress.glb"
	root.add_child(source)
	var target := Model.new()
	target.source_path = "res://assets/characters/model1/v1/model1.glb"
	root.add_child(target)
	var from := source.get_node("Armature/Skeleton3D") as Skeleton3D
	var to := target.get_node("Armature/Skeleton3D") as Skeleton3D
	# Лук отложен: текущая сборка обновляет только огнестрельный профиль.
	for kind in ["shooter"]:
		var original: AnimationLibrary = load("res://assets/animations/huntress_" + kind + ".tres")
		var library := AnimationLibrary.new()
		for name in original.get_animation_list():
			var clip := original.get_animation(name)
			var baked := Transfer.bake(from, to, clip, clip.loop_mode != Animation.LOOP_NONE)
			for key in clip.get_meta_list(): baked.set_meta(key, clip.get_meta(key))
			library.add_animation(name, baked)
		for key in original.get_meta_list(): library.set_meta(key, original.get_meta(key))
		library.set_meta("pelvis_rest", to.get_bone_rest(to.find_bone("pelvis")).origin)
		if original.has_meta("grip_correction"):
			var old_hand := from.get_bone_global_rest(from.find_bone("hand_r")).basis
			var new_hand := to.get_bone_global_rest(to.find_bone("hand_r")).basis
			library.set_meta("grip_correction", new_hand.inverse() * old_hand * original.get_meta("grip_correction"))
		assert(ResourceSaver.save(library, "res://assets/animations/model1_" + kind + ".tres") == OK)
		print("MODEL1_BAKE_OK ", kind, " clips=", library.get_animation_list().size())
	source.free()
	target.free()
	quit()
