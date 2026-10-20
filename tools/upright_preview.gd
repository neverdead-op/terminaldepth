extends "res://tools/huntress_preview.gd"
## Сравнение стойки и походки на настоящем игроке, без сохранений.
func _capture() -> void:
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.get_node("HUD").hide()
 $PreviewHelp.hide()
 for child in player.get_children():
  if child.get_script()==preload("res://scripts/player_bar_3d.gd"):
   child.set_process(false)
   child.hide()
 var animator:AnimationTree=player.get_node("Animator")
 var tag="after" if animator.get_animation(&"SP_idle").has_meta("upright_posture") else "before"
 for state in ["idle","walk","run","fire"]:
  player.velocity=Vector3.FORWARD*(1.8 if state=="walk" else (3.6 if state=="run" else 0.0))
  player._firing=state=="fire"
  await get_tree().create_timer(.6).timeout
  for view in ["front","side","game"]:
   var target=player.global_position+Vector3.UP*.85
   camera.position=target+({"front":Vector3(0,.35,-4),"side":Vector3(4,.2,0),"game":Vector3(0,5,4)}[view])
   camera.look_at(target)
   camera.size=2.5 if view!="game" else 3.5
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://ztest/upright_"+tag+"_"+state+"_"+view+".png")
  var sk:Skeleton3D=animator._skeleton
  var bends=[]
  for side in ["l","r"]:
   var a=sk.get_bone_global_pose(sk.find_bone("thigh_"+side)).origin
   var b=sk.get_bone_global_pose(sk.find_bone("calf_"+side)).origin
   var c=sk.get_bone_global_pose(sk.find_bone("foot_"+side)).origin
   bends.append(rad_to_deg((b-a).angle_to(c-b)))
  print("UPRIGHT_SAMPLE ",tag," ",state," knee_bend=",bends)
 if tag=="after":
  player._firing=false
  for speed in [1.8,3.6]:
   for i in 8:
    player.velocity=Vector3(sin(i*PI/4),0,-cos(i*PI/4))*speed
    await get_tree().create_timer(.3).timeout
    assert(String(animator._state).begins_with("Walk" if speed<2 else "Run"))
    _check_grip(animator)
  var shotgun=GearItem.create(DB.base_by_id(&"shotgun"),1,0)
  assert(player.inventory.add_item(shotgun))
  assert(player.inventory.equip_weapon(shotgun,1).is_empty())
  player.select_weapon(1)
  player.velocity=Vector3.ZERO
  for firing in [false,true]:
   player._firing=firing
   await get_tree().create_timer(.5).timeout
   _check_grip(animator)
   var target=player.global_position+Vector3.UP*.85
   camera.position=target+Vector3(3,.5,-4)
   camera.look_at(target)
   camera.size=2.5
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://ztest/upright_shotgun_"+("aim" if firing else "idle")+".png")
  print("UPRIGHT_RUNTIME_OK walk/run in eight directions, crossbow and shotgun grip")
 print("UPRIGHT_PREVIEW_OK")
 get_tree().quit()

func _check_grip(animator:AnimationTree) -> void:
 for modifier in animator._skeleton.get_children():
  if modifier.get_script()==preload("res://scripts/weapon_support_modifier.gd"):
   assert(modifier._weight>.99 and modifier.last_error<.02,"Support hand lost the weapon")
