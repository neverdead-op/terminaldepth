extends RefCounted
## Дерево пассивных умений (первая, компактная версия для демо до 5 уровня).
## Узел: id, name, pos (в клетках дерева, 1 клетка ≈ 60 пикселей), kind (start / small / notable),
## icon (значок, см. ui_icons.gd), stats — те же характеристики, что дают вещи (см. item_db.gd AFFIXES.stat).
## Вкладывать очко можно только в узел, соседний с уже взятым (как в PoE 2). Связи — в EDGES.

## Дерево — четыре ряда слева направо (Атака, Скорость, Защита, Стойкость), крупный узел в конце ряда,
## между соседними рядами — переходы. Начало — слева по центру.
const ROWS := [["ГРАНАТЫ", -4.0], ["АТАКА", -2.4], ["СКОРОСТЬ", -0.8], ["ЗАЩИТА", 0.8], ["СТОЙКОСТЬ", 2.4],
		["СНАРЯДЫ", -3.2, 7.7], ["ЛЁГКОЕ", -1.9, 9.4], ["СРЕДНЕЕ", -0.6, 9.4], ["ТЯЖЁЛОЕ", 0.7, 9.4],
		["ОГОНЬ", 4.0, -3.9], ["КИСЛОТА", 3.45, 2.8], ["ЭЛЕКТРО", 3.45, 6.8]]

const NODES := [
	{"id": &"start", "name": "Оперативник", "pos": Vector2(-4.6, 0), "kind": "start", "icon": &"helmet", "stats": {}},

	{"id": &"off1", "name": "Меткость", "pos": Vector2(-2.6, -2.4), "kind": "small", "icon": &"damage", "stats": {&"damage_pct": 8}},
	{"id": &"off2", "name": "Спусковой крючок", "pos": Vector2(-0.8, -2.4), "kind": "small", "icon": &"fire_rate", "stats": {&"fire_rate_pct": 7}},
	{"id": &"off3", "name": "Убойная сила", "pos": Vector2(1.0, -2.4), "kind": "small", "icon": &"damage", "stats": {&"damage_pct": 10}},
	{"id": &"off_n", "name": "Шквал огня", "pos": Vector2(3.0, -2.4), "kind": "notable", "icon": &"fire_rate",
		"stats": {&"fire_rate_pct": 15, &"damage_pct": 10}},

	{"id": &"util1", "name": "Сноровка", "pos": Vector2(-2.6, -0.8), "kind": "small", "icon": &"fast_reload", "stats": {&"reload_pct": 12}},
	{"id": &"util2", "name": "Лёгкий шаг", "pos": Vector2(-0.8, -0.8), "kind": "small", "icon": &"speed", "stats": {&"move_speed": 4}},
	{"id": &"util3", "name": "Отработанные движения", "pos": Vector2(1.0, -0.8), "kind": "small", "icon": &"fast_reload", "stats": {&"reload_pct": 15}},
	{"id": &"util_n", "name": "Быстрые руки", "pos": Vector2(3.0, -0.8), "kind": "notable", "icon": &"fast_reload",
		"stats": {&"reload_pct": 25, &"move_speed": 6, &"fire_rate_pct": 5}},

	{"id": &"def1", "name": "Выносливость", "pos": Vector2(-2.6, 0.8), "kind": "small", "icon": &"life", "stats": {&"max_hp": 15}},
	{"id": &"def2", "name": "Бронепластины", "pos": Vector2(-0.8, 0.8), "kind": "small", "icon": &"armor", "stats": {&"armor_flat": 20}},
	{"id": &"def3", "name": "Генератор щита", "pos": Vector2(1.0, 0.8), "kind": "small", "icon": &"energy_shield", "stats": {&"es_flat": 15}},
	{"id": &"def_n", "name": "Закалённый", "pos": Vector2(3.0, 0.8), "kind": "notable", "icon": &"life",
		"stats": {&"max_hp": 30, &"armor_pct": 25, &"es_pct": 25}},

	{"id": &"res1", "name": "Фильтры", "pos": Vector2(-2.6, 2.4), "kind": "small", "icon": &"acid", "stats": {&"res_acid": 10}},
	{"id": &"res2", "name": "Изоляция", "pos": Vector2(-0.8, 2.4), "kind": "small", "icon": &"electric",
		"stats": {&"res_electric": 10, &"res_fire": 10}},
	{"id": &"res3", "name": "Регенерация тканей", "pos": Vector2(1.0, 2.4), "kind": "small", "icon": &"life", "stats": {&"hp_regen": 2}},
	{"id": &"res_n", "name": "Ксено-иммунитет", "pos": Vector2(3.0, 2.4), "kind": "notable", "icon": &"acid",
		"stats": {&"res_fire": 12, &"res_electric": 12, &"res_acid": 12, &"es_recharge": 25}},

	# --- Гранаты (над рядом атаки) ---
	{"id": &"gren1", "name": "Запал", "pos": Vector2(-2.6, -4.0), "kind": "small", "icon": &"explosive",
		"stats": {&"grenade_recharge": 15}},
	{"id": &"gren2", "name": "Начинка", "pos": Vector2(-0.8, -4.0), "kind": "small", "icon": &"explosive",
		"stats": {&"grenade_damage": 20}},
	{"id": &"gren3", "name": "Широкий разлёт", "pos": Vector2(1.0, -4.0), "kind": "small", "icon": &"explosive",
		"stats": {&"grenade_radius": 15, &"grenade_recharge": 10}},
	{"id": &"gren_n", "name": "Подрывник", "pos": Vector2(3.0, -4.0), "kind": "notable", "icon": &"explosive",
		"stats": {&"grenade_charges": 1, &"grenade_damage": 25, &"grenade_radius": 15}},

	# --- Снаряды и классы оружия (справа от крупных узлов) ---
	{"id": &"proj1", "name": "Баллистика", "pos": Vector2(4.8, -3.2), "kind": "small", "icon": &"pierce",
		"stats": {&"proj_speed": 15}},
	{"id": &"proj_n", "name": "Баллистик", "pos": Vector2(6.6, -3.2), "kind": "notable", "icon": &"pierce",
		"stats": {&"pierce": 1, &"proj_speed": 20, &"damage_pct": 5}},

	{"id": &"light1", "name": "Лёгкая рука", "pos": Vector2(4.8, -1.9), "kind": "small", "icon": &"fire_rate",
		"stats": {&"light_dmg": 12}},
	{"id": &"light2", "name": "Быстрый спуск", "pos": Vector2(6.6, -1.9), "kind": "small", "icon": &"fire_rate",
		"stats": {&"light_fire_rate": 10}},
	{"id": &"light_n", "name": "Ганслингер", "pos": Vector2(8.4, -1.9), "kind": "notable", "icon": &"fire_rate",
		"stats": {&"light_dmg": 20, &"light_fire_rate": 12, &"move_speed": 5}},

	{"id": &"med1", "name": "Строевая выучка", "pos": Vector2(4.8, -0.6), "kind": "small", "icon": &"damage",
		"stats": {&"medium_dmg": 12}},
	{"id": &"med2", "name": "Смена магазина", "pos": Vector2(6.6, -0.6), "kind": "small", "icon": &"fast_reload",
		"stats": {&"medium_reload": 15}},
	{"id": &"med_n", "name": "Ветеран", "pos": Vector2(8.4, -0.6), "kind": "notable", "icon": &"damage",
		"stats": {&"medium_dmg": 22, &"medium_reload": 15, &"max_hp": 15}},

	{"id": &"heavy1", "name": "Упор", "pos": Vector2(4.8, 0.7), "kind": "small", "icon": &"ext_mag",
		"stats": {&"heavy_dmg": 14}},
	{"id": &"heavy2", "name": "Лента подачи", "pos": Vector2(6.6, 0.7), "kind": "small", "icon": &"ext_mag",
		"stats": {&"heavy_magazine": 20}},
	{"id": &"heavy_n", "name": "Опустошитель", "pos": Vector2(8.4, 0.7), "kind": "notable", "icon": &"ext_mag",
		"stats": {&"heavy_dmg": 30, &"heavy_magazine": 25, &"armor_flat": 20}},

	# --- Стихии (под рядом стойкости): урон стихией и сила её состояния ---
	{"id": &"fire1", "name": "Зажигательная смесь", "pos": Vector2(-2.6, 4.0), "kind": "small", "icon": &"fire",
		"stats": {&"fire_dmg": 10}},
	{"id": &"fire2", "name": "Тлеющие угли", "pos": Vector2(-1.4, 4.0), "kind": "small", "icon": &"fire",
		"stats": {&"burn_pct": 25}},
	{"id": &"fire_n", "name": "Пироман", "pos": Vector2(-0.2, 4.0), "kind": "notable", "icon": &"fire",
		"stats": {&"fire_dmg": 20, &"burn_pct": 40}},
	{"id": &"acid1", "name": "Едкий раствор", "pos": Vector2(1.6, 4.0), "kind": "small", "icon": &"acid",
		"stats": {&"acid_dmg": 10}},
	{"id": &"acid2", "name": "Разъедание", "pos": Vector2(2.8, 4.0), "kind": "small", "icon": &"acid",
		"stats": {&"corrode_pct": 30}},
	{"id": &"acid_n", "name": "Растворитель", "pos": Vector2(4.0, 4.0), "kind": "notable", "icon": &"acid",
		"stats": {&"acid_dmg": 20, &"corrode_pct": 50}},
	{"id": &"elec1", "name": "Конденсатор", "pos": Vector2(5.6, 4.0), "kind": "small", "icon": &"electric",
		"stats": {&"electric_dmg": 10}},
	{"id": &"elec2", "name": "Пробой", "pos": Vector2(6.8, 4.0), "kind": "small", "icon": &"electric",
		"stats": {&"shock_pct": 8}},
	{"id": &"elec_n", "name": "Перегрузка сети", "pos": Vector2(8.0, 4.0), "kind": "notable", "icon": &"electric",
		"stats": {&"electric_dmg": 20, &"shock_pct": 15}},

	# --- Особые узлы оружия (в конце веток классов) ---
	{"id": &"dual_n", "name": "Два ствола", "pos": Vector2(11.0, -1.9), "kind": "notable", "icon": &"multishot",
		"stats": {&"dual_pistols": 1}},
	{"id": &"rifle_n", "name": "Злая очередь", "pos": Vector2(11.0, -0.9), "kind": "notable", "icon": &"ricochet",
		"stats": {&"rifle_ricochet": 50}},
	{"id": &"shot_n", "name": "Быстрый затвор", "pos": Vector2(11.0, 0.1), "kind": "notable", "icon": &"fast_reload",
		"stats": {&"shotgun_instant": 30}},

	# Переходы между соседними рядами.
	{"id": &"mix_ul", "name": "Стрельба с ходу", "pos": Vector2(0.1, -1.6), "kind": "small", "icon": &"fire_rate",
		"stats": {&"fire_rate_pct": 4, &"move_speed": 3}},
	{"id": &"mix_ur", "name": "Боевой опыт", "pos": Vector2(0.1, 0.0), "kind": "small", "icon": &"damage",
		"stats": {&"damage_pct": 5, &"max_hp": 8}},
	{"id": &"mix_dr", "name": "Стойкость", "pos": Vector2(0.1, 1.6), "kind": "small", "icon": &"armor",
		"stats": {&"armor_flat": 10, &"res_fire": 6}},
]

const EDGES := [
	[&"start", &"off1"], [&"off1", &"off2"], [&"off2", &"off3"], [&"off3", &"off_n"],
	[&"start", &"util1"], [&"util1", &"util2"], [&"util2", &"util3"], [&"util3", &"util_n"],
	[&"start", &"def1"], [&"def1", &"def2"], [&"def2", &"def3"], [&"def3", &"def_n"],
	[&"start", &"res1"], [&"res1", &"res2"], [&"res2", &"res3"], [&"res3", &"res_n"],
	[&"off2", &"mix_ul"], [&"mix_ul", &"util2"], [&"util2", &"mix_ur"], [&"mix_ur", &"def2"],
	[&"def2", &"mix_dr"], [&"mix_dr", &"res2"],
	[&"off1", &"gren1"], [&"gren1", &"gren2"], [&"gren2", &"gren3"], [&"gren3", &"gren_n"], [&"gren_n", &"proj1"],
	[&"off_n", &"proj1"], [&"proj1", &"proj_n"],
	[&"off_n", &"light1"], [&"light1", &"light2"], [&"light2", &"light_n"],
	[&"util_n", &"med1"], [&"med1", &"med2"], [&"med2", &"med_n"],
	[&"def_n", &"heavy1"], [&"heavy1", &"heavy2"], [&"heavy2", &"heavy_n"],
	[&"light1", &"med1"], [&"med1", &"heavy1"],
	[&"res1", &"fire1"], [&"fire1", &"fire2"], [&"fire2", &"fire_n"],
	[&"res3", &"acid1"], [&"acid1", &"acid2"], [&"acid2", &"acid_n"],
	[&"res_n", &"elec1"], [&"elec1", &"elec2"], [&"elec2", &"elec_n"],
	[&"light_n", &"dual_n"], [&"med_n", &"rifle_n"], [&"med_n", &"shot_n"],
]

## Как писать характеристики в подсказке.
const STAT_TEXT := {
	&"damage_pct": "+%d%% к урону", &"fire_rate_pct": "+%d%% к скорости стрельбы",
	&"reload_pct": "+%d%% к скорости перезарядки", &"move_speed": "+%d%% к скорости бега",
	&"max_hp": "+%d к максимуму Life", &"armor_flat": "+%d к Armour", &"armor_pct": "+%d%% к Armour",
	&"es_flat": "+%d к Energy Shield", &"es_pct": "+%d%% к Energy Shield", &"hp_regen": "+%d Life в секунду",
	&"es_recharge": "Energy Shield восстанавливается на %d%% быстрее",
	&"res_fire": "+%d%% к Fire Resistance", &"res_electric": "+%d%% к Lightning Resistance",
	&"res_acid": "+%d%% к Acid Resistance",
	&"grenade_recharge": "Гранаты восстанавливаются на %d%% быстрее", &"grenade_damage": "+%d%% к урону гранат",
	&"grenade_radius": "+%d%% к радиусу взрыва гранат", &"grenade_charges": "+%d граната в запасе",
	&"proj_speed": "+%d%% к скорости и дальности пуль", &"pierce": "Пули пробивают ещё %d врага",
	&"light_dmg": "+%d%% к урону лёгкого оружия", &"light_fire_rate": "+%d%% к скорострельности лёгкого оружия",
	&"medium_dmg": "+%d%% к урону среднего оружия", &"medium_reload": "+%d%% к перезарядке среднего оружия",
	&"heavy_dmg": "+%d%% к урону тяжёлого оружия", &"heavy_magazine": "+%d%% к магазину тяжёлого оружия",
	&"fire_dmg": "+%d%% урона огнём (от урона выстрела)", &"acid_dmg": "+%d%% урона кислотой (от урона выстрела)",
	&"electric_dmg": "+%d%% урона электричеством (от урона выстрела)",
	&"burn_pct": "Горение наносит на %d%% больше урона", &"corrode_pct": "Кислота разъедает броню на %d%% дольше",
	&"shock_pct": "Шокированные враги получают ещё +%d%% урона",
	&"dual_pistols": "Пистолет — в обеих руках: магазин ×2, темп +60%%, перезарядка на 50%% дольше",
	&"rifle_ricochet": "Автоматы: %d%% шанс, что пуля прошьёт врага и отрикошетит",
	&"shotgun_instant": "Дробовики: %d%% шанс мгновенной перезарядки",
}


static func node(id: StringName) -> Dictionary:
	for n in NODES:
		if n.id == id:
			return n
	return {}


static func neighbors(id: StringName) -> Array:
	var result := []
	for e in EDGES:
		if e[0] == id:
			result.append(e[1])
		elif e[1] == id:
			result.append(e[0])
	return result


static func describe(n: Dictionary) -> Array:
	var lines := []
	for stat in n.stats:
		var text: String = STAT_TEXT.get(stat, String(stat) + " %d")
		lines.append(text % n.stats[stat] if text.contains("%d") else text.replace("%%", "%"))
	return lines
