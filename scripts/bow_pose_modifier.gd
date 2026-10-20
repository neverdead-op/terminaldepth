extends SkeletonModifier3D
## Preserve supplied arm animation; align the chest in yaw and attach the bow.
@export var body: Node3D
var _grip := Basis.IDENTITY
var _draw_span := .38
var _aim_weight := 0.0
func _ready() -> void:
 var lib:AnimationLibrary=load(body.get_node("Model").animation_library_path)
 _grip=lib.get_meta("bow_grip_basis",Basis.IDENTITY)
 _draw_span=lib.get_meta("bow_draw_span",.38)
func _process_modification_with_delta(delta: float) -> void:
 if not is_instance_valid(body) or not body.fixed_bow_loadout: return
 var sk:=get_skeleton()
 var blocked:bool=body.is_dodging() or body._recovery_left>0 or body.is_dead() or body.is_sprinting() or body._bow_equip_left>0
 var aiming:bool=(body._bow_draw_elapsed>body._bow_nock_time or body._bow_release_left>.2) and not blocked
 _aim_weight=move_toward(_aim_weight,1.0 if aiming else 0.0,delta*12.0)
 var forward:Vector3=-body.global_basis.z
 if _aim_weight>0:
  var wrist:=sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_l"))
  var bow_forward:Vector3=-(wrist.basis.orthonormalized()*_grip).z
  bow_forward.y=0
  if bow_forward.length_squared()>.001:
   var yaw:=bow_forward.normalized().signed_angle_to(forward,Vector3.UP)*_aim_weight
   var chest:=sk.find_bone("spine_01")
   var pose:=sk.get_bone_global_pose(chest)
   var axis:=sk.global_basis.inverse()*Vector3.UP
   pose.basis=Basis(axis.normalized(),yaw)*pose.basis
   sk.set_bone_global_pose(chest,pose)
 var left:=sk.global_transform*sk.get_bone_global_pose(sk.find_bone("hand_l"))
 var right:=sk.global_transform*sk.get_bone_global_pose(sk.find_bone("hand_r"))
 var desired:Basis=(left.basis.orthonormalized()*_grip).orthonormalized()
 body.gun.basis=left.basis.inverse()*desired
 var grip:Vector3=left.origin+desired*Vector3(0,-.02,-.05)
 body.gun.position=left.basis.inverse()*(grip-left.origin)
 var local_nock:Vector3=desired.inverse()*(right.origin-grip)
 var nocked:bool=body._bow_draw_elapsed>body._bow_nock_time and not blocked
 var amount:float=clampf((local_nock.z-.196)/_draw_span,0,1) if nocked else 0.0
 var released:=Vector3(0,0,.196)
 if body._bow_release_left>0:
  var elapsed:float=body.bow_release_time-body._bow_release_left
  released.z+=sin(elapsed*90.0)*.018*exp(-elapsed*18.0)
 for visual in body.gun.get_children():
  if visual.has_method("update_pose"):visual.update_pose(local_nock if nocked else released,nocked,amount)
 set_meta("arrow_origin",grip-desired.z*.05)
 set_meta("nock_world",right.origin)
 var head:=sk.find_bone("Head")
 var head_forward:=sk.global_basis*sk.get_bone_global_pose(head).basis*sk.get_bone_global_rest(head).basis.inverse()*Vector3.BACK
 set_meta("head_forward",head_forward.normalized())
