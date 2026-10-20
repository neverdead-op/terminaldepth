extends Control
## Экран инвентаря в стиле PoE 2 (Tab / I, на геймпаде — Back). Игра на паузе, пока он открыт.
## Слева — панель оружия (как раздел камней в PoE 2): у каждого оружия строка и ряд гнёзд под модули,
## внизу — характеристики персонажа. Справа — экипировка на персонаже и сетка сумки 12×5:
## вещи занимают несколько клеток, ксено-фрагменты лежат стопками. Посередине видно игру.
## При наведении всплывает подсказка с названием, свойствами и кнопками.
##
## Управление одно для геймпада и клавиатуры/мыши:
##   крестовина / стик / стрелки / мышь — курсор;
##   A или X(квадрат) / Enter / ЛКМ — главное действие:
##       модуль → взять и вставить в гнездо; вещь в сумке → надеть; надетая вещь → снять;
##       модуль в гнезде → вынуть; фрагмент → взять и применять к вещам; чистый модуль → выбрать модуль;
##       строка оружия → взять его в руки; оружие в сумке → в один из двух слотов;
##   Y(треугольник) / F / ПКМ — модуль из сумки сразу в оружие в руках; на строке оружия — убрать его в сумку;
##   B(круг) / Esc — отменить / закрыть.

const PASSIVES := preload("res://scripts/passive_db.gd")
const UiIcons := preload("res://scripts/ui_icons.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const ModuleDB := preload("res://scripts/module_db.gd")
const Style := preload("res://scripts/ui_style.gd")
const Typography := preload("res://scripts/ui_typography.gd")

## Виртуальный размер экрана, под который разложен интерфейс (растягивается под окно).
const DESIGN := Vector2(1040, 720)
const HORIZONTAL_FIT := DESIGN.x / 1280.0
const GRID_ORIGIN := Vector2(794, 438)
## Клетка сумки (крупнее клеток торговца — лучше видно вещи).
const BAG_CELL := 38.0
## Левая и правая панели.
const LEFT := Rect2(10, 10, 452, 700)
const RIGHT := Rect2(778, 10, 492, 700)
## Сетка товаров торговца — в левой панели.
const SHOP_ORIGIN := Vector2(40, 104)
const LOOT := preload("res://scripts/loot_pickup.gd")
const CELL := 31.0
const SHOP_CELL := 60.0
const SHOP_COLUMNS := 6
const SHOP_ROWS := 9
var _catalog_pages := 1
const TOOLTIP_WIDTH := 300.0
## Насколько мельче шрифт в подсказках, чем задано в строках.
const TIP_FONT := 0.88
## Подписи пустых слотов экипировки.
const SLOT_CAPTIONS := {&"helmet": "Шлем", &"body": "Броня", &"gloves": "Перчатки", &"boots": "Ботинки",
		&"implant1": "Имплант", &"implant2": "Имплант", &"combat": "Модуль"}

enum Mode { NORMAL, HOLD_MODULE, HOLD_CURRENCY, CHOOSE_MODULE, HOLD_ITEM }

## Окно выбора чистого модуля: значков в ряду, размер значка, зазор, отступы и высоты зон.
const PICK_COLS := 7
const PICK_TILE := 52.0
const PICK_GAP := 8.0
const PICK_PAD := 20.0
const PICK_HEADER := 50.0
const PICK_INFO := 88.0
const PICK_FOOTER := 26.0

@export var panel_color := Color(0.028, 0.032, 0.042, 0.97)
@export var frame_color := Color(0.64, 0.49, 0.29, 0.85)
## Фон ячеек — в цвет клеток картинок-значков (почти чёрный с синевой, как на референсе).
const ICON_BG := Color(0.012, 0.018, 0.028, 0.96)
const HERO_DOLL := preload("res://assets/ui/ref/hero_doll.png")
@export var line_color := Color(1, 1, 1, 0.1)
@export var text_color := Color(0.9, 0.88, 0.82)
@export var dim_text := Color(0.6, 0.6, 0.58)
@export var affix_color := Color(0.53, 0.53, 1.0)
@export var hint_color := Color(0.95, 0.8, 0.45)
@export var cursor_color := Color(1, 1, 1)
## Задержка перед автоповтором при удержании направления и шаг повтора (сек).
@export var repeat_delay := 0.32
@export var repeat_step := 0.11

var player: Node
## Первое гнездо оружия — тип патронов (как player.AMMO_SOCKET).
const AMMO_SOCKET := 0
var inventory: PlayerInventory
## Отдельная вкладка навыков использует тот же инвентарь и проверки модулей.
var skills_screen: Control
var is_skills_view := false
var _defer_overlays := false
var _trade_selection: Dictionary = {}
var _catalog_page := 0

var _cells: Array[Dictionary] = []
var _cursor := 0
var _mode := Mode.NORMAL
var _held_module: ModuleData
var _held_currency := &""
var _held_stack: PlayerInventory.CurrencyStack
var _return_cursor := 0
var _origin := Vector2.ZERO
var _scale := 1.0
var _layout_size := Vector2.ZERO
var _repeat_left := 0.0
var _last_dir := Vector2.ZERO
var _message := ""
var _message_left := 0.0
var _time := 0.0
var _font: Font
## Режим окна: "" — обычный инвентарь, &"vendor" — торговец, &"salvage" — верстак разбора.
var _context := &""
## Торговец или верстак, который открыл окно.
var _source: Node
## Страница товаров торговца (на складе: 0 — валюта, 1… — вкладки с вещами).
var _shop_page := 0
## Вещь «в руке» (перенос): откуда взяли — чтобы вернуть при отмене.
var _held_item = null
var _held_from: PlayerInventory
var _held_from_pos := Vector2i.ZERO
## Мышь: где нажали (для перетаскивания) и идёт ли перетаскивание.
var _press_index := -1
var _press_pos := Vector2.ZERO
var _dragging := false
## Нажатие было двойным щелчком (для вещей одиночный щелчок ничего не делает).
var _press_double := false
## Ячейки, где действие — только двойным щелчком (надеть/снять/вставить/купить/продать/разобрать).
const DOUBLE_CLICK_KINDS := ["grid", "shop", "equip", "socket"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.fallback_font
	inventory = player.get_node("Inventory")  # @onready у игрока ещё не сработал: HUD готов раньше
	inventory.changed.connect(_on_inventory_changed)


## Сумка или оружие изменились (новое гнездо от резака, другой ствол): ячейки перестраиваем сразу,
## курсор остаётся на той же ячейке.
func _on_inventory_changed() -> void:
	if visible and not _cells.is_empty():
		var c: Dictionary = _cells[clampi(_cursor, 0, _cells.size() - 1)]
		var keep := _cell_id(c)
		_layout()
		for i in _cells.size():
			if _cell_id(_cells[i]) == keep:
				_cursor = i
				break
	queue_redraw()


func _cell_id(c: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [c.kind, c.get("w", ""), c.get("s", ""), c.get("cell", ""), c.get("key", ""),
			c.get("page", c.get("id", ""))]


# --- Ввод ------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not is_skills_view:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_left(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _press_index >= 0 and not _dragging \
			and event.position.distance_to(_press_pos) > 10.0:
		_start_drag()
	if event.is_action_pressed("menu_move"):
		_move_action()
	elif event.is_action_pressed("menu_accept"):
		if _mode == Mode.HOLD_ITEM:
			_place_held()
		else:
			_accept()
	elif event.is_action_pressed("menu_drop"):
		_drop()
	elif event.is_action_pressed("menu_alt"):
		_quick()
	elif event.is_action_pressed("menu_back"):
		_back()
	elif event is InputEventMouseMotion:
		_hover(event.position)
		return
	elif event is InputEventMouseButton and event.pressed:
		if not _has_cell_at(event.position):
			return
		_hover(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if _mode != Mode.NORMAL:
				_back()
			else:
				_quick()
	else:
		return
	get_viewport().set_input_as_handled()


## Левая кнопка мыши: нажали на вещь и повели — перетаскивание; просто щёлкнули — обычное действие.
func _mouse_left(event: InputEventMouseButton) -> void:
	if not _has_cell_at(event.position):
		if not event.pressed and _dragging:
			_cancel_held()
		_press_index = -1
		_dragging = false
		return
	_hover(event.position)
	if event.pressed:
		if _cells[_cursor].kind == "close":
			_accept()
			return
		if _mode == Mode.HOLD_ITEM:
			_place_held()
			return
		var kind: String = _cells[_cursor].kind
		if _mode == Mode.NORMAL and _pickable(_cursor):
			_press_index = _cursor
			_press_pos = event.position
			_press_double = event.double_click
			return
		if _mode == Mode.NORMAL and kind in DOUBLE_CLICK_KINDS and not event.double_click:
			return  # одиночный щелчок по вещи — только выбрать
		_accept()
		return
	# Отпустили.
	if _dragging:
		_dragging = false
		_press_index = -1
		if not _place_held():
			_cancel_held()
		return
	if _press_index >= 0:
		_press_index = -1
		if _press_double:
			_accept()


func _start_drag() -> void:
	_cursor = _press_index
	if _pick_up(_cursor):
		_dragging = true
	else:
		_press_index = -1


## X / □: взять вещь под курсором «в руку» или положить ту, что в руке.
func _move_action() -> void:
	if _mode == Mode.HOLD_ITEM:
		_place_held()
	elif _mode == Mode.NORMAL and _pickable(_cursor):
		_pick_up(_cursor)


# --- Перенос вещей ---------------------------------------------------------------------

## Сетка, к которой относится ячейка: сумка или вкладка склада.
func _container_of(c: Dictionary) -> PlayerInventory:
	if c.kind == "grid":
		return inventory
	if c.kind == "shop" and _context == &"stash" and _shop_page > 0:
		return _shop()
	return null


func _pickable(i: int) -> bool:
	var c: Dictionary = _cells[i]
	var box := _container_of(c)
	return box != null and not box.entry_at(c.cell).is_empty()


func _pick_up(i: int) -> bool:
	var c: Dictionary = _cells[i]
	var box := _container_of(c)
	if box == null:
		return false
	var e := box.entry_at(c.cell)
	if e.is_empty():
		return false
	_held_item = e.item
	_held_from = box
	_held_from_pos = e.pos
	box.entries.erase(e)
	box.changed.emit()
	_mode = Mode.HOLD_ITEM
	Sfx.play(&"ui_click", player.global_position)
	return true


## Положить вещь из руки в ячейку под курсором. true — положили (или поменяли местами).
func _place_held() -> bool:
	var c: Dictionary = _cells[_cursor]
	var item = _held_item
	var swapped = null
	var ok := false
	var box := _container_of(c)
	if c.kind == "socket" and item is ModuleData:
		var error: String = player.module_error(c.w, c.s, item)
		if error != "":
			_show_message(error)
			return false
		# На время установки возвращаем модуль в сумку; замена сохраняет старый модуль там же.
		if not inventory.add_item(item):
			_show_message("Нет места для замены модуля")
			return false
		error = player.insert_module(c.w, c.s, item)
		if error != "":
			inventory.remove_item(item)
			_show_message(error)
			return false
		ok = true
	elif c.kind == "scur" and item is PlayerInventory.CurrencyStack:
		Game.stash_currency[item.id] = Game.stash_currency.get(item.id, 0) + item.count
		ok = true
	elif box != null:
		if box != inventory and item is PlayerInventory.CurrencyStack:
			# Фрагменты на складе живут во вкладке «Валюта».
			Game.stash_currency[item.id] = Game.stash_currency.get(item.id, 0) + item.count
			ok = true
		else:
			var result := box.place(item, c.cell)
			ok = result.ok or result.has("merged")
			swapped = result.swapped
			if result.has("merged") and not result.ok:
				swapped = item  # не всё влезло в стопку — остаток в руке
	elif c.kind == "equip" and item is GearItem and not item.is_weapon():
		var slot: StringName = &"implant" if String(c.key).begins_with("implant") else c.key
		if item.slot == slot:
			swapped = inventory.equipment[c.key]
			inventory.equipment[c.key] = item
			inventory.changed.emit()
			ok = true
	elif c.kind == "weapon" and item is GearItem and item.is_weapon():
		if c.w in range(PlayerInventory.WEAPON_COUNT) and item.slot in [&"weapon", &"mines"]:
			swapped = inventory.weapons[c.w]
			inventory.weapons[c.w] = item
			inventory.changed.emit()
			player.select_weapon(c.w)
			ok = true
	if not ok:
		_show_message("Сюда нельзя")
		return false
	Sfx.play(&"key_pickup", player.global_position, -8.0)
	if swapped != null:
		_held_item = swapped
		_held_from = inventory
		_held_from_pos = Vector2i(-1, -1)
	else:
		_held_item = null
		_mode = Mode.NORMAL
	return true


## Отмена: вещь возвращается туда, откуда её взяли (или в любое свободное место сумки, или на пол).
func _cancel_held() -> void:
	if _held_item == null:
		_mode = Mode.NORMAL
		return
	var item = _held_item
	_held_item = null
	_mode = Mode.NORMAL
	var box: PlayerInventory = _held_from if _held_from != null else inventory
	if _held_from_pos.x >= 0 and box._area_free(Rect2i(_held_from_pos, PlayerInventory.size_of(item))):
		box.entries.append({"item": item, "pos": _held_from_pos})
		box.changed.emit()
		return
	if item is PlayerInventory.CurrencyStack:
		var left := inventory.add_currency(item.id, item.count)
		if left <= 0:
			return
		item.count = left
	elif inventory.add_item(item):
		return
	var at: Vector3 = player.global_position - player.global_basis.z * 1.2
	if item is GearItem:
		LOOT.drop(player.get_parent(), at, &"gear", item, 1, true)
	elif item is ModuleData:
		LOOT.drop(player.get_parent(), at, &"module", item, 1, true)
	else:
		LOOT.drop(player.get_parent(), at, &"currency", item.id, item.count, true)


## Открыть окно как торговца или верстак (вызывают vendor.gd и workbench.gd).
func open_context(context: StringName, source: Node) -> void:
	_context = context
	_trade_selection.clear()
	_source = source
	_shop_page = 0
	_catalog_page = 0
	if visible:
		_layout()
	else:
		_toggle()


func _toggle() -> void:
	if player.is_dead():
		return
	if visible and _mode == Mode.HOLD_ITEM:
		_cancel_held()
	_press_index = -1
	_dragging = false
	visible = not visible
	if not visible:
		_context = &""
		_source = null
	get_tree().paused = visible
	_mode = Mode.NORMAL
	_message = ""
	Sfx.play(&"ui_open", player.global_position)
	if visible:
		_layout()
		_cursor = _find_grid(Vector2i.ZERO)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _context == &"vendor" and not _cells.is_empty():
		_remember_trade(_cells[_cursor])
	_message_left -= delta
	var dir := Input.get_vector("menu_left", "menu_right", "menu_up", "menu_down", 0.5)
	if dir.length() > 0.5:
		dir = Vector2(signf(dir.x), 0) if absf(dir.x) > absf(dir.y) else Vector2(0, signf(dir.y))
		if dir != _last_dir:
			_move(dir)
			_repeat_left = repeat_delay
		else:
			_repeat_left -= delta
			if _repeat_left <= 0.0:
				_move(dir)
				_repeat_left = repeat_step
	_last_dir = dir if dir.length() > 0.5 else Vector2.ZERO
	queue_redraw()


## Переход к ближайшей подходящей ячейке в нужную сторону. Клетки одной большой вещи пропускаются.
func _move(dir: Vector2) -> void:
	var current_key = _key(_cursor)
	var from: Vector2 = _cell_rect(_cursor).get_center()
	var best := -1
	var best_score := INF
	for i in _cells.size():
		if i == _cursor or not _selectable(i):
			continue
		if current_key != null and _key(i) == current_key:
			continue
		var d: Vector2 = _cells[i].rect.get_center() - from
		var along := d.dot(dir)
		if along < 4.0:
			continue
		var score := along + absf(d.dot(dir.orthogonal())) * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_cursor = best
		Sfx.play(&"ui_click", player.global_position, -10.0)


## Что «под» ячейкой: у клеток одной вещи — сама вещь, иначе null.
func _key(i: int):
	var c: Dictionary = _cells[i]
	if c.kind == "grid":
		var e := inventory.entry_at(c.cell)
		return e.item if not e.is_empty() else null
	if c.kind == "shop":
		var e := _shop().entry_at(c.cell)
		return e.item if not e.is_empty() else null
	return null


func _selectable(i: int) -> bool:
	var c: Dictionary = _cells[i]
	if c.kind == "close": return true
	match _mode:
		Mode.HOLD_MODULE:
			return c.kind == "socket"
		Mode.HOLD_CURRENCY:
			return _gear_at(c) != null
		Mode.CHOOSE_MODULE:
			return c.kind == "pick"
		Mode.HOLD_ITEM:
			return (c.kind == "socket" and _held_item is ModuleData) or c.kind in ["grid", "equip", "weapon", "scur"] or (c.kind == "shop" and _context == &"stash")
	return c.kind != "pick"


func _has_cell_at(screen_pos: Vector2) -> bool:
	for i in _cells.size():
		if _selectable(i) and _cells[i].rect.has_point(screen_pos):
			return true
	return false


func _hover(screen_pos: Vector2) -> void:
	for i in _cells.size():
		if _selectable(i) and _cells[i].rect.has_point(screen_pos):
			_cursor = i
			return


# --- Действия ---------------------------------------------------------------------------

func _accept() -> void:
	var c: Dictionary = _cells[_cursor]
	if c.kind == "close":
		if _mode == Mode.HOLD_ITEM: _cancel_held()
		_toggle()
		return
	match _mode:
		Mode.HOLD_MODULE:
			if c.kind != "socket":
				return
			var error: String = player.insert_module(c.w, c.s, _held_module)
			if error != "":
				_show_message(error)
				return
			_mode = Mode.NORMAL
			Sfx.play(&"key_pickup", player.global_position, -6.0)
		Mode.HOLD_CURRENCY:
			var gear := _gear_at(c)
			if gear == null:
				return
			var error := inventory.apply_currency(_held_currency, gear, _held_stack)
			if error != "":
				_show_message(error)
				return
			Sfx.play(&"heal", player.global_position, -4.0)
			if _held_stack != null and _held_stack.count <= 0:
				_held_stack = null
			if inventory.count(_held_currency) <= 0:
				_mode = Mode.NORMAL
				_cursor = _return_cursor
		Mode.CHOOSE_MODULE:
			if c.kind != "pick":
				return
			var module := inventory.make_module(c.id, _held_stack)
			if module == null:
				_show_message("Нет места в сумке")
				return
			_hold_module(module)
		Mode.NORMAL:
			if _context == &"stash" and c.kind in ["grid", "shop", "scur", "page"]:
				_stash_accept(c)
			else:
				_accept_normal(c)


func _accept_normal(c: Dictionary) -> void:
	if c.kind == "catalog_page":
		_catalog_page += c.dir
		_trade_selection.clear()
		_layout()
		return
	if c.kind == "trade_action":
		_trade_action()
		return
	if c.kind == "shop":
		_buy(c.cell)
		return
	if c.kind == "page":
		_set_page(c.page)
		return
	if _context == &"stash":
		_stash_accept(c)
		return
	if c.kind == "grid" and _context != &"":
		var e := inventory.entry_at(c.cell)
		if not e.is_empty():
			if _context == &"vendor":
				_sell(e.item)
			else:
				_salvage(e.item)
		return
	match c.kind:
		"grid":
			var e := inventory.entry_at(c.cell)
			if e.is_empty():
				return
			var item = e.item
			if item is ModuleData:
				_hold_module(item)
			elif item is GearItem and item.is_weapon():
				var target := _weapon_target(item)
				var error := inventory.equip_weapon(item, target)
				if error != "":
					_show_message(error)
				else:
					player.select_weapon(target)
					Sfx.play(&"reload_end", player.global_position)
			elif item is GearItem:
				var error := inventory.equip(item)
				if error != "":
					_show_message(error)
				else:
					Sfx.play(&"ui_click", player.global_position)
			elif item is PlayerInventory.CurrencyStack:
				_return_cursor = _cursor
				_held_stack = item
				if item.id == &"blank_module":
					_mode = Mode.CHOOSE_MODULE
					_cursor = _find_pick(0)
				else:
					var first := _first_gear_cell()
					if first < 0:
						_show_message("Нет предметов, к которым можно применить")
						return
					_held_currency = item.id
					_mode = Mode.HOLD_CURRENCY
					_cursor = first
				Sfx.play(&"ui_click", player.global_position)
		"socket":
			if player.get_module(c.w, c.s) != null:
				var error: String = player.remove_module(c.w, c.s)
				if error != "":
					_show_message(error)
				else:
					Sfx.play(&"ui_click", player.global_position)
		"equip":
			if inventory.equipment[c.key] != null:
				var error := inventory.unequip(c.key)
				if error != "":
					_show_message(error)
				else:
					Sfx.play(&"ui_click", player.global_position)
		"weapon":
			if c.w < PlayerInventory.WEAPON_COUNT and player.weapon_item(c.w) != null:
				player.select_weapon(c.w)
		"page":
			_set_page(c.page)


# --- Склад ------------------------------------------------------------------------------

## A на складе: вещь из сумки — на склад (фрагменты — во вкладку «Валюта»), со склада — в сумку.
func _stash_accept(c: Dictionary) -> void:
	match c.kind:
		"page":
			_set_page(c.page)
		"grid":
			var e := inventory.entry_at(c.cell)
			if e.is_empty():
				return
			if e.item is PlayerInventory.CurrencyStack:
				Game.stash_currency[e.item.id] = Game.stash_currency.get(e.item.id, 0) + e.item.count
				inventory.remove_item(e.item)
			else:
				var target := _shop() if _shop_page > 0 else null
				var stored := false
				for tab in ([target] if target != null else []) + Game.stash_tabs:
					if tab.add_item(e.item):
						stored = true
						break
				if not stored:
					_show_message("На складе нет места")
					return
				inventory.remove_item(e.item)
			Sfx.play(&"key_pickup", player.global_position, -8.0)
		"shop":
			var e := _shop().entry_at(c.cell)
			if e.is_empty():
				return
			if not inventory.add_item(e.item):
				_show_message("Нет места в сумке")
				return
			_shop().remove_item(e.item)
			Sfx.play(&"key_pickup", player.global_position, -8.0)
		"scur":
			var have: int = Game.stash_currency.get(c.id, 0)
			if have <= 0:
				return
			var take := mini(have, ItemDB.STACK_SIZE)
			var left := inventory.add_currency(c.id, take)
			if left >= take:
				_show_message("Нет места в сумке")
				return
			Game.stash_currency[c.id] = have - (take - left)
			Sfx.play(&"key_pickup", player.global_position, -8.0)
		_:
			_accept_normal(c)


# --- Торговец, верстак, выбросить ----------------------------------------------------

func _shop() -> PlayerInventory:
	if _context == &"stash":
		return Game.stash_tabs[maxi(_shop_page - 1, 0)]
	return _source.stocks[_shop_page]


func _set_page(page: int) -> void:
	_shop_page = page
	_catalog_page = 0
	_trade_selection.clear()
	Sfx.play(&"ui_click", player.global_position)
	if _context in [&"stash", &"vendor"]:
		var keep := _cursor
		_layout()
		_cursor = clampi(keep, 0, _cells.size() - 1)
		for i in _cells.size():
			if _cells[i].kind == "page" and _cells[i].page == page:
				_cursor = i


func _gamble() -> bool:
	return _source != null and _source.get("gamble") == true


func _price(item) -> int:
	return _source.gamble_cost(item) if _gamble() else ItemDB.buy_price(item)


func _sell(item) -> void:
	if item is GearItem and item.has_modules():
		_show_message("Сначала выньте модули из оружия")
		return
	var price := ItemDB.sell_price(item)
	inventory.remove_item(item)
	player.add_gold(price)
	Sfx.play(&"key_pickup", player.global_position, -4.0)


func _buy(cell: Vector2i) -> void:
	var e := _shop().entry_at(cell)
	if e.is_empty():
		return
	var price := _price(e.item)
	if player.gold < price:
		_show_message("Не хватает золота: нужно %d" % price)
		return
	if _gamble():
		# Витрина баз: покупаем новый случайный предмет, сама витрина не пустеет.
		var rolled: GearItem = _source.roll_from(e.item)
		if not inventory.add_item(rolled):
			_show_message("Нет места в сумке")
			return
		player.add_gold(-price)
		Sfx.play(&"key_pickup", player.global_position, -4.0)
		_show_message("Выпало: %s (%s)" % [rolled.display_name(), ItemDB.RARITY_NAMES[rolled.rarity]], rolled.color())
		return
	var ok: bool
	if e.item is PlayerInventory.CurrencyStack:
		ok = inventory.free_spot(Vector2i.ONE).x >= 0 or inventory.count(e.item.id) > 0
		if ok:
			var left := inventory.add_currency(e.item.id, e.item.count)
			if left > 0:
				_show_message("Нет места в сумке")
				return
	else:
		ok = inventory.add_item(e.item)
	if not ok:
		_show_message("Нет места в сумке")
		return
	_shop().remove_item(e.item)
	player.add_gold(-price)
	Sfx.play(&"key_pickup", player.global_position, -4.0)
	_layout()


func _salvage(item) -> void:
	if item is GearItem and item.has_modules():
		_show_message("Сначала выньте модули из оружия")
		return
	var shard := ItemDB.salvage_shards(item)
	if shard.is_empty():
		_show_message("Это нельзя разобрать")
		return
	inventory.remove_item(item)
	var whole := inventory.add_shards(shard[0], shard[1])
	var name: String = ItemDB.CURRENCY[shard[0]].name
	Sfx.play(&"door_open", player.global_position, -4.0)
	if whole > 0:
		Sfx.play(&"level_up", player.global_position, -10.0)
		_show_message("Собран целый %s!" % name, Color(1.0, 0.85, 0.4))
	else:
		_show_message("+%d осколок %s  (%d / %d)" % [shard[1], name, inventory.shards.get(shard[0], 0),
				ItemDB.SHARDS_PER_FRAGMENT], Color(0.6, 1.0, 0.6))


## Выбросить вещь из сумки на пол рядом с игроком (подберётся снова, когда отойдёте и вернётесь).
func _drop() -> void:
	var c: Dictionary = _cells[_cursor]
	if _mode != Mode.NORMAL or c.kind != "grid" or _context != &"":
		return
	var e := inventory.entry_at(c.cell)
	if e.is_empty():
		return
	var item = e.item
	inventory.remove_item(item)
	var level := player.get_parent()
	var at: Vector3 = player.global_position - player.global_basis.z * 1.2
	if item is GearItem:
		LOOT.drop(level, at, &"gear", item, 1, true)
	elif item is ModuleData:
		LOOT.drop(level, at, &"module", item, 1, true)
	else:
		LOOT.drop(level, at, &"currency", item.id, item.count, true)
	Sfx.play(&"ui_click", player.global_position)


## Взять модуль: курсор прыгает к свободному гнезду оружия в руках.
func _hold_module(module: ModuleData) -> void:
	if skills_screen != null:
		_mode = Mode.NORMAL
		visible = false
		skills_screen.open_module(module)
		return
	_held_module = module
	var e := inventory.find_entry(module)
	_return_cursor = _find_grid(e.pos) if not e.is_empty() else _cursor
	var w: int = player.current_weapon_index()
	var slot := _first_free_socket(w, module)
	if slot < 0:
		for other in PlayerInventory.WEAPON_COUNT:
			var candidate := _first_free_socket(other, module)
			if candidate >= 0:
				w = other
				slot = candidate
				break
	if slot < 0:
		_show_message("Нет свободного совместимого гнезда")
		return
	_mode = Mode.HOLD_MODULE
	_cursor = _find_socket(w, slot)
	Sfx.play(&"ui_click", player.global_position)


## В какой слот встанет оружие из сумки: свободный, иначе текущий.
func _weapon_target(item: GearItem) -> int:
	for i in PlayerInventory.WEAPON_COUNT:
		if player.weapon_item(i) == null:
			return i
	return player.current_weapon_index()


func _quick() -> void:
	var c: Dictionary = _cells[_cursor]
	if _context == &"vendor" and c.kind in ["shop", "grid"]:
		_remember_trade(c)
		_trade_action()
		return
	if _mode == Mode.NORMAL and c.kind == "weapon":
		var error := inventory.unequip_weapon(c.w)
		if error != "":
			_show_message(error)
		else:
			Sfx.play(&"ui_click", player.global_position)
		return
	if _mode != Mode.NORMAL or c.kind != "grid":
		return
	var e := inventory.entry_at(c.cell)
	if e.is_empty() or not e.item is ModuleData:
		return
	var w: int = player.current_weapon_index()
	var slot := _first_free_socket(w, e.item)
	if slot < 0:
		_show_message("В оружии «%s» нет свободных гнёзд" % player.weapon_item(w).display_name())
		return
	var error: String = player.insert_module(w, slot, e.item)
	if error != "":
		_show_message(error)
	else:
		Sfx.play(&"key_pickup", player.global_position, -6.0)


func _back() -> void:
	if _mode == Mode.HOLD_ITEM:
		_cancel_held()
		return
	if _mode == Mode.NORMAL:
		_toggle()
		return
	_mode = Mode.NORMAL
	_cursor = clampi(_return_cursor, 0, _cells.size() - 1)
	Sfx.play(&"ui_click", player.global_position)


## Куда встанет модуль: стихия — в гнездо патронов (даже если занято — заменит), остальное — в свободное обычное.
func _first_free_socket(w: int, module: ModuleData = null) -> int:
	for s in player.sockets_of(w):
		if module != null and player.module_error(w, s, module) != "":
			continue
		if player.get_module(w, s) == null or (s == AMMO_SOCKET and module != null and module.is_ammo()):
			return s
	return -1


func _first_gear_cell() -> int:
	for i in _cells.size():
		if _gear_at(_cells[i]) != null:
			return i
	return -1


## Предмет экипировки в ячейке (в сумке или надетый), иначе null.
func _gear_at(c: Dictionary) -> GearItem:
	if c.kind == "grid":
		var e := inventory.entry_at(c.cell)
		return e.item if not e.is_empty() and e.item is GearItem else null
	if c.kind == "equip":
		return inventory.equipment[c.key]
	if c.kind == "weapon":
		return player.weapon_item(c.w)
	return null


var _message_color := Color(1, 0.45, 0.35)


func _show_message(text: String, color := Color(1, 0.45, 0.35)) -> void:
	_message = text
	_message_left = 2.5
	_message_color = color
	if color.r > color.g:
		Sfx.play(&"door_locked", player.global_position, -8.0)


func _find_grid(cell: Vector2i) -> int:
	for i in _cells.size():
		if _cells[i].kind == "grid" and _cells[i].cell == cell:
			return i
	return 0


func _find_socket(w: int, s: int) -> int:
	for i in _cells.size():
		if _cells[i].kind == "socket" and _cells[i].w == w and _cells[i].s == s:
			return i
	return 0


func _find_pick(index: int) -> int:
	for i in _cells.size():
		if _cells[i].kind == "pick" and _cells[i].index == index:
			return i
	return 0


# --- Раскладка ---------------------------------------------------------------------------

## Парный макет используется только личными окнами; торговля и склад сохраняют раскладку.
func _paired_menu() -> bool:
	return is_skills_view and _context == &""

func _menu_design() -> Vector2:
	return Vector2(1280, 720) if _paired_menu() else DESIGN

func _bag_origin() -> Vector2:
	return Vector2(702, 426) if _paired_menu() else GRID_ORIGIN

func _bag_cell() -> float:
	return 44.0 if _paired_menu() else BAG_CELL

func _right_panel() -> Rect2:
	return Rect2(674, 48, 584, 640) if _paired_menu() else RIGHT

func _layout() -> void:
	_layout_size = size
	var design := _menu_design()
	_scale = minf(size.x / design.x, size.y / design.y)
	_origin = (size - design * _scale) * 0.5
	_cells.clear()
	if _context == &"stash":
		for p in Game.STASH_TABS + 1:
			_cells.append({"kind": "page", "page": p, "rect": _r(Rect2(SHOP_ORIGIN.x + p * 82, 64, 76, 24))})
		if _shop_page == 0:
			for i in ItemDB.CURRENCY_ORDER.size():
				var pos := SHOP_ORIGIN + Vector2((i % 4) * 92, floori(i / 4.0) * 70)
				_cells.append({"kind": "scur", "id": ItemDB.CURRENCY_ORDER[i], "rect": _r(Rect2(pos, Vector2(86, 62)))})
		else:
			for y in PlayerInventory.HEIGHT:
				for x in PlayerInventory.WIDTH:
					_cells.append({"kind": "shop", "cell": Vector2i(x, y),
							"rect": _r(Rect2(SHOP_ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL)))})
	if _context == &"vendor":
		_cells.append({"kind": "trade_action", "rect": _r(Rect2(237, 650, 201, 34))})
		for p in _source.stocks.size():
			_cells.append({"kind": "page", "page": p, "rect": _r(Rect2(29 + p * 76, 64, 72, 23))})
		_layout_catalog()
	for w in PlayerInventory.WEAPON_COUNT:
		var weapon_rect := Rect2(742 + w * 232, 344, 214, 55) if _paired_menu() else Rect2(958 + w * 148, 344, 136, 64)
		_cells.append({"kind": "weapon", "w": w, "rect": _r(weapon_rect)})
	var equip := {
		&"helmet": Rect2(1034, 98, 70, 70), &"combat": Rect2(1114, 114, 44, 44),
		&"implant1": Rect2(980, 191, 40, 48), &"body": Rect2(1028, 183, 80, 122),
		&"implant2": Rect2(1116, 191, 40, 48), &"gloves": Rect2(979, 302, 61, 50),
		&"boots": Rect2(1102, 302, 61, 50),
	}
	if _paired_menu():
		equip = {
			&"helmet": Rect2(930, 112, 66, 66), &"combat": Rect2(1030, 122, 44, 44),
			&"implant1": Rect2(844, 206, 52, 52), &"body": Rect2(920, 198, 82, 104),
			&"implant2": Rect2(1026, 206, 52, 52), &"gloves": Rect2(860, 274, 54, 46),
			&"boots": Rect2(1010, 274, 54, 46),
		}
	for key in equip:
		var equipment_rect: Rect2 = equip[key]
		if not _paired_menu():
			equipment_rect.position.x = 1024 + (equipment_rect.position.x - 1069) * 1.2
			equipment_rect.size.x *= 1.2
		_cells.append({"kind": "equip", "key": key, "rect": _r(equipment_rect)})
	for y in PlayerInventory.HEIGHT:
		for x in PlayerInventory.WIDTH:
			_cells.append({"kind": "grid", "cell": Vector2i(x, y),
					"rect": _r(Rect2(_bag_origin() + Vector2(x, y) * _bag_cell(), Vector2.ONE * _bag_cell()))})
	var pick_box := _pick_box()
	for i in ModuleDB.ALL.size():
		var pos := pick_box.position + Vector2(PICK_PAD + (i % PICK_COLS) * (PICK_TILE + PICK_GAP),
				PICK_HEADER + floori(i / float(PICK_COLS)) * (PICK_TILE + PICK_GAP))
		_cells.append({"kind": "pick", "index": i, "id": ModuleDB.ALL[i].id,
				"rect": _r(Rect2(pos, Vector2(PICK_TILE, PICK_TILE)))})
	_cells.append({"kind": "close", "rect": _r(Rect2(_right_panel().end.x - 36, _right_panel().position.y + 10, 24, 24))})
	_cursor = clampi(_cursor, 0, _cells.size() - 1)


## Крупная витрина: переупаковывает только отображение, координаты вещей в запасе не меняет.
func _layout_catalog() -> void:
	var occupied := PackedByteArray()
	occupied.resize(SHOP_COLUMNS * SHOP_ROWS)
	occupied.fill(0)
	var page := 0
	var placements: Array[Dictionary] = []
	for entry in _shop().entries:
		var item_size := PlayerInventory.size_of(entry.item)
		var at := _catalog_fit(occupied, item_size)
		if at.x < 0:
			page += 1
			occupied.fill(0)
			at = _catalog_fit(occupied, item_size)
		for y in item_size.y:
			for x in item_size.x:
				occupied[(at.y + y) * SHOP_COLUMNS + at.x + x] = 1
		placements.append({"page": page, "cell": entry.pos, "rect": Rect2(SHOP_ORIGIN + Vector2(at) * SHOP_CELL, Vector2(item_size) * SHOP_CELL)})
	_catalog_pages = page + 1
	_catalog_page = clampi(_catalog_page, 0, page)
	for placement in placements:
		if placement.page == _catalog_page:
			_cells.append({"kind": "shop", "cell": placement.cell, "rect": _r(placement.rect)})
	if _catalog_pages > 1:
		_cells.append({"kind": "catalog_page", "dir": -1, "rect": _r(Rect2(373, 64, 29, 23))})
		_cells.append({"kind": "catalog_page", "dir": 1, "rect": _r(Rect2(408, 64, 29, 23))})


func _catalog_fit(occupied: PackedByteArray, item_size: Vector2i) -> Vector2i:
	for y in SHOP_ROWS - item_size.y + 1:
		for x in SHOP_COLUMNS - item_size.x + 1:
			var fits := true
			for iy in item_size.y:
				for ix in item_size.x:
					if occupied[(y + iy) * SHOP_COLUMNS + x + ix] != 0: fits = false
			if fits: return Vector2i(x, y)
	return Vector2i(-1, -1)


func _weapon_top(w: int) -> float:
	return 52.0 + w * 150.0


func _socket_center(w: int, s: int) -> Vector2:
	var item: GearItem = player.weapon_item(w)
	if item != null and s >= item.sockets:
		return Vector2(258 + (s - item.sockets) * 48, _weapon_top(w) + 118)
	return Vector2(58 + s * 49, _weapon_top(w) + 79)


## Прямоугольник, который подсвечивает курсор: у клетки большой вещи — вся вещь.
func _cell_rect(i: int) -> Rect2:
	var c: Dictionary = _cells[i]
	if c.kind == "grid":
		var e := inventory.entry_at(c.cell)
		if not e.is_empty():
			return _grid_rect(e.pos, PlayerInventory.size_of(e.item))
	if c.kind == "shop":
		var e := _shop().entry_at(c.cell)
		if not e.is_empty():
			return _grid_rect(e.pos, PlayerInventory.size_of(e.item), SHOP_ORIGIN)
	return c.rect


func _grid_rect(pos: Vector2i, item_size: Vector2i, origin := GRID_ORIGIN) -> Rect2:
	if _context == &"vendor" and origin == SHOP_ORIGIN:
		for c in _cells:
			if c.kind == "shop" and c.cell == pos: return c.rect
		return Rect2()
	var c := _bag_cell() if origin == GRID_ORIGIN else CELL
	var start := _bag_origin() if origin == GRID_ORIGIN else origin
	return _r(Rect2(start + Vector2(pos) * c, Vector2(item_size) * c))


func _r(rect: Rect2) -> Rect2:
	var fit := 1.0 if _paired_menu() else HORIZONTAL_FIT
	return Rect2(_origin + Vector2(rect.position.x * fit, rect.position.y) * _scale,
			Vector2(rect.size.x * fit, rect.size.y) * _scale)


func _p(v: Vector2) -> Vector2:
	return _origin + Vector2(v.x * (1.0 if _paired_menu() else HORIZONTAL_FIT), v.y) * _scale


# --- Рисование ---------------------------------------------------------------------------

func _draw() -> void:
	if player == null or size.x < 1.0 or size.y < 1.0:
		return
	if size != _layout_size or _cells.is_empty():
		_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.007, 0.012, 0.94 if _paired_menu() else 0.35))
	var left_title := "НАВЫКИ И МОДУЛИ"
	if _context == &"salvage":
		left_title = "ВЕРСТАК РАЗБОРА"
	elif _context == &"stash":
		left_title = "СКЛАД"
	elif _context == &"vendor":
		left_title = "%s · %s" % [String(_source.vendor_name).to_upper(), "ВЫБОР ВСЛЕПУЮ" if _gamble() else "ТОРГОВЛЯ"]
	if _context != &"" and _context != &"vendor":
		_draw_panel(LEFT, left_title)
	elif _context == &"vendor": _draw_panel(LEFT, Loc.npc_name(_source.vendor_name) + " · ТОРГОВЛЯ")
	_draw_panel(_right_panel(), "ИНВЕНТАРЬ")
	if _context == &"":
		_text("СУМКА", _bag_origin() + Vector2(2, -10), 11, dim_text)
	match _context:
		&"":
			pass
		&"vendor":
			_draw_vendor()
		&"salvage":
			_draw_salvage()
		&"stash":
			_draw_stash_help()
	_draw_equipped_weapons()
	_draw_gold()
	if _context == &"" or _context == &"stash" or _context == &"vendor" or _context == &"salvage":
		# Фигура героя за слотами экипировки (как в PoE 2), из референса «Кербер-7».
		var doll := Rect2(866, 104, 200, 224) if _paired_menu() else Rect2(917, 88, 212, 318)
		Style.art(self, "paperdoll", _r(doll), Color(1, 1, 1, 0.25 if _paired_menu() else 0.45))
		if _paired_menu(): _text("ЭКИПИРОВКА", Vector2(700, 108), 11, dim_text)
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		var faded := _mode == Mode.HOLD_MODULE or _mode == Mode.HOLD_CURRENCY
		faded = faded and not _selectable(i)
		match c.kind:
			"socket":
				_draw_socket(c, player.get_module(c.w, c.s), faded, c.s == AMMO_SOCKET)
			"equip":
				_draw_equip(c, faded)
			"grid", "shop":
				Style.cell(self, c.rect)
			"catalog_page":
				Style.button(self, c.rect, _scale)
				_draw_center_px("‹" if c.dir < 0 else "›", c.rect.get_center() + Vector2(0, 4) * _scale, 13, text_color)
			"close":
				Style.slot(self, c.rect, _scale)
				_draw_center_px("×", c.rect.get_center() + Vector2(0, 5) * _scale, 18, dim_text)
			"page":
				var on: bool = c.page == _shop_page
				Style.button(self, c.rect, _scale, on)
				var label := "Стр. %d" % (c.page + 1)
				if _context == &"stash":
					label = "Валюта" if c.page == 0 else "Вещи %d" % c.page
				_draw_center_px(label, c.rect.get_center() + Vector2(0, 5 * _scale), 12,
						Color(0.95, 0.85, 0.6) if on else dim_text)
			"scur":
				var info: Dictionary = ItemDB.CURRENCY[c.id]
				var have: int = Game.stash_currency.get(c.id, 0)
				draw_rect(c.rect, Color(info.color.darkened(0.88), 0.95 if have > 0 else 0.5))
				draw_rect(c.rect, Color(info.color, 0.5 if have > 0 else 0.15), false, 1.0)
				UiIcons.draw_currency(self, c.id, c.rect.position + Vector2(18, 24) * _scale, 11 * _scale,
						Color(info.color, 1.0 if have > 0 else 0.25))
				_draw_center_px("%d" % have, c.rect.position + Vector2(60, 30) * _scale, 15,
						Color(1, 1, 1, 1.0 if have > 0 else 0.3))
				_draw_center_px(info.name, c.rect.position + Vector2(43, 54) * _scale, 9, Color(info.color, 0.8))
	_draw_bag_grid()
	_draw_grid_items(inventory, GRID_ORIGIN)
	if _context == &"vendor" or (_context == &"stash" and _shop_page > 0):
		_draw_grid_items(_shop(), SHOP_ORIGIN)
	if not _defer_overlays:
		_draw_overlays()


func _draw_overlays() -> void:
	if _mode == Mode.CHOOSE_MODULE:
		_draw_chooser()
	_draw_cursor()
	if _mode != Mode.CHOOSE_MODULE:
		_draw_tooltip()
	if _message_left > 0.0:
		_text_center(_message, Vector2(640, 690), 16, _message_color)
	if not _paired_menu(): _text_right("B / ○ / Esc — закрыть", Vector2(1256, 700), 11, dim_text)


func _draw_panel(rect: Rect2, title: String) -> void:
	var r := _r(rect)
	Style.panel(self, r, _scale)
	# Заголовок слева, крупными буквами, с оранжевой чертой снизу.
	var text := Loc.t(title).to_upper()
	var size := int(15 * _scale)
	var w := Loc.MAIN_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(r.get_center().x - w * 0.5, _p(Vector2(0, rect.position.y + 33)).y).round()
	draw_string(Loc.MAIN_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Style.GOLD)
	var y := at.y - 5 * _scale
	draw_line(Vector2(r.position.x + 24 * _scale, y), Vector2(at.x - 12 * _scale, y), Color(Style.BRONZE, 0.7), _scale)
	draw_line(Vector2(at.x + w + 12 * _scale, y), Vector2(r.end.x - 24 * _scale, y), Color(Style.BRONZE, 0.7), _scale)


func _draw_equipped_weapons() -> void:
	for c in _cells:
		if c.kind != "weapon":
			continue
		Style.slot(self, c.rect, _scale, c.w == player.current_weapon_index())
		var item: GearItem = player.weapon_item(c.w)
		if item != null:
			UiIcons.draw_item_picture(self, item, c.rect.grow(-9 * _scale))
			draw_rect(c.rect, Color(item.color(), 0.65), false, 1.5)
			_draw_center_px(str(c.w + 1), c.rect.position + Vector2(10, 14) * _scale, 11, item.color())
		else:
			_draw_center_px("Пусто", c.rect.get_center() + Vector2(0, 4) * _scale, 11, dim_text)


func _draw_weapons() -> void:
	for w in PlayerInventory.WEAPON_COUNT:
		var top := _weapon_top(w)
		var item: GearItem = player.weapon_item(w)
		draw_rect(_r(Rect2(24, top, 376, 142)), Color(1, 1, 1, 0.02))
		if item == null:
			_text("Пусто", Vector2(36, top + 36), 14, dim_text)
			continue
		_text(item.display_name(), Vector2(36, top + 24), 14, item.color())
		_text("Мины" if item.slot == &"mines" else "Основной выстрел", Vector2(36, top + 46), 12, dim_text)
		if item.base.id in [&"rifle", &"rifle_mk2"]:
			_text("Подствольная граната", Vector2(36, top + 116), 10, dim_text)


func _draw_socket(c: Dictionary, module: ModuleData, faded: bool, ammo := false) -> void:
	var center: Vector2 = c.rect.get_center()
	var r: float = c.rect.size.x * 0.5
	var a := 0.3 if faded else 1.0
	Style.socket(self, c.rect, false, Color(1, 1, 1, a))
	if ammo and module == null:
		for k in PlayerInventory.WEAPON_COUNT:
			var col: Color = [Color(1, 0.38, 0.12), Color(0.45, 1, 0.25), Color(0.4, 0.75, 1.0)][k]
			draw_circle(center + Vector2((k - 1) * r * 0.32, 0), r * 0.10, Color(col, 0.5 * a))
	if module != null:
		draw_circle(center, r * 0.78, Color(module.color.darkened(0.6), a))
		UiIcons.draw_module(self, module.id, center, r * 0.52, Color(module.color.lightened(0.25), a))


func _draw_equip(c: Dictionary, faded: bool) -> void:
	var item: GearItem = inventory.equipment[c.key]
	var rect: Rect2 = c.rect
	# Пустой слот — полупрозрачный: сквозь него видна фигура героя.
	Style.slot(self, rect, _scale, item != null)
	if item == null:
		var slot: StringName = &"implant" if String(c.key).begins_with("implant") else c.key
		UiIcons.draw_gear(self, slot, rect.get_center(), minf(rect.size.x, rect.size.y) * 0.32, Color(1, 1, 1, 0.07))
		var caption := Loc.t(SLOT_CAPTIONS.get(c.key, ""))
		var fs := int(10 * _scale)
		var tw := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(rect.get_center().x - tw * 0.5, rect.end.y + 11 * _scale), caption,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(dim_text, 0.6))
		return
	_draw_gear(rect, item, 0.3 if faded else 1.0)


func _remember_trade(c: Dictionary) -> void:
	if c.kind not in ["shop", "grid"]: return
	var entry := (_shop() if c.kind == "shop" else inventory).entry_at(c.cell)
	if not entry.is_empty():
		_trade_selection = {"kind": c.kind, "cell": c.cell, "page": _shop_page, "item": entry.item}


func _trade_valid() -> bool:
	if _trade_selection.is_empty(): return false
	var container := inventory if _trade_selection.kind == "grid" else _shop()
	var entry := container.entry_at(_trade_selection.cell)
	return not entry.is_empty() and entry.item == _trade_selection.item and (_trade_selection.kind != "shop" or _trade_selection.page == _shop_page)


func _trade_action() -> void:
	if not _trade_valid():
		_show_message("Сначала выберите предмет")
		return
	if _trade_selection.kind == "shop": _buy(_trade_selection.cell)
	else: _sell(_trade_selection.item)
	_trade_selection.clear()
	_layout()


func _draw_vendor() -> void:
	var selected := _trade_valid()
	_text("ТОВАРЫ" + (" · %d / %d" % [_catalog_page + 1, _catalog_pages] if _catalog_pages > 1 else ""), Vector2(40, 98), 12, dim_text)
	Style.tooltip(self, _r(Rect2(SHOP_ORIGIN, Vector2(SHOP_COLUMNS, SHOP_ROWS) * SHOP_CELL)).grow(5 * _scale), _scale)
	for y in SHOP_ROWS:
		for x in SHOP_COLUMNS:
			Style.cell(self, _r(Rect2(SHOP_ORIGIN + Vector2(x, y) * SHOP_CELL, Vector2.ONE * SHOP_CELL)))
	for c in _cells:
		if c.kind == "trade_action":
			Style.button(self, c.rect, _scale, selected)
			var label := "ВЫБЕРИТЕ ПРЕДМЕТ"
			if selected:
				var price := _price(_trade_selection.item) if _trade_selection.kind == "shop" else ItemDB.sell_price(_trade_selection.item)
				label = ("КУПИТЬ · %d" if _trade_selection.kind == "shop" else "ПРОДАТЬ · %d") % price
			_draw_center_px(label, c.rect.get_center() + Vector2(0, 4) * _scale, 12, text_color)
	Style.gold(self, _r(Rect2(30, 669, 23, 23)))
	_text(str(player.gold), Vector2(62, 687), 18, text_color)

func _draw_stash_help() -> void:
	var y := SHOP_ORIGIN.y + PlayerInventory.HEIGHT * CELL + 24 if _shop_page > 0 else 470.0
	var lines := [
		"Склад общий и не пропадает.",
		"«Валюта» — фрагменты без ограничения количества.",
		"A / ✕ на вещи в сумке — убрать на склад,",
		"A / ✕ на вещи на складе — забрать в сумку.",
		"Мышью — перетащить; X / □ — взять и положить.",
	]
	for i in lines.size():
		_text(lines[i], Vector2(26, y + i * 18), 12, dim_text)


func _draw_salvage() -> void:
	var lines := [
		"Разбор превращает вещи в осколки.",
		"10 осколков = целый фрагмент.  A / ✕ на вещи — разобрать.",
		"",
		"Белая вещь (Normal)   →  осколок Mutagen Vial",
		"Синяя вещь (Magic)    →  осколок Reliquary Core",
		"Жёлтая вещь (Rare)    →  осколок Chaos Catalyst",
		"Уникальная (Unique)   →  5 осколков Seraph's Heart",
		"Модуль оружия         →  сразу Blank Module",
	]
	for i in lines.size():
		_text(lines[i], Vector2(28, 70 + i * 20), 12, text_color if i > 2 else dim_text)
	# Копилка осколков: полоски до 10.
	var y := 250.0
	_text("ОСКОЛКИ", Vector2(28, y), 12, Color(0.95, 0.85, 0.6))
	for i in ItemDB.SHARD_BY_RARITY.size():
		var id: StringName = ItemDB.SHARD_BY_RARITY[i]
		var info: Dictionary = ItemDB.CURRENCY[id]
		var have: int = inventory.shards.get(id, 0)
		var row_y := y + 22 + i * 30
		UiIcons.draw_currency(self, id, _p(Vector2(40, row_y - 4)), 9 * _scale, info.color)
		_text(info.name, Vector2(56, row_y), 12, info.color)
		for k in ItemDB.SHARDS_PER_FRAGMENT:
			var cell := _r(Rect2(200 + k * 18, row_y - 12, 14, 14))
			draw_rect(cell, Color(info.color, 0.85) if k < have else Color(1, 1, 1, 0.06))
			draw_rect(cell, Color(info.color, 0.4), false, 1.0)
		_text("%d / %d" % [have, ItemDB.SHARDS_PER_FRAGMENT], Vector2(386, row_y), 11, dim_text)


func _draw_gold() -> void:
	var gy := _bag_origin().y + PlayerInventory.HEIGHT * _bag_cell() + 20
	var at := _p(Vector2(_bag_origin().x + 8, gy))
	Style.gold(self, Rect2(at - Vector2.ONE * 9 * _scale, Vector2.ONE * 18 * _scale))
	_text("%d" % player.gold, Vector2(_bag_origin().x + 20, gy + 5), 14, Color(1.0, 0.85, 0.4))
	if _context == &"":
		_draw_legend()


## Подсказка по кнопкам внизу правой панели — что делает каждая.
func _draw_legend() -> void:
	if _paired_menu():
		_text_center("ЛКМ — выбрать · 2×ЛКМ / A — надеть · ПКМ / Y — быстро · Alt / LB — сравнить · Esc / B — закрыть", Vector2(640, 710), 11, dim_text)
		return
	# Краткие строки помещаются под сумкой даже при высоте 720; подробности — в подсказке вещи.
	var rows := [
		"A / 2×ЛКМ — надеть или вставить · Y / ПКМ — быстро",
		"X / тащить — перенос · Alt / LB — сравнение · G — выбросить",
	]
	for i in rows.size():
		_text(rows[i], Vector2(GRID_ORIGIN.x + 2, 670 + i * 16), 10, dim_text)



func _draw_bag_grid() -> void:
	var bounds := _r(Rect2(_bag_origin(), Vector2(PlayerInventory.WIDTH, PlayerInventory.HEIGHT) * _bag_cell()))
	Style.tooltip(self, bounds.grow(5 * _scale), _scale)
	for y in PlayerInventory.HEIGHT:
		for x in PlayerInventory.WIDTH:
			Style.cell(self, _r(Rect2(_bag_origin() + Vector2(x, y) * _bag_cell(), Vector2.ONE * _bag_cell())))


func _draw_grid_items(source: PlayerInventory, origin: Vector2) -> void:
	var faded_mode := _mode == Mode.HOLD_MODULE or _mode == Mode.HOLD_CURRENCY
	for e in source.entries:
		var item = e.item
		var rect := _grid_rect(e.pos, PlayerInventory.size_of(item), origin)
		if rect.size.x <= 0: continue
		var a := 1.0
		if faded_mode and not item is GearItem:
			a = 0.3
		if _mode == Mode.HOLD_MODULE and item == _held_module:
			a = 0.25
		if item is GearItem:
			_draw_gear(rect, item, 0.3 if _mode == Mode.HOLD_MODULE else a)
		elif item is ModuleData:
			draw_rect(rect.grow(-1), Color(item.color.darkened(0.82), a))
			draw_circle(rect.get_center(), rect.size.x * 0.4, Color(item.color.darkened(0.6), a))
			UiIcons.draw_module(self, item.id, rect.get_center(), rect.size.x * 0.27, Color(item.color.lightened(0.2), a))
		else:
			var info: Dictionary = ItemDB.CURRENCY[item.id]
			var held: bool = _mode == Mode.HOLD_CURRENCY and item == _held_stack
			draw_rect(rect.grow(-1), Color(info.color.darkened(0.88), a))
			if held:
				draw_rect(rect.grow(-1), info.color, false, 2.0)
			UiIcons.draw_currency(self, item.id, rect.get_center() + Vector2(2, 3) * _scale, rect.size.x * 0.32,
					Color(info.color, a))
			draw_string(_font, rect.position + Vector2(3, 12) * _scale, str(item.count), HORIZONTAL_ALIGNMENT_LEFT, -1,
					int(12 * _scale), Color(1, 1, 1, a))


## Вещь: фон цвета редкости (как в PoE 2: синий/жёлтый оттенок клеток) и значок.
func _draw_price(rect: Rect2, price: int) -> void:
	var fs := 11
	var width := _font.get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * _scale)).x + 22 * _scale
	var badge := Rect2(rect.end - Vector2(width + 4 * _scale, 17 * _scale), Vector2(width, 15 * _scale))
	draw_rect(badge, Color(0.005, 0.006, 0.008, 0.9))
	Style.gold(self, Rect2(badge.position + Vector2(1, 1) * _scale, Vector2.ONE * 13 * _scale))
	draw_string(_font, badge.position + Vector2(17, 12) * _scale, str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * _scale), text_color)

func _draw_gear(rect: Rect2, item: GearItem, a: float) -> void:
	if item.slot == &"mines":
		UiIcons.draw_mine(self, rect.grow(-3 * _scale), Color(1, 1, 1, a))
		return
	var color := item.color()
	var tint: Color = [Color(0.08, 0.08, 0.09), Color(0.05, 0.07, 0.2), Color(0.18, 0.14, 0.04), Color(0.2, 0.08, 0.02)][item.rarity]
	# Есть картинка (клетка из референса со своим фоном) — фон в цвет её клетки, рамка — цвет редкости.
	if UiIcons.texture(item.icon_path()) != null:
		Style.slot(self, rect, _scale)
		UiIcons.draw_item_picture(self, item, rect.grow(-5 * _scale), Color(1, 1, 1, a))
		draw_rect(rect.grow(-3 * _scale), Color(color, 0.45 * a), false, _scale)
		return
	draw_rect(rect.grow(-1), Color(tint, 0.9 * a))
	draw_rect(rect.grow(-1), Color(color, 0.55 * a), false, 1.5)
	if item.is_weapon():
		UiIcons.draw_weapon_picture(self, item.weapon_data(), rect.grow(-3 * _scale), Color(1, 1, 1, a),
				-60.0 if rect.size.y > rect.size.x * 1.2 else -25.0)
		return
	UiIcons.draw_gear(self, item.slot, rect.get_center(), minf(rect.size.x, rect.size.y) * 0.36, Color(color, a),
			item.defense_kind())


func _draw_character() -> void:
	var x := 30.0
	var y := 520.0
	draw_line(_p(Vector2(24, y - 16)), _p(Vector2(400, y - 16)), Color(frame_color, 0.4), 1.0)
	_text("ПЕРСОНАЖ", Vector2(x, y), 12, Color(0.95, 0.85, 0.6))
	var lines := [
		"Life  %d / %d%s" % [ceili(player.hp), int(player.max_hp),
				"   (+%d в сек.)" % int(player.hp_regen) if player.hp_regen > 0 else ""],
		"Energy Shield  %d / %d" % [ceili(player.es), int(player.max_es)],
		"Armour  %d   (удар в 20 слабее на %d%%)" % [int(player.armor), roundi(player.armor_reduction(20.0) * 100.0)],
		"Resistances:  Fire %d%%   Lightning %d%%   Acid %d%%" % [
				int(player.resists[&"fire"]), int(player.resists[&"electric"]), int(player.resists[&"acid"])],
		"Скорость бега  +%d%%" % roundi((player.move_speed_mult - 1.0) * 100.0),
	]
	var gear: Dictionary = player._gear
	var bonus := []
	if gear.get(&"damage_pct", 0) > 0:
		bonus.append("урон +%d%%" % gear[&"damage_pct"])
	if gear.get(&"fire_rate_pct", 0) > 0:
		bonus.append("темп +%d%%" % gear[&"fire_rate_pct"])
	if gear.get(&"reload_pct", 0) > 0:
		bonus.append("перезарядка +%d%%" % gear[&"reload_pct"])
	if not bonus.is_empty():
		lines.append("Всё оружие:  " + ", ".join(bonus))
	for i in lines.size():
		_text(lines[i], Vector2(x, y + 20 + i * 18), 12, text_color)


func _draw_cursor() -> void:
	if _mode == Mode.HOLD_ITEM and _held_item != null:
		_draw_held()
		return
	var rect := _cell_rect(_cursor).grow(3.0 * _scale)
	var color := Color(cursor_color, 0.6 + 0.4 * sin(_time * 6.0))
	if _cells[_cursor].kind in ["socket", "skill"]:
		draw_arc(rect.get_center(), rect.size.x * 0.5, 0, TAU, 40, color, 3.0, true)
	else:
		draw_rect(rect, color, false, 2.5)
	var at := rect.position + Vector2(rect.size.x, 0)
	if _mode == Mode.HOLD_MODULE:
		draw_circle(at, 15 * _scale, _held_module.color.darkened(0.7))
		draw_arc(at, 15 * _scale, 0, TAU, 24, _held_module.color, 2.0, true)
		UiIcons.draw_module(self, _held_module.id, at, 9 * _scale, _held_module.color.lightened(0.3))
	elif _mode == Mode.HOLD_CURRENCY:
		var info: Dictionary = ItemDB.CURRENCY[_held_currency]
		draw_circle(at, 15 * _scale, info.color.darkened(0.8))
		UiIcons.draw_currency(self, _held_currency, at, 11 * _scale, info.color)


## Вещь в руке: рамка места под курсором (зелёная — можно положить) и сама вещь у мыши / курсора.
func _draw_held() -> void:
	var c: Dictionary = _cells[_cursor]
	var item = _held_item
	var item_size := PlayerInventory.size_of(item)
	var target: Rect2 = c.rect
	var box := _container_of(c)
	if box != null:
		var origin := GRID_ORIGIN if c.kind == "grid" else SHOP_ORIGIN
		var pos: Vector2i = c.cell
		pos.x = clampi(pos.x, 0, PlayerInventory.WIDTH - item_size.x)
		pos.y = clampi(pos.y, 0, PlayerInventory.HEIGHT - item_size.y)
		target = _grid_rect(pos, item_size, origin)
	var pulse := 0.6 + 0.4 * sin(_time * 6.0)
	draw_rect(target.grow(2), Color(0.5, 1.0, 0.5, pulse), false, 2.5)
	# Сама вещь — у мыши, если ей пользуются, иначе у ячейки.
	var size_px := Vector2(item_size) * _bag_cell() * _scale
	var at := get_local_mouse_position() - size_px * 0.5 if _dragging or player._using_mouse else \
			target.position + Vector2(6, -6) * _scale
	var rect := Rect2(at, size_px)
	if item is GearItem:
		_draw_gear(rect, item, 0.85)
	elif item is ModuleData:
		draw_rect(rect, Color(item.color.darkened(0.82), 0.9))
		UiIcons.draw_module(self, item.id, rect.get_center(), rect.size.x * 0.27, item.color.lightened(0.2))
	else:
		var info: Dictionary = ItemDB.CURRENCY[item.id]
		draw_rect(rect, Color(info.color.darkened(0.88), 0.9))
		UiIcons.draw_currency(self, item.id, rect.get_center(), rect.size.x * 0.32, info.color)
		draw_string(_font, rect.position + Vector2(3, 12) * _scale, str(item.count), HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(12 * _scale), Color.WHITE)
	draw_rect(rect, Color(1, 1, 1, 0.8), false, 1.5)


## Окно выбора чистого модуля: компактная сетка значков, под ней — название и описание выбранного.
## Размер окна считается от числа модулей, поэтому новые модули ничего не сдвинут и не наложат.
func _pick_box() -> Rect2:
	var rows := ceili(ModuleDB.ALL.size() / float(PICK_COLS))
	var w := PICK_PAD * 2.0 + PICK_COLS * PICK_TILE + (PICK_COLS - 1) * PICK_GAP
	var h := PICK_HEADER + rows * PICK_TILE + (rows - 1) * PICK_GAP + PICK_INFO + PICK_FOOTER
	return Rect2(((DESIGN - Vector2(w, h)) * 0.5).round(), Vector2(w, h))


func _draw_chooser() -> void:
	var box := _pick_box()
	var left := box.position.x + PICK_PAD
	var right := box.end.x - PICK_PAD
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	draw_rect(_r(box), panel_color)
	draw_rect(_r(box), frame_color, false, 2.0)

	# Заголовок: слева название, справа подсказка мельче.
	_text("Чистый модуль", Vector2(left, box.position.y + 29), 16, Color(0.95, 0.85, 0.6))
	_text_right("Выберите, каким он станет", Vector2(right, box.position.y + 29), 12, dim_text)
	draw_line(_p(Vector2(left, box.position.y + 39)), _p(Vector2(right, box.position.y + 39)), line_color, 1.0)

	for c in _cells:
		if c.kind != "pick":
			continue
		var module: ModuleData = ModuleDB.ALL[c.index]
		draw_rect(c.rect, module.color.darkened(0.82))
		draw_circle(c.rect.get_center(), c.rect.size.x * 0.38, module.color.darkened(0.6))
		UiIcons.draw_module(self, module.id, c.rect.get_center(), c.rect.size.x * 0.25, module.color.lightened(0.2))

	# Описание выбранного модуля — в своей зоне под сеткой.
	var rows := ceili(ModuleDB.ALL.size() / float(PICK_COLS))
	var info_top := box.position.y + PICK_HEADER + rows * PICK_TILE + (rows - 1) * PICK_GAP + 10.0
	draw_line(_p(Vector2(left, info_top)), _p(Vector2(right, info_top)), line_color, 1.0)
	if _cells[_cursor].kind == "pick":
		var picked: ModuleData = ModuleDB.ALL[_cells[_cursor].index]
		_text(picked.display_name, Vector2(left, info_top + 22), 15, picked.color.lightened(0.2))
		_text_right(picked.category, Vector2(right, info_top + 22), 11, dim_text)
		var lines := _wrap(picked.description, 13, (right - left) * _scale)
		for i in mini(lines.size(), 3):
			_text(lines[i], Vector2(left, info_top + 42 + i * 17), 13, text_color)

	_text("A / ✕ / ЛКМ — выбрать    B / ○ / ПКМ — отмена",
			Vector2(left, box.end.y - 12), 11, dim_text)


# --- Всплывающая подсказка (как в PoE 2) -------------------------------------------------

## Строка подсказки: [текст, цвет, размер] или "---" — разделитель.
func _tooltip_lines() -> Dictionary:
	var c: Dictionary = _cells[_cursor]
	if _mode == Mode.HOLD_ITEM:
		return {}
	if c.kind == "scur":
		var info: Dictionary = ItemDB.CURRENCY[c.id]
		return {"title": info.name, "color": info.color, "lines": [
			["На складе: %d" % Game.stash_currency.get(c.id, 0), dim_text, 13], "---", [info.text, text_color, 15],
			"---", ["A / ✕ — взять стопку в сумку", hint_color, 12]]}
	if _context == &"stash" and (c.kind == "grid" or c.kind == "shop"):
		var box: PlayerInventory = inventory if c.kind == "grid" else _shop()
		var e := box.entry_at(c.cell)
		if e.is_empty():
			return {}
		var hint := "A / ✕ — убрать на склад" if c.kind == "grid" else "A / ✕ — забрать в сумку"
		hint += "   ·   X / □ — перенести"
		if e.item is GearItem:
			return _gear_tooltip(e.item, hint)
		if e.item is ModuleData:
			return _module_tooltip(e.item, hint)
		return _currency_tooltip(e.item, hint)
	if c.kind == "shop":
		var e := _shop().entry_at(c.cell)
		if e.is_empty():
			return {}
		var hint := "A / ✕ — купить за %d золота" % _price(e.item)
		if _gamble() and e.item is GearItem:
			var kind_name: String = ItemDB.SLOT_NAMES[e.item.slot]
			return {"title": e.item.base.name, "color": text_color, "lines": [
				["%s · база" % kind_name, dim_text, 13], "---",
				["Каждая покупка — новый случайный предмет этой базы:", text_color, 14],
				["редкость и свойства выпадут при покупке", text_color, 14],
				["(Normal / Magic / Rare, изредка Unique)", dim_text, 13], "---", [hint, hint_color, 12]]}
		if e.item is GearItem:
			return _with_compare(e.item, _gear_tooltip(e.item, hint))
		if e.item is ModuleData:
			return _module_tooltip(e.item, hint)
		return _currency_tooltip(e.item, hint)
	if c.kind == "grid" and _context != &"":
		var e := inventory.entry_at(c.cell)
		if e.is_empty():
			return {}
		var hint := "A / ✕ — продать за %d золота" % ItemDB.sell_price(e.item)
		if _context == &"salvage":
			var shard := ItemDB.salvage_shards(e.item)
			if shard.is_empty():
				hint = "Нельзя разобрать"
			else:
				hint = "A / ✕ — разобрать: +%d осколок %s" % [shard[1], ItemDB.CURRENCY[shard[0]].name]
		if e.item is GearItem:
			return _gear_tooltip(e.item, hint)
		if e.item is ModuleData:
			return _module_tooltip(e.item, hint)
		return _currency_tooltip(e.item, hint)
	match c.kind:
		"grid":
			var e := inventory.entry_at(c.cell)
			if e.is_empty():
				return {}
			if e.item is GearItem:
				return _with_compare(e.item, _gear_tooltip(e.item, "A / ✕ — надеть" if _mode == Mode.NORMAL else "A / ✕ — применить   ·   B / ○ — хватит"))
			if e.item is ModuleData:
				return _module_tooltip(e.item, "A / ✕ — вставить в гнездо   ·   Y / △ — в оружие в руках")
			return _currency_tooltip(e.item)
		"equip":
			var item: GearItem = inventory.equipment[c.key]
			if item != null:
				return _gear_tooltip(item, "A / ✕ — снять" if _mode == Mode.NORMAL else "A / ✕ — применить   ·   B / ○ — хватит")
			var slot: StringName = &"implant" if String(c.key).begins_with("implant") else c.key
			return {"title": ItemDB.SLOT_NAMES[slot], "color": text_color, "lines": [["Пусто", dim_text, 14]]}
		"socket":
			if _mode == Mode.HOLD_MODULE:
				return _module_tooltip(_held_module, "A / ✕ — вставить сюда   ·   B / ○ — отмена")
			var module: ModuleData = player.get_module(c.w, c.s)
			if module != null:
				return _module_tooltip(module, "A / ✕ — вынуть в сумку")
			return {"title": "Пустое гнездо", "color": text_color,
					"lines": [[("Тип патронов: огонь, кислота или электричество" if c.s == AMMO_SOCKET else ("Модификатор дополнительного навыка" if c.s >= player.weapon_item(c.w).sockets else "Модификатор основного навыка")), dim_text, 14]]}
		"weapon":
			return _weapon_tooltip(c.w)
	return {}


## Что изменится, если надеть вещь вместо надетой: строки «+12 к броне» (зелёным) / «−5 …» (красным).
## Держать Alt / LT — рядом покажется подсказка надетой вещи.
func _with_compare(item: GearItem, tip: Dictionary) -> Dictionary:
	var worn := _worn_for(item)
	var mine := item.stats()
	var theirs: Dictionary = worn.stats() if worn != null else {}
	var keys := mine.keys()
	for k in theirs:
		if not keys.has(k):
			keys.append(k)
	var diff := []
	for k in keys:
		var d: int = int(mine.get(k, 0)) - int(theirs.get(k, 0))
		if d == 0:
			continue
		var fmt: String = PASSIVES.STAT_TEXT.get(k, ItemDB.stat_text(k))
		var text: String
		if fmt.contains("−%d"):  # «−%d%% к разбросу»: больше — лучше, знак наоборот
			text = fmt.replace("−%d", ("−" if d > 0 else "+") + str(absi(d))).replace("%%", "%")
		else:
			text = fmt.replace("+%d", "%d").replace("%d", ("+" if d > 0 else "−") + str(absi(d))).replace("%%", "%")
		diff.append([text, Color(0.45, 1.0, 0.45) if d > 0 else Color(1.0, 0.45, 0.4), 14])
	var lines: Array = tip.lines
	var hint = lines.pop_back()
	lines.append(["Если надеть вместо %s:" % ("надетого" if worn != null else "пустого места"), dim_text, 13])
	if item.is_weapon():
		var before := worn.dps() if worn != null else 0.0
		var after := item.dps()
		lines.append(["Урон в секунду: %.0f → %.0f" % [before, after],
				Color(0.45, 1.0, 0.45) if after >= before else Color(1.0, 0.45, 0.4), 14])
	if diff.is_empty():
		lines.append(["Без изменений", dim_text, 14])
	lines.append_array(diff)
	lines.append("---")
	lines.append(hint)
	lines.append(["Alt / LT (держать) — сравнить с надетым", hint_color, 12])
	if worn != null and Input.is_action_pressed("menu_compare"):
		tip["compare"] = worn
	return tip


## Какую надетую вещь заменит эта (для имплантов — первый пустой слот или первый имплант).
func _worn_for(item: GearItem) -> GearItem:
	if item.is_weapon():
		return player.weapon_item(_weapon_target(item))
	if item.slot == &"implant":
		if inventory.equipment[&"implant1"] == null or inventory.equipment[&"implant2"] == null:
			return null
		return inventory.equipment[&"implant1"]
	return inventory.equipment.get(item.slot)


func _gear_tooltip(item: GearItem, hint: String) -> Dictionary:
	var lines := []
	var kind_name: String = {&"armor": " · Armour", &"es": " · Energy Shield", &"hybrid": " · Armour и Energy Shield"}.get(
			item.defense_kind(), "")
	lines.append(["%s · %s%s" % [ItemDB.SLOT_NAMES[item.slot], ItemDB.RARITY_NAMES[item.rarity], kind_name], dim_text, 13])
	var base_lines := []
	var affix_lines := []
	for line in item.describe():
		if line[1]:
			affix_lines.append([line[0], affix_color, 15])
		else:
			# Значение выросло от свойств — синим, как в PoE 2.
			var boosted: bool = line.size() > 2 and line[2]
			base_lines.append([line[0], Color(0.53, 0.53, 1.0) if boosted else text_color, 15])
	if not base_lines.is_empty():
		lines.append("---")
		lines.append_array(base_lines)
	lines.append("---")
	lines.append(["Item Level: %d" % item.item_level, dim_text, 13])
	if not affix_lines.is_empty():
		lines.append("---")
		lines.append_array(affix_lines)
	if item.rarity == 3:
		lines.append("---")
		lines.append(["«%s»" % item.unique.flavour, Color(0.85, 0.6, 0.35), 13])
	lines.append("---")
	lines.append([hint, hint_color, 12])
	var title := item.display_name()
	return {"title": title, "subtitle": item.base.name if item.rarity >= 2 else "", "color": item.color(), "lines": lines}


func _module_tooltip(module: ModuleData, hint: String) -> Dictionary:
	return {"title": module.display_name, "color": module.color.lightened(0.15), "lines": [
		["Модуль оружия · %s" % module.category, dim_text, 13], "---",
		[module.description, text_color, 15], "---", [hint, hint_color, 12]]}


func _currency_tooltip(stack, custom_hint := "") -> Dictionary:
	var info: Dictionary = ItemDB.CURRENCY[stack.id]
	var hint := "A / ✕ — выбрать модуль" if stack.id == &"blank_module" else "A / ✕ — взять и применять к вещам"
	if custom_hint != "":
		hint = custom_hint
	return {"title": info.name, "color": info.color, "lines": [
		["Размер стопки: %d / %d" % [stack.count, ItemDB.STACK_SIZE], dim_text, 13], "---",
		[info.text, text_color, 15], "---", [hint, hint_color, 12]]}


func _weapon_tooltip(w: int) -> Dictionary:
	var item: GearItem = player.weapon_item(w)
	if item == null:
		return {"title": "Пустой слот оружия", "color": text_color,
				"lines": [["Сюда встаёт найденное оружие: A / ✕ на нём в сумке", dim_text, 14]]}
	var hint := "В руках" if w == player.current_weapon_index() else "A / ✕ — взять в руки"
	if _mode == Mode.HOLD_CURRENCY:
		hint = "A / ✕ — применить   ·   B / ○ — хватит"
	else:
		hint += "   ·   Y / △ — убрать в сумку"
	var tip := _gear_tooltip(item, hint)
	# Итог с модулями и экипировкой — перед подсказкой кнопок.
	var s: Dictionary = player.weapon_stats(w)
	var lines: Array = tip.lines
	var last = lines.pop_back()
	lines.append(["С модулями и экипировкой:", dim_text, 13])
	lines.append(["Урон %.0f%s · %.1f выстр./с · магазин %d" % [s.damage, " ×%d" % s.pellets if s.pellets > 1 else "",
			s.fire_rate, s.magazine], text_color, 14])
	var extra := []
	if s.pierce > 0:
		extra.append("пробивает: %d" % s.pierce)
	if s.chain > 0:
		extra.append("рикошетов: %d" % s.chain)
	if s.leech > 0.0:
		extra.append("вампиризм %d%%" % roundi(s.leech * 100.0))
	var names := {&"fire": "огнём", &"electric": "электр.", &"acid": "кислотой"}
	for element in s.elements:
		extra.append("+%d%% %s" % [roundi(s.elements[element] * 100.0), names.get(element, element)])
	if not extra.is_empty():
		lines.append([" · ".join(extra), affix_color, 13])
	lines.append("---")
	lines.append(last)
	return tip


func _draw_tooltip() -> void:
	var tip := _tooltip_lines()
	if tip.is_empty():
		return
	var width := TOOLTIP_WIDTH * _scale
	var height := _measure_tip(tip, width)
	# Как в PoE 2: подсказка встаёт сбоку от панели (у правой — слева от неё, у левой — справа),
	# на высоте предмета, и не закрывает соседние вещи.
	var anchor := _cell_rect(_cursor)
	var pos := Vector2(_p(Vector2(RIGHT.position.x - 6, 0)).x - width, anchor.position.y)
	var left_side := anchor.get_center().x < size.x * 0.5
	if left_side:
		pos.x = _p(Vector2((552 if is_skills_view else LEFT.end.x) + 6, 0)).x
	pos.y = clampf(pos.y, 4.0, size.y - height - 4.0)
	pos.x = clampf(pos.x, 4.0, size.x - width - 4.0)
	_draw_tip_box(tip, pos, width, height)
	# Сравнение (держать Alt / LT): рядом — то, что надето сейчас.
	if tip.has("compare"):
		var other := _gear_tooltip(tip.compare, "Надето сейчас")
		var h2 := _measure_tip(other, width)
		var pos2 := Vector2(pos.x - width - 8 * _scale if not left_side else pos.x + width + 8 * _scale, pos.y)
		pos2.x = clampf(pos2.x, 4.0, size.x - width - 4.0)
		pos2.y = clampf(pos2.y, 4.0, size.y - h2 - 4.0)
		_draw_tip_box(other, pos2, width, h2)


## Высота подсказки; заодно переносит длинные строки по словам.
func _measure_tip(tip: Dictionary, width: float) -> float:
	var header_h := (52.0 if tip.get("subtitle", "") != "" else 36.0) * _scale
	var height := header_h + 10 * _scale
	var rows := []
	for line in tip.lines:
		if line is String:
			rows.append(line)
			continue
		var fs := roundi(line[2] * TIP_FONT)
		for part in _wrap(line[0], fs, width - 20 * _scale):
			rows.append([part, line[1], fs])
	tip.lines = rows
	for line in tip.lines:
		height += (10.0 if line is String else line[2] + 5.0) * _scale
	return height + 6 * _scale


func _draw_tip_box(tip: Dictionary, pos: Vector2, width: float, height: float) -> void:
	var header_h := (52.0 if tip.get("subtitle", "") != "" else 36.0) * _scale
	var box := Rect2(pos, Vector2(width, height))
	var color: Color = tip.color
	Style.tooltip(self, box, _scale)
	draw_rect(box.grow(-5 * _scale), Color(color, 0.35), false, 1.0)
	var header := Rect2(pos, Vector2(width, header_h))
	draw_rect(header.grow(-7 * _scale), Color(color.darkened(0.88), 0.72))
	draw_line(header.position + Vector2(0, header_h), header.end, Color(color, 0.6), 1.0)
	var cx := pos.x + width * 0.5
	if tip.get("subtitle", "") != "":
		Typography.title(self, tip.title, Vector2(cx, pos.y + 24 * _scale), roundi(21 * _scale), color, width - 28 * _scale)
		Typography.title(self, tip.subtitle, Vector2(cx, pos.y + 43 * _scale), roundi(17 * _scale), color, width - 28 * _scale)
	else:
		Typography.title(self, tip.title, Vector2(cx, pos.y + 24 * _scale), roundi(21 * _scale), color, width - 28 * _scale)
	var y := pos.y + header_h + 8 * _scale
	for line in tip.lines:
		if line is String:
			# Разделитель с ромбиком посередине.
			draw_line(Vector2(pos.x + 30 * _scale, y + 2), Vector2(pos.x + width - 30 * _scale, y + 2), Color(color, 0.25), 1.0)
			y += 10 * _scale
			continue
		y += line[2] * _scale
		_draw_center_px(line[0], Vector2(cx, y), line[2], line[1])
		y += 5 * _scale


# --- Текст -----------------------------------------------------------------------------------

func _wrap(text: String, size_px: int, max_width: float) -> Array:
	text = Loc.t(text)
	var fs := roundi(size_px * _scale)
	var result := []
	var current := ""
	for word in text.split(" "):
		var attempt := word if current == "" else current + " " + word
		if current != "" and _font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_width:
			result.append(current)
			current = word
		else:
			current = attempt
	if current != "":
		result.append(current)
	return result

func _text(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	draw_string(_font, _p(pos).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size_px * _scale), color)


func _text_center(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	if size_px >= 20:
		Typography.title(self, text, _p(pos), roundi((size_px + 5) * _scale), Typography.GOLD, 440 * _scale)
		return
	_draw_center_px(text, _p(pos), size_px, color)


func _text_right(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size_px * _scale)).x
	draw_string(_font, (_p(pos) - Vector2(w, 0)).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size_px * _scale), color)


## Текст по центру точки (в настоящих пикселях экрана).
func _draw_center_px(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var fs := roundi(size_px * _scale)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, (pos - Vector2(w * 0.5, 0)).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
