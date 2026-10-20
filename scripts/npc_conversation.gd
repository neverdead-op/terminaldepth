extends PanelContainer
## Небольшое меню персонажа: темы слева, доступные услуги справа.

const Dialog := preload("res://scripts/npc_dialog.gd")
const DialogBox := preload("res://scripts/dialog_box.gd")
const Style := preload("res://scripts/ui_style.gd")
var _player: Node
var _source: Node
var _npc := ""
var _opening_until := 0
var _navigation_at := 0
var _first_button: Button
var _last_focus: Control


static func show_for(player: Node, source: Node, npc: String) -> void:
	var panel := new()
	panel._player = player
	panel._source = source
	panel._npc = npc
	player.get_node("HUD").add_child(panel)


func _ready() -> void:
	_opening_until = Time.get_ticks_msec() + 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var viewport_size := get_viewport_rect().size
	var ui_scale := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	scale = Vector2.ONE * ui_scale
	position = Vector2(24 * ui_scale, maxf(24, viewport_size.y - 370 * ui_scale))
	custom_minimum_size = Vector2(580, 252)
	add_theme_stylebox_override("panel", Style.panel_box())
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var title := Label.new()
	title.text = Loc.npc_name(_npc).to_upper()
	title.add_theme_font_override("font", Loc.TITLE_FONT)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Style.TEXT)
	layout.add_child(title)
	layout.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	layout.add_child(columns)
	var topics := VBoxContainer.new()
	topics.custom_minimum_size.x = 268
	topics.add_theme_constant_override("separation", 8)
	columns.add_child(topics)
	var services := VBoxContainer.new()
	services.custom_minimum_size.x = 248
	services.add_theme_constant_override("separation", 8)
	columns.add_child(services)
	_button(topics, "Кербер-7", _story.bind("Кербер-7"))
	_button(topics, "Сигнал из глубины", _story.bind("Сигнал из глубины"))
	_button(topics, "Снаряжение и навыки", _story.bind("Снаряжение и навыки"))
	if _source.get("stocks") != null:
		_button(services, "Купить или продать", _service.bind(&"vendor"))
	else:
		_button(services, "Разобрать снаряжение", _service.bind(&"salvage"))
	_button(services, "До встречи", _close)
	var first := topics.get_child(0) as Button
	_first_button = first
	var groups := [topics.get_children(), services.get_children()]
	for x in 2:
		for y in groups[x].size():
			var button: Button = groups[x][y]
			button.focus_neighbor_top = button.get_path_to(groups[x][wrapi(y - 1, 0, groups[x].size())])
			button.focus_neighbor_bottom = button.get_path_to(groups[x][(y + 1) % groups[x].size()])
			var other: Button = groups[1 - x][mini(y, groups[1 - x].size() - 1)]
			button.focus_neighbor_left = button.get_path_to(other)
			button.focus_neighbor_right = button.get_path_to(other)
	first.grab_focus()

func _draw() -> void:
	Style.panel(self, Rect2(Vector2.ZERO, size))


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = Loc.t(text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", Loc.MAIN_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Style.TEXT)
	button.add_theme_color_override("font_hover_color", Style.GOLD.lightened(0.2))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.12, 0.10, 0.065, 0.8)
	focus.border_color = Color(0.58, 0.43, 0.25)
	focus.set_border_width_all(1)
	focus.content_margin_left = 12
	focus.content_margin_right = 12
	var normal := focus.duplicate() as StyleBoxFlat
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("hover", focus)
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)


func _story(topic: String) -> void:
	var lines: Array = []
	match topic:
		"Сигнал из глубины":
			lines = Dialog.current(_npc)
			Dialog.mark_seen(_npc)
		"Кербер-7":
			lines = ["«Кербер-7» строили как исследовательский комплекс. Сады Эдема должны были кормить колонию. Потом связь с нижними ярусами оборвалась.", "Лаборатория держится на резервном питании. Здесь можно передохнуть и подготовиться к спуску."]
		"Снаряжение и навыки":
			lines = ["Оружие экипируется рядом с бронёй. Нажми K, чтобы открыть навыки и их модификаторы.", "У автомата есть подствольная граната, у плазменного резака — рассекающий импульс. Их модификаторы независимы от основного выстрела."]
	if lines.is_empty():
		lines = ["Новых сигналов пока нет. Возвращайся после следующего спуска."]
	_last_focus = get_viewport().gui_get_focus_owner()
	visible = false
	DialogBox.show_lines(get_tree(), _npc, lines, func():
		visible = true
		get_tree().paused = true
		if is_instance_valid(_last_focus):
			_last_focus.call_deferred("grab_focus"))


func _service(context: StringName) -> void:
	_close()
	_player.get_node("HUD").inventory_screen.open_context(context, _source)


func _close() -> void:
	get_tree().paused = false
	queue_free()


func _input(event: InputEvent) -> void:
	if not visible or Time.get_ticks_msec() < _opening_until:
		return
	if event.is_action_pressed("menu_back"):
		get_viewport().set_input_as_handled()
		_close()
		return
	var focus := get_viewport().gui_get_focus_owner() as Button
	if focus == null or not is_ancestor_of(focus):
		focus = _first_button
		focus.grab_focus()
	if event.is_action_pressed("menu_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		focus.pressed.emit()
		return
	for entry in [["menu_up", SIDE_TOP], ["menu_down", SIDE_BOTTOM], ["menu_left", SIDE_LEFT], ["menu_right", SIDE_RIGHT]]:
		if event.is_action_pressed(entry[0]):
			get_viewport().set_input_as_handled()
			if Time.get_ticks_msec() < _navigation_at:
				return
			_navigation_at = Time.get_ticks_msec() + 160
			var path := focus.get_focus_neighbor(entry[1])
			if not path.is_empty():
				(focus.get_node(path) as Button).grab_focus()
			return
