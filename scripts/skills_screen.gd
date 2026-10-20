extends "res://scripts/inventory_screen.gd"
## Навыки оружия и их независимые модули; общая логика сумки остаётся в родительском окне.
const Art := preload("res://scripts/inventory_art.gd")
var _row_top := [84.0, 224.0]
var _row_height := [132.0, 132.0]
var _module_page := 0
var _action_target := ""
var _compare_requested := false
## Инвентарь и навыки открываются одним окном с общим курсором и переносом вещей.
var with_inventory := false

func _combined() -> bool:
	return _context == &""

func _ready() -> void:
	is_skills_view = true
	super()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("skills") and not with_inventory:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		if with_inventory:
			_toggle()
			get_viewport().set_input_as_handled()
		return
	super(event)

func open_module(module: ModuleData) -> void:
	var owned := _owned()
	for i in owned.size():
		if owned[i].item == module: _module_page = i / 18
	if not visible: _toggle()
	_layout()
	_hold_module(module)

func _owned() -> Array:
	return inventory.entries.filter(func(e: Dictionary) -> bool:
		return e.item is ModuleData or (e.item is PlayerInventory.CurrencyStack and e.item.id == &"blank_module"))

func _menu_design() -> Vector2:
	return Art.SIZE if _combined() else super()

func _bag_cell() -> float:
	return 41.5 if _combined() else super()

func _layout() -> void:
	if not _combined():
		super()
		return
	_layout_size = size
	_scale = minf(size.x / Art.SIZE.x, size.y / Art.SIZE.y)
	_origin = (size - Art.SIZE * _scale) * 0.5
	_cells.clear()
	var equip := Art.equipment()
	for key in equip:
		_cells.append({"kind": "equip", "key": key, "rect": _r(equip[key])})
	for w in PlayerInventory.WEAPON_COUNT:
		_cells.append({"kind": "weapon", "w": w, "rect": _r(Art.weapon_rect(w))})
	for y in PlayerInventory.HEIGHT:
		for x in PlayerInventory.WIDTH:
			_cells.append({"kind": "grid", "cell": Vector2i(x, y), "rect": _r(Art.bag_rect(Vector2i(x, y)))})
	for w in PlayerInventory.WEAPON_COUNT:
		_row_top[w] = 119 + w * 310
		var item: GearItem = player.weapon_item(w)
		_cells.append({"kind": "weapon", "w": w, "rect": _r(Art.weapon_rect(w, true))})
		if item == null: continue
		_cells.append({"kind": "skill", "w": w, "secondary": false, "rect": _r(Art.skill_rect(w))})
		if item.secondary_skill() != &"":
			_cells.append({"kind": "skill", "w": w, "secondary": true, "rect": _r(Art.skill_rect(w, true))})
		for slot in player.sockets_of(w):
			var center := _socket_center(w, slot)
			_cells.append({"kind": "socket", "w": w, "s": slot, "rect": _r(Rect2(center - Vector2.ONE * 24, Vector2.ONE * 48))})
	var owned := _owned()
	_module_page = clampi(_module_page, 0, maxi(0, ceili(owned.size() / 18.0) - 1))
	for i in mini(18, owned.size() - _module_page * 18):
		var e: Dictionary = owned[i + _module_page * 18]
		_cells.append({"kind": "grid", "cell": e.pos, "module_strip": true, "rect": _r(Art.module_rect(i))})
	if owned.size() > 18:
		_cells.append({"kind": "module_page", "dir": -1, "rect": _r(Rect2(486, 812, 24, 22))})
		_cells.append({"kind": "module_page", "dir": 1, "rect": _r(Rect2(520, 812, 24, 22))})
	for i in 3:
		_cells.append({"kind": "menu_action", "action": i, "rect": _r(Art.action_rect(i))})
	var pick_box := _pick_box()
	for i in ModuleDB.ALL.size():
		var pos := pick_box.position + Vector2(PICK_PAD + (i % PICK_COLS) * (PICK_TILE + PICK_GAP), PICK_HEADER + floori(i / float(PICK_COLS)) * (PICK_TILE + PICK_GAP))
		_cells.append({"kind": "pick", "index": i, "id": ModuleDB.ALL[i].id, "rect": _r(Rect2(pos, Vector2(PICK_TILE, PICK_TILE)))})
	_cells.append({"kind": "close", "rect": _r(Rect2(1625, 64, 28, 28))})
	_cursor = clampi(_cursor, 0, _cells.size() - 1)

func _socket_center(w: int, slot: int) -> Vector2:
	var item: GearItem = player.weapon_item(w)
	if item != null and slot >= item.sockets:
		return Art.socket_center(w, slot - item.sockets, true)
	return Art.socket_center(w, slot)

func _cell_rect(index: int) -> Rect2:
	if _cells[index].get("module_strip", false): return _cells[index].rect
	return super(index)

func _grid_rect(pos: Vector2i, item_size: Vector2i, origin := GRID_ORIGIN) -> Rect2:
	if _combined() and origin == GRID_ORIGIN: return _r(Art.bag_rect(pos, item_size))
	return super(pos, item_size, origin)

## Кнопки действуют на последний выбранный предмет, даже после перемещения указателя к ним.
func _hover(screen_pos: Vector2) -> void:
	if _combined():
		for i in _cells.size():
			if _selectable(i) and _cells[i].rect.grow(0.25).has_point(screen_pos):
				_cursor = i
				break
	else:
		super(screen_pos)
	_remember_action_target()

func _has_cell_at(screen_pos: Vector2) -> bool:
	if not _combined(): return super(screen_pos)
	for i in _cells.size():
		if _selectable(i) and _cells[i].rect.grow(0.25).has_point(screen_pos): return true
	return false

func _remember_action_target() -> void:
	if _cells.is_empty(): return
	var c: Dictionary = _cells[_cursor]
	if c.kind in ["grid", "equip", "weapon", "socket", "skill"]:
		var id := _cell_id(c)
		if id != _action_target: _compare_requested = false
		_action_target = id

func _process(delta: float) -> void:
	super(delta)
	if visible and _combined(): _remember_action_target()

func _accept() -> void:
	var c: Dictionary = _cells[_cursor]
	if c.kind != "menu_action":
		super()
		return
	if _mode != Mode.NORMAL: return
	for i in _cells.size():
		if _cell_id(_cells[i]) == _action_target:
			_cursor = i
			match c.action:
				0: super()
				1: _compare_requested = not _compare_requested
				2: _drop()
			return

func _with_compare(item: GearItem, tip: Dictionary) -> Dictionary:
	var result := super(item, tip)
	if _compare_requested:
		var worn := _worn_for(item)
		if worn != null: result["compare"] = worn
	return result

func _accept_normal(c: Dictionary) -> void:
	if c.kind == "module_page":
		_module_page += c.dir
		_layout()
		return
	super(c)

func _tooltip_lines() -> Dictionary:
	if _combined() and not _cells.is_empty() and _cells[_cursor].kind == "menu_action":
		var previous := _cursor
		for i in _cells.size():
			if _cell_id(_cells[i]) == _action_target:
				_cursor = i
				var tip := _tooltip_lines()
				_cursor = previous
				return tip
		return {}
	if _cells.is_empty() or _cells[_cursor].kind != "skill": return super()
	var c: Dictionary = _cells[_cursor]
	var item: GearItem = player.weapon_item(c.w)
	var weapon := item.weapon_data()
	var lines: Array = []
	var title := "Выстрел"
	if c.secondary and item.secondary_skill() == &"plasma_pulse":
		var stats: Dictionary = player.pulse_stats(c.w)
		title = "Рассекающий импульс" if weapon.projectile == &"plasma" else "Заряженный выстрел"
		lines = [["Цельная летящая полоса плазмы" if weapon.projectile == &"plasma" else "Мощный одиночный выстрел", text_color, 14], ["Урон: %.0f · ширина: %.2f м" % [stats.damage, stats.width] if weapon.projectile == &"plasma" else "Урон: %.0f" % stats.damage, text_color, 14],
			["Зарядка: %.2f с · восстановление: %.2f с" % [weapon.secondary_charge, stats.cooldown], dim_text, 13],
			["Расход: %d заряда" % weapon.secondary_ammo_cost, dim_text, 13],
			["Пробиваний в глубину: %d" % stats.pierce, dim_text, 13], ["Модификаторы этой строки не меняют основной выстрел.", dim_text, 13]]
	elif c.secondary:
		title = "Подствольная граната"
		lines = [["Отдельный навык коломёта", text_color, 14], ["Собственные модификаторы урона, стихии, радиуса и восстановления.", dim_text, 13]]
	else:
		var stats: Dictionary = player.weapon_stats(c.w)
		title = "Плазменный заряд" if weapon.projectile == &"plasma" else "Выстрел"
		lines = [["Урон: %.0f · темп: %.2f / с" % [stats.damage, stats.fire_rate], text_color, 14], ["Пробиваний: %d" % stats.pierce, dim_text, 13]]
		if weapon.projectile == &"plasma": lines.append(["Ширина полосы: %.2f м" % stats.width, Style.BLUE, 14])
		if stats.get("nova_projectiles", 0) > 0:
			lines.append(["Нова: %d снарядов по %.0f урона · один раз на выстрел" % [stats.nova_projectiles, stats.damage * stats.nova_damage_ratio], Style.BLUE, 13])
	lines.append(["Модификаторы устанавливаются в гнёзда справа.", hint_color, 12])
	return {"title": title, "color": Style.BLUE if weapon.projectile == &"plasma" else text_color, "lines": lines}

func _draw() -> void:
	if not _combined():
		super()
		return
	if player == null or size.x < 1: return
	if size != _layout_size or _cells.is_empty(): _layout()
	Art.draw_layout(self, _r)
	_text_center("НАВЫКИ И МОДУЛИ", Vector2(310, 88), 21, text_color)
	_text_center("ИНВЕНТАРЬ", Vector2(1360, 80), 21, text_color)
	for w in PlayerInventory.WEAPON_COUNT:
		var item: GearItem = player.weapon_item(w)
		_text("%d · %s" % [w + 1, item.display_name() if item != null else "Пустой слот оружия"], Vector2(92, 229 + w * 310), 16, text_color)
		if item == null: continue
		_draw_skill(w, false)
		if item.secondary_skill() != &"": _draw_skill(w, true)
	for c in _cells:
		match c.kind:
			"weapon":
				var item: GearItem = player.weapon_item(c.w)
				if item != null:
					UiIcons.draw_item_picture(self, item, c.rect.grow(-3 * _scale))
					if c.w == player.current_weapon_index(): draw_rect(c.rect.grow(-2 * _scale), Color(0.70, 0.40, 0.24, 0.65), false, _scale)
			"equip":
				var item: GearItem = inventory.equipment[c.key]
				if item != null: UiIcons.draw_item_picture(self, item, c.rect.grow(-5 * _scale))
				else: _draw_center_px(SLOT_CAPTIONS[c.key], c.rect.get_center() + Vector2(0, 5) * _scale, 13, Color(dim_text, 0.6))
			"socket":
				var module: ModuleData = player.get_module(c.w, c.s)
				if module != null:
					draw_circle(c.rect.get_center(), c.rect.size.x * 0.38, Color(module.color.darkened(0.7), 0.9))
					UiIcons.draw_module(self, module.id, c.rect.get_center(), c.rect.size.x * 0.33, Color.WHITE)
			"grid":
				if not c.get("module_strip", false): continue
				var e := inventory.entry_at(c.cell)
				if e.is_empty(): continue
				if e.item is ModuleData: UiIcons.draw_module(self, e.item.id, c.rect.get_center(), c.rect.size.x * 0.36, Color.WHITE)
				else: UiIcons.draw_currency(self, e.item.id, c.rect.get_center(), c.rect.size.x * 0.32, Color.WHITE)
			"menu_action":
				_draw_center_px(["Надеть", "Сравнить", "Выбросить"][c.action], c.rect.get_center() + Vector2(0, 5) * _scale, 14, text_color)
			"module_page":
				_draw_center_px("‹" if c.dir < 0 else "›", c.rect.get_center() + Vector2(0, 6) * _scale, 20, text_color)
			"close":
				_draw_center_px("×", c.rect.get_center() + Vector2(0, 6) * _scale, 23, text_color)
	_draw_grid_items(inventory, GRID_ORIGIN)
	_text_center(str(player.gold), Vector2(1130, 894), 17, Style.GOLD)
	_draw_module_detail()
	_draw_overlays()
	_text("2×ЛКМ / A · Надеть    Alt / LB · Сравнить    Esc / B · Закрыть", Vector2(80, 894), 12, dim_text)

func _draw_skill(w: int, secondary: bool) -> void:
	var item: GearItem = player.weapon_item(w)
	var center := _p(Art.skill_rect(w, secondary).get_center())
	if secondary:
		if item.secondary_skill() == &"plasma_pulse": UiIcons.draw_module(self, &"electric", center, 26 * _scale, Style.BLUE)
		else: UiIcons.draw_texture_fit(self, preload("res://assets/ui/ref/ico_grenade.png"), Rect2(center - Vector2.ONE * 26 * _scale, Vector2.ONE * 52 * _scale))
	elif item.weapon_data().projectile == &"plasma":
		UiIcons.draw_module(self, &"electric", center, 26 * _scale, Style.BLUE)
	elif item.slot == &"mines":
		UiIcons.draw_mine(self, Rect2(center - Vector2.ONE * 26 * _scale, Vector2.ONE * 52 * _scale))
	else:
		UiIcons.draw_module(self, &"damage", center, 25 * _scale, Color.WHITE)
	var title := ("Рассекающий импульс" if item.secondary_skill() == &"plasma_pulse" else "Подствольная граната") if secondary else "Выстрел"
	_draw_center_px(title, _p(Vector2(370, (389 if secondary else 328) + w * 310)), 13, dim_text)

## Описание остаётся в отведённой рисунком нижней плашке; полная подсказка — при наведении.
func _draw_module_detail() -> void:
	if _cells.is_empty(): return
	var previous := _cursor
	if _cells[_cursor].kind == "menu_action":
		for i in _cells.size():
			if _cell_id(_cells[i]) == _action_target:
				_cursor = i
				break
	var tip := _tooltip_lines()
	_cursor = previous
	if tip.is_empty():
		_text("Выберите предмет или модуль", Vector2(80, 847), 17, dim_text)
		return
	_text(tip.title, Vector2(80, 847), 18, tip.color)
	for line in tip.lines:
		if line is Array and not String(line[0]).is_empty():
			var rows := _wrap(Loc.t(String(line[0])), roundi(13 * _scale), 450 * _scale)
			if not rows.is_empty(): _text(rows[0], Vector2(80, 875), 13, dim_text)
			break

## При наведении на оружие показываем крупное изображение над его характеристиками.
func _weapon_tooltip(w: int) -> Dictionary:
	var tip := super(w)
	var item: GearItem = player.weapon_item(w)
	if _combined() and item != null: tip["weapon_preview"] = item
	return tip

func _measure_tip(tip: Dictionary, width: float) -> float:
	return super(tip, width) + (180 * _scale if tip.has("weapon_preview") else 0.0)

func _draw_tip_box(tip: Dictionary, pos: Vector2, width: float, height: float) -> void:
	if not tip.has("weapon_preview"):
		super(tip, pos, width, height)
		return
	var preview_height := 180 * _scale
	var area := Rect2(pos, Vector2(width, preview_height))
	Style.tooltip(self, area, _scale)
	UiIcons.draw_item_picture(self, tip.weapon_preview, area.grow(-10 * _scale))
	super(tip, pos + Vector2(0, preview_height), width, height - preview_height)
