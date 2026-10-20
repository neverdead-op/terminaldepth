extends SceneTree
const Transfer:=preload("res://tools/animation_transfer.gd")
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
 var model:=preload("res://assets/characters/huntress_player.tscn").instantiate();root.add_child(model)
 var sk:Skeleton3D=model.get_node("Armature/Skeleton3D")
 var lib:AnimationLibrary=load(model.animation_library_path)
 var clip:=lib.get_animation("Bow_Shot")
 var release:float=clip.get_meta("release_time")
 var begin:float=clip.get_meta("recoil_begin")
 assert(lib.get_meta("bow_combat_sources") and clip.get_meta("source_files").size()==3)
 var hand:=sk.find_bone("hand_r")
 var before:=Transfer.poses(sk,clip,release-.035)
 var after:=Transfer.poses(sk,clip,release+.17)
 var movement:=before[hand].origin.distance_to(after[hand].origin)
 assert(movement>.05,"Real recoil must move the right hand")
 # After its short transition the composite must match the supplied recoil.
 var source:=Transfer.poses(sk,lib.get_animation("BC_recoil"),.25)
 var actual:=Transfer.poses(sk,clip,begin+.25)
 for name in ["hand_l","hand_r","Head","upperarm_l","upperarm_r"]:
  var bone:=sk.find_bone(name)
  assert(actual[bone].basis.get_rotation_quaternion().angle_to(source[bone].basis.get_rotation_quaternion())<.015,"Source animation changed: "+name)
 var max_up:float=-1
 for f in 61:
  var poses:=Transfer.poses(sk,clip,clip.length*f/60.0)
  var head:=sk.find_bone("Head")
  var forward:=poses[head].basis*sk.get_bone_global_rest(head).basis.inverse()*Vector3.BACK
  max_up=maxf(max_up,forward.normalized().y)
 assert(max_up<.45,"Retargeting tips the head back")
 assert(lib.get_animation("SP_dive_roll").get_meta("source_file").ends_with("dive.fbx"))
 for mode in ["run","walk"]:
  for direction in ["forward","left","right"]:
   assert(lib.get_animation("SP_"+mode+"_"+direction).get_meta("source_file").ends_with(mode+"_"+direction+".fbx"))
 print("BOW_ACTION_TEST_OK: real FBX recoil, source rotations preserved, hand_motion=",movement," max_head_up=",max_up," release=",release," cycle=",clip.length)
 model.free();quit()
