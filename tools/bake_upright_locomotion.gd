extends SceneTree
## Отдельная запечённая поправка осанки MODEL 1. Исходные боевые клипы не перезаписываются.
const Model=preload("res://scripts/shooter_model.gd")
const Transfer=preload("res://tools/animation_transfer.gd")
const SOURCE="res://assets/animations/model1_shooter.tres"
const OUTPUT="res://assets/animations/model1_upright.tres"
const STANCE_WIDTH=0.36
const LATERAL_SCALE=0.60
const STRIDE_SCALE=0.80
var sk:Skeleton3D
var changed:Dictionary={}
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var model=Model.new()
 model.source_path="res://assets/characters/model1/v1/model1.glb"
 root.add_child(model)
 sk=model.get_node("Armature/Skeleton3D")
 var source:AnimationLibrary=load(SOURCE)
 var library=AnimationLibrary.new()
 for bone in ["pelvis","spine_01","thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r"]:
  changed[sk.find_bone(bone)]=true
 for name in source.get_animation_list():
  if name!="SP_idle" and not String(name).begins_with("SP_walk_") and not String(name).begins_with("SP_run_"):continue
  var original=source.get_animation(name)
  var clip:Animation=original.duplicate(true)
  var idle=name==&"SP_idle"
  var steps=maxi(1,ceili(original.length*60))
  # Удаляем старые ключи выбранных костей, чтобы между новыми кадрами не всплывала прежняя поза.
  for t in clip.get_track_count():
   var bone=sk.find_bone(String(clip.track_get_path(t).get_concatenated_subnames()))
   if changed.has(bone):
    for k in range(clip.track_get_key_count(t)-1,-1,-1):clip.track_remove_key(t,k)
  # Меняем только таз, нижнюю спину и ноги. Руки и оружейные действия остаются исходными.
  for frame in steps+1:
   var time=original.length*frame/steps
   var pose=Transfer.poses(sk,original,time)
   _upright_pose(pose,idle)
   for t in clip.get_track_count():
    var bone=sk.find_bone(String(clip.track_get_path(t).get_concatenated_subnames()))
    if not changed.has(bone):continue
    if clip.track_get_type(t)==Animation.TYPE_ROTATION_3D:
     clip.rotation_track_insert_key(t,time,sk.get_bone_pose_rotation(bone))
    elif bone==sk.find_bone("pelvis") and clip.track_get_type(t)==Animation.TYPE_POSITION_3D:
     clip.position_track_insert_key(t,time,sk.get_bone_pose_position(bone))
  clip.set_meta("upright_posture",true)
  if not idle and original.has_meta("locomotion_speed"):
   # Подстройка темпа следует новой длине шага, игровая скорость не меняется.
   var direction=String(name).trim_prefix("SP_walk_").trim_prefix("SP_run_")
   var scale=LATERAL_SCALE if direction in ["left","right"] else STRIDE_SCALE
   if direction in ["forward_left","forward_right","backward_left","backward_right"]:
    scale=sqrt((LATERAL_SCALE*LATERAL_SCALE+STRIDE_SCALE*STRIDE_SCALE)*.5)
   clip.set_meta("locomotion_speed",float(original.get_meta("locomotion_speed"))*scale)
  library.add_animation(name,clip)
 library.set_meta("pelvis_rest",sk.get_bone_rest(sk.find_bone("pelvis")).origin)
 assert(ResourceSaver.save(library,OUTPUT)==OK)
 print("UPRIGHT_BAKE_OK clips=",library.get_animation_list().size())
 model.free()
 quit()
func _upright_pose(original:Array[Transform3D],idle:bool) -> void:
 sk.reset_bone_poses()
 var pelvis=sk.find_bone("pelvis")
 var lateral:Vector3=original[sk.find_bone("thigh_l")].origin-original[sk.find_bone("thigh_r")].origin
 var correction=Basis(Vector3.UP,atan2(lateral.z,lateral.x))
 var goals:Array[Vector3]=[]
 var foot_bases:Array[Basis]=[]
 var height=sk.get_bone_rest(pelvis).origin.y-.01
 for side in ["l","r"]:
  var upper=sk.find_bone("thigh_"+side)
  var lower=sk.find_bone("calf_"+side)
  var foot=sk.find_bone("foot_"+side)
  var goal:Vector3=correction*(original[foot].origin-original[pelvis].origin)
  goal=Vector3(goal.x*LATERAL_SCALE,original[foot].origin.y,goal.z*STRIDE_SCALE)
  if idle:goal=Vector3(STANCE_WIDTH*.5*(1 if side=="l" else -1),sk.get_bone_global_rest(foot).origin.y,.03 if side=="l" else -.03)
  goals.append(goal)
  foot_bases.append(sk.get_bone_global_rest(foot).basis if idle else correction*original[foot].basis)
  var length=sk.get_bone_rest(lower).origin.length()+sk.get_bone_rest(foot).origin.length()
  var hip=sk.get_bone_rest(upper).origin
  var horizontal=Vector2(goal.x-hip.x,goal.z-hip.z).length_squared()
  var reach=sqrt(maxf(.01,pow(length*.992,2)-horizontal))
  height=minf(height,goal.y+reach-hip.y)
 sk.set_bone_pose_position(pelvis,Vector3(0,height,0))
 for i in 2:
  var side="l" if i==0 else "r"
  var upper=sk.find_bone("thigh_"+side)
  var lower=sk.find_bone("calf_"+side)
  var foot=sk.find_bone("foot_"+side)
  var a=sk.get_bone_global_pose(upper).origin
  var b=sk.get_bone_global_pose(lower).origin
  var c=sk.get_bone_global_pose(foot).origin
  var first=a.distance_to(b)
  var second=b.distance_to(c)
  var ray=goals[i]-a
  var direction=ray.normalized()
  var distance=ray.length()
  var along=(first*first+distance*distance-second*second)/(2*distance)
  var pole=(Vector3.BACK-direction*Vector3.BACK.dot(direction)).normalized()
  var knee=a+direction*along+pole*sqrt(maxf(0,first*first-along*along))
  var bone_pose=sk.get_bone_global_pose(upper)
  bone_pose.basis=Basis(Quaternion((b-a).normalized(),(knee-a).normalized()))*bone_pose.basis
  sk.set_bone_global_pose(upper,bone_pose)
  bone_pose=sk.get_bone_global_pose(lower)
  var end=sk.get_bone_global_pose(foot).origin
  bone_pose.basis=Basis(Quaternion((end-bone_pose.origin).normalized(),(goals[i]-bone_pose.origin).normalized()))*bone_pose.basis
  sk.set_bone_global_pose(lower,bone_pose)
  bone_pose=sk.get_bone_global_pose(foot)
  bone_pose.basis=foot_bases[i]
  sk.set_bone_global_pose(foot,bone_pose)
  assert(bone_pose.origin.distance_to(goals[i])<.002)
