extends Control
## Меню паузы (Esc, на геймпаде — Start): продолжить, персонаж, дерево пассивок, управление,
## вибрация геймпада, выход. Страница «Управление» — переназначение кнопок:
## выбрать действие и столбец (клавиатура / геймпад), A — «нажмите новую кнопку», B / Esc — отмена.

const InputSetup := preload("res://scripts/input_setup.gd")

const DESIGN := Vector2(1280, 720)
const ART := preload("res://assets/ui/gothic_v3/pause_menu.png")
const MENU_FONT := preload("res://assets/fonts/menu_font.tres")

@export var gold := Color(0.95, 0.85, 0.6)
@export var text_color := Color(0.9, 0.88, 0.82)
@export var dim_text := Color(0.6, 0.6, 0.58)
@export var frame_color := Color(0.35, 0.85, 1.0, 0.75)
const CYAN := Color(0.35, 0.85, 1.0)

var player: Node
var _page := &"main"
var _cursor := 0
var _column := 0  # 0 — клавиатура, 1 — геймпад
var _waiting := false
var _scale := 1.0
var _origin := Vector2.ZERO
var _font: Font
var _time := 0.0
var _repeat := 0.0
var _last_dir := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.fallback_font


func _items() -> Array:
	return ["Продолжить", "Персонаж", "Дерево пассивок", "Управление",
		"Вибрация геймпада: %s" % ("вкл" if player.vibration_enabled else "выкл"),
		"Язык / Language: %s" % Loc.LANGUAGE_NAMES[Loc.language], "Главное меню", "Выйти из игры"]


func _input(event: InputEvent) -> void:
	if _waiting:
		_capture(event)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		if event.is_action_pressed("pause_menu") and not get_tree().paused and not player.is_dead():
			_open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_item_at(event.position)
		queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _item_at(event.position):
			_accept()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("menu_back"):
		if _page == &"controls":
			_page = &"main"
			_cursor = 3
		else:
			_close()
	elif event.is_action_pressed("menu_accept"):
		_accept()
	else:
		return
	get_viewport().set_input_as_handled()


func _open() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	visible = true
	get_tree().paused = true
	_page = &"main"
	_cursor = 0
	Sfx.play(&"ui_open", player.global_position)


func _close() -> void:
	visible = false
	get_tree().paused = false


func _accept() -> void:
	Sfx.play(&"ui_click", player.global_position)
	if _page == &"main":
		match _cursor:
			0:
				_close()
			1:
				_close()
				_send(&"character")
			2:
				_close()
				_send(&"passives")
			3:
				_page = &"controls"
				_cursor = 0
				_column = 0
			4:
				player.vibration_enabled = not player.vibration_enabled
			5:
				Loc.next_language()
			6:
				_close()
				Game.to_main_menu.call_deferred()
			7:
				get_tree().quit()
		return
	var rows := InputSetup.REBINDABLE.size()
	if _cursor < rows:
		_waiting = true
	elif _cursor == rows:
		InputSetup.reset_to_defaults()
	else:
		_page = &"main"
		_cursor = 3


## Попадание мыши проверяем по тем же прямоугольникам, которые рисует меню.
func _item_at(point: Vector2) -> bool:
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	if _page == &"main":
		for i in _items().size():
			if _main_item_rect(i).has_point(point):
				_cursor = i
				return true
	else:
		var rows := InputSetup.REBINDABLE.size()
		for i in rows:
			if _r(_control_rect(i)).has_point(point):
				_cursor = i
				_column = 1 if point.x > _p(Vector2(806, 0)).x else 0
				return true
		for j in 2:
			if _r(_extra_rect(j)).has_point(point):
				_cursor = rows + j
				return true
	return false


## Открыть другое окно так, будто нажали его кнопку.
func _send(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)


## Ждём новую кнопку: для столбца клавиатуры — клавишу или кнопку мыши, для геймпада — кнопку или курок.
func _capture(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_waiting = false
		return
	var action: String = InputSetup.REBINDABLE[_cursor][0]
	var new_event: InputEvent = null
	if _column == 0:
		if event is InputEventKey:
			new_event = InputEventKey.new()
			new_event.physical_keycode = event.physical_keycode
		elif event is InputEventMouseButton:
			new_event = InputEventMouseButton.new()
			new_event.button_index = event.button_index
	else:
		if event is InputEventJoypadButton:
			if event.button_index == JOY_BUTTON_START:
				_waiting = false
				return
			new_event = InputEventJoypadButton.new()
			new_event.button_index = event.button_index
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6 and \
				event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			new_event = InputEventJoypadMotion.new()
			new_event.axis = event.axis
			new_event.axis_value = 1.0
	if new_event != null:
		InputSetup.rebind(action, new_event, _column == 1)
		_waiting = false
		Sfx.play(&"door_unlock", player.global_position, -6.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var count := _items().size() if _page == &"main" else InputSetup.REBINDABLE.size() + 2
	if not _waiting:
		var v := Input.get_vector("menu_left", "menu_right", "menu_up", "menu_down", 0.5)
		var dir := 0
		if absf(v.y) > absf(v.x):
			dir = int(signf(v.y))
		elif absf(v.x) > 0.5 and _page == &"controls":
			_column = 0 if v.x < 0 else 1
		if dir != 0:
			if dir != _last_dir:
				_cursor = wrapi(_cursor + dir, 0, count)
				_repeat = 0.3
			else:
				_repeat -= delta
				if _repeat <= 0.0:
					_cursor = wrapi(_cursor + dir, 0, count)
					_repeat = 0.1
		_last_dir = dir
	queue_redraw()


## Рамка и рабочие области берутся из одинаковых координат исходного рисунка.
func _art_box() -> Rect2:
	var height := 704.0
	var width := height * 1024.0 / 1536.0
	return Rect2((1280 - width) * 0.5, 8, width, height)

func _main_item_rect(index: int) -> Rect2:
	var box := _art_box()
	var k := box.size.y / 1536.0
	return _r(Rect2(box.position + Vector2(214, 282 + index * 132) * k, Vector2(596, 72) * k))

func _control_rect(index: int) -> Rect2:
	return Rect2(324, 133 + index * 26, 640, 25)

func _extra_rect(index: int) -> Rect2:
	return Rect2(470, 133 + (InputSetup.REBINDABLE.size() + index) * 26, 340, 25)

func _menu_text(text: String, rect: Rect2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var fs := maxi(12, roundi(size_px * _scale))
	while MENU_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 12 * _scale and fs > 10: fs -= 1
	var width := MENU_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(rect.get_center().x - width * 0.5, rect.get_center().y + (MENU_FONT.get_ascent(fs) - MENU_FONT.get_descent(fs)) * 0.5).round()
	draw_string_outline(MENU_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
	draw_string(MENU_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _draw() -> void:
	if player == null or size.x < 1: return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.005, 0.009, 0.76))
	if _page == &"main":
		draw_texture_rect(ART, _r(_art_box()), false)
		_menu_text("ПАУЗА", _r(Rect2(480, 66, 320, 40)), 32, gold)
		var items := _items()
		for i in items.size():
			var rect := _main_item_rect(i)
			var selected := i == _cursor
			if selected:
				draw_rect(rect, Color(0.65, 0.43, 0.28, 0.12))
			_menu_text(Loc.t(String(items[i])).to_upper(), rect, 20, gold if selected else text_color)
		_menu_text("Esc / Start / B — назад", _r(Rect2(470, 620, 340, 30)), 18, text_color)
		return
	# Широкая версия той же рамки оставляет место всем действиям и двум столбцам ввода.
	draw_texture_rect_region(ART, _r(Rect2(264, 12, 752, 696)), Rect2(106, 8, 812, 1515))
	# Спокойная подложка таблицы не растягивает декоративные детали исходной шапки.
	draw_rect(_r(Rect2(324, 110, 640, 507)), Color(0.018, 0.020, 0.023))
	_menu_text("УПРАВЛЕНИЕ", _r(Rect2(420, 54, 440, 42)), 30, gold)
	_text("Действие", Vector2(334, 124), 13, dim_text)
	_center("Клавиатура / мышь", Vector2(709, 124), 13, dim_text)
	_center("Геймпад", Vector2(883, 124), 13, dim_text)
	var rows := InputSetup.REBINDABLE
	for i in rows.size():
		var y := 152 + i * 26
		var selected := i == _cursor
		if selected: draw_rect(_r(_control_rect(i)), Color(1, 1, 1, 0.06))
		_text(rows[i][1], Vector2(334, y), 14, text_color)
		for column in 2:
			var cell := Rect2(622 if column == 0 else 808, y - 18, 174 if column == 0 else 148, 24)
			var waiting_here := selected and _waiting and column == _column
			var label := "нажмите…" if waiting_here else InputSetup.binding_name(rows[i][0], column == 1)
			if selected and column == _column: draw_rect(_r(cell), Color(gold, 0.8), false, _scale)
			_center(label, cell.get_center() + Vector2(0, 5), 13, gold if waiting_here else text_color)
	var extra := ["Сбросить по умолчанию", "Назад"]
	for j in 2:
		var rect := _r(_extra_rect(j))
		if _cursor == rows.size() + j: draw_rect(rect, Color(gold, 0.7), false, _scale)
		_menu_text(extra[j], rect, 19, gold if _cursor == rows.size() + j else text_color)
	var hint := "Нажмите новую кнопку · Esc / Start — отмена" if _waiting else "↑↓ — действие · ←→ — столбец · Enter / A — назначить · Esc / B — назад"
	_center(hint, Vector2(640, 652), 11, dim_text)


func _p(v: Vector2) -> Vector2:
	return _origin + v * _scale


func _r(rect: Rect2) -> Rect2:
	return Rect2(_origin + rect.position * _scale, rect.size * _scale)


func _text(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	draw_string(_font, _origin + pos * _scale, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_px * _scale), color)


func _center(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var fs := int(size_px * _scale)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, _origin + pos * _scale - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
