extends SceneTree
## Отдельная библиотека для Erika: оригинал Ch15 и его анимации не перезаписываются.
const Model := preload("res://scripts/shooter_model.gd")
const Transfer := preload("res://tools/animation_transfer.gd")
const SourceLibrary := preload("res://assets/animations/shooter_native.tres")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := Model.new()
	source.source_path = Model.SOURCE
	root.add_child(source)
	var target := Model.new()
	target.source_path = "res://animation/erika_archer/Erika Archer.fbx"
	target.target_height = 1.8
	root.add_child(target)
	var from := source.get_node("Armature/Skeleton3D") as Skeleton3D
	var to := target.get_node("Armature/Skeleton3D") as Skeleton3D
	for mesh in to.find_children("*", "MeshInstance3D", true, false): print("ERIKA_MESH ", mesh.name)
	var library := AnimationLibrary.new()
	var required := ["SP_idle", "SP_death_from_the_front", "SP_dive_roll", "Pistol_Idle", "Pistol_Aim_Neutral", "Pistol_Reload", "Pistol_Shoot", "MX_Pistol_Run", "MX_Reloading", "SC_rifle_aiming_idle", "SC_firing_rifle", "OverhandThrow"]
	for mode in ["walk", "run", "sprint"]:
		for direction in ["forward", "forward_right", "right", "backward_right", "backward", "backward_left", "left", "forward_left"]:
			required.append("SP_" + mode + "_" + direction)
	for name in required:
		var clip := SourceLibrary.get_animation(name)
		var baked := Transfer.bake(from, to, clip, clip.loop_mode != Animation.LOOP_NONE)
		for key in clip.get_meta_list(): baked.set_meta(key, clip.get_meta(key))
		library.add_animation(name, baked)
		print("ERIKA_BAKE ", name)
	library.set_meta("pelvis_rest", to.get_bone_rest(to.find_bone("pelvis")).origin)
	var source_hand := from.get_bone_global_rest(from.find_bone("hand_r")).basis
	var target_hand := to.get_bone_global_rest(to.find_bone("hand_r")).basis
	library.set_meta("grip_correction", target_hand.inverse() * source_hand * SourceLibrary.get_meta("grip_correction"))
	assert(ResourceSaver.save(library, "res://assets/animations/erika_shooter.tres") == OK)
	source.free()
	target.free()
	print("ERIKA_BAKE_OK: ", required.size(), " full clips, original materials and rig")
	quit()
