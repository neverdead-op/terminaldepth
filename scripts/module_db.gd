extends RefCounted
## Список всех модулей оружия — отсюда выбираются случайные модули для выпадения с врагов.
## Добавили новый модуль в data/modules — допишите его сюда.

const ALL := [
	preload("res://data/modules/ricochet.tres"),
	preload("res://data/modules/pierce.tres"),
	preload("res://data/modules/fire.tres"),
	preload("res://data/modules/electric.tres"),
	preload("res://data/modules/acid.tres"),
	preload("res://data/modules/fast_reload.tres"),
	preload("res://data/modules/ext_mag.tres"),
	preload("res://data/modules/damage.tres"),
	preload("res://data/modules/fire_rate.tres"),
	preload("res://data/modules/multishot.tres"),
	preload("res://data/modules/nova_shot.tres"),
	preload("res://data/modules/leech.tres"),
	preload("res://data/modules/explosive.tres"),
	preload("res://data/modules/homing.tres"),
	preload("res://data/modules/overcharge.tres"),
	preload("res://data/modules/concentrate.tres"),
]


static func random() -> ModuleData:
	return ALL.pick_random()


static func by_id(id: StringName) -> ModuleData:
	for m in ALL:
		if m.id == id:
			return m
	return null
