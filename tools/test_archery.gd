extends Node3D
const ItemDB := preload("res://scripts/item_db.gd")
class Target extends StaticBody3D:
 var hits := 0
 func take_damage(amount: float, _element := &"physical", _source = null) -> float:
  hits += 1
  return amount
 func is_dead() -> bool: return false

func _ready() -> void:
 set_meta("test_runner", true)
 Game.testing = true
 _run.call_deferred()

func _run() -> void:
 var preview := preload("res://scenes/tools/huntress_preview.tscn").instantiate()
 add_child(preview)
 for child in preview.get_children():
  if child.get_script() == preload("res://scripts/dummy.gd"): child.free()
 var p = preview.player
 assert(p._bow_equip_left > 0)
 await get_tree().create_timer(1.05).timeout
 assert(p._bow_equip_left == 0, "Equip clip must finish before shooting")
 p.set_physics_process(false)
 p.rotation = Vector3.ZERO
 p.set_process_unhandled_input(false)
 var target := Target.new()
 target.collision_layer = 4
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(2, 2, 1)
 shape.shape = box
 shape.position.y = 1
 target.add_child(shape)
 add_child(target)
 target.position = Vector3(0, 0, -7)
 await get_tree().create_timer(.4).timeout
 assert(p.current_weapon().projectile == &"wood_arrow")
 assert(p.get_node_or_null("Flashlight") == null)
 var aura: OmniLight3D = p.get_node("Aura")
 assert(aura.light_color.r > aura.light_color.b and not aura.shadow_enabled)
 var old = p.inventory.weapons.duplicate()
 p.select_weapon(1)
 p._equip(1)
 assert(p.current_weapon_index() == 0)
 var rifle := GearItem.create(ItemDB.base_by_id(&"rifle"), 1, 0)
 assert(p.inventory.equip_weapon(rifle, 1) != "")
 assert(p.inventory.weapons == old)
 p._using_mouse = false
 p._aim_dir = Vector3.FORWARD
 p.aim_target = target
 p._fire_cooldown = 0
 Input.action_press("shoot")
 for i in ceili(p.bow_draw_time * .85 / .016):
  p._update_shooting(.016)
  await get_tree().process_frame
 assert(p.bow_shots_fired == 0)
 assert(p.bow_draw_fraction() > .5)
 await get_tree().create_timer(.2).timeout
 var head_forward: Vector3 = p._bow_modifier.get_meta("head_forward")
 assert(head_forward.y < .45, "Head must not tip back while aiming")
 # SkeletonModifier poses are restored after rendering. Compare against the
 # wrist sampled inside the modifier, which is the actual rendered pose.
 var right_hand: Vector3 = p._bow_modifier.get_meta("nock_world")
 for visual in p.gun.get_children():
  if visual.has_method("update_pose"):
   assert(visual.nocked)
   assert(visual._limbs.size() == 1, "Bow must contain the draw blend shape")
   assert(visual._limbs[0].get_blend_shape_value(0) > .05, "Bow limbs must bend while drawing")
   var nock: Vector3 = visual._arrow.to_global(Vector3(0,0,.30))
   assert(nock.distance_to(right_hand) < .025, "String and arrow must follow the animated right hand")
 var steps := 0
 while p.bow_shots_fired == 0 and steps < 120:
  p._update_shooting(.016)
  await get_tree().process_frame
  steps += 1
 assert(p.bow_shots_fired == 1)
 await get_tree().create_timer(.5).timeout
 assert(target.hits == 1, "Arrow must hit a real physics target")
 for bullet in preview.get_node("Arrows")._bullets:
  if bullet._look == &"wood_arrow":
   assert(not bullet.get_node("Mesh").get_active_material(0).emission_enabled)
 p._bow_draw_elapsed = .3
 p._start_dodge(Vector3.FORWARD)
 p._update_shooting(.016)
 assert(p._bow_draw_elapsed == 0 and p.bow_shots_fired == 1)
 # Resume real player physics with held RT after the complete roll.
 Input.action_release("shoot")
 var trigger := InputEventJoypadMotion.new()
 trigger.axis = JOY_AXIS_TRIGGER_RIGHT
 trigger.axis_value = 1.0
 Input.parse_input_event(trigger)
 p.set_physics_process(true)
 var deadline := Time.get_ticks_msec() + 4000
 while p.bow_shots_fired == 1 and Time.get_ticks_msec() < deadline:
  await get_tree().physics_frame
 assert(p.bow_shots_fired > 1, "Held shooting must resume after rolling")
 assert(not p.is_dodging() and p._recovery_left <= 0)
 Input.action_release("shoot")
 trigger.axis_value = 0
 Input.parse_input_event(trigger)
 print("ARCHERY_TEST_OK shots=", p.bow_shots_fired, " hits=", target.hits)
 get_tree().quit()
