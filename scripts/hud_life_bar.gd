extends Control
## Полоска здоровья справа внизу: красная — Life, поверх неё синий слой — Energy Shield (тратится первым).
## Белый след показывает только что потерянное здоровье, светло-красный — сколько ещё вольёт аптечка.

@export var life_color := Color(0.72, 0.07, 0.08)
@export var life_light := Color(0.95, 0.3, 0.26)
@export var trail_color := Color(1.0, 0.92, 0.85, 0.85)
@export var heal_color := Color(1.0, 0.5, 0.5, 0.45)
@export var es_color := Color(0.35, 0.72, 1.0)
@export var frame_color := Color(0.62, 0.52, 0.34)
## Как быстро белый след догоняет здоровье (доля в секунду).
@export var trail_speed := 0.5

var player: Node
var _trail := 1.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	if player == null:
		return
	var ratio: float = clampf(player.hp / player.max_hp, 0.0, 1.0)
	_trail = move_toward(_trail, ratio, trail_speed * delta) if _trail > ratio else ratio
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var w := size.x
	var life := Rect2(0, 0, w, 18)
	var has_es: bool = player.max_es > 0.0
	# Здоровье: подложка, белый след урона, лечение от аптечки, заливка, блик.
	var ratio: float = clampf(player.hp / player.max_hp, 0.0, 1.0)
	var heal: float = clampf(player.pending_heal() / player.max_hp, 0.0, 1.0 - ratio)
	draw_rect(life.grow(3), Color(0.03, 0.02, 0.02, 0.85))
	draw_rect(Rect2(life.position, Vector2(w * _trail, life.size.y)), trail_color)
	draw_rect(Rect2(life.position + Vector2(w * ratio, 0), Vector2(w * heal, life.size.y)), heal_color)
	draw_rect(Rect2(life.position, Vector2(w * ratio, life.size.y)), life_color)
	draw_rect(Rect2(life.position, Vector2(w * ratio, life.size.y * 0.35)), Color(life_light, 0.35))
	# Energy Shield — слой поверх здоровья (как в PoE 2): он тратится первым.
	if has_es:
		var es_ratio: float = clampf(player.es / player.max_es, 0.0, 1.0)
		var es_rect := Rect2(life.position, Vector2(w * es_ratio, life.size.y))
		draw_rect(es_rect, Color(0.2, 0.55, 1.0, 0.82))
		draw_rect(Rect2(es_rect.position, Vector2(es_rect.size.x, 3)), Color(0.8, 0.95, 1.0, 0.9))
	for i in range(1, 10):
		var x := w * i / 10.0
		draw_line(Vector2(x, life.position.y), Vector2(x, life.end.y), Color(0, 0, 0, 0.35), 1.0)
	draw_rect(life.grow(3), frame_color, false, 1.5)
	# Числа: слева — Life, справа — Energy Shield.
	var fs := 11
	var y := life.position.y + life.size.y * 0.5 + fs * 0.36
	_text("Life %d / %d" % [ceili(player.hp), int(player.max_hp)], Vector2(8, y), fs, false)
	if has_es:
		_text("Energy Shield %d / %d" % [ceili(player.es), int(player.max_es)], Vector2(w - 8, y), fs, true)


func _text(text: String, at: Vector2, fs: int, right: bool) -> void:
	if right:
		at.x -= _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.9))
