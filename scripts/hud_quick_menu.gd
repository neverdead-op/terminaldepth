extends Control
## Меню-крестовина слева внизу: верх — аптечка, слева и справа — два слота оружия.
## Совпадает с крестовиной геймпада. Выбранное оружие — светлый увеличенный ромб.
## Всё рисуется кодом (_draw), картинки иконок не нужны. Перерисовка только когда что-то изменилось.

@export var spacing := 38.0  ## расстояние от центра до ромбов
@export var diamond_size := 20.0  ## полуразмер ромба
@export var selected_scale := 1.15
@export var fill_color := Color(0.04, 0.05, 0.06, 0.78)
@export var border_color := Color(1, 1, 1, 0.38)
@export var selected_color := Color(0.95, 0.95, 0.93, 0.97)
@export var icon_color := Color(0.92, 0.94, 0.96)
@export var empty_color := Color(1, 1, 1, 0.25)

const UiIcons := preload("res://scripts/ui_icons.gd")

## Ромбы оружия в порядке слотов: слева и справа.
const SLOT_OFFSETS := [Vector2(-1, 0), Vector2(1, 0)]

var player: Node
var _scales := [1.0, 1.0]
var _last_state := ""


func _process(delta: float) -> void:
	if player == null:
		return
	var selected: int = player.current_weapon_index()
	var animating := false
	for i in PlayerInventory.WEAPON_COUNT:
		var target := selected_scale if i == selected else 1.0
		_scales[i] = move_toward(_scales[i], target, delta * 3.0)
		animating = animating or not is_equal_approx(_scales[i], target)
	var state := "%d|%.2f|%s|%s" % [selected, player.flask_charges, player.weapon_item(0), player.weapon_item(1)]
	if true:
		_last_state = state
		queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var center := size * 0.5
	var font := ThemeDB.fallback_font

	# Тонкие линии-«крестовина» за ромбами.
	var line := Color(1, 1, 1, 0.12)
	draw_line(center + Vector2(-spacing, 0), center + Vector2(spacing, 0), line, 1.0)
	draw_line(center + Vector2(0, -spacing), center + Vector2(0, spacing), line, 1.0)

	# Аптечка (верх). Если целого заряда нет — иконка тусклая, ромб «наполняется» по дробной части.
	var flask_pos := center + Vector2(0, -spacing)
	var charges: float = player.flask_charges
	var flask_ready := charges >= 1.0
	_draw_diamond(flask_pos, diamond_size, false)
	var part := charges - floorf(charges)
	if part > 0.01:
		_draw_diamond_fill_part(flask_pos, diamond_size - 4.0, part, Color(0.45, 0.9, 0.6, 0.35))
	_draw_cross(flask_pos, diamond_size * 0.42, icon_color if flask_ready else empty_color)
	draw_string(font, flask_pos + Vector2(diamond_size * 0.55, diamond_size * 0.75), str(int(floorf(charges))),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, icon_color if flask_ready else empty_color)

	# Оружие.
	var selected: int = player.current_weapon_index()
	for i in PlayerInventory.WEAPON_COUNT:
		var pos: Vector2 = center + SLOT_OFFSETS[i] * spacing
		var s: float = diamond_size * _scales[i]
		var data: WeaponData = player.weapon_data(i)
		var has_weapon := data != null
		var is_selected := has_weapon and i == selected
		_draw_diamond(pos, s, is_selected)
		if has_weapon:
			var color := Color(0.08, 0.09, 0.1) if is_selected else icon_color
			var box := Rect2(pos - Vector2(s * 1.2, s * 0.7), Vector2(s * 2.4, s * 1.4))
			var tex := UiIcons.texture(player.weapon_item(i).icon_path())
			if tex != null:
				UiIcons.draw_texture_fit(self, tex, box.grow(s * 0.25), Color.WHITE, -30.0)
			else:
				UiIcons.draw_weapon_picture(self, data, box, Color.WHITE, -35.0)

	# Центр.
	_draw_cross(center, 7.0, Color(1, 1, 1, 0.8))
	_draw_skills()


## Навыки справа от крестовины: граната (заряды) и ударная волна (перезарядка кругом).
func _draw_skills() -> void:
	var skills = player.get_node_or_null("Skills")
	if skills == null:
		return
	var font := ThemeDB.fallback_font
	var base := size * 0.5 + Vector2(spacing * 5.2, spacing * 0.35)
	var items := [
		["G / RB", skills.grenades > 0, 1.0 - skills.grenade_timer / skills.recharge_time() if skills.grenades < skills.max_grenades() else 1.0, str(skills.grenades), Color(1.0, 0.55, 0.25)],
		["V / LB", skills.nova_timer <= 0.0, 1.0 - skills.nova_timer / skills.nova_cooldown, "", Color(0.45, 0.75, 1.0)],
	]
	for i in items.size():
		var it: Array = items[i]
		var p: Vector2 = base + Vector2(i * 36.0, 0)
		var r := 14.0
		draw_circle(p, r, Color(0.04, 0.05, 0.06, 0.8))
		draw_arc(p, r, -PI / 2, -PI / 2 + TAU * clampf(it[2], 0.0, 1.0), 24, it[4] if it[1] else Color(it[4], 0.5), 2.5, true)
		if i == 0:
			draw_circle(p, 5.0, it[4] if it[1] else Color(it[4], 0.3))
		else:
			draw_arc(p, 6.0, 0, TAU, 16, it[4] if it[1] else Color(it[4], 0.3), 2.0, true)
		if it[3] != "":
			draw_string(font, p + Vector2(7, 14), it[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(font, p + Vector2(-16, -18), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.5))


func _diamond_points(pos: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, 0), pos + Vector2(0, s), pos + Vector2(-s, 0)])


func _draw_diamond(pos: Vector2, s: float, selected: bool) -> void:
	var points := _diamond_points(pos, s)
	draw_colored_polygon(points, selected_color if selected else fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(1, 1, 1, 0.9) if selected else border_color, 1.5, true)
	if not selected:
		var inner := _diamond_points(pos, s - 4.0)
		inner.append(inner[0])
		draw_polyline(inner, Color(1, 1, 1, 0.08), 1.0, true)


## Заполнение ромба снизу вверх на долю amount (0..1) — прогресс следующего заряда аптечки.
func _draw_diamond_fill_part(pos: Vector2, s: float, amount: float, color: Color) -> void:
	var y_cut := pos.y + s - 2.0 * s * amount
	var poly := PackedVector2Array()
	var pts := _diamond_points(pos, s)
	# Обрезаем ромб горизонтальной линией y_cut, оставляя нижнюю часть.
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		if a.y >= y_cut:
			poly.append(a)
		if (a.y - y_cut) * (b.y - y_cut) < 0.0:
			var t := (y_cut - a.y) / (b.y - a.y)
			poly.append(a.lerp(b, t))
	if poly.size() >= 3:
		draw_colored_polygon(poly, color)


func _draw_cross(pos: Vector2, r: float, color: Color) -> void:
	var w := r * 0.36
	draw_rect(Rect2(pos.x - r, pos.y - w, r * 2.0, w * 2.0), color)
	draw_rect(Rect2(pos.x - w, pos.y - r, w * 2.0, r * 2.0), color)
