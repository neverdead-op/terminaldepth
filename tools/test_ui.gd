extends Node
## Проверка живого интерфейса без записи сохранения.
const DB := preload("res://scripts/item_db.gd")

func _ready() -> void:
	set_meta("test_runner", true)
	_run.call_deferred()

func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screens/ui_" + label + ".png")

func _run() -> void:
	var player := Game.start_test(1, &"normal")
	await get_tree().create_timer(1.0).timeout
	player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	await Game.complete_zone(player)
	await get_tree().create_timer(0.6).timeout
	player.set_physics_process(false)
	for id in [&"rifle", &"plasma_cutter"]:
		var item := GearItem.create(DB.base_by_id(id), 1, 1)
		item.corp = &"helix"
		assert(player.inventory.add_item(item))
		assert(player.inventory.equip_weapon(item, 1 if id == &"rifle" else 2) == "")
	player.select_weapon(1)
	for id in [&"patrol_helmet", &"spacesuit", &"tactical_gloves", &"servo_boots", &"reflex_implant", &"shield_module"]:
		var gear := GearItem.create(DB.base_by_id(id), 4, 1)
		assert(player.inventory.add_item(gear))
		assert(player.inventory.equip(gear) == "")
	for id in [&"rifle", &"sensor_helmet", &"combat_mitts", &"reflex_implant"]:
		assert(player.inventory.add_item(GearItem.create(DB.base_by_id(id), 2, 1)))
	player.gold = 10000
	player.hp = 94
	player.max_es = 60
	player.es = 38
	var hud: Node = player.get_node("HUD")
	var inventory: Control = hud.inventory_screen
	var skills: Control = hud.skills_screen
	await get_tree().process_frame
	await _capture("hud")
	inventory.open_context(&"", null)
	await get_tree().process_frame
	assert(inventory.visible and not skills.visible and get_tree().paused)
	assert(inventory._cells.filter(func(c): return c.kind == "socket").is_empty())
	assert(inventory._cells.filter(func(c): return c.kind == "weapon").size() == 3)
	await _capture("inventory")
	var module := preload("res://data/modules/damage.tres").duplicate()
	assert(player.inventory.add_item(module))
	inventory._hold_module(module)
	await get_tree().process_frame
	assert(skills.visible and not inventory.visible and get_tree().paused)
	assert(skills._mode == skills.Mode.HOLD_MODULE)
	skills._cursor = skills._find_socket(1, 1)
	skills._accept()
	assert(player.weapon_item(1).modules[1] == module)
	await _capture("skills")
	var tabs: Control
	for child in skills.get_parent().get_children():
		if child.get_script() == preload("res://scripts/menu_tabs.gd"): tabs = child
	assert(tabs != null)
	var next := InputEventAction.new()
	next.action = &"menu_tab_prev"
	next.pressed = true
	tabs._input(next)
	assert(inventory.visible and not skills.visible and get_tree().paused)
	inventory._toggle()
	assert(not get_tree().paused)
	var vendor: Node
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.get("vendor_name") == "Angie": vendor = n
	assert(vendor != null)
	# Повторяемая витрина для сравнения снимков, настоящие базы и реальные цены.
	vendor.stock.entries.clear()
	for id in [&"rifle", &"shotgun", &"plasma_cutter", &"carbine", &"patrol_helmet", &"spacesuit", &"tactical_gloves", &"servo_boots", &"reflex_implant"]:
		var sample := GearItem.create(DB.base_by_id(id), 1, 1)
		sample.corp = &"helix"
		assert(vendor.stock.add_item(sample))
	vendor.stock.add_currency(&"mutagen", 2)
	vendor.stock.add_currency(&"unstable", 1)
	inventory.open_context(&"vendor", vendor)
	await get_tree().process_frame
	inventory._set_page(1)
	assert(inventory._shop() == vendor.stocks[1])
	for cell in inventory._cells:
		if cell.kind == "shop": assert(not vendor.stocks[1].entry_at(cell.cell).is_empty())
	inventory._set_page(0)
	var entry: Dictionary = vendor.stock.entries[0]
	var bought = entry.item
	var price: int = inventory._price(bought)
	var before: int = player.gold
	for i in inventory._cells.size():
		var c: Dictionary = inventory._cells[i]
		if c.kind == "shop" and c.cell == entry.pos: inventory._cursor = i
	inventory._remember_trade({"kind": "shop", "cell": entry.pos})
	await _capture("trade")
	for i in inventory._cells.size():
		if inventory._cells[i].kind == "trade_action": inventory._cursor = i
	inventory._accept()
	assert(player.gold == before - price)
	assert(not player.inventory.find_entry(bought).is_empty())
	var owned: Dictionary = player.inventory.find_entry(bought)
	inventory._remember_trade({"kind": "grid", "cell": owned.pos})
	inventory._trade_action()
	assert(player.inventory.find_entry(bought).is_empty())
	assert(player.gold == before - price + DB.sell_price(bought))
	# Большой ассортимент: дополнительные страницы не скрывают доступ к товарам.
	vendor.stock.entries.clear()
	for i in 6:
		assert(vendor.stock.add_item(GearItem.create(DB.base_by_id(&"spacesuit"), 1, 0)))
	for i in 6:
		assert(vendor.stock.add_item(GearItem.create(DB.base_by_id(&"servo_boots"), 1, 0)))
	inventory._layout()
	assert(inventory._catalog_pages == 2)
	assert(inventory._cells.filter(func(c): return c.kind in ["inv_section", "trade_tab"]).is_empty())
	var shown: Array[Vector2i] = []
	for page in inventory._catalog_pages:
		inventory._catalog_page = page
		inventory._layout()
		var shop_cells: Array = inventory._cells.filter(func(c): return c.kind == "shop")
		for c in shop_cells:
			assert(not shown.has(c.cell))
			shown.append(c.cell)
			assert(inventory._r(inventory.LEFT).encloses(c.rect))
			for other in shop_cells:
				if c.cell != other.cell: assert(not c.rect.intersects(other.rect))
	assert(shown.size() == vendor.stock.entries.size())
	inventory._catalog_page = 0
	inventory._layout()
	await _capture("trade_full")
	inventory._toggle()
	assert(not get_tree().paused)
	preload("res://scripts/npc_conversation.gd").show_for(player, vendor, "Angie")
	await get_tree().process_frame
	var conversation: Control = hud.get_child(hud.get_child_count() - 1)
	await _capture("dialogue")
	conversation._story("Снаряжение и навыки")
	var box: Control = get_tree().get_first_node_in_group("dialog_box")
	box._shown_chars = 1000
	await _capture("story")
	assert(box._body.get_line_count() >= 2)
	assert(box._body.get_line_count() * box._body.get_line_height() < box._body.size.y)
	var back := InputEventAction.new()
	back.action = &"menu_back"
	back.pressed = true
	box._input(back)
	assert(conversation.visible and get_tree().paused)
	conversation._close()
	var loot := preload("res://scripts/loot_pickup.gd")
	for id in [&"plasma_cutter", &"rifle", &"pump_shotgun"]:
		loot.drop(player.get_parent(), player.global_position + Vector3(randf_range(-1, 1), 0.2, -2), &"gear", GearItem.create(DB.base_by_id(id), 1, 1))
	await get_tree().create_timer(0.3).timeout
	await _capture("loot")
	for key in ["gold", "merchant_frame", "item_slot", "skill_socket", "button", "paperdoll", "portrait_angie", "inventory_cell", "minimap"]:
		var texture: Texture2D = load("res://assets/ui/gothic_v2/" + key + ".png")
		assert(texture.get_image().get_pixel(0, 0).a < 0.1)
	print("UI_OK: larger bag, large merchant grid, buy/sell, all stock pages, no redundant tabs, dialogue wrapping")
	get_tree().quit()
