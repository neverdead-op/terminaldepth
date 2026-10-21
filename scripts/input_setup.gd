extends RefCounted
## Регистрирует кнопки управления: клавиатура + мышь и геймпад.
## Используются физические клавиши, поэтому WASD работает и на русской раскладке.
## Игрок может переназначить основные действия в меню паузы → «Управление»; его выбор хранится
## в user://controls.cfg и применяется поверх стандартных кнопок при каждом запуске.

const CONFIG_PATH := "user://controls.cfg"

## Что можно переназначить в меню: [действие, название].
const REBINDABLE := [
	["skill_fireball", "Огненный шар"],
	["shoot", "Стрельба"], ["dodge", "Перекат / спринт"], ["reload", "Перезарядка"],
	["pickup", "Поднять вещь"], ["heal", "Аптечка"], ["interact", "Взаимодействовать"],
	["weapon_next", "Следующее оружие"], ["town_portal", "Портал на базу"], ["inventory", "Инвентарь"],
	["skill_grenade", "Граната"], ["skill_nova", "Ударная волна"], ["skill_mine", "Мина"],
	["skills", "Навыки и модули"], ["character", "Персонаж"], ["passives", "Дерево пассивок"],
]

static var _loaded := false


static func setup() -> void:
	# Окно света только в сценах с PostFXStudio; L3 на геймпаде.
	_add("postfx_studio", [_key(KEY_F8), _joy(JOY_BUTTON_LEFT_STICK)])
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])

	# Правый стик — ручной прицел (необязателен: без него работает автоприцел).
	_add("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])

	_add("shoot", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add("dodge", [_key(KEY_SPACE), _joy(JOY_BUTTON_A)])
	_add("reload", [_key(KEY_R), _joy(JOY_BUTTON_X)])

	# Смена оружия: 1/2, колесо мыши, Q; на геймпаде — Y по кругу.
	_add("weapon_next", [_key(KEY_Q), _mouse(MOUSE_BUTTON_WHEEL_DOWN), _joy(JOY_BUTTON_Y)])
	_add("weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP)])
	# Крестовина геймпада: влево / вправо — два слота оружия, вверх — аптечка.
	_add("weapon_1", [_key(KEY_1), _joy(JOY_BUTTON_DPAD_LEFT)])
	_add("weapon_2", [_key(KEY_2), _joy(JOY_BUTTON_DPAD_RIGHT)])
	# Аптечка — верхний ромб меню.
	_add("heal", [_key(KEY_E), _joy(JOY_BUTTON_DPAD_UP)])
	# Портал на базу и взаимодействие (торговец, верстак, портал обратно).
	_add("town_portal", [_key(KEY_H), _joy(JOY_BUTTON_LEFT_STICK)])
	# Навыки: граната и ударная волна.
	_add("skill_grenade", [_key(KEY_G), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("skill_nova", [_key(KEY_V), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_add("skill_mine", [_key(KEY_B), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add("skill_fireball", [_key(KEY_T), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	# ПКМ — действие: поднять вещь, открыть сундук, поговорить (гранаты пока убраны).
	_add("interact", [_key(KEY_F), _mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_B)])
	# Поднять вещь с пола (золото подбирается само). На геймпаде — та же X, что и перезарядка.
	_add("pickup", [_mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_X)])
	# Окна: персонаж (на геймпаде — из меню паузы), дерево пассивок, меню паузы.
	_add("character", [_key(KEY_C)])
	_add("passives", [_key(KEY_P), _joy(JOY_BUTTON_RIGHT_STICK)])
	_add("pause_menu", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	# Выбросить вещь из сумки (в инвентаре).
	_add("menu_drop", [_key(KEY_DELETE), _key(KEY_G), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	# Сравнить вещь с надетой (держать, в инвентаре).
	_add("menu_compare", [_key(KEY_ALT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	# Переключение окон Инвентарь — Персонаж — Пассивки (L1 / R1).
	_add("menu_tab_prev", [_key(KEY_PAGEUP), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_add("menu_tab_next", [_key(KEY_PAGEDOWN), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	# Инвентарь (оружие, модули, снаряжение).
	# На геймпаде: Back → LB/RB к вкладке навыков.
	_add("skills", [_key(KEY_K)])
	_add("inventory", [_key(KEY_TAB), _key(KEY_I), _joy(JOY_BUTTON_BACK)])
	# Управление в меню. Геймпад: A и X(квадрат) — выбрать, Y(треугольник) — быстро, B(круг) — назад.
	_add("menu_left", [_key(KEY_LEFT), _key(KEY_A), _joy(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("menu_right", [_key(KEY_RIGHT), _key(KEY_D), _joy(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("menu_up", [_key(KEY_UP), _key(KEY_W), _joy(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("menu_down", [_key(KEY_DOWN), _key(KEY_S), _joy(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("menu_accept", [_key(KEY_ENTER), _key(KEY_SPACE), _key(KEY_E), _joy(JOY_BUTTON_A)])
	# Взять вещь «в руку» и положить в другое место (геймпад X / □; мышью — перетаскиванием).
	_add("menu_move", [_key(KEY_M), _joy(JOY_BUTTON_X)])
	_add("menu_alt", [_key(KEY_F), _joy(JOY_BUTTON_Y)])
	_add("menu_back", [_key(KEY_ESCAPE), _key(KEY_BACKSPACE), _joy(JOY_BUTTON_B)])

	if not _loaded:
		_loaded = true
		_load_overrides()


# --- Переназначение ---------------------------------------------------------------------

## Заменить у действия кнопку одного вида: pad = true — геймпада, false — клавиатуры/мыши. Сохраняется.
static func rebind(action: String, event: InputEvent, pad: bool) -> void:
	for old in InputMap.action_get_events(action):
		if _is_pad(old) == pad:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)
	_save()


## Вернуть все кнопки по умолчанию.
static func reset_to_defaults() -> void:
	for row in REBINDABLE:
		if InputMap.has_action(row[0]):
			InputMap.erase_action(row[0])
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(CONFIG_PATH)
	setup()


## Название кнопки действия для меню (первая кнопка нужного вида).
static func binding_name(action: String, pad: bool) -> String:
	for event in InputMap.action_get_events(action):
		if _is_pad(event) == pad:
			return event_name(event)
	return "—"


static func event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
	if event is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "Колёсико",
				MOUSE_BUTTON_WHEEL_UP: "Колесо вверх", MOUSE_BUTTON_WHEEL_DOWN: "Колесо вниз"}.get(
				event.button_index, "Мышь %d" % event.button_index)
	if event is InputEventJoypadButton:
		return {JOY_BUTTON_A: "A / ✕", JOY_BUTTON_B: "B / ○", JOY_BUTTON_X: "X / □", JOY_BUTTON_Y: "Y / △",
				JOY_BUTTON_LEFT_SHOULDER: "LT / L2", JOY_BUTTON_RIGHT_SHOULDER: "RB / R1",
				JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3",
				JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "Крест. ↑", JOY_BUTTON_DPAD_DOWN: "Крест. ↓",
				JOY_BUTTON_DPAD_LEFT: "Крест. ←", JOY_BUTTON_DPAD_RIGHT: "Крест. →"}.get(
				event.button_index, "Кнопка %d" % event.button_index)
	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT / R2"
			JOY_AXIS_TRIGGER_LEFT:
				return "LT / L2"
		return "Стик"
	return "?"


static func _is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func _save() -> void:
	var config := ConfigFile.new()
	for row in REBINDABLE:
		var events := []
		for event in InputMap.action_get_events(row[0]):
			events.append(var_to_str(event))
		config.set_value("controls", row[0], events)
	config.save(CONFIG_PATH)


static func _load_overrides() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for row in REBINDABLE:
		# Новое действие (нет в старом файле настроек) — остаётся с кнопками по умолчанию.
		if not config.has_section_key("controls", row[0]) or not InputMap.has_action(row[0]):
			continue
		var saved = config.get_value("controls", row[0])
		if saved == null:
			continue
		InputMap.action_erase_events(row[0])
		for text in saved:
			var event = str_to_var(text)
			if event is InputEvent:
				InputMap.action_add_event(row[0], event)


static func _add(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
