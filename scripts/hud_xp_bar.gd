extends Control
## Тонкая полоса опыта внизу по центру экрана, как в PoE 2, и уровень персонажа.

@export var fill_color := Color(0.85, 0.75, 0.4)
@export var back_color := Color(0.04, 0.04, 0.05, 0.75)

var player: Node


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var bar := Rect2(Vector2(0, size.y - 6.0), Vector2(size.x, 6.0))
	draw_rect(bar, back_color)
	var need: int = player.xp_for_next_level()
	var ratio := 1.0 if player.is_max_level() else float(player.xp) / maxf(float(need), 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill_color)
	draw_rect(bar, Color(1, 1, 1, 0.25), false, 1.0)
	for i in range(1, 10):
		var x := bar.size.x * i / 10.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.5), 1.0)
	var font := ThemeDB.fallback_font
	var text := "Уровень %d" % player.level
	if player.is_max_level():
		text += "  ·  максимум для демо"
	else:
		text += "  ·  опыт %d / %d" % [player.xp, need]
	text = Loc.t(text)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, Vector2((size.x - w) * 0.5, bar.position.y - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
	draw_string(font, Vector2((size.x - w) * 0.5, bar.position.y - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, fill_color)
