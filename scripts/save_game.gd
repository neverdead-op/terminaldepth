extends RefCounted
## Сохранение прогресса в user://save.json: режим, этаж, уровень/опыт/золото, пассивки, аптечка,
## сумка, надетое, оружие с модулями, осколки, склад. Сам этаж (враги, сундуки) не сохраняется —
## после загрузки игрок стоит на базе, лифт ведёт на сохранённый этаж (как выход из игры в PoE 2).

const ItemDB := preload("res://scripts/item_db.gd")
const ModuleDB := preload("res://scripts/module_db.gd")
const PATH := "user://save.json"
const VERSION := 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Короткая сводка для главного меню: {mode, floor, level} или пусто.
static func summary() -> Dictionary:
	var data := _read()
	if data.is_empty():
		return {}
	return {"mode": data.get("mode", "normal"), "floor": int(data.get("floor", 1)),
			"level": int(data.get("player", {}).get("level", 1))}


static func write(game: Node, player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	var stash := []
	for tab in game.stash_tabs:
		stash.append(_inventory_to(tab))
	var data := {
		"version": VERSION, "campaign_version": 2, "mode": String(game.mode), "floor": game.floor_number,
		"player": {"level": player.level, "xp": player.xp, "gold": player.gold, "passive_points": player.passive_points,
			"allocated": player.allocated.map(func(a): return String(a)), "flask": player.flask_charges},
		"inventory": _inventory_to(player.inventory),
		"stash": stash,
		"stash_currency": _dict_str(game.stash_currency),
		"dialog_seen": game.dialog_seen.keys(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


static func read_all() -> Dictionary:
	return _read()


## Разложить сохранённое по игроку и складу (игрок уже в сцене).
static func apply(data: Dictionary, game: Node, player: Node) -> void:
	var p: Dictionary = data.get("player", {})
	player.level = int(p.get("level", 1))
	player.xp = int(p.get("xp", 0))
	player.gold = int(p.get("gold", 0))
	player.passive_points = int(p.get("passive_points", 0))
	var alloc: Array[StringName] = []
	for a in p.get("allocated", ["start"]):
		alloc.append(StringName(a))
	player.allocated = alloc
	player.flask_charges = float(p.get("flask", player.flask_max_charges))
	_inventory_from(player.inventory, data.get("inventory", {}))
	# Отложенное оружие сохраняем в сумке, но не возвращаем в активные слоты.
	# При полном рюкзаке используем существующий список восстановленных предметов.
	if not player.fixed_bow_loadout:
		var inv: PlayerInventory = player.inventory
		for i in inv.weapons.size():
			var item: GearItem = inv.weapons[i]
			if item == null or ItemDB.available_in_act_one(item.base): continue
			inv.weapons[i] = null
			if not inv.add_item(item): inv.recovered_items.append(item)
		if inv.weapons.all(func(item): return item == null):
			inv.weapons[0] = GearItem.create(ItemDB.base_by_id(&"rifle"), 1, 0)
	var stash: Array = data.get("stash", [])
	for i in mini(stash.size(), game.stash_tabs.size()):
		_inventory_from(game.stash_tabs[i], stash[i])
	for k in data.get("dialog_seen", []):
		game.dialog_seen[k] = true
	game.stash_currency.clear()
	for k in data.get("stash_currency", {}):
		game.stash_currency[StringName(k)] = int(data.stash_currency[k])


# --- Внутреннее ---

static func _read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _dict_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out


static func _inventory_to(inv: Node) -> Dictionary:
	var entries := []
	for e in inv.entries:
		var it := _item_to(e.item)
		if not it.is_empty():
			entries.append({"x": e.pos.x, "y": e.pos.y, "item": it})
	var equip := {}
	for k in inv.equipment:
		equip[String(k)] = _item_to(inv.equipment[k]) if inv.equipment[k] != null else null
	var weapons := []
	for w in inv.weapons:
		weapons.append(_item_to(w) if w != null else null)
	var recovered := []
	for item in inv.recovered_items:
		var packed := _item_to(item)
		if not packed.is_empty():
			recovered.append(packed)
	return {"entries": entries, "equipment": equip, "weapons": weapons, "weapon_layout": PlayerInventory.WEAPON_COUNT,
			"grid_layout": 2, "recovered": recovered,
			"shards": _dict_str(inv.shards)}


static func _inventory_from(inv: Node, d: Dictionary) -> void:
	if d.is_empty():
		return
	inv.entries.clear()
	inv.recovered_items.clear()
	inv.weapons.fill(null)
	for e in d.get("entries", []):
		var item = _item_from(e.item)
		if item != null:
			var size: Vector2i = PlayerInventory.size_of(item)
			var saved_pos := Vector2i(int(e.x), int(e.y))
			var saved_area := Rect2i(saved_pos, size)
			var fits: bool = saved_pos.x >= 0 and saved_pos.y >= 0 and saved_area.end.x <= PlayerInventory.WIDTH and saved_area.end.y <= PlayerInventory.HEIGHT and inv._area_free(saved_area)
			if fits:
				inv.entries.append({"item": item, "pos": saved_pos})
			else:
				var spot: Vector2i = inv.free_spot(size)
				if spot.x >= 0:
					inv.entries.append({"item": item, "pos": spot})
				else:
					inv.recovered_items.append(item)
	for packed in d.get("recovered", []):
		var item = _item_from(packed)
		if item != null:
			inv.recovered_items.append(item)
	for k in d.get("equipment", {}):
		var v = d.equipment[k]
		inv.equipment[StringName(k)] = _item_from(v) if v != null else null
	var weapons: Array = d.get("weapons", [])
	if int(d.get("weapon_layout", 0)) == PlayerInventory.WEAPON_COUNT:
		for i in mini(weapons.size(), PlayerInventory.WEAPON_COUNT):
			inv.weapons[i] = _item_from(weapons[i]) if weapons[i] != null else null
	else:
		# В старых сохранениях были пистолетный слот и два слота основного оружия.
		# Оставляем экипированными два основных ствола, а остальные переносим в сумку.
		var candidates: Array = []
		for old_index in [1, 2, 0, 3]:
			if old_index < weapons.size() and weapons[old_index] != null:
				var item = _item_from(weapons[old_index])
				if item is GearItem and item.slot == &"mines":
					item.base = item.base.duplicate(true)
					item.base.slot = &"weapon"
				candidates.append(item)
		var equipped := 0
		for item in candidates:
			if item is GearItem and item.slot == &"weapon" and equipped < PlayerInventory.WEAPON_COUNT:
				inv.weapons[equipped] = item
				equipped += 1
			elif item != null:
				var spot: Vector2i = inv.free_spot(PlayerInventory.size_of(item))
				if spot.x >= 0:
					inv.entries.append({"item": item, "pos": spot})
				else:
					inv.recovered_items.append(item)
	inv.shards.clear()
	for k in d.get("shards", {}):
		inv.shards[StringName(k)] = int(d.shards[k])
	inv.changed.emit()


static func _item_to(item) -> Dictionary:
	if item is GearItem:
		var affixes := []
		for a in item.affixes:
			affixes.append({"id": String(a.id), "tier": a.tier, "value": a.value})
		var modules := []
		for m in item.modules:
			modules.append(String(m.id) if m != null else null)
		return {"t": "gear", "base": String(item.base.id), "rarity": item.rarity, "ilvl": item.item_level,
			"affixes": affixes, "rare_name": item.rare_name, "unique": String(item.unique.get("id", "")),
			"sockets": item.sockets, "modules": modules,
			"secondary_modules": item.secondary_modules.map(func(m): return String(m.id) if m != null else null),
			"quality": item.quality, "aug_sockets": item.aug_sockets,
			"augments": item.augments.map(func(a): return String(a)), "corp": String(item.corp)}
	if item is ModuleData:
		return {"t": "module", "id": String(item.id)}
	if item != null and "count" in item:
		return {"t": "currency", "id": String(item.id), "count": item.count}
	return {}


static func _item_from(d) -> Variant:
	if not d is Dictionary or d.is_empty():
		return null
	match d.get("t", ""):
		"module":
			return ModuleDB.by_id(StringName(d.id))
		"currency":
			return PlayerInventory.CurrencyStack.new(StringName(d.id), int(d.count))
		"gear":
			# Отложенные старые базы заменяются резаком; действующий pistol сохраняем.
			var base_id := StringName(d.base)
			if base_id in [&"heavy_pistol", &"revolver", &"magnum", &"machine_pistol"]:
				base_id = &"plasma_cutter_mk2" if int(d.get("ilvl", 1)) >= 4 else &"plasma_cutter"
			var base := ItemDB.base_by_id(base_id).duplicate(true)
			if base.is_empty():
				return null
			if base.get("slot", &"") == &"sidearm":
				base.slot = &"weapon"
			var item := GearItem.create(base, int(d.ilvl), 0)
			item.rarity = int(d.rarity)
			item.affixes.clear()
			for a in d.get("affixes", []):
				var v = a.value
				item.affixes.append({"id": StringName(a.id), "tier": int(a.tier),
						"value": int(v) if is_equal_approx(float(v), roundf(float(v))) else float(v)})
			item.rare_name = d.get("rare_name", "")
			var uid := StringName(d.get("unique", ""))
			if uid != &"":
				for u in ItemDB.UNIQUES:
					if u.id == uid:
						item.unique = u
			item.sockets = int(d.get("sockets", item.sockets))
			item.modules.clear()
			for m in d.get("modules", []):
				item.modules.append(ModuleDB.by_id(StringName(m)) if m != null else null)
			item.modules.resize(item.sockets)
			item.secondary_modules = d.get("secondary_modules", [null, null]).map(func(m): return ModuleDB.by_id(StringName(m)) if m != null else null)
			item.secondary_modules.resize(2)
			item.quality = int(d.get("quality", 0))
			item.aug_sockets = int(d.get("aug_sockets", 0))
			item.augments.clear()
			for a in d.get("augments", []):
				item.augments.append(StringName(a))
			item.corp = base.get("corp", StringName(d.get("corp", "")))
			return item
	return null
