extends Control
## Главное меню при запуске: новая игра в одном из режимов, язык, выход.
## Режимы (Game.mode): normal — обычный, hardcore — одна жизнь, god — тест (бессмертие и много добычи).
## Управление: стрелки / стик / крестовина и A / Enter, или мышь.

const InputSetup := preload("res://scripts/input_setup.gd")
const DESIGN := Vector2(1672, 941)
const MENU_FONT := preload("res://assets/fonts/menu_font.tres")
const Style := preload("res://scripts/ui_style.gd")

@export var gold := Color(0.95, 0.85, 0.6)
@export var text_color := Color(0.9, 0.88, 0.82)
@export var dim_text := Color(0.6, 0.6, 0.58)
@export var frame_color := Color(0.88, 0.47, 0.16, 0.75)

const SaveGame := preload("res://scripts/save_game.gd")
const MODE_NAMES := {"normal": "SSF", "hardcore": "HC SSF", "god": "God mode"}

## Главная страница меню.
const MAIN_ITEMS := [
	{"id": &"new", "text": "Новая игра", "about": "Начать новый забег — выбор режима."},
	{"id": &"language", "text": "", "about": "Язык интерфейса / Interface language"},
	{"id": &"quit", "text": "Выйти из игры", "about": ""},
]
## Страница «Новая игра»: режимы с пояснениями.
const MODE_ITEMS := [
	{"id": &"normal", "text": "SSF",
		"about": "Solo Self-Found: всё снаряжение — только своё, найденное и созданное. Смерть — возрождение у входа на этаж."},
	{"id": &"hardcore", "text": "HC SSF",
		"about": "Hardcore Solo Self-Found: одна жизнь. Смерть — конец забега, сохранение стирается."},
	{"id": &"god", "text": "God mode",
		"about": "Для тестов: бессмертие, стартовый запас вещей и фрагментов, много золота и добычи."},
	{"id": &"tavern", "text": "Таверна",
		"about": "Сразу в таверне с пистолетом и 500 золота: торговцы, верстак, дверь в область 2. Без сохранения."},
	{"id": &"demo", "text": "Demo",
		"about": "Первый уровень с коломётом: огненный заряд и рикошет сразу. Без сохранения."},
	{"id": &"back", "text": "Назад", "about": ""},
]

var ITEMS: Array = MAIN_ITEMS.duplicate()
var _page := &"main"
var _cursor := 0
var _scale := 1.0
var _origin := Vector2.ZERO
var _font: Font
var _time := 0.0
var _stars: Array[Vector3] = []
var _repeat := 0.0
var _last_dir := 0


func _ready() -> void:
	InputSetup.setup()
	# Есть сохранение — первым пунктом «Продолжить».
	_add_continue()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_font = MENU_FONT
	_cursor = 0 if ITEMS[0].get("enabled", true) else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 220:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))


func _process(delta: float) -> void:
	_time += delta
	var v := Input.get_vector("menu_left", "menu_right", "menu_up", "menu_down", 0.5)
	var dir := int(signf(v.y)) if absf(v.y) > 0.5 else 0
	if dir != 0:
		if dir != _last_dir:
			_step(dir)
			_repeat = 0.3
		else:
			_repeat -= delta
			if _repeat <= 0.0:
				_step(dir)
				_repeat = 0.12
	_last_dir = dir
	queue_redraw()


func _step(dir: int) -> void:
	_cursor = wrapi(_cursor + dir, 0, ITEMS.size())
	while not ITEMS[_cursor].get("enabled", true):
		_cursor = wrapi(_cursor + dir, 0, ITEMS.size())
	Sfx.play(&"ui_click", Vector3.ZERO, -8.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _item_at(event.position)
		if i >= 0:
			_cursor = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _item_at(event.position)
		if i >= 0:
			_cursor = i
			_accept()
	elif event.is_action_pressed("menu_accept"):
		_accept()
	elif event.is_action_pressed("menu_back") and _page == &"new":
		_open_page(&"main")


func _accept() -> void:
	if not ITEMS[_cursor].get("enabled", true): return
	var id: StringName = ITEMS[_cursor].id
	Sfx.play(&"ui_open", Vector3.ZERO)
	match id:
		&"new":
			_open_page(&"new")
		&"back":
			_open_page(&"main")
		&"language":
			Loc.next_language()
		&"quit":
			get_tree().quit()
		&"continue":
			Game.continue_game()
		&"demo":
			Game.start_demo()
		&"tavern":
			Game.start_tavern()
		_:
			Game.new_game(id)


func _open_page(page: StringName) -> void:
	_page = page
	ITEMS = (MODE_ITEMS if page == &"new" else MAIN_ITEMS).duplicate()
	if page == &"main":
		_add_continue()
	_cursor = 0 if ITEMS[0].get("enabled", true) else 1


func _add_continue() -> void:
	var info := SaveGame.summary()
	var about := "Нет сохранённого забега."
	if not info.is_empty():
		about = Loc.t("Режим: %s · этаж %d · уровень %d") % [Loc.t(MODE_NAMES.get(info.mode, info.mode)), info.floor, info.level]
	ITEMS.push_front({"id": &"continue", "text": "Продолжить", "about": about, "enabled": not info.is_empty()})


const BG := preload("res://assets/ui/gothic_v3/main_menu.png")
const BG_SIZE := Vector2(1672, 941)
const BUTTON_SOURCE := Rect2(55, 286, 609, 108)

## Весь рисунок остаётся виден; активные области масштабируются вместе с ним.
func _bg_scale() -> float:
	return minf(size.x / BG_SIZE.x, size.y / BG_SIZE.y)

func _bg_origin() -> Vector2:
	return (size - BG_SIZE * _bg_scale()) * 0.5

func _button_frame(i: int) -> Rect2:
	return Rect2(55, 286 + i * 134, 609, 108) if _page == &"main" else Rect2(55, 283 + i * 100, 609, 94)

func _item_rect(i: int) -> Rect2:
	var frame := _button_frame(i)
	return Rect2(_bg_origin() + (frame.position + Vector2(48, 23)) * _bg_scale(), (frame.size - Vector2(96, 46)) * _bg_scale())

func _item_at(pos: Vector2) -> int:
	for i in ITEMS.size():
		if ITEMS[i].get("enabled", true) and _item_rect(i).has_point(pos): return i
	return -1

func _draw() -> void:
	var k := _bg_scale()
	var o := _bg_origin()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.006, 0.008, 0.012))
	draw_texture_rect(BG, Rect2(o, BG_SIZE * k), false)
	if _page == &"new":
		# Четыре режима и «Назад» используют те же рамки внутри отдельной панели.
		Style.panel(self, Rect2(o + Vector2(30, 262) * k, Vector2(658, 540) * k), k)
		for i in ITEMS.size():
			var frame := _button_frame(i)
			draw_texture_rect_region(BG, Rect2(o + frame.position * k, frame.size * k), BUTTON_SOURCE)
	for i in ITEMS.size():
		var r := _item_rect(i)
		var enabled: bool = ITEMS[i].get("enabled", true)
		var selected := i == _cursor and enabled
		if selected:
			draw_rect(r, Color(0.65, 0.42, 0.24, 0.10))
			draw_line(Vector2(r.position.x + 70 * k, r.end.y - 3 * k), Vector2(r.end.x - 70 * k, r.end.y - 3 * k), Color(0.77, 0.62, 0.43, 0.65), k)
		var text: String = ITEMS[i].text
		if ITEMS[i].id == &"language": text = "%s: %s" % [Loc.t("Язык"), Loc.LANGUAGE_NAMES[Loc.language]]
		else: text = Loc.t(text)
		text = text.to_upper()
		var fs := maxi(16, roundi((35 if _page == &"main" else 31) * k))
		while _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 20 * k and fs > 12: fs -= 1
		var baseline := r.get_center().y + (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
		var color := Color(0.98, 0.92, 0.79) if selected else Color(0.78, 0.76, 0.70)
		if not enabled: color = Color(0.43, 0.44, 0.44)
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(r.get_center().x - width * 0.5, baseline).round()
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	var about := Loc.t(String(ITEMS[_cursor].about))
	if not about.is_empty(): _draw_about(about, o, k)

func _draw_about(text: String, origin: Vector2, k: float) -> void:
	var font := Loc.MAIN_FONT
	var fs := maxi(11, roundi(19 * k))
	var line := ""
	var lines: Array[String] = []
	for word in text.split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 575 * k and not line.is_empty():
			lines.append(line)
			line = word
		else: line = candidate
	if not line.is_empty(): lines.append(line)
	for i in mini(lines.size(), 4):
		var at := origin + Vector2(75, 826 + i * 25) * k
		draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.9))
		draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.75, 0.71))
