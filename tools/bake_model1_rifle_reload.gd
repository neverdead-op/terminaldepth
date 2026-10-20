extends SceneTree
## Компактная перезарядка: удержание автомата правой рукой, действие левой из FBX.
const Transfer := preload("res://tools/animation_transfer.gd")
const Model := preload("res://scripts/shooter_model.gd")
const OUTPUT := "res://assets/animations/model1_shooter.tres"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var backup := "res://art_source/model1_before_reload_" + str(Time.get_unix_time_from_system()).replace(".","_")
	assert(DirAccess.make_dir_recursive_absolute(backup)==OK)
	var ignore:=FileAccess.open(backup+"/.gdignore",FileAccess.WRITE)
	ignore.close()
	assert(DirAccess.copy_absolute(OUTPUT,backup+"/model1_shooter.tres")==OK)
	var model:=Model.new()
	model.source_path="res://assets/characters/model1/v1/model1.glb"
	root.add_child(model)
	var sk:=model.get_node("Armature/Skeleton3D") as Skeleton3D
	var source:Node3D=load("res://animation/Reloading.fbx").instantiate()
	root.add_child(source)
	var from:=source.find_child("Skeleton3D",true,false) as Skeleton3D
	var ap:=source.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var source_clip:Animation
	for name in ap.get_animation_list():
		if name!="RESET":source_clip=ap.get_animation(name)
	assert(source_clip!=null)
	var action:=Transfer.bake(from,sk,source_clip,false)
	var lib:=load(OUTPUT) as AnimationLibrary
	var hold:=lib.get_animation("SC_rifle_aiming_idle")
	var result:=Animation.new()
	result.length=action.length
	result.loop_mode=Animation.LOOP_NONE
	var left:Array[int]=[]
	var stack:Array[int]=[sk.find_bone("clavicle_l")]
	while not stack.is_empty():
		var b:int=stack.pop_back();left.append(b);stack.append_array(sk.get_bone_children(b))
	var tracks:Array[int]=[]
	for i in sk.get_bone_count():
		var t:=result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(t,NodePath("Armature/Skeleton3D:"+sk.get_bone_name(i)))
		tracks.append(t)
	var frames:=ceili(result.length*30)
	for f in frames+1:
		var phase:=float(f)/frames
		var time:=result.length*phase
		var baseline:=Transfer.poses(sk,hold,fmod(time,hold.length))
		var motion:=Transfer.poses(sk,action,time)
		var weight:=smoothstep(0.,.12,phase)*(1.-smoothstep(.82,1.,phase))
		for i in sk.get_bone_count():
			var parent:=sk.get_bone_parent(i)
			var base_local:=baseline[parent].basis.inverse()*baseline[i].basis if parent>=0 else baseline[i].basis
			var rotation:=base_local.orthonormalized().get_rotation_quaternion()
			if i in left:
				var action_local:=motion[parent].basis.inverse()*motion[i].basis
				rotation=rotation.slerp(action_local.orthonormalized().get_rotation_quaternion(),weight)
			result.rotation_track_insert_key(tracks[i],time,rotation.normalized())
	result.set_meta("source_file","res://animation/Reloading.fbx")
	result.set_meta("compact_rifle_reload",true)
	lib.remove_animation("MX_Reloading");lib.add_animation("MX_Reloading",result)
	assert(ResourceSaver.save(lib,OUTPUT)==OK)
	print("COMPACT_RIFLE_RELOAD_OK seconds=",result.length," left_bones=",left.size()," backup=",backup)
	source.free();model.free();quit()
