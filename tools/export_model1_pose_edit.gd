extends SceneTree
## Выгружает игровые позы в отдельный рабочий файл для ручной настройки в Blender.
const Transfer := preload("res://tools/animation_transfer.gd")
func _initialize() -> void:
	_run.call_deferred()
func _matrix(t: Transform3D) -> Array:
	return [t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z,0,0,0,1]
func _run() -> void:
	var model := preload("res://assets/characters/model1_player.tscn").instantiate()
	root.add_child(model)
	var sk := model.get_node("Armature/Skeleton3D") as Skeleton3D
	var library: AnimationLibrary = load("res://assets/animations/model1_shooter.tres")
	var data := {"rest":{}, "actions":{}}
	for i in sk.get_bone_count(): data.rest[sk.get_bone_name(i)] = _matrix(sk.get_bone_global_rest(i))
	for name in ["SP_idle", "SP_walk_forward"]:
		var clip := library.get_animation(name)
		var frames: Array = []
		for f in range(ceili(clip.length * 30) + 1):
			var poses := Transfer.poses(sk, clip, minf(clip.length,f/30.0))
			var frame := {}
			for i in sk.get_bone_count(): frame[sk.get_bone_name(i)] = _matrix(poses[i])
			frames.append(frame)
		data.actions[name] = frames
	DirAccess.make_dir_recursive_absolute("res://art_source/model1_pose_edit")
	var file := FileAccess.open("res://art_source/model1_pose_edit/game_poses.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	model.free()
	print("MODEL1_POSE_EDIT_EXPORTED")
	quit()
