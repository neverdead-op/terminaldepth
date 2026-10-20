extends RefCounted
## Римские заглавные с засечками; длинное название уменьшается внутри своей плашки.
const GOLD := Color(0.94, 0.82, 0.53)
static func title(ci: CanvasItem, text: String, baseline: Vector2, size_px: int, color: Color, max_width: float) -> void:
	text = Loc.t(text).to_upper()
	var font := Loc.TITLE_FONT
	var fs := maxi(9, size_px)
	while fs > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_width:
		fs -= 1
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_width:
		while text.length() > 1 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_width:
			text = text.substr(0, text.length() - 1)
		text += "…"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := (baseline - Vector2(width * 0.5, 0)).round()
	emboss(ci, font, at, text, fs, color, max_width)

## Тёмный нижний край и светлая верхняя грань дают мягкое тиснение без толстой обводки.
static func emboss(ci: CanvasItem, font: Font, at: Vector2, text: String, fs: int, color: Color, max_width := -1.0) -> void:
	ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fs, 1, Color(0, 0, 0, 0.85))
	ci.draw_string(font, at + Vector2(0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fs, Color(0, 0, 0, 0.9))
	ci.draw_string(font, at + Vector2(0, -0.6), text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fs, Color(color.lightened(0.4), color.a * 0.55))
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fs, color)

static func title_in_rect(ci: CanvasItem, text: String, box: Rect2, size_px: int, color: Color) -> void:
	text = Loc.t(text).to_upper()
	var fs := maxi(9, size_px)
	while fs > 9 and Loc.TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > box.size.x:
		fs -= 1
	var baseline := box.get_center() + Vector2(0, (Loc.TITLE_FONT.get_ascent(fs) - Loc.TITLE_FONT.get_descent(fs)) * 0.5)
	title(ci, text, baseline, fs, color, box.size.x)
