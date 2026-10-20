class_name GearItem
extends RefCounted
## Один предмет экипировки: база, редкость, уровень предмета и выпавшие свойства.
## Создаётся в игре (выпадает с врагов), а не хранится файлом. Крафт фрагментами меняет его на месте.

const ItemDB := preload("res://scripts/item_db.gd")
const ArtNames := preload("res://scripts/item_art_names.gd")

var base: Dictionary
var rarity := 0  # 0 — белый, 1 — синий, 2 — жёлтый
var item_level := 1
## Свойства: [{id, tier (номер в списке tiers), value}]
var affixes: Array[Dictionary] = []
var rare_name := ""
## Уникальный предмет (запись из ItemDB.UNIQUES) — у него свои имя и свойства. Пусто — обычный.
var unique: Dictionary = {}
## Только у оружия: сколько гнёзд под модули и что в них вставлено (модули остаются в оружии, как камни в PoE).
var sockets := 0
var modules: Array = []
## Модификаторы второго навыка оружия, отдельно от основного выстрела.
var secondary_modules: Array = [null, null]
## Качество 0…20 (%): броня/щит базы или урон оружия.
var quality := 0
## Гнёзда аугментов в броне и что в них вставлено (id аугментов).
var aug_sockets := 0
var augments: Array[StringName] = []
## Фирма-производитель оружия (ItemDB.CORPS): встроенные свойства и вид значка. У брони фирма — по типу защиты.
var corp := &""
var _weapon_data: WeaponData


static func create(base_dict: Dictionary, level: int, rarity_value: int) -> GearItem:
	var item := GearItem.new()
	item.base = base_dict
	if ArtNames.NAMES.has(base_dict.id):
		item.base = base_dict.duplicate()
		item.base.name = ArtNames.NAMES[base_dict.id]
	item.item_level = level
	if item.is_weapon():
		item.sockets = ItemDB.START_SOCKETS
		item.modules.resize(item.sockets)
		if ItemDB.WEAPON_ICON_KIND.has(item._weapon_file()):
			item.corp = base_dict.get("corp", &"helix")
	else:
		var makers: Array = ItemDB.CORP_BY_DEFENSE[item.defense_kind()]
		item.corp = base_dict.get("corp", makers[absi(hash(base_dict.id)) % makers.size()])
	item.set_rarity(rarity_value)
	return item


func is_weapon() -> bool:
	return base.has("weapon")


## Цифры базы оружия (файл WeaponData).
func weapon_data() -> WeaponData:
	if _weapon_data == null and is_weapon():
		_weapon_data = load(base.weapon)
		if ArtNames.NAMES.has(base.id):
			_weapon_data.display_name = ArtNames.NAMES[base.id]
	return _weapon_data


func has_modules() -> bool:
	return modules.any(func(m): return m != null) or secondary_modules.any(func(m): return m != null)

func secondary_skill() -> StringName:
	return weapon_data().secondary_skill if is_weapon() else &""


static func random_drop(level: int, rarity_bonus := 0.0) -> GearItem:
	# Изредка — уникальный (у сундуков и жёлтых врагов чаще).
	if randf() < 0.004 + rarity_bonus * 0.015:
		var u := ItemDB.random_unique(level)
		if not u.is_empty():
			return create_unique(u, level)
	return create(ItemDB.random_base(&"", level), level, ItemDB.roll_rarity(rarity_bonus, level))


static func create_unique(u: Dictionary, level: int) -> GearItem:
	var item := create(ItemDB.base_by_id(u.base), level, 0)
	item.rarity = 3
	item.unique = u
	if item.is_weapon():
		item.corp = &""  # у уникального оружия свои свойства, без фирмы
	return item


var slot: StringName:
	get:
		return base.slot


## Сколько клеток сумки занимает.
var grid_size: Vector2i:
	get:
		return Vector2i(2, 2) if base.slot == &"mines" else ItemDB.SLOT_SIZES[base.slot]


## Поменять редкость и заново выбросить свойства под неё.
func set_rarity(value: int) -> void:
	rarity = value
	affixes.clear()
	match rarity:
		1:
			_add_random_affixes(randi_range(1, 2))
		2:
			_add_random_affixes(randi_range(3, 4))
			_roll_name()


func max_affixes() -> int:
	return [0, 2, 6][rarity]


# --- Крафт ---------------------------------------------------------------------

## Применить ксено-фрагмент (правила как у сфер PoE 2). Возвращает текст ошибки или "" если получилось.
func apply_currency(id: StringName) -> String:
	if id in [&"plating_kit", &"calibration_kit"]:
		return _add_quality(id)
	if ItemDB.AUGMENTS.has(id):
		return _insert_augment(id)
	if rarity == 3 and id != &"socket_cutter":
		return "Unique-предмет нельзя изменить"
	match id:
		&"mutagen":  # Transmutation
			if rarity != 0:
				return "Mutagen Vial работает только на белых (Normal) предметах"
			rarity = 1
			_add_random_affixes(1)
		&"unstable":  # Augmentation
			if rarity != 1:
				return "Unstable Mutagen работает только на синих (Magic) предметах"
			if affixes.size() >= 2:
				return "У синего предмета уже два свойства — нужен Reliquary Core"
			if not _add_random_affixes(1):
				return "Нет подходящих свойств"
		&"hive_core":  # Regal
			if rarity != 1:
				return "Reliquary Core работает только на синих (Magic) предметах"
			rarity = 2
			_add_random_affixes(1)
			_roll_name()
		&"queen_heart":  # Exalted
			if rarity != 2:
				return "Seraph's Heart работает только на жёлтых (Rare) предметах"
			if affixes.size() >= 6:
				return "У предмета уже 6 свойств"
			if not _add_random_affixes(1):
				return "Нет места: уже 3 префикса или 3 суффикса подходящих видов"
		&"catalyst":  # Chaos (по задумке: заменить все свойства)
			if rarity != 2:
				return "Chaos Catalyst работает только на жёлтых (Rare) предметах"
			var count := affixes.size()
			affixes.clear()
			_add_random_affixes(count)
		&"cocoon":  # Alchemy
			if rarity != 0:
				return "Alchemist's Chalice работает только на белых (Normal) предметах"
			rarity = 2
			_add_random_affixes(4)
			_roll_name()
		&"solvent":  # Annulment
			if rarity == 0 or affixes.is_empty():
				return "Annulment Solvent работает на синих и жёлтых предметах со свойствами"
			affixes.remove_at(randi() % affixes.size())
		&"stabilizer":  # Divine
			if affixes.is_empty():
				return "У предмета нет свойств"
			for a in affixes:
				var t: Array = ItemDB.AFFIXES[a.id].tiers[a.tier]
				a.value = randi_range(t[1], t[2])
		&"socket_cutter":
			if not is_weapon():
				var most: int = ItemDB.AUGMENT_SOCKETS.get(slot, 0)
				if most == 0:
					return "Socket Cutter работает на оружии и броне"
				if aug_sockets >= most:
					return "Больше гнёзд аугментов здесь не открыть"
				aug_sockets += 1
				return ""
			if sockets >= ItemDB.MAX_SOCKETS:
				return "В оружии уже %d гнёзд — больше нельзя" % ItemDB.MAX_SOCKETS
			sockets += 1
			modules.append(null)
		_:
			return "Это нельзя применить к предмету"
	return ""


# --- Характеристики ---------------------------------------------------------------

## Насколько «улучшенная» база, выпавшая раньше своего уровня, слабее полной: на 1-м уровне она
## примерно как обычная, дальше каждый уровень чуть сильнее, а на своём уровне — полная сила.
const UNDERLEVEL_STEP := 0.27

## Встроенные свойства базы: [[id, число], ...]. У обычных вещей одно или ни одного, у улучшенных — свои.
func implicits() -> Array:
	var list: Array = base.get("implicits", []).duplicate()
	if base.has("implicit"):
		list.push_front(base.implicit)
	return list


## Множитель защиты базы: +6% за уровень предмета и поправка для баз, выпавших раньше своего уровня.
func defense_level_scale() -> float:
	var scale := 1.0 + 0.06 * (item_level - 1)
	var base_level: int = base.get("level", 1)
	if item_level < base_level:
		scale *= (1.0 + UNDERLEVEL_STEP * (item_level - 1)) / (1.0 + UNDERLEVEL_STEP * (base_level - 1))
	return scale


## Всё, что предмет даёт персонажу: {stat: число}. Защита базы растёт с уровнем предмета.
func stats() -> Dictionary:
	var result := {}
	var scale := defense_level_scale() * (1.0 + quality / 100.0)
	var armor_pct := 0.0
	var es_pct := 0.0
	for a in affixes:
		if a.id == &"armor_pct":
			armor_pct += a.value
		elif a.id == &"es_pct":
			es_pct += a.value
	if base.armor > 0:
		result[&"armor_flat"] = roundi(base.armor * scale * (1.0 + armor_pct / 100.0))
	if base.es > 0:
		result[&"es_flat"] = roundi(base.es * scale * (1.0 + es_pct / 100.0))
	if is_weapon() and quality > 0:
		result[&"w_damage"] = quality
	for a in augments:
		var aug: Array = ItemDB.AUGMENTS[a]
		result[aug[0]] = result.get(aug[0], 0) + aug[1]
	for imp in implicits():
		var affix: Dictionary = ItemDB.AFFIXES[imp[0]]
		result[affix.stat] = result.get(affix.stat, 0) + imp[1]
	for a in affixes:
		if a.id == &"armor_pct" or a.id == &"es_pct":
			continue  # уже учтено в защите самой вещи
		var stat: StringName = ItemDB.AFFIXES[a.id].stat
		result[stat] = result.get(stat, 0) + a.value
	for m in unique.get("mods", []):
		result[m[0]] = result.get(m[0], 0) + m[1]
	if is_weapon() and corp != &"":
		for m in ItemDB.CORPS[corp].mods:
			result[m[0]] = result.get(m[0], 0) + m[1]
	return result


## Класс оружия: &"light", &"medium", &"heavy" (для веток пассивок).
func weapon_class() -> StringName:
	return ItemDB.WEAPON_CLASS.get(_weapon_file(), &"medium")


func _weapon_file() -> StringName:
	return StringName(String(base.weapon).get_file().get_basename()) if is_weapon() else &""


## Путь к картинке-значку вещи (вырезано из референсов) или "" — тогда рисуем значок кодом.
func icon_path() -> String:
	if base.has("icon"):
		return base.icon
	if base.id in [&"plasma_cutter", &"plasma_cutter_mk2"]:
		return "res://assets/icons/weapons/%s.png" % base.id
	if slot == &"mines":
		return "res://assets/icons/weapons/mine_pack_v2.png"
	if is_weapon():
		var kind: StringName = ItemDB.WEAPON_ICON_KIND.get(_weapon_file(), &"")
		if kind == &"":
			return ""
		var maker: StringName = corp if corp != &"" else ItemDB.CORP_ORDER[absi(hash(base.id)) % ItemDB.CORP_ORDER.size()]
		return "res://assets/icons/corp_weapons/%s_%s.png" % [maker, kind]
	var maker2: StringName = corp if corp != &"" else &"orion"
	match slot:
		&"helmet", &"gloves":
			return "res://assets/icons/gear/%s_%s_%d.png" % [slot, maker2, absi(hash(base.id)) % 3]
		&"body":
			return "res://assets/icons/gear/body_%s.png" % maker2
		&"boots":
			return "res://assets/icons/gear/boots_%s.png" % maker2
		&"implant", &"combat":
			if ItemDB.HEX_ICONS.has(base.id):
				return "res://assets/icons/gear/hex_%s.png" % ItemDB.HEX_ICONS[base.id]
	return ""


## Тип защиты: &"armor", &"es", &"hybrid" или пусто (импланты, модули).
func defense_kind() -> StringName:
	if base.armor > 0 and base.es > 0:
		return &"hybrid"
	if base.es > 0:
		return &"es"
	if base.armor > 0:
		return &"armor"
	return &""


func display_name() -> String:
	if rarity == 3:
		return Loc.t(unique.name)
	if rarity == 2:
		var parts := rare_name.split(" ", true, 1)
		return Loc.t(parts[0]) + (" " + Loc.t(parts[1]) if parts.size() > 1 else "")
	if corp != &"" and is_weapon() and not ArtNames.NAMES.has(base.id):
		return "%s %s" % [ItemDB.CORPS[corp].name, Loc.t(base.name)]
	return Loc.t(base.name)


func color() -> Color:
	return ItemDB.RARITY_COLORS[rarity]


## Строки для подсказки: [текст, это свойство (а не база)?].
func describe() -> Array:
	var lines := []
	var scale := defense_level_scale() * (1.0 + quality / 100.0)
	if quality > 0:
		lines.append(["Quality: +%d%%" % quality, false])
	if not is_weapon() and slot in [&"helmet", &"body", &"gloves", &"boots"]:
		lines.append([ArtNames.DEFENSE_LABELS.get(defense_kind(), ""), false])
	if is_weapon() and corp != &"":
		var info: Dictionary = ItemDB.CORPS[corp]
		lines.append(["%s — %s" % [info.name, Loc.t(info.tag)], false])
		for m in info.mods:
			lines.append([m[2], false])
	if is_weapon():
		var w := weapon_data()
		var s := stats()
		var dmg: float = w.damage * (1.0 + s.get(&"w_damage", 0) / 100.0)
		lines.append(["Урон: %.0f%s" % [dmg, "  × %d пуль" % w.pellets if w.pellets > 1 else ""], false,
				s.get(&"w_damage", 0) > 0])
		for el in [["w_fire", "Урон огнём: +%d"], ["w_electric", "Урон электричеством: +%d"], ["w_acid", "Урон кислотой: +%d"]]:
			if s.get(StringName(el[0]), 0) > 0:
				lines.append([el[1] % s[StringName(el[0])], false, true])
		var fr: float = s.get(&"w_fire_rate", 0)
		lines.append(["Выстрелов в секунду: %.1f" % (w.fire_rate * (1.0 + fr / 100.0)), false, fr > 0])
		lines.append(["Магазин: %d" % ceili(w.magazine_size * (1.0 + s.get(&"w_magazine", 0) / 100.0)), false,
				s.get(&"w_magazine", 0) > 0])
		lines.append(["Урон в секунду: %.0f" % dps(), false])
		lines.append(["Гнёзда для модулей: %d / %d" % [sockets, ItemDB.MAX_SOCKETS], false])
	var st := stats()
	if base.armor > 0:
		var boosted: bool = st.get(&"armor_flat", 0) > roundi(base.armor * defense_level_scale())
		lines.append(["Armour: %d" % (st.get(&"armor_flat", 0) + _flat(&"armor")), false, boosted or _flat(&"armor") > 0])
	if base.es > 0:
		var boosted_es: bool = st.get(&"es_flat", 0) > roundi(base.es * defense_level_scale())
		lines.append(["Energy Shield: %d" % (st.get(&"es_flat", 0) + _flat(&"es")), false, boosted_es or _flat(&"es") > 0])
	for imp in implicits():
		lines.append([ItemDB.AFFIXES[imp[0]].text % imp[1], false])
	for a in affixes:
		var info: Dictionary = ItemDB.AFFIXES[a.id]
		var tier_label: int = info.tiers.size() - a.tier
		lines.append(["%s   (T%d)" % [info.text % a.value, tier_label], true])
	for m in unique.get("mods", []):
		lines.append([m[2], true])
	for i in aug_sockets:
		if i < augments.size():
			lines.append(["◆ " + ItemDB.AUGMENTS[augments[i]][2], true])
		else:
			lines.append(["◇ Пустое гнездо аугмента", true])
	return lines


## Сумма плоского свойства вещи (например, «+N к Armour»).
func _flat(id: StringName) -> int:
	var total := 0
	for a in affixes:
		if a.id == id:
			total += int(a.value)
	return total


## Качество: белым +5%, синим +2%, жёлтым и уникальным +1%, максимум +20%.
func _add_quality(id: StringName) -> String:
	if (id == &"calibration_kit") != is_weapon():
		return "Calibration Kit — для оружия, Plating Kit — для брони и остального"
	if quality >= ItemDB.MAX_QUALITY:
		return "Качество уже максимальное (+20%)"
	quality = mini(quality + [5, 2, 1, 1][rarity], ItemDB.MAX_QUALITY)
	return ""


func _insert_augment(id: StringName) -> String:
	if aug_sockets == 0:
		return "Нет гнезда для аугмента — откройте его Socket Cutter-ом (броня)"
	if augments.size() >= aug_sockets:
		return "Все гнёзда аугментов заняты"
	augments.append(id)
	return ""


## Урон в секунду оружия без модулей (для сравнения стволов).
func dps() -> float:
	if not is_weapon():
		return 0.0
	var w := weapon_data()
	var s := stats()
	var added: float = s.get(&"w_fire", 0) + s.get(&"w_electric", 0) + s.get(&"w_acid", 0)
	return (w.damage * (1.0 + s.get(&"w_damage", 0) / 100.0) + added) * w.pellets 			* w.fire_rate * (1.0 + s.get(&"w_fire_rate", 0) / 100.0)


# --- Внутреннее --------------------------------------------------------------------

## Добавить случайные свойства. false — не нашлось ни одного подходящего.
func _add_random_affixes(count: int) -> bool:
	var added := false
	var max_each := 1 if rarity == 1 else 3
	for i in count:
		var prefixes := affixes.filter(func(a): return ItemDB.AFFIXES[a.id].type == "prefix").size()
		var suffixes := affixes.size() - prefixes
		var pool := []
		for id in ItemDB.AFFIXES:
			var info: Dictionary = ItemDB.AFFIXES[id]
			if not slot in info.slots:
				continue
			if id in ItemDB.NEEDS_ARMOR and base.armor <= 0:
				continue
			if id in ItemDB.NEEDS_ES and base.es <= 0:
				continue
			if affixes.any(func(a): return a.id == id):
				continue
			if info.type == "prefix" and prefixes >= max_each:
				continue
			if info.type == "suffix" and suffixes >= max_each:
				continue
			pool.append(id)
		if pool.is_empty():
			return added
		var id: StringName = pool.pick_random()
		affixes.append(_roll_affix(id))
		added = true
	return added


## Тир: доступны те, что разрешены уровнем предмета; сильные выпадают реже.
func _roll_affix(id: StringName) -> Dictionary:
	var tiers: Array = ItemDB.AFFIXES[id].tiers
	var weights := []
	var total := 0.0
	for t in tiers.size():
		var w := 0.0
		if tiers[t][0] <= item_level:
			w = 1.0 / (1.0 + t * 1.5)
		weights.append(w)
		total += w
	var pick := randf() * total
	var tier := 0
	for t in tiers.size():
		pick -= weights[t]
		if pick <= 0.0 and weights[t] > 0.0:
			tier = t
			break
	return {"id": id, "tier": tier, "value": randi_range(tiers[tier][1], tiers[tier][2])}


func _roll_name() -> void:
	rare_name = "%s %s" % [ItemDB.RARE_ADJECTIVES.pick_random(), ItemDB.RARE_NOUNS[slot].pick_random()]
