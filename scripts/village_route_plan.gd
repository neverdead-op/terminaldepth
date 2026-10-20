extends RefCounted
## План первого уровня SSF: из чего состоит пол деревни и где стоят ключевые точки.
## Координаты — Vector2(x, z) в метрах; путь идёт от старта (z≈8) к таверне (z≈-246).
## Три части: узкое начало с обучением → поляны с островами → петли вокруг площади привратника.
## Пол собирается из клеток 2×2 м, поэтому любые кривые формы превращаются в стены автоматически.

const CELL := 2

## Главный путь игрока: по нему кладётся булыжная дорога и ставятся фонари.
var route := PackedVector2Array([Vector2(0, 14), Vector2(0, -2), Vector2(-5, -14), Vector2(-6, -26), Vector2(1, -38), Vector2(6, -48), Vector2(2, -60), Vector2(0, -68), Vector2(0, -86), Vector2(-2, -104), Vector2(4, -124), Vector2(10, -140), Vector2(12, -158), Vector2(8, -174), Vector2(0, -190), Vector2(0, -214), Vector2(0, -246)])

## Отрезки дорожек: [от, до, полуширина]. Улицы — 12 м шириной, перешейки — 13 м, боковые тропы — 9 м.
var lanes := [
	[Vector2(0, 14), Vector2(0, -2), 7.0],
	[Vector2(0, -2), Vector2(-5, -14), 6.0],
	[Vector2(-5, -14), Vector2(-6, -26), 6.0],
	[Vector2(-6, -26), Vector2(1, -38), 6.0],
	[Vector2(1, -38), Vector2(6, -48), 6.0],
	[Vector2(6, -48), Vector2(2, -60), 6.0],
	[Vector2(0, -68), Vector2(0, -88), 6.0],  # горловина с дверью: уже ширины двери
	[Vector2(4, -124), Vector2(10, -140), 6.5],
	[Vector2(8, -174), Vector2(0, -192), 6.5],
	# Тупик могильщика к западу от первой поляны.
	[Vector2(-26, -104), Vector2(-50, -96), 4.5],
	# Обходная тропа: вторая дорога между полянами.
	[Vector2(16, -106), Vector2(32, -118), 4.5],
	[Vector2(32, -118), Vector2(28, -150), 4.5],
	# Тропа к ритуальному алтарю.
	[Vector2(30, -158), Vector2(50, -164), 6.0],
	# Площадь привратника: южный, западный и восточный проходы с кольца, северный к таверне.
	[Vector2(0, -192), Vector2(0, -206), 4.5],
	[Vector2(-20, -214), Vector2(-9, -214), 4.5],
	[Vector2(20, -214), Vector2(9, -214), 4.5],
	# Короткие проходы с кольца в рынок и двор часовни.
	[Vector2(-28, -214), Vector2(-20, -214), 4.5],
	[Vector2(28, -214), Vector2(20, -214), 4.5],
	[Vector2(0, -222), Vector2(0, -246), 6.5],
]

## Открытые пространства: [центр, радиусы (x, z), сила «рваного» края].
var blobs := [
	[Vector2(-6, -24), Vector2(11, 8), 0.12],    # карман первого отряда
	[Vector2(6, -46), Vector2(11, 8), 0.12],     # карман второго отряда
	[Vector2(0, -64), Vector2(13, 9), 0.10],    # дворик с сундуком перед дверью
	[Vector2(-4, -106), Vector2(26, 19), 0.16], # поляна 1: двор забытых могил
	[Vector2(-56, -94), Vector2(9, 8), 0.14],   # тупик могильщика
	[Vector2(12, -158), Vector2(23, 17), 0.16], # поляна 2: ритуальная роща
	[Vector2(56, -166), Vector2(10, 9), 0.12],  # алтарь
	[Vector2(0, -214), Vector2(11, 11), 0.05],  # площадь привратника
	[Vector2(-34, -214), Vector2(10, 12), 0.12],# заброшенный рынок
	[Vector2(34, -214), Vector2(10, 12), 0.12], # двор старой часовни
]

## Кольцо вокруг площади привратника: центр, внутренний и внешний радиус.
var ring_center := Vector2(0, -214)
var ring_radii := Vector2(16, 22)

var start := Vector2(0, 8)
var exit := Vector2(0, -241)
var tavern := Vector2(0, -247)
var gate := Vector2(0, -78)
var gate_chest := Vector2(-5, -66)
var boss := Vector2(0, -214)

## Острова — препятствия на открытых местах, вокруг которых удобно кружить в бою.
## [центр, размер (x, z), тип]: crypt — склеп в каменной ограде, tree — мёртвое дерево в камнях,
## rock — валун, column — колонна.
var islands := [
	[Vector2(-18, -98), Vector2(5, 4), &"crypt"],
	[Vector2(-24, -114), Vector2(4, 5), &"crypt"],
	[Vector2(-10, -118), Vector2(4, 3), &"crypt"],
	[Vector2(10, -98), Vector2(5, 4), &"crypt"],
	[Vector2(14, -114), Vector2(4, 4), &"crypt"],
	[Vector2(-12, -92), Vector2(2, 2), &"rock"],
	[Vector2(6, -110), Vector2(2, 2), &"rock"],
	[Vector2(0, -150), Vector2(3, 3), &"tree"],
	[Vector2(-4, -164), Vector2(3, 3), &"tree"],
	[Vector2(22, -150), Vector2(3, 3), &"tree"],
	[Vector2(24, -166), Vector2(3, 3), &"tree"],
	[Vector2(16, -170), Vector2(2, 2), &"rock"],
	[Vector2(-6, -208), Vector2(1, 1), &"column"],
	[Vector2(6, -208), Vector2(1, 1), &"column"],
	[Vector2(-6, -220), Vector2(1, 1), &"column"],
	[Vector2(6, -220), Vector2(1, 1), &"column"],
	[Vector2(-34, -218), Vector2(3, 2), &"rock"],
	[Vector2(34, -208), Vector2(4, 3), &"crypt"],
]

## Отряды врагов: центры групп. Первый — только простые противники (обучение).
## Лёгкое, среднее и сложное рядом: малые карманы, поляны, кольцо.
var packs := PackedVector2Array([
	# Первые ~50 м от старта — тихо: первый отряд у второго кармана.
	Vector2(6, -48), Vector2(-2, -64),
	Vector2(-8, -100), Vector2(4, -104), Vector2(-16, -108), Vector2(0, -116),
	Vector2(-54, -94), Vector2(30, -128),
	Vector2(6, -152), Vector2(14, -162), Vector2(4, -170), Vector2(20, -158),
	Vector2(56, -166),
	Vector2(-13, -201), Vector2(13, -201), Vector2(-13, -227), Vector2(13, -227),
	Vector2(-34, -212), Vector2(34, -216),
])

## Освещённые места: фонари вдоль пути и у важных объектов.
var lanterns := PackedVector2Array([Vector2(-4, 10), Vector2(4, 0), Vector2(-9, -14), Vector2(-11, -28), Vector2(10, -48), Vector2(-7, -62), Vector2(7, -62), Vector2(-4, -82), Vector2(4, -82), Vector2(-24, -102), Vector2(12, -126), Vector2(-56, -88), Vector2(34, -122), Vector2(28, -152), Vector2(56, -158), Vector2(-4, -186), Vector2(4, -186), Vector2(-14, -228), Vector2(14, -200), Vector2(-4, -236), Vector2(4, -236)])

## Области-ориентиры для задания «Исследуйте старые кварталы».
var landmark_rects: Array[Rect2] = [Rect2(-14, -116, 18, 14), Rect2(4, -164, 16, 12), Rect2(-40, -220, 12, 12), Rect2(28, -220, 12, 12)]
var landmark_names := PackedStringArray(["Двор забытых могил", "Ритуальная роща", "Заброшенный рынок", "Двор старой часовни"])
## Где положить покрытие «камень площади»; остальное вне дороги — земля.
var plazas: Array[Rect2] = [Rect2(-10, -72, 20, 14), Rect2(-12, -226, 24, 24), Rect2(24, -228, 20, 26)]

var chests := [Vector2(-60, -92), Vector2(-38, -206), Vector2(40, -222)]
var obelisks := [Vector2(-52, -100), Vector2(30, -214)]
var ritual := Vector2(58, -166)
var rifle_pickup := Vector2(8, -124)
var plasma_pickup := Vector2(-8, -158)
var support_pickup := Vector2(-4, -166)
## Пороги по z для подсказок: когда игрок проходит эту глубину.
var hint_gate_z := -60.0
var hint_quarters_z := -90.0
var hint_plasma_z := -150.0
var hint_support_z := -160.0
var hint_boss_z := -192.0
var fog_points := PackedVector2Array([Vector2(0, -10), Vector2(0, -64), Vector2(-6, -108), Vector2(12, -160), Vector2(0, -214)])
var signs := [["СТАРАЯ ОКРАИНА", Vector2(0, 14)], ["УЛИЦА ПОГАСШИХ ФОНАРЕЙ", Vector2(-6, -26)], ["ПЕПЕЛЬНЫЙ ПЕРЕУЛОК", Vector2(4, -124)]]

var cells := {}


## Собирает клетки пола. Мелкие «острова» пола, отрезанные от старта, отбрасываются.
func build(seed := 1907) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.09
	cells.clear()
	var min_corner := Vector2(INF, INF)
	var max_corner := Vector2(-INF, -INF)
	for lane in lanes:
		min_corner = min_corner.min((lane[0] as Vector2).min(lane[1]) - Vector2.ONE * (lane[2] + 3))
		max_corner = max_corner.max((lane[0] as Vector2).max(lane[1]) + Vector2.ONE * (lane[2] + 3))
	for blob in blobs:
		min_corner = min_corner.min(blob[0] - blob[1] * 1.4)
		max_corner = max_corner.max(blob[0] + blob[1] * 1.4)
	min_corner = min_corner.min(ring_center - Vector2.ONE * (ring_radii.y + 3))
	max_corner = max_corner.max(ring_center + Vector2.ONE * (ring_radii.y + 3))
	for x in range(int(floor(min_corner.x / CELL)) * CELL, int(ceil(max_corner.x)), CELL):
		for z in range(int(floor(min_corner.y / CELL)) * CELL, int(ceil(max_corner.y)), CELL):
			var c := Vector2(x + 1, z + 1)
			if _inside(c, noise):
				cells[Vector2i(x, z)] = true
	_keep_connected()
	return cells


func _inside(c: Vector2, noise: FastNoiseLite) -> bool:
	var wobble := noise.get_noise_2d(c.x, c.y)
	for lane in lanes:
		var closest := Geometry2D.get_closest_point_to_segment(c, lane[0], lane[1])
		if c.distance_to(closest) < lane[2] + wobble * 1.2:
			return true
	for blob in blobs:
		var d: float = ((c - blob[0]) / blob[1]).length()
		if d < 1.0 + wobble * blob[2] * 2.0:
			return true
	var r := c.distance_to(ring_center)
	if r > ring_radii.x - wobble and r < ring_radii.y + wobble:
		return true
	return false


func _keep_connected() -> void:
	var first := Vector2i(int(floor(start.x / CELL)) * CELL, int(floor(start.y / CELL)) * CELL)
	var seen := {first: true}
	var queue: Array[Vector2i] = [first]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir in [Vector2i(CELL, 0), Vector2i(-CELL, 0), Vector2i(0, CELL), Vector2i(0, -CELL)]:
			var next: Vector2i = cell + dir
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	cells = seen


## Склеивает клетки в крупные прямоугольники: для коллизии пола и мини-карты.
func merged_rects() -> Array[Rect2]:
	var rows := {}
	for cell: Vector2i in cells:
		if not rows.has(cell.y): rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var open := {}  # Vector2i(x0, x1) -> Rect2 ещё растущего прямоугольника
	var result: Array[Rect2] = []
	var zs := rows.keys()
	zs.sort()
	var last_z = null
	for z in zs:
		var xs: Array = rows[z]
		xs.sort()
		var runs := []
		var run_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] != prev + CELL:
				runs.append(Vector2i(run_start, prev + CELL))
				run_start = xs[i]
			prev = xs[i]
		runs.append(Vector2i(run_start, prev + CELL))
		var next_open := {}
		for run in runs:
			if last_z != null and z == last_z + CELL and open.has(run):
				var grown: Rect2 = open[run]
				grown.size.y += CELL
				next_open[run] = grown
				open.erase(run)
			else:
				next_open[run] = Rect2(run.x, z, run.y - run.x, CELL)
		for rect in open.values():
			result.append(rect)
		open = next_open
		last_z = z
	for rect in open.values():
		result.append(rect)
	return result


func has_floor(at: Vector2) -> bool:
	return cells.has(Vector2i(int(floor(at.x / CELL)) * CELL, int(floor(at.y / CELL)) * CELL))


## Расстояние до ближайшего края пола (в клетках по 2 м), не дальше limit.
func distance_to_edge(at: Vector2, limit := 8.0) -> float:
	var best := limit
	for dx in range(-int(limit), int(limit) + 1, CELL):
		for dz in range(-int(limit), int(limit) + 1, CELL):
			var p := at + Vector2(dx, dz)
			if not has_floor(p):
				best = minf(best, at.distance_to(p))
	return best


## Есть ли пол ближе radius метров (для деревьев и скал за стенами).
func near_floor(at: Vector2, radius: float) -> bool:
	for dx in range(-int(radius), int(radius) + 1, CELL):
		for dz in range(-int(radius), int(radius) + 1, CELL):
			if Vector2(dx, dz).length() <= radius and has_floor(at + Vector2(dx, dz)):
				return true
	return false


## Расстояние от точки до главного пути.
func distance_to_route(at: Vector2) -> float:
	var best := INF
	for i in route.size() - 1:
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, route[i], route[i + 1])))
	return best
