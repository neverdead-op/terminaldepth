extends "res://tools/bake_archery.gd"
## Retarget the supplied actions and join them without procedural arm poses.
func _run() -> void:
 var model := Model.new()
 model.source_path = "res://assets/characters/red_huntress/v1/huntress.glb"
 root.add_child(model)
 target = model.get_node("Armature/Skeleton3D")
 library = load("res://assets/animations/huntress_archery.tres").duplicate(true)
 for file in DirAccess.get_files_at("res://animation/bow_combat"):
  if not file.ends_with(".fbx"): continue
  var name := StringName("BC_"+file.get_basename())
  if library.has_animation(name):library.remove_animation(name)
  add_clip("res://animation/bow_combat/"+file,name,file.get_basename() in ["idle","overdraw","aim_walk_right","run_forward","run_back","run_left","run_right","sprint","walk_forward","walk_left","walk_right"])
  library.get_animation(name).set_meta("source_file", "res://animation/bow_combat/"+file)
 _alias(&"Bow_Idle", &"BC_idle")
 _alias(&"Bow_Rest", &"BC_idle")
 _alias(&"Bow_Equip", &"BC_equip")
 _alias(&"SP_dive_roll", &"BC_dive")
 for mode in ["walk","run","sprint"]:
  for direction in ["forward","forward_right","right","backward_right","backward","backward_left","left","forward_left"]:
   var source_dir: String = {"backward":"back","forward_right":"forward","forward_left":"forward","backward_right":"back","backward_left":"back"}.get(direction,direction)
   var key: String = "BC_"+mode+"_"+source_dir
   if mode=="sprint":key="BC_sprint"
   if not library.has_animation(key):continue
   var clip:Animation=library.get_animation(key).duplicate(true)
   var yaw:float={"forward_right":-45.0,"forward_left":45.0,"backward_right":45.0,"backward_left":-45.0}.get(direction,0.0)
   if mode=="sprint":yaw={"forward":0.0,"forward_right":-45.0,"right":-90.0,"backward_right":-135.0,"backward":180.0,"backward_left":135.0,"left":90.0,"forward_left":45.0}[direction]
   for track in clip.get_track_count():
    if clip.track_get_type(track)==Animation.TYPE_ROTATION_3D and String(clip.track_get_path(track).get_concatenated_subnames())=="pelvis":
     for k in clip.track_get_key_count(track):clip.track_set_key_value(track,k,Quaternion(Vector3.UP,deg_to_rad(yaw))*clip.track_get_key_value(track,k))
   _put(StringName("SP_"+mode+"_"+direction),clip)
 _join_shot()
 var aim:=Transfer.poses(target,library.get_animation("BC_overdraw"),.1)
 var left:=target.find_bone("hand_l")
 var right:=target.find_bone("hand_r")
 var desired:=Basis.looking_at(Vector3.BACK,Vector3.UP)
 var grip_basis:=aim[left].basis.inverse()*target.global_basis.inverse()*desired
 library.set_meta("bow_grip_basis",grip_basis)
 var nock:=desired.inverse()*(target.global_basis*(aim[right].origin-aim[left].origin))-Vector3(0,-.02,-.05)
 library.set_meta("bow_draw_span",maxf(.12,nock.z-.196))
 library.set_meta("bow_equip_time",library.get_animation("Bow_Equip").length)
 library.set_meta("bow_nock_time",.64)
 library.set_meta("bow_combat_sources",true)
 assert(ResourceSaver.save(library,"res://assets/animations/huntress_archery.tres")==OK)
 model.free()
 print("BOW_COMBAT_BAKE_OK: supplied draw/overdraw/recoil, equip, dive and locomotion")
 quit()
func _put(name:StringName,clip:Animation) -> void:
 if library.has_animation(name):library.remove_animation(name)
 library.add_animation(name,clip)
func _alias(name:StringName,source:StringName) -> void:
 _put(name,library.get_animation(source).duplicate(true))
func _join_shot() -> void:
 var draw:=library.get_animation("BC_draw_arrow")
 var aim:=library.get_animation("BC_overdraw")
 var recoil:=library.get_animation("BC_recoil")
 var begin:=draw.length+.10
 var release:=begin+2.0/30.0
 var clip:=Animation.new()
 clip.length=begin+recoil.length
 var tracks:Array[int]=[]
 for i in target.get_bone_count():
  var track:=clip.add_track(Animation.TYPE_ROTATION_3D)
  clip.track_set_path(track,NodePath("Armature/Skeleton3D:"+target.get_bone_name(i)))
  tracks.append(track)
 var end_draw:=Transfer.poses(target,draw,draw.length)
 var end_aim:=Transfer.poses(target,aim,.1)
 for f in ceili(clip.length*60)+1:
  var t:=minf(f/60.0,clip.length)
  var poses:Array[Transform3D]
  var previous:Array[Transform3D]
  var weight:=1.0
  if t<=draw.length:poses=Transfer.poses(target,draw,t)
  elif t<begin:
   poses=Transfer.poses(target,aim,t-draw.length);previous=end_draw;weight=smoothstep(draw.length,begin,t)
  else:
   poses=Transfer.poses(target,recoil,t-begin);previous=end_aim;weight=smoothstep(begin,begin+.035,t)
  for i in target.get_bone_count():
   var parent:=target.get_bone_parent(i)
   var basis:=poses[i].basis if parent<0 else poses[parent].basis.inverse()*poses[i].basis
   var q:=basis.orthonormalized().get_rotation_quaternion()
   if weight<1.0:
    var prior:=previous[i].basis if parent<0 else previous[parent].basis.inverse()*previous[i].basis
    q=prior.orthonormalized().get_rotation_quaternion().slerp(q,weight)
   clip.rotation_track_insert_key(tracks[i],t,q)
 clip.set_meta("release_time",release)
 clip.set_meta("recoil_begin",begin)
 clip.set_meta("nock_time",.64)
 clip.set_meta("source_files",["draw_arrow.fbx","overdraw.fbx","recoil.fbx"])
 _put(&"Bow_Shot",clip)
 library.set_meta("bow_draw_time",release)
 library.set_meta("bow_recovery_time",clip.length-release)
