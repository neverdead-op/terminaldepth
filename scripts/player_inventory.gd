class_name PlayerInventory
extends Node
## Сумка игрока, как в PoE 2: сетка WIDTH×HEIGHT, вещи занимают несколько клеток (бронежилет 2×3 и т.п.),
## ксено-фрагменты лежат в клетках стопками. Плюс надетая экипировка.
## Узел Inventory внутри игрока. Любое изменение — сигнал changed.

signal changed

const ItemDB := preload("res://scripts/item_db.gd")
const ModuleDB := preload("res://scripts/module_db.gd")

## Слоты экипировки на персонаже (имплантов два).
const EQUIP_SLOTS := [&"helmet", &"body", &"gloves", &"boots", &"implant1", &"implant2", &"combat"]
const WIDTH := 12
const HEIGHT := 5
const WEAPON_COUNT := 2


## Стопка ксено-фрагментов в одной клетке.
class CurrencyStack:
	extends RefCounted
	var id: StringName
	var count := 0

	func _init(currency_id: StringName, amount: int) -> void:
		id = currency_id
		count = amount


## Предметы в сетке: [{item, pos: Vector2i}]. item — GearItem, ModuleData или CurrencyStack.
var entries: Array[Dictionary] = []
## Вещи из старого сохранения, которым временно не нашлось места после перестройки ячеек.
var recovered_items: Array = []
## Надетое: ключ из EQUIP_SLOTS → GearItem или null.
var equipment := {}
## Осколки с верстака: id фрагмента → сколько накоплено (0..9). 10 — превращаются в целый фрагмент.
var shards := {}
## Два равноправных слота оружия. Оба можно оставить пустыми, заменить или снять.
var weapons: Array = [null, null]


func _ready() -> void:
	for key in EQUIP_SLOTS:
		equipment[key] = null
	changed.connect(_restore_recovered_items)


func _restore_recovered_items() -> void:
	for i in range(recovered_items.size() - 1, -1, -1):
		var item = recovered_items[i]
		var spot := free_spot(size_of(item))
		if spot.x >= 0:
			entries.append({"item": item, "pos": spot})
			recovered_items.remove_at(i)


static func size_of(item) -> Vector2i:
	return item.grid_size if item is GearItem else Vector2i.ONE


## Что лежит в клетке (или null).
func entry_at(cell: Vector2i) -> Dictionary:
	for e in entries:
		var s := size_of(e.item)
		if Rect2i(e.pos, s).has_point(cell):
			return e
	return {}


func find_entry(item) -> Dictionary:
	for e in entries:
		if e.item == item:
			return e
	return {}


## Первое свободное место под предмет (сверху вниз по столбцам, как в PoE). (-1, -1) — нет места.
func free_spot(item_size: Vector2i, ignore = null) -> Vector2i:
	for x in WIDTH - item_size.x + 1:
		for y in HEIGHT - item_size.y + 1:
			if _area_free(Rect2i(Vector2i(x, y), item_size), ignore):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _area_free(area: Rect2i, ignore = null) -> bool:
	for e in entries:
		if e.item != ignore and area.intersects(Rect2i(e.pos, size_of(e.item))):
			return false
	return true


func can_fit(item) -> bool:
	return free_spot(size_of(item)).x >= 0


## Положить предмет в первое свободное место. false — не влез.
func add_item(item) -> bool:
	var spot := free_spot(size_of(item))
	if spot.x < 0:
		return false
	entries.append({"item": item, "pos": spot})
	changed.emit()
	return true


## Положить (или передвинуть) вещь в клетку pos. Если там ровно одна другая вещь — она возвращается
## (её «берут в руку», как в PoE 2). Возвращает {ok, swapped} — swapped: вытесненная вещь или null.
func place(item, pos: Vector2i) -> Dictionary:
	var item_size := size_of(item)
	pos.x = clampi(pos.x, 0, WIDTH - item_size.x)
	pos.y = clampi(pos.y, 0, HEIGHT - item_size.y)
	var area := Rect2i(pos, item_size)
	var hit := []
	for e in entries:
		if e.item != item and area.intersects(Rect2i(e.pos, size_of(e.item))):
			hit.append(e)
	# Стопка фрагментов на такую же стопку — докладываем.
	if hit.size() == 1 and item is CurrencyStack and hit[0].item is CurrencyStack and hit[0].item.id == item.id:
		var target: CurrencyStack = hit[0].item
		var put := mini(item.count, ItemDB.STACK_SIZE - target.count)
		target.count += put
		item.count -= put
		var own := find_entry(item)
		if item.count <= 0 and not own.is_empty():
			entries.erase(own)
		changed.emit()
		return {"ok": item.count <= 0, "swapped": item if item.count > 0 else null, "merged": true}
	if hit.size() > 1:
		return {"ok": false, "swapped": null}
	var swapped = null
	if hit.size() == 1:
		swapped = hit[0].item
		entries.erase(hit[0])
	var own := find_entry(item)
	if own.is_empty():
		entries.append({"item": item, "pos": pos})
	else:
		own.pos = pos
	changed.emit()
	return {"ok": true, "swapped": swapped}


func remove_item(item) -> void:
	var e := find_entry(item)
	if not e.is_empty():
		entries.erase(e)
		changed.emit()


# --- Фрагменты ---------------------------------------------------------------------

## Добавить фрагменты: сначала докладываем в неполные стопки, потом занимаем новые клетки.
## Возвращает, сколько НЕ влезло (0 — всё в сумке).
func add_currency(id: StringName, amount := 1) -> int:
	for e in entries:
		if amount <= 0:
			break
		if e.item is CurrencyStack and e.item.id == id and e.item.count < ItemDB.STACK_SIZE:
			var put := mini(amount, ItemDB.STACK_SIZE - e.item.count)
			e.item.count += put
			amount -= put
	while amount > 0:
		var spot := free_spot(Vector2i.ONE)
		if spot.x < 0:
			changed.emit()
			return amount
		var put := mini(amount, ItemDB.STACK_SIZE)
		entries.append({"item": CurrencyStack.new(id, put), "pos": spot})
		amount -= put
	changed.emit()
	return 0


func count(id: StringName) -> int:
	var total := 0
	for e in entries:
		if e.item is CurrencyStack and e.item.id == id:
			total += e.item.count
	return total


## Потратить один фрагмент: из указанной стопки (если есть) или из любой. Пустая стопка исчезает.
func _spend(id: StringName, stack: CurrencyStack = null) -> void:
	if stack == null or stack.count <= 0:
		for e in entries:
			if e.item is CurrencyStack and e.item.id == id and e.item.count > 0:
				stack = e.item
				break
	if stack == null:
		return
	stack.count -= 1
	if stack.count <= 0:
		entries.erase(find_entry(stack))


## Применить фрагмент к предмету (в сумке или надетому). Возвращает текст ошибки или "".
func apply_currency(id: StringName, item: GearItem, stack: CurrencyStack = null) -> String:
	if count(id) <= 0:
		return "Нет фрагментов"
	var error := item.apply_currency(id)
	if error != "":
		return error
	_spend(id, stack)
	changed.emit()
	return ""


## Превратить чистый модуль в выбранный модуль оружия (он кладётся в сумку). null — не вышло.
func make_module(module_id: StringName, stack: CurrencyStack = null) -> ModuleData:
	if count(&"blank_module") <= 0:
		return null
	var module: ModuleData = ModuleDB.by_id(module_id)
	if module == null:
		return null
	_spend(&"blank_module", stack)
	if not add_item(module):
		add_currency(&"blank_module")  # не влез — возвращаем чистый модуль
		return null
	changed.emit()
	return module


# --- Экипировка ----------------------------------------------------------------------

## Надеть предмет из сумки. Что было надето — ложится в сумку (на освободившееся место, если влезает).
## Возвращает текст ошибки или "".
func equip(item: GearItem) -> String:
	var key := _equip_key(item.slot)
	var old: GearItem = equipment[key]
	var e := find_entry(item)
	if old != null:
		var spot := free_spot(old.grid_size, item)
		if spot.x < 0:
			return "Нет места в сумке для снятого предмета"
		entries.erase(e)
		entries.append({"item": old, "pos": spot})
	else:
		entries.erase(e)
	equipment[key] = item
	changed.emit()
	return ""


## Взять оружие из сумки в один из двух равноправных слотов.
func equip_weapon(item: GearItem, index: int) -> String:
	if is_instance_valid(owner) and owner.get("fixed_bow_loadout") == true: return "Пока используется только закреплённый лук"
	if not ItemDB.available_in_act_one(item.base): return "Это оружие отложено для следующих актов"
	if index < 0 or index >= WEAPON_COUNT or item.slot not in [&"weapon", &"mines"]:
		return "Оружие можно поставить в один из двух слотов"
	var old: GearItem = weapons[index]
	var e := find_entry(item)
	if old != null:
		var spot := free_spot(old.grid_size, item)
		if spot.x < 0:
			return "Нет места в сумке для снятого оружия"
		entries.erase(e)
		entries.append({"item": old, "pos": spot})
	else:
		entries.erase(e)
	weapons[index] = item
	changed.emit()
	return ""


## Убрать оружие в сумку вместе с установленными модулями.
func unequip_weapon(index: int) -> String:
	if is_instance_valid(owner) and owner.get("fixed_bow_loadout") == true: return "Пока используется только закреплённый лук"
	if index < 0 or index >= WEAPON_COUNT:
		return "Нет такого слота оружия"
	var item: GearItem = weapons[index]
	if item == null:
		return ""
	if not can_fit(item):
		return "Нет места в сумке"
	weapons[index] = null
	add_item(item)
	return ""


## Добавить осколки; каждые 10 — целый фрагмент в сумку. Возвращает, сколько фрагментов собралось.
func add_shards(id: StringName, amount: int) -> int:
	var total: int = shards.get(id, 0) + amount
	var whole := total / ItemDB.SHARDS_PER_FRAGMENT
	shards[id] = total % ItemDB.SHARDS_PER_FRAGMENT
	if whole > 0:
		add_currency(id, whole)
	changed.emit()
	return whole


## Снять предмет в сумку. Возвращает текст ошибки или "".
func unequip(key: StringName) -> String:
	var item: GearItem = equipment[key]
	if item == null:
		return ""
	if not can_fit(item):
		return "Нет места в сумке"
	equipment[key] = null
	add_item(item)
	return ""


## Сумма всех характеристик надетой экипировки.
func gear_stats() -> Dictionary:
	var total := {}
	for key in EQUIP_SLOTS:
		var item: GearItem = equipment[key]
		if item == null:
			continue
		var s := item.stats()
		for stat in s:
			total[stat] = total.get(stat, 0) + s[stat]
	return total


func _equip_key(slot: StringName) -> StringName:
	if slot != &"implant":
		return slot
	if equipment[&"implant1"] == null:
		return &"implant1"
	if equipment[&"implant2"] == null:
		return &"implant2"
	return &"implant1"
