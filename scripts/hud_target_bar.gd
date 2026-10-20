extends Control
## Полоска цели сверху по центру, как в PoE 2: имя врага цветом редкости, здоровье,
## значки свойств и состояний (горит, шок, кислота), у синих и жёлтых — описание свойств.
## Показывает последнего врага, по которому попал игрок (Enemy.last_target).

const Style := preload("res://scripts/ui_style.gd")
const Mods := preload("res://scripts/monster_mods.gd")
const Frame := preload("res://scripts/health_bar_frame.gd")
const Typography := preload("res://scripts/ui_typography.gd")

## Сколько секунд держать полоску после последнего попадания.
@export var show_time := 6.0
@export var bar_size := Vector2(190, 5)
@export var boss_bar_size := Vector2(330, 8)
@export var fill_color := Color(0.62, 0.08, 0.06)
@export var trail_color := Color(0.95, 0.85, 0.7, 0.8)
@export var frame_color := Color(0.62, 0.52, 0.34)

const STATUS := {
	&"fire": {"icon": &"flame", "color": Color(1.0, 0.55, 0.15), "text": "Горит"},
	&"electric": {"icon": &"bolt", "color": Color(0.5, 0.75, 1.0), "text": "Шок"},
	&"acid": {"icon": &"drop", "color": Color(0.55, 1.0, 0.25), "text": "Разъеден"},
}

var _target: Enemy
var _trail := 1.0
var _alpha := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	var target := Enemy.last_target
	var fresh := is_instance_valid(target) and target.has_method("is_dead") and \
			(Time.get_ticks_msec() - Enemy.last_target_msec) < show_time * 1000.0
	if fresh and target != _target:
		_target = target
		_trail = clampf(target.hp / target.max_hp, 0.0, 1.0)
	var want := 1.0 if fresh and not target.is_dead() else 0.0
	_alpha = move_toward(_alpha, want, delta * (6.0 if want > 0.0 else 2.0))
	if is_instance_valid(_target):
		var ratio := clampf(_target.hp / _target.max_hp, 0.0, 1.0)
		_trail = move_toward(_trail, ratio, delta * 0.6) if _trail > ratio else ratio
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01 or not is_instance_valid(_target):
		return
	modulate.a = _alpha
	var w := size.x
	var boss := _target.guards_exit or _target.is_in_group("bosses")
	var dimensions := boss_bar_size if boss else bar_size
	var layout := Frame.target_layout(w * 0.5, dimensions.x, boss, dimensions.y)
	var bar: Rect2 = layout.bar
	var color: Color = Mods.RARITY_COLORS[_target.rarity]
	# Полоса здоровья: рамка, белый след урона, заливка.
	draw_rect(bar, Color(0, 0, 0, 0.85))
	var ratio := clampf(_target.hp / _target.max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)), trail_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y * 0.35)), Color(1, 1, 1, 0.12))
	Frame.draw_target(self, layout.panel, boss)
	# Имя, уровень и здоровье остаются живыми данными поверх рисунка.
	Typography.title_in_rect(self, _target.get_title(), layout.title_rect, 17 if boss else 13, Typography.GOLD if _target.rarity == 0 or boss else color)
	var level_box: Rect2 = layout.level_rect
	_center("ур. %d" % _target.level, Vector2(level_box.get_center().x, level_box.get_center().y + (_font.get_ascent(9) - _font.get_descent(9)) * 0.5), 9, Color(0.78, 0.76, 0.71))

	# Значки: свойства и состояния.
	var icons := []
	for id in _target.mods:
		icons.append([Mods.MODS[id]["icon"], Mods.MODS[id]["color"]])
	for s in _target.status_list():
		icons.append([STATUS[s]["icon"], STATUS[s]["color"]])
	var icon_size := 15.0
	var x := w * 0.5 - icons.size() * (icon_size + 4) * 0.5
	for icon in icons:
		var r := Rect2(x, layout.panel.end.y + 5, icon_size, icon_size)
		_draw_icon(icon[0], r, icon[1])
		x += icon_size + 4
	# Описание свойств (как у Vileripper в PoE 2).
	var y: float = layout.panel.end.y + 5 + (icon_size + 12 if not icons.is_empty() else 10)
	for id in _target.mods:
		_center(Mods.MODS[id]["text"], Vector2(w * 0.5, y), 11, Color(0.75, 0.8, 1.0))
		y += 13


func _draw_icon(kind: StringName, r: Rect2, color: Color) -> void:
	var c := r.get_center()
	var h := r.size.x * 0.5
	# Ромб-подложка.
	var diamond := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
	draw_colored_polygon(diamond, Color(0.05, 0.05, 0.06, 0.9))
	diamond.append(diamond[0])
	draw_polyline(diamond, color.darkened(0.2), 1.5)
	var s := h * 0.5
	match kind:
		&"bolt", &"storm":
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.3, -s), c + Vector2(-s * 0.4, s * 0.1),
				c + Vector2(s * 0.4, -s * 0.1), c + Vector2(-s * 0.3, s)]), color, 2.0)
			if kind == &"storm":
				draw_arc(c + Vector2(0, -s * 0.9), s * 0.7, PI, TAU, 8, color, 1.5)
		&"flame":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, s * 0.4),
				c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.4)]), color)
		&"drop":
			draw_circle(c + Vector2(0, s * 0.3), s * 0.6, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.55, s * 0.1),
				c + Vector2(-s * 0.55, s * 0.1)]), color)
		&"speed":
			for i in 2:
				var o := Vector2(-s * 0.4 + i * s * 0.6, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.3, -s * 0.6), c + o + Vector2(s * 0.3, 0),
					c + o + Vector2(-s * 0.3, s * 0.6)]), color, 2.0)
		&"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, -s * 0.7),
				c + Vector2(s * 0.6, s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.6, s * 0.2)]), color)
		&"heart":
			draw_circle(c + Vector2(-s * 0.35, -s * 0.2), s * 0.42, color)
			draw_circle(c + Vector2(s * 0.35, -s * 0.2), s * 0.42, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.75, 0), c + Vector2(s * 0.75, 0),
				c + Vector2(0, s * 0.85)]), color)
		&"claw":
			for i in 3:
				var o := Vector2((i - 1) * s * 0.45, 0)
				draw_line(c + o + Vector2(s * 0.3, -s * 0.8), c + o + Vector2(-s * 0.3, s * 0.8), color, 2.0)
		&"plus":
			draw_rect(Rect2(c - Vector2(s * 0.2, s * 0.8), Vector2(s * 0.4, s * 1.6)), color)
			draw_rect(Rect2(c - Vector2(s * 0.8, s * 0.2), Vector2(s * 1.6, s * 0.4)), color)
		&"burst":
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.25, c + Vector2(cos(a), sin(a)) * s * 0.9, color, 2.0)
		_:
			draw_circle(c, s * 0.5, color)


func _center(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	text = Loc.t(text)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var p := pos - Vector2(tw * 0.5, 0)
	draw_string(_font, p + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.9))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
