class_name ModuleData
extends Resource
## Модуль оружия (аналог камня поддержки в PoE). Вставляется в слот любого оружия и меняет его.
## Все эффекты — числа ниже; у каждого модуля заполнены только нужные, остальные — ноль.
## Файлы модулей лежат в data/modules, список всех — в scripts/module_db.gd.

@export var id := &""
@export var display_name := "Модуль"
@export_multiline var description := ""
## Цвет в интерфейсе и на полу.
@export var color := Color(0.9, 0.9, 0.9)
## Короткая надпись (если значок не нарисован).
@export var short_name := "?"
## Тип для подсказки: Стихия, Механика, Характеристика, Особое. Значок рисуется по id (ui_icons.gd).
@export var category := "Характеристика"

@export_group("Числа")
@export var damage_bonus := 0.0  ## +доля урона (0.3 = +30%)
@export var fire_rate_bonus := 0.0
@export var reload_speed_bonus := 0.0  ## 0.35 = перезарядка на 35% быстрее
@export var magazine_bonus := 0.0
@export var extra_projectiles := 0
## Множитель урона каждой пули (для доп. снарядов: 0.7 = −30%).
@export var damage_multiplier := 1.0

@export_group("Механики")
@export var pierce := 0  ## сколько врагов пуля прошивает насквозь
@export var chain := 0  ## сколько раз пуля перескакивает на следующего врага
## Число вторичных снарядов при первом попадании выстрела; они не создают новые волны.
@export var nova_projectiles := 0
## Урон вторичной пули относительно уже изменённого урона основной.
@export var nova_damage_ratio := 0.5
@export var leech := 0.0  ## доля нанесённого урона, которая лечит игрока
## Взрыв при попадании: радиус (м) и доля урона пули всем врагам рядом.
@export var explode_radius := 0.0
@export var explode_ratio := 0.0
## Самонаведение: как быстро пуля доворачивает к врагу (радиан в секунду). 0 — летит прямо.
@export var homing := 0.0
## Множитель радиуса взрывов (мины, взрывные пули).
@export var area_mult := 1.0

@export_group("Куда ставится")
## Можно ли в оружие (пули). false — только для мин.
@export var weapon_ok := true
## Можно ли в минный ранец. false — модуль только для пуль (рикошет, пробивание, наведение, темп).
@export var mine_ok := true

@export_group("Стихия")
## fire, electric или acid. Пусто — без стихии.
@export var element := &""
## Добавленный урон стихией в долях физического (0.4 = +40%).
@export var element_ratio := 0.0


## Тип патронов (огонь / кислота / электричество): ставится только в первое гнездо, одно на оружие.
func is_ammo() -> bool:
	return element != &""
