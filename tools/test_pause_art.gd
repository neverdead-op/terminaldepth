extends Node
## Пауза и отмена назначения клавиш без изменения настоящих настроек и сохранений.
var menu: Control
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 set_meta("test_runner", true)
 _run.call_deferred()
func _capture(label: String) -> void:
 if "--capture" not in OS.get_cmdline_user_args(): return
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://output/" + label + ".png")
func _run() -> void:
 var player = Game.start_test(1, &"normal", "res://scenes/art/level1_supplied.tscn", {"fixed_bow_loadout":false,"start_weapon":&"rifle"})
 await get_tree().create_timer(0.8).timeout
 player.set_physics_process(false)
 for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
 for child in player.get_node("HUD").get_children():
  if child is CanvasLayer:
   for node in child.get_children():
    if node.get_script() == preload("res://scripts/pause_menu.gd"): menu = node
 assert(menu != null)
 var pause := InputEventAction.new(); pause.action = &"pause_menu"; pause.pressed = true
 menu._input(pause)
 assert(menu.visible and get_tree().paused and menu._items().size() == 8)
 for i in 8:
  assert(menu._item_at(menu._main_item_rect(i).get_center()) and menu._cursor == i)
 menu._cursor = 0
 await _capture("pause_menu_art")
 var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = menu._main_item_rect(3).get_center()
 menu._input(click)
 assert(menu._page == &"controls")
 var rows: int = menu.InputSetup.REBINDABLE.size()
 for i in rows:
  assert(menu._item_at(menu._r(menu._control_rect(i)).get_center()) and menu._cursor == i)
  assert(menu._r(menu._control_rect(i)).end.y < menu.size.y)
  assert(menu._item_at(menu._p(Vector2(900, 145 + i * 26))) and menu._column == 1)
 for j in 2:
  assert(menu._item_at(menu._r(menu._extra_rect(j)).get_center()) and menu._cursor == rows + j)
 menu._cursor = 0; menu._column = 0
 menu._accept()
 assert(menu._waiting)
 var cancel := InputEventKey.new(); cancel.physical_keycode = KEY_ESCAPE; cancel.pressed = true
 menu._input(cancel)
 assert(not menu._waiting and menu._page == &"controls")
 await _capture("pause_controls_art")
 var back := InputEventAction.new(); back.action = &"menu_back"; back.pressed = true
 menu._input(back)
 assert(menu._page == &"main" and menu.visible and get_tree().paused)
 menu._input(back)
 assert(not menu.visible and not get_tree().paused)
 print("PAUSE_ART_OK: 8 buttons, all control rows and columns, cancel binding, Esc open/back/close; no saves/settings written")
 get_tree().quit()
