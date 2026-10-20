extends Control
const Style := preload("res://scripts/ui_style.gd")
## Подсказка действия прямо над объектом: значок клавиши (F, ПКМ, ○, □ … — для текущего устройства)
## и что произойдёт («Открыть сундук», «Поднять: …»). Объект — ближайший интерактивный (сундук, робот,
## торговец) или подсвеченная вещь на полу.

@export var font_size := 15
@export var accent := Color(0.3, 0.85, 1.0)

var player: Node3D
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var target: Node3D = player.nearest_interactable()
	var key := ""
	var text := ""
	var height := 1.7
	if target != null:
		key = Loc.action_key("interact")
		text = Loc.npc_name(target.prompt)
		height = target.get("prompt_height") if target.get("prompt_height") != null else 1.7
	else:
		return
	if target == null:
		return
	var at := target.global_position + Vector3.UP * height
	if camera.is_position_behind(at):
		return
	var font := Loc.MAIN_FONT
	var p := camera.unproject_position(at)
	# Клавиши: «X / ПКМ» — несколько значков подряд.
	var keys := key.split(" / ")
	var key_w := []
	var total := 0.0
	for k in keys:
		var kw := maxf(font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0, 18.0)
		key_w.append(kw)
		total += kw + 3.0
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10.0
	var h := 25.0
	var x := p.x - (total + text_w) * 0.5
	var y := p.y - h
	var bounce := sin(_pulse * 4.0) * 1.0
	y += bounce
	for i in keys.size():
		var r := Rect2(x, y, key_w[i], h)
		Style.slot(self, r)
		draw_string(font, Vector2(x, y + 17), keys[i], HORIZONTAL_ALIGNMENT_CENTER, key_w[i], font_size, Style.GOLD)
		x += key_w[i] + 3.0
	var tr := Rect2(x, y + 1, text_w, h - 2)
	Style.nameplate(self, tr, Style.GOLD)
	draw_string(font, Vector2(x + 8, y + 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Style.TEXT)
	# Хвостик к объекту.
	draw_line(Vector2(p.x, y + h + bounce * 0.0), Vector2(p.x, p.y + 6), Color(accent, 0.5), 1.0)
