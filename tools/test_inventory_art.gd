extends Node
## Рабочие области нового рисунка, реальные действия инвентаря и пауза. Сохранения отключены.
const Art := preload("res://scripts/inventory_art.gd")
const DB := preload("res://scripts/item_db.gd")
var screen: Control
var player: Node

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 set_meta("test_runner", true)
 _run.call_deferred()

func _click(at: Vector2, twice := false) -> void:
 var button := InputEventMouseButton.new()
 button.button_index = MOUSE_BUTTON_LEFT
 button.position = at
 button.pressed = true
 button.double_click = twice
 screen._input(button)
 button = button.duplicate()
 button.pressed = false
 button.double_click = false
 screen._input(button)

func _run() -> void:
 player = Game.start_test(1, &"normal", "res://scenes/art/level1_supplied.tscn", {"fixed_bow_loadout":false,"start_weapon":&"rifle","start_weapon_corp":&"","animation_library_path":"res://assets/animations/model1_shooter.tres"})
 await get_tree().create_timer(1.2).timeout
 player.set_physics_process(false)
 for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
 var hud: Node = player.get_node("HUD")
 screen = hud.inventory_screen
 var second_weapon := GearItem.create(DB.base_by_id(&"shotgun"), 1, 0)
 assert(player.inventory.add_item(second_weapon))
 assert(player.inventory.equip_weapon(second_weapon, 1) == "")
 var fire: ModuleData = preload("res://data/modules/fire.tres").duplicate()
 assert(player.inventory.add_item(fire))
 var ricochet: ModuleData = preload("res://data/modules/ricochet.tres").duplicate()
 assert(player.inventory.add_item(ricochet))
 var helmet := GearItem.create(DB.base_by_id(&"patrol_helmet"), 1, 0)
 assert(player.inventory.add_item(helmet))
 screen.open_context(&"", null)
 await get_tree().process_frame
 assert(Game.testing and screen.visible and get_tree().paused)
 assert(screen._cells.filter(func(c): return c.kind == "grid" and not c.get("module_strip", false)).size() == 60)
 assert(screen._cells.filter(func(c): return c.kind == "equip").size() == 7)
 assert(Art.weapon_rect(0).size.y >= 100 and Art.weapon_rect(0, true).size.x >= 240)
 assert(Art.LEFT_PANEL.size.x / Art.SIZE.x < 0.37 and Art.RIGHT_PANEL.size.x / Art.SIZE.x < 0.37)
 assert(not screen._has_cell_at(screen._p(Vector2(836, 470))))
 # Каждая клетка и большая вещь попадают в нарисованную сетку, включая нижнюю строку.
 for y in 5:
  for x in 12:
   var rect: Rect2 = screen._grid_rect(Vector2i(x, y), Vector2i.ONE)
   assert(rect == screen._r(Art.bag_rect(Vector2i(x, y))))
   screen._hover(rect.get_center())
   assert(screen._cells[screen._cursor].get("cell", Vector2i(-1, -1)) == Vector2i(x, y))
 # Настоящее надевание двойным щелчком по вещи.
 var e: Dictionary = player.inventory.find_entry(helmet)
 _click(screen._grid_rect(e.pos, PlayerInventory.size_of(helmet)).get_center(), true)
 assert(player.inventory.equipment[&"helmet"] == helmet)
 # Настоящее перетаскивание из сумки в первое гнездо оружия.
 e = player.inventory.find_entry(fire)
 var at: Vector2 = screen._grid_rect(e.pos, Vector2i.ONE).get_center()
 var button := InputEventMouseButton.new()
 button.button_index = MOUSE_BUTTON_LEFT; button.pressed = true; button.position = at
 screen._input(button)
 var socket: Vector2 = screen._cells[screen._find_socket(0, 0)].rect.get_center()
 var motion := InputEventMouseMotion.new(); motion.position = socket
 screen._input(motion)
 button = button.duplicate(); button.pressed = false; button.position = socket
 screen._input(button)
 assert(player.get_module(0, 0) == fire and screen._mode == screen.Mode.NORMAL)
 screen._hold_module(ricochet)
 screen._cursor = screen._find_socket(0, 1)
 screen._accept()
 assert(player.get_module(0, 1) == ricochet)
 # Кнопка нижней панели работает с выбранным предметом.
 var gear := GearItem.create(DB.base_by_id(&"tactical_gloves"), 1, 0)
 assert(player.inventory.add_item(gear))
 e = player.inventory.find_entry(gear)
 screen._hover(screen._grid_rect(e.pos, PlayerInventory.size_of(gear)).get_center())
 var use_button: Dictionary = screen._cells.filter(func(c): return c.kind == "menu_action" and c.action == 0)[0]
 _click(use_button.rect.get_center())
 assert(player.inventory.equipment[&"gloves"] == gear)
 # Наполнение и переход на следующую страницу не теряют модули.
 for id in [&"electric", &"acid", &"damage", &"pierce", &"homing"]:
  assert(player.inventory.add_item(load("res://data/modules/%s.tres" % id).duplicate()))
 var armor := GearItem.create(DB.base_by_id(&"spacesuit"), 1, 0)
 assert(player.inventory.add_item(armor))
 # Снимок с предметами и живыми модулями, без плавающей подсказки поверх сетки.
 screen._cursor = screen._cells.size() - 1
 await get_tree().process_frame
 await get_tree().process_frame
 if "--capture" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://output/inventory_weapon_cards.png")
 var weapon_cell: Dictionary = screen._cells.filter(func(c): return c.kind == "weapon" and c.w == 0)[0]
 screen._hover(weapon_cell.rect.get_center())
 assert(screen._tooltip_lines().get("weapon_preview") == player.weapon_item(0))
 if "--capture" in OS.get_cmdline_user_args():
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://output/inventory_weapon_inspect.png")
 for i in 15:
  assert(player.inventory.add_item(preload("res://data/modules/damage.tres").duplicate()))
 assert(screen._owned().size() == 20)
 assert(screen._cells.filter(func(c): return c.get("module_strip", false)).size() == 18)
 screen._cursor = screen._cells.find(screen._cells.filter(func(c): return c.kind == "module_page" and c.dir == 1)[0])
 screen._accept()
 assert(screen._module_page == 1)
 assert(screen._cells.filter(func(c): return c.get("module_strip", false)).size() == 2)
 # Оставшиеся две нижние кнопки: сравнение с надетым и выбрасывание в тестовый мир.
 var spare := GearItem.create(DB.base_by_id(&"patrol_helmet"), 1, 0)
 assert(player.inventory.add_item(spare))
 e = player.inventory.find_entry(spare)
 screen._hover(screen._grid_rect(e.pos, PlayerInventory.size_of(spare)).get_center())
 var compare_button: Dictionary = screen._cells.filter(func(c): return c.kind == "menu_action" and c.action == 1)[0]
 _click(compare_button.rect.get_center())
 assert(screen._compare_requested and screen._tooltip_lines().get("compare") == helmet)
 var drop_button: Dictionary = screen._cells.filter(func(c): return c.kind == "menu_action" and c.action == 2)[0]
 _click(drop_button.rect.get_center())
 assert(player.inventory.find_entry(spare).is_empty())
 var tabs: Control
 for child in screen.get_parent().get_children():
  if child.get_script() == preload("res://scripts/menu_tabs.gd"): tabs = child
 assert(tabs != null)
 assert(tabs._tab_rect(0) == screen._r(Art.tab_rect(0)))
 var tab_click := InputEventMouseButton.new()
 tab_click.button_index = MOUSE_BUTTON_LEFT; tab_click.pressed = true; tab_click.position = tabs._tab_rect(1).get_center()
 tabs._input(tab_click)
 assert(hud.skills_screen.visible and not screen.visible and get_tree().paused)
 screen = hud.skills_screen
 var back := InputEventAction.new(); back.action = &"menu_back"; back.pressed = true
 screen._input(back)
 assert(not screen.visible and not get_tree().paused)
 print("INVENTORY_ART_OK: 60 cells, 7 equipment slots, mouse equip, drag module, all 3 action buttons, 20 modules over 2 pages, tabs and pause; no saves")
 get_tree().quit()
