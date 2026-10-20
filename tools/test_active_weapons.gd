extends "res://tools/level1_playtest.gd"
## Без записи сохранений: рабочее оружие и загрузка отложенного пистолета.
func _start() -> void:
 if "--campaign-start" not in OS.get_cmdline_user_args():
  super._start()
  return
 checking=true
 player=Game.start_test(1,&"normal")
 level=player.get_parent()
 _check.call_deferred()

func _check() -> void:
 await get_tree().create_timer(.9).timeout
 for enemy in get_tree().get_nodes_in_group("enemies"):enemy.set_physics_process(false)
 assert(Game.testing)
 assert(ItemDB.ACT_ONE_WEAPONS.all(func(id):return load(ItemDB.base_by_id(id).weapon).icon in [&"rifle",&"shotgun"]))
 for i in 100:
  var base=ItemDB.random_base(&"weapon",1+i%5)
  assert(load(base.weapon).icon in [&"rifle",&"shotgun"])
 assert(player.weapon_item(0).base.id==&"rifle")
 assert(player.weapon_item(1).base.id==&"shotgun")
 assert(player.current_weapon().projectile==&"stake")
 var animator:AnimationTree=player.get_node("Animator")
 assert(animator.hold_anim==&"Pistol_Idle")
 assert(not animator.has_animation(&"Pistol_Stance") and not animator.has_animation(&"Pistol_Rest"))
 for i in 2:
  player.select_weapon(i)
  await get_tree().create_timer(player.switch_delay+.15).timeout
  var ammo:int=player.current_ammo()
  Input.action_press("shoot")
  await get_tree().create_timer(.12).timeout
  Input.action_release("shoot")
  await get_tree().create_timer(.1).timeout
  assert(player.current_ammo()==ammo-1)
 var saved=preload("res://scripts/save_game.gd")
 var pistol=GearItem.create(ItemDB.base_by_id(&"pistol"),1,0)
 pistol.quality=7
 pistol.modules[0]=preload("res://data/modules/fire.tres").duplicate()
 assert(player.inventory.add_item(pistol))
 assert(not player.inventory.equip_weapon(pistol,0).is_empty())
 var snapshot:Dictionary=saved._inventory_to(player.inventory)
 snapshot.weapons[0]=saved._item_to(pistol)
 # Убираем тестовую копию из сумки: в исходном снимке он только в слоте.
 snapshot.entries=snapshot.entries.filter(func(entry):return entry.item.get("base","")!="pistol")
 saved.apply({"inventory":snapshot},Game,player)
 player._on_inventory_changed()
 assert(player.inventory.weapons[0]==null and player.weapon_item(1).base.id==&"shotgun")
 var preserved:GearItem
 for entry in player.inventory.entries:
  if entry.item is GearItem and entry.item.base.id==&"pistol":preserved=entry.item
 assert(preserved!=null and preserved.quality==7 and preserved.modules[0].id==&"fire")
 snapshot=saved._inventory_to(player.inventory)
 snapshot.weapons=[saved._item_to(pistol),null]
 saved.apply({"inventory":snapshot},Game,player)
 player._on_inventory_changed()
 assert(player.weapon_item(0).base.id==&"rifle")
 assert(player.current_weapon().projectile==&"stake")
 var camera=get_viewport().get_camera_3d()
 var rig=camera.get_parent()
 assert(not rig.camera_impulses_enabled)
 rig.add_dip(.5);rig.add_shake(1.0);rig.add_weapon_shake(.5,1.0)
 await get_tree().create_timer(.2).timeout
 assert(rig._dip==0.0 and rig._trauma==0.0)
 assert(camera.position.distance_to(rig._camera_offset())<.0001)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://ztest/active_crossbow_shotgun.png")
 print("ACTIVE_WEAPONS_OK crossbow, shotgun, shots, no pistol animation profile, preserved stored pistol, fallback crossbow, stable camera")
 get_tree().quit()
