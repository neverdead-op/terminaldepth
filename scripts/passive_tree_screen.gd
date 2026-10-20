extends Control
## Дерево пассивок (P, на геймпаде — нажатие правого стика). Четыре ряда слева направо. Игра на паузе, пока окно открыто.
## Узлы рисуются кружками: взятые — золотые, доступные (соседние со взятыми, если есть очки) — мигают,
## остальные — тёмные. Курсор ходит по узлам крестовиной/стиком/стрелками, мышь — наведением.
## A / ✕ / ЛКМ — вложить очко, Y / △ / ПКМ — вернуть очко (только с края ветки), B / ○ — закрыть.

const UiIcons := preload("res://scripts/ui_icons.gd")
const PassiveDB := preload("res://scripts/passive_db.gd")

const DESIGN := Vector2(1280, 720)
## Сколько пикселей (в 1280×720) в одной клетке дерева.
const UNIT := 56.0
const CENTER := Vector2(560, 370)

@export var allocated_color := Color(0.95, 0.78, 0.35)
@export var available_color := Color(0.6, 1.0, 0.6)
@export var locked_color := Color(0.35, 0.35, 0.38)
@export var text_color := Color(0.9, 0.88, 0.82)
@export var dim_text := Color(0.6, 0.6, 0.58)

var player: Node
var _cursor := 0
var _scale := 1.0
var _origin := Vector2.ZERO
var _font: Font
var _time := 0.0
var _repeat_left := 0.0
var _last_dir := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.fallback_font


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("passives") or (visible and event.is_action_pressed("menu_back")):
		if not visible and (get_tree().paused or player.is_dead()):
			return
		visible = not visible
		get_tree().paused = visible
		Sfx.play(&"ui_open", player.global_position)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("menu_accept"):
		_allocate()
	elif event.is_action_pressed("menu_alt"):
		_refund()
	elif event is InputEventMouseMotion:
		_hover(event.position)
		return
	elif event is InputEventMouseButton and event.pressed:
		_hover(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_allocate()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_refund()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var dir := Input.get_vector("menu_left", "menu_right", "menu_up", "menu_down", 0.5)
	if dir.length() > 0.5:
		if dir.normalized() != _last_dir:
			_move(dir.normalized())
			_repeat_left = 0.3
		else:
			_repeat_left -= delta
			if _repeat_left <= 0.0:
				_move(dir.normalized())
				_repeat_left = 0.12
	_last_dir = dir.normalized() if dir.length() > 0.5 else Vector2.ZERO
	queue_redraw()


func _move(dir: Vector2) -> void:
	var from: Vector2 = PassiveDB.NODES[_cursor].pos
	var best := -1
	var best_score := INF
	for i in PassiveDB.NODES.size():
		if i == _cursor:
			continue
		var d: Vector2 = PassiveDB.NODES[i].pos - from
		var along := d.dot(dir)
		if along < 0.3:
			continue
		var score := along + absf(d.dot(dir.orthogonal())) * 2.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_cursor = best
		Sfx.play(&"ui_click", player.global_position, -10.0)


func _hover(screen_pos: Vector2) -> void:
	for i in PassiveDB.NODES.size():
		if screen_pos.distance_to(_node_pos(PassiveDB.NODES[i])) < _radius(PassiveDB.NODES[i]) + 4:
			_cursor = i
			return


func _allocate() -> void:
	if player.allocate(PassiveDB.NODES[_cursor].id):
		Sfx.play(&"door_unlock", player.global_position, -2.0)
	else:
		Sfx.play(&"door_locked", player.global_position, -10.0)


func _refund() -> void:
	if player.refund(PassiveDB.NODES[_cursor].id):
		Sfx.play(&"ui_click", player.global_position)
	else:
		Sfx.play(&"door_locked", player.global_position, -10.0)


func _node_pos(n: Dictionary) -> Vector2:
	return _origin + (CENTER + n.pos * UNIT) * _scale


func _radius(n: Dictionary) -> float:
	return {"start": 26.0, "notable": 22.0, "small": 14.0}[n.kind] * _scale


func _draw() -> void:
	if player == null or size.x < 1.0:
		return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.94))
	_center("ДЕРЕВО ПАССИВОК", _origin + Vector2(640, 46) * _scale, 22, Color(0.95, 0.85, 0.6))
	_center("Свободных очков: %d" % player.passive_points, _origin + Vector2(640, 74) * _scale, 16,
			available_color if player.passive_points > 0 else dim_text)

	# Подписи рядов.
	for row in PassiveDB.ROWS:
		var y: float = CENTER.y + row[1] * UNIT
		var x: float = row[2] if row.size() > 2 else -3.6
		_center(row[0], _origin + Vector2(CENTER.x + x * UNIT, y + 5) * _scale, 12, dim_text)

	# Связи.
	for e in PassiveDB.EDGES:
		var a := PassiveDB.node(e[0])
		var b := PassiveDB.node(e[1])
		var both: bool = e[0] in player.allocated and e[1] in player.allocated
		draw_line(_node_pos(a), _node_pos(b), allocated_color if both else Color(1, 1, 1, 0.15), 4.0 if both else 2.0, true)

	# Узлы.
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	for n in PassiveDB.NODES:
		var p := _node_pos(n)
		var r := _radius(n)
		var taken: bool = n.id in player.allocated
		var available: bool = player.can_allocate(n.id)
		var ring := allocated_color if taken else (Color(available_color, pulse) if available else locked_color)
		draw_circle(p, r, Color(0.05, 0.05, 0.06))
		draw_arc(p, r, 0, TAU, 32, ring, 3.0 if n.kind != "small" else 2.0, true)
		var icon_color := allocated_color if taken else (available_color if available else Color(0.5, 0.5, 0.52))
		UiIcons.draw_stat(self, n.icon, p, r * 0.55, icon_color)

	# Курсор и подсказка.
	var cur: Dictionary = PassiveDB.NODES[_cursor]
	var cp := _node_pos(cur)
	draw_arc(cp, _radius(cur) + 6 * _scale, 0, TAU, 32, Color(1, 1, 1, pulse), 2.5, true)
	_draw_tooltip(cur, cp)
	_center("A / ✕ — вложить очко      Y / △ — вернуть очко (с края ветки)      B / ○ / P — закрыть",
			_origin + Vector2(640, 700) * _scale, 13, dim_text)


func _draw_tooltip(n: Dictionary, at: Vector2) -> void:
	var lines := PassiveDB.describe(n)
	var status := "Взято" if n.id in player.allocated else ("Можно взять" if player.can_allocate(n.id) else
			("Нет свободных очков" if player.passive_points <= 0 else "Сначала возьмите соседний узел"))
	if n.kind == "start":
		status = "Начало дерева"
	var width := 300.0 * _scale
	var height := (40.0 + lines.size() * 20.0 + 26.0) * _scale
	var pos := at + Vector2(30, -20) * _scale
	if pos.x + width > size.x - 8:
		pos.x = at.x - width - 30 * _scale
	pos.y = clampf(pos.y, 8, size.y - height - 8)
	var color := allocated_color if n.kind == "notable" else text_color
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0.03, 0.03, 0.035, 0.97))
	draw_rect(Rect2(pos, Vector2(width, height)), Color(color, 0.6), false, 1.5)
	_center(n.name, pos + Vector2(width * 0.5, 24 * _scale), 17, color)
	for i in lines.size():
		_center(lines[i], pos + Vector2(width * 0.5, (48 + i * 20) * _scale), 14, Color(0.55, 0.6, 1.0))
	_center(status, pos + Vector2(width * 0.5, height - 10 * _scale), 12, dim_text)


func _center(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var fs := int(size_px * _scale)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, pos - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
