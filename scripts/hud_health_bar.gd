extends Control
## Полоска ХП справа внизу. Скошенные края в стиле меню.
## Белый «след» плавно догоняет после урона, зелёным показано лечение, которое ещё «дольётся».

@export var fill_color := Color(0.86, 0.18, 0.2)
@export var trail_color := Color(1, 1, 1, 0.75)
@export var heal_color := Color(0.4, 0.95, 0.55, 0.55)
@export var back_color := Color(0.04, 0.05, 0.06, 0.78)
@export var border_color := Color(1, 1, 1, 0.38)
## Как быстро белый след догоняет текущее ХП (доля полоски в секунду).
@export var trail_speed := 0.5
## Пауза перед тем, как след начнёт догонять (сек).
@export var trail_delay := 0.4
@export var slant := 10.0  ## скос краёв, пикселей
@export var es_color := Color(0.35, 0.7, 1.0)

var player: Node
var _trail := 1.0
var _trail_wait := 0.0
var _last_ratio := 1.0


func _process(delta: float) -> void:
	if player == null:
		return
	var ratio: float = player.hp / player.max_hp
	if ratio < _last_ratio:
		_trail_wait = trail_delay
	_last_ratio = ratio
	if _trail < ratio:
		_trail = ratio
	elif _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		_trail = move_toward(_trail, ratio, trail_speed * delta)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var bar := Rect2(Vector2(0, size.y - 16.0), Vector2(size.x, 16.0))
	var ratio: float = player.hp / player.max_hp
	var heal: float = player.pending_heal() / player.max_hp

	_slanted(bar, 0.0, 1.0, back_color)
	_slanted(bar, ratio, _trail, trail_color)
	_slanted(bar, ratio, minf(ratio + heal, 1.0), heal_color)
	_slanted(bar, 0.0, ratio, fill_color)
	var outline := _slanted_points(bar, 0.0, 1.0)
	outline.append(outline[0])
	draw_polyline(outline, border_color, 1.5, true)

	var font := ThemeDB.fallback_font
	var text := "%d / %d" % [ceili(player.hp), int(player.max_hp)]
	var text_y := bar.position.y - 8.0
	# Энергощит — тонкая синяя полоса над ХП (принимает урон первым).
	if player.max_es > 0.0:
		var es_bar := Rect2(Vector2(0, bar.position.y - 10.0), Vector2(size.x, 7.0))
		_slanted(es_bar, 0.0, 1.0, back_color)
		_slanted(es_bar, 0.0, player.es / player.max_es, es_color)
		draw_string(font, Vector2(0, es_bar.position.y - 6.0), "Energy Shield %d / %d" % [ceili(player.es), int(player.max_es)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, es_color)
		text_y = es_bar.position.y - 6.0
	draw_string(font, Vector2(0, text_y), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 18,
			Color(0.9, 0.93, 1.0))


## Кусок полоски от доли a до доли b (0..1) в форме параллелограмма.
func _slanted(bar: Rect2, a: float, b: float, color: Color) -> void:
	if b - a <= 0.001:
		return
	draw_colored_polygon(_slanted_points(bar, a, b), color)


func _slanted_points(bar: Rect2, a: float, b: float) -> PackedVector2Array:
	var w := bar.size.x - slant
	var x0 := bar.position.x + w * a
	var x1 := bar.position.x + w * b
	var top := bar.position.y
	var bottom := bar.end.y
	return PackedVector2Array([Vector2(x0 + slant, top), Vector2(x1 + slant, top), Vector2(x1, bottom), Vector2(x0, bottom)])
