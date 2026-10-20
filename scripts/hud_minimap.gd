extends Control
const Style := preload("res://scripts/ui_style.gd")
## Мини-карта в правом верхнем углу: комнаты и коридоры открываются, когда игрок к ним подходит.
## Игрок — стрелка в центре, выход — голубой квадрат (когда его комната открыта).
## Берёт план у уровня (zone.gd: map_rects, exit_position). На уровнях без плана скрыта.

## Сколько пикселей на метр.
@export var map_scale := 1.8
## С какого расстояния комната открывается на карте (м).
@export var reveal_distance := 16.0
## Заливка пола (непрозрачная — наложения прямоугольников не видно) и контур краёв.
@export var floor_color := Color(0.12, 0.12, 0.115, 1.0)
@export var edge_color := Color(0.67, 0.57, 0.39, 0.9)
@export var back_color := Color(0.015, 0.017, 0.022, 0.88)
@export var enemy_color := Color(1.0, 0.2, 0.15)
## Насколько далеко враги видны на карте (м). Дальше — только стрелка к ближайшему скоплению.
@export var enemy_radius := 40.0

var player: Node3D
var _rects: Array[Rect2] = []
var _revealed: Array[bool] = []
var _exit := Vector2.ZERO
var _exit_known := false
var _check_left := 0.0
var _level: Node
## Враги для карты: точки (x, z) и кто из них босс; обновляется раз в 0.3 с.
var _enemy_points: Array[Vector2] = []
var _boss_points: Array[Vector2] = []
## Роботы-союзники: [точка, включён ли].
var _ally_points: Array = []
## Цели заданий: [точка, цвет] — ключ-карта, обелиски, инкубаторы, разлом, отключённые роботы.
var _quest_points: Array = []
## Куда показывать стрелку: центр ближайшего скопления врагов за краем карты.
var _cluster := Vector2.INF


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_load_map.call_deferred()  # сцена уровня ещё не назначена, пока HUD готовится


func _load_map() -> void:
	set_process(true)
	var level := player.get_parent()  # уровень — тот узел, в котором стоит игрок
	_level = level
	if level == null or not "map_rects" in level:
		visible = false
		return
	visible = true
	if level.has_meta("minimap_revealed"):
		# Вернулись в ту же зону — открытые комнаты помним.
		_rects = level.map_rects
		_exit = level.exit_position
		_revealed = level.get_meta("minimap_revealed")
		_exit_known = level.get_meta("minimap_exit_known", false)
		return
	_rects = level.map_rects
	_exit = level.exit_position
	_revealed = []
	_revealed.resize(_rects.size())
	_revealed.fill(false)


func _process(delta: float) -> void:
	if player.get_parent() != _level:
		if _level != null and is_instance_valid(_level) and "map_rects" in _level:
			_level.set_meta("minimap_revealed", _revealed)
			_level.set_meta("minimap_exit_known", _exit_known)
		_load_map()
	if not visible:
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.3
		var p := Vector2(player.global_position.x, player.global_position.z)
		_scan_enemies(p)
		for i in _rects.size():
			if not _revealed[i] and _distance_to_rect(p, _rects[i]) < reveal_distance:
				_revealed[i] = true
				if _rects[i].has_point(_exit):
					_exit_known = true
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 11.0
	var p := Vector2(player.global_position.x, player.global_position.z)
	# Квадратная область обзора внутри реликварной рамы.
	var viewport := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	draw_rect(viewport, back_color)
	# Открытые залы: обводка и заливка обрезаются по внутреннему квадрату.
	for pass_i in 2:
		for i in _rects.size():
			if not _revealed[i]:
				continue
			var r := Rect2(center + (_rects[i].position - p) * map_scale, _rects[i].size * map_scale)
			if pass_i == 0:
				r = r.grow(1.5)
			if r.position.distance_to(center) > radius * 4.0 and not r.has_point(center) \
					and not Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2).intersects(r):
				continue
			var clipped := r.intersection(viewport)
			if clipped.has_area(): draw_rect(clipped, edge_color if pass_i == 0 else floor_color)
	for k in 3:
		var gap := (k + 1) * radius * 0.5
		for axis in [Vector2.RIGHT, Vector2.DOWN]:
			var at: Vector2 = viewport.position + axis * gap
			draw_line(at, at + axis.orthogonal().abs() * radius * 2, Color(edge_color, 0.08), 1.0)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(edge_color, 0.08), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(edge_color, 0.08), 1.0)
	if _exit_known:
		_marker(center, radius, _exit - p, Color(0.3, 0.85, 1.0), "square")
	# Враги — красные точки (босс — крупнее).
	for e in _enemy_points:
		var q := center + (e - p) * map_scale
		if viewport.grow(-3).has_point(q):
			draw_circle(q, 2.2, enemy_color)
	for bp in _boss_points:
		_marker(center, radius, bp - p, Color(1.0, 0.75, 0.2), "circle")
	# Задания: ключ-карта — всегда (жёлтый ромб), остальное — когда зал открыт.
	for qp in _quest_points:
		_marker(center, radius, qp[0] - p, qp[1], "diamond")
	if _cluster != Vector2.INF:
		var d := (_cluster - p).normalized()
		var edge := center + d / maxf(absf(d.x), absf(d.y)) * (radius - 9.0)
		var sd := d.orthogonal()
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		draw_colored_polygon(PackedVector2Array([edge + d * 8, edge - d * 4 + sd * 6, edge - d * 4 - sd * 6]),
				Color(enemy_color, pulse))
	# Стрелка игрока по направлению взгляда (−Z — вверх по экрану).
	var forward := -player.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + dir * 8, center - dir * 5 + side * 5, center - dir * 5 - side * 5]),
			Color(1, 1, 1))
	draw_string(get_theme_default_font(), center + Vector2(-5, -radius + 17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.6, 0.95, 1.0))
	# Художественная рама не закрывает живые данные карты.
	Style.art(self, "minimap", Rect2(Vector2.ZERO, size))


## Значок за пределами карты прижат к стороне квадрата (подсказка, куда идти).
func _marker(center: Vector2, radius: float, offset: Vector2, color: Color, shape: String) -> void:
	var q := center + offset * map_scale
	var delta := q - center
	var edge := maxf(absf(delta.x), absf(delta.y)) > radius - 7.0
	if edge:
		q = center + delta / maxf(absf(delta.x), absf(delta.y)) * (radius - 7.0)
	var r := 6.0
	match shape:
		"square":
			draw_rect(Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0), color)
		"circle":
			draw_circle(q, r + 1.0, Color(0, 0, 0, 0.7))
			draw_circle(q, r, color)
		_:
			var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
			var rr := r * pulse
			var dia := PackedVector2Array([q + Vector2(0, -rr - 1), q + Vector2(rr + 1, 0), q + Vector2(0, rr + 1),
					q + Vector2(-rr - 1, 0)])
			draw_colored_polygon(dia, Color(0, 0, 0, 0.75))
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -rr), q + Vector2(rr, 0), q + Vector2(0, rr),
					q + Vector2(-rr, 0)]), color)


static func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _scan_enemies(p: Vector2) -> void:
	_enemy_points.clear()
	_boss_points.clear()
	_ally_points.clear()
	_quest_points.clear()
	for k in get_tree().get_nodes_in_group("quest_items"):
		_quest_points.append([Vector2(k.global_position.x, k.global_position.z), Color(1.0, 0.85, 0.2)])
	for group in [[&"ally_robots", Color(0.35, 0.85, 1.0)], [&"quest_obelisk", Color(1.0, 0.3, 0.25)],
			[&"quest_nest", Color(0.5, 1.0, 0.3)], [&"quest_seal", Color(0.85, 0.35, 1.0)]]:
		for node in get_tree().get_nodes_in_group(group[0]):
			if not node is Node3D or node.get("destroyed") == true or node.get("active") == true or node.get("spent") == true:
				continue
			var q := Vector2(node.global_position.x, node.global_position.z)
			if _is_revealed(q):
				_quest_points.append([q, group[1]])
	var escorting := false
	for node in get_tree().get_nodes_in_group("quest_escort"):
		if not node is Node3D or node.get("rescued") == true or node.get("failed") == true:
			continue
		if node.get("following") == true:
			escorting = true
		else:
			var q := Vector2(node.global_position.x, node.global_position.z)
			if _is_revealed(q):
				_quest_points.append([q, Color(0.35, 0.9, 1.0)])
	# Пока сотрудник идёт за героем, лифт всегда отмечен как цель маршрута.
	if escorting:
		_exit_known = true
	var outside: Array[Vector2] = []
	var half := size * 0.5 / map_scale
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D:
			continue
		var q := Vector2(e.global_position.x, e.global_position.z)
		if e.is_in_group("bosses"):
			_boss_points.append(q)
		# Туман войны: враги видны только в открытых залах.
		if not _is_revealed(q):
			continue
		if q.distance_squared_to(p) < enemy_radius * enemy_radius and q.distance_to(p) < half.x:
			_enemy_points.append(q)
		else:
			outside.append(q)
	# Ближайший к игроку враг вне карты — и центр стаи вокруг него.
	_cluster = Vector2.INF
	if _enemy_points.is_empty() and not outside.is_empty():
		var nearest := outside[0]
		for q in outside:
			if q.distance_squared_to(p) < nearest.distance_squared_to(p):
				nearest = q
		var sum := Vector2.ZERO
		var n := 0
		for q in outside:
			if q.distance_squared_to(nearest) < 100.0:
				sum += q
				n += 1
		_cluster = sum / n


func _is_revealed(q: Vector2) -> bool:
	for i in _rects.size():
		if _revealed[i] and _rects[i].has_point(q):
			return true
	return false


static func _distance_to_rect(p: Vector2, r: Rect2) -> float:
	var q := p.clamp(r.position, r.end)
	return p.distance_to(q)
