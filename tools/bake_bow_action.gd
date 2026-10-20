extends SceneTree
## Authored bow action baked onto the huntress rig. No runtime arm pinning.
const Transfer := preload("res://tools/animation_transfer.gd")
const Reach := preload("res://tools/bow_action_ik.gd")
var sk: Skeleton3D
var reach: RefCounted
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var model := preload("res://assets/characters/huntress_player.tscn").instantiate()
 model.rotation.y = PI
 root.add_child(model)
 sk = model.get_node("Armature/Skeleton3D")
 # Disable runtime coat modifiers while sampling the authored action.
 for child in sk.get_children():
  if child is SkeletonModifier3D: child.active = false
 reach = Reach.new()
 var lib: AnimationLibrary = load("res://assets/animations/huntress_archery.tres").duplicate(true)
 var base := lib.get_animation("Bow_Idle")
 var clip := Animation.new()
 clip.length = 1.16
 var tracks := []
 for i in sk.get_bone_count():
  var track := clip.add_track(Animation.TYPE_ROTATION_3D)
  clip.track_set_path(track, NodePath("Armature/Skeleton3D:" + sk.get_bone_name(i)))
  tracks.append(track)
 for f in 71:
  var t := clip.length * f / 70.0
  var poses := Transfer.poses(sk, base, t)
  for i in sk.get_bone_count(): sk.set_bone_global_pose(i, poses[i])
  var raise := smoothstep(.05, .30, t) * (1.0 - smoothstep(.96, 1.16, t))
  var draw := smoothstep(.30, .74, t)
  var loose := smoothstep(.74, .80, t)
  var recover := smoothstep(.90, 1.16, t)
  var recoil := sin(clampf((t-.74)/.20, 0, 1) * PI)
  # Turn the chest side-on, with a small forward weight transfer, then unwind.
  for pair in [["spine_01", .35], ["spine_02", .35], ["spine_03", .30]]:
   var i := sk.find_bone(pair[0])
   var pose := sk.get_bone_global_pose(i)
   var axis := sk.global_basis.inverse() * Vector3.UP
   pose.basis = Basis(axis.normalized(), (-.40*raise + recoil*.09)*pair[1]) * pose.basis
   sk.set_bone_global_pose(i, pose)
  # The original rest head faces forward. Preserve that orientation in world
  # space instead of inheriting the source idle's neck pitch or chest twist.
  for name in ["neck_01", "Head"]:
   var i := sk.find_bone(name)
   var pose := sk.get_bone_global_pose(i)
   pose.basis = sk.get_bone_global_rest(i).basis
   sk.set_bone_global_pose(i, pose)
  var bow := Vector3(.04, lerpf(.96, 1.40, raise), -lerpf(.16,.57,raise))
  bow += Vector3(0, recoil*.018, recoil*.025)
  reach._reach(sk, "l", bow, bow + Vector3(-.25,-.12,.06), 1.0)
  var left := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_l"))
  var nock := left.origin + Vector3(0,-.02,-.05) + Vector3(draw*.12, draw*.03, .196+draw*.38)
  var right := Vector3(.24,.94,-.08).lerp(nock, raise)
  right += Vector3(loose*.12, loose*.025, loose*.10) * (1.0-recover)
  reach._reach(sk,"r",right,Vector3(.60,1.43,.25).lerp(Vector3(.43,1.0,.05),1.0-raise),1.0)
  for side in ["l", "r"]:
   var hand := sk.find_bone("hand_"+side)
   var finger := sk.find_bone("index_01_"+side)
   var pose := sk.get_bone_global_pose(hand)
   var axis := sk.get_bone_global_pose(finger).origin - pose.origin
   var desired := sk.global_basis.inverse() * Vector3(0,-.60,-.80)
   pose.basis = Basis(Quaternion(axis.normalized(),desired.normalized())) * pose.basis
   sk.set_bone_global_pose(hand,pose)
  for i in sk.get_bone_count():
   clip.rotation_track_insert_key(tracks[i],t,sk.get_bone_pose_rotation(i))
 clip.set_meta("release_time", .74)
 clip.set_meta("source", "Authored action over Longbow idle; no downloaded shooting clip")
 if lib.has_animation("Bow_Shot"):lib.remove_animation("Bow_Shot")
 lib.add_animation("Bow_Shot",clip)
 var rest := clip.duplicate(true)
 rest.length = 1.0
 rest.loop_mode = Animation.LOOP_LINEAR
 for track in rest.get_track_count():
  var q:Quaternion=rest.track_get_key_value(track,0)
  while rest.track_get_key_count(track)>0:rest.track_remove_key(track,0)
  rest.rotation_track_insert_key(track,0,q)
  rest.rotation_track_insert_key(track,1,q)
 if lib.has_animation("Bow_Rest"):lib.remove_animation("Bow_Rest")
 lib.add_animation("Bow_Rest",rest)
 assert(ResourceSaver.save(lib,"res://assets/animations/huntress_archery.tres")==OK)
 reach = null
 model.free()
 print("BOW_ACTION_BAKE_OK: 1.16s, release at .74, head level, torso and arm recovery")
 quit()
