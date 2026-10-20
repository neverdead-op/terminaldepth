extends RefCounted
## Справочник экипировки: основы (базы) по слотам, свойства (префиксы и суффиксы) с тирами по уровню
## предмета, ксено-фрагменты для крафта и правила редкости. Всё — простые таблицы, их можно дополнять.
##
## Тиры: в списке tiers — от слабого к сильному, у каждого [мин. уровень предмета, от, до].
## Уровень предмета = номер этажа (1–30): Т4 появляется с 3-го этажа, Т3 — с 6-го, Т2 — с 11-го, Т1 — с 18-го.
## level у базы — с какого этажа она начинает выпадать (лучшие базы — глубже).
## В подсказке тир показывается как в PoE: Т5 — самый слабый, Т1 — самый сильный.

const SLOT_NAMES := {
	&"mines": "Минное оружие",
	&"helmet": "Шлем", &"body": "Бронежилет", &"gloves": "Перчатки", &"boots": "Ботинки",
	&"implant": "Имплант", &"combat": "Боевой модуль", &"sidearm": "Запасное оружие", &"weapon": "Оружие",
}

## Оружие — тоже предмет: слот sidearm (пистолет, всегда при себе) или weapon (два слота под основное).
## weapon — файл с цифрами базы (WeaponData), свойства предмета усиливают именно это оружие.
const WEAPON_SLOTS := [&"sidearm", &"weapon", &"mines"]
## Гнёзд под модули у нового оружия и сколько можно открыть Гнездовым резаком.
const START_SOCKETS := 2
const MAX_SOCKETS := 5
## Качество предмета (как в PoE 2): до +20%. Броня/щит базы и урон оружия растут на столько процентов.
const MAX_QUALITY := 20
## Гнёзда аугментов в броне (аналог рун PoE 2): сколько можно открыть Socket Cutter-ом.
const AUGMENT_SOCKETS := {&"helmet": 1, &"body": 2, &"gloves": 1, &"boots": 1}

## Аугменты: вставляются в гнёзда брони навсегда и дают свойство. Лежат в сумке стопками, как фрагменты.
const AUGMENTS := {
	&"aug_life": [&"max_hp", 15, "+15 к максимуму Life"],
	&"aug_es": [&"es_flat", 15, "+15 к Energy Shield"],
	&"aug_armour": [&"armor_flat", 25, "+25 к Armour"],
	&"aug_fire": [&"res_fire", 10, "+10% к Fire Resistance"],
	&"aug_lightning": [&"res_electric", 10, "+10% к Lightning Resistance"],
	&"aug_acid": [&"res_acid", 10, "+10% к Acid Resistance"],
}

## Базы: name, slot, armor, es (защита растёт с уровнем предмета), implicit — встроенное свойство,
## implicits — несколько встроенных свойств сразу (у улучшенных версий).
const BASES := [
	{"id": &"relay_boots", "name": "Ботинки Vortech «Оплот»", "slot": &"boots", "armor": 11, "es": 9, "implicits": [[&"move_speed", 5]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/relay_boots.png"},
	{"id": &"relay_gloves", "name": "Перчатки Vortech «Оплот»", "slot": &"gloves", "armor": 9, "es": 7, "implicits": [[&"reload", 10]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/relay_gloves.png"},
	{"id": &"patrol_helmet", "name": "Шлем Vortech «Заслон»", "slot": &"helmet", "armor": 14, "es": 0, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/patrol_helmet.png"},
	{"id": &"sensor_helmet", "name": "Шлем Vortech «Импульс»", "slot": &"helmet", "armor": 0, "es": 12, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/sensor_helmet.png"},
	{"id": &"assault_helmet", "name": "Шлем Vortech «Контур»", "slot": &"helmet", "armor": 8, "es": 7, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/assault_helmet.png"},
	{"id": &"vest", "name": "Броня Vortech «Заслон»", "slot": &"body", "armor": 40, "es": 0, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/vest.png"},
	{"id": &"hazmat", "name": "Броня Vortech «Импульс»", "slot": &"body", "armor": 0, "es": 30, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/hazmat.png"},
	{"id": &"spacesuit", "name": "Броня Vortech «Контур»", "slot": &"body", "armor": 22, "es": 18, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/spacesuit.png"},
	{"id": &"tactical_gloves", "name": "Перчатки Vortech «Заслон»", "slot": &"gloves", "armor": 8, "es": 0, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/tactical_gloves.png"},
	{"id": &"conductor_gloves", "name": "Перчатки Vortech «Импульс»", "slot": &"gloves", "armor": 0, "es": 7, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/conductor_gloves.png"},
	{"id": &"combat_mitts", "name": "Перчатки Vortech «Контур»", "slot": &"gloves", "armor": 5, "es": 4, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/combat_mitts.png"},
	{"id": &"army_boots", "name": "Ботинки Vortech «Заслон»", "slot": &"boots", "armor": 10, "es": 0, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/army_boots.png"},
	{"id": &"mag_boots", "name": "Ботинки Vortech «Импульс»", "slot": &"boots", "armor": 0, "es": 8, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/mag_boots.png"},
	{"id": &"scout_boots", "name": "Ботинки Vortech «Контур»", "slot": &"boots", "armor": 6, "es": 5, "level": 1, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/scout_boots.png"},
	{"id": &"neuro_implant", "name": "Нейроимплант", "slot": &"implant", "armor": 0, "es": 0,
		"implicit": [&"life", 8]},
	{"id": &"filter_implant", "name": "Имплант-фильтр", "slot": &"implant", "armor": 0, "es": 0,
		"implicit": [&"res_acid", 10]},
	{"id": &"reflex_implant", "name": "Имплант реакции", "slot": &"implant", "armor": 0, "es": 0,
		"implicit": [&"fire_rate", 4]},
	{"id": &"wasp_module", "name": "Боевой модуль «Оса»", "slot": &"combat", "armor": 0, "es": 0,
		"implicit": [&"damage", 6]},
	{"id": &"shield_module", "name": "Модуль «Щит»", "slot": &"combat", "armor": 0, "es": 12},
	{"id": &"regen_module", "name": "Модуль «Регенератор»", "slot": &"combat", "armor": 0, "es": 0,
		"implicit": [&"hp_regen", 1]},
	# Базы получше — выпадают глубже.
	{"id": &"bastion_helmet", "name": "Шлем Vortech «Бастион»", "slot": &"helmet", "armor": 26, "es": 0, "implicits": [[&"life", 15]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/bastion_helmet.png"},
	{"id": &"emitter_crown", "name": "Шлем Vortech «Спектр»", "slot": &"helmet", "armor": 0, "es": 22, "implicits": [[&"es_recharge", 20]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/emitter_crown.png"},
	{"id": &"command_helmet", "name": "Шлем Vortech «Оплот»", "slot": &"helmet", "armor": 15, "es": 13, "implicits": [[&"res_all", 5]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/command_helmet.png"},
	{"id": &"exoskeleton", "name": "Броня Vortech «Бастион»", "slot": &"body", "armor": 72, "es": 0, "implicits": [[&"life", 25], [&"hp_regen", 1]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/exoskeleton.png"},
	{"id": &"hive_suit", "name": "Броня Vortech «Спектр»", "slot": &"body", "armor": 0, "es": 54, "implicits": [[&"es_recharge", 25], [&"res_electric", 10]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/hive_suit.png"},
	{"id": &"drop_suit", "name": "Броня Vortech «Оплот»", "slot": &"body", "armor": 40, "es": 32, "implicits": [[&"res_all", 8], [&"life", 10]], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/drop_suit.png"},
	{"id": &"power_gloves", "name": "Перчатки Vortech «Бастион»", "slot": &"gloves", "armor": 15, "es": 0,
		"implicit": [&"damage", 5], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/power_gloves.png"},
	{"id": &"neuro_gloves", "name": "Перчатки Vortech «Спектр»", "slot": &"gloves", "armor": 0, "es": 13,
		"implicit": [&"fire_rate", 4], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/neuro_gloves.png"},
	{"id": &"servo_boots", "name": "Ботинки Vortech «Бастион»", "slot": &"boots", "armor": 18, "es": 0,
		"implicit": [&"move_speed", 5], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/servo_boots.png"},
	{"id": &"grav_boots", "name": "Ботинки Vortech «Спектр»", "slot": &"boots", "armor": 0, "es": 15,
		"implicit": [&"move_speed", 5], "level": 4, "act": 1, "corp": &"vortech", "icon": "res://assets/icons/act_one/grav_boots.png"},
	{"id": &"regulator_implant", "name": "Имплант-регулятор", "slot": &"implant", "armor": 0, "es": 0, "level": 2,
		"implicit": [&"es_recharge", 15]},
	{"id": &"hive_module", "name": "Модуль «Литания»", "slot": &"combat", "armor": 0, "es": 0, "level": 4,
		"implicit": [&"damage", 10]},
	{"id": &"pistol", "name": "Пистолет «Страж»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/pistol.tres"},
	{"id": &"revolver", "name": "Револьвер «Бык»", "slot": &"sidearm", "armor": 0, "es": 0, "level": 2,
		"weapon": "res://data/weapons/revolver.tres"},
	{"id": &"rifle", "name": "Коломёт «Кербер»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/rifle.tres", "level": 1, "act": 1, "corp": &"helix", "icon": "res://assets/icons/act_one/rifle.png"},
	# Улучшенные коломёт и дробовик: та же модель, что у обычных, но со своими встроенными свойствами.
	{"id": &"rifle_mk2", "name": "Коломёт «Кербер» II", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/rifle.tres", "implicits": [[&"w_range", 30], [&"w_pierce", 1]], "level": 4, "act": 1,
		"corp": &"helix", "icon": "res://assets/icons/act_one/rifle.png"},
	{"id": &"shotgun_mk2", "name": "Дробовик «Молот» II", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/shotgun.tres", "implicits": [[&"w_extra", 2], [&"w_accuracy", 20]], "level": 4, "act": 1,
		"corp": &"helix", "icon": "res://assets/icons/act_one/shotgun.png"},
	{"id": &"machinegun", "name": "Пулемёт «Шквал»", "slot": &"weapon", "armor": 0, "es": 0, "level": 3,
		"weapon": "res://data/weapons/machinegun.tres"},
	{"id": &"shotgun", "name": "Дробовик «Молот»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/shotgun.tres", "level": 1, "act": 1, "corp": &"helix", "icon": "res://assets/icons/act_one/shotgun.png"},
	{"id": &"sniper", "name": "Винтовка «Игла»", "slot": &"weapon", "armor": 0, "es": 0, "level": 2,
		"weapon": "res://data/weapons/sniper.tres", "implicit": [&"w_pierce", 1]},
	# Ultimate Gun Pack и лук.
	{"id": &"heavy_pistol", "name": "Тяжёлый пистолет «Довод»", "slot": &"sidearm", "armor": 0, "es": 0, "level": 1,
		"weapon": "res://data/weapons/heavy_pistol.tres"},
	{"id": &"machine_pistol", "name": "Пистолет-пулемёт «Шершень»", "slot": &"sidearm", "armor": 0, "es": 0, "level": 2,
		"weapon": "res://data/weapons/machine_pistol.tres"},
	{"id": &"magnum", "name": "Магнум «Кувалда»", "slot": &"sidearm", "armor": 0, "es": 0, "level": 3,
		"weapon": "res://data/weapons/magnum.tres"},
	{"id": &"smg", "name": "Пистолет-пулемёт «Оса»", "slot": &"weapon", "armor": 0, "es": 0, "level": 1,
		"weapon": "res://data/weapons/smg.tres"},
	{"id": &"carbine", "name": "Карабин «Патруль»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/carbine.tres", "level": 4, "act": 1, "corp": &"helix", "icon": "res://assets/icons/act_one/carbine.png"},
	{"id": &"battle_rifle", "name": "Боевая винтовка «Таран»", "slot": &"weapon", "armor": 0, "es": 0, "level": 2,
		"weapon": "res://data/weapons/battle_rifle.tres"},
	{"id": &"pump_shotgun", "name": "Помповый дробовик «Бульдог»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/pump_shotgun.tres", "level": 4, "act": 1, "corp": &"helix", "icon": "res://assets/icons/act_one/pump_shotgun.png"},
	{"id": &"sawed_off", "name": "Обрез «Вплотную»", "slot": &"weapon", "armor": 0, "es": 0, "level": 1,
		"weapon": "res://data/weapons/sawed_off.tres"},
	{"id": &"marksman", "name": "Марксманская винтовка «Сокол»", "slot": &"weapon", "armor": 0, "es": 0, "level": 3,
		"weapon": "res://data/weapons/marksman.tres"},
	{"id": &"heavy_sniper", "name": "Крупнокалиберная винтовка «Рельс»", "slot": &"weapon", "armor": 0, "es": 0,
		"level": 4, "weapon": "res://data/weapons/heavy_sniper.tres"},
	{"id": &"bow", "name": "Энергетический лук «Жнец»", "slot": &"weapon", "armor": 0, "es": 0, "level": 2,
		"weapon": "res://data/weapons/bow.tres"},
	{"id": &"grenade_launcher", "name": "Гранатомёт «Гром»", "slot": &"weapon", "armor": 0, "es": 0, "level": 3,
		"weapon": "res://data/weapons/grenade_launcher.tres"},
	{"id": &"flamethrower", "name": "Огнемёт «Санитар»", "slot": &"weapon", "armor": 0, "es": 0, "level": 2,
		"weapon": "res://data/weapons/flamethrower.tres"},
	{"id": &"plasma_cutter", "name": "Плазменный резак «Шов»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/plasma_cutter.tres", "level": 1, "act": 1, "corp": &"helix", "icon": "res://assets/icons/act_one/plasma_cutter.png"},
	{"id": &"plasma_cutter_mk2", "name": "Плазменный резак «Разлом»", "slot": &"weapon", "armor": 0, "es": 0,
		"weapon": "res://data/weapons/plasma_cutter_mk2.tres", "level": 4, "act": 1, "corp": &"helix", "icon": "res://assets/icons/act_one/plasma_cutter_mk2.png"},
]

## Уникальные (оранжевые) предметы: своя база, своё имя, фиксированные свойства [stat, число, текст] и цитата.
## Крафтом не меняются (кроме Гнездового резака у оружия). level — с какого этажа могут выпасть.
const UNIQUES := [
	{"id": &"last_word", "name": "Последний довод", "base": &"revolver", "level": 1,
		"flavour": "Шесть патронов. Шесть ответов.",
		"mods": [[&"w_damage", 60, "+60% к урону этого оружия"], [&"w_chain", 2, "Пули рикошетят ещё 2 раза"],
			[&"w_magazine", -34, "−34% к размеру магазина"]]},
	{"id": &"swarm", "name": "Рой", "base": &"machinegun", "level": 3,
		"flavour": "Их было слишком много. Теперь много — нас.",
		"mods": [[&"w_extra", 1, "+1 пуля за выстрел"], [&"w_acid", 45, "+45% урона кислотой"],
			[&"w_damage", -25, "−25% к урону этого оружия"]]},
	{"id": &"queen_needle", "name": "Игла Серафима", "base": &"sniper", "level": 2,
		"flavour": "Одна игла — одна жизнь. Иногда несколько.",
		"mods": [[&"w_damage", 70, "+70% к урону этого оружия"], [&"w_pierce", 3, "Пули пробивают ещё 3 врагов"],
			[&"w_electric", 30, "+30% урона электричеством"]]},
	{"id": &"hive_eye", "name": "Око Пророка", "base": &"sensor_helmet", "level": 1,
		"flavour": "Он видит всё. И всё видит его.",
		"mods": [[&"es_flat", 40, "+40 к Energy Shield"], [&"es_recharge", 80, "Energy Shield восстанавливается на 80% быстрее"],
			[&"max_hp", -20, "−20 к максимуму Life"]]},
	{"id": &"bearer_skin", "name": "Кожа Носителя", "base": &"vest", "level": 1,
		"flavour": "Внутри было тесно. Снаружи — прочно.",
		"mods": [[&"armor_flat", 120, "+120 к Armour"], [&"hp_regen", 4, "+4 Life в секунду"],
			[&"move_speed", -8, "−8% к скорости бега"]]},
	{"id": &"runner", "name": "Скороход", "base": &"scout_boots", "level": 1,
		"flavour": "Лучшая защита — быть в другом месте.",
		"mods": [[&"move_speed", 30, "+30% к скорости бега"], [&"res_acid", 25, "+25% к Acid Resistance"]]},
	{"id": &"blood_pact", "name": "Кровавый договор", "base": &"neuro_implant", "level": 2,
		"flavour": "Плата вперёд. Сдача — кровью врагов.",
		"mods": [[&"leech_pct", 3, "3% урона восстанавливает Life"], [&"damage_pct", 15, "+15% к урону"],
			[&"max_hp", -15, "−15 к максимуму Life"]]},
	{"id": &"sparker", "name": "Искровик", "base": &"conductor_gloves", "level": 1,
		"flavour": "Не трогай. Серьёзно, не трогай.",
		"mods": [[&"electric_dmg", 40, "+40% урона электричеством ко всему оружию"],
			[&"fire_rate_pct", 10, "+10% к скорости стрельбы"]]},
]

## Сколько клеток сумки занимает предмет (ширина × высота), как в PoE 2.
const SLOT_SIZES := {
	&"mines": Vector2i(2, 2),
	&"helmet": Vector2i(2, 2), &"body": Vector2i(2, 3), &"gloves": Vector2i(2, 2), &"boots": Vector2i(2, 2),
	&"implant": Vector2i(1, 1), &"combat": Vector2i(1, 1), &"sidearm": Vector2i(2, 2), &"weapon": Vector2i(3, 2),
}
## Сколько фрагментов одного вида помещается в одну клетку.
const STACK_SIZE := 20

const DEFENSE_SLOTS := [&"helmet", &"body", &"gloves", &"boots"]
const ALL_SLOTS := [&"helmet", &"body", &"gloves", &"boots", &"implant", &"combat"]

## Свойства. stat — какая характеристика игрока растёт; text — как писать в подсказке (%d — число).
const AFFIXES := {
	&"life": {"type": "prefix", "stat": &"max_hp", "text": "+%d к максимуму Life", "slots": ALL_SLOTS,
		"tiers": [[1, 10, 19], [3, 20, 34], [6, 35, 49], [11, 50, 69], [18, 70, 89]]},
	&"armor": {"type": "prefix", "stat": &"armor_flat", "text": "+%d к Armour", "slots": DEFENSE_SLOTS,
		"tiers": [[1, 8, 15], [3, 16, 30], [6, 31, 50], [11, 51, 75], [18, 76, 110]]},
	&"es": {"type": "prefix", "stat": &"es_flat", "text": "+%d к Energy Shield", "slots": DEFENSE_SLOTS,
		"tiers": [[1, 6, 12], [3, 13, 24], [6, 25, 38], [11, 39, 55], [18, 56, 80]]},
	&"armor_pct": {"type": "prefix", "stat": &"armor_pct", "text": "+%d%% к Armour этой вещи", "slots": DEFENSE_SLOTS,
		"tiers": [[1, 10, 19], [3, 20, 34], [6, 35, 49], [11, 50, 69], [18, 70, 89]]},
	&"es_pct": {"type": "prefix", "stat": &"es_pct", "text": "+%d%% к Energy Shield этой вещи", "slots": DEFENSE_SLOTS,
		"tiers": [[1, 10, 19], [3, 20, 34], [6, 35, 49], [11, 50, 69], [18, 70, 89]]},
	&"damage": {"type": "prefix", "stat": &"damage_pct", "text": "+%d%% к урону",
		"slots": [&"gloves", &"implant", &"combat"],
		"tiers": [[1, 5, 9], [3, 10, 15], [6, 16, 22], [11, 23, 30], [18, 31, 40]]},
	&"res_fire": {"type": "suffix", "stat": &"res_fire", "text": "+%d%% к Fire Resistance", "slots": ALL_SLOTS,
		"tiers": [[1, 6, 11], [3, 12, 17], [6, 18, 23], [11, 24, 29], [18, 30, 35]]},
	&"res_electric": {"type": "suffix", "stat": &"res_electric", "text": "+%d%% к Lightning Resistance",
		"slots": ALL_SLOTS, "tiers": [[1, 6, 11], [3, 12, 17], [6, 18, 23], [11, 24, 29], [18, 30, 35]]},
	&"res_acid": {"type": "suffix", "stat": &"res_acid", "text": "+%d%% к Acid Resistance", "slots": ALL_SLOTS,
		"tiers": [[1, 6, 11], [3, 12, 17], [6, 18, 23], [11, 24, 29], [18, 30, 35]]},
	&"move_speed": {"type": "suffix", "stat": &"move_speed", "text": "+%d%% к скорости бега", "slots": [&"boots"],
		"tiers": [[1, 5, 9], [3, 10, 14], [6, 15, 19], [11, 20, 24], [18, 25, 30]]},
	&"hp_regen": {"type": "suffix", "stat": &"hp_regen", "text": "+%d Life в секунду",
		"slots": [&"helmet", &"body", &"implant", &"combat"],
		"tiers": [[1, 1, 2], [3, 2, 3], [6, 3, 5], [11, 5, 7], [18, 7, 10]]},
	&"es_recharge": {"type": "suffix", "stat": &"es_recharge", "text": "Energy Shield восстанавливается на %d%% быстрее",
		"slots": [&"helmet", &"body", &"implant", &"combat"],
		"tiers": [[1, 10, 19], [3, 20, 29], [6, 30, 39], [11, 40, 49], [18, 50, 60]]},
	&"fire_rate": {"type": "suffix", "stat": &"fire_rate_pct", "text": "+%d%% к скорости стрельбы",
		"slots": [&"gloves", &"implant", &"combat"],
		"tiers": [[1, 4, 7], [3, 8, 11], [6, 12, 15], [11, 16, 19], [18, 20, 24]]},
	&"reload": {"type": "suffix", "stat": &"reload_pct", "text": "+%d%% к скорости перезарядки",
		"slots": [&"gloves", &"implant"],
		"tiers": [[1, 8, 14], [3, 15, 21], [6, 22, 28], [11, 29, 35], [18, 36, 45]]},
	# --- Оружие: свойства усиливают только само оружие ---
	&"w_damage": {"type": "prefix", "stat": &"w_damage", "text": "+%d%% к урону этого оружия", "slots": WEAPON_SLOTS,
		"tiers": [[1, 15, 24], [3, 25, 39], [6, 40, 59], [11, 60, 84], [18, 85, 110]]},
	&"w_fire": {"type": "prefix", "stat": &"w_fire", "text": "Добавляет %d урона огнём к выстрелу (поджигает)", "slots": WEAPON_SLOTS,
		"tiers": [[1, 2, 4], [3, 5, 8], [6, 9, 13], [11, 14, 20], [18, 21, 30]]},
	&"w_electric": {"type": "prefix", "stat": &"w_electric", "text": "Добавляет %d урона электричеством к выстрелу (шок)",
		"slots": WEAPON_SLOTS, "tiers": [[1, 2, 4], [3, 5, 8], [6, 9, 13], [11, 14, 20], [18, 21, 30]]},
	&"w_acid": {"type": "prefix", "stat": &"w_acid", "text": "Добавляет %d урона кислотой к выстрелу (снимает Armour)",
		"slots": WEAPON_SLOTS, "tiers": [[1, 2, 4], [3, 5, 8], [6, 9, 13], [11, 14, 20], [18, 21, 30]]},
	&"w_magazine": {"type": "prefix", "stat": &"w_magazine", "text": "+%d%% к размеру магазина", "slots": WEAPON_SLOTS,
		"tiers": [[1, 15, 24], [3, 25, 34], [6, 35, 49], [11, 50, 64], [18, 65, 80]]},
	&"w_fire_rate": {"type": "suffix", "stat": &"w_fire_rate", "text": "+%d%% к скорострельности",
		"slots": WEAPON_SLOTS, "tiers": [[1, 6, 10], [3, 11, 15], [6, 16, 20], [11, 21, 26], [18, 27, 32]]},
	&"w_reload": {"type": "suffix", "stat": &"w_reload", "text": "+%d%% к скорости перезарядки этого оружия",
		"slots": WEAPON_SLOTS, "tiers": [[1, 10, 17], [3, 18, 25], [6, 26, 33], [11, 34, 42], [18, 43, 55]]},
	&"w_leech": {"type": "suffix", "stat": &"w_leech", "text": "%d%% урона восстанавливает Life", "slots": WEAPON_SLOTS,
		"tiers": [[1, 1, 1], [3, 2, 2], [6, 3, 3], [11, 4, 4], [18, 5, 6]]},
	&"w_accuracy": {"type": "suffix", "stat": &"w_accuracy", "text": "−%d%% к разбросу пуль", "slots": WEAPON_SLOTS,
		"tiers": [[1, 10, 19], [3, 20, 29], [6, 30, 39], [11, 40, 49], [18, 50, 60]]},
	&"w_range": {"type": "suffix", "stat": &"w_range", "text": "+%d%% к дальности и скорости пуль",
		"slots": WEAPON_SLOTS, "tiers": [[1, 10, 19], [3, 20, 29], [6, 30, 39], [11, 40, 49], [18, 50, 60]]},
	# --- Новые свойства экипировки ---
	&"res_all": {"type": "suffix", "stat": &"res_all", "text": "+%d%% ко всем Resistances",
		"slots": [&"helmet", &"body", &"implant"], "tiers": [[1, 3, 5], [3, 6, 8], [6, 9, 11], [11, 12, 14], [18, 15, 18]]},
	&"leech": {"type": "suffix", "stat": &"leech_pct", "text": "%d%% урона восстанавливает Life",
		"slots": [&"gloves", &"implant"], "tiers": [[1, 1, 1], [6, 2, 2], [18, 3, 3]]},
	&"fire_dmg": {"type": "prefix", "stat": &"fire_dmg", "text": "+%d%% урона огнём ко всему оружию",
		"slots": [&"gloves", &"implant", &"combat"], "tiers": [[1, 5, 9], [3, 10, 14], [6, 15, 20], [11, 21, 27], [18, 28, 35]]},
	&"electric_dmg": {"type": "prefix", "stat": &"electric_dmg", "text": "+%d%% урона электричеством ко всему оружию",
		"slots": [&"gloves", &"implant", &"combat"], "tiers": [[1, 5, 9], [3, 10, 14], [6, 15, 20], [11, 21, 27], [18, 28, 35]]},
	&"acid_dmg": {"type": "prefix", "stat": &"acid_dmg", "text": "+%d%% урона кислотой ко всему оружию",
		"slots": [&"gloves", &"implant", &"combat"], "tiers": [[1, 5, 9], [3, 10, 14], [6, 15, 20], [11, 21, 27], [18, 28, 35]]},
	&"flask": {"type": "suffix", "stat": &"flask_pct", "text": "+%d%% к лечению аптечкой",
		"slots": [&"body", &"implant", &"combat"], "tiers": [[1, 10, 19], [3, 20, 29], [6, 30, 39], [11, 40, 49], [18, 50, 60]]},
	# Встроенное и уникальное (не выпадают случайно): пробивание, рикошеты, доп. пули.
	&"w_pierce": {"type": "implicit", "stat": &"w_pierce", "text": "Пули пробивают врагов: %d", "slots": [],
		"tiers": [[1, 1, 1]]},
	&"w_chain": {"type": "implicit", "stat": &"w_chain", "text": "Пули рикошетят: %d", "slots": [], "tiers": [[1, 1, 1]]},
	&"w_extra": {"type": "implicit", "stat": &"w_extra", "text": "+%d пуль за выстрел", "slots": [], "tiers": [[1, 1, 1]]},
}


## Какие свойства бессмысленны без защиты нужного вида на базе (не выпадают на такой вещи).
const NEEDS_ARMOR := [&"armor", &"armor_pct"]
const NEEDS_ES := [&"es", &"es_pct"]


## Как писать характеристику (для сравнения вещей): текст из свойства с этим stat.
static func stat_text(stat: StringName) -> String:
	for id in AFFIXES:
		if AFFIXES[id].stat == stat:
			return AFFIXES[id].text
	return String(stat) + ": %d"

## Ксено-фрагменты (валюта крафта, как сферы PoE 2) и чистый модуль. Лежат в сумке стопками.
## Свойств у синего — до 2 (1 префикс + 1 суффикс), у жёлтого — до 6 (3 + 3).
const CURRENCY := {
	&"mutagen": {"name": "Mutagen Vial", "color": Color(0.35, 0.65, 1.0),
		"text": "Белый предмет → синий (Magic) с одним случайным свойством."},
	&"unstable": {"name": "Unstable Mutagen", "color": Color(0.35, 0.75, 1.0),
		"text": "Синему предмету с одним свойством добавляет второе."},
	&"hive_core": {"name": "Reliquary Core", "color": Color(0.6, 0.76, 1.0),
		"text": "Синий предмет → жёлтый, добавляет ещё одно свойство."},
	&"queen_heart": {"name": "Seraph's Heart", "color": Color(1.0, 0.78, 0.25),
		"text": "Жёлтому предмету добавляет ещё одно свойство (всего до 6)."},
	&"catalyst": {"name": "Chaos Catalyst", "color": Color(1.0, 0.35, 0.6),
		"text": "Жёлтый предмет: все свойства заменяются случайными (число свойств сохраняется)."},
	&"blank_module": {"name": "Blank Module", "color": Color(0.85, 0.88, 0.95),
		"text": "Превращается в любой модуль оружия на выбор."},
	&"socket_cutter": {"name": "Socket Cutter", "color": Color(0.95, 0.75, 0.45),
		"text": "Оружию — ещё гнездо для модуля (до 5). Броне — гнездо для аугмента (бронежилет до 2, остальное 1)."},
	&"cocoon": {"name": "Alchemist's Chalice", "color": Color(1.0, 0.6, 0.25),
		"text": "Белый предмет → сразу жёлтый с 4 случайными свойствами (как Сфера алхимии)."},
	&"solvent": {"name": "Annulment Solvent", "color": Color(0.6, 0.95, 0.9),
		"text": "Убирает одно случайное свойство с синего или жёлтого предмета."},
	&"stabilizer": {"name": "Divine Stabilizer", "color": Color(1.0, 0.95, 0.7),
		"text": "Перебрасывает числа всех свойств в пределах их тиров."},
	&"plating_kit": {"name": "Plating Kit", "color": Color(0.8, 0.82, 0.88),
		"text": "Броня: +качество (белой +5%, синей +2%, жёлтой и уникальной +1%), до +20%."},
	&"calibration_kit": {"name": "Calibration Kit", "color": Color(0.95, 0.8, 0.55),
		"text": "Оружие: +качество (белому +5%, синему +2%, жёлтому и уникальному +1%), до +20%."},
	&"aug_life": {"name": "Vital Augment", "color": Color(1.0, 0.35, 0.35),
		"text": "Вставляется в гнездо аугмента брони: +15 к максимуму Life."},
	&"aug_es": {"name": "Shield Augment", "color": Color(0.4, 0.75, 1.0),
		"text": "Вставляется в гнездо аугмента брони: +15 к Energy Shield."},
	&"aug_armour": {"name": "Plate Augment", "color": Color(0.85, 0.8, 0.7),
		"text": "Вставляется в гнездо аугмента брони: +25 к Armour."},
	&"aug_fire": {"name": "Thermal Augment", "color": Color(1.0, 0.55, 0.15),
		"text": "Вставляется в гнездо аугмента брони: +10% к Fire Resistance."},
	&"aug_lightning": {"name": "Grounding Augment", "color": Color(0.5, 0.75, 1.0),
		"text": "Вставляется в гнездо аугмента брони: +10% к Lightning Resistance."},
	&"aug_acid": {"name": "Neutralizer Augment", "color": Color(0.55, 1.0, 0.25),
		"text": "Вставляется в гнездо аугмента брони: +10% к Acid Resistance."},
}
const CURRENCY_ORDER := [&"blank_module", &"mutagen", &"unstable", &"hive_core", &"queen_heart", &"catalyst",
		&"cocoon", &"socket_cutter", &"solvent", &"stabilizer", &"plating_kit", &"calibration_kit",
		&"aug_life", &"aug_es", &"aug_armour", &"aug_fire", &"aug_lightning", &"aug_acid"]
## Вес выпадения фрагментов (чистые модули выпадают отдельно). Сердце Королевы — редкое.
const CURRENCY_WEIGHTS := {&"mutagen": 400, &"unstable": 300, &"hive_core": 60, &"catalyst": 30, &"queen_heart": 5,
		&"socket_cutter": 15, &"solvent": 30, &"stabilizer": 12, &"cocoon": 20, &"plating_kit": 120, &"calibration_kit": 100,
		&"aug_life": 10, &"aug_es": 10, &"aug_armour": 10, &"aug_fire": 10, &"aug_lightning": 10, &"aug_acid": 10}
## С какого этажа фрагмент начинает падать (на первом — только простые: учим по одной-две механике).
const CURRENCY_MIN_LEVEL := {&"mutagen": 1, &"unstable": 1, &"plating_kit": 1, &"calibration_kit": 1, &"hive_core": 2,
		&"solvent": 2, &"aug_life": 2, &"aug_es": 2, &"aug_armour": 2, &"aug_fire": 3, &"aug_lightning": 3, &"aug_acid": 3,
		&"catalyst": 3, &"cocoon": 3, &"socket_cutter": 3, &"stabilizer": 4, &"queen_heart": 4}

const RARITY_NAMES := ["Normal", "Magic", "Rare", "Unique"]
# --- Корпорации-производители (как в Borderlands): у оружия встроенные свойства фирмы, у брони — вид ---
## mods: [stat, число, текст]. Отрицательные числа — минусы фирмы.
const CORPS := {
	&"vortech": {"name": "Vortech", "tag": "Броня и системы", "color": Color(0.95, 0.72, 0.22),
		"mods": [[&"w_magazine", 30, "+30% к размеру магазина"], [&"w_damage", 12, "+12% к урону этого оружия"],
			[&"w_fire_rate", -10, "−10% к скорострельности"]]},
	&"helix": {"name": "Helix", "tag": "Оружие", "color": Color(1.0, 0.5, 0.15),
		"mods": [[&"w_fire_rate", 18, "+18% к скорострельности"], [&"w_accuracy", -20, "+20% к разбросу пуль"]]},
	&"kraken": {"name": "Kraken", "tag": "Биотех", "color": Color(0.95, 0.27, 0.3),
		"mods": [[&"w_acid", 4, "Добавляет 4 урона кислотой к выстрелу (снимает Armour)"], [&"w_leech", 2, "2% урона восстанавливает Life"]]},
	&"orion": {"name": "Orion", "tag": "Индастриз", "color": Color(0.45, 0.75, 1.0),
		"mods": [[&"w_pierce", 1, "Пули пробивают врагов: 1"], [&"w_range", 25, "+25% к дальности и скорости пуль"],
			[&"w_accuracy", 15, "−15% к разбросу пуль"]]},
	&"syntek": {"name": "Syntek", "tag": "Аугментика", "color": Color(0.72, 0.42, 1.0),
		"mods": [[&"w_electric", 4, "Добавляет 4 урона электричеством к выстрелу (шок)"], [&"w_reload", 20, "+20% к скорости перезарядки этого оружия"]]},
}
const CORP_ORDER := [&"vortech", &"helix", &"kraken", &"orion", &"syntek"]
## Броня: какие фирмы делают броню каждого типа защиты (вид значка).
const CORP_BY_DEFENSE := {&"armor": [&"vortech", &"helix"], &"es": [&"syntek", &"kraken"], &"hybrid": [&"orion"],
		&"": [&"orion"]}
## Файл оружия → колонка на листе значков (assets/icons/corp_weapons/<фирма>_<вид>.png).
const WEAPON_ICON_KIND := {&"pistol": &"pistol", &"revolver": &"pistol", &"heavy_pistol": &"pistol", &"magnum": &"pistol",
		&"machine_pistol": &"smg", &"smg": &"smg", &"rifle": &"smg", &"carbine": &"smg", &"battle_rifle": &"rifle",
		&"marksman": &"rifle", &"sniper": &"sniper", &"heavy_sniper": &"sniper", &"machinegun": &"heavy",
		&"grenade_launcher": &"heavy", &"flamethrower": &"heavy", &"shotgun": &"shotgun", &"pump_shotgun": &"shotgun",
		&"sawed_off": &"shotgun", &"plasma_cutter": &"plasma", &"plasma_cutter_mk2": &"plasma"}
## Класс оружия для веток дерева пассивок: лёгкое (пистолеты, ПП), среднее (автоматы, винтовки, дробовики),
## тяжёлое (пулемёт, гранатомёт, огнемёт, снайперские).
const WEAPON_CLASS := {&"pistol": &"light", &"revolver": &"light", &"heavy_pistol": &"light", &"magnum": &"light",
		&"machine_pistol": &"light", &"smg": &"light", &"rifle": &"medium", &"carbine": &"medium",
		&"battle_rifle": &"medium", &"marksman": &"medium", &"shotgun": &"medium", &"pump_shotgun": &"medium",
		&"sawed_off": &"medium", &"bow": &"medium", &"machinegun": &"heavy", &"grenade_launcher": &"heavy",
		&"flamethrower": &"heavy", &"sniper": &"heavy", &"heavy_sniper": &"heavy", &"plasma_cutter": &"light", &"plasma_cutter_mk2": &"light"}
## Импланты и боевые модули → шестиугольный значок (assets/icons/gear/hex_<имя>.png).
const HEX_ICONS := {&"neuro_implant": &"damage", &"filter_implant": &"resist", &"reflex_implant": &"speed",
		&"regulator_implant": &"regen", &"wasp_module": &"crit", &"shield_module": &"es", &"regen_module": &"life",
		&"hive_module": &"stamina"}

const RARITY_COLORS := [Color(0.88, 0.88, 0.88), Color(0.45, 0.6, 1.0), Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.15)]

const RARE_ADJECTIVES := ["Гибельный", "Стальной", "Кислотный", "Тихий", "Чёрный", "Звёздный", "Ржавый",
		"Святой", "Холодный", "Багровый", "Лунный", "Мёртвый", "Глухой", "Пепельный"]
const RARE_NOUNS := {
	&"mines": ["Капкан", "Заряд", "Приговор"],
	&"helmet": ["Венец", "Колпак", "Череп"], &"body": ["Панцирь", "Саван", "Доспех"],
	&"gloves": ["Хват", "Кулак", "Захват"], &"boots": ["Шаг", "Ход", "Топот"],
	&"implant": ["Разъём", "Чип", "Узел"], &"combat": ["Контур", "Сигнал", "Модуль"],
	&"sidearm": ["Довод", "Ствол", "Жало"], &"weapon": ["Гром", "Шторм", "Ливень", "Приговор"],
}


# --- Экономика: цены у торговца и разбор на верстаке -------------------------------------

## Цена за одну штуку фрагмента у торговца.
const CURRENCY_PRICES := {&"blank_module": 180, &"mutagen": 45, &"unstable": 75, &"hive_core": 270,
		&"queen_heart": 1050, &"catalyst": 360, &"socket_cutter": 450, &"solvent": 240, &"stabilizer": 420, &"cocoon": 300, &"plating_kit": 90,
		&"calibration_kit": 90, &"aug_life": 210, &"aug_es": 210, &"aug_armour": 210, &"aug_fire": 210, &"aug_lightning": 210,
		&"aug_acid": 210}
const MODULE_PRICE := 220


## Сколько золота стоит купить предмет. item — GearItem, ModuleData или стопка фрагментов.
static func buy_price(item) -> int:
	if item is GearItem:
		var extra: int = (item.sockets - START_SOCKETS) * 60 + 15 if item.is_weapon() else 0
		return [30, 120, 450, 1500][item.rarity] + item.affixes.size() * 25 + (item.item_level - 1) * 10 + extra * 3
	if item is ModuleData:
		return MODULE_PRICE
	return CURRENCY_PRICES.get(item.id, 10) * item.count


## Продажа — четверть цены покупки (как у торговцев в PoE 2: продать дёшево, купить дорого).
static func sell_price(item) -> int:
	return maxi(1, buy_price(item) / 12)


## Разбор на верстаке даёт осколки: 10 осколков = целый фрагмент. Какой — по цвету вещи:
## белая → Mutagen Vial, синяя → Reliquary Core, жёлтая → Chaos Catalyst, уникальная — 5 осколков Seraph's Heart.
const SHARDS_PER_FRAGMENT := 10
const SHARD_BY_RARITY := [&"mutagen", &"hive_core", &"catalyst", &"queen_heart"]


## Сколько и каких осколков даст вещь: [id, число] или [] — нельзя разобрать. Модуль — сразу целый Blank Module.
static func salvage_shards(item) -> Array:
	if item is ModuleData:
		return [&"blank_module", SHARDS_PER_FRAGMENT]
	if item is GearItem:
		return [SHARD_BY_RARITY[item.rarity], 5 if item.rarity == 3 else 1]
	return []


## (Старое) Что давал разбор целиком: [{id, count, chance}].
static func salvage_table(item) -> Array:
	if item is ModuleData:
		return [{"id": &"blank_module", "count": 1, "chance": 1.0}]
	if not item is GearItem:
		return []
	match item.rarity:
		3:
			return [{"id": &"hive_core", "count": 2, "chance": 1.0}, {"id": &"queen_heart", "count": 1, "chance": 0.35},
					{"id": &"stabilizer", "count": 1, "chance": 0.5}]
		0:
			return [{"id": &"mutagen", "count": 1, "chance": 0.7}]
		1:
			return [{"id": &"mutagen", "count": 1, "chance": 1.0}, {"id": &"unstable", "count": 1, "chance": 0.6}]
	var table := [{"id": &"unstable", "count": 2, "chance": 1.0}, {"id": &"hive_core", "count": 1, "chance": 0.4},
			{"id": &"catalyst", "count": 1, "chance": 0.2}, {"id": &"queen_heart", "count": 1, "chance": 0.03}]
	if item.is_weapon():
		table.append({"id": &"socket_cutter", "count": 1, "chance": 0.35})
	return table


static func base_by_id(id: StringName) -> Dictionary:
	for b in BASES:
		if b.id == id:
			return b
	if id == MINE_BASE.id:
		return MINE_BASE
	return {}


## Старый минный ранец оставлен только для чтения прежних сохранений.
## Мины ставятся кнопкой (B / LT), гнёзда как у оружия: первое — стихия, остальные — обычные модули.
const MINE_BASE := {"id": &"mine_pack", "name": "Минный ранец «Капкан»", "slot": &"mines", "armor": 0, "es": 0,
	"weapon": "res://data/weapons/mine.tres"}
const MINE_SOCKETS := 3


## Случайная база (слот — любой, если не задан), только те, что уже выпадают на этом уровне.
const ACT_ONE_WEAPONS := [&"rifle", &"shotgun", &"rifle_mk2", &"shotgun_mk2"]

## Ограничиваем получение, сохраняя все поздние базы и старые сохранения.
static func available_in_act_one(base: Dictionary) -> bool:
	return not base.has("weapon") or base.id in ACT_ONE_WEAPONS

## С этого уровня выпадают все базы снаряжения сразу, без ожидания их собственного уровня.
const ALL_GEAR_FROM_LEVEL := 2

static func available_bases(level: int) -> Array:
	return BASES.filter(func(b): return available_in_act_one(b) and (level >= ALL_GEAR_FROM_LEVEL or b.get("level", 1) <= level))

static func random_base(slot := &"", level := 99) -> Dictionary:
	return available_bases(level).filter(func(b): return slot == &"" or b.slot == slot).pick_random()


## Случайный уникальный предмет, доступный на этом уровне.
static func random_unique(level: int) -> Dictionary:
	var pool := UNIQUES.filter(func(u): return u.level <= level and available_in_act_one(base_by_id(u.base)))
	return pool.pick_random() if not pool.is_empty() else {}


## Редкость при выпадении: 0 — белый, 1 — синий, 2 — жёлтый. bonus сдвигает шансы к редким (боссы).
## Редкость вещи: растёт с этажом (level) и бонусом (сундуки, жёлтые враги).
static func roll_rarity(bonus := 0.0, level := 1) -> int:
	var r := randf()
	if r < 0.02 + 0.015 * (level - 1) + bonus * 0.3:
		return 2
	if r < 0.18 + 0.04 * (level - 1) + bonus * 0.7:
		return 1
	return 0


static func random_currency(level := 99) -> StringName:
	var total := 0
	for k in CURRENCY_WEIGHTS:
		if CURRENCY_MIN_LEVEL.get(k, 1) <= level:
			total += CURRENCY_WEIGHTS[k]
	var pick := randi() % total
	for k in CURRENCY_WEIGHTS:
		if CURRENCY_MIN_LEVEL.get(k, 1) > level:
			continue
		pick -= CURRENCY_WEIGHTS[k]
		if pick < 0:
			return k
	return &"mutagen"
