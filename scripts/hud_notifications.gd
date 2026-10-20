extends Control
## Лента сообщений слева сверху: небольшие тёмные плашки с цветной полосой слева (сообщения, задания,
## новый уровень). Новая плашка выезжает сверху, старые сдвигаются вниз и гаснут сами. Не больше max_cards.

@export var card_width := 310.0
@export var font_size := 13
@export var sub_font_size := 12
@export var max_cards := 2
@export var accent := Color(0.78, 0.66, 0.43)
@export var background := Color(0.025, 0.023, 0.022, 0.94)

var _cards: Array = []  # {text, sub, color, time, duration, y}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Показать плашку. sub — вторая строка мельче (необязательно).
func push(text: String, color := Color(0, 0, 0, 0), sub := "", duration := 4.0) -> void:
	text = Loc.t(text)
	if sub != "":
		sub = Loc.t(sub)
	# То же сообщение уже на экране — просто продлеваем его.
	for card in _cards:
		if card.text == text and card.sub == sub:
			card.time = minf(card.time, 0.3)
			return
	_cards.push_front({"text": text, "sub": sub, "color": accent if color.a == 0.0 else color,
			"time": 0.0, "duration": duration, "y": -40.0})
	while _cards.size() > max_cards:
		_cards.pop_back()


func _process(delta: float) -> void:
	if _cards.is_empty():
		return
	var y := 0.0
	for card in _cards:
		card.time += delta
		card.y = lerpf(card.y, y, 1.0 - exp(-14.0 * delta))
		y += _card_height(card) + 6.0
	_cards = _cards.filter(func(c: Dictionary) -> bool: return c.time < c.duration + 0.6)
	queue_redraw()


func _card_height(card: Dictionary) -> float:
	var font := get_theme_default_font()
	var h := font.get_multiline_string_size(card.text, HORIZONTAL_ALIGNMENT_LEFT, card_width - 26, font_size).y
	if card.sub != "":
		h += font.get_multiline_string_size(card.sub, HORIZONTAL_ALIGNMENT_LEFT, card_width - 26, sub_font_size).y + 2
	return h + 14.0


func _draw() -> void:
	var font := get_theme_default_font()
	for card in _cards:
		var appear := clampf(card.time / 0.18, 0.0, 1.0)
		var fade := 1.0 - clampf((card.time - card.duration) / 0.6, 0.0, 1.0)
		var a := appear * fade
		var x := -24.0 * (1.0 - ease(appear, 0.4))
		var h := _card_height(card)
		var rect := Rect2(x, card.y, card_width, h)
		var c: Color = card.color
		draw_rect(rect, Color(background, background.a * a))
		draw_rect(rect.grow(-2), Color(0.52, 0.39, 0.24, 0.65 * a), false, 1.0)
		draw_rect(Rect2(x, card.y, 3, h), Color(c, a))
		var ty: float = card.y + 7 + font.get_ascent(font_size)
		draw_multiline_string(font, Vector2(x + 14, ty), card.text, HORIZONTAL_ALIGNMENT_LEFT, card_width - 26,
				font_size, -1, Color(0.93, 0.9, 0.84, a))
		if card.sub != "":
			var main_h := font.get_multiline_string_size(card.text, HORIZONTAL_ALIGNMENT_LEFT, card_width - 26, font_size).y
			draw_multiline_string(font, Vector2(x + 14, ty + main_h + 2), card.sub, HORIZONTAL_ALIGNMENT_LEFT,
					card_width - 26, sub_font_size, -1, Color(c.lightened(0.3), 0.9 * a))
