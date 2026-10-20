extends Node
## F6 starts the approved courtyard with live enemies, without campaign saves.
var player: Node3D
var zone: Node3D
var checking := false
func _ready() -> void:
 set_meta("test_runner", true)
 _start.call_deferred()
func _start() -> void:
 player = Game.start_test(1, &"normal", "res://scenes/art/threshold_composition.tscn")
 zone = player.get_parent()
 zone.overview = false
 zone.follow_distance = 13.8
 zone._apply_camera()
 var key := InputEventKey.new()
 key.pressed = true
 key.keycode = KEY_F4
 zone._unhandled_key_input(key)
 var i := 0
 for enemy in get_tree().get_nodes_in_group("enemies"):
  if not zone.is_ancestor_of(enemy): continue
  enemy.position = [Vector3(-3, .2, -4), Vector3(3, .2, -5), Vector3(0, .2, -7)][i]
  i += 1
 var help := Label.new()
 help.text = "ЛУК: удерживать ЛКМ / RT    •    Space / A — перекат    •    F7 — начать бой заново"
 help.position = Vector2(20, 88)
 help.add_theme_font_size_override("font_size", 16)
 zone.get_node("PreviewControls").add_child(help)
 if not checking and ("--check" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args()):
  checking = true
  _check.call_deferred()
func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7: _start()
func _check() -> void:
 for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
 await get_tree().create_timer(1.5).timeout
 assert(Game.testing and player.current_weapon().projectile == &"wood_arrow")
 assert(get_tree().get_nodes_in_group("enemies").size() == 3)
 assert(zone.get_node("CameraRig/Camera3D").current and player.is_on_floor())
 if "--check" in OS.get_cmdline_user_args():
  var previous: WeakRef = weakref(player)
  var restart := InputEventKey.new()
  restart.keycode = KEY_F7
  restart.pressed = true
  _unhandled_key_input(restart)
  await get_tree().create_timer(1.0).timeout
  assert(previous.get_ref() == null and Game.player == player)
  assert(get_tree().get_nodes_in_group("enemies").size() == 3)
  assert(Game.testing and zone.get_node("CameraRig/Camera3D").current)
 if "--capture" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://docs/screens/archery_combat_preview.png")
 print("ARCHERY_COMBAT_PREVIEW_OK: courtyard, 3 enemies, gameplay camera, no menu, no saves")
 get_tree().quit()
