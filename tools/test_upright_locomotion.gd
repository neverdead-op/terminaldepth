extends SceneTree
## Проверка ног во всём цикле, сохранения оружейных костей и деформации сетки.
const Transfer=preload("res://tools/animation_transfer.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var model=load("res://assets/characters/model1_player.tscn").instantiate()
 root.add_child(model)
 var sk:Skeleton3D=model.get_node("Armature/Skeleton3D")
 var original:AnimationLibrary=load("res://assets/animations/model1_shooter.tres")
 var library:AnimationLibrary=load("res://assets/animations/model1_upright.tres")
 assert(library.get_animation_list().size()==17)
 assert(not library.has_animation("SP_dive_roll") and not library.has_animation("SP_sprint_forward"))
 var mesh:MeshInstance3D=sk.find_child("Model1Hero",true,false)
 var arrays=mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var stride=weights.size()/vertices.size()
 var mapping=[]
 for i in mesh.skin.get_bind_count():mapping.append(sk.find_bone(mesh.skin.get_bind_name(i)))
 var max_support_bend=0.0
 var samples=0
 for name in library.get_animation_list():
  var clip=library.get_animation(name)
  var old=original.get_animation(name)
  for frame in 33:
   var time=clip.length*frame/32.0
   var pose=Transfer.poses(sk,clip,time)
   var before=Transfer.poses(sk,old,time)
   for bone_name in ["spine_02","spine_03","upperarm_l","lowerarm_l","hand_l","upperarm_r","lowerarm_r","hand_r"]:
    var i=sk.find_bone(bone_name)
    var parent=sk.get_bone_parent(i)
    var local=(pose[parent].basis.inverse()*pose[i].basis).orthonormalized().get_rotation_quaternion()
    var previous=(before[parent].basis.inverse()*before[i].basis).orthonormalized().get_rotation_quaternion()
    assert(absf(local.normalized().dot(previous.normalized()))>.999999,"Weapon bone changed: "+bone_name)
   var pelvis=pose[sk.find_bone("pelvis")]
   assert(pelvis.basis.y.normalized().dot(Vector3.UP)>.999)
   if name==&"SP_idle":
    var width=absf(pose[sk.find_bone("foot_l")].origin.x-pose[sk.find_bone("foot_r")].origin.x)
    assert(absf(width-.36)<.002)
   var floor_height=minf(pose[sk.find_bone("foot_l")].origin.y,pose[sk.find_bone("foot_r")].origin.y)
   for side in ["l","r"]:
    var hip=pose[sk.find_bone("thigh_"+side)].origin
    var knee=pose[sk.find_bone("calf_"+side)].origin
    var foot=pose[sk.find_bone("foot_"+side)].origin
    assert(absf(foot.y-before[sk.find_bone("foot_"+side)].origin.y)<.003 or name==&"SP_idle")
    var bend=rad_to_deg((knee-hip).angle_to(foot-knee))
    if foot.y<.13 and foot.y<floor_height+.015:max_support_bend=maxf(max_support_bend,bend)
    if name==&"SP_idle":assert(bend<25)
   for v in range(0,vertices.size(),53):
    var point=Vector3.ZERO
    for j in stride:
     var w=weights[v*stride+j]
     if w<=0:continue
     var bind=joints[v*stride+j]
     point+=(pose[mapping[bind]]*mesh.skin.get_bind_pose(bind)*vertices[v])*w
    assert(point.is_finite() and point.length()<3.5)
    samples+=1
 assert(max_support_bend<35,"Support leg remains crouched")
 print("UPRIGHT_LOCOMOTION_OK clips=17, samples=",samples," max_support_knee_bend=",max_support_bend," weapon bones unchanged")
 model.free()
 quit()
