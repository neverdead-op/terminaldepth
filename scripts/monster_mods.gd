extends RefCounted
## Свойства синих и жёлтых врагов — как модификаторы монстров в PoE 2.
## Синий враг получает одно свойство (оно же в имени: «Стремительный Ползун»),
## жёлтый — 2–3 свойства и собственное имя («Гнилоклык»).
## icon — какой значок рисовать в полоске цели сверху экрана (hud_target_bar.gd).

const RARITY_COLORS := [Color(0.92, 0.92, 0.9), Color(0.45, 0.55, 1.0), Color(1.0, 0.9, 0.35)]

const MODS := {
	&"swift": {"name": "Стремительный", "text": "Быстрее двигается и атакует", "icon": &"speed",
		"color": Color(0.6, 1.0, 0.6)},
	&"armored": {"name": "Бронированный", "text": "Больше Armour — режет физический урон", "icon": &"shield",
		"color": Color(0.75, 0.75, 0.8)},
	&"huge": {"name": "Громадный", "text": "Больше Life", "icon": &"heart", "color": Color(1.0, 0.4, 0.4)},
	&"berserk": {"name": "Яростный", "text": "Наносит больше урона", "icon": &"claw", "color": Color(1.0, 0.3, 0.2)},
	&"shocking": {"name": "Электрический", "text": "Весь урон — электричеством", "icon": &"bolt",
		"color": Color(0.5, 0.75, 1.0)},
	&"burning": {"name": "Огненный", "text": "Весь урон — огнём", "icon": &"flame", "color": Color(1.0, 0.55, 0.15)},
	&"acidic": {"name": "Кислотный", "text": "Весь урон — кислотой", "icon": &"drop", "color": Color(0.55, 1.0, 0.25)},
	&"storm": {"name": "Грозовой", "text": "Периодически вызывает молнию", "icon": &"storm",
		"color": Color(0.65, 0.8, 1.0)},
	&"regen": {"name": "Живучий", "text": "Восстанавливает Life", "icon": &"plus", "color": Color(0.4, 1.0, 0.5)},
	&"volatile": {"name": "Взрывной", "text": "Взрывается после смерти", "icon": &"burst",
		"color": Color(1.0, 0.7, 0.3)},
}

## С какого этажа свойство может выпасть: опасные (живучесть, броня) — только поздно, игрок привыкает постепенно.
const MIN_LEVEL := {&"swift": 1, &"shocking": 1, &"burning": 1, &"acidic": 1, &"huge": 2, &"berserk": 2,
		&"volatile": 2, &"armored": 3, &"storm": 3, &"regen": 4}

## Стихийные свойства не сочетаются друг с другом.
const ELEMENT_MODS := [&"shocking", &"burning", &"acidic"]

const NAME_HEADS := ["Гнило", "Крово", "Скверно", "Желче", "Косто", "Мрако", "Ядо", "Ржаво", "Пепло", "Стале",
	"Чумо", "Хрипо", "Слизе", "Игло", "Тлено"]
const NAME_TAILS := ["клык", "жор", "рез", "хват", "плёт", "дёр", "гриз", "лом", "пасть", "жал", "рёв", "кус"]


static func roll(count: int, level := 99) -> Array[StringName]:
	var result: Array[StringName] = []
	var pool: Array = MODS.keys().filter(func(m): return MIN_LEVEL.get(m, 1) <= level)
	pool.shuffle()
	for id in pool:
		if result.size() >= count:
			break
		if id in ELEMENT_MODS and result.any(func(m): return m in ELEMENT_MODS):
			continue
		result.append(id)
	return result


## Имя жёлтого врага: [начало, конец] — склеиваются при показе (на нужном языке).
static func rare_name() -> Array:
	return [NAME_HEADS.pick_random(), NAME_TAILS.pick_random()]
