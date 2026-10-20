extends "res://tools/huntress_preview.gd"
## Просмотр и проверка переходов пистолета без сохранений кампании.
func _capture() -> void:
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.get_node("HUD").hide()
 $PreviewHelp.hide()
 await get_tree().create_timer(.6).timeout
 var animator:AnimationTree=player.get_node("Animator")
 assert(animator.hold_anim==&"Pistol_Rest")
 assert(animator.pistol_run_anim==&"Pistol_Move")
 for state in ["idle","walk","run","sprint","fire","reload","roll","rest"]:
  player.velocity=Vector3.FORWARD * (6.3 if state=="sprint" else (4.0 if state=="run" else (1.8 if state=="walk" else 0.0)))
  player._sprinting=state=="sprint"
  player._firing=state=="fire"
  if state=="fire": animator.play_shot(player.current_weapon())
  if state=="reload": animator._on_reload_started(1.2)
  if state=="roll":
   animator._on_reload_cancelled()
   player._start_dodge(Vector3.FORWARD)
   player._roll_elapsed=player.dodge_duration*.4
   player._dodge_left=player.dodge_duration*.6
  if state=="rest":
   player._dodge_left=0.0
   player._recovery_left=0.0
   player._roll_elapsed=player.dodge_duration+player.dodge_recovery
  await get_tree().create_timer(.4).timeout
  assert(animator._rifle_pose<.01)
  # Рукоять находится в ладони, а не впереди пальцев.
  assert(player.gun.position.length()<.10)
  if state in ["walk","run","sprint"]:
   assert(animator._pistol_move>(.6 if state=="walk" else .95))
   assert(animator.get("parameters/upper/blend_amount")>.99)
  if state in ["idle","rest"]:
   assert(animator._aim<.01 and animator._pistol_move<.01)
  for modifier in animator._skeleton.get_children():
   if modifier.get_script()==preload("res://scripts/weapon_support_modifier.gd"):
    if state=="fire": assert(modifier.last_error<.015 and modifier._weight>.99)
    else: assert(modifier._weight<.01)
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://ztest/pistol_"+state+".png")
  print("PISTOL_STATE_OK ",state)
 print("PISTOL_GRIP_OK")
 get_tree().quit()
