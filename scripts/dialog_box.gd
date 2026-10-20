extends Control
const Style := preload("res://scripts/ui_style.gd")
## Окно разговора внизу экрана: имя персонажа, фраза, «далее» (A / ✕ / ЛКМ / F). Игра на паузе.
## Открывается DialogBox.show_lines(имя, фразы, по_окончании) — найдёт себя в группе dialog_box.

@export var accent := Color(0.95, 0.75, 0.3)

var _name := ""
var _lines: Array = []
var _page := 0
var _done: Callable
var _shown_chars := 0.0
var _body: Label


static func show_lines(tree: SceneTree, npc: String, lines: Array, done := Callable()) -> void:
	var box = tree.get_first_node_in_group("dialog_box")
	if box == null:
		if done.is_valid():
			done.call()
		return
	box._open(npc, lines, done)


func _ready() -> void:
	add_to_group("dialog_box")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.add_theme_font_override("font", Loc.MAIN_FONT)
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", Style.TEXT)
	_body.add_theme_constant_override("line_spacing", 5)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)


func _open(npc: String, lines: Array, done: Callable) -> void:
	_name = npc
	_lines = lines
	_page = 0
	_done = done
	_shown_chars = 0.0
	visible = true
	get_tree().paused = true
	Sfx.play(&"ui_open", Vector3.ZERO, -6.0)


func _process(delta: float) -> void:
	if visible:
		_shown_chars += delta * 60.0
		_body.text = Loc.t(_lines[mini(_page, _lines.size() - 1)]) if not _lines.is_empty() else ""
		_body.visible_characters = int(_shown_chars)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	if not visible:
		return
	var next: bool = event.is_action_pressed("menu_accept") or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if event.is_action_pressed("menu_back"):
		_page = _lines.size()
		next = true
	if not next:
		return
	get_viewport().set_input_as_handled()
	var text: String = Loc.t(_lines[mini(_page, _lines.size() - 1)])
	if _page < _lines.size() and _shown_chars < text.length():
		_shown_chars = text.length()  # сначала дописать фразу целиком
		return
	_page += 1
	_shown_chars = 0.0
	Sfx.play(&"ui_click", Vector3.ZERO, -8.0)
	if _page >= _lines.size():
		visible = false
		get_tree().paused = false
		if _done.is_valid():
			_done.call()


func _draw() -> void:
	if _lines.is_empty():
		return
	var ui_scale := minf(size.x / 1280.0, size.y / 720.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * ui_scale)
	var font := Loc.MAIN_FONT
	var w := minf(620.0, size.x / ui_scale - 48.0)
	var box := Rect2(24, size.y / ui_scale - 390, w, 250)
	Style.panel(self, box)
	draw_string(Loc.TITLE_FONT, box.position + Vector2(24, 40), Loc.npc_name(_name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 18, Style.TEXT)
	_body.position = ((box.position + Vector2(24, 66)) * ui_scale).round()
	_body.size = Vector2(w - 48, 145)
	_body.scale = Vector2.ONE * ui_scale
	var hint := "%s — %s   %d / %d" % [Loc.keys("F / ЛКМ / A / ✕"), Loc.t("далее"), _page + 1, _lines.size()]
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(box.end.x - 24 - hint_width, box.end.y - 32), hint, HORIZONTAL_ALIGNMENT_LEFT, -1,
			12, Color(0.7, 0.68, 0.62))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
