extends Control
const Style := preload("res://scripts/ui_style.gd")
const Art := preload("res://scripts/inventory_art.gd")
## Вкладки сверху над окнами «Инвентарь — Персонаж — Пассивки»: видны, когда открыто одно из них.
## L1 / R1 (геймпад) или щелчок мышью по вкладке — переключиться (игра остаётся на паузе).

var screens: Array = []  # [Control инвентаря, персонажа, пассивок]
const TITLES := ["Инвентарь", "Навыки", "Персонаж", "Пассивки"]
const KEYS := ["I", "K", "C", "P"]

@export var accent := Color(0.78, 0.64, 0.39)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _current() -> int:
	for i in screens.size():
		if screens[i].visible:
			return i
	return -1


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var cur := _current()
	if cur < 0:
		return
	# Инвентарь в режиме торговца/склада/верстака — вкладки не переключаем.
	if cur == 0 and screens[0].get("_context") != &"":
		return
	if event.is_action_pressed("menu_tab_prev"):
		_switch(cur, wrapi(cur - 1, 0, screens.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_tab_next"):
		_switch(cur, wrapi(cur + 1, 0, screens.size()))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in screens.size():
			if _tab_rect(i).has_point(event.position):
				if i != cur:
					_switch(cur, i)
				get_viewport().set_input_as_handled()
				return


func _switch(from: int, to: int) -> void:
	if from in [0, 1]:
		screens[from]._toggle()
	else:
		screens[from].visible = false
	if to in [0, 1]:
		screens[to]._toggle()
	else:
		screens[to].visible = true
	get_tree().paused = true
	Sfx.play(&"ui_click", Vector3.ZERO, -6.0)


func _tab_rect(i: int) -> Rect2:
	var cur := _current()
	if cur in [0, 1] and screens[cur]._paired_menu():
		return screens[cur]._r(Art.tab_rect(i))
	var w := 150.0
	var x := size.x * 0.5 - w * screens.size() * 0.5 + i * w
	return Rect2(x, 4, w - 6, 28)


func _draw() -> void:
	var cur := _current()
	if cur < 0 or (cur == 0 and screens[0].get("_context") != &""):
		return
	var font := get_theme_default_font()
	var artwork: bool = cur in [0, 1] and screens[cur]._paired_menu()
	for i in screens.size():
		var r := _tab_rect(i)
		var on := i == cur
		if not artwork:
			Style.slot(self, r, 1.0, on)
		else:
			draw_rect(r, Color(0.025, 0.028, 0.03, 0.94))
			draw_rect(r, Color(0.73, 0.66, 0.50) if on else Color(0.31, 0.30, 0.27), false, 1)
		var text := "%s  %s" % [Loc.t(TITLES[i]), Loc.keys(KEYS[i])]
		var fs: int = roundi(19 * screens[cur]._scale) if artwork else 13
		var y := r.get_center().y + fs * 0.35 if artwork else r.position.y + 19
		draw_string(font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs,
				Color(1, 0.92, 0.8) if on else Color(0.7, 0.68, 0.64))
	# Подсказка про L1 / R1 (только на геймпаде).
	if Loc.using_gamepad:
		var l := _tab_rect(0)
		var rr := _tab_rect(screens.size() - 1)
		var lb := "L1" if Loc.playstation_pad else "LB"
		var rb := "R1" if Loc.playstation_pad else "RB"
		draw_string(font, Vector2(l.position.x - 40, l.position.y + 19), "◀ " + lb, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
		draw_string(font, Vector2(rr.end.x + 8, rr.position.y + 19), rb + " ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
