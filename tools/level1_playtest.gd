extends Node
const Modules:=preload("res://scripts/module_db.gd")
const ItemDB:=preload("res://scripts/item_db.gd")
var player:Node3D
var level:Node3D
var checking:=false
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 set_meta("test_runner",true)
 _start.call_deferred()
func _start() -> void:
 player=Game.start_test(1,&"normal","res://scenes/art/level1_supplied.tscn",{"fixed_bow_loadout":false,"start_weapon":&"rifle","start_weapon_corp":&"","animation_library_path":"res://assets/animations/model1_shooter.tres"})
 level=player.get_parent()
 var camera_controls:=preload("res://scripts/level1_camera_controls.gd").new()
 camera_controls.name="CameraControls";level.add_child(camera_controls)
 player.floor_max_angle=deg_to_rad(55)
 var steps:=preload("res://scripts/level1_step_assist.gd").new()
 steps.name="MapSteps";steps.body=player;player.add_child(steps)
 var rifle:GearItem=player.weapon_item(0)
 rifle.modules[0]=Modules.by_id(&"fire").duplicate()
 rifle.modules[1]=Modules.by_id(&"ricochet").duplicate()
 player._on_modules_changed()
 player._ammo[0]=player.current_magazine_size()
 var shotgun:=GearItem.create(ItemDB.base_by_id(&"shotgun"),1,0)
 shotgun.corp=&""
 var shotgun_added:bool=player.inventory.add_item(shotgun)
 var shotgun_error:String=player.inventory.equip_weapon(shotgun,1)
 assert(shotgun_added and shotgun_error.is_empty())
 var canvas:=CanvasLayer.new();canvas.name="TestControls";level.add_child(canvas)
 var label:=Label.new();label.position=Vector2(18,64);label.text="1 УРОВЕНЬ • АРБАЛЕТ: ОГОНЬ + РИКОШЕТ • F2 — карта целиком • F7 — заново • цель: таверна";label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_outline_size",4);canvas.add_child(label)
 player.show_message("1 — арбалет, 2 — дробовик, Q — сменить оружие. R — перезарядка. Доберитесь до таверны.",6)
 if not checking and ("--check" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--walk-check" in OS.get_cmdline_user_args() or "--combat-check" in OS.get_cmdline_user_args()):
  checking=true;_check.call_deferred()
func _unhandled_key_input(event:InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F7:_start()
func _check() -> void:
 await get_tree().create_timer(.8).timeout
 for enemy in get_tree().get_nodes_in_group("enemies"):
  enemy.set_physics_process(false)
  if "--walk-check" in OS.get_cmdline_user_args():enemy.collision_layer=0
 assert(Game.testing and not player.fixed_bow_loadout)
 assert(player.get_node("Model").source_path=="res://assets/characters/model1/v1/model1.glb")
 assert(player.get_node("Model").animation_library_path=="res://assets/animations/model1_shooter.tres")
 assert(player.current_weapon().icon==&"rifle" and player.current_ammo()==player.current_magazine_size())
 assert(player.weapon_stats(0).chain==1 and player.weapon_stats(0).ammo==&"fire")
 assert(level.mob_count==64)
 var composition:Dictionary={"crawler":0,"spitter":0,"leaper":0,"brute":0}
 for enemy in get_tree().get_nodes_in_group("enemies"):
  if not level.is_ancestor_of(enemy):continue
  var kind:String=enemy.get_script().resource_path.get_file().get_basename()
  assert(composition.has(kind),"Unexpected playtest enemy: "+kind)
  composition[kind]+=1
  if kind=="spitter":assert(is_equal_approx(enemy.projectile_damage,7.0))
 assert(composition=={"crawler":37,"spitter":12,"leaper":12,"brute":3},"Unexpected playtest composition")
 print("LEVEL1_ENEMY_MIX_OK ",composition)
 var map:=level.get_world_3d().navigation_map
 var route:=NavigationServer3D.map_get_path(map,player.position,level.finish_position,true)
 assert(route.size()>2 and route[-1].distance_to(level.finish_position)<.5,"No complete route to the tavern")
 assert(player.is_on_floor(),"Spawn must stand on the bridge")
 if "--check" in OS.get_cmdline_user_args():
  assert(player.weapon_item(1).base.id==&"shotgun")
  Input.action_press("weapon_2")
  await get_tree().create_timer(.15).timeout
  Input.action_release("weapon_2")
  assert(player.current_weapon_index()==1 and player.current_weapon().icon==&"shotgun")
  assert(player.current_weapon().model.resource_path=="res://assets/guns/Shotgun_ShortStock.fbx")
  await get_tree().create_timer(player.switch_delay+.1).timeout
  var shotgun_ammo:int=player.current_ammo()
  Input.action_press("shoot")
  await get_tree().create_timer(.1).timeout
  Input.action_release("shoot")
  assert(player.current_ammo()==shotgun_ammo-1)
  Input.action_press("reload")
  await get_tree().create_timer(.1).timeout
  Input.action_release("reload")
  await get_tree().create_timer(player.weapon_stats(1).reload_time+.2).timeout
  assert(player.current_ammo()==player.current_magazine_size())
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://docs/screens/level1_shotgun_integrated.png")
  Input.action_press("weapon_1")
  await get_tree().create_timer(.15).timeout
  Input.action_release("weapon_1")
  assert(player.current_weapon_index()==0 and player.current_weapon().icon==&"rifle")
  print("LEVEL1_SHOTGUN_LOADOUT_OK slots 1/2, input switching, shooting, reload, rifle restored")
  var animator:AnimationTree=player.get_node("Animator")
  var previous_velocity:Vector3=player.velocity
  var configured_rate:float=animator.run_playback_multiplier
  assert(is_equal_approx(configured_rate,.85))
  player.velocity=Vector3(0,0,-5)
  animator.run_playback_multiplier=1.0;animator._physics_process(1.0/60)
  var base_rate:float=animator.get("parameters/legs_speed/scale")
  animator.run_playback_multiplier=configured_rate;animator._physics_process(1.0/60)
  var expected_rate:float=base_rate if animator.firearm_run_stride_sync else base_rate*configured_rate
  assert(is_equal_approx(animator.get("parameters/legs_speed/scale"),expected_rate))
  assert(player.velocity==Vector3(0,0,-5))
  player.velocity=previous_velocity;animator._physics_process(1.0/60)
  print("LEVEL1_RUN_RATE_OK stride_sync=",animator.firearm_run_stride_sync," sprint_multiplier=",configured_rate," movement speed preserved")
  var controls:CanvasLayer=level.get_node("CameraControls")
  controls.set_open(true)
  assert(get_tree().paused)
  controls.sliders["distance"].value=14
  controls.sliders["angle"].value=60
  controls.sliders["height"].value=12
  controls.sliders["fov"].value=62
  var trial:Camera3D=level.get_node("CameraRig/Camera3D")
  assert(is_equal_approx(trial.position.y,12) and is_equal_approx(trial.fov,62))
  assert((-trial.global_basis.z).dot((level.get_node("CameraRig").global_position-trial.global_position).normalized())>.999)
  controls.set_open(false)
  assert(not get_tree().paused)
  var previous:WeakRef=weakref(player)
  var restart:=InputEventKey.new();restart.pressed=true;restart.keycode=KEY_F7
  _unhandled_key_input(restart)
  await get_tree().create_timer(.9).timeout
  assert(previous.get_ref()==null and level.mob_count==64)
  assert(player.weapon_item(1).base.id==&"shotgun")
  assert(player.current_weapon().icon==&"rifle" and player.weapon_stats(0).chain==1 and player.weapon_stats(0).ammo==&"fire")
  assert(is_equal_approx(level.get_node("CameraRig/Camera3D").fov,62))
  var next_controls:CanvasLayer=level.get_node("CameraControls")
  next_controls.settings=next_controls.DEFAULT_SETTINGS;next_controls._apply()
  print("LEVEL1_CAMERA_PANEL_OK live sliders, aim, pause/resume and F7 retention")
  print("LEVEL1_RESTART_OK F7 restores rifle, fire, ricochet and 64 mobs")
 if "--combat-check" in OS.get_cmdline_user_args():await _combat_check()
 if "--walk-check" in OS.get_cmdline_user_args():
  if not await _walk_route(route):get_tree().quit(2);return
  player.get_node("MapSteps").direction_override=Vector3.ZERO
  level.set_process(true);player.set_physics_process(true)
  for i in 300:
   await get_tree().physics_frame
   if get_tree().current_scene.scene_file_path==Game.HUB_SCENE:break
  assert(get_tree().current_scene.scene_file_path==Game.HUB_SCENE,"The finish must enter the tavern")
  assert(player.current_weapon().icon==&"rifle" and player.weapon_stats(0).ammo==&"fire" and player.weapon_stats(0).chain==1)
  print("LEVEL1_FINISH_TRANSFER_OK tavern entered, rifle and modules preserved, no saves")
  get_tree().quit();return
 if "--capture" in OS.get_cmdline_user_args():
  if "--camera-panel" in OS.get_cmdline_user_args():level.get_node("CameraControls").set_open(true)
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://docs/screens/level1_supplied_gameplay.png")
  if "--camera-panel" in OS.get_cmdline_user_args():level.get_node("CameraControls").set_open(false)
  var key:=InputEventKey.new();key.keycode=KEY_F2;key.pressed=true;level._unhandled_key_input(key)
  await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://docs/screens/level1_supplied_overview.png")
 print("LEVEL1_TEST_OK mobs=",level.mob_count," rifle, fire ammo, ricochet, grounded spawn, full route points=",route.size()," no saves")
 get_tree().quit()
func _walk_route(route:PackedVector3Array) -> bool:
 player.set_physics_process(false)
 level.set_process(false)
 var step:=1
 var stuck:=0
 var previous:Vector3=player.position
 for frame in 9000:
  if step>=route.size():break
  await get_tree().physics_frame
  var to:Vector3=route[step]-player.position;to.y=0
  if to.length()<.45:step+=1;continue
  var direction:=to.normalized()
  player.velocity=Vector3(direction.x*4.5,player.velocity.y-9.8/60,direction.z*4.5)
  player.move_and_slide()
  player.get_node("MapSteps").direction_override=direction
  player.get_node("MapSteps").try_step()
  if Vector2(player.position.x-previous.x,player.position.z-previous.z).length()<.008:stuck+=1
  else:stuck=0
  if stuck>90:
   print("LEVEL1_WALK_BLOCKED at=",player.position," target=",route[step]," waypoint=",step," / ",route.size())
   return false
  previous=player.position
 assert(step>=route.size(),"Walk timed out")
 assert(player.position.distance_to(level.finish_position)<1.5)
 print("LEVEL1_PHYSICAL_WALK_OK waypoints=",step)
 return true
func _combat_check() -> void:
 player.set_physics_process(false)
 player.position=Vector3(2000,0,2000);player.rotation=Vector3.ZERO
 player._using_mouse=false;player._aim_dir=Vector3.FORWARD;player._firing=true
 var targets:Array[Enemy]=[]
 for x in [0.0,2.4]:
  var target:Enemy=preload("res://scenes/crawler.tscn").instantiate()
  target.max_hp=100000;target.drops_enabled=false;target.damage=0
  target.position=player.position+Vector3(x,0,-6)
  level.add_child(target);target.set_physics_process(false);targets.append(target)
 player.aim_target=targets[0]
 await get_tree().create_timer(.3).timeout
 var health_a:=targets[0].hp;var health_b:=targets[1].hp
 seed(19)
 for i in 12:
  player._shoot(player.current_weapon())
  await get_tree().create_timer(.04).timeout
 await get_tree().create_timer(.5).timeout
 assert(targets[0].hp<health_a and targets[0]._burn_left>0,"Fire rounds must deal damage and ignite")
 assert(targets[1].hp<health_b and targets[1]._burn_left>0,"Ricochet must hit and ignite a second target")
 print("LEVEL1_RIFLE_COMBAT_OK fire damage, burning and real enemy-to-enemy ricochet")
