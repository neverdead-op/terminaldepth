extends Control
## Окно персонажа в стиле PoE 2 (C, на геймпаде — Start). Игра на паузе, пока оно открыто.
## Сверху — уровень и опыт, плитки «Здоровье / Энергощит / Броня / Скорость» со значками,
## блок сопротивлений (значение и в скобках — сколько набрано сверх потолка), ниже — подробности.
## Закрыть: C / Start / B / Esc.

const UiIcons := preload("res://scripts/ui_icons.gd")

const DESIGN := Vector2(1280, 720)

@export var panel_color := Color(0.028, 0.032, 0.042, 0.97)
@export var frame_color := Color(0.88, 0.47, 0.16, 0.75)
@export var title_color := Color(0.95, 0.85, 0.6)
@export var text_color := Color(0.9, 0.88, 0.82)
@export var dim_text := Color(0.6, 0.6, 0.58)

var player: Node
var _scale := 1.0
var _origin := Vector2.ZERO
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.fallback_font


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("character") or (visible and (event.is_action_pressed("menu_back") or event.is_action_pressed("inventory"))):
		if not visible and (get_tree().paused or player.is_dead()):
			return  # не открываем поверх инвентаря или торговца
		visible = not visible
		get_tree().paused = visible
		Sfx.play(&"ui_open", player.global_position)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if player == null or size.x < 1.0:
		return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var panel := Rect2(16, 16, 470, 688)
	draw_rect(_r(panel), panel_color)
	draw_rect(_r(panel), frame_color, false, 2.0)
	draw_rect(_r(panel).grow(-4 * _scale), Color(frame_color, 0.25), false, 1.0)
	var plate := Rect2(121, 24, 260, 32)
	draw_rect(_r(plate), Color(0.16, 0.13, 0.08, 0.95))
	draw_rect(_r(plate), frame_color, false, 1.5)
	_center("ПЕРСОНАЖ", Vector2(251, 46), 17, title_color)

	# --- Шапка: портрет, класс, уровень, опыт ---
	var portrait := Rect2(36, 70, 72, 72)
	draw_rect(_r(portrait), Color(0, 0, 0, 0.5))
	draw_rect(_r(portrait), frame_color, false, 1.5)
	UiIcons.draw_gear(self, &"helmet", _p(portrait.get_center()), 26 * _scale, Color(0.5, 0.85, 1.0))
	_text("Оперативник", Vector2(124, 94), 20, text_color)
	_text("Уровень %d" % player.level, Vector2(124, 118), 15, title_color)
	var need: int = player.xp_for_next_level()
	var bar := Rect2(124, 128, 344, 8)
	draw_rect(_r(bar), Color(0, 0, 0, 0.6))
	var ratio := 1.0 if player.is_max_level() else float(player.xp) / maxf(float(need), 1.0)
	draw_rect(_r(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))), Color(0.85, 0.75, 0.4))
	var xp_text := "максимум для демо" if player.is_max_level() else "опыт %d / %d" % [player.xp, need]
	_text(xp_text, Vector2(124, 152), 12, dim_text)
	if player.passive_points > 0:
		_text("Очки пассивок: %d  —  P / R3" % player.passive_points, Vector2(300, 152), 12, Color(0.6, 1.0, 0.6))

	# --- Плитки основных характеристик ---
	var tiles := [
		["life", "Life", "%d" % int(player.max_hp), Color(0.9, 0.2, 0.25)],
		["energy_shield", "Energy Shield", "%d" % int(player.max_es), Color(0.4, 0.75, 1.0)],
		["armor", "Armour", "%d" % int(player.armor), Color(0.8, 0.78, 0.7)],
		["speed", "Скорость", "+%d%%" % roundi((player.move_speed_mult - 1.0) * 100.0), Color(0.6, 0.95, 0.6)],
	]
	for i in tiles.size():
		var tile := Rect2(34 + i * 110, 172, 102, 104)
		draw_rect(_r(tile), Color(0.08, 0.075, 0.07, 0.95))
		draw_rect(_r(tile), Color(frame_color, 0.6), false, 1.5)
		UiIcons.draw_stat(self, StringName(tiles[i][0]), _p(tile.position + Vector2(51, 32)), 18 * _scale, tiles[i][3])
		_center(tiles[i][1], tile.position + Vector2(51, 70), 13, dim_text)
		_center(tiles[i][2], tile.position + Vector2(51, 92), 18, text_color)

	# --- Сопротивления ---
	draw_line(_p(Vector2(40, 296)), _p(Vector2(462, 296)), Color(frame_color, 0.4), 1.0)
	_center("СОПРОТИВЛЕНИЯ", Vector2(251, 312), 12, title_color)
	var res := [
		[&"fire", "Огонь", Color(1.0, 0.45, 0.2)],
		[&"electric", "Электричество", Color(0.45, 0.7, 1.0)],
		[&"acid", "Кислота", Color(0.5, 1.0, 0.3)],
	]
	for i in res.size():
		var row := Rect2(40, 324 + i * 40, 422, 34)
		draw_rect(_r(row), Color(0.07, 0.065, 0.06, 0.9))
		UiIcons.draw_stat(self, res[i][0], _p(row.position + Vector2(22, 17)), 12 * _scale, res[i][2])
		_text(res[i][1], row.position + Vector2(48, 23), 15, text_color)
		var capped: float = player.resists[res[i][0]]
		var raw: float = player.resists_raw[res[i][0]]
		_text_right("%d%%   (%d%%)" % [int(capped), int(raw)], row.position + Vector2(410, 23), 15,
				Color(0.95, 0.85, 0.6) if capped >= player.resist_cap else text_color)

	# --- Подробности ---
	var y := 460.0
	draw_line(_p(Vector2(40, y - 12)), _p(Vector2(462, y - 12)), Color(frame_color, 0.4), 1.0)
	var sections := [
		["Life", [
			["Максимум Life", "%d" % int(player.max_hp)],
			["Регенерация в секунду", "%d" % int(player.hp_regen)],
		]],
		["Energy Shield", [
			["Максимум Energy Shield", "%d" % int(player.max_es)],
			["Восстановление в секунду", "%.1f" % (player.max_es * player.es_recharge_rate * player._es_recharge_mult)],
			["Задержка восстановления", "%.1f с" % player.es_recharge_delay],
		]],
		["Armour", [
			["Снижение удара в 20 урона", "%d%%" % roundi(player.armor_reduction(20.0) * 100.0)],
			["Снижение удара в 50 урона", "%d%%" % roundi(player.armor_reduction(50.0) * 100.0)],
		]],
	]
	for section in sections:
		_text(section[0], Vector2(40, y), 17, title_color)
		y += 22
		for line in section[1]:
			_text(line[0], Vector2(48, y), 13, text_color)
			_text_right(line[1], Vector2(462, y), 13, text_color)
			y += 18
		y += 8
	_text_right("C / B / Esc — закрыть", Vector2(470, 698), 12, dim_text)


func _r(rect: Rect2) -> Rect2:
	return Rect2(_origin + rect.position * _scale, rect.size * _scale)


func _p(v: Vector2) -> Vector2:
	return _origin + v * _scale


func _text(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	draw_string(_font, _p(pos), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_px * _scale), color)


func _center(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var fs := int(size_px * _scale)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, _p(pos) - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _text_right(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var fs := int(size_px * _scale)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, _p(pos) - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
