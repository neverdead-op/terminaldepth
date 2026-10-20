extends Node
## Проверка главного меню без запуска забега и записи настроек или сохранений.
const Menu := preload("res://scripts/main_menu.gd")
var menu: Control
func _ready() -> void:
 set_meta("test_runner", true)
 _run.call_deferred()
func _capture(name: String) -> void:
 if "--capture" not in OS.get_cmdline_user_args(): return
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://output/" + name + ".png")
func _run() -> void:
 menu = Menu.new()
 add_child(menu)
 await get_tree().process_frame
 assert(menu.ITEMS.size() == 4 and menu._page == &"main")
 for letter in "ПродолжитьНоваяиграЯзыкВыйтиЁё": assert(menu._font.has_char(letter.unicode_at(0)))
 for dims in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 768), Vector2(2560, 1080)]:
  menu.size = dims
  for i in menu.ITEMS.size():
   var r: Rect2 = menu._item_rect(i)
   assert(Rect2(Vector2.ZERO, dims).encloses(r))
   if menu.ITEMS[i].get("enabled", true): assert(menu._item_at(r.get_center()) == i)
 menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await get_tree().process_frame
 await _capture("main_menu_endorama")
 var index := 0
 for i in menu.ITEMS.size():
  if menu.ITEMS[i].id == &"new": index = i
 var click := InputEventMouseButton.new()
 click.pressed = true; click.button_index = MOUSE_BUTTON_LEFT; click.position = menu._item_rect(index).get_center()
 menu._input(click)
 assert(menu._page == &"new" and menu.ITEMS.size() == 5)
 for i in 5: assert(menu._item_at(menu._item_rect(i).get_center()) == i)
 await _capture("main_menu_modes")
 var back := InputEventAction.new(); back.action = &"menu_back"; back.pressed = true
 menu._input(back)
 assert(menu._page == &"main" and menu.ITEMS.size() == 4)
 # Отключённое продолжение не реагирует на подтверждение; стик его пропускает.
 menu.ITEMS[0] = menu.ITEMS[0].duplicate()
 menu.ITEMS[0].enabled = false
 menu._cursor = 0
 menu._accept()
 assert(menu._page == &"main")
 menu._cursor = 1; menu._step(-1)
 assert(menu._cursor == 3)
 print("MAIN_MENU_ART_OK: Cyrillic font, 4 main buttons, 5 mode buttons, mouse, back, disabled continue, 4 aspect ratios; no saves/settings written")
 get_tree().quit()
