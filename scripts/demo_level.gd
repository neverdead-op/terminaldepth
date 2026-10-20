extends "res://scripts/zone.gd"
## Демо-арена (главное меню → «Новая игра» → Demo): тест без забега.
## Оружейная — безопасная комната со складом «Арсенал»: всё оружие, все модули, фрагменты.
## Проход на юг ведёт на арену, где враги всех видов идут волнами без конца.
## Сохранений нет (Game.testing), герой бессмертен, 5-й уровень и запас очков пассивок.

const ModuleDB := preload("res://scripts/module_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const STASH := preload("res://scripts/stash.gd")
const SAFE := preload("res://scripts/safe_zone.gd")
const FLOOR_SHADER := preload("res://assets/shaders/floor.gdshader")
const WALL_SHADER := preload("res://assets/shaders/wall.gdshader")
const KINDS := {
	"crawler": preload("res://scenes/crawler.tscn"), "leaper": preload("res://scenes/leaper.tscn"),
	"spitter": preload("res://scenes/spitter.tscn"), "brute": preload("res://scenes/brute.tscn"),
	"robot_walker": preload("res://scenes/robot_walker.tscn"), "robot_drone": preload("res://scenes/robot_drone.tscn"),
	"robot_heavy": preload("res://scenes/robot_heavy.tscn"),
}

## Оружейная, проход и арена (x, z, ширина, глубина).
const ROOM := Rect2(-9, -9, 18, 18)
const PASS := Rect2(-3, 9, 6, 8)
const ARENA := Rect2(-24, 17, 48, 40)
## Сколько врагов на арене одновременно; осталось меньше половины — приходит новая волна.
@export var arena_enemies := 45
@export var wave_check_every := 4.0

var _enemies: Node3D
var _wave_check := 0.0
var _spawned := 0


func _ready() -> void:
	map_rects = [ROOM, PASS, ARENA]
	_build()
	super()
	_fill_arsenal.call_deferred()


func _build() -> void:
	var geo := $Navigation/Geometry
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	floor_mat.set_shader_parameter("base_color", Color(0.16, 0.16, 0.18))
	var wall_mat := ShaderMaterial.new()
	wall_mat.shader = WALL_SHADER
	for r: Rect2 in map_rects:
		_box(geo, Vector3(r.get_center().x, -0.25, r.get_center().y), Vector3(r.size.x, 0.5, r.size.y), floor_mat)
	# Стены по контуру: клетки 1 м вокруг проходимого.
	var walls := {}
	for r: Rect2 in map_rects:
		for x in range(int(r.position.x) - 1, int(r.end.x) + 1):
			for z in range(int(r.position.y) - 1, int(r.end.y) + 1):
				if not _walkable(x + 0.5, z + 0.5):
					walls[Vector2i(x, z)] = true
	# Соседние клетки по X сливаем в одну коробку.
	var done := {}
	for cell: Vector2i in walls:
		if done.has(cell):
			continue
		var end := cell.x
		while walls.has(Vector2i(end + 1, cell.y)) and not done.has(Vector2i(end + 1, cell.y)):
			end += 1
		for x in range(cell.x, end + 1):
			done[Vector2i(x, cell.y)] = true
		var length := end - cell.x + 1
		_box(geo, Vector3(cell.x + length * 0.5, 1.5, cell.y + 0.5), Vector3(length, 3.0, 1.0), wall_mat)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.5, 0.55)
	env.ambient_light_energy = 1.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for r: Rect2 in map_rects:
		for x in range(int(r.position.x) + 3, int(r.end.x) - 1, 8):
			for z in range(int(r.position.y) + 3, int(r.end.y) - 1, 8):
				var light := OmniLight3D.new()
				light.light_color = Color(0.85, 0.9, 1.0) if r == ROOM else Color(1.0, 0.65, 0.45)
				light.light_energy = 6.0
				light.omni_range = 11.0
				light.position = Vector3(x, 2.7, z)
				add_child(light)
	# Оружейная безопасна: враги туда не заходят и не видят героя.
	var safe := Area3D.new()
	safe.set_script(SAFE)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM.size.x, 4, ROOM.size.y)
	shape.shape = box
	safe.add_child(shape)
	safe.position = Vector3(ROOM.get_center().x, 1, ROOM.get_center().y)
	add_child(safe)
	var stash := Node3D.new()
	stash.set_script(STASH)
	stash.set("stash_name", "Арсенал")
	stash.position = Vector3(0, 0, -6)
	add_child(stash)
	_enemies = Node3D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_spawn_wave(arena_enemies)


func _walkable(x: float, z: float) -> bool:
	for r: Rect2 in map_rects:
		if r.has_point(Vector2(x, z)):
			return true
	return false


func _box(parent: Node, center: Vector3, box_size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	parent.add_child(body)


func _spawn_wave(count: int) -> void:
	for i in count:
		_spawned += 1
		# Каждый 5-й — тяжёлый (Носитель, тяжёлый робот), остальные — вперемешку.
		var kind: String = ["brute", "robot_heavy"].pick_random() if _spawned % 5 == 0 \
				else ["crawler", "crawler", "leaper", "spitter", "robot_walker", "robot_drone"].pick_random()
		var e: Node3D = KINDS[kind].instantiate()
		if _spawned % 9 == 0:
			e.set("rarity", 2 if _spawned % 18 == 0 else 1)
		e.position = Vector3(randf_range(ARENA.position.x + 3, ARENA.end.x - 3), 0.1,
				randf_range(ARENA.position.y + 14, ARENA.end.y - 3))
		_enemies.add_child(e)


func _process(delta: float) -> void:
	super(delta)
	_wave_check -= delta
	if _wave_check > 0.0:
		return
	_wave_check = wave_check_every
	var alive := _enemies.get_children().filter(func(n: Node) -> bool: return n.is_in_group("enemies")).size()
	if alive < arena_enemies / 2:
		_spawn_wave(arena_enemies - alive)


## Склад «Арсенал»: всё оружие (Rare 5-го уровня), все модули по два, все фрагменты по 20.
func _fill_arsenal() -> void:
	var tabs: Array = Game.stash_tabs
	for t in tabs:
		t.entries.clear()
	var last: int = tabs.size() - 1
	# Модули — в последнюю вкладку, оружие — по порядку во все (последняя добирает остаток).
	for m in ModuleDB.ALL:
		for k in 2:
			tabs[last].add_item(m.duplicate())
	var tab := 0
	for b in ItemDB.BASES:
		if not b.has("weapon") or not ItemDB.available_in_act_one(b):
			continue
		var item := GearItem.create(b, 5, 2)
		while tab <= last and not tabs[tab].add_item(item):
			tab += 1
	for id in ItemDB.CURRENCY_ORDER:
		Game.stash_currency[id] = 20
