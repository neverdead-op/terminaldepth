extends Node
## Small-step support for this imported, uneven playtest map only.
@export var body:CharacterBody3D
@export var step_height:=.78
var direction_override:=Vector3.ZERO
func _ready() -> void:process_physics_priority=10
func _physics_process(_delta:float) -> void:
 if not is_instance_valid(body) or not body.is_physics_processing():return
 try_step()
func try_step() -> void:
 if body.has_method("is_dead") and body.is_dead():return
 if body.get_slide_collision_count()==0:return
 var direction:=direction_override
 if direction.length_squared()<.01:
  if body.is_in_group("player"):
   var input:=Input.get_vector("move_left","move_right","move_up","move_down")
   direction=Vector3(input.x,0,input.y)
  elif body.is_in_group("enemies"):
   var path:PackedVector3Array=body.get("_path")
   var index:int=body.get("_path_index")
   if index<path.size():direction=path[index]-body.global_position
 direction.y=0
 if direction.length_squared()<.01:return
 direction=direction.normalized()
 var origin:=body.global_position
 var elevated:=body.global_transform;elevated.origin.y+=step_height
 if body.test_move(body.global_transform,Vector3.UP*step_height):return
 if body.test_move(elevated,direction*.55):return
 var query:=PhysicsRayQueryParameters3D.create(origin+direction*.55+Vector3.UP*(step_height+.12),origin+direction*.55-Vector3.UP*.12,1,[body.get_rid()])
 var hit:=body.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty() or hit.normal.y<.6:return
 var rise:float=hit.position.y-origin.y
 if rise<.06 or rise>step_height:return
 body.global_position=origin+direction*.28+Vector3.UP*(rise+.035)
 body.velocity.y=0
